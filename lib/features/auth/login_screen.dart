import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme.dart';
import '../dashboard/dashboard_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  Future<void> _signIn() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    if (username.isEmpty || password.isEmpty) {
      _showError('يرجى إدخال اسم المستخدم وكلمة المرور');
      return;
    }

    setState(() => _isLoading = true);
    try {
      // Query profile by username and password (simple auth for local system)
      final response = await Supabase.instance.client
          .from('profiles')
          .select()
          .eq('username', username)
          .maybeSingle();

      if (response == null) {
        _showError('اسم المستخدم غير موجود');
        return;
      }

      // Simple password check (in production, use hashed passwords)
      final storedPassword = response['password'] ?? 'admin123';
      if (password != storedPassword) {
        _showError('كلمة المرور غير صحيحة');
        return;
      }

      final role = response['role'] ?? 'employee';
      
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => DashboardScreen(userRole: role)),
        );
      }
    } catch (e) {
      debugPrint('Login error: $e');
      _showError('حدث خطأ في الاتصال بالسيرفر');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: AppTheme.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 800;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
          ),
        ),
        child: Stack(
          children: [
            // Background Orbs
            Positioned(
              top: -100, right: -100,
              child: Container(
                width: 300, height: 300,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withAlpha(77),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Positioned(
              bottom: -50, left: -50,
              child: Container(
                width: 200, height: 200,
                decoration: BoxDecoration(
                  color: AppTheme.accent.withAlpha(51),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            
            // Glass Effect
            Positioned.fill(
              child: BackdropFilter(
                filter: AppTheme.glassBlur,
                child: Container(color: Colors.black.withAlpha(26)),
              ),
            ),

            // Login Form
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: isDesktop ? 420 : 500),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Logo
                          const Icon(Icons.spa_rounded, size: 64, color: AppTheme.primary),
                          const SizedBox(height: 24),
                          Text(
                            'CarePoint',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold, color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'نظام إدارة المركز التجميلي',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white70),
                          ),
                          const SizedBox(height: 48),
                          
                          // Username Field
                          TextFormField(
                            controller: _usernameController,
                            decoration: const InputDecoration(
                              labelText: 'اسم المستخدم',
                              prefixIcon: Icon(Icons.person_outline),
                            ),
                            textInputAction: TextInputAction.next,
                          ),
                          const SizedBox(height: 16),
                          
                          // Password Field
                          TextFormField(
                            controller: _passwordController,
                            decoration: InputDecoration(
                              labelText: 'كلمة المرور',
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                              ),
                            ),
                            obscureText: _obscurePassword,
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) => _signIn(),
                          ),
                          const SizedBox(height: 32),
                          
                          // Login Button
                          SizedBox(
                            height: 50,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _signIn,
                              child: _isLoading
                                  ? const SizedBox(
                                      height: 24, width: 24,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                    )
                                  : const Text('تسجيل الدخول'),
                            ),
                          ),
                          
                          const SizedBox(height: 24),
                          
                          // Hint for default credentials
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.blue.withAlpha(26),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.blue.withAlpha(77)),
                            ),
                            child: const Column(
                              children: [
                                Text('بيانات الدخول الافتراضية:', style: TextStyle(color: Colors.blue, fontSize: 12)),
                                SizedBox(height: 4),
                                Text('المستخدم: admin | كلمة المرور: admin123', 
                                  style: TextStyle(color: Colors.white70, fontSize: 11)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}

class _DebugButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _DebugButton({required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withAlpha(51),
          border: Border.all(color: color.withAlpha(128)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12),
        ),
      ),
    );
  }
}
