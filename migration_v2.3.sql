-- =====================================================
-- Migration v2.3 - نظام الحجز بالأقسام
-- تاريخ: 2026-01-18
-- =====================================================

-- 1. تعديل جدول الجلسات
-- =====================================================
-- إضافة department_id للحجز بالقسم
ALTER TABLE sessions 
  ADD COLUMN IF NOT EXISTS department_id UUID REFERENCES departments(id);

-- إضافة payment_time لتتبع وقت الدفع
ALTER TABLE sessions 
  ADD COLUMN IF NOT EXISTS payment_time TIMESTAMPTZ;

-- إضافة assigned_doctor_id للدكتور المعين عند الدفع
ALTER TABLE sessions 
  ADD COLUMN IF NOT EXISTS assigned_doctor_id UUID REFERENCES profiles(id);

-- إضافة assigned_at لوقت تعيين الدكتور
ALTER TABLE sessions 
  ADD COLUMN IF NOT EXISTS assigned_at TIMESTAMPTZ;

-- جعل doctor_id اختياري (للحجز بدون دكتور)
ALTER TABLE sessions 
  ALTER COLUMN doctor_id DROP NOT NULL;

-- 2. تعديل جدول المرضى - التصنيف
-- =====================================================
-- إضافة تصنيف الزبون
ALTER TABLE patients 
  ADD COLUMN IF NOT EXISTS category TEXT DEFAULT 'new' 
  CHECK (category IN ('vip', 'regular', 'new', 'blacklist'));

-- إضافة عدد الزيارات الإجمالي
ALTER TABLE patients 
  ADD COLUMN IF NOT EXISTS total_visits INT DEFAULT 0;

-- إضافة إجمالي المبلغ المدفوع
ALTER TABLE patients 
  ADD COLUMN IF NOT EXISTS total_spent INT DEFAULT 0;

-- إضافة الموظف المسؤول عن المتابعة
ALTER TABLE patients 
  ADD COLUMN IF NOT EXISTS assigned_staff_id UUID REFERENCES profiles(id);

-- 3. تعديل جدول المتابعات
-- =====================================================
-- إضافة الموظف المعين للمتابعة
ALTER TABLE follow_ups 
  ADD COLUMN IF NOT EXISTS assigned_to UUID REFERENCES profiles(id);

-- من قام بالتعيين
ALTER TABLE follow_ups 
  ADD COLUMN IF NOT EXISTS assigned_by UUID REFERENCES profiles(id);

-- وقت التعيين
ALTER TABLE follow_ups 
  ADD COLUMN IF NOT EXISTS assigned_at TIMESTAMPTZ;

-- 4. تعديل جدول الإشعارات
-- =====================================================
-- إضافة الأولوية
ALTER TABLE notifications 
  ADD COLUMN IF NOT EXISTS priority TEXT DEFAULT 'normal' 
  CHECK (priority IN ('low', 'normal', 'high', 'urgent'));

-- إضافة الفئة
ALTER TABLE notifications 
  ADD COLUMN IF NOT EXISTS category TEXT DEFAULT 'general';

-- إضافة رابط الإجراء
ALTER TABLE notifications 
  ADD COLUMN IF NOT EXISTS action_url TEXT;

-- 5. جدول إعدادات المتابعة (جديد)
-- =====================================================
CREATE TABLE IF NOT EXISTS follow_up_settings (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  daily_limit_per_staff INT DEFAULT 20,
  auto_assign_to_creator BOOLEAN DEFAULT true,
  priority_vip BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- إدراج الإعدادات الافتراضية
INSERT INTO follow_up_settings (daily_limit_per_staff, auto_assign_to_creator, priority_vip)
SELECT 20, true, true
WHERE NOT EXISTS (SELECT 1 FROM follow_up_settings);

-- 6. تحديث تصنيف الزبائن الحاليين
-- =====================================================
-- تحديث عدد الزيارات لكل مريض
UPDATE patients p SET total_visits = (
  SELECT COUNT(*) FROM sessions s WHERE s.patient_id = p.id AND s.status = 'completed'
);

-- تحديث التصنيف بناءً على عدد الزيارات
UPDATE patients SET category = 'vip' WHERE total_visits >= 5;
UPDATE patients SET category = 'regular' WHERE total_visits BETWEEN 2 AND 4;
UPDATE patients SET category = 'new' WHERE total_visits <= 1;

-- 7. تعيين المتابعات للموظف الذي أنشأ الحجز
-- =====================================================
UPDATE follow_ups f SET assigned_to = (
  SELECT s.created_by FROM sessions s WHERE s.patient_id = f.patient_id LIMIT 1
)
WHERE assigned_to IS NULL;

-- 8. تمكين Realtime للجداول المحدثة
-- =====================================================
ALTER PUBLICATION supabase_realtime ADD TABLE follow_up_settings;

-- 9. Index للأداء
-- =====================================================
CREATE INDEX IF NOT EXISTS idx_sessions_department ON sessions(department_id);
CREATE INDEX IF NOT EXISTS idx_sessions_assigned_doctor ON sessions(assigned_doctor_id);
CREATE INDEX IF NOT EXISTS idx_patients_category ON patients(category);
CREATE INDEX IF NOT EXISTS idx_follow_ups_assigned ON follow_ups(assigned_to);
CREATE INDEX IF NOT EXISTS idx_notifications_priority ON notifications(priority);

-- =====================================================
-- ✅ Migration Complete!
-- =====================================================
