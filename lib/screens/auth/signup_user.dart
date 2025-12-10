import 'package:arcular_plus/utils/user_type_enum.dart';
import 'package:arcular_plus/screens/auth/login_screen.dart';
import 'package:arcular_plus/screens/user/dashboard_user.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:arcular_plus/services/auth_service.dart';
import 'package:arcular_plus/services/api_service.dart';
import 'package:arcular_plus/models/user_model.dart';
import 'package:arcular_plus/utils/validators.dart';
import 'patient_registration_screen.dart';
import 'doctor_registration_screen.dart';
import 'hospital_registration_screen.dart';
import 'lab_registration_screen.dart';
import 'pharmacy_registration_screen.dart';
import 'package:arcular_plus/config/themes.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../../widgets/custom_button.dart';
import '../../widgets/input_field.dart';
import 'package:glassmorphism/glassmorphism.dart';
import 'package:eva_icons_flutter/eva_icons_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_sign_in/google_sign_in.dart';

class SignupScreen extends StatefulWidget {
  final String? prefilledEmail;
  const SignupScreen({super.key, this.prefilledEmail});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
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

  Future<void> _registerUser() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => loading = true);

    try {
      // Check if user already exists
      final existingUser = await ApiService.getUserInfoByEmail(_emailController.text.trim());
      if (existingUser != null) {
        setState(() => loading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'User with this email already exists. Please login.',
                style: GoogleFonts.poppins(),
              ),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }

      // Check if phone number already exists
      final existingPhone = await ApiService.getUserInfoByPhone(_phoneController.text.trim());
      if (existingPhone != null) {
        setState(() => loading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'User with this phone number already exists. Please login.',
                style: GoogleFonts.poppins(),
              ),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }

      // Create Firebase user
      final UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (userCredential.user != null) {
        // Navigate to patient registration screen with user data
        if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
              builder: (context) => PatientRegistrationScreen(
                signupEmail: _emailController.text.trim(),
                signupPhone: _phoneController.text.trim(),
                signupPassword: _passwordController.text,
            signupCountryCode: _countryCode,
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

  Future<void> _handleGoogleSignup() async {
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
                    'Google account connected! Completing registration...',
                    style: GoogleFonts.poppins(),
                  ),
                  backgroundColor: const Color(0xFF32CCBC), // Green teal color to match theme
                  behavior: SnackBarBehavior.floating,
                ),
              );
              
              // Navigate directly to patient registration with Google data
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => PatientRegistrationScreen(
                    signupEmail: user.email ?? '',
                    signupPhone: '', // Google users will add phone in registration
                    signupPassword: '', // No password needed for Google users
                    signupCountryCode: _countryCode,
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
                    'Account already exists. Please login instead.',
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
                  'Google account connected! Completing registration...',
                  style: GoogleFonts.poppins(),
                ),
                backgroundColor: const Color(0xFF32CCBC), // Green teal color to match theme
                behavior: SnackBarBehavior.floating,
              ),
            );
            
            // Navigate directly to patient registration with Google data
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => PatientRegistrationScreen(
                  signupEmail: googleUser.email,
                  signupPhone: '', // Google users will add phone in registration
                  signupPassword: '', // No password needed for Google users
                  signupCountryCode: _countryCode,
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

  Future<void> _startPhoneAuth(String phoneNumber) async {
    setState(() => loading = true);
    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      timeout: const Duration(seconds: 60),
      verificationCompleted: (PhoneAuthCredential credential) async {
        // Auto-retrieval or instant verification
        await FirebaseAuth.instance.signInWithCredential(credential);
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => PatientRegistrationScreen(
              signupEmail: _emailController.text.trim(),
              signupPhone: _phoneController.text.trim(),
              signupPassword: _passwordController.text,
              signupCountryCode: '+91',
            )),
          );
        }
      },
      verificationFailed: (FirebaseAuthException e) {
        setState(() {
          _errorMessage = e.message ?? 'Phone verification failed';
          loading = false;
        });
      },
      codeSent: (String verificationId, int? resendToken) {
        setState(() {
          _verificationId = verificationId;
          _otpSent = true;
          loading = false;
        });
        _showOtpDialog();
      },
      codeAutoRetrievalTimeout: (String verificationId) {
        setState(() {
          _verificationId = verificationId;
          loading = false;
        });
      },
    );
  }

  Future<void> _verifyOtpAndSignIn() async {
    if (_verificationId == null || _otpController.text.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter the OTP.';
      });
      return;
    }
    setState(() => loading = true);
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: _otpController.text.trim(),
      );
      final userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
      if (userCredential.user != null && mounted) {
        Navigator.of(context).pop(); // Close OTP dialog
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => PatientRegistrationScreen(
            signupEmail: _emailController.text.trim(),
            signupPhone: _phoneController.text.trim(),
            signupPassword: _passwordController.text,
            signupCountryCode: '+91',
          )),
        );
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        _errorMessage = e.message ?? 'OTP verification failed';
      });
    } finally {
      setState(() => loading = false);
    }
  }

  void _showOtpDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text('Enter OTP'),
          content: TextField(
            controller: _otpController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'OTP'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: _verifyOtpAndSignIn,
              child: const Text('Verify'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF32CCBC), Color(0xFF90F7EC), Color(0xFFE8F5E8)], // Green teal gradient
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
                'Create your account to start your health journey',
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
                                colors: [Color(0xFF32CCBC), Color(0xFF90F7EC)], // Green teal gradient
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
                    decoration: const InputDecoration(
                      labelText: 'Email',
                                  prefixIcon: Icon(EvaIcons.emailOutline, color: Color(0xFF32CCBC)), // Green teal
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
                                    colors: [Color(0xFF32CCBC), Color(0xFF90F7EC)], // Green teal gradient
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
                                      colors: [Color(0xFF32CCBC), Color(0xFF90F7EC)], // Green teal gradient
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
                          controller: _phoneController,
                          decoration: const InputDecoration(
                            labelText: 'Phone Number',
                                        prefixIcon: Icon(EvaIcons.phoneOutline, color: Color(0xFF32CCBC)), // Green teal
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
                                colors: [Color(0xFF32CCBC), Color(0xFF90F7EC)], // Green teal gradient
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
                                  prefixIcon: Icon(EvaIcons.lockOutline, color: Color(0xFF32CCBC)), // Green teal
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
                                colors: [Color(0xFF32CCBC), Color(0xFF90F7EC)], // Green teal gradient
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
                                  prefixIcon: Icon(EvaIcons.lockOutline, color: Color(0xFF32CCBC)), // Green teal
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
                              colors: [Color(0xFF32CCBC), Color(0xFF90F7EC)], // Green teal gradient
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                            borderRadius: BorderRadius.circular(28),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF32CCBC).withOpacity(0.3), // Green teal shadow
                                blurRadius: 15,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                            onPressed: loading ? null : _registerUser,
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
                            icon: const Icon(EvaIcons.google, color: Color(0xFF32CCBC)), // Green teal Google icon
                            label: Text(
                              'Continue with Google',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF32CCBC), // Green teal
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFF32CCBC)), // Green teal border
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
                                    color: const Color(0xFF32CCBC), // Green teal
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

  Widget _buildTextField({
    required String label,
    Function(String)? onChanged,
    TextEditingController? controller,
    bool obscureText = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        enabled: label != 'Email' || (controller == null ? true : controller.text.isEmpty),
        initialValue: controller == null ? null : null, // Don't use initialValue if controller is set
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        obscureText: obscureText,
        onChanged: onChanged,
        validator: (value) {
          if (label == 'Email' && (value == null || value.isEmpty)) {
            return 'Email is required';
          }
          return null;
        },
      ),
    );
  }
}
