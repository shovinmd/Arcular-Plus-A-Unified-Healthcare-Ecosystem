import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/auth_service.dart';
import '../../widgets/input_field.dart';
import '../../widgets/custom_button.dart';
import 'pharmacy_registration_screen.dart';

class PharmacySignupScreen extends StatefulWidget {
  const PharmacySignupScreen({super.key});

  @override
  State<PharmacySignupScreen> createState() => _PharmacySignupScreenState();
}

class _PharmacySignupScreenState extends State<PharmacySignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _auth = AuthService();
  
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  bool _isEmail = true;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _toggleEmailPhone() {
    setState(() {
      _isEmail = !_isEmail;
      if (_isEmail) {
        _phoneController.clear();
      } else {
        _emailController.clear();
      }
    });
  }

  void _togglePasswordVisibility() {
    setState(() {
      _obscurePassword = !_obscurePassword;
    });
  }

  void _toggleConfirmPasswordVisibility() {
    setState(() {
      _obscureConfirmPassword = !_obscureConfirmPassword;
    });
  }

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Email is required';
    }
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
      return 'Please enter a valid email';
    }
    return null;
  }

  String? _validatePhone(String? value) {
    if (value == null || value.isEmpty) {
      return 'Phone number is required';
    }
    if (value.length < 10) {
      return 'Please enter a valid phone number';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    if (value.length < 6) {
      return 'Password must be at least 6 characters';
    }
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please confirm your password';
    }
    if (value != _passwordController.text) {
      return 'Passwords do not match';
    }
    return null;
  }

  Future<void> _proceedToRegistration() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        // Create Firebase user
        final userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _isEmail ? _emailController.text.trim() : '${_phoneController.text.trim()}@pharmacy.arcular.com',
          password: _passwordController.text,
        );

        if (userCredential.user != null) {
          // Save user type to SharedPreferences
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('user_type', 'pharmacy');
          await prefs.setString('user_uid', userCredential.user!.uid);

          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => PharmacyRegistrationScreen(
                  signupEmail: _isEmail ? _emailController.text.trim() : '',
                  signupPhone: !_isEmail ? _phoneController.text.trim() : '',
                  signupPassword: _passwordController.text,
                  signupCountryCode: '+91',
                ),
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF9C27B0), // Pharmacy purple
              Color(0xFFBA68C8),
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 40),
                  
                  // Logo and Title
                  Center(
                    child: Column(
                      children: [
                        Image.asset(
                          'assets/images/logo.png',
                          height: 80,
                          width: 80,
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Pharmacy Registration',
                          style: GoogleFonts.poppins(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Create your pharmacy account',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 40),
                  
                  // Email/Phone Toggle
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: _toggleEmailPhone,
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: _isEmail ? Colors.white.withOpacity(0.2) : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Center(
                                child: Text(
                                  'Email',
                                  style: GoogleFonts.poppins(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: _toggleEmailPhone,
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: !_isEmail ? Colors.white.withOpacity(0.2) : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Center(
                                child: Text(
                                  'Phone',
                                  style: GoogleFonts.poppins(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Email or Phone Field
                  if (_isEmail)
                    InputField(
                      controller: _emailController,
                      labelText: 'Email Address',
                      hintText: 'Enter your email address',
                      keyboardType: TextInputType.emailAddress,
                      validator: _validateEmail,
                    )
                  else
                    InputField(
                      controller: _phoneController,
                      labelText: 'Phone Number',
                      hintText: 'Enter your phone number',
                      keyboardType: TextInputType.phone,
                      validator: _validatePhone,
                    ),
                  
                  const SizedBox(height: 20),
                  
                  // Password Field
                  InputField(
                    controller: _passwordController,
                    labelText: 'Password',
                    hintText: 'Create a strong password',
                    obscureText: _obscurePassword,
                    validator: _validatePassword,
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Confirm Password Field
                  InputField(
                    controller: _confirmPasswordController,
                    labelText: 'Confirm Password',
                    hintText: 'Confirm your password',
                    obscureText: _obscureConfirmPassword,
                    validator: _validateConfirmPassword,
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // Proceed Button
                  CustomButton(
                    text: _isLoading ? 'Creating Account...' : 'Continue',
                    onPressed: _isLoading ? () {} : _proceedToRegistration,
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Back to Login
                  Center(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        'Back to Login',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
} 