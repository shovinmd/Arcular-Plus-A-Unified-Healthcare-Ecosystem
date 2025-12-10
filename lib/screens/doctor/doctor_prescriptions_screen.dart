import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:arcular_plus/services/api_service.dart';
import 'package:arcular_plus/models/user_model.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:arcular_plus/screens/doctor/create_prescription_screen.dart';

// Color constants for doctor theme (purple gradient)
const Color kDoctorBackground = Color(0xFFF9FAFB);
const Color kDoctorPrimary = Color(0xFF6A11CB); // Purple
const Color kDoctorSecondary = Color(0xFF2575FC); // Blue-purple
const Color kDoctorAccent = Color(0xFFF3E8FF);
const Color kPrimaryText = Color(0xFF2E2E2E);
const Color kSecondaryText = Color(0xFF6B7280);
const Color kBorder = Color(0xFFE5E7EB);
const Color kSuccess = Color(0xFF34D399);
const Color kWarning = Color(0xFFFFD54F);
const Color kError = Color(0xFFEF4444);

class DoctorPrescriptionsScreen extends StatefulWidget {
  const DoctorPrescriptionsScreen({super.key});

  @override
  State<DoctorPrescriptionsScreen> createState() =>
      _DoctorPrescriptionsScreenState();
}

class _DoctorPrescriptionsScreenState extends State<DoctorPrescriptionsScreen> {
  int _selectedIndex = 0;
  UserModel? _doctor;
  bool _isLoading = true;
  bool _isRefreshing = false;
  List<Map<String, dynamic>> _prescriptions = [];
  String? _profileImageUrl;
  String _searchQuery = '';
  String _selectedPatientFilter = 'All';

  @override
  void initState() {
    super.initState();
    _loadDoctorData();
  }

  Future<void> _loadDoctorData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final doctorModel = await ApiService.getUserInfo(user.uid);

      // Load profile image from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final profileImageUrl = prefs.getString('doctor_profile_image_url');

      if (mounted) {
        setState(() {
          _doctor = doctorModel;
          _profileImageUrl = profileImageUrl;
          _isLoading = false;
        });
      }
      await _fetchPrescriptions();
    } catch (e) {
      print('❌ Error loading doctor data: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _fetchPrescriptions() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      final data = await ApiService.getPrescriptionsByDoctor(uid);
      if (mounted) setState(() => _prescriptions = data);
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
    await _fetchPrescriptions();
    setState(() => _isRefreshing = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kDoctorBackground,
      body: _isLoading
          ? _buildLoadingScreen()
          : Column(
              children: [
                // Modern Header with Profile
                _buildHeader(),

                // Tab Bar
                _buildTabBar(),

                // Search and Filter Bar
                _buildSearchAndFilter(),

                // Content
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _refreshData,
                    color: kDoctorPrimary,
                    child: _isRefreshing
                        ? const Center(
                            child: CircularProgressIndicator(
                                color: kDoctorPrimary))
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
          colors: [kDoctorPrimary, kDoctorSecondary, kDoctorAccent],
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
          colors: [kDoctorPrimary, kDoctorSecondary],
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
                      'Manage Prescriptions',
                      style: GoogleFonts.poppins(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  IconButton(
                    onPressed: _createNewPrescription,
                    icon: const Icon(Icons.add, color: Colors.white),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Profile section
              Row(
                children: [
                  // Profile image
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.white24,
                    backgroundImage: _profileImageUrl != null
                        ? NetworkImage(_profileImageUrl!)
                        : null,
                    child: _profileImageUrl == null
                        ? Text(
                            (_doctor?.fullName?.isNotEmpty ?? false)
                                ? _doctor!.fullName![0].toUpperCase()
                                : '?',
                            style: GoogleFonts.poppins(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 16),

                  // Doctor info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Prescriptions',
                          style: GoogleFonts.poppins(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Create and manage patient prescriptions',
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
      color: Colors.white,
      child: Row(
        children: [
          Expanded(child: _buildTabButton('All Prescriptions', 0)),
          Expanded(child: _buildTabButton('Active', 1)),
          Expanded(child: _buildTabButton('Completed', 2)),
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
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? kDoctorPrimary : Colors.transparent,
          border: Border(
            bottom: BorderSide(
              color: isSelected ? kDoctorPrimary : kBorder,
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

  Widget _buildSearchAndFilter() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
              decoration: InputDecoration(
                hintText: 'Search by patient name, ARC ID, diagnosis...',
                prefixIcon: const Icon(Icons.search, color: kDoctorPrimary),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: kBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: kDoctorPrimary),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          DropdownButton<String>(
            value: _selectedPatientFilter,
            items: const [
              DropdownMenuItem(value: 'All', child: Text('All Patients')),
              DropdownMenuItem(value: 'Recent', child: Text('Recent')),
            ],
            onChanged: (value) {
              setState(() {
                _selectedPatientFilter = value!;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    final filteredPrescriptions = _getFilteredPrescriptions();

    if (filteredPrescriptions.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filteredPrescriptions.length,
      itemBuilder: (context, index) {
        final prescription = filteredPrescriptions[index];
        return _buildPrescriptionCard(prescription);
      },
    );
  }

  List<Map<String, dynamic>> _getFilteredPrescriptions() {
    List<Map<String, dynamic>> filtered = _prescriptions;

    // Filter by tab
    if (_selectedIndex == 1) {
      filtered = filtered.where((p) => p['status'] == 'Active').toList();
    } else if (_selectedIndex == 2) {
      filtered = filtered.where((p) => p['status'] == 'Completed').toList();
    }

    // Filter by search query
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((p) {
        final patientName = (p['patientName'] ?? '').toLowerCase();
        final arcId = (p['patientArcId'] ?? '').toLowerCase();
        final doctorName = (p['doctorName'] ?? '').toLowerCase();
        final diagnosis = (p['diagnosis'] ?? '').toLowerCase();
        final query = _searchQuery.toLowerCase();

        // If query looks like an ARC ID, prioritize exact/startsWith matches
        final isArcQuery = query.startsWith('arc-');
        if (isArcQuery) {
          return arcId.startsWith(query) || arcId.contains(query);
        }

        return patientName.contains(query) ||
            arcId.contains(query) ||
            doctorName.contains(query) ||
            diagnosis.contains(query);
      }).toList();
    }

    return filtered;
  }

  Widget _buildEmptyState() {
    String title, subtitle, actionText;
    IconData icon;

    switch (_selectedIndex) {
      case 1:
        title = 'No Active Prescriptions';
        subtitle = 'You don\'t have any active prescriptions at the moment.';
        actionText = 'Create a new prescription for your patient';
        icon = Icons.medication;
        break;
      case 2:
        title = 'No Completed Prescriptions';
        subtitle =
            'Completed prescriptions will appear here once marked as done.';
        actionText = 'Mark prescriptions as completed when treatment is over';
        icon = Icons.check_circle;
        break;
      default:
        title = 'No Prescriptions Found';
        subtitle = 'Start creating prescriptions for your patients.';
        actionText = 'Create your first prescription';
        icon = Icons.medication;
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: kDoctorPrimary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 64,
                color: kDoctorPrimary,
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
            ElevatedButton.icon(
              onPressed: _createNewPrescription,
              icon: const Icon(Icons.add),
              label: Text(
                actionText,
                style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: kDoctorPrimary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
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
    final bool isCompleted = ((_val('status')).toLowerCase() == 'completed');
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [kDoctorPrimary, kDoctorSecondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: kDoctorPrimary.withOpacity(0.2),
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
            'Prescription #$displayId',
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
                'Patient: $patientLabel',
                style: GoogleFonts.poppins(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Date: ${dateIso.isNotEmpty ? DateFormat('MMM d, y').format(DateTime.parse(dateIso)) : '—'}',
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
                  // Prescription details
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildDetailRow('Diagnosis',
                            prescription['diagnosis'] ?? 'Not specified'),
                        _buildDetailRow(
                            'Instructions',
                            prescription['instructions'] ??
                                'No special instructions'),
                        if (prescription['followUpDate'] != null)
                          _buildDetailRow(
                              'Follow-up Date',
                              DateFormat('MMM d, y').format(DateTime.parse(
                                  prescription['followUpDate']))),
                        _buildDetailRow(
                            'Status', prescription['status'] ?? 'Active'),
                      ],
                    ),
                  ),

                  // Medications
                  if (prescription['medications'] != null &&
                      prescription['medications'].isNotEmpty)
                    ...prescription['medications'].map<Widget>(
                        (medication) => _buildMedicationTile(medication)),

                  // Action buttons
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        if (!isCompleted)
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => CreatePrescriptionScreen(
                                      doctor: _doctor!,
                                      isEdit: true,
                                      existingPrescription: prescription,
                                      onPrescriptionCreated: () {
                                        _fetchPrescriptions();
                                      },
                                    ),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.edit, size: 18),
                              label: Text(
                                'Edit',
                                style: GoogleFonts.poppins(fontSize: 12),
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: kDoctorPrimary,
                                side: const BorderSide(color: kDoctorPrimary),
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
                                _completePrescription(prescription),
                            icon: const Icon(Icons.check, size: 18),
                            label: Text(
                              isCompleted ? 'Completed' : 'Mark Complete',
                              style: GoogleFonts.poppins(fontSize: 12),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  isCompleted ? kSuccess : kWarning,
                              foregroundColor:
                                  isCompleted ? Colors.white : Colors.black,
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
            width: 100,
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

  Widget _buildMedicationTile(Map<String, dynamic> medication) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kDoctorAccent,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            medication['name'] ?? 'Unknown Medication',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: kPrimaryText,
            ),
          ),
          const SizedBox(height: 8),
          _buildMedicationInfoRow(
              'Dosage', medication['dose'] ?? 'Not specified'),
          _buildMedicationInfoRow(
              'Frequency', medication['frequency'] ?? 'Not specified'),
          _buildMedicationInfoRow(
              'Duration', medication['duration'] ?? 'Not specified'),
          if (medication['instructions'] != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: kDoctorPrimary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: kDoctorPrimary.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: kDoctorPrimary, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Instructions: ${medication['instructions']}',
                      style: GoogleFonts.poppins(
                        color: kDoctorPrimary,
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

  void _createNewPrescription() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreatePrescriptionScreen(
          doctor: _doctor!,
          onPrescriptionCreated: () {
            _fetchPrescriptions(); // Refresh the list
          },
        ),
      ),
    );
  }

  void _editPrescription(Map<String, dynamic> prescription) {
    final id = (prescription['id'] ?? prescription['_id']).toString();
    final TextEditingController diagnosisCtrl = TextEditingController(
        text: (prescription['diagnosis'] ?? '').toString());
    final TextEditingController instructionsCtrl = TextEditingController(
        text: (prescription['instructions'] ?? '').toString());
    final TextEditingController notesCtrl =
        TextEditingController(text: (prescription['notes'] ?? '').toString());
    DateTime? followUp = prescription['followUpDate'] != null
        ? DateTime.tryParse(prescription['followUpDate'])
        : null;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Edit Prescription',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: diagnosisCtrl,
                  decoration: const InputDecoration(labelText: 'Diagnosis'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: instructionsCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Instructions'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: notesCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Notes'),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        followUp == null
                            ? 'No follow-up date'
                            : 'Follow-up: ${DateFormat('MMM d, y').format(followUp!)}',
                        style: GoogleFonts.poppins(fontSize: 12),
                      ),
                    ),
                    TextButton(
                      onPressed: () async {
                        final now = DateTime.now();
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: followUp ?? now,
                          firstDate: now,
                          lastDate: now.add(const Duration(days: 365)),
                        );
                        if (picked != null) setLocal(() => followUp = picked);
                      },
                      child: const Text('Pick date'),
                    )
                  ],
                )
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel', style: GoogleFonts.poppins())),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                final payload = {
                  'diagnosis': diagnosisCtrl.text.trim(),
                  'instructions': instructionsCtrl.text.trim(),
                  'notes': notesCtrl.text.trim(),
                  'followUpDate': followUp?.toIso8601String(),
                };
                final ok = await ApiService.updatePrescription(id, payload);
                if (ok) {
                  await _fetchPrescriptions();
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text('Prescription updated',
                            style: GoogleFonts.poppins()),
                        backgroundColor: kSuccess),
                  );
                } else {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text('Failed to update',
                            style: GoogleFonts.poppins()),
                        backgroundColor: kError),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: kDoctorPrimary,
                  foregroundColor: Colors.white),
              child: Text('Save', style: GoogleFonts.poppins()),
            )
          ],
        ),
      ),
    );
  }

  void _completePrescription(Map<String, dynamic> prescription) {
    if (prescription['status'] == 'Completed') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'This prescription is already completed',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: kSuccess,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          'Complete Prescription',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: kPrimaryText,
          ),
        ),
        content: Text(
          'Mark prescription #${prescription['id']} as completed? This will move it to the user\'s completed prescriptions.',
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
            onPressed: () async {
              Navigator.pop(context);
              await _markPrescriptionComplete(prescription);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: kSuccess,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'Mark Complete',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _markPrescriptionComplete(
      Map<String, dynamic> prescription) async {
    try {
      final id = (prescription['id'] ?? prescription['_id']).toString();
      final ok = await ApiService.completePrescription(id);
      if (!ok) throw 'Server rejected request';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Prescription marked as completed successfully',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: kSuccess,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );

      // Refresh the prescriptions list
      await _fetchPrescriptions();
    } catch (e) {
      print('❌ Error completing prescription: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to complete prescription: $e',
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
