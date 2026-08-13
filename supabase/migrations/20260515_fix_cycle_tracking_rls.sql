-- Fix RLS policy to allow users to update and delete their own cycle tracking data when unpaired

DO $$
BEGIN
  -- Add update policy for owner
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'cycle_tracking'
      AND policyname = 'Users can update their own cycle data'
  ) THEN
    CREATE POLICY "Users can update their own cycle data" ON public.cycle_tracking
      FOR UPDATE
      USING (user_id = auth.uid())
      WITH CHECK (user_id = auth.uid());
  END IF;

  -- Add delete policy for owner
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'cycle_tracking'
      AND policyname = 'Users can delete their own cycle data'
  ) THEN
    CREATE POLICY "Users can delete their own cycle data" ON public.cycle_tracking
      FOR DELETE
      USING (user_id = auth.uid());
  END IF;
END
$$;
