import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:arcular_plus/widgets/chatarc_floating_button.dart';
import 'nurse_assigned_patients_screen.dart';
import 'nurse_reminders_screen.dart';
import 'nurse_prescription_tab.dart';
import 'package:arcular_plus/screens/doctor/doctor_chat_screen.dart';
import 'package:arcular_plus/screens/nurse/nurse_talk_screen.dart';
import 'vital_monitoring_screen.dart';
import 'package:arcular_plus/services/auth_service.dart';
import 'package:arcular_plus/services/api_service.dart';
import 'package:arcular_plus/models/user_model.dart';
import 'package:arcular_plus/screens/auth/login_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:arcular_plus/screens/nurse/nurse_profile_screen.dart';
import 'package:arcular_plus/screens/nurse/nurse_notifications_screen.dart';

// Updated color constants for nurse dashboard - new nurse gradient/theme
const Color kNursePrimary = Color(0xFFC084FC); // Lavender
const Color kNurseSecondary = Color(0xFFA78BFA); // Soft purple
const Color kNurseAccent = Color(0xFFD6BCFA);
const Color kNurseBackground = Color(0xFFF6F0FF);
const Color kNurseSurface = Color(0xFFFFFFFF);
const Color kNurseText = Color(0xFF2E2E2E);
const Color kNurseTextSecondary = Color(0xFFA78BFA);
const Color kNurseSuccess = Color(0xFF4CAF50);
const Color kNurseWarning = Color(0xFFFF9800);
const Color kNurseError = Color(0xFFF44336);

class NurseDashboardScreen extends StatefulWidget {
  const NurseDashboardScreen({Key? key}) : super(key: key);

  @override
  State<NurseDashboardScreen> createState() => _NurseDashboardScreenState();
}

class _NurseDashboardScreenState extends State<NurseDashboardScreen> {
  UserModel? _nurse;
  bool _isLoading = true;
  bool _isApproved = false;
  Map<String, dynamic> _stats = {};
  String? _profileImageUrl;

  @override
  void initState() {
    super.initState();
    _loadCachedApprovalStatus();
    _loadCachedProfileImage();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadNurseData();
      _loadDashboardStats();
    });
  }

  Future<void> _loadCachedProfileImage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final url = prefs.getString('nurse_profile_image_url');
      if (url != null && mounted) {
        setState(() {
          _profileImageUrl = url;
        });
      }
    } catch (_) {}
  }

  // Load cached approval status instantly
  Future<void> _loadCachedApprovalStatus() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isApproved = prefs.getBool('nurse_is_approved') ?? false;
    });
  }

  Future<void> _loadNurseData() async {
    try {
      final authService = AuthService();
      final user = authService.currentUser;
      if (user != null) {
        print('👩‍⚕️ Loading nurse data for UID: ${user.uid}');

        // Use universal getUserInfo method which respects user type
        final nurseUser = await ApiService.getUserInfo(user.uid);

        if (nurseUser != null) {
          print('✅ Nurse data loaded successfully: ${nurseUser.fullName}');
          setState(() {
            _nurse = nurseUser;
            _isApproved = nurseUser.isApproved ?? false;
            _isLoading = false;
          });
        } else {
          print('❌ Nurse data not found');
          setState(() => _isLoading = false);
        }
      }
    } catch (e) {
      print('❌ Error loading nurse data: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadDashboardStats() async {
    try {
      final currentUser = AuthService().currentUser;
      if (currentUser == null) return;

      // Fetch nurse assignments to get real patient count
      final assignments = await ApiService.getNurseAssignments();

      // Count unique patients
      final uniquePatients =
          assignments.map((a) => a['patientId']).toSet().length;

      // Compute shift stats: active vs completed based on current time and shift window
      int activeShifts = 0;
      int completedShifts = 0;
      final now = DateTime.now();
      for (final a in assignments) {
        final shiftLabel = (a['shift'] ?? '').toString().toLowerCase();
        // Parse assignment date
        DateTime date = DateTime(now.year, now.month, now.day);
        final ad = a['assignmentDate']?.toString();
        final parsed = ad != null ? DateTime.tryParse(ad) : null;
        if (parsed != null) {
          date = DateTime(parsed.year, parsed.month, parsed.day);
        }
        // Map shift to start/end times
        String start = '06:00';
        String end = '14:00';
        if (shiftLabel.contains('night')) {
          start = '22:00';
          end = '06:00';
        } else if (shiftLabel.contains('evening')) {
          start = '14:00';
          end = '22:00';
        } else if (shiftLabel.contains('morning')) {
          start = '06:00';
          end = '14:00';
        } else if (shiftLabel.contains('day')) {
          start = '07:00';
          end = '19:00';
        }
        DateTime startDt = DateTime(date.year, date.month, date.day,
            int.parse(start.split(':')[0]), int.parse(start.split(':')[1]));
        DateTime endDt = DateTime(date.year, date.month, date.day,
            int.parse(end.split(':')[0]), int.parse(end.split(':')[1]));
        // Handle overnight
        if (endDt.isBefore(startDt)) {
          endDt = endDt.add(const Duration(days: 1));
        }
        if (now.isAfter(endDt))
          completedShifts++;
        else
          activeShifts++;
      }

      // Count active tasks from reminders for all assigned patients
      int activeTasks = 0;
      try {
        for (final assignment in assignments) {
          final patientArcId = assignment['patientArcId']?.toString();
          if (patientArcId != null && patientArcId.isNotEmpty) {
            final reminders =
                await ApiService.getRemindersByArcId(patientArcId);
            for (final reminder in reminders) {
              final status =
                  (reminder['status'] ?? '').toString().toLowerCase();
              // Only count active tasks (not completed)
              if (status != 'completed') {
                activeTasks++;
              }
            }
          }
        }
      } catch (e) {
        print('❌ Error counting tasks: $e');
        activeTasks = 0;
      }

      if (mounted) {
        setState(() {
          _stats = {
            'totalPatients': uniquePatients,
            'activeShifts': activeShifts,
            'activeTasks': activeTasks,
            'completedShifts': completedShifts,
          };
        });
      }
    } catch (e) {
      print('❌ Error loading dashboard stats: $e');
      // Set default values on error
      if (mounted) {
        setState(() {
          _stats = {
            'totalPatients': 0,
            'activeShifts': 0,
            'activeTasks': 0,
            'completedShifts': 0,
          };
        });
      }
    }
  }

  void _handleMenuSelection(String value) async {
    switch (value) {
      case 'profile':
        // Navigate instantly with minimal data, let profile screen refresh
        if (_nurse != null && mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => NurseProfileScreen(nurse: _nurse!),
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
            gradient: LinearGradient(
              colors: [kNurseSecondary, kNursePrimary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: kNursePrimary.withOpacity(0.3),
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
                            foregroundColor: kNursePrimary,
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
                              color: kNursePrimary,
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: FutureBuilder<SharedPreferences>(
          future: SharedPreferences.getInstance(),
          builder: (context, snapshot) {
            String imagePath =
                'assets/images/Female/nurs/think.png'; // Default to nurse thinking
            // Use lavender gradient on initial nurse welcome/loading screen
            List<Color> gradientColors = [
              const Color(0xFFC084FC),
              const Color(0xFFA78BFA)
            ];

            if (snapshot.hasData) {
              final gender =
                  snapshot.data!.getString('user_gender') ?? 'Female';

              // Gender-specific nurse image
              if (gender == 'Male') {
                imagePath = 'assets/images/Male/nurs/think.png';
              } else {
                imagePath = 'assets/images/Female/nurs/think.png';
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

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA), // light gray background
      appBar: AppBar(
        title: Text(
          'Nurse Dashboard',
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
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [kNurseSecondary, kNursePrimary],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const NurseNotificationsScreen(),
                ),
              );
            },
          ),
          PopupMenuButton<String>(
            onSelected: _handleMenuSelection,
            icon: const Icon(Icons.more_vert, color: Colors.white),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'profile',
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        kNursePrimary,
                        kNurseSecondary
                      ], // Nurse purple gradient
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
          _buildHomeScreen(),
          const ChatArcFloatingButton(userType: 'nurse'),
        ],
      ),
    );
  }

  Widget _buildHomeScreen() {
    return RefreshIndicator(
      onRefresh: _refreshDashboard,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildWelcomeStatsCard(),
            const SizedBox(height: 16),
            _buildApprovalStatusCard(),
            const SizedBox(height: 16),
            _buildQuickActionsGrid(),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeStatsCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [kNursePrimary, kNurseSecondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: kNursePrimary.withOpacity(0.3),
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
              CircleAvatar(
                radius: 30,
                backgroundColor: Colors.white.withOpacity(0.2),
                child: (_profileImageUrl ?? _nurse?.profileImageUrl) != null
                    ? ClipOval(
                        child: Image.network(
                          _profileImageUrl ?? _nurse!.profileImageUrl!,
                          width: 60,
                          height: 60,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return const Icon(
                              Icons.person,
                              size: 30,
                              color: Colors.white,
                            );
                          },
                        ),
                      )
                    : const Icon(
                        Icons.person,
                        size: 30,
                        color: Colors.white,
                      ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome back,',
                      style: GoogleFonts.poppins(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      _nurse?.fullName ?? 'Nurse',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                  child: _buildStatChip(
                      'Patients', Icons.people, _stats['totalPatients'] ?? 0)),
              const SizedBox(width: 12),
              Expanded(
                  child: _buildStatChip(
                      'Shifts', Icons.schedule, _stats['activeShifts'] ?? 0)),
              const SizedBox(width: 12),
              Expanded(
                  child: _buildStatChip(
                      'Tasks', Icons.task_alt, _stats['activeTasks'] ?? 0)),
            ],
          ),
          // Shift schedule quick action removed per request
        ],
      ),
    );
  }

  Widget _buildStatChip(String label, IconData icon, int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(height: 4),
          Text(
            count.toString(),
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.poppins(
              color: Colors.white.withOpacity(0.9),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildApprovalStatusCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _isApproved
              ? [kNursePrimary, kNurseSecondary]
              : [Colors.orange, Colors.orange[400]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color:
                (_isApproved ? kNursePrimary : Colors.orange).withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              _isApproved ? Icons.check_circle : Icons.pending,
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
                  _isApproved ? 'Fully Approved' : 'Pending Approval',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  _isApproved
                      ? 'You\'re fully approved. All features are enabled.'
                      : 'Your account is under review',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionsGrid() {
    final actions = [
      {
        'title': 'Assigned Patients',
        'icon': Icons.people_alt,
        'gradient': [const Color(0xFF2196F3), const Color(0xFF64B5F6)],
      },
      {
        'title': 'Vitals',
        'icon': Icons.monitor_heart,
        'gradient': [const Color(0xFFFF7043), const Color(0xFFFFA07A)],
      },
      {
        'title': 'Reminders',
        'icon': Icons.notifications,
        'gradient': [const Color(0xFFFFB300), const Color(0xFFFFD54F)],
      },
      {
        'title': 'Prescriptions & Reports',
        'icon': Icons.medication,
        'gradient': [const Color(0xFF43A047), const Color(0xFF81C784)],
      },
      {
        'title': 'Doctor Chat',
        'icon': Icons.chat,
        'gradient': [const Color(0xFF8E24AA), const Color(0xFFBA68C8)],
      },
      {
        'title': 'NurseTalk',
        'icon': Icons.group,
        'gradient': [
          const Color.fromARGB(255, 28, 169, 176),
          const Color(0xFF64B5F6)
        ],
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 4),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.15,
          ),
          itemCount: actions.length,
          itemBuilder: (context, index) {
            final action = actions[index];
            return GestureDetector(
              onTap: () {
                // Navigate to respective screen
                if (index == 0) {
                  // Navigate to assigned patients screen
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const NurseAssignedPatientsScreen(),
                    ),
                  );
                } else if (index == 1) {
                  // Navigate to vitals monitoring screen
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const VitalMonitoringScreen(),
                    ),
                  );
                } else if (index == 2) {
                  // Navigate to reminders screen (by ARC ID)
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const NurseRemindersScreen(),
                    ),
                  );
                } else if (index == 3) {
                  // Navigate to prescriptions tab
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const NursePrescriptionTab(),
                    ),
                  );
                } else if (index == 4) {
                  // Navigate to chat tab
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          DoctorChatScreen(senderRole: 'nurse'),
                    ),
                  );
                } else if (index == 5) {
                  // Navigate to NurseTalk screen
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const NurseTalkScreen(),
                    ),
                  );
                }
              },
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: (action['gradient'] as List<Color>),
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.12),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      action['icon'] as IconData,
                      color: Colors.white,
                      size: 32,
                    ),
                    const SizedBox(height: 10),
                    Flexible(
                      child: Text(
                        action['title'] as String,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          letterSpacing: 0.2,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        softWrap: true,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Future<void> _refreshDashboard() async {
    await _loadNurseData();
    await _loadDashboardStats();
  }
}

class NurseMedicationLogTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [kNurseSecondary, kNursePrimary],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.medication,
                size: 60,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Medication Admin Log',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Track medication administration',
              style: GoogleFonts.poppins(
                color: Colors.white.withOpacity(0.8),
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
