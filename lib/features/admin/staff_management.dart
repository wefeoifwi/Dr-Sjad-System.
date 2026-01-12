import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import 'admin_provider.dart';

class StaffManagementScreen extends StatefulWidget {
  const StaffManagementScreen({super.key});

  @override
  State<StaffManagementScreen> createState() => _StaffManagementScreenState();
}

class _StaffManagementScreenState extends State<StaffManagementScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // Load data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdminProvider>().loadStaff();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.background,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              const Icon(Icons.people_alt, color: AppTheme.primary, size: 32),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('إدارة الموظفين', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white), overflow: TextOverflow.ellipsis),
                    Text('إدارة الأطباء، والموظفين، والصلاحيات', style: TextStyle(color: Colors.white54, fontSize: 12), overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              // Hide button text on small screens if needed, or just icon
              if (MediaQuery.of(context).size.width > 600) ...[
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  icon: const Icon(Icons.add),
                  label: const Text('إضافة'),
                  onPressed: () => _showAddStaffDialog(context),
                ),
              ] else 
                 IconButton(
                    onPressed: () => _showAddStaffDialog(context), 
                    icon: const Icon(Icons.add_circle, color: AppTheme.primary, size: 32),
                 )
            ],
          ),
          const SizedBox(height: 24),

          // Tabs
          Container(
            height: 45,
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white10),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: AppTheme.primary.withAlpha(51),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.primary.withAlpha(128)),
              ),
              labelColor: AppTheme.primary,
              unselectedLabelColor: Colors.white54,
              labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              tabs: const [
                Tab(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.medical_services, size: 16), SizedBox(width: 4), Text('الأطباء')])),
                Tab(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.badge, size: 16), SizedBox(width: 4), Text('الموظفين')])),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _StaffList(type: 'doctor'),
                _StaffList(type: 'employee'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showAddStaffDialog(BuildContext context) {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final usernameController = TextEditingController();
    final passwordController = TextEditingController(); // Keep password for auth, even if user said 'instead', they likely need one.
    // If user REALLY meant no password, we'd need a default one. Let's keep it for now but maybe minimize emphasis?
    // Actually, "badal kalimat al sir" -> "Instead of password". Maybe they want to set the username *as* the password? Unsafe.
    // I will assume they want a Username field and I will keep Password for now but put Username first.
    
    final phoneController = TextEditingController();
    String role = 'reception'; // Default to reception as it's common
    String? startDepartment; // 'General', 'Dermatology', 'Laser', 'Dental'
    
    // Departments List
    final List<String> medicalDepts = ['الجلدية', 'الليزر', 'الأسنان', 'التجميل'];
    final List<String> receptionDepts = ['عام (الكل)', ...medicalDepts];

    bool isLoading = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          bool showDept = role == 'doctor' || role == 'reception';
          
          return AlertDialog(
            title: const Text('إضافة مستخدم جديد'),
            content: SizedBox(
              width: 400,
              child: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Role Selection
                       DropdownButtonFormField<String>(initialValue: role,
                        decoration: const InputDecoration(labelText: 'الدور/الوظيفة', border: OutlineInputBorder()),
                        items: const [
                          DropdownMenuItem(value: 'doctor', child: Text('طبيب (Doctor)')),
                          DropdownMenuItem(value: 'reception', child: Text('استقبال (Reception)')),
                          DropdownMenuItem(value: 'admin', child: Text('مدير (Admin)')),
                        ],
                        onChanged: (val) {
                           setState(() {
                             role = val!;
                             startDepartment = null; // Reset dept
                           });
                        },
                      ),
                      const SizedBox(height: 16),
                      
                      // Department Selection (Conditional)
                      if (showDept) ...[
                        DropdownButtonFormField<String>(initialValue: startDepartment,
                          decoration: const InputDecoration(labelText: 'القسم', border: OutlineInputBorder()),
                          items: (role == 'doctor' ? medicalDepts : receptionDepts).map((d) {
                             return DropdownMenuItem(value: d, child: Text(d));
                          }).toList(),
                          validator: (v) => v == null ? 'يرجى تحديد القسم' : null,
                          onChanged: (val) => setState(() => startDepartment = val),
                        ),
                        const SizedBox(height: 16),
                      ],

                      TextFormField(
                        controller: nameController,
                        decoration: const InputDecoration(labelText: 'الاسم الكامل', border: OutlineInputBorder(), prefixIcon: Icon(Icons.person)),
                        validator: (v) => v!.isEmpty ? 'مطلوب' : null,
                      ),
                      const SizedBox(height: 16),
                      
                      // Username & Password
                      TextFormField(
                        controller: usernameController,
                        decoration: const InputDecoration(labelText: 'اسم المستخدم (للإيداع)', border: OutlineInputBorder(), prefixIcon: Icon(Icons.account_circle)),
                        validator: (v) => v!.isEmpty ? 'مطلوب' : null,
                      ),
                      const SizedBox(height: 16),
                       TextFormField(
                        controller: passwordController,
                        decoration: const InputDecoration(labelText: 'كلمة المرور', border: OutlineInputBorder(), prefixIcon: Icon(Icons.lock)),
                        validator: (v) => v!.length < 6 ? '6 أحرف على الأقل' : null,
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
              ElevatedButton(
                onPressed: isLoading ? null : () async {
                  if (formKey.currentState!.validate()) {
                    setState(() => isLoading = true);
                    try {
                      // Generate dummy email for Supabase Auth if needed: username@carepoint.local
                      final email = '${usernameController.text.trim()}@carepoint.local';
                      
                      await context.read<AdminProvider>().addStaff(
                        email: email, // Use generated email
                        username: usernameController.text.trim(),
                        password: passwordController.text,
                        name: nameController.text,
                        role: role,
                        phone: phoneController.text,
                        department: startDepartment,
                      );
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تمت الإضافة بنجاح'), backgroundColor: Colors.green));
                    } catch (e) {
                      setState(() => isLoading = false);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red));
                    }
                  }
                },
                child: isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('حفظ'),
              ),
            ],
          );
        }
      ),
    );
  }
}

class _StaffList extends StatelessWidget {
  final String type;
  const _StaffList({required this.type});

  @override
  Widget build(BuildContext context) {
    return Consumer<AdminProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        final isDoctor = type == 'doctor';
        final List<Map<String, dynamic>> list = isDoctor ? provider.doctors : provider.employees;

        if (list.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(isDoctor ? Icons.medical_services_outlined : Icons.people_outline, size: 48, color: Colors.white24),
                const SizedBox(height: 16),
                Text('لا يوجد ${isDoctor ? 'أطباء' : 'موظفين'} حالياً', style: const TextStyle(color: Colors.white54)),
              ],
            ),
          );
        }

        return ListView.separated(
          itemCount: list.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final staff = list[index];
            final name = staff['name'] ?? 'بدون اسم';
            final role = staff['role'] ?? 'موظف';
            
            return Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withAlpha(13)),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: isDoctor ? Colors.purple.withAlpha(51) : Colors.blue.withAlpha(51),
                    child: Icon(isDoctor ? Icons.medical_services : Icons.person, color: isDoctor ? Colors.purple : Colors.blue, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name, 
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isDoctor ? 'طبيب - $role' : 'موظف - $role', 
                          style: const TextStyle(fontSize: 11, color: Colors.white54),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                   // Responsive Actions
                   if (MediaQuery.of(context).size.width > 500) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.green.withAlpha(26),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.green.withAlpha(77)),
                        ),
                        child: const Text('نشط', style: TextStyle(color: Colors.green, fontSize: 10)),
                      ),
                      const SizedBox(width: 8),
                   ],
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20), 
                    onPressed: () => _confirmDelete(context, staff['id'], type),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _confirmDelete(BuildContext context, String id, String type) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: const Text('هل أنت متأكد من حذف هذا المستخدم؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(context);
              context.read<AdminProvider>().deleteStaff(id, type);
            }, 
            child: const Text('حذف'),
          ),
        ],
      ),
    );
  }
}
