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
  final _amountController = TextEditingController(text: '25000'); // Default Fee
  final _notesController = TextEditingController();
  String _paymentMethod = 'cash'; // cash, card, transfer
  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.surface,
      title: const Text('تسجيل دخول ودفع'),
      content: SizedBox(
        width: 400,
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
                  const Icon(Icons.person, color: AppTheme.primary),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.booking.patientName, style: const TextStyle(fontWeight: FontWeight.bold)),
                      const Text('كشفية / جلسة علاجية', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            
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
            const SizedBox(height: 24),

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
          onPressed: _isProcessing ? null : _processPayment,
          child: _isProcessing 
            ? const SizedBox(
                width: 20, height: 20,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
              )
            : const Text('تأكيد الدفع والدخول'),
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

    setState(() => _isProcessing = true);

    try {
      final supabase = Supabase.instance.client;
      
      // 1. Save payment to payments table
      await supabase.from('payments').insert({
        'session_id': widget.booking.id,
        'patient_id': widget.booking.patientId,
        'amount': amount,
        'payment_method': _paymentMethod,
        'notes': _notesController.text,
        // received_by will be set once we have proper auth
      });

      // 2. Update session status and price
      await supabase.from('sessions').update({
        'status': 'arrived',
        'price': amount,
      }).eq('id', widget.booking.id);

      // 3. Refresh the schedule
      if (context.mounted) {
        context.read<ScheduleProvider>().loadData();
        
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم استلام ${_amountController.text} د.ع وتسجيل وصول المريض بنجاح'),
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
