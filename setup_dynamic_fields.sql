-- إنشاء جدول الحقول الديناميكية
-- يجب تنفيذ هذا في Supabase SQL Editor

-- جدول تعريفات الحقول الديناميكية
CREATE TABLE IF NOT EXISTS dynamic_field_definitions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  label_ar TEXT NOT NULL,
  field_type TEXT NOT NULL CHECK (field_type IN ('text', 'number', 'boolean', 'select', 'date')),
  scope TEXT NOT NULL CHECK (scope IN ('patient', 'session')),
  service_type TEXT, -- NULL = ينطبق على جميع الخدمات
  options TEXT[], -- للحقول من نوع select
  is_required BOOLEAN DEFAULT false,
  display_order INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- جدول قيم الحقول الديناميكية
CREATE TABLE IF NOT EXISTS dynamic_field_values (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  field_id UUID REFERENCES dynamic_field_definitions(id) ON DELETE CASCADE,
  patient_id UUID REFERENCES patients(id) ON DELETE CASCADE,
  session_id UUID REFERENCES sessions(id) ON DELETE CASCADE,
  value TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- إضافة بعض الحقول الافتراضية لخدمات الليزر
INSERT INTO dynamic_field_definitions (name, label_ar, field_type, scope, service_type, options, is_required, display_order) VALUES
  ('skin_type', 'نوع البشرة', 'select', 'session', NULL, ARRAY['I', 'II', 'III', 'IV', 'V', 'VI'], false, 1),
  ('session_number', 'رقم الجلسة', 'number', 'session', NULL, NULL, false, 2),
  ('spot_bd', 'Spot B.D', 'text', 'session', 'Laser', NULL, false, 3),
  ('alex_value', 'Alex (J/cm²)', 'number', 'session', 'Laser', NULL, false, 4),
  ('yag_value', 'Yag (J/cm²)', 'number', 'session', 'Laser', NULL, false, 5),
  ('room', 'الغرفة', 'text', 'session', NULL, NULL, false, 6);

-- إنشاء Index لتحسين الأداء
CREATE INDEX IF NOT EXISTS idx_dynamic_field_values_patient ON dynamic_field_values(patient_id);
CREATE INDEX IF NOT EXISTS idx_dynamic_field_values_session ON dynamic_field_values(session_id);
CREATE INDEX IF NOT EXISTS idx_dynamic_field_definitions_scope ON dynamic_field_definitions(scope);

-- تفعيل RLS
ALTER TABLE dynamic_field_definitions ENABLE ROW LEVEL SECURITY;
ALTER TABLE dynamic_field_values ENABLE ROW LEVEL SECURITY;

-- سياسات الأمان (للسماح للجميع بالقراءة والكتابة مؤقتاً)
CREATE POLICY "Allow all for dynamic_field_definitions" ON dynamic_field_definitions FOR ALL USING (true);
CREATE POLICY "Allow all for dynamic_field_values" ON dynamic_field_values FOR ALL USING (true);
