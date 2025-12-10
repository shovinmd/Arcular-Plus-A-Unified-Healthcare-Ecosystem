import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:glassmorphism/glassmorphism.dart';
import 'package:arcular_plus/services/api_service.dart';

// Nurse assigned patients screen - matching nurse theme colors
class NurseAssignedPatientsScreen extends StatefulWidget {
  const NurseAssignedPatientsScreen({super.key});

  @override
  State<NurseAssignedPatientsScreen> createState() =>
      _NurseAssignedPatientsScreenState();
}

class _NurseAssignedPatientsScreenState
    extends State<NurseAssignedPatientsScreen> {
  List<Map<String, dynamic>> _assignedPatients = [];
  bool _isLoading = true;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  // Nurse theme colors - Updated to blue theme
  final Color kNursePrimary = const Color(0xFF3B82F6); // Blue
  final Color kNurseSecondary = const Color(0xFF60A5FA); // Light blue

  @override
  void initState() {
    super.initState();
    _loadAssignedPatients();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAssignedPatients() async {
    setState(() => _isLoading = true);
    try {
      final list = await ApiService.getNurseAssignments();
      final mapped = list.map<Map<String, dynamic>>((a) {
        DateTime? dt;
        final rawDate = a['assignmentDate'];
        if (rawDate is String) dt = DateTime.tryParse(rawDate);
        if (rawDate is DateTime) dt = rawDate;
        dt ??= DateTime.now();

        final doctorName = a['doctorName'] ??
            (a['doctorId'] is Map
                ? (a['doctorId']['fullName'] ?? '')
                : 'Doctor');
        final patientName = a['patientName'] ??
            (a['patientId'] is Map
                ? (a['patientId']['fullName'] ?? 'Patient')
                : 'Patient');
        final patientArcId = a['patientArcId'] ??
            (a['patientId'] is Map ? (a['patientId']['arcId'] ?? '') : '');
        final shift = a['shift'] ?? '';
        final status = a['status'] ?? 'assigned';

        return {
          'patientId': a['_id'] ?? a['patientId'],
          'patientName': patientName,
          'patientArcId': patientArcId,
          'doctorName': doctorName,
          'doctorId':
              a['doctorId'] is Map ? a['doctorId']['_id'] : a['doctorId'],
          'ward': a['ward'] ?? 'General Ward',
          'assignmentDate': dt,
          'assignmentTime': a['assignmentTime'] ?? '',
          'shift': shift,
          'status': status,
          'notes': a['notes'] ?? '',
          'tasks': <String>[],
        };
      }).toList();

      setState(() {
        _assignedPatients = mapped;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showErrorSnackBar('Failed to load assigned patients: $e');
    }
  }

  List<Map<String, dynamic>> get _filteredPatients {
    if (_searchQuery.isEmpty) return _assignedPatients;

    return _assignedPatients.where((patient) {
      return patient['patientName']
              .toLowerCase()
              .contains(_searchQuery.toLowerCase()) ||
          patient['patientArcId']
              .toLowerCase()
              .contains(_searchQuery.toLowerCase()) ||
          patient['doctorName']
              .toLowerCase()
              .contains(_searchQuery.toLowerCase()) ||
          patient['ward'].toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
    });
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return Colors.green;
      case 'completed':
        return Colors.grey; // Completed in grey
      case 'pending':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return Icons.check_circle;
      case 'completed':
        return Icons.done_all;
      case 'pending':
        return Icons.schedule;
      default:
        return Icons.help_outline;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red[600],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showPatientDetails(Map<String, dynamic> patient) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.person, color: kNursePrimary),
            const SizedBox(width: 8),
            Text(
              'Patient Assignment Details',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Patient Name', patient['patientName']),
              _buildDetailRow('ARC ID', patient['patientArcId']),
              _buildDetailRow('Assigned Doctor', patient['doctorName']),
              _buildDetailRow('Ward', patient['ward']),
              _buildDetailRow('Shift', patient['shift']),
              _buildDetailRow(
                  'Assignment Date', _formatDate(patient['assignmentDate'])),
              _buildDetailRow('Assignment Time', patient['assignmentTime']),
              _buildDetailRow('Status', patient['status'].toUpperCase()),
              if (patient['notes'] != null && patient['notes'].isNotEmpty)
                _buildDetailRow('Notes', patient['notes']),
              const SizedBox(height: 12),
              Text(
                'Tasks:',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 8),
              ...(patient['tasks'] as List<String>)
                  .map(
                    (task) => Padding(
                      padding: const EdgeInsets.only(left: 16, bottom: 4),
                      child: Row(
                        children: [
                          Icon(Icons.check_circle_outline,
                              size: 16, color: kNursePrimary),
                          const SizedBox(width: 8),
                          Text(
                            task,
                            style: GoogleFonts.poppins(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Close',
              style: GoogleFonts.poppins(color: kNursePrimary),
            ),
          ),
          if (patient['status'] == 'active')
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _markAsCompleted(patient);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: kNursePrimary,
                foregroundColor: Colors.white,
              ),
              child: Text(
                'Mark Complete',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              ),
            ),
        ],
      ),
    );
  }

  void _markAsCompleted(Map<String, dynamic> patient) {
    setState(() {
      patient['status'] = 'completed';
    });
    _showErrorSnackBar('Assignment marked as completed!');
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.poppins(color: Colors.grey[600]),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'My Assigned Patients',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        backgroundColor: kNursePrimary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _loadAssignedPatients,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [kNurseSecondary, kNursePrimary],
          ),
        ),
        child: Column(
          children: [
            // Header with search
            Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(Icons.people_alt, color: Colors.white, size: 28),
                      const SizedBox(width: 12),
                      Text(
                        'My Patient Assignments',
                        style: GoogleFonts.poppins(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Patients assigned to you with doctor and ward details',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Search bar
                  GlassmorphicContainer(
                    width: double.infinity,
                    height: 60,
                    borderRadius: 16,
                    blur: 20,
                    alignment: Alignment.center,
                    border: 2,
                    linearGradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withOpacity(0.1),
                        Colors.white.withOpacity(0.05),
                      ],
                    ),
                    borderGradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withOpacity(0.5),
                        Colors.white.withOpacity(0.2),
                      ],
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: _onSearchChanged,
                      style: GoogleFonts.poppins(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Search patients, doctors, or wards...',
                        hintStyle: GoogleFonts.poppins(color: Colors.white70),
                        prefixIcon: Icon(Icons.search, color: Colors.white70),
                        border: InputBorder.none,
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Patients list
            Expanded(
              child: _isLoading
                  ? Center(
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
                              Icons.medical_services,
                              size: 60,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'Loading assigned patients...',
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 16),
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
                    )
                  : _filteredPatients.isEmpty
                      ? Center(
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
                                  Icons.people_outline,
                                  size: 60,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 24),
                              Text(
                                _assignedPatients.isEmpty
                                    ? 'No patients assigned yet'
                                    : 'No patients match your search',
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _assignedPatients.isEmpty
                                    ? 'Patients will appear here when assigned'
                                    : 'Try adjusting your search terms',
                                style: GoogleFonts.poppins(
                                  color: Colors.white.withOpacity(0.8),
                                  fontSize: 16,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _filteredPatients.length,
                          itemBuilder: (context, index) {
                            final patient = _filteredPatients[index];
                            return Container(
                              margin: const EdgeInsets.only(bottom: 16),
                              child: GlassmorphicContainer(
                                width: double.infinity,
                                height: 140,
                                borderRadius: 16,
                                blur: 20,
                                alignment: Alignment.center,
                                border: 2,
                                linearGradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Colors.white.withOpacity(0.1),
                                    Colors.white.withOpacity(0.05),
                                  ],
                                ),
                                borderGradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Colors.white.withOpacity(0.5),
                                    Colors.white.withOpacity(0.2),
                                  ],
                                ),
                                child: InkWell(
                                  onTap: () => _showPatientDetails(patient),
                                  borderRadius: BorderRadius.circular(16),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        // Header row
                                        Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(12),
                                              decoration: BoxDecoration(
                                                gradient: LinearGradient(
                                                  colors: [
                                                    Colors.white
                                                        .withOpacity(0.3),
                                                    Colors.white
                                                        .withOpacity(0.1)
                                                  ],
                                                  begin: Alignment.topLeft,
                                                  end: Alignment.bottomRight,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              child: const Icon(Icons.person,
                                                  color: Colors.white,
                                                  size: 24),
                                            ),
                                            const SizedBox(width: 16),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    patient['patientName'],
                                                    style: GoogleFonts.poppins(
                                                      color: Colors.white,
                                                      fontSize: 14,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    'ARC ID: ${patient['patientArcId']}',
                                                    style: GoogleFonts.poppins(
                                                      color: Colors.white70,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 12,
                                                      vertical: 6),
                                              decoration: BoxDecoration(
                                                color: _getStatusColor(
                                                        patient['status'])
                                                    .withOpacity(0.2),
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                                border: Border.all(
                                                  color: _getStatusColor(
                                                          patient['status'])
                                                      .withOpacity(0.5),
                                                ),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    _getStatusIcon(
                                                        patient['status']),
                                                    size: 14,
                                                    color: _getStatusColor(
                                                        patient['status']),
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    patient['status']
                                                        .toUpperCase(),
                                                    style: GoogleFonts.poppins(
                                                      color: _getStatusColor(
                                                          patient['status']),
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),

                                        // Details row
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    children: [
                                                      Icon(
                                                          Icons
                                                              .medical_services,
                                                          size: 14,
                                                          color:
                                                              Colors.white70),
                                                      const SizedBox(width: 6),
                                                      Expanded(
                                                        child: Text(
                                                          'Dr: ${patient['doctorName']?.toString().replaceFirst('Dr. ', '') ?? 'Unknown'}',
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                          style: GoogleFonts
                                                              .poppins(
                                                                  color: Colors
                                                                      .white70,
                                                                  fontSize: 12),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Row(
                                                    children: [
                                                      Icon(Icons.location_on,
                                                          size: 14,
                                                          color:
                                                              Colors.white70),
                                                      const SizedBox(width: 6),
                                                      Expanded(
                                                        child: Text(
                                                          'Ward: ${patient['ward']}',
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                          style: GoogleFonts
                                                              .poppins(
                                                                  color: Colors
                                                                      .white70,
                                                                  fontSize: 12),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.end,
                                              children: [
                                                Row(
                                                  children: [
                                                    Icon(Icons.schedule,
                                                        size: 14,
                                                        color: Colors.white70),
                                                    const SizedBox(width: 6),
                                                    Expanded(
                                                      child: Text(
                                                        '${patient['shift']} Shift',
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                        style:
                                                            GoogleFonts.poppins(
                                                                color: Colors
                                                                    .white70,
                                                                fontSize: 12),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 4),
                                                Row(
                                                  children: [
                                                    Icon(Icons.access_time,
                                                        size: 14,
                                                        color: Colors.white70),
                                                    const SizedBox(width: 6),
                                                    Flexible(
                                                      child: Text(
                                                        patient[
                                                            'assignmentTime'],
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                        style:
                                                            GoogleFonts.poppins(
                                                                color: Colors
                                                                    .white70,
                                                                fontSize: 12),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
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
        ),
      ),
    );
  }
}
