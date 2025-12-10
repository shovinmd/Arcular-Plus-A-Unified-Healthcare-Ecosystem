import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:arcular_plus/services/api_service.dart';
import 'package:arcular_plus/models/user_model.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

// Color constants for hospital theme
const Color kHospitalBackground = Color(0xFFF9FAFB);
const Color kHospitalPrimary = Color(0xFF4CAF50);
const Color kHospitalSecondary = Color(0xFF81C784);
const Color kHospitalAccent = Color(0xFFE8F5E8);
const Color kHospitalPrimaryText = Color(0xFF2E2E2E);
const Color kHospitalSecondaryText = Color(0xFF6B7280);
const Color kHospitalBorder = Color(0xFFE5E7EB);
const Color kHospitalSuccess = Color(0xFF34D399);
const Color kHospitalWarning = Color(0xFFFFD54F);
const Color kHospitalError = Color(0xFFEF4444);

class HospitalPatientRecordsScreen extends StatefulWidget {
  const HospitalPatientRecordsScreen({super.key});

  @override
  State<HospitalPatientRecordsScreen> createState() =>
      _HospitalPatientRecordsScreenState();
}

class _HospitalPatientRecordsScreenState
    extends State<HospitalPatientRecordsScreen> {
  int _selectedIndex = 0;
  UserModel? _hospital;
  bool _isLoading = true;
  bool _isRefreshing = false;
  bool _isPrescriptionsLoading = false;
  bool _isLabReportsLoading = false;
  String _searchQuery = '';
  List<Map<String, dynamic>> _prescriptions = [];
  List<Map<String, dynamic>> _labReports = [];

  @override
  void initState() {
    super.initState();
    _loadHospitalData();
  }

  Future<void> _loadHospitalData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final hospitalModel = await ApiService.getUserInfo(user.uid);

      // Load profile image from SharedPreferences (reserved for future use)
      final prefs = await SharedPreferences.getInstance();
      prefs.getString('hospital_profile_image_url');

      if (mounted) {
        setState(() {
          _hospital = hospitalModel;
          _isLoading = false;
        });
      }
      await _fetchPatientRecords();
      await _fetchPrescriptions();
    } catch (e) {
      print('❌ Error loading hospital data: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _fetchPatientRecords() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Get hospital ID from user info
      final hospitalModel = await ApiService.getUserInfo(user.uid);
      if (hospitalModel?.uid == null) return;

      // Fetch patient records using the new API
      final records =
          await ApiService.getPatientRecordsByHospital(hospitalModel!.uid);

      if (mounted) {
        setState(() {
          // Patient records removed - only using prescriptions and lab reports
        });
      }
    } catch (e) {
      print('❌ Error fetching patient records: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load patient records: $e'),
            backgroundColor: kHospitalError,
          ),
        );
      }
    }
  }

  Future<void> _refreshData() async {
    setState(() => _isRefreshing = true);
    await _fetchPatientRecords();
    await _fetchPrescriptions();
    setState(() => _isRefreshing = false);
  }

  Future<void> _fetchPrescriptions() async {
    if (mounted) {
      setState(() {
        _isPrescriptionsLoading = true;
      });
    }

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Get hospital ID from user info
      final hospitalModel = await ApiService.getUserInfo(user.uid);
      if (hospitalModel?.uid == null) return;

      print('🏥 Fetching prescriptions for hospital: ${hospitalModel!.uid}');

      // Fetch prescriptions for this hospital
      final prescriptions =
          await ApiService.getPrescriptionsByHospital(hospitalModel.uid);

      print('🏥 Found ${prescriptions.length} prescriptions');

      if (mounted) {
        setState(() {
          _prescriptions = prescriptions;
          _isPrescriptionsLoading = false;
        });
      }
    } catch (e) {
      print('❌ Error fetching prescriptions: $e');
      if (mounted) {
        setState(() {
          _isPrescriptionsLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load prescriptions: $e'),
            backgroundColor: kHospitalError,
          ),
        );
      }
    }
  }

  Future<void> _fetchLabReportsByArcId(String arcId) async {
    setState(() {
      _isLabReportsLoading = true;
    });

    try {
      print('🏥 Fetching lab reports for patient ARC ID: $arcId');

      // Fetch lab reports by patient ARC ID
      final labReportsData = await ApiService.getLabReportsByArcId(arcId);

      print('🏥 Found ${labReportsData.length} lab reports');

      if (mounted) {
        setState(() {
          _labReports = labReportsData;
          _isLabReportsLoading = false;
        });
      }
    } catch (e) {
      print('❌ Error fetching lab reports: $e');
      if (mounted) {
        setState(() {
          _isLabReportsLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load lab reports: $e'),
            backgroundColor: kHospitalError,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kHospitalBackground,
      body: _isLoading
          ? _buildLoadingScreen()
          : Column(
              children: [
                // Modern Header with Profile
                _buildHeader(),

                // Tab Bar
                _buildTabBar(),

                // Search Bar
                _buildSearchBar(),

                // Content
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _refreshData,
                    color: kHospitalPrimary,
                    child: _isRefreshing
                        ? const Center(
                            child: CircularProgressIndicator(
                                color: kHospitalPrimary))
                        : _buildContent(),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildLoadingScreen() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF6A11CB), Color(0xFF2575FC)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              color: Colors.white,
              strokeWidth: 3,
            ),
            SizedBox(height: 16),
            Text(
              'Loading Patient Records...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF6A11CB), Color(0xFF2575FC)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              // Top row with back button and title
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                  ),
                  Expanded(
                    child: Text(
                      'Patient Records',
                      style: GoogleFonts.poppins(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(width: 48), // Balance the back button
                ],
              ),
              const SizedBox(height: 16),

              // Profile section
              Row(
                children: [
                  // Gradient avatar without question mark
                  Container(
                    width: 60,
                    height: 60,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [Color(0xFF6A11CB), Color(0xFF2575FC)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: const Icon(Icons.local_hospital,
                        color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 16),

                  // Hospital info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _hospital?.fullName ?? 'Hospital',
                          style: GoogleFonts.poppins(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'See the patient prescriptions and reports',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: Colors.white70,
                          ),
                        ),
                      ],
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

  Widget _buildTabBar() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF6A11CB), Color(0xFF2575FC)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
      ),
      child: Row(
        children: [
          Expanded(
              child:
                  _buildTabButtonIcon(Icons.receipt_long, 0, 'Prescriptions')),
          Expanded(child: _buildTabButtonIcon(Icons.science, 1, 'Lab Reports')),
        ],
      ),
    );
  }

  // Deprecated text tab button kept for reference (no longer used)

  Widget _buildTabButtonIcon(IconData icon, int index, String tooltip) {
    final isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedIndex = index;
        });
      },
      child: Tooltip(
        message: tooltip,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
          decoration: BoxDecoration(
            color: isSelected
                ? Colors.white.withOpacity(0.15)
                : Colors.transparent,
            border: Border(
              bottom: BorderSide(
                color: isSelected ? Colors.white : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          child: Icon(
            icon,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: TextField(
        onChanged: (value) {
          setState(() {
            _searchQuery = value;
          });
        },
        decoration: InputDecoration(
          hintText: 'Search patient records...',
          prefixIcon: const Icon(Icons.search, color: kHospitalPrimary),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: kHospitalBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: kHospitalPrimary),
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    switch (_selectedIndex) {
      case 0:
        return _buildPrescriptions();
      case 1:
        return _buildLabReports();
      default:
        return _buildPrescriptions();
    }
  }

  Widget _buildPrescriptions() {
    if (_isPrescriptionsLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(kHospitalPrimary),
            ),
            SizedBox(height: 16),
            Text(
              'Loading prescriptions...',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    // Apply search filter to prescriptions
    final List<Map<String, dynamic>> visiblePrescriptions =
        _prescriptions.where((prescription) {
      if (_searchQuery.trim().isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      final patientName =
          (prescription['patientName'] ?? '').toString().toLowerCase();
      final doctorName =
          (prescription['doctorName'] ?? '').toString().toLowerCase();
      final diagnosis =
          (prescription['diagnosis'] ?? '').toString().toLowerCase();
      final patientArcId =
          (prescription['patientArcId'] ?? '').toString().toLowerCase();
      return patientName.contains(q) ||
          doctorName.contains(q) ||
          diagnosis.contains(q) ||
          patientArcId.contains(q);
    }).toList();

    if (visiblePrescriptions.isEmpty) {
      return _buildPrescriptionsEmptyState();
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: visiblePrescriptions.length,
      itemBuilder: (context, index) {
        final prescription = visiblePrescriptions[index];
        return _buildPrescriptionCard(prescription);
      },
    );
  }

  Widget _buildLabReports() {
    // Apply search filter to lab reports
    final List<Map<String, dynamic>> visibleReports =
        _labReports.where((report) {
      if (_searchQuery.trim().isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      final testName = (report['testName'] ?? '').toString().toLowerCase();
      final patientName =
          (report['patientName'] ?? '').toString().toLowerCase();
      final labName = (report['labName'] ?? '').toString().toLowerCase();
      final notes = (report['notes'] ?? '').toString().toLowerCase();
      return testName.contains(q) ||
          patientName.contains(q) ||
          labName.contains(q) ||
          notes.contains(q);
    }).toList();

    if (_isLabReportsLoading) {
      return const Center(
        child: CircularProgressIndicator(color: kHospitalPrimary),
      );
    }

    if (visibleReports.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  color: kHospitalAccent,
                  borderRadius: BorderRadius.circular(42),
                ),
                child: const Icon(
                  Icons.science,
                  size: 42,
                  color: kHospitalPrimary,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'No Lab Reports Found',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: kHospitalPrimaryText,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Search for a patient ARC ID to view their lab reports',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: kHospitalSecondaryText,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                  _showArcIdSearchDialog();
                },
                icon: const Icon(Icons.search),
                label: const Text('Search by ARC ID'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kHospitalPrimary,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: visibleReports.length,
      itemBuilder: (context, index) {
        final report = visibleReports[index];
        return _buildLabReportCard(report);
      },
    );
  }

  void _showArcIdSearchDialog() {
    final TextEditingController arcIdController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Search Lab Reports',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: kHospitalPrimaryText,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Enter patient ARC ID to fetch their lab reports',
              style: GoogleFonts.poppins(
                color: kHospitalSecondaryText,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: arcIdController,
              decoration: InputDecoration(
                labelText: 'Patient ARC ID',
                hintText: 'e.g., ARC-D7159326',
                prefixIcon: const Icon(Icons.qr_code, color: kHospitalPrimary),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: kHospitalBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: kHospitalPrimary),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(color: kHospitalSecondaryText),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              final arcId = arcIdController.text.trim();
              if (arcId.isNotEmpty) {
                Navigator.pop(context);
                _fetchLabReportsByArcId(arcId);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: kHospitalPrimary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'Search',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabReportCard(Map<String, dynamic> report) {
    final status = report['status'] ?? 'pending';
    final statusColor = _getStatusColor(status);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kHospitalBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [statusColor, statusColor.withOpacity(0.7)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.science,
            color: Colors.white,
            size: 24,
          ),
        ),
        title: Text(
          report['testName'] ?? 'Lab Report',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 16,
            color: kHospitalPrimaryText,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: GoogleFonts.poppins(
                      color: statusColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: kHospitalAccent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    report['testName'] ?? 'Unknown',
                    style: GoogleFonts.poppins(
                      color: kHospitalPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 16,
              runSpacing: 4,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.person, size: 12, color: kHospitalSecondaryText),
                    const SizedBox(width: 4),
                    Text(
                      'Patient: ${report['patientName'] ?? 'Unknown'}',
                      style: GoogleFonts.poppins(
                        color: kHospitalSecondaryText,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.business,
                        size: 12, color: kHospitalSecondaryText),
                    const SizedBox(width: 4),
                    Text(
                      'Lab: ${report['labName'] ?? 'Lab'}',
                      style: GoogleFonts.poppins(
                        color: kHospitalSecondaryText,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.calendar_today,
                        size: 12, color: kHospitalSecondaryText),
                    const SizedBox(width: 4),
                    Text(
                      'Date: ${_formatDate(report['uploadDate'])}',
                      style: GoogleFonts.poppins(
                        color: kHospitalSecondaryText,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        trailing: report['reportUrl'] != null && report['reportUrl'].isNotEmpty
            ? IconButton(
                onPressed: () => _openReport(report),
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [statusColor, statusColor.withOpacity(0.7)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.open_in_new,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              )
            : Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.block,
                  color: Colors.grey,
                  size: 20,
                ),
              ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return kHospitalSuccess;
      case 'pending':
        return kHospitalWarning;
      case 'in_progress':
        return kHospitalPrimary;
      case 'cancelled':
        return kHospitalError;
      default:
        return Colors.grey;
    }
  }

  Future<void> _openReport(Map<String, dynamic> report) async {
    try {
      print('🔍 Opening report: ${report['testName']}');
      print('🔍 Report URL: ${report['reportUrl']}');

      final reportUrl = report['reportUrl'] ?? '';
      if (reportUrl.isEmpty) {
        throw Exception('Report URL is empty');
      }

      final Uri url = Uri.parse(reportUrl);

      if (await canLaunchUrl(url)) {
        print('✅ Can launch URL, opening in external app');
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        print('⚠️ Cannot launch URL externally, trying in-app webview');
        await launchUrl(url, mode: LaunchMode.platformDefault);
      }
    } catch (e) {
      print('❌ Error opening report: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not open report: $e'),
          backgroundColor: kHospitalError,
        ),
      );
    }
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return 'Unknown date';
    try {
      final date = DateTime.parse(dateString);
      return DateFormat('MMM dd, yyyy').format(date);
    } catch (e) {
      return 'Invalid date';
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Color(0xFF6A11CB), Color(0xFF2575FC)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child:
                  const Icon(Icons.folder_open, color: Colors.white, size: 36),
            ),
            const SizedBox(height: 24),
            Text(
              'No Patient Records Found',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF6A11CB),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Patient records will appear here once patients are admitted.',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: kHospitalSecondaryText,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrescriptionsEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Color(0xFF6A11CB), Color(0xFF2575FC)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child:
                  const Icon(Icons.medication, color: Colors.white, size: 36),
            ),
            const SizedBox(height: 24),
            Text(
              'No Prescriptions Found',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF6A11CB),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Prescriptions will appear here once doctors create them for patients.',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: kHospitalSecondaryText,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPatientRecordCard(Map<String, dynamic> record) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6A11CB), Color(0xFF2575FC)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: kHospitalPrimary.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.white24),
        child: ExpansionTile(
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.person, color: Colors.white, size: 24),
          ),
          title: Text(
            record['patientName'],
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              color: Colors.white,
              fontSize: 16,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Text(
                'ARC ID: ${record['patientArcId']}',
                style: GoogleFonts.poppins(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Doctor: ${record['doctorName'] ?? record['doctorAssigned'] ?? '-'}',
                style: GoogleFonts.poppins(
                  color: Colors.white60,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          children: [
            Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: Column(
                children: [
                  // Record details
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildDetailRow('Patient ID', record['patientId']),
                        _buildDetailRow(
                            'Admission Date',
                            DateFormat('MMM d, y')
                                .format(record['admissionDate'])),
                        _buildDetailRow('Status', record['status']),
                        _buildDetailRow('Prescriptions',
                            '${record['prescriptions'].length} active'),
                        _buildDetailRow('Lab Reports',
                            '${record['labReports'].length} completed'),
                        _buildDetailRow('Appointments',
                            '${record['appointments'].length} scheduled'),
                        _buildDetailRow('Total Billing',
                            '\$${record['billingHistory'].fold(0.0, (sum, bill) => sum + bill['amount'])}'),
                      ],
                    ),
                  ),

                  // Action buttons
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _viewFullRecord(record),
                            icon: const Icon(Icons.visibility, size: 18),
                            label: Text(
                              'View Full Record',
                              style: GoogleFonts.poppins(fontSize: 12),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: kHospitalPrimary,
                              side: const BorderSide(color: kHospitalPrimary),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _archiveRecord(record),
                            icon: const Icon(Icons.archive, size: 18),
                            label: Text(
                              'Archive',
                              style: GoogleFonts.poppins(fontSize: 12),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: kHospitalWarning,
                              foregroundColor: Colors.black,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
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
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.white70,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _viewFullRecord(Map<String, dynamic> record) {
    // TODO: Navigate to full patient record screen
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Viewing full record for ${record['patientName']}',
          style: GoogleFonts.poppins(),
        ),
        backgroundColor: kHospitalPrimary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  void _archiveRecord(Map<String, dynamic> record) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          'Archive Record',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: kHospitalPrimaryText,
          ),
        ),
        content: Text(
          'Archive patient record for ${record['patientName']}? This will move it to archived records.',
          style: GoogleFonts.poppins(
            color: kHospitalSecondaryText,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(
                color: kHospitalSecondaryText,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Record archived successfully',
                    style: GoogleFonts.poppins(),
                  ),
                  backgroundColor: kHospitalSuccess,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: kHospitalWarning,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'Archive',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrescriptionCard(Map<String, dynamic> prescription) {
    String _val(String key) {
      final v = prescription[key];
      if (v == null) return '';
      final s = v.toString().trim();
      return s;
    }

    final String displayId = _val('id').isNotEmpty
        ? _val('id')
        : (_val('_id').isNotEmpty ? _val('_id') : '—');
    final String patientLabel = _val('patientName').isNotEmpty
        ? _val('patientName')
        : (_val('patientArcId').isNotEmpty
            ? _val('patientArcId')
            : 'Unknown Patient');
    final String dateIso = _val('prescriptionDate').isNotEmpty
        ? _val('prescriptionDate')
        : _val('createdAt');

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6A11CB), Color(0xFF2575FC)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: kHospitalPrimary.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.white24),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          childrenPadding: const EdgeInsets.all(16),
          iconColor: Colors.white,
          collapsedIconColor: Colors.white,
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child:
                    const Icon(Icons.medication, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      patientLabel,
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_val('doctorName')} • ${_val('diagnosis')}',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.white70,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _val('status'),
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              children: [
                Icon(Icons.calendar_today, size: 14, color: Colors.white70),
                const SizedBox(width: 4),
                Text(
                  DateFormat('MMM d, y').format(DateTime.parse(dateIso)),
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(width: 16),
                Icon(Icons.person, size: 14, color: Colors.white70),
                const SizedBox(width: 4),
                Text(
                  _val('patientArcId'),
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
          children: [
            // Prescription Details
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDetailRow('Prescription ID', displayId),
                  _buildDetailRow('Patient', patientLabel),
                  _buildDetailRow('Doctor', _val('doctorName')),
                  _buildDetailRow('Diagnosis', _val('diagnosis')),
                  _buildDetailRow('Status', _val('status')),
                  if (_val('instructions').isNotEmpty)
                    _buildDetailRow('Instructions', _val('instructions')),
                  if (_val('notes').isNotEmpty)
                    _buildDetailRow('Notes', _val('notes')),
                ],
              ),
            ),

            // Medications
            if (prescription['medications'] != null &&
                prescription['medications'].isNotEmpty)
              ...prescription['medications'].map<Widget>(
                  (medication) => _buildMedicationTile(medication)),
          ],
        ),
      ),
    );
  }

  Widget _buildMedicationTile(Map<String, dynamic> medication) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.medication_liquid, color: Colors.white, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  medication['name'] ?? 'Unknown Medication',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
                Text(
                  '${medication['dosage'] ?? ''} ${medication['frequency'] ?? ''}',
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
