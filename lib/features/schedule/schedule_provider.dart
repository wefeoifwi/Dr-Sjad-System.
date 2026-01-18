import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'models.dart';
import '../notifications/notifications_provider.dart';
import '../../core/realtime_service.dart';

class ScheduleProvider extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;
  NotificationsProvider? _notificationsProvider;
  StreamSubscription? _realtimeSubscription;
  
  // Set notifications provider from outside
  void setNotificationsProvider(NotificationsProvider provider) {
    _notificationsProvider = provider;
  }

  // Filters
  DateTime _selectedDate = DateTime.now();
  String _selectedDepartmentId = 'all'; 
  
  // Customization
  double _hourHeight = 100.0; 
  
  // State
  bool _isLoading = false;
  List<Doctor> _allDoctors = []; 
  List<Booking> _bookings = [];
  List<Map<String, dynamic>> _departmentsList = [];
  
  // Stream for forcing UI updates
  final _updateController = StreamController<void>.broadcast();
  Stream<void> get updateStream => _updateController.stream;

  // Getters
  DateTime get selectedDate => _selectedDate;
  String get selectedDepartmentId => _selectedDepartmentId;
  double get hourHeight => _hourHeight;
  bool get isLoading => _isLoading;
  List<Booking> get bookings => _bookings;

  // Computed Properties
  List<Doctor> get doctors {
    if (_selectedDepartmentId == 'all') {
      return _allDoctors;
    }
    return _allDoctors.where((d) => d.departmentId == _selectedDepartmentId).toList();
  }

  Map<String, String> get departments {
    Map<String, String> result = {'all': 'الكل'};
    for (var dept in _departmentsList) {
      result[dept['id']] = dept['name'];
    }
    return result;
  }

  /// قائمة الأقسام كـ Department objects
  List<Department> get departmentObjects {
    return _departmentsList.map((d) => Department.fromJson(d)).toList();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 🔄 نظام التحديث اللحظي - باستخدام RealtimeService المركزي
  // ═══════════════════════════════════════════════════════════════════════════
  
  /// بدء الاستماع للتحديثات اللحظية
  void subscribeToRealtimeUpdates() {
    _realtimeSubscription?.cancel();
    
    debugPrint('🔌 ScheduleProvider: الاستماع لـ RealtimeService');
    
    _realtimeSubscription = RealtimeService().sessionsStream.listen((event) {
      debugPrint('📨 ScheduleProvider: استلام حدث ${event.type}');
      _handleRealtimeEvent(event);
    });
  }
  
  /// معالجة أحداث Realtime
  void _handleRealtimeEvent(RealtimeEvent event) {
    switch (event.type) {
      case 'insert':
        if (event.newData != null) {
          _handleInsert(event.newData!);
        }
        break;
        
      case 'update':
        if (event.newData != null) {
          _handleUpdate(event.newData!);
        }
        break;
        
      case 'delete':
        if (event.oldData != null) {
          _handleDelete(event.oldData!);
        }
        break;
    }
  }
  
  /// معالجة إضافة جلسة جديدة
  Future<void> _handleInsert(Map<String, dynamic> record) async {
    debugPrint('➕ جلسة جديدة: ${record['id']}');
    
    try {
      // جلب البيانات الكاملة للحجز الجديد
      final fullRecord = await _supabase
        .from('sessions')
        .select('*, patient:patients(name), doctor:profiles!sessions_doctor_id_fkey(name), creator:profiles!sessions_created_by_fkey(name)')
        .eq('id', record['id'])
        .single();
      
      final booking = _parseBooking(fullRecord);
      
      // ✅ إنشاء نسخة جديدة من القائمة لضمان تحديث الواجهة (Immutability)
      final oldCount = _bookings.length;
      var newList = List<Booking>.from(_bookings);
      newList.add(booking);
      // إعادة الترتيب حسب الوقت
      newList.sort((a, b) => a.startTime.compareTo(b.startTime));
      
      _bookings = newList;
      
      debugPrint('✅ تمت الإضافة: ${booking.patientName}');
      debugPrint('📊 عدد الحجوزات: $oldCount → ${_bookings.length}');
      
      debugPrint('🔔 إرسال notifyListeners...');
      notifyListeners();
      debugPrint('📡 إرسال Stream update...');
      _updateController.add(null);
      debugPrint('✅ تم إرسال التحديث!');
    } catch (e) {
      debugPrint('❌ خطأ في جلب بيانات الحجز الجديد: $e');
      loadData(); // Fallback
    }
  }
  
  /// معالجة تحديث جلسة
  void _handleUpdate(Map<String, dynamic> record) {
    debugPrint('📝 تحديث جلسة: ${record['id']}');
    
    final index = _bookings.indexWhere((b) => b.id == record['id']);
    if (index != -1) {
      final oldBooking = _bookings[index];
      
      // نستخدم البيانات من الـ payload إذا كانت موجودة، وإلا نبقي القديمة
      // ملاحظة: الـ payload يحتوي فقط على الحقول المتغيرة في بعض الحالات، 
      // لذا يجب الحذر. لكن مع REPLICA IDENTITY FULL المفروض تصل كاملة.
      
      final newBooking = Booking(
        id: oldBooking.id,
        patientId: oldBooking.patientId,
        patientName: oldBooking.patientName, // الاسم لا يتغير عادة في تحديث الحالة
        doctorId: oldBooking.doctorId,
        doctorName: oldBooking.doctorName,
        startTime: oldBooking.startTime,
        endTime: oldBooking.endTime,
        status: record['status'] ?? oldBooking.status,
        notes: record['notes'] ?? oldBooking.notes,
        sessionStartTime: record['session_start_time'] != null 
            ? DateTime.parse(record['session_start_time']).toLocal() 
            : oldBooking.sessionStartTime,
        sessionEndTime: record['session_end_time'] != null 
            ? DateTime.parse(record['session_end_time']).toLocal() 
            : oldBooking.sessionEndTime,
        createdById: oldBooking.createdById,
        createdByName: oldBooking.createdByName,
      );
      
      // ✅ إنشاء نسخة جديدة من القائمة
      var newList = List<Booking>.from(_bookings);
      newList[index] = newBooking;
      _bookings = newList;
      
      debugPrint('✅ تم التحديث: ${oldBooking.patientName} - الحالة: ${newBooking.status}');
      notifyListeners();
      _updateController.add(null); // Force update
    } else {
      // الجلسة غير موجودة محلياً (ربما تمت إضافتها للتو أو خارج النطاق)
      debugPrint('⚠️ الجلسة المحدثة غير موجودة محلياً، جاري إعادة التحميل...');
      loadData();
    }
  }
  
  /// معالجة حذف جلسة
  void _handleDelete(Map<String, dynamic> record) {
    debugPrint('🗑️ حذف جلسة: ${record['id']}');
    
    final exists = _bookings.any((b) => b.id == record['id']);
    if (exists) {
      // ✅ إنشاء نسخة جديدة من القائمة بدون العنصر المحذوف
      _bookings = _bookings.where((b) => b.id != record['id']).toList();
      debugPrint('✅ تم الحذف من القائمة المحلية');
      notifyListeners();
      _updateController.add(null); // Force update
    }
  }
  
  /// تحويل البيانات الخام إلى Booking
  Booking _parseBooking(Map<String, dynamic> s) {
    final startTime = DateTime.parse(s['start_time']).toLocal();
    final endTime = s['end_time'] != null 
        ? DateTime.parse(s['end_time']).toLocal() 
        : startTime.add(const Duration(minutes: 30));
    
    return Booking(
      id: s['id'],
      patientId: s['patient_id'] ?? '',
      patientName: s['patient']?['name'] ?? 'Unknown',
      doctorId: s['doctor_id'],
      doctorName: s['doctor']?['name'] ?? '',
      startTime: startTime,
      endTime: endTime,
      status: s['status'] ?? 'scheduled',
      notes: s['notes'],
      sessionStartTime: s['session_start_time'] != null 
          ? DateTime.parse(s['session_start_time']).toLocal() 
          : null,
      sessionEndTime: s['session_end_time'] != null 
          ? DateTime.parse(s['session_end_time']).toLocal() 
          : null,
      createdById: s['created_by'],
      createdByName: s['creator']?['name'],
    );
  }

  @override
  void dispose() {
    _realtimeSubscription?.cancel();
    _updateController.close();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Actions & Loaders
  // ═══════════════════════════════════════════════════════════════════════════

  void setDepartment(String depId) {
    _selectedDepartmentId = depId;
    notifyListeners();
  }

  void changeDate(DateTime date) {
    _selectedDate = date;
    loadData();
  }

  void setZoom(double newHeight) {
    _hourHeight = newHeight.clamp(30.0, 300.0);
    notifyListeners();
  }

  Future<void> loadData() async {
    _isLoading = true;
    notifyListeners();

    try {
      // 0. Fetch Departments (if not loaded)
      if (_departmentsList.isEmpty) {
        final deptResponse = await _supabase
            .from('departments')
            .select()
            .eq('is_active', true);
        _departmentsList = List<Map<String, dynamic>>.from(deptResponse);
      }

      // 1. Fetch Doctors (Profiles)
      final profilesResponse = await _supabase
          .from('profiles')
          .select()
          .eq('role', 'doctor');
      
      _allDoctors = (profilesResponse as List).map((doc) {
        // Find department ID from name
        String deptId = 'dep_unknown';
        final deptName = doc['department'];
        try {
          final matchingDept = _departmentsList.firstWhere(
            (d) => d['name'] == deptName,
            orElse: () => {'id': 'dep_unknown'},
          );
          deptId = matchingDept['id'];
        } catch (_) {}
        
        return Doctor(
          id: doc['id'], 
          name: doc['name'] ?? 'Unknown', 
          departmentId: deptId,
          color: Colors.blueAccent, 
        );
      }).toList();

      // 2. Fetch Sessions for selected date (UTC)
      final startOfDay = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day).toUtc().toIso8601String();
      final endOfDay = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, 23, 59, 59).toUtc().toIso8601String();

      final sessionsResponse = await _supabase
          .from('sessions')
          .select('*, patient:patients(name), doctor:profiles!sessions_doctor_id_fkey(name), creator:profiles!sessions_created_by_fkey(name)')
          .gte('start_time', startOfDay)
          .lte('start_time', endOfDay);

      _bookings = (sessionsResponse as List).map((s) {
        return _parseBooking(s);
      }).toList();

    } catch (e) {
      debugPrint('Error loading schedule data: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Create or Find Patient Helper
  Future<String> findOrCreatePatient({
    required String name, 
    String? phone,
    int? age,
    String? gender,
    String? address,
    String? source,
  }) async {
    try {
      // 1. Search by phone (Priority)
      if (phone != null && phone.isNotEmpty) {
        final existing = await _supabase
            .from('patients')
            .select()
            .eq('phone', phone)
            .maybeSingle();
        if (existing != null) {
          return existing['id'];
        }
      }
      
      // 2. Search by name (Secondary)
      final existingByName = await _supabase
          .from('patients')
          .select()
          .ilike('name', name)
          .maybeSingle();

      if (existingByName != null) return existingByName['id'];

      // 3. Create new
      final newPatient = await _supabase.from('patients').insert({
        'name': name,
        'phone': phone,
        'age': age,
        'gender': gender,
        'address': address,
        'source': source,
      }).select().single();

      return newPatient['id'];
    } catch (e) {
      debugPrint('Error in findOrCreatePatient: $e');
      rethrow;
    }
  }

  /// Check conflicts
  Future<bool> checkConflict(String doctorId, DateTime start, DateTime end) async {
    // السماح بحجز عدة مرضى في نفس الوقت لنفس الطبيب
    return false; 
  }

  /// Add new booking - الحجز بالقسم (doctor_id اختياري)
  Future<void> addBooking({
    required String patientName, 
    String? patientPhone,
    int? patientAge,
    String? patientGender,
    String? patientAddress,
    String? source,
    String? doctorId, // أصبح اختياري
    required String departmentId, // مطلوب
    required DateTime startTime,
    required int durationMinutes,
    required String serviceType,
    String? serviceId, 
    String? deviceId,
    String? room,
    String? notes,
  }) async {
    try {
      final patientId = await findOrCreatePatient(
        name: patientName, 
        phone: patientPhone,
        age: patientAge,
        gender: patientGender,
        address: patientAddress,
        source: source
      );

      final endTime = startTime.add(Duration(minutes: durationMinutes)); 

      await _supabase.from('sessions').insert({
        'patient_id': patientId,
        'doctor_id': doctorId, // قد يكون null
        'department_id': departmentId, // القسم مطلوب
        'start_time': startTime.toUtc().toIso8601String(),
        'end_time': endTime.toUtc().toIso8601String(),
        'service_type': serviceType,
        'service_id': serviceId,
        'device_id': deviceId,
        'room': room,
        'status': 'scheduled',
        'notes': notes,
        'created_by': _supabase.auth.currentUser?.id,
      });

      // إرسال إشعار للقسم
      if (_notificationsProvider != null) {
        // ignore: unused_local_variable - kept for future notification customization
        final deptName = departments[departmentId] ?? 'القسم';
        await _notificationsProvider!.notifyNewBooking(
          patientName: patientName,
          doctorId: doctorId ?? departmentId, // للإشعار
          date: DateFormat('d/M/yyyy').format(startTime),
          time: DateFormat('h:mm a').format(startTime),
        );
      }
      
      // Realtime سيقوم بالتحديث تلقائياً
    } catch (e) {
      debugPrint('Error creating booking: $e');
      rethrow;
    }
  }

  /// Update Booking Status
  Future<void> updateBookingStatus(String bookingId, String newStatus, {String? patientName, String? doctorName}) async {
    try {
      Map<String, dynamic> updateData = {'status': newStatus};
      
      if (newStatus == 'in_session') {
        updateData['session_start_time'] = DateTime.now().toIso8601String();
      } else if (newStatus == 'completed') {
        updateData['session_end_time'] = DateTime.now().toIso8601String();
      }
      
      await _supabase.from('sessions').update(updateData).eq('id', bookingId);
      
      // إرسال إشعارات
      if (_notificationsProvider != null) {
        // نحاول العثور على الحجز محلياً أولاً
        Booking? booking;
        try {
          booking = _bookings.firstWhere((b) => b.id == bookingId);
        } catch (_) {}

        final pName = booking?.patientName ?? patientName ?? 'مريض';
        final dName = booking?.doctorName ?? doctorName ?? 'طبيب';
        final dId = booking?.doctorId ?? '';
        
        if (newStatus == 'arrived') {
          await _notificationsProvider!.notifyPatientArrived(
            patientName: pName,
            doctorId: dId,
          );
        } else if (newStatus == 'in_session') {
          final adminIds = await _notificationsProvider!.getAdminIds();
          await _notificationsProvider!.notifySessionStarted(
            patientName: pName,
            doctorName: dName,
            adminIds: adminIds,
          );
        }
      }
    } catch (e) {
      debugPrint('Error updating booking status: $e');
      rethrow; 
    }
  }

  /// Actions: Request Cancellation
  Future<void> requestCancellation(String bookingId, String reason) async {
    try {
      await _supabase.from('sessions').update({
        'status': 'cancellation_pending',
        'cancel_reason': reason,
      }).eq('id', bookingId);
    } catch (e) {
      debugPrint('Error requesting cancellation: $e');
      rethrow;
    }
  }

  /// Actions: Log Postponement
  Future<void> logPostponement(String bookingId, String reason) async {
     try {
       final data = await _supabase.from('sessions').select('notes').eq('id', bookingId).single();
       final oldNotes = data['notes'] ?? '';
       final newNotes = '$oldNotes\n[Postponed]: $reason';
       
       await _supabase.from('sessions').update({'notes': newNotes}).eq('id', bookingId);
     } catch (e) {
       rethrow;
     }
  }
}
