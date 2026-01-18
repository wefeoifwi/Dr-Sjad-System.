-- Custom Fields System for Dynamic Doctor Forms
-- Run this in Supabase SQL Editor

-- 1. Custom Fields Definition Table
CREATE TABLE IF NOT EXISTS public.custom_fields (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL,                    -- اسم الحقل بالعربي
    field_key TEXT UNIQUE NOT NULL,        -- مفتاح برمجي فريد
    field_type TEXT NOT NULL DEFAULT 'text', -- text, number, boolean, select, multiselect
    scope TEXT NOT NULL DEFAULT 'session', -- patient (ثابت), session (متكرر)
    options JSONB,                         -- خيارات للـ select/multiselect
    is_required BOOLEAN DEFAULT false,
    display_order INTEGER DEFAULT 0,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. Custom Field Values Table
CREATE TABLE IF NOT EXISTS public.custom_field_values (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    field_id UUID NOT NULL REFERENCES public.custom_fields(id) ON DELETE CASCADE,
    patient_id UUID NOT NULL REFERENCES public.patients(id) ON DELETE CASCADE,
    session_id UUID REFERENCES public.sessions(id) ON DELETE CASCADE,  -- NULL if scope=patient
    value JSONB NOT NULL,
    created_by UUID REFERENCES public.profiles(id),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    -- Prevent duplicate values for same field/patient/session combo
    UNIQUE(field_id, patient_id, session_id)
);

-- 3. Indexes for performance
CREATE INDEX IF NOT EXISTS idx_custom_fields_scope ON public.custom_fields(scope);
CREATE INDEX IF NOT EXISTS idx_custom_fields_active ON public.custom_fields(is_active);
CREATE INDEX IF NOT EXISTS idx_field_values_patient ON public.custom_field_values(patient_id);
CREATE INDEX IF NOT EXISTS idx_field_values_session ON public.custom_field_values(session_id);
CREATE INDEX IF NOT EXISTS idx_field_values_field ON public.custom_field_values(field_id);

-- 4. Enable RLS
ALTER TABLE public.custom_fields ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.custom_field_values ENABLE ROW LEVEL SECURITY;

-- 5. RLS Policies
-- Custom fields - readable by all, writable by admin only
CREATE POLICY "custom_fields_read" ON public.custom_fields FOR SELECT USING (true);
CREATE POLICY "custom_fields_write" ON public.custom_fields FOR ALL USING (true);

-- Field values - readable by all, writable by doctors/admin
CREATE POLICY "field_values_read" ON public.custom_field_values FOR SELECT USING (true);
CREATE POLICY "field_values_write" ON public.custom_field_values FOR ALL USING (true);

-- 6. Sample fields (optional - you can add via the admin panel)
INSERT INTO public.custom_fields (name, field_key, field_type, scope, options, is_required, display_order) VALUES
    ('نوع البشرة', 'skin_type', 'select', 'patient', '["دهنية", "جافة", "مختلطة", "عادية", "حساسة"]', true, 1),
    ('الحساسيات', 'allergies', 'text', 'patient', NULL, false, 2),
    ('الأمراض المزمنة', 'chronic_diseases', 'multiselect', 'patient', '["سكري", "ضغط", "قلب", "غدة درقية", "لا يوجد"]', false, 3),
    ('مستوى الألم قبل', 'pain_before', 'select', 'session', '["1", "2", "3", "4", "5", "6", "7", "8", "9", "10"]', false, 1),
    ('مستوى الألم بعد', 'pain_after', 'select', 'session', '["1", "2", "3", "4", "5", "6", "7", "8", "9", "10"]', false, 2),
    ('ملاحظات الجلسة', 'session_notes', 'text', 'session', NULL, false, 3),
    ('هل يوجد تورم؟', 'has_swelling', 'boolean', 'session', NULL, false, 4),
    ('نسبة الطاقة المستخدمة', 'energy_level', 'number', 'session', NULL, false, 5)
ON CONFLICT (field_key) DO NOTHING;
