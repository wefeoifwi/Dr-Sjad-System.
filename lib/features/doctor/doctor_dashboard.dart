import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../schedule/schedule_provider.dart'; 
import '../schedule/models.dart';
import 'doctor_sidebar.dart';
import 'patient_medical_view.dart';

class DoctorDashboard extends StatefulWidget {
  const DoctorDashboard({super.key});

  @override
  State<DoctorDashboard> createState() => _DoctorDashboardState();
}

class _DoctorDashboardState extends State<DoctorDashboard> {
  Booking? _selectedPatient;
  bool _isSidebarVisible = true;

  @override
  void initState() {
    super.initState();
    // Load patient queue
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ScheduleProvider>().loadData();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Row(
        children: [
          // 1. Sidebar (Collapsible)
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: _isSidebarVisible ? 300 : 0,
            child: OverflowBox(
              alignment: Alignment.topLeft,
              minWidth: 300,
              maxWidth: 300,
              child: DoctorSidebar(
                selectedBookingId: _selectedPatient?.id,
                onPatientSelected: (booking) {
                  setState(() => _selectedPatient = booking);
                },
              ),
            ),
          ),
          if (_isSidebarVisible) const VerticalDivider(width: 1, color: Colors.white10),

          // 2. Main Medical View
          Expanded(
            child: Column(
              children: [
                // Top Bar (Toggle Sidebar)
                Container(
                  height: 50,
                  color: AppTheme.surface,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(_isSidebarVisible ? Icons.menu_open : Icons.menu),
                        onPressed: () => setState(() => _isSidebarVisible = !_isSidebarVisible),
                        tooltip: 'إظهار/إخفاء القائمة',
                      ),
                      if (!_isSidebarVisible) ...[
                        const SizedBox(width: 8),
                         const Text('قائمة الانتظار', style: TextStyle(fontWeight: FontWeight.bold)),
                      ],
                      const Spacer(),
                      if (_selectedPatient != null)
                        Text('تعديل ملف: ${_selectedPatient!.patientName}', style: const TextStyle(color: Colors.white54)),
                    ],
                  ),
                ),
                
                Expanded(
                  child: _selectedPatient == null 
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.medical_information, size: 64, color: Colors.white10),
                            SizedBox(height: 16),
                            Text('اختر مريضاً من القائمة لعرض الملف الطبي', style: TextStyle(color: Colors.white38)),
                          ],
                        ),
                      )
                    : PatientMedicalView(booking: _selectedPatient!), // The detailed view
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
