-- ══════════════════════════════════════════════════════════════════════════════
-- Enable Realtime for Critical Tables
-- This migration adds missing realtime subscriptions for:
-- 1. pairings (Critical: needed for pairing recognition)
-- 2. budget_transactions (Shared expense tracking)
-- 3. cycle_tracking (Period tracking with partner sync)
-- ══════════════════════════════════════════════════════════════════════════════

-- Enable realtime for pairings table (CRITICAL for pairing flow)
-- Both users need to receive updates when pairing status changes
ALTER PUBLICATION supabase_realtime ADD TABLE pairings;

-- Enable realtime for budget_transactions table
ALTER PUBLICATION supabase_realtime ADD TABLE budget_transactions;

-- Enable realtime for cycle_tracking table
ALTER PUBLICATION supabase_realtime ADD TABLE cycle_tracking;

-- ══════════════════════════════════════════════════════════════════════════════
-- Verify the changes (run this to check):
-- SELECT tablename FROM pg_publication_tables 
-- WHERE publication_name = 'supabase_realtime'
-- ORDER BY tablename;
-- ══════════════════════════════════════════════════════════════════════════════
