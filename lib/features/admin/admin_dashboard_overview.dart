import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/theme.dart';
import '../schedule/timeline_view.dart';

class AdminDashboardOverview extends StatelessWidget {
  const AdminDashboardOverview({super.key});

  @override
  Widget build(BuildContext context) {
    // Responsive helper
    final isDesktop = MediaQuery.of(context).size.width > 1100;

    // Use a direct container (or specific background widget) instead of nested Scaffold
    return Container(
      color: AppTheme.background,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Expanded( // Fix Overflow
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text('لوحة التحكم', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white)),
                      SizedBox(height: 8),
                      Text('ملخص أداء المركز اليومي', style: TextStyle(color: Colors.white54, fontSize: 14)),
                    ],
                  ),
                ),
                // Date Chip
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(13),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 16, color: AppTheme.primary),
                      const SizedBox(width: 8),
                      Text(
                        DateTime.now().toString().split(' ')[0], 
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // 1. KPI Cards Row
            SizedBox(
              height: 150,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: const [
                  _KDICard(
                    title: 'إيرادات اليوم', 
                    value: '2.5M د.ع', 
                    trend: '+12%', 
                    icon: Icons.monetization_on, 
                    color1: Color(0xFF00B09B), 
                    color2: Color(0xFF96C93D),
                  ),
                  SizedBox(width: 16),
                  _KDICard(
                    title: 'عدد الجلسات', 
                    value: '45', 
                    trend: '+5', 
                    icon: Icons.calendar_month, 
                    color1: Color(0xFF4CA1AF), 
                    color2: Color(0xFF2C3E50),
                  ),
                  SizedBox(width: 16),
                  _KDICard(
                    title: 'المرضى الجدد', 
                    value: '12', 
                    trend: '+2', 
                    icon: Icons.person_add, 
                    color1: Color(0xFFFF5F6D), 
                    color2: Color(0xFFFFC371),
                  ),
                  SizedBox(width: 16),
                  _KDICard(
                    title: 'أفضل طبيب', 
                    value: 'د. سجاد', 
                    subValue: '18 جلسة', 
                    icon: Icons.star, 
                    color1: Color(0xFF8E2DE2), 
                    color2: Color(0xFF4A00E0),
                  ),
                  SizedBox(width: 16),
                  _KDICard(
                    title: 'أكثر جهاز', 
                    value: 'Candela', 
                    subValue: '90% إشغال', 
                    icon: Icons.flash_on, 
                    color1: Color(0xFFDD5E89), 
                    color2: Color(0xFFF7BB97),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // 2. Charts & Timeline
            if (isDesktop)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 1, child: _RevenueChartSection()),
                  const SizedBox(width: 24),
                  // Check Timeline Live View
                  Expanded(
                    flex: 2, 
                    child: Container(
                      height: 500, // Fixed height for timeline
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: const TimelineView(userRole: 'admin'),
                      ),
                    ),
                  ),
                ],
              )
            else
              Column(
                children: [
                   Container(
                      height: 500,
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: const TimelineView(userRole: 'admin'),
                      ),
                    ),
                  const SizedBox(height: 24),
                  _RevenueChartSection(),
                ],
              ),
          ],
        ),
      ),
    );
  }
} // End of AdminDashboardOverview
class _KDICard extends StatelessWidget {
  final String title;
  final String value;
  final String? trend;
  final String? subValue;
  final IconData icon;
  final Color color1;
  final Color color2;

  const _KDICard({
    required this.title, 
    required this.value, 
    required this.icon, 
    required this.color1,
    required this.color2,
    this.trend,
    this.subValue,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [color1.withAlpha(204), color2.withAlpha(204)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(color: color1.withAlpha(51), blurRadius: 6, offset: const Offset(0, 3)),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.antiAlias, // Optimize rendering
        children: [
          // Background Icon
          Positioned(
            right: -20,
            top: -20,
            child: Icon(icon, size: 100, color: Colors.white.withAlpha(26)),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(icon, color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    Text(title, style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
                  ],
                ),
                const Spacer(),
                Text(value, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
                if (subValue != null)
                  Text(subValue!, style: const TextStyle(fontSize: 12, color: Colors.white70))
                else if (trend != null)
                   Container(
                     padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                     decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(8)),
                     child: Text(trend!, style: const TextStyle(fontSize: 12, color: Colors.white)),
                   ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RevenueChartSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 400,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [ // Removed const from Row if children are not all const, but here they seem const-compatible or I'll remove const from Row parent if needed
               Expanded(
                 child: Text(
                   'إحصائيات الإيرادات (الأسبوعية)', 
                   style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
                   overflow: TextOverflow.ellipsis,
                 ),
               ),
              Icon(Icons.bar_chart, color: AppTheme.primary),
            ],
          ),
          const SizedBox(height: 32),
          Expanded(
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: 20,
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (group) => Colors.grey,
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        const style = TextStyle(color: Colors.white38, fontWeight: FontWeight.bold, fontSize: 10);
                        String text;
                        switch (value.toInt()) {
                          case 0: text = 'السبت'; break;
                          case 1: text = 'الأحد'; break;
                          case 2: text = 'الاثنين'; break;
                          case 3: text = 'الثلاثاء'; break;
                          case 4: text = 'الأربعاء'; break;
                          case 5: text = 'الخميس'; break;
                          case 6: text = 'الجمعة'; break;
                          default: text = '';
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(text, style: style),
                        );
                      },
                    ),
                  ),
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                barGroups: [
                  _makeBarGroup(0, 5, 12, const Color(0xff53fdd7)),
                  _makeBarGroup(1, 10, 8, const Color(0xffff5182)),
                  _makeBarGroup(2, 14, 15, const Color(0xffffff51)),
                  _makeBarGroup(3, 15, 5, const Color(0xff53fdd7)),
                  _makeBarGroup(4, 13, 10, const Color(0xffff5182)),
                  _makeBarGroup(5, 10, 10, const Color(0xffffff51)),
                  _makeBarGroup(6, 16, 18, const Color(0xff53fdd7)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  BarChartGroupData _makeBarGroup(int x, double y1, double y2, Color color) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: y1,
          color: color,
          width: 12,
          borderRadius: BorderRadius.circular(4),
        ),
        BarChartRodData(
          toY: y2,
          color: color.withAlpha(128),
          width: 12,
          borderRadius: BorderRadius.circular(4),
        ),
      ],
    );
  }
}
