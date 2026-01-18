// run_migration.dart
// تشغيل: dart run run_migration.dart

import 'package:supabase/supabase.dart';

void main() async {
  final supabase = SupabaseClient(
    'https://cdsueamzjwoidfjdlaiw.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImNkc3VlYW16andvaWRmamRsYWl3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjgwOTA0OTEsImV4cCI6MjA4MzY2NjQ5MX0.aQ-33I19lIB3dGM-StY6wxzplm14FbxLt833s74GSZI',
  );

  print('🔄 تشغيل التحديثات على قاعدة البيانات...\n');

  // Migration 1: Call Tracking Fields
  try {
    await supabase.rpc('exec_sql', params: {
      'sql': '''
        ALTER TABLE follow_ups ADD COLUMN IF NOT EXISTS call_attempts INTEGER DEFAULT 0;
        ALTER TABLE follow_ups ADD COLUMN IF NOT EXISTS last_call_at TIMESTAMPTZ;
        ALTER TABLE follow_ups ADD COLUMN IF NOT EXISTS call_outcome TEXT;
        ALTER TABLE follow_ups ADD COLUMN IF NOT EXISTS call_notes TEXT;
      '''
    });
    print('✅ تم إضافة حقول تتبع الاتصال');
  } catch (e) {
    print('⚠️ حقول تتبع الاتصال: $e');
  }

  // Migration 2: Department Custom Fields
  try {
    await supabase.rpc('exec_sql', params: {
      'sql': 'ALTER TABLE dynamic_field_definitions ADD COLUMN IF NOT EXISTS department_id UUID REFERENCES departments(id);'
    });
    print('✅ تم إضافة حقل القسم للحقول المخصصة');
  } catch (e) {
    print('⚠️ حقل القسم: $e');
  }

  print('\n✅ تم الانتهاء!');
  
  supabase.dispose();
}
