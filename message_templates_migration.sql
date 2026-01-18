-- قوالب رسائل الواتساب
CREATE TABLE IF NOT EXISTS message_templates (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    template_type TEXT NOT NULL UNIQUE, -- reminder, confirmation, cancellation, thank_you
    template_name TEXT NOT NULL,
    template_content TEXT NOT NULL,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- إعدادات العيادة
CREATE TABLE IF NOT EXISTS clinic_settings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    setting_key TEXT NOT NULL UNIQUE,
    setting_value TEXT NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- تفعيل RLS
ALTER TABLE message_templates ENABLE ROW LEVEL SECURITY;
ALTER TABLE clinic_settings ENABLE ROW LEVEL SECURITY;

-- سياسات القراءة للجميع
CREATE POLICY "Anyone can read templates" ON message_templates FOR SELECT USING (true);
CREATE POLICY "Anyone can read settings" ON clinic_settings FOR SELECT USING (true);

-- سياسات الكتابة للأدمن فقط
CREATE POLICY "Admin can manage templates" ON message_templates FOR ALL USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
);
CREATE POLICY "Admin can manage settings" ON clinic_settings FOR ALL USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
);

-- إدخال القوالب الافتراضية
INSERT INTO message_templates (template_type, template_name, template_content) VALUES
('reminder', 'تذكير بالموعد', '🏥 *{clinic_name}*

مرحباً {patient_name}،

نود تذكيركم بموعدكم:
📅 التاريخ: *{date}*
🕐 الوقت: *{time}*
👨‍⚕️ الطبيب: د. {doctor_name}

📍 العنوان: {clinic_address}

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

نتمنى لكم الشفاء العاجل! 💚

للمتابعة: {clinic_phone}')
ON CONFLICT (template_type) DO NOTHING;

-- إدخال إعدادات العيادة الافتراضية
INSERT INTO clinic_settings (setting_key, setting_value) VALUES
('clinic_name', 'عيادة د. سجاد'),
('clinic_address', 'العراق - بغداد'),
('clinic_phone', '07801234567'),
('doctor_name', 'سجاد')
ON CONFLICT (setting_key) DO NOTHING;
