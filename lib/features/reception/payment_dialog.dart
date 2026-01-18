import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme.dart';
import '../schedule/models.dart';
import '../schedule/schedule_provider.dart';

class PaymentDialog extends StatefulWidget {
  final Booking booking;
  const PaymentDialog({super.key, required this.booking});

  @override
  State<PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends State<PaymentDialog> {
  final _amountController = TextEditingController(text: '25000');
  final _notesController = TextEditingController();
  String _paymentMethod = 'cash';
  String? _selectedDoctorId; // الدكتور المعين
  bool _isProcessing = false;
  List<Doctor> _availableDoctors = []; // الأطباء المتاحين في القسم

  @override
  void initState() {
    super.initState();
    _loadDoctorsForDepartment();
  }

  Future<void> _loadDoctorsForDepartment() async {
    final provider = context.read<ScheduleProvider>();
    final deptId = widget.booking.departmentId;
    
    if (deptId != null) {
      // فلترة الأطباء حسب القسم
      final doctors = provider.doctors.where((d) => d.departmentId == deptId).toList();
      setState(() {
        _availableDoctors = doctors;
        if (doctors.isNotEmpty) {
          _selectedDoctorId = doctors.first.id;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.surface,
      title: const Text('استلام المبلغ وتعيين الطبيب'),
      content: SizedBox(
        width: 450,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Patient Info
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    // تصنيف الزبون
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: widget.booking.categoryEnum.color.withAlpha(50),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(widget.booking.categoryEnum.icon, 
                               color: widget.booking.categoryEnum.color, size: 14),
                          const SizedBox(width: 4),
                          Text(widget.booking.categoryEnum.label,
                               style: TextStyle(color: widget.booking.categoryEnum.color, 
                                                fontSize: 11, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.booking.patientName, 
                               style: const TextStyle(fontWeight: FontWeight.bold)),
                          Text('${widget.booking.serviceType} | ${widget.booking.departmentName ?? ""}',
                               style: const TextStyle(color: Colors.white70, fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // اختيار الطبيب
              const Text('اختر الطبيب للجلسة', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              if (_availableDoctors.isEmpty)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withAlpha(30),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.warning, color: Colors.orange, size: 18),
                      SizedBox(width: 8),
                      Text('لا يوجد أطباء متاحين في هذا القسم', 
                           style: TextStyle(color: Colors.orange)),
                    ],
                  ),
                )
              else
                DropdownButtonFormField<String>(
                  value: _selectedDoctorId,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.medical_services),
                  ),
                  items: _availableDoctors.map((doc) {
                    return DropdownMenuItem(
                      value: doc.id,
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 12,
                            backgroundColor: doc.color,
                            child: Text(doc.name[0], 
                                   style: const TextStyle(color: Colors.white, fontSize: 10)),
                          ),
                          const SizedBox(width: 8),
                          Text(doc.name),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (val) => setState(() => _selectedDoctorId = val),
                  validator: (val) => val == null ? 'يرجى اختيار الطبيب' : null,
                ),
              const SizedBox(height: 20),
              
              // Amount
              const Text('المبلغ المطلوب (د.ع)', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  suffixText: 'د.ع',
                ),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),

              // Payment Method
              const Text('طريقة الدفع', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: _methodCard('نقدي', 'cash', Icons.money)),
                  const SizedBox(width: 8),
                  Expanded(child: _methodCard('بطاقة', 'card', Icons.credit_card)),
                  const SizedBox(width: 8),
                  Expanded(child: _methodCard('تحويل', 'transfer', Icons.send)),
                ],
              ),
              const SizedBox(height: 16),
              
              // Notes
              TextField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: 'ملاحظات (اختياري)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isProcessing ? null : () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
          onPressed: _isProcessing || _selectedDoctorId == null ? null : _processPayment,
          child: _isProcessing 
            ? const SizedBox(
                width: 20, height: 20,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
              )
            : const Text('تأكيد الدفع وتعيين الطبيب'),
        ),
      ],
    );
  }

  Future<void> _processPayment() async {
    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى إدخال مبلغ صحيح'), backgroundColor: Colors.red),
      );
      return;
    }

    if (_selectedDoctorId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى اختيار الطبيب'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final supabase = Supabase.instance.client;
      final now = DateTime.now().toUtc().toIso8601String();
      
      // 1. Save payment
      await supabase.from('payments').insert({
        'session_id': widget.booking.id,
        'patient_id': widget.booking.patientId,
        'amount': amount,
        'payment_method': _paymentMethod,
        'notes': _notesController.text,
      });

      // 2. Update session - تعيين الدكتور ووقت الدفع
      await supabase.from('sessions').update({
        'status': 'arrived',
        'price': amount,
        'assigned_doctor_id': _selectedDoctorId, // الدكتور المعين
        'assigned_at': now, // وقت التعيين
        'payment_time': now, // وقت الدفع
      }).eq('id', widget.booking.id);

      // 3. تحديث عدد الزيارات للمريض
      await supabase.rpc('increment_patient_visits', params: {
        'p_id': widget.booking.patientId
      }).catchError((_) {}); // تجاهل إذا لم تكن الدالة موجودة

      // 4. Refresh
      if (context.mounted) {
        context.read<ScheduleProvider>().loadData();
        
        final doctorName = _availableDoctors
            .firstWhere((d) => d.id == _selectedDoctorId, orElse: () => _availableDoctors.first)
            .name;
        
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ تم استلام ${_amountController.text} د.ع وتعيين الطبيب $doctorName'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Widget _methodCard(String label, String value, IconData icon) {
    final isSelected = _paymentMethod == value;
    return InkWell(
      onTap: () => setState(() => _paymentMethod = value),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary.withAlpha(50) : Colors.transparent,
          border: Border.all(
            color: isSelected ? AppTheme.primary : Colors.white24,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? AppTheme.primary : Colors.white54, size: 20),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(
              color: isSelected ? AppTheme.primary : Colors.white54,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            )),
          ],
        ),
      ),
    );
  }
}
