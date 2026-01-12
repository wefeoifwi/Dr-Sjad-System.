import 'package:flutter/material.dart';
import '../../core/theme.dart';

// Placeholder Screens for the 9 Modules
import 'admin_dashboard_overview.dart'; 
import 'staff_management.dart';
import '../patients/patients_screen.dart';
import 'assets_management.dart'; // Assets Screen
import 'booking_management.dart'; // Booking Screen
import '../follow_up/follow_up_screen.dart'; // Follow-up Screen
import 'finance_management.dart'; // Finance Screen
import 'reports_hub.dart'; // Reports Screen
// We will create these placeholders progressively
class PlaceholderScreen extends StatelessWidget {
  final String title;
  const PlaceholderScreen(this.title, {super.key});
  @override
  Widget build(BuildContext context) => Center(child: Text(title, style: const TextStyle(fontSize: 24, color: Colors.white54)));
}

class AdminLayoutShell extends StatefulWidget {
  const AdminLayoutShell({super.key});

  @override
  State<AdminLayoutShell> createState() => _AdminLayoutShellState();
}

class _AdminLayoutShellState extends State<AdminLayoutShell> {
  int _selectedIndex = 0;
  bool _isSidebarExpanded = true; // Sidebar state

  final List<Widget> _screens = [
    const AdminDashboardOverview(), // 1. Dashboard
    const StaffManagementScreen(), // 2. Staff Management
    const PatientsScreen(), // 3. Patient Management
    const AssetsManagementScreen(), // 3. Assets Management (Devices & Depts)
    const BookingManagementScreen(), // 4. Booking Management
    const FinanceManagementScreen(), // 6. Finance Management
    const FollowUpScreen(), // 6. Follow-up Center (Reused)
    const ReportsScreen(), // 8. Reports Hub
    const PlaceholderScreen('General Settings'), // 9
  ];

  @override
  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 900;

    if (isDesktop) {
      // Desktop Layout: Sidebar + Content
      return Scaffold(
        backgroundColor: AppTheme.background,
        body: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Collapsible Sidebar
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: _isSidebarExpanded ? 240 : 70,
              color: AppTheme.surface,
              child: Column(
                children: [
                  // Sidebar Header
                  Container(
                    height: 80,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withAlpha(26),
                      border: Border(bottom: BorderSide(color: Colors.white.withAlpha(26))),
                    ),
                    child: ListTile(
                      contentPadding: EdgeInsets.symmetric(horizontal: _isSidebarExpanded ? 16 : 8),
                      leading: IconButton(
                         icon: Icon(_isSidebarExpanded ? Icons.menu_open : Icons.menu, color: Colors.white),
                         onPressed: () => setState(() => _isSidebarExpanded = !_isSidebarExpanded),
                      ),
                      title: _isSidebarExpanded 
                        ? const Text('Admin Panel', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))
                        : null,
                    ),
                  ),
                  _buildNavigationList(isSidebarCollapsed: !_isSidebarExpanded),
                ],
              ),
            ),
            const VerticalDivider(width: 1, color: Colors.white10),
            // Main Content
            Expanded(child: _screens[_selectedIndex]),
          ],
        ),
      );
    } else {
      // Mobile Layout: AppBar + Drawer
      return Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          backgroundColor: AppTheme.surface,
          title: const Text('لوحة التحكم', style: TextStyle(fontSize: 18)),
          centerTitle: true,
        ),
        drawer: Drawer(
          backgroundColor: AppTheme.surface,
          child: Column(
            children: [
              UserAccountsDrawerHeader(
                decoration: const BoxDecoration(color: AppTheme.primary),
                accountName: const Text('Admin Panel'),
                accountEmail: const Text('Manager Access'),
                currentAccountPicture: const CircleAvatar(backgroundColor: Colors.white, child: Icon(Icons.admin_panel_settings, color: AppTheme.primary)),
              ),
              _buildNavigationList(isMobile: true),
            ],
          ),
        ),
        body: _screens[_selectedIndex],
      );
    }
  }

  Widget _buildNavigationList({bool isSidebarCollapsed = false, bool isMobile = false}) {
    return Expanded(
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          _buildNavItem(0, 'الرئيسية', Icons.dashboard, isCollapsed: isSidebarCollapsed, isMobile: isMobile),
          _buildNavItem(1, 'الموظفين', Icons.people_alt, isCollapsed: isSidebarCollapsed, isMobile: isMobile),
          _buildNavItem(2, 'المرضى', Icons.accessibility_new, isCollapsed: isSidebarCollapsed, isMobile: isMobile),
          _buildNavItem(3, 'الأصول/الأجهزة', Icons.devices_other, isCollapsed: isSidebarCollapsed, isMobile: isMobile),
          _buildNavItem(4, 'الحجوزات', Icons.calendar_month, isCollapsed: isSidebarCollapsed, isMobile: isMobile),
          _buildNavItem(5, 'المالية', Icons.attach_money, isCollapsed: isSidebarCollapsed, isMobile: isMobile),
          _buildNavItem(6, 'المتابعة', Icons.checklist_rtl, isCollapsed: isSidebarCollapsed, isMobile: isMobile),
          _buildNavItem(7, 'التقارير', Icons.bar_chart, isCollapsed: isSidebarCollapsed, isMobile: isMobile),
          _buildNavItem(8, 'الإعدادات', Icons.settings, isCollapsed: isSidebarCollapsed, isMobile: isMobile),
          const Divider(color: Colors.white10),
          _buildNavItem(-1, 'خروج', Icons.logout, isCollapsed: isSidebarCollapsed, isMobile: isMobile, isLogout: true),
        ],
      ),
    );
  }

  Widget _buildNavItem(int index, String title, IconData icon, {
    bool isCollapsed = false, 
    bool isMobile = false,
    bool isLogout = false
  }) {
    final isSelected = _selectedIndex == index;
    return InkWell(
      onTap: () {
        if (isLogout) {
           Navigator.of(context).pushReplacementNamed('/login');
        } else {
           setState(() => _selectedIndex = index);
           if (isMobile) Navigator.pop(context); // Close drawer
        }
      },
      child: Container(
        height: 50,
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary.withAlpha(51) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: isCollapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
          children: [
             Icon(icon, color: isLogout ? Colors.redAccent : (isSelected ? AppTheme.primary : Colors.white54), size: 22),
             if (!isCollapsed) ...[
               const SizedBox(width: 12),
               Expanded(
                 child: Text(title, style: TextStyle(
                   color: isLogout ? Colors.redAccent : (isSelected ? Colors.white : Colors.white70),
                   fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                   fontSize: 14,
                 )),
               ),
             ]
          ],
        ),
      ),
    );
  }
}
