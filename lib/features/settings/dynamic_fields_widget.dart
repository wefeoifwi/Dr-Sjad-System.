import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme.dart';

/// Widget لعرض وتعبئة الحقول الديناميكية
/// يستخدم في صفحة المريض (scope=patient) أو نهاية الجلسة (scope=session)
class DynamicFieldsWidget extends StatefulWidget {
  final String patientId;
  final String? sessionId; // null for patient-scope fields
  final String scope; // 'patient' or 'session'
  final bool readOnly;
  final VoidCallback? onSaved;

  const DynamicFieldsWidget({
    super.key,
    required this.patientId,
    this.sessionId,
    required this.scope,
    this.readOnly = false,
    this.onSaved,
  });

  @override
  State<DynamicFieldsWidget> createState() => _DynamicFieldsWidgetState();
}

class _DynamicFieldsWidgetState extends State<DynamicFieldsWidget> {
  List<Map<String, dynamic>> _fields = [];
  Map<String, dynamic> _values = {}; // field_id -> value
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadFieldsAndValues();
  }

  Future<void> _loadFieldsAndValues() async {
    setState(() => _isLoading = true);
    try {
      final supabase = Supabase.instance.client;

      // Load fields
      final fields = await supabase
          .from('custom_fields')
          .select()
          .eq('scope', widget.scope)
          .eq('is_active', true)
          .order('display_order');

      // Load existing values
      var query = supabase
          .from('custom_field_values')
          .select()
          .eq('patient_id', widget.patientId);

      if (widget.scope == 'session' && widget.sessionId != null) {
        query = query.eq('session_id', widget.sessionId!);
      }

      final values = await query;

      // Map values by field_id
      final valuesMap = <String, dynamic>{};
      for (var v in values) {
        valuesMap[v['field_id'].toString()] = v['value'];
      }

      setState(() {
        _fields = List<Map<String, dynamic>>.from(fields);
        _values = valuesMap;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      debugPrint('Error loading fields: $e');
    }
  }

  Future<void> _saveAll() async {
    setState(() => _isSaving = true);
    try {
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser?.id;

      for (var field in _fields) {
        final fieldId = field['id'].toString();
        final value = _values[fieldId];
        if (value == null) continue;

        final data = {
          'field_id': fieldId,
          'patient_id': widget.patientId,
          'session_id': widget.scope == 'session' ? widget.sessionId : null,
          'value': value,
          'created_by': userId,
          'updated_at': DateTime.now().toIso8601String(),
        };

        // Upsert
        await supabase.from('custom_field_values').upsert(data, onConflict: 'field_id,patient_id,session_id');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم الحفظ ✓'), backgroundColor: Colors.green),
        );
        widget.onSaved?.call();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red),
        );
      }
    }
    setState(() => _isSaving = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()));
    }

    if (_fields.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        child: const Center(child: Text('لا توجد حقول مخصصة', style: TextStyle(color: Colors.white38))),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Row(
            children: [
              Icon(
                widget.scope == 'patient' ? Icons.person : Icons.medical_services,
                color: AppTheme.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                widget.scope == 'patient' ? 'معلومات المريض الثابتة' : 'معلومات الجلسة',
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ],
          ),
        ),

        // Fields
        ...(_fields.map((f) => _buildField(f))),

        // Save Button
        if (!widget.readOnly) ...[
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isSaving ? null : _saveAll,
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, padding: const EdgeInsets.all(12)),
              icon: _isSaving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.save),
              label: Text(_isSaving ? 'جاري الحفظ...' : 'حفظ'),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildField(Map<String, dynamic> field) {
    final fieldId = field['id'].toString();
    final name = field['name'] ?? '';
    final type = field['field_type'] ?? 'text';
    final isRequired = field['is_required'] == true;
    final options = field['options'] != null ? List<String>.from(field['options']) : <String>[];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(name, style: const TextStyle(color: Colors.white70, fontSize: 13)),
              if (isRequired) const Text(' *', style: TextStyle(color: Colors.red)),
            ],
          ),
          const SizedBox(height: 6),
          _buildFieldInput(fieldId, type, options),
        ],
      ),
    );
  }

  Widget _buildFieldInput(String fieldId, String type, List<String> options) {
    switch (type) {
      case 'text':
        return TextField(
          controller: TextEditingController(text: _values[fieldId]?.toString() ?? ''),
          onChanged: (v) => _values[fieldId] = v,
          enabled: !widget.readOnly,
          decoration: _inputDecoration('أدخل النص'),
          maxLines: 2,
        );

      case 'number':
        return TextField(
          controller: TextEditingController(text: _values[fieldId]?.toString() ?? ''),
          onChanged: (v) => _values[fieldId] = num.tryParse(v),
          enabled: !widget.readOnly,
          keyboardType: TextInputType.number,
          decoration: _inputDecoration('أدخل الرقم'),
        );

      case 'boolean':
        final value = _values[fieldId] == true;
        return Row(
          children: [
            _boolChip('نعم', true, value, fieldId),
            const SizedBox(width: 8),
            _boolChip('لا', false, !value && _values.containsKey(fieldId), fieldId),
          ],
        );

      case 'select':
        return DropdownButtonFormField<String>(
          value: _values[fieldId]?.toString(),
          items: options.map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(),
          onChanged: widget.readOnly ? null : (v) => setState(() => _values[fieldId] = v),
          decoration: _inputDecoration('اختر'),
          dropdownColor: AppTheme.surface,
          style: const TextStyle(color: Colors.white),
        );

      case 'multiselect':
        final selected = _values[fieldId] != null ? List<String>.from(_values[fieldId]) : <String>[];
        return Wrap(
          spacing: 6,
          runSpacing: 6,
          children: options.map((o) {
            final isSelected = selected.contains(o);
            return FilterChip(
              label: Text(o, style: TextStyle(fontSize: 12, color: isSelected ? Colors.white : Colors.white70)),
              selected: isSelected,
              selectedColor: AppTheme.primary,
              backgroundColor: AppTheme.background,
              checkmarkColor: Colors.white,
              onSelected: widget.readOnly
                  ? null
                  : (v) {
                      setState(() {
                        if (v) {
                          selected.add(o);
                        } else {
                          selected.remove(o);
                        }
                        _values[fieldId] = selected;
                      });
                    },
            );
          }).toList(),
        );

      default:
        return const Text('نوع غير معروف', style: TextStyle(color: Colors.red));
    }
  }

  Widget _boolChip(String label, bool targetValue, bool isSelected, String fieldId) {
    return InkWell(
      onTap: widget.readOnly ? null : () => setState(() => _values[fieldId] = targetValue),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary : AppTheme.background,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isSelected ? AppTheme.primary : Colors.white24),
        ),
        child: Text(label, style: TextStyle(color: isSelected ? Colors.white : Colors.white54)),
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
