import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../ai/ai_chat_bubble.dart';
import 'package:provider/provider.dart';
import '../notifications/notifications_provider.dart';
import '../notifications/notification_badge.dart';

// Placeholder Screens for the 9 Modules
import 'admin_dashboard_overview.dart'; 
import 'staff_management.dart';
import '../patients/patients_screen.dart';
import 'assets_management.dart'; // Assets Screen
import 'booking_management.dart'; // Booking Screen
import '../follow_up/follow_up_screen.dart'; // Follow-up Screen
import 'finance_management.dart'; // Finance Screen
import 'reports_hub.dart'; // Reports Screen
import '../settings/settings_screen.dart'; // Settings Screen
import 'data_import_screen.dart'; // Data Import Screen
import 'dynamic_fields_management.dart'; // Dynamic Fields Management
import 'employee_stats_screen.dart'; // Employee Stats Screen
import 'message_templates_screen.dart'; // Message Templates Screen
import 'admin_activity_dashboard.dart'; // Activity Dashboard
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
    const AdminDashboardOverview(), // 0. Dashboard
    const AdminActivityDashboard(), // 1. Activity Dashboard (NEW)
    const StaffManagementScreen(), // 2. Staff Management
    const PatientsScreen(userRole: 'admin'), // 3. Patient Management
    const AssetsManagementScreen(), // 4. Assets Management
    const BookingManagementScreen(), // 5. Booking Management
    const FinanceManagementScreen(), // 6. Finance Management
    const FollowUpScreen(userRole: 'admin'), // 7. Follow-up Center
    const ReportsScreen(), // 8. Reports Hub
    const EmployeeStatsScreen(), // 9. Employee Stats
    const MessageTemplatesScreen(), // 10. Message Templates
    const DataImportScreen(), // 11. Data Import
    const DynamicFieldsManagementScreen(), // 12. Dynamic Fields
    const SettingsScreen(), // 13. Settings
  ];
  
  @override
  void initState() {
    super.initState();
    // Listen to Notification Navigation Events
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final notifProvider = context.read<NotificationsProvider>();
      notifProvider.navigationStream.listen((route) {
        if (mounted) {
           _handleExternalNavigation(route);
        }
      });
    });
  }

  void _handleExternalNavigation(String route) {
    int targetIndex = -1;
    
    switch (route) {
      case 'cancellation_requests':
        targetIndex = 4; // Booking Management (where cancellation usually resides)
        break;
      case 'follow_up':
        targetIndex = 6; // Follow-up Center
        break;
    }

    if (targetIndex != -1) {
      setState(() => _selectedIndex = targetIndex);
    }
  }

  @override
  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 900;

    if (isDesktop) {
      // Desktop Layout: Sidebar + Content + AI Bubble
      return Scaffold(
        backgroundColor: AppTheme.background,
        body: Stack(
          children: [
            Row(
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
                        child: _isSidebarExpanded
                          ? Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.menu_open, color: Colors.white),
                                  onPressed: () => setState(() => _isSidebarExpanded = !_isSidebarExpanded),
                                ),
                                const Text('Admin Panel', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                const Spacer(),
                                const NotificationBadge(),
                                const SizedBox(width: 8),
                              ],
                            )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.menu, color: Colors.white),
                                  onPressed: () => setState(() => _isSidebarExpanded = !_isSidebarExpanded),
                                ),
                                const SizedBox(height: 8),
                                const NotificationBadge(),
                              ],
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
            // AI Chat Bubble
            const AIChatBubble(),
          ],
        ),
      );
    } else {
      // Mobile Layout: AppBar + Drawer + AI Bubble
      return Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          backgroundColor: AppTheme.surface,
          title: const Text('لوحة التحكم', style: TextStyle(fontSize: 18)),
          centerTitle: true,
          actions: const [
            NotificationBadge(),
            SizedBox(width: 8),
          ],
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
        body: Stack(
          children: [
            _screens[_selectedIndex],
            // AI Chat Bubble
            const AIChatBubble(),
          ],
        ),
      );
    }
  }

  Widget _buildNavigationList({bool isSidebarCollapsed = false, bool isMobile = false}) {
    return Expanded(
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          _buildNavItem(0, 'الرئيسية', Icons.dashboard, isCollapsed: isSidebarCollapsed, isMobile: isMobile),
          _buildNavItem(1, 'لوحة المتابعة', Icons.track_changes, isCollapsed: isSidebarCollapsed, isMobile: isMobile),
          _buildNavItem(2, 'الموظفين', Icons.people_alt, isCollapsed: isSidebarCollapsed, isMobile: isMobile),
          _buildNavItem(3, 'المرضى', Icons.accessibility_new, isCollapsed: isSidebarCollapsed, isMobile: isMobile),
          _buildNavItem(4, 'الأصول/الأجهزة', Icons.devices_other, isCollapsed: isSidebarCollapsed, isMobile: isMobile),
          _buildNavItem(5, 'الحجوزات', Icons.calendar_month, isCollapsed: isSidebarCollapsed, isMobile: isMobile),
          _buildNavItem(6, 'المالية', Icons.attach_money, isCollapsed: isSidebarCollapsed, isMobile: isMobile),
          _buildNavItem(7, 'المتابعة', Icons.checklist_rtl, isCollapsed: isSidebarCollapsed, isMobile: isMobile),
          _buildNavItem(8, 'التقارير', Icons.bar_chart, isCollapsed: isSidebarCollapsed, isMobile: isMobile),
          _buildNavItem(9, 'إحصائيات الموظفين', Icons.analytics, isCollapsed: isSidebarCollapsed, isMobile: isMobile),
          _buildNavItem(10, 'قوالب الرسائل', Icons.message, isCollapsed: isSidebarCollapsed, isMobile: isMobile),
          _buildNavItem(11, 'استيراد بيانات', Icons.upload_file, isCollapsed: isSidebarCollapsed, isMobile: isMobile),
          _buildNavItem(12, 'الحقول الديناميكية', Icons.dynamic_form, isCollapsed: isSidebarCollapsed, isMobile: isMobile),
          _buildNavItem(13, 'الإعدادات', Icons.settings, isCollapsed: isSidebarCollapsed, isMobile: isMobile),
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
