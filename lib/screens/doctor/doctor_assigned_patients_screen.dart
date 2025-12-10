import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:arcular_plus/services/api_service.dart';
import 'package:arcular_plus/screens/doctor/patient_detail_tabs_screen.dart';

// Doctor assigned patients screen - matching patient card colors
class DoctorAssignedPatientsScreen extends StatefulWidget {
  const DoctorAssignedPatientsScreen({super.key});

  @override
  State<DoctorAssignedPatientsScreen> createState() =>
      _DoctorAssignedPatientsScreenState();
}

class _DoctorAssignedPatientsScreenState
    extends State<DoctorAssignedPatientsScreen> {
  // Themed colors to match the green Assigned Patients card
  static const Color _bgStart = Color(0xFF17B18A);
  static const Color _bgEnd = Color(0xFF0E8F78);
  List<Map<String, dynamic>> _assignedPatients = [];
  bool _isLoading = true;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

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
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        setState(() => _isLoading = false);
        _showErrorSnackBar('You are not signed in');
        return;
      }

      final assignments = await ApiService.getDoctorAssignments();

      final mapped = assignments.map<Map<String, dynamic>>((a) {
        DateTime? parsedDate;
        final rawDate = a['assignmentDate'];
        if (rawDate is String) {
          parsedDate = DateTime.tryParse(rawDate);
        } else if (rawDate is DateTime) {
          parsedDate = rawDate;
        }
        parsedDate ??= DateTime.now();

        return {
          'patientId':
              a['patientId'] is Map ? a['patientId']['_id'] : a['patientId'],
          'patientName': a['patientName'] ??
              (a['patientId'] is Map ? a['patientId']['fullName'] : ''),
          'patientArcId': a['patientArcId'] ??
              (a['patientId'] is Map ? a['patientId']['arcId'] : ''),
          'doctorName': a['doctorName'] ??
              (a['doctorId'] is Map ? (a['doctorId']['fullName'] ?? '') : ''),
          'doctorId':
              a['doctorId'] is Map ? a['doctorId']['_id'] : a['doctorId'],
          'nurseName': a['nurseName'] ??
              (a['nurseId'] is Map ? (a['nurseId']['fullName'] ?? '') : ''),
          'nurseId': a['nurseId'] is Map ? a['nurseId']['_id'] : a['nurseId'],
          'ward': a['ward'] ?? 'General Ward',
          'shift': a['shift'] ?? '',
          'assignmentDate': parsedDate,
          'assignmentTime': a['assignmentTime'] ?? '',
          'status': a['status'] ?? 'assigned',
          'notes': a['notes'] ?? '',
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
      final q = _searchQuery.toLowerCase();
      final pn = (patient['patientName'] ?? '').toString().toLowerCase();
      final arc = (patient['patientArcId'] ?? '').toString().toLowerCase();
      final dn = (patient['doctorName'] ?? '').toString().toLowerCase();
      final nn = (patient['nurseName'] ?? '').toString().toLowerCase();
      final ward = (patient['ward'] ?? '').toString().toLowerCase();
      return pn.contains(q) ||
          arc.contains(q) ||
          dn.contains(q) ||
          nn.contains(q) ||
          ward.contains(q);
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
        backgroundColor: const Color(0xFFF7FAF9),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        insetPadding: const EdgeInsets.all(16),
        contentTextStyle: GoogleFonts.poppins(color: const Color(0xFF5E6E6B)),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
        actionsPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        clipBehavior: Clip.antiAlias,
        scrollable: true,
        // Constrain dialog width for small screens to prevent overflow
        // ignore: sized_box_for_whitespace
        title: LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 320;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _bgEnd.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.person, color: _bgEnd, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Patient Details',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF102A27),
                        ),
                      ),
                    ),
                    if (!isNarrow)
                      _StatusChip(
                          colorGetter: _getStatusColor,
                          iconGetter: _getStatusIcon,
                          status: patient['status'])
                  ],
                ),
                if (isNarrow) ...[
                  const SizedBox(height: 8),
                  _StatusChip(
                      colorGetter: _getStatusColor,
                      iconGetter: _getStatusIcon,
                      status: patient['status'])
                ]
              ],
            );
          },
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Patient Name', patient['patientName']),
              _buildDetailRow('ARC ID', patient['patientArcId']),
              const SizedBox(height: 6),
              _buildDetailRow('Assigned Doctor', patient['doctorName'],
                  icon: Icons.local_hospital),
              _buildDetailRow('Assigned Nurse', patient['nurseName'],
                  icon: Icons.person_outline),
              _buildDetailRow('Ward', patient['ward'],
                  icon: Icons.location_on_outlined),
              const SizedBox(height: 6),
              _buildDetailRow(
                  'Assignment Date', _formatDate(patient['assignmentDate']),
                  icon: Icons.calendar_today),
              _buildDetailRow('Assignment Time', patient['assignmentTime'],
                  icon: Icons.access_time),
              if (patient['notes'] != null &&
                  patient['notes'].toString().isNotEmpty) ...[
                const Divider(height: 20),
                _buildDetailRow('Notes', patient['notes']),
              ]
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: _bgEnd,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('Close',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  void _openPatientTabs(Map<String, dynamic> patient) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PatientDetailTabsScreen(
          patientId: patient['patientId']?.toString() ?? '',
          patientName: patient['patientName']?.toString() ?? 'Patient',
          patientArcId: patient['patientArcId']?.toString() ?? '',
          assignmentId: patient['assignmentId']?.toString(),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {IconData? icon}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 6),
                ],
                Expanded(
                  child: Text(
                    '$label:',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF3D4F4C),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.poppins(color: const Color(0xFF5E6E6B)),
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Assigned Patients',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
            Text(
              '${_assignedPatients.length} patients',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.white70,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
        backgroundColor: _bgEnd,
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
            colors: [_bgStart, _bgEnd],
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
                        'My Assigned Patients',
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
                    'Patients assigned to you with nurse details',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Search bar
                  Container(
                    width: double.infinity,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: _onSearchChanged,
                      style: GoogleFonts.poppins(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Search patients, nurses, or wards...',
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
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.3),
                                  width: 1,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: InkWell(
                                onTap: () => _openPatientTabs(patient),
                                onLongPress: () => _showPatientDetails(patient),
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
                                                  Colors.white.withOpacity(0.3),
                                                  Colors.white.withOpacity(0.1)
                                                ],
                                                begin: Alignment.topLeft,
                                                end: Alignment.bottomRight,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: const Icon(Icons.person,
                                                color: Colors.white, size: 24),
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
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  'ARC ID: ${patient['patientArcId']}',
                                                  style: GoogleFonts.poppins(
                                                    color: Colors.white70,
                                                    fontSize: 13,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 12, vertical: 6),
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
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),

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
                                                    Icon(Icons.medical_services,
                                                        size: 14,
                                                        color: Colors.white70),
                                                    const SizedBox(width: 6),
                                                    Expanded(
                                                      child: Text(
                                                        'Doctor: ${patient['doctorName']}',
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                        style:
                                                            GoogleFonts.poppins(
                                                                color: Colors
                                                                    .white70,
                                                                fontSize: 13),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 4),
                                                Row(
                                                  children: [
                                                    Icon(Icons.person_outline,
                                                        size: 14,
                                                        color: Colors.white70),
                                                    const SizedBox(width: 6),
                                                    Expanded(
                                                      child: Text(
                                                        'Nurse: ${patient['nurseName']}',
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                        style:
                                                            GoogleFonts.poppins(
                                                                color: Colors
                                                                    .white70,
                                                                fontSize: 13),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 4),
                                                Row(
                                                  children: [
                                                    Icon(Icons.location_on,
                                                        size: 14,
                                                        color: Colors.white70),
                                                    const SizedBox(width: 6),
                                                    Expanded(
                                                      child: Text(
                                                        'Ward: ${patient['ward']}',
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                        style:
                                                            GoogleFonts.poppins(
                                                                color: Colors
                                                                    .white70,
                                                                fontSize: 13),
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
                                                  Icon(Icons.calendar_today,
                                                      size: 14,
                                                      color: Colors.white70),
                                                  const SizedBox(width: 6),
                                                  Flexible(
                                                    child: Text(
                                                      _formatDate(patient[
                                                          'assignmentDate']),
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style:
                                                          GoogleFonts.poppins(
                                                              color: Colors
                                                                  .white70,
                                                              fontSize: 13),
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
                                                  Expanded(
                                                    child: Text(
                                                      [
                                                        if ((patient['shift'] ??
                                                                '')
                                                            .toString()
                                                            .isNotEmpty)
                                                          '${patient['shift']} Shift',
                                                        if ((patient[
                                                                    'assignmentTime'] ??
                                                                '')
                                                            .toString()
                                                            .isNotEmpty)
                                                          patient[
                                                              'assignmentTime'],
                                                      ]
                                                          .where((e) =>
                                                              e != null &&
                                                              e
                                                                  .toString()
                                                                  .isNotEmpty)
                                                          .join('  •  '),
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style:
                                                          GoogleFonts.poppins(
                                                              color: Colors
                                                                  .white70,
                                                              fontSize: 13),
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

class _StatusChip extends StatelessWidget {
  final Color Function(String) colorGetter;
  final IconData Function(String) iconGetter;
  final String status;
  const _StatusChip({
    required this.colorGetter,
    required this.iconGetter,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    final color = colorGetter(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(iconGetter(status), size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            status.toUpperCase(),
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
