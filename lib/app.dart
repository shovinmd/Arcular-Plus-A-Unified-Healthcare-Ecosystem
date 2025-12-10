import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:arcular_plus/screens/auth/select_user_type.dart';
import 'config/themes.dart';
import 'package:arcular_plus/screens/hospital/dashboard_hospital.dart';
import 'package:arcular_plus/screens/user/dashboard_user.dart';
import 'package:arcular_plus/services/api_service.dart';
import 'package:arcular_plus/models/user_model.dart';
import 'package:arcular_plus/screens/doctor/dashboard_doctor.dart';
import 'package:arcular_plus/screens/lab/dashboard_lab.dart';
import 'package:arcular_plus/screens/pharmacy/dashboard_pharmacy.dart';
import 'package:arcular_plus/screens/nurse/dashboard_nurse.dart';
import 'package:arcular_plus/screens/user/pregnancy_tracking_screen.dart';
import 'package:arcular_plus/screens/user/pregnancy_blog_screen.dart';
import 'package:arcular_plus/screens/auth/approval_pending_screen.dart';
import 'package:arcular_plus/screens/user/cart_screen.dart';
import 'package:arcular_plus/screens/user/my_orders_screen.dart';
import 'package:arcular_plus/screens/user/rating_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async'; // Added for StreamSubscription

class ArcularPlusApp extends StatelessWidget {
  final bool isWebVersion;

  const ArcularPlusApp({super.key, this.isWebVersion = false});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Arcular+',
      theme: userTheme,
      debugShowCheckedModeBanner: false,
      home: AuthWrapper(isWebVersion: isWebVersion),
      routes: {
        '/doctor_dashboard': (context) => const DashboardDoctor(),
        '/lab_dashboard': (context) => const LabDashboardScreen(),
        '/pharmacy-dashboard': (context) => const DashboardPharmacy(),
        '/hospital-dashboard': (context) => const HospitalDashboardScreen(),
        '/pregnancy-tracking': (context) => const PregnancyTrackingScreen(),
        '/pregnancy-blog': (context) => const PregnancyBlogScreen(),
        '/approval-pending': (context) => const ApprovalPendingScreen(),
        '/cart': (context) => const CartScreen(),
        '/my_orders': (context) => const MyOrdersScreen(),
        '/rating': (context) {
          final args = ModalRoute.of(context)!.settings.arguments
              as Map<String, dynamic>;
          return RatingScreen(
            orderId: args['orderId'],
            orderItems: args['orderItems'],
            pharmacyName: args['pharmacyName'],
          );
        },
      },
    );
  }
}

class AuthWrapper extends StatefulWidget {
  final bool isWebVersion;

  const AuthWrapper({super.key, this.isWebVersion = false});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  UserModel? _userModel;
  bool _loading = true;
  bool _showingSuccess = false;
  String? _error;
  StreamSubscription<User?>? _authStateSubscription;
  bool _isCheckingAuth =
      false; // Flag to prevent multiple simultaneous auth checks
  int _authStateChangeCount = 0; // Counter to track auth state changes

  @override
  void initState() {
    super.initState();
    print('🚀 AuthWrapper initialized');
    // Don't immediately check auth - let the auth state listener handle it
    // This prevents interference with the login process
    _setupAuthListener();
  }

  void _setupAuthListener() {
    _authStateSubscription =
        FirebaseAuth.instance.authStateChanges().listen((User? user) {
      _authStateChangeCount++;
      print('🔄 Auth state changed #$_authStateChangeCount: ${user?.uid}');
      if (user == null) {
        // User signed out
        print('👋 User signed out, clearing state');
        if (mounted) {
          setState(() {
            _userModel = null;
            _loading = false;
          });
        }
      } else {
        // User signed in or token refreshed
        print('🔐 User signed in: ${user.uid}');
        if (_userModel == null) {
          // Add a longer delay to allow the login process to complete
          // and prevent race conditions
          print('⏳ Waiting before checking auth...');
          Future.delayed(const Duration(seconds: 2), () {
            // Double-check that user is still logged in and component is mounted
            final currentUser = FirebaseAuth.instance.currentUser;
            if (mounted &&
                currentUser?.uid == user.uid &&
                currentUser != null) {
              print('✅ User still logged in, proceeding with auth check...');
              _checkAuth();
            } else {
              print(
                  '❌ User changed, logged out, or component unmounted, skipping auth check');
              print('   - Current user: ${currentUser?.uid}');
              print('   - Original user: ${user.uid}');
              print('   - Component mounted: $mounted');
            }
          });
        } else {
          print('ℹ️ User model already exists, skipping auth check');
        }
      }
    });
  }

  @override
  void dispose() {
    _authStateSubscription?.cancel();
    super.dispose();
  }

  void _checkAuth() async {
    // Prevent multiple simultaneous auth checks
    if (_isCheckingAuth) {
      print('⚠️ Auth check already in progress, skipping...');
      return;
    }

    _isCheckingAuth = true;

    try {
      print('🔍 Starting authentication check...');
      final user = FirebaseAuth.instance.currentUser;
      print('👤 Current user: ${user?.uid}');

      if (user != null) {
        print('✅ User is authenticated, fetching user data...');

        // Check SharedPreferences values for debugging
        final prefs = await SharedPreferences.getInstance();
        final storedUserType = prefs.getString('user_type');
        final storedUserUid = prefs.getString('user_uid');
        print(
            '🔍 SharedPreferences - user_type: $storedUserType, user_uid: $storedUserUid');

        try {
          // Check if token is still valid
          await user.getIdToken(true); // Force refresh
          print('🔑 Token refreshed successfully');

          // Try fetching user info from backend using universal getUserInfo
          print('🌐 Fetching user info from backend...');
          final userModel = await ApiService.getUserInfo(user.uid);
          print(
              '✅ User model received: ${userModel?.fullName}, type: ${userModel?.type}');

          if (mounted && FirebaseAuth.instance.currentUser?.uid == user.uid) {
            print('🎯 Setting user model and clearing loading state...');
            setState(() {
              _userModel = userModel;
              _loading = false;
              _error = null; // Clear any previous errors
            });
            print('✅ State updated successfully');
            // Show success screen briefly before navigating
            setState(() {
              _showingSuccess = true;
            });
            // Hide success screen after 2 seconds and proceed to dashboard
            Timer(const Duration(seconds: 2), () {
              if (mounted) {
                setState(() {
                  _showingSuccess = false;
                });
              }
            });
          } else {
            print('⚠️ Component unmounted or user changed during fetch');
          }
        } catch (e) {
          print('⚠️ Error fetching user info: $e');
          // Don't immediately set error, try to refresh token first
          try {
            print('🔄 Attempting token refresh and retry...');
            await user.getIdToken(true);
            print('🔄 Token refreshed, retrying user info fetch...');
            final userModel = await ApiService.getUserInfo(user.uid);
            if (mounted && FirebaseAuth.instance.currentUser?.uid == user.uid) {
              print('✅ Retry successful, updating state...');
              setState(() {
                _userModel = userModel;
                _loading = false;
                _error = null;
              });
            } else {
              print('⚠️ Component unmounted or user changed during retry');
            }
          } catch (retryError) {
            print('❌ Retry failed: $retryError');
            // Only set error if user is still logged in
            if (mounted && FirebaseAuth.instance.currentUser?.uid == user.uid) {
              print('❌ Setting error state...');
              setState(() {
                _error =
                    'Failed to load user data. Please try logging in again.';
                _loading = false;
              });
            }
          }
        }
      } else {
        print('❌ No user logged in');
        if (mounted) {
          setState(() {
            _userModel = null;
            _loading = false;
            _error = null;
          });
        }
      }
    } catch (e) {
      print('❌ Error in _checkAuth: $e');
      if (mounted) {
        setState(() {
          _error = 'Authentication error: $e';
          _loading = false;
        });
      }
    } finally {
      _isCheckingAuth = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_showingSuccess) {
      return Scaffold(
        body: FutureBuilder<SharedPreferences>(
          future: SharedPreferences.getInstance(),
          builder: (context, snapshot) {
            String imagePath =
                'assets/images/Female/pat/happy.png'; // Default happy for female
            List<Color> gradientColors = [
              const Color(0xFF32CCBC), // Patient teal
              const Color(0xFF90F7EC),
            ];

            if (snapshot.hasData) {
              final gender =
                  snapshot.data!.getString('user_gender') ?? 'Female';
              final userType =
                  snapshot.data!.getString('user_type') ?? 'patient';

              // Gender-specific happy image on success
              if (gender == 'Male') {
                switch (userType) {
                  case 'doctor':
                    imagePath = 'assets/images/Male/doc/happy.png';
                    break;
                  case 'hospital':
                    imagePath =
                        'assets/images/Male/hosp/happy.png'; // Hospital-specific happy
                    break;
                  case 'lab':
                    imagePath =
                        'assets/images/Male/lab/clam.png'; // Lab-specific clam image
                    break;
                  case 'nurse':
                    imagePath =
                        'assets/images/Male/nurs/smile.png'; // Nurse-specific smile image
                    break;
                  case 'pharmacy':
                    imagePath =
                        'assets/images/Male/pharm/happy.png'; // Pharmacy-specific happy image
                    break;
                  default: // patient
                    imagePath = 'assets/images/Male/pat/happy.png';
                    break;
                }
              } else if (gender == 'Female') {
                switch (userType) {
                  case 'doctor':
                    imagePath = 'assets/images/Female/doc/happy.png';
                    break;
                  case 'hospital':
                    imagePath =
                        'assets/images/Female/hosp/happy.png'; // Hospital-specific happy
                    break;
                  case 'lab':
                    imagePath =
                        'assets/images/Female/lab/happy.png'; // Lab-specific happy image
                    break;
                  case 'nurse':
                    imagePath =
                        'assets/images/Female/nurs/happy.png'; // Nurse-specific happy image
                    break;
                  case 'pharmacy':
                    imagePath =
                        'assets/images/Female/pharm/happy.png'; // Pharmacy-specific happy image
                    break;
                  default: // patient
                    imagePath = 'assets/images/Female/pat/happy.png';
                    break;
                }
              } else {
                // Default to Female images for 'Other' gender
                switch (userType) {
                  case 'doctor':
                    imagePath = 'assets/images/Female/doc/happy.png';
                    break;
                  case 'hospital':
                    imagePath =
                        'assets/images/Female/hosp/happy.png'; // Hospital-specific happy
                    break;
                  case 'lab':
                    imagePath =
                        'assets/images/Female/lab/happy.png'; // Lab-specific happy image
                    break;
                  case 'nurse':
                    imagePath =
                        'assets/images/Female/nurs/happy.png'; // Nurse-specific happy image
                    break;
                  case 'pharmacy':
                    imagePath =
                        'assets/images/Female/pharm/happy.png'; // Pharmacy-specific happy image
                    break;
                  default: // patient
                    imagePath = 'assets/images/Female/pat/happy.png';
                    break;
                }
              }

              // Role-based gradient colors
              switch (userType) {
                case 'doctor':
                  gradientColors = [
                    const Color(0xFF2196F3),
                    const Color(0xFF64B5F6)
                  ]; // Doctor blue
                  break;
                case 'hospital':
                  gradientColors = [
                    const Color(0xFF4CAF50),
                    const Color(0xFF81C784)
                  ]; // Hospital green
                  break;
                case 'lab':
                  gradientColors = [
                    const Color(0xFFFF9800),
                    const Color(0xFFFFB74D)
                  ]; // Lab orange
                  break;
                case 'nurse':
                  gradientColors = [
                    const Color(0xFF9C27B0),
                    const Color(0xFFBA68C8)
                  ]; // Nurse purple
                  break;
                case 'pharmacy':
                  gradientColors = [
                    const Color(0xFFFFD700),
                    const Color(0xFFFFA500)
                  ]; // Pharmacy orange/yellow theme
                  break;
                default: // patient
                  gradientColors = [
                    const Color(0xFF32CCBC),
                    const Color(0xFF90F7EC)
                  ]; // Patient teal
                  break;
              }
            }

            return Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: gradientColors,
                ),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Gender-specific happy image with celebration animation
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 1.0, end: 1.3),
                      duration: const Duration(milliseconds: 800),
                      builder: (context, value, child) {
                        return Transform.scale(
                          scale: value,
                          child: Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.3),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.white.withOpacity(0.5),
                                  blurRadius: 25,
                                  spreadRadius: 8,
                                ),
                              ],
                            ),
                            child: Image.asset(
                              imagePath,
                              width: 120,
                              height: 120,
                              fit: BoxFit.contain,
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 32),

                    // Success message
                    Text(
                      'Welcome Back!',
                      style: GoogleFonts.poppins(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Loading your dashboard...',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );
    }

    if (_loading) {
      return Scaffold(
        body: FutureBuilder<SharedPreferences>(
          future: SharedPreferences.getInstance(),
          builder: (context, snapshot) {
            String imagePath =
                'assets/images/Female/pat/think.png'; // Default to think for female
            List<Color> gradientColors = [
              const Color(0xFF32CCBC), // Patient teal
              const Color(0xFF90F7EC),
            ];

            if (snapshot.hasData) {
              final gender =
                  snapshot.data!.getString('user_gender') ?? 'Female';
              final userType =
                  snapshot.data!.getString('user_type') ?? 'patient';

              // Gender-specific role-based images while loading
              if (gender == 'Male') {
                // Use role-specific images for males
                switch (userType) {
                  case 'doctor':
                    imagePath =
                        'assets/images/Male/doc/good.png'; // Male doctor good image
                    break;
                  case 'hospital':
                    imagePath =
                        'assets/images/Male/hosp/think.png'; // Hospital-specific image
                    break;
                  case 'lab':
                    imagePath = 'assets/images/Male/lab/think.png';
                    break;
                  case 'nurse':
                    imagePath = 'assets/images/Male/nurs/think.png';
                    break;
                  case 'pharmacy':
                    imagePath =
                        'assets/images/Male/pharm/think.png'; // Pharmacy-specific image
                    break;
                  default: // patient
                    imagePath = 'assets/images/Male/pat/think.png';
                    break;
                }
              } else if (gender == 'Female') {
                // Use role-specific images for females
                switch (userType) {
                  case 'doctor':
                    imagePath = 'assets/images/Female/doc/think.png';
                    break;
                  case 'hospital':
                    imagePath =
                        'assets/images/Female/hosp/think.png'; // Hospital-specific image
                    break;
                  case 'lab':
                    imagePath = 'assets/images/Female/lab/think.png';
                    break;
                  case 'nurse':
                    imagePath = 'assets/images/Female/nurs/think.png';
                    break;
                  case 'pharmacy':
                    imagePath = 'assets/images/Female/pharm/think.png';
                    break;
                  default: // patient
                    imagePath = 'assets/images/Female/pat/think.png';
                    break;
                }
              } else {
                // Default to Female images for 'Other' gender
                switch (userType) {
                  case 'doctor':
                    imagePath = 'assets/images/Female/doc/think.png';
                    break;
                  case 'hospital':
                    imagePath =
                        'assets/images/Female/hosp/think.png'; // Hospital-specific image
                    break;
                  case 'lab':
                    imagePath = 'assets/images/Female/lab/think.png';
                    break;
                  case 'nurse':
                    imagePath = 'assets/images/Female/nurs/think.png';
                    break;
                  case 'pharmacy':
                    imagePath = 'assets/images/Female/pharm/think.png';
                    break;
                  default: // patient
                    imagePath = 'assets/images/Female/pat/think.png';
                    break;
                }
              }

              // Role-based gradient colors
              switch (userType) {
                case 'doctor':
                  gradientColors = [
                    const Color(0xFF2196F3),
                    const Color(0xFF64B5F6)
                  ]; // Doctor blue
                  break;
                case 'hospital':
                  gradientColors = [
                    const Color(0xFF4CAF50),
                    const Color(0xFF81C784)
                  ]; // Hospital green
                  break;
                case 'lab':
                  gradientColors = [
                    const Color(0xFFFF9800),
                    const Color(0xFFFFB74D)
                  ]; // Lab orange
                  break;
                case 'nurse':
                  gradientColors = [
                    const Color(0xFF9C27B0),
                    const Color(0xFFBA68C8)
                  ]; // Nurse purple
                  break;
                case 'pharmacy':
                  gradientColors = [
                    const Color(0xFFFFD700),
                    const Color(0xFFFFA500)
                  ]; // Pharmacy orange/yellow theme
                  break;
                default: // patient
                  gradientColors = [
                    const Color(0xFF32CCBC),
                    const Color(0xFF90F7EC)
                  ]; // Patient teal
                  break;
              }
            }

            return Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: gradientColors,
                ),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Gender-specific role image with glassmorphism and zoom animation
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.8, end: 1.2),
                      duration: const Duration(seconds: 2),
                      builder: (context, value, child) {
                        return Transform.scale(
                          scale: value,
                          child: Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.white.withOpacity(0.3),
                                  blurRadius: 20,
                                  spreadRadius: 5,
                                ),
                              ],
                            ),
                            child: Image.asset(
                              imagePath,
                              width: 120,
                              height: 120,
                              fit: BoxFit.contain,
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 32),

                    // Loading message
                    Text(
                      'Loading...',
                      style: GoogleFonts.poppins(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Loading spinner
                    SizedBox(
                      width: 30,
                      height: 30,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 3,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text(
                  'Error',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _loading = true;
                      _error = null;
                    });
                    _checkAuth();
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_userModel != null) {
      // Route based on user type
      print('🎯 AuthWrapper routing user type: ${_userModel!.type}');

      // Check if user type needs approval
      if (_userModel!.type == 'hospital' ||
          _userModel!.type == 'doctor' ||
          _userModel!.type == 'nurse' ||
          _userModel!.type == 'lab' ||
          _userModel!.type == 'pharmacy') {
        // Check approval status for service providers
        if (_userModel!.isApproved != true ||
            _userModel!.approvalStatus != 'approved') {
          print(
              '⏳ Service provider not approved, showing approval pending screen');
          return ApprovalPendingScreen(userType: _userModel!.type);
        }
      }

      switch (_userModel!.type) {
        case 'hospital':
          print('🏥 AuthWrapper: Navigating to HospitalDashboardScreen');
          return const HospitalDashboardScreen();
        case 'doctor':
          print('👨‍⚕️ AuthWrapper: Navigating to DashboardDoctor');
          return const DashboardDoctor();
        case 'lab':
          print('🔬 AuthWrapper: Navigating to LabDashboardScreen');
          return const LabDashboardScreen();
        case 'pharmacy':
          print('💊 AuthWrapper: Navigating to DashboardPharmacy');
          return const DashboardPharmacy();
        case 'nurse':
          print('👩‍⚕️ AuthWrapper: Navigating to NurseDashboardScreen');
          return const NurseDashboardScreen();
        case 'patient':
        default:
          print('👤 AuthWrapper: Navigating to DashboardUser (patient)');
          return const DashboardUser();
      }
    }

    return SelectUserTypeScreen(isWebVersion: widget.isWebVersion);
  }
}
