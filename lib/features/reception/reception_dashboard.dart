import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';
import '../schedule/schedule_provider.dart';
import '../schedule/models.dart';
import '../schedule/booking_dialog.dart';
import 'payment_dialog.dart';

class ReceptionDashboard extends StatefulWidget {
  const ReceptionDashboard({super.key});

  @override
  State<ReceptionDashboard> createState() => _ReceptionDashboardState();
}

class _ReceptionDashboardState extends State<ReceptionDashboard> {
  String _filterStatus = 'all'; // all, booked, arrived, completed

  @override
  Widget build(BuildContext context) {
    // For now, we reuse ScheduleProvider to get bookings. 
    // In a real app, we might have a dedicated ReceptionProvider or query specifically for "Today".
    final provider = context.watch<ScheduleProvider>();
    final today = DateTime.now();
    
    // Filter bookings for TODAY only
    final todayBookings = provider.bookings.where((b) {
      return b.startTime.year == today.year && 
             b.startTime.month == today.month && 
             b.startTime.day == today.day;
    }).toList();

    // Apply Status Filter
    List<Booking> filteredList = todayBookings;
    if (_filterStatus != 'all') {
      filteredList = todayBookings.where((b) => b.status == _filterStatus).toList();
    }

    // Sort by time
    filteredList.sort((a, b) => a.startTime.compareTo(b.startTime));

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 24),
            _buildStatCards(todayBookings),
            const SizedBox(height: 24),
            Expanded(child: _buildBookingList(filteredList)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('لوحة الاستقبال', style: Theme.of(context).textTheme.headlineMedium),
            Text(
              DateFormat('EEEE, d MMMM yyyy', 'ar').format(DateTime.now()),
              style: const TextStyle(color: Colors.white54),
            ),
          ],
        ),
        Row(
          children: [
             ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => _showWalkInBookingDialog(),
              icon: const Icon(Icons.add_circle_outline),
              label: const Text('حجز فوري / انتظار'),
            ),
            const SizedBox(width: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white10),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _filterStatus,
                  dropdownColor: AppTheme.surface,
                  style: const TextStyle(color: Colors.white),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('الكل')),
                    DropdownMenuItem(value: 'booked', child: Text('انتظار الوصول')),
                    DropdownMenuItem(value: 'arrived', child: Text('تم الوصول (الانتظار)')),
                    DropdownMenuItem(value: 'completed', child: Text('مكتمل')),
                  ],
                  onChanged: (val) => setState(() => _filterStatus = val!),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _showWalkInBookingDialog() {
    // Open the standard Booking dialog for TODAY
    showDialog(
      context: context,
      builder: (_) => BookingDialog(
        initialDate: DateTime.now(),
        preselectedDoctorId: null, 
        // BookingDialog might need refactoring if it expects doctors passed in, 
        // but ScheduleProvider has them. Let's check BookingDialog signature.
        // Assuming BookingDialog acts as a consumer or needs arguments.
        // For now, let's assume it manages its own state or we pass empty and it fetches.
        // We actually need to import it.
      ),
    );
  }

  Widget _buildStatCards(List<Booking> bookings) {
    final total = bookings.length;
    final arrived = bookings.where((b) => b.status == 'arrived' || b.status == 'in_session').length;
    final completed = bookings.where((b) => b.status == 'completed').length;
    final pending = total - arrived - completed; // Roughly 'booked'

    return Row(
      children: [
        _statCard('مواعيد اليوم', total.toString(), Colors.blue, Icons.calendar_today),
        const SizedBox(width: 16),
        _statCard('في الانتظار/العيادة', arrived.toString(), Colors.orange, Icons.people),
        const SizedBox(width: 16),
        _statCard('تمت الخدمة', completed.toString(), Colors.green, Icons.check_circle),
      ],
    );
  }

  Widget _statCard(String title, String value, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withAlpha(77)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withAlpha(26),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                Text(title, style: const TextStyle(color: Colors.white60, fontSize: 12)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBookingList(List<Booking> bookings) {
    if (bookings.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_busy, size: 64, color: Colors.white.withAlpha(51)),
            const SizedBox(height: 16),
            const Text('لا توجد مواعيد مطابقة', style: TextStyle(color: Colors.white38)),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: bookings.length,
      itemBuilder: (context, index) {
        final booking = bookings[index];
        final isBooked = booking.status == 'booked';

        return Card(
          color: AppTheme.surface,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: CircleAvatar(
              backgroundColor: isBooked ? Colors.orange.withAlpha(51) : Colors.green.withAlpha(51),
              child: Text(
                DateFormat('h:mm').format(booking.startTime),
                style: TextStyle(
                  color: isBooked ? Colors.orange : Colors.green, 
                  fontWeight: FontWeight.bold, 
                  fontSize: 12
                ),
              ),
            ),
            title: Text(booking.patientName, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Row(
              children: [
                const Icon(Icons.person, size: 14, color: Colors.white38),
                const SizedBox(width: 4),
                Text('د. ${booking.doctorId == '1' ? "سجاد" : "اخر"}', style: const TextStyle(color: Colors.white38)),
                const SizedBox(width: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    _getStatusLabel(booking.status),
                    style: const TextStyle(fontSize: 10, color: Colors.white70),
                  ),
                ),
              ],
            ),
            trailing: isBooked 
              ? ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                  icon: const Icon(Icons.payment),
                  label: const Text('دفع ودخول'),
                  onPressed: () => _showPaymentDialog(booking),
                )
              : const Icon(Icons.check_circle, color: Colors.white12),
          ),
        );
      },
    );
  }

  void _showPaymentDialog(Booking booking) {
    showDialog(
      context: context,
      builder: (context) => PaymentDialog(booking: booking),
    );
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'booked': return 'محجوز';
      case 'arrived': return 'وصل';
      case 'in_session': return 'بالجلسة';
      case 'completed': return 'مكتمل';
      default: return status;
    }
  }
}
