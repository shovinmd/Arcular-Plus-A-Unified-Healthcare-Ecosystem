import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:arcular_plus/models/user_model.dart';
import 'package:arcular_plus/services/auth_service.dart';
import 'package:arcular_plus/screens/auth/login_screen.dart';
import 'package:arcular_plus/widgets/chatarc_floating_button.dart';
import 'package:arcular_plus/widgets/shaking_bell_notification.dart';
import 'package:arcular_plus/services/api_service.dart';
import 'package:arcular_plus/screens/lab/lab_profile_screen.dart';
import 'package:arcular_plus/screens/lab/lab_upload_report_screen.dart';
import 'package:arcular_plus/screens/lab/lab_tracking_screen.dart';
import 'package:arcular_plus/screens/lab/lab_test_request_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:convert';

// CSV download functionality - using share_plus for all platforms
import 'lab_notifications_screen.dart';

class LabDashboardScreen extends StatefulWidget {
  const LabDashboardScreen({super.key});

  @override
  State<LabDashboardScreen> createState() => _LabDashboardScreenState();
}

class _LabDashboardScreenState extends State<LabDashboardScreen> {
  int _currentIndex = 0;
  UserModel? _labUser;
  bool _isLoading = true;

  // Real-time analytics data
  Map<String, dynamic> _realAnalytics = {
    'totalTests': 0,
    'pendingTests': 0,
    'completedTests': 0,
    'revenue': 0,
  };
  bool _analyticsLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeDashboard();
  }

  Future<void> _initializeDashboard() async {
    // Set loading to false immediately to show the UI
    setState(() => _isLoading = false);

    // Load data in background
    await _loadLabUser();
    await _loadRealTimeAnalytics();
  }

  Future<void> _loadLabUser() async {
    try {
      final authService = AuthService();
      final user = authService.currentUser;
      if (user != null) {
        print('🔬 Loading lab data for UID: ${user.uid}');

        // Use universal getUserInfo method which respects user type
        final labUser = await ApiService.getUserInfo(user.uid);

        if (labUser != null) {
          print('✅ Lab data loaded successfully: ${labUser.fullName}');
          setState(() {
            _labUser = labUser;
            _isLoading = false;
          });
        } else {
          print('❌ Lab data not found, using fallback data');
          // Fallback to mock data if API fails
          _labUser = UserModel(
            uid: user.uid,
            fullName: 'Lab Technician',
            email: user.email ?? '',
            mobileNumber: '+91 9876543210',
            gender: 'Male',
            dateOfBirth: DateTime.now().subtract(const Duration(days: 10950)),
            address: '123 Lab Street',
            pincode: '123456',
            city: 'Mumbai',
            state: 'Maharashtra',
            type: 'lab',
            createdAt: DateTime.now(),
            healthQrId: 'LAB123456789',
            labName: 'Advanced Diagnostics Lab',
            labLicenseNumber: 'LAB123456',
            labAddress: '123 Lab Street, Mumbai',
            availableTests: ['Blood Test', 'X-Ray', 'ECG', 'MRI', 'CT Scan'],
            homeSampleCollection: true,
          );
          setState(() => _isLoading = false);
        }
      }
    } catch (e) {
      print('❌ Error loading lab user: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadRealTimeAnalytics() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final labMongoId = await ApiService.getLabMongoId(user.uid);
      if (labMongoId == null) return;

      final requests = await ApiService.getLabTestRequests(labMongoId);

      // Calculate real-time analytics
      final totalTests = requests.length;
      final pendingTests =
          requests.where((r) => r['status'] == 'Pending').length;
      final completedTests =
          requests.where((r) => r['status'] == 'Completed').length;

      // Calculate total revenue from completed tests
      double totalRevenue = 0;
      for (final request in requests) {
        if (request['status'] == 'Completed' && request['billAmount'] != null) {
          totalRevenue += (request['billAmount'] as num).toDouble();
        }
      }

      setState(() {
        _realAnalytics = {
          'totalTests': totalTests,
          'pendingTests': pendingTests,
          'completedTests': completedTests,
          'revenue': totalRevenue.round(),
        };
        _analyticsLoading = false;
      });
    } catch (e) {
      setState(() => _analyticsLoading = false);
      print('❌ Error loading real-time analytics: $e');
    }
  }

  Future<void> _refreshDashboard() async {
    await _loadLabUser();
    await _loadRealTimeAnalytics();
    setState(() {});
  }

  Widget _buildOverviewTab() {
    return RefreshIndicator(
        onRefresh: _refreshDashboard,
        color: const Color(0xFFFB923C),
        backgroundColor: Colors.white,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome card (hospital-style)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFFFB923C),
                      Color(0xFFFDBA74)
                    ], // Lab orange theme
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFB923C)
                          .withOpacity(0.25), // Lab orange theme
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        FutureBuilder<SharedPreferences>(
                          future: SharedPreferences.getInstance(),
                          builder: (context, snap) {
                            final prefs = snap.data;
                            final cached =
                                prefs?.getString('lab_profile_image_url');
                            final url = (cached != null && cached.isNotEmpty)
                                ? cached
                                : _labUser?.profileImageUrl;
                            return CircleAvatar(
                              radius: 30,
                              backgroundColor: Colors.white.withOpacity(0.2),
                              backgroundImage: (url != null && url.isNotEmpty)
                                  ? NetworkImage(url)
                                  : null,
                              child: (url == null || url.isEmpty)
                                  ? const Icon(Icons.science,
                                      color: Colors.white, size: 30)
                                  : null,
                            );
                          },
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Welcome back,',
                                  style: GoogleFonts.poppins(
                                      color: Colors.white.withOpacity(0.9),
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500)),
                              const SizedBox(height: 4),
                              Text(_labUser?.labName ?? 'Lab',
                                  style: GoogleFonts.poppins(
                                      color: Colors.white,
                                      fontSize: 22,
                                      fontWeight: FontWeight.w700)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _miniStat(
                              'Total Requests',
                              _realAnalytics['totalTests'].toString(),
                              Icons.analytics),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _miniStat(
                              'Pending',
                              _realAnalytics['pendingTests'].toString(),
                              Icons.pending),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text('Manage your lab operations efficiently',
                        style: GoogleFonts.poppins(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 13)),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Approval Badge
              _buildApprovalBadge(),
              const SizedBox(height: 24),

              // Quick Actions (lab-themed gradient tiles)
              _buildQuickActions(),
              const SizedBox(height: 16),

              // Recent Activity
              const Text(
                'Recent Activity',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              _buildRecentActivityList(),
            ],
          ),
        ));
  }

  Widget _buildAnalyticsTab() {
    return RefreshIndicator(
      onRefresh: _loadRealTimeAnalytics,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Analytics',
                style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF2E2E2E))),
            const SizedBox(height: 12),
            _analyticsLoading
                ? const Center(child: CircularProgressIndicator())
                : GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.2,
                    children: [
                      _buildStatCard('Total Tests',
                          _realAnalytics['totalTests'].toString(), Colors.blue),
                      _buildStatCard(
                          'Pending Tests',
                          _realAnalytics['pendingTests'].toString(),
                          Colors.orange),
                      _buildStatCard(
                          'Completed Tests',
                          _realAnalytics['completedTests'].toString(),
                          const Color(0xFF34D399)),
                      _buildIconStatCard(
                          'Revenue (₹)',
                          '₹${_realAnalytics['revenue']}',
                          Icons.attach_money,
                          const Color(0xFF10B981)),
                    ],
                  ),
            const SizedBox(height: 20),
            // Export and Generate Cards
            Row(
              children: [
                Expanded(
                  child: _buildActionCard(
                    'Export Data',
                    'Download test data as CSV',
                    Icons.download,
                    Colors.green,
                    () => _exportData(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildActionCard(
                    'Generate Report',
                    'Create detailed lab report',
                    Icons.description,
                    Colors.blue,
                    () => _generateReport(),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard(String title, String subtitle, IconData icon,
      Color color, VoidCallback onTap) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withOpacity(0.1),
            color.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.15),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: color, size: 28),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child:
                        Icon(Icons.arrow_forward_ios, color: color, size: 16),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[800],
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _exportData() async {
    try {
      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      // Get test requests data
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        Navigator.of(context).pop();
        _showErrorSnackBar('User not authenticated');
        return;
      }

      final labMongoId = await ApiService.getLabMongoId(user.uid);
      if (labMongoId == null) {
        Navigator.of(context).pop();
        _showErrorSnackBar('Lab not found');
        return;
      }

      final requests = await ApiService.getLabTestRequests(labMongoId);

      // Create CSV content
      final csvContent = _createCsvContent(requests);

      // Close loading dialog
      Navigator.of(context).pop();

      // Share the CSV content
      await _shareCsvContent(csvContent, 'lab_test_data.csv');

      _showSuccessSnackBar('Data exported successfully!');
    } catch (e) {
      // Close loading dialog if open
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      _showErrorSnackBar('Failed to export data: $e');
    }
  }

  Future<void> _generateReport() async {
    try {
      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      // Get test requests data
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        Navigator.of(context).pop();
        _showErrorSnackBar('User not authenticated');
        return;
      }

      final labMongoId = await ApiService.getLabMongoId(user.uid);
      if (labMongoId == null) {
        Navigator.of(context).pop();
        _showErrorSnackBar('Lab not found');
        return;
      }

      final requests = await ApiService.getLabTestRequests(labMongoId);

      // Create detailed report content
      final reportContent = _createDetailedReportContent(requests);

      // Close loading dialog
      Navigator.of(context).pop();

      // Share the report content
      await _shareCsvContent(reportContent, 'lab_detailed_report.csv');

      _showSuccessSnackBar('Report generated successfully!');
    } catch (e) {
      // Close loading dialog if open
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      _showErrorSnackBar('Failed to generate report: $e');
    }
  }

  String _createCsvContent(List<Map<String, dynamic>> requests) {
    final buffer = StringBuffer();

    // CSV Headers
    buffer.writeln(
        'Request ID,Patient Name,Patient ARC ID,Test Name,Test Type,Hospital Name,Status,Urgency,Bill Amount,Payment Options,Requested Date,Completed Date');

    // CSV Data
    for (final request in requests) {
      buffer.writeln([
        request['requestId'] ?? '',
        request['patientName'] ?? '',
        request['patientArcId'] ?? '',
        request['testName'] ?? '',
        request['testType'] ?? '',
        request['hospitalName'] ?? '',
        request['status'] ?? '',
        request['urgency'] ?? '',
        request['billAmount']?.toString() ?? '0',
        (request['paymentOptions'] as List?)?.join('; ') ?? '',
        request['requestedDate'] ?? '',
        request['completedAt'] ?? '',
      ]
          .map((field) => '"${field.toString().replaceAll('"', '""')}"')
          .join(','));
    }

    return buffer.toString();
  }

  String _createDetailedReportContent(List<Map<String, dynamic>> requests) {
    final buffer = StringBuffer();

    // Report Header
    buffer.writeln('LAB DETAILED REPORT');
    buffer.writeln('Generated on: ${DateTime.now().toLocal()}');
    buffer.writeln('Lab: ${_labUser?.labName ?? 'Unknown Lab'}');
    buffer.writeln('');

    // Summary
    final totalRequests = requests.length;
    final pendingRequests =
        requests.where((r) => r['status'] == 'Pending').length;
    final completedRequests =
        requests.where((r) => r['status'] == 'Completed').length;
    final admittedRequests =
        requests.where((r) => r['status'] == 'Admitted').length;

    buffer.writeln('SUMMARY');
    buffer.writeln('Total Requests: $totalRequests');
    buffer.writeln('Pending: $pendingRequests');
    buffer.writeln('Admitted: $admittedRequests');
    buffer.writeln('Completed: $completedRequests');
    buffer.writeln('');

    // Detailed Data
    buffer.writeln('DETAILED DATA');
    buffer.writeln(
        'Request ID,Patient Name,Patient ARC ID,Test Name,Test Type,Hospital Name,Status,Urgency,Bill Amount,Payment Options,Requested Date,Completed Date,Lab Notes');

    for (final request in requests) {
      buffer.writeln([
        request['requestId'] ?? '',
        request['patientName'] ?? '',
        request['patientArcId'] ?? '',
        request['testName'] ?? '',
        request['testType'] ?? '',
        request['hospitalName'] ?? '',
        request['status'] ?? '',
        request['urgency'] ?? '',
        request['billAmount']?.toString() ?? '0',
        (request['paymentOptions'] as List?)?.join('; ') ?? '',
        request['requestedDate'] ?? '',
        request['completedAt'] ?? '',
        request['labNotes'] ?? '',
      ]
          .map((field) => '"${field.toString().replaceAll('"', '""')}"')
          .join(','));
    }

    return buffer.toString();
  }

  Future<void> _shareCsvContent(String content, String fileName) async {
    // Use share_plus for all platforms
    await Share.share(content, subject: fileName);
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Text(message),
          ],
        ),
        backgroundColor: Colors.green[600],
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error, color: Colors.white),
            const SizedBox(width: 8),
            Text(message),
          ],
        ),
        backgroundColor: Colors.red[600],
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _buildRecentActivityList() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _loadRecentTestRequests(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Icon(Icons.science_outlined,
                      size: 48, color: Colors.grey[400]),
                  const SizedBox(height: 8),
                  Text(
                    'No recent test requests',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Test requests from hospitals will appear here',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.grey[500],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        final requests = snapshot.data!.take(3).toList();
        return Column(
          children: requests.map((request) {
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: _getStatusColor(request['status']),
                  child: Icon(Icons.science, color: Colors.white),
                ),
                title: Text(request['patientName'] ?? 'Unknown Patient'),
                subtitle: Text(
                    '${request['testName'] ?? 'Test'} - ${request['status'] ?? 'Unknown'}'),
                trailing: Chip(
                  label: Text(request['urgency'] ?? 'Normal'),
                  backgroundColor:
                      _getPriorityColor(request['urgency'] ?? 'Normal'),
                  labelStyle: const TextStyle(color: Colors.white),
                ),
                onTap: () {
                  // Navigate to test request details or test request screen
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const LabTestRequestScreen(),
                    ),
                  );
                },
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Future<List<Map<String, dynamic>>> _loadRecentTestRequests() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return [];

      final labMongoId = await ApiService.getLabMongoId(user.uid);
      if (labMongoId == null) return [];

      final requests = await ApiService.getLabTestRequests(labMongoId);
      // Sort by creation date (most recent first) and take latest 5
      requests.sort((a, b) => DateTime.parse(b['createdAt'] ?? '')
          .compareTo(DateTime.parse(a['createdAt'] ?? '')));
      return requests.take(5).toList();
    } catch (e) {
      print('❌ Error loading recent test requests: $e');
      return [];
    }
  }

  Widget _buildQuickActions() {
    final actions = [
      {
        'title': 'Upload Report',
        'icon': Icons.upload_file,
        'gradient': [const Color(0xFF4CAF50), const Color(0xFF45A049)],
        'route': () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => const LabUploadReportScreen()),
            ),
      },
      {
        'title': 'Track Reports',
        'icon': Icons.track_changes,
        'gradient': [const Color(0xFF2196F3), const Color(0xFF1976D2)],
        'route': () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => const LabTrackingScreen()),
            ),
      },
      {
        'title': 'Test Requests',
        'icon': Icons.science,
        'gradient': [const Color(0xFFFF9800), const Color(0xFFF57C00)],
        'route': () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => const LabTestRequestScreen()),
            ),
      },
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.1,
      ),
      itemCount: actions.length,
      itemBuilder: (context, index) {
        final action = actions[index];
        return _buildActionTile(action);
      },
    );
  }

  Widget _buildActionTile(Map<String, dynamic> action) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: action['gradient'] as List<Color>,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: (action['gradient'] as List<Color>)[0].withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: action['route'] as VoidCallback,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  action['icon'] as IconData,
                  color: Colors.white,
                  size: 32,
                ),
                const SizedBox(height: 8),
                Text(
                  action['title'] as String,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, Color color) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withOpacity(0.1),
            color.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.15),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.analytics, color: color, size: 28),
            ),
            const SizedBox(height: 16),
            Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIconStatCard(
      String title, String value, IconData icon, Color color) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withOpacity(0.1),
            color.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.15),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 16),
            Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniStat(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    value,
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'admitted':
        return Colors.green;
      case 'completed':
        return Colors.blue;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Color _getPriorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'emergency':
        return Colors.red;
      case 'high':
        return Colors.orange;
      case 'normal':
        return Colors.blue;
      case 'low':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Lab Dashboard',
            style: GoogleFonts.poppins(
                color: Colors.white, fontWeight: FontWeight.w600)),
        backgroundColor: const Color(0xFFFB923C), // Orange theme
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          ShakingBellNotification(
            userType: 'lab',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const LabNotificationsScreen(),
              ),
            ),
            iconColor: Colors.white,
            iconSize: 24,
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'profile':
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => LabProfileScreen(lab: _labUser!),
                    ),
                  );
                  break;
                case 'logout':
                  _showLogoutDialog();
                  break;
              }
            },
            icon: const Icon(Icons.more_vert, color: Colors.white),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'profile',
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFFFF9800), Color(0xFFE65100)],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.all(Radius.circular(8)),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: const Row(
                    children: [
                      Icon(Icons.person, color: Colors.white),
                      SizedBox(width: 8),
                      Text(
                        'Profile',
                        style: TextStyle(
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
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFFE57373), Color(0xFFEF5350)],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.all(Radius.circular(8)),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: const Row(
                    children: [
                      Icon(Icons.logout, color: Colors.white),
                      SizedBox(width: 8),
                      Text(
                        'Logout',
                        style: TextStyle(
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
          IndexedStack(
            index: _currentIndex,
            children: [
              _buildOverviewTab(),
              _buildAnalyticsTab(),
            ],
          ),
          const ChatArcFloatingButton(userType: 'lab'),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFFFB923C), // Orange theme
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.dashboard), label: 'Overview'),
          BottomNavigationBarItem(
              icon: Icon(Icons.analytics), label: 'Analytics'),
        ],
      ),
    );
  }

  // Show Logout Dialog (similar to hospital but with orange theme)
  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.transparent,
        contentPadding: EdgeInsets.zero,
        content: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFB923C), Color(0xFFFDBA74)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFB923C).withOpacity(0.25),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.logout,
                color: Colors.white,
                size: 48,
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
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
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
                      ),
                      child: TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                          AuthService().signOut().then((_) {
                            Navigator.pushAndRemoveUntil(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const LoginScreen()),
                              (route) => false,
                            );
                          });
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFFFB923C),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Logout',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFFFB923C),
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
    );
  }

  // Build Approval Badge (similar to pharmacy)
  Widget _buildApprovalBadge() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFB923C), Color(0xFFFDBA74)], // Lab orange theme
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.check_circle,
              color: Colors.white,
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Lab Approved',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Your lab is fully functional and operational',
                    style: GoogleFonts.poppins(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
