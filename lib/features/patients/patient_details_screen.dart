import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';

class PatientDetailsScreen extends StatelessWidget {
  final Map<String, dynamic> patient;

  const PatientDetailsScreen({super.key, required this.patient});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(patient['name'] ?? 'تفاصيل المريض'),
        backgroundColor: AppTheme.surface,
        actions: [
          IconButton(icon: const Icon(Icons.edit), onPressed: () {}),
        ],
      ),
      body: DefaultTabController(
        length: 2,
        child: Column(
          children: [
            // Top Info Card
            Container(
              padding: const EdgeInsets.all(24),
              color: AppTheme.surface,
              child: Column(
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 32,
                        backgroundColor: AppTheme.primary,
                        child: Text(
                          (patient['name'] ?? '?')[0],
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(patient['name'] ?? 'بدون اسم', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(Icons.phone, size: 16, color: Colors.white70),
                                const SizedBox(width: 8),
                                Text(patient['phone'] ?? '---', style: const TextStyle(color: Colors.white70)),
                                const SizedBox(width: 24),
                                const Icon(Icons.cake, size: 16, color: Colors.white70),
                                const SizedBox(width: 8),
                                Text('${patient['age'] ?? '-'} سنة', style: const TextStyle(color: Colors.white70)),
                              ],
                            )
                          ],
                        ),
                      ),
                      Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.green.withAlpha(26),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.green),
                            ),
                            child: const Text('عميل نشط', style: TextStyle(color: Colors.green)),
                          ),
                          const SizedBox(height: 8),
                          Text('آخر زيارة: ${patient['last_visit'] != null ? DateFormat('yyyy-MM-dd').format(DateTime.parse(patient['last_visit'])) : '-'}', style: const TextStyle(color: Colors.white38, fontSize: 12)),
                        ],
                      )
                    ],
                  ),
                ],
              ),
            ),
            
            // Tabs
            const TabBar(
              tabs: [
                Tab(text: 'جلسات العلاج'),
                Tab(text: 'الملف المالي'),
                // Tab(text: 'الصور والملفات'),
              ],
            ),
            
            // Content
            Expanded(
              child: TabBarView(
                children: [
                  _SessionsTab(patientId: patient['id']),
                  const Center(child: Text('قريباً: الملف المالي', style: TextStyle(color: Colors.white54))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SessionsTab extends StatelessWidget {
  final String? patientId;
  const _SessionsTab({this.patientId});

  @override
  Widget build(BuildContext context) {
    // Should fetch from provider based on patientID
    // TODO: Implement Real Fetch
    
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 0, 
      itemBuilder: (context, index) => const SizedBox(),
    );
  }
}
