-- CarePoint Database Schema for Supabase (Enhanced Version)
-- Run this SQL in your Supabase SQL Editor (supabase.com/dashboard/project/_/sql)
-- Version: 2.0 - Added payments, activity_logs, and enhanced patient fields

-- 1. Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 2. Profiles Table (Staff: Doctors, Employees, Admin)
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    username TEXT UNIQUE NOT NULL,
    password TEXT DEFAULT 'admin123',
    email TEXT,
    name TEXT NOT NULL,
    role TEXT NOT NULL DEFAULT 'employee', -- 'doctor', 'admin', 'reception', 'call_center', 'employee'
    phone TEXT,
    department TEXT,
    avatar_url TEXT,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 3. Patients Table (Enhanced with medical fields)
CREATE TABLE IF NOT EXISTS public.patients (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL,
    phone TEXT,
    age INTEGER,
    address TEXT,
    notes TEXT,
    gender TEXT DEFAULT 'female',
    source TEXT DEFAULT 'walk_in', -- 'walk_in', 'referral', 'social_media', 'call_center'
    -- NEW: Medical fields
    skin_type TEXT DEFAULT 'III', -- Fitzpatrick scale: I, II, III, IV, V, VI
    medical_history TEXT,
    allergies TEXT,
    blood_type TEXT,
    emergency_contact TEXT,
    emergency_phone TEXT,
    last_visit_date TIMESTAMPTZ,
    total_visits INTEGER DEFAULT 0,
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
    status TEXT DEFAULT 'active', -- 'active', 'maintenance', 'inactive'
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
    start_time TIMESTAMPTZ NOT NULL,
    end_time TIMESTAMPTZ,
    service_type TEXT,
    status TEXT DEFAULT 'scheduled', -- 'scheduled', 'booked', 'arrived', 'in_session', 'completed', 'cancelled', 'no_show', 'cancellation_pending'
    price NUMERIC DEFAULT 0,
    paid_amount NUMERIC DEFAULT 0,
    notes TEXT,
    cancel_reason TEXT,
    postpone_reason TEXT,
    medical_notes JSONB,
    room TEXT,
    session_number INTEGER DEFAULT 1,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID REFERENCES public.profiles(id),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 8. NEW: Payments Table (Track individual payments)
CREATE TABLE IF NOT EXISTS public.payments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    session_id UUID REFERENCES public.sessions(id) ON DELETE CASCADE,
    patient_id UUID REFERENCES public.patients(id) ON DELETE SET NULL,
    amount NUMERIC NOT NULL,
    payment_method TEXT DEFAULT 'cash', -- 'cash', 'card', 'transfer', 'insurance'
    reference_number TEXT,
    received_by UUID REFERENCES public.profiles(id),
    notes TEXT,
    is_refund BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 9. NEW: Activity Logs Table (Audit trail)
CREATE TABLE IF NOT EXISTS public.activity_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    user_name TEXT,
    action TEXT NOT NULL, -- 'login', 'logout', 'create', 'update', 'delete', 'cancel_booking', 'approve_cancellation'
    entity_type TEXT, -- 'session', 'patient', 'profile', 'payment', 'device', 'service'
    entity_id UUID,
    old_values JSONB,
    new_values JSONB,
    details TEXT,
    ip_address TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 10. Row Level Security
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.patients ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.departments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.devices ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.services ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.activity_logs ENABLE ROW LEVEL SECURITY;

-- Allow all operations for development (Update for production!)
CREATE POLICY "Allow all" ON public.profiles FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow all" ON public.patients FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow all" ON public.sessions FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow all" ON public.departments FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow all" ON public.devices FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow all" ON public.services FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow all" ON public.payments FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow all" ON public.activity_logs FOR ALL USING (true) WITH CHECK (true);

-- 11. Indexes for performance
CREATE INDEX IF NOT EXISTS idx_sessions_patient_id ON public.sessions(patient_id);
CREATE INDEX IF NOT EXISTS idx_sessions_doctor_id ON public.sessions(doctor_id);
CREATE INDEX IF NOT EXISTS idx_sessions_start_time ON public.sessions(start_time);
CREATE INDEX IF NOT EXISTS idx_sessions_status ON public.sessions(status);
CREATE INDEX IF NOT EXISTS idx_payments_session_id ON public.payments(session_id);
CREATE INDEX IF NOT EXISTS idx_activity_logs_user_id ON public.activity_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_activity_logs_entity_type ON public.activity_logs(entity_type);
CREATE INDEX IF NOT EXISTS idx_patients_phone ON public.patients(phone);

-- 12. Trigger to update patient's last_visit_date and total_visits
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

-- 13. Trigger to update session paid_amount when payment is made
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

-- =====================================================
-- SAMPLE DATA
-- =====================================================

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

-- Services (with department links)
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

-- Sample Patients (with enhanced fields)
INSERT INTO public.patients (name, phone, age, gender, source, skin_type, medical_history) VALUES 
    ('فاطمة أحمد', '0551234567', 28, 'female', 'social_media', 'III', 'لا يوجد تاريخ مرضي'),
    ('نورة محمد', '0559876543', 35, 'female', 'referral', 'IV', 'حساسية خفيفة'),
    ('سلمى خالد', '0553456789', 24, 'female', 'walk_in', 'II', NULL),
    ('هند عبدالله', '0557654321', 42, 'female', 'call_center', 'III', 'سكري نوع 2'),
    ('ريم سعد', '0552345678', 31, 'female', 'social_media', 'III', NULL)
ON CONFLICT DO NOTHING;

SELECT 'CarePoint Enhanced Database Schema created successfully! (v2.0)' as result;
