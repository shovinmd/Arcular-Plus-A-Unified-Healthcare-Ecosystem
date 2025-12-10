import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:glassmorphism/glassmorphism.dart';
import 'package:eva_icons_flutter/eva_icons_flutter.dart';

import 'signup_user.dart';
import 'hospital_signup_screen.dart';
import 'doctor_signup_screen.dart';
import 'lab_signup_screen.dart';
import 'nurse_signup_screen.dart';
import 'pharmacy_signup_screen.dart';
import 'login_screen.dart';
import 'doctor_registration_screen.dart';
import 'pharmacy_registration_screen.dart';
import 'lab_registration_screen.dart';
import 'nurse_registration_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/platform_web_navigation_service.dart';
import '../admin/admin_selection_screen.dart';
import 'universal_signup_screen.dart';
import '../../utils/user_type_enum.dart';
import 'universal_signup_screen.dart';
import '../../utils/user_type_enum.dart';

class SelectUserTypeScreen extends StatefulWidget {
  final bool isWebVersion;

  const SelectUserTypeScreen({super.key, this.isWebVersion = false});

  @override
  State<SelectUserTypeScreen> createState() => _SelectUserTypeScreenState();
}

class _SelectUserTypeScreenState extends State<SelectUserTypeScreen>
    with SingleTickerProviderStateMixin {
  String? _selectedRole;
  late final AnimationController _pulseController;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);
    _pulse = CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _navigateToRoleSignup(String role) {
    UserType userType;

    switch (role.toLowerCase()) {
      case 'patient':
        userType = UserType.patient;
        break;
      case 'hospital':
        userType = UserType.hospital;
        break;
      case 'doctor':
        userType = UserType.doctor;
        break;
      case 'nurse':
        userType = UserType.nurse;
        break;
      case 'lab':
        userType = UserType.lab;
        break;
      case 'pharmacy':
        userType = UserType.pharmacy;
        break;
      default:
        userType = UserType.patient;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => UniversalSignupScreen(userType: userType),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA), // light gray
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: GlassmorphicContainer(
              width: double.infinity,
              height: MediaQuery.of(context).size.height * 0.92,
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
                stops: [0.1, 1],
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
                    Image.asset(
                      'assets/images/logo.png',
                      height: 162,
                      width: 162,
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Welcome to Arcular Plus',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Your Health, Our Priority',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),

                    // Show different content based on version
                    if (widget.isWebVersion) ...[
                      // Web version - simplified for web deployment
                      _buildWebVersionContent(),
                    ] else ...[
                      // Mobile version - full features
                      _buildMobileVersionContent(),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWebVersionContent() {
    return Column(
      children: [
        const Text(
          'Web Version - Simplified',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.blue,
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'This is the web version with limited features for web deployment.',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        // Web-specific buttons
        AnimatedBuilder(
          animation: _pulse,
          builder: (context, child) {
            final s = 1.0 + 0.02 * _pulse.value;
            return Transform.scale(scale: s, child: child);
          },
          child: Container(
            width: double.infinity,
            height: 50,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0396FF), Color(0xFFABDCFF)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(25),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0396FF)
                      .withOpacity(0.25 + 0.25 * _pulse.value),
                  blurRadius: 10 + 8 * _pulse.value,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                foregroundColor: Colors.white,
                shadowColor: Colors.transparent,
                shape: StadiumBorder(),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Poppins',
                ),
              ),
              icon: const Icon(Icons.login, color: Colors.white),
              label: const Text('Login'),
            ),
          ),
        ),
        const SizedBox(height: 16),
        AnimatedBuilder(
          animation: _pulse,
          builder: (context, child) {
            final s = 1.0 + 0.02 * _pulse.value;
            return Transform.scale(scale: s, child: child);
          },
          child: Container(
            width: double.infinity,
            height: 50,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF32CCBC), Color(0xFF90F7EC)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(25),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF32CCBC)
                      .withOpacity(0.25 + 0.25 * _pulse.value),
                  blurRadius: 10 + 8 * _pulse.value,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SignupScreen()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                foregroundColor: Colors.white,
                shadowColor: Colors.transparent,
                shape: StadiumBorder(),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Poppins',
                ),
              ),
              icon: const Icon(Icons.person, color: Colors.white),
              label: const Text('Patient Registration'),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileVersionContent() {
    return Column(
      children: [
        Container(
          width: double.infinity,
          height: 50,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0396FF), Color(0xFFABDCFF)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(25),
          ),
          child: ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              foregroundColor: Colors.white,
              shadowColor: Colors.transparent,
              shape: StadiumBorder(),
              textStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                fontFamily: 'Poppins',
              ),
            ),
            icon: const Icon(Icons.login, color: Colors.white),
            label: const Text('Login'),
          ),
        ),
        const SizedBox(height: 30),
        const Text(
          'Create New Account',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 20),
        // Hospital & Other Button (gradient)
        AnimatedBuilder(
          animation: _pulse,
          builder: (context, child) {
            final s = 1.0 + 0.02 * _pulse.value;
            return Transform.scale(scale: s, child: child);
          },
          child: Container(
            width: double.infinity,
            height: 50,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFFFF8C00),
                  Color(0xFFFFA500)
                ], // Hospital orange gradient
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(25),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFFA500)
                      .withOpacity(0.25 + 0.25 * _pulse.value),
                  blurRadius: 10 + 8 * _pulse.value,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ElevatedButton.icon(
              onPressed: () async {
                final role = await showDialog<String>(
                  context: context,
                  builder: (context) {
                    return AlertDialog(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      title: const Text(
                        'Select Role',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildRoleOption(
                            'Hospital',
                            Icons.local_hospital,
                            [
                              const Color(0xFF4CAF50),
                              const Color(0xFF81C784)
                            ], // Hospital green gradient
                            'Manage hospital operations',
                          ),
                          const SizedBox(height: 8),
                          _buildRoleOption(
                            'Doctor',
                            Icons.person,
                            [const Color(0xFF2196F3), const Color(0xFF64B5F6)],
                            'Provide medical care',
                          ),
                          const SizedBox(height: 8),
                          _buildRoleOption(
                            'Nurse',
                            Icons.medical_services,
                            [const Color(0xFFC084FC), const Color(0xFFA78BFA)],
                            'Patient care and support',
                          ),
                          const SizedBox(height: 8),
                          _buildRoleOption(
                            'Lab',
                            Icons.science,
                            [const Color(0xFFFDBA74), const Color(0xFFFB923C)],
                            'Laboratory services',
                          ),
                          const SizedBox(height: 8),
                          _buildRoleOption(
                            'Pharmacy',
                            Icons.local_pharmacy,
                            [const Color(0xFFFFD700), const Color(0xFFFFA500)],
                            'Medication management',
                          ),
                        ],
                      ),
                    );
                  },
                );
                if (role != null) {
                  _navigateToRoleSignup(role);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                foregroundColor: Colors.white,
                shadowColor: Colors.transparent,
                shape: StadiumBorder(),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Poppins',
                ),
              ),
              icon: const Icon(Icons.local_hospital, color: Colors.white),
              label: const Text('Hospital & Other'),
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Patient Button (gradient)
        Container(
          width: double.infinity,
          height: 50,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF32CCBC), Color(0xFF90F7EC)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(25),
          ),
          child: ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SignupScreen()),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              foregroundColor: Colors.white,
              shadowColor: Colors.transparent,
              shape: StadiumBorder(),
              textStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                fontFamily: 'Poppins',
              ),
            ),
            icon: const Icon(Icons.person, color: Colors.white),
            label: const Text('Patient'),
          ),
        ),
        const SizedBox(height: 32),
        Container(
          width: double.infinity,
          height: 50,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF7367F0), Color(0xFFCE9FFC)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(25),
          ),
          child: ElevatedButton.icon(
            icon: const Icon(Icons.admin_panel_settings, color: Colors.white),
            label: const Text('Admin & ARC Staff',
                style: TextStyle(fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              foregroundColor: Colors.white,
              shadowColor: Colors.transparent,
              shape: StadiumBorder(),
              textStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                fontFamily: 'Poppins',
              ),
            ),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                builder: (context) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24.0, vertical: 24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Select Login Type',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 18),
                        ListTile(
                          leading: Icon(Icons.group, color: Colors.blue),
                          title: Text('ARC Staff Login'),
                          trailing:
                              Icon(Icons.arrow_forward, color: Colors.blue),
                          onTap: () async {
                            await PlatformWebNavigationService
                                .navigateToStaffWebPage(context);
                          },
                        ),
                        ListTile(
                          leading: Icon(Icons.security, color: Colors.red),
                          title: Text('Superadmin Login'),
                          trailing:
                              Icon(Icons.arrow_forward, color: Colors.red),
                          onTap: () async {
                            await PlatformWebNavigationService
                                .navigateToAdminWebPage(context);
                          },
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildRoleOption(String title, IconData icon,
      List<Color> gradientColors, String description) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) {
        final s = 1.0 + 0.02 * _pulse.value;
        return Transform.scale(
          scale: s,
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: gradientColors,
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color:
                      gradientColors[0].withOpacity(0.25 + 0.25 * _pulse.value),
                  blurRadius: 10 + 8 * _pulse.value,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => Navigator.pop(context, title.toLowerCase()),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          icon,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              description,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_ios,
                        color: Colors.white.withOpacity(0.85),
                        size: 16,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
