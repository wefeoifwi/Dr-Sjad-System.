-- ============================================
-- DR SJAD System - Database Update for Import
-- تحديث قاعدة البيانات للتوافق مع الاستيراد
-- ============================================

-- 1. إنشاء جدول الغرف
CREATE TABLE IF NOT EXISTS rooms (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(255) NOT NULL,
    is_active BOOLEAN DEFAULT true,
    description TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- تفعيل RLS للغرف
ALTER TABLE rooms ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow all rooms" ON rooms;
CREATE POLICY "Allow all rooms" ON rooms FOR ALL USING (true);

-- 2. إنشاء جدول الأجهزة
CREATE TABLE IF NOT EXISTS devices (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(255) NOT NULL,
    status VARCHAR(50) DEFAULT 'active',
    description TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- تفعيل RLS للأجهزة
ALTER TABLE devices ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow all devices" ON devices;
CREATE POLICY "Allow all devices" ON devices FOR ALL USING (true);

-- 3. تحديث جدول الخدمات (إضافة default_price إذا لم يكن موجوداً)
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'services' AND column_name = 'default_price') THEN
        ALTER TABLE services ADD COLUMN default_price DECIMAL(10,2) DEFAULT 0;
    END IF;
END $$;

-- 4. تحديث جدول profiles (إضافة is_active إذا لم يكن موجوداً)
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'profiles' AND column_name = 'is_active') THEN
        ALTER TABLE profiles ADD COLUMN is_active BOOLEAN DEFAULT true;
    END IF;
END $$;

-- 5. تحديث جدول profiles (إضافة username و password إذا لم يكونا موجودين)
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'profiles' AND column_name = 'username') THEN
        ALTER TABLE profiles ADD COLUMN username VARCHAR(255);
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'profiles' AND column_name = 'password') THEN
        ALTER TABLE profiles ADD COLUMN password VARCHAR(255);
    END IF;
END $$;

-- 6. تحديث جدول sessions (إضافة room_id إذا لم يكن موجوداً)
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'sessions' AND column_name = 'room_id') THEN
        ALTER TABLE sessions ADD COLUMN room_id UUID REFERENCES rooms(id);
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'sessions' AND column_name = 'device_id') THEN
        ALTER TABLE sessions ADD COLUMN device_id UUID REFERENCES devices(id);
    END IF;
END $$;

-- 7. إنشاء فهارس للبحث السريع
CREATE INDEX IF NOT EXISTS idx_rooms_name ON rooms(name);
CREATE INDEX IF NOT EXISTS idx_devices_name ON devices(name);
CREATE INDEX IF NOT EXISTS idx_services_name ON services(name);
CREATE INDEX IF NOT EXISTS idx_profiles_role ON profiles(role);
CREATE INDEX IF NOT EXISTS idx_profiles_username ON profiles(username);

-- 8. إضافة بعض الغرف الافتراضية
INSERT INTO rooms (name, is_active) VALUES 
    ('Room 1', true),
    ('Room 2', true),
    ('Room 3', true)
ON CONFLICT DO NOTHING;

-- ============================================
-- ✅ Database updated successfully!
-- تم تحديث قاعدة البيانات بنجاح!
-- ============================================
