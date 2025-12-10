import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/input_field.dart';
import 'package:glassmorphism/glassmorphism.dart';
import 'package:eva_icons_flutter/eva_icons_flutter.dart';

import 'hospital_registration_screen.dart';
import 'login_screen.dart';

class HospitalSignupScreen extends StatefulWidget {
  final String? prefilledEmail;
  const HospitalSignupScreen({super.key, this.prefilledEmail});

  @override
  State<HospitalSignupScreen> createState() => _HospitalSignupScreenState();
}

class _HospitalSignupScreenState extends State<HospitalSignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _auth = AuthService();

  // Form Fields
  String name = '';
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _verifyPasswordController = TextEditingController();
  String _countryCode = '+91';
  bool loading = false;
  String? _errorMessage;
  bool _isGoogleSignup = false;
  String? _verificationId;
  bool _otpSent = false;
  final TextEditingController _otpController = TextEditingController();
  bool _showPasswordFields = true;
  bool _showEmailField = true;
  bool _showPhoneField = true;
  int _currentStep = 1; // 1 for email/phone, 2 for password

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _emailController.text = user.email ?? '';
      _isGoogleSignup = true;
      _showEmailField = false; // Hide email field for Google sign-up
      _showPasswordFields = false; // Hide password fields for Google sign-up
    } else if (widget.prefilledEmail != null && widget.prefilledEmail!.isNotEmpty) {
      _emailController.text = widget.prefilledEmail!;
    }
    _emailController.addListener(_handleEmailChange);
    _phoneController.addListener(_handlePhoneChange);
  }

  void _handleEmailChange() {
    final email = _emailController.text.trim();
    if (email.isNotEmpty) {
      setState(() {
        _showPasswordFields = true;
        _showPhoneField = false;
      });
    } else {
      setState(() {
        _showPasswordFields = false;
        _showPhoneField = true;
      });
    }
  }

  void _handlePhoneChange() {
    final phone = _phoneController.text.trim();
    if (phone.isNotEmpty) {
      setState(() {
        _showPasswordFields = true;
        _showEmailField = false;
      });
    } else {
      setState(() {
        _showPasswordFields = false;
        _showEmailField = true;
      });
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _verifyPasswordController.dispose();
    super.dispose();
  }

  Future<void> _registerHospital() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => loading = true);

    try {
      print('🚀 Starting hospital signup...');
      print('📧 Email: ${_emailController.text.trim()}');
      print('📱 Phone: ${_phoneController.text.trim()}');
      
      // Store credentials temporarily for registration screen
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_signup_email', _emailController.text.trim());
      await prefs.setString('last_signup_password', _passwordController.text);
      print('💾 Credentials stored in SharedPreferences');
      
      // Navigate to hospital registration screen with user data
      if (mounted) {
        print('🔄 Navigating to hospital registration screen...');
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => HospitalRegistrationScreen(
              signupEmail: _emailController.text.trim(),
              signupPhone: _phoneController.text.trim(),
              signupPassword: _passwordController.text,
              signupCountryCode: _countryCode,
            ),
          ),
        );
      }
    } catch (e) {
      print('❌ Hospital signup failed: $e');
      setState(() => loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Signup failed: $e',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _handleGoogleSignup() async {
    setState(() => loading = true);
    
    try {
      print('🔐 Starting Google sign-up process...');
      
      // Step 1: Get Google account
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        print('❌ Google sign-in cancelled by user');
        setState(() => loading = false);
        return;
      }

      print('✅ Google account selected: ${googleUser.email}');
      
      // Step 2: Get authentication tokens
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      print('🔑 Google authentication tokens obtained');

      // Step 3: Sign in to Firebase with Google credentials
      try {
        final UserCredential userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
        final User? user = userCredential.user;

        if (user != null) {
          print('✅ Firebase user authenticated: ${user.uid}');
          
          // Check if this is a new user
          final isNewUser = userCredential.additionalUserInfo?.isNewUser ?? false;
          
          if (isNewUser) {
            print('🆕 New user detected, proceeding to registration');
            setState(() => loading = false);
            
            if (mounted) {
              // Show success message
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Google account connected! Completing hospital registration...',
                    style: GoogleFonts.poppins(),
                  ),
                  backgroundColor: const Color(0xFF32CCBC),
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 2),
                ),
              );
              
              // Navigate to hospital registration
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => HospitalRegistrationScreen(
                    signupEmail: user.email ?? '',
                    signupPhone: '', // Google users will add phone in registration
                    signupPassword: '', // No password needed for Google users
                    signupCountryCode: _countryCode,
                  ),
                ),
              );
            }
          } else {
            print('⚠️ Existing user detected, redirecting to login');
            setState(() => loading = false);
            
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Hospital account already exists. Please login instead.',
                    style: GoogleFonts.poppins(),
                  ),
                  backgroundColor: Colors.orange,
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 3),
                ),
              );
              
              // Navigate to login screen
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              );
            }
          }
        } else {
          throw Exception('Failed to create Firebase user');
        }
        
      } catch (signInError) {
        // If sign in fails, it might be a new user - try to create account
        if (signInError.toString().contains('user-not-found') || signInError.toString().contains('invalid-credential')) {
          // This is likely a new user - directly navigate to registration
          print('🆕 New user detected from error, proceeding to registration');
          setState(() => loading = false);
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Google account connected! Completing hospital registration...',
                  style: GoogleFonts.poppins(),
                ),
                backgroundColor: const Color(0xFF32CCBC),
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 2),
              ),
            );
            
            // Navigate directly to hospital registration with Google data
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => HospitalRegistrationScreen(
                  signupEmail: googleUser.email,
                  signupPhone: '', // Google users will add phone in registration
                  signupPassword: '', // No password needed for Google users
                  signupCountryCode: _countryCode,
                ),
              ),
            );
          }
        } else {
          // Re-throw the error for other types of failures
          rethrow;
        }
      }
      
    } catch (e) {
      print('❌ Google sign-up error: $e');
      setState(() => loading = false);
      
      if (mounted) {
        String errorMessage = 'Google sign-in failed';
        
        // Provide more specific error messages
        if (e.toString().contains('network')) {
          errorMessage = 'Network error. Please check your internet connection.';
        } else if (e.toString().contains('cancelled')) {
          errorMessage = 'Google sign-in was cancelled.';
        } else if (e.toString().contains('popup_closed')) {
          errorMessage = 'Google sign-in popup was closed. Please try again.';
        } else {
          errorMessage = 'Google sign-in failed: ${e.toString().split(':').last.trim()}';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage, style: GoogleFonts.poppins()),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF4CAF50), Color(0xFF81C784), Color(0xFFE8F5E8)], // Hospital green gradient
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: GlassmorphicContainer(
                width: double.infinity,
                height: 800, // Increased height to prevent overflow
                borderRadius: 20,
                blur: 20,
                alignment: Alignment.center,
                border: 2,
                linearGradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withOpacity(0.9),
                    Colors.white.withOpacity(0.8),
                  ],
                  stops: [0.1, 1],
                ),
                borderGradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFF32CCBC).withOpacity(0.3), // Green teal
                    const Color(0xFF90F7EC).withOpacity(0.3), // Green teal
                  ],
                ),
                child: SingleChildScrollView( // Add scrolling to prevent overflow
                  padding: const EdgeInsets.all(24.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Logo without circle background - bigger size like select user type
                        Image.asset(
                          'assets/images/logo.png',
                          height: 207, // Increased from 162 to 207 (45 pixels bigger)
                          width: 207, // Increased from 162 to 207 (45 pixels bigger)
                        ),
                        const SizedBox(height: 16), // Reduced from 20
                        Text(
                          'Join Arcular+',
                          style: GoogleFonts.poppins(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF32CCBC), // Green teal
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 6), // Reduced from 8
                        Text(
                          'Create your hospital account to start managing operations',
                          style: GoogleFonts.poppins(
                            fontSize: 13, // Reduced from 14
                            color: Colors.grey[600],
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20), // Reduced from 30
                        
                        // Email Field
                        if (_showEmailField) ...[
                          Container(
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF4CAF50), Color(0xFF81C784)], // Hospital green gradient
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white, // Enabled background
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: TextFormField(
                                controller: _emailController,
                                enabled: true, // Enable the field for editing
                                decoration: const InputDecoration(
                                  labelText: 'Email',
                                  prefixIcon: Icon(EvaIcons.emailOutline, color: Color(0xFF4CAF50)), // Hospital green
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
                          const SizedBox(height: 12), // Reduced from 16
                        ],
                        
                        // Phone Field
                        if (_showPhoneField) ...[
                          Row(
                            children: [
                              Container(
                                width: 80,
                                height: 50,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFF4CAF50), Color(0xFF81C784)], // Hospital green gradient
                                    begin: Alignment.centerLeft,
                                    end: Alignment.centerRight,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Center(
                                  child: Text(
                                    _countryCode,
                                    style: GoogleFonts.poppins(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [Color(0xFF4CAF50), Color(0xFF81C784)], // Hospital green gradient
                                      begin: Alignment.centerLeft,
                                      end: Alignment.centerRight,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.white, // Enabled background
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: TextFormField(
                                      controller: _phoneController,
                                      enabled: true, // Enable the field for editing
                                      decoration: const InputDecoration(
                                        labelText: 'Phone Number',
                                        prefixIcon: Icon(EvaIcons.phoneOutline, color: Color(0xFF4CAF50)), // Hospital green
                                        border: InputBorder.none,
                                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                      ),
                                      keyboardType: TextInputType.phone,
                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
                                          return 'Please enter your phone number';
                                        }
                                        if (value.length < 10) {
                                          return 'Please enter a valid phone number';
                                        }
                                        return null;
                                      },
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12), // Reduced from 16
                        ],
                        
                        // Password Fields
                        if (_showPasswordFields) ...[
                          Container(
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF4CAF50), Color(0xFF81C784)], // Hospital green gradient
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
                                decoration: const InputDecoration(
                                  labelText: 'Password',
                                  prefixIcon: Icon(EvaIcons.lockOutline, color: Color(0xFF4CAF50)), // Hospital green
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                ),
                                obscureText: true,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter a password';
                                  }
                                  if (value.length < 6) {
                                    return 'Password must be at least 6 characters';
                                  }
                                  return null;
                                },
                              ),
                            ),
                          ),
                          const SizedBox(height: 12), // Reduced from 16
                          Container(
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF4CAF50), Color(0xFF81C784)], // Hospital green gradient
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
                                decoration: const InputDecoration(
                                  labelText: 'Confirm Password',
                                  prefixIcon: Icon(EvaIcons.lockOutline, color: Color(0xFF4CAF50)), // Hospital green
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                ),
                                obscureText: true,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please confirm your password';
                                  }
                                  if (value != _passwordController.text) {
                                    return 'Passwords do not match';
                                  }
                                  return null;
                                },
                              ),
                            ),
                          ),
                          const SizedBox(height: 12), // Reduced from 16
                        ],
                        
                        const SizedBox(height: 20), // Reduced from 24
                        
                        // Continue Button
                        Container(
                          width: double.infinity,
                          height: 50,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF4CAF50), Color(0xFF81C784)], // Hospital green gradient
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                            borderRadius: BorderRadius.circular(28),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF4CAF50).withOpacity(0.3), // Hospital green shadow
                                blurRadius: 15,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                            onPressed: loading ? null : _registerHospital,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(28),
                              ),
                              shadowColor: Colors.transparent,
                            ),
                            child: loading
                                ? const CircularProgressIndicator(color: Colors.white)
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.arrow_forward, size: 20),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Continue',
                                        style: GoogleFonts.poppins(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                        
                        const SizedBox(height: 20),
                        
                        // Google Sign In Button
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: OutlinedButton.icon(
                            onPressed: loading ? null : _handleGoogleSignup,
                            icon: const Icon(EvaIcons.google, color: Color(0xFF4CAF50)), // Hospital green Google icon
                            label: Text(
                              'Continue with Google',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF4CAF50), // Hospital green
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFF4CAF50)), // Hospital green border
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(28),
                              ),
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 20),
                        
                        // Login Link
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Already have an account? ',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                              GestureDetector(
                                onTap: () {
                                  Navigator.pushReplacement(
                                    context,
                                    MaterialPageRoute(builder: (context) => const LoginScreen()),
                                  );
                                },
                                child: Text(
                                  'Login',
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF4CAF50), // Hospital green
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
              ),
            ),
          ),
        ),
      ),
    );
  }
} 