import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme.dart';
import '../schedule/schedule_provider.dart';
import '../schedule/models.dart';

class DoctorSidebar extends StatefulWidget {
  final Function(Booking) onPatientSelected;
  final String? selectedBookingId;

  const DoctorSidebar({
    super.key, 
    required this.onPatientSelected,
    required this.selectedBookingId,
  });

  @override
  State<DoctorSidebar> createState() => _DoctorSidebarState();
}

class _DoctorSidebarState extends State<DoctorSidebar> {
  String _searchQuery = '';
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ScheduleProvider>();
    final currentUserId = Supabase.instance.client.auth.currentUser?.id ?? '';
    
    // جلب جميع مواعيد اليوم
    final allBookings = provider.bookings;
    
    // فلترة الحجوزات الخاصة بهذا الطبيب
    // ملاحظة: إذا لم يكن للطبيب مواعيد، نعرض جميع المواعيد المتاحة
    var myBookings = allBookings.where((b) => b.doctorId == currentUserId).toList();
    
    // إذا لم يجد مواعيد خاصة بالطبيب، نعرض جميع المواعيد التي تحتاج اهتمام
    // (هذا مفيد للاختبار أو إذا كان هناك طبيب واحد)
    final showAllIfEmpty = myBookings.isEmpty;
    if (showAllIfEmpty) {
      myBookings = allBookings.where((b) => 
        b.status == 'arrived' || b.status == 'in_session'
      ).toList();
    }
    
    // فلترة حسب البحث
    var filteredBookings = myBookings;
    if (_searchQuery.isNotEmpty) {
      filteredBookings = myBookings.where((b) =>
        b.patientName.toLowerCase().contains(_searchQuery.toLowerCase())
      ).toList();
    }
    
    // تقسيم حسب الحالة - قائمة الانتظار تشمل arrived و in_session
    final inSessionQueue = filteredBookings.where((b) => b.status == 'in_session').toList();
    final arrivedQueue = filteredBookings.where((b) => b.status == 'arrived').toList();
    final pendingQueue = filteredBookings.where((b) => b.status == 'booked' || b.status == 'scheduled').toList();
    final completedQueue = filteredBookings.where((b) => b.status == 'completed').toList();
    
    // ترتيب حسب الوقت
    inSessionQueue.sort((a, b) => a.startTime.compareTo(b.startTime));
    arrivedQueue.sort((a, b) => a.startTime.compareTo(b.startTime));
    pendingQueue.sort((a, b) => a.startTime.compareTo(b.startTime));
    completedQueue.sort((a, b) => b.startTime.compareTo(a.startTime)); // الأحدث أولاً

    return Container(
      width: 300,
      color: AppTheme.surface,
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.primary.withAlpha(26),
              border: Border(bottom: BorderSide(color: Colors.white.withAlpha(26))),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.people, color: AppTheme.primary),
                    const SizedBox(width: 8),
                    const Text('قائمة المراجعين', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const Spacer(),
                    // زر التحديث
                    IconButton(
                      icon: const Icon(Icons.refresh, size: 20),
                      tooltip: 'تحديث',
                      onPressed: () => context.read<ScheduleProvider>().loadData(),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // إحصائيات سريعة
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildStatBadge('${inSessionQueue.length}', 'في جلسة', Colors.cyan),
                    _buildStatBadge('${arrivedQueue.length}', 'بالانتظار', Colors.green),
                    _buildStatBadge('${pendingQueue.length}', 'قادمين', Colors.orange),
                    _buildStatBadge('${completedQueue.length}', 'مكتمل', Colors.blue),
                  ],
                ),
                const SizedBox(height: 12),
                // البحث
                TextField(
                  controller: _searchController,
                  onChanged: (v) => setState(() => _searchQuery = v),
                  decoration: InputDecoration(
                    hintText: 'بحث عن مريض...',
                    prefixIcon: const Icon(Icons.search, size: 18),
                    isDense: true,
                    filled: true,
                    fillColor: Colors.white.withAlpha(13),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
              ],
            ),
          ),
          
          // Loading state
          if (provider.isLoading)
            const Expanded(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (myBookings.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.event_busy, size: 48, color: Colors.white.withAlpha(51)),
                    const SizedBox(height: 16),
                    const Text('لا توجد مواعيد اليوم', style: TextStyle(color: Colors.white38)),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: () => context.read<ScheduleProvider>().loadData(),
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text('تحديث'),
                    ),
                  ],
                ),
              ),
            )
          else
            // القائمة
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(8),
                children: [
                  // 🔴 قسم في الجلسة الآن (الأهم)
                  if (inSessionQueue.isNotEmpty) ...[
                    _buildSectionHeader('🔴 في الجلسة الآن', inSessionQueue.length, Colors.cyan, Icons.play_circle),
                    ...inSessionQueue.map((b) => _buildPatientTile(b, isInSession: true)),
                    const SizedBox(height: 16),
                  ],
                  
                  // قسم الانتظار
                  if (arrivedQueue.isNotEmpty) ...[
                    _buildSectionHeader('في غرفة الانتظار', arrivedQueue.length, Colors.green, Icons.hourglass_top),
                    ...arrivedQueue.map((b) => _buildPatientTile(b, isQueue: true)),
                    const SizedBox(height: 16),
                  ],
                  
                  // قسم القادمين
                  if (pendingQueue.isNotEmpty) ...[
                    _buildSectionHeader('قادمين لاحقاً', pendingQueue.length, Colors.orange, Icons.schedule),
                    ...pendingQueue.map((b) => _buildPatientTile(b)),
                    const SizedBox(height: 16),
                  ],
                  
                  // قسم المكتملين
                  if (completedQueue.isNotEmpty) ...[
                    _buildSectionHeader('مكتمل', completedQueue.length, Colors.blue, Icons.done_all),
                    ...completedQueue.map((b) => _buildPatientTile(b, isCompleted: true)),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatBadge(String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(26),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(color: color, fontSize: 10)),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, int count, Color color, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withAlpha(26),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Text(title, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text('$count', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildPatientTile(Booking booking, {bool isQueue = false, bool isCompleted = false, bool isInSession = false}) {
    final isSelected = booking.id == widget.selectedBookingId;
    
    Color statusColor;
    if (isInSession) {
      statusColor = Colors.cyan;
    } else if (isQueue) {
      statusColor = Colors.green;
    } else if (isCompleted) {
      statusColor = Colors.blue;
    } else {
      statusColor = Colors.orange;
    }
    
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: isSelected ? AppTheme.primary.withAlpha(26) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: isSelected ? Border.all(color: AppTheme.primary.withAlpha(128)) : null,
      ),
      child: ListTile(
        onTap: () => widget.onPatientSelected(booking),
        leading: Stack(
          children: [
            CircleAvatar(
              backgroundColor: statusColor.withAlpha(51),
              radius: 20,
              child: Text(
                booking.patientName.isNotEmpty ? booking.patientName[0].toUpperCase() : '?',
                style: TextStyle(color: statusColor, fontWeight: FontWeight.bold),
              ),
            ),
            if (isQueue)
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppTheme.surface, width: 2),
                  ),
                ),
              ),
          ],
        ),
        title: Text(
          booking.patientName,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            fontSize: 13,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          AppTheme.formatTime12h(booking.startTime),
          style: TextStyle(color: statusColor, fontSize: 11),
        ),
        trailing: isQueue
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green.withAlpha(26),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text('جاهز', style: TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold)),
            )
          : null,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        horizontalTitleGap: 8,
      ),
    );
  }
}
