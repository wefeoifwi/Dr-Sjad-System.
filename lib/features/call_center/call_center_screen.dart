import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';
import '../../core/responsive_layout.dart';
import '../schedule/schedule_provider.dart';
import '../schedule/models.dart';
import '../schedule/booking_dialog.dart';
import '../admin/admin_provider.dart';
import '../follow_up/follow_up_provider.dart';
import '../notifications/notification_badge.dart';

class CallCenterScreen extends StatefulWidget {
  const CallCenterScreen({super.key});

  @override
  State<CallCenterScreen> createState() => _CallCenterScreenState();
}

class _CallCenterScreenState extends State<CallCenterScreen> {
  String _filterStatus = 'all';
  String _filterDepartment = 'all';
  String _searchQuery = '';
  DateTime _selectedDate = DateTime.now();
  final _searchController = TextEditingController();
  
  // Timer للتحقق من تغيير البيانات
  Timer? _refreshTimer;
  int _lastBookingCount = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ScheduleProvider>().loadData();
    });
    
    // Timer يتحقق كل ثانية من تغيير عدد الحجوزات
    _refreshTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        final provider = context.read<ScheduleProvider>();
        if (provider.bookings.length != _lastBookingCount) {
          debugPrint('🔄 CallCenter Force rebuild: $_lastBookingCount → ${provider.bookings.length}');
          _lastBookingCount = provider.bookings.length;
          setState(() {});
        }
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _refreshTimer?.cancel();
    super.dispose();
  }

  List<Booking> _getFilteredBookings(List<Booking> bookings) {
    var filtered = bookings.toList();

    // فلترة حسب التاريخ
    filtered = filtered.where((b) =>
      b.startTime.year == _selectedDate.year &&
      b.startTime.month == _selectedDate.month &&
      b.startTime.day == _selectedDate.day
    ).toList();

    // فلترة حسب الحالة
    if (_filterStatus != 'all') {
      if (_filterStatus == 'pending') {
        filtered = filtered.where((b) => b.status == 'booked' || b.status == 'scheduled').toList();
      } else {
        filtered = filtered.where((b) => b.status == _filterStatus).toList();
      }
    }

    // فلترة حسب القسم
    if (_filterDepartment != 'all') {
      filtered = filtered.where((b) => b.departmentId == _filterDepartment).toList();
    }

    // البحث بالاسم
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((b) =>
        b.patientName.toLowerCase().contains(_searchQuery.toLowerCase())
      ).toList();
    }

    // ترتيب حسب الوقت
    filtered.sort((a, b) => a.startTime.compareTo(b.startTime));
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ScheduleProvider>();
    final adminProvider = context.watch<AdminProvider>();
    final bookings = _getFilteredBookings(provider.bookings);
    final isMobile = ResponsiveLayout.isMobile(context);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        title: const Text('الكول سنتر'),
        centerTitle: true,
        actions: [
          const NotificationBadge(),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => provider.loadData(),
            tooltip: 'تحديث',
          ),
        ],
      ),
      body: Column(
        children: [
          // شريط الفلاتر
          _buildFiltersBar(provider.departmentObjects, isMobile),
          
          // قائمة الحجوزات
          Expanded(
            child: provider.isLoading
              ? const Center(child: CircularProgressIndicator())
              : bookings.isEmpty
                ? _buildEmptyState()
                : _buildBookingsList(bookings, isMobile),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.primary,
        onPressed: _showNewBookingDialog,
        icon: const Icon(Icons.add),
        label: const Text('حجز جديد'),
      ),
    );
  }

  Widget _buildFiltersBar(List<Department> departments, bool isMobile) {
    final isToday = _selectedDate.year == DateTime.now().year &&
                    _selectedDate.month == DateTime.now().month &&
                    _selectedDate.day == DateTime.now().day;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border(bottom: BorderSide(color: Colors.white.withAlpha(26))),
      ),
      child: Column(
        children: [
          // التاريخ
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_right, size: 20),
                onPressed: () => setState(() => _selectedDate = _selectedDate.subtract(const Duration(days: 1))),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate,
                    firstDate: DateTime.now().subtract(const Duration(days: 365)),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (picked != null) setState(() => _selectedDate = picked);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isToday ? AppTheme.primary.withAlpha(26) : Colors.white10,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: isToday ? AppTheme.primary : Colors.white24),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.calendar_today, size: 14, color: isToday ? AppTheme.primary : Colors.white70),
                      const SizedBox(width: 4),
                      Text(
                        DateFormat('yyyy/MM/dd', 'ar').format(_selectedDate),
                        style: TextStyle(fontSize: 12, color: isToday ? AppTheme.primary : Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_left, size: 20),
                onPressed: () => setState(() => _selectedDate = _selectedDate.add(const Duration(days: 1))),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              if (!isToday) ...[
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () => setState(() => _selectedDate = DateTime.now()),
                  child: const Text('اليوم'),
                ),
              ],
            ],
          ),
          
          const SizedBox(height: 12),
          
          // البحث
          TextField(
            controller: _searchController,
            onChanged: (v) => setState(() => _searchQuery = v),
            decoration: InputDecoration(
              hintText: 'بحث بالاسم...',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                  )
                : null,
              isDense: true,
              filled: true,
              fillColor: Colors.white10,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),
          
          const SizedBox(height: 12),
          
          // الفلاتر
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('الكل', 'all', _filterStatus, (v) => setState(() => _filterStatus = v)),
                const SizedBox(width: 8),
                _buildFilterChip('انتظار', 'pending', _filterStatus, (v) => setState(() => _filterStatus = v), color: Colors.orange),
                const SizedBox(width: 8),
                _buildFilterChip('تم الدفع', 'arrived', _filterStatus, (v) => setState(() => _filterStatus = v), color: Colors.green),
                const SizedBox(width: 8),
                _buildFilterChip('بالجلسة', 'in_session', _filterStatus, (v) => setState(() => _filterStatus = v), color: Colors.blue),
                const SizedBox(width: 8),
                _buildFilterChip('مكتمل', 'completed', _filterStatus, (v) => setState(() => _filterStatus = v), color: Colors.grey),
                
                const SizedBox(width: 16),
                
                // فلتر القسم
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _filterDepartment,
                      dropdownColor: AppTheme.surface,
                      isDense: true,
                      items: [
                        const DropdownMenuItem(value: 'all', child: Text('كل الأقسام')),
                        ...departments.map((d) => DropdownMenuItem(
                          value: d.id,
                          child: Text(d.name),
                        )),
                      ],
                      onChanged: (v) => setState(() => _filterDepartment = v ?? 'all'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value, String current, Function(String) onSelect, {Color? color}) {
    final isSelected = current == value;
    return InkWell(
      onTap: () => onSelect(value),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? (color ?? AppTheme.primary).withAlpha(26) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? (color ?? AppTheme.primary) : Colors.white24),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? (color ?? AppTheme.primary) : Colors.white70,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.event_available, size: 64, color: Colors.white.withAlpha(51)),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isNotEmpty ? 'لا توجد نتائج للبحث' : 'لا توجد مواعيد',
            style: const TextStyle(color: Colors.white38, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildBookingsList(List<Booking> bookings, bool isMobile) {
    return ListView.builder(
      padding: EdgeInsets.all(isMobile ? 8 : 16),
      itemCount: bookings.length,
      itemBuilder: (context, index) => _buildBookingCard(bookings[index], isMobile),
    );
  }

  Widget _buildBookingCard(Booking booking, bool isMobile) {
    // تحديد الحالة والأزرار المتاحة
    final isPending = booking.status == 'booked' || booking.status == 'scheduled';
    final isArrived = booking.status == 'arrived';
    final isInSession = booking.status == 'in_session';
    final isCompleted = booking.status == 'completed';
    
    Color statusColor;
    String statusText;
    IconData statusIcon;
    
    if (isPending) {
      statusColor = Colors.orange;
      statusText = 'انتظار الدفع';
      statusIcon = Icons.pending_actions;
    } else if (isArrived) {
      statusColor = Colors.green;
      statusText = 'تم الدفع ✓';
      statusIcon = Icons.check_circle;
    } else if (isInSession) {
      statusColor = Colors.blue;
      statusText = 'بالجلسة';
      statusIcon = Icons.medical_services;
    } else if (isCompleted) {
      statusColor = Colors.grey;
      statusText = 'مكتمل';
      statusIcon = Icons.done_all;
    } else {
      statusColor = Colors.red;
      statusText = booking.status;
      statusIcon = Icons.cancel;
    }

    return Card(
      color: AppTheme.surface,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: statusColor.withAlpha(77)),
      ),
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 12 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // الصف الأول: الوقت والاسم والحالة
            Row(
              children: [
                // الوقت
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withAlpha(26),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    AppTheme.formatTime12h(booking.startTime),
                    style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
                const SizedBox(width: 12),
                
                // الاسم والطبيب
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        booking.patientName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'د. ${(booking.doctorName ?? "").isNotEmpty ? booking.doctorName : "غير محدد"}',
                        style: const TextStyle(color: Colors.white54, fontSize: 11),
                      ),
                      if (booking.createdByName != null && booking.createdByName!.isNotEmpty)
                        Text(
                          '📋 بواسطة: ${booking.createdByName}',
                          style: TextStyle(color: Colors.cyan.withAlpha(180), fontSize: 10),
                        ),
                    ],
                  ),
                ),
                
                // الحالة
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withAlpha(26),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 12, color: statusColor),
                      const SizedBox(width: 4),
                      Text(statusText, style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // الصف الثاني: الأزرار الديناميكية
            _buildActionButtons(booking, isPending, isArrived, isInSession, isCompleted, isMobile),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(Booking booking, bool isPending, bool isArrived, bool isInSession, bool isCompleted, bool isMobile) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        // حالة انتظار الدفع
        if (isPending) ...[
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.orange,
              padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 16, vertical: 8),
            ),
            onPressed: () => _showCancelDialog(booking),
            icon: const Icon(Icons.cancel, size: 16),
            label: const Text('إلغاء', style: TextStyle(fontSize: 12)),
          ),
          Text('⏳ بانتظار الدفع من الاستقبال', style: TextStyle(color: Colors.orange.withAlpha(180), fontSize: 11)),
        ],
        
        // حالة تم الدفع - يمكن إدخال للدكتور
        if (isArrived)
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 20, vertical: 8),
            ),
            onPressed: () => _admitToDoctor(booking),
            icon: const Icon(Icons.login, size: 16),
            label: const Text('إدخال للدكتور', style: TextStyle(fontSize: 12)),
          ),
        
        // حالة بالجلسة - يمكن إنهاء الجلسة
        if (isInSession)
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 20, vertical: 8),
            ),
            onPressed: () => _showEndSessionDialog(booking),
            icon: const Icon(Icons.logout, size: 16),
            label: const Text('إنهاء الجلسة', style: TextStyle(fontSize: 12)),
          ),
        
        // حالة مكتمل - يمكن إضافة متابعة
        if (isCompleted) ...[
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.primary,
              padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 16, vertical: 8),
            ),
            onPressed: () => _showAddFollowUpDialog(booking),
            icon: const Icon(Icons.event_repeat, size: 16),
            label: const Text('إضافة متابعة', style: TextStyle(fontSize: 12)),
          ),
          const Icon(Icons.check_circle, color: Colors.grey, size: 20),
        ],
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ACTIONS
  // ═══════════════════════════════════════════════════════════════════════════

  void _showNewBookingDialog() {
    final scheduleProvider = context.read<ScheduleProvider>();
    final adminProvider = context.read<AdminProvider>();
    
    showDialog(
      context: context,
      builder: (dialogContext) => MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: scheduleProvider),
          ChangeNotifierProvider.value(value: adminProvider),
        ],
        child: BookingDialog(initialDate: scheduleProvider.selectedDate),
      ),
    );
  }

  Future<void> _admitToDoctor(Booking booking) async {
    // تأكيد الإدخال
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('إدخال للدكتور'),
        content: Text('هل تريد إدخال "${booking.patientName}" للدكتور؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('نعم، إدخال'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await context.read<ScheduleProvider>().updateBookingStatus(booking.id, 'in_session');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✓ تم إدخال ${booking.patientName} للدكتور'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  void _showEndSessionDialog(Booking booking) {
    bool addFollowUp = false;
    DateTime? followUpDate;
    
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppTheme.surface,
          title: const Text('إنهاء الجلسة'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('هل تريد إنهاء جلسة "${booking.patientName}"؟'),
              const SizedBox(height: 16),
              
              // خيار إضافة متابعة
              SwitchListTile(
                title: const Text('إضافة متابعة'),
                subtitle: const Text('جدولة موعد قادم'),
                value: addFollowUp,
                onChanged: (v) => setDialogState(() => addFollowUp = v),
                activeTrackColor: AppTheme.primary,
              ),
              
              if (addFollowUp) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now().add(const Duration(days: 7)),
                      firstDate: DateTime.now().add(const Duration(days: 1)),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null) {
                      setDialogState(() => followUpDate = picked);
                    }
                  },
                  icon: const Icon(Icons.calendar_today),
                  label: Text(
                    followUpDate == null 
                      ? 'اختر يوم الموعد القادم' 
                      : DateFormat('d/M/yyyy').format(followUpDate!),
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
              onPressed: () async {
                Navigator.pop(ctx);
                await _endSession(booking, addFollowUp, followUpDate);
              },
              child: const Text('إنهاء الجلسة'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _endSession(Booking booking, bool addFollowUp, DateTime? followUpDate) async {
    // تحديث الحالة إلى مكتمل
    await context.read<ScheduleProvider>().updateBookingStatus(booking.id, 'completed');
    
    // إضافة متابعة إذا طلب
    if (addFollowUp && followUpDate != null) {
      await context.read<FollowUpProvider>().addToFollowUp(
        patientId: booking.patientId,
        doctorId: booking.effectiveDoctorId ?? '',
        scheduledDate: followUpDate,
        createdBy: 'call_center',
      );
    }
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(addFollowUp 
            ? '✓ تم إنهاء الجلسة وإضافة متابعة في ${DateFormat('d/M').format(followUpDate!)}'
            : '✓ تم إنهاء الجلسة'),
          backgroundColor: Colors.blue,
        ),
      );
    }
  }

  void _showAddFollowUpDialog(Booking booking) {
    DateTime? followUpDate;
    
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppTheme.surface,
          title: const Text('إضافة متابعة'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('إضافة متابعة لـ "${booking.patientName}"'),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now().add(const Duration(days: 7)),
                    firstDate: DateTime.now().add(const Duration(days: 1)),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (picked != null) {
                    setDialogState(() => followUpDate = picked);
                  }
                },
                icon: const Icon(Icons.calendar_today),
                label: Text(
                  followUpDate == null 
                    ? 'اختر يوم الموعد القادم' 
                    : DateFormat('d/M/yyyy').format(followUpDate!),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: followUpDate == null ? null : () async {
                Navigator.pop(ctx);
                await context.read<FollowUpProvider>().addToFollowUp(
                  patientId: booking.patientId,
                  doctorId: booking.effectiveDoctorId ?? '',
                  scheduledDate: followUpDate!,
                  createdBy: 'call_center',
                );
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('✓ تم إضافة متابعة في ${DateFormat('d/M').format(followUpDate!)}'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              },
              child: const Text('إضافة'),
            ),
          ],
        ),
      ),
    );
  }

  void _showCancelDialog(Booking booking) {
    final reasonController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('إلغاء الحجز'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('هل تريد إلغاء حجز "${booking.patientName}"؟'),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'سبب الإلغاء',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('تراجع')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              await context.read<ScheduleProvider>().requestCancellation(
                booking.id, 
                reasonController.text.isNotEmpty ? reasonController.text : 'بدون سبب',
              );
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('✓ تم إرسال طلب الإلغاء للمدير'),
                    backgroundColor: Colors.orange,
                  ),
                );
              }
            },
            child: const Text('إلغاء الحجز'),
          ),
        ],
      ),
    );
  }
}
