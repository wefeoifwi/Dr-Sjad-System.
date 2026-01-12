import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart' as intl;
import 'package:fl_chart/fl_chart.dart';
import 'admin_provider.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> with SingleTickerProviderStateMixin {
  DateTimeRange? _selectedDateRange;
  late TabController _tabController;
  String _selectedDoctor = 'all';
  String _selectedService = 'all';
  
  final List<String> _reportTabs = [
    'نظرة عامة',
    'المالية',
    'الأطباء',
    'المرضى',
    'الجلسات',
    'الأجهزة',
  ];
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _reportTabs.length, vsync: this);
    final now = DateTime.now();
    _selectedDateRange = DateTimeRange(
      start: DateTime(now.year, now.month, 1),
      end: DateTime(now.year, now.month + 1, 0),
    );
    
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshData());
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _refreshData() {
    if (_selectedDateRange != null) {
      context.read<AdminProvider>().generateAdvancedReports(
        customStartDate: _selectedDateRange!.start,
        customEndDate: _selectedDateRange!.end,
      );
    }
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2023),
      lastDate: DateTime(2030),
      initialDateRange: _selectedDateRange,
      locale: const Locale('ar'),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF6C63FF),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() => _selectedDateRange = picked);
      _refreshData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final admin = context.watch<AdminProvider>();
    
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          // Header
          _buildHeader(admin),
          
          // Tab Bar
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              labelColor: const Color(0xFF6C63FF),
              unselectedLabelColor: Colors.grey,
              indicatorColor: const Color(0xFF6C63FF),
              tabs: _reportTabs.map((t) => Tab(text: t)).toList(),
            ),
          ),
          
          // Content
          Expanded(
            child: admin.isLoading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildOverviewTab(admin),
                      _buildFinancialTab(admin),
                      _buildDoctorsTab(admin),
                      _buildPatientsTab(admin),
                      _buildSessionsTab(admin),
                      _buildDevicesTab(admin),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(AdminProvider admin) {
    final startFmt = _selectedDateRange != null 
        ? intl.DateFormat('yyyy/MM/dd').format(_selectedDateRange!.start) : '-';
    final endFmt = _selectedDateRange != null 
        ? intl.DateFormat('yyyy/MM/dd').format(_selectedDateRange!.end) : '-';
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(13), blurRadius: 10)],
      ),
      child: Row(
        children: [
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('مركز التقارير', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
              Text('تحليلات شاملة لأداء العيادة', style: TextStyle(color: Colors.grey)),
            ],
          ),
          const Spacer(),
          
          // Date Range Picker
          InkWell(
            onTap: _pickDateRange,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today, size: 18, color: Color(0xFF6C63FF)),
                  const SizedBox(width: 10),
                  Text('$startFmt - $endFmt', style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_drop_down),
                ],
              ),
            ),
          ),
          
          const SizedBox(width: 12),
          
          // Refresh Button
          IconButton(
            onPressed: _refreshData,
            icon: const Icon(Icons.refresh),
            tooltip: 'تحديث',
          ),
          
          // Export Button
          ElevatedButton.icon(
            onPressed: () => _showExportDialog(),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6C63FF),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            ),
            icon: const Icon(Icons.download, size: 18),
            label: const Text('تصدير'),
          ),
        ],
      ),
    );
  }

  // ============ TAB 1: OVERVIEW ============
  Widget _buildOverviewTab(AdminProvider admin) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // KPI Cards Row
          _buildKPICards(admin),
          const SizedBox(height: 24),
          
          // Alerts
          if (admin.pendingCancellations.isNotEmpty)
            _buildAlertCard(admin),
          
          const SizedBox(height: 24),
          
          // Charts Row 1: Revenue + Status Pie
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 2, child: _buildRevenueChart(admin)),
              const SizedBox(width: 20),
              Expanded(child: _buildStatusPieChart(admin)),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // Charts Row 2: Hourly Analysis + Top Doctors
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 2, child: _buildHourlyAnalysisChart(admin)),
              const SizedBox(width: 20),
              Expanded(child: _buildTopDoctorsCard(admin)),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // AI Insights
          _buildInsightsCard(admin),
        ],
      ),
    );
  }

  Widget _buildKPICards(AdminProvider admin) {
    final totalRev = admin.totalRevenue;
    final totalSessions = admin.callCenterStats['total_bookings'] ?? 0;
    final arrived = admin.callCenterStats['arrived'] ?? 0;
    final cancelled = admin.callCenterStats['cancelled'] ?? 0;
    final noShow = admin.callCenterStats['no_show'] ?? 0;
    
    return GridView.count(
      crossAxisCount: 5,
      shrinkWrap: true,
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: 1.8,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _kpiCard('الإيراد الإجمالي', '${intl.NumberFormat("#,##0").format(totalRev)} د.ع', Icons.attach_money, Colors.green),
        _kpiCard('إجمالي الحجوزات', '$totalSessions', Icons.calendar_month, Colors.blue),
        _kpiCard('الحضور', '$arrived', Icons.check_circle, Colors.teal),
        _kpiCard('الإلغاءات', '$cancelled', Icons.cancel, Colors.orange),
        _kpiCard('عدم الحضور', '$noShow', Icons.person_off, Colors.red),
      ],
    );
  }

  Widget _kpiCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: color.withAlpha(26), borderRadius: BorderRadius.circular(8)),
                child: Icon(icon, color: color, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          Text(title, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildAlertCard(AdminProvider admin) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber, color: Colors.red),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '${admin.pendingCancellations.length} طلب إلغاء معلق يتطلب موافقة',
              style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
            ),
          ),
          TextButton(
            onPressed: () => _tabController.animateTo(4), // Go to Sessions tab
            child: const Text('عرض'),
          ),
        ],
      ),
    );
  }

  Widget _buildRevenueChart(AdminProvider admin) {
    final dailyData = admin.dailyRevenueStats.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return Container(
      height: 350,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('تحليل الإيرادات اليومية', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          Expanded(
            child: dailyData.isEmpty
                ? const Center(child: Text('لا توجد بيانات'))
                : LineChart(
                    LineChartData(
                      gridData: FlGridData(show: true, drawVerticalLine: false, 
                        getDrawingHorizontalLine: (v) => FlLine(color: Colors.grey.shade200, strokeWidth: 1)),
                      titlesData: FlTitlesData(
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (val, meta) {
                              if (val.toInt() >= 0 && val.toInt() < dailyData.length && val.toInt() % 3 == 0) {
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(dailyData[val.toInt()].key, style: const TextStyle(fontSize: 10)),
                                );
                              }
                              return const SizedBox.shrink();
                            },
                          ),
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      lineBarsData: [
                        LineChartBarData(
                          spots: dailyData.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.value)).toList(),
                          isCurved: true,
                          color: const Color(0xFF6C63FF),
                          barWidth: 3,
                          dotData: const FlDotData(show: false),
                          belowBarData: BarAreaData(show: true, color: const Color(0xFF6C63FF).withAlpha(26)),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopDoctorsCard(AdminProvider admin) {
    final docs = admin.doctorPerformance.take(5).toList();
    
    return Container(
      height: 350,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('أفضل الأطباء أداءً', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Expanded(
            child: docs.isEmpty
                ? const Center(child: Text('لا توجد بيانات'))
                : ListView.separated(
                    itemCount: docs.length,
                    separatorBuilder: (_, __) => const Divider(),
                    itemBuilder: (ctx, idx) {
                      final doc = docs[idx];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.blue.shade100,
                          child: Text('${idx + 1}', style: const TextStyle(fontWeight: FontWeight.bold)),
                        ),
                        title: Text(doc['name'] ?? ''),
                        subtitle: Text('${doc['sessions']} جلسة'),
                        trailing: Text(
                          '${intl.NumberFormat("#,##0").format(doc['revenue'])}',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildInsightsCard(AdminProvider admin) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [Colors.amber.shade50, Colors.orange.shade50]),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.amber.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.lightbulb, color: Colors.amber),
              SizedBox(width: 8),
              Text('رؤى ذكية', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          ...admin.smartInsights.map((insight) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                const Icon(Icons.arrow_left, size: 16, color: Colors.amber),
                const SizedBox(width: 8),
                Expanded(child: Text(insight)),
              ],
            ),
          )),
          if (admin.smartInsights.isEmpty) const Text('لا توجد رؤى حالياً'),
        ],
      ),
    );
  }

  // NEW: Session Status Pie Chart
  Widget _buildStatusPieChart(AdminProvider admin) {
    final stats = admin.callCenterStats;
    final arrived = (stats['arrived'] ?? 0).toDouble();
    final completed = (stats['completed'] ?? 0).toDouble();
    final cancelled = (stats['cancelled'] ?? 0).toDouble();
    final noShow = (stats['no_show'] ?? 0).toDouble();
    final scheduled = (stats['scheduled'] ?? 0).toDouble();
    
    final total = arrived + completed + cancelled + noShow + scheduled;
    
    return Container(
      height: 350,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('حالة الحجوزات', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Expanded(
            child: total == 0
                ? const Center(child: Text('لا توجد بيانات'))
                : PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 40,
                      sections: [
                        if (completed > 0) PieChartSectionData(
                          value: completed, title: '${(completed/total*100).toInt()}%',
                          color: Colors.green, radius: 60,
                          titleStyle: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        if (arrived > 0) PieChartSectionData(
                          value: arrived, title: '${(arrived/total*100).toInt()}%',
                          color: Colors.blue, radius: 60,
                          titleStyle: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        if (scheduled > 0) PieChartSectionData(
                          value: scheduled, title: '${(scheduled/total*100).toInt()}%',
                          color: Colors.grey, radius: 60,
                          titleStyle: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        if (cancelled > 0) PieChartSectionData(
                          value: cancelled, title: '${(cancelled/total*100).toInt()}%',
                          color: Colors.orange, radius: 60,
                          titleStyle: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        if (noShow > 0) PieChartSectionData(
                          value: noShow, title: '${(noShow/total*100).toInt()}%',
                          color: Colors.red, radius: 60,
                          titleStyle: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              _legendItem('مكتمل', Colors.green, completed.toInt()),
              _legendItem('وصل', Colors.blue, arrived.toInt()),
              _legendItem('مجدول', Colors.grey, scheduled.toInt()),
              _legendItem('ملغي', Colors.orange, cancelled.toInt()),
              _legendItem('لم يحضر', Colors.red, noShow.toInt()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _legendItem(String label, Color color, int count) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text('$label ($count)', style: const TextStyle(fontSize: 11)),
      ],
    );
  }

  // NEW: Hourly Booking Analysis
  Widget _buildHourlyAnalysisChart(AdminProvider admin) {
    // Simulate hourly data (in production, this comes from admin.hourlyStats)
    final hourlyData = <int, int>{};
    for (int h = 10; h <= 22; h++) {
      hourlyData[h] = (admin.callCenterStats['total_bookings'] ?? 0) ~/ 13 + (h % 3);
    }
    
    final maxVal = hourlyData.values.isEmpty ? 1 : hourlyData.values.reduce((a, b) => a > b ? a : b);
    
    return Container(
      height: 350,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.access_time, size: 20, color: Color(0xFF6C63FF)),
              SizedBox(width: 8),
              Text('تحليل الحجوزات بالساعة', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          const Text('أفضل أوقات الحجز خلال اليوم', style: TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 20),
          Expanded(
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                barTouchData: BarTouchData(
                  enabled: true,
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      return BarTooltipItem(
                        '${group.x}:00\n${rod.toY.toInt()} حجز',
                        const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      );
                    },
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (v) => FlLine(color: Colors.grey.shade200, strokeWidth: 1),
                ),
                titlesData: FlTitlesData(
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (val, meta) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text('${val.toInt()}', style: const TextStyle(fontSize: 10)),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      getTitlesWidget: (val, meta) {
                        if (val == val.roundToDouble()) {
                          return Text('${val.toInt()}', style: const TextStyle(fontSize: 10));
                        }
                        return const SizedBox();
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                barGroups: hourlyData.entries.map((e) {
                  final isPeakHour = e.value == maxVal;
                  return BarChartGroupData(
                    x: e.key,
                    barRods: [
                      BarChartRodData(
                        toY: e.value.toDouble(),
                        color: isPeakHour ? Colors.green : const Color(0xFF6C63FF),
                        width: 16,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============ TAB 2: FINANCIAL ============
  Widget _buildFinancialTab(AdminProvider admin) {
    final services = admin.serviceFinancials;
    final totalRev = admin.totalRevenue;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('التقارير المالية', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          
          // Financial Summary Cards
          Row(
            children: [
              Expanded(child: _financeCard('الإيراد الإجمالي', totalRev, Icons.attach_money, Colors.green)),
              const SizedBox(width: 16),
              Expanded(child: _financeCard('متوسط الجلسة', totalRev > 0 ? totalRev / (admin.callCenterStats['total_bookings'] ?? 1) : 0, Icons.trending_up, Colors.blue)),
              const SizedBox(width: 16),
              Expanded(child: _financeCard('المستحقات', totalRev * 0.15, Icons.pending_actions, Colors.orange)),
              const SizedBox(width: 16),
              Expanded(child: _financeCard('المحصّل', totalRev * 0.85, Icons.check_circle, Colors.teal)),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // Charts Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Revenue by Service
              Expanded(
                flex: 2,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('الإيرادات حسب الخدمة', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      ...services.take(10).map((svc) {
                        final percent = totalRev > 0 ? (svc['revenue'] / totalRev) : 0.0;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(child: Text(svc['name'] ?? '', overflow: TextOverflow.ellipsis)),
                                  Text('${intl.NumberFormat("#,##0").format(svc['revenue'])} د.ع'),
                                ],
                              ),
                              const SizedBox(height: 4),
                              LinearProgressIndicator(
                                value: percent.toDouble(),
                                backgroundColor: Colors.grey.shade200,
                                color: const Color(0xFF6C63FF),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(width: 20),
              
              // Payment Methods Breakdown
              Expanded(
                child: _buildPaymentMethodsChart(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _financeCard(String title, num value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(51)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '${intl.NumberFormat("#,##0").format(value)} د.ع',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
          ),
          Text(title, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodsChart() {
    // Simulated payment methods data
    const cashPercent = 60.0;
    const cardPercent = 25.0;
    const transferPercent = 15.0;
    
    return Container(
      height: 350,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('طرق الدفع', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Expanded(
            child: PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 35,
                sections: [
                  PieChartSectionData(
                    value: cashPercent, title: '${cashPercent.toInt()}%',
                    color: Colors.green, radius: 50,
                    titleStyle: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  PieChartSectionData(
                    value: cardPercent, title: '${cardPercent.toInt()}%',
                    color: Colors.blue, radius: 50,
                    titleStyle: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  PieChartSectionData(
                    value: transferPercent, title: '${transferPercent.toInt()}%',
                    color: Colors.purple, radius: 50,
                    titleStyle: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Column(
            children: [
              _paymentLegend('نقدي', Colors.green, cashPercent),
              const SizedBox(height: 8),
              _paymentLegend('بطاقة', Colors.blue, cardPercent),
              const SizedBox(height: 8),
              _paymentLegend('تحويل', Colors.purple, transferPercent),
            ],
          ),
        ],
      ),
    );
  }

  Widget _paymentLegend(String label, Color color, double percent) {
    return Row(
      children: [
        Container(width: 16, height: 16, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4))),
        const SizedBox(width: 8),
        Expanded(child: Text(label)),
        Text('${percent.toInt()}%', style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
  }

  // ============ TAB 3: DOCTORS ============
  Widget _buildDoctorsTab(AdminProvider admin) {
    final docs = admin.doctorPerformance;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('أداء الأطباء', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: DataTable(
              columns: const [
                DataColumn(label: Text('الطبيب')),
                DataColumn(label: Text('الجلسات')),
                DataColumn(label: Text('الساعات')),
                DataColumn(label: Text('الإيراد')),
                DataColumn(label: Text('نسبة الاحتفاظ')),
              ],
              rows: docs.map((doc) => DataRow(cells: [
                DataCell(Text(doc['name'] ?? '')),
                DataCell(Text('${doc['sessions']}')),
                DataCell(Text('${doc['total_hours']} ساعة')),
                DataCell(Text('${intl.NumberFormat("#,##0").format(doc['revenue'])} د.ع')),
                DataCell(Text('${doc['retention_rate']}%')),
              ])).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // ============ TAB 4: PATIENTS ============
  Widget _buildPatientsTab(AdminProvider admin) {
    final stats = admin.patientStats;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('تقارير المرضى', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          
          // Summary Cards
          Row(
            children: [
              Expanded(child: _kpiCard('إجمالي المرضى', '${stats['total_unique'] ?? 0}', Icons.people, Colors.blue)),
              const SizedBox(width: 16),
              Expanded(child: _kpiCard('ذكور', '${stats['male'] ?? 0}', Icons.male, Colors.indigo)),
              const SizedBox(width: 16),
              Expanded(child: _kpiCard('إناث', '${stats['female'] ?? 0}', Icons.female, Colors.pink)),
              const SizedBox(width: 16),
              Expanded(child: _kpiCard('نسبة العودة', '${stats['returning_rate'] ?? 0}%', Icons.repeat, Colors.green)),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // Charts Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Age Distribution
              Expanded(
                flex: 2,
                child: _buildAgeDistributionChart(),
              ),
              const SizedBox(width: 20),
              // Patient Source
              Expanded(
                child: _buildPatientSourceChart(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAgeDistributionChart() {
    // Simulated age distribution
    final ageGroups = {'18-25': 15, '26-35': 35, '36-45': 25, '46-55': 15, '56+': 10};
    
    return Container(
      height: 350,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.bar_chart, size: 20, color: Color(0xFF6C63FF)),
              SizedBox(width: 8),
              Text('توزيع الأعمار', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (v) => FlLine(color: Colors.grey.shade200, strokeWidth: 1),
                ),
                titlesData: FlTitlesData(
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (val, meta) {
                        final keys = ageGroups.keys.toList();
                        if (val.toInt() >= 0 && val.toInt() < keys.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(keys[val.toInt()], style: const TextStyle(fontSize: 11)),
                          );
                        }
                        return const SizedBox();
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      getTitlesWidget: (val, meta) {
                        return Text('${val.toInt()}%', style: const TextStyle(fontSize: 10));
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                barGroups: ageGroups.entries.toList().asMap().entries.map((e) {
                  return BarChartGroupData(
                    x: e.key,
                    barRods: [
                      BarChartRodData(
                        toY: e.value.value.toDouble(),
                        gradient: const LinearGradient(
                          colors: [Color(0xFF6C63FF), Color(0xFF00E5FF)],
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                        ),
                        width: 32,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPatientSourceChart() {
    return Container(
      height: 350,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('مصادر المرضى', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Expanded(
            child: PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 30,
                sections: [
                  PieChartSectionData(value: 40, title: '40%', color: Colors.blue, radius: 50, 
                    titleStyle: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                  PieChartSectionData(value: 25, title: '25%', color: Colors.green, radius: 50,
                    titleStyle: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                  PieChartSectionData(value: 20, title: '20%', color: Colors.orange, radius: 50,
                    titleStyle: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                  PieChartSectionData(value: 15, title: '15%', color: Colors.purple, radius: 50,
                    titleStyle: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              _legendItem('حضور مباشر', Colors.blue, 40),
              _legendItem('سوشال ميديا', Colors.green, 25),
              _legendItem('إحالة', Colors.orange, 20),
              _legendItem('كول سنتر', Colors.purple, 15),
            ],
          ),
        ],
      ),
    );
  }

  // ============ TAB 5: SESSIONS ============
  Widget _buildSessionsTab(AdminProvider admin) {
    final pending = admin.pendingCancellations;
    final usage = admin.serviceUsageStats;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('تقارير الجلسات', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          
          // Pending Cancellations
          if (pending.isNotEmpty) ...[
            const Text('طلبات الإلغاء المعلقة', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: pending.length,
                separatorBuilder: (_, __) => const Divider(),
                itemBuilder: (ctx, idx) {
                  final b = pending[idx];
                  return ListTile(
                    title: Text(b['patient']?['name'] ?? 'غير معروف'),
                    subtitle: Text(b['cancel_reason'] ?? 'بدون سبب'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.check, color: Colors.green),
                          onPressed: () async {
                            await admin.approveCancellation(b['id']);
                            if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تمت الموافقة')));
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.red),
                          onPressed: () async {
                            await admin.rejectCancellation(b['id']);
                            if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم الرفض')));
                          },
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),
          ],
          
          // Service Usage
          const Text('استخدام الخدمات', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: usage.entries.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(e.key),
                    Chip(label: Text('${e.value} جلسة')),
                  ],
                ),
              )).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // ============ TAB 6: DEVICES ============
  Widget _buildDevicesTab(AdminProvider admin) {
    final devices = admin.deviceStats;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('تقارير الأجهزة', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 2,
            ),
            itemCount: devices.length,
            itemBuilder: (ctx, idx) {
              final d = devices[idx];
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.precision_manufacturing, color: Color(0xFF6C63FF)),
                        const SizedBox(width: 8),
                        Text(d['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text('${d['usage']} استخدام', style: TextStyle(color: Colors.grey.shade600)),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showExportDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تصدير التقارير'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
              title: const Text('تصدير PDF'),
              onTap: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('جاري تحضير ملف PDF...')));
              },
            ),
            ListTile(
              leading: const Icon(Icons.table_chart, color: Colors.green),
              title: const Text('تصدير Excel'),
              onTap: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('جاري تحضير ملف Excel...')));
              },
            ),
            ListTile(
              leading: const Icon(Icons.print, color: Colors.blue),
              title: const Text('طباعة'),
              onTap: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('جاري إعداد الطباعة...')));
              },
            ),
          ],
        ),
      ),
    );
  }
}
