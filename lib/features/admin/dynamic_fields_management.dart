import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme.dart';

class DynamicFieldsManagementScreen extends StatefulWidget {
  const DynamicFieldsManagementScreen({super.key});

  @override
  State<DynamicFieldsManagementScreen> createState() => _DynamicFieldsManagementScreenState();
}

class _DynamicFieldsManagementScreenState extends State<DynamicFieldsManagementScreen> {
  List<Map<String, dynamic>> _fields = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadFields();
  }

  Future<void> _loadFields() async {
    setState(() => _isLoading = true);
    try {
      final data = await Supabase.instance.client
          .from('dynamic_field_definitions')
          .select()
          .order('display_order');
      
      setState(() {
        _fields = List<Map<String, dynamic>>.from(data);
        _isLoading = false;
        _error = null;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = 'خطأ في تحميل البيانات: $e\n\nتأكد من تنفيذ setup_dynamic_fields.sql في Supabase';
      });
    }
  }

  Future<void> _deleteField(String id) async {
    try {
      await Supabase.instance.client
          .from('dynamic_field_definitions')
          .delete()
          .eq('id', id);
      _loadFields();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ تم الحذف')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ خطأ: $e')),
        );
      }
    }
  }

  void _showAddEditDialog([Map<String, dynamic>? existing]) {
    final nameController = TextEditingController(text: existing?['label_ar'] ?? '');
    final keyController = TextEditingController(text: existing?['name'] ?? '');
    String fieldType = existing?['field_type'] ?? 'text';
    String scope = existing?['scope'] ?? 'session';
    final optionsController = TextEditingController(
      text: (existing?['options'] as List?)?.join(', ') ?? '',
    );
    bool isRequired = existing?['is_required'] ?? false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppTheme.surface,
          title: Text(existing == null ? '➕ إضافة حقل جديد' : '✏️ تعديل الحقل'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'اسم الحقل (عربي)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: keyController,
                  decoration: const InputDecoration(
                    labelText: 'المفتاح (إنجليزي)',
                    hintText: 'skin_type',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: fieldType,
                  decoration: const InputDecoration(
                    labelText: 'نوع الحقل',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'text', child: Text('نص')),
                    DropdownMenuItem(value: 'number', child: Text('رقم')),
                    DropdownMenuItem(value: 'boolean', child: Text('نعم/لا')),
                    DropdownMenuItem(value: 'select', child: Text('قائمة اختيار')),
                    DropdownMenuItem(value: 'date', child: Text('تاريخ')),
                  ],
                  onChanged: (v) => setDialogState(() => fieldType = v!),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: scope,
                  decoration: const InputDecoration(
                    labelText: 'النطاق',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'session', child: Text('الجلسة')),
                    DropdownMenuItem(value: 'patient', child: Text('المريض')),
                  ],
                  onChanged: (v) => setDialogState(() => scope = v!),
                ),
                if (fieldType == 'select') ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: optionsController,
                    decoration: const InputDecoration(
                      labelText: 'الخيارات (مفصولة بفاصلة)',
                      hintText: 'I, II, III, IV, V, VI',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                CheckboxListTile(
                  title: const Text('حقل مطلوب'),
                  value: isRequired,
                  onChanged: (v) => setDialogState(() => isRequired = v!),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
              onPressed: () async {
                if (nameController.text.isEmpty || keyController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('يرجى ملء جميع الحقول')),
                  );
                  return;
                }

                final data = {
                  'name': keyController.text,
                  'label_ar': nameController.text,
                  'field_type': fieldType,
                  'scope': scope,
                  'is_required': isRequired,
                  'options': fieldType == 'select'
                      ? optionsController.text.split(',').map((e) => e.trim()).toList()
                      : null,
                };

                try {
                  if (existing == null) {
                    await Supabase.instance.client
                        .from('dynamic_field_definitions')
                        .insert(data);
                  } else {
                    await Supabase.instance.client
                        .from('dynamic_field_definitions')
                        .update(data)
                        .eq('id', existing['id']);
                  }
                  if (mounted) Navigator.pop(ctx);
                  _loadFields();
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('❌ خطأ: $e')),
                    );
                  }
                }
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('إدارة الحقول الديناميكية'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadFields,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.primary,
        onPressed: () => _showAddEditDialog(),
        icon: const Icon(Icons.add),
        label: const Text('إضافة حقل'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline, size: 64, color: Colors.red),
                        const SizedBox(height: 16),
                        Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: _loadFields,
                          icon: const Icon(Icons.refresh),
                          label: const Text('إعادة المحاولة'),
                        ),
                      ],
                    ),
                  ),
                )
              : _fields.isEmpty
                  ? const Center(
                      child: Text('لا توجد حقول. اضغط على زر الإضافة لإنشاء حقل جديد.'),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _fields.length,
                      itemBuilder: (context, index) {
                        final field = _fields[index];
                        return Card(
                          color: AppTheme.surface,
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: Icon(_getFieldIcon(field['field_type']), color: AppTheme.primary),
                            title: Text(field['label_ar'] ?? ''),
                            subtitle: Text(
                              '${field['name']} • ${_getScopeLabel(field['scope'])} • ${_getTypeLabel(field['field_type'])}',
                              style: const TextStyle(color: Colors.white54),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (field['is_required'] == true)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.withAlpha(51),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text('مطلوب', style: TextStyle(color: Colors.orange, fontSize: 12)),
                                  ),
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: const Icon(Icons.edit, color: Colors.white54),
                                  onPressed: () => _showAddEditDialog(field),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  onPressed: () => showDialog(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: const Text('تأكيد الحذف'),
                                      content: Text('هل تريد حذف "${field['label_ar']}"؟'),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(ctx),
                                          child: const Text('إلغاء'),
                                        ),
                                        ElevatedButton(
                                          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                          onPressed: () {
                                            Navigator.pop(ctx);
                                            _deleteField(field['id']);
                                          },
                                          child: const Text('حذف'),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
    );
  }

  IconData _getFieldIcon(String? type) {
    switch (type) {
      case 'text': return Icons.text_fields;
      case 'number': return Icons.numbers;
      case 'boolean': return Icons.toggle_on;
      case 'select': return Icons.list;
      case 'date': return Icons.calendar_today;
      default: return Icons.input;
    }
  }

  String _getScopeLabel(String? scope) {
    switch (scope) {
      case 'session': return 'جلسة';
      case 'patient': return 'مريض';
      default: return scope ?? '';
    }
  }

  String _getTypeLabel(String? type) {
    switch (type) {
      case 'text': return 'نص';
      case 'number': return 'رقم';
      case 'boolean': return 'نعم/لا';
      case 'select': return 'قائمة';
      case 'date': return 'تاريخ';
      default: return type ?? '';
    }
  }
}
