import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme.dart';
import '../schedule/models.dart';

class PatientMedicalView extends StatefulWidget {
  final Booking booking;
  const PatientMedicalView({super.key, required this.booking});

  @override
  State<PatientMedicalView> createState() => _PatientMedicalViewState();
}

class _PatientMedicalViewState extends State<PatientMedicalView> {
  // Medical Form Controllers
  final _sessionNumController = TextEditingController(text: '1');
  final _spotBdController = TextEditingController();
  final _alexController = TextEditingController();
  final _yagController = TextEditingController();
  final _notesController = TextEditingController();
  
  String _skinType = 'III'; // Default
  
  // Patient data from database
  Map<String, dynamic>? _patientData;
  bool _isLoadingPatient = true;

  @override
  void initState() {
    super.initState();
    _loadPatientData();
  }

  @override
  void didUpdateWidget(covariant PatientMedicalView oldWidget) {
    if (oldWidget.booking.id != widget.booking.id) {
      // Reset form when patient changes
      _sessionNumController.text = '1';
      _spotBdController.clear();
      _alexController.clear();
      _yagController.clear();
      _notesController.clear();
      _loadPatientData();
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
          _skinType = data?['skin_type'] ?? 'III';
          _isLoadingPatient = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingPatient = false);
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
            length: 2,
            child: Column(
              children: [
                const TabBar(
                  tabs: [
                    Tab(text: 'الجلسة الحالية'),
                    Tab(text: 'السجل الطبي (History)'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      // Tab 1: Current Session Form
                      SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLaserParams(),
                            const SizedBox(height: 24),
                            const Text('ملاحظات الجلسة', style: TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _notesController,
                              maxLines: 5,
                              decoration: InputDecoration(
                                hintText: 'سجل تفاصيل الإجراء، رد فعل البشرة، أو توصيات...',
                                filled: true,
                                fillColor: AppTheme.surface,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                            const SizedBox(height: 24),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primary,
                                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                                ),
                                onPressed: () async {
                                  try {
                                    // Prepare Data
                                    final medicalNotes = '''
Medical Log:
Skin Type: $_skinType
Session: ${_sessionNumController.text}
Spot: ${_spotBdController.text}
Alex: ${_alexController.text}
Yag: ${_yagController.text}
User Notes: ${_notesController.text}
''';
                                    
                                    // Update Session in Supabase
                                    await Supabase.instance.client
                                        .from('sessions')
                                        .update({
                                          'status': 'completed',
                                          'notes': medicalNotes,
                                          // 'price': ... // price logic if needed
                                        })
                                        .eq('id', widget.booking.id);
                                    
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ سجل الجلسة بنجاح')));
                                    }
                                  } catch (e) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ في الحفظ: $e')));
                                    }
                                  }
                                },
                                icon: const Icon(Icons.save),
                                label: const Text('حفظ السجل وإنهاء الجلسة'),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Tab 2: History (Mock) -> Fetch Real History
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
    return FutureBuilder(
      future: Supabase.instance.client
          .from('sessions')
          .select('*, doctor:profiles(name)')
          .eq('patient_id', widget.booking.patientId) // Filter by patient
          .eq('status', 'completed')
          .order('start_time', ascending: false),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
        
        final history = snapshot.data as List;
        
        if (history.isEmpty) return const Center(child: Text('لا يوجد سجل سابق لهذا المريض', style: TextStyle(color: Colors.white38)));

        return ListView.builder(
          padding: const EdgeInsets.all(24),
          itemCount: history.length,
          itemBuilder: (context, index) {
            final item = history[index];
            return _HistoryItem(
              date: item['start_time'].toString().substring(0, 10),
              sessionType: item['service_type'] ?? 'General',
              doctor: item['doctor']?['name'] ?? 'Unknown',
            );
          },
        );
      },
    );
  }

  Widget _buildLaserParams() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.flash_on, color: Colors.orange),
              const SizedBox(width: 8),
              Text('إعدادات الليزر', style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _InputGroup(
                  label: 'Skin Type',
                  child: DropdownButtonFormField<String>(initialValue: _skinType,
                    dropdownColor: AppTheme.surface,
                    decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()),
                    items: ['I', 'II', 'III', 'IV', 'V', 'VI'].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                    onChanged: (v) => setState(() => _skinType = v!),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _InputGroup(
                  label: 'Session #',
                  child: TextField(
                    controller: _sessionNumController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _InputGroup(
                  label: 'Spot B.D',
                  child: TextField(
                    controller: _spotBdController,
                    decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _InputGroup(
                  label: 'Alex',
                  child: TextField(
                    controller: _alexController,
                     decoration: const InputDecoration(isDense: true, border: OutlineInputBorder(), suffixText: 'J/cm²'),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _InputGroup(
                  label: 'Yag',
                  child: TextField(
                    controller: _yagController,
                     decoration: const InputDecoration(isDense: true, border: OutlineInputBorder(), suffixText: 'J/cm²'),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              const Expanded(child: SizedBox()), // Spacer
            ],
          ),
        ],
      ),
    );
  }
}

class _InputGroup extends StatelessWidget {
  final String label;
  final Widget child;
  const _InputGroup({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white70)),
        const SizedBox(height: 8),
        child,
      ],
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

class _HistoryItem extends StatelessWidget {
  final String date;
  final String sessionType;
  final String doctor;
  
  const _HistoryItem({required this.date, required this.sessionType, required this.doctor});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppTheme.surface,
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: const Icon(Icons.history, color: Colors.white54),
        title: Text(sessionType, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('$doctor  •  $date'),
        trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.white38),
      ),
    );
  }
}
