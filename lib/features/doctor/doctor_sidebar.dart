import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../schedule/schedule_provider.dart';
import '../schedule/models.dart';

class DoctorSidebar extends StatelessWidget {
  final Function(Booking) onPatientSelected;
  final String? selectedBookingId;

  const DoctorSidebar({
    super.key, 
    required this.onPatientSelected,
    required this.selectedBookingId,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ScheduleProvider>();
    // Mock Doctor ID '1'
    final myQueue = provider.bookings.where((b) => b.status == 'arrived' && b.doctorId == '1').toList();
    final allPatients = provider.bookings.where((b) => b.doctorId == '1').toList(); // For search

    return Container(
      width: 280,
      color: AppTheme.surface,
      child: Column(
        children: [
          // Header / Search
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('قائمة المراجعين', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(height: 12),
                TextField(
                  decoration: InputDecoration(
                    hintText: 'بحث عن مريض...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    isDense: true,
                    filled: true,
                    fillColor: Colors.white.withAlpha(13),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                  ),
                ),
              ],
            ),
          ),
          
          const Divider(height: 1),

          // List
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(8),
              children: [
                if (myQueue.isNotEmpty) ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    child: Text('غرفة الانتظار (وصلوا)', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold)),
                  ),
                  ...myQueue.map((b) => _buildPatientTile(b, context, isQueue: true)),
                  const Divider(height: 24),
                ],

                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  child: Text('كل المرضى', style: TextStyle(color: Colors.white54, fontSize: 12)),
                ),
                ...allPatients.where((b) => b.status != 'arrived').map((b) => _buildPatientTile(b, context)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPatientTile(Booking booking, BuildContext context, {bool isQueue = false}) {
    final isSelected = booking.id == selectedBookingId;
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: isSelected ? AppTheme.primary.withAlpha(26) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: isSelected ? Border.all(color: AppTheme.primary.withAlpha(77)) : null,
      ),
      child: ListTile(
        onTap: () => onPatientSelected(booking),
        leading: CircleAvatar(
          backgroundColor: isQueue ? Colors.green : Colors.grey.withAlpha(77),
          radius: 16,
          child: Icon(Icons.person, size: 16, color: isQueue ? Colors.white : Colors.white70),
        ),
        title: Text(booking.patientName, style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          fontSize: 14,
        )),
        subtitle: isQueue 
          ? const Text('في الانتظار', style: TextStyle(color: Colors.green, fontSize: 10))
          : Text(booking.status, style: const TextStyle(fontSize: 10, color: Colors.white38)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 8),
        horizontalTitleGap: 8,
      ),
    );
  }
}
