import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:arcular_plus/screens/user/medicine_order_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:arcular_plus/services/api_service.dart';
import 'package:arcular_plus/models/user_model.dart';
import 'package:google_fonts/google_fonts.dart';

// Color constants for patient theme (green gradient)
const Color kPatientBackground = Color(0xFFF9FAFB);
const Color kPatientPrimary = Color(0xFF00C853); // Green
const Color kPatientSecondary = Color(0xFF66BB6A); // Light green
const Color kPatientAccent = Color(0xFFE8F5E8);
const Color kPrimaryText = Color(0xFF2E2E2E);
const Color kSecondaryText = Color(0xFF6B7280);
const Color kBorder = Color(0xFFE5E7EB);
const Color kSuccess = Color(0xFF34D399);
const Color kWarning = Color(0xFFFFD54F);
const Color kError = Color(0xFFEF4444);

class PrescriptionScreen extends StatefulWidget {
  const PrescriptionScreen({super.key});

  @override
  State<PrescriptionScreen> createState() => _PrescriptionScreenState();
}

class _PrescriptionScreenState extends State<PrescriptionScreen> {
  int _selectedIndex = 0;
  UserModel? _user;
  bool _isLoading = true;
  bool _isRefreshing = false;
  List<Map<String, dynamic>> _items = [];

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final userModel = await ApiService.getUserInfo(user.uid);

      if (mounted) {
        setState(() {
          _user = userModel;
          _isLoading = false;
        });
      }
      await _fetchTabData();
    } catch (e) {
      print('❌ Error loading user data: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _fetchTabData() async {
    if (_user == null) return;

    String? status;
    if (_selectedIndex == 0) status = 'Active';
    if (_selectedIndex == 1) status = 'Completed';

    print(
        '🩺 Fetching prescriptions for tab: $_selectedIndex, status: $status');
    print('🩺 User healthQrId: ${_user!.healthQrId}, arcId: ${_user!.arcId}');

    try {
      List<Map<String, dynamic>> data = [];

      // Try to fetch by ARC ID first (preferred method)
      String? arcId = _user!.healthQrId ?? _user!.arcId;
      if (arcId != null && arcId.isNotEmpty) {
        print('🩺 Fetching by ARC ID: $arcId with status: $status');

        // First try without status filter to see if there are any prescriptions
        final allData = await ApiService.getPrescriptionsByPatientArcId(arcId);
        print(
            '🩺 All prescriptions for ARC ID (no status filter): ${allData.length}');
        if (allData.isNotEmpty) {
          print(
              '🩺 Sample prescription statuses: ${allData.map((p) => p['status']).toList()}');
        }

        data = await ApiService.getPrescriptionsByPatientArcId(arcId,
            status: status);
        print('🩺 ARC ID fetch result: ${data.length} prescriptions');
        if (data.isNotEmpty) {
          print('🩺 Sample prescription data: ${data.first}');
        }
      }

      // Fallback to UID if ARC ID method fails or returns empty
      if (data.isEmpty) {
        final uid = FirebaseAuth.instance.currentUser?.uid;
        if (uid != null) {
          print('🩺 Fallback: Fetching by UID: $uid');
          data = await ApiService.getPrescriptionsByStatus(uid, status: status);
          print('🩺 UID fetch result: ${data.length} prescriptions');
        }
      }

      print('🩺 Final data count: ${data.length}');
      if (mounted) setState(() => _items = data);
    } catch (e) {
      print('❌ Error fetching prescriptions: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load prescriptions: $e'),
            backgroundColor: kError,
          ),
        );
      }
    }
  }

  Future<void> _refreshData() async {
    setState(() => _isRefreshing = true);
    await _fetchTabData();
    setState(() => _isRefreshing = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kPatientBackground,
      body: _isLoading
          ? _buildLoadingScreen()
          : Column(
              children: [
                // Modern Header with Profile
                _buildHeader(),

                // Tab Bar
                _buildTabBar(),

                // Content
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _refreshData,
                    color: kPatientPrimary,
                    child: _isRefreshing
                        ? const Center(
                            child: CircularProgressIndicator(
                                color: kPatientPrimary))
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
          colors: [kPatientPrimary, kPatientSecondary, kPatientAccent],
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
              'Loading Prescriptions...',
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
          colors: [kPatientPrimary, kPatientSecondary],
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
                      'View Prescriptions',
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

              // Title block (no profile avatar)
              Align(
                alignment: Alignment.centerLeft,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Manage your prescriptions',
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Prescriptions fetched from doctor will auto-show in the "Prescriptions" tab',
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
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: Colors.white,
      child: Row(
        children: [
          Expanded(child: _buildTabButton('Active', 0)),
          Expanded(child: _buildTabButton('Completed', 1)),
        ],
      ),
    );
  }

  Widget _buildTabButton(String title, int index) {
    final isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedIndex = index;
        });
        _fetchTabData();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? kPatientPrimary : Colors.transparent,
          border: Border(
            bottom: BorderSide(
              color: isSelected ? kPatientPrimary : kBorder,
              width: 3,
            ),
          ),
        ),
        child: Text(
          title,
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            color: isSelected ? Colors.white : kSecondaryText,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    switch (_selectedIndex) {
      case 0:
        return _buildActivePrescriptions();
      case 1:
        return _buildCompletedPrescriptions();
      default:
        return _buildActivePrescriptions();
    }
  }

  Widget _buildActivePrescriptions() {
    if (_items.isEmpty) {
      return _buildEmptyState(
        icon: Icons.medication,
        title: 'No Active Prescriptions',
        subtitle: 'You don\'t have any active prescriptions at the moment.',
        actionText: 'Visit a doctor to get a prescription',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _items.length,
      itemBuilder: (context, index) {
        final prescription = _normalizePrescription(_items[index]);
        return _buildPrescriptionCard(prescription);
      },
    );
  }

  Widget _buildCompletedPrescriptions() {
    if (_items.isEmpty) {
      return _buildEmptyState(
        icon: Icons.check_circle,
        title: 'No Completed Prescriptions',
        subtitle: 'Completed prescriptions will appear here once finished.',
        actionText: 'Check back after completing treatments',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _items.length,
      itemBuilder: (context, index) {
        final prescription = _normalizePrescription(_items[index]);
        return _buildPrescriptionCard(prescription);
      },
    );
  }

  // Archived tab removed per requirements

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
    required String actionText,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: kPatientPrimary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 64,
                color: kPatientPrimary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: kPrimaryText,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: kSecondaryText,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: kPatientAccent,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                actionText,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: kPatientPrimary,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrescriptionCard(Map<String, dynamic> prescription) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [kPatientPrimary, kPatientSecondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: kPatientPrimary.withOpacity(0.2),
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
            child: const Icon(Icons.medication, color: Colors.white, size: 24),
          ),
          title: Text(
            'Prescription #${prescription['id']}',
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
              if (_user?.type == 'patient')
                Text(
                  '${prescription['doctor']} - ${prescription['specialty']}',
                  style: GoogleFonts.poppins(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                )
              else if (_user?.type == 'doctor')
                Text(
                  'Patient: ${prescription['patient'] ?? 'Unknown Patient'}',
                  style: GoogleFonts.poppins(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                )
              else if (_user?.type == 'pharmacy')
                Text(
                  'Patient: ${prescription['patient'] ?? 'Unknown Patient'} - ${prescription['doctor']}',
                  style: GoogleFonts.poppins(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              const SizedBox(height: 2),
              Text(
                'Date: ${DateFormat('MMM d, y').format(prescription['date'])}',
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
                  ...prescription['medications'].map<Widget>(
                      (medication) => _buildMedicationTile(medication)),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        if (_user?.type == 'patient') ...[
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _addToMyMedicines(prescription),
                              icon: const Icon(Icons.add_circle_outline,
                                  size: 18),
                              label: Text(
                                'Add To My Medicines',
                                style: GoogleFonts.poppins(fontSize: 12),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: kPatientPrimary,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () =>
                                  _refillPrescription(prescription),
                              icon: const Icon(Icons.refresh, size: 18),
                              label: Text(
                                'Request Refill',
                                style: GoogleFonts.poppins(fontSize: 12),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: kWarning,
                                foregroundColor: Colors.black,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                        ] else if (_user?.type == 'doctor') ...[
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _editPrescription(prescription),
                              icon: const Icon(Icons.edit, size: 18),
                              label: Text(
                                'Edit',
                                style: GoogleFonts.poppins(fontSize: 12),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () =>
                                  _viewPatientHistory(prescription),
                              icon: const Icon(Icons.history, size: 18),
                              label: Text(
                                'Patient History',
                                style: GoogleFonts.poppins(fontSize: 12),
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: kPatientPrimary,
                                side: const BorderSide(color: kPatientPrimary),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                        ] else if (_user?.type == 'pharmacy') ...[
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () =>
                                  _dispenseMedication(prescription),
                              icon: const Icon(Icons.medication, size: 18),
                              label: Text(
                                'Dispense',
                                style: GoogleFonts.poppins(fontSize: 12),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _contactDoctor(prescription),
                              icon: const Icon(Icons.phone, size: 18),
                              label: Text(
                                'Contact Doctor',
                                style: GoogleFonts.poppins(fontSize: 12),
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: kPatientPrimary,
                                side: const BorderSide(color: kPatientPrimary),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                        ],
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

  Map<String, dynamic> _normalizePrescription(Map<String, dynamic> raw) {
    return {
      'id': raw['_id'] ?? raw['id'] ?? '',
      'doctor': raw['doctorName'] ?? raw['doctor'] ?? '',
      'specialty': raw['doctorSpecialty'] ?? raw['specialty'] ?? '',
      'patient': raw['patient'] ?? '',
      'date': raw['prescriptionDate'] != null
          ? DateTime.parse(raw['prescriptionDate'])
          : DateTime.now(),
      'medications': (raw['medications'] as List?)
              ?.map((m) => {
                    'name': m['name'] ?? '',
                    'dosage': m['dose'] ?? m['dosage'] ?? '',
                    'frequency': m['frequency'] ?? '',
                    'duration': m['duration'] ?? '',
                    'instructions': m['instructions'],
                    'status':
                        (raw['status'] ?? 'Active').toString().toLowerCase(),
                    'times': m['times'] ?? [],
                  })
              .toList() ??
          [],
      'status': raw['status'] ?? 'Active',
    };
  }

  Future<void> _addToMyMedicines(Map<String, dynamic> prescription) async {
    try {
      final id = (prescription['id'] ?? '').toString();
      final items = await ApiService.transformPrescriptionToMedicines(id);

      if (items.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'No medicines found in this prescription',
                style: GoogleFonts.poppins(),
              ),
              backgroundColor: kError,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        }
        return;
      }

      int successCount = 0;
      int failCount = 0;

      for (final m in items) {
        try {
          final success = await ApiService.addMedication(m);
          if (success) {
            successCount++;
          } else {
            failCount++;
            print('❌ Failed to add medicine: ${m['name']}');
          }
        } catch (e) {
          failCount++;
          print('❌ Error adding medicine ${m['name']}: $e');
        }
      }

      if (mounted) {
        if (successCount == items.length) {
          // All medicines added successfully
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Successfully added ${successCount} medication(s) to My Medicines',
                style: GoogleFonts.poppins(),
              ),
              backgroundColor: kSuccess,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        } else if (successCount > 0) {
          // Some medicines added successfully
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Added ${successCount} of ${items.length} medications. ${failCount} failed.',
                style: GoogleFonts.poppins(),
              ),
              backgroundColor: kWarning,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        } else {
          // No medicines added successfully
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Failed to add any medications. Please try again.',
                style: GoogleFonts.poppins(),
              ),
              backgroundColor: kError,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        }
      }
    } catch (e) {
      print('❌ Error adding to medicines: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to add medications: $e',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: kError,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }
  }

  Widget _buildMedicationTile(Map<String, dynamic> medication) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kPatientAccent,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  medication['name'],
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: kPrimaryText,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getStatusColor(medication['status']).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  medication['status'].toUpperCase(),
                  style: GoogleFonts.poppins(
                    color: _getStatusColor(medication['status']),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildMedicationInfoRow('Dosage', medication['dosage']),
          _buildMedicationInfoRow('Frequency', medication['frequency']),
          _buildMedicationInfoRow('Duration', medication['duration']),
          if (medication['instructions'] != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: kPatientPrimary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: kPatientPrimary.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: kPatientPrimary, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Instructions: ${medication['instructions']}',
                      style: GoogleFonts.poppins(
                        color: kPatientPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMedicationInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: kSecondaryText,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: kPrimaryText,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return kSuccess;
      case 'completed':
        return kPatientPrimary;
      case 'expired':
        return kError;
      case 'discontinued':
        return Colors.orange;
      case 'archived':
        return kSecondaryText;
      default:
        return kSecondaryText;
    }
  }

  // Removed unused download action as per new UX

  void _refillPrescription(Map<String, dynamic> prescription) async {
    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: kPatientPrimary),
              const SizedBox(height: 16),
              Text(
                'Requesting refill...',
                style: GoogleFonts.poppins(),
              ),
            ],
          ),
        ),
      );

      // Extract medicine names from prescription medications
      final medications = prescription['medications'] as List<dynamic>? ?? [];
      if (medications.isEmpty) {
        // Close loading dialog
        if (mounted) Navigator.pop(context);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'No medicines found in this prescription',
                style: GoogleFonts.poppins(),
              ),
              backgroundColor: kError,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        }
        return;
      }

      // Get the first medicine name for search
      final firstMedicine = medications.first as Map<String, dynamic>;
      final medicineName = firstMedicine['name'] as String? ?? '';

      if (medicineName.isEmpty) {
        // Close loading dialog
        if (mounted) Navigator.pop(context);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'No medicine name found to search',
                style: GoogleFonts.poppins(),
              ),
              backgroundColor: kError,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        }
        return;
      }

      // Close loading dialog
      if (mounted) Navigator.pop(context);

      // Navigate to medicine order screen with search query
      if (mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MedicineOrderScreen(searchQuery: medicineName),
          ),
        );
      }
    } catch (e) {
      print('❌ Error requesting refill: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to request refill: $e',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: kError,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }
  }

  void _editPrescription(Map<String, dynamic> prescription) {
    // TODO: Navigate to edit prescription screen
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Edit prescription feature coming soon',
          style: GoogleFonts.poppins(),
        ),
        backgroundColor: kWarning,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  void _viewPatientHistory(Map<String, dynamic> prescription) {
    // TODO: Navigate to patient history screen
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Patient history feature coming soon',
          style: GoogleFonts.poppins(),
        ),
        backgroundColor: kWarning,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  void _dispenseMedication(Map<String, dynamic> prescription) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          'Dispense Medication',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: kPrimaryText,
          ),
        ),
        content: Text(
          'Confirm dispensing medication for prescription #${prescription['id']}?',
          style: GoogleFonts.poppins(
            color: kSecondaryText,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(
                color: kSecondaryText,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Medication dispensed successfully',
                    style: GoogleFonts.poppins(),
                  ),
                  backgroundColor: kSuccess,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: kPatientPrimary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'Dispense',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _contactDoctor(Map<String, dynamic> prescription) {
    // TODO: Implement contact doctor functionality
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Contact doctor feature coming soon',
          style: GoogleFonts.poppins(),
        ),
        backgroundColor: kWarning,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}
