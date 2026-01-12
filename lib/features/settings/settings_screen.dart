import 'package:flutter/material.dart';
import '../../core/theme.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

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
          _buildSettingsTile(Icons.language, 'اللغة', 'العربية'),
          _buildSettingsTile(Icons.dark_mode, 'المظهر', 'داكن'),
          
          const SizedBox(height: 24),
          _buildSectionHeader('الحساب والأمان'),
          _buildSettingsTile(Icons.person, 'الملف الشخصي', 'تعديل البيانات'),
          _buildSettingsTile(Icons.lock, 'كلمة المرور', 'تغيير كلمة المرور'),
          
          const SizedBox(height: 24),
          _buildSectionHeader('النظام'),
          _buildSettingsTile(Icons.notifications, 'الإشعارات', 'مفعلة'),
          _buildSettingsTile(Icons.info, 'حول البرنامج', 'V 1.0.0'),
          
          const SizedBox(height: 40),
          Center(
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.withAlpha(26), // 0.1 * 255
                foregroundColor: Colors.red,
              ),
              onPressed: () {}, // Log out logic
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

  Widget _buildSettingsTile(IconData icon, String title, String subtitle) {
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
        onTap: () {},
      ),
    );
  }
}
