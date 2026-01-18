import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import 'admin_provider.dart';

class AssetsManagementScreen extends StatefulWidget {
  const AssetsManagementScreen({super.key});

  @override
  State<AssetsManagementScreen> createState() => _AssetsManagementScreenState();
}

class _AssetsManagementScreenState extends State<AssetsManagementScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this); // Changed to 3
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdminProvider>().loadDevices();
      context.read<AdminProvider>().loadServices();
      context.read<AdminProvider>().loadDepartments();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Wrap(
              spacing: 16,
              runSpacing: 12,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text('إدارة الأصول', style: Theme.of(context).textTheme.titleLarge),
                ElevatedButton.icon(
                  onPressed: () => _showAddDialog(),
                  icon: const Icon(Icons.add, size: 18),
                  label: Text(_getButtonLabel(), style: const TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Tabs
            Container(
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: TabBar(
                controller: _tabController,
                indicatorColor: AppTheme.primary,
                labelColor: AppTheme.primary,
                unselectedLabelColor: Colors.grey,
                onTap: (index) => setState(() {}),
                tabs: const [
                  Tab(text: 'الأجهزة الطبية', icon: Icon(Icons.medical_services)),
                  Tab(text: 'أنواع الخدمات (العلاجات)', icon: Icon(Icons.spa)),
                  Tab(text: 'الأقسام الطبية', icon: Icon(Icons.category)),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: const [
                  _DevicesList(),
                  _ServicesList(),
                   _DepartmentsList(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getButtonLabel() {
    switch (_tabController.index) {
      case 0: return 'إضافة جهاز';
      case 1: return 'إضافة خدمة';
      case 2: return 'إضافة قسم';
      default: return 'إضافة';
    }
  }

  void _showAddDialog() {
    final adminProvider = context.read<AdminProvider>();
    
    if (_tabController.index == 0) {
      showDialog(
        context: context,
        builder: (_) => ChangeNotifierProvider.value(
          value: adminProvider,
          child: const _AddDeviceDialog(),
        ),
      );
    } else if (_tabController.index == 1) {
      showDialog(
        context: context,
        builder: (_) => ChangeNotifierProvider.value(
          value: adminProvider,
          child: const _AddServiceDialog(),
        ),
      );
    } else {
      showDialog(
        context: context,
        builder: (_) => ChangeNotifierProvider.value(
          value: adminProvider,
          child: const _AddDepartmentDialog(),
        ),
      );
    }
  }
}

class _DevicesList extends StatelessWidget {
  const _DevicesList();

  @override
  Widget build(BuildContext context) {
    return Consumer<AdminProvider>(
      builder: (context, provider, child) {
        if (provider.devices.isEmpty) {
          return const Center(child: Text('لا يوجد أجهزة مضافة', style: TextStyle(color: Colors.white54)));
        }
        return ListView.separated(
          itemCount: provider.devices.length,
          separatorBuilder: (_, i) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final device = provider.devices[index];
            return Container(
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white10),
              ),
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withAlpha(26),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.devices, color: AppTheme.primary),
                ),
                title: Text(device['name'] ?? 'بدون اسم', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                subtitle: Text('${device['type'] ?? 'عام'} - ${device['status'] ?? 'نشط'}', style: const TextStyle(color: Colors.white70)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blueAccent),
                      onPressed: () => _showEditDeviceDialog(context, device),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.redAccent),
                      onPressed: () => _confirmDelete(context, device['id'], device['name']),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showEditDeviceDialog(BuildContext context, Map<String, dynamic> device) {
    final nameController = TextEditingController(text: device['name']);
    final typeController = TextEditingController(text: device['type'] ?? '');
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تعديل الجهاز'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameController, decoration: const InputDecoration(labelText: 'اسم الجهاز', border: OutlineInputBorder())),
            const SizedBox(height: 16),
            TextField(controller: typeController, decoration: const InputDecoration(labelText: 'النوع', border: OutlineInputBorder())),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              try {
                await context.read<AdminProvider>().updateDevice(
                  device['id'],
                  name: nameController.text,
                  type: typeController.text,
                );
                if (ctx.mounted) Navigator.pop(ctx);
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red));
              }
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, String id, String? name) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: Text('هل أنت متأكد من حذف الجهاز "${name ?? ''}"؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          TextButton(
            onPressed: () {
               context.read<AdminProvider>().deleteDevice(id);
               Navigator.pop(ctx);
            },
            child: const Text('حذف', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class _ServicesList extends StatelessWidget {
  const _ServicesList();

  @override
  Widget build(BuildContext context) {
     return Consumer<AdminProvider>(
      builder: (context, provider, child) {
        if (provider.services.isEmpty) {
          return const Center(child: Text('لا يوجد خدمات مضافة', style: TextStyle(color: Colors.white54)));
        }
         return ListView.separated(
          itemCount: provider.services.length,
          separatorBuilder: (_, i) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final service = provider.services[index];
            return Container(
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white10),
              ),
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.purple.withAlpha(26),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.spa, color: Colors.purpleAccent),
                ),
                title: Text(service['name'] ?? 'بدون اسم', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                subtitle: Text('${service['default_price']} د.ع', style: const TextStyle(color: Colors.white70)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blueAccent),
                      onPressed: () => _showEditServiceDialog(context, service),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.redAccent),
                      onPressed: () => _confirmDeleteService(context, service['id'], service['name']),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showEditServiceDialog(BuildContext context, Map<String, dynamic> service) {
    final nameController = TextEditingController(text: service['name']);
    final priceController = TextEditingController(text: service['default_price']?.toString() ?? '0');
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تعديل الخدمة'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameController, decoration: const InputDecoration(labelText: 'اسم الخدمة', border: OutlineInputBorder())),
            const SizedBox(height: 16),
            TextField(controller: priceController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'السعر (د.ع)', border: OutlineInputBorder())),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              try {
                await context.read<AdminProvider>().updateService(
                  service['id'],
                  name: nameController.text,
                  price: double.tryParse(priceController.text) ?? 0,
                );
                if (ctx.mounted) Navigator.pop(ctx);
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red));
              }
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteService(BuildContext context, String id, String? name) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: Text('هل أنت متأكد من حذف الخدمة "${name ?? ''}"؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          TextButton(
            onPressed: () {
              context.read<AdminProvider>().deleteService(id);
              Navigator.pop(ctx);
            },
            child: const Text('حذف', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class _AddDeviceDialog extends StatefulWidget {
  const _AddDeviceDialog();

  @override
  State<_AddDeviceDialog> createState() => _AddDeviceDialogState();
}

class _AddDeviceDialogState extends State<_AddDeviceDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _typeController = TextEditingController();
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('إضافة جهاز جديد'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'اسم الجهاز', border: OutlineInputBorder()),
              validator: (v) => v!.isEmpty ? 'مطلوب' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _typeController,
              decoration: const InputDecoration(labelText: 'النوع (ليزر، تنظيف بشرة...)', border: OutlineInputBorder()),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
        ElevatedButton(
          onPressed: _isLoading ? null : () async {
            if (_formKey.currentState!.validate()) {
              setState(() => _isLoading = true);
              try {
                await context.read<AdminProvider>().addDevice(
                  name: _nameController.text,
                  type: _typeController.text,
                );
                if (mounted) Navigator.pop(context);
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red),
                  );
                }
              } finally {
                if (mounted) setState(() => _isLoading = false);
              }
            }
          },
          child: _isLoading ? const CircularProgressIndicator() : const Text('إضافة'),
        ),
      ],
    );
  }
}

class _AddServiceDialog extends StatefulWidget {
  const _AddServiceDialog();

  @override
  State<_AddServiceDialog> createState() => _AddServiceDialogState();
}

class _AddServiceDialogState extends State<_AddServiceDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('إضافة خدمة جديدة'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'اسم الخدمة', border: OutlineInputBorder()),
              validator: (v) => v!.isEmpty ? 'مطلوب' : null,
            ),
            const SizedBox(height: 16),
             TextFormField(
              controller: _priceController,
              decoration: const InputDecoration(labelText: 'السعر الافتراضي', border: OutlineInputBorder(), suffixText: 'د.ع'),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
        ElevatedButton(
          onPressed: _isLoading ? null : () async {
             if (_formKey.currentState!.validate()) {
              setState(() => _isLoading = true);
              try {
                await context.read<AdminProvider>().addService(
                  name: _nameController.text,
                  price: double.tryParse(_priceController.text) ?? 0,
                );
                if (mounted) Navigator.pop(context);
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red),
                  );
                }
              } finally {
                if (mounted) setState(() => _isLoading = false);
              }
            }
          },
          child: _isLoading ? const CircularProgressIndicator() : const Text('إضافة'),
        ),
      ],
    );
  }
}

class _DepartmentsList extends StatelessWidget {
  const _DepartmentsList();

  @override
  Widget build(BuildContext context) {
     return Consumer<AdminProvider>(
      builder: (context, provider, child) {
        if (provider.departments.isEmpty) {
          return const Center(child: Text('لا يوجد أقسام مضافة', style: TextStyle(color: Colors.white54)));
        }
        return ListView.separated(
          itemCount: provider.departments.length,
          separatorBuilder: (_, i) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final dept = provider.departments[index];
            return Container(
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white10),
              ),
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blueAccent.withAlpha(26),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.category, color: Colors.blueAccent),
                ),
                title: Text(dept['name'] ?? 'بدون اسم', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blueAccent),
                      onPressed: () => _showEditDepartmentDialog(context, dept),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.redAccent),
                      onPressed: () => _confirmDeleteDepartment(context, dept['id'], dept['name']),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showEditDepartmentDialog(BuildContext context, Map<String, dynamic> dept) {
    final nameController = TextEditingController(text: dept['name']);
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تعديل القسم'),
        content: TextField(
          controller: nameController, 
          decoration: const InputDecoration(labelText: 'اسم القسم', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              try {
                await context.read<AdminProvider>().updateDepartment(dept['id'], name: nameController.text);
                if (ctx.mounted) Navigator.pop(ctx);
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red));
              }
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteDepartment(BuildContext context, String id, String? name) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: Text('هل أنت متأكد من حذف القسم "${name ?? ''}"؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          TextButton(
            onPressed: () {
              context.read<AdminProvider>().deleteDepartment(id);
              Navigator.pop(ctx);
            },
            child: const Text('حذف', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class _AddDepartmentDialog extends StatefulWidget {
  const _AddDepartmentDialog();

  @override
  State<_AddDepartmentDialog> createState() => _AddDepartmentDialogState();
}

class _AddDepartmentDialogState extends State<_AddDepartmentDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('إضافة قسم جديد'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'اسم القسم', border: OutlineInputBorder()),
              validator: (v) => v!.isEmpty ? 'مطلوب' : null,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
        ElevatedButton(
          onPressed: _isLoading ? null : () async {
             if (_formKey.currentState!.validate()) {
              setState(() => _isLoading = true);
              try {
                await context.read<AdminProvider>().addDepartment(_nameController.text);
                if (mounted) Navigator.pop(context);
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red),
                  );
                }
              } finally {
                if (mounted) setState(() => _isLoading = false);
              }
            }
          },
          child: _isLoading ? const CircularProgressIndicator() : const Text('إضافة'),
        ),
      ],
    );
  }
}
