import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'schedule_provider.dart';
import '../admin/admin_provider.dart';

class BookingDialog extends StatefulWidget {
  final DateTime initialDate; 
  final String? preselectedDepartmentId; // تغيير من Doctor إلى Department

  const BookingDialog({super.key, required this.initialDate, this.preselectedDepartmentId});

  @override
  State<BookingDialog> createState() => _BookingDialogState();
}

class _BookingDialogState extends State<BookingDialog> {
  // Controllers
  final _patientSearchController = TextEditingController();
  final _phoneController = TextEditingController();
  final _ageController = TextEditingController();
  final _addressController = TextEditingController();
  final _notesController = TextEditingController();
  
  // State
  int _durationMinutes = 30; 
  TimeOfDay _selectedTime = const TimeOfDay(hour: 12, minute: 0);
  String? _selectedDepartmentId; // تغيير من Doctor إلى Department
  String? _selectedServiceId;
  String? _selectedDeviceId;
  String? _selectedRoom;
  String _selectedGender = 'female';
  String _selectedSource = 'walk_in';
  bool _isSaving = false; // منع النقر المزدوج
  
  // Patient search
  List<Map<String, dynamic>> _patientSuggestions = [];
  String? _selectedPatientId;
  // ignore: unused_field - tracked for UI state
  bool _isNewPatient = true;

  @override
  void initState() {
    super.initState();
    _selectedTime = TimeOfDay.fromDateTime(widget.initialDate);
    _selectedDepartmentId = widget.preselectedDepartmentId;
    
    // Load services/devices if empty
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final admin = context.read<AdminProvider>();
      if (admin.services.isEmpty) admin.loadServices();
      if (admin.devices.isEmpty) admin.loadDevices();
    });
  }

  Future<void> _searchPatients(String query) async {
    if (query.length < 2) {
      setState(() => _patientSuggestions = []);
      return;
    }
    
    try {
      final supabase = Supabase.instance.client;
      final results = await supabase
          .from('patients')
          .select()
          .or('name.ilike.%$query%,phone.ilike.%$query%')
          .limit(5);
      
      setState(() {
        _patientSuggestions = List<Map<String, dynamic>>.from(results);
      });
    } catch (e) {
      debugPrint('Error searching patients: $e');
    }
  }

  void _selectPatient(Map<String, dynamic> patient) {
    setState(() {
      _selectedPatientId = patient['id'];
      _patientSearchController.text = patient['name'] ?? '';
      _phoneController.text = patient['phone'] ?? '';
      _ageController.text = (patient['age'] ?? '').toString();
      _addressController.text = patient['address'] ?? '';
      _selectedGender = patient['gender'] ?? 'female';
      _isNewPatient = false;
      _patientSuggestions = [];
    });
  }

  @override
  Widget build(BuildContext context) {
    final admin = context.watch<AdminProvider>();

    return AlertDialog(
      title: const Text('حجز موعد جديد'),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 1. Patient Info
              const Align(
                alignment: Alignment.centerRight,
                child: Text('معلومات المريض', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
              ),
              const SizedBox(height: 10),
              
              // Patient Search with Autocomplete
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _patientSearchController,
                    decoration: InputDecoration(
                      labelText: 'اسم المريض',
                      prefixIcon: const Icon(Icons.person),
                      suffixIcon: _selectedPatientId != null
                          ? const Icon(Icons.check_circle, color: Colors.green)
                          : null,
                      hintText: 'ابحث بالاسم أو رقم الهاتف',
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    onChanged: (value) {
                      _selectedPatientId = null;
                      _isNewPatient = true;
                      _searchPatients(value);
                    },
                  ),
                  // Suggestions list
                  if (_patientSuggestions.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      decoration: BoxDecoration(
                        color: Colors.grey[800],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue),
                      ),
                      child: Column(
                        children: _patientSuggestions.map((patient) => ListTile(
                          dense: true,
                          leading: const CircleAvatar(child: Icon(Icons.person, size: 18)),
                          title: Text(patient['name'] ?? 'بدون اسم'),
                          subtitle: Text(patient['phone'] ?? ''),
                          trailing: Text('عمر: ${patient['age'] ?? '-'}'),
                          onTap: () => _selectPatient(patient),
                        )).toList(),
                      ),
                    ),
                  if (_selectedPatientId != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.green.withAlpha(26),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.check_circle, color: Colors.green, size: 18),
                            SizedBox(width: 8),
                            Text('تم اختيار مريض موجود مسبقاً', style: TextStyle(color: Colors.green)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: _phoneController,
                      decoration: const InputDecoration(
                        labelText: 'رقم الهاتف', 
                        prefixIcon: Icon(Icons.phone), 
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      keyboardType: TextInputType.phone,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _ageController,
                      decoration: const InputDecoration(
                        labelText: 'العمر', 
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedGender,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'الجنس', border: OutlineInputBorder(), isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8)),
                      items: const [
                        DropdownMenuItem(value: 'female', child: Text('أنثى', style: TextStyle(fontSize: 12))),
                        DropdownMenuItem(value: 'male', child: Text('ذكر', style: TextStyle(fontSize: 12))),
                      ],
                      onChanged: (val) => setState(() => _selectedGender = val!),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedSource,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'المصدر', border: OutlineInputBorder(), isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8)),
                      items: const [
                        DropdownMenuItem(value: 'walk_in', child: Text('حضور', style: TextStyle(fontSize: 12))),
                        DropdownMenuItem(value: 'call_center', child: Text('اتصال', style: TextStyle(fontSize: 12))),
                        DropdownMenuItem(value: 'social_media', child: Text('سوشيال', style: TextStyle(fontSize: 12))),
                        DropdownMenuItem(value: 'referral', child: Text('توصية', style: TextStyle(fontSize: 12))),
                      ],
                      onChanged: (val) => setState(() => _selectedSource = val!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              
              // 2. Booking Details
              const Align(
                alignment: Alignment.centerRight,
                child: Text('تفاصيل الحجز', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
              ),
              const SizedBox(height: 10),
              
              Consumer<ScheduleProvider>(
                builder: (context, provider, child) {
                  return DropdownButtonFormField<String>(
                    value: _selectedDepartmentId,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'القسم', prefixIcon: Icon(Icons.business, size: 18), border: OutlineInputBorder(), isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8)),
                    items: provider.departments.entries.where((e) => e.key != 'all').map((dept) {
                      return DropdownMenuItem(value: dept.key, child: Text(dept.value));
                    }).toList(),
                    onChanged: widget.preselectedDepartmentId != null 
                      ? null 
                      : (val) => setState(() => _selectedDepartmentId = val),
                    validator: (val) => val == null ? 'يرجى اختيار القسم' : null,
                  );
                }
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedServiceId,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'الخدمة', prefixIcon: Icon(Icons.local_hospital, size: 18), border: OutlineInputBorder(), isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8)),
                      items: admin.services.map((s) => DropdownMenuItem(
                        value: s['id'] as String, 
                        child: Text('${s['name']}', style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
                      )).toList(),
                      onChanged: (val) => setState(() => _selectedServiceId = val),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Device & Room
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedDeviceId,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'الجهاز', prefixIcon: Icon(Icons.precision_manufacturing, size: 18), border: OutlineInputBorder(), isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8)),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('بدون', style: TextStyle(fontSize: 11))),
                        ...admin.devices.where((d) => d['status'] == 'active').map((d) => DropdownMenuItem(
                          value: d['id'] as String, 
                          child: Text(d['name'], style: const TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis),
                        )),
                      ],
                      onChanged: (val) => setState(() => _selectedDeviceId = val),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedRoom,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'الغرفة', prefixIcon: Icon(Icons.meeting_room, size: 18), border: OutlineInputBorder(), isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8)),
                      items: const [
                        DropdownMenuItem(value: 'غرفة ليزر 1', child: Text('غرفة 1', style: TextStyle(fontSize: 11))),
                        DropdownMenuItem(value: 'غرفة ليزر 2', child: Text('غرفة 2', style: TextStyle(fontSize: 11))),
                        DropdownMenuItem(value: 'غرفة ليزر 3', child: Text('غرفة 3', style: TextStyle(fontSize: 11))),
                        DropdownMenuItem(value: 'الاستشارة', child: Text('استشارة', style: TextStyle(fontSize: 11))),
                      ],
                      onChanged: (val) => setState(() => _selectedRoom = val),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              
              // Time & Duration
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: _pickTime,
                      child: InputDecorator(
                        decoration: const InputDecoration(labelText: 'الوقت', prefixIcon: Icon(Icons.access_time), border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                        child: Text(_selectedTime.format(context)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      initialValue: _durationMinutes.toString(),
                      decoration: const InputDecoration(labelText: 'المدة (د)', prefixIcon: Icon(Icons.timer), border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                      keyboardType: TextInputType.number,
                      onChanged: (val) => setState(() => _durationMinutes = int.tryParse(val) ?? 30),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              
              TextField(
                controller: _notesController,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'ملاحظات', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context), 
          child: const Text('إلغاء'),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : _validateAndSave,
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6C63FF), foregroundColor: Colors.white),
          child: _isSaving 
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Text('تأكيد الحجز'),
        ),
      ],
    );
  }

  Future<void> _pickTime() async {
    final t = await showTimePicker(context: context, initialTime: _selectedTime);
    if (t != null) setState(() => _selectedTime = t);
  }

  Future<void> _validateAndSave() async {
    if (_selectedDepartmentId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('يرجى اختيار القسم')));
      return;
    }
    if (_patientSearchController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('يرجى إدخال اسم المريض')));
      return;
    }
    if (_selectedServiceId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('يرجى اختيار الخدمة')));
      return;
    }

    final provider = context.read<ScheduleProvider>();
    final admin = context.read<AdminProvider>(); 
    
    final start = DateTime(
      widget.initialDate.year, 
      widget.initialDate.month, 
      widget.initialDate.day, 
      _selectedTime.hour, 
      _selectedTime.minute
    );
    // ignore: unused_local_variable - end time calculated for future use
    final end = start.add(Duration(minutes: _durationMinutes));

    // لا نحتاج للتحقق من التعارض لأن الحجز بالقسم وليس بالدكتور
    // الدكتور سيتم تعيينه لاحقاً عند الدفع
    _save(provider, admin, start);
  }

  Future<void> _save(ScheduleProvider provider, AdminProvider admin, DateTime start) async {
    // منع التكرار
    if (_isSaving) return;
    
    setState(() => _isSaving = true);
    
    try {
      final serviceEntry = admin.services.firstWhere((s) => s['id'] == _selectedServiceId);
      final serviceName = serviceEntry['name'];
      
      await provider.addBooking(
        patientName: _patientSearchController.text,
        patientPhone: _phoneController.text,
        patientAge: int.tryParse(_ageController.text),
        patientGender: _selectedGender,
        patientAddress: _addressController.text,
        source: _selectedSource,
        departmentId: _selectedDepartmentId!, // القسم بدلاً من الدكتور
        startTime: start,
        durationMinutes: _durationMinutes,
        serviceType: serviceName, 
        serviceId: _selectedServiceId,
        deviceId: _selectedDeviceId,
        room: _selectedRoom,
        notes: _notesController.text,
      );
      
      if (mounted) {
         Navigator.pop(context, true);
         ScaffoldMessenger.of(context).showSnackBar(
           const SnackBar(content: Text('✅ تم الحجز بنجاح'), backgroundColor: Colors.green),
         );
      }
    } catch (e) {
      debugPrint('Booking error: $e');
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ خطأ: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}
