import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme.dart';

class MessageTemplatesScreen extends StatefulWidget {
  const MessageTemplatesScreen({super.key});

  @override
  State<MessageTemplatesScreen> createState() => _MessageTemplatesScreenState();
}

class _MessageTemplatesScreenState extends State<MessageTemplatesScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _templates = [];
  Map<String, String> _clinicSettings = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      // تحميل القوالب
      final templates = await _supabase.from('message_templates').select().order('template_type');
      
      // تحميل إعدادات العيادة
      final settings = await _supabase.from('clinic_settings').select();
      
      setState(() {
        _templates = List<Map<String, dynamic>>.from(templates);
        _clinicSettings = {
          for (var s in settings) s['setting_key'] as String: s['setting_value'] as String
        };
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading data: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('📱 قوالب رسائل الواتساب'),
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // إعدادات العيادة
                  _buildSectionHeader('🏥 معلومات العيادة', Icons.settings),
                  _buildClinicSettingsCard(),
                  const SizedBox(height: 24),
                  
                  // القوالب المتاحة
                  _buildSectionHeader('📝 قوالب الرسائل', Icons.message),
                  const SizedBox(height: 8),
                  _buildVariablesHelper(),
                  const SizedBox(height: 16),
                  ..._templates.map((t) => _buildTemplateCard(t)),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.primary),
          const SizedBox(width: 8),
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildClinicSettingsCard() {
    return Card(
      color: AppTheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildSettingRow('clinic_name', 'اسم العيادة', Icons.business),
            const Divider(),
            _buildSettingRow('doctor_name', 'اسم الطبيب', Icons.person),
            const Divider(),
            _buildSettingRow('clinic_address', 'العنوان', Icons.location_on),
            const Divider(),
            _buildSettingRow('clinic_phone', 'رقم الهاتف', Icons.phone),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingRow(String key, String label, IconData icon) {
    return ListTile(
      leading: Icon(icon, color: Colors.white54),
      title: Text(label),
      subtitle: Text(_clinicSettings[key] ?? 'غير محدد', style: const TextStyle(color: Colors.white70)),
      trailing: IconButton(
        icon: const Icon(Icons.edit, color: AppTheme.primary),
        onPressed: () => _showEditSettingDialog(key, label),
      ),
    );
  }

  Widget _buildVariablesHelper() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.withAlpha(26),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.withAlpha(77)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue, size: 18),
              SizedBox(width: 8),
              Text('المتغيرات المتاحة:', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              _buildVariableChip('{patient_name}', 'اسم المريض'),
              _buildVariableChip('{date}', 'التاريخ'),
              _buildVariableChip('{time}', 'الوقت'),
              _buildVariableChip('{clinic_name}', 'اسم العيادة'),
              _buildVariableChip('{doctor_name}', 'اسم الطبيب'),
              _buildVariableChip('{clinic_address}', 'العنوان'),
              _buildVariableChip('{clinic_phone}', 'الهاتف'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVariableChip(String variable, String hint) {
    return Chip(
      label: Text(variable, style: const TextStyle(fontSize: 11)),
      backgroundColor: Colors.blue.withAlpha(51),
      padding: EdgeInsets.zero,
    );
  }

  Widget _buildTemplateCard(Map<String, dynamic> template) {
    final typeInfo = _getTemplateTypeInfo(template['template_type']);
    
    return Card(
      color: AppTheme.surface,
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            leading: CircleAvatar(
              backgroundColor: typeInfo['color'].withAlpha(51),
              child: Icon(typeInfo['icon'], color: typeInfo['color']),
            ),
            title: Text(template['template_name'] ?? ''),
            subtitle: Text(typeInfo['label'], style: TextStyle(color: typeInfo['color'])),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Switch(
                  value: template['is_active'] ?? true,
                  onChanged: (v) => _toggleTemplate(template['id'], v),
                  activeTrackColor: Colors.green,
                ),
                IconButton(
                  icon: const Icon(Icons.edit, color: AppTheme.primary),
                  onPressed: () => _showEditTemplateDialog(template),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                template['template_content'] ?? '',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Map<String, dynamic> _getTemplateTypeInfo(String type) {
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

  void _showEditSettingDialog(String key, String label) {
    final controller = TextEditingController(text: _clinicSettings[key] ?? '');
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('تعديل $label'),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await _supabase.from('clinic_settings').upsert({
                  'setting_key': key,
                  'setting_value': controller.text,
                  'updated_at': DateTime.now().toIso8601String(),
                }, onConflict: 'setting_key');
                _loadData();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('تم الحفظ'), backgroundColor: Colors.green),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  void _showEditTemplateDialog(Map<String, dynamic> template) {
    final nameController = TextEditingController(text: template['template_name']);
    final contentController = TextEditingController(text: template['template_content']);
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('تعديل قالب: ${template['template_name']}'),
        content: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'اسم القالب', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: contentController,
                decoration: const InputDecoration(labelText: 'محتوى الرسالة', border: OutlineInputBorder()),
                maxLines: 8,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await _supabase.from('message_templates').update({
                  'template_name': nameController.text,
                  'template_content': contentController.text,
                  'updated_at': DateTime.now().toIso8601String(),
                }).eq('id', template['id']);
                _loadData();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('تم حفظ القالب'), backgroundColor: Colors.green),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleTemplate(String id, bool value) async {
    try {
      await _supabase.from('message_templates').update({
        'is_active': value,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', id);
      _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}
