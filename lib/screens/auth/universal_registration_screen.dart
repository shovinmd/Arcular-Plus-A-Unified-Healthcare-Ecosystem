import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:glassmorphism/glassmorphism.dart';
import 'package:eva_icons_flutter/eva_icons_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../utils/user_type_enum.dart';
import '../../services/auth_service.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/input_field.dart';
import 'patient_registration_screen.dart';
import 'doctor_registration_screen.dart';
import 'hospital_registration_screen.dart';
import 'lab_registration_screen.dart';
import 'nurse_registration_screen.dart';
import 'pharmacy_registration_screen.dart';

class UniversalRegistrationScreen extends StatefulWidget {
  final UserType userType;
  final String email;
  final String phone;
  final bool isGoogleSignup;

  const UniversalRegistrationScreen({
    super.key,
    required this.userType,
    required this.email,
    required this.phone,
    required this.isGoogleSignup,
  });

  @override
  State<UniversalRegistrationScreen> createState() =>
      _UniversalRegistrationScreenState();
}

class _UniversalRegistrationScreenState
    extends State<UniversalRegistrationScreen> {
  // Role-based colors and data
  late List<Color> _gradientColors;
  late String _roleTitle;
  late String _roleSubtitle;
  late IconData _roleIcon;

  @override
  void initState() {
    super.initState();
    _initializeRoleData();
  }

  void _initializeRoleData() {
    switch (widget.userType) {
      case UserType.patient:
        _gradientColors = [const Color(0xFF32CCBC), const Color(0xFF90F7EC)];
        _roleTitle = "Patient Registration";
        _roleSubtitle = "Complete your health profile";
        _roleIcon = Icons.person;
        break;
      case UserType.doctor:
        _gradientColors = [const Color(0xFF2196F3), const Color(0xFF64B5F6)];
        _roleTitle = "Doctor Registration";
        _roleSubtitle = "Complete your medical profile";
        _roleIcon = Icons.medical_services;
        break;
      case UserType.hospital:
        _gradientColors = [const Color(0xFF4CAF50), const Color(0xFF81C784)];
        _roleTitle = "Hospital Registration";
        _roleSubtitle = "Complete your facility profile";
        _roleIcon = Icons.local_hospital;
        break;
      case UserType.nurse:
        _gradientColors = [const Color(0xFFC084FC), const Color(0xFFA78BFA)];
        _roleTitle = "Nurse Registration";
        _roleSubtitle = "Complete your nursing profile";
        _roleIcon = Icons.medical_services;
        break;
      case UserType.lab:
        _gradientColors = [const Color(0xFFFDBA74), const Color(0xFFFB923C)];
        _roleTitle = "Lab Registration";
        _roleSubtitle = "Complete your lab profile";
        _roleIcon = Icons.science;
        break;
      case UserType.pharmacy:
        _gradientColors = [const Color(0xFFFFD700), const Color(0xFFFFA500)];
        _roleTitle = "Pharmacy Registration";
        _roleSubtitle = "Complete your pharmacy profile";
        _roleIcon = Icons.local_pharmacy;
        break;
    }
  }

  void _navigateToRoleRegistration() async {
    // Get stored credentials from SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final storedEmail = prefs.getString('last_signup_email') ?? widget.email;
    final storedPhone = prefs.getString('last_signup_phone') ?? widget.phone;
    final storedPassword = prefs.getString('last_signup_password') ?? '';

    print('🔍 Retrieved stored credentials:');
    print('📧 Email: $storedEmail');
    print('📱 Phone: $storedPhone');
    print('🔑 Password: ${storedPassword.isNotEmpty ? '***' : 'not set'}');
    print('🔍 Widget credentials (fallback):');
    print('   Email: ${widget.email}');
    print('   Phone: ${widget.phone}');
    print('   Is Google Signup: ${widget.isGoogleSignup}');

    Widget targetScreen;

    switch (widget.userType) {
      case UserType.patient:
        targetScreen = PatientRegistrationScreen(
          signupEmail: storedEmail.isNotEmpty ? storedEmail : '',
          signupPhone: storedPhone.isNotEmpty ? storedPhone : '',
          signupPassword: storedPassword.isNotEmpty ? storedPassword : '',
          signupCountryCode: '+91',
        );
        break;
      case UserType.doctor:
        targetScreen = DoctorRegistrationScreen(
          signupEmail: storedEmail.isNotEmpty ? storedEmail : '',
          signupPhone: storedPhone.isNotEmpty ? storedPhone : '',
          signupPassword: storedPassword.isNotEmpty ? storedPassword : '',
          signupCountryCode: '+91',
        );
        break;
      case UserType.hospital:
        targetScreen = HospitalRegistrationScreen(
          signupEmail: storedEmail.isNotEmpty ? storedEmail : '',
          signupPhone: storedPhone.isNotEmpty ? storedPhone : '',
          signupPassword: storedPassword.isNotEmpty ? storedPassword : '',
          signupCountryCode: '+91',
        );
        break;
      case UserType.nurse:
        targetScreen = NurseRegistrationScreen(
          signupEmail: storedEmail.isNotEmpty ? storedEmail : '',
          signupPhone: storedPhone.isNotEmpty ? storedPhone : '',
          signupPassword: storedPassword.isNotEmpty ? storedPassword : '',
          signupCountryCode: '+91',
        );
        break;
      case UserType.lab:
        targetScreen = LabRegistrationScreen(
          signupEmail: storedEmail.isNotEmpty ? storedEmail : '',
          signupPhone: storedPhone.isNotEmpty ? storedPhone : '',
          signupPassword: storedPassword.isNotEmpty ? storedPassword : '',
          signupCountryCode: '+91',
        );
        break;
      case UserType.pharmacy:
        targetScreen = PharmacyRegistrationScreen(
          signupEmail: storedEmail.isNotEmpty ? storedEmail : '',
          signupPhone: storedPhone.isNotEmpty ? storedPhone : '',
          signupPassword: storedPassword.isNotEmpty ? storedPassword : '',
          signupCountryCode: '+91',
        );
        break;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => targetScreen),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              _gradientColors[0].withOpacity(0.1),
              _gradientColors[1].withOpacity(0.05),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              child: GlassmorphicContainer(
                width: double.infinity,
                height: MediaQuery.of(context).size.height * 0.8,
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
                    Colors.grey.withOpacity(0.2),
                    Colors.white.withOpacity(0.2),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24.0, vertical: 16.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Role Icon
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: _gradientColors,
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(40),
                          boxShadow: [
                            BoxShadow(
                              color: _gradientColors[0].withOpacity(0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Icon(
                          _roleIcon,
                          color: Colors.white,
                          size: 40,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Title
                      Text(
                        _roleTitle,
                        style: GoogleFonts.poppins(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),

                      // Subtitle
                      Text(
                        _roleSubtitle,
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 32),

                      // Account Info Card
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.1),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.check_circle,
                                  color: _gradientColors[0],
                                  size: 24,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'Account Created Successfully',
                                  style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            if (widget.email.isNotEmpty) ...[
                              _buildInfoRow(
                                  'Email', widget.email, Icons.email_outlined),
                              const SizedBox(height: 8),
                            ],
                            if (widget.phone.isNotEmpty) ...[
                              _buildInfoRow(
                                  'Phone', widget.phone, Icons.phone_outlined),
                              const SizedBox(height: 8),
                            ],
                            if (widget.isGoogleSignup) ...[
                              _buildInfoRow('Sign-in Method', 'Google Account',
                                  Icons.g_mobiledata),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),

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
                          onPressed: _navigateToRoleRegistration,
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
                          icon: const Icon(Icons.arrow_forward,
                              color: Colors.white),
                          label: const Text('Continue to Registration'),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Back Button
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          'Back to Sign Up',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: _gradientColors[0],
                            fontWeight: FontWeight.w600,
                          ),
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
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(
          icon,
          color: _gradientColors[0],
          size: 20,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              Text(
                value,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
