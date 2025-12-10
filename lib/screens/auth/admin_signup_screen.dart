import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/input_field.dart';
import 'package:glassmorphism/glassmorphism.dart';
import 'package:eva_icons_flutter/eva_icons_flutter.dart';

import 'admin_registration_screen.dart';
import 'login_screen.dart';

class AdminSignupScreen extends StatefulWidget {
  final String? prefilledEmail;
  const AdminSignupScreen({super.key, this.prefilledEmail});

  @override
  State<AdminSignupScreen> createState() => _AdminSignupScreenState();
}

class _AdminSignupScreenState extends State<AdminSignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _auth = AuthService();

  // Form Fields
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _verifyPasswordController = TextEditingController();
  bool loading = false;
  String? _errorMessage;
  bool _obscurePassword = true;
  bool _obscureVerifyPassword = true;

  @override
  void initState() {
    super.initState();
    if (widget.prefilledEmail != null && widget.prefilledEmail!.isNotEmpty) {
      _emailController.text = widget.prefilledEmail!;
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _verifyPasswordController.dispose();
    super.dispose();
  }

  Future<void> _registerAdmin() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      loading = true;
      _errorMessage = null;
    });

    try {
      // Create Firebase user
      final userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (userCredential.user != null) {
        // Save admin type to SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_type', 'admin');
        await prefs.setString('user_uid', userCredential.user!.uid);

        if (mounted) {
          // Navigate to admin registration screen
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
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage = 'Registration failed';
      if (e.code == 'weak-password') {
        errorMessage = 'Password is too weak';
      } else if (e.code == 'email-already-in-use') {
        errorMessage = 'Email is already registered';
      } else if (e.code == 'invalid-email') {
        errorMessage = 'Invalid email address';
      }
      setState(() {
        _errorMessage = errorMessage;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Registration failed: $e';
      });
    } finally {
      setState(() {
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Admin Registration',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF1565C0), // Admin blue
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1565C0), Color(0xFF42A5F5), Color(0xFFE3F2FD)], // Admin blue gradient
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header
                        Text(
                          'Admin Account Setup',
                          style: GoogleFonts.poppins(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Create your admin account to manage the system',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            color: Colors.white.withOpacity(0.8),
                          ),
                        ),
                        const SizedBox(height: 32),
                        
                        // Email Field
                        Container(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF1565C0), Color(0xFF42A5F5)], // Admin blue gradient
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: TextFormField(
                              controller: _emailController,
                              decoration: InputDecoration(
                                labelText: 'Email Address *',
                                prefixIcon: const Icon(EvaIcons.emailOutline, color: Color(0xFF1565C0)),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                              ),
                              keyboardType: TextInputType.emailAddress,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter email address';
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
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: TextFormField(
                              controller: _passwordController,
                              decoration: InputDecoration(
                                labelText: 'Password *',
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
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                              ),
                              obscureText: _obscurePassword,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter password';
                                }
                                if (value.length < 6) {
                                  return 'Password must be at least 6 characters';
                                }
                                return null;
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        
                        // Verify Password Field
                        Container(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF1565C0), Color(0xFF42A5F5)], // Admin blue gradient
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: TextFormField(
                              controller: _verifyPasswordController,
                              decoration: InputDecoration(
                                labelText: 'Verify Password *',
                                prefixIcon: const Icon(EvaIcons.lockOutline, color: Color(0xFF1565C0)),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscureVerifyPassword ? EvaIcons.eyeOffOutline : EvaIcons.eyeOutline,
                                    color: const Color(0xFF1565C0),
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _obscureVerifyPassword = !_obscureVerifyPassword;
                                    });
                                  },
                                ),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                              ),
                              obscureText: _obscureVerifyPassword,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please verify password';
                                }
                                if (value != _passwordController.text) {
                                  return 'Passwords do not match';
                                }
                                return null;
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
                        
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
                        const SizedBox(height: 24),
                        
                        // Register Button
                        Container(
                          width: double.infinity,
                          height: 50,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF1565C0), Color(0xFF42A5F5)], // Admin blue gradient
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                            borderRadius: BorderRadius.circular(25),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF1565C0).withOpacity(0.3),
                                blurRadius: 15,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                            onPressed: loading ? null : _registerAdmin,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(25),
                              ),
                              shadowColor: Colors.transparent,
                            ),
                            child: loading
                                ? const CircularProgressIndicator(color: Colors.white)
                                : Text(
                                    'Create Admin Account',
                                    style: GoogleFonts.poppins(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        
                        // Login Link
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Already have an admin account? ',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                color: Colors.white.withOpacity(0.8),
                              ),
                            ),
                            GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const LoginScreen(),
                                  ),
                                );
                              },
                              child: Text(
                                'Login',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
} 