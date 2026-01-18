import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme.dart';
import '../admin/admin_provider.dart';
import '../schedule/schedule_provider.dart';
import '../schedule/models.dart';
import '../schedule/booking_dialog.dart';
import '../notifications/notification_badge.dart';

class ReceptionDashboard extends StatefulWidget {
  const ReceptionDashboard({super.key});

  @override
  State<ReceptionDashboard> createState() => _ReceptionDashboardState();
}

class _ReceptionDashboardState extends State<ReceptionDashboard> {
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
          debugPrint('🔄 Force rebuild: $_lastBookingCount → ${provider.bookings.length}');
          _lastBookingCount = provider.bookings.length;
          setState(() {}); // إجبار إعادة البناء
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
    // فلترة حسب التاريخ
    debugPrint('🔍 فلترة: ${bookings.length} حجز، التاريخ المحدد: ${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}');
    var filtered = bookings.where((b) {
      final match = b.startTime.year == _selectedDate.year &&
        b.startTime.month == _selectedDate.month &&
        b.startTime.day == _selectedDate.day;
      if (!match) {
        debugPrint('   ❌ ${b.patientName}: ${b.startTime.day}/${b.startTime.month} != ${_selectedDate.day}/${_selectedDate.month}');
      }
      return match;
    }).toList();
    debugPrint('   ✅ بعد الفلترة: ${filtered.length} حجز');

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
    
    debugPrint('📺 Reception rebuild: ${provider.bookings.length} total, ${bookings.length} filtered for ${_selectedDate.day}/${_selectedDate.month}');
    
    // إحصائيات سريعة
    final todayAll = provider.bookings.where((b) =>
      b.startTime.year == _selectedDate.year &&
      b.startTime.month == _selectedDate.month &&
      b.startTime.day == _selectedDate.day
    ).toList();
    
    final pending = todayAll.where((b) => b.status == 'booked' || b.status == 'scheduled').length;
    final arrived = todayAll.where((b) => b.status == 'arrived').length;
    final completed = todayAll.where((b) => b.status == 'completed').length;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Column(
        children: [
          // شريط الأدوات العلوي
          _buildTopBar(pending, arrived, completed, provider.departmentObjects),
          
          // المحتوى الرئيسي
          Expanded(
            child: provider.isLoading
              ? const Center(child: CircularProgressIndicator())
              : bookings.isEmpty
                ? _buildEmptyState()
                : _buildBookingsList(bookings),
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

  Widget _buildTopBar(int pending, int arrived, int completed, List<Department> departments) {
    final isToday = _selectedDate.year == DateTime.now().year &&
                    _selectedDate.month == DateTime.now().month &&
                    _selectedDate.day == DateTime.now().day;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border(bottom: BorderSide(color: Colors.white.withAlpha(26))),
      ),
      child: Column(
        children: [
          // الصف الأول: العنوان والتاريخ
          Row(
            children: [
              Flexible(
                child: Text('لوحة الاستقبال', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
              ),
              const SizedBox(width: 8),
              
              // التنقل في التاريخ
              IconButton(
                icon: const Icon(Icons.chevron_right, size: 20),
                onPressed: () {
                  setState(() => _selectedDate = _selectedDate.subtract(const Duration(days: 1)));
                  context.read<ScheduleProvider>().changeDate(_selectedDate);
                },
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              InkWell(
                onTap: () => _selectDate(),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                        DateFormat('d/M', 'ar').format(_selectedDate),
                        style: TextStyle(fontSize: 12, color: isToday ? AppTheme.primary : Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_left, size: 20),
                onPressed: () {
                  setState(() => _selectedDate = _selectedDate.add(const Duration(days: 1)));
                  context.read<ScheduleProvider>().changeDate(_selectedDate);
                },
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              Spacer(),
              const NotificationBadge(),
              const SizedBox(width: 8),
              if (!isToday) ...[
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () {
                    setState(() => _selectedDate = DateTime.now());
                    context.read<ScheduleProvider>().changeDate(_selectedDate);
                  },
                  child: const Text('اليوم'),
                ),
              ],
              
              // زر التحديث
              const SizedBox(width: 16),
              IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: 'تحديث',
                onPressed: () => context.read<ScheduleProvider>().loadData(),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // الصف الثاني: البحث والفلاتر
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // البحث
              SizedBox(
                width: 200,
                child: TextField(
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
              ),
              
              // فلتر الحالة
              _buildFilterChip('الكل', 'all', _filterStatus, (v) => setState(() => _filterStatus = v)),
              _buildFilterChip('بانتظار', 'pending', _filterStatus, (v) => setState(() => _filterStatus = v), color: Colors.orange),
              _buildFilterChip('وصلوا', 'arrived', _filterStatus, (v) => setState(() => _filterStatus = v), color: Colors.green),
              _buildFilterChip('مكتمل', 'completed', _filterStatus, (v) => setState(() => _filterStatus = v), color: Colors.blue),
              
              // فلتر القسم
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _filterDepartment,
                    dropdownColor: AppTheme.surface,
                    hint: const Text('القسم'),
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
              
              // الإحصائيات السريعة
              _buildMiniStat('بانتظار', pending, Colors.orange),
              _buildMiniStat('وصلوا', arrived, Colors.green),
              _buildMiniStat('مكتمل', completed, Colors.blue),
            ],
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

  Widget _buildMiniStat(String label, int value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withAlpha(26),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Text('$value', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: color, fontSize: 11)),
        ],
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

  Widget _buildBookingsList(List<Booking> bookings) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: bookings.length,
      itemBuilder: (context, index) => _buildBookingCard(bookings[index]),
    );
  }

  Widget _buildBookingCard(Booking booking) {
    final canPay = booking.status == 'booked' || booking.status == 'scheduled';
    final isArrived = booking.status == 'arrived';
    final isCompleted = booking.status == 'completed';
    
    Color statusColor;
    String statusText;
    IconData statusIcon;
    
    if (canPay) {
      statusColor = Colors.orange;
      statusText = 'بانتظار الدفع';
      statusIcon = Icons.pending_actions;
    } else if (isArrived) {
      statusColor = Colors.green;
      statusText = 'في العيادة';
      statusIcon = Icons.check_circle;
    } else if (isCompleted) {
      statusColor = Colors.blue;
      statusText = 'مكتمل';
      statusIcon = Icons.done_all;
    } else {
      statusColor = Colors.grey;
      statusText = booking.status;
      statusIcon = Icons.help;
    }

    return Card(
      color: AppTheme.surface,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: statusColor.withAlpha(51)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showPatientDetails(booking),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // الوقت
              Container(
                width: 60,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: statusColor.withAlpha(26),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Text(
                      AppTheme.formatTime12h(booking.startTime, showMinutes: false),
                      style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    Text(
                      booking.startTime.minute.toString().padLeft(2, '0'),
                      style: TextStyle(color: statusColor.withAlpha(180), fontSize: 11),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(width: 16),
              
              // معلومات المريض
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            booking.patientName,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          decoration: BoxDecoration(
                            color: statusColor.withAlpha(26),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(statusIcon, size: 10, color: statusColor),
                              const SizedBox(width: 2),
                              Text(statusText, style: TextStyle(color: statusColor, fontSize: 9, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(Icons.medical_services, size: 12, color: Colors.white38),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            'د. ${(booking.doctorName ?? "").isNotEmpty ? booking.doctorName : "غير محدد"}',
                            style: const TextStyle(color: Colors.white54, fontSize: 11),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              // الأزرار
              if (canPay)
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                  onPressed: () => _showPaymentDialog(booking),
                  icon: const Icon(Icons.payment, size: 18),
                  label: const Text('استلام ودخول'),
                )
              else if (isArrived)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.green.withAlpha(26),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.hourglass_top, color: Colors.green, size: 18),
                      SizedBox(width: 4),
                      Text('في الانتظار', style: TextStyle(color: Colors.green, fontSize: 12)),
                    ],
                  ),
                )
              else
                const Icon(Icons.check_circle, color: Colors.blue, size: 24),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
      context.read<ScheduleProvider>().changeDate(picked);
    }
  }

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
        child: BookingDialog(initialDate: _selectedDate),
      ),
    ).then((_) => context.read<ScheduleProvider>().loadData());
  }

  void _showPaymentDialog(Booking booking) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _AdvancedPaymentDialog(
        booking: booking,
        onSuccess: () {
          // تحديث فوري بدون إعادة تحميل
          context.read<ScheduleProvider>().loadData();
        },
      ),
    );
  }

  void _showPatientDetails(Booking booking) {
    showDialog(
      context: context,
      builder: (ctx) => _PatientDetailsDialog(booking: booking),
    );
  }

  // ignore: unused_element - kept for potential future use
  Future<void> _markComplete(Booking booking) async {
    await context.read<ScheduleProvider>().updateBookingStatus(booking.id, 'completed');
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// نافذة الدفع المتقدمة
// ══════════════════════════════════════════════════════════════════════════════
class _AdvancedPaymentDialog extends StatefulWidget {
  final Booking booking;
  final VoidCallback onSuccess;

  const _AdvancedPaymentDialog({required this.booking, required this.onSuccess});

  @override
  State<_AdvancedPaymentDialog> createState() => _AdvancedPaymentDialogState();
}

class _AdvancedPaymentDialogState extends State<_AdvancedPaymentDialog> {
  final _amountController = TextEditingController(text: '25000');
  final _notesController = TextEditingController();
  String _paymentMethod = 'cash';
  bool _isProcessing = false;
  List<Map<String, dynamic>> _previousVisits = [];
  Map<String, dynamic>? _patientInfo;
  bool _loadingPatient = true;
  
  // إضافة اختيار الطبيب
  String? _selectedDoctorId;
  List<Doctor> _availableDoctors = [];

  @override
  void initState() {
    super.initState();
    _loadPatientData();
    _loadDoctorsForDepartment();
  }

  Future<void> _loadDoctorsForDepartment() async {
    try {
      final supabase = Supabase.instance.client;
      final deptId = widget.booking.departmentId;
      
      if (deptId != null) {
        // جلب الأطباء من القسم
        final data = await supabase
            .from('profiles')
            .select('id, name, avatar_url')
            .eq('role', 'doctor')
            .eq('department_id', deptId);
        
        if (mounted) {
          setState(() {
            _availableDoctors = (data as List).map((d) => Doctor(
              id: d['id'],
              name: d['name'] ?? 'طبيب',
              departmentId: deptId,
              color: Colors.teal,
            )).toList();
            
            if (_availableDoctors.isNotEmpty) {
              _selectedDoctorId = _availableDoctors.first.id;
            }
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading doctors: $e');
    }
  }

  Future<void> _loadPatientData() async {
    try {
      final supabase = Supabase.instance.client;
      
      // جلب معلومات المريض
      final patientRes = await supabase
          .from('patients')
          .select()
          .eq('id', widget.booking.patientId)
          .maybeSingle();
      
      // جلب الزيارات السابقة
      final visitsRes = await supabase
          .from('sessions')
          .select('*, services(name)')
          .eq('patient_id', widget.booking.patientId)
          .neq('id', widget.booking.id)
          .order('start_time', ascending: false)
          .limit(5);

      if (mounted) {
        setState(() {
          _patientInfo = patientRes;
          _previousVisits = List<Map<String, dynamic>>.from(visitsRes);
          _loadingPatient = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loadingPatient = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 550,
        constraints: const BoxConstraints(maxHeight: 650),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.green.withAlpha(26),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.payment, color: Colors.green, size: 28),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text('استلام الدفع وتسجيل الدخول', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: _isProcessing ? null : () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            
            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // معلومات المريض
                    _buildPatientInfoSection(),
                    
                    const SizedBox(height: 20),
                    const Divider(),
                    const SizedBox(height: 20),
                    
                    // الزيارات السابقة
                    if (_previousVisits.isNotEmpty) ...[
                      _buildPreviousVisitsSection(),
                      const SizedBox(height: 20),
                      const Divider(),
                      const SizedBox(height: 20),
                    ],
                    
                    // الدفع
                    _buildPaymentSection(),
                  ],
                ),
              ),
            ),
            
            // Actions
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black12,
                border: Border(top: BorderSide(color: Colors.white.withAlpha(26))),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isProcessing ? null : () => Navigator.pop(context),
                      child: const Text('إلغاء'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: _isProcessing ? null : _processPayment,
                      icon: _isProcessing
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.check),
                      label: Text(_isProcessing ? 'جاري المعالجة...' : 'تأكيد الاستلام'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPatientInfoSection() {
    if (_loadingPatient) {
      return const Center(child: CircularProgressIndicator());
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primary.withAlpha(26),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primary.withAlpha(51)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: AppTheme.primary,
                radius: 24,
                child: Text(
                  widget.booking.patientName.isNotEmpty ? widget.booking.patientName[0].toUpperCase() : '?',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.booking.patientName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    Text(
                      'الموعد: ${AppTheme.formatTime12h(widget.booking.startTime)} - د. ${widget.booking.doctorName}',
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_patientInfo != null) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                if (_patientInfo!['phone'] != null)
                  _infoChip(Icons.phone, _patientInfo!['phone']),
                if (_patientInfo!['gender'] != null)
                  _infoChip(Icons.person, _patientInfo!['gender'] == 'male' ? 'ذكر' : 'أنثى'),
                if (_patientInfo!['age'] != null)
                  _infoChip(Icons.cake, '${_patientInfo!['age']} سنة'),
                _infoChip(Icons.history, '${_previousVisits.length} زيارات سابقة'),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _infoChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white54),
          const SizedBox(width: 4),
          Text(text, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildPreviousVisitsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('آخر الزيارات', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ...(_previousVisits.take(3).map((v) => Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(13),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Text(
                DateFormat('d/M/yyyy').format(DateTime.parse(v['start_time'])),
                style: const TextStyle(fontSize: 12, color: Colors.white70),
              ),
              const SizedBox(width: 16),
              Text(v['services']?['name'] ?? 'خدمة', style: const TextStyle(fontSize: 12)),
              const Spacer(),
              Text(
                v['price'] != null ? '${v['price']} د.ع' : '-',
                style: const TextStyle(fontSize: 12, color: Colors.green),
              ),
            ],
          ),
        ))),
      ],
    );
  }

  Widget _buildPaymentSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('تفاصيل الدفع', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        
        // ⭐ اختيار الطبيب (جديد)
        const Text('اختر الطبيب للجلسة', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
        const SizedBox(height: 8),
        if (_availableDoctors.isEmpty)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.withAlpha(30),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              children: [
                Icon(Icons.warning, color: Colors.orange, size: 18),
                SizedBox(width: 8),
                Text('لا يوجد أطباء متاحين في هذا القسم', style: TextStyle(color: Colors.orange)),
              ],
            ),
          )
        else
          DropdownButtonFormField<String>(
            value: _selectedDoctorId,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.medical_services, color: Colors.green),
              filled: true,
              fillColor: Colors.black12,
            ),
            items: _availableDoctors.map((doc) {
              return DropdownMenuItem(
                value: doc.id,
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: doc.color,
                      child: Text(doc.name[0], style: const TextStyle(color: Colors.white, fontSize: 12)),
                    ),
                    const SizedBox(width: 10),
                    Text(doc.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
              );
            }).toList(),
            onChanged: (val) => setState(() => _selectedDoctorId = val),
          ),
        
        const SizedBox(height: 20),
        const Divider(),
        const SizedBox(height: 12),
        
        // المبلغ
        TextField(
          controller: _amountController,
          keyboardType: TextInputType.number,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          decoration: const InputDecoration(
            labelText: 'المبلغ',
            suffixText: 'د.ع',
            border: OutlineInputBorder(),
          ),
        ),
        
        const SizedBox(height: 16),
        
        // طريقة الدفع
        Row(
          children: [
            _paymentMethodBtn('نقدي', 'cash', Icons.money),
            const SizedBox(width: 8),
            _paymentMethodBtn('بطاقة', 'card', Icons.credit_card),
            const SizedBox(width: 8),
            _paymentMethodBtn('تحويل', 'transfer', Icons.send),
          ],
        ),
        
        const SizedBox(height: 16),
        
        // ملاحظات
        TextField(
          controller: _notesController,
          maxLines: 2,
          decoration: const InputDecoration(
            labelText: 'ملاحظات (اختياري)',
            border: OutlineInputBorder(),
          ),
        ),
      ],
    );
  }

  Widget _paymentMethodBtn(String label, String value, IconData icon) {
    final isSelected = _paymentMethod == value;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _paymentMethod = value),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primary.withAlpha(51) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isSelected ? AppTheme.primary : Colors.white24, width: 2),
          ),
          child: Column(
            children: [
              Icon(icon, color: isSelected ? AppTheme.primary : Colors.white54),
              const SizedBox(height: 4),
              Text(label, style: TextStyle(
                color: isSelected ? AppTheme.primary : Colors.white54,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              )),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _processPayment() async {
    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى إدخال مبلغ صحيح'), backgroundColor: Colors.red),
      );
      return;
    }

    // التحقق من اختيار الطبيب
    if (_selectedDoctorId == null && _availableDoctors.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى اختيار الطبيب'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final supabase = Supabase.instance.client;
      final now = DateTime.now().toUtc().toIso8601String();
      
      await supabase.from('payments').insert({
        'session_id': widget.booking.id,
        'patient_id': widget.booking.patientId,
        'amount': amount,
        'payment_method': _paymentMethod,
        'notes': _notesController.text,
      });

      // تحديث الجلسة مع الطبيب المعين ووقت الدفع
      await supabase.from('sessions').update({
        'status': 'arrived',
        'price': amount,
        'assigned_doctor_id': _selectedDoctorId,
        'assigned_at': now,
        'payment_time': now,
      }).eq('id', widget.booking.id);

      // جلب اسم الطبيب المحدد
      final doctorName = _availableDoctors
          .firstWhere((d) => d.id == _selectedDoctorId, orElse: () => _availableDoctors.isNotEmpty ? _availableDoctors.first : Doctor(id: '', name: 'غير محدد', departmentId: '', color: Colors.grey))
          .name;

      if (mounted) {
        widget.onSuccess();
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Flexible(child: Text('✓ تم استلام ${_amountController.text} د.ع وتعيين د. $doctorName')),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// نافذة تفاصيل المريض
// ══════════════════════════════════════════════════════════════════════════════
class _PatientDetailsDialog extends StatefulWidget {
  final Booking booking;

  const _PatientDetailsDialog({required this.booking});

  @override
  State<_PatientDetailsDialog> createState() => _PatientDetailsDialogState();
}

class _PatientDetailsDialogState extends State<_PatientDetailsDialog> {
  Map<String, dynamic>? _patientInfo;
  List<Map<String, dynamic>> _allVisits = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final supabase = Supabase.instance.client;
      
      final patientRes = await supabase
          .from('patients')
          .select()
          .eq('id', widget.booking.patientId)
          .maybeSingle();
      
      final visitsRes = await supabase
          .from('sessions')
          .select('*, services(name), profiles!sessions_doctor_id_fkey(name)')
          .eq('patient_id', widget.booking.patientId)
          .order('start_time', ascending: false);

      if (mounted) {
        setState(() {
          _patientInfo = patientRes;
          _allVisits = List<Map<String, dynamic>>.from(visitsRes);
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 500,
        constraints: const BoxConstraints(maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.primary.withAlpha(26),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: AppTheme.primary,
                    child: Text(widget.booking.patientName[0].toUpperCase()),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(widget.booking.patientName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                ],
              ),
            ),
            
            // Content
            Flexible(
              child: _loading
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // معلومات المريض
                        if (_patientInfo != null) ...[
                          _buildInfoRow('الهاتف', _patientInfo!['phone'] ?? '-', Icons.phone),
                          _buildInfoRow('الجنس', _patientInfo!['gender'] == 'male' ? 'ذكر' : 'أنثى', Icons.person),
                          _buildInfoRow('العمر', _patientInfo!['age'] != null ? '${_patientInfo!['age']} سنة' : '-', Icons.cake),
                          _buildInfoRow('المصدر', _patientInfo!['source'] ?? '-', Icons.source),
                          const SizedBox(height: 16),
                          const Divider(),
                        ],
                        
                        // الزيارات
                        const SizedBox(height: 16),
                        Text('جميع الزيارات (${_allVisits.length})', style: const TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        ...(_allVisits.map((v) => _buildVisitCard(v))),
                      ],
                    ),
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.white54),
          const SizedBox(width: 12),
          Text(label, style: const TextStyle(color: Colors.white54)),
          const Spacer(),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildVisitCard(Map<String, dynamic> visit) {
    final date = DateTime.parse(visit['start_time']);
    final status = visit['status'] ?? 'unknown';
    final isCurrent = visit['id'] == widget.booking.id;
    
    Color statusColor;
    switch (status) {
      case 'completed': statusColor = Colors.blue; break;
      case 'arrived': statusColor = Colors.green; break;
      case 'cancelled': statusColor = Colors.red; break;
      default: statusColor = Colors.orange;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isCurrent ? AppTheme.primary.withAlpha(26) : Colors.white.withAlpha(13),
        borderRadius: BorderRadius.circular(8),
        border: isCurrent ? Border.all(color: AppTheme.primary) : null,
      ),
      child: Row(
        children: [
          Container(
            width: 8, height: 8,
            decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(DateFormat('d/M/yyyy - h:mm a').format(date), style: const TextStyle(fontWeight: FontWeight.w500)),
              Text(visit['services']?['name'] ?? 'خدمة', style: const TextStyle(fontSize: 12, color: Colors.white54)),
            ],
          ),
          const Spacer(),
          Text(
            visit['price'] != null ? '${visit['price']} د.ع' : '-',
            style: TextStyle(color: statusColor, fontWeight: FontWeight.bold),
          ),
          if (isCurrent) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: AppTheme.primary, borderRadius: BorderRadius.circular(4)),
              child: const Text('الحالية', style: TextStyle(fontSize: 10, color: Colors.white)),
            ),
          ],
        ],
      ),
    );
  }
}
