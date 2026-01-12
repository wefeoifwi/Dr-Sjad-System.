import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../schedule/schedule_provider.dart';
import '../schedule/timeline_view.dart';
import '../patients/patients_screen.dart';
import '../settings/settings_screen.dart';
import '../doctor/doctor_dashboard.dart';
import '../follow_up/follow_up_screen.dart';
import '../reception/reception_dashboard.dart';
import '../admin/admin_layout_shell.dart';
import '../admin/admin_provider.dart';
import 'layout_shell.dart';

class DashboardScreen extends StatefulWidget {
  final String userRole;
  const DashboardScreen({super.key, required this.userRole});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    if (widget.userRole == 'admin') {
      return MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ScheduleProvider()),
          ChangeNotifierProvider(create: (_) => AdminProvider()),
        ],
        child: const AdminLayoutShell(),
      );
    }

    return ChangeNotifierProvider(
      create: (_) => ScheduleProvider(),
      child: LayoutShell(
        selectedIndex: _selectedIndex,
        onIndexChanged: (index) => setState(() => _selectedIndex = index),
        destinations: _getDestinations(),
        child: _buildBody(),
      ),
    );
  }

  List<NavigationDestination> _getDestinations() {
    final role = widget.userRole;

    if (role == 'admin') {
       return []; // Admin has its own Shell
    }
    
    if (role == 'reception') {
      return const [
        NavigationDestination(
          icon: Icon(Icons.table_chart_outlined),
          selectedIcon: Icon(Icons.table_chart),
          label: 'الاستقبال (اليوم)',
        ),
        NavigationDestination(
          icon: Icon(Icons.settings_outlined),
          selectedIcon: Icon(Icons.settings),
          label: 'الإعدادات',
        ),
      ];
    } else if (role == 'doctor') {
      return const [
        NavigationDestination(
          icon: Icon(Icons.dashboard_outlined),
          selectedIcon: Icon(Icons.dashboard),
          label: 'الرئيسية',
        ),
         NavigationDestination(
          icon: Icon(Icons.calendar_month_outlined),
          selectedIcon: Icon(Icons.calendar_month),
          label: 'قائمة الانتظار', 
        ),
         NavigationDestination(
          icon: Icon(Icons.people_outline),
          selectedIcon: Icon(Icons.people),
          label: 'المرضى',
        ),
        NavigationDestination(
          icon: Icon(Icons.settings_outlined),
          selectedIcon: Icon(Icons.settings),
          label: 'الإعدادات',
        ),
      ];
    } else {
      // Default: Call Center
      return const [
         NavigationDestination(
          icon: Icon(Icons.calendar_month_outlined),
          selectedIcon: Icon(Icons.calendar_month),
          label: 'الجدول (الرئيسية)', 
        ),
         NavigationDestination(
          icon: Icon(Icons.people_outline),
          selectedIcon: Icon(Icons.people),
          label: 'سجل المرضى (CRM)',
        ),
         NavigationDestination(
          icon: Icon(Icons.repeat),
          selectedIcon: Icon(Icons.repeat_on),
          label: 'متابعة المواعيد',
        ),
        NavigationDestination(
          icon: Icon(Icons.settings_outlined),
          selectedIcon: Icon(Icons.settings),
          label: 'الإعدادات',
        ),
      ];
    }
  }

  Widget _buildBody() {
    final role = widget.userRole;

    if (role == 'admin') {
      return const AdminLayoutShell(); // 9-Module Admin Panel
    } else if (role == 'reception') {
      // RECEPTION MENU: [0: ReceptionDashboard, 1: Settings]
      switch (_selectedIndex) {
        case 0: return const ReceptionDashboard();
        case 1: return const SettingsScreen();
        default: return const Center(child: Text("غير موجود"));
      }
    } else if (role == 'doctor') {
      // DOCTOR MENU: [0:Home, 1:Queue, 2:Patients, 3:Settings]
      switch (_selectedIndex) {
        case 0: return Center(child: Text("الرئيسية - ${widget.userRole}"));
        case 1: return const DoctorDashboard();
        case 2: return const PatientsScreen();
        case 3: return const SettingsScreen();
        default: return const Center(child: Text("غير موجود"));
      }
    } else {
      // CALL CENTER MENU: [0:Timeline, 1:Patients, 2:FollowUp, 3:Settings]
      switch (_selectedIndex) {
        case 0: return const TimelineView();
        case 1: return const PatientsScreen();
        case 2: return const FollowUpScreen();
        case 3: return const SettingsScreen();
        default: return const Center(child: Text("غير موجود"));
      }
    }
  }
}
