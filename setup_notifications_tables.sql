-- ============================================
-- CarePoint v3.0 - جداول الإشعارات والمتابعة
-- شغّل هذا الملف في Supabase SQL Editor
-- ============================================

-- 1. جدول الإشعارات
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

CREATE INDEX IF NOT EXISTS idx_notifications_user ON public.notifications(user_id, is_read);

-- 2. جدول المتابعة
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
    created_by UUID REFERENCES public.profiles(id),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_follow_ups_status ON public.follow_ups(status, scheduled_date);

-- 3. جدول سجل النشاط
CREATE TABLE IF NOT EXISTS public.activity_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES public.profiles(id),
    action TEXT NOT NULL,
    details TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 4. إضافة عمود is_active للموظفين (إذا لم يكن موجوداً)
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'profiles' AND column_name = 'is_active') THEN
        ALTER TABLE public.profiles ADD COLUMN is_active BOOLEAN DEFAULT TRUE;
    END IF;
END $$;

-- 5. RLS Policies للإشعارات
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own notifications" ON public.notifications
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Authenticated users can insert notifications" ON public.notifications
    FOR INSERT WITH CHECK (true);

CREATE POLICY "Users can update own notifications" ON public.notifications
    FOR UPDATE USING (auth.uid() = user_id);

-- 6. RLS Policies للمتابعة
ALTER TABLE public.follow_ups ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Authenticated users can view follow_ups" ON public.follow_ups
    FOR SELECT USING (true);

CREATE POLICY "Authenticated users can insert follow_ups" ON public.follow_ups
    FOR INSERT WITH CHECK (true);

CREATE POLICY "Authenticated users can update follow_ups" ON public.follow_ups
    FOR UPDATE USING (true);

-- تم بنجاح!
SELECT 'تم إنشاء جداول الإشعارات والمتابعة وسجل النشاط بنجاح! ✅' as result;
