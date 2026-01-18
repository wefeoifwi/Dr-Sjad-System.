import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme.dart';

class AdminActivityDashboard extends StatefulWidget {
  const AdminActivityDashboard({super.key});

  @override
  State<AdminActivityDashboard> createState() => _AdminActivityDashboardState();
}

class _AdminActivityDashboardState extends State<AdminActivityDashboard> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _supabase = Supabase.instance.client;
  
  // Date Range Filter
  DateTime? _startDate;
  DateTime? _endDate;
  String _selectedPeriod = 'all'; // 'today', 'week', 'month', 'custom', 'all'
  
  // Data
  List<Map<String, dynamic>> _cancellations = [];
  List<Map<String, dynamic>> _postponements = [];
  List<Map<String, dynamic>> _followUps = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _setDateRange(String period) {
    final now = DateTime.now();
    setState(() {
      _selectedPeriod = period;
      switch (period) {
        case 'today':
          _startDate = DateTime(now.year, now.month, now.day);
          _endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
          break;
        case 'week':
          _startDate = now.subtract(const Duration(days: 7));
          _endDate = now;
          break;
        case 'month':
          _startDate = DateTime(now.year, now.month - 1, now.day);
          _endDate = now;
          break;
        case 'all':
          _startDate = null;
          _endDate = null;
          break;
      }
    });
    _loadData();
  }

  Future<void> _pickCustomDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
    );
    if (picked != null) {
      setState(() {
        _selectedPeriod = 'custom';
        _startDate = picked.start;
        _endDate = picked.end;
      });
      _loadData();
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    try {
      // Build date filter
      String? dateFilter;
      if (_startDate != null && _endDate != null) {
        final start = _startDate!.toIso8601String();
        final end = _endDate!.toIso8601String();
        dateFilter = 'created_at.gte.$start,created_at.lte.$end';
      }

      // 1. Load Cancellations (sessions with status = 'cancelled' or 'cancellation_pending')
      var cancellationQuery = _supabase
          .from('sessions')
          .select('*, patients(name, phone), profiles!sessions_created_by_fkey(name)')
          .or('status.eq.cancelled,status.eq.cancellation_pending');
      
      if (_startDate != null) {
        cancellationQuery = cancellationQuery.gte('updated_at', _startDate!.toIso8601String());
      }
      if (_endDate != null) {
        cancellationQuery = cancellationQuery.lte('updated_at', _endDate!.toIso8601String());
      }
      
      final cancellationsData = await cancellationQuery.order('updated_at', ascending: false);

      // 2. Load Postponements (sessions with postpone_reason not null)
      var postponeQuery = _supabase
          .from('sessions')
          .select('*, patients(name, phone), profiles!sessions_created_by_fkey(name)')
          .not('postpone_reason', 'is', null);
      
      if (_startDate != null) {
        postponeQuery = postponeQuery.gte('updated_at', _startDate!.toIso8601String());
      }
      if (_endDate != null) {
        postponeQuery = postponeQuery.lte('updated_at', _endDate!.toIso8601String());
      }
      
      final postponementsData = await postponeQuery.order('updated_at', ascending: false);

      // 3. Load Follow-ups
      var followUpQuery = _supabase
          .from('follow_ups')
          .select('*, patients(name, phone), profiles!follow_ups_created_by_fkey(name)');
      
      if (_startDate != null) {
        followUpQuery = followUpQuery.gte('updated_at', _startDate!.toIso8601String());
      }
      if (_endDate != null) {
        followUpQuery = followUpQuery.lte('updated_at', _endDate!.toIso8601String());
      }
      
      final followUpsData = await followUpQuery.order('updated_at', ascending: false);

      setState(() {
        _cancellations = List<Map<String, dynamic>>.from(cancellationsData);
        _postponements = List<Map<String, dynamic>>.from(postponementsData);
        _followUps = List<Map<String, dynamic>>.from(followUpsData);
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading activity data: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Stats
    final pendingCancellations = _cancellations.where((c) => c['status'] == 'cancellation_pending').length;
    final approvedCancellations = _cancellations.where((c) => c['status'] == 'cancelled').length;
    final pendingFollowUps = _followUps.where((f) => f['status'] == 'pending').length;
    final completedFollowUps = _followUps.where((f) => f['status'] == 'confirmed' || f['status'] == 'completed').length;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('لوحة متابعة الأنشطة'),
        backgroundColor: AppTheme.surface,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.primary,
          tabs: [
            Tab(text: 'الإلغاءات (${_cancellations.length})'),
            Tab(text: 'التأجيلات (${_postponements.length})'),
            Tab(text: 'المتابعات (${_followUps.length})'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Date Filter Bar
          Container(
            padding: const EdgeInsets.all(12),
            color: AppTheme.surface,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildPeriodChip('الكل', 'all'),
                      _buildPeriodChip('اليوم', 'today'),
                      _buildPeriodChip('أسبوع', 'week'),
                      _buildPeriodChip('شهر', 'month'),
                      ActionChip(
                        avatar: const Icon(Icons.date_range, size: 18),
                        label: Text(_selectedPeriod == 'custom' 
                            ? '${DateFormat('MM/dd').format(_startDate!)} - ${DateFormat('MM/dd').format(_endDate!)}'
                            : 'تحديد مدة'),
                        backgroundColor: _selectedPeriod == 'custom' ? AppTheme.primary.withAlpha(51) : null,
                        onPressed: _pickCustomDateRange,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // Stats Row
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildMiniStat('بانتظار الموافقة', pendingCancellations, Colors.orange),
                      const SizedBox(width: 8),
                      _buildMiniStat('تم الإلغاء', approvedCancellations, Colors.red),
                      const SizedBox(width: 8),
                      _buildMiniStat('تأجيلات', _postponements.length, Colors.blue),
                      const SizedBox(width: 8),
                      _buildMiniStat('متابعات معلقة', pendingFollowUps, Colors.orange),
                      const SizedBox(width: 8),
                      _buildMiniStat('متابعات مكتملة', completedFollowUps, Colors.green),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildCancellationsTab(),
                      _buildPostponementsTab(),
                      _buildFollowUpsTab(),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodChip(String label, String value) {
    final isSelected = _selectedPeriod == value;
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        selectedColor: AppTheme.primary.withAlpha(51),
        onSelected: (_) => _setDateRange(value),
      ),
    );
  }

  Widget _buildMiniStat(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withAlpha(26),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withAlpha(77)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$count', style: TextStyle(fontWeight: FontWeight.bold, color: color)),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 11, color: color)),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  // CANCELLATIONS TAB
  // ════════════════════════════════════════════════════════════════
  Widget _buildCancellationsTab() {
    if (_cancellations.isEmpty) {
      return _buildEmptyState('لا توجد إلغاءات', Icons.cancel_outlined);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _cancellations.length,
      itemBuilder: (context, index) {
        final item = _cancellations[index];
        final patientName = item['patients']?['name'] ?? 'مريض';
        final reason = item['cancel_reason'] ?? 'بدون سبب';
        final status = item['status'];
        final date = item['updated_at'] != null 
            ? DateFormat('yyyy-MM-dd HH:mm').format(DateTime.parse(item['updated_at']).toLocal())
            : '-';
        final createdBy = item['profiles']?['name'] ?? '-';

        return Card(
          color: AppTheme.surface,
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: status == 'cancelled' 
                  ? Colors.red.withAlpha(51) 
                  : Colors.orange.withAlpha(51),
              child: Icon(
                status == 'cancelled' ? Icons.check : Icons.hourglass_top,
                color: status == 'cancelled' ? Colors.red : Colors.orange,
              ),
            ),
            title: Text(patientName, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('السبب: $reason', style: const TextStyle(color: Colors.white70)),
                Text('بواسطة: $createdBy • $date', style: const TextStyle(color: Colors.white38, fontSize: 11)),
              ],
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: status == 'cancelled' ? Colors.red.withAlpha(26) : Colors.orange.withAlpha(26),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                status == 'cancelled' ? 'ملغي' : 'بانتظار',
                style: TextStyle(
                  color: status == 'cancelled' ? Colors.red : Colors.orange,
                  fontSize: 11,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ════════════════════════════════════════════════════════════════
  // POSTPONEMENTS TAB
  // ════════════════════════════════════════════════════════════════
  Widget _buildPostponementsTab() {
    if (_postponements.isEmpty) {
      return _buildEmptyState('لا توجد تأجيلات', Icons.schedule);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _postponements.length,
      itemBuilder: (context, index) {
        final item = _postponements[index];
        final patientName = item['patients']?['name'] ?? 'مريض';
        final reason = item['postpone_reason'] ?? 'بدون سبب';
        final date = item['updated_at'] != null 
            ? DateFormat('yyyy-MM-dd HH:mm').format(DateTime.parse(item['updated_at']).toLocal())
            : '-';
        final originalDate = item['start_time'] != null 
            ? DateFormat('yyyy-MM-dd').format(DateTime.parse(item['start_time']).toLocal())
            : '-';

        return Card(
          color: AppTheme.surface,
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.blue.withAlpha(51),
              child: const Icon(Icons.update, color: Colors.blue),
            ),
            title: Text(patientName, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('السبب: $reason', style: const TextStyle(color: Colors.white70)),
                Text('الموعد الأصلي: $originalDate', style: const TextStyle(color: Colors.white38, fontSize: 11)),
                Text('تاريخ التأجيل: $date', style: const TextStyle(color: Colors.white38, fontSize: 11)),
              ],
            ),
            trailing: const Icon(Icons.chevron_left, color: Colors.white38),
          ),
        );
      },
    );
  }

  // ════════════════════════════════════════════════════════════════
  // FOLLOW-UPS TAB
  // ════════════════════════════════════════════════════════════════
  Widget _buildFollowUpsTab() {
    if (_followUps.isEmpty) {
      return _buildEmptyState('لا توجد متابعات', Icons.follow_the_signs);
    }

    // Group by status
    final pending = _followUps.where((f) => f['status'] == 'pending').toList();
    final confirmed = _followUps.where((f) => f['status'] == 'confirmed').toList();
    final completed = _followUps.where((f) => f['status'] == 'completed').toList();
    final cancelled = _followUps.where((f) => f['status'] == 'cancelled' || f['status'] == 'pending_cancellation').toList();

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        if (pending.isNotEmpty) ...[
          _buildSectionHeader('بانتظار الاتصال', pending.length, Colors.orange),
          ...pending.map(_buildFollowUpCard),
        ],
        if (confirmed.isNotEmpty) ...[
          _buildSectionHeader('مؤكدة', confirmed.length, Colors.green),
          ...confirmed.map(_buildFollowUpCard),
        ],
        if (completed.isNotEmpty) ...[
          _buildSectionHeader('مكتملة', completed.length, Colors.teal),
          ...completed.map(_buildFollowUpCard),
        ],
        if (cancelled.isNotEmpty) ...[
          _buildSectionHeader('ملغية', cancelled.length, Colors.red),
          ...cancelled.map(_buildFollowUpCard),
        ],
      ],
    );
  }

  Widget _buildSectionHeader(String title, int count, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(width: 4, height: 20, color: color),
          const SizedBox(width: 8),
          Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(color: color.withAlpha(51), borderRadius: BorderRadius.circular(12)),
            child: Text('$count', style: TextStyle(color: color, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildFollowUpCard(Map<String, dynamic> item) {
    final patientName = item['patients']?['name'] ?? 'مريض';
    final status = item['status'] ?? 'pending';
    final scheduledDate = item['scheduled_date'] ?? '-';
    final createdBy = item['profiles']?['name'] ?? '-';
    final reason = item['cancellation_reason'];

    Color statusColor;
    switch (status) {
      case 'confirmed': statusColor = Colors.green; break;
      case 'completed': statusColor = Colors.teal; break;
      case 'cancelled':
      case 'pending_cancellation': statusColor = Colors.red; break;
      default: statusColor = Colors.orange;
    }

    return Card(
      color: AppTheme.surface,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: statusColor.withAlpha(51),
          child: Icon(Icons.person, color: statusColor),
        ),
        title: Text(patientName, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('موعد: $scheduledDate', style: const TextStyle(color: Colors.white70)),
            Text('أنشأها: $createdBy', style: const TextStyle(color: Colors.white38, fontSize: 11)),
            if (reason != null && reason.isNotEmpty)
              Text('السبب: $reason', style: const TextStyle(color: Colors.red, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(String message, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.white24),
          const SizedBox(height: 16),
          Text(message, style: const TextStyle(color: Colors.white54)),
        ],
      ),
    );
  }
}
