import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme.dart';

class DataImportScreen extends StatefulWidget {
  const DataImportScreen({super.key});

  @override
  State<DataImportScreen> createState() => _DataImportScreenState();
}

class _DataImportScreenState extends State<DataImportScreen> {
  List<List<dynamic>> _excelData = [];
  List<String> _headers = [];
  bool _isLoading = false;
  bool _isImporting = false;
  int _importedCount = 0;
  int _totalCount = 0;
  String _statusMessage = '';
  
  // Statistics for import summary
  int _newPatientsCount = 0;
  int _newDoctorsCount = 0;
  int _newServicesCount = 0;
  int _newRoomsCount = 0;
  int _newSessionsCount = 0;
  int _skippedRowsCount = 0;
  int _errorRowsCount = 0;
  final List<String> _errorMessages = [];
  
  // Caches to avoid duplicate creation
  final Map<String, String> _patientCache = {};
  final Map<String, String> _doctorCache = {};
  final Map<String, String> _serviceCache = {};
  final Map<String, String> _roomCache = {};
  final Map<String, String> _deviceCache = {};
  
  // Column mapping
  final Map<String, String?> _columnMapping = {
    'clientName': null,
    'phone': null,
    'gender': null,
    'skinType': null,
    'operatorName': null,
    'date': null,
    'time': null,
    'sessionType': null,
    'sessionNumber': null,
    'price': null,
    'room': null,
    'device': null,
    'spot': null,
    'bd': null,
    'alex': null,
    'yag': null,
    'note': null,
  };

  Future<void> _pickExcelFile() async {
    setState(() => _isLoading = true);
    
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
        withData: true,
      );
      
      if (result != null && result.files.single.bytes != null) {
        final bytes = result.files.single.bytes!;
        final excel = Excel.decodeBytes(bytes);
        
        // Get first sheet
        final sheet = excel.tables[excel.tables.keys.first]!;
        
        if (sheet.rows.isNotEmpty) {
          // First row is headers
          _headers = sheet.rows.first
              .map((cell) => cell?.value?.toString() ?? '')
              .toList();
          
          // Rest is data
          _excelData = sheet.rows.skip(1).map((row) {
            return row.map((cell) => cell?.value?.toString() ?? '').toList();
          }).toList();
          
          // Auto-detect column mapping
          _autoDetectMapping();
          
          setState(() {
            _statusMessage = 'تم تحميل ${_excelData.length} سجل';
          });
        }
      }
    } catch (e) {
      setState(() => _statusMessage = 'خطأ: $e');
    }
    
    setState(() => _isLoading = false);
  }

  void _autoDetectMapping() {
    for (int i = 0; i < _headers.length; i++) {
      final header = _headers[i].toLowerCase().trim();
      
      // Client Name / Clinite Name → Patient name
      if (header == 'client name' || header == 'clinite name' || header.contains('client')) {
        _columnMapping['clientName'] = _headers[i];
      // Operator Name / Oprater Name → Doctor name  
      } else if (header == 'operator name' || header == 'oprater name' || header.contains('operator') || header.contains('oprater')) {
        _columnMapping['operatorName'] = _headers[i];
      // Gender
      } else if (header == 'gender' || header.contains('gender')) {
        _columnMapping['gender'] = _headers[i];
      // Skin Type
      } else if (header == 'skin type' || header.contains('skin')) {
        _columnMapping['skinType'] = _headers[i];
      // Date
      } else if (header == 'date' || header.contains('date') && !header.contains('birth')) {
        _columnMapping['date'] = _headers[i];
      // Time
      } else if (header == 'time' || header.contains('time')) {
        _columnMapping['time'] = _headers[i];
      // Session Type → Service name
      } else if (header == 'session type' || header.contains('session type') || header.contains('service')) {
        _columnMapping['sessionType'] = _headers[i];
      // Session Number
      } else if (header == 'session number' || header.contains('session num')) {
        _columnMapping['sessionNumber'] = _headers[i];
      // Price
      } else if (header == 'price' || header.contains('price')) {
        _columnMapping['price'] = _headers[i];
      // Room
      } else if (header == 'room' || header.contains('room')) {
        _columnMapping['room'] = _headers[i];
      // Device (optional)
      } else if (header.contains('device') || header.contains('machine')) {
        _columnMapping['device'] = _headers[i];
      // Spot / Sopt (dynamic field)
      } else if (header == 'spot' || header == 'sopt' || header.contains('spot')) {
        _columnMapping['spot'] = _headers[i];
      // B.D (Birth Date) (dynamic field)
      } else if (header == 'b.d' || header == 'bd' || header.contains('birth')) {
        _columnMapping['bd'] = _headers[i];
      // Alex (dynamic field)
      } else if (header == 'alex' || header.contains('alex')) {
        _columnMapping['alex'] = _headers[i];
      // Yag (dynamic field)
      } else if (header == 'yag' || header.contains('yag')) {
        _columnMapping['yag'] = _headers[i];
      // Notes
      } else if (header == 'notes' || header == 'note' || header.contains('note')) {
        _columnMapping['note'] = _headers[i];
      // Phone (optional)
      } else if (header.contains('phone') || header.contains('mobile')) {
        _columnMapping['phone'] = _headers[i];
      }
    }
  }

  // Get or create patient (searches DB first, then cache, then creates)
  Future<String> _getOrCreatePatient(SupabaseClient supabase, String name, String? phone, String? gender, String? skinType) async {
    final cacheKey = name.toLowerCase().trim();
    
    // Check name cache first
    if (_patientCache.containsKey(cacheKey)) {
      return _patientCache[cacheKey]!;
    }
    
    // Check phone cache
    if (phone != null && phone.isNotEmpty) {
      final phoneKey = 'phone:$phone';
      if (_patientCache.containsKey(phoneKey)) {
        _patientCache[cacheKey] = _patientCache[phoneKey]!;
        return _patientCache[phoneKey]!;
      }
    }
    
    // Search in database by name or phone
    try {
      dynamic existing;
      if (phone != null && phone.isNotEmpty) {
        existing = await supabase
            .from('patients')
            .select('id')
            .eq('phone', phone)
            .maybeSingle();
      }
      
      existing ??= await supabase
          .from('patients')
          .select('id')
          .ilike('name', cacheKey)
          .maybeSingle();
      
      if (existing != null) {
        _patientCache[cacheKey] = existing['id'];
        if (phone != null && phone.isNotEmpty) {
          _patientCache['phone:$phone'] = existing['id'];
        }
        return existing['id'];
      }
    } catch (e) {
      debugPrint('Patient search error: $e');
    }
    
    // Not found - create new patient
    try {
      final newPatient = await supabase.from('patients').insert({
        'name': name,
        'phone': phone,
        'gender': gender?.toLowerCase() == 'male' ? 'male' : 'female',
        'skin_type': skinType ?? 'III',
      }).select('id').single();
      
      _patientCache[cacheKey] = newPatient['id'];
      if (phone != null && phone.isNotEmpty) {
        _patientCache['phone:$phone'] = newPatient['id'];
      }
      _newPatientsCount++;
      debugPrint('✅ Created patient: $name');
      return newPatient['id'];
    } catch (e) {
      debugPrint('Patient creation error: $e');
      rethrow;
    }
  }

  // Get or create doctor (creates inactive account if new)
  Future<String?> _getOrCreateDoctor(SupabaseClient supabase, String? name) async {
    if (name == null || name.trim().isEmpty) return null;
    
    final cleanName = name.trim();
    final cacheKey = cleanName.toLowerCase();
    if (_doctorCache.containsKey(cacheKey)) {
      return _doctorCache[cacheKey]!;
    }
    
    try {
      // Try to find existing doctor in profiles (exact or partial match)
      final existing = await supabase
          .from('profiles')
          .select('id')
          .eq('role', 'doctor')
          .ilike('name', '%$cleanName%')
          .maybeSingle();
      
      if (existing != null) {
        _doctorCache[cacheKey] = existing['id'];
        return existing['id'];
      }
      
      // Create new doctor profile with temp credentials
      final safeName = cleanName.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toLowerCase();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      
      final newDoctor = await supabase.from('profiles').insert({
        'name': cleanName,
        'role': 'doctor',
        'is_active': false,          // غير مفعّل
        'username': 'dr_${safeName}_$timestamp',  // username مؤقت
        'password': 'changeme123',   // كلمة سر مؤقتة
        'email': 'dr.$safeName.$timestamp@imported.temp',
      }).select('id').single();
      
      _doctorCache[cacheKey] = newDoctor['id'];
      _newDoctorsCount++;
      debugPrint('✅ Created doctor: $cleanName');
      return newDoctor['id'];
    } catch (e) {
      debugPrint('❌ Doctor creation error for "$cleanName": $e');
      _errorMessages.add('فشل إنشاء طبيب: $cleanName - $e');
      return null;
    }
  }

  // Get or create service (searches DB first, then creates)
  Future<String?> _getOrCreateService(SupabaseClient supabase, String? serviceName, {double? price}) async {
    if (serviceName == null || serviceName.trim().isEmpty) return null;
    
    final cacheKey = serviceName.toLowerCase().trim();
    if (_serviceCache.containsKey(cacheKey)) {
      return _serviceCache[cacheKey]!;
    }
    
    // Search in database first
    try {
      final existing = await supabase
          .from('services')
          .select('id')
          .ilike('name', '%${serviceName.trim()}%')
          .maybeSingle();
      
      if (existing != null) {
        _serviceCache[cacheKey] = existing['id'];
        return existing['id'];
      }
    } catch (e) {
      debugPrint('Service search error: $e');
    }
    
    // Not found - create new service with price
    try {
      final newService = await supabase.from('services').insert({
        'name': serviceName.trim(),
        'default_price': price ?? 0,
        'is_active': true,
      }).select('id').single();
      
      _serviceCache[cacheKey] = newService['id'];
      _newServicesCount++;
      debugPrint('✅ Created service: $serviceName (price: ${price ?? 0})');
      return newService['id'];
    } catch (e) {
      debugPrint('Service creation error: $e');
      _errorMessages.add('فشل إنشاء خدمة: $serviceName - $e');
      return null;
    }
  }

  // Get or create room (searches DB first, then creates)
  Future<String?> _getOrCreateRoom(SupabaseClient supabase, String? roomName) async {
    if (roomName == null || roomName.trim().isEmpty) return null;
    
    final cacheKey = roomName.toLowerCase().trim();
    if (_roomCache.containsKey(cacheKey)) {
      return _roomCache[cacheKey]!;
    }
    
    // Search in database first
    try {
      final existing = await supabase
          .from('rooms')
          .select('id')
          .ilike('name', '%${roomName.trim()}%')
          .maybeSingle();
      
      if (existing != null) {
        _roomCache[cacheKey] = existing['id'];
        return existing['id'];
      }
    } catch (e) {
      debugPrint('Room search error: $e');
      // Table might not exist, continue to create
    }
    
    // Not found - create new room
    try {
      final newRoom = await supabase.from('rooms').insert({
        'name': roomName.trim(),
        'is_active': true,
      }).select('id').single();
      
      _roomCache[cacheKey] = newRoom['id'];
      _newRoomsCount++;
      debugPrint('✅ Created room: $roomName');
      return newRoom['id'];
    } catch (e) {
      debugPrint('Room creation error: $e');
      // Table might not exist - just return null and store in dynamic fields
      return null;
    }
  }
  
  // Get or create device
  Future<String?> _getOrCreateDevice(SupabaseClient supabase, String? deviceName) async {
    if (deviceName == null || deviceName.trim().isEmpty) return null;
    
    final cacheKey = deviceName.toLowerCase().trim();
    if (_deviceCache.containsKey(cacheKey)) {
      return _deviceCache[cacheKey]!;
    }
    
    try {
      // Try to find existing device
      final existing = await supabase
          .from('devices')
          .select('id')
          .ilike('name', '%$deviceName%')
          .maybeSingle();
      
      if (existing != null) {
        _deviceCache[cacheKey] = existing['id'];
        return existing['id'];
      }
      
      // Create new device
      final newDevice = await supabase.from('devices').insert({
        'name': deviceName.trim(),
        'status': 'active',
      }).select('id').single();
      
      _deviceCache[cacheKey] = newDevice['id'];
      return newDevice['id'];
    } catch (e) {
      debugPrint('Device error: $e');
      return null;
    }
  }

  String? _getValue(List<dynamic> row, String mappingKey) {
    final columnName = _columnMapping[mappingKey];
    if (columnName == null) return null;
    final index = _headers.indexOf(columnName);
    if (index < 0 || index >= row.length) return null;
    final value = row[index]?.toString();
    return (value?.isEmpty ?? true) ? null : value;
  }

  // Parse date from various formats
  DateTime? _parseDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return null;
    
    try {
      // Try ISO format first (2024-01-15)
      if (dateStr.contains('-') && !dateStr.contains('/')) {
        return DateTime.parse(dateStr.split(' ').first);
      }
      
      // Try slash format (MM/DD/YYYY or DD/MM/YYYY)
      if (dateStr.contains('/')) {
        final parts = dateStr.split('/');
        if (parts.length >= 3) {
          int p1 = int.tryParse(parts[0]) ?? 1;
          int p2 = int.tryParse(parts[1]) ?? 1;
          int year = int.tryParse(parts[2]) ?? DateTime.now().year;
          if (year < 100) year += 2000; // Handle 2-digit years
          
          // Determine if MM/DD or DD/MM based on values
          if (p1 > 12) {
            // p1 is day, p2 is month (DD/MM/YYYY)
            return DateTime(year, p2, p1);
          } else {
            // Assume MM/DD/YYYY
            return DateTime(year, p1, p2);
          }
        }
      }
      
      // Try parsing as number (Excel serial date)
      final numDate = double.tryParse(dateStr);
      if (numDate != null && numDate > 40000 && numDate < 50000) {
        // Excel date serial number
        return DateTime(1899, 12, 30).add(Duration(days: numDate.toInt()));
      }
    } catch (e) {
      debugPrint('Date parse error for "$dateStr": $e');
    }
    
    return null;
  }

  // Parse time from various formats
  (int, int) _parseTime(String? timeStr) {
    if (timeStr == null || timeStr.isEmpty) return (10, 0);
    
    try {
      // Remove spaces and common separators
      String cleaned = timeStr.trim().replaceAll(' ', '');
      bool isPM = cleaned.toLowerCase().contains('pm') || cleaned.contains('م');
      bool isAM = cleaned.toLowerCase().contains('am') || cleaned.contains('ص');
      
      // Extract just the numbers
      cleaned = cleaned.replaceAll(RegExp(r'[^0-9:]'), '');
      
      if (cleaned.contains(':')) {
        final parts = cleaned.split(':');
        int hour = int.tryParse(parts[0]) ?? 10;
        int minute = int.tryParse(parts[1]) ?? 0;
        
        // Handle AM/PM
        if (isPM && hour != 12) hour += 12;
        if (isAM && hour == 12) hour = 0;
        
        return (hour.clamp(0, 23), minute.clamp(0, 59));
      }
      
      // Handle decimal time (e.g., 14.5 = 2:30 PM)
      final numTime = double.tryParse(cleaned);
      if (numTime != null) {
        int hour = numTime.floor();
        int minute = ((numTime - hour) * 60).round();
        return (hour.clamp(0, 23), minute.clamp(0, 59));
      }
    } catch (e) {
      debugPrint('Time parse error for "$timeStr": $e');
    }
    
    return (10, 0); // Default time
  }

  // Pre-load existing data for faster import
  Future<void> _preloadExistingData(SupabaseClient supabase) async {
    try {
      // Load all doctors
      final doctors = await supabase.from('profiles').select('id, name').eq('role', 'doctor');
      for (var doc in doctors) {
        if (doc['name'] != null) {
          _doctorCache[doc['name'].toString().toLowerCase()] = doc['id'];
        }
      }
      debugPrint('📌 Pre-loaded ${_doctorCache.length} doctors');
      
      // Load all services
      final services = await supabase.from('services').select('id, name');
      for (var svc in services) {
        if (svc['name'] != null) {
          _serviceCache[svc['name'].toString().toLowerCase()] = svc['id'];
        }
      }
      debugPrint('📌 Pre-loaded ${_serviceCache.length} services');
      
      // Load all patients (name + phone)
      final patients = await supabase.from('patients').select('id, name, phone');
      for (var pat in patients) {
        if (pat['name'] != null) {
          _patientCache[pat['name'].toString().toLowerCase()] = pat['id'];
        }
        if (pat['phone'] != null && pat['phone'].toString().isNotEmpty) {
          _patientCache['phone:${pat['phone']}'] = pat['id'];
        }
      }
      debugPrint('📌 Pre-loaded ${_patientCache.length} patients');
      
      // Load rooms (if table exists)
      try {
        final rooms = await supabase.from('rooms').select('id, name');
        for (var room in rooms) {
          if (room['name'] != null) {
            _roomCache[room['name'].toString().toLowerCase()] = room['id'];
          }
        }
        debugPrint('📌 Pre-loaded ${_roomCache.length} rooms');
      } catch (_) {}
      
      // Load devices (if table exists)
      try {
        final devices = await supabase.from('devices').select('id, name');
        for (var dev in devices) {
          if (dev['name'] != null) {
            _deviceCache[dev['name'].toString().toLowerCase()] = dev['id'];
          }
        }
        debugPrint('📌 Pre-loaded ${_deviceCache.length} devices');
      } catch (_) {}
      
    } catch (e) {
      debugPrint('Pre-load error: $e');
    }
  }

  Future<void> _startImport() async {
    if (_excelData.isEmpty) return;
    
    // Reset counters
    _newPatientsCount = 0;
    _newDoctorsCount = 0;
    _newServicesCount = 0;
    _newRoomsCount = 0;
    _newSessionsCount = 0;
    _skippedRowsCount = 0;
    _errorRowsCount = 0;
    _errorMessages.clear();
    _patientCache.clear();
    _doctorCache.clear();
    _serviceCache.clear();
    _roomCache.clear();
    _deviceCache.clear();
    
    setState(() {
      _isImporting = true;
      _importedCount = 0;
      _totalCount = _excelData.length;
      _statusMessage = 'جاري تحميل البيانات الحالية...';
    });
    
    final supabase = Supabase.instance.client;
    
    // Pre-load existing data for faster lookup
    await _preloadExistingData(supabase);
    
    setState(() {
      _statusMessage = 'جاري الاستيراد...';
    });
    
    for (int rowIndex = 0; rowIndex < _excelData.length; rowIndex++) {
      final row = _excelData[rowIndex];
      
      try {
        final clientName = _getValue(row, 'clientName');
        if (clientName == null || clientName.trim().isEmpty) {
          _skippedRowsCount++;
          _importedCount++;
          setState(() => _statusMessage = 'جاري الاستيراد... ($_importedCount/$_totalCount)');
          continue;
        }
        
        // Get or create patient
        String patientId;
        try {
          patientId = await _getOrCreatePatient(
            supabase,
            clientName.trim(),
            _getValue(row, 'phone'),
            _getValue(row, 'gender'),
            _getValue(row, 'skinType'),
          );
        } catch (e) {
          _errorRowsCount++;
          _errorMessages.add('صف ${rowIndex + 2}: خطأ إنشاء المريض - $e');
          _importedCount++;
          continue;
        }
        
        // Get doctor (optional - don't fail if not found)
        String? doctorId = await _getOrCreateDoctor(supabase, _getValue(row, 'operatorName'));
        
        // Get or create service with price
        String? serviceId;
        final priceStr = _getValue(row, 'price');
        final price = double.tryParse(priceStr?.replaceAll(',', '').replaceAll('ر.س', '').trim() ?? '0') ?? 0;
        // Use sessionType as service name
        final serviceName = _getValue(row, 'sessionType');
        try {
          serviceId = await _getOrCreateService(supabase, serviceName, price: price);
        } catch (e) {
          debugPrint('Service error: $e');
        }
        
        // Get room (optional - don't fail if not found)
        String? roomId = await _getOrCreateRoom(supabase, _getValue(row, 'room'));
        
        // Get device (optional - don't fail if not found)
        String? deviceId = await _getOrCreateDevice(supabase, _getValue(row, 'device'));
        
        // Parse date and time
        final dateStr = _getValue(row, 'date');
        final timeStr = _getValue(row, 'time');
        
        DateTime? startTime = _parseDate(dateStr);
        startTime ??= DateTime.now();
        
        final (hour, minute) = _parseTime(timeStr);
        startTime = DateTime(startTime.year, startTime.month, startTime.day, hour, minute);
        
        // Build dynamic fields - include ALL extra data
        final dynamicFields = <String, dynamic>{};
        
        // Standard laser fields
        if (_getValue(row, 'spot') != null) dynamicFields['Spot'] = _getValue(row, 'spot');
        if (_getValue(row, 'bd') != null) dynamicFields['B.D'] = _getValue(row, 'bd');
        if (_getValue(row, 'alex') != null) dynamicFields['Alex'] = _getValue(row, 'alex');
        if (_getValue(row, 'yag') != null) dynamicFields['Yag'] = _getValue(row, 'yag');
        if (_getValue(row, 'sessionNumber') != null) dynamicFields['Session Number'] = _getValue(row, 'sessionNumber');
        
        // Store doctor name if no ID found
        final doctorName = _getValue(row, 'operatorName');
        if (doctorId == null && doctorName != null && doctorName.isNotEmpty) {
          dynamicFields['Operator'] = doctorName;
        }
        
        // Store room name if no ID found  
        final roomName = _getValue(row, 'room');
        if (roomId == null && roomName != null && roomName.isNotEmpty) {
          dynamicFields['Room'] = roomName;
        }
        
        // Store device name if no ID found
        final deviceName = _getValue(row, 'device');
        if (deviceId == null && deviceName != null && deviceName.isNotEmpty) {
          dynamicFields['Device'] = deviceName;
        }
        
        // Create session
        try {
          final sessionData = <String, dynamic>{
            'patient_id': patientId,
            'doctor_id': doctorId,
            'service_id': serviceId,
            'start_time': startTime.toIso8601String(),
            'end_time': startTime.add(const Duration(minutes: 30)).toIso8601String(),
            'service_type': serviceName ?? 'General',
            'price': price,
            'notes': _getValue(row, 'note'),
            'status': 'completed',
            'room': _getValue(row, 'room'),
            'session_number': int.tryParse(_getValue(row, 'sessionNumber') ?? '1') ?? 1,
          };
          
          // Add medical_notes as JSONB if we have dynamic fields
          if (dynamicFields.isNotEmpty) {
            sessionData['medical_notes'] = dynamicFields;
          }
          
          await supabase.from('sessions').insert(sessionData);
          
          _newSessionsCount++;
        } catch (e) {
          _errorRowsCount++;
          _errorMessages.add('صف ${rowIndex + 2}: خطأ إنشاء الجلسة - $e');
        }
        
      } catch (e) {
        _errorRowsCount++;
        _errorMessages.add('صف ${rowIndex + 2}: $e');
      }
      
      setState(() {
        _importedCount++;
        _statusMessage = 'جاري الاستيراد... ($_importedCount/$_totalCount)';
      });
    }
    
    // Show summary
    setState(() {
      String summary = '''📊 ملخص الاستيراد:
━━━━━━━━━━━━━━━━━━━━━
✅ جلسات مستوردة: $_newSessionsCount
👤 مرضى جدد: $_newPatientsCount
👨‍⚕️ أطباء جدد: $_newDoctorsCount
🏥 خدمات جديدة: $_newServicesCount
🚪 غرف جديدة: $_newRoomsCount''';
      
      if (_newDoctorsCount > 0) {
        summary += '\n\n💡 تم إنشاء $_newDoctorsCount طبيب جديد بحالة "غير مفعّل"';
        summary += '\n   ← افتح "إدارة الموظفين" لتفعيلهم وإضافة كلمة السر';
      }
      
      if (_skippedRowsCount > 0) {
        summary += '\n⏭️ صفوف فارغة: $_skippedRowsCount';
      }
      if (_errorRowsCount > 0) {
        summary += '\n❌ صفوف فاشلة: $_errorRowsCount';
      }
      
      // Add first few error messages
      if (_errorMessages.isNotEmpty) {
        summary += '\n\n⚠️ رسائل الأخطاء:';
        for (int i = 0; i < _errorMessages.length && i < 5; i++) {
          summary += '\n• ${_errorMessages[i]}';
        }
        if (_errorMessages.length > 5) {
          summary += '\n... و${_errorMessages.length - 5} أخطاء أخرى';
        }
      }
      
      _statusMessage = summary;
      _isImporting = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('استيراد بيانات Excel'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Step 1: Pick File
            _buildSection(
              title: '1️⃣ اختر ملف Excel',
              child: Row(
                children: [
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    ),
                    onPressed: _isLoading ? null : _pickExcelFile,
                    icon: _isLoading 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.upload_file),
                    label: const Text('اختيار ملف'),
                  ),
                  const SizedBox(width: 16),
                  if (_excelData.isNotEmpty)
                    Text('📊 ${_excelData.length} سجل', style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Step 2: Column Mapping
            if (_headers.isNotEmpty) ...[
              _buildSection(
                title: '2️⃣ ربط الأعمدة',
                child: Wrap(
                  spacing: 16,
                  runSpacing: 8,
                  children: _columnMapping.entries.map((e) {
                    return SizedBox(
                      width: 200,
                      child: DropdownButtonFormField<String>(
                        value: e.value,
                        decoration: InputDecoration(
                          labelText: _getArabicLabel(e.key),
                          isDense: true,
                          border: const OutlineInputBorder(),
                        ),
                        items: [
                          const DropdownMenuItem(value: null, child: Text('-- تخطي --')),
                          ..._headers.map((h) => DropdownMenuItem(value: h, child: Text(h))),
                        ],
                        onChanged: (v) => setState(() => _columnMapping[e.key] = v),
                      ),
                    );
                  }).toList(),
                ),
              ),
              
              const SizedBox(height: 24),
            ],
            
            // Step 3: Preview
            if (_excelData.isNotEmpty) ...[
              _buildSection(
                title: '3️⃣ معاينة البيانات (أول 5 سجلات)',
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowColor: WidgetStateProperty.all(AppTheme.primary.withAlpha(26)),
                    columns: _headers.map((h) => DataColumn(label: Text(h, style: const TextStyle(fontWeight: FontWeight.bold)))).toList(),
                    rows: _excelData.take(5).map((row) {
                      return DataRow(
                        cells: row.map((cell) => DataCell(Text(cell.toString()))).toList(),
                      );
                    }).toList(),
                  ),
                ),
              ),
              
              const SizedBox(height: 24),
            ],
            
            // Step 4: Import
            if (_excelData.isNotEmpty)
              _buildSection(
                title: '4️⃣ بدء الاستيراد',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      ),
                      onPressed: _isImporting ? null : _startImport,
                      icon: _isImporting 
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.play_arrow),
                      label: Text(_isImporting ? 'جاري الاستيراد...' : 'بدء الاستيراد'),
                    ),
                    const SizedBox(height: 16),
                    if (_isImporting)
                      LinearProgressIndicator(
                        value: _totalCount > 0 ? _importedCount / _totalCount : 0,
                        backgroundColor: Colors.white10,
                        valueColor: const AlwaysStoppedAnimation(Colors.green),
                      ),
                    const SizedBox(height: 8),
                    Text(_statusMessage, style: TextStyle(
                      color: _statusMessage.contains('✅') ? Colors.green : 
                             _statusMessage.contains('❌') ? Colors.red : Colors.white70,
                    )),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  String _getArabicLabel(String key) {
    switch (key) {
      case 'clientName': return 'اسم المريض';
      case 'phone': return 'رقم الهاتف';
      case 'gender': return 'الجنس';
      case 'skinType': return 'نوع البشرة';
      case 'operatorName': return 'الطبيب';
      case 'date': return 'التاريخ';
      case 'time': return 'الوقت';
      case 'sessionType': return 'نوع الجلسة';
      case 'sessionNumber': return 'رقم الجلسة';
      case 'price': return 'السعر';
      case 'room': return 'الغرفة';
      case 'spot': return 'Spot';
      case 'bd': return 'B.D';
      case 'alex': return 'Alex';
      case 'yag': return 'Yag';
      case 'note': return 'الملاحظات';
      default: return key;
    }
  }
}
