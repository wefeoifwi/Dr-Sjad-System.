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
  String _searchQuery = '';
  final _searchController = TextEditingController();

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
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
          const SizedBox(height: 16),

          // Search Bar
          TextField(
            controller: _searchController,
            onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
            decoration: InputDecoration(
              hintText: 'بحث بالاسم...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: AppTheme.surface,
            ),
          ),
          const SizedBox(height: 16),

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
                _StaffList(type: 'doctor', searchQuery: _searchQuery),
                _StaffList(type: 'employee', searchQuery: _searchQuery),
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
    
    // Get the provider BEFORE opening the dialog
    final adminProvider = context.read<AdminProvider>();

    showDialog(
      context: context,
      builder: (ctx) => ChangeNotifierProvider.value(
        value: adminProvider,
        child: StatefulBuilder(
          builder: (dialogContext, setState) {
            bool showDept = role == 'doctor' || role == 'reception' || role == 'call_center';
            
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
                            DropdownMenuItem(value: 'call_center', child: Text('كول سنتر (Call Center)')),
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
                        
                        await adminProvider.addStaff(
                          email: email, // Use generated email
                          username: usernameController.text.trim(),
                          password: passwordController.text,
                          name: nameController.text,
                          role: role,
                          phone: phoneController.text,
                          department: startDepartment,
                        );
                        Navigator.pop(ctx);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تمت الإضافة بنجاح'), backgroundColor: Colors.green));
                        }
                      } catch (e) {
                        setState(() => isLoading = false);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red));
                        }
                      }
                    }
                  },
                  child: isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('حفظ'),
                ),
              ],
            );
          }
        ),
      ),
    );
  }
}

class _StaffList extends StatelessWidget {
  final String type;
  final String searchQuery;
  const _StaffList({required this.type, this.searchQuery = ''});

  @override
  Widget build(BuildContext context) {
    return Consumer<AdminProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        final isDoctor = type == 'doctor';
        List<Map<String, dynamic>> list = isDoctor ? provider.doctors : provider.employees;

        // Apply search filter
        if (searchQuery.isNotEmpty) {
          list = list.where((staff) {
            final name = (staff['name'] ?? '').toString().toLowerCase();
            final phone = (staff['phone'] ?? '').toString().toLowerCase();
            return name.contains(searchQuery) || phone.contains(searchQuery);
          }).toList();
        }

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
            final isActive = staff['is_active'] ?? true;
            
            return Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isActive ? Colors.white.withAlpha(13) : Colors.red.withAlpha(50)),
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
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isActive ? Colors.white : Colors.white54),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isDoctor ? 'طبيب' : _getRoleLabel(role), 
                          style: const TextStyle(fontSize: 11, color: Colors.white54),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                   // Status Badge and Actions
                   if (MediaQuery.of(context).size.width > 500) ...[ 
                     Container(
                       padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                       decoration: BoxDecoration(
                         color: isActive ? Colors.green.withAlpha(26) : Colors.red.withAlpha(26),
                         borderRadius: BorderRadius.circular(20),
                         border: Border.all(color: isActive ? Colors.green.withAlpha(77) : Colors.red.withAlpha(77)),
                       ),
                       child: Text(isActive ? 'نشط' : 'موقف', style: TextStyle(color: isActive ? Colors.green : Colors.red, fontSize: 10)),
                     ),
                     const SizedBox(width: 8),
                   ],
                  // Edit Button
                  IconButton(
                    icon: const Icon(Icons.edit, color: Colors.cyan, size: 20),
                    tooltip: 'تعديل البيانات',
                    onPressed: () => _showEditStaffDialog(context, staff),
                  ),
                  // Toggle Active Button
                  IconButton(
                    icon: Icon(isActive ? Icons.pause_circle : Icons.play_circle, color: isActive ? Colors.orange : Colors.green, size: 20),
                    tooltip: isActive ? 'إيقاف الحساب' : 'تفعيل الحساب',
                    onPressed: () => _toggleStaffStatus(context, staff['id'], !isActive, name),
                  ),
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

  void _showEditStaffDialog(BuildContext context, Map<String, dynamic> staff) {
    final nameController = TextEditingController(text: staff['name'] ?? '');
    final usernameController = TextEditingController(text: staff['username'] ?? staff['email']?.toString().split('@').first ?? '');
    final passwordController = TextEditingController();
    final phoneController = TextEditingController(text: staff['phone'] ?? '');
    bool isLoading = false;
    bool showPassword = false;
    
    final adminProvider = context.read<AdminProvider>();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogContext, setState) {
          return AlertDialog(
            backgroundColor: AppTheme.surface,
            title: Row(
              children: [
                const Icon(Icons.edit, color: Colors.cyan),
                const SizedBox(width: 8),
                Text('تعديل: ${staff['name'] ?? 'مستخدم'}'),
              ],
            ),
            content: SizedBox(
              width: 400,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Info Card
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.withAlpha(26),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.withAlpha(51)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, color: Colors.blue, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'الدور: ${_getRoleLabel(staff['role'] ?? 'موظف')}',
                              style: const TextStyle(color: Colors.blue, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    
                    // Name
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'الاسم الكامل',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Username
                    TextField(
                      controller: usernameController,
                      decoration: const InputDecoration(
                        labelText: 'اسم المستخدم (Username)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.account_circle),
                        helperText: 'سيتم تحديث البريد تلقائياً',
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Phone
                    TextField(
                      controller: phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'رقم الهاتف',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.phone),
                      ),
                    ),
                    const SizedBox(height: 20),
                    
                    // Password Section
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.withAlpha(26),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.withAlpha(51)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.lock_reset, color: Colors.orange, size: 18),
                              SizedBox(width: 8),
                              Text('تغيير كلمة المرور', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          const Text('اتركها فارغة إذا لا تريد تغييرها', style: TextStyle(fontSize: 11, color: Colors.white54)),
                          const SizedBox(height: 12),
                          TextField(
                            controller: passwordController,
                            obscureText: !showPassword,
                            decoration: InputDecoration(
                              labelText: 'كلمة المرور الجديدة',
                              border: const OutlineInputBorder(),
                              prefixIcon: const Icon(Icons.lock),
                              suffixIcon: IconButton(
                                icon: Icon(showPassword ? Icons.visibility_off : Icons.visibility),
                                onPressed: () => setState(() => showPassword = !showPassword),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('إلغاء'),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.cyan),
                onPressed: isLoading ? null : () async {
                  setState(() => isLoading = true);
                  try {
                    await adminProvider.updateStaffInfo(
                      userId: staff['id'],
                      name: nameController.text.trim(),
                      username: usernameController.text.trim(),
                      phone: phoneController.text.trim(),
                      newPassword: passwordController.text.isNotEmpty ? passwordController.text : null,
                    );
                    Navigator.pop(ctx);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('✅ تم تحديث البيانات بنجاح'), backgroundColor: Colors.green),
                      );
                    }
                  } catch (e) {
                    setState(() => isLoading = false);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('❌ خطأ: $e'), backgroundColor: Colors.red),
                      );
                    }
                  }
                },
                icon: isLoading 
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.save),
                label: const Text('حفظ التعديلات'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _toggleStaffStatus(BuildContext context, String id, bool newStatus, String name) {
    final statusText = newStatus ? 'تفعيل' : 'إيقاف';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$statusText الحساب'),
        content: Text('هل تريد $statusText حساب "$name"؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: newStatus ? Colors.green : Colors.orange),
            onPressed: () {
              context.read<AdminProvider>().toggleStaffStatus(id, newStatus);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('تم $statusText الحساب بنجاح'), backgroundColor: newStatus ? Colors.green : Colors.orange),
              );
            },
            child: Text(statusText),
          ),
        ],
      ),
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

  String _getRoleLabel(String role) {
    switch (role) {
      case 'admin': return 'مدير';
      case 'reception': return 'استقبال';
      case 'call_center': return 'كول سنتر';
      case 'doctor': return 'طبيب';
      default: return 'موظف';
    }
  }
}
