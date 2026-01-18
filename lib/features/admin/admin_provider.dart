import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminProvider extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;
  
  // ═══════════════════════════════════════════════════════════════════════════
  // SMART CACHING SYSTEM - Prevents unnecessary reloads
  // ═══════════════════════════════════════════════════════════════════════════
  DateTime? _staffLastLoad;
  DateTime? _servicesLastLoad;
  DateTime? _devicesLastLoad;
  static const Duration _cacheValidDuration = Duration(minutes: 5);
  
  bool _isCacheValid(DateTime? lastLoad) {
    if (lastLoad == null) return false;
    return DateTime.now().difference(lastLoad) < _cacheValidDuration;
  }

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
        'details': details?.toString(),
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('Activity log error: $e');
    }
  }

  // --- Staff Management ---
  List<Map<String, dynamic>> _doctors = [];
  List<Map<String, dynamic>> _employees = [];
  bool _isLoading = false;

  List<Map<String, dynamic>> get doctors => _doctors;
  List<Map<String, dynamic>> get employees => _employees;
  bool get isLoading => _isLoading;

  Future<void> loadStaff({bool force = false}) async {
    // Use cache if valid and not forced
    if (!force && _isCacheValid(_staffLastLoad) && _doctors.isNotEmpty) return;
    
    _isLoading = true;
    notifyListeners();
    try {
      final response = await _supabase.from('profiles').select();
      final List<Map<String, dynamic>> allProfiles = List<Map<String, dynamic>>.from(response);

      _doctors = allProfiles.where((p) => p['role'] == 'doctor').toList();
      _employees = allProfiles.where((p) => p['role'] != 'doctor').toList();
      _staffLastLoad = DateTime.now();
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
      // Handle specific PostgreSQL errors
      final errorStr = e.toString();
      if (errorStr.contains('23505')) {
        throw Exception('اسم المستخدم "$username" مستخدم مسبقاً. الرجاء اختيار اسم آخر.');
      }
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

  // --- Assets (Devices & Services) ---
  List<Map<String, dynamic>> _devices = [];
  List<Map<String, dynamic>> _services = [];

  List<Map<String, dynamic>> get devices => _devices;
  List<Map<String, dynamic>> get services => _services;

  Future<void> loadDevices({bool force = false}) async {
    if (!force && _isCacheValid(_devicesLastLoad) && _devices.isNotEmpty) return;
    try {
      final data = await _supabase.from('devices').select().order('created_at');
      _devices = List<Map<String, dynamic>>.from(data);
      _devicesLastLoad = DateTime.now();
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
    } catch (e) {
      debugPrint('Error adding device: $e');
      if (e.toString().contains('23505')) {
        throw Exception('الجهاز "$name" موجود مسبقاً.');
      }
      rethrow;
    }
  }

  Future<void> deleteDevice(String id) async {
    try {
      await _supabase.from('devices').delete().eq('id', id);
      _devices.removeWhere((d) => d['id'] == id);
      notifyListeners();
    } catch (e) { rethrow; }
  }

  Future<void> updateDevice(String id, {required String name, String? type, String? status}) async {
    try {
      final updated = await _supabase.from('devices').update({
        'name': name,
        'type': type,
        'status': status ?? 'active',
      }).eq('id', id).select().single();
      
      final index = _devices.indexWhere((d) => d['id'] == id);
      if (index != -1) _devices[index] = updated;
      notifyListeners();
    } catch (e) { rethrow; }
  }

  Future<void> loadServices({bool force = false}) async {
    if (!force && _isCacheValid(_servicesLastLoad) && _services.isNotEmpty) return;
    try {
      final data = await _supabase.from('services').select().order('created_at');
      _services = List<Map<String, dynamic>>.from(data);
      _servicesLastLoad = DateTime.now();
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
    } catch (e) {
      debugPrint('Error adding service: $e');
      if (e.toString().contains('23505')) {
        throw Exception('الخدمة "$name" موجودة مسبقاً.');
      }
      rethrow;
    }
  }

  Future<void> deleteService(String id) async {
    try {
      await _supabase.from('services').delete().eq('id', id);
      _services.removeWhere((s) => s['id'] == id);
      notifyListeners();
    } catch (e) {
      debugPrint('Error deleting service: $e');
      rethrow;
    }
  }

  Future<void> updateService(String id, {required String name, required double price}) async {
    try {
      final updated = await _supabase.from('services').update({
        'name': name,
        'default_price': price,
      }).eq('id', id).select().single();
      
      final index = _services.indexWhere((s) => s['id'] == id);
      if (index != -1) _services[index] = updated;
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

  Future<void> updateDepartment(String id, {required String name}) async {
    try {
      final updated = await _supabase.from('departments').update({
        'name': name,
      }).eq('id', id).select().single();
      
      final index = _departments.indexWhere((d) => d['id'] == id);
      if (index != -1) _departments[index] = updated;
      notifyListeners();
    } catch (e) { rethrow; }
  }

  // --- Staff Status Toggle ---
  Future<void> toggleStaffStatus(String id, bool isActive) async {
    try {
      await _supabase.from('profiles').update({
        'is_active': isActive,
      }).eq('id', id);
      
      // Update local lists
      for (var list in [_doctors, _employees]) {
        final index = list.indexWhere((s) => s['id'] == id);
        if (index != -1) {
          list[index] = {...list[index], 'is_active': isActive};
        }
      }
      notifyListeners();
    } catch (e) { rethrow; }
  }

  // --- Update Staff Info (Name, Username, Phone, Password) ---
  Future<void> updateStaffInfo({
    required String userId,
    required String name,
    required String username,
    required String phone,
    String? newPassword,
  }) async {
    try {
      // 1. Update profile table
      final updatedProfile = await _supabase.from('profiles').update({
        'name': name,
        'username': username,
        'email': '$username@carepoint.local',
        'phone': phone,
        if (newPassword != null && newPassword.isNotEmpty) 'password': newPassword,
      }).eq('id', userId).select().single();
      
      // 2. Update local lists
      for (var list in [_doctors, _employees]) {
        final index = list.indexWhere((s) => s['id'] == userId);
        if (index != -1) {
          list[index] = updatedProfile;
        }
      }
      
      // 3. Log activity
      await _logActivity(
        action: 'update_staff',
        entityType: 'profile',
        entityId: userId,
        details: {
          'name': name,
          'username': username,
          'password_changed': newPassword != null && newPassword.isNotEmpty,
        },
      );
      
      notifyListeners();
    } catch (e) {
      debugPrint('Error updating staff: $e');
      final errorStr = e.toString();
      if (errorStr.contains('23505')) {
        throw Exception('اسم المستخدم "$username" مستخدم مسبقاً. الرجاء اختيار اسم آخر.');
      }
      rethrow;
    }
  }

  // --- Activity Log ---
  List<Map<String, dynamic>> _activityLogs = [];
  List<Map<String, dynamic>> get activityLogs => _activityLogs;

  Future<void> loadActivityLogs({int limit = 100}) async {
    try {
      final data = await _supabase
          .from('activity_logs')
          .select('*, profiles(name)')
          .order('created_at', ascending: false)
          .limit(limit);
      _activityLogs = List<Map<String, dynamic>>.from(data);
      notifyListeners();
    } catch (e) { 
      debugPrint('Error loading activity logs: $e');
      // Table might not exist yet, create empty list
      _activityLogs = [];
    }
  }

  Future<void> logActivity({required String userId, required String action, String? details}) async {
    try {
      await _supabase.from('activity_logs').insert({
        'user_id': userId,
        'action': action,
        'details': details,
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) { 
      debugPrint('Error logging activity: $e');
    }
  }

  // --- Reports & Analytics ---
  List<Map<String, dynamic>> _allSessions = [];
  List<Map<String, dynamic>> _pendingCancellations = [];
  double _totalRevenue = 0;
  
  Map<String, dynamic> _callCenterStats = {};
  List<Map<String, dynamic>> _doctorPerformance = [];
  List<Map<String, dynamic>> _serviceFinancials = [];
  final List<String> _smartInsights = [];
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
             if (g == 'male') {
               male++;
             } else {
               female++;
             }
             
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

  // ═══════════════════════════════════════════════════════════════════════════
  // PATIENTS - With Pagination & Server-Side Search for 500K+ patients
  // ═══════════════════════════════════════════════════════════════════════════
  
  List<Map<String, dynamic>> _patients = [];
  int _patientsTotal = 0;
  int _patientsPage = 0;
  String _patientsSearch = '';
  bool _patientsHasMore = true;
  bool _patientsLoading = false;
  static const int _patientsPageSize = 50;

  List<Map<String, dynamic>> get patients => _patients;
  int get patientsTotal => _patientsTotal;
  int get patientsPage => _patientsPage;
  bool get patientsHasMore => _patientsHasMore;
  bool get patientsLoading => _patientsLoading;

  /// Load patients with pagination - call with reset=true for first load
  Future<void> loadPatients({bool reset = false, String? search}) async {
    if (_patientsLoading) return;
    
    _patientsLoading = true;
    if (reset) {
      _patients = [];
      _patientsPage = 0;
      _patientsHasMore = true;
    }
    if (search != null) _patientsSearch = search;
    notifyListeners();

    try {
      final from = _patientsPage * _patientsPageSize;
      final to = from + _patientsPageSize - 1;

      PostgrestFilterBuilder query = _supabase.from('patients').select();
      
      // Server-side search
      if (_patientsSearch.isNotEmpty) {
        query = query.or('name.ilike.%$_patientsSearch%,phone.ilike.%$_patientsSearch%');
      }

      final response = await query.order('created_at', ascending: false).range(from, to);
      
      final newPatients = List<Map<String, dynamic>>.from(response);
      _patients.addAll(newPatients);
      _patientsHasMore = newPatients.length == _patientsPageSize;
      _patientsPage++;
      
      // Get total count separately if needed (optional, can be slow with large data)
      if (reset && _patientsSearch.isEmpty) {
        try {
          final countRes = await _supabase.from('patients').select('id').count(CountOption.exact);
          _patientsTotal = countRes.count;
        } catch (_) {
          _patientsTotal = _patients.length;
        }
      }
    } catch (e) {
      debugPrint('Error loading patients: $e');
    } finally {
      _patientsLoading = false;
      notifyListeners();
    }
  }

  /// Search patients (server-side)
  Future<void> searchPatients(String query) async {
    await loadPatients(reset: true, search: query);
  }

  /// Load more patients (next page)
  Future<void> loadMorePatients() async {
    if (_patientsHasMore && !_patientsLoading) {
      await loadPatients();
    }
  }

  Future<void> addPatient({
    required String name,
    required String phone,
    int? age,
    String? address,
    String? notes,
  }) async {
    try {
      final res = await _supabase.from('patients').insert({
        'name': name,
        'phone': phone,
        'age': age,
        'address': address,
        'created_at': DateTime.now().toIso8601String(),
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
