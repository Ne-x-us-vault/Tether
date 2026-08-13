-- ══════════════════════════════════════════════════════════════════════════════
-- Migration: Add message reactions and edit tracking
-- Date: 2026-05-12
-- Purpose: Support emoji reactions and message editing with edit history
-- ══════════════════════════════════════════════════════════════════════════════

-- 1. Create message_reactions table
CREATE TABLE IF NOT EXISTS public.message_reactions (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  message_id uuid NOT NULL REFERENCES public.messages(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  emoji text NOT NULL,
  created_at timestamp with time zone DEFAULT now(),
  
  -- Ensure only one reaction per user per message per emoji
  UNIQUE(message_id, user_id, emoji)
);

-- 2. Add edited_at and edit_history to messages table
ALTER TABLE IF EXISTS public.messages
ADD COLUMN IF NOT EXISTS edited_at timestamp with time zone;

ALTER TABLE IF EXISTS public.messages
ADD COLUMN IF NOT EXISTS edit_history jsonb DEFAULT NULL;

-- 3. Create indices for performance
CREATE INDEX IF NOT EXISTS idx_message_reactions_message_id 
  ON public.message_reactions(message_id);
  
CREATE INDEX IF NOT EXISTS idx_message_reactions_user_id 
  ON public.message_reactions(user_id);

CREATE INDEX IF NOT EXISTS idx_message_reactions_created_at 
  ON public.message_reactions(created_at);

-- 4. Enable realtime for message_reactions
ALTER PUBLICATION supabase_realtime ADD TABLE public.message_reactions;

-- 5. Set up Row-Level Security (RLS) for message_reactions
ALTER TABLE public.message_reactions ENABLE ROW LEVEL SECURITY;

-- Allow users to see reactions on messages they're part of
CREATE POLICY "Users can view reactions on their pairing messages"
ON public.message_reactions FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM public.messages m
    JOIN public.pairings p ON m.pairing_id = p.id
    WHERE m.id = message_id
    AND (p.user1_id = auth.uid() OR p.user2_id = auth.uid())
  )
);

-- Allow users to add/remove their own reactions
CREATE POLICY "Users can manage their own reactions"
ON public.message_reactions FOR INSERT
WITH CHECK (
  auth.uid() = user_id
  AND EXISTS (
    SELECT 1 FROM public.messages m
    JOIN public.pairings p ON m.pairing_id = p.id
    WHERE m.id = message_id
    AND (p.user1_id = auth.uid() OR p.user2_id = auth.uid())
  )
);

CREATE POLICY "Users can delete their own reactions"
ON public.message_reactions FOR DELETE
USING (
  auth.uid() = user_id
);

-- 6. Update messages table RLS to allow reading edited_at and edit_history
-- (assuming RLS already exists for messages, this just ensures those columns are readable)

-- ══════════════════════════════════════════════════════════════════════════════
-- End Migration
-- ══════════════════════════════════════════════════════════════════════════════
