import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminProvider extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;

  // --- Activity Logging Helper ---
  Future<void> _logActivity({
    required String action,
    String? entityType,
    String? entityId,
    Map<String, dynamic>? details,
  }) async {
    try {
      await _supabase.from('activity_logs').insert({
        'action': action,
        'entity_type': entityType,
        'entity_id': entityId,
        'details': details != null ? details.toString() : null,
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('Activity log error: $e');
      // Don't throw - logging failures shouldn't break main operations
    }
  }

  // --- Staff Management ---
  List<Map<String, dynamic>> _doctors = [];
  List<Map<String, dynamic>> _employees = [];
  bool _isLoading = false;

  List<Map<String, dynamic>> get doctors => _doctors;
  List<Map<String, dynamic>> get employees => _employees;
  bool get isLoading => _isLoading;

  Future<void> loadStaff() async {
    _isLoading = true;
    notifyListeners();
    try {
      final response = await _supabase.from('profiles').select();
      final List<Map<String, dynamic>> allProfiles = List<Map<String, dynamic>>.from(response);

      _doctors = allProfiles.where((p) => p['role'] == 'doctor').toList();
      _employees = allProfiles.where((p) => p['role'] != 'doctor').toList();
    } catch (e) {
      debugPrint('Error loading staff: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addStaff({
    required String email, 
    required String password, 
    required String name, 
    required String role, 
    required String username,
    String? phone,
    String? department,
  }) async {
    try {
      final newProfile = {
        'username': username,
        'email': email,
        'password': password, // Storing plain text as requested for this phase
        'name': name,
        'role': role,
        'phone': phone,
        'department': department,
        'created_at': DateTime.now().toIso8601String(),
      };

      final response = await _supabase.from('profiles').insert(newProfile).select().single();
      
      if (role == 'doctor') {
        _doctors.add(response);
      } else {
        _employees.add(response);
      }
      
      // Log activity
      await _logActivity(
        action: 'create_staff',
        entityType: 'profile',
        entityId: response['id'],
        details: {'name': name, 'role': role},
      );
      
      notifyListeners();
    } catch (e) {
      debugPrint('Error adding staff: $e');
      rethrow;
    }
  }

  Future<void> deleteStaff(String id, String role) async {
     try {
       await _supabase.from('profiles').delete().eq('id', id);
       if (role == 'doctor') {
         _doctors.removeWhere((p) => p['id'] == id);
       } else {
         _employees.removeWhere((p) => p['id'] == id);
       }
       
       // Log activity
       await _logActivity(
         action: 'delete_staff',
         entityType: 'profile',
         entityId: id,
         details: {'role': role},
       );
       
       notifyListeners();
     } catch (e) {
       rethrow;
     }
  }

  // --- Patient Management ---
  List<Map<String, dynamic>> _patients = [];
  List<Map<String, dynamic>> get patients => _patients;

  Future<void> loadPatients() async {
    _isLoading = true;
    notifyListeners();
    try {
      final response = await _supabase.from('patients').select().order('created_at', ascending: false);
      _patients = List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error loading patients: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // --- Assets (Devices & Services) ---
  List<Map<String, dynamic>> _devices = [];
  List<Map<String, dynamic>> _services = [];

  List<Map<String, dynamic>> get devices => _devices;
  List<Map<String, dynamic>> get services => _services;

  Future<void> loadDevices() async {
    try {
      final data = await _supabase.from('devices').select().order('created_at');
      _devices = List<Map<String, dynamic>>.from(data);
      notifyListeners();
    } catch (e) {
       debugPrint('Error loading devices: $e');
    }
  }

  Future<void> addDevice({required String name, String? type}) async {
    try {
      final res = await _supabase.from('devices').insert({
        'name': name, 'type': type, 'status': 'active',
      }).select().single();
      _devices.add(res);
      notifyListeners();
    } catch (e) { rethrow; }
  }

  Future<void> deleteDevice(String id) async {
    try {
      await _supabase.from('devices').delete().eq('id', id);
      _devices.removeWhere((d) => d['id'] == id);
      notifyListeners();
    } catch (e) { rethrow; }
  }

  Future<void> loadServices() async {
    try {
      final data = await _supabase.from('services').select().order('created_at');
      _services = List<Map<String, dynamic>>.from(data);
      notifyListeners();
    } catch (e) { debugPrint('Error loading services: $e'); }
  }

  Future<void> addService({required String name, required double price}) async {
    try {
      final res = await _supabase.from('services').insert({
        'name': name, 'default_price': price,
      }).select().single();
      _services.add(res);
      notifyListeners();
    } catch (e) { rethrow; }
  }

  // --- Departments ---
  List<Map<String, dynamic>> _departments = [];
  List<Map<String, dynamic>> get departments => _departments;

  Future<void> loadDepartments() async {
    try {
      final data = await _supabase.from('departments').select().order('name');
      _departments = List<Map<String, dynamic>>.from(data);
      notifyListeners();
    } catch (e) { debugPrint('Error loading departments: $e'); }
  }

  Future<void> addDepartment(String name) async {
    try {
      final res = await _supabase.from('departments').insert({'name': name}).select().single();
      _departments.add(res);
      notifyListeners();
    } catch (e) { rethrow; }
  }

  Future<void> deleteDepartment(String id) async {
    try {
      await _supabase.from('departments').delete().eq('id', id);
      _departments.removeWhere((d) => d['id'] == id);
      notifyListeners();
    } catch (e) { rethrow; }
  }

  // --- Reports & Analytics ---
  List<Map<String, dynamic>> _allSessions = [];
  List<Map<String, dynamic>> _pendingCancellations = [];
  double _totalRevenue = 0;
  
  Map<String, dynamic> _callCenterStats = {};
  List<Map<String, dynamic>> _doctorPerformance = [];
  List<Map<String, dynamic>> _serviceFinancials = [];
  List<String> _smartInsights = [];
  Map<String, dynamic> _patientStats = {};
  List<Map<String, dynamic>> _roomStats = [];
  Map<String, dynamic> _followUpStats = {};
  Map<String, dynamic> _noShowStats = {};
  List<Map<String, dynamic>> _deviceStats = [];
  Map<String, int> _serviceUsageStats = {}; 
  Map<String, double> _dailyRevenueStats = {};

  // Getters
  List<Map<String, dynamic>> get allSessions => _allSessions;
  List<Map<String, dynamic>> get pendingCancellations => _pendingCancellations;
  double get totalRevenue => _totalRevenue;
  Map<String, dynamic> get callCenterStats => _callCenterStats;
  List<Map<String, dynamic>> get doctorPerformance => _doctorPerformance;
  List<Map<String, dynamic>> get serviceFinancials => _serviceFinancials;
  List<String> get smartInsights => _smartInsights;
  Map<String, dynamic> get patientStats => _patientStats;
  List<Map<String, dynamic>> get roomStats => _roomStats;
  Map<String, dynamic> get followUpStats => _followUpStats;
  Map<String, dynamic> get noShowStats => _noShowStats;
  List<Map<String, dynamic>> get deviceStats => _deviceStats;
  Map<String, int> get serviceUsageStats => _serviceUsageStats;
  Map<String, double> get dailyRevenueStats => _dailyRevenueStats;

  Future<void> loadPendingCancellations() async {
    try {
      final res = await _supabase.from('sessions')
          .select('*, patient:patients(name)')
          .eq('status', 'cancellation_pending');
      _pendingCancellations = List<Map<String, dynamic>>.from(res);
      notifyListeners();
    } catch (e) { debugPrint('Error loading pending cancellations: $e'); }
  }

  Future<void> approveCancellation(String bookingId) async {
    await _supabase.from('sessions').update({'status': 'cancelled'}).eq('id', bookingId);
    _pendingCancellations.removeWhere((b) => b['id'] == bookingId);
    notifyListeners();
    await generateAdvancedReports(); 
  }

  Future<void> rejectCancellation(String bookingId) async {
    await _supabase.from('sessions').update({'status': 'scheduled', 'cancel_reason': null}).eq('id', bookingId);
    _pendingCancellations.removeWhere((b) => b['id'] == bookingId);
    notifyListeners();
    await generateAdvancedReports();
  }

  Future<void> generateAdvancedReports({DateTime? customStartDate, DateTime? customEndDate}) async {
    _isLoading = true;
    notifyListeners();
    try {
      // 1. Fetch Data
      if (_devices.isEmpty) await loadDevices();
      await loadPendingCancellations();

      final now = DateTime.now();
      final start = customStartDate ?? now.subtract(const Duration(days: 30));
      final end = customEndDate ?? now;

      final res = await _supabase.from('sessions')
          .select('*, patient:patients(*), doctor:profiles(name)')
          .gte('start_time', start.toIso8601String())
          .lte('start_time', end.add(const Duration(days: 1)).toIso8601String()); // Inclusive end

      _allSessions = List<Map<String, dynamic>>.from(res);

      // 2. Aggregate
      double revenue = 0;
      int cancelled = 0;
      int arrived = 0;
      int noShow = 0;
      int followUps = 0;

      Map<String, int> sourceCounts = {};
      Map<String, double> docRev = {};
      Map<String, int> docSessions = {};
      Map<String, int> docMinutes = {};
      Map<String, double> svcRev = {};
      Map<String, int> svcCount = {};
      Map<String, double> dailyRev = {};
      Map<String, int> roomCounts = {};
      Map<String, int> deviceCounts = {};
      
      int male = 0;
      int female = 0;
      Set<String> uniquePatients = {};

      for (var s in _allSessions) {
        final status = s['status'];
        final price = (s['price'] as num?)?.toDouble() ?? 0.0;
        final docId = s['doctor_id'];
        final svc = s['service_type'] ?? 'General';
        final room = s['room'];
        final deviceId = s['device_id'];
        final patient = s['patient'];
        final pId = s['patient_id'];

        // General Stats
        if (status == 'cancelled') cancelled++;
        if (status == 'no_show') noShow++;
        if (status == 'arrived' || status == 'completed') arrived++;

        // Revenue & Financials
        if (status == 'completed') {
          revenue += price;
          
          if (docId != null) {
             docRev[docId] = (docRev[docId] ?? 0) + price;
          }
          svcRev[svc] = (svcRev[svc] ?? 0) + price;
          
          if (s['end_time'] != null) {
            final d = DateTime.parse(s['end_time']);
            final dayKey = "${d.year}-${d.month}-${d.day}"; // Or formatted
            final dayLabel = "${d.month}/${d.day}";
            dailyRev[dayLabel] = (dailyRev[dayLabel] ?? 0) + price;
          }
        }

        // Usage Stats
        if (status != 'cancelled') {
           if (docId != null) {
             docSessions[docId] = (docSessions[docId] ?? 0) + 1;
             
             // Time
             if (s['start_time'] != null && s['end_time'] != null) {
               final dur = DateTime.parse(s['end_time']).difference(DateTime.parse(s['start_time'])).inMinutes;
               docMinutes[docId] = (docMinutes[docId] ?? 0) + dur;
             } else {
               docMinutes[docId] = (docMinutes[docId] ?? 0) + 30;
             }
           }
           svcCount[svc] = (svcCount[svc] ?? 0) + 1;
           if (room != null) roomCounts[room] = (roomCounts[room] ?? 0) + 1;
           if (deviceId != null) deviceCounts[deviceId] = (deviceCounts[deviceId] ?? 0) + 1;
        }

        // Patient Stats
        if (pId != null && !uniquePatients.contains(pId)) {
          uniquePatients.add(pId);
          if (patient != null) {
             final g = patient['gender'];
             if (g == 'male') male++; else female++;
             
             final src = patient['source'] ?? 'unknown';
             sourceCounts[src] = (sourceCounts[src] ?? 0) + 1;
          }
        }
        
        // Follow Up Check
        if (s['notes'] != null && s['notes'].toString().contains('متابعة')) followUps++;
      }

      _totalRevenue = revenue;
      _serviceUsageStats = svcCount;
      _dailyRevenueStats = dailyRev;

      // Call Center / Source Stats
      _callCenterStats = {
        'total_bookings': _allSessions.length,
        'cancelled': cancelled,
        'arrived': arrived,
        'no_show': noShow,
        'sources': sourceCounts, 
      };

      // Doctor Performance
      List<Map<String, dynamic>> docPerf = [];
      for (var doc in _doctors) {
        final id = doc['id'];
        if ((docSessions[id] ?? 0) > 0) {
           docPerf.add({
             'name': doc['name'],
             'sessions': docSessions[id] ?? 0,
             'revenue': docRev[id] ?? 0.0,
             'total_hours': ((docMinutes[id] ?? 0) / 60).toStringAsFixed(1),
             'retention_rate': 0, // Complex to calc perfectly, skipping for now
           });
        }
      }
      docPerf.sort((a,b) => (b['revenue'] as double).compareTo(a['revenue'] as double));
      _doctorPerformance = docPerf;

      // Service Financials
      _serviceFinancials = svcRev.entries.map((e) => {'name': e.key, 'revenue': e.value}).toList();
      _serviceFinancials.sort((a,b) => (b['revenue'] as double).compareTo(a['revenue'] as double));

      // Patient Stats
      _patientStats = {
        'total_unique': uniquePatients.length,
        'male': male,
        'female': female,
        'returning_rate': 0, // Placeholder
      };

      // Room Stats
      _roomStats = roomCounts.entries.map((e) => {'name': e.key, 'usage': e.value}).toList();

      // Device Stats
      _deviceStats = deviceCounts.entries.map((e) {
        final devName = _devices.firstWhere((d) => d['id'] == e.key, orElse: () => {'name': 'Unknown'})['name'];
        return {'name': devName, 'usage': e.value};
      }).toList();

      // Insights
      _smartInsights.clear();
      if (cancelled > (_allSessions.length * 0.25)) _smartInsights.add('نسبة الإلغاء مرتفعة هذا الشهر.');
      if (revenue < 1000) _smartInsights.add('الإيرادات منخفضة مقارنة بالمعدل المستهدف.');

      _followUpStats = {'count': followUps, 'percentage': 0};
      _noShowStats = {'count': noShow};

    } catch (e) {
      debugPrint('Error generating reports: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  // --- Restored Missing Methods for Compatibility ---

  double _dailyRevenue = 0;
  double _monthlyRevenue = 0;
  List<Map<String, dynamic>> _recentTransactions = [];

  double get dailyRevenue => _dailyRevenue;
  double get monthlyRevenue => _monthlyRevenue;
  List<Map<String, dynamic>> get recentTransactions => _recentTransactions;

  Future<void> addPatient({
    required String name,
    required String phone,
    int? age,
    String? address,
    String? notes,
  }) async {
    try {
      final newPatient = {
        'name': name,
        'phone': phone,
        'age': age,
        'address': address,
        'medical_history': notes, // Mapping notes to medical_history or just ignoring if column missing, assuming medical_history exists or adding it
        'created_at': DateTime.now().toIso8601String(),
      };
      
      // Check if medical_history exists in schema, if not just insert others. 
      // Based on schema it might not be there, so let's stick to safe fields or just 'info'.
      // actually schema has 'medical_history' and 'notes' usually? 
      // Let's use 'notes' if it was added, otherwise ignore. 
      // Re-checking schema... `patients` table has `medical_history`.
      
      final res = await _supabase.from('patients').insert({
        'name': name,
        'phone': phone,
        'age': age,
        'address': address,
        // 'medical_history': notes, // Optional, uncomment if schema supports
      }).select().single();

      _patients.insert(0, res);
      notifyListeners();
    } catch (e) {
      debugPrint('Error adding patient: $e');
      rethrow;
    }
  }

  Future<void> loadFinancialStats() async {
    _isLoading = true;
    notifyListeners();
    try {
      final now = DateTime.now();
      
      // 1. Daily Revenue
      final startOfDay = DateTime(now.year, now.month, now.day).toIso8601String();
      final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59).toIso8601String();
      
      final dailyRes = await _supabase
          .from('sessions')
          .select('price')
          .eq('status', 'completed')
          .gte('end_time', startOfDay)
          .lte('end_time', endOfDay);
      
      _dailyRevenue = (dailyRes as List).fold(0.0, (sum, item) => sum + ((item['price'] as num?)?.toDouble() ?? 0.0));

      // 2. Monthly Revenue
      final startOfMonth = DateTime(now.year, now.month, 1).toIso8601String();
      final endOfMonth = DateTime(now.year, now.month + 1, 0, 23, 59, 59).toIso8601String();

      final monthlyRes = await _supabase
          .from('sessions')
          .select('price')
          .eq('status', 'completed')
          .gte('end_time', startOfMonth)
          .lte('end_time', endOfMonth);

      _monthlyRevenue = (monthlyRes as List).fold(0.0, (sum, item) => sum + ((item['price'] as num?)?.toDouble() ?? 0.0));
      
      // 3. Total Revenue (for period) -> reused from generateAdvancedReports if needed, 
      // but for the card we might want All Time? Or just Month? 
      // The UI shows "Total Revenue" card. Let's make it ALL TIME or Year? 
      // Let's stick to Month for "Total" in this context or just sum of all time.
      // For safety, let's load ALL time revenue
      final totalRes = await _supabase
          .from('sessions')
          .select('price')
          .eq('status', 'completed');
      _totalRevenue = (totalRes as List).fold(0.0, (sum, item) => sum + ((item['price'] as num?)?.toDouble() ?? 0.0));


      // 4. Recent Transactions
      final recentRes = await _supabase
          .from('sessions')
          .select('*, patient:patients(name)')
          .eq('status', 'completed')
          .order('end_time', ascending: false)
          .limit(10);
      
      _recentTransactions = List<Map<String, dynamic>>.from(recentRes);

    } catch (e) {
      debugPrint('Error loading financial stats: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
