import 'package:arcular_plus/utils/user_type_enum.dart';
import 'package:arcular_plus/screens/hospital/dashboard_hospital.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:arcular_plus/services/auth_service.dart';

import '../../widgets/custom_button.dart';
import '../../widgets/input_field.dart';
import 'login_screen.dart';

class SignupHospitalScreen extends StatefulWidget {
  const SignupHospitalScreen({super.key});

  @override
  State<SignupHospitalScreen> createState() => _SignupHospitalScreenState();
}

class _SignupHospitalScreenState extends State<SignupHospitalScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _hospitalNameController = TextEditingController();
  final _licenseNumberController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _pincodeController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _hospitalNameController.dispose();
    _licenseNumberController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _pincodeController.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // Use the auth service to register hospital
      final authService = AuthService();
      // TODO: Refactor this screen to use the new hospital registration flow with UserModel. The old registerHospital method is removed.
      // final userModel = await authService.registerHospital(
      //   email: _emailController.text.trim(),
      //   password: _passwordController.text,
      //   hospitalName: _hospitalNameController.text,
      //   phone: _phoneController.text,
      //   licenseNumber: _licenseNumberController.text,
      // );

      // if (userModel != null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Registration successful!')),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message ?? 'Registration failed')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Registration failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hospital Registration'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Bigger Logo
              Image.asset(
                'assets/images/logo.png',
                height: 150,
                width: 150,
              ),
              const SizedBox(height: 20),
              
              // Welcome Text
              const Text(
                'Join as Healthcare Provider',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Connect with patients and manage your practice',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30),
              
              _buildTextField(
                controller: _hospitalNameController,
                label: 'Hospital/Clinic Name',
                icon: Icons.local_hospital,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Hospital/Clinic name is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _licenseNumberController,
                label: 'License Number',
                icon: Icons.badge,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'License number is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _phoneController,
                label: 'Phone Number',
                icon: Icons.phone,
                keyboardType: TextInputType.phone,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Phone number is required';
                  }
                  if (value.length < 10) {
                    return 'Enter a valid phone number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _addressController,
                label: 'Address',
                icon: Icons.location_on,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Address is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _pincodeController,
                label: 'Pincode',
                icon: Icons.pin,
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Pincode is required';
                  }
                  if (value.length < 5) {
                    return 'Enter a valid pincode';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _emailController,
                label: 'Email',
                icon: Icons.email,
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) return 'Please enter email';
                  if (!RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$').hasMatch(value)) return 'Please enter valid email';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _passwordController,
                label: 'Password',
                icon: Icons.lock,
                obscureText: true,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) return 'Please enter password';
                  if (value.length < 6)
                    return 'Password must be at least 6 characters';
                  return null;
                },
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _signUp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'Create Account',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
              const SizedBox(height: 20),
              
              // Login Link
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Already have an account? '),
                  TextButton(
                    onPressed: () => Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (context) => const LoginScreen()),
                    ),
                    child: const Text(
                      'Login',
                      style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscureText = false,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return InputField(
      controller: controller,
      labelText: label,
      obscureText: obscureText,
      keyboardType: keyboardType,
      validator: validator,
    );
  }
}
