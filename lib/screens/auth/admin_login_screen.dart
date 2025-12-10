import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import 'package:glassmorphism/glassmorphism.dart';
import 'package:eva_icons_flutter/eva_icons_flutter.dart';

import 'admin_registration_screen.dart';
import 'admin_signup_screen.dart';
import '../admin/admin_dashboard_screen.dart';

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _authService = AuthService();

  // Form Fields
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _loading = false;
  String? _errorMessage;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    // Pre-fill with admin credentials if available
    _emailController.text = 'admin@gmail.com';
    _passwordController.text = 'admin123';
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleAdminLogin() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      // Sign in with Firebase
      final userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (userCredential.user != null) {
        // Check if admin exists in backend
        final adminUser = await ApiService.getAdminInfo(userCredential.user!.uid);
        
        if (adminUser != null) {
          // Admin exists, save to SharedPreferences
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('user_type', 'admin');
          await prefs.setString('user_uid', userCredential.user!.uid);
          await prefs.setString('user_gender', 'Other');
          
          if (mounted) {
            // Navigate to admin dashboard
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const AdminDashboardScreen()),
              (route) => false,
            );
          }
        } else {
          // Admin doesn't exist in backend, show message and go to registration
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Admin details not found. Please complete your profile.'),
                backgroundColor: const Color(0xFF1565C0),
                duration: const Duration(seconds: 3),
              ),
            );
            
            // Navigate to admin registration after a short delay
            Future.delayed(const Duration(seconds: 1), () {
              if (mounted) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AdminRegistrationScreen(
                      signupEmail: _emailController.text.trim(),
                      signupPassword: _passwordController.text,
                    ),
                  ),
                );
              }
            });
          }
        }
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage = 'Login failed';
      if (e.code == 'user-not-found') {
        errorMessage = 'User not found. Please contact admin.';
      } else if (e.code == 'wrong-password') {
        errorMessage = 'Invalid password.';
      } else if (e.code == 'invalid-email') {
        errorMessage = 'Invalid email address.';
      } else if (e.code == 'user-disabled') {
        errorMessage = 'Account has been disabled.';
      }
      setState(() {
        _errorMessage = errorMessage;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Login failed: $e';
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1565C0), Color(0xFF42A5F5), Color(0xFFE3F2FD)], // Admin blue gradient
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: GlassmorphicContainer(
                  width: double.infinity,
                  height: MediaQuery.of(context).size.height * 0.7,
                  borderRadius: 32,
                  blur: 12,
                  alignment: Alignment.center,
                  border: 1.5,
                  linearGradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withOpacity(0.9),
                      Colors.white.withOpacity(0.8),
                    ],
                  ),
                  borderGradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      const Color(0xFF1565C0).withOpacity(0.3),
                      const Color(0xFF42A5F5).withOpacity(0.3),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Logo and Title
                          Image.asset(
                            'assets/images/logo.png',
                            height: 80,
                            width: 80,
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'Admin Login',
                            style: GoogleFonts.poppins(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF1565C0),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Access your admin dashboard',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 40),
                          
                          // Email Field
                          Container(
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF1565C0), Color(0xFF42A5F5)], // Admin blue gradient
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                              ),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Container(
                              margin: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: TextFormField(
                                controller: _emailController,
                                decoration: InputDecoration(
                                  hintText: 'Email',
                                  prefixIcon: const Icon(EvaIcons.emailOutline, color: Color(0xFF1565C0)),
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                                ),
                                keyboardType: TextInputType.emailAddress,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter your email';
                                  }
                                  if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                                    return 'Please enter a valid email';
                                  }
                                  return null;
                                },
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          
                          // Password Field
                          Container(
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF1565C0), Color(0xFF42A5F5)], // Admin blue gradient
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                              ),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Container(
                              margin: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: TextFormField(
                                controller: _passwordController,
                                decoration: InputDecoration(
                                  hintText: 'Password',
                                  prefixIcon: const Icon(EvaIcons.lockOutline, color: Color(0xFF1565C0)),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscurePassword ? EvaIcons.eyeOffOutline : EvaIcons.eyeOutline,
                                      color: const Color(0xFF1565C0),
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _obscurePassword = !_obscurePassword;
                                      });
                                    },
                                  ),
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                                ),
                                obscureText: _obscurePassword,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter your password';
                                  }
                                  return null;
                                },
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          
                          // Error Message
                          if (_errorMessage != null)
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.red.withOpacity(0.3)),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.error, color: Colors.red, size: 20),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _errorMessage!,
                                      style: GoogleFonts.poppins(
                                        color: Colors.red,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          const SizedBox(height: 32),
                          
                          // Login Button
                          Container(
                            width: double.infinity,
                            height: 56,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF1565C0), Color(0xFF42A5F5)], // Admin blue gradient
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                              ),
                              borderRadius: BorderRadius.circular(28),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF1565C0).withOpacity(0.3),
                                  blurRadius: 15,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: ElevatedButton(
                              onPressed: _loading ? null : _handleAdminLogin,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(28),
                                ),
                                shadowColor: Colors.transparent,
                              ),
                              child: _loading
                                  ? const CircularProgressIndicator(color: Colors.white)
                                  : Text(
                                      'Login',
                                      style: GoogleFonts.poppins(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          
                          // Register Link
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'New admin? ',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                              GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const AdminSignupScreen(),
                                    ),
                                  );
                                },
                                child: Text(
                                  'Register',
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF1565C0),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 40),
                          
                          // Copyright
                          Text(
                            '© 2025 Arcular+ Healthcare Platform',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.grey[500],
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
} 