# **HELP & SUPPORT - DATABASE CHANGES PLAN**

**Status:** Ready for Execution  
**Date:** 2025-01-XX  
**Purpose:** Add ticket numbering system to support_tickets table

---

## **📋 PREREQUISITES**

✅ **Already Completed:**
- `category` field has been added to `support_tickets` table

---

## **🎯 OBJECTIVE**

Add automatic ticket number generation system:
- Format: `TKT-000001`, `TKT-000002`, etc.
- Auto-generated on ticket creation
- User-friendly reference number

---

## **📝 STEP-BY-STEP EXECUTION PLAN**

### **Step 1: Add `ticket_number` Column**

**Execute in Supabase SQL Editor:**

```sql
-- Add ticket_number column to support_tickets table
ALTER TABLE public.support_tickets 
ADD COLUMN ticket_number text UNIQUE;
```

**Expected Result:**
- Column `ticket_number` added to `support_tickets` table
- UNIQUE constraint ensures no duplicate ticket numbers

**Verification:**
```sql
-- Check if column exists
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_name = 'support_tickets' 
AND column_name = 'ticket_number';
```

---

### **Step 2: Create Sequence for Ticket Numbers**

**Execute in Supabase SQL Editor:**

```sql
-- Create sequence starting from 1
CREATE SEQUENCE IF NOT EXISTS public.ticket_number_seq 
START 1 
INCREMENT 1;
```

**Expected Result:**
- Sequence `ticket_number_seq` created
- Starts at 1, increments by 1 for each ticket

**Verification:**
```sql
-- Check sequence exists
SELECT sequence_name, start_value, increment
FROM information_schema.sequences
WHERE sequence_name = 'ticket_number_seq';
```

---

### **Step 3: Create Function to Generate Ticket Number**

**Execute in Supabase SQL Editor:**

```sql
-- Function to generate ticket number in format TKT-000001
CREATE OR REPLACE FUNCTION public.generate_ticket_number()
RETURNS text 
LANGUAGE plpgsql
AS $$
DECLARE
    next_num integer;
    ticket_num text;
BEGIN
    -- Get next number from sequence
    next_num := nextval('public.ticket_number_seq');
    
    -- Format as TKT-000001 (6 digits, zero-padded)
    ticket_num := 'TKT-' || LPAD(next_num::text, 6, '0');
    
    RETURN ticket_num;
END;
$$;
```

**Expected Result:**
- Function `generate_ticket_number()` created
- Returns formatted ticket number: `TKT-000001`, `TKT-000002`, etc.

**Verification:**
```sql
-- Test function (should return TKT-000001)
SELECT public.generate_ticket_number();
```

---

### **Step 4: Create Trigger Function**

**Execute in Supabase SQL Editor:**

```sql
-- Function to set ticket_number before insert
CREATE OR REPLACE FUNCTION public.set_ticket_number()
RETURNS TRIGGER 
LANGUAGE plpgsql
AS $$
BEGIN
    -- Only generate if ticket_number is NULL (allows manual override if needed)
    IF NEW.ticket_number IS NULL THEN
        NEW.ticket_number := public.generate_ticket_number();
    END IF;
    
    RETURN NEW;
END;
$$;
```

**Expected Result:**
- Trigger function `set_ticket_number()` created
- Automatically generates ticket number if not provided

**Verification:**
```sql
-- Check function exists
SELECT routine_name, routine_type
FROM information_schema.routines
WHERE routine_name = 'set_ticket_number';
```

---

### **Step 5: Create Trigger on support_tickets Table**

**Execute in Supabase SQL Editor:**

```sql
-- Create trigger to auto-generate ticket_number on insert
CREATE TRIGGER ticket_number_trigger
BEFORE INSERT ON public.support_tickets
FOR EACH ROW
EXECUTE FUNCTION public.set_ticket_number();
```

**Expected Result:**
- Trigger `ticket_number_trigger` created
- Fires automatically before each INSERT
- Generates ticket number automatically

**Verification:**
```sql
-- Check trigger exists
SELECT trigger_name, event_manipulation, event_object_table
FROM information_schema.triggers
WHERE trigger_name = 'ticket_number_trigger';
```

---

### **Step 6: Test the Implementation**

**Execute in Supabase SQL Editor:**

```sql
-- Test insert (use a test user_id or your actual user_id)
INSERT INTO public.support_tickets (
    user_id,
    subject,
    message,
    category,
    status
) VALUES (
    '00000000-0000-0000-0000-000000000000'::uuid,  -- Replace with actual user_id for testing
    'Test Ticket',
    'This is a test ticket to verify ticket number generation',
    'question',
    'open'
) RETURNING id, ticket_number, subject, created_at;
```

**Expected Result:**
- Ticket inserted successfully
- `ticket_number` automatically generated (e.g., `TKT-000001`)
- Returns ticket with ticket_number

**Verification:**
```sql
-- Check all tickets with ticket numbers
SELECT id, ticket_number, subject, category, status, created_at
FROM public.support_tickets
ORDER BY created_at DESC
LIMIT 5;
```

---

### **Step 7: Handle Existing Tickets (If Any)**

**If you have existing tickets without ticket numbers:**

```sql
-- Update existing tickets with ticket numbers
UPDATE public.support_tickets
SET ticket_number = public.generate_ticket_number()
WHERE ticket_number IS NULL
ORDER BY created_at ASC;
```

**Expected Result:**
- All existing tickets get ticket numbers
- Numbers assigned in chronological order

**Verification:**
```sql
-- Check no NULL ticket numbers exist
SELECT COUNT(*) as null_ticket_numbers
FROM public.support_tickets
WHERE ticket_number IS NULL;
-- Should return 0
```

---

## **✅ COMPLETION CHECKLIST**

After executing all steps, verify:

- [ ] `ticket_number` column exists in `support_tickets` table
- [ ] Sequence `ticket_number_seq` exists
- [ ] Function `generate_ticket_number()` exists and works
- [ ] Function `set_ticket_number()` exists
- [ ] Trigger `ticket_number_trigger` exists
- [ ] Test insert generates ticket number automatically
- [ ] All existing tickets have ticket numbers (if any)

---

## **🔍 TROUBLESHOOTING**

### **Issue: Duplicate ticket number error**
**Solution:** Check sequence value and reset if needed:
```sql
-- Check current sequence value
SELECT last_value FROM ticket_number_seq;

-- Reset sequence if needed (use next available number)
SELECT setval('ticket_number_seq', (SELECT MAX(CAST(SUBSTRING(ticket_number FROM 5) AS INTEGER)) FROM support_tickets));
```

### **Issue: Trigger not firing**
**Solution:** Check trigger exists and is enabled:
```sql
-- Check trigger status
SELECT * FROM information_schema.triggers 
WHERE trigger_name = 'ticket_number_trigger';
```

### **Issue: Function not found**
**Solution:** Ensure functions are in `public` schema:
```sql
-- Check function exists
SELECT routine_name FROM information_schema.routines 
WHERE routine_name IN ('generate_ticket_number', 'set_ticket_number');
```

---

## **📊 FINAL TABLE STRUCTURE**

After completion, `support_tickets` table will have:

```sql
support_tickets
├── id (uuid, PK) - Internal UUID
├── user_id (uuid, FK) - User reference
├── ticket_number (text, UNIQUE) - User-facing: TKT-000001
├── category (text) - bug/feature/question/feedback/other
├── subject (text) - Ticket subject
├── message (text) - Ticket message
├── status (text) - open/closed
├── created_at (timestamptz) - Creation timestamp
└── closed_at (timestamptz) - Closure timestamp (nullable)
```

---

## **🚀 NEXT STEPS (After DB Changes)**

1. Update `SupportTicket` model in Flutter to include `ticketNumber` field
2. Create Help & Support screen UI
3. Create service to submit tickets
4. Display ticket number to user after submission
5. Create "My Tickets" list view (optional)

---

## **📝 NOTES**

- **Ticket Number Format:** `TKT-000001` (6 digits, zero-padded)
- **Auto-generation:** Trigger handles automatically on INSERT
- **Uniqueness:** UNIQUE constraint prevents duplicates
- **Sequence:** Starts at 1, increments automatically
- **Manual Override:** Can manually set ticket_number if needed (for special cases)

---

**Status:** Ready for Execution  
**Estimated Time:** 5-10 minutes  
**Risk Level:** LOW (additive changes, no data loss)

