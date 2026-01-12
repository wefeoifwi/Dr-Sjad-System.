import 'package:flutter/material.dart';
import '../../core/theme.dart';

class FollowUpScreen extends StatefulWidget {
  const FollowUpScreen({super.key});

  @override
  State<FollowUpScreen> createState() => _FollowUpScreenState();
}

class _FollowUpScreenState extends State<FollowUpScreen> {
  // Mock Data: Patients with scheduled future sessions
  final List<Map<String, dynamic>> _followUpPatients = [
    {
      'name': 'سارة محمد',
      'phone': '07701234567',
      'last_session': '2025-01-10',
      'next_session': '2025-01-17', // Has future session -> Show
      'session_count': 1,
      'status': 'active', 
    },
    {
      'name': 'نورا خليل',
      'phone': '07501122334',
      'last_session': '2025-01-11',
      'next_session': '2025-01-25', // Has future session -> Show
      'session_count': 3,
      'status': 'active',
    },
  ];

  @override
  Widget build(BuildContext context) {
    // User Request: Only show those with future sessions
    final filteredList = _followUpPatients.where((p) => p['next_session'] != null).toList();

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('متابعة المواعيد القادمة'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: filteredList.length,
        itemBuilder: (context, index) {
          final patient = filteredList[index];
          final nextDate = patient['next_session'];

          return Card(
            color: AppTheme.surface,
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.blue.withAlpha(51),
                child: const Icon(Icons.calendar_month, color: Colors.blue),
              ),
              title: Text(patient['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('آخر جلسة: ${patient['last_session']} (رقم ${patient['session_count']})'),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.access_time, size: 14, color: Colors.green),
                      const SizedBox(width: 4),
                      Text('الموعد القادم: $nextDate', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Confirm Button
                  IconButton(
                    icon: const Icon(Icons.check_circle, color: Colors.green),
                    tooltip: 'تأكيد الموعد',
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تأكيد الموعد وإرسال رسالة تذكير للمريض')));
                    },
                  ),
                  // More Actions (Postpone / Cancel)
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'postpone') {
                        _showCancelOrPostponeDialog(patient, isPostpone: true);
                      } else if (value == 'cancel') {
                        _showCancelOrPostponeDialog(patient, isPostpone: false);
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                         value: 'postpone',
                         child: Row(
                           children: [
                             Icon(Icons.update, color: Colors.orange, size: 20),
                             SizedBox(width: 8),
                             Text('تأجيل الموعد'),
                           ],
                         ),
                      ),
                      const PopupMenuItem(
                        value: 'cancel',
                        child: Row(
                          children: [
                            Icon(Icons.cancel, color: Colors.red, size: 20),
                            SizedBox(width: 8),
                            Text('إلغاء الموعد'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showCancelOrPostponeDialog(Map<String, dynamic> patient, {required bool isPostpone}) {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isPostpone ? 'تأجيل الموعد' : 'طلب إلغاء الموعد'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isPostpone)
               Container(
                 padding: const EdgeInsets.all(8),
                 margin: const EdgeInsets.only(bottom: 16),
                 decoration: BoxDecoration(
                   color: Colors.red.withAlpha(26),
                   borderRadius: BorderRadius.circular(8),
                   border: Border.all(color: Colors.red.withAlpha(77)),
                 ),
                 child: const Row(
                   children: [
                     Icon(Icons.security, color: Colors.red, size: 20),
                     SizedBox(width: 8),
                     Expanded(child: Text('تنبيه: الإلغاء يتطلب موافقة المدير. سيتم تعليق الحجز حتى الموافقة.', style: TextStyle(color: Colors.red, fontSize: 12))),
                   ],
                 ),
               ),
            
            Text('المريض: ${patient['name']}'),
            const SizedBox(height: 8),
            Text(isPostpone 
              ? 'يرجى تحديد الموعد الجديد وسبب التأجيل.' 
              : 'يرجى ذكر سبب الإلغاء بدقة للمدير.'),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: InputDecoration(
                labelText: 'السبب (مطلوب)',
                border: const OutlineInputBorder(),
                filled: true,
                fillColor: AppTheme.surface,
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('رجوع')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: isPostpone ? Colors.orange : Colors.red),
            onPressed: () {
              if (reasonController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('يرجى كتابة السبب')));
                return;
              }
              Navigator.pop(ctx);
              
              if (isPostpone) {
                 ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('تم تأجيل الموعد للمريض ${patient['name']}.'))
                );
              } else {
                 ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('تم رفع طلب الإلغاء للمدير للمريض ${patient['name']}.'),
                    backgroundColor: Colors.blueGrey,
                  )
                );
              }
            },
            child: Text(isPostpone ? 'تأكيد التأجيل' : 'إرسال طلب الإلغاء'),
          ),
        ],
      ),
    );
  }
}
