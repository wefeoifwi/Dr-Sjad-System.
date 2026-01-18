import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme.dart';
import '../auth/login_screen.dart';
import '../admin/data_import_screen.dart';
import '../admin/data_export_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  Map<String, dynamic>? _userProfile;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId != null) {
        final data = await Supabase.instance.client
            .from('profiles')
            .select()
            .eq('id', userId)
            .maybeSingle();
        if (mounted) setState(() => _userProfile = data);
      }
    } catch (e) {
      debugPrint('Error loading profile: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text('الإعدادات', style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 32),

                _buildSectionHeader('عام'),
                _buildSettingsTile(Icons.language, 'اللغة', 'العربية', () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('اللغة العربية هي الوحيدة المتاحة حالياً')),
                  );
                }),
                _buildSettingsTile(Icons.dark_mode, 'المظهر', 'داكن', () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('المظهر الداكن هو الوحيد المتاح حالياً')),
                  );
                }),
                
                const SizedBox(height: 24),
                _buildSectionHeader('الحساب والأمان'),
                _buildSettingsTile(
                  Icons.person, 
                  'الملف الشخصي', 
                  _userProfile?['name'] ?? 'غير محدد',
                  () => _showProfileDialog(context),
                ),
                _buildSettingsTile(Icons.lock, 'كلمة المرور', 'تغيير كلمة المرور', () {
                  _showChangePasswordDialog(context);
                }),
                
                const SizedBox(height: 24),
                _buildSectionHeader('النظام'),
                _buildSettingsTile(Icons.upload_file, 'استيراد بيانات', 'استيراد ملف Excel', () {
                  Navigator.push(context, MaterialPageRoute(
                    builder: (_) => const _DataImportScreenWrapper(),
                  ));
                }),
                _buildSettingsTile(Icons.download, 'تصدير بيانات', 'تصدير إلى ملف Excel', () {
                  Navigator.push(context, MaterialPageRoute(
                    builder: (_) => const DataExportScreen(),
                  ));
                }),
                _buildSettingsTile(Icons.delete_forever, 'مسح شامل للنظام', 'حذف جميع البيانات ما عدا المستخدمين', () {
                  _showWipeSystemDialog(context);
                }),
                // الحقول الديناميكية متاحة فقط في لوحة تحكم المدير
                _buildSettingsTile(Icons.info, 'حول البرنامج', 'V 1.0.0', () {
                  _showAboutDialog(context);
                }),
                
                const SizedBox(height: 40),
                Center(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.withAlpha(26),
                      foregroundColor: Colors.red,
                    ),
                    onPressed: () => _logout(context),
                    icon: const Icon(Icons.logout),
                    label: const Text('تسجيل الخروج'),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(title, style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildSettingsTile(IconData icon, String title, String subtitle, VoidCallback onTap) {
    return Card(
      color: AppTheme.surface,
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(icon, color: Colors.white70),
        title: Text(title),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(subtitle, style: const TextStyle(color: Colors.white38)),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.white38),
          ],
        ),
        onTap: onTap,
      ),
    );
  }

  void _showProfileDialog(BuildContext context) {
    final phoneController = TextEditingController(text: _userProfile?['phone'] ?? '');
    // ignore: unused_local_variable - kept for future use
    final isAdmin = _userProfile?['role'] == 'admin';
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('الملف الشخصي'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // الاسم (للعرض فقط)
            TextField(
              enabled: false,
              decoration: InputDecoration(
                labelText: 'الاسم',
                hintText: _userProfile?['name'] ?? 'غير محدد',
                border: const OutlineInputBorder(),
                filled: true,
                fillColor: Colors.grey.withAlpha(26),
                helperText: 'الاسم يمكن تعديله من قبل المدير فقط',
                helperStyle: const TextStyle(color: Colors.orange, fontSize: 11),
              ),
              controller: TextEditingController(text: _userProfile?['name'] ?? ''),
            ),
            const SizedBox(height: 16),
            
            // الدور (للعرض فقط)
            TextField(
              enabled: false,
              decoration: InputDecoration(
                labelText: 'الدور',
                border: const OutlineInputBorder(),
                filled: true,
                fillColor: Colors.grey.withAlpha(26),
              ),
              controller: TextEditingController(text: _getRoleLabel(_userProfile?['role'])),
            ),
            const SizedBox(height: 16),
            
            // رقم الهاتف (قابل للتعديل)
            TextField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'رقم الهاتف',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.phone),
                helperText: 'يمكنك تعديل رقم هاتفك',
                helperStyle: TextStyle(color: Colors.green, fontSize: 11),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              try {
                final userId = Supabase.instance.client.auth.currentUser?.id;
                if (userId != null) {
                  await Supabase.instance.client.from('profiles').update({
                    'phone': phoneController.text,
                  }).eq('id', userId);
                  
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('تم حفظ التعديلات بنجاح'), backgroundColor: Colors.green),
                  );
                  _loadUserProfile(); // Refresh
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red),
                );
              }
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  String _getRoleLabel(String? role) {
    switch (role) {
      case 'admin': return 'مدير النظام';
      case 'doctor': return 'طبيب';
      case 'reception': return 'استقبال';
      case 'call_center': return 'كول سنتر';
      default: return 'غير محدد';
    }
  }

  void _logout(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تسجيل الخروج'),
        content: const Text('هل أنت متأكد من رغبتك في تسجيل الخروج؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await Supabase.instance.client.auth.signOut();
              Navigator.pop(ctx);
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (route) => false,
              );
            },
            child: const Text('تسجيل الخروج'),
          ),
        ],
      ),
    );
  }

  void _showChangePasswordDialog(BuildContext context) {
    final newPassController = TextEditingController();
    final confirmPassController = TextEditingController();
    bool isLoading = false;
    
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('تغيير كلمة المرور'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: newPassController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'كلمة المرور الجديدة',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock_outline),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: confirmPassController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'تأكيد كلمة المرور',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: isLoading ? null : () async {
                if (newPassController.text.length < 6) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('كلمة المرور يجب أن تكون 6 أحرف على الأقل'), backgroundColor: Colors.orange),
                  );
                  return;
                }
                
                if (newPassController.text != confirmPassController.text) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('كلمتا المرور غير متطابقتين'), backgroundColor: Colors.red),
                  );
                  return;
                }
                
                setState(() => isLoading = true);
                
                try {
                  await Supabase.instance.client.auth.updateUser(
                    UserAttributes(password: newPassController.text),
                  );
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('تم تغيير كلمة المرور بنجاح'), backgroundColor: Colors.green),
                  );
                } catch (e) {
                  setState(() => isLoading = false);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red),
                  );
                }
              },
              child: isLoading 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حول البرنامج'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('CarePoint Clinic Management', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            SizedBox(height: 8),
            Text('الإصدار: 1.0.0'),
            SizedBox(height: 8),
            Text('نظام إدارة عيادات متكامل'),
            SizedBox(height: 16),
            Text('© 2026 جميع الحقوق محفوظة', style: TextStyle(color: Colors.white54)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إغلاق')),
        ],
      ),
    );
  }

  void _showWipeSystemDialog(BuildContext context) {
    final confirmController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Row(
          children: [
            Icon(Icons.warning_amber, color: Colors.red, size: 28),
            SizedBox(width: 8),
            Text('⚠️ تحذير: مسح شامل', style: TextStyle(color: Colors.red)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('سيتم حذف جميع البيانات التالية نهائياً:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _buildDeleteItem('المرضى (patients)'),
            _buildDeleteItem('الجلسات (sessions)'),
            _buildDeleteItem('المتابعات (follow_ups)'),
            _buildDeleteItem('المدفوعات (payments)'),
            _buildDeleteItem('الخدمات (services)'),
            _buildDeleteItem('الحقول الديناميكية (dynamic_fields)'),
            const SizedBox(height: 16),
            const Text('✅ سيتم الإبقاء على:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
            const SizedBox(height: 8),
            const Text('• المستخدمين (profiles)', style: TextStyle(color: Colors.green)),
            const SizedBox(height: 16),
            const Text('اكتب "مسح" للتأكيد:', style: TextStyle(color: Colors.orange)),
            const SizedBox(height: 8),
            TextField(
              controller: confirmController,
              decoration: const InputDecoration(
                hintText: 'اكتب "مسح" هنا',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              if (confirmController.text.trim() != 'مسح') {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('❌ يجب كتابة "مسح" للتأكيد')),
                );
                return;
              }
              
              Navigator.pop(ctx);
              
              // Show loading
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (_) => const AlertDialog(
                  backgroundColor: AppTheme.surface,
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('جاري المسح...'),
                    ],
                  ),
                ),
              );
              
              try {
                final supabase = Supabase.instance.client;
                
                // Delete in order (respecting foreign keys - children first)
                // حذف الجداول التابعة أولاً
                
                // 1. حذف قيم الحقول الديناميكية (تعتمد على patients/sessions)
                try { 
                  await supabase.from('dynamic_field_values').delete().gte('id', '00000000-0000-0000-0000-000000000000'); 
                } catch (e) { debugPrint('Skip dynamic_field_values: $e'); }
                
                // 2. حذف المدفوعات (تعتمد على sessions)
                try { 
                  await supabase.from('payments').delete().gte('id', '00000000-0000-0000-0000-000000000000'); 
                } catch (e) { debugPrint('Skip payments: $e'); }
                
                // 3. حذف المتابعات (تعتمد على patients)
                try { 
                  await supabase.from('follow_ups').delete().gte('id', '00000000-0000-0000-0000-000000000000'); 
                } catch (e) { debugPrint('Skip follow_ups: $e'); }
                
                // 4. حذف الجلسات (تعتمد على patients/services/rooms)
                try { 
                  await supabase.from('sessions').delete().gte('id', '00000000-0000-0000-0000-000000000000'); 
                } catch (e) { debugPrint('Skip sessions: $e'); }
                
                // 5. حذف المرضى
                try { 
                  await supabase.from('patients').delete().gte('id', '00000000-0000-0000-0000-000000000000'); 
                } catch (e) { debugPrint('Skip patients: $e'); }
                
                // 6. حذف الخدمات
                try { 
                  await supabase.from('services').delete().gte('id', '00000000-0000-0000-0000-000000000000'); 
                } catch (e) { debugPrint('Skip services: $e'); }
                
                // 7. حذف الغرف
                try { 
                  await supabase.from('rooms').delete().gte('id', '00000000-0000-0000-0000-000000000000'); 
                } catch (e) { debugPrint('Skip rooms: $e'); }
                
                // 8. حذف الأجهزة
                try { 
                  await supabase.from('devices').delete().gte('id', '00000000-0000-0000-0000-000000000000'); 
                } catch (e) { debugPrint('Skip devices: $e'); }
                
                // 9. حذف تعريفات الحقول الديناميكية
                try { 
                  await supabase.from('dynamic_field_definitions').delete().gte('id', '00000000-0000-0000-0000-000000000000'); 
                } catch (e) { debugPrint('Skip dynamic_field_definitions: $e'); }
                
                if (context.mounted) {
                  Navigator.pop(context); // Close loading
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('✅ تم المسح الشامل بنجاح'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  Navigator.pop(context); // Close loading
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('❌ خطأ: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: const Text('🗑️ مسح نهائي'),
          ),
        ],
      ),
    );
  }

  Widget _buildDeleteItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          const Icon(Icons.close, color: Colors.red, size: 16),
          const SizedBox(width: 8),
          Text(text, style: const TextStyle(color: Colors.red)),
        ],
      ),
    );
  }
}

// Wrapper for DataImportScreen to be used from Settings
class _DataImportScreenWrapper extends StatelessWidget {
  const _DataImportScreenWrapper();

  @override
  Widget build(BuildContext context) {
    return const DataImportScreen();
  }
}
