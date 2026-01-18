import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'theme.dart';

/// Helper class for WhatsApp messaging with templates
class WhatsAppHelper {
  static final _supabase = Supabase.instance.client;

  /// Show contact options bottom sheet (call + WhatsApp templates)
  static Future<void> showContactOptions({
    required BuildContext context,
    required String phone,
    required String patientName,
    String? date,
    String? time,
    String userRole = 'employee',
  }) async {
    // Only allow admin, call_center, reception
    if (!['admin', 'call_center', 'reception'].contains(userRole)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('غير مسموح لك باستخدام هذه الميزة'), backgroundColor: Colors.red),
      );
      return;
    }

    // Load templates and settings
    List<Map<String, dynamic>> templates = [];
    Map<String, String> settings = {};

    try {
      final templatesData = await _supabase
          .from('message_templates')
          .select()
          .eq('is_active', true);
      templates = List<Map<String, dynamic>>.from(templatesData);

      final settingsData = await _supabase.from('clinic_settings').select();
      for (var s in settingsData) {
        settings[s['setting_key'] as String] = s['setting_value'] as String;
      }
    } catch (e) {
      debugPrint('Error loading templates: $e');
    }

    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      isScrollControlled: true, // Allow larger content
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Text(
                'التواصل مع $patientName',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            const SizedBox(height: 16),

            // Phone call
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Colors.blue,
                child: Icon(Icons.phone, color: Colors.white),
              ),
              title: const Text('اتصال هاتفي'),
              subtitle: Text(phone),
              onTap: () {
                Navigator.pop(ctx);
                _makePhoneCall(context, phone);
              },
            ),

            const Divider(),
            const Text(
              '📱 رسائل واتساب',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
            ),
            const SizedBox(height: 8),

            // WhatsApp templates - Scrollable
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: templates.map((t) => _buildTemplateOption(
                    ctx: ctx,
                    context: context,
                    template: t,
                    phone: phone,
                    patientName: patientName,
                    date: date ?? '',
                    time: time ?? '',
                    settings: settings,
                  )).toList(),
                ),
              ),
            ),

            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  static Widget _buildTemplateOption({
    required BuildContext ctx,
    required BuildContext context,
    required Map<String, dynamic> template,
    required String phone,
    required String patientName,
    required String date,
    required String time,
    required Map<String, String> settings,
  }) {
    final typeInfo = _getTemplateTypeInfo(template['template_type']);

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: (typeInfo['color'] as Color).withAlpha(51),
        child: Icon(typeInfo['icon'], color: typeInfo['color'], size: 20),
      ),
      title: Text(template['template_name'] ?? ''),
      subtitle: Text(
        typeInfo['label'],
        style: TextStyle(color: typeInfo['color'], fontSize: 11),
      ),
      onTap: () {
        Navigator.pop(ctx);
        sendTemplateMessage(
          context: context,
          phone: phone,
          template: template['template_content'],
          patientName: patientName,
          date: date,
          time: time,
          settings: settings,
        );
      },
    );
  }

  static Map<String, dynamic> _getTemplateTypeInfo(String type) {
    switch (type) {
      case 'reminder':
        return {'label': 'تذكير بالموعد', 'color': Colors.orange, 'icon': Icons.alarm};
      case 'confirmation':
        return {'label': 'تأكيد الحجز', 'color': Colors.green, 'icon': Icons.check_circle};
      case 'cancellation':
        return {'label': 'إلغاء الموعد', 'color': Colors.red, 'icon': Icons.cancel};
      case 'thank_you':
        return {'label': 'شكر بعد الزيارة', 'color': Colors.purple, 'icon': Icons.favorite};
      default:
        return {'label': type, 'color': Colors.grey, 'icon': Icons.message};
    }
  }

  /// Make phone call
  static Future<void> _makePhoneCall(BuildContext context, String phone) async {
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا يوجد رقم هاتف'), backgroundColor: Colors.red),
      );
      return;
    }

    final cleanPhone = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    final Uri phoneUri = Uri(scheme: 'tel', path: cleanPhone);

    if (await canLaunchUrl(phoneUri)) {
      await launchUrl(phoneUri);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر الاتصال بـ $phone'), backgroundColor: Colors.red),
        );
      }
    }
  }

  /// Send template message via WhatsApp
  static Future<void> sendTemplateMessage({
    required BuildContext context,
    required String phone,
    required String template,
    required String patientName,
    required String date,
    required String time,
    required Map<String, String> settings,
  }) async {
    // Replace variables
    String message = template
        .replaceAll('{patient_name}', patientName)
        .replaceAll('{date}', date)
        .replaceAll('{time}', time.isNotEmpty ? time : '---')
        .replaceAll('{clinic_name}', settings['clinic_name'] ?? 'العيادة')
        .replaceAll('{doctor_name}', settings['doctor_name'] ?? '')
        .replaceAll('{clinic_address}', settings['clinic_address'] ?? '')
        .replaceAll('{clinic_phone}', settings['clinic_phone'] ?? '');

    await openWhatsApp(context: context, phone: phone, message: message);
  }

  /// Open WhatsApp with message
  static Future<void> openWhatsApp({
    required BuildContext context,
    required String phone,
    required String message,
  }) async {
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا يوجد رقم هاتف'), backgroundColor: Colors.red),
      );
      return;
    }

    // Clean and convert to international format
    String cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanPhone.startsWith('0')) {
      cleanPhone = '964${cleanPhone.substring(1)}';
    } else if (!cleanPhone.startsWith('964')) {
      cleanPhone = '964$cleanPhone';
    }

    final url = 'https://wa.me/$cleanPhone?text=${Uri.encodeComponent(message)}';

    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر فتح واتساب'), backgroundColor: Colors.red),
        );
      }
    }
  }

  /// Quick send confirmation after booking
  static Future<void> sendBookingConfirmation({
    required BuildContext context,
    required String phone,
    required String patientName,
    required String date,
    required String time,
  }) async {
    try {
      // Load settings
      final settingsData = await _supabase.from('clinic_settings').select();
      Map<String, String> settings = {};
      for (var s in settingsData) {
        settings[s['setting_key'] as String] = s['setting_value'] as String;
      }

      // Load confirmation template
      final templates = await _supabase
          .from('message_templates')
          .select()
          .eq('template_type', 'confirmation')
          .eq('is_active', true)
          .limit(1);

      if (templates.isNotEmpty) {
        await sendTemplateMessage(
          context: context,
          phone: phone,
          template: templates[0]['template_content'],
          patientName: patientName,
          date: date,
          time: time,
          settings: settings,
        );
      }
    } catch (e) {
      debugPrint('Error sending confirmation: $e');
    }
  }
}
