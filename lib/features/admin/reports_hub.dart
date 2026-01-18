import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import 'package:fl_chart/fl_chart.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});
  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  // Filters
  DateTimeRange? _dateRange;
  String _selectedDoctor = 'all';
  String _selectedService = 'all';
  String _selectedStatus = 'all';
  String _selectedReception = 'all';
  String _selectedCallCenter = 'all';
  String _searchQuery = '';
  
  // Data
  bool _isLoading = true;
  Map<String, dynamic> _stats = {};
  List<Map<String, dynamic>> _sessions = [];
  List<Map<String, dynamic>> _patients = [];
  List<Map<String, dynamic>> _doctors = [];
  List<Map<String, dynamic>> _services = [];
  // ignore: unused_field - stored for future use
  List<Map<String, dynamic>> _devices = [];
  // ignore: unused_field - stored for future use 
  List<Map<String, dynamic>> _receptionists = [];
  // ignore: unused_field - stored for future use
  List<Map<String, dynamic>> _callCenterStaff = [];
  
  // Quick Filters
  String _quickFilter = 'month'; // today, week, month, year, custom
  
  final _searchController = TextEditingController();
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _setQuickFilter('month');
    _loadData();
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }
  
  void _setQuickFilter(String filter) {
    final now = DateTime.now();
    setState(() {
      _quickFilter = filter;
      switch (filter) {
        case 'today':
          _dateRange = DateTimeRange(
            start: DateTime(now.year, now.month, now.day),
            end: DateTime(now.year, now.month, now.day, 23, 59, 59),
          );
          break;
        case 'week':
          final weekStart = now.subtract(Duration(days: now.weekday - 1));
          _dateRange = DateTimeRange(
            start: DateTime(weekStart.year, weekStart.month, weekStart.day),
            end: now,
          );
          break;
        case 'month':
          _dateRange = DateTimeRange(
            start: DateTime(now.year, now.month, 1),
            end: DateTime(now.year, now.month + 1, 0),
          );
          break;
        case 'year':
          _dateRange = DateTimeRange(
            start: DateTime(now.year, 1, 1),
            end: DateTime(now.year, 12, 31),
          );
          break;
      }
    });
    _loadData();
  }
  
  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    try {
      final supabase = Supabase.instance.client;
      
      // Load all data in parallel for speed
      final results = await Future.wait([
        supabase.from('sessions').select('*, patients(name, phone, gender, source), services(name), profiles!sessions_doctor_id_fkey(name)'),
        supabase.from('patients').select('*'),
        supabase.from('profiles').select('*').eq('role', 'doctor'),
        supabase.from('services').select('*'),
        supabase.from('devices').select('*'),
        supabase.from('profiles').select('*').eq('role', 'reception'),
        supabase.from('profiles').select('*').eq('role', 'call_center'),
      ]);
      
      _sessions = List<Map<String, dynamic>>.from(results[0]);
      _patients = List<Map<String, dynamic>>.from(results[1]);
      _doctors = List<Map<String, dynamic>>.from(results[2]);
      _services = List<Map<String, dynamic>>.from(results[3]);
      _devices = List<Map<String, dynamic>>.from(results[4]);
      _receptionists = List<Map<String, dynamic>>.from(results[5]);
      _callCenterStaff = List<Map<String, dynamic>>.from(results[6]);
      
      _calculateStats();
    } catch (e) {
      debugPrint('Error loading data: $e');
    }
    
    setState(() => _isLoading = false);
  }
  
  void _calculateStats() {
    // Filter sessions by date
    final filtered = _sessions.where((s) {
      if (s['start_time'] == null) return false;
      final time = DateTime.parse(s['start_time']);
      return _dateRange == null || 
          (time.isAfter(_dateRange!.start.subtract(const Duration(days: 1))) && 
           time.isBefore(_dateRange!.end.add(const Duration(days: 1))));
    }).toList();
    
    // Apply other filters
    final filteredByAll = filtered.where((s) {
      if (_selectedDoctor != 'all' && s['doctor_id']?.toString() != _selectedDoctor) return false;
      if (_selectedService != 'all' && s['service_id']?.toString() != _selectedService) return false;
      if (_selectedStatus != 'all' && s['status'] != _selectedStatus) return false;
      
      // Filter by reception or call center who booked
      if (_selectedReception != 'all') {
        final bookedById = s['booked_by_id']?.toString() ?? '';
        if (bookedById != _selectedReception) return false;
      }
      if (_selectedCallCenter != 'all') {
        final bookedById = s['booked_by_id']?.toString() ?? '';
        if (bookedById != _selectedCallCenter) return false;
      }
      
      // Enhanced search - search everything
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final patientName = (s['patients']?['name'] ?? '').toString().toLowerCase();
        final patientPhone = (s['patients']?['phone'] ?? '').toString().toLowerCase();
        final serviceName = (s['services']?['name'] ?? '').toString().toLowerCase();
        final doctorName = (s['profiles']?['name'] ?? '').toString().toLowerCase();
        final bookedByName = (s['booked_by']?['name'] ?? '').toString().toLowerCase();
        final status = (s['status'] ?? '').toString().toLowerCase();
        final notes = (s['notes'] ?? '').toString().toLowerCase();
        
        if (!patientName.contains(q) && 
            !patientPhone.contains(q) &&
            !serviceName.contains(q) &&
            !doctorName.contains(q) &&
            !bookedByName.contains(q) &&
            !status.contains(q) &&
            !notes.contains(q)) {
          return false;
        }
      }
      return true;
    }).toList();
    
    // Calculate stats
    int totalRevenue = 0;
    int todayRevenue = 0;
    int completed = 0, cancelled = 0, noShow = 0, pending = 0, arrived = 0;
    Map<String, int> hourlyBookings = {};
    Map<String, int> dailyRevenue = {};
    Map<String, int> serviceRevenue = {};
    Map<String, Map<String, dynamic>> doctorStats = {};
    
    final today = DateTime.now();
    
    for (var s in filteredByAll) {
      final price = (s['price'] ?? 0) as int;
      final status = s['status'] ?? '';
      final startTime = s['start_time'] != null ? DateTime.parse(s['start_time']) : null;
      
      if (status == 'completed') {
        totalRevenue += price;
        completed++;
        
        if (startTime != null) {
          // Today revenue
          if (startTime.year == today.year && startTime.month == today.month && startTime.day == today.day) {
            todayRevenue += price;
          }
          
          // Daily revenue
          final dayKey = intl.DateFormat('MM/dd').format(startTime);
          dailyRevenue[dayKey] = (dailyRevenue[dayKey] ?? 0) + price;
          
          // Hourly
          hourlyBookings['${startTime.hour}'] = (hourlyBookings['${startTime.hour}'] ?? 0) + 1;
          
          // Service revenue
          final serviceName = s['services']?['name'] ?? 'غير محدد';
          serviceRevenue[serviceName] = (serviceRevenue[serviceName] ?? 0) + price;
        }
      } else if (status == 'cancelled') {
        cancelled++;
      } else if (status == 'no_show') {
        noShow++;
      } else if (status == 'arrived') {
        arrived++;
      } else {
        pending++;
      }
      
      // Doctor stats
      final docId = s['doctor_id']?.toString() ?? '';
      final docName = s['profiles']?['name'] ?? 'غير محدد';
      if (docId.isNotEmpty) {
        if (!doctorStats.containsKey(docId)) {
          doctorStats[docId] = {'name': docName, 'sessions': 0, 'revenue': 0, 'completed': 0, 'cancelled': 0};
        }
        doctorStats[docId]!['sessions'] = (doctorStats[docId]!['sessions'] ?? 0) + 1;
        if (status == 'completed') {
          doctorStats[docId]!['revenue'] = (doctorStats[docId]!['revenue'] ?? 0) + price;
          doctorStats[docId]!['completed'] = (doctorStats[docId]!['completed'] ?? 0) + 1;
        } else if (status == 'cancelled') {
          doctorStats[docId]!['cancelled'] = (doctorStats[docId]!['cancelled'] ?? 0) + 1;
        }
      }
    }
    
    // Sort service revenue
    var sortedServices = serviceRevenue.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    // Sort doctor stats
    var sortedDoctors = doctorStats.values.toList()
      ..sort((a, b) => (b['revenue'] as int).compareTo(a['revenue'] as int));
    
    _stats = {
      'totalRevenue': totalRevenue,
      'todayRevenue': todayRevenue,
      'totalSessions': filteredByAll.length,
      'completed': completed,
      'cancelled': cancelled,
      'noShow': noShow,
      'pending': pending,
      'arrived': arrived,
      'avgSession': completed > 0 ? totalRevenue ~/ completed : 0,
      'completionRate': filteredByAll.isNotEmpty ? (completed / filteredByAll.length * 100).toStringAsFixed(1) : '0',
      'cancellationRate': filteredByAll.isNotEmpty ? (cancelled / filteredByAll.length * 100).toStringAsFixed(1) : '0',
      'hourlyBookings': hourlyBookings,
      'dailyRevenue': dailyRevenue,
      'serviceRevenue': sortedServices,
      'doctorStats': sortedDoctors,
      'filteredSessions': filteredByAll,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Column(
        children: [
          _buildHeader(),
          _buildQuickFilters(),
          _buildAdvancedFilters(),
          _buildTabBar(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildOverviewTab(),
                      _buildFinancialTab(),
                      _buildDoctorsTab(),
                      _buildSessionsTab(),
                      _buildPatientsTab(),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border(bottom: BorderSide(color: Colors.white.withAlpha(13))),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < 600;
          
          return Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // العنوان
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.analytics, color: AppTheme.primary, size: 22),
                  const SizedBox(width: 8),
                  Text(isMobile ? 'التقارير' : 'مركز التقارير', 
                    style: TextStyle(fontSize: isMobile ? 16 : 18, fontWeight: FontWeight.bold)),
                ],
              ),
              
              // الأزرار
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // البحث (للشاشات الكبيرة فقط)
                  if (!isMobile)
                    SizedBox(
                      width: 180,
                      height: 36,
                      child: TextField(
                        controller: _searchController,
                        onChanged: (v) {
                          setState(() => _searchQuery = v);
                          _calculateStats();
                        },
                        decoration: InputDecoration(
                          hintText: 'بحث...',
                          hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
                          prefixIcon: const Icon(Icons.search, color: Colors.white38, size: 18),
                          filled: true,
                          fillColor: AppTheme.background,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                        ),
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                  const SizedBox(width: 4),
                  IconButton(
                    onPressed: _loadData,
                    icon: const Icon(Icons.refresh, color: Colors.white70, size: 20),
                    tooltip: 'تحديث',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 4),
                  ElevatedButton.icon(
                    onPressed: _showExportDialog,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      minimumSize: Size.zero,
                    ),
                    icon: const Icon(Icons.download, size: 16),
                    label: Text(isMobile ? '' : 'تصدير', style: const TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildQuickFilters() {
    final filters = [
      {'key': 'today', 'label': 'اليوم', 'icon': Icons.today},
      {'key': 'week', 'label': 'الأسبوع', 'icon': Icons.view_week},
      {'key': 'month', 'label': 'الشهر', 'icon': Icons.calendar_month},
      {'key': 'year', 'label': 'السنة', 'icon': Icons.calendar_today},
      {'key': 'custom', 'label': 'مخصص', 'icon': Icons.date_range},
    ];
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: AppTheme.surface,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            const Text('الفترة: ', style: TextStyle(color: Colors.white70, fontSize: 11)),
            const SizedBox(width: 4),
            ...filters.map((f) => Padding(
              padding: const EdgeInsets.only(left: 4),
              child: _QuickFilterChip(
                label: f['label'] as String,
                icon: f['icon'] as IconData,
                isSelected: _quickFilter == f['key'],
                onTap: () {
                  if (f['key'] == 'custom') {
                    _pickCustomDateRange();
                  } else {
                    _setQuickFilter(f['key'] as String);
                  }
                },
              ),
            )),
            const SizedBox(width: 8),
            if (_dateRange != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withAlpha(26),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${intl.DateFormat('d/M').format(_dateRange!.start)} - ${intl.DateFormat('d/M').format(_dateRange!.end)}',
                  style: const TextStyle(color: AppTheme.primary, fontSize: 10, fontWeight: FontWeight.w600),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdvancedFilters() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: AppTheme.surface,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            // Doctor Filter
            _FilterDropdown(
              label: 'الطبيب',
              value: _selectedDoctor,
              items: [
                const DropdownMenuItem(value: 'all', child: Text('الكل', style: TextStyle(fontSize: 11))),
                ..._doctors.map((d) => DropdownMenuItem(
                  value: d['id'].toString(),
                  child: Text(d['name'] ?? '', style: const TextStyle(fontSize: 11)),
                )),
              ],
              onChanged: (v) {
                setState(() => _selectedDoctor = v ?? 'all');
                _calculateStats();
              },
            ),
            const SizedBox(width: 8),
            // Service Filter
            _FilterDropdown(
              label: 'الخدمة',
              value: _selectedService,
              items: [
                const DropdownMenuItem(value: 'all', child: Text('الكل', style: TextStyle(fontSize: 11))),
                ..._services.map((s) => DropdownMenuItem(
                  value: s['id'].toString(),
                  child: Text(s['name'] ?? '', style: const TextStyle(fontSize: 11)),
                )),
              ],
              onChanged: (v) {
                setState(() => _selectedService = v ?? 'all');
                _calculateStats();
              },
            ),
            const SizedBox(width: 8),
            // Status Filter
            _FilterDropdown(
              label: 'الحالة',
              value: _selectedStatus,
              items: const [
                DropdownMenuItem(value: 'all', child: Text('الكل', style: TextStyle(fontSize: 11))),
                DropdownMenuItem(value: 'completed', child: Text('مكتمل', style: TextStyle(fontSize: 11))),
                DropdownMenuItem(value: 'arrived', child: Text('وصل', style: TextStyle(fontSize: 11))),
                DropdownMenuItem(value: 'booked', child: Text('محجوز', style: TextStyle(fontSize: 11))),
                DropdownMenuItem(value: 'cancelled', child: Text('ملغي', style: TextStyle(fontSize: 11))),
              ],
              onChanged: (v) {
                setState(() => _selectedStatus = v ?? 'all');
                _calculateStats();
              },
            ),
            const SizedBox(width: 8),
            // Clear Filters
            if (_selectedDoctor != 'all' || _selectedService != 'all' || _selectedStatus != 'all' || _searchQuery.isNotEmpty)
              IconButton(
                onPressed: () {
                  setState(() {
                    _selectedDoctor = 'all';
                    _selectedService = 'all';
                    _selectedStatus = 'all';
                    _selectedReception = 'all';
                    _selectedCallCenter = 'all';
                    _searchQuery = '';
                    _searchController.clear();
                  });
                  _calculateStats();
                },
                icon: const Icon(Icons.clear_all, size: 18, color: Colors.white54),
                tooltip: 'مسح الفلاتر',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: AppTheme.surface,
      child: TabBar(
        controller: _tabController,
        labelColor: AppTheme.primary,
        unselectedLabelColor: Colors.white54,
        indicatorColor: AppTheme.primary,
        tabs: const [
          Tab(text: 'نظرة عامة', icon: Icon(Icons.dashboard, size: 18)),
          Tab(text: 'المالية', icon: Icon(Icons.attach_money, size: 18)),
          Tab(text: 'الأطباء', icon: Icon(Icons.medical_services, size: 18)),
          Tab(text: 'الجلسات', icon: Icon(Icons.calendar_month, size: 18)),
          Tab(text: 'المرضى', icon: Icon(Icons.people, size: 18)),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // TAB 1: OVERVIEW
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // KPI Cards
          _buildKPICards(),
          const SizedBox(height: 20),
          // Charts Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 2, child: _buildRevenueChart()),
              const SizedBox(width: 20),
              Expanded(child: _buildStatusPieChart()),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 2, child: _buildHourlyChart()),
              const SizedBox(width: 20),
              Expanded(child: _buildTopDoctorsCard()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildKPICards() {
    final cards = [
      {'title': 'الإيراد', 'value': intl.NumberFormat("#,##0").format(_stats['totalRevenue'] ?? 0), 'icon': Icons.attach_money, 'color': Colors.green},
      {'title': 'الجلسات', 'value': '${_stats['totalSessions'] ?? 0}', 'icon': Icons.calendar_month, 'color': Colors.blue},
      {'title': 'مكتمل', 'value': '${_stats['completed'] ?? 0}', 'icon': Icons.check_circle, 'color': Colors.teal},
      {'title': 'ملغي', 'value': '${_stats['cancelled'] ?? 0}', 'icon': Icons.cancel, 'color': Colors.orange},
      {'title': 'نسبة', 'value': '${_stats['completionRate'] ?? 0}%', 'icon': Icons.trending_up, 'color': AppTheme.primary},
    ];
    
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;
        final crossAxisCount = isMobile ? 3 : 5;
        final aspectRatio = isMobile ? 1.2 : 2.0;
        
        return GridView.count(
          crossAxisCount: crossAxisCount,
          shrinkWrap: true,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: aspectRatio,
          physics: const NeverScrollableScrollPhysics(),
          children: cards.map((c) => _KPICard(
            title: c['title'] as String,
            value: c['value'] as String,
            icon: c['icon'] as IconData,
            color: c['color'] as Color,
          )).toList(),
        );
      },
    );
  }

  Widget _buildRevenueChart() {
    final dailyData = _stats['dailyRevenue'] as Map<String, int>? ?? {};
    final sortedData = dailyData.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
    
    return _ChartCard(
      title: 'الإيرادات اليومية',
      height: 300,
      child: sortedData.isEmpty
          ? const Center(child: Text('لا توجد بيانات', style: TextStyle(color: Colors.white54)))
          : LineChart(
              LineChartData(
                gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (v) => FlLine(color: Colors.white12)),
                titlesData: FlTitlesData(
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      getTitlesWidget: (val, meta) {
                        if (val.toInt() >= 0 && val.toInt() < sortedData.length && val.toInt() % 3 == 0) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(sortedData[val.toInt()].key, style: const TextStyle(fontSize: 10, color: Colors.white54)),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 50,
                      getTitlesWidget: (val, meta) => Text('${(val / 1000).toStringAsFixed(0)}k', style: const TextStyle(fontSize: 10, color: Colors.white54)),
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: sortedData.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.value.toDouble())).toList(),
                    isCurved: true,
                    color: AppTheme.primary,
                    barWidth: 3,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(show: true, color: AppTheme.primary.withAlpha(51)),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildStatusPieChart() {
    final completed = (_stats['completed'] ?? 0).toDouble();
    final cancelled = (_stats['cancelled'] ?? 0).toDouble();
    final noShow = (_stats['noShow'] ?? 0).toDouble();
    final pending = (_stats['pending'] ?? 0).toDouble();
    final total = completed + cancelled + noShow + pending;
    
    return _ChartCard(
      title: 'توزيع الحالات',
      height: 300,
      child: total == 0
          ? const Center(child: Text('لا توجد بيانات', style: TextStyle(color: Colors.white54)))
          : Column(
              children: [
                Expanded(
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 30,
                      sections: [
                        if (completed > 0) PieChartSectionData(value: completed, title: '', color: Colors.green, radius: 45),
                        if (cancelled > 0) PieChartSectionData(value: cancelled, title: '', color: Colors.orange, radius: 45),
                        if (noShow > 0) PieChartSectionData(value: noShow, title: '', color: Colors.red, radius: 45),
                        if (pending > 0) PieChartSectionData(value: pending, title: '', color: Colors.grey, radius: 45),
                      ],
                    ),
                  ),
                ),
                Wrap(
                  spacing: 12,
                  children: [
                    _LegendItem(label: 'مكتمل', color: Colors.green, count: completed.toInt()),
                    _LegendItem(label: 'ملغي', color: Colors.orange, count: cancelled.toInt()),
                    _LegendItem(label: 'لم يحضر', color: Colors.red, count: noShow.toInt()),
                    _LegendItem(label: 'محجوز', color: Colors.grey, count: pending.toInt()),
                  ],
                ),
              ],
            ),
    );
  }

  Widget _buildHourlyChart() {
    final hourlyData = _stats['hourlyBookings'] as Map<String, int>? ?? {};
    
    return _ChartCard(
      title: 'الحجوزات بالساعة',
      height: 300,
      child: hourlyData.isEmpty
          ? const Center(child: Text('لا توجد بيانات', style: TextStyle(color: Colors.white54)))
          : BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (v) => FlLine(color: Colors.white12)),
                titlesData: FlTitlesData(
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (val, meta) => Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text('${val.toInt()}', style: const TextStyle(fontSize: 10, color: Colors.white54)),
                      ),
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                barGroups: hourlyData.entries.map((e) => BarChartGroupData(
                  x: int.parse(e.key),
                  barRods: [BarChartRodData(toY: e.value.toDouble(), color: AppTheme.primary, width: 14, borderRadius: const BorderRadius.vertical(top: Radius.circular(4)))],
                )).toList(),
              ),
            ),
    );
  }

  Widget _buildTopDoctorsCard() {
    final docs = _stats['doctorStats'] as List<Map<String, dynamic>>? ?? [];
    
    return _ChartCard(
      title: 'أفضل الأطباء',
      height: 300,
      child: docs.isEmpty
          ? const Center(child: Text('لا توجد بيانات', style: TextStyle(color: Colors.white54)))
          : ListView.separated(
              shrinkWrap: true,
              itemCount: docs.take(5).length,
              separatorBuilder: (_, i) => Divider(color: Colors.white.withAlpha(26)),
              itemBuilder: (ctx, idx) {
                final doc = docs[idx];
                return ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    radius: 16,
                    backgroundColor: AppTheme.primary.withAlpha(51),
                    child: Text('${idx + 1}', style: const TextStyle(color: AppTheme.primary, fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                  title: Text(doc['name'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 13)),
                  subtitle: Text('${doc['sessions']} جلسة', style: const TextStyle(color: Colors.white54, fontSize: 11)),
                  trailing: Text('${intl.NumberFormat("#,##0").format(doc['revenue'])} د.ع', style: const TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold)),
                );
              },
            ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // TAB 2: FINANCIAL
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildFinancialTab() {
    final serviceRev = _stats['serviceRevenue'] as List<MapEntry<String, int>>? ?? [];
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Summary Cards
          Row(
            children: [
              Expanded(child: _FinanceCard(title: 'الإيراد الإجمالي', value: _stats['totalRevenue'] ?? 0, icon: Icons.attach_money, color: Colors.green)),
              const SizedBox(width: 12),
              Expanded(child: _FinanceCard(title: 'متوسط الجلسة', value: _stats['avgSession'] ?? 0, icon: Icons.trending_up, color: Colors.blue)),
              const SizedBox(width: 12),
              Expanded(child: _FinanceCard(title: 'إيراد اليوم', value: _stats['todayRevenue'] ?? 0, icon: Icons.today, color: Colors.teal)),
              const SizedBox(width: 12),
              Expanded(child: _FinanceCard(title: 'الجلسات المكتملة', value: _stats['completed'] ?? 0, icon: Icons.check_circle, color: AppTheme.primary, isCurrency: false)),
            ],
          ),
          const SizedBox(height: 20),
          // Service Revenue
          _ChartCard(
            title: 'الإيرادات حسب الخدمة',
            height: 400,
            child: serviceRev.isEmpty
                ? const Center(child: Text('لا توجد بيانات', style: TextStyle(color: Colors.white54)))
                : ListView.builder(
                    itemCount: serviceRev.length,
                    itemBuilder: (ctx, idx) {
                      final svc = serviceRev[idx];
                      final max = serviceRev.first.value;
                      final percent = max > 0 ? svc.value / max : 0.0;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(child: Text(svc.key, style: const TextStyle(color: Colors.white, fontSize: 13), overflow: TextOverflow.ellipsis)),
                                Text('${intl.NumberFormat("#,##0").format(svc.value)} د.ع', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                              ],
                            ),
                            const SizedBox(height: 4),
                            LinearProgressIndicator(
                              value: percent,
                              backgroundColor: Colors.white12,
                              color: AppTheme.primary,
                              minHeight: 6,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // TAB 3: DOCTORS
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildDoctorsTab() {
    final docs = _stats['doctorStats'] as List<Map<String, dynamic>>? ?? [];
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: _ChartCard(
        title: 'أداء الأطباء',
        height: 600,
        child: docs.isEmpty
            ? const Center(child: Text('لا توجد بيانات', style: TextStyle(color: Colors.white54)))
            : DataTable(
                columnSpacing: 30,
                headingRowColor: WidgetStateProperty.all(AppTheme.primary.withAlpha(26)),
                columns: const [
                  DataColumn(label: Text('#', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('الطبيب', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('الجلسات', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), numeric: true),
                  DataColumn(label: Text('مكتمل', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), numeric: true),
                  DataColumn(label: Text('ملغي', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), numeric: true),
                  DataColumn(label: Text('الإيراد', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), numeric: true),
                  DataColumn(label: Text('نسبة الإكمال', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), numeric: true),
                ],
                rows: docs.asMap().entries.map((e) {
                  final doc = e.value;
                  final sessions = doc['sessions'] ?? 0;
                  final completed = doc['completed'] ?? 0;
                  final rate = sessions > 0 ? (completed / sessions * 100).toStringAsFixed(1) : '0';
                  return DataRow(cells: [
                    DataCell(Text('${e.key + 1}', style: const TextStyle(color: Colors.white70))),
                    DataCell(Text(doc['name'] ?? '', style: const TextStyle(color: Colors.white))),
                    DataCell(Text('$sessions', style: const TextStyle(color: Colors.white70))),
                    DataCell(Text('$completed', style: const TextStyle(color: Colors.green))),
                    DataCell(Text('${doc['cancelled'] ?? 0}', style: const TextStyle(color: Colors.orange))),
                    DataCell(Text('${intl.NumberFormat("#,##0").format(doc['revenue'])} د.ع', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                    DataCell(Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: double.parse(rate) >= 80 ? Colors.green.withAlpha(51) : Colors.orange.withAlpha(51),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text('$rate%', style: TextStyle(color: double.parse(rate) >= 80 ? Colors.green : Colors.orange, fontSize: 12)),
                    )),
                  ]);
                }).toList(),
              ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // TAB 4: SESSIONS
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildSessionsTab() {
    final sessions = _stats['filteredSessions'] as List<Map<String, dynamic>>? ?? [];
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${sessions.length} جلسة', style: const TextStyle(color: Colors.white70, fontSize: 14)),
          const SizedBox(height: 12),
          _ChartCard(
            title: 'قائمة الجلسات',
            height: 600,
            child: sessions.isEmpty
                ? const Center(child: Text('لا توجد جلسات', style: TextStyle(color: Colors.white54)))
                : ListView.builder(
                    itemCount: sessions.length,
                    itemBuilder: (ctx, idx) {
                      final s = sessions[idx];
                      final status = s['status'] ?? '';
                      final statusColor = status == 'completed' ? Colors.green : status == 'cancelled' ? Colors.orange : status == 'no_show' ? Colors.red : Colors.grey;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.background,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: statusColor.withAlpha(77)),
                        ),
                        child: Row(
                          children: [
                            Container(width: 4, height: 40, decoration: BoxDecoration(color: statusColor, borderRadius: BorderRadius.circular(2))),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(s['patients']?['name'] ?? 'غير محدد', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                                  Text(s['services']?['name'] ?? '', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text('${intl.NumberFormat("#,##0").format(s['price'] ?? 0)} د.ع', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                Text(s['start_time'] != null ? intl.DateFormat('yyyy/MM/dd - HH:mm').format(DateTime.parse(s['start_time'])) : '', style: const TextStyle(color: Colors.white38, fontSize: 11)),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // TAB 5: PATIENTS
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildPatientsTab() {
    // Patient analysis
    Map<String, int> patientVisits = {};
    Map<String, int> patientSpending = {};
    Map<String, String> patientNames = {};
    
    for (var s in _sessions) {
      final pid = s['patient_id']?.toString() ?? '';
      if (pid.isNotEmpty) {
        patientVisits[pid] = (patientVisits[pid] ?? 0) + 1;
        patientNames[pid] = s['patients']?['name'] ?? 'غير محدد';
        if (s['status'] == 'completed') {
          patientSpending[pid] = (patientSpending[pid] ?? 0) + ((s['price'] ?? 0) as int);
        }
      }
    }
    
    final vip = patientVisits.entries.where((e) => e.value >= 5).length;
    final regular = patientVisits.entries.where((e) => e.value >= 2 && e.value < 5).length;
    final oneTime = patientVisits.entries.where((e) => e.value == 1).length;
    
    var topPatients = patientSpending.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Summary
          Row(
            children: [
              Expanded(child: _KPICard(title: 'إجمالي المرضى', value: '${_patients.length}', icon: Icons.people, color: Colors.blue)),
              const SizedBox(width: 12),
              Expanded(child: _KPICard(title: 'VIP (+5 زيارات)', value: '$vip', icon: Icons.star, color: Colors.amber)),
              const SizedBox(width: 12),
              Expanded(child: _KPICard(title: 'عادي (2-4)', value: '$regular', icon: Icons.person, color: Colors.teal)),
              const SizedBox(width: 12),
              Expanded(child: _KPICard(title: 'جديد (1)', value: '$oneTime', icon: Icons.person_add, color: Colors.grey)),
            ],
          ),
          const SizedBox(height: 20),
          // Top Patients
          _ChartCard(
            title: 'أفضل المرضى إنفاقاً',
            height: 400,
            child: topPatients.isEmpty
                ? const Center(child: Text('لا توجد بيانات', style: TextStyle(color: Colors.white54)))
                : ListView.builder(
                    itemCount: topPatients.take(10).length,
                    itemBuilder: (ctx, idx) {
                      final p = topPatients[idx];
                      return ListTile(
                        leading: CircleAvatar(
                          radius: 18,
                          backgroundColor: idx < 3 ? Colors.amber.withAlpha(51) : AppTheme.primary.withAlpha(51),
                          child: Text('${idx + 1}', style: TextStyle(color: idx < 3 ? Colors.amber : AppTheme.primary, fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                        title: Text(patientNames[p.key] ?? '', style: const TextStyle(color: Colors.white)),
                        subtitle: Text('${patientVisits[p.key] ?? 0} زيارة', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                        trailing: Text('${intl.NumberFormat("#,##0").format(p.value)} د.ع', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // DIALOGS
  // ═══════════════════════════════════════════════════════════════════════════
  Future<void> _pickCustomDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2023),
      lastDate: DateTime(2030),
      initialDateRange: _dateRange,
      locale: const Locale('ar'),
    );
    if (picked != null) {
      setState(() {
        _quickFilter = 'custom';
        _dateRange = picked;
      });
      _loadData();
    }
  }

  void _showExportDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('تصدير التقرير', style: TextStyle(color: Colors.white)),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(leading: Icon(Icons.picture_as_pdf, color: Colors.red), title: Text('PDF', style: TextStyle(color: Colors.white))),
            ListTile(leading: Icon(Icons.table_chart, color: Colors.green), title: Text('Excel', style: TextStyle(color: Colors.white))),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إغلاق')),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// WIDGETS
// ═══════════════════════════════════════════════════════════════════════════════

class _QuickFilterChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;
  
  const _QuickFilterChip({required this.label, required this.icon, required this.isSelected, required this.onTap});
  
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary : AppTheme.background,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? AppTheme.primary : Colors.white24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: isSelected ? Colors.white : Colors.white54),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(fontSize: 12, color: isSelected ? Colors.white : Colors.white54)),
          ],
        ),
      ),
    );
  }
}

class _FilterDropdown extends StatelessWidget {
  final String label;
  final String value;
  final List<DropdownMenuItem<String>> items;
  final Function(String?) onChanged;
  
  const _FilterDropdown({required this.label, required this.value, required this.items, required this.onChanged});
  
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$label: ', style: const TextStyle(color: Colors.white54, fontSize: 12)),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(color: AppTheme.background, borderRadius: BorderRadius.circular(8)),
          child: DropdownButton<String>(
            value: value,
            items: items,
            onChanged: onChanged,
            dropdownColor: AppTheme.surface,
            underline: const SizedBox(),
            style: const TextStyle(color: Colors.white, fontSize: 13),
            icon: const Icon(Icons.arrow_drop_down, color: Colors.white54),
          ),
        ),
      ],
    );
  }
}

class _KPICard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  
  const _KPICard({required this.title, required this.value, required this.icon, required this.color});
  
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withAlpha(51)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const Spacer(),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
          ),
          Flexible(
            child: Text(title, style: const TextStyle(color: Colors.white54, fontSize: 8), overflow: TextOverflow.ellipsis, maxLines: 1),
          ),
        ],
      ),
    );
  }
}

class _FinanceCard extends StatelessWidget {
  final String title;
  final int value;
  final IconData icon;
  final Color color;
  final bool isCurrency;
  
  const _FinanceCard({required this.title, required this.value, required this.icon, required this.color, this.isCurrency = true});
  
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withAlpha(51)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              isCurrency ? intl.NumberFormat("#,##0").format(value) : '$value',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color),
            ),
          ),
          Text(title, style: const TextStyle(color: Colors.white54, fontSize: 9), overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  final String title;
  final double height;
  final Widget child;
  
  const _ChartCard({required this.title, required this.height, required this.child});
  
  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withAlpha(13)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 16),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final String label;
  final Color color;
  final int count;
  
  const _LegendItem({required this.label, required this.color, required this.count});
  
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text('$label ($count)', style: const TextStyle(fontSize: 11, color: Colors.white54)),
      ],
    );
  }
}
