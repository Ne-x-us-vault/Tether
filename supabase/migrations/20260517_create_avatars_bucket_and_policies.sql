-- ============================================================================
-- Migration: Create Avatars Storage Bucket and RLS Policies
-- ============================================================================

-- 1. Create the 'avatars' storage bucket if it doesn't already exist
INSERT INTO storage.buckets (id, name, public) 
VALUES ('avatars', 'avatars', true)
ON CONFLICT (id) DO UPDATE SET public = true;

-- 2. Allow public read access to all avatar files
CREATE POLICY "Allow public read access to avatars" 
ON storage.objects FOR SELECT 
USING (bucket_id = 'avatars');

-- 3. Allow authenticated users to upload new avatars
CREATE POLICY "Allow authenticated uploads to avatars" 
ON storage.objects FOR INSERT TO authenticated 
WITH CHECK (bucket_id = 'avatars');

-- 4. Allow authenticated users to update existing avatars
CREATE POLICY "Allow authenticated updates to avatars" 
ON storage.objects FOR UPDATE TO authenticated 
USING (bucket_id = 'avatars');

-- 5. Allow authenticated users to delete their old avatars
CREATE POLICY "Allow authenticated deletes to avatars" 
ON storage.objects FOR DELETE TO authenticated 
USING (bucket_id = 'avatars');
