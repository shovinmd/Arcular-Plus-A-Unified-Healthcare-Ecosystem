import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:arcular_plus/screens/universal_qr_scanner_screen.dart';
import 'package:arcular_plus/services/auth_service.dart';
import 'package:arcular_plus/services/api_service.dart';
import 'package:arcular_plus/models/user_model.dart';
import 'package:arcular_plus/models/appointment_model.dart';
import 'package:arcular_plus/screens/auth/login_screen.dart';
import 'package:arcular_plus/widgets/chatarc_floating_button.dart';
import 'package:arcular_plus/widgets/shaking_bell_notification.dart';
import 'package:arcular_plus/screens/doctor/update_doctor_profile_screen.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:arcular_plus/screens/doctor/doctor_profile_screen.dart';
import 'package:arcular_plus/screens/doctor/doctor_notifications_screen.dart';
import 'package:arcular_plus/screens/doctor/doctor_prescriptions_screen.dart';
import 'package:arcular_plus/screens/doctor/doctor_appointments_screen.dart';
import 'package:arcular_plus/screens/doctor/doctor_reports_screen.dart';
import 'package:arcular_plus/screens/doctor/doctor_assigned_patients_screen.dart';
import 'package:arcular_plus/screens/doctor/doctor_schedule_screen.dart';
import 'package:glassmorphism/glassmorphism.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_animate/flutter_animate.dart';

// Updated color constants for doctor dashboard - matching patient design patterns
const Color kDoctorPrimary = Color(0xFF2196F3); // Doctor blue
const Color kDoctorSecondary = Color(0xFF64B5F6);
const Color kDoctorAccent = Color(0xFF90CAF9);
const Color kDoctorBackground = Color(0xFFF8FBFF);
const Color kDoctorSurface = Color(0xFFFFFFFF);
const Color kDoctorText = Color(0xFF1A237E);
const Color kDoctorTextSecondary = Color(0xFF546E7A);
const Color kDoctorSuccess = Color(0xFF4CAF50);
const Color kDoctorWarning = Color(0xFFFF9800);
const Color kDoctorError = Color(0xFFF44336);

class DoctorAppointmentsTab extends StatefulWidget {
  const DoctorAppointmentsTab({super.key});

  @override
  State<DoctorAppointmentsTab> createState() => _DoctorAppointmentsTabState();
}

class _DoctorAppointmentsTabState extends State<DoctorAppointmentsTab> {
  List<AppointmentModel> appointments = [];
  bool isLoading = true;
  final Map<String, UserModel?> _patientCache = {};
  final Map<String, String> _hospitalNameCache = {};

  @override
  void initState() {
    super.initState();
    _loadAppointments();
  }

  Future<void> _loadAppointments() async {
    setState(() => isLoading = true);
    try {
      // Get current doctor's ID from auth service
      final currentUser = AuthService().currentUser;
      if (currentUser != null) {
        final doctorAppointments =
            await ApiService.getDoctorAppointments(currentUser.uid);
        setState(() {
          appointments = doctorAppointments;
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() => isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load appointments: $e'),
            backgroundColor: kDoctorError,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  List<AppointmentModel> _filterAppointments(String tab) {
    if (tab == 'Upcoming') {
      return appointments.where((a) {
        final status = (a.status ?? '').toLowerCase();
        final isFuture = a.dateTime.isAfter(DateTime.now());
        return isFuture && (status == 'confirmed' || status == 'pending');
      }).toList();
    }
    if (tab == 'Completed') {
      return appointments
          .where((a) => (a.status ?? '').toLowerCase() == 'completed')
          .toList();
    }
    if (tab == 'Cancelled') {
      return appointments
          .where((a) => (a.status ?? '').toLowerCase() == 'cancelled')
          .toList();
    }
    return appointments;
  }

  Future<UserModel?> _getPatient(String uid) async {
    if (_patientCache.containsKey(uid)) return _patientCache[uid];
    try {
      final user = await ApiService.getUserInfo(uid);
      _patientCache[uid] = user;
      return user;
    } catch (_) {
      _patientCache[uid] = null;
      return null;
    }
  }

  Future<String> _getHospitalName(String? hospitalId) async {
    if (hospitalId == null || hospitalId.isEmpty) return 'Not linked';
    if (_hospitalNameCache.containsKey(hospitalId)) {
      return _hospitalNameCache[hospitalId]!;
    }
    try {
      final info = await ApiService.getUserInfo(hospitalId);
      final name = (info?.ownerName?.isNotEmpty == true)
          ? info!.ownerName!
          : (info?.fullName.isNotEmpty == true)
              ? info!.fullName
              : 'Hospital';
      _hospitalNameCache[hospitalId] = name;
      return name;
    } catch (_) {
      return 'Hospital';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [kDoctorPrimary, kDoctorSecondary],
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
                  boxShadow: [
                    BoxShadow(
                      color: Colors.white.withOpacity(0.3),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Icon(
                  Icons.medical_services,
                  size: 60,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Loading appointments...',
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
        ),
      );
    }

    if (appointments.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [kDoctorPrimary, kDoctorSecondary],
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
                  Icons.calendar_today,
                  size: 60,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'No appointments scheduled',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Your upcoming appointments will appear here',
                style: GoogleFonts.poppins(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return DefaultTabController(
      length: 4,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [kDoctorPrimary, kDoctorSecondary],
          ),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Row(
                children: [
                  Text('Manage Appointments',
                      style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700)),
                ],
              ),
            ),
            const SizedBox(height: 8),
            TabBar(
              isScrollable: true,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              indicatorColor: Colors.white,
              tabs: const [
                Tab(text: 'All'),
                Tab(text: 'Upcoming'),
                Tab(text: 'Completed'),
                Tab(text: 'Cancelled'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children:
                    ['All', 'Upcoming', 'Completed', 'Cancelled'].map((tab) {
                  final list = _filterAppointments(tab);
                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: list.length,
                    itemBuilder: (context, index) {
                      final a = list[index];
                      return FutureBuilder<List<dynamic>>(
                        future: Future.wait([
                          _getPatient(a.patientId),
                          _getHospitalName(a.hospitalId),
                        ]),
                        builder: (context, snap) {
                          final patient = (snap.data != null)
                              ? snap.data![0] as UserModel?
                              : null;
                          final hospitalName = (snap.data != null)
                              ? (snap.data![1] as String)
                              : 'Hospital';
                          final displayName =
                              patient?.fullName.isNotEmpty == true
                                  ? patient!.fullName
                                  : 'Patient';
                          final arcId = patient?.arcId ?? '-';
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
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
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
                                        borderRadius: BorderRadius.circular(12),
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
                                          Text(displayName,
                                              style: GoogleFonts.poppins(
                                                  color: Colors.white,
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold)),
                                          const SizedBox(height: 4),
                                          Text('ARC ID: $arcId',
                                              style: GoogleFonts.poppins(
                                                  color: Colors.white70,
                                                  fontSize: 13)),
                                          const SizedBox(height: 4),
                                          Text('Hospital: $hospitalName',
                                              style: GoogleFonts.poppins(
                                                  color: Colors.white70,
                                                  fontSize: 13)),
                                          const SizedBox(height: 6),
                                          Row(
                                            children: [
                                              Icon(Icons.calendar_today,
                                                  size: 14,
                                                  color: Colors.white70),
                                              const SizedBox(width: 6),
                                              Text(
                                                _formatDate(a.dateTime),
                                                style: GoogleFonts.poppins(
                                                    color: Colors.white70,
                                                    fontSize: 13),
                                              ),
                                              const SizedBox(width: 12),
                                              Icon(Icons.access_time,
                                                  size: 14,
                                                  color: Colors.white70),
                                              const SizedBox(width: 6),
                                              Text(
                                                _formatTime(a.dateTime),
                                                style: GoogleFonts.poppins(
                                                    color: Colors.white70,
                                                    fontSize: 13),
                                              ),
                                            ],
                                          ),
                                          if ((a.reason ?? '').isNotEmpty)
                                            Padding(
                                              padding:
                                                  const EdgeInsets.only(top: 6),
                                              child: Text(
                                                'Reason: ${a.reason}',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: GoogleFonts.poppins(
                                                    color: Colors.white70,
                                                    fontSize: 13),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: _getStatusColor(a.status)
                                            .withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: _getStatusColor(a.status)
                                              .withOpacity(0.5),
                                        ),
                                      ),
                                      child: Text(
                                        (a.status ?? 'Pending')
                                            .toString()
                                            .trim(),
                                        style: GoogleFonts.poppins(
                                          color: _getStatusColor(a.status),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  );
                }).toList(),
              ),
            )
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'confirmed':
        return kDoctorSuccess;
      case 'pending':
        return kDoctorWarning;
      case 'cancelled':
        return kDoctorError;
      default:
        return kDoctorWarning;
    }
  }

  String _formatDate(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
  }

  String _formatTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'confirmed':
        return Icons.check_circle;
      case 'pending':
        return Icons.schedule;
      case 'cancelled':
        return Icons.cancel;
      case 'completed':
        return Icons.done_all;
      default:
        return Icons.info;
    }
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  void _showAppointmentDetails(AppointmentModel appointment) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Appointment Details',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('Patient ID', appointment.patientId),
            _buildDetailRow('Date', _formatDateTime(appointment.dateTime)),
            _buildDetailRow('Status', appointment.status),
            _buildDetailRow('Doctor', appointment.doctorName),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Close',
              style: GoogleFonts.poppins(color: kDoctorPrimary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                color: kDoctorText,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.poppins(color: kDoctorTextSecondary),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmAppointment(AppointmentModel appointment) {
    // TODO: Implement appointment confirmation
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Appointment confirmed!'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _rescheduleAppointment(AppointmentModel appointment) {
    // TODO: Implement appointment rescheduling
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Reschedule feature coming soon!'),
        backgroundColor: Colors.orange,
      ),
    );
  }
}

class DoctorPatientsTab extends StatefulWidget {
  const DoctorPatientsTab({super.key});
  @override
  State<DoctorPatientsTab> createState() => _DoctorPatientsTabState();
}

class _DoctorPatientsTabState extends State<DoctorPatientsTab> {
  final TextEditingController _searchController = TextEditingController();
  String? _scannedId;
  UserModel? _scannedPatient;
  bool _isLoading = false;

  Future<void> _scanQr() async {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const UniversalQRScannerScreen()),
    );
  }

  Future<void> _loadPatientInfo(String qrId) async {
    setState(() => _isLoading = true);
    try {
      final patient = await ApiService.getPatientByQrId(qrId);
      setState(() {
        _scannedPatient = patient;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load patient info: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search Section
          GlassmorphicContainer(
            width: double.infinity,
            height: 70,
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
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      labelText: 'Search by QR Health ID',
                      labelStyle:
                          GoogleFonts.poppins(color: kDoctorTextSecondary),
                      prefixIcon: Icon(Icons.qr_code, color: kDoctorPrimary),
                      border: InputBorder.none,
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    onSubmitted: (value) {
                      if (value.isNotEmpty) {
                        _loadPatientInfo(value);
                      }
                    },
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.qr_code_scanner,
                      size: 32, color: kDoctorPrimary),
                  tooltip: 'Scan QR',
                  onPressed: _scanQr,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          if (_scannedId != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Scanned ID: $_scannedId',
                    style: GoogleFonts.poppins(
                      color: Colors.green,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          if (_isLoading) ...[
            Center(
              child: Column(
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(kDoctorPrimary),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Loading patient information...',
                    style: GoogleFonts.poppins(
                      color: kDoctorTextSecondary,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          if (_scannedPatient != null) ...[
            Text(
              'Patient Information',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: kDoctorText,
              ),
            ),
            const SizedBox(height: 12),
            GlassmorphicContainer(
              width: double.infinity,
              height: 300,
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
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [kDoctorPrimary, kDoctorSecondary],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            _scannedPatient!.fullName
                                .split(' ')
                                .map((n) => n[0])
                                .join(''),
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _scannedPatient!.fullName,
                                style: GoogleFonts.poppins(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: kDoctorText,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Age: ${_calculateAge(_scannedPatient!.dateOfBirth)} years',
                                style: GoogleFonts.poppins(
                                  color: kDoctorTextSecondary,
                                  fontSize: 14,
                                ),
                              ),
                              if (_scannedPatient!.bloodGroup != null)
                                Text(
                                  'Blood Group: ${_scannedPatient!.bloodGroup}',
                                  style: GoogleFonts.poppins(
                                    color: kDoctorTextSecondary,
                                    fontSize: 14,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const Divider(color: kDoctorTextSecondary, height: 1),
                    const SizedBox(height: 16),
                    _buildPatientDetailRow('Email', _scannedPatient!.email),
                    _buildPatientDetailRow(
                        'Phone', _scannedPatient!.mobileNumber),
                    if (_scannedPatient!.height != null)
                      _buildPatientDetailRow(
                          'Height', '${_scannedPatient!.height} cm'),
                    if (_scannedPatient!.weight != null)
                      _buildPatientDetailRow(
                          'Weight', '${_scannedPatient!.weight} kg'),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              // TODO: Navigate to patient history
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Patient history coming soon!'),
                                  backgroundColor: Colors.orange,
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: kDoctorPrimary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            icon: Icon(Icons.history),
                            label: Text(
                              'View History',
                              style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              // TODO: Navigate to prescriptions
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Prescriptions coming soon!'),
                                  backgroundColor: Colors.orange,
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: kDoctorSecondary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            icon: Icon(Icons.medical_services),
                            label: Text(
                              'Prescriptions',
                              style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0),
          ],
        ],
      ),
    );
  }

  Widget _buildPatientDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                color: kDoctorText,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.poppins(
                color: kDoctorTextSecondary,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  int _calculateAge(DateTime dateOfBirth) {
    final now = DateTime.now();
    int age = now.year - dateOfBirth.year;
    if (now.month < dateOfBirth.month ||
        (now.month == dateOfBirth.month && now.day < dateOfBirth.day)) {
      age--;
    }
    return age;
  }
}

class DoctorPrescriptionsTab extends StatefulWidget {
  const DoctorPrescriptionsTab({super.key});
  @override
  State<DoctorPrescriptionsTab> createState() => _DoctorPrescriptionsTabState();
}

class _DoctorPrescriptionsTabState extends State<DoctorPrescriptionsTab> {
  File? _pickedFile;
  String? _fileName;
  final TextEditingController _prescriptionController = TextEditingController();

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.any);
    if (result != null && result.files.single.path != null) {
      setState(() {
        _pickedFile = File(result.files.single.path!);
        _fileName = result.files.single.name;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Write Prescription',
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: kDoctorText,
            ),
          ),
          const SizedBox(height: 20),

          // Prescription Input Section
          GlassmorphicContainer(
            width: double.infinity,
            height: 200,
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
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Prescription Details',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: kDoctorText,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: TextField(
                      controller: _prescriptionController,
                      maxLines: null,
                      expands: true,
                      decoration: InputDecoration(
                        hintText: 'Enter prescription details...',
                        hintStyle:
                            GoogleFonts.poppins(color: kDoctorTextSecondary),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                              color: kDoctorPrimary.withOpacity(0.3)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: kDoctorPrimary),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // File Upload Section
          GlassmorphicContainer(
            width: double.infinity,
            height: 120,
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
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  ElevatedButton.icon(
                    onPressed: _pickFile,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kDoctorPrimary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.upload_file),
                    label: Text(
                      'Upload Prescription File',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                    ),
                  ),
                  if (_fileName != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: kDoctorAccent.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border:
                            Border.all(color: kDoctorAccent.withOpacity(0.3)),
                      ),
                      child: Text(
                        'Selected: $_fileName',
                        style: GoogleFonts.poppins(
                          color: kDoctorPrimary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          if (_pickedFile != null) ...[
            const SizedBox(height: 16),
            GlassmorphicContainer(
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
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text(
                      'File Preview',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: kDoctorText,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_fileName!.endsWith('.png') ||
                        _fileName!.endsWith('.jpg') ||
                        _fileName!.endsWith('.jpeg'))
                      Image.file(_pickedFile!, height: 80),
                    if (_fileName!.endsWith('.pdf'))
                      Icon(Icons.picture_as_pdf,
                          size: 48, color: kDoctorPrimary),
                  ],
                ),
              ),
            ),
          ],

          const SizedBox(height: 24),

          Text(
            'Uploaded Prescriptions',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: kDoctorText,
            ),
          ),
          const SizedBox(height: 16),

          GlassmorphicContainer(
            width: double.infinity,
            height: 80,
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
            child: ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: kDoctorPrimary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.medical_services, color: kDoctorPrimary),
              ),
              title: Text(
                'Prescription for John Doe',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  color: kDoctorText,
                ),
              ),
              subtitle: Text(
                '2024-06-10',
                style: GoogleFonts.poppins(color: kDoctorTextSecondary),
              ),
              trailing: Icon(Icons.visibility, color: kDoctorPrimary),
            ),
          ),
        ],
      ),
    );
  }
}

class DoctorReportsTab extends StatefulWidget {
  const DoctorReportsTab({super.key});
  @override
  State<DoctorReportsTab> createState() => _DoctorReportsTabState();
}

class _DoctorReportsTabState extends State<DoctorReportsTab> {
  File? _pickedFile;
  String? _fileName;

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.any);
    if (result != null && result.files.single.path != null) {
      setState(() {
        _pickedFile = File(result.files.single.path!);
        _fileName = result.files.single.name;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Upload Patient Report',
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: kDoctorText,
            ),
          ),
          const SizedBox(height: 20),

          // File Upload Section
          GlassmorphicContainer(
            width: double.infinity,
            height: 120,
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
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  ElevatedButton.icon(
                    onPressed: _pickFile,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kDoctorPrimary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.upload_file),
                    label: Text(
                      'Pick File',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                    ),
                  ),
                  if (_fileName != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: kDoctorAccent.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border:
                            Border.all(color: kDoctorAccent.withOpacity(0.3)),
                      ),
                      child: Text(
                        'Selected: $_fileName',
                        style: GoogleFonts.poppins(
                          color: kDoctorPrimary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          if (_pickedFile != null) ...[
            const SizedBox(height: 16),
            GlassmorphicContainer(
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
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text(
                      'File Preview',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: kDoctorText,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_fileName!.endsWith('.png') ||
                        _fileName!.endsWith('.jpg') ||
                        _fileName!.endsWith('.jpeg'))
                      Image.file(_pickedFile!, height: 80),
                    if (_fileName!.endsWith('.pdf'))
                      Icon(Icons.picture_as_pdf,
                          size: 48, color: kDoctorPrimary),
                  ],
                ),
              ),
            ),
          ],

          const SizedBox(height: 24),

          Text(
            'Uploaded Reports',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: kDoctorText,
            ),
          ),
          const SizedBox(height: 16),

          GlassmorphicContainer(
            width: double.infinity,
            height: 80,
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
            child: ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: kDoctorSecondary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.description, color: kDoctorSecondary),
              ),
              title: Text(
                'Report for John Doe',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  color: kDoctorText,
                ),
              ),
              subtitle: Text(
                '2024-06-10',
                style: GoogleFonts.poppins(color: kDoctorTextSecondary),
              ),
              trailing: Icon(Icons.visibility, color: kDoctorPrimary),
            ),
          ),
        ],
      ),
    );
  }
}

class DoctorAvailabilityTab extends StatelessWidget {
  const DoctorAvailabilityTab({super.key});

  @override
  Widget build(BuildContext context) {
    final TextEditingController _dateController = TextEditingController();
    final TextEditingController _timeController = TextEditingController();
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Manage Availability',
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: kDoctorText,
            ),
          ),
          const SizedBox(height: 20),

          // Add Slot Section
          GlassmorphicContainer(
            width: double.infinity,
            height: 120,
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
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Add Available Slot',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: kDoctorText,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _dateController,
                          decoration: InputDecoration(
                            labelText: 'Date',
                            labelStyle: GoogleFonts.poppins(
                                color: kDoctorTextSecondary),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                  color: kDoctorPrimary.withOpacity(0.3)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: kDoctorPrimary),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _timeController,
                          decoration: InputDecoration(
                            labelText: 'Time',
                            labelStyle: GoogleFonts.poppins(
                                color: kDoctorTextSecondary),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                  color: kDoctorPrimary.withOpacity(0.3)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: kDoctorPrimary),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: () {},
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kDoctorPrimary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Add',
                          style:
                              GoogleFonts.poppins(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          Text(
            'Available Slots',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: kDoctorText,
            ),
          ),
          const SizedBox(height: 16),

          GlassmorphicContainer(
            width: double.infinity,
            height: 80,
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
            child: ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: kDoctorAccent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.schedule, color: kDoctorAccent),
              ),
              title: Text(
                '2024-06-12',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  color: kDoctorText,
                ),
              ),
              subtitle: Text(
                '10:00 AM - 12:00 PM',
                style: GoogleFonts.poppins(color: kDoctorTextSecondary),
              ),
              trailing: Icon(Icons.delete_outline, color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }
}

class DoctorProfileTab extends StatefulWidget {
  const DoctorProfileTab({super.key});

  @override
  State<DoctorProfileTab> createState() => _DoctorProfileTabState();
}

class _DoctorProfileTabState extends State<DoctorProfileTab> {
  @override
  Widget build(BuildContext context) {
    // Navigate to the dedicated profile screen
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final currentUser = AuthService().currentUser;
      if (currentUser != null) {
        final doctorModel = await ApiService.getUserInfo(currentUser.uid);
        if (doctorModel != null && mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => DoctorProfileScreen(doctor: doctorModel)),
          );
        }
      }
    });

    // Return a loading screen while navigating
    return Scaffold(
      backgroundColor: kDoctorBackground,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(kDoctorPrimary),
            ),
            const SizedBox(height: 16),
            Text(
              'Loading profile...',
              style: GoogleFonts.poppins(
                fontSize: 16,
                color: kDoctorTextSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DashboardDoctor extends StatefulWidget {
  const DashboardDoctor({super.key});

  @override
  State<DashboardDoctor> createState() => _DashboardDoctorState();
}

class _DashboardDoctorState extends State<DashboardDoctor> {
  int _selectedIndex = 0;
  UserModel? _doctor;
  bool _isApproved = false;
  String _approvalStatus = 'pending';
  int _appointmentsCount = 0;
  int _patientsCount = 0;
  Timer? _nameRefreshTimer;

  @override
  void initState() {
    super.initState();
    _loadCachedApproval();
    _loadDoctorData();
    _nameRefreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _refreshDoctorName();
    });
  }

  Future<void> _loadDoctorData() async {
    try {
      final currentUser = AuthService().currentUser;
      if (currentUser == null) return;
      final info = await ApiService.getUserInfo(currentUser.uid);
      if (!mounted) return;
      setState(() {
        _doctor = info;
        _isApproved = info?.isApproved ?? false;
        _approvalStatus = info?.approvalStatus ?? 'pending';
      });
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('doctor_is_approved', _isApproved);
        await prefs.setString('doctor_approval_status', _approvalStatus);
      } catch (_) {}

      // Load counts after loading doctor data
      await _loadCounts();
    } catch (_) {
      // Keep defaults on failure
    }
  }

  Future<void> _loadCounts() async {
    try {
      final currentUser = AuthService().currentUser;
      if (currentUser == null) return;

      // Load confirmed/pending/scheduled/approved counts directly from backend per status
      final statuses = ['confirmed', 'pending', 'scheduled', 'approved'];
      final results = await Future.wait(statuses.map(
        (s) => ApiService.getDoctorAppointments(currentUser.uid, status: s),
      ));
      final Map<String, AppointmentModel> mergedByKey = {};
      for (final list in results) {
        for (final a in list) {
          final key = (a.appointmentId != null && a.appointmentId!.isNotEmpty)
              ? a.appointmentId!
              : a.id;
          mergedByKey[key] = a;
        }
      }
      final confirmedAppointments = mergedByKey.values.toList();

      // Load unique patients count from direct doctor appointments (no hospital merge)
      final allDirect = await ApiService.getDoctorAppointments(currentUser.uid);
      final Set<String> uniquePatients = {};
      for (final apt in allDirect) {
        if (apt.patientId != null && apt.patientId.isNotEmpty) {
          uniquePatients.add(apt.patientId);
        }
      }

      if (mounted) {
        setState(() {
          _appointmentsCount = confirmedAppointments.length;
          _patientsCount = uniquePatients
              .length; // Reverted to general patients count from appointments
        });
      }
    } catch (e) {
      print('❌ Error loading counts: $e');
    }
  }

  Future<void> _refreshDoctorName() async {
    try {
      final currentUser = AuthService().currentUser;
      if (currentUser == null) return;
      final info = await ApiService.getUserInfo(currentUser.uid);
      if (!mounted) return;
      if (info != null && info.fullName.isNotEmpty) {
        setState(() {
          // Update only the name if we already have a model
          if (_doctor != null) {
            _doctor = _doctor!.copyWith(fullName: info.fullName);
          } else {
            _doctor = info;
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _refreshDashboard() async {
    try {
      await _loadDoctorData();
      await _refreshDoctorName();
    } catch (e) {
      print('❌ Error refreshing dashboard: $e');
    }
  }

  Future<void> _loadCachedApproval() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedApproved = prefs.getBool('doctor_is_approved');
      final cachedStatus = prefs.getString('doctor_approval_status');
      if (cachedApproved != null || cachedStatus != null) {
        if (!mounted) return;
        setState(() {
          _isApproved = cachedApproved ?? _isApproved;
          _approvalStatus = cachedStatus ?? _approvalStatus;
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: kDoctorBackground,
        appBarTheme: AppBarTheme(
          backgroundColor: kDoctorPrimary,
          foregroundColor: Colors.white,
          titleTextStyle: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          selectedItemColor: kDoctorPrimary,
          unselectedItemColor: kDoctorTextSecondary,
          type: BottomNavigationBarType.fixed,
        ),
      ),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Doctor Dashboard'),
          actions: [
            ShakingBellNotification(
              userType: 'doctor',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const DoctorNotificationsScreen(),
                  ),
                );
              },
              iconColor: Colors.white,
              iconSize: 24,
            ),
            PopupMenuButton<String>(
              onSelected: (value) async {
                if (value == 'profile') {
                  // Navigate to doctor profile screen
                  final currentUser = AuthService().currentUser;
                  UserModel? profileUser = _doctor;
                  if (profileUser == null && currentUser != null) {
                    profileUser = await ApiService.getUserInfo(currentUser.uid);
                  }
                  if (!mounted) return;
                  if (profileUser != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            DoctorProfileScreen(doctor: profileUser!),
                      ),
                    );
                  }
                } else if (value == 'logout') {
                  _showLogoutDialog();
                }
              },
              icon: const Icon(Icons.more_vert, color: Colors.white),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'profile',
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [kDoctorPrimary, kDoctorSecondary],
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
                        Text('Profile',
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            )),
                      ],
                    ),
                  ),
                ),
                PopupMenuItem(
                  value: 'logout',
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFE57373), Color(0xFFEF5350)],
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
                        Text('Logout',
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            )),
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
            const ChatArcFloatingButton(userType: 'doctor'),
          ],
        ),
        // Removed BottomNavigationBar since it only had 1 item and wasn't being used properly
      ),
    );
  }

  Widget _buildBody() {
    return _buildHomeScreen();
  }

  Widget _buildHomeScreen() {
    return RefreshIndicator(
      onRefresh: _refreshDashboard,
      color: kDoctorPrimary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildWelcomeStatsCard(),
            const SizedBox(height: 24),
            _buildQuickActionsGrid(),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeStatsCard() {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [kDoctorPrimary, kDoctorSecondary],
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
                // Circular wrapper with extra padding like hospital welcome card
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.22),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withOpacity(0.35)),
                  ),
                  child: CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.white.withOpacity(0.28),
                    backgroundImage:
                        (_doctor?.profileImageUrl?.isNotEmpty ?? false)
                            ? NetworkImage(_doctor!.profileImageUrl!)
                            : null,
                    child: (_doctor?.profileImageUrl?.isEmpty ?? true)
                        ? const Icon(Icons.person,
                            color: Colors.white, size: 30)
                        : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _doctor?.fullName.isNotEmpty == true
                            ? 'Welcome, ' + _doctor!.fullName.trim() + '!'
                            : 'Welcome, Doctor!',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'Here’s your dashboard overview.',
                        style: GoogleFonts.poppins(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Refresh',
                  onPressed: () async {
                    await _refreshDoctorName();
                    await _loadCounts();
                  },
                  icon: const Icon(Icons.refresh, color: Colors.white70),
                )
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                    child:
                        _buildStatChip('Appointments', Icons.calendar_today)),
                const SizedBox(width: 12),
                Expanded(
                    child:
                        _buildStatChip('Patients', Icons.people_alt_rounded)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatChip(String label, IconData icon) {
    int count = 0;
    if (label == 'Appointments') {
      count = _appointmentsCount;
    } else if (label == 'Patients') {
      count = _patientsCount;
    } else if (label == 'Reports') {
      count = 0; // Reports count not implemented yet
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.18),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.30)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.white, size: 24),
          const SizedBox(height: 8),
          Text(
            count.toString(),
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 20,
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              style: GoogleFonts.poppins(
                color: Colors.white.withOpacity(0.95),
                fontWeight: FontWeight.w500,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionsGrid() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      children: [
        _buildActionTile(
          title: 'Appointments',
          icon: Icons.calendar_today,
          colors: [Colors.blue[400]!, Colors.blue[600]!],
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const DoctorAppointmentsScreen(),
            ),
          ),
        ),
        _buildActionTile(
          title: 'Assigned Patients',
          icon: Icons.people_alt,
          colors: [Colors.teal[400]!, Colors.teal[600]!],
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const DoctorAssignedPatientsScreen(),
            ),
          ),
        ),
        _buildActionTile(
          title: 'Prescriptions',
          icon: Icons.medical_services,
          colors: [Colors.indigo[300]!, Colors.indigo[500]!],
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const DoctorPrescriptionsScreen(),
            ),
          ),
        ),
        _buildActionTile(
          title: 'Reports',
          icon: Icons.description,
          colors: [Colors.purple[300]!, Colors.purple[500]!],
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const DoctorReportsScreen(),
            ),
          ),
        ),
        _buildActionTile(
          title: 'Availability',
          icon: Icons.schedule,
          colors: [Colors.orange[300]!, Colors.orange[600]!],
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const DoctorScheduleScreen(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionTile({
    required String title,
    required IconData icon,
    required List<Color> colors,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
              colors: colors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: colors.first.withOpacity(0.25),
              blurRadius: 10,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: Colors.white, size: 28),
              Text(
                title,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
                Color(0xFF2196F3),
                Color(0xFF64B5F6)
              ], // Doctor blue gradient
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF2196F3).withOpacity(0.3),
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
                            foregroundColor: const Color(0xFF2196F3),
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
                              color: const Color(0xFF2196F3),
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
}
