import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';
import 'schedule_provider.dart';
import 'models.dart';
import 'booking_dialog.dart';

class TimelineView extends StatefulWidget {
  const TimelineView({super.key});

  @override
  State<TimelineView> createState() => _TimelineViewState();
}

class _TimelineViewState extends State<TimelineView> {
  double _baseHourHeight = 100.0;
  
  // Shared scroll controller for synchronized scrolling
  final ScrollController _verticalScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ScheduleProvider>().loadData();
    });
  }

  @override
  void dispose() {
    _verticalScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ScheduleProvider>();
    
    if (provider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return GestureDetector(
      onScaleStart: (details) {
        _baseHourHeight = provider.hourHeight;
      },
      onScaleUpdate: (details) {
        if (details.pointerCount == 2) { 
           // Calculate new height based on scale
           final newHeight = _baseHourHeight * details.verticalScale;
           provider.setZoom(newHeight);
        }
      },
      child: Column(
        children: [
          _buildHeader(provider),
          Expanded(
            child: SingleChildScrollView(
              controller: _verticalScrollController,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTimeColumn(provider),
                  ...provider.doctors.map((doctor) => 
                    _buildDoctorColumn(doctor, provider.bookings, provider)
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(ScheduleProvider provider) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: AppTheme.surface,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            SizedBox(
              width: 180,
              child: DropdownButtonFormField<String>(initialValue: provider.selectedDepartmentId,
                decoration: const InputDecoration(
                  labelText: 'القسم',
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  isDense: true,
                ),
                items: provider.departments.entries.map((e) {
                  return DropdownMenuItem(value: e.key, child: Text(e.value));
                }).toList(),
                onChanged: (val) => provider.setDepartment(val!),
              ),
            ),
            const SizedBox(width: 16),
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.zoom_out, size: 28),
                  onPressed: () => provider.setZoom(provider.hourHeight - 20),
                  tooltip: 'تصغير الجدول',
                ),
                SizedBox(
                  width: 150,
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 6,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                    ),
                    child: Slider(
                      value: provider.hourHeight,
                      min: 30.0,
                      max: 300.0,
                      onChanged: (val) => provider.setZoom(val),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.zoom_in, size: 28),
                  onPressed: () => provider.setZoom(provider.hourHeight + 20),
                  tooltip: 'تكبير الجدول',
                ),
              ],
            ),
            const SizedBox(width: 32),
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios),
                  onPressed: () => provider.changeDate(provider.selectedDate.subtract(const Duration(days: 1))),
                ),
                Text(
                  DateFormat('EEEE, d MMMM', 'ar').format(provider.selectedDate),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.arrow_forward_ios),
                  onPressed: () => provider.changeDate(provider.selectedDate.add(const Duration(days: 1))),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeColumn(ScheduleProvider provider) {
    return SizedBox(
      width: 60,
      child: Column(
        children: [
          const SizedBox(height: 50), // Header offset
          ...List.generate(14, (index) {
            final hour = 10 + index;
            return SizedBox(
              height: provider.hourHeight,
              child: Text(
                '$hour:00',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white.withAlpha(128)),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildDoctorColumn(Doctor doctor, List<Booking> bookings, ScheduleProvider provider) {
    final doctorBookings = bookings.where((b) => b.doctorId == doctor.id).toList();

    return Container(
      width: 200, 
      margin: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        border: Border(right: BorderSide(color: Colors.white.withAlpha(26))),
      ),
      child: Column(
        children: [
          Container(
            height: 50,
            padding: const EdgeInsets.all(12),
            color: doctor.color.withAlpha(51),
            child: Row(
              children: [
                 CircleAvatar(
                   radius: 16, 
                   backgroundColor: doctor.color,
                   child: Text(doctor.name[0], style: const TextStyle(color: Colors.white)),
                 ),
                 const SizedBox(width: 8),
                 Expanded(
                   child: Text(
                     doctor.name,
                     style: const TextStyle(fontWeight: FontWeight.bold),
                     overflow: TextOverflow.ellipsis,
                   ),
                 ),
              ],
            ),
          ),
          ...List.generate(14, (index) {
            final hour = 10 + index;
            final slotBooking = doctorBookings.firstWhere(
              (b) => b.startTime.hour == hour,
              orElse: () => Booking(
                id: '', patientId: '', patientName: '', doctorId: '', 
                startTime: DateTime(2000), endTime: DateTime(2000), status: '',
              ),
            );

            if (slotBooking.id.isNotEmpty) {
              return _buildBookingCard(slotBooking, doctor.color, provider.hourHeight);
            }

            return _buildEmptySlot(doctor, hour, provider.hourHeight);
          }),
        ],
      ),
    );
  }

  Widget _buildBookingCard(Booking booking, Color color, double hourHeight) {
    final duration = booking.endTime.difference(booking.startTime).inMinutes;
    final height = (duration / 60) * hourHeight;

    // Dynamic padding: if height is small, reduce padding
    final double padding = height < 30 ? 2.0 : 8.0;

    return Container(
      height: height, 
      margin: const EdgeInsets.all(4),
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: color.withAlpha(204),
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
      ),
      child: InkWell(
        onTap: () => _showBookingOptions(booking),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min, // Important for small heights
          children: [
            // Only show name if height allows
            if (height >= 15)
              Flexible( // Use Flexible to prevent overflow
                child: Text(
                  booking.patientName,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            if (height > 40)
              Text(
                '${DateFormat('h:mm a').format(booking.startTime)} - ${DateFormat('h:mm a').format(booking.endTime)}',
                style: const TextStyle(fontSize: 11, color: Colors.white70),
                overflow: TextOverflow.ellipsis,
              ),
            if (height > 80) ...[ 
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  _getStatusLabel(booking.status),
                  style: const TextStyle(fontSize: 10),
                ),
              )
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildEmptySlot(Doctor doctor, int hour, double height) {
    return InkWell(
      onTap: () async {
        final date = context.read<ScheduleProvider>().selectedDate;
        final slotDate = DateTime(date.year, date.month, date.day, hour, 0);
        
        final result = await showDialog(
          context: context,
          builder: (_) => BookingDialog(
            initialDate: slotDate,
            preselectedDoctorId: doctor.id,
          ),
        );

        if (result == true) {
          if (mounted) context.read<ScheduleProvider>().loadData();
          ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(content: Text('تم إضافة الحجز للدكتور ${doctor.name}')),
          );
        }
      },
      child: Container(
        height: height,
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: Colors.white.withAlpha(13))),
        ),
        child: Center(
          child: Icon(Icons.add_circle_outline, color: Colors.white.withAlpha(26)),
        ),
      ),
    );
  }

  void _showBookingOptions(Booking booking) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('خيارات الحجز - ${booking.patientName}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            
            if (booking.status == 'scheduled' || booking.status == 'booked') ...[
               ListTile(
                 leading: const Icon(Icons.payment, color: Colors.green),
                 title: const Text('استلام المبلغ (تحويل إلى "وصل")'),
                 onTap: () async {
                    Navigator.pop(ctx);
                    await context.read<ScheduleProvider>().updateBookingStatus(booking.id, 'arrived');
                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم استلام المبلغ وتسجيل وصول المريض')));
                 },
               ),
               ListTile(
                 leading: const Icon(Icons.access_time, color: Colors.orange),
                 title: const Text('تأجيل الموعد'),
                 onTap: () {
                   Navigator.pop(ctx);
                   _showCancelOrPostponeDialog(booking, isPostpone: true);
                 },
               ),
               ListTile(
                 leading: const Icon(Icons.cancel_outlined, color: Colors.red),
                 title: const Text('إلغاء الموعد'),
                 onTap: () {
                   Navigator.pop(ctx);
                   _showCancelOrPostponeDialog(booking, isPostpone: false);
                 },
               ),
            ] else if (booking.status == 'arrived') ...[
              // Only active if status is arrived (paid)
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, minimumSize: const Size(double.infinity, 50)),
                icon: const Icon(Icons.login),
                label: const Text('إدخال للطبيب (بدء الجلسة)'),
                onPressed: () async {
                   Navigator.pop(ctx);
                   await context.read<ScheduleProvider>().updateBookingStatus(booking.id, 'in_session');
                   if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('بدأت الجلسة... العداد يعمل')));
                },
              ),
              const SizedBox(height: 8),
               ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.grey, minimumSize: const Size(double.infinity, 50)),
                icon: const Icon(Icons.undo),
                label: const Text('تراجع عن الوصول'),
                onPressed: () async {
                   Navigator.pop(ctx);
                   await context.read<ScheduleProvider>().updateBookingStatus(booking.id, 'scheduled');
                },
              ),
            ] else if (booking.status == 'in_session') ...[
               ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red, minimumSize: const Size(double.infinity, 50)),
                icon: const Icon(Icons.stop),
                label: const Text('إنهاء الجلسة وحجز موعد قادم'),
                onPressed: () {
                   Navigator.pop(ctx);
                   _showEndSessionDialog(booking);
                },
              ),
            ],
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showEndSessionDialog(Booking booking) {
    DateTime? nextDate;
    
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('إنهاء الجلسة'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('هل تريد إنهاء الجلسة الحالية؟'),
                const SizedBox(height: 16),
                const Divider(),
                const Text('الموعد القادم (اختياري)', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ListTile(
                  title: Text(nextDate == null ? 'حدد موعداً قادماً' : DateFormat('yyyy-MM-dd').format(nextDate!)),
                  trailing: const Icon(Icons.calendar_today),
                  tileColor: AppTheme.surface,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now().add(const Duration(days: 7)),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (date != null) {
                      setState(() => nextDate = date);
                    }
                  },
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  String msg = 'تم إنهاء الجلسة.';
                  if (nextDate != null) {
                    msg += ' وتم حجز الموعد القادم في ${DateFormat('MM-dd').format(nextDate!)}';
                  }
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
                },
                child: const Text('تأكيد الإنهاء'),
              ),
            ],
          );
        }
      ),
    );
  }

  void _showCancelOrPostponeDialog(Booking booking, {required bool isPostpone}) {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isPostpone ? 'تأجيل الموعد' : 'طلب إلغاء الموعد'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isPostpone)
               Container(
                 padding: const EdgeInsets.all(8),
                 margin: const EdgeInsets.only(bottom: 16),
                 decoration: BoxDecoration(
                   color: Colors.red.withAlpha(26),
                   borderRadius: BorderRadius.circular(8),
                   border: Border.all(color: Colors.red.withAlpha(77)),
                 ),
                 child: const Row(
                   children: [
                     Icon(Icons.security, color: Colors.red, size: 20),
                     SizedBox(width: 8),
                     Expanded(child: Text('تنبيه: الإلغاء يتطلب موافقة المدير. سيتم تعليق الحجز حتى الموافقة.', style: TextStyle(color: Colors.red, fontSize: 12))),
                   ],
                 ),
               ),
            
            Text(isPostpone 
              ? 'يرجى تحديد سبب التأجيل (سيتم إشعار المريض).' 
              : 'يرجى ذكر سبب الإلغاء بدقة للمدير.'),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: InputDecoration(
                labelText: 'السبب (مطلوب)',
                border: const OutlineInputBorder(),
                filled: true,
                fillColor: AppTheme.surface,
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('رجوع')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: isPostpone ? Colors.orange : Colors.red),
            onPressed: () async {
              if (reasonController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('يرجى كتابة السبب')));
                return;
              }
              Navigator.pop(ctx);
              
              if (isPostpone) {
                 await context.read<ScheduleProvider>().logPostponement(booking.id, reasonController.text);
                 if (context.mounted) {
                   ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('تم تسجيل ملاحظة التأجيل. السبب: ${reasonController.text}'))
                  );
                 }
              } else {
                 await context.read<ScheduleProvider>().requestCancellation(booking.id, reasonController.text);
                 if (context.mounted) {
                   ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('تم رفع طلب الإلغاء للمدير. السبب: ${reasonController.text}'),
                      backgroundColor: Colors.blueGrey,
                    )
                  );
                 }
              }
            },
            child: Text(isPostpone ? 'تأكيد التأجيل' : 'إرسال طلب الإلغاء'),
          ),
        ],
      ),
    );
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'booked': return 'محجوز';
      case 'arrived': return 'وصل/تم الدفع';
      case 'in_session': return 'بالجلسة';
      case 'completed': return 'مكتمل';
      case 'cancellation_pending': return 'بانتظار الموافقة على الإلغاء';
      default: return status;
    }
  }
}
