import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'package:arcular_plus/utils/constants.dart';
import 'package:arcular_plus/utils/user_type_enum.dart';
import 'package:arcular_plus/screens/user/ai_chatbot_screen.dart';
import 'package:arcular_plus/screens/user/appointment_booking_screen.dart';
import 'package:arcular_plus/screens/user/calendar_user.dart';
import 'package:arcular_plus/screens/user/update_profile_screen.dart';
import 'package:arcular_plus/screens/user/emergency_sos_screen.dart';
import 'package:arcular_plus/screens/user/medicine_user.dart';
import 'package:arcular_plus/screens/user/report_user.dart';
import 'package:arcular_plus/screens/user/prescription_screen.dart';
import 'package:arcular_plus/screens/user/lab_reports_screen.dart';
import 'package:arcular_plus/screens/user/medicine_order_screen.dart';
import 'package:arcular_plus/screens/user/pregnancy_tracking_screen.dart';
import 'package:arcular_plus/screens/user/pregnancy_blog_screen.dart';
import 'package:arcular_plus/screens/user/notifications_screen.dart';
import 'package:arcular_plus/screens/user/health_history_screen.dart';
import 'package:arcular_plus/screens/user/profile_screen.dart';
import 'package:arcular_plus/screens/user/user_settings_screen.dart';
import 'package:arcular_plus/screens/user/menstrual_cycle_screen.dart';
import 'package:arcular_plus/screens/user/bmi_calculator_screen.dart';
import 'package:arcular_plus/screens/scanner_screen.dart';
import 'package:arcular_plus/screens/auth/login_screen.dart';
import 'package:arcular_plus/services/api_service.dart';
import 'package:arcular_plus/services/auth_service.dart';
import 'package:arcular_plus/services/fcm_service.dart';
import 'package:arcular_plus/widgets/custom_button.dart';
import 'package:arcular_plus/widgets/chatarc_floating_button.dart';
import 'package:arcular_plus/models/user_model.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:glassmorphism/glassmorphism.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'dart:convert';

// Add color constants at the top
const Color kBackground = Color(0xFFF9FAFB);
const Color kPrimaryText = Color(0xFF2E2E2E);
const Color kSecondaryText = Color(0xFF6B7280);
const Color kBorder = Color(0xFFE5E7EB);
const Color kSuccess = Color(0xFFA3E635);
const Color kUserBlue = Color(0xFF0057A0);

class DashboardUser extends StatefulWidget {
  const DashboardUser({super.key});

  @override
  State<DashboardUser> createState() => _DashboardUserState();
}

class _DashboardUserState extends State<DashboardUser>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  int _selectedIndex = 0;
  DateTime? _lastBackPressedAt;
  UserModel? _currentUser;
  bool _pregnancyTrackingEnabled = false;
  String _babyName = '';
  DateTime? _dueDate;
  double? _babyWeightAtBirth;

  int _appointmentsCount = 0;
  int _medicationsCount = 0;
  int _reportsCount = 0;
  bool _loadingCounts = true;

  // New fields for enhanced dashboard
  Map<String, dynamic>? _healthSummary;

  bool _loadingHealthData = true;

  String? _cachedGender;
  String? _cachedType;

  // FCM notification related fields
  final FCMService _fcmService = FCMService();
  int _notificationCount = 0;
  bool _fcmInitialized = false;
  List<Map<String, dynamic>> _upcomingReminders = [];

  // Timer for periodic refresh
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadCachedUserInfo();
    _loadUserData();
    _loadCounts();
    _loadHealthData();
    _initializeFCM();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh counts when dependencies change (e.g., returning from other screens)
    _loadCounts();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Refresh counts when app becomes active
      _loadCounts();
      // Also refresh reminders to get latest data
      _loadUpcomingReminders();
    }
  }

  // Method to manually refresh counts
  Future<void> _refreshDashboardCounts() async {
    await _loadCounts();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Dashboard refreshed! Reports: $_reportsCount'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    super.dispose();
  }

  // Override wake word navigation methods
  @override
  void _navigateToChat() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AIChatbotScreen()),
    );
  }

  @override
  void _navigateToChatWithVoice() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AIChatbotScreen()),
    );
  }

  @override
  void _navigateToChatWithImage() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AIChatbotScreen()),
    );
  }

  Future<void> _loadCachedUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _cachedGender = prefs.getString('user_gender');
      _cachedType = prefs.getString('user_type');
    });

    // Refresh reminders after loading user info (to filter by gender)
    await _loadUpcomingReminders();
  }

  Future<void> _loadUserData() async {
    try {
      final user = await AuthService().currentUser;
      if (user == null) return;

      print('👤 Loading patient data for UID: ${user.uid}');

      // Use universal getUserInfo method which respects user type
      final userModel = await ApiService.getUserInfo(user.uid);

      if (userModel != null) {
        print('✅ Patient data loaded successfully: ${userModel.fullName}');
        setState(() {
          _currentUser = userModel;
        });
      } else {
        print('❌ Patient data not found');
      }
    } catch (e) {
      print('❌ Error loading patient data: $e');
      // Show error message to user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error connecting to server: $e'),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: 'Retry',
              onPressed: () => _loadUserData(),
            ),
          ),
        );
      }
    }
  }

  Future<void> _loadCounts() async {
    setState(() => _loadingCounts = true);
    final user = FirebaseAuth.instance.currentUser;
    print('🔍 Dashboard _loadCounts - Firebase user: ${user?.uid}');
    if (user == null) return;

    try {
      // Use the exact same method as the reports screen
      print('🔍 Dashboard: Loading counts for user: ${user.uid}');
      print('🔍 Dashboard: Calling ApiService.getAppointments...');
      final appointments = await ApiService.getAppointments(user.uid);
      print('🔍 Dashboard: Appointments loaded: ${appointments.length}');

      print('🔍 Dashboard: Calling ApiService.getMedications...');
      final medications = await ApiService.getMedications(user.uid);
      print('🔍 Dashboard: Medications loaded: ${medications.length}');

      print('🔍 Dashboard: Calling ApiService.getReportsByUser...');
      final userReports = await ApiService.getReportsByUser(user.uid);
      print('🔍 Dashboard: User reports loaded: ${userReports.length}');

      // Also get lab reports by ARC ID
      int labReportsCount = 0;
      try {
        final userInfo = await ApiService.getUserInfo(user.uid);
        if (userInfo != null) {
          final arcId = userInfo.healthQrId ?? userInfo.arcId;
          if (arcId != null && arcId.isNotEmpty) {
            print('🔍 Dashboard: Getting lab reports for ARC ID: $arcId');
            final labReports = await ApiService.getLabReportsByArcId(arcId);
            labReportsCount = labReports.length;
            print('🔍 Dashboard: Lab reports loaded: $labReportsCount');
          }
        }
      } catch (e) {
        print('❌ Error loading lab reports for dashboard: $e');
      }

      final totalReports = userReports.length + labReportsCount;
      print('🔍 Dashboard: Total reports (user + lab): $totalReports');

      print(
          '🔍 Dashboard: Final counts - Appointments: ${appointments.length}, Medications: ${medications.length}, Total Reports: $totalReports');

      // Filter out completed and consultation_completed appointments for count
      final pendingAppointments = appointments
          .where((apt) =>
              apt.status.toLowerCase() != 'completed' &&
              apt.status.toLowerCase() != 'consultation_completed' &&
              apt.status.toLowerCase() != 'cancelled')
          .toList();

      setState(() {
        _appointmentsCount = pendingAppointments.length;
        _medicationsCount = medications.length;
        _reportsCount = totalReports;
        _loadingCounts = false;
      });
      print(
          '📊 Counts loaded: Appointments: $_appointmentsCount, Medications: $_medicationsCount, Total Reports: $_reportsCount');
    } catch (e) {
      print('❌ Error loading counts: $e');
      setState(() {
        _loadingCounts = false;
      });
    }
  }

  Future<void> _loadHealthData() async {
    setState(() => _loadingHealthData = true);
    final user = await AuthService().currentUser;
    if (user == null) return;

    try {
      // Load health summary
      final healthSummary = await ApiService.getUserHealthSummary(user.uid);

      setState(() {
        _healthSummary = healthSummary;
        _loadingHealthData = false;
      });
    } catch (e) {
      print('❌ Error loading health data: $e');
      setState(() {
        _loadingHealthData = false;
      });
    }
  }

  // Initialize FCM service
  Future<void> _initializeFCM() async {
    try {
      await _fcmService.initialize();
      setState(() {
        _fcmInitialized = true;
      });

      // Subscribe to patient-specific topics
      await _fcmService.subscribeToTopic('patients');
      await _fcmService.subscribeToTopic('general');

      // Load notification count
      await _loadNotificationCount();

      // Load upcoming reminders
      await _loadUpcomingReminders();

      // Listen for real-time updates
      _fcmService.events.listen((event) {
        final type = (event['type'] ?? '').toString().toLowerCase();
        print('📱 FCM Event received: $type');

        // Refresh counts when appointment, medication, or report data changes
        if (type.contains('appointment') ||
            type.contains('medication') ||
            type.contains('report') ||
            type.contains('order')) {
          print('🔄 Refreshing dashboard counts due to $type event');
          _loadCounts();
        }

        // Refresh notifications when notification events occur
        if (type.contains('notification') || type.contains('reminder')) {
          print('🔄 Refreshing notifications due to $type event');
          _loadNotificationCount();
          _loadUpcomingReminders();
        }
      });

      // Start periodic refresh every 30 seconds for real-time updates
      _startPeriodicRefresh();

      print('✅ FCM: Patient dashboard notifications initialized');
    } catch (e) {
      print('❌ FCM: Error initializing notifications: $e');
    }
  }

  // Start periodic refresh for real-time updates
  void _startPeriodicRefresh() {
    _refreshTimer?.cancel(); // Cancel any existing timer
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted) {
        print('🔄 Periodic refresh: Updating dashboard counts');
        _loadCounts();
        _loadNotificationCount();
        _loadUpcomingReminders();
      }
    });
  }

  // Load notification count
  Future<void> _loadNotificationCount() async {
    try {
      final user = await AuthService().currentUser;
      if (user == null) return;

      // Get unread notifications count from backend
      final response = await ApiService.getUnreadNotificationsCount(user.uid);
      setState(() {
        _notificationCount = response;
      });
    } catch (e) {
      print('❌ Error loading notification count: $e');
    }
  }

  // Refresh notifications
  Future<void> _refreshNotifications() async {
    await _loadNotificationCount();
    await _loadUpcomingReminders();
    await _showCustomPopup(success: true, message: 'Notifications refreshed!');
  }

  // Filter reminders based on individual user preferences
  Future<List<Map<String, dynamic>>> _filterRemindersByPreferences(
      List<Map<String, dynamic>> allReminders) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<Map<String, dynamic>> filteredReminders = [];

      for (final reminder in allReminders) {
        final type = reminder['type']?.toString().toLowerCase() ?? '';
        bool shouldShow = false;

        switch (type) {
          case 'next period':
            shouldShow = prefs.getBool('remind_next_period') ?? true;
            break;
          case 'ovulation':
            shouldShow = prefs.getBool('remind_ovulation') ?? true;
            break;
          case 'fertile window':
            shouldShow = prefs.getBool('remind_fertile_window') ?? true;
            break;
          default:
            shouldShow = true; // Show unknown types by default
        }

        if (shouldShow) {
          filteredReminders.add(reminder);
          print('✅ Dashboard: Including $type reminder (enabled)');
        } else {
          print('⚠️ Dashboard: Skipping $type reminder (disabled)');
        }
      }

      print(
          '✅ Dashboard: Filtered ${allReminders.length} reminders to ${filteredReminders.length} based on preferences');
      return filteredReminders;
    } catch (e) {
      print('❌ Dashboard: Error filtering reminders by preferences: $e');
      return allReminders; // Return all reminders if filtering fails
    }
  }

  // Load upcoming reminders
  Future<void> _loadUpcomingReminders() async {
    try {
      // Only load reminders for female users
      if (_cachedGender != 'Female') {
        setState(() {
          _upcomingReminders = [];
        });
        print('⚠️ User is male, skipping menstrual reminders');
        return;
      }

      // Use FCM service but ensure it gets the latest data
      if (_fcmInitialized) {
        final allReminders = await _fcmService.getUpcomingReminders();

        print(
            '🔍 Dashboard: Raw reminders from FCM service: ${allReminders.length}');
        for (final reminder in allReminders) {
          print(
              '   - Type: ${reminder['type']}, Title: ${reminder['title']}, Date: ${reminder['date']}');
        }

        // Filter reminders based on individual user preferences
        final filteredReminders =
            await _filterRemindersByPreferences(allReminders);

        setState(() {
          _upcomingReminders = filteredReminders;
        });
        print(
            '✅ Dashboard: Loaded ${filteredReminders.length} filtered reminders for female user');
        print(
            '✅ Dashboard: Reminders include: ${filteredReminders.map((r) => r['type']).toList()}');
      }
    } catch (e) {
      print('❌ Dashboard: Error loading upcoming reminders: $e');
    }
  }

  Future<void> _refreshDashboard() async {
    await _loadUserData();
    await _loadCounts();
    await _loadHealthData();
    await _loadUpcomingReminders(); // Refresh reminders with latest preferences
    await _showCustomPopup(success: true, message: 'Data updated!');
  }

  Future<void> _showCustomPopup(
      {required bool success, required String message}) async {
    final prefs = await SharedPreferences.getInstance();
    final gender = prefs.getString('user_gender') ?? 'Female';
    final userType = prefs.getString('user_type') ?? 'patient';

    String imagePath;
    List<Color> gradientColors;

    if (success) {
      imagePath = gender == 'Male'
          ? 'assets/images/Male/pat/love.png'
          : 'assets/images/Female/pat/love.png';
    } else {
      imagePath = gender == 'Male'
          ? 'assets/images/Male/pat/angry.png'
          : 'assets/images/Female/pat/angry.png';
    }

    // Role-based gradient colors
    switch (userType) {
      case 'doctor':
        gradientColors = success
            ? [const Color(0xFF2196F3), const Color(0xFF64B5F6)] // Doctor blue
            : [Colors.red[400]!, Colors.red[600]!];
        break;
      case 'hospital':
        gradientColors = success
            ? [
                const Color(0xFF4CAF50),
                const Color(0xFF81C784)
              ] // Hospital green
            : [Colors.red[400]!, Colors.red[600]!];
        break;
      case 'lab':
        gradientColors = success
            ? [const Color(0xFFFF9800), const Color(0xFFFFB74D)] // Lab orange
            : [Colors.red[400]!, Colors.red[600]!];
        break;
      case 'nurse':
        gradientColors = success
            ? [const Color(0xFF9C27B0), const Color(0xFFBA68C8)] // Nurse purple
            : [Colors.red[400]!, Colors.red[600]!];
        break;
      case 'pharmacy':
        gradientColors = success
            ? [
                const Color(0xFFFFD700),
                const Color(0xFFFFA500)
              ] // Pharmacy orange/yellow theme
            : [Colors.red[400]!, Colors.red[600]!];
        break;
      default: // patient
        gradientColors = success
            ? [const Color(0xFF32CCBC), const Color(0xFF90F7EC)] // Patient teal
            : [Colors.red[400]!, Colors.red[600]!];
        break;
    }

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.transparent, // Remove white background
        elevation: 0, // Remove shadow
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: gradientColors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Image.asset(imagePath,
                    width: 80, height: 80, fit: BoxFit.contain),
              ),
              const SizedBox(height: 16),
              Text(
                message,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.white,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
    );
    if (_currentUser == null) {
      // Show custom gradient loading screen instead of default spinner
      return Scaffold(
        body: FutureBuilder<SharedPreferences>(
          future: SharedPreferences.getInstance(),
          builder: (context, snapshot) {
            String imagePath =
                'assets/images/Female/pat/cry.png'; // Default to cry for female
            List<Color> gradientColors = [
              const Color(0xFF32CCBC), // Patient teal
              const Color(0xFF90F7EC),
            ];

            if (snapshot.hasData) {
              final gender =
                  snapshot.data!.getString('user_gender') ?? 'Female';
              final userType =
                  snapshot.data!.getString('user_type') ?? 'patient';

              // Gender-specific thinking image (use cry for females)
              if (gender == 'Male') {
                imagePath = 'assets/images/Male/pat/think.png';
              } else {
                // For females, use cry image consistently
                imagePath = 'assets/images/Female/pat/cry.png';
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
                  ]; // Pharmacy orange/yellow gradient
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
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: WillPopScope(
        onWillPop: () async {
          // If there is a route to pop in the current navigator stack, allow it
          if (Navigator.of(context).canPop()) {
            return true;
          }
          // If not on Home tab, go to Home instead of exiting
          if (_selectedIndex != 0) {
            setState(() {
              _selectedIndex = 0;
            });
            return false;
          }
          // On Home: require double back to exit
          final now = DateTime.now();
          if (_lastBackPressedAt == null ||
              now.difference(_lastBackPressedAt!) >
                  const Duration(seconds: 2)) {
            _lastBackPressedAt = now;
            if (mounted) {
              ScaffoldMessenger.of(context).removeCurrentSnackBar();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Press back again to exit')),
              );
            }
            return false;
          }
          return true; // Exit on second back within 2 seconds
        },
        child: Scaffold(
          backgroundColor: const Color(0xFFF5F6FA), // light gray
          appBar: AppBar(
            title: Text(
              'Patient Dashboard',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            backgroundColor: Colors.transparent,
            foregroundColor: Colors.white,
            elevation: 0,
            iconTheme: const IconThemeData(color: Colors.white),
            flexibleSpace: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFF32CCBC),
                    Color(0xFF90F7EC)
                  ], // Patient teal gradient
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.notifications, color: Colors.white),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const NotificationsScreen()),
                ),
              ),
              PopupMenuButton<String>(
                onSelected: _handleMenuSelection,
                icon: const Icon(Icons.more_vert, color: Colors.white),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'profile',
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFF32CCBC),
                            Color(0xFF90F7EC)
                          ], // Patient teal gradient
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      child: Row(
                        children: [
                          const Icon(Icons.person, color: Colors.white),
                          const SizedBox(width: 8),
                          Text(
                            'Profile',
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'logout',
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFFE57373),
                            Color(0xFFEF5350)
                          ], // Red gradient for logout
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      child: Row(
                        children: [
                          const Icon(Icons.logout, color: Colors.white),
                          const SizedBox(width: 8),
                          Text(
                            'Logout',
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          body: Stack(
            children: [
              _buildBody(),
              // Hide floating chat button on SOS screen
              if (_selectedIndex != 2)
                Positioned(
                  right: 16,
                  bottom: 80, // above the nav bar
                  child: ChatArcFloatingButton(userType: 'user'),
                ),
            ],
          ),
          // Hide bottom navigation bar on SOS screen
          bottomNavigationBar: _selectedIndex == 2
              ? null
              : BottomNavigationBar(
                  type: BottomNavigationBarType.fixed,
                  currentIndex: _selectedIndex,
                  onTap: (index) {
                    setState(() {
                      _selectedIndex = index;
                    });
                  },
                  selectedItemColor:
                      const Color(0xFF32CCBC), // Patient teal color
                  unselectedItemColor: Colors.grey,
                  backgroundColor: Colors.white,
                  items: const [
                    BottomNavigationBarItem(
                      icon: Icon(Icons.home),
                      label: 'Home',
                    ),
                    BottomNavigationBarItem(
                      icon: Icon(Icons.calendar_today),
                      label: 'Calendar',
                    ),
                    BottomNavigationBarItem(
                      icon: Icon(Icons.emergency, color: Colors.red),
                      label: 'SOS',
                    ),
                    BottomNavigationBarItem(
                      icon: Icon(Icons.medication),
                      label: 'Medicine',
                    ),
                    BottomNavigationBarItem(
                      icon: Icon(Icons.description),
                      label: 'Reports',
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    switch (_selectedIndex) {
      case 0:
        return _buildHomeScreen();
      case 1:
        return const CalendarUserScreen();
      case 2:
        return const EmergencySOSScreen();
      case 3:
        return const MedicineUserScreen();
      case 4:
        return const ReportUserScreen();
      default:
        return _buildHomeScreen();
    }
  }

  Widget _buildHomeScreen() {
    return RefreshIndicator(
      onRefresh: _refreshDashboard,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome Section
            _buildWelcomeSection(),
            const SizedBox(height: 24),

            // Upcoming Reminders Section
            _buildUpcomingRemindersSection(),
            const SizedBox(height: 24),
            // Pregnancy Tracking Section (only for currently pregnant females)
            if (_currentUser?.gender == 'Female' &&
                _currentUser?.isPregnant == true) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFFF857A6),
                      Color(0xFFFF5858)
                    ], // Pink gradient
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.pregnant_woman,
                            color: Colors.white, size: 24),
                        const SizedBox(width: 8),
                        Text(
                          'Pregnancy Tracking',
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Track your pregnancy journey with personalized care reminders and health monitoring.',
                      style: GoogleFonts.poppins(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () {
                              print('🔍 Track Pregnancy button clicked!');
                              print('🔍 Current context: $context');
                              print(
                                  '🔍 Navigator can pop: ${Navigator.canPop(context)}');

                              // Try multiple navigation approaches
                              try {
                                // Method 1: Direct push
                                Navigator.of(context)
                                    .pushNamed('/pregnancy-tracking');
                                print(
                                    '✅ Navigation to pregnancy tracking successful (Method 1)');
                              } catch (e) {
                                print('❌ Method 1 failed: $e');
                                try {
                                  // Method 2: MaterialPageRoute
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const PregnancyTrackingScreen(),
                                    ),
                                  );
                                  print(
                                      '✅ Navigation to pregnancy tracking successful (Method 2)');
                                } catch (e2) {
                                  print('❌ Method 2 failed: $e2');
                                }
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.track_changes,
                                      size: 16, color: Colors.white),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Track Pregnancy',
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: InkWell(
                            onTap: () {
                              print('🔍 Pregnancy Blog button clicked!');
                              print('🔍 Current context: $context');
                              print(
                                  '🔍 Navigator can pop: ${Navigator.canPop(context)}');

                              // Try multiple navigation approaches
                              try {
                                // Method 1: Direct push
                                Navigator.of(context)
                                    .pushNamed('/pregnancy-blog');
                                print(
                                    '✅ Navigation to pregnancy blog successful (Method 1)');
                              } catch (e) {
                                print('❌ Method 1 failed: $e');
                                try {
                                  // Method 2: MaterialPageRoute
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const PregnancyBlogScreen(),
                                    ),
                                  );
                                  print(
                                      '✅ Navigation to pregnancy blog successful (Method 2)');
                                } catch (e2) {
                                  print('❌ Method 2 failed: $e2');
                                }
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.article,
                                      size: 16, color: Colors.white),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Pregnancy Blog',
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],

            // Quick Actions Grid
            _buildQuickActionsGrid(),
            const SizedBox(height: 24),
            // Pregnancy History Section (for females with previous pregnancy data)
            if (_currentUser?.gender == 'Female' &&
                _currentUser?.isPregnant == false &&
                _currentUser?.numberOfPreviousPregnancies != null &&
                _currentUser!.numberOfPreviousPregnancies! > 0) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFFE8F5E8),
                      Color(0xFFF0F8F0)
                    ], // Light green gradient
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.history, color: Colors.green[700], size: 24),
                        const SizedBox(width: 8),
                        Text(
                          'Pregnancy History',
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.green[700],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'You have ${_currentUser!.numberOfPreviousPregnancies} previous pregnancy(ies).',
                      style: GoogleFonts.poppins(
                        color: Colors.green[700],
                        fontSize: 14,
                      ),
                    ),
                    if (_currentUser?.lastPregnancyYear != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Last pregnancy: ${_currentUser!.lastPregnancyYear}',
                        style: GoogleFonts.poppins(
                          color: Colors.green[600],
                          fontSize: 14,
                        ),
                      ),
                    ],
                    if (_currentUser?.pregnancyHealthNotes != null &&
                        _currentUser!.pregnancyHealthNotes!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Health Notes: ${_currentUser!.pregnancyHealthNotes}',
                        style: GoogleFonts.poppins(
                          color: Colors.green[600],
                          fontSize: 14,
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pushNamed(context, '/pregnancy-blog');
                      },
                      icon: const Icon(Icons.article, size: 16),
                      label: Text(
                        'Pregnancy Education',
                        style: GoogleFonts.poppins(fontSize: 12),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green[600],
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            // Health Summary
            _buildHealthSummary(),
            const SizedBox(height: 24),
            // Health Insurance Info
            _buildHealthInsuranceInfo(),
            const SizedBox(height: 24),

            // Emergency Connect
            _buildEmergencyConnectSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeSection() {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [
              Color(0xFF32CCBC),
              Color(0xFF90F7EC)
            ], // Patient teal gradient
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.white.withOpacity(0.2),
                  backgroundImage: (_currentUser?.profileImageUrl != null &&
                          (_currentUser?.profileImageUrl ?? '').isNotEmpty)
                      ? NetworkImage(_currentUser!.profileImageUrl!)
                      : null,
                  child: (_currentUser?.profileImageUrl == null ||
                          (_currentUser?.profileImageUrl ?? '').isEmpty)
                      ? const Icon(Icons.person, color: Colors.white, size: 30)
                      : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Welcome back,',
                        style: GoogleFonts.poppins(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 16,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      Text(
                        _currentUser?.fullName ?? 'Patient',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: _loadingCounts
                      ? null
                      : () {
                          _refreshDashboardCounts();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Refreshing dashboard...'),
                              duration: Duration(seconds: 1),
                            ),
                          );
                        },
                  icon: _loadingCounts
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Icon(Icons.refresh, color: Colors.white, size: 24),
                  tooltip:
                      _loadingCounts ? 'Refreshing...' : 'Refresh Dashboard',
                ),
              ],
            ),
            const SizedBox(height: 16),
            _loadingCounts
                ? Container(
                    height: 100,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      ),
                    ),
                  )
                : Row(
                    children: [
                      _buildStatCard('Appointments',
                          _appointmentsCount.toString(), Icons.calendar_today),
                      const SizedBox(width: 12),
                      _buildStatCard('Medications',
                          _medicationsCount.toString(), Icons.medication),
                      const SizedBox(width: 12),
                      _buildStatCard('Reports', _reportsCount.toString(),
                          Icons.description),
                    ],
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon) {
    return Expanded(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        height: 100, // Fixed height for consistency
        padding: const EdgeInsets.all(6), // Further reduced padding
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                color: Colors.white, size: 18), // Further reduced icon size
            const SizedBox(height: 4), // Reduced spacing
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 500),
              child: Text(
                value,
                key: ValueKey(
                    value), // This ensures animation when value changes
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 16, // Reduced from 18
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 2), // Reduced spacing
            Text(
              label,
              style: GoogleFonts.poppins(
                color: Colors.white.withOpacity(0.9),
                fontSize: 10, // Reduced from 12 for "Appointments"
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHealthInsuranceInfo() {
    if (_healthSummary == null || _healthSummary!['healthInsurance'] == null) {
      return const SizedBox.shrink();
    }

    final healthInsurance = _healthSummary!['healthInsurance'];
    final id = healthInsurance['id'];
    final policyNumber = healthInsurance['policyNumber'];
    final expiryDate = healthInsurance['expiryDate'];

    if (id == null && policyNumber == null) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4CAF50), Color(0xFF81C784)], // Green gradient
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4CAF50).withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.health_and_safety,
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
                      'Health Insurance',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'Your insurance information',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.95),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withOpacity(0.3),
              ),
            ),
            child: Column(
              children: [
                if (id != null) ...[
                  _buildInsuranceRow('Insurance ID', id),
                  const SizedBox(height: 8),
                ],
                if (policyNumber != null) ...[
                  _buildInsuranceRow('Policy Number', policyNumber),
                  const SizedBox(height: 8),
                ],
                if (expiryDate != null) ...[
                  _buildInsuranceRow(
                      'Expiry Date', _formatExpiryDate(expiryDate)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInsuranceRow(String label, String value) {
    return Row(
      children: [
        SizedBox(
          width: 100,
          child: Text(
            '$label:',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.black,
            ),
          ),
        ),
      ],
    );
  }

  // Formats expiry date from various inputs (ISO string, epoch, or plain string)
  String _formatExpiryDate(dynamic raw) {
    try {
      if (raw == null) return '-';
      // Numeric epoch (ms or s)
      if (raw is num) {
        final ms = raw > 100000000000 ? raw.toInt() : (raw.toInt() * 1000);
        return DateTime.fromMillisecondsSinceEpoch(ms)
            .toLocal()
            .toString()
            .split(' ')
            .first; // YYYY-MM-DD
      }
      final s = raw.toString().trim();
      if (s.isEmpty || s == '000000' || s == '000000.0' || s == '0') return '-';

      // Try common formats
      DateTime? dt;
      // ISO
      try {
        dt = DateTime.parse(s);
      } catch (_) {}
      // yyyymmdd
      if (dt == null && RegExp(r'^\d{8}\$').hasMatch(s)) {
        final y = int.parse(s.substring(0, 4));
        final m = int.parse(s.substring(4, 6));
        final d = int.parse(s.substring(6, 8));
        dt = DateTime(y, m, d);
      }
      // yymmdd
      if (dt == null && RegExp(r'^\d{6}$').hasMatch(s)) {
        final y = 2000 + int.parse(s.substring(0, 2));
        final m = int.parse(s.substring(2, 4));
        final d = int.parse(s.substring(4, 6));
        dt = DateTime(y, m, d);
      }

      if (dt == null) return s; // fallback: show raw
      // Format DD/MM/YYYY
      final dd = dt.day.toString().padLeft(2, '0');
      final mm = dt.month.toString().padLeft(2, '0');
      final yyyy = dt.year.toString();
      return '$dd/$mm/$yyyy';
    } catch (_) {
      return raw.toString();
    }
  }

  Widget _buildNotificationsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Notifications',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF2E2E2E),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const NotificationsScreen()),
                );
              },
              child: Text(
                'View All',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF32CCBC),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          height: 120,
          child: Card(
            elevation: 2,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF9C27B0),
                    Color(0xFFBA68C8)
                  ], // Purple gradient
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.notifications,
                          color: Colors.white,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Stay Updated',
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Check your latest notifications and updates',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                    const Spacer(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) =>
                                      const NotificationsScreen()),
                            );
                          },
                          style: TextButton.styleFrom(
                            backgroundColor: Colors.white.withOpacity(0.2),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          child: Text(
                            'View Notifications',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
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
      ],
    );
  }

  Widget _buildUpcomingRemindersSection() {
    // Check if user is female - only show menstrual reminders for females
    if (_cachedGender != 'Female') {
      return const SizedBox.shrink(); // Hide section for male users
    }

    if (_upcomingReminders.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Upcoming Reminders',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF2E2E2E),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          height: 150,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _upcomingReminders.length,
            itemBuilder: (context, index) {
              final reminder = _upcomingReminders[index];
              return Container(
                width: 280,
                margin: const EdgeInsets.only(right: 16),
                child: Card(
                  elevation: 3,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.pink[400]!, Colors.pink[600]!],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                _getReminderIcon(reminder['type'] ?? ''),
                                color: Colors.white,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  reminder['title'] ?? 'Reminder',
                                  style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            reminder['description'] ?? '',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.white.withOpacity(0.9),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const Spacer(),
                          Row(
                            children: [
                              Icon(
                                Icons.access_time,
                                color: Colors.white.withOpacity(0.8),
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _formatReminderDateTime(reminder['date'] ?? '',
                                    reminder['time'] ?? ''),
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  color: Colors.white.withOpacity(0.8),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActionsGrid() {
    final List<Widget> actions = [
      _buildActionCard(
        'Book Appointment',
        Icons.calendar_today,
        [Colors.blue[400]!, Colors.blue[600]!],
        () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) => const AppointmentBookingScreen()),
        ),
      ),
      _buildActionCard(
        'View Prescriptions',
        Icons.medication,
        [Colors.green[400]!, Colors.green[600]!],
        () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const PrescriptionScreen()),
        ),
      ),
      _buildActionCard(
        'Lab Reports',
        Icons.science,
        [Colors.purple[400]!, Colors.purple[600]!],
        () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const LabReportsScreen()),
        ),
      ),
      _buildActionCard(
        'Order Medicines',
        Icons.shopping_cart,
        [Colors.orange[400]!, Colors.orange[600]!],
        () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const MedicineOrderScreen()),
        ),
      ),
      // Pregnancy Tracking and Blog removed from Quick Actions - kept in pregnancy tracking bar above
      _buildActionCard(
        'Health History',
        Icons.history,
        [Colors.teal[400]!, Colors.teal[600]!],
        () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const HealthHistoryScreen()),
        ),
      ),

      // BMI Calculator (For all users)
      _buildActionCard(
        'BMI Calculator',
        Icons.monitor_weight,
        [
          const Color(0xFF32CCBC),
          const Color(0xFF90F7EC)
        ], // Patient teal gradient
        () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const BMICalculatorScreen()),
        ),
      ),
    ];
    // Menstrual Cycle (Always for females, regardless of pregnancy status)
    if (_currentUser?.gender == 'Female') {
      actions.add(
        GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MenstrualCycleScreen()),
            );
          },
          child: _buildQuickActionCard('Menstrual Cycle', Icons.calendar_today,
              [Colors.pink[400]!, Colors.pink[600]!]),
        ),
      );
    }
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: actions,
    );
  }

  Widget _buildActionCard(String title, IconData icon,
      List<Color> gradientColors, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: gradientColors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: Colors.white,
                size: 32,
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActionCard(
      String title, IconData icon, List<Color> gradientColors) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradientColors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: Colors.white,
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHealthSummary() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Health Summary',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF32CCBC), // Patient teal color
              ),
            ),
            if (_loadingHealthData)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFF32CCBC),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Card(
          elevation: 2,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF32CCBC),
                  Color(0xFF90F7EC)
                ], // Patient teal gradient
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _loadingHealthData
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      ),
                    )
                  : Column(
                      children: [
                        _buildHealthMetric(
                            'Blood Group',
                            _healthSummary?['bloodGroup'] ?? 'Not specified',
                            Colors.white),
                        const Divider(color: Colors.white30),
                        _buildHealthMetric(
                            'Height',
                            _healthSummary?['height'] != null
                                ? '${_healthSummary!['height']} cm'
                                : 'Not specified',
                            Colors.white),
                        const Divider(color: Colors.white30),
                        _buildHealthMetric(
                            'Weight',
                            _healthSummary?['weight'] != null
                                ? '${_healthSummary!['weight']} kg'
                                : 'Not specified',
                            Colors.white),
                        const Divider(color: Colors.white30),
                        _buildHealthMetric(
                            'BMI', _calculateBMI(), Colors.white),
                        if (_healthSummary?['isPregnant'] == true) ...[
                          const Divider(color: Colors.white30),
                          _buildHealthMetric('Pregnancy Status',
                              _getPregnancyWeekStatus(), Colors.orange),
                        ],
                        if (_healthSummary?['knownAllergies'] != null &&
                            (_healthSummary!['knownAllergies'] as List)
                                .isNotEmpty) ...[
                          const Divider(color: Colors.white30),
                          _buildHealthMetric(
                              'Allergies',
                              '${(_healthSummary!['knownAllergies'] as List).length} reported',
                              Colors.red[100]!),
                        ],
                      ],
                    ),
            ),
          ),
        ),
      ],
    );
  }

  String _getPregnancyWeekStatus() {
    try {
      if (_currentUser?.pregnancyStartDate == null) {
        return 'Currently Pregnant';
      }

      final startDate = _currentUser!.pregnancyStartDate!;
      final now = DateTime.now();
      final daysSinceStart = now.difference(startDate).inDays;
      final weeks = (daysSinceStart / 7).floor();

      if (weeks < 0) {
        return 'Currently Pregnant';
      } else if (weeks >= 40) {
        return 'Week 40+ (Full Term)';
      } else {
        return 'Week $weeks';
      }
    } catch (e) {
      print('❌ Error calculating pregnancy week: $e');
      return 'Currently Pregnant';
    }
  }

  Widget _buildHealthMetric(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // Calculate BMI based on height and weight
  String _calculateBMI() {
    final height = _healthSummary?['height'];
    final weight = _healthSummary?['weight'];

    if (height == null || weight == null) {
      return 'Not calculated';
    }

    try {
      // Convert height from cm to meters
      final heightInMeters = height / 100;
      // Calculate BMI: weight (kg) / height (m)²
      final bmi = weight / (heightInMeters * heightInMeters);

      // Determine BMI category
      String category;
      if (bmi < 18.5) {
        category = 'Underweight';
      } else if (bmi < 25) {
        category = 'Normal';
      } else if (bmi < 30) {
        category = 'Overweight';
      } else {
        category = 'Obese';
      }

      return '${bmi.toStringAsFixed(1)} ($category)';
    } catch (e) {
      return 'Error calculating';
    }
  }

  // Emergency Connect Section
  Widget _buildEmergencyConnectSection() {
    if (_healthSummary == null || _healthSummary!['emergencyContact'] == null) {
      return const SizedBox.shrink();
    }

    final emergencyContact = _healthSummary!['emergencyContact'];
    final name = emergencyContact['name'];
    final number = emergencyContact['number'];
    final relation = emergencyContact['relation'];

    if (name == null || number == null) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Emergency Connect',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF2E2E2E),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFF4444), Color(0xFFFF6666)], // Red gradient
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFF4444).withOpacity(0.3),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.emergency_outlined,
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
                          'Emergency Contact',
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'Quick access to your emergency contact',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.2),
                  ),
                ),
                child: Column(
                  children: [
                    _buildEmergencyContactRow('Name', name),
                    const SizedBox(height: 8),
                    _buildEmergencyContactRow('Phone', number),
                    if (relation != null) ...[
                      const SizedBox(height: 8),
                      _buildEmergencyContactRow('Relation', relation),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmergencyContactRow(String label, String value) {
    return Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(
            '$label:',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.white.withOpacity(0.9),
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  void _handleMenuSelection(String value) {
    switch (value) {
      case 'profile':
        if (_currentUser != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => UserProfileScreen(user: _currentUser!),
            ),
          );
        }
        break;
      case 'logout':
        _showLogoutDialog();
        break;
    }
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                Color(0xFF32CCBC),
                Color(0xFF90F7EC)
              ], // Patient teal gradient
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF32CCBC).withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Logout icon with gradient background
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.logout,
                    size: 48,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Logout',
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Are you sure you want to logout?',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
                const SizedBox(height: 24),

                // Action buttons
                Row(
                  children: [
                    // Cancel button
                    Expanded(
                      child: Container(
                        height: 45,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            'Cancel',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Logout button
                    Expanded(
                      child: Container(
                        height: 45,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: () async {
                            Navigator.pop(context);
                            await AuthService().signOut();
                            if (mounted) {
                              Navigator.pushAndRemoveUntil(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => const LoginScreen()),
                                (route) => false,
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            foregroundColor: const Color(0xFF32CCBC),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            'Logout',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF32CCBC),
                            ),
                          ),
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
    );
  }

  // Build notification settings section

  IconData _getReminderIcon(String type) {
    switch (type.toLowerCase()) {
      case 'next period':
        return Icons.bloodtype;
      case 'ovulation':
        return Icons.notifications;
      case 'fertile window':
        return Icons.favorite;
      default:
        return Icons.notifications;
    }
  }

  String _formatReminderDateTime(String date, String time) {
    try {
      if (date.isNotEmpty) {
        final dateTime = DateTime.parse(date);
        final formattedDate =
            '${dateTime.day}/${dateTime.month}/${dateTime.year}';
        if (time.isNotEmpty) {
          return '$formattedDate at $time';
        }
        return formattedDate;
      }
      return 'Date not set';
    } catch (e) {
      return 'Invalid date';
    }
  }
}
