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

import 'doctor_registration_screen.dart';
import 'login_screen.dart';

class DoctorSignupScreen extends StatefulWidget {
  final String? prefilledEmail;
  const DoctorSignupScreen({super.key, this.prefilledEmail});

  @override
  State<DoctorSignupScreen> createState() => _DoctorSignupScreenState();
}

class _DoctorSignupScreenState extends State<DoctorSignupScreen> {
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

  Future<void> _registerDoctor() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      loading = true;
      _errorMessage = null;
    });

    try {
      print('🚀 Starting Firebase user creation...');
      print('📧 Email: ${_emailController.text.trim()}');
      print('🔑 Password length: ${_passwordController.text.length}');
      
      // Create Firebase user directly
      final userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      print('✅ Firebase user created successfully');
      print('👤 User UID: ${userCredential.user?.uid}');
      print('📧 User email: ${userCredential.user?.email}');

      if (userCredential.user != null) {
        // Store credentials temporarily for registration screen
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('last_signup_email', _emailController.text.trim());
        await prefs.setString('last_signup_password', _passwordController.text);
        print('💾 Credentials stored in SharedPreferences');
        
        if (mounted) {
          print('🔄 Navigating to doctor registration screen...');
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => DoctorRegistrationScreen(
                signupEmail: _emailController.text.trim(),
                signupPhone: _phoneController.text.trim(),
                signupPassword: _passwordController.text,
                signupCountryCode: '+91',
              ),
            ),
          );
        }
      } else {
        print('❌ User credential is null');
        setState(() {
          _errorMessage = 'Failed to create user account';
        });
      }
    } catch (e) {
      print('❌ Firebase user creation failed: $e');
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  Future<void> _handleGoogleSignup() async {
    setState(() {
      loading = true;
      _errorMessage = null;
    });

    try {
      final GoogleSignIn googleSignIn = GoogleSignIn();
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

      if (googleUser == null) {
        setState(() {
          loading = false;
        });
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
                    'Google account connected! Completing doctor registration...',
                    style: GoogleFonts.poppins(),
                  ),
                  backgroundColor: const Color(0xFF2196F3), // Doctor blue
                  behavior: SnackBarBehavior.floating,
                ),
              );
              
              // Navigate directly to doctor registration with Google data
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => DoctorRegistrationScreen(
                    signupEmail: googleUser.email,
                    signupPhone: '',
                    signupPassword: '',
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
                    'Doctor account already exists. Please login instead.',
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
                  'Google account connected! Completing doctor registration...',
                  style: GoogleFonts.poppins(),
                ),
                backgroundColor: const Color(0xFF2196F3), // Doctor blue
                behavior: SnackBarBehavior.floating,
              ),
            );
            
            // Navigate directly to doctor registration with Google data
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => DoctorRegistrationScreen(
                  signupEmail: '',
                  signupPhone: '',
                  signupPassword: '',
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
      setState(() {
        _errorMessage = e.toString();
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF2196F3), Color(0xFF64B5F6), Color(0xFFE3F2FD)], // Doctor blue gradient
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
                // Header
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      const SizedBox(height: 40),
                      // Logo
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.2),
                        ),
                        child: const Icon(
                          Icons.medical_services,
                          size: 60,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Join as Doctor',
                        style: GoogleFonts.poppins(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Create your doctor account to start helping patients',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          color: Colors.white.withOpacity(0.8),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                
                // Form Container
                Expanded(
                  child: GlassmorphicContainer(
                    width: double.infinity,
                    height: double.infinity,
                    borderRadius: 20,
                    blur: 20,
                    alignment: Alignment.center,
                    border: 2,
                    linearGradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withOpacity(0.1),
                        Colors.white.withOpacity(0.05),
                      ],
                    ),
                    borderGradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withOpacity(0.5),
                        Colors.white.withOpacity(0.2),
                      ],
                    ),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Step Title
                          Text(
                            _currentStep == 1 ? 'Contact Information' : 'Security Setup',
                            style: GoogleFonts.poppins(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF2196F3), // Doctor blue
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _currentStep == 1 
                              ? 'Enter your email or phone number'
                              : 'Create a secure password',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 32),
                          
                          // Step Content
                          if (_currentStep == 1) _buildContactStep(),
                          if (_currentStep == 2) _buildPasswordStep(),
                          
                          const SizedBox(height: 32),
                          
                          // Error Message
                          if (_errorMessage != null)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.red.withOpacity(0.3)),
                              ),
                              child: Text(
                                _errorMessage!,
                                style: GoogleFonts.poppins(
                                  color: Colors.red,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          
                          const SizedBox(height: 24),
                          
                          // Navigation Buttons
                          Row(
                            children: [
                              if (_currentStep > 1)
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () {
                                      setState(() {
                                        _currentStep--;
                                      });
                                    },
                                    style: OutlinedButton.styleFrom(
                                      side: const BorderSide(color: Color(0xFF2196F3)), // Doctor blue
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(28),
                                      ),
                                      padding: const EdgeInsets.symmetric(vertical: 16),
                                    ),
                                    child: Text(
                                      'Previous',
                                      style: GoogleFonts.poppins(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xFF2196F3), // Doctor blue
                                      ),
                                    ),
                                  ),
                                ),
                              if (_currentStep > 1) const SizedBox(width: 16),
                              Expanded(
                                child: CustomButton(
                                  text: _currentStep == 1 ? 'Next' : 'Create Account',
                                  onPressed: _currentStep == 1 
                                    ? () {
                                        if (_canProceedToNextStep()) {
                                          setState(() {
                                            _currentStep++;
                                          });
                                        }
                                      }
                                    : loading ? () {} : _registerDoctor,
                                  color: const Color(0xFF2196F3), // Doctor blue
                                  textColor: Colors.white,
                                ),
                              ),
                            ],
                          ),
                          
                          const SizedBox(height: 24),
                          
                          // Google Sign In
                          if (_currentStep == 1)
                            Column(
                              children: [
                                Row(
                                  children: [
                                    Expanded(child: Divider(color: Colors.grey[300])),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 16),
                                      child: Text(
                                        'OR',
                                        style: GoogleFonts.poppins(
                                          color: Colors.grey[600],
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                    Expanded(child: Divider(color: Colors.grey[300])),
                                  ],
                                ),
                                const SizedBox(height: 24),
                                SizedBox(
                                  width: double.infinity,
                                  height: 50,
                                  child: OutlinedButton.icon(
                                    onPressed: loading ? null : _handleGoogleSignup,
                                    icon: const Icon(EvaIcons.google, color: Color(0xFF2196F3)), // Doctor blue Google icon
                                    label: Text(
                                      'Continue with Google',
                                      style: GoogleFonts.poppins(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xFF2196F3), // Doctor blue
                                      ),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      side: const BorderSide(color: Color(0xFF2196F3)), // Doctor blue border
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(28),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          
                          const SizedBox(height: 24),
                          
                          // Login Link
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
                                onTap: () {
                                  Navigator.pushReplacement(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => const LoginScreen(),
                                    ),
                                  );
                                },
                                child: Text(
                                  'Login',
                                  style: GoogleFonts.poppins(
                                    color: const Color(0xFF2196F3), // Doctor blue
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
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
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContactStep() {
    return Column(
      children: [
        // Email Field
        if (_showEmailField) ...[
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF2196F3), Color(0xFF64B5F6)], // Doctor blue gradient
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
                  prefixIcon: Icon(EvaIcons.emailOutline, color: Color(0xFF2196F3)), // Doctor blue
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
                    colors: [Color(0xFF2196F3), Color(0xFF64B5F6)], // Doctor blue gradient
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
                      colors: [Color(0xFF2196F3), Color(0xFF64B5F6)], // Doctor blue gradient
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
                        prefixIcon: Icon(EvaIcons.phoneOutline, color: Color(0xFF2196F3)), // Doctor blue
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
      ],
    );
  }

  Widget _buildPasswordStep() {
    return Column(
      children: [
        // Password Field
        Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF2196F3), Color(0xFF64B5F6)], // Doctor blue gradient
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
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Password',
                prefixIcon: Icon(EvaIcons.lockOutline, color: Color(0xFF2196F3)), // Doctor blue
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              ),
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
        
        const SizedBox(height: 12),
        
        // Confirm Password Field
        Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF2196F3), Color(0xFF64B5F6)], // Doctor blue gradient
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
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Confirm Password',
                prefixIcon: Icon(EvaIcons.lockOutline, color: Color(0xFF2196F3)), // Doctor blue
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              ),
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
      ],
    );
  }

  bool _canProceedToNextStep() {
    if (_currentStep == 1) {
      final email = _emailController.text.trim();
      final phone = _phoneController.text.trim();
      
      // Check if either email or phone is provided
      if (email.isEmpty && phone.isEmpty) {
        return false;
      }
      
      // If email is provided, validate email format
      if (email.isNotEmpty) {
        final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
        if (!emailRegex.hasMatch(email)) {
          return false;
        }
      }
      
      // If phone is provided, validate phone format (basic check)
      if (phone.isNotEmpty && phone.length < 10) {
        return false;
      }
      
      return true;
    } else if (_currentStep == 2) {
      // For step 2, check if password fields are filled and match
      final password = _passwordController.text;
      final verifyPassword = _verifyPasswordController.text;
      
      if (password.isEmpty || verifyPassword.isEmpty) {
        return false;
      }
      
      if (password != verifyPassword) {
        return false;
      }
      
      if (password.length < 6) {
        return false;
      }
      
      return true;
    }
    return true;
  }
} 