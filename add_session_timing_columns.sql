-- Run this SQL in Supabase SQL Editor to add session timing columns
-- هذا السكربت لتحديث قاعدة البيانات الموجودة

-- Add session timing columns to sessions table
ALTER TABLE public.sessions 
ADD COLUMN IF NOT EXISTS session_start_time TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS session_end_time TIMESTAMPTZ;

-- Add comment for documentation
COMMENT ON COLUMN public.sessions.session_start_time IS 'Actual time when patient entered doctor room';
COMMENT ON COLUMN public.sessions.session_end_time IS 'Actual time when session ended';

SELECT 'Session timing columns added successfully!' as result;
