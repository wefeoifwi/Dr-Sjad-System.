import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../core/responsive_layout.dart';
import '../schedule/schedule_provider.dart'; 
import '../schedule/models.dart';
import 'doctor_sidebar.dart';
import 'patient_medical_view.dart';
import '../notifications/notification_badge.dart';

class DoctorDashboard extends StatefulWidget {
  const DoctorDashboard({super.key});

  @override
  State<DoctorDashboard> createState() => _DoctorDashboardState();
}

class _DoctorDashboardState extends State<DoctorDashboard> {
  Booking? _selectedPatient;
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  
  // Timer للتحقق من تغيير البيانات
  Timer? _refreshTimer;
  int _lastBookingCount = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ScheduleProvider>().loadData();
    });
    
    // Timer يتحقق كل ثانية من تغيير عدد الحجوزات
    _refreshTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        final provider = context.read<ScheduleProvider>();
        if (provider.bookings.length != _lastBookingCount) {
          debugPrint('🔄 Doctor Force rebuild: $_lastBookingCount → ${provider.bookings.length}');
          _lastBookingCount = provider.bookings.length;
          setState(() {});
        }
      }
    });
  }
  
  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // مهم: استخدام watch لإعادة بناء الشاشة عند تغيير البيانات
    final _ = context.watch<ScheduleProvider>();
    
    final isMobile = ResponsiveLayout.isMobile(context);
    
    if (isMobile) {
      return _buildMobileLayout();
    } else {
      return _buildDesktopLayout();
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // MOBILE LAYOUT - Drawer + Main Content
  // ═══════════════════════════════════════════════════════════════════════════
  
  Widget _buildMobileLayout() {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        title: _selectedPatient == null 
          ? const Text('لوحة الطبيب')
          : Text(_selectedPatient!.patientName, style: const TextStyle(fontSize: 16)),
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        actions: [
          const NotificationBadge(),
          if (_selectedPatient != null)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => setState(() => _selectedPatient = null),
              tooltip: 'إغلاق الملف',
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => context.read<ScheduleProvider>().loadData(),
            tooltip: 'تحديث',
          ),
        ],
      ),
      drawer: Drawer(
        backgroundColor: AppTheme.surface,
        child: SafeArea(
          child: DoctorSidebar(
            selectedBookingId: _selectedPatient?.id,
            onPatientSelected: (booking) {
              setState(() => _selectedPatient = booking);
              Navigator.pop(context); // إغلاق الـ Drawer
            },
          ),
        ),
      ),
      body: _selectedPatient == null 
        ? _buildEmptyState(true)
        : PatientMedicalView(booking: _selectedPatient!),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // DESKTOP LAYOUT - Side by Side
  // ═══════════════════════════════════════════════════════════════════════════
  
  Widget _buildDesktopLayout() {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Row(
        children: [
          // Sidebar
          DoctorSidebar(
            selectedBookingId: _selectedPatient?.id,
            onPatientSelected: (booking) {
              setState(() => _selectedPatient = booking);
            },
          ),
          const VerticalDivider(width: 1, color: Colors.white10),

          // Main Content
          Expanded(
            child: Column(
              children: [
                // Top Bar
                Container(
                  height: 50,
                  color: AppTheme.surface,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      if (_selectedPatient != null) ...[
                        const Icon(Icons.person, color: AppTheme.primary),
                        const SizedBox(width: 8),
                        Text(_selectedPatient!.patientName, style: const TextStyle(fontWeight: FontWeight.bold)),
                      ] else
                        const Text('قائمة الانتظار', style: TextStyle(fontWeight: FontWeight.bold)),
                      const Spacer(),
                      const NotificationBadge(),
                      IconButton(
                        icon: const Icon(Icons.refresh),
                        onPressed: () => context.read<ScheduleProvider>().loadData(),
                        tooltip: 'تحديث',
                      ),
                    ],
                  ),
                ),
                
                Expanded(
                  child: _selectedPatient == null 
                    ? _buildEmptyState(false)
                    : PatientMedicalView(booking: _selectedPatient!),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isMobile) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.medical_information, size: isMobile ? 48 : 64, color: Colors.white10),
          const SizedBox(height: 16),
          Text(
            isMobile ? 'افتح القائمة واختر مريضاً' : 'اختر مريضاً من القائمة',
            style: const TextStyle(color: Colors.white38),
          ),
          if (isMobile) ...[
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => _scaffoldKey.currentState?.openDrawer(),
              icon: const Icon(Icons.menu),
              label: const Text('عرض قائمة المرضى'),
            ),
          ],
        ],
      ),
    );
  }
}
