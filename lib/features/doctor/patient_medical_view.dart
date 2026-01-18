import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme.dart';
import '../schedule/models.dart';
import '../settings/dynamic_fields_widget.dart';

class PatientMedicalView extends StatefulWidget {
  final Booking booking;
  const PatientMedicalView({super.key, required this.booking});

  @override
  State<PatientMedicalView> createState() => _PatientMedicalViewState();
}

class _PatientMedicalViewState extends State<PatientMedicalView> {
  // Controllers
  final _notesController = TextEditingController();
  
  // Patient data from database
  Map<String, dynamic>? _patientData;
  bool _isLoadingPatient = true;
  
  // History data - cached to avoid multiple queries
  List<Map<String, dynamic>> _historyData = [];
  bool _isLoadingHistory = true;

  @override
  void initState() {
    super.initState();
    _loadPatientData();
    _loadHistoryData();
  }

  @override
  void didUpdateWidget(covariant PatientMedicalView oldWidget) {
    if (oldWidget.booking.id != widget.booking.id) {
      // Reset form when patient changes
      _notesController.clear();
      _loadPatientData();
      _loadHistoryData();
    }
    super.didUpdateWidget(oldWidget);
  }

  Future<void> _loadPatientData() async {
    if (widget.booking.patientId.isEmpty) return;
    
    setState(() => _isLoadingPatient = true);
    try {
      final data = await Supabase.instance.client
          .from('patients')
          .select()
          .eq('id', widget.booking.patientId)
          .maybeSingle();
      
      if (mounted) {
        setState(() {
          _patientData = data;
          _isLoadingPatient = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingPatient = false);
      }
    }
  }

  Future<void> _loadHistoryData() async {
    if (widget.booking.patientId.isEmpty) return;
    
    setState(() => _isLoadingHistory = true);
    try {
      final data = await Supabase.instance.client
          .from('sessions')
          .select('*, doctor:profiles(name)')
          .eq('patient_id', widget.booking.patientId)
          .eq('status', 'completed')
          .order('start_time', ascending: false)
          .limit(20); // تحديد الحد الأقصى لتحسين الأداء
      
      if (mounted) {
        setState(() {
          _historyData = List<Map<String, dynamic>>.from(data);
          _isLoadingHistory = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingHistory = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Patient Header with real data
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            border: Border(bottom: BorderSide(color: Colors.white.withAlpha(13))),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 32,
                backgroundColor: AppTheme.primary,
                child: Text(widget.booking.patientName[0], style: const TextStyle(fontSize: 28, color: Colors.white)),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.booking.patientName, style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 8),
                    _isLoadingPatient
                      ? const SizedBox(height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                      : Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            _Tag(label: 'العمر: ${_patientData?['age'] ?? 'غير محدد'}'),
                            _Tag(label: 'الزيارات: ${_patientData?['total_visits'] ?? 0}'),
                            _Tag(
                              label: 'نوع البشرة: ${_patientData?['skin_type'] ?? 'III'}', 
                              color: Colors.orange,
                            ),
                            if (_patientData?['medical_history'] != null && _patientData!['medical_history'].toString().isNotEmpty)
                              _Tag(label: 'تاريخ طبي: نعم', color: Colors.red),
                          ],
                        ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Tabs & Content
        Expanded(
          child: DefaultTabController(
            length: 3,
            child: Column(
              children: [
                const TabBar(
                  isScrollable: true,
                  tabs: [
                    Tab(text: 'الجلسة الحالية'),
                    Tab(text: 'بيانات المريض'),
                    Tab(text: 'السجل الطبي'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      // Tab 1: Current Session - Dynamic Fields + Notes
                      SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // نوع الخدمة
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppTheme.primary.withAlpha(26),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.medical_services, color: AppTheme.primary),
                                  const SizedBox(width: 8),
                                  Text('نوع الخدمة: ${widget.booking.serviceType}', 
                                    style: const TextStyle(fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            
                            // الحقول الديناميكية حسب نوع الخدمة
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppTheme.surface,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.white10),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Row(
                                    children: [
                                      Icon(Icons.tune, color: Colors.cyan),
                                      SizedBox(width: 8),
                                      Text('حقول الجلسة', style: TextStyle(fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  widget.booking.patientId.isNotEmpty
                                    ? DynamicFieldsWidget(
                                        patientId: widget.booking.patientId,
                                        sessionId: widget.booking.id,
                                        scope: 'session',
                                      )
                                    : const Center(child: Text('لا يوجد مريض', style: TextStyle(color: Colors.white38))),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            
                            // ملاحظات الجلسة
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppTheme.surface,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.white10),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Row(
                                    children: [
                                      Icon(Icons.notes, color: Colors.orange),
                                      SizedBox(width: 8),
                                      Text('ملاحظات الجلسة', style: TextStyle(fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  TextField(
                                    controller: _notesController,
                                    maxLines: 4,
                                    decoration: InputDecoration(
                                      hintText: 'سجل ملاحظات الجلسة، رد فعل المريض، توصيات...',
                                      filled: true,
                                      fillColor: Colors.white.withAlpha(13),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),
                            
                            // زر الحفظ
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primary,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                ),
                                onPressed: () async {
                                  try {
                                    await Supabase.instance.client
                                        .from('sessions')
                                        .update({
                                          'notes': _notesController.text,
                                        })
                                        .eq('id', widget.booking.id);
                                    
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('✅ تم حفظ الملاحظات بنجاح')),
                                      );
                                    }
                                  } catch (e) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('❌ خطأ: $e')),
                                      );
                                    }
                                  }
                                },
                                icon: const Icon(Icons.save),
                                label: const Text('حفظ الملاحظات'),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Tab 2: Patient DataPermanent Fields
                      SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: widget.booking.patientId.isNotEmpty
                          ? DynamicFieldsWidget(
                              patientId: widget.booking.patientId,
                              scope: 'patient',
                            )
                          : const Center(child: Text('لا يوجد مريض', style: TextStyle(color: Colors.white38))),
                      ),

                      // Tab 4: History
                      _buildHistoryList(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHistoryList() {
    if (_isLoadingHistory) {
      return const Center(child: CircularProgressIndicator());
    }
    
    if (_historyData.isEmpty) {
      return const Center(
        child: Text('لا يوجد سجل سابق لهذا المريض', style: TextStyle(color: Colors.white38)),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _historyData.length,
      itemBuilder: (context, index) {
        final item = _historyData[index];
        return _ExpandableHistoryItem(sessionData: item);
      },
    );
  }
}

class _Tag extends StatelessWidget {
  final String label;
  final Color color;
  const _Tag({required this.label, this.color = Colors.blue});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(26),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withAlpha(77)),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 12)),
    );
  }
}

// Widget قابل للتوسيع لعرض الزيارة السابقة مع كل التفاصيل
class _ExpandableHistoryItem extends StatefulWidget {
  final Map<String, dynamic> sessionData;
  
  const _ExpandableHistoryItem({required this.sessionData});

  @override
  State<_ExpandableHistoryItem> createState() => _ExpandableHistoryItemState();
}

class _ExpandableHistoryItemState extends State<_ExpandableHistoryItem> with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  late AnimationController _animationController;
  late Animation<double> _rotateAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _rotateAnimation = Tween<double>(begin: 0, end: 0.5).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _toggleExpand() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.sessionData;
    
    // الحقول الأساسية
    final startTimeStr = data['start_time']?.toString() ?? '';
    String formattedDate = '-';
    String formattedTime = '-';
    if (startTimeStr.length >= 16) {
      final dateTime = DateTime.tryParse(startTimeStr);
      if (dateTime != null) {
        final localTime = dateTime.toLocal();
        formattedDate = '${localTime.day}/${localTime.month}/${localTime.year}';
        final hour = localTime.hour > 12 ? localTime.hour - 12 : (localTime.hour == 0 ? 12 : localTime.hour);
        final amPm = localTime.hour >= 12 ? 'م' : 'ص';
        formattedTime = '$hour:${localTime.minute.toString().padLeft(2, '0')} $amPm';
      }
    }
    
    final serviceType = data['service_type'] ?? data['service']?['name'] ?? 'جلسة';
    final doctorName = data['doctor']?['name'] ?? 'غير محدد';
    final notes = data['notes']?.toString() ?? '';
    final price = data['price'];
    final status = data['status'] ?? 'completed';
    
    // مدة الجلسة
    String duration = '-';
    if (data['session_start_time'] != null && data['session_end_time'] != null) {
      try {
        final start = DateTime.parse(data['session_start_time']);
        final end = DateTime.parse(data['session_end_time']);
        final diff = end.difference(start);
        duration = '${diff.inMinutes} دقيقة';
      } catch (_) {}
    }
    
    // الحقول الديناميكية
    final dynamicFields = data['dynamic_fields'] as Map<String, dynamic>? ?? {};
    
    // لون الحالة
    Color statusColor = Colors.green;
    String statusText = 'مكتملة';
    if (status == 'cancelled') {
      statusColor = Colors.red;
      statusText = 'ملغية';
    } else if (status == 'scheduled') {
      statusColor = Colors.orange;
      statusText = 'مجدولة';
    }

    return Card(
      color: AppTheme.surface,
      margin: const EdgeInsets.only(bottom: 12),
      elevation: _isExpanded ? 4 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: _isExpanded ? AppTheme.primary.withAlpha(128) : Colors.transparent,
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: _toggleExpand,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // الصف الرئيسي (دائماً مرئي) - المعلومات الأساسية
              Row(
                children: [
                  // التاريخ مع أيقونة
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppTheme.primary.withAlpha(51), AppTheme.primary.withAlpha(26)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.calendar_today, size: 16, color: AppTheme.primary),
                        const SizedBox(height: 4),
                        Text(formattedDate, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                        Text(formattedTime, style: const TextStyle(fontSize: 10, color: Colors.white60)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  
                  // المعلومات الرئيسية
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // نوع الخدمة مع حالة
                        Row(
                          children: [
                            Expanded(
                              child: Text(serviceType, 
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: statusColor.withAlpha(26),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: statusColor.withAlpha(77)),
                              ),
                              child: Text(statusText, style: TextStyle(fontSize: 9, color: statusColor, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        
                        // الطبيب والسعر
                        Row(
                          children: [
                            Icon(Icons.person, size: 12, color: Colors.white54),
                            const SizedBox(width: 4),
                            Text('د. $doctorName', style: const TextStyle(color: Colors.white54, fontSize: 11)),
                            const Spacer(),
                            if (price != null && price > 0) ...[
                              Icon(Icons.payments_outlined, size: 12, color: Colors.green.shade300),
                              const SizedBox(width: 4),
                              Text('$price ر.س', style: TextStyle(color: Colors.green.shade300, fontSize: 11, fontWeight: FontWeight.bold)),
                            ],
                          ],
                        ),
                        
                        // معاينة سريعة للحقول الديناميكية (أول 3)
                        if (dynamicFields.isNotEmpty && !_isExpanded) ...[
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: dynamicFields.entries.take(3).map((e) => Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.cyan.withAlpha(26),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text('${e.key}: ${e.value}', style: const TextStyle(fontSize: 9, color: Colors.cyan)),
                            )).toList(),
                          ),
                        ],
                      ],
                    ),
                  ),
                  
                  const SizedBox(width: 8),
                  
                  // سهم التوسع
                  RotationTransition(
                    turns: _rotateAnimation,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(13),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(Icons.keyboard_arrow_down, color: Colors.white54, size: 20),
                    ),
                  ),
                ],
              ),
              
              // ═══════════════════════════════════════════════════════════
              // التفاصيل الموسعة
              // ═══════════════════════════════════════════════════════════
              AnimatedCrossFade(
                firstChild: const SizedBox.shrink(),
                secondChild: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    const Divider(height: 1, color: Colors.white12),
                    const SizedBox(height: 16),
                    
                    // إحصائيات سريعة
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(8),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildStatItem(Icons.timer_outlined, 'المدة', duration, Colors.blue),
                          _buildStatItem(Icons.payments_outlined, 'السعر', price != null ? '$price ر.س' : '-', Colors.green),
                          _buildStatItem(Icons.medical_services_outlined, 'الحالة', statusText, statusColor),
                        ],
                      ),
                    ),
                    
                    // الحقول الديناميكية (كاملة)
                    if (dynamicFields.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          const Icon(Icons.tune, size: 16, color: Colors.cyan),
                          const SizedBox(width: 8),
                          const Text('بيانات الجلسة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          const Spacer(),
                          Text('${dynamicFields.length} حقل', style: const TextStyle(fontSize: 11, color: Colors.white38)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.cyan.withAlpha(13),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.cyan.withAlpha(38)),
                        ),
                        child: Wrap(
                          spacing: 12,
                          runSpacing: 10,
                          children: dynamicFields.entries.map((e) => Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('${e.key}: ', style: const TextStyle(fontSize: 12, color: Colors.white54)),
                              Text('${e.value}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            ],
                          )).toList(),
                        ),
                      ),
                    ],
                    
                    // الملاحظات
                    if (notes.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          const Icon(Icons.notes, size: 16, color: Colors.orange),
                          const SizedBox(width: 8),
                          const Text('ملاحظات الجلسة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange.withAlpha(13),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.orange.withAlpha(38)),
                        ),
                        child: Text(notes, style: const TextStyle(fontSize: 12, height: 1.5)),
                      ),
                    ],
                    
                    // إذا لم تكن هناك تفاصيل إضافية
                    if (dynamicFields.isEmpty && notes.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        child: const Center(
                          child: Text('لا توجد تفاصيل إضافية لهذه الجلسة', 
                            style: TextStyle(color: Colors.white38, fontSize: 12)),
                        ),
                      ),
                  ],
                ),
                crossFadeState: _isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 200),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String label, String value, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withAlpha(26),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(height: 6),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.white54)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
