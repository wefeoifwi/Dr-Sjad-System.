import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'models.dart';

class ScheduleProvider extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Filters
  DateTime _selectedDate = DateTime.now();
  String _selectedDepartmentId = 'all'; 
  
  // Customization
  double _hourHeight = 100.0; 

  bool _isLoading = false;
  
  List<Doctor> _allDoctors = []; 
  List<Booking> _bookings = [];
  List<Map<String, dynamic>> _departmentsList = []; // NEW: Dynamic departments
  
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

  // FIXED: Dynamic departments from database
  Map<String, String> get departments {
    Map<String, String> result = {'all': 'الكل'};
    for (var dept in _departmentsList) {
      result[dept['id']] = dept['name'];
    }
    return result;
  }

  // Actions
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
        final matchingDept = _departmentsList.firstWhere(
          (d) => d['name'] == deptName,
          orElse: () => {'id': 'dep_unknown'},
        );
        deptId = matchingDept['id'];
        
        return Doctor(
          id: doc['id'], 
          name: doc['name'] ?? 'Unknown', 
          departmentId: deptId,
          color: Colors.blueAccent, 
        );
      }).toList();

      // 2. Fetch Sessions for selected date
      final startOfDay = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day).toIso8601String();
      final endOfDay = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, 23, 59, 59).toIso8601String();

      final sessionsResponse = await _supabase
          .from('sessions')
          .select('*, patient:patients(name)')
          .gte('start_time', startOfDay)
          .lte('start_time', endOfDay);

      _bookings = (sessionsResponse as List).map((s) {
        final startTime = DateTime.parse(s['start_time']).toLocal();
        final endTime = s['end_time'] != null 
            ? DateTime.parse(s['end_time']).toLocal() 
            : startTime.add(const Duration(minutes: 30));

        return Booking(
          id: s['id'],
          patientId: s['patient_id'] ?? '',
          patientName: s['patient']?['name'] ?? 'Unknown',
          doctorId: s['doctor_id'],
          startTime: startTime,
          endTime: endTime,
          status: s['status'] ?? 'scheduled',
          notes: s['notes'],
        );
      }).toList();

    } catch (e) {
      debugPrint('Error loading schedule data: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

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
          // Optional: Update missing info if needed
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

  Future<bool> checkConflict(String doctorId, DateTime start, DateTime end) async {
    // Check if any booking for this doctor overlaps with [start, end]
    // Overlap logic: (StartA < EndB) and (EndA > StartB)
    try {
      final res = await _supabase
          .from('sessions')
          .select('id')
          .eq('doctor_id', doctorId)
          .neq('status', 'cancelled')
          .lt('start_time', end.toIso8601String())
          .gt('end_time', start.toIso8601String())
          .limit(1);
      
      return (res as List).isNotEmpty;
    } catch (e) {
      debugPrint('Conflict check error: $e');
      return false; 
    }
  }

  Future<void> addBooking({
    required String patientName, 
    String? patientPhone,
    int? patientAge,
    String? patientGender,
    String? patientAddress,
    String? source,
    required String doctorId,
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
        'doctor_id': doctorId,
        'start_time': startTime.toIso8601String(),
        'end_time': endTime.toIso8601String(),
        'service_type': serviceType,
        'service_id': serviceId,
        'device_id': deviceId,
        'room': room,
        'status': 'scheduled',
        'notes': notes,
        'created_by': _supabase.auth.currentUser?.id,
      });

      // Refresh
      await loadData();
    } catch (e) {
      debugPrint('Error creating booking: $e');
      rethrow;
    }
  }

  Future<void> updateBookingStatus(String bookingId, String newStatus) async {
    try {
      await _supabase.from('sessions').update({'status': newStatus}).eq('id', bookingId);
      await loadData();
    } catch (e) {
      debugPrint('Error updating booking status: $e');
      rethrow; 
    }
  }

  Future<void> requestCancellation(String bookingId, String reason) async {
    try {
      await _supabase.from('sessions').update({
        'status': 'cancellation_pending',
        'cancel_reason': reason,
      }).eq('id', bookingId);
      
      await loadData();
    } catch (e) {
      debugPrint('Error requesting cancellation: $e');
      rethrow;
    }
  }

  Future<void> logPostponement(String bookingId, String reason) async {
     try {
       final data = await _supabase.from('sessions').select('notes').eq('id', bookingId).single();
       final oldNotes = data['notes'] ?? '';
       final newNotes = '$oldNotes\n[Postponed]: $reason';
       
       await _supabase.from('sessions').update({'notes': newNotes}).eq('id', bookingId);
       await loadData();
     } catch (e) {
       rethrow;
     }
  }
}
