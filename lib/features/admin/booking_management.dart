import 'package:flutter/material.dart';
import '../../features/schedule/timeline_view.dart';
import '../../core/theme.dart';

class BookingManagementScreen extends StatelessWidget {
  const BookingManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Admin Specific Header or Controls could go here if needed, 
            // but for now we just show the reused timeline.
             Text(
              'إدارة الحجوزات (الجدول الزمني)', 
              style: Theme.of(context).textTheme.headlineMedium
            ),
            const SizedBox(height: 16),
            const Expanded(
              child: TimelineView(),
            ),
          ],
        ),
      ),
    );
  }
}
