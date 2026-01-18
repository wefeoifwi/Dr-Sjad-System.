import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme.dart';

class CustomFieldsScreen extends StatefulWidget {
  const CustomFieldsScreen({super.key});

  @override
  State<CustomFieldsScreen> createState() => _CustomFieldsScreenState();
}

class _CustomFieldsScreenState extends State<CustomFieldsScreen> {
  List<Map<String, dynamic>> _patientFields = [];
  List<Map<String, dynamic>> _sessionFields = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFields();
  }

  Future<void> _loadFields() async {
    setState(() => _isLoading = true);
    try {
      final supabase = Supabase.instance.client;
      final fields = await supabase
          .from('custom_fields')
          .select()
          .eq('is_active', true)
          .order('display_order');
      
      setState(() {
        _patientFields = List<Map<String, dynamic>>.from(
            fields.where((f) => f['scope'] == 'patient'));
        _sessionFields = List<Map<String, dynamic>>.from(
            fields.where((f) => f['scope'] == 'session'));
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showAddEditDialog([Map<String, dynamic>? field]) {
    showDialog(
      context: context,
      builder: (ctx) => _FieldDialog(
        field: field,
        onSave: (data) async {
          try {
            final supabase = Supabase.instance.client;
            if (field != null) {
              await supabase.from('custom_fields').update(data).eq('id', field['id']);
            } else {
              await supabase.from('custom_fields').insert(data);
            }
            _loadFields();
            if (mounted) Navigator.pop(ctx);
          } catch (e) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red),
            );
          }
        },
      ),
    );
  }

  Future<void> _deleteField(Map<String, dynamic> field) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('حذف الحقل', style: TextStyle(color: Colors.white)),
        content: Text('هل أنت متأكد من حذف "${field['name']}"؟',
            style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('حذف'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await Supabase.instance.client
            .from('custom_fields')
            .update({'is_active': false})
            .eq('id', field['id']);
        _loadFields();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        title: const Text('إدارة الحقول الديناميكية'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadFields),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddEditDialog(),
        backgroundColor: AppTheme.primary,
        icon: const Icon(Icons.add),
        label: const Text('إضافة حقل'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Info Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withAlpha(26),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.primary.withAlpha(77)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline, color: AppTheme.primary),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'الحقول الثابتة تُملأ مرة واحدة لكل مريض.\n'
                            'الحقول المتكررة تُملأ في كل جلسة.',
                            style: TextStyle(color: Colors.white70, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Patient Fields (Permanent)
                  _buildFieldsSection(
                    title: '📋 الحقول الثابتة (للمريض)',
                    subtitle: 'تُملأ مرة واحدة وتبقى محفوظة',
                    fields: _patientFields,
                    color: Colors.blue,
                  ),
                  const SizedBox(height: 24),

                  // Session Fields (Per Session)
                  _buildFieldsSection(
                    title: '🔄 الحقول المتكررة (لكل جلسة)',
                    subtitle: 'يتم إدخالها في كل جلسة',
                    fields: _sessionFields,
                    color: Colors.orange,
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildFieldsSection({
    required String title,
    required String subtitle,
    required List<Map<String, dynamic>> fields,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(77)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 4, height: 40, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16)),
                    Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                  ],
                ),
              ),
              Text('${fields.length} حقل', style: TextStyle(color: color, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 16),
          if (fields.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              alignment: Alignment.center,
              child: const Text('لا توجد حقول', style: TextStyle(color: Colors.white38)),
            )
          else
            ...fields.map((f) => _buildFieldTile(f, color)),
        ],
      ),
    );
  }

  Widget _buildFieldTile(Map<String, dynamic> field, Color color) {
    final type = field['field_type'] ?? 'text';
    final typeIcon = _getTypeIcon(type);
    final typeName = _getTypeName(type);
    final isRequired = field['is_required'] == true;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: color.withAlpha(51), borderRadius: BorderRadius.circular(8)),
            child: Icon(typeIcon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(field['name'] ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
                    if (isRequired) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: Colors.red.withAlpha(51), borderRadius: BorderRadius.circular(4)),
                        child: const Text('مطلوب', style: TextStyle(color: Colors.red, fontSize: 10)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(typeName, style: const TextStyle(color: Colors.white38, fontSize: 11)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit, size: 18, color: Colors.white54),
            onPressed: () => _showAddEditDialog(field),
            tooltip: 'تعديل',
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
            onPressed: () => _deleteField(field),
            tooltip: 'حذف',
          ),
        ],
      ),
    );
  }

  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'text': return Icons.text_fields;
      case 'number': return Icons.numbers;
      case 'boolean': return Icons.toggle_on;
      case 'select': return Icons.list;
      case 'multiselect': return Icons.checklist;
      default: return Icons.help_outline;
    }
  }

  String _getTypeName(String type) {
    switch (type) {
      case 'text': return 'نص';
      case 'number': return 'رقم';
      case 'boolean': return 'نعم / لا';
      case 'select': return 'اختيار واحد';
      case 'multiselect': return 'اختيار متعدد';
      default: return type;
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// ADD/EDIT FIELD DIALOG
// ═══════════════════════════════════════════════════════════════════════════

class _FieldDialog extends StatefulWidget {
  final Map<String, dynamic>? field;
  final Function(Map<String, dynamic>) onSave;

  const _FieldDialog({this.field, required this.onSave});

  @override
  State<_FieldDialog> createState() => _FieldDialogState();
}

class _FieldDialogState extends State<_FieldDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _keyController = TextEditingController();
  String _type = 'text';
  String _scope = 'session';
  bool _isRequired = false;
  String? _selectedDepartmentId; // NEW: Department-specific field
  List<Map<String, dynamic>> _departments = []; // NEW: Departments list
  List<String> _options = [];
  final _optionController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadDepartments(); // NEW: Load departments
    if (widget.field != null) {
      _nameController.text = widget.field!['name'] ?? '';
      _keyController.text = widget.field!['field_key'] ?? '';
      _type = widget.field!['field_type'] ?? 'text';
      _scope = widget.field!['scope'] ?? 'session';
      _isRequired = widget.field!['is_required'] ?? false;
      _selectedDepartmentId = widget.field!['department_id']; // NEW
      if (widget.field!['options'] != null) {
        _options = List<String>.from(widget.field!['options']);
      }
    }
  }

  Future<void> _loadDepartments() async {
    try {
      final data = await Supabase.instance.client.from('departments').select('id, name').order('name');
      setState(() => _departments = List<Map<String, dynamic>>.from(data));
    } catch (e) {
      debugPrint('Error loading departments: $e');
    }
  }

  void _addOption() {
    final opt = _optionController.text.trim();
    if (opt.isNotEmpty && !_options.contains(opt)) {
      setState(() {
        _options.add(opt);
        _optionController.clear();
      });
    }
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    // Generate key from name if empty
    var key = _keyController.text.trim();
    if (key.isEmpty) {
      key = _nameController.text.trim()
          .toLowerCase()
          .replaceAll(' ', '_')
          .replaceAll(RegExp(r'[^\w]'), '');
    }

    final data = {
      'name': _nameController.text.trim(),
      'field_key': key,
      'field_type': _type,
      'scope': _scope,
      'is_required': _isRequired,
      'department_id': _selectedDepartmentId, // NEW: Include department
      'options': (_type == 'select' || _type == 'multiselect') ? _options : null,
    };

    widget.onSave(data);
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.field != null;

    return Dialog(
      backgroundColor: AppTheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 450,
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(isEdit ? Icons.edit : Icons.add_circle, color: AppTheme.primary),
                    const SizedBox(width: 12),
                    Text(isEdit ? 'تعديل الحقل' : 'إضافة حقل جديد',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                  ],
                ),
                const SizedBox(height: 20),

                // Name
                const Text('اسم الحقل', style: TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _nameController,
                  decoration: _inputDecoration('مثال: نوع البشرة'),
                  validator: (v) => v == null || v.isEmpty ? 'مطلوب' : null,
                ),
                const SizedBox(height: 16),

                // Type
                const Text('نوع الحقل', style: TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _typeChip('text', 'نص', Icons.text_fields),
                    _typeChip('number', 'رقم', Icons.numbers),
                    _typeChip('boolean', 'نعم/لا', Icons.toggle_on),
                    _typeChip('select', 'اختيار', Icons.list),
                    _typeChip('multiselect', 'متعدد', Icons.checklist),
                  ],
                ),
                const SizedBox(height: 16),

                // Scope
                const Text('نطاق الحقل', style: TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(child: _scopeChip('patient', '📋 ثابت (مرة واحدة)')),
                    const SizedBox(width: 8),
                    Expanded(child: _scopeChip('session', '🔄 متكرر (كل جلسة)')),
                  ],
                ),
                const SizedBox(height: 16),

                // Options (for select/multiselect)
                if (_type == 'select' || _type == 'multiselect') ...[
                  const Text('الخيارات', style: TextStyle(color: Colors.white70, fontSize: 13)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _optionController,
                          decoration: _inputDecoration('أضف خيار'),
                          onSubmitted: (_) => _addOption(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: _addOption,
                        icon: const Icon(Icons.add_circle, color: AppTheme.primary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: _options.map((opt) => Chip(
                      label: Text(opt, style: const TextStyle(fontSize: 12)),
                      backgroundColor: AppTheme.background,
                      deleteIcon: const Icon(Icons.close, size: 16),
                      onDeleted: () => setState(() => _options.remove(opt)),
                    )).toList(),
                  ),
                  const SizedBox(height: 16),
                ],

                // Department Selection (NEW)
                if (_departments.isNotEmpty) ...[
                  const Text('تخصيص للقسم (اختياري):', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String?>(
                        value: _selectedDepartmentId,
                        dropdownColor: AppTheme.surface,
                        isExpanded: true,
                        hint: const Text('كل الأقسام (افتراضي)', style: TextStyle(color: Colors.white54)),
                        items: [
                          const DropdownMenuItem<String?>(value: null, child: Text('كل الأقسام (افتراضي)')),
                          ..._departments.map((d) => DropdownMenuItem<String?>(
                            value: d['id'],
                            child: Text(d['name'] ?? ''),
                          )),
                        ],
                        onChanged: (v) => setState(() => _selectedDepartmentId = v),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Required
                CheckboxListTile(
                  value: _isRequired,
                  onChanged: (v) => setState(() => _isRequired = v ?? false),
                  title: const Text('حقل مطلوب', style: TextStyle(color: Colors.white)),
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  activeColor: AppTheme.primary,
                ),
                const SizedBox(height: 20),

                // Actions
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: _save,
                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
                      icon: const Icon(Icons.save),
                      label: Text(isEdit ? 'حفظ التعديلات' : 'إضافة'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _typeChip(String type, String label, IconData icon) {
    final isSelected = _type == type;
    return InkWell(
      onTap: () => setState(() => _type = type),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary : AppTheme.background,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isSelected ? AppTheme.primary : Colors.white24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: isSelected ? Colors.white : Colors.white54),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(fontSize: 12, color: isSelected ? Colors.white : Colors.white54)),
          ],
        ),
      ),
    );
  }

  Widget _scopeChip(String scope, String label) {
    final isSelected = _scope == scope;
    return InkWell(
      onTap: () => setState(() => _scope = scope),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary.withAlpha(51) : AppTheme.background,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isSelected ? AppTheme.primary : Colors.white24),
        ),
        child: Text(label, textAlign: TextAlign.center, style: TextStyle(
          fontSize: 12,
          color: isSelected ? AppTheme.primary : Colors.white54,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        )),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
      filled: true,
      fillColor: AppTheme.background,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    );
  }
}
