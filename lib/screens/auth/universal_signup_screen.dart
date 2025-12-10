import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:glassmorphism/glassmorphism.dart';
import 'package:eva_icons_flutter/eva_icons_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../utils/user_type_enum.dart';
import '../../services/auth_service.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/input_field.dart';
import 'login_screen.dart';
import 'universal_registration_screen.dart';
import 'hospital_registration_screen.dart';
import 'doctor_registration_screen.dart';
import 'nurse_registration_screen.dart';
import 'lab_registration_screen.dart';
import 'pharmacy_registration_screen.dart';
import 'patient_registration_screen.dart';

class UniversalSignupScreen extends StatefulWidget {
  final UserType userType;
  final String? prefilledEmail;

  const UniversalSignupScreen({
    super.key,
    required this.userType,
    this.prefilledEmail,
  });

  @override
  State<UniversalSignupScreen> createState() => _UniversalSignupScreenState();
}

class _UniversalSignupScreenState extends State<UniversalSignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _auth = AuthService();

  // Form Fields
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  // UI State
  bool _isLoading = false;
  bool _showPasswordFields = false;
  bool _showEmailField = true;
  bool _showPhoneField = true;
  bool _isGoogleSignup = false;
  String _countryCode = '+91';
  String? _errorMessage;

  // Role-based colors
  late List<Color> _gradientColors;
  late String _roleTagline;

  @override
  void initState() {
    super.initState();
    _initializeRoleData();
    _setupPrefilledData();
    _setupListeners();
  }

  void _initializeRoleData() {
    switch (widget.userType) {
      case UserType.patient:
        _gradientColors = [const Color(0xFF32CCBC), const Color(0xFF90F7EC)];
        _roleTagline = "Join Arcular+ for better health management";
        break;
      case UserType.doctor:
        _gradientColors = [const Color(0xFF2196F3), const Color(0xFF64B5F6)];
        _roleTagline = "Join Arcular+ to provide better healthcare";
        break;
      case UserType.hospital:
        _gradientColors = [const Color(0xFF4CAF50), const Color(0xFF81C784)];
        _roleTagline = "Join Arcular+ to manage healthcare operations";
        break;
      case UserType.nurse:
        _gradientColors = [const Color(0xFFC084FC), const Color(0xFFA78BFA)];
        _roleTagline = "Join Arcular+ to deliver patient care";
        break;
      case UserType.lab:
        _gradientColors = [const Color(0xFFFDBA74), const Color(0xFFFB923C)];
        _roleTagline = "Join Arcular+ to provide lab services";
        break;
      case UserType.pharmacy:
        _gradientColors = [const Color(0xFFFFD700), const Color(0xFFFFA500)];
        _roleTagline = "Join Arcular+ to manage medications";
        break;
    }
  }

  void _setupPrefilledData() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _emailController.text = user.email ?? '';
      _isGoogleSignup = true;
      _showEmailField = false;
      _showPasswordFields = false;
    } else if (widget.prefilledEmail != null &&
        widget.prefilledEmail!.isNotEmpty) {
      _emailController.text = widget.prefilledEmail!;
    }
  }

  void _setupListeners() {
    _emailController.addListener(_handleEmailChange);
    _phoneController.addListener(_handlePhoneChange);
  }

  void _handleEmailChange() {
    final email = _emailController.text.trim();
    setState(() {
      _showPasswordFields = email.isNotEmpty;
      _showPhoneField = email.isEmpty;
    });
  }

  void _handlePhoneChange() {
    final phone = _phoneController.text.trim();
    setState(() {
      _showPasswordFields = phone.isNotEmpty;
      _showEmailField = phone.isEmpty;
    });
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);

    try {
      print(
          '🔐 Starting Google sign-up process for ${widget.userType.displayName}...');

      // Step 1: Get Google account
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        print('❌ Google sign-in cancelled by user');
        setState(() => _isLoading = false);
        return;
      }

      print('✅ Google account selected: ${googleUser.email}');

      // Step 2: Get authentication tokens
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      print('🔑 Google authentication tokens obtained');

      // Step 3: Sign in to Firebase with Google credentials
      try {
        final UserCredential userCredential =
            await FirebaseAuth.instance.signInWithCredential(credential);
        final User? user = userCredential.user;

        if (user != null) {
          print('✅ Firebase user authenticated: ${user.uid}');

          // Check if this is a new user
          final isNewUser =
              userCredential.additionalUserInfo?.isNewUser ?? false;

          if (isNewUser) {
            print('🆕 New user detected, proceeding to registration');
            setState(() => _isLoading = false);

            if (mounted) {
              // Show success message
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Google account connected! Completing ${widget.userType.displayName} registration...',
                    style: GoogleFonts.poppins(),
                  ),
                  backgroundColor: const Color(0xFF32CCBC),
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 2),
                ),
              );

              // Navigate to specific registration screen based on user type
              _navigateToSpecificRegistration(user.email ?? '');
            }
          } else {
            print('⚠️ Existing user detected, redirecting to login');
            setState(() => _isLoading = false);

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    '${widget.userType.displayName} account already exists. Please login instead.',
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
        if (signInError.toString().contains('user-not-found') ||
            signInError.toString().contains('invalid-credential')) {
          // This is likely a new user - directly navigate to registration
          print('🆕 New user detected from error, proceeding to registration');
          setState(() => _isLoading = false);

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Google account connected! Completing ${widget.userType.displayName} registration...',
                  style: GoogleFonts.poppins(),
                ),
                backgroundColor: const Color(0xFF32CCBC),
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 2),
              ),
            );

            // Navigate directly to specific registration with Google data
            _navigateToSpecificRegistration(googleUser.email);
          }
        } else {
          // Re-throw other errors
          throw signInError;
        }
      }
    } catch (e) {
      print('❌ Google sign-up failed: $e');
      setState(() {
        _errorMessage = 'Google sign-in failed: ${e.toString()}';
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Google sign-in failed: ${e.toString()}',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _navigateToSpecificRegistration(String email) {
    // Navigate to specific registration screen based on user type
    switch (widget.userType) {
      case UserType.hospital:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => HospitalRegistrationScreen(
              signupEmail: email,
              signupPhone: '',
              signupPassword: '',
              signupCountryCode: '+91',
            ),
          ),
        );
        break;
      case UserType.doctor:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => DoctorRegistrationScreen(
              signupEmail: email,
              signupPhone: '',
              signupPassword: _passwordController.text.trim(),
              signupCountryCode: '+91',
            ),
          ),
        );
        break;
      case UserType.nurse:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => NurseRegistrationScreen(
              signupEmail: email,
              signupPhone: '',
              signupPassword: _passwordController.text.trim(),
              signupCountryCode: '+91',
            ),
          ),
        );
        break;
      case UserType.lab:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => LabRegistrationScreen(
              signupEmail: email,
              signupPhone: '',
              signupPassword: _passwordController.text.trim(),
              signupCountryCode: '+91',
            ),
          ),
        );
        break;
      case UserType.pharmacy:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => PharmacyRegistrationScreen(
              signupEmail: email,
              signupPhone: '',
              signupPassword: _passwordController.text.trim(),
              signupCountryCode: '+91',
            ),
          ),
        );
        break;
      case UserType.patient:
      default:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => PatientRegistrationScreen(
              signupEmail: email,
              signupPhone: '',
              signupPassword: '',
              signupCountryCode: '+91',
            ),
          ),
        );
        break;
    }
  }

  void _navigateToRegistration() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => UniversalRegistrationScreen(
          userType: widget.userType,
          email: _emailController.text.trim(),
          phone: _phoneController.text.trim(),
          isGoogleSignup: _isGoogleSignup,
        ),
      ),
    );
  }

  Future<void> _handleContinue() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // Validate email or phone is provided
      final email = _emailController.text.trim();
      final phone = _phoneController.text.trim();

      if (email.isEmpty && phone.isEmpty) {
        setState(() {
          _errorMessage = 'Please provide either email or phone number';
          _isLoading = false;
        });
        return;
      }

      // If password fields are shown, validate them
      if (_showPasswordFields) {
        if (_passwordController.text != _confirmPasswordController.text) {
          setState(() {
            _errorMessage = 'Passwords do not match';
            _isLoading = false;
          });
          return;
        }
      }

      // Store credentials in SharedPreferences for registration screens
      if (email.isNotEmpty || phone.isNotEmpty) {
        final prefs = await SharedPreferences.getInstance();
        if (email.isNotEmpty) {
          await prefs.setString('last_signup_email', email);
        }
        if (phone.isNotEmpty) {
          await prefs.setString('last_signup_phone', phone);
        }
        // Always store password if provided, regardless of _showPasswordFields
        if (_passwordController.text.isNotEmpty) {
          await prefs.setString(
              'last_signup_password', _passwordController.text);
          print('🔑 Password stored: ***');
        } else {
          print('🔑 No password provided');
        }

        // Verify credentials were stored
        final storedEmail = prefs.getString('last_signup_email');
        final storedPhone = prefs.getString('last_signup_phone');
        final storedPassword = prefs.getString('last_signup_password');

        print('💾 Credentials stored in SharedPreferences:');
        print('📧 Email: $storedEmail');
        print('📱 Phone: $storedPhone');
        print(
            '🔑 Password: ${storedPassword?.isNotEmpty == true ? '***' : 'not set'}');
        print('🔍 Original values:');
        print('   Email: $email');
        print('   Phone: $phone');
        print(
            '   Password: ${_passwordController.text.isNotEmpty ? '***' : 'not set'}');
      }

      _navigateToRegistration();
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              _gradientColors[0].withOpacity(0.8), // More visible
              _gradientColors[1].withOpacity(0.6), // More visible
              _gradientColors[0].withOpacity(0.3), // Light at bottom
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              child: GlassmorphicContainer(
                width: double.infinity,
                height: MediaQuery.of(context).size.height * 0.9,
                borderRadius: 32,
                blur: 12,
                alignment: Alignment.center,
                border: 1.5,
                linearGradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withOpacity(0.85),
                    Colors.white.withOpacity(0.7),
                  ],
                  stops: const [0.1, 1],
                ),
                borderGradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    _gradientColors[0].withOpacity(0.3),
                    _gradientColors[1].withOpacity(0.3),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24.0, vertical: 16.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Logo
                        Image.asset(
                          'assets/images/logo.png',
                          height: 120,
                          width: 120,
                          errorBuilder: (context, error, stackTrace) {
                            return Icon(
                              Icons.medical_services,
                              size: 120,
                              color: _gradientColors[0],
                            );
                          },
                        ),
                        const SizedBox(height: 20),

                        // Title
                        Text(
                          'Join Arcular+',
                          style: GoogleFonts.poppins(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: _gradientColors[0], // Use role color
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Role-based tagline
                        Text(
                          _roleTagline,
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 32),

                        // Email Input
                        if (_showEmailField) ...[
                          _buildInputField(
                            controller: _emailController,
                            label: 'Email',
                            icon: Icons.email_outlined,
                            keyboardType: TextInputType.emailAddress,
                            validator: (value) {
                              if (value != null && value.isNotEmpty) {
                                if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                                    .hasMatch(value)) {
                                  return 'Please enter a valid email';
                                }
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Phone Input
                        if (_showPhoneField) ...[
                          _buildPhoneInput(),
                          const SizedBox(height: 16),
                        ],

                        // Password Fields (shown when email or phone is entered)
                        if (_showPasswordFields) ...[
                          _buildInputField(
                            controller: _passwordController,
                            label: 'Create Password',
                            icon: Icons.lock_outlined,
                            isPassword: true,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Password is required';
                              }
                              if (value.length < 6) {
                                return 'Password must be at least 6 characters';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          _buildInputField(
                            controller: _confirmPasswordController,
                            label: 'Confirm Password',
                            icon: Icons.lock_outlined,
                            isPassword: true,
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
                          const SizedBox(height: 16),
                        ],

                        // Error Message
                        if (_errorMessage != null) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.red[50],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.red[200]!),
                            ),
                            child: Text(
                              _errorMessage!,
                              style: TextStyle(color: Colors.red[700]),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Continue Button
                        Container(
                          width: double.infinity,
                          height: 50,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: _gradientColors,
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                            borderRadius: BorderRadius.circular(25),
                            boxShadow: [
                              BoxShadow(
                                color: _gradientColors[0].withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ElevatedButton.icon(
                            onPressed: _isLoading ? null : _handleContinue,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              foregroundColor: Colors.white,
                              shadowColor: Colors.transparent,
                              shape: const StadiumBorder(),
                              textStyle: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            icon: _isLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                          Colors.white),
                                    ),
                                  )
                                : const Icon(Icons.arrow_forward,
                                    color: Colors.white),
                            label: Text(
                                _isLoading ? 'Please wait...' : 'Continue'),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Google Sign-In Button
                        Container(
                          width: double.infinity,
                          height: 50,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(25),
                            border: Border.all(color: Colors.grey[300]!),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.withOpacity(0.2),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ElevatedButton.icon(
                            onPressed: _isLoading ? null : _handleGoogleSignIn,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              foregroundColor: Colors.grey[700],
                              shadowColor: Colors.transparent,
                              shape: const StadiumBorder(),
                              textStyle: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            icon: const Icon(
                              Icons.g_mobiledata,
                              size: 20,
                              color: Colors.red,
                            ),
                            label: const Text('Continue with Google'),
                          ),
                        ),
                        const SizedBox(height: 32),

                        // Login Link
                        Row(
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
                                  MaterialPageRoute(
                                      builder: (_) => const LoginScreen()),
                                );
                              },
                              child: Text(
                                'Login',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: _gradientColors[0],
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

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isPassword = false,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        obscureText: isPassword,
        keyboardType: keyboardType,
        validator: validator,
        style: GoogleFonts.poppins(fontSize: 16),
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: _gradientColors[0]),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.transparent,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildPhoneInput() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Country Code Dropdown
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: _gradientColors[0].withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                bottomLeft: Radius.circular(12),
              ),
            ),
            child: DropdownButton<String>(
              value: _countryCode,
              underline: const SizedBox(),
              items: const [
                DropdownMenuItem(value: '+91', child: Text('+91')),
                DropdownMenuItem(value: '+1', child: Text('+1')),
                DropdownMenuItem(value: '+44', child: Text('+44')),
              ],
              onChanged: (value) {
                setState(() {
                  _countryCode = value!;
                });
              },
            ),
          ),
          // Phone Number Input
          Expanded(
            child: TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              style: GoogleFonts.poppins(fontSize: 16),
              decoration: InputDecoration(
                labelText: 'Phone Number',
                prefixIcon:
                    Icon(Icons.phone_outlined, color: _gradientColors[0]),
                border: const OutlineInputBorder(
                  borderRadius: BorderRadius.only(
                    topRight: Radius.circular(12),
                    bottomRight: Radius.circular(12),
                  ),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.transparent,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }
}
