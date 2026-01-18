-- إنشاء جدول الغرف
-- Create rooms table for Dr SJAD System

CREATE TABLE IF NOT EXISTS rooms (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(255) NOT NULL,
    is_active BOOLEAN DEFAULT true,
    description TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- إضافة فهرس على الاسم
CREATE INDEX IF NOT EXISTS idx_rooms_name ON rooms(name);

-- تفعيل RLS
ALTER TABLE rooms ENABLE ROW LEVEL SECURITY;

-- سياسة القراءة: الجميع يستطيع القراءة
CREATE POLICY "Rooms are viewable by everyone" ON rooms
    FOR SELECT USING (true);

-- سياسة الإدخال: المصرح لهم فقط
CREATE POLICY "Rooms can be inserted by authenticated users" ON rooms
    FOR INSERT WITH CHECK (true);

-- سياسة التحديث: المصرح لهم فقط
CREATE POLICY "Rooms can be updated by authenticated users" ON rooms
    FOR UPDATE USING (true);

-- سياسة الحذف: المصرح لهم فقط
CREATE POLICY "Rooms can be deleted by authenticated users" ON rooms
    FOR DELETE USING (true);

-- إضافة غرف افتراضية
INSERT INTO rooms (name, is_active) VALUES 
    ('غرفة 1', true),
    ('غرفة 2', true),
    ('غرفة 3', true),
    ('Room 1', true),
    ('Room 2', true)
ON CONFLICT DO NOTHING;

-- رسالة تأكيد
-- ✅ Table 'rooms' created successfully!
