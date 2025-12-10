import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'select_user_type.dart';

class ApprovalPendingScreen extends StatefulWidget {
  final String userType;

  const ApprovalPendingScreen({
    super.key,
    this.userType =
        'hospital', // Default to hospital for backward compatibility
  });

  @override
  State<ApprovalPendingScreen> createState() => _ApprovalPendingScreenState();
}

class _ApprovalPendingScreenState extends State<ApprovalPendingScreen> {
  // Get role-specific colors
  Color get _primaryColor {
    switch (widget.userType.toLowerCase()) {
      case 'hospital':
        return const Color(0xFF2E7D32); // Green
      case 'doctor':
        return const Color(0xFF2196F3); // Blue
      case 'nurse':
        return const Color(0xFFC084FC); // Nurse lavender base
      case 'lab':
        return const Color(0xFFFB923C); // Lab orange base (matches dashboard)
      case 'pharmacy':
        return const Color(0xFFFFD700); // Pharmacy golden yellow base
      default:
        return const Color.fromARGB(255, 46, 117, 125); // Default green
    }
  }

  Color get _secondaryColor {
    switch (widget.userType.toLowerCase()) {
      case 'hospital':
        return const Color(0xFF4CAF50); // Light green
      case 'doctor':
        return const Color(0xFF64B5F6); // Light blue
      case 'nurse':
        return const Color(0xFFA78BFA); // Nurse lavender light
      case 'lab':
        return const Color(0xFFFDBA74); // Lab light orange (matches dashboard)
      case 'pharmacy':
        return const Color(0xFFFFA500); // Pharmacy golden orange secondary
      default:
        return const Color(0xFF4CAF50); // Default light green
    }
  }

  // Get role-specific title
  String get _roleTitle {
    switch (widget.userType.toLowerCase()) {
      case 'hospital':
        return 'Hospital';
      case 'doctor':
        return 'Doctor';
      case 'nurse':
        return 'Nurse';
      case 'lab':
        return 'Laboratory';
      case 'pharmacy':
        return 'Pharmacy';
      default:
        return 'Service Provider';
    }
  }

  // Get role-specific subtitle
  String get _roleSubtitle {
    return 'Your $_roleTitle registration is under review';
  }

  // Get role-specific info items
  List<Map<String, String>> get _roleSpecificInfo {
    switch (widget.userType.toLowerCase()) {
      case 'hospital':
        return [
          {
            'title': 'Admin Review',
            'description':
                'Our team will review your hospital details and documents'
          },
          {
            'title': 'Verification',
            'description': 'We\'ll verify your license and registration details'
          },
          {
            'title': 'Notification',
            'description':
                'You\'ll receive an email once approved or if additional info is needed'
          }
        ];
      case 'doctor':
        return [
          {
            'title': 'Medical Board Review',
            'description':
                'Our medical team will review your qualifications and experience'
          },
          {
            'title': 'License Verification',
            'description':
                'We\'ll verify your medical license and registration number'
          },
          {
            'title': 'Notification',
            'description':
                'You\'ll receive an email once approved or if additional info is needed'
          }
        ];
      case 'nurse':
        return [
          {
            'title': 'Nursing Board Review',
            'description':
                'Our nursing team will review your qualifications and experience'
          },
          {
            'title': 'License Verification',
            'description':
                'We\'ll verify your nursing license and registration number'
          },
          {
            'title': 'Notification',
            'description':
                'You\'ll receive an email once approved or if additional info is needed'
          }
        ];
      case 'lab':
        return [
          {
            'title': 'Lab Accreditation Review',
            'description':
                'Our lab team will review your facility and equipment details'
          },
          {
            'title': 'License Verification',
            'description':
                'We\'ll verify your lab license and accreditation details'
          },
          {
            'title': 'Notification',
            'description':
                'You\'ll receive an email once approved or if additional info is needed'
          }
        ];
      case 'pharmacy':
        return [
          {
            'title': 'Pharmacy Board Review',
            'description':
                'Our pharmacy team will review your facility and license details'
          },
          {
            'title': 'License Verification',
            'description':
                'We\'ll verify your pharmacy license and registration details'
          },
          {
            'title': 'Notification',
            'description':
                'You\'ll receive an email once approved or if additional info is needed'
          }
        ];
      default:
        return [
          {
            'title': 'Admin Review',
            'description': 'Our team will review your details and documents'
          },
          {
            'title': 'Verification',
            'description': 'We\'ll verify your license and registration details'
          },
          {
            'title': 'Notification',
            'description':
                'You\'ll receive an email once approved or if additional info is needed'
          }
        ];
    }
  }

  // Get role-specific icon
  IconData get _roleIcon {
    switch (widget.userType.toLowerCase()) {
      case 'hospital':
        return Icons.local_hospital;
      case 'doctor':
        return Icons.medical_services;
      case 'nurse':
        return Icons.health_and_safety;
      case 'lab':
        return Icons.science;
      case 'pharmacy':
        return Icons.local_pharmacy;
      default:
        return Icons.hourglass_empty;
    }
  }

  // Get role-specific estimated review time
  String get _estimatedReviewTime {
    switch (widget.userType.toLowerCase()) {
      case 'hospital':
        return '24-48 hours';
      case 'doctor':
        return '48-72 hours';
      case 'nurse':
        return '24-48 hours';
      case 'lab':
        return '48-72 hours';
      case 'pharmacy':
        return '48-72 hours';
      default:
        return '24-48 hours';
    }
  }

  // Get role-specific review time description
  String get _reviewTimeDescription {
    switch (widget.userType.toLowerCase()) {
      case 'hospital':
        return 'Hospital registrations typically take 24-48 hours to review';
      case 'doctor':
        return 'Doctor registrations typically take 48-72 hours to review';
      case 'nurse':
        return 'Nurse registrations typically take 24-48 hours to review';
      case 'lab':
        return 'Lab registrations typically take 48-72 hours to review';
      case 'pharmacy':
        return 'Pharmacy registrations typically take 48-72 hours to review';
      default:
        return 'Registrations typically take 24-48 hours to review';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '$_roleTitle Approval Pending',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: _primaryColor, // Changed from blue to green
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              _primaryColor,
              _secondaryColor
            ], // Changed from blue to green
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Icon
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: Colors.white.withOpacity(0.3)),
                          ),
                          child: Icon(
                            _roleIcon,
                            size: 60,
                            color: Colors.white,
                          ),
                        ),

                        const SizedBox(height: 32),

                        // Title
                        Text(
                          '$_roleTitle Approval Pending',
                          style: GoogleFonts.poppins(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          textAlign: TextAlign.center,
                        ),

                        const SizedBox(height: 16),

                        // Subtitle
                        Text(
                          _roleSubtitle,
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            color: Colors.white.withOpacity(0.9),
                          ),
                          textAlign: TextAlign.center,
                        ),

                        const SizedBox(height: 16),

                        // Role-specific welcome message
                        Text(
                          'Welcome to Arcular Plus! We\'re excited to have you join our platform.',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: Colors.white.withOpacity(0.8),
                          ),
                          textAlign: TextAlign.center,
                        ),

                        const SizedBox(height: 32),

                        // Info Card
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color: Colors.white.withOpacity(0.3)),
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.info_outline,
                                      color: Colors.white, size: 24),
                                  const SizedBox(width: 12),
                                  Text(
                                    'What happens next for $_roleTitle?',
                                    style: GoogleFonts.poppins(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              ..._roleSpecificInfo
                                  .map((item) => Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 12),
                                        child: _buildInfoItem(
                                          title: item['title']!,
                                          description: item['description']!,
                                        ),
                                      ))
                                  .toList(),
                            ],
                          ),
                        ),

                        const SizedBox(height: 32),

                        // Estimated Time
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: Colors.orange.withOpacity(0.5)),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.schedule,
                                  color: Colors.orange, size: 24),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Estimated Review Time',
                                      style: GoogleFonts.poppins(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.orange,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _reviewTimeDescription,
                                      style: GoogleFonts.poppins(
                                        fontSize: 14,
                                        color: Colors.orange.withOpacity(0.8),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Logout Button - Always visible at bottom
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton(
                    onPressed: _logout,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Logout',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
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

  Widget _buildInfoItem({
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.info_outline,
            color: Colors.white.withOpacity(0.8), size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.white.withOpacity(0.8),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _logout() async {
    try {
      await FirebaseAuth.instance.signOut();

      // Clear SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      if (mounted) {
        // Navigate to user type selection screen and clear all routes
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) => const SelectUserTypeScreen(),
          ),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error logging out: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
