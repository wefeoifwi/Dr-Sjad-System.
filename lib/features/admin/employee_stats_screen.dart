import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme.dart';

class EmployeeStatsScreen extends StatefulWidget {
  const EmployeeStatsScreen({super.key});

  @override
  State<EmployeeStatsScreen> createState() => _EmployeeStatsScreenState();
}

class _EmployeeStatsScreenState extends State<EmployeeStatsScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();
  List<Map<String, dynamic>> _employeeStats = [];

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() => _isLoading = true);
    
    try {
      // جلب جميع الجلسات في الفترة المحددة مع معلومات المنشئ
      final sessions = await _supabase
          .from('sessions')
          .select('id, status, created_by, created_at, creator:profiles!sessions_created_by_fkey(id, name)')
          .gte('created_at', _startDate.toIso8601String())
          .lte('created_at', _endDate.add(const Duration(days: 1)).toIso8601String());

      // تجميع الإحصائيات حسب الموظف
      Map<String, Map<String, dynamic>> statsMap = {};
      
      for (var session in sessions) {
        final creatorId = session['created_by'];
        final creatorName = session['creator']?['name'] ?? 'غير معروف';
        final status = session['status'] ?? 'scheduled';
        
        if (creatorId == null) continue;
        
        if (!statsMap.containsKey(creatorId)) {
          statsMap[creatorId] = {
            'id': creatorId,
            'name': creatorName,
            'total': 0,
            'scheduled': 0,
            'booked': 0,
            'arrived': 0,
            'in_session': 0,
            'completed': 0,
            'cancelled': 0,
            'cancellation_pending': 0,
          };
        }
        
        statsMap[creatorId]!['total'] = (statsMap[creatorId]!['total'] as int) + 1;
        if (statsMap[creatorId]!.containsKey(status)) {
          statsMap[creatorId]![status] = (statsMap[creatorId]![status] as int) + 1;
        }
      }
      
      setState(() {
        _employeeStats = statsMap.values.toList();
        _employeeStats.sort((a, b) => (b['total'] as int).compareTo(a['total'] as int));
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading employee stats: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        title: const Text('إحصائيات الموظفين'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadStats,
          ),
        ],
      ),
      body: Column(
        children: [
          // فلتر التاريخ
          Container(
            padding: const EdgeInsets.all(16),
            color: AppTheme.surface,
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => _selectDate(true),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white10,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.calendar_today, size: 16),
                          const SizedBox(width: 8),
                          Text('من: ${DateFormat('d/M/yyyy').format(_startDate)}'),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    onTap: () => _selectDate(false),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white10,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.calendar_today, size: 16),
                          const SizedBox(width: 8),
                          Text('إلى: ${DateFormat('d/M/yyyy').format(_endDate)}'),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _loadStats,
                  child: const Text('تطبيق'),
                ),
              ],
            ),
          ),
          
          // الإحصائيات
          Expanded(
            child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _employeeStats.isEmpty
                ? const Center(child: Text('لا توجد بيانات', style: TextStyle(color: Colors.white54)))
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _employeeStats.length,
                    itemBuilder: (context, index) => _buildEmployeeCard(_employeeStats[index]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmployeeCard(Map<String, dynamic> stats) {
    final total = stats['total'] as int;
    final completed = stats['completed'] as int;
    final cancelled = (stats['cancelled'] as int) + (stats['cancellation_pending'] as int);
    final pending = (stats['scheduled'] as int) + (stats['booked'] as int) + (stats['arrived'] as int);
    final inSession = stats['in_session'] as int;
    
    return Card(
      color: AppTheme.surface,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // الاسم والإجمالي
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppTheme.primary,
                  child: Text(
                    stats['name'].toString().isNotEmpty ? stats['name'].toString()[0].toUpperCase() : '?',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        stats['name'] ?? 'غير معروف',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Text(
                        'إجمالي الحجوزات: $total',
                        style: const TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withAlpha(26),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$total',
                    style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            const Divider(color: Colors.white12),
            const SizedBox(height: 12),
            
            // الإحصائيات التفصيلية
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                _buildStatChip('مكتمل', completed, Colors.green),
                _buildStatChip('بانتظار', pending, Colors.orange),
                _buildStatChip('بالجلسة', inSession, Colors.blue),
                _buildStatChip('ملغي', cancelled, Colors.red),
              ],
            ),
            
            // نسبة الإكمال
            if (total > 0) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text('نسبة الإكمال: ', style: TextStyle(color: Colors.white54, fontSize: 12)),
                  Text(
                    '${((completed / total) * 100).toStringAsFixed(1)}%',
                    style: TextStyle(
                      color: completed / total > 0.7 ? Colors.green : Colors.orange,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatChip(String label, int value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withAlpha(26),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withAlpha(77)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '$label: $value',
            style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Future<void> _selectDate(bool isStart) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate : _endDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }
}
