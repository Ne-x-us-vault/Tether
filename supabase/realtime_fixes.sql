-- ══════════════════════════════════════════════════════════════════════════════
-- LOVIT APP - SUPABASE REALTIME FIXES
-- Enable realtime for pairings, budget_transactions, cycle_tracking, and profiles
-- ══════════════════════════════════════════════════════════════════════════════

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- ADD MISSING TABLES TO REALTIME PUBLICATION
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

-- Critical fix 1: Enable realtime for pairings (required for pairing cache sync)
ALTER PUBLICATION supabase_realtime ADD TABLE pairings;

-- Critical fix 2: Enable realtime for budget_transactions (required for budget sync)
ALTER PUBLICATION supabase_realtime ADD TABLE budget_transactions;

-- Critical fix 3: Enable realtime for cycle_tracking (required for period tracking sync)
ALTER PUBLICATION supabase_realtime ADD TABLE cycle_tracking;

-- Critical fix 4: Enable realtime for profiles (required for battery, presence, location sync)
ALTER PUBLICATION supabase_realtime ADD TABLE profiles;

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- COMPLETE LIST OF REALTIME ENABLED TABLES (AFTER FIXES)
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- 
-- 1. messages ✅ (messaging)
-- 2. tasks ✅ (shared todo)
-- 3. calendar_events ✅ (shared calendar)
-- 4. shared_locations ✅ (location sharing)
-- 5. notifications ✅ (notifications)
-- 6. pairings ✅ (pairing flow) [ADDED]
-- 7. budget_transactions ✅ (budget) [ADDED]
-- 8. cycle_tracking ✅ (period tracking) [ADDED]
-- 9. profiles ✅ (battery, presence, location) [ADDED]
--
-- These tables sync automatically when changes occur on either device.
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
