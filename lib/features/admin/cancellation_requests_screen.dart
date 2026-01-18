import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../follow_up/follow_up_provider.dart';

class CancellationRequestsScreen extends StatefulWidget {
  const CancellationRequestsScreen({super.key});

  @override
  State<CancellationRequestsScreen> createState() => _CancellationRequestsScreenState();
}

class _CancellationRequestsScreenState extends State<CancellationRequestsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<FollowUpProvider>().loadPendingCancellations();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('طلبات الإلغاء المعلقة'),
        backgroundColor: AppTheme.surface,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => context.read<FollowUpProvider>().loadPendingCancellations(),
          ),
        ],
      ),
      body: Consumer<FollowUpProvider>(
        builder: (context, provider, _) {
          if (provider.pendingCancellations.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle, size: 64, color: Colors.green),
                  SizedBox(height: 16),
                  Text('لا توجد طلبات إلغاء معلقة', style: TextStyle(color: Colors.white54)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: provider.pendingCancellations.length,
            itemBuilder: (context, index) {
              final request = provider.pendingCancellations[index];
              return _buildRequestCard(request);
            },
          );
        },
      ),
    );
  }

  Widget _buildRequestCard(Map<String, dynamic> request) {
    final patientName = request['patients']?['name'] ?? 'مريض';
    final patientPhone = request['patients']?['phone'] ?? '';
    final requestedBy = request['profiles']?['name'] ?? 'موظف';
    final reason = request['cancellation_reason'] ?? 'بدون سبب';
    final scheduledDate = request['scheduled_date'] ?? '';

    return Card(
      color: AppTheme.surface,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Colors.orange, width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                const CircleAvatar(
                  backgroundColor: Color(0x33FF9800),
                  child: Icon(Icons.cancel, color: Colors.orange),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(patientName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      if (patientPhone.isNotEmpty)
                        Text(patientPhone, style: const TextStyle(color: Colors.white70)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange.withAlpha(51),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text('بانتظار الموافقة', style: TextStyle(color: Colors.orange, fontSize: 11)),
                ),
              ],
            ),

            const Divider(height: 24),

            // Details
            _buildDetailRow(Icons.calendar_today, 'موعد في: $scheduledDate'),
            const SizedBox(height: 8),
            _buildDetailRow(Icons.person, 'طلب بواسطة: $requestedBy'),
            const SizedBox(height: 12),
            
            // Reason Box
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withAlpha(26),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withAlpha(77)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('سبب الإلغاء:', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(reason, style: const TextStyle(color: Colors.white70)),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Actions
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () => _confirmAction(
                      request,
                      isApprove: false,
                      title: 'رفض الإلغاء',
                      message: 'سيتم إعادة الموعد للحالة السابقة وإشعار الموظف',
                    ),
                    icon: const Icon(Icons.close),
                    label: const Text('رفض'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () => _confirmAction(
                      request,
                      isApprove: true,
                      title: 'الموافقة على الإلغاء',
                      message: 'سيتم إلغاء الموعد نهائياً وإشعار الموظف',
                    ),
                    icon: const Icon(Icons.check),
                    label: const Text('موافقة'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.white54),
        const SizedBox(width: 8),
        Text(text, style: const TextStyle(color: Colors.white70)),
      ],
    );
  }

  void _confirmAction(Map<String, dynamic> request, {required bool isApprove, required String title, required String message}) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: isApprove ? Colors.green : Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                final provider = context.read<FollowUpProvider>();
                if (isApprove) {
                  await provider.approveCancellation(
                    followUpId: request['id'],
                    requestedByUserId: request['created_by'] ?? '',
                    patientName: request['patients']?['name'] ?? '',
                  );
                } else {
                  await provider.rejectCancellation(
                    followUpId: request['id'],
                    requestedByUserId: request['created_by'] ?? '',
                    patientName: request['patients']?['name'] ?? '',
                  );
                }
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(isApprove ? 'تم الموافقة على الإلغاء' : 'تم رفض الإلغاء'),
                      backgroundColor: isApprove ? Colors.green : Colors.orange,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red));
                }
              }
            },
            child: Text(isApprove ? 'موافقة' : 'رفض'),
          ),
        ],
      ),
    );
  }
}
