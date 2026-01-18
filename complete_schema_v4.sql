-- ═══════════════════════════════════════════════════════════════════════════════
-- CarePoint COMPLETE Database Schema
-- Version: 4.0 - Fresh Installation
-- Run ALL of this in Supabase SQL Editor for new project setup
-- ═══════════════════════════════════════════════════════════════════════════════

-- 1. Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ═══════════════════════════════════════════════════════════════════════════════
-- CORE TABLES
-- ═══════════════════════════════════════════════════════════════════════════════

-- 2. Profiles Table (Staff: Doctors, Employees, Admin)
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    username TEXT UNIQUE NOT NULL,
    password TEXT DEFAULT 'admin123',
    email TEXT,
    name TEXT NOT NULL,
    role TEXT NOT NULL DEFAULT 'employee',
    phone TEXT,
    department TEXT,
    avatar_url TEXT,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 3. Patients Table
CREATE TABLE IF NOT EXISTS public.patients (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL,
    phone TEXT,
    age INTEGER,
    address TEXT,
    notes TEXT,
    gender TEXT DEFAULT 'female',
    source TEXT DEFAULT 'walk_in',
    skin_type TEXT DEFAULT 'III',
    medical_history TEXT,
    allergies TEXT,
    blood_type TEXT,
    emergency_contact TEXT,
    emergency_phone TEXT,
    last_visit_date TIMESTAMPTZ,
    total_visits INTEGER DEFAULT 0,
    category TEXT DEFAULT 'regular', -- regular, vip, blacklist
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 4. Departments Table
CREATE TABLE IF NOT EXISTS public.departments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL UNIQUE,
    description TEXT,
    color_code TEXT DEFAULT '#6C63FF',
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 5. Devices Table
CREATE TABLE IF NOT EXISTS public.devices (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL,
    type TEXT,
    status TEXT DEFAULT 'active',
    serial_number TEXT,
    last_maintenance_date TIMESTAMPTZ,
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 6. Services Table
CREATE TABLE IF NOT EXISTS public.services (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL,
    name_ar TEXT,
    description TEXT,
    default_price NUMERIC DEFAULT 0,
    duration_minutes INTEGER DEFAULT 30,
    device_id UUID REFERENCES public.devices(id),
    department_id UUID REFERENCES public.departments(id),
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 7. Sessions Table (Bookings/Appointments)
CREATE TABLE IF NOT EXISTS public.sessions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    patient_id UUID REFERENCES public.patients(id) ON DELETE SET NULL,
    doctor_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    service_id UUID REFERENCES public.services(id) ON DELETE SET NULL,
    device_id UUID REFERENCES public.devices(id) ON DELETE SET NULL,
    department_id UUID REFERENCES public.departments(id) ON DELETE SET NULL,
    start_time TIMESTAMPTZ NOT NULL,
    end_time TIMESTAMPTZ,
    session_start_time TIMESTAMPTZ,
    session_end_time TIMESTAMPTZ,
    service_type TEXT,
    status TEXT DEFAULT 'scheduled',
    price NUMERIC DEFAULT 0,
    paid_amount NUMERIC DEFAULT 0,
    notes TEXT,
    cancel_reason TEXT,
    postpone_reason TEXT,
    medical_notes JSONB,
    room TEXT,
    session_number INTEGER DEFAULT 1,
    assigned_to UUID REFERENCES public.profiles(id),
    booked_by UUID REFERENCES public.profiles(id),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID REFERENCES public.profiles(id),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 8. Payments Table
CREATE TABLE IF NOT EXISTS public.payments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    session_id UUID REFERENCES public.sessions(id) ON DELETE CASCADE,
    patient_id UUID REFERENCES public.patients(id) ON DELETE SET NULL,
    amount NUMERIC NOT NULL,
    payment_method TEXT DEFAULT 'cash',
    reference_number TEXT,
    received_by UUID REFERENCES public.profiles(id),
    notes TEXT,
    is_refund BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 9. Notifications Table
CREATE TABLE IF NOT EXISTS public.notifications (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
    title TEXT NOT NULL,
    message TEXT NOT NULL,
    type TEXT DEFAULT 'general',
    reference_id UUID,
    is_read BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 10. Follow-ups Table
CREATE TABLE IF NOT EXISTS public.follow_ups (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    patient_id UUID REFERENCES public.patients(id) ON DELETE CASCADE NOT NULL,
    doctor_id UUID REFERENCES public.profiles(id),
    scheduled_date DATE NOT NULL,
    scheduled_time TIME,
    status TEXT DEFAULT 'pending',
    reminder_sent BOOLEAN DEFAULT FALSE,
    cancellation_reason TEXT,
    cancellation_approved BOOLEAN,
    assigned_to UUID REFERENCES public.profiles(id),
    call_attempts INTEGER DEFAULT 0,
    last_call_at TIMESTAMPTZ,
    call_outcome TEXT,
    call_notes TEXT,
    created_by UUID REFERENCES public.profiles(id),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 11. Activity Logs Table
CREATE TABLE IF NOT EXISTS public.activity_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    user_name TEXT,
    action TEXT NOT NULL,
    entity_type TEXT,
    entity_id UUID,
    old_values JSONB,
    new_values JSONB,
    details TEXT,
    ip_address TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ═══════════════════════════════════════════════════════════════════════════════
-- CUSTOM FIELDS SYSTEM
-- ═══════════════════════════════════════════════════════════════════════════════

-- 12. Custom Fields Definition
CREATE TABLE IF NOT EXISTS public.custom_fields (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL,
    field_key TEXT UNIQUE NOT NULL,
    field_type TEXT NOT NULL DEFAULT 'text',
    scope TEXT NOT NULL DEFAULT 'session',
    options JSONB,
    is_required BOOLEAN DEFAULT false,
    display_order INTEGER DEFAULT 0,
    is_active BOOLEAN DEFAULT true,
    department_id UUID REFERENCES public.departments(id),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 13. Custom Field Values
CREATE TABLE IF NOT EXISTS public.custom_field_values (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    field_id UUID NOT NULL REFERENCES public.custom_fields(id) ON DELETE CASCADE,
    patient_id UUID NOT NULL REFERENCES public.patients(id) ON DELETE CASCADE,
    session_id UUID REFERENCES public.sessions(id) ON DELETE CASCADE,
    value JSONB NOT NULL,
    created_by UUID REFERENCES public.profiles(id),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(field_id, patient_id, session_id)
);

-- ═══════════════════════════════════════════════════════════════════════════════
-- MESSAGE TEMPLATES
-- ═══════════════════════════════════════════════════════════════════════════════

-- 14. Message Templates
CREATE TABLE IF NOT EXISTS public.message_templates (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    template_type TEXT NOT NULL UNIQUE,
    template_name TEXT NOT NULL,
    template_content TEXT NOT NULL,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 15. Clinic Settings
CREATE TABLE IF NOT EXISTS public.clinic_settings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    setting_key TEXT NOT NULL UNIQUE,
    setting_value TEXT NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ═══════════════════════════════════════════════════════════════════════════════
-- INDEXES
-- ═══════════════════════════════════════════════════════════════════════════════

CREATE INDEX IF NOT EXISTS idx_sessions_patient_id ON public.sessions(patient_id);
CREATE INDEX IF NOT EXISTS idx_sessions_doctor_id ON public.sessions(doctor_id);
CREATE INDEX IF NOT EXISTS idx_sessions_start_time ON public.sessions(start_time);
CREATE INDEX IF NOT EXISTS idx_sessions_status ON public.sessions(status);
CREATE INDEX IF NOT EXISTS idx_sessions_department ON public.sessions(department_id);
CREATE INDEX IF NOT EXISTS idx_payments_session_id ON public.payments(session_id);
CREATE INDEX IF NOT EXISTS idx_activity_logs_user_id ON public.activity_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_patients_phone ON public.patients(phone);
CREATE INDEX IF NOT EXISTS idx_notifications_user ON public.notifications(user_id, is_read);
CREATE INDEX IF NOT EXISTS idx_follow_ups_status ON public.follow_ups(status, scheduled_date);
CREATE INDEX IF NOT EXISTS idx_custom_fields_scope ON public.custom_fields(scope);
CREATE INDEX IF NOT EXISTS idx_field_values_patient ON public.custom_field_values(patient_id);

-- ═══════════════════════════════════════════════════════════════════════════════
-- ROW LEVEL SECURITY
-- ═══════════════════════════════════════════════════════════════════════════════

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.patients ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.departments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.devices ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.services ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.activity_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.follow_ups ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.custom_fields ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.custom_field_values ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.message_templates ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.clinic_settings ENABLE ROW LEVEL SECURITY;

-- Allow all operations (for development - tighten for production)
CREATE POLICY "Allow all" ON public.profiles FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow all" ON public.patients FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow all" ON public.sessions FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow all" ON public.departments FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow all" ON public.devices FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow all" ON public.services FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow all" ON public.payments FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow all" ON public.activity_logs FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow all" ON public.notifications FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow all" ON public.follow_ups FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow all" ON public.custom_fields FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow all" ON public.custom_field_values FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow all" ON public.message_templates FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow all" ON public.clinic_settings FOR ALL USING (true) WITH CHECK (true);

-- ═══════════════════════════════════════════════════════════════════════════════
-- TRIGGERS
-- ═══════════════════════════════════════════════════════════════════════════════

-- Update patient stats on session completion
CREATE OR REPLACE FUNCTION update_patient_visit_stats()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.status = 'completed' AND (OLD.status IS NULL OR OLD.status != 'completed') THEN
        UPDATE public.patients 
        SET 
            last_visit_date = NEW.end_time,
            total_visits = total_visits + 1,
            updated_at = NOW()
        WHERE id = NEW.patient_id;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_update_patient_visits ON public.sessions;
CREATE TRIGGER trigger_update_patient_visits
    AFTER UPDATE ON public.sessions
    FOR EACH ROW
    EXECUTE FUNCTION update_patient_visit_stats();

-- Update session paid amount
CREATE OR REPLACE FUNCTION update_session_paid_amount()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE public.sessions 
    SET 
        paid_amount = COALESCE((
            SELECT SUM(CASE WHEN is_refund THEN -amount ELSE amount END) 
            FROM public.payments 
            WHERE session_id = NEW.session_id
        ), 0),
        updated_at = NOW()
    WHERE id = NEW.session_id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_update_session_paid ON public.payments;
CREATE TRIGGER trigger_update_session_paid
    AFTER INSERT OR UPDATE OR DELETE ON public.payments
    FOR EACH ROW
    EXECUTE FUNCTION update_session_paid_amount();

-- ═══════════════════════════════════════════════════════════════════════════════
-- SAMPLE DATA
-- ═══════════════════════════════════════════════════════════════════════════════

-- Departments
INSERT INTO public.departments (name, description, color_code) VALUES 
    ('جلدية', 'قسم الأمراض الجلدية', '#4CAF50'),
    ('ليزر', 'قسم علاجات الليزر', '#2196F3'),
    ('تجميل', 'قسم التجميل والعناية', '#E91E63'),
    ('حقن', 'قسم الحقن التجميلية', '#FF9800')
ON CONFLICT (name) DO NOTHING;

-- Devices
INSERT INTO public.devices (name, type, status, serial_number) VALUES 
    ('Candela GentleMax Pro', 'Laser', 'active', 'CAN-2024-001'),
    ('Cynosure Elite iQ', 'Laser', 'active', 'CYN-2024-002'),
    ('Diode Laser 808nm', 'Laser', 'active', 'DIO-2024-003'),
    ('IPL Machine', 'Light Therapy', 'maintenance', 'IPL-2023-001'),
    ('Fractional CO2', 'Laser', 'active', 'FCO-2024-001')
ON CONFLICT DO NOTHING;

-- Staff Profiles
INSERT INTO public.profiles (username, password, name, role, department, email, phone) VALUES 
    ('admin', 'admin123', 'مدير النظام', 'admin', NULL, 'admin@carepoint.local', '0551000001'),
    ('reception', 'admin123', 'موظف الاستقبال', 'reception', NULL, 'reception@carepoint.local', '0551000002'),
    ('callcenter', 'admin123', 'موظف الكول سنتر', 'call_center', NULL, 'callcenter@carepoint.local', '0551000003'),
    ('dr_ahmed', 'admin123', 'د. أحمد الجابري', 'doctor', 'ليزر', 'ahmed@carepoint.local', '0551000004'),
    ('dr_sara', 'admin123', 'د. سارة العلي', 'doctor', 'جلدية', 'sara@carepoint.local', '0551000005'),
    ('dr_omar', 'admin123', 'د. عمر حسن', 'doctor', 'تجميل', 'omar@carepoint.local', '0551000006')
ON CONFLICT (username) DO NOTHING;

-- Services
INSERT INTO public.services (name, name_ar, default_price, duration_minutes, description) VALUES 
    ('Alexandrite Laser', 'ليزر الكسندرايت', 150, 30, 'علاج ليزر للبشرة الفاتحة'),
    ('Yag Laser', 'ليزر ياغ', 200, 30, 'علاج ليزر للبشرة الداكنة'),
    ('Diode Laser', 'ليزر دايود', 100, 20, 'إزالة الشعر بالليزر'),
    ('Consultation', 'استشارة', 50, 15, 'استشارة طبية'),
    ('Botox', 'بوتوكس', 300, 45, 'حقن البوتوكس'),
    ('Filler', 'فيلر', 250, 30, 'حقن الفيلر'),
    ('Chemical Peel', 'تقشير كيميائي', 180, 40, 'تقشير البشرة'),
    ('Fractional CO2', 'ليزر فراكشنال', 350, 60, 'تجديد البشرة بالليزر'),
    ('PRP Treatment', 'علاج البلازما', 400, 45, 'حقن البلازما الغنية بالصفائح')
ON CONFLICT DO NOTHING;

-- Message Templates
INSERT INTO public.message_templates (template_type, template_name, template_content) VALUES
('reminder', 'تذكير بالموعد', '🏥 *{clinic_name}*

مرحباً {patient_name}،

نود تذكيركم بموعدكم:
📅 التاريخ: *{date}*
🕐 الوقت: *{time}*

نتطلع لرؤيتكم! 😊'),
('confirmation', 'تأكيد الحجز', '✅ *تأكيد الحجز*

مرحباً {patient_name}،

تم تأكيد حجزكم بنجاح:
📅 التاريخ: *{date}*
🕐 الوقت: *{time}*

شكراً لثقتكم بـ {clinic_name}'),
('cancellation', 'إلغاء الموعد', '❌ *إلغاء الموعد*

مرحباً {patient_name}،

نعتذر، تم إلغاء موعدكم يوم {date}.

للحجز مرة أخرى:
📞 {clinic_phone}'),
('thank_you', 'شكر بعد الزيارة', '🙏 *شكراً لزيارتكم*

{patient_name} العزيز،

شكراً لزيارتكم {clinic_name} اليوم.

نتمنى لكم الشفاء العاجل! 💚')
ON CONFLICT (template_type) DO NOTHING;

-- Clinic Settings
INSERT INTO public.clinic_settings (setting_key, setting_value) VALUES
('clinic_name', 'عيادة د. سجاد'),
('clinic_address', 'العراق - بغداد'),
('clinic_phone', '07801234567'),
('doctor_name', 'سجاد')
ON CONFLICT (setting_key) DO NOTHING;

-- Sample Custom Fields
INSERT INTO public.custom_fields (name, field_key, field_type, scope, options, is_required, display_order) VALUES
    ('نوع البشرة', 'skin_type', 'select', 'patient', '["دهنية", "جافة", "مختلطة", "عادية", "حساسة"]', true, 1),
    ('الحساسيات', 'allergies', 'text', 'patient', NULL, false, 2),
    ('الأمراض المزمنة', 'chronic_diseases', 'multiselect', 'patient', '["سكري", "ضغط", "قلب", "غدة درقية", "لا يوجد"]', false, 3),
    ('مستوى الألم قبل', 'pain_before', 'select', 'session', '["1", "2", "3", "4", "5", "6", "7", "8", "9", "10"]', false, 1),
    ('مستوى الألم بعد', 'pain_after', 'select', 'session', '["1", "2", "3", "4", "5", "6", "7", "8", "9", "10"]', false, 2),
    ('ملاحظات الجلسة', 'session_notes', 'text', 'session', NULL, false, 3)
ON CONFLICT (field_key) DO NOTHING;

-- ═══════════════════════════════════════════════════════════════════════════════
-- ENABLE REALTIME
-- ═══════════════════════════════════════════════════════════════════════════════

ALTER PUBLICATION supabase_realtime ADD TABLE sessions;
ALTER PUBLICATION supabase_realtime ADD TABLE notifications;
ALTER PUBLICATION supabase_realtime ADD TABLE follow_ups;

SELECT '✅ CarePoint Database Schema v4.0 installed successfully!' as result;
