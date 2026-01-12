import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'schedule_provider.dart';
import '../admin/admin_provider.dart';

class BookingDialog extends StatefulWidget {
  final DateTime initialDate; 
  final String? preselectedDoctorId;

  const BookingDialog({super.key, required this.initialDate, this.preselectedDoctorId});

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
  String? _selectedDoctorId;
  String? _selectedServiceId;
  String? _selectedDeviceId;
  String? _selectedRoom;
  String _selectedGender = 'female';
  String _selectedSource = 'walk_in';

  @override
  void initState() {
    super.initState();
    _selectedTime = TimeOfDay.fromDateTime(widget.initialDate);
    _selectedDoctorId = widget.preselectedDoctorId;
    
    // Load services/devices if empty
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final admin = context.read<AdminProvider>();
      // We assume services/devices might already be loaded or need loading
      if (admin.services.isEmpty) admin.loadServices();
      if (admin.devices.isEmpty) admin.loadDevices();
    });
  }

  @override
  Widget build(BuildContext context) {
    final admin = context.watch<AdminProvider>();
    // final schedule = context.watch<ScheduleProvider>(); // Not strictly needed for build unless utilizing state

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
              
              TextField(
                controller: _patientSearchController,
                decoration: const InputDecoration(
                  labelText: 'اسم المريض',
                  prefixIcon: Icon(Icons.person),
                  hintText: 'ابحث أو ادخل اسم جديد',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
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
                    child: DropdownButtonFormField<String>(initialValue: _selectedGender,
                      decoration: const InputDecoration(labelText: 'الجنس', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                      items: const [
                        DropdownMenuItem(value: 'female', child: Text('أنثى')),
                        DropdownMenuItem(value: 'male', child: Text('ذكر')),
                      ],
                      onChanged: (val) => setState(() => _selectedGender = val!),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(initialValue: _selectedSource,
                      decoration: const InputDecoration(labelText: 'المصدر', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                      items: const [
                        DropdownMenuItem(value: 'walk_in', child: Text('حضور مباشر')),
                        DropdownMenuItem(value: 'call_center', child: Text('مركز الاتصال')),
                        DropdownMenuItem(value: 'social_media', child: Text('سوشيال ميديا')),
                        DropdownMenuItem(value: 'referral', child: Text('توصية')),
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
                  return DropdownButtonFormField<String>(initialValue: _selectedDoctorId,
                    decoration: const InputDecoration(labelText: 'الطبيب المعالج', prefixIcon: Icon(Icons.medical_services), border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                    items: provider.doctors.map((doc) {
                      return DropdownMenuItem(value: doc.id, child: Text(doc.name));
                    }).toList(),
                    onChanged: widget.preselectedDoctorId != null 
                      ? null 
                      : (val) => setState(() => _selectedDoctorId = val),
                    validator: (val) => val == null ? 'يرجى اختيار الطبيب' : null,
                  );
                }
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(initialValue: _selectedServiceId,
                      decoration: const InputDecoration(labelText: 'الخدمة', prefixIcon: Icon(Icons.local_hospital), border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                      items: admin.services.map((s) => DropdownMenuItem(
                        value: s['id'] as String, 
                        child: Text('${s['name']} (${s['default_price']} د.ع)'),
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
                    child: DropdownButtonFormField<String>(initialValue: _selectedDeviceId,
                      decoration: const InputDecoration(labelText: 'الجهاز / الغرفة', prefixIcon: Icon(Icons.precision_manufacturing), border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('بدون جهاز')),
                        ...admin.devices.where((d) => d['status'] == 'active').map((d) => DropdownMenuItem(
                          value: d['id'] as String, 
                          child: Text(d['name']),
                        )),
                      ],
                      onChanged: (val) => setState(() => _selectedDeviceId = val),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(initialValue: _selectedRoom,
                      decoration: const InputDecoration(labelText: 'الغرفة', prefixIcon: Icon(Icons.meeting_room), border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                      items: const [
                        DropdownMenuItem(value: 'غرفة ليزر 1', child: Text('غرفة 1')),
                        DropdownMenuItem(value: 'غرفة ليزر 2', child: Text('غرفة 2')),
                        DropdownMenuItem(value: 'غرفة ليزر 3', child: Text('غرفة 3')),
                        DropdownMenuItem(value: 'الاستشارة', child: Text('الاستشارة')),
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
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
        ElevatedButton(
          onPressed: _validateAndSave,
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6C63FF), foregroundColor: Colors.white),
          child: const Text('تأكيد الحجز'),
        ),
      ],
    );
  }

  Future<void> _pickTime() async {
    final t = await showTimePicker(context: context, initialTime: _selectedTime);
    if (t != null) setState(() => _selectedTime = t);
  }

  Future<void> _validateAndSave() async {
    if (_selectedDoctorId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('يرجى اختيار الطبيب')));
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
    final end = start.add(Duration(minutes: _durationMinutes));

    // 1. Conflict Check
    final hasConflict = await provider.checkConflict(_selectedDoctorId!, start, end);
    
    if (hasConflict && mounted) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('تنبيه: تعارض', style: TextStyle(color: Colors.orange)),
          content: const Text('يوجد موعد آخر لهذا الطبيب في نفس الوقت. هل تود المتابعة؟'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              onPressed: () {
                Navigator.pop(ctx);
                _save(provider, admin, start);
              }, 
              child: const Text('متابعة وحجز'),
            ),
          ],
        ),
      );
    } else {
      _save(provider, admin, start);
    }
  }

  Future<void> _save(ScheduleProvider provider, AdminProvider admin, DateTime start) async {
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
        doctorId: _selectedDoctorId!,
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
         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم الحجز بنجاح')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
      }
    }
  }
}
