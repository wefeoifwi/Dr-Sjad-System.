import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';
import 'admin_provider.dart';

class FinanceManagementScreen extends StatefulWidget {
  const FinanceManagementScreen({super.key});

  @override
  State<FinanceManagementScreen> createState() => _FinanceManagementScreenState();
}

class _FinanceManagementScreenState extends State<FinanceManagementScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdminProvider>().loadFinancialStats();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('الإدارة المالية', style: Theme.of(context).textTheme.headlineMedium),
                ElevatedButton.icon(
                  onPressed: () {
                    // TODO: Export Report
                  },
                  icon: const Icon(Icons.download),
                  label: const Text('تصدير تقرير'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.surface,
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white24),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Financial Stats Cards
            Consumer<AdminProvider>(
              builder: (context, provider, _) {
                 return Row(
                  children: [
                    _StatsCard(
                      title: 'إيرادات اليوم',
                      value: '${provider.dailyRevenue} د.ع',
                      icon: Icons.attach_money,
                      color: Colors.green,
                      isLoading: provider.isLoading,
                    ),
                    const SizedBox(width: 16),
                    _StatsCard(
                      title: 'إيرادات الشهر',
                      value: '${provider.monthlyRevenue} د.ع',
                      icon: Icons.calendar_month,
                      color: Colors.blue,
                       isLoading: provider.isLoading,
                    ),
                    const SizedBox(width: 16),
                    _StatsCard(
                      title: 'إجمالي الإيرادات',
                      value: '${provider.totalRevenue} د.ع',
                      icon: Icons.account_balance_wallet,
                      color: Colors.purple,
                       isLoading: provider.isLoading,
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 32),

            // Recent Transactions (Completed Sessions)
            Text('آخر المعاملات (الجلسات المكتملة)', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            
            Expanded(
              child: Consumer<AdminProvider>(
                builder: (context, provider, _) {
                  if (provider.isLoading && provider.recentTransactions.isEmpty) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  
                  if (provider.recentTransactions.isEmpty) {
                    return const Center(child: Text('لا توجد معاملات مسجلة', style: TextStyle(color: Colors.white54)));
                  }

                  return Container(
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: ListView.separated(
                      padding: const EdgeInsets.all(8),
                      itemCount: provider.recentTransactions.length,
                      separatorBuilder: (_, i) => const Divider(color: Colors.white10),
                      itemBuilder: (context, index) {
                        final transaction = provider.recentTransactions[index];
                        final date = DateTime.parse(transaction['end_time'] ?? transaction['start_time']);
                        
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.green.withAlpha(26),
                            child: const Icon(Icons.check, color: Colors.green, size: 20),
                          ),
                          title: Text(
                            transaction['patient']?['name'] ?? 'مريض مجهول',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            '${DateFormat('yyyy-MM-dd hh:mm a').format(date)} - ${transaction['service_type'] ?? 'خدمة'}',
                            style: const TextStyle(color: Colors.white54),
                          ),
                          trailing: Text(
                            '+ ${transaction['price']} د.ع',
                            style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatsCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final bool isLoading;

  const _StatsCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withAlpha(77)),
          boxShadow: [
            BoxShadow(color: color.withAlpha(26), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: color, size: 28),
                if (isLoading) 
                  const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              ],
            ),
            const SizedBox(height: 16),
            Text(title, style: const TextStyle(color: Colors.white70, fontSize: 14)),
            const SizedBox(height: 8),
            Text(value, style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold, shadows: [
              Shadow(color: color.withAlpha(128), blurRadius: 10),
            ])),
          ],
        ),
      ),
    );
  }
}
