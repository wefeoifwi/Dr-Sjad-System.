import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/theme.dart';

class DataExportScreen extends StatefulWidget {
  const DataExportScreen({super.key});

  @override
  State<DataExportScreen> createState() => _DataExportScreenState();
}

class _DataExportScreenState extends State<DataExportScreen> {
  bool _isExporting = false;
  String _statusMessage = '';
  
  // Export options
  bool _exportPatients = true;
  bool _exportSessions = true;
  bool _exportFollowUps = false;
  bool _exportPayments = false;

  Future<void> _startExport() async {
    setState(() {
      _isExporting = true;
      _statusMessage = 'جاري تجهيز البيانات...';
    });

    try {
      final excel = Excel.createExcel();
      final supabase = Supabase.instance.client;

      // Export Patients
      if (_exportPatients) {
        setState(() => _statusMessage = 'جاري تصدير المرضى...');
        final patients = await supabase.from('patients').select();
        
        final sheet = excel['المرضى'];
        // Headers
        sheet.appendRow([
          TextCellValue('الاسم'),
          TextCellValue('الهاتف'),
          TextCellValue('الجنس'),
          TextCellValue('العمر'),
          TextCellValue('نوع البشرة'),
          TextCellValue('التاريخ الطبي'),
          TextCellValue('تاريخ التسجيل'),
        ]);
        
        for (final p in patients) {
          sheet.appendRow([
            TextCellValue(p['name']?.toString() ?? ''),
            TextCellValue(p['phone']?.toString() ?? ''),
            TextCellValue(p['gender']?.toString() ?? ''),
            TextCellValue(p['age']?.toString() ?? ''),
            TextCellValue(p['skin_type']?.toString() ?? ''),
            TextCellValue(p['medical_history']?.toString() ?? ''),
            TextCellValue(p['created_at']?.toString() ?? ''),
          ]);
        }
      }

      // Export Sessions
      if (_exportSessions) {
        setState(() => _statusMessage = 'جاري تصدير الجلسات...');
        final sessions = await supabase.from('sessions').select('''
          *,
          patient:patients(name),
          doctor:profiles(name)
        ''');
        
        final sheet = excel['الجلسات'];
        // Headers
        sheet.appendRow([
          TextCellValue('اسم المريض'),
          TextCellValue('الطبيب'),
          TextCellValue('التاريخ'),
          TextCellValue('الوقت'),
          TextCellValue('نوع الخدمة'),
          TextCellValue('السعر'),
          TextCellValue('الحالة'),
          TextCellValue('الملاحظات'),
          TextCellValue('الحقول الديناميكية'),
        ]);
        
        for (final s in sessions) {
          final date = DateTime.tryParse(s['start_time']?.toString() ?? '');
          sheet.appendRow([
            TextCellValue(s['patient']?['name']?.toString() ?? ''),
            TextCellValue(s['doctor']?['name']?.toString() ?? ''),
            TextCellValue(date != null ? '${date.year}-${date.month}-${date.day}' : ''),
            TextCellValue(date != null ? '${date.hour}:${date.minute.toString().padLeft(2, '0')}' : ''),
            TextCellValue(s['service_type']?.toString() ?? ''),
            TextCellValue(s['price']?.toString() ?? '0'),
            TextCellValue(s['status']?.toString() ?? ''),
            TextCellValue(s['notes']?.toString() ?? ''),
            TextCellValue(s['dynamic_fields']?.toString() ?? ''),
          ]);
        }
      }

      // Export Follow-ups
      if (_exportFollowUps) {
        setState(() => _statusMessage = 'جاري تصدير المتابعات...');
        final followUps = await supabase.from('follow_ups').select('''
          *,
          patient:patients(name)
        ''');
        
        final sheet = excel['المتابعات'];
        sheet.appendRow([
          TextCellValue('اسم المريض'),
          TextCellValue('تاريخ المتابعة'),
          TextCellValue('الحالة'),
          TextCellValue('الملاحظات'),
        ]);
        
        for (final f in followUps) {
          sheet.appendRow([
            TextCellValue(f['patient']?['name']?.toString() ?? ''),
            TextCellValue(f['follow_up_date']?.toString() ?? ''),
            TextCellValue(f['status']?.toString() ?? ''),
            TextCellValue(f['notes']?.toString() ?? ''),
          ]);
        }
      }

      // Export Payments
      if (_exportPayments) {
        setState(() => _statusMessage = 'جاري تصدير المدفوعات...');
        final payments = await supabase.from('payments').select('''
          *,
          session:sessions(patient:patients(name))
        ''');
        
        final sheet = excel['المدفوعات'];
        sheet.appendRow([
          TextCellValue('اسم المريض'),
          TextCellValue('المبلغ'),
          TextCellValue('طريقة الدفع'),
          TextCellValue('التاريخ'),
        ]);
        
        for (final p in payments) {
          sheet.appendRow([
            TextCellValue(p['session']?['patient']?['name']?.toString() ?? ''),
            TextCellValue(p['amount']?.toString() ?? '0'),
            TextCellValue(p['payment_method']?.toString() ?? ''),
            TextCellValue(p['created_at']?.toString() ?? ''),
          ]);
        }
      }

      // Remove default sheet
      excel.delete('Sheet1');

      // Generate file
      setState(() => _statusMessage = 'جاري إنشاء الملف...');
      final bytes = excel.encode();
      
      if (bytes != null) {
        final fileName = 'clinic_data_${DateTime.now().millisecondsSinceEpoch}.xlsx';
        
        if (kIsWeb) {
          // Web: Use download workaround
          setState(() => _statusMessage = '⚠️ التصدير على الويب: استخدم الطباعة أو لقطة الشاشة');
        } else {
          // Mobile/Desktop: Save to file and share
          final directory = await getApplicationDocumentsDirectory();
          final filePath = '${directory.path}/$fileName';
          final file = File(filePath);
          await file.writeAsBytes(bytes);
          
          // Share or show path
          if (Platform.isAndroid || Platform.isIOS) {
            await Share.shareXFiles([XFile(filePath)], text: 'بيانات العيادة');
            setState(() => _statusMessage = '✅ تم التصدير بنجاح!');
          } else {
            // Desktop
            setState(() => _statusMessage = '✅ تم حفظ الملف في:\n$filePath');
          }
        }
      }
    } catch (e) {
      setState(() => _statusMessage = '❌ خطأ: $e');
    }

    setState(() => _isExporting = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('تصدير بيانات Excel'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Options
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('📊 اختر البيانات للتصدير:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 16),
                  _buildCheckbox('المرضى', _exportPatients, (v) => setState(() => _exportPatients = v!)),
                  _buildCheckbox('الجلسات', _exportSessions, (v) => setState(() => _exportSessions = v!)),
                  _buildCheckbox('المتابعات', _exportFollowUps, (v) => setState(() => _exportFollowUps = v!)),
                  _buildCheckbox('المدفوعات', _exportPayments, (v) => setState(() => _exportPayments = v!)),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Export Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                onPressed: _isExporting ? null : _startExport,
                icon: _isExporting 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.download),
                label: Text(_isExporting ? 'جاري التصدير...' : '📥 تصدير إلى Excel'),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Status
            if (_statusMessage.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _statusMessage.contains('✅') ? Colors.green.withAlpha(26) : 
                         _statusMessage.contains('❌') ? Colors.red.withAlpha(26) : 
                         AppTheme.primary.withAlpha(26),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    if (_statusMessage.contains('✅'))
                      const Icon(Icons.check_circle, color: Colors.green, size: 20)
                    else if (_statusMessage.contains('❌'))
                      const Icon(Icons.error, color: Colors.red, size: 20)
                    else
                      const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                    const SizedBox(width: 12),
                    Expanded(child: Text(_statusMessage)),
                  ],
                ),
              ),
            
            const SizedBox(height: 24),
            
            // Info
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.withAlpha(26),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info, color: Colors.blue),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'سيتم تنزيل ملف Excel يحتوي على البيانات المحددة.\nكل جدول سيكون في ورقة عمل منفصلة.',
                      style: TextStyle(color: Colors.blue),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCheckbox(String label, bool value, ValueChanged<bool?> onChanged) {
    return CheckboxListTile(
      title: Text(label),
      value: value,
      onChanged: onChanged,
      controlAffinity: ListTileControlAffinity.leading,
      activeColor: AppTheme.primary,
    );
  }
}
