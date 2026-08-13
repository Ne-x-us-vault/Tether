-- ============================================================================
-- Migration: Create Messages and Memories Storage Buckets and RLS Policies
-- Date: 2026-05-18
-- ============================================================================

-- 1. Create the 'messages' storage bucket if it doesn't already exist
INSERT INTO storage.buckets (id, name, public) 
VALUES ('messages', 'messages', true)
ON CONFLICT (id) DO UPDATE SET public = true;

-- 2. Create the 'memories' storage bucket if it doesn't already exist
INSERT INTO storage.buckets (id, name, public) 
VALUES ('memories', 'memories', true)
ON CONFLICT (id) DO UPDATE SET public = true;

-- 3. Allow public read access to all message files
CREATE POLICY "Allow public read access to messages" 
ON storage.objects FOR SELECT 
USING (bucket_id = 'messages');

-- 4. Allow authenticated uploads to messages
CREATE POLICY "Allow authenticated uploads to messages" 
ON storage.objects FOR INSERT TO authenticated 
WITH CHECK (bucket_id = 'messages');

-- 5. Allow authenticated updates to messages
CREATE POLICY "Allow authenticated updates to messages" 
ON storage.objects FOR UPDATE TO authenticated 
USING (bucket_id = 'messages');

-- 6. Allow authenticated deletes to messages
CREATE POLICY "Allow authenticated deletes to messages" 
ON storage.objects FOR DELETE TO authenticated 
USING (bucket_id = 'messages');

-- 7. Allow public read access to all memory files
CREATE POLICY "Allow public read access to memories" 
ON storage.objects FOR SELECT 
USING (bucket_id = 'memories');

-- 8. Allow authenticated uploads to memories
CREATE POLICY "Allow authenticated uploads to memories" 
ON storage.objects FOR INSERT TO authenticated 
WITH CHECK (bucket_id = 'memories');

-- 9. Allow authenticated updates to memories
CREATE POLICY "Allow authenticated updates to memories" 
ON storage.objects FOR UPDATE TO authenticated 
USING (bucket_id = 'memories');

-- 10. Allow authenticated deletes to memories
CREATE POLICY "Allow authenticated deletes to memories" 
ON storage.objects FOR DELETE TO authenticated 
USING (bucket_id = 'memories');
