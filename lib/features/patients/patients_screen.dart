import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../core/whatsapp_helper.dart';
import '../admin/admin_provider.dart';
import 'patient_details_screen.dart';
import 'dart:async';

class PatientsScreen extends StatefulWidget {
  final String userRole;
  const PatientsScreen({super.key, this.userRole = 'employee'});

  @override
  State<PatientsScreen> createState() => _PatientsScreenState();
}

class _PatientsScreenState extends State<PatientsScreen> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdminProvider>().loadPatients(reset: true);
    });
    
    // Infinite scroll listener
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      context.read<AdminProvider>().loadMorePatients();
    }
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      context.read<AdminProvider>().searchPatients(query);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Consumer<AdminProvider>(
        builder: (context, provider, child) {
          final patients = provider.patients;
          final isLoading = provider.patientsLoading;
          final total = provider.patientsTotal;
          
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('سجل المرضى', style: Theme.of(context).textTheme.headlineMedium),
                        if (total > 0)
                          Text('$total مريض مسجل', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                      ],
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _showAddPatientDialog(context), 
                      icon: const Icon(Icons.person_add), 
                      label: const Text('إضافة مريض')
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Search Bar with server-side search
                TextField(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  decoration: InputDecoration(
                    hintText: 'بحث بالاسم أو الهاتف... (بحث سريع على الخادم)',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              context.read<AdminProvider>().searchPatients('');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: AppTheme.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Patient List with infinite scroll
                Expanded(
                  child: patients.isEmpty && isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : patients.isEmpty
                          ? const Center(child: Text('لا يوجد مرضى', style: TextStyle(color: Colors.white54)))
                          : GridView.builder(
                              controller: _scrollController,
                              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                                maxCrossAxisExtent: 400,
                                childAspectRatio: 2.2,
                                crossAxisSpacing: 16,
                                mainAxisSpacing: 16,
                              ),
                              itemCount: patients.length + (provider.patientsHasMore ? 1 : 0),
                              itemBuilder: (context, index) {
                                // Loading indicator at bottom
                                if (index >= patients.length) {
                                  return const Center(child: Padding(
                                    padding: EdgeInsets.all(16),
                                    child: CircularProgressIndicator(),
                                  ));
                                }
                                
                                final patient = patients[index];
                                return _PatientCard(patient: patient, userRole: widget.userRole);
                              },
                            ),
                ),

                // Footer with count
                if (patients.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'يُعرض ${patients.length} من $total',
                          style: const TextStyle(color: Colors.white38, fontSize: 12),
                        ),
                        if (provider.patientsHasMore) ...[
                          const SizedBox(width: 8),
                          TextButton.icon(
                            onPressed: () => provider.loadMorePatients(),
                            icon: const Icon(Icons.arrow_downward, size: 14),
                            label: const Text('تحميل المزيد', style: TextStyle(fontSize: 12)),
                          ),
                        ],
                      ],
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showAddPatientDialog(BuildContext context) {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final ageController = TextEditingController();
    final addressController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('إضافة مريض جديد', style: TextStyle(color: Colors.white)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'الاسم *', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneController,
                decoration: const InputDecoration(labelText: 'الهاتف *', border: OutlineInputBorder()),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: ageController,
                decoration: const InputDecoration(labelText: 'العمر', border: OutlineInputBorder()),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: addressController,
                decoration: const InputDecoration(labelText: 'العنوان', border: OutlineInputBorder()),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isNotEmpty && phoneController.text.isNotEmpty) {
                try {
                  await context.read<AdminProvider>().addPatient(
                    name: nameController.text,
                    phone: phoneController.text,
                    age: int.tryParse(ageController.text),
                    address: addressController.text.isNotEmpty ? addressController.text : null,
                  );
                  if (ctx.mounted) Navigator.pop(ctx);
                  // Reload to show new patient
                  context.read<AdminProvider>().loadPatients(reset: true);
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: Colors.red));
                  }
                }
              }
            },
            child: const Text('إضافة'),
          ),
        ],
      ),
    );
  }
}

class _PatientCard extends StatelessWidget {
  final Map<String, dynamic> patient;
  final String userRole;
  const _PatientCard({required this.patient, this.userRole = 'employee'});

  @override
  Widget build(BuildContext context) {
    final name = patient['name'] ?? 'بدون اسم';
    final phone = patient['phone'] ?? '---';
    final age = patient['age'];
    final gender = patient['gender'] ?? 'female';
    final source = patient['source'] ?? 'walk_in';
    final visitCount = patient['total_visits'] ?? patient['visit_count'] ?? 0;
    
    final statusColor = visitCount > 5 ? Colors.amber : Colors.green;
    final genderIcon = gender == 'male' ? Icons.man : Icons.woman;
    final genderColor = gender == 'male' ? Colors.blue : Colors.pink;

    return Card(
      color: AppTheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: statusColor.withAlpha(77), width: 1),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => PatientDetailsScreen(patient: patient)));
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: genderColor.withAlpha(51),
                    child: Icon(genderIcon, color: genderColor, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white), maxLines: 1, overflow: TextOverflow.ellipsis),
                        Row(
                          children: [
                            const Icon(Icons.phone, size: 11, color: Colors.white54),
                            const SizedBox(width: 4),
                            Text(phone, style: const TextStyle(color: Colors.white70, fontSize: 10)),
                            if (age != null) Text(' | $age سنة', style: const TextStyle(color: Colors.white54, fontSize: 10)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(color: statusColor.withAlpha(51), borderRadius: BorderRadius.circular(10)),
                    child: Text('$visitCount', style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  _SourceBadge(source: source),
                  const Spacer(),
                  // WhatsApp button for admin, call_center, reception
                  if (['admin', 'call_center', 'reception'].contains(userRole))
                    IconButton(
                      icon: const Icon(Icons.message, color: Colors.green, size: 18),
                      tooltip: 'تواصل واتساب',
                      onPressed: () => WhatsAppHelper.showContactOptions(
                        context: context,
                        phone: phone,
                        patientName: name,
                        userRole: userRole,
                      ),
                    ),
                  const Icon(Icons.arrow_forward_ios, size: 12, color: Colors.white24),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SourceBadge extends StatelessWidget {
  final String source;
  const _SourceBadge({required this.source});

  @override
  Widget build(BuildContext context) {
    String label;
    Color color;
    IconData icon;
    
    switch (source) {
      case 'walk_in':
        label = 'حضوري';
        color = Colors.green;
        icon = Icons.directions_walk;
        break;
      case 'call':
        label = 'اتصال';
        color = Colors.blue;
        icon = Icons.phone;
        break;
      case 'online':
        label = 'أونلاين';
        color = Colors.purple;
        icon = Icons.language;
        break;
      case 'referral':
        label = 'إحالة';
        color = Colors.orange;
        icon = Icons.people;
        break;
      default:
        label = source;
        color = Colors.grey;
        icon = Icons.help_outline;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: color.withAlpha(26), borderRadius: BorderRadius.circular(6)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 3),
          Text(label, style: TextStyle(color: color, fontSize: 9)),
        ],
      ),
    );
  }
}
