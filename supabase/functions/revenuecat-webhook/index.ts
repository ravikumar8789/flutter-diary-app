import { serve } from "https://deno.land/std@0.177.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  if (req.method !== 'POST') {
    return new Response(JSON.stringify({ error: 'Method not allowed' }), {
      status: 405,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  }

  try {
    // 1. Verify auth header (configure same value in RevenueCat dashboard)
    const authHeader = req.headers.get('authorization')
    const expectedAuth = Deno.env.get('REVENUECAT_WEBHOOK_SECRET')
    if (expectedAuth && authHeader !== expectedAuth) {
      return new Response(JSON.stringify({ error: 'Unauthorized' }), {
        status: 401,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    const body = await req.json()
    const event = body?.event
    if (!event) {
      return new Response(JSON.stringify({ error: 'No event' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    const userId = event.app_user_id
    const eventId = event.id
    const eventType = event.type
    const entitlementIds = event.entitlement_ids ?? []
    const expirationAtMs = event.expiration_at_ms
    const productId = event.product_id ?? null
    const store =
      event.store === 'PLAY_STORE'
        ? 'play_store'
        : event.store === 'APP_STORE'
          ? 'app_store'
          : null

    if (!userId) {
      return new Response(JSON.stringify({ error: 'No app_user_id' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? ''
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    if (!supabaseUrl || !supabaseServiceKey) {
      throw new Error('Missing Supabase config')
    }

    const supabase = createClient(supabaseUrl, supabaseServiceKey)

    // User must exist in users table (FK constraint)
    const { data: userExists } = await supabase
      .from('users')
      .select('id')
      .eq('id', userId)
      .single()

    if (!userExists) {
      return new Response(
        JSON.stringify({ ok: true, skipped: 'user_not_found' }),
        { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Idempotency: skip if same event already processed
    const { data: existing } = await supabase
      .from('user_premium')
      .select('last_event_id')
      .eq('user_id', userId)
      .single()

    if (existing?.last_event_id === eventId) {
      return new Response(
        JSON.stringify({ ok: true, skipped: 'duplicate' }),
        { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Grant: INITIAL_PURCHASE, RENEWAL, PRODUCT_CHANGE, TEST (for RevenueCat test webhooks)
    // Revoke: EXPIRATION (CANCELLATION = user cancelled but access until period end, keep premium)
    const grantEvents = ['INITIAL_PURCHASE', 'RENEWAL', 'PRODUCT_CHANGE', 'TEST']
    const revokeEvent = eventType === 'EXPIRATION'
    // TEST events have null entitlement_ids; treat as premium for testing
    const hasPremium =
      (entitlementIds.includes('premium') || eventType === 'TEST') &&
      grantEvents.includes(eventType) &&
      !revokeEvent

    const premiumExpiresAt = expirationAtMs
      ? new Date(expirationAtMs).toISOString()
      : null
    const gracePeriodExpiresAt = event.grace_period_expiration_at_ms
      ? new Date(event.grace_period_expiration_at_ms).toISOString()
      : null

    const row = {
      user_id: userId,
      is_premium: hasPremium,
      premium_expires_at: revokeEvent ? null : premiumExpiresAt,
      grace_period_expires_at: revokeEvent ? null : gracePeriodExpiresAt,
      entitlement_id: 'premium',
      product_id: productId,
      store,
      last_event_id: eventId,
      source: 'revenuecat',
      updated_at: new Date().toISOString(),
    }

    const { error } = await supabase
      .from('user_premium')
      .upsert(row, { onConflict: 'user_id' })

    if (error) throw error

    return new Response(JSON.stringify({ ok: true }), {
      status: 200,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  } catch (e) {
    const errMsg = e instanceof Error ? e.message : JSON.stringify(e)
    console.error('RevenueCat webhook error:', errMsg, e)
    return new Response(JSON.stringify({ error: errMsg }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  }
})
