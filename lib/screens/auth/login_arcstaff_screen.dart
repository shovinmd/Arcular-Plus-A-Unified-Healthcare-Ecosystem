import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:arcular_plus/services/auth_service.dart';
import 'package:arcular_plus/services/api_service.dart';
import 'package:arcular_plus/models/user_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../arcstaff/arcstaff_dashboard_screen.dart';

class LoginArcStaffScreen extends StatefulWidget {
  const LoginArcStaffScreen({Key? key}) : super(key: key);

  @override
  State<LoginArcStaffScreen> createState() => _LoginArcStaffScreenState();
}

class _LoginArcStaffScreenState extends State<LoginArcStaffScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();
  bool _loading = false;
  String? _errorMessage;

  Future<void> _login() async {
    setState(() {
      _errorMessage = null;
    });
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      setState(() {
        _errorMessage = 'Please fill all fields';
      });
      return;
    }
    setState(() => _loading = true);
    try {
      final userModel = await _authService.signIn(
        _emailController.text.trim(),
        _passwordController.text,
      );
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          _errorMessage = 'Firebase login failed!';
          _loading = false;
        });
        return;
      }
      final backendUser = await ApiService.getUserInfo(user.uid);
      if (backendUser == null) {
        setState(() {
          _errorMessage = 'User not found. Please contact admin.';
          _loading = false;
        });
        return;
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_email', backendUser.email);
      await prefs.setString('user_type', backendUser.type);
      await prefs.setString('user_role', backendUser.role ?? '');
      // Only allow arcstaff or superadmin
      final role = (backendUser.role ?? '').toLowerCase();
      if (role == 'arcstaff') {
        // TODO: Navigate to ARC Staff dashboard
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const ArcStaffDashboardScreen()),
        );
      } else if (role == 'superadmin') {
        // TODO: Navigate to Superadmin dashboard
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Superadmin Dashboard coming soon!')),
        );
      } else {
        setState(() {
          _errorMessage = 'Access denied: Not ARC Staff or Superadmin.';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Login failed: ${e.toString()}';
      });
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: Center(
        child: SingleChildScrollView(
          child: Container(
            padding: const EdgeInsets.all(32),
            constraints: const BoxConstraints(maxWidth: 400),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'assets/images/logo.png',
                  height: 80,
                  width: 80,
                ),
                const SizedBox(height: 16),
                const Text(
                  'ARC Staff Login',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0057A0),
                  ),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email_outlined),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    prefixIcon: Icon(Icons.lock_outline),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                if (_errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.red, fontSize: 14),
                    ),
                  ),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _login,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0057A0),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    child: _loading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('Login'),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  '© 2025 Arcular+ Healthcare Platform',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
} 