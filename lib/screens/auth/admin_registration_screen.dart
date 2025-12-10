import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../../models/user_model.dart';
import '../../services/api_service.dart';
import '../../widgets/input_field.dart';
import 'package:glassmorphism/glassmorphism.dart';
import 'package:eva_icons_flutter/eva_icons_flutter.dart';
import '../admin/admin_dashboard_screen.dart';

class AdminRegistrationScreen extends StatefulWidget {
  final String signupEmail;
  final String signupPassword;

  const AdminRegistrationScreen({
    super.key,
    required this.signupEmail,
    required this.signupPassword,
  });

  @override
  State<AdminRegistrationScreen> createState() => _AdminRegistrationScreenState();
}

class _AdminRegistrationScreenState extends State<AdminRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // Form Controllers
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _organizationController = TextEditingController();
  final TextEditingController _designationController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _stateController = TextEditingController();
  final TextEditingController _pincodeController = TextEditingController();
  
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _emailController.text = widget.signupEmail;
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _organizationController.dispose();
    _designationController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _pincodeController.dispose();
    super.dispose();
  }

  Future<void> _registerAdmin() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('No authenticated user found');
      }

      // Create admin user model
      final adminUser = UserModel(
        uid: user.uid,
        fullName: _fullNameController.text.trim(),
        email: _emailController.text.trim(),
        mobileNumber: _phoneController.text.trim(),
        gender: 'Other',
        dateOfBirth: DateTime.now(),
        address: _addressController.text.trim(),
        city: _cityController.text.trim(),
        state: _stateController.text.trim(),
        pincode: _pincodeController.text.trim(),
        type: 'admin',
        role: 'admin',
        createdAt: DateTime.now(),
        // Admin-specific fields
        organization: _organizationController.text.trim(),
        designation: _designationController.text.trim(),
      );

      // Save to backend
      final success = await ApiService.registerAdmin(adminUser);
      
                        if (success) {
                    // Save user type to SharedPreferences
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setString('user_type', 'admin');
                    await prefs.setString('user_uid', user.uid);
                    
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Admin profile completed successfully!'),
                          backgroundColor: const Color(0xFF1565C0),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                      
                      // Navigate to admin dashboard
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(builder: (_) => const AdminDashboardScreen()),
                        (route) => false,
                      );
                    }
                  } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to register admin. Please try again.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Registration failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Admin Details',
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
                          'Complete Your Profile',
                          style: GoogleFonts.poppins(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Please provide your admin details',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            color: Colors.white.withOpacity(0.8),
                          ),
                        ),
                        const SizedBox(height: 32),
                        
                        // Full Name
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
                              controller: _fullNameController,
                              decoration: InputDecoration(
                                labelText: 'Full Name *',
                                prefixIcon: const Icon(EvaIcons.personOutline, color: Color(0xFF1565C0)),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter your full name';
                                }
                                return null;
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        
                        // Email (pre-filled)
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
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: TextFormField(
                              controller: _emailController,
                              enabled: false,
                              decoration: InputDecoration(
                                labelText: 'Email Address (Pre-filled)',
                                prefixIcon: const Icon(EvaIcons.emailOutline, color: Color(0xFF1565C0)),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        
                        // Phone
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
                              controller: _phoneController,
                              decoration: InputDecoration(
                                labelText: 'Phone Number *',
                                prefixIcon: const Icon(EvaIcons.phoneOutline, color: Color(0xFF1565C0)),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                              ),
                              keyboardType: TextInputType.phone,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter phone number';
                                }
                                if (value.length < 10) {
                                  return 'Please enter a valid phone number';
                                }
                                return null;
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        
                        // Organization
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
                              controller: _organizationController,
                              decoration: InputDecoration(
                                labelText: 'Organization *',
                                prefixIcon: const Icon(EvaIcons.briefcaseOutline, color: Color(0xFF1565C0)),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter organization name';
                                }
                                return null;
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        
                        // Designation
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
                              controller: _designationController,
                              decoration: InputDecoration(
                                labelText: 'Designation *',
                                prefixIcon: const Icon(EvaIcons.awardOutline, color: Color(0xFF1565C0)),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter your designation';
                                }
                                return null;
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        
                        // Address
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
                              controller: _addressController,
                              decoration: InputDecoration(
                                labelText: 'Address *',
                                prefixIcon: const Icon(EvaIcons.homeOutline, color: Color(0xFF1565C0)),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter your address';
                                }
                                return null;
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        
                        // City
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
                              controller: _cityController,
                              decoration: InputDecoration(
                                labelText: 'City *',
                                prefixIcon: const Icon(EvaIcons.mapOutline, color: Color(0xFF1565C0)),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter your city';
                                }
                                return null;
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        
                        // State
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
                              controller: _stateController,
                              decoration: InputDecoration(
                                labelText: 'State *',
                                prefixIcon: const Icon(EvaIcons.mapOutline, color: Color(0xFF1565C0)),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter your state';
                                }
                                return null;
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        
                        // Pincode
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
                              controller: _pincodeController,
                              decoration: InputDecoration(
                                labelText: 'Pincode *',
                                prefixIcon: const Icon(Icons.location_on, color: Color(0xFF1565C0)),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                              ),
                              keyboardType: TextInputType.number,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter your pincode';
                                }
                                if (value.length != 6) {
                                  return 'Please enter a valid 6-digit pincode';
                                }
                                return null;
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
                        
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
                            onPressed: _isLoading ? null : _registerAdmin,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(25),
                              ),
                              shadowColor: Colors.transparent,
                            ),
                            child: _isLoading
                                ? const CircularProgressIndicator(color: Colors.white)
                                : Text(
                                    'Complete Registration',
                                    style: GoogleFonts.poppins(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                          ),
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