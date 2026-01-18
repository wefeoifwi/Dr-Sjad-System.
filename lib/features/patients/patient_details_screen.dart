import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme.dart';

class PatientDetailsScreen extends StatelessWidget {
  final Map<String, dynamic> patient;

  const PatientDetailsScreen({super.key, required this.patient});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(patient['name'] ?? 'تفاصيل المريض'),
        backgroundColor: AppTheme.surface,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => _showEditPatientDialog(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // Top Info Card
          Container(
            padding: const EdgeInsets.all(24),
            color: AppTheme.surface,
            child: Column(
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 32,
                      backgroundColor: AppTheme.primary,
                      child: Text(
                        (patient['name'] ?? '?')[0],
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(patient['name'] ?? 'بدون اسم', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 12,
                            runSpacing: 8,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.phone, size: 16, color: Colors.white70),
                                  const SizedBox(width: 4),
                                  Text(patient['phone'] ?? '---', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                                ],
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.cake, size: 16, color: Colors.white70),
                                  const SizedBox(width: 4),
                                  Text('${patient['age'] ?? '-'} سنة', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                                ],
                              ),
                            ],
                          )
                        ],
                      ),
                    ),
                    Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.green.withAlpha(26),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.green),
                          ),
                          child: const Text('عميل نشط', style: TextStyle(color: Colors.green)),
                        ),
                        const SizedBox(height: 8),
                        Text('آخر زيارة: ${patient['last_visit'] != null ? DateFormat('yyyy-MM-dd').format(DateTime.parse(patient['last_visit'])) : '-'}', style: const TextStyle(color: Colors.white38, fontSize: 12)),
                      ],
                    )
                  ],
                ),
              ],
            ),
          ),
          
          // Tabs for Sessions and Activity Log
          Expanded(
            child: DefaultTabController(
              length: 2,
              child: Column(
                children: [
                  // Tab Bar
                  Container(
                    color: AppTheme.surface,
                    child: const TabBar(
                      indicatorColor: AppTheme.primary,
                      labelColor: AppTheme.primary,
                      unselectedLabelColor: Colors.white54,
                      tabs: [
                        Tab(icon: Icon(Icons.history), text: 'الجلسات'),
                        Tab(icon: Icon(Icons.timeline), text: 'سجل الأحداث'),
                      ],
                    ),
                  ),
                  // Tab Views
                  Expanded(
                    child: TabBarView(
                      children: [
                        _SessionsTab(patientId: patient['id']),
                        _ActivityLogTab(patientId: patient['id']),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showEditPatientDialog(BuildContext context) {
    final nameController = TextEditingController(text: patient['name']);
    final phoneController = TextEditingController(text: patient['phone']);
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تعديل بيانات المريض'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'الاسم', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: phoneController,
              decoration: const InputDecoration(labelText: 'رقم الهاتف', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('تم حفظ التعديلات'), backgroundColor: Colors.green),
              );
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }
}

class _SessionsTab extends StatefulWidget {
  final String? patientId;
  const _SessionsTab({this.patientId});

  @override
  State<_SessionsTab> createState() => _SessionsTabState();
}

class _SessionsTabState extends State<_SessionsTab> {
  List<Map<String, dynamic>> _sessions = [];
  bool _isLoading = true;
  Map<String, int> _serviceSessionCounts = {}; // لحساب رقم الجلسة لكل خدمة

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    if (widget.patientId == null) {
      setState(() => _isLoading = false);
      return;
    }
    
    try {
      final data = await Supabase.instance.client
          .from('sessions')
          .select('*, profiles!sessions_doctor_id_fkey(name), services(name)')
          .eq('patient_id', widget.patientId!)
          .order('start_time', ascending: true); // ترتيب تصاعدي لحساب رقم الجلسة
      
      // حساب رقم الجلسة لكل خدمة
      Map<String, int> counts = {};
      List<Map<String, dynamic>> sessionsWithNumbers = [];
      
      for (var session in data) {
        final serviceName = session['services']?['name'] ?? 'خدمة';
        counts[serviceName] = (counts[serviceName] ?? 0) + 1;
        session['session_number'] = counts[serviceName];
        sessionsWithNumbers.add(Map<String, dynamic>.from(session));
      }
      
      setState(() {
        _sessions = sessionsWithNumbers.reversed.toList(); // عكس الترتيب للعرض (الأحدث أولاً)
        _serviceSessionCounts = counts;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      debugPrint('Error loading sessions: $e');
    }
  }

  void _showSessionDetails(Map<String, dynamic> session) {
    final serviceName = session['services']?['name'] ?? 'خدمة';
    final sessionNum = session['session_number'] ?? 1;
    final doctorName = session['profiles']?['name'] ?? 'غير محدد';
    final status = session['status'] ?? 'booked';
    final startTime = session['start_time'] != null 
        ? DateTime.parse(session['start_time']).toLocal()
        : null;
    final notes = session['notes'] ?? '';
    final price = session['price'];
    final room = session['room'];
    
    // Get medical_notes (dynamic fields)
    final medicalNotes = session['medical_notes'] as Map<String, dynamic>?;
    
    Color statusColor;
    String statusLabel;
    switch (status) {
      case 'completed':
        statusColor = Colors.green;
        statusLabel = 'مكتملة';
        break;
      case 'in_session':
        statusColor = Colors.blue;
        statusLabel = 'جارية';
        break;
      case 'cancelled':
        statusColor = Colors.red;
        statusLabel = 'ملغية';
        break;
      case 'arrived':
        statusColor = Colors.teal;
        statusLabel = 'وصل';
        break;
      default:
        statusColor = Colors.orange;
        statusLabel = 'محجوزة';
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Title
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withAlpha(26),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.medical_services, color: AppTheme.primary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$serviceName #$sessionNum',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            startTime != null ? DateFormat('yyyy-MM-dd • HH:mm', 'ar').format(startTime) : '-',
                            style: const TextStyle(color: Colors.white54),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: statusColor.withAlpha(26),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: statusColor),
                      ),
                      child: Text(statusLabel, style: TextStyle(color: statusColor)),
                    ),
                  ],
                ),
                
                const SizedBox(height: 20),
                const Divider(color: Colors.white12),
                const SizedBox(height: 12),
                
                // Basic Details
                _buildDetailRow(Icons.person, 'الطبيب', doctorName),
                const SizedBox(height: 12),
                if (room != null && room.toString().isNotEmpty) ...[
                  _buildDetailRow(Icons.room, 'الغرفة', room.toString()),
                  const SizedBox(height: 12),
                ],
                if (price != null) ...[
                  _buildDetailRow(Icons.attach_money, 'السعر', '$price د.ع'),
                  const SizedBox(height: 12),
                ],
                if (notes.isNotEmpty) ...[
                  _buildDetailRow(Icons.note, 'ملاحظات', notes),
                  const SizedBox(height: 12),
                ],
                
                // Dynamic Fields (medical_notes)
                if (medicalNotes != null && medicalNotes.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  const Divider(color: Colors.white12),
                  const SizedBox(height: 12),
                  const Row(
                    children: [
                      Icon(Icons.science, size: 18, color: AppTheme.primary),
                      SizedBox(width: 8),
                      Text('البيانات الفنية', style: TextStyle(
                        color: AppTheme.primary,
                        fontWeight: FontWeight.bold,
                      )),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ...medicalNotes.entries.map((entry) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        const Icon(Icons.circle, size: 8, color: Colors.white38),
                        const SizedBox(width: 12),
                        Text('${entry.key}: ', style: const TextStyle(color: Colors.white54)),
                        Expanded(
                          child: Text(
                            entry.value?.toString() ?? '-',
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  )),
                ],
                
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.white38),
        const SizedBox(width: 12),
        Text('$label: ', style: const TextStyle(color: Colors.white54)),
        Expanded(child: Text(value, style: const TextStyle(color: Colors.white))),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    
    if (_sessions.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_busy, size: 64, color: Colors.white24),
            SizedBox(height: 16),
            Text('لا توجد جلسات سابقة', style: TextStyle(color: Colors.white54)),
          ],
        ),
      );
    }

    // إحصائيات مختصرة
    return Column(
      children: [
        // إحصائيات الخدمات
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _serviceSessionCounts.entries.map((entry) => Container(
                margin: const EdgeInsets.only(left: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withAlpha(26),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.primary.withAlpha(77)),
                ),
                child: Text(
                  '${entry.key}: ${entry.value}',
                  style: const TextStyle(color: AppTheme.primary, fontSize: 12),
                ),
              )).toList(),
            ),
          ),
        ),
        
        // قائمة الجلسات
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: _sessions.length,
            itemBuilder: (context, index) {
              final session = _sessions[index];
              final serviceName = session['services']?['name'] ?? 'خدمة';
              final sessionNum = session['session_number'] ?? 1;
              final status = session['status'] ?? 'booked';
              final startTime = session['start_time'] != null 
                  ? DateTime.parse(session['start_time']).toLocal()
                  : null;
              
              Color statusColor;
              switch (status) {
                case 'completed': statusColor = Colors.green; break;
                case 'in_session': statusColor = Colors.blue; break;
                case 'cancelled': statusColor = Colors.red; break;
                default: statusColor = Colors.orange;
              }

              return Card(
                color: AppTheme.surface,
                margin: const EdgeInsets.only(bottom: 8),
                child: InkWell(
                  onTap: () => _showSessionDetails(session),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        // رقم الجلسة
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: statusColor.withAlpha(26),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(
                            child: Text(
                              '#$sessionNum',
                              style: TextStyle(color: statusColor, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        
                        // الخدمة والتاريخ
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                serviceName,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              Text(
                                startTime != null ? DateFormat('MM/dd').format(startTime) : '-',
                                style: const TextStyle(color: Colors.white54, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        
                        // سهم
                        const Icon(Icons.chevron_left, color: Colors.white38),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// ACTIVITY LOG TAB - سجل الأحداث الكامل
// ═══════════════════════════════════════════════════════════════════════════

class _ActivityLogTab extends StatefulWidget {
  final String patientId;
  const _ActivityLogTab({required this.patientId});

  @override
  State<_ActivityLogTab> createState() => _ActivityLogTabState();
}

class _ActivityLogTabState extends State<_ActivityLogTab> {
  List<Map<String, dynamic>> _activities = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadActivities();
  }

  Future<void> _loadActivities() async {
    setState(() => _isLoading = true);

    try {
      final supabase = Supabase.instance.client;
      List<Map<String, dynamic>> all = [];

      // 1. Load Sessions
      final sessions = await supabase
          .from('sessions')
          .select('id, status, start_time, end_time, notes, department_id, departments(name)')
          .eq('patient_id', widget.patientId)
          .order('start_time', ascending: false)
          .limit(50);

      for (var s in sessions) {
        all.add({
          'type': 'session',
          'date': s['start_time'],
          'status': s['status'],
          'title': 'جلسة',
          'subtitle': s['departments']?['name'] ?? '',
          'notes': s['notes'],
          'icon': Icons.event,
          'color': _getStatusColor(s['status']),
        });
      }

      // 2. Load Follow-ups
      final followUps = await supabase
          .from('follow_ups')
          .select('id, status, scheduled_date, scheduled_time, call_attempts, call_outcome, cancellation_reason')
          .eq('patient_id', widget.patientId)
          .order('scheduled_date', ascending: false)
          .limit(50);

      for (var f in followUps) {
        String title = 'متابعة';
        if (f['status'] == 'cancelled' || f['status'] == 'pending_cancellation') {
          title = 'متابعة ملغية';
        } else if (f['status'] == 'confirmed') {
          title = 'متابعة مؤكدة';
        }

        all.add({
          'type': 'follow_up',
          'date': '${f['scheduled_date']}T${f['scheduled_time'] ?? '00:00'}:00',
          'status': f['status'],
          'title': title,
          'subtitle': f['call_attempts'] != null && f['call_attempts'] > 0 
              ? '${f['call_attempts']} محاولة اتصال' 
              : '',
          'notes': f['cancellation_reason'],
          'icon': Icons.phone_callback,
          'color': _getFollowUpColor(f['status']),
        });
      }

      // Sort by date (newest first)
      all.sort((a, b) {
        final dateA = DateTime.tryParse(a['date'] ?? '') ?? DateTime(2000);
        final dateB = DateTime.tryParse(b['date'] ?? '') ?? DateTime(2000);
        return dateB.compareTo(dateA);
      });

      setState(() {
        _activities = all;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      debugPrint('Error loading activities: $e');
    }
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'completed': return Colors.green;
      case 'cancelled': return Colors.red;
      case 'in_session': return Colors.cyan;
      case 'arrived': return Colors.teal;
      case 'booked': return Colors.orange;
      default: return Colors.grey;
    }
  }

  Color _getFollowUpColor(String? status) {
    switch (status) {
      case 'confirmed': return Colors.green;
      case 'pending': return Colors.orange;
      case 'cancelled': return Colors.red;
      default: return Colors.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_activities.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.timeline, size: 64, color: Colors.white.withAlpha(51)),
            const SizedBox(height: 16),
            const Text('لا توجد أحداث مسجلة', style: TextStyle(color: Colors.white54)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadActivities,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _activities.length,
        itemBuilder: (context, index) {
          final activity = _activities[index];
          final date = DateTime.tryParse(activity['date'] ?? '');
          final formattedDate = date != null 
              ? DateFormat('yyyy/MM/dd - HH:mm', 'ar').format(date.toLocal())
              : '';

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Timeline Circle
                Column(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: (activity['color'] as Color).withAlpha(51),
                        shape: BoxShape.circle,
                        border: Border.all(color: activity['color'], width: 2),
                      ),
                      child: Icon(activity['icon'], size: 18, color: activity['color']),
                    ),
                    if (index < _activities.length - 1)
                      Container(width: 2, height: 40, color: Colors.white24),
                  ],
                ),
                const SizedBox(width: 12),
                // Content
                Expanded(
                  child: Card(
                    color: AppTheme.surface,
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(activity['title'], style: TextStyle(fontWeight: FontWeight.bold, color: activity['color'])),
                              ),
                              Text(formattedDate, style: const TextStyle(color: Colors.white54, fontSize: 11)),
                            ],
                          ),
                          if (activity['subtitle'] != null && (activity['subtitle'] as String).isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(activity['subtitle'], style: const TextStyle(color: Colors.white70, fontSize: 12)),
                          ],
                          if (activity['notes'] != null && (activity['notes'] as String).isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white.withAlpha(13),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(activity['notes'], style: const TextStyle(color: Colors.white54, fontSize: 11)),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
