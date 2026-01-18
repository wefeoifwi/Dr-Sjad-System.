import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';
import '../admin/admin_provider.dart';
import 'schedule_provider.dart';
import 'models.dart';
import 'booking_dialog.dart';

class TimelineView extends StatefulWidget {
  final String userRole; // 'admin', 'reception', 'call_center'
  
  const TimelineView({super.key, this.userRole = 'admin'});

  @override
  State<TimelineView> createState() => _TimelineViewState();
}

class _TimelineViewState extends State<TimelineView> {
  double _baseHourHeight = 100.0;
  final ScrollController _horizontalScrollController = ScrollController();
  final ScrollController _verticalScrollController = ScrollController();
  
  // Timer للتحديث اللحظي
  Timer? _refreshTimer;
  int _lastBookingCount = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ScheduleProvider>().loadData();
    });
    
    // Timer للتحديث اللحظي
    _refreshTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        final provider = context.read<ScheduleProvider>();
        if (provider.bookings.length != _lastBookingCount) {
          _lastBookingCount = provider.bookings.length;
          setState(() {});
        }
      }
    });
  }

  @override
  void dispose() {
    _horizontalScrollController.dispose();
    _verticalScrollController.dispose();
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ScheduleProvider>();
    
    if (provider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final departments = provider.departmentObjects;
    final bookings = provider.bookings;
    
    // ساعات العمل من 10 صباحاً إلى 12 مساءً (14 ساعة)
    final hours = List.generate(14, (i) => 10 + i);

    return GestureDetector(
      onScaleStart: (details) {
        _baseHourHeight = provider.hourHeight;
      },
      onScaleUpdate: (details) {
        if (details.pointerCount == 2) {
          final newHeight = _baseHourHeight * details.verticalScale;
          provider.setZoom(newHeight);
        }
      },
      child: Column(
        children: [
          // شريط التحكم العلوي
          _buildControlBar(provider),
          
          // الجدول الرئيسي
          Expanded(
            child: Row(
              children: [
                // عمود أسماء الأقسام (ثابت)
                _buildDepartmentsColumn(departments, provider.hourHeight),
                
                // الجدول مع الأوقات
                Expanded(
                  child: Column(
                    children: [
                      // صف الأوقات (ثابت)
                      _buildTimeHeader(hours, provider.hourHeight),
                      
                      // خلايا الحجوزات
                      Expanded(
                        child: SingleChildScrollView(
                          controller: _verticalScrollController,
                          child: SingleChildScrollView(
                            controller: _horizontalScrollController,
                            scrollDirection: Axis.horizontal,
                            child: _buildGrid(departments, hours, bookings, provider.hourHeight),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // شريط التحكم العلوي
  Widget _buildControlBar(ScheduleProvider provider) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: AppTheme.surface,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            // اختيار القسم
            SizedBox(
              width: 150,
              child: DropdownButtonFormField<String>(
                value: provider.selectedDepartmentId,
                decoration: const InputDecoration(
                  labelText: 'القسم',
                  contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  isDense: true,
                ),
                items: provider.departments.entries.map((e) {
                  return DropdownMenuItem(value: e.key, child: Text(e.value, style: const TextStyle(fontSize: 12)));
                }).toList(),
                onChanged: (val) => provider.setDepartment(val!),
              ),
            ),
            const SizedBox(width: 12),
            
            // أزرار التكبير والتصغير
            IconButton(
              icon: const Icon(Icons.zoom_out, size: 20),
              onPressed: () => provider.setZoom(provider.hourHeight - 20),
              tooltip: 'تصغير',
            ),
            SizedBox(
              width: 100,
              child: Slider(
                value: provider.hourHeight,
                min: 30.0,
                max: 300.0,
                onChanged: (val) => provider.setZoom(val),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.zoom_in, size: 20),
              onPressed: () => provider.setZoom(provider.hourHeight + 20),
              tooltip: 'تكبير',
            ),
            const SizedBox(width: 12),
            
            // التنقل بين التواريخ
            IconButton(
              icon: const Icon(Icons.chevron_right, size: 24),
              onPressed: () => provider.changeDate(provider.selectedDate.subtract(const Duration(days: 1))),
            ),
            InkWell(
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: provider.selectedDate,
                  firstDate: DateTime.now().subtract(const Duration(days: 365)),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (date != null) provider.changeDate(date);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  DateFormat('d/M/yyyy', 'ar').format(provider.selectedDate),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_left, size: 24),
              onPressed: () => provider.changeDate(provider.selectedDate.add(const Duration(days: 1))),
            ),
            const SizedBox(width: 8),
            
            // زر التحديث
            IconButton(
              icon: const Icon(Icons.refresh, size: 20),
              onPressed: () => provider.loadData(),
              tooltip: 'تحديث',
            ),
          ],
        ),
      ),
    );
  }

  // عمود أسماء الأقسام على الجانب
  Widget _buildDepartmentsColumn(List<Department> departments, double cellHeight) {
    return Container(
      width: 120,
      color: AppTheme.surface,
      child: Column(
        children: [
          // خلية فارغة للمحاذاة مع صف الأوقات
          Container(
            height: 50,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.white.withAlpha(26))),
            ),
            child: const Text('القسم', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          ),
          
          // أسماء الأقسام
          Expanded(
            child: SingleChildScrollView(
              // لا نستخدم controller هنا لتجنب خطأ multiple ScrollPosition
              child: Column(
                children: departments.map((dept) {
                  return Container(
                    height: cellHeight,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: dept.color.withAlpha(26),
                      border: Border(bottom: BorderSide(color: Colors.white.withAlpha(13))),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: dept.color,
                          child: Icon(Icons.business, color: Colors.white, size: 14),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            dept.name,
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 2,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // صف الأوقات في الأعلى
  Widget _buildTimeHeader(List<int> hours, double cellWidth) {
    return Container(
      height: 50,
      color: AppTheme.surface,
      child: SingleChildScrollView(
        // لا نستخدم controller هنا لتجنب خطأ multiple ScrollPosition
        scrollDirection: Axis.horizontal,
        child: Row(
          children: hours.map((hour) {
            final hour12 = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
            final period = hour >= 12 ? 'م' : 'ص';
            
            return Container(
              width: cellWidth,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(color: Colors.white.withAlpha(26)),
                  bottom: BorderSide(color: Colors.white.withAlpha(26)),
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('$hour12', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  Text(period, style: TextStyle(fontSize: 10, color: Colors.white.withAlpha(128))),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // الجدول الرئيسي (Grid) - حسب الأقسام
  Widget _buildGrid(List<Department> departments, List<int> hours, List<Booking> bookings, double cellSize) {
    return Column(
      children: departments.map((dept) {
        // الحجوزات لهذا القسم (حسب department_id)
        final deptBookings = bookings.where((b) => b.departmentId == dept.id).toList();
        
        return SizedBox(
          height: cellSize,
          child: Row(
            children: hours.map((hour) {
              final hourBookings = deptBookings.where((b) => b.startTime.hour == hour).toList();
              return _buildCell(dept, hour, hourBookings, cellSize);
            }).toList(),
          ),
        );
      }).toList(),
    );
  }

  // خلية واحدة في الجدول
  Widget _buildCell(Department dept, int hour, List<Booking> bookings, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(color: Colors.white.withAlpha(13)),
          bottom: BorderSide(color: Colors.white.withAlpha(13)),
        ),
      ),
      child: bookings.isEmpty
          ? _buildEmptyCell(dept, hour)
          : _buildBookingsCell(bookings, dept.color),
    );
  }

  // خلية فارغة (للحجز الجديد)
  Widget _buildEmptyCell(Department dept, int hour) {
    return InkWell(
      onTap: () => _openBookingDialog(dept, hour),
      child: Container(
        color: Colors.transparent,
        child: Center(
          child: Icon(Icons.add, color: Colors.white.withAlpha(26), size: 16),
        ),
      ),
    );
  }

  // خلية تحتوي على حجوزات
  Widget _buildBookingsCell(List<Booking> bookings, Color doctorColor) {
    if (bookings.length == 1) {
      return _buildBookingChip(bookings.first);
    }
    
    // حجوزات متعددة في نفس الساعة
    return Column(
      children: bookings.take(3).map((b) => Expanded(child: _buildBookingChip(b))).toList(),
    );
  }

  // شريحة الحجز داخل الخلية
  Widget _buildBookingChip(Booking booking) {
    final statusColor = _getStatusColor(booking.status);
    
    return GestureDetector(
      onTap: () => _showBookingOptions(booking),
      child: Container(
        margin: const EdgeInsets.all(2),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [statusColor.withAlpha(200), statusColor.withAlpha(100)],
          ),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: statusColor, width: 1),
        ),
        child: Center(
          child: Text(
            booking.patientName,
            style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'completed': return Colors.green;
      case 'arrived': return Colors.blue;
      case 'booked':
      case 'scheduled': return Colors.orange;
      case 'cancelled': return Colors.red;
      case 'no_show': return Colors.grey;
      case 'in_session': return Colors.cyan;
      default: return Colors.purple;
    }
  }

  void _openBookingDialog(Department dept, int hour) async {
    final date = context.read<ScheduleProvider>().selectedDate;
    final slotDate = DateTime(date.year, date.month, date.day, hour, 0);
    
    final scheduleProvider = context.read<ScheduleProvider>();
    AdminProvider? adminProvider;
    try {
      adminProvider = context.read<AdminProvider>();
    } catch (_) {}

    await showDialog(
      context: context,
      builder: (ctx) => MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: scheduleProvider),
          if (adminProvider != null) ChangeNotifierProvider.value(value: adminProvider),
        ],
        child: BookingDialog(
          preselectedDepartmentId: dept.id,
          initialDate: slotDate,
        ),
      ),
    );
  }

  void _showBookingOptions(Booking booking) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Color(0xFF1E1E2E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // معلومات الحجز
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: _getStatusColor(booking.status),
                  child: Text(booking.patientName[0], style: const TextStyle(color: Colors.white)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(booking.patientName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      Text('د. ${booking.doctorName}', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                      Text(DateFormat('h:mm a').format(booking.startTime), style: const TextStyle(color: Colors.white70, fontSize: 12)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getStatusColor(booking.status).withAlpha(51),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(_getStatusLabel(booking.status), style: TextStyle(color: _getStatusColor(booking.status), fontSize: 11)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(color: Colors.white24),
            const SizedBox(height: 8),
            
            // الأزرار حسب الحالة
            if (booking.status == 'scheduled' || booking.status == 'booked') ...[
              _actionButton('استلام المبلغ (وصل)', Icons.payment, Colors.green, () async {
                Navigator.pop(ctx);
                await context.read<ScheduleProvider>().updateBookingStatus(booking.id, 'arrived');
              }),
              _actionButton('تأجيل الموعد', Icons.access_time, Colors.orange, () {
                Navigator.pop(ctx);
                // TODO: Show postpone dialog
              }),
              _actionButton('طلب إلغاء', Icons.cancel, Colors.red, () {
                Navigator.pop(ctx);
                // TODO: Show cancel request dialog
              }),
            ] else if (booking.status == 'arrived') ...[
              _actionButton('إدخال للطبيب (بدء الجلسة)', Icons.login, Colors.blue, () async {
                Navigator.pop(ctx);
                await context.read<ScheduleProvider>().updateBookingStatus(booking.id, 'in_session');
              }),
            ] else if (booking.status == 'in_session') ...[
              _actionButton('إنهاء الجلسة', Icons.stop, Colors.red, () async {
                Navigator.pop(ctx);
                await context.read<ScheduleProvider>().updateBookingStatus(booking.id, 'completed');
              }),
            ],
            
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _actionButton(String label, IconData icon, Color color, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(label, style: const TextStyle(fontSize: 14)),
        onTap: onTap,
        tileColor: color.withAlpha(13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'booked': return 'محجوز';
      case 'scheduled': return 'مجدول';
      case 'arrived': return 'وصل';
      case 'in_session': return 'في الجلسة';
      case 'completed': return 'مكتمل';
      case 'cancelled': return 'ملغي';
      default: return status;
    }
  }
}
