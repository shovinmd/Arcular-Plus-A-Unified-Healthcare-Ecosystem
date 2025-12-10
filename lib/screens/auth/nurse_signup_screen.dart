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

import 'nurse_registration_screen.dart';
import 'login_screen.dart';

class NurseSignupScreen extends StatefulWidget {
  final String? prefilledEmail;
  const NurseSignupScreen({super.key, this.prefilledEmail});

  @override
  State<NurseSignupScreen> createState() => _NurseSignupScreenState();
}

class _NurseSignupScreenState extends State<NurseSignupScreen> {
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
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _registerNurse() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => loading = true);

    try {
      // Create Firebase user
      final UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (userCredential.user != null) {
        // Save user type to SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_type', 'nurse');
        await prefs.setString('user_uid', userCredential.user!.uid);

        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => NurseRegistrationScreen(
                signupEmail: _emailController.text.trim(),
                signupPhone: _phoneController.text.trim(),
                signupPassword: _passwordController.text,
                signupCountryCode: '+91',
              ),
            ),
          );
        }
      }
    } catch (e) {
      setState(() => loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Registration failed: $e',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() => loading = true);

    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        setState(() => loading = false);
        return;
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Try to sign in first to check if user exists
      try {
        final UserCredential userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
        final User? user = userCredential.user;

        if (user != null) {
          // Check if this is a new user or existing user
          final isNewUser = userCredential.additionalUserInfo?.isNewUser ?? false;
          
          if (isNewUser) {
            // This is a new user - directly navigate to registration with Google data
            setState(() => loading = false);
            
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Google account connected! Completing nurse registration...',
                    style: GoogleFonts.poppins(),
                  ),
                  backgroundColor: const Color(0xFFE91E63), // Nurse pink color
                  behavior: SnackBarBehavior.floating,
                ),
              );
              
              // Navigate directly to nurse registration with Google data
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => NurseRegistrationScreen(
                    signupEmail: _emailController.text.trim(),
                    signupPhone: _phoneController.text.trim(),
                    signupPassword: _passwordController.text,
                    signupCountryCode: '+91',
                  ),
                ),
              );
            }
          } else {
            // This is an existing user - they should login instead
            setState(() => loading = false);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Nurse account already exists. Please login instead.',
                    style: GoogleFonts.poppins(),
                  ),
                  backgroundColor: Colors.orange,
                  behavior: SnackBarBehavior.floating,
                ),
              );
              // Navigate to login screen
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              );
            }
          }
        }
      } catch (e) {
        // If sign in fails, it might be a new user - try to create account
        if (e.toString().contains('user-not-found') || e.toString().contains('invalid-credential')) {
          // This is likely a new user - directly navigate to registration
          setState(() => loading = false);
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Google account connected! Completing nurse registration...',
                  style: GoogleFonts.poppins(),
                ),
                backgroundColor: const Color(0xFFE91E63), // Nurse pink color
                behavior: SnackBarBehavior.floating,
              ),
            );
            
            // Navigate directly to nurse registration with Google data
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => NurseRegistrationScreen(
                  signupEmail: _emailController.text.trim(),
                  signupPhone: _phoneController.text.trim(),
                  signupPassword: _passwordController.text,
                  signupCountryCode: '+91',
                ),
              ),
            );
          }
        } else {
          // Re-throw the error
          rethrow;
        }
      }
    } catch (e) {
      setState(() => loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Google sign-in failed: $e',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
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
            colors: [Color(0xFFE91E63), Color(0xFFF48FB1), Color(0xFFFCE4EC)], // Nurse pink gradient
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
                height: 800,
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
                    const Color(0xFFE91E63).withOpacity(0.3),
                    const Color(0xFFF48FB1).withOpacity(0.3),
                  ],
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Logo
                        Image.asset(
                          'assets/images/logo.png',
                          height: 120,
                          width: 120,
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Join Arcular+',
                          style: GoogleFonts.poppins(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFFE91E63),
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Create your nurse account',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 32),
                        
                        // Email Field
                        if (_showEmailField) ...[
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey[300]!),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  child: Icon(
                                    Icons.email_outlined,
                                    color: const Color(0xFFE91E63),
                                    size: 20,
                                  ),
                                ),
                                Expanded(
                                  child: TextFormField(
                                    controller: _emailController,
                                    keyboardType: TextInputType.emailAddress,
                                    decoration: const InputDecoration(
                                      hintText: 'Email',
                                      border: InputBorder.none,
                                      contentPadding: EdgeInsets.symmetric(vertical: 16),
                                    ),
                                    validator: (value) {
                                      if (value == null || value.trim().isEmpty) {
                                        return 'Email is required';
                                      }
                                      if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                                        return 'Please enter a valid email';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                        
                        // Phone Field
                        if (_showPhoneField) ...[
                          Row(
                            children: [
                              // Country Code Button
                              Container(
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFFE91E63), Color(0xFFF48FB1)],
                                    begin: Alignment.centerLeft,
                                    end: Alignment.centerRight,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                                  child: Text(
                                    '+91',
                                    style: GoogleFonts.poppins(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Phone Input Field
                              Expanded(
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.grey[300]!),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        child: Icon(
                                          Icons.phone_outlined,
                                          color: const Color(0xFFE91E63),
                                          size: 20,
                                        ),
                                      ),
                                      Expanded(
                                        child: TextFormField(
                                          controller: _phoneController,
                                          keyboardType: TextInputType.phone,
                                          decoration: const InputDecoration(
                                            hintText: 'Phone Number',
                                            border: InputBorder.none,
                                            contentPadding: EdgeInsets.symmetric(vertical: 16),
                                          ),
                                          validator: (value) {
                                            if (value == null || value.trim().isEmpty) {
                                              return 'Phone number is required';
                                            }
                                            return null;
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                        ],
                        
                        // Password Fields
                        if (_showPasswordFields) ...[
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey[300]!),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  child: Icon(
                                    Icons.lock_outline,
                                    color: const Color(0xFFE91E63),
                                    size: 20,
                                  ),
                                ),
                                Expanded(
                                  child: TextFormField(
                                    controller: _passwordController,
                                    obscureText: true,
                                    decoration: const InputDecoration(
                                      hintText: 'Password',
                                      border: InputBorder.none,
                                      contentPadding: EdgeInsets.symmetric(vertical: 16),
                                    ),
                                    validator: (value) {
                                      if (value == null || value.trim().isEmpty) {
                                        return 'Password is required';
                                      }
                                      if (value.length < 6) {
                                        return 'Password must be at least 6 characters';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey[300]!),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  child: Icon(
                                    Icons.lock_outline,
                                    color: const Color(0xFFE91E63),
                                    size: 20,
                                  ),
                                ),
                                Expanded(
                                  child: TextFormField(
                                    controller: _verifyPasswordController,
                                    obscureText: true,
                                    decoration: const InputDecoration(
                                      hintText: 'Confirm Password',
                                      border: InputBorder.none,
                                      contentPadding: EdgeInsets.symmetric(vertical: 16),
                                    ),
                                    validator: (value) {
                                      if (value == null || value.trim().isEmpty) {
                                        return 'Please confirm your password';
                                      }
                                      if (value != _passwordController.text) {
                                        return 'Passwords do not match';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],
                        
                        // Continue Button
                        if (_showPasswordFields) ...[
                          Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFE91E63), Color(0xFFF48FB1)],
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ElevatedButton(
                              onPressed: loading ? () {} : _registerNurse,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    loading ? 'Creating Account...' : 'Continue',
                                    style: GoogleFonts.poppins(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Icon(
                                    Icons.arrow_forward,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                        
                        // Google Sign In Button
                        Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE91E63)),
                          ),
                          child: ElevatedButton.icon(
                            onPressed: loading ? () {} : _signInWithGoogle,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            icon: Text(
                              'G',
                              style: GoogleFonts.poppins(
                                color: const Color(0xFFE91E63),
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            label: Text(
                              loading ? 'Connecting...' : 'Continue with Google',
                              style: GoogleFonts.poppins(
                                color: const Color(0xFFE91E63),
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 24),
                        
                        // Login link
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Already have an account? ',
                              style: GoogleFonts.poppins(
                                color: Colors.grey[600],
                                fontSize: 14,
                              ),
                            ),
                            GestureDetector(
                              onTap: () => Navigator.pop(context),
                              child: Text(
                                'Login',
                                style: GoogleFonts.poppins(
                                  color: const Color(0xFFE91E63),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          ],
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