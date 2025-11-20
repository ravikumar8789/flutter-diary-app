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

  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? ''
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''

    if (!supabaseUrl || !supabaseServiceKey) {
      throw new Error('Missing Supabase configuration')
    }

    const supabase = createClient(supabaseUrl, supabaseServiceKey)

    // Get all active users (or batch process)
    // For now, process users who have entries in the last 7 days
    const sevenDaysAgo = new Date()
    sevenDaysAgo.setDate(sevenDaysAgo.getDate() - 7)
    const sevenDaysAgoStr = sevenDaysAgo.toISOString().split('T')[0]

    const { data: activeUsers, error: usersError } = await supabase
      .from('entries')
      .select('user_id, users!inner(timezone)')
      .gte('entry_date', sevenDaysAgoStr)
      .not('user_id', 'is', null)

    if (usersError) throw usersError

    // Get unique users
    const uniqueUsers = [...new Map(
      (activeUsers || []).map((u: any) => [u.user_id, u])
    ).values()]

    let processed = 0
    let skipped = 0
    let errors = 0

    for (const user of uniqueUsers) {
      try {
        const userTimezone = (user as any).users?.timezone || 'UTC'
        
        // Calculate yesterday's date in user's timezone
        // For simplicity, use UTC and adjust (you may need timezone library)
        const now = new Date()
        const yesterday = new Date(now)
        yesterday.setDate(yesterday.getDate() - 1)
        const yesterdayStr = yesterday.toISOString().split('T')[0]

        // Find yesterday's entry
        const { data: yesterdayEntry, error: entryError } = await supabase
          .from('entries')
          .select('id')
          .eq('user_id', (user as any).user_id)
          .eq('entry_date', yesterdayStr)
          .maybeSingle()

        if (entryError || !yesterdayEntry) {
          skipped++
          continue
        }

        // Check completion
        const { data: isComplete, error: checkError } = await supabase.rpc(
          'check_entry_completion',
          { entry_uuid: yesterdayEntry.id }
        )

        if (checkError || !isComplete) {
          skipped++
          continue
        }

        // Check if insight already exists
        const { data: existingInsight } = await supabase
          .from('entry_insights')
          .select('id')
          .eq('entry_id', yesterdayEntry.id)
          .eq('status', 'success')
          .maybeSingle()

        if (existingInsight) {
          skipped++
          continue
        }

        // Call ai-analyze-daily
        await supabase.functions.invoke('ai-analyze-daily', {
          body: {
            entry_id: yesterdayEntry.id,
            user_id: (user as any).user_id
          }
        })

        processed++

      } catch (error) {
        console.error(`Error processing user ${(user as any).user_id}:`, error)
        errors++
      }
    }

    return new Response(
      JSON.stringify({ 
        success: true, 
        processed, 
        skipped, 
        errors,
        total: uniqueUsers.length 
      }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )

  } catch (error) {
    return new Response(
      JSON.stringify({ 
        success: false, 
        error: error instanceof Error ? error.message : 'Unknown error'
      }),
      { 
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
      }
    )
  }
})

