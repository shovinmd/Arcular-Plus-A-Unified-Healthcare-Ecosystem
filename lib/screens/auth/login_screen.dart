import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:glassmorphism/glassmorphism.dart';
import 'package:arcular_plus/services/auth_service.dart';
import 'package:arcular_plus/services/api_service.dart';
import 'package:arcular_plus/screens/auth/universal_signup_screen.dart';
import 'package:arcular_plus/screens/auth/approval_pending_screen.dart';
import 'package:arcular_plus/utils/user_type_enum.dart';
import 'package:arcular_plus/screens/user/dashboard_user.dart';
import 'package:arcular_plus/screens/hospital/dashboard_hospital.dart';
import 'package:arcular_plus/screens/doctor/dashboard_doctor.dart';
import 'package:arcular_plus/screens/lab/dashboard_lab.dart';
import 'package:arcular_plus/screens/nurse/dashboard_nurse.dart';
import 'package:arcular_plus/screens/pharmacy/dashboard_pharmacy.dart';
import 'package:eva_icons_flutter/eva_icons_flutter.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();
  bool _loading = false;
  bool _obscurePassword = true;
  String _selectedUserType = 'patient'; // Default to patient

  // User type options with their colors
  final List<Map<String, dynamic>> _userTypes = [
    {
      'type': 'patient',
      'label': 'Patient',
      'icon': Icons.person,
      'colors': [Color(0xFF32CCBC), Color(0xFF90F7EC)],
    },
    {
      'type': 'hospital',
      'label': 'Hospital',
      'icon': Icons.local_hospital,
      'colors': [Color(0xFF4CAF50), Color(0xFF81C784)],
    },
    {
      'type': 'doctor',
      'label': 'Doctor',
      'icon': Icons.medical_services,
      'colors': [Color(0xFF2196F3), Color(0xFF64B5F6)],
    },
    {
      'type': 'nurse',
      'label': 'Nurse',
      'icon': Icons.healing,
      'colors': [Color(0xFFC084FC), Color(0xFFA78BFA)],
    },
    {
      'type': 'lab',
      'label': 'Lab',
      'icon': Icons.science,
      'colors': [Color(0xFFFDBA74), Color(0xFFFB923C)],
    },
    {
      'type': 'pharmacy',
      'label': 'Pharmacy',
      'icon': Icons.local_pharmacy,
      'colors': [Color(0xFFFFD700), Color(0xFFFFA500)],
    },
  ];

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleEmailLogin() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      print('🔐 Starting email login process...');
      print('👤 Selected user type: $_selectedUserType');

      // Set the selected user type in SharedPreferences BEFORE authentication
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_type', _selectedUserType);
      print('💾 Set SharedPreferences user_type to: $_selectedUserType');

      // First, check if this email exists and how it was registered
      try {
        final methods = await FirebaseAuth.instance
            .fetchSignInMethodsForEmail(_emailController.text.trim());
        print('🔍 Sign-in methods for email: $methods');

        if (methods.contains('google.com')) {
          // User registered with Google, show appropriate message
          setState(() => _loading = false);
          _showFailurePopup(
              'This account was created with Google Sign-in. Please use the "Sign in with Google" button to login.');
          return;
        } else if (methods.isEmpty) {
          // No Firebase account exists, but backend might have the user
          print('⚠️ No Firebase account found, but checking backend...');
        }
      } catch (e) {
        print('⚠️ Could not check sign-in methods: $e');
        // Continue with normal login flow
      }

      // For service providers, check backend first to verify approval status
      if (_selectedUserType != 'patient') {
        print('🏥 Service provider login - checking backend first...');

        try {
          // Check if user exists in backend and get approval status
          final backendResponse = await ApiService.checkServiceProviderLogin(
            _emailController.text.trim(),
            _selectedUserType,
          );

          if (backendResponse != null) {
            print('✅ Backend user found: ${backendResponse.toJson()}');

            // Check approval status
            if (backendResponse.isApproved == true) {
              print('✅ User is approved, proceeding with Firebase auth...');

              // User is approved, proceed with Firebase authentication
              final userModel = await _authService.signIn(
                _emailController.text.trim(),
                _passwordController.text,
              );

              if (userModel != null) {
                print('✅ Firebase authentication successful');
                print('🔍 Firebase UID: ${userModel.uid}');
                print('🔍 Backend UID: ${backendResponse.uid}');

                // Check if UIDs match (for security)
                if (userModel.uid != backendResponse.uid) {
                  print(
                      '❌ UID mismatch - user might have been registered with Google');
                  _showFailurePopup(
                      'This account was created with Google Sign-in. Please use the "Sign in with Google" button to login.');
                  return;
                }

                // Update SharedPreferences with backend data
                await prefs.setString('user_gender', backendResponse.gender);
                await prefs.setString('user_type', backendResponse.type);
                await prefs.setString('user_uid', userModel.uid);

                // Cache approval status for instant dashboard display
                await prefs.setBool('${backendResponse.type}_is_approved',
                    backendResponse.isApproved ?? false);
                await prefs.setString('${backendResponse.type}_approval_status',
                    backendResponse.approvalStatus ?? 'pending');

                print('💾 SharedPreferences saved from backend data');
                print(
                    '💾 Approval status cached: ${backendResponse.isApproved}, ${backendResponse.approvalStatus}');

                // Navigate to dashboard
                _showSuccessPopup();
                return;
              } else {
                print('❌ Firebase authentication failed');
                _showFailurePopup(
                    'Invalid email or password. Please try again.');
                return;
              }
            } else {
              print('⏳ User is not approved yet');
              setState(() => _loading = false);

              // Navigate to approval pending screen
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      ApprovalPendingScreen(userType: backendResponse.type),
                ),
              );
              return;
            }
          } else {
            print('❌ User not found in backend');
            setState(() => _loading = false);
            _showFailurePopup(
                'User not found. Please check your credentials or contact support.');
            return;
          }
        } catch (e) {
          print('❌ Backend check failed: $e');
          // Fall back to old method
          print('🔄 Falling back to old login method...');
        }
      }

      // Fallback: Use the old method for patients or if backend check fails
      print('🔄 Using fallback login method...');

      final userModel = await _authService.signIn(
        _emailController.text.trim(),
        _passwordController.text,
      );
      if (!mounted) return;
      if (userModel != null) {
        print('✅ Firebase authentication successful');
        print('👤 User UID: ${userModel.uid}');

        // For patients, use the old method
        if (_selectedUserType == 'patient') {
          print('👤 Patient login - fetching user info from backend...');
          final backendUser = await ApiService.getUserInfo(userModel.uid);
          print('🌐 Backend user info: ${backendUser?.toJson()}');
          print('🔍 Backend user is null: ${backendUser == null}');

          if (backendUser != null) {
            print('📋 User type from backend: ${backendUser.type}');
            print('👤 User gender from backend: ${backendUser.gender}');

            // Update SharedPreferences with the actual user type from backend
            await prefs.setString('user_gender', backendUser.gender);
            await prefs.setString('user_type', backendUser.type);
            await prefs.setString('user_uid', userModel.uid);

            // Cache approval status for instant dashboard display
            await prefs.setBool('${backendUser.type}_is_approved',
                backendUser.isApproved ?? false);
            await prefs.setString('${backendUser.type}_approval_status',
                backendUser.approvalStatus ?? 'pending');

            print('💾 SharedPreferences saved:');
            print('   - user_gender: ${backendUser.gender}');
            print('   - user_type: ${backendUser.type}');
            print('   - user_uid: ${userModel.uid}');
            print(
                '   - approval status cached: ${backendUser.isApproved}, ${backendUser.approvalStatus}');

            // Go directly to dashboard
            _showSuccessPopup();
          } else {
            print(
                '❌ Backend user info is null - user not found in any collection');
            print(
                '🔍 This might be a new user or user not properly registered');

            // Show error message
            _showFailurePopup(
                'User not found. Please check your credentials or contact support.');
          }
        } else {
          // For service providers in fallback, show error
          print('❌ Service provider login failed in fallback mode');
          _showFailurePopup(
              'Service provider login failed. Please try again or contact support.');
        }
      } else {
        print('❌ Firebase authentication failed');
        // Login failed
        _showFailurePopup('Invalid email or password. Please try again.');
      }
    } catch (e) {
      print('❌ Login error: $e');
      _showFailurePopup('Login failed: ${e.toString()}');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _loading = true);
    try {
      print('🔐 Starting Google Sign-In process...');
      print('👤 Selected user type: $_selectedUserType');

      // Set the selected user type in SharedPreferences BEFORE Google sign-in
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_type', _selectedUserType);
      print('💾 Set SharedPreferences user_type to: $_selectedUserType');

      await _authService.signInWithGoogle();
      if (!mounted) return;
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _showFailurePopup('Google sign-in failed!');
        setState(() => _loading = false);
        return;
      }

      print('✅ Google authentication successful');
      print('👤 User UID: ${user.uid}');

      // For patients, use the old method
      if (_selectedUserType == 'patient') {
        print('👤 Patient login - fetching user info from backend...');
        final backendUser = await ApiService.getUserInfo(user.uid);
        print('🌐 Backend user info: ${backendUser?.toJson()}');

        if (backendUser != null) {
          print('📋 User type from backend: ${backendUser.type}');
          print('👤 User gender from backend: ${backendUser.gender}');

          // Update SharedPreferences with the actual user type from backend
          await prefs.setString('user_gender', backendUser.gender);
          await prefs.setString('user_type', backendUser.type);
          await prefs.setString('user_uid', user.uid);

          // Cache approval status for instant dashboard display
          await prefs.setBool('${backendUser.type}_is_approved',
              backendUser.isApproved ?? false);
          await prefs.setString('${backendUser.type}_approval_status',
              backendUser.approvalStatus ?? 'pending');

          print('💾 SharedPreferences saved:');
          print('   - user_gender: ${backendUser.gender}');
          print('   - user_type: ${backendUser.type}');
          print('   - user_uid: ${user.uid}');
          print(
              '   - approval status cached: ${backendUser.isApproved}, ${backendUser.approvalStatus}');

          // Go directly to dashboard
          _showSuccessPopup();
        } else {
          print('❌ Backend user info is null - new user');
          print('🔍 This might be a new user or user not properly registered');

          // Show error message
          _showFailurePopup(
              'User not found. Please check your credentials or contact support.');
        }
      } else {
        // For service providers, check backend for approval status after Google auth
        print(
            '🏥 Service provider Google sign-in - checking backend for approval status...');

        try {
          // Check if user exists in backend and get approval status
          final backendResponse = await ApiService.checkServiceProviderLogin(
            user.email ?? '',
            _selectedUserType,
          );

          print('🔍 Backend response: ${backendResponse?.toJson()}');

          if (backendResponse != null) {
            print('✅ Backend user found: ${backendResponse.toJson()}');

            // Check approval status
            if (backendResponse.isApproved == true) {
              print('✅ User is approved, proceeding with Google sign-in...');
              print('🔍 Google UID: ${user.uid}');
              print('🔍 Backend UID: ${backendResponse.uid}');

              // Check if UIDs match (for security)
              if (user.uid != backendResponse.uid) {
                print(
                    '❌ UID mismatch - user might have been registered with email/password');
                _showFailurePopup(
                    'This account was created with email/password. Please use the email/password login instead.');
                return;
              }

              // Update SharedPreferences with backend data
              await prefs.setString('user_gender', backendResponse.gender);
              await prefs.setString('user_type', backendResponse.type);
              await prefs.setString('user_uid', user.uid);

              // Cache approval status for instant dashboard display
              await prefs.setBool('${backendResponse.type}_is_approved',
                  backendResponse.isApproved ?? false);
              await prefs.setString('${backendResponse.type}_approval_status',
                  backendResponse.approvalStatus ?? 'pending');

              print('💾 SharedPreferences saved from backend data');
              print(
                  '💾 Approval status cached: ${backendResponse.isApproved}, ${backendResponse.approvalStatus}');

              // Navigate to dashboard
              _showSuccessPopup();
            } else {
              print('⏳ User is not approved yet');
              setState(() => _loading = false);

              // Navigate to approval pending screen
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      ApprovalPendingScreen(userType: backendResponse.type),
                ),
              );
            }
          } else {
            print('❌ User not found in backend');
            setState(() => _loading = false);

            // Check if this is a new Google user who needs to register
            if (user.email != null) {
              _showFailurePopup(
                'Account not found. If you are a new $_selectedUserType, please use the Sign Up button to register first. '
                'If you already have an account, please use email and password login.',
              );
            } else {
              _showFailurePopup(
                  'User not found. Please check your credentials or contact support.');
            }
          }
        } catch (e) {
          print('❌ Backend check failed: $e');
          setState(() => _loading = false);
          _showFailurePopup(
              'Service provider verification failed. Please try again or contact support.');
        }
      }
    } catch (e) {
      print('❌ Google Sign-In error: $e');
      _showFailurePopup('Google Sign-In failed: ${e.toString()}');
    } finally {
      setState(() => _loading = false);
    }
  }

  void _navigateToDashboard(String userType) {
    print('🎯 _navigateToDashboard called with userType: $userType');
    print('🔄 Navigating directly to dashboard...');

    // Navigate directly to the appropriate dashboard
    // This ensures the user reaches the dashboard immediately
    if (mounted) {
      switch (userType) {
        case 'patient':
          print('👤 Navigating to DashboardUser (patient dashboard)');
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const DashboardUser()),
          );
          break;
        case 'hospital':
          print('🏥 Navigating to HospitalDashboardScreen');
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const HospitalDashboardScreen()),
          );
          break;
        case 'doctor':
          print('👨‍⚕️ Navigating to DashboardDoctor');
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const DashboardDoctor()),
          );
          break;
        case 'lab':
          print('🔬 Navigating to LabDashboardScreen');
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const LabDashboardScreen()),
          );
          break;
        case 'nurse':
          print('👩‍⚕️ Navigating to NurseDashboardScreen');
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const NurseDashboardScreen()),
          );
          break;
        case 'pharmacy':
          print('💊 Navigating to DashboardPharmacy');
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const DashboardPharmacy()),
          );
          break;
        default:
          print('❓ Unknown user type: $userType, defaulting to DashboardUser');
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const DashboardUser()),
          );
      }
    }
  }

  Widget _buildProcessingScreen() {
    return FutureBuilder<SharedPreferences>(
      future: SharedPreferences.getInstance(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          // Get the selected user type from SharedPreferences or default to patient
          final selectedUserType = _userTypes.firstWhere(
            (userType) => userType['type'] == _selectedUserType,
            orElse: () => _userTypes[0],
          );
          final gradientColors = selectedUserType['colors'] as List<Color>;

          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: gradientColors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
          );
        }

        final prefs = snapshot.data;
        final userGender = prefs?.getString('user_gender') ?? 'male';
        final userType = prefs?.getString('user_type') ?? 'patient';

        String imagePath = 'assets/images/logo.png'; // Default logo

        // Set gender-specific image based on user type and gender
        if (userGender.toLowerCase() == 'female') {
          switch (userType.toLowerCase()) {
            case 'patient':
              imagePath = 'assets/images/Female/pat/cry.png';
              break;
            case 'doctor':
              imagePath = 'assets/images/Female/doc/cry.png';
              break;
            case 'nurse':
              imagePath = 'assets/images/Female/nurs/cry.png';
              break;
            case 'lab':
              imagePath = 'assets/images/Female/lab/cry.png';
              break;
            case 'pharmacy':
              imagePath = 'assets/images/Female/pharm/cry.png';
              break;
            case 'hospital':
              imagePath = 'assets/images/Female/hosp/cry.png';
              break;
            default:
              imagePath = 'assets/images/Female/pat/cry.png';
          }
        } else {
          // Male gender
          switch (userType.toLowerCase()) {
            case 'patient':
              imagePath = 'assets/images/Male/pat/think.png';
              break;
            case 'doctor':
              imagePath = 'assets/images/Male/doc/think.png';
              break;
            case 'nurse':
              imagePath = 'assets/images/Male/nurs/think.png';
              break;
            case 'lab':
              imagePath = 'assets/images/Male/lab/think.png';
              break;
            case 'pharmacy':
              imagePath = 'assets/images/Male/pharm/think.png';
              break;
            case 'hospital':
              imagePath = 'assets/images/Male/doc/think.png';
              break;
            default:
              imagePath = 'assets/images/Male/pat/think.png';
          }
        }

        // Get the selected user type from SharedPreferences or default to patient
        final selectedUserType = _userTypes.firstWhere(
          (type) => type['type'] == userType,
          orElse: () => _userTypes[0],
        );
        final gradientColors = selectedUserType['colors'] as List<Color>;

        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: gradientColors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Application Branding (Top Circle)
                Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Image.asset(
                      'assets/images/logo.png',
                      height: 81,
                      width: 81,
                    ),
                  ),
                ),
                const SizedBox(height: 40),
                // Processing Image (Middle Circle)
                Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Image.asset(
                      imagePath,
                      height: 100,
                      width: 100,
                    ),
                  ),
                ),
                const SizedBox(height: 40),
                // Loading Text
                Text(
                  'Loading...',
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Please wait while we process your request',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    color: Colors.white70,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                // Loading Indicator
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      strokeWidth: 3,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showRoleSelectionDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Select Role',
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 20),
                _buildRoleOption(
                  'Hospital',
                  'Manage hospital operations',
                  [
                    const Color(0xFF4CAF50),
                    const Color(0xFF81C784)
                  ], // Hospital green gradient
                  Icons.local_hospital,
                  () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const UniversalSignupScreen(
                            userType: UserType.hospital),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
                _buildRoleOption(
                  'Doctor',
                  'Provide medical care',
                  [
                    const Color(0xFF2196F3),
                    const Color(0xFF64B5F6)
                  ], // Doctor blue gradient
                  Icons.person,
                  () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const UniversalSignupScreen(
                            userType: UserType.doctor),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
                _buildRoleOption(
                  'Nurse',
                  'Patient care and support',
                  [
                    const Color(0xFFC084FC),
                    const Color(0xFFA78BFA)
                  ], // Nurse gradient
                  Icons.medical_services,
                  () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const UniversalSignupScreen(
                            userType: UserType.nurse),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
                _buildRoleOption(
                  'Lab',
                  'Laboratory services',
                  [
                    const Color(0xFFFDBA74),
                    const Color(0xFFFB923C)
                  ], // Lab green-blue gradient
                  Icons.science,
                  () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            const UniversalSignupScreen(userType: UserType.lab),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
                _buildRoleOption(
                  'Pharmacy',
                  'Medication management',
                  [
                    const Color(0xFFFFD700),
                    const Color(0xFFFFA500)
                  ], // Pharmacy yellow gradient
                  Icons.local_pharmacy,
                  () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const UniversalSignupScreen(
                            userType: UserType.pharmacy),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
                _buildRoleOption(
                  'Patient',
                  'Access healthcare services',
                  [
                    const Color(0xFF32CCBC),
                    const Color(0xFF90F7EC)
                  ], // Patient blue gradient
                  Icons.person,
                  () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const UniversalSignupScreen(
                            userType: UserType.patient),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRoleOption(String title, String description, List<Color> colors,
      IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: colors,
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: colors[0].withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
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
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    description,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: Colors.white,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  void _showSuccessPopup() async {
    // Get the user type from SharedPreferences to ensure we navigate to the correct dashboard
    final prefs = await SharedPreferences.getInstance();
    final userType = prefs.getString('user_type') ?? _selectedUserType;

    print(
        '🎯 _showSuccessPopup - navigating with userType: $userType (from SharedPreferences)');

    // No popup needed - go directly to dashboard
    _navigateToDashboard(userType);
  }

  void _showFailurePopup(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Login Failed',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: Text(
          message,
          style: GoogleFonts.poppins(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK', style: GoogleFonts.poppins()),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Get the selected user type colors
    final selectedUserType = _userTypes.firstWhere(
      (type) => type['type'] == _selectedUserType,
      orElse: () => _userTypes[0],
    );
    final gradientColors = selectedUserType['colors'] as List<Color>;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradientColors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: _loading
              ? _buildProcessingScreen()
              : Center(
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: GlassmorphicContainer(
                        width: double.infinity,
                        height: MediaQuery.of(context).size.height *
                            0.85, // Reduced height
                        borderRadius: 32,
                        blur: 12,
                        alignment: Alignment.center,
                        border: 1.5,
                        linearGradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.white.withOpacity(0.9),
                            Colors.white.withOpacity(0.8),
                          ],
                        ),
                        borderGradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            gradientColors[0].withOpacity(0.3),
                            gradientColors[1].withOpacity(0.3),
                          ],
                        ),
                        child: SingleChildScrollView(
                          // Added scrollable content
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Image.asset(
                                'assets/images/logo.png',
                                height: 100, // Reduced from 120
                                width: 100, // Reduced from 120
                              ),
                              const SizedBox(height: 16), // Reduced from 20
                              Text(
                                'Welcome Back!',
                                style: GoogleFonts.poppins(
                                  fontSize: 24, // Reduced from 28
                                  fontWeight: FontWeight.bold,
                                  color: gradientColors[0],
                                ),
                              ),
                              const SizedBox(height: 6), // Reduced from 8
                              Text(
                                'Sign in to continue your health journey',
                                style: GoogleFonts.poppins(
                                  fontSize: 14, // Reduced from 16
                                  color: Colors.grey[600],
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 24), // Reduced from 32
                              Form(
                                key: _formKey,
                                child: Column(
                                  children: [
                                    // User Type Selection
                                    Container(
                                      margin: const EdgeInsets.only(
                                          bottom: 16), // Reduced from 20
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Select Your Role',
                                            style: GoogleFonts.poppins(
                                              fontSize: 14, // Reduced from 16
                                              fontWeight: FontWeight.w600,
                                              color: Colors.grey[700],
                                            ),
                                          ),
                                          const SizedBox(
                                              height: 8), // Reduced from 12
                                          Container(
                                            height: 45, // Reduced from 50
                                            child: ListView.builder(
                                              scrollDirection: Axis.horizontal,
                                              itemCount: _userTypes.length,
                                              itemBuilder: (context, index) {
                                                final userType =
                                                    _userTypes[index];
                                                final isSelected =
                                                    _selectedUserType ==
                                                        userType['type'];

                                                return GestureDetector(
                                                  onTap: () {
                                                    setState(() {
                                                      _selectedUserType =
                                                          userType['type'];
                                                    });
                                                  },
                                                  child: Container(
                                                    margin:
                                                        const EdgeInsets.only(
                                                            right: 12),
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        horizontal: 16,
                                                        vertical: 8),
                                                    decoration: BoxDecoration(
                                                      gradient: LinearGradient(
                                                        colors: isSelected
                                                            ? userType['colors']
                                                            : [
                                                                Colors
                                                                    .grey[300]!,
                                                                Colors
                                                                    .grey[300]!
                                                              ],
                                                        begin: Alignment
                                                            .centerLeft,
                                                        end: Alignment
                                                            .centerRight,
                                                      ),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              25),
                                                      boxShadow: isSelected
                                                          ? [
                                                              BoxShadow(
                                                                color: userType[
                                                                            'colors']
                                                                        [0]
                                                                    .withOpacity(
                                                                        0.3),
                                                                blurRadius: 8,
                                                                offset:
                                                                    const Offset(
                                                                        0, 3),
                                                              ),
                                                            ]
                                                          : null,
                                                    ),
                                                    child: Row(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: [
                                                        Icon(
                                                          userType['icon'],
                                                          color: isSelected
                                                              ? Colors.white
                                                              : Colors
                                                                  .grey[600],
                                                          size: 20,
                                                        ),
                                                        const SizedBox(
                                                            width: 8),
                                                        Text(
                                                          userType['label'],
                                                          style: GoogleFonts
                                                              .poppins(
                                                            fontSize: 14,
                                                            fontWeight:
                                                                FontWeight.w600,
                                                            color: isSelected
                                                                ? Colors.white
                                                                : Colors
                                                                    .grey[600],
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                );
                                              },
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: gradientColors,
                                          begin: Alignment.centerLeft,
                                          end: Alignment.centerRight,
                                        ),
                                        borderRadius: BorderRadius.circular(24),
                                        boxShadow: [
                                          BoxShadow(
                                            color: gradientColors[0]
                                                .withOpacity(0.2),
                                            blurRadius: 15,
                                            offset: const Offset(0, 5),
                                          ),
                                        ],
                                      ),
                                      child: Container(
                                        margin: const EdgeInsets.all(2),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius:
                                              BorderRadius.circular(22),
                                        ),
                                        child: TextFormField(
                                          controller: _emailController,
                                          decoration: InputDecoration(
                                            hintText: 'Email',
                                            prefixIcon: Icon(
                                                EvaIcons.emailOutline,
                                                color: gradientColors[0]),
                                            border: InputBorder.none,
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                                    horizontal: 20,
                                                    vertical: 16),
                                          ),
                                          keyboardType:
                                              TextInputType.emailAddress,
                                          validator: (value) {
                                            if (value == null ||
                                                value.isEmpty) {
                                              return 'Please enter your email';
                                            }
                                            return null;
                                          },
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 20),
                                    Container(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: gradientColors,
                                          begin: Alignment.centerLeft,
                                          end: Alignment.centerRight,
                                        ),
                                        borderRadius: BorderRadius.circular(24),
                                        boxShadow: [
                                          BoxShadow(
                                            color: gradientColors[0]
                                                .withOpacity(0.2),
                                            blurRadius: 15,
                                            offset: const Offset(0, 5),
                                          ),
                                        ],
                                      ),
                                      child: Container(
                                        margin: const EdgeInsets.all(2),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius:
                                              BorderRadius.circular(22),
                                        ),
                                        child: TextFormField(
                                          controller: _passwordController,
                                          decoration: InputDecoration(
                                            hintText: 'Password',
                                            prefixIcon: Icon(
                                                EvaIcons.lockOutline,
                                                color: gradientColors[0]),
                                            suffixIcon: IconButton(
                                              icon: Icon(
                                                _obscurePassword
                                                    ? EvaIcons.eyeOffOutline
                                                    : EvaIcons.eyeOutline,
                                                color: gradientColors[0],
                                              ),
                                              onPressed: () {
                                                setState(() {
                                                  _obscurePassword =
                                                      !_obscurePassword;
                                                });
                                              },
                                            ),
                                            border: InputBorder.none,
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                                    horizontal: 20,
                                                    vertical: 16),
                                          ),
                                          obscureText: _obscurePassword,
                                          validator: (value) {
                                            if (value == null ||
                                                value.isEmpty) {
                                              return 'Please enter your password';
                                            }
                                            return null;
                                          },
                                        ),
                                      ),
                                    ),
                                    const SizedBox(
                                        height: 24), // Reduced from 32
                                    Container(
                                      width: double.infinity,
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: gradientColors,
                                          begin: Alignment.centerLeft,
                                          end: Alignment.centerRight,
                                        ),
                                        borderRadius: BorderRadius.circular(24),
                                        boxShadow: [
                                          BoxShadow(
                                            color: gradientColors[0]
                                                .withOpacity(0.3),
                                            blurRadius: 15,
                                            offset: const Offset(0, 8),
                                          ),
                                        ],
                                      ),
                                      child: ElevatedButton(
                                        onPressed: _handleEmailLogin,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.transparent,
                                          shadowColor: Colors.transparent,
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(24),
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 14), // Reduced from 16
                                        ),
                                        child: Text(
                                          'Login',
                                          style: GoogleFonts.poppins(
                                            fontSize: 16, // Reduced from 18
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(
                                        height: 16), // Reduced from 20
                                    Container(
                                      width: double.infinity,
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: gradientColors,
                                          begin: Alignment.centerLeft,
                                          end: Alignment.centerRight,
                                        ),
                                        borderRadius: BorderRadius.circular(24),
                                        boxShadow: [
                                          BoxShadow(
                                            color: gradientColors[0]
                                                .withOpacity(0.3),
                                            blurRadius: 15,
                                            offset: const Offset(0, 8),
                                          ),
                                        ],
                                      ),
                                      child: ElevatedButton.icon(
                                        onPressed: _handleGoogleSignIn,
                                        icon: const Icon(
                                          Icons.g_mobiledata,
                                          color: Colors.white,
                                          size: 24,
                                        ),
                                        label: Text(
                                          'Continue with Google',
                                          style: GoogleFonts.poppins(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.white,
                                          ),
                                        ),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.transparent,
                                          shadowColor: Colors.transparent,
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(24),
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 16),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 32),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          "Don't have an account? ",
                                          style: GoogleFonts.poppins(
                                            fontSize: 14,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                        GestureDetector(
                                          onTap: () {
                                            _showRoleSelectionDialog();
                                          },
                                          child: Text(
                                            'Sign Up',
                                            style: GoogleFonts.poppins(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: gradientColors[0],
                                            ),
                                          ),
                                        ),
                                      ],
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
}
