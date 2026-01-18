-- ✅ تفعيل Realtime للجداول الأساسية
-- انسخ هذا الكود وشغله في Supabase -> SQL Editor

-- 1. جدول الحجوزات (Sessions)
ALTER PUBLICATION supabase_realtime ADD TABLE sessions;
ALTER TABLE sessions REPLICA IDENTITY FULL;

-- 2. جدول الإشعارات (Notifications)
ALTER PUBLICATION supabase_realtime ADD TABLE notifications;
ALTER TABLE notifications REPLICA IDENTITY FULL;

-- 3. جدول المرضى (Patients) - اختياري لتحديث الأسماء
ALTER PUBLICATION supabase_realtime ADD TABLE patients;
ALTER TABLE patients REPLICA IDENTITY FULL;

-- للتحقق من التفعيل:
SELECT * FROM pg_publication_tables WHERE pubname = 'supabase_realtime';
