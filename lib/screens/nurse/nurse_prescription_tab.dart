import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/api_service.dart';
import '../../models/user_model.dart';

// Nurse prescription tab placeholder - matching nurse theme colors
class NursePrescriptionTab extends StatefulWidget {
  const NursePrescriptionTab({super.key});

  @override
  State<NursePrescriptionTab> createState() => _NursePrescriptionTabState();
}

class _NursePrescriptionTabState extends State<NursePrescriptionTab>
    with SingleTickerProviderStateMixin {
  // Nurse theme colors - Green to match assigned patients
  final Color kNursePrimary = const Color(0xFF17B18A); // Teal green
  final Color kNurseSecondary = const Color(0xFF0E8F78); // Darker teal

  List<UserModel> _assignedPatients = [];
  UserModel? _selectedPatient;
  List<Map<String, dynamic>> _prescriptions = [];
  List<Map<String, dynamic>> _reports = [];
  bool _isLoading = false;
  late TabController _tabController;
  final TextEditingController _arcIdCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) return;
      // Auto-fetch when visiting tabs
      if (_tabController.index == 0) {
        _loadPrescriptions();
      } else if (_tabController.index == 1) {
        if (_reports.isEmpty) _loadReports();
      }
    });
    _loadAssignedPatients();
  }

  Future<void> _loadAssignedPatients() async {
    setState(() => _isLoading = true);
    try {
      // Use assigned patients only
      final assignments = await ApiService.getNurseAssignments();
      final patients = assignments.map<UserModel>((a) {
        final p = a['patientId'] is Map ? a['patientId'] : null;
        final uid = p != null ? (p['_id'] ?? '') : (a['patientId'] ?? '');
        final name = a['patientName'] ??
            (p != null ? (p['fullName'] ?? 'Patient') : 'Patient');
        final arcId = a['patientArcId'] ??
            (p != null ? (p['healthQrId'] ?? p['arcId'] ?? '') : '');
        return UserModel(
          uid: uid,
          fullName: name,
          email: '',
          mobileNumber: '',
          gender: '',
          dateOfBirth: DateTime(2000, 1, 1),
          address: '',
          pincode: '',
          city: '',
          state: '',
          type: 'patient',
          createdAt: DateTime.now(),
          healthQrId: arcId,
        );
      }).toList();
      setState(() {
        _assignedPatients = patients;
        if (patients.isNotEmpty) {
          _selectedPatient = patients.first;
          _loadPrescriptions();
        }
      });
    } catch (e) {
      print('❌ Error loading assigned patients: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadPrescriptions() async {
    final arcFromInput = _arcIdCtrl.text.trim();
    final arcId = arcFromInput.isNotEmpty
        ? arcFromInput
        : (_selectedPatient?.healthQrId ?? '');
    if (arcId.isEmpty) return;

    try {
      // Fetch prescriptions strictly by ARC ID
      final prescriptions =
          await ApiService.getPatientPrescriptionsByArc(arcId);
      setState(() {
        _prescriptions = prescriptions;
      });
    } catch (e) {
      print('❌ Error loading prescriptions: $e');
    }
  }

  Future<void> _loadReports() async {
    final arcFromInput = _arcIdCtrl.text.trim();
    final fallbackArc = _selectedPatient?.healthQrId ?? '';
    final arcId = arcFromInput.isNotEmpty ? arcFromInput : fallbackArc;
    if (arcId.isEmpty) return;
    try {
      final reports = await ApiService.getLabReportsByArcId(arcId);
      setState(() => _reports = reports);
    } catch (e) {
      print('❌ Error loading reports: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Prescriptions',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        backgroundColor: kNursePrimary,
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Prescriptions', icon: Icon(Icons.medication_outlined)),
            Tab(text: 'Reports', icon: Icon(Icons.description_outlined)),
          ],
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              kNurseSecondary.withOpacity(0.3),
              kNursePrimary.withOpacity(0.1)
            ],
          ),
        ),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  _buildPatientSelector(),
                  _buildArcInput(),
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _prescriptions.isEmpty
                            ? _buildEmptyState()
                            : _buildPrescriptionsList(),
                        _buildReportsList(),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildPatientSelector() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Select Patient',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: kNursePrimary,
            ),
          ),
          const SizedBox(height: 12),
          if (_assignedPatients.isEmpty)
            Text(
              'No patients assigned',
              style: GoogleFonts.poppins(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            )
          else
            DropdownButtonFormField<UserModel>(
              value: _selectedPatient,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.person),
              ),
              items: _assignedPatients.map((patient) {
                return DropdownMenuItem<UserModel>(
                  value: patient,
                  child: Text(
                    patient.fullName,
                    style: GoogleFonts.poppins(),
                  ),
                );
              }).toList(),
              onChanged: (patient) {
                setState(() {
                  _selectedPatient = patient;
                  _arcIdCtrl.text = patient?.healthQrId ?? '';
                });
                _loadPrescriptions();
                _loadReports();
              },
            ),
        ],
      ),
    );
  }

  Widget _buildArcInput() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _arcIdCtrl,
              decoration: InputDecoration(
                labelText: 'Patient ARC ID (e.g., ARC-XXXXXXX)',
                prefixIcon: const Icon(Icons.qr_code_2),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () {
              _loadPrescriptions();
              _loadReports();
            },
            style: ElevatedButton.styleFrom(backgroundColor: kNurseSecondary),
            child: const Text('Fetch'),
          )
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
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
              color: kNursePrimary,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No Prescriptions',
            style: GoogleFonts.poppins(
              color: kNursePrimary,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'No prescriptions found for this patient',
            style: GoogleFonts.poppins(
              color: Colors.grey[600],
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportsList() {
    final arcFromInput = _arcIdCtrl.text.trim();
    final fallbackArc = _selectedPatient?.healthQrId ?? '';
    final arcId = arcFromInput.isNotEmpty ? arcFromInput : fallbackArc;
    if (arcId.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Enter patient ARC ID to fetch reports',
                style: GoogleFonts.poppins()),
            const SizedBox(height: 8),
            Text('Tip: selecting a patient will auto-fill ARC ID',
                style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey)),
          ],
        ),
      );
    }
    if (_reports.isEmpty) {
      return Center(
        child: Text('No reports', style: GoogleFonts.poppins()),
      );
    }
    // Show latest first
    final items = List<Map<String, dynamic>>.from(_reports);
    items.sort((a, b) => (b['createdAt'] ?? '')
        .toString()
        .compareTo((a['createdAt'] ?? '').toString()));
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      itemBuilder: (context, i) {
        final r = items[i];
        return Card(
          elevation: 2,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.description_outlined),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        (r['testName'] ?? r['title'] ?? 'Lab Report')
                            .toString(),
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (r['result'] != null)
                  Text('Result: ${r['result']}', style: GoogleFonts.poppins()),
                if (r['notes'] != null)
                  Text('Notes: ${r['notes']}', style: GoogleFonts.poppins()),
                const SizedBox(height: 8),
                Text(
                  (r['createdAt'] ?? r['date'] ?? '').toString(),
                  style: GoogleFonts.poppins(
                      fontSize: 12, color: Colors.grey[700]),
                ),
                const SizedBox(height: 8),
                if ((r['reportUrl'] ?? r['fileUrl'] ?? r['documentUrl']) !=
                    null)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () => _openUrl(
                          (r['reportUrl'] ?? r['fileUrl'] ?? r['documentUrl'])
                              .toString()),
                      icon: const Icon(Icons.open_in_new),
                      label: const Text('View'),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Widget _buildPrescriptionsList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _prescriptions.length,
      itemBuilder: (context, index) {
        final prescription = _prescriptions[index];
        return _buildPrescriptionCard(prescription);
      },
    );
  }

  Widget _buildPrescriptionCard(Map<String, dynamic> prescription) {
    final meds = (prescription['medications'] is List)
        ? List<Map<String, dynamic>>.from(prescription['medications'])
        : <Map<String, dynamic>>[];
    final firstMed = meds.isNotEmpty ? meds.first : <String, dynamic>{};
    final title = prescription['medicineName'] ??
        prescription['name'] ??
        firstMed['medicineName'] ??
        firstMed['name'] ??
        'Unknown Medicine';
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
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
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: kNursePrimary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.medication,
                  color: kNursePrimary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: kNursePrimary,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: prescription['status'] == 'Active'
                      ? Colors.green.withOpacity(0.1)
                      : Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  prescription['status'] ?? 'Unknown',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: prescription['status'] == 'Active'
                        ? Colors.green[700]
                        : Colors.orange[700],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildPrescriptionDetail(
              'Dosage',
              prescription['dosage'] ??
                  firstMed['dosage'] ??
                  firstMed['dose'] ??
                  'N/A'),
          _buildPrescriptionDetail('Frequency',
              prescription['frequency'] ?? firstMed['frequency'] ?? 'N/A'),
          _buildPrescriptionDetail('Duration',
              prescription['duration'] ?? firstMed['duration'] ?? 'N/A'),
          _buildPrescriptionDetail(
              'Instructions',
              prescription['instructions'] ??
                  firstMed['instructions'] ??
                  firstMed['notes'] ??
                  'N/A'),
          if (prescription['startDate'] != null) ...[
            const SizedBox(height: 8),
            Text(
              'Start Date: ${DateFormat('MMM d, y').format(DateTime.parse(prescription['startDate']))}',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPrescriptionDetail(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.grey[800],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
