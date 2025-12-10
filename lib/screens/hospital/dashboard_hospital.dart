import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:arcular_plus/services/api_service.dart';
import 'package:arcular_plus/models/user_model.dart';
import 'package:arcular_plus/models/appointment_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';
import 'package:arcular_plus/screens/auth/login_screen.dart';
import 'package:arcular_plus/screens/hospital/hospital_profile_screen.dart';
import 'package:arcular_plus/screens/auth/approval_pending_screen.dart';
import 'package:arcular_plus/screens/hospital/notification_screen.dart';
import 'package:arcular_plus/screens/hospital/appointment_management_screen.dart';
import 'package:arcular_plus/screens/hospital/manage_lab_screen.dart';
import 'package:arcular_plus/screens/hospital/manage_pharmacy_screen.dart';
import 'package:arcular_plus/screens/hospital/nurse_management_screen.dart';
import 'package:arcular_plus/screens/hospital/hospital_patient_records_screen.dart';
import 'package:arcular_plus/screens/hospital/sos_analytics_screen.dart';
import 'package:arcular_plus/services/sos_alert_service.dart';
import 'package:arcular_plus/services/realtime_sos_service.dart';
import 'package:arcular_plus/widgets/chatarc_floating_button.dart';

const String baseUrl = 'https://arcular-plus-backend.onrender.com';

// Utility function to get doctor specializations
String getDoctorSpecializations(UserModel doctor) {
  // Get all specializations from the doctor
  List<String> allSpecializations = [];

  // Add primary specialization if exists
  if (doctor.specialization != null && doctor.specialization!.isNotEmpty) {
    allSpecializations.add(doctor.specialization!);
  }

  // Add multiple specializations if exists
  if (doctor.specializations != null && doctor.specializations!.isNotEmpty) {
    for (String spec in doctor.specializations!) {
      if (spec.isNotEmpty && !allSpecializations.contains(spec)) {
        allSpecializations.add(spec);
      }
    }
  }

  // Return comma-separated specializations or default
  if (allSpecializations.isNotEmpty) {
    return allSpecializations.join(', ');
  } else {
    return 'General Medicine';
  }
}

// Dialog to show doctor appointments
class _DoctorAppointmentsDialog extends StatelessWidget {
  final UserModel doctor;
  final List<AppointmentModel> appointments;

  const _DoctorAppointmentsDialog({
    required this.doctor,
    required this.appointments,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.green[600]!, Colors.green[400]!],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      '${doctor.fullName} • Appointments',
                      style: GoogleFonts.poppins(
                          color: Colors.white, fontWeight: FontWeight.w600),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 420,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: appointments.isEmpty
                    ? Center(
                        child: Text('No appointments found',
                            style: GoogleFonts.poppins()),
                      )
                    : ListView.builder(
                        itemCount: appointments.length,
                        itemBuilder: (context, index) {
                          final apt = appointments[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          apt.patientName ?? 'Unknown Patient',
                                          style: GoogleFonts.poppins(
                                              fontWeight: FontWeight.w700),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.green[50],
                                          borderRadius:
                                              BorderRadius.circular(20),
                                        ),
                                        child: Text(
                                          apt.status,
                                          style: GoogleFonts.poppins(
                                              fontSize: 12,
                                              color: Colors.green[800]),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    DateFormat('MMM dd, yyyy • hh:mm a')
                                        .format(apt.dateTime),
                                    style: GoogleFonts.poppins(
                                        fontSize: 12, color: Colors.grey[700]),
                                  ),
                                  if ((apt.department ?? '').isNotEmpty)
                                    Text('Dept: ${apt.department}',
                                        style:
                                            GoogleFonts.poppins(fontSize: 12)),
                                  if ((apt.patientPhone ?? '').isNotEmpty)
                                    Text('Phone: ${apt.patientPhone}',
                                        style:
                                            GoogleFonts.poppins(fontSize: 12)),
                                  if ((apt.reason ?? '').isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text('Reason: ${apt.reason}',
                                        style: GoogleFonts.poppins(
                                            fontSize: 12,
                                            color: Colors.grey[600]),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Close',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Dialog to show all hospital appointments
class _AppointmentManagementDialog extends StatefulWidget {
  @override
  State<_AppointmentManagementDialog> createState() =>
      _AppointmentManagementDialogState();
}

class _AppointmentManagementDialogState
    extends State<_AppointmentManagementDialog> {
  bool _loading = true;
  List<AppointmentModel> _appointments = [];

  @override
  void initState() {
    super.initState();
    _loadAppointments();
  }

  Future<void> _loadAppointments() async {
    try {
      if (mounted) {
        setState(() => _loading = true);
      }
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        if (mounted) {
          setState(() => _loading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('User not authenticated')),
          );
        }
        return;
      }

      final hospitalMongoId = await ApiService.getHospitalMongoId(uid);
      if (hospitalMongoId == null) {
        if (mounted) {
          setState(() => _loading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Hospital not found')),
          );
        }
        return;
      }

      final appointments =
          await ApiService.getHospitalAppointments(hospitalMongoId);
      if (mounted) {
        setState(() {
          _appointments = appointments;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load appointments: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Hospital Appointments', style: GoogleFonts.poppins()),
      content: SizedBox(
        width: double.maxFinite,
        height: 500,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _appointments.isEmpty
                ? const Center(child: Text('No appointments found'))
                : RefreshIndicator(
                    onRefresh: _loadAppointments,
                    child: ListView.builder(
                      itemCount: _appointments.length,
                      itemBuilder: (context, index) {
                        final apt = _appointments[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            title: Text(apt.patientName ?? 'Unknown Patient',
                                style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w600)),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Doctor: ${apt.doctorName}',
                                    style: GoogleFonts.poppins(fontSize: 12)),
                                Text(
                                    DateFormat('MMM dd, yyyy • hh:mm a')
                                        .format(apt.dateTime),
                                    style: GoogleFonts.poppins(fontSize: 12)),
                                if ((apt.department ?? '').isNotEmpty)
                                  Text('Dept: ${apt.department}',
                                      style: GoogleFonts.poppins(fontSize: 12)),
                                if ((apt.reason ?? '').isNotEmpty)
                                  Text('Reason: ${apt.reason}',
                                      style: GoogleFonts.poppins(fontSize: 12)),
                                Text('Status: ${apt.status}',
                                    style: GoogleFonts.poppins(fontSize: 12)),
                                if ((apt.patientPhone ?? '').isNotEmpty)
                                  Text('Phone: ${apt.patientPhone}',
                                      style: GoogleFonts.poppins(fontSize: 12)),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Close', style: GoogleFonts.poppins()),
        ),
      ],
    );
  }
}

class HospitalDashboardScreen extends StatefulWidget {
  const HospitalDashboardScreen({super.key});

  @override
  State<HospitalDashboardScreen> createState() =>
      _HospitalDashboardScreenState();
}

class _ManageDoctorsScreen extends StatefulWidget {
  const _ManageDoctorsScreen();

  @override
  State<_ManageDoctorsScreen> createState() => _ManageDoctorsScreenState();
}

class _ManageDoctorsScreenState extends State<_ManageDoctorsScreen> {
  bool _loading = true;
  List<UserModel> _doctors = [];
  List<UserModel> _filteredDoctors = [];
  Map<String, int> _doctorToAppointmentCount = {};
  List<AppointmentModel> _allAppointments = [];
  final _arcIdController = TextEditingController();
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _arcIdController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      if (mounted) {
        setState(() => _loading = true);
      }
      final hospitalMongoId = await ApiService.getHospitalMongoId(
          FirebaseAuth.instance.currentUser!.uid);
      if (hospitalMongoId == null) {
        if (mounted) {
          setState(() => _loading = false);
        }
        return;
      }
      final doctors = await ApiService.getAffiliatedDoctors(hospitalMongoId);
      // Fetch appointments once and count per doctor
      final hospitalAppointments =
          await ApiService.getHospitalAppointments(hospitalMongoId);

      // Filter appointments to only show those from affiliated doctors
      final affiliatedDoctorUids = doctors.map((d) => d.uid).toSet();
      final affiliatedAppointments = hospitalAppointments.where((apt) {
        return affiliatedDoctorUids.contains(apt.doctorId.trim());
      }).toList();

      // Build per-doctor appointment counts from filtered appointments
      final Map<String, int> counts = {};
      for (final apt in affiliatedAppointments) {
        for (final d in doctors) {
          final matchesById = (apt.doctorId.trim() == d.uid.trim());
          final matchesByName = apt.doctorName.trim().toLowerCase() ==
              d.fullName.trim().toLowerCase();
          if (matchesById || matchesByName) {
            counts[d.uid] = (counts[d.uid] ?? 0) + 1;
            break;
          }
        }
      }
      if (mounted) {
        setState(() {
          _doctors = doctors;
          _filteredDoctors = doctors;
          _doctorToAppointmentCount = counts;
          _allAppointments =
              affiliatedAppointments; // Use filtered appointments
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to load doctors: $e')));
      }
    }
  }

  void _filterDoctors(String query) {
    if (mounted) {
      setState(() {
        if (query.isEmpty) {
          _filteredDoctors = _doctors;
        } else {
          _filteredDoctors = _doctors.where((doctor) {
            // Search in doctor name
            bool nameMatch =
                doctor.fullName.toLowerCase().contains(query.toLowerCase());

            // Search in primary specialization
            bool specializationMatch = (doctor.specialization ?? '')
                .toLowerCase()
                .contains(query.toLowerCase());

            // Search in multiple specializations
            bool specializationsMatch = false;
            if (doctor.specializations != null) {
              specializationsMatch = doctor.specializations!.any(
                  (spec) => spec.toLowerCase().contains(query.toLowerCase()));
            }

            return nameMatch || specializationMatch || specializationsMatch;
          }).toList();
        }
      });
    }
  }

  Future<void> _associate() async {
    final arcId = _arcIdController.text.trim();
    if (arcId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter ARC ID')),
      );
      return;
    }

    try {
      await ApiService.associateDoctorByArcId(arcId);
      _arcIdController.clear();
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('Doctor associated successfully!'),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text('Failed to associate doctor: $e')),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _viewDoctorAppointments(UserModel doctor) {
    // Show appointment details in a dialog instead of separate screen
    showDialog(
      context: context,
      builder: (context) => _DoctorAppointmentsDialog(
        doctor: doctor,
        appointments: _getDoctorAppointments(doctor.uid),
      ),
    );
  }

  Future<void> _removeDoctorAssociation(UserModel doctor) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Remove Doctor',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        content: Text(
          'Are you sure you want to remove ${doctor.fullName} from this hospital? This action cannot be undone.',
          style: GoogleFonts.poppins(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(color: Colors.grey[600]),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text(
              'Remove',
              style: GoogleFonts.poppins(),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ApiService.removeDoctorAssociation(doctor.uid);
        await _load(); // Refresh the list
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 8),
                  Text('${doctor.fullName} removed successfully!'),
                ],
              ),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.error, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(child: Text('Failed to remove doctor: $e')),
                ],
              ),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  List<AppointmentModel> _getDoctorAppointments(String doctorUid) {
    return _allAppointments.where((apt) {
      final matchesById = (apt.doctorId.trim() == doctorUid.trim());
      final doctor = _doctors.firstWhere((d) => d.uid == doctorUid,
          orElse: () => UserModel(
                uid: '',
                fullName: '',
                email: '',
                mobileNumber: '',
                gender: '',
                dateOfBirth: DateTime.now(),
                address: '',
                pincode: '',
                city: '',
                state: '',
                type: '',
                createdAt: DateTime.now(),
              ));
      final matchesByName = apt.doctorName.trim().toLowerCase() ==
          doctor.fullName.trim().toLowerCase();
      return matchesById || matchesByName;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          'Manage Doctors',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: kHospitalGreen,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _load,
            icon: const Icon(Icons.refresh, color: Colors.white),
          ),
        ],
      ),
      body: DefaultTabController(
        length: 2,
        child: Column(
          children: [
            // Add Doctor Section
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    kHospitalGreen.withOpacity(0.1),
                    kHospitalGreen.withOpacity(0.05)
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: kHospitalGreen.withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.person_add, color: kHospitalGreen, size: 24),
                      const SizedBox(width: 8),
                      Text(
                        'Add Doctor',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: kPrimaryText,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _arcIdController,
                          decoration: InputDecoration(
                            labelText: 'Doctor ARC ID (e.g., DOC12345678)',
                            hintText: 'Enter doctor\'s ARC ID',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            prefixIcon: const Icon(Icons.badge),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: _associate,
                        icon: const Icon(Icons.add),
                        label: const Text('Add'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kHospitalGreen,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Search Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _searchController,
                onChanged: _filterDoctors,
                decoration: InputDecoration(
                  hintText: 'Search doctors by name or specialization...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Section tabs under search
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: TabBar(
                  labelColor: kHospitalGreen,
                  unselectedLabelColor: Colors.grey[500],
                  indicatorColor: kHospitalGreen,
                  tabs: const [
                    Tab(text: 'List'),
                    Tab(text: 'Ratings'),
                  ],
                ),
              ),
            ),

            // Tab Views
            Expanded(
              child: TabBarView(
                children: [
                  // 1) List
                  _loading
                      ? const Center(child: CircularProgressIndicator())
                      : (_filteredDoctors.isEmpty
                          ? _buildEmptyState()
                          : ListView.builder(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              itemCount: _filteredDoctors.length,
                              itemBuilder: (context, index) {
                                final doctor = _filteredDoctors[index];
                                final appointmentCount =
                                    _doctorToAppointmentCount[doctor.uid] ?? 0;
                                return _buildDoctorCard(
                                    doctor, appointmentCount);
                              },
                            )),

                  // 2) Ratings aggregated by doctor
                  _buildDoctorRatingsAggregate(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDoctorRatingsAggregate() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: _filteredDoctors.length,
      itemBuilder: (context, index) {
        final d = _filteredDoctors[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: const Icon(Icons.star, color: Colors.amber),
            title: Text(d.fullName, style: GoogleFonts.poppins()),
            subtitle: FutureBuilder<List<Map<String, dynamic>>>(
              future: ApiService.getProviderRatings(
                  providerId: d.uid, providerType: 'doctor'),
              builder: (context, snap) {
                final list = snap.data ?? [];
                if (list.isEmpty) return const Text('No ratings');
                final avg = list
                        .map((e) => (e['rating'] ?? 0) as num)
                        .fold<num>(0, (s, v) => s + v) /
                    list.length;
                return Text(
                  '${avg.toStringAsFixed(1)} / 5  •  ${list.length} ratings',
                  style: GoogleFonts.poppins(fontSize: 12),
                );
              },
            ),
            trailing: IconButton(
              icon: const Icon(Icons.remove_red_eye),
              onPressed: () => _viewDoctorAppointments(d),
            ),
          ),
        );
      },
    );
  }

  // Details tab removed per requirement; aggregate view no longer used.

  // Details KV row helper no longer used after removing the Details tab

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.medical_services_outlined,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No doctors found',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add doctors using their ARC ID to get started',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildDoctorCard(UserModel doctor, int appointmentCount) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            // Doctor Avatar
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [kHospitalGreen.withOpacity(0.8), kHospitalGreen],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(30),
              ),
              child: const Icon(
                Icons.person,
                color: Colors.white,
                size: 30,
              ),
            ),

            const SizedBox(width: 16),

            // Doctor Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    doctor.fullName,
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: kPrimaryText,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    getDoctorSpecializations(doctor),
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      color: kSecondaryText,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      // ARC ID Badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: kHospitalGreen.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: kHospitalGreen.withOpacity(0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.badge,
                              size: 14,
                              color: kHospitalGreen,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${doctor.arcId ?? doctor.uid}',
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: kHospitalGreen,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Appointments Badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: kHospitalGreen.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: kHospitalGreen.withOpacity(0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.calendar_today,
                              size: 14,
                              color: kHospitalGreen,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '$appointmentCount',
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: kHospitalGreen,
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

            // Action Buttons
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // View Appointments Button
                InkWell(
                  onTap: () => _viewDoctorAppointments(doctor),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: kHospitalGreen.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.visibility,
                      color: kHospitalGreen,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Remove Button
                InkWell(
                  onTap: () => _removeDoctorAssociation(doctor),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.remove_circle_outline,
                      color: Colors.red,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Doctor Appointments Screen
class _DoctorAppointmentsScreen extends StatefulWidget {
  final UserModel doctor;
  final int appointmentCount;

  const _DoctorAppointmentsScreen({
    required this.doctor,
    required this.appointmentCount,
  });

  @override
  State<_DoctorAppointmentsScreen> createState() =>
      _DoctorAppointmentsScreenState();
}

class _DoctorAppointmentsScreenState extends State<_DoctorAppointmentsScreen>
    with SingleTickerProviderStateMixin {
  List<AppointmentModel> _appointments = [];
  bool _loading = true;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadAppointments();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAppointments() async {
    try {
      setState(() => _loading = true);
      final allAppointments = await ApiService.getHospitalAppointments(
          FirebaseAuth.instance.currentUser!.uid);
      setState(() {
        _appointments = allAppointments
            .where((apt) => apt.doctorId == widget.doctor.uid)
            .toList();
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load appointments: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          'Dr. ${widget.doctor.fullName}',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: kHospitalGreen,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _loadAppointments,
            icon: const Icon(Icons.refresh, color: Colors.white),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Appointments'),
            Tab(text: 'Details'),
            Tab(text: 'Ratings'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: Appointments
          Column(
            children: [
              // Doctor Info Card
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      kHospitalGreen.withOpacity(0.1),
                      kHospitalGreen.withOpacity(0.05)
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: kHospitalGreen.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            kHospitalGreen.withOpacity(0.8),
                            kHospitalGreen
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: const Icon(
                        Icons.person,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Dr. ${widget.doctor.fullName}',
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: kPrimaryText,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            getDoctorSpecializations(widget.doctor),
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              color: kSecondaryText,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: kHospitalGreen.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: kHospitalGreen.withOpacity(0.3)),
                            ),
                            child: Text(
                              '${widget.appointmentCount} Total Appointments',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: kHospitalGreen,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Appointments List
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _appointments.isEmpty
                        ? _buildEmptyState()
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: _appointments.length,
                            itemBuilder: (context, index) {
                              final appointment = _appointments[index];
                              return _buildAppointmentCard(appointment);
                            },
                          ),
              ),
            ],
          ),

          // Tab 2: Details (Doctor meta, schedule, completion summary)
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Meta
                Text('Doctor Meta',
                    style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87)),
                const SizedBox(height: 8),
                _kv('ARC ID', widget.doctor.arcId ?? widget.doctor.uid),
                _kv('Total Appointments', '${_appointments.length}'),
                const SizedBox(height: 16),
                // Schedule
                Text('Schedule',
                    style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87)),
                const SizedBox(height: 8),
                Builder(builder: (context) {
                  final upcoming = _appointments
                      .where((a) => a.dateTime.isAfter(DateTime.now()))
                      .toList()
                    ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
                  final nextSlot = upcoming.isNotEmpty ? upcoming.first : null;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _kv(
                        'Next Slot',
                        nextSlot != null
                            ? DateFormat('MMM dd, yyyy • hh:mm a')
                                .format(nextSlot.dateTime)
                            : 'Not scheduled',
                      ),
                      if (nextSlot?.hospitalName != null)
                        _kv('Hospital', nextSlot!.hospitalName!),
                    ],
                  );
                }),
                const SizedBox(height: 16),
                // Completion
                Text('Completion Details',
                    style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87)),
                const SizedBox(height: 8),
                Builder(builder: (context) {
                  final completed = _appointments
                      .where((a) => a.status.toLowerCase() == 'completed')
                      .toList()
                    ..sort((a, b) => b.dateTime.compareTo(a.dateTime));
                  final last = completed.isNotEmpty ? completed.first : null;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _kv(
                        'Last Completed',
                        last != null
                            ? DateFormat('MMM dd, yyyy • hh:mm a')
                                .format(last.dateTime)
                            : 'No completed appointments',
                      ),
                      _kv(
                          'Consultation Summary',
                          (last?.notes?.isNotEmpty ?? false)
                              ? last!.notes!
                              : '—'),
                    ],
                  );
                }),
              ],
            ),
          ),

          // Tab 3: Ratings (doctor)
          FutureBuilder<List<Map<String, dynamic>>>(
            future: ApiService.getProviderRatings(
              providerId: widget.doctor.uid,
              providerType: 'doctor',
            ),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final ratings = snapshot.data ?? [];
              if (ratings.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.star_outline,
                          size: 72, color: Colors.grey[400]),
                      const SizedBox(height: 12),
                      Text('No ratings yet',
                          style: GoogleFonts.poppins(
                              color: Colors.grey[600], fontSize: 16)),
                    ],
                  ),
                );
              }

              final avg = ratings
                      .map((e) => (e['rating'] ?? 0) as num)
                      .fold<num>(0, (s, v) => s + v) /
                  ratings.length;

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: ratings.length + 1,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: const Icon(Icons.star,
                            color: Colors.amber, size: 28),
                        title: Text('${avg.toStringAsFixed(1)} / 5',
                            style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w700)),
                        subtitle: Text('${ratings.length} ratings',
                            style: GoogleFonts.poppins(fontSize: 12)),
                      ),
                    );
                  }
                  final r = ratings[index - 1];
                  final int stars = (r['rating'] ?? 0) as int;
                  final String review = (r['review'] ?? '').toString();
                  final String when = (r['createdAt'] ?? '').toString();
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: List.generate(5, (i) {
                              return Icon(
                                i < stars ? Icons.star : Icons.star_border,
                                color: Colors.amber,
                                size: 18,
                              );
                            }),
                          ),
                          if (review.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(review, style: GoogleFonts.poppins()),
                          ],
                          const SizedBox(height: 6),
                          Text(when,
                              style: GoogleFonts.poppins(
                                  color: Colors.grey[600], fontSize: 12)),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _kv(String key, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(key,
                style: GoogleFonts.poppins(
                    color: Colors.grey[700], fontWeight: FontWeight.w500)),
          ),
          Expanded(
            child:
                Text(value, style: GoogleFonts.poppins(color: Colors.black87)),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.calendar_today,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No appointments found',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'This doctor has no appointments yet',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppointmentCard(AppointmentModel appointment) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  appointment.patientName ?? 'Unknown Patient',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: kPrimaryText,
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getStatusColor(appointment.status).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border:
                        Border.all(color: _getStatusColor(appointment.status)),
                  ),
                  child: Text(
                    appointment.status.toUpperCase(),
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: _getStatusColor(appointment.status),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              DateFormat('MMM dd, yyyy • hh:mm a').format(appointment.dateTime),
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: kSecondaryText,
              ),
            ),
            if (appointment.reason != null &&
                appointment.reason!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                appointment.reason!,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: kSecondaryText,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'confirmed':
        return Colors.blue;
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}

class _HospitalDashboardScreenState extends State<HospitalDashboardScreen> {
  int _selectedIndex = 0;
  UserModel? _hospital;
  bool _loading = true;
  // late ApprovalStatusService _approvalService;

  // Real-time stats
  int _workingStaffCount = 0;
  int _appointmentsCount = 0;
  int _patientsCount = 0;
  bool _isApproved = false;

  // Google-style gradient colors for hospital
  final List<Color> _hospitalGradient = [
    const Color(0xFF4CAF50), // Primary green
    const Color(0xFF66BB6A), // Light green
    const Color(0xFF81C784), // Lighter green
  ];

  @override
  void initState() {
    super.initState();
    // Load cached approval instantly, then fetch latest
    _loadCachedApprovalStatus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkApprovalStatus();
    });
  }

  Future<void> _loadCachedApprovalStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedApproved = prefs.getBool('hospital_is_approved');
      if (cachedApproved != null) {
        if (!mounted) return;
        setState(() {
          _isApproved = cachedApproved;
        });
      }
    } catch (_) {}
  }

  Future<void> _checkApprovalStatus() async {
    try {
      print('🔍 Checking hospital approval status...');

      // Get current user's UID
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('❌ No Firebase user found');
        return;
      }

      // Check approval status from backend
      final approvalStatus =
          await ApiService.getHospitalApprovalStatus(user.uid);

      if (approvalStatus != null) {
        final isApproved = approvalStatus['isApproved'] ?? false;
        final status = approvalStatus['approvalStatus'] ?? 'pending';

        print('📊 Approval status: $status, isApproved: $isApproved');

        if (isApproved && status == 'approved') {
          print('✅ Hospital approved, loading dashboard');
          _loadHospitalData();
        } else {
          print('⏳ Hospital not approved, showing approval pending screen');
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => const ApprovalPendingScreen(),
              ),
            );
          }
        }
      } else {
        print('❌ Could not fetch approval status, showing approval pending');
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => const ApprovalPendingScreen(),
            ),
          );
        }
      }
    } catch (e) {
      print('❌ Error checking approval status: $e');
      // On error, show approval pending screen
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const ApprovalPendingScreen(),
          ),
        );
      }
    }
  }

  Future<void> _loadHospitalData() async {
    try {
      // Load hospital profile
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        return;
      }
      final hospitalData = await ApiService.getHospitalProfile(user.uid);

      if (hospitalData != null) {
        // Set hospital but keep loading until stats are ready
        setState(() {
          _hospital = hospitalData;
        });

        // Load real-time stats BEFORE showing dashboard
        await _loadRealTimeStats();

        // Now allow dashboard to render
        if (mounted) {
          setState(() {
            _loading = false;
          });
        }
      } else {
        if (mounted) setState(() => _loading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadRealTimeStats() async {
    try {
      if (_hospital?.uid == null || _hospital!.uid.isEmpty) {
        return;
      }

      // Resolve Mongo _id for affiliation queries
      final mongoId = await ApiService.getHospitalMongoId(_hospital!.uid);
      if (mongoId == null || mongoId.isEmpty) {
        return;
      }
      final staffCount = await ApiService.getWorkingStaffCount(mongoId);

      // Load appointments using Mongo _id (not UID)
      final appointmentsData =
          await ApiService.getHospitalAppointments(mongoId);

      // Filter appointments to only show those from affiliated doctors
      final affiliatedDoctors = await ApiService.getAffiliatedDoctors(mongoId);
      final affiliatedDoctorUids = affiliatedDoctors.map((d) => d.uid).toSet();
      final affiliatedAppointments = appointmentsData.where((apt) {
        return affiliatedDoctorUids.contains(apt.doctorId.trim());
      }).toList();

      // final today = DateTime.now();
      final activeStatuses = {
        'pending',
        'scheduled',
        'confirmed',
        'rescheduled'
      };
      final activeAppointmentsCount =
          affiliatedAppointments.where((appointment) {
        final isActive =
            activeStatuses.contains(appointment.status.toLowerCase());
        return isActive;
      }).length;
      // Compute today's active appointments (unused currently but kept for future UI metrics)
      /* final todayAppointments = affiliatedAppointments.where((appointment) {
        final appointmentDate = appointment.dateTime;
        final isToday = appointmentDate.year == today.year &&
            appointmentDate.month == today.month &&
            appointmentDate.day == today.day;
        final isActive =
            activeStatuses.contains(appointment.status.toLowerCase());
        return isToday && isActive;
      }).length; */

      // Patients count: distinct patients with active appointments
      final Set<String> distinctPatients = {};
      for (final a in affiliatedAppointments) {
        final isActive = activeStatuses.contains(a.status.toLowerCase());
        final pid = (a.patientId).toString();
        if (isActive && pid.isNotEmpty) distinctPatients.add(pid);
      }
      final patientsCount = distinctPatients.length;

      // Check approval status
      final approvalStatus =
          await ApiService.getHospitalApprovalStatus(_hospital!.uid);
      final isApproved = approvalStatus?['isApproved'] ?? false;

      setState(() {
        _workingStaffCount = staffCount;
        _appointmentsCount = activeAppointmentsCount;
        _patientsCount = patientsCount;
        _isApproved = isApproved;
      });
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('hospital_is_approved', _isApproved);
      } catch (_) {}
    } catch (e) {
      setState(() {
        _workingStaffCount = 0;
        _appointmentsCount = 0;
        _patientsCount = 0;
        _isApproved = false;
      });
    }
  }

  void _onTabTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _handleMenuSelection(String value) {
    switch (value) {
      case 'profile':
        if (_hospital != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => HospitalProfileScreen(hospital: _hospital!),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Hospital data not loaded. Please refresh.',
                style: GoogleFonts.poppins(),
              ),
              backgroundColor: Colors.orange,
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
                Color(0xFF4CAF50),
                Color(0xFF81C784)
              ], // Hospital green gradient
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF4CAF50).withOpacity(0.3),
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
                            await FirebaseAuth.instance.signOut();
                            if (mounted) {
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                    builder: (context) => const LoginScreen()),
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            foregroundColor: const Color(0xFF4CAF50),
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
                              color: const Color(0xFF4CAF50),
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
    if (_loading) {
      return Scaffold(
        body: FutureBuilder<SharedPreferences>(
          future: SharedPreferences.getInstance(),
          builder: (context, snapshot) {
            return Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: _hospitalGradient,
                ),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Hospital icon with glassmorphism and zoom animation
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
                            child: const Icon(
                              Icons.local_hospital,
                              size: 120,
                              color: Colors.white,
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
                    const SizedBox(
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
      backgroundColor: const Color(0xFFF5F6FA), // light gray
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(
          'Hospital Dashboard',
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
                Color(0xFF4CAF50),
                Color(0xFF81C784)
              ], // Hospital green gradient
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
          ),
        ),
        actions: [
          // Notifications Icon
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => NotificationScreen(
                    hospitalId: _hospital?.uid ?? '',
                  ),
                ),
              );
            },
            icon: const Icon(Icons.notifications, color: Colors.white),
            tooltip: 'Notifications',
          ),
          // Profile Menu
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
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFF4CAF50),
                        Color(0xFF81C784)
                      ], // Hospital green gradient
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
          IndexedStack(
            index: _selectedIndex,
            children: [
              _buildOverviewTab(),
              _buildSOSTab(),
            ],
          ),
          const ChatArcFloatingButton(userType: 'hospital'),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        onTap: (index) {
          _onTabTapped(index);
        },
        selectedItemColor: const Color(0xFF4CAF50), // Hospital green color
        unselectedItemColor: Colors.grey,
        backgroundColor: Colors.white,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Overview',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.emergency, color: Colors.red),
            label: 'SOS',
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewTab() {
    return RefreshIndicator(
      onRefresh: _loadHospitalData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome Section with Stats
            _buildWelcomeSection(),
            const SizedBox(height: 16),

            // Hospital Status Card
            _buildHospitalStatusCard(),
            const SizedBox(height: 24),

            // Quick Actions Grid
            _buildQuickActionsGrid(),
            const SizedBox(height: 24),

            // Hospital Overview Section
            _buildHospitalStatsSection(),
            const SizedBox(height: 24),
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
              Color(0xFF4CAF50),
              Color(0xFF81C784)
            ], // Hospital green gradient
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
                  backgroundImage: (_hospital?.profileImageUrl != null &&
                          _hospital!.profileImageUrl!.isNotEmpty)
                      ? NetworkImage(_hospital!.profileImageUrl!)
                      : null,
                  child: (_hospital?.profileImageUrl == null ||
                          _hospital!.profileImageUrl!.isEmpty)
                      ? const Icon(Icons.local_hospital,
                          color: Colors.white, size: 30)
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
                        _hospital?.hospitalName ?? 'Loading...',
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
                  onPressed: _loadHospitalData,
                  icon:
                      const Icon(Icons.refresh, color: Colors.white, size: 24),
                  tooltip: 'Refresh Dashboard',
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Stats Row
            Row(
              children: [
                _buildStatCard('Working Staff', _workingStaffCount.toString(),
                    Icons.medical_services),
                const SizedBox(width: 12),
                _buildStatCard('Appointments', _appointmentsCount.toString(),
                    Icons.calendar_today),
                const SizedBox(width: 12),
                _buildStatCard(
                    'Patients', _patientsCount.toString(), Icons.people),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Manage your hospital operations efficiently',
              style: GoogleFonts.poppins(
                fontSize: 16,
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(height: 4),
            Text(
              value,
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              label,
              style: GoogleFonts.poppins(
                color: Colors.white.withOpacity(0.8),
                fontSize: 11,
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

  Widget _buildHospitalStatusCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: _isApproved
                ? [Colors.green[400]!, Colors.green[600]!]
                : [Colors.orange[400]!, Colors.orange[600]!],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              _isApproved ? Icons.check_circle : Icons.pending,
              color: Colors.white,
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _isApproved ? 'Hospital Approved' : 'Approval Pending',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    _isApproved
                        ? 'Your hospital is fully functional and operational'
                        : 'Your hospital registration is under review',
                    style: GoogleFonts.poppins(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            if (_isApproved)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'ACTIVE',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHospitalStatsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Hospital Overview',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF4CAF50), // Hospital green color
          ),
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
                  Color(0xFF4CAF50),
                  Color(0xFF81C784)
                ], // Hospital green gradient
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildStatRow('Hospital Type',
                      _hospital?.hospitalType ?? 'Private', Colors.white),
                  const Divider(color: Colors.white30),
                  _buildStatRow(
                      'Total Beds',
                      _hospital?.numberOfBeds?.toString() ?? '50',
                      Colors.white),
                  const Divider(color: Colors.white30),
                  _buildStatRow(
                      'Departments',
                      _hospital?.departments?.length.toString() ?? '5',
                      Colors.white),
                  const Divider(color: Colors.white30),
                  _buildStatRow(
                      'Location',
                      '${_hospital?.city ?? 'Mumbai'}, ${_hospital?.state ?? 'Maharashtra'}',
                      Colors.white),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatRow(String label, String value, Color color) {
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

  Widget _buildQuickActionsGrid() {
    final List<Widget> actions = [
      _buildActionCard(
        'Appointments',
        Icons.calendar_today,
        [Colors.blue[400]!, Colors.blue[600]!],
        () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const AppointmentManagementScreen(),
          ),
        ).then((_) {
          if (mounted) {
            _loadRealTimeStats();
          }
        }),
      ),
      _buildActionCard(
        'Manage Doctors',
        Icons.medical_services,
        [Colors.green[400]!, Colors.green[600]!],
        () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const _ManageDoctorsScreen(),
            ),
          );
        },
      ),
      _buildActionCard(
        'Manage Nurses',
        Icons.medical_services_outlined,
        [Colors.purple[400]!, Colors.purple[600]!],
        () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => NurseManagementScreen(
                hospitalId: _hospital?.uid ?? '',
                hospitalName: _hospital?.hospitalName ??
                    _hospital?.fullName ??
                    'Hospital',
              ),
            ),
          );
        },
      ),
      _buildActionCard(
        'Manage Lab',
        Icons.science,
        [Colors.orange[400]!, Colors.orange[600]!],
        () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ManageLabScreen()),
          );
        },
      ),
      _buildActionCard(
        'Manage Pharmacy',
        Icons.local_pharmacy,
        [
          const Color(0xFFE65100),
          const Color(0xFFF57C00)
        ], // Orange pharmacy theme
        () {
          Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => const ManagePharmacyScreen()),
          );
        },
      ),
      _buildActionCard(
        'Patient Records',
        Icons.folder,
        [Colors.indigo[400]!, Colors.indigo[600]!],
        () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const HospitalPatientRecordsScreen(),
            ),
          );
        },
      ),
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.2,
      children: actions,
    );
  }

  Widget _buildActionCard(
      String title, IconData icon, List<Color> colors, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: colors,
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
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSOSTab() {
    if (_hospital?.uid == null || _hospital!.uid.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Loading hospital data... SOS will be available shortly.',
            style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return _SOSTab(
      hospitalId: _hospital!.uid,
      hospital: _hospital,
      onNavigateToSOS: () {
        setState(() {
          _selectedIndex = 1; // Navigate to SOS tab
        });
      },
    );
  }
}

class _SOSTab extends StatefulWidget {
  final String hospitalId;
  final UserModel? hospital;
  final VoidCallback onNavigateToSOS;
  const _SOSTab(
      {required this.hospitalId,
      required this.hospital,
      required this.onNavigateToSOS});

  @override
  State<_SOSTab> createState() => _SOSTabState();
}

class _SOSTabState extends State<_SOSTab> with TickerProviderStateMixin {
  List<Map<String, dynamic>> _sosRequests = [];
  List<Map<String, dynamic>> _acceptedRequests = [];
  List<Map<String, dynamic>> _cancelledRequests = [];
  bool _loading = true;
  bool _realtimeEnabled = false;
  late TabController _tabController;

  // Alarm system
  bool _hasNewSOS = false;
  late AnimationController _alarmController;
  late Animation<double> _alarmAnimation;
  Timer? _vibrationTimer; // Add vibration timer for continuous vibration

  // SOS Alert Service
  final SOSAlertService _sosAlertService = SOSAlertService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    // Initialize alarm animation
    _alarmController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _alarmAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _alarmController,
      curve: Curves.easeInOut,
    ));

    // Initialize SOS alert service
    _sosAlertService.initialize();

    _loadSOSRequests();
    _startRealtimeMonitoring();
  }

  @override
  void dispose() {
    // Clean up vibration timer
    _vibrationTimer?.cancel();
    _vibrationTimer = null;

    _tabController.dispose();
    _alarmController.dispose();
    RealtimeSOSService.instance.stopRealtimeMonitoring();
    _sosAlertService.dispose(); // Dispose SOS alert service
    super.dispose();
  }

  Future<void> _startRealtimeMonitoring() async {
    try {
      await RealtimeSOSService.instance.startRealtimeMonitoring(
        userType: 'hospital',
        onSOSReceived: (request) {
          if (mounted) {
            setState(() {
              _sosRequests.insert(0, request);
              _hasNewSOS = true;
            });

            // Start alarm animation
            _alarmController.repeat(reverse: true);

            // Play alarm sound and vibrate device
            _playAlarmSound();

            // Show full-screen emergency dialog
            _showEmergencyDialog(request);
          }
        },
        onStatusUpdated: (request) {
          if (mounted) {
            _loadSOSRequests(); // Refresh the list
          }
        },
      );

      setState(() {
        _realtimeEnabled = true;
      });

      print('✅ Real-time SOS monitoring started for hospital');
    } catch (e) {
      print('❌ Error starting real-time SOS monitoring: $e');
    }
  }

  Future<void> _loadSOSRequests() async {
    setState(() => _loading = true);
    try {
      // Load all SOS requests for this hospital
      final allRequests =
          await ApiService.getHospitalSOSRequests(widget.hospitalId);

      setState(() {
        _sosRequests = allRequests
            .where((req) => req['hospitalStatus'] == 'notified')
            .toList();
        _acceptedRequests = allRequests
            .where((req) =>
                req['hospitalStatus'] == 'accepted' ||
                req['hospitalStatus'] == 'admitted' ||
                req['hospitalStatus'] == 'discharged')
            .toList();
        _cancelledRequests = allRequests
            .where((req) => req['hospitalStatus'] == 'cancelled')
            .toList();
        _loading = false;
      });

      // Debug logging
      print('🏥 SOS Requests loaded:');
      print('📊 Pending: ${_sosRequests.length}');
      print('📊 Accepted/Admitted: ${_acceptedRequests.length}');
      print('📊 Cancelled: ${_cancelledRequests.length}');

      // Debug each accepted request
      for (var req in _acceptedRequests) {
        print(
            '🏥 Accepted Request: ${req['patientName']} - Status: ${req['hospitalStatus']}');
      }
    } catch (e) {
      print('❌ Error loading SOS requests: $e');
      setState(() {
        _sosRequests = [];
        _acceptedRequests = [];
        _cancelledRequests = [];
        _loading = false;
      });
    }
  }

  // Play alarm sound and vibrate device using SOS Alert Service
  void _playAlarmSound() {
    try {
      print('🔊 Starting SOS alert system (sound + vibration)');

      // Use the new SOS alert service for both mobile and web
      _sosAlertService.startSOSAlert();
    } catch (e) {
      print('❌ Error starting SOS alert: $e');
    }
  }

  // Stop alarm using SOS Alert Service
  void _stopAlarm() {
    setState(() {
      _hasNewSOS = false;
    });

    // Stop vibration timer
    _vibrationTimer?.cancel();
    _vibrationTimer = null;

    // Stop alarm animation
    _alarmController.stop();

    // Stop SOS alert service (sound + vibration)
    _sosAlertService.stopSOSAlert();

    print('🔕 Alarm stopped - vibration and animation disabled');
  }

  // Show full-screen emergency dialog
  void _showEmergencyDialog(Map<String, dynamic> request) {
    if (!mounted) return;

    // Debug logging for emergency dialog data
    print('🚨 Emergency Dialog Data:');
    print('  - Request keys: ${request.keys.toList()}');
    print('  - SOS Request ID: ${request['sosRequestId']}');
    print('  - Patient Info: ${request['patientInfo']}');
    print('  - Emergency Details: ${request['emergencyDetails']}');

    // Extract SOS request data for debugging
    final sosRequest = request['sosRequestId'] ?? request;
    print('  - SOS Request keys: ${sosRequest.keys.toList()}');
    print('  - Patient Name: ${sosRequest['patientName']}');
    print('  - Patient Phone: ${sosRequest['patientPhone']}');
    print('  - Address: ${sosRequest['address']}');
    print('  - Location: ${sosRequest['location']}');

    showDialog(
      context: context,
      barrierDismissible: false, // Cannot dismiss by tapping outside
      builder: (context) => WillPopScope(
        onWillPop: () async => false, // Prevent back button dismissal
        child: Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            width: double.infinity,
            height: double.infinity,
            child: Stack(
              children: [
                // Content - Clean white emergency box only
                Center(
                  child: Container(
                    margin: const EdgeInsets.all(20),
                    padding: const EdgeInsets.all(30),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Emergency Icon
                        AnimatedBuilder(
                          animation: _alarmAnimation,
                          builder: (context, child) {
                            return Transform.scale(
                              scale: 1.0 + (_alarmAnimation.value * 0.3),
                              child: Icon(
                                Icons.emergency,
                                size: 80,
                                color: Colors.red[600],
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 20),

                        // Emergency Title
                        Text(
                          '🚨 EMERGENCY ALERT 🚨',
                          style: GoogleFonts.poppins(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.red[600],
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),

                        // Patient Info with enhanced location details
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.red[50],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.red[200]!),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Patient: ${_getPatientNameFromRequest(request)}',
                                style: GoogleFonts.poppins(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red[700],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Phone: ${_getPatientPhoneFromRequest(request)}',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  color: Colors.red[600],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Location: ${_getLocationAddressFromRequest(request)}',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  color: Colors.red[600],
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Coordinates: ${_getCoordinatesFromRequest(request)}',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: Colors.red[500],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Emergency: ${request['emergencyDetails']?['emergencyType'] ?? 'Medical'}',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.red[700],
                                ),
                              ),
                              if (request['emergencyDetails']?['description'] !=
                                      null &&
                                  request['emergencyDetails']['description']
                                      .toString()
                                      .isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  'Description: ${request['emergencyDetails']['description']}',
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    color: Colors.red[600],
                                  ),
                                ),
                              ],
                              const SizedBox(height: 12),
                              // Google Maps Link
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    _openGoogleMaps(request);
                                  },
                                  icon: const Icon(Icons.map, size: 16),
                                  label: const Text('Open in Google Maps'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue[600],
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Action Buttons
                        Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () {
                                      print('🔍 VIEW REQUEST button pressed');
                                      Navigator.of(context).pop();
                                      print(
                                          '🔍 Dialog dismissed, navigating to SOS tab');
                                      widget.onNavigateToSOS();
                                      _stopAlarm();
                                      print('🔍 Navigation completed');
                                    },
                                    icon:
                                        const Icon(Icons.visibility, size: 20),
                                    label: const Text('VIEW REQUEST'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green[600],
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 16),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () {
                                      Navigator.of(context).pop();
                                      _stopAlarm();
                                    },
                                    icon: const Icon(Icons.close, size: 20),
                                    label: const Text('DISMISS'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.grey[600],
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 16),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Urgency Message
                        Text(
                          'IMMEDIATE ATTENTION REQUIRED!',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.red[600],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Helper method to format datetime with proper timezone
  String _formatDateTime(dynamic dateTimeString) {
    try {
      if (dateTimeString == null) return 'Unknown time';

      // Parse the datetime string
      final dateTime = DateTime.parse(dateTimeString.toString());

      // Format as YYYY-MM-DD HH:MM:SS (exact time without timezone conversion)
      return '${dateTime.year.toString().padLeft(4, '0')}-'
          '${dateTime.month.toString().padLeft(2, '0')}-'
          '${dateTime.day.toString().padLeft(2, '0')} '
          '${dateTime.hour.toString().padLeft(2, '0')}:'
          '${dateTime.minute.toString().padLeft(2, '0')}:'
          '${dateTime.second.toString().padLeft(2, '0')}';
    } catch (e) {
      print('❌ Error formatting datetime: $e');
      return 'Unknown time';
    }
  }

  // Helper method to extract patient name from request
  String _getPatientNameFromRequest(Map<String, dynamic> request) {
    try {
      // Extract SOS request data (it's nested in sosRequestId when populated)
      final sosRequest = request['sosRequestId'] ?? request;

      // Try multiple ways to get patient name
      return sosRequest['patientName'] ??
          request['patientInfo']?['patientName'] ??
          'Unknown';
    } catch (e) {
      print('❌ Error extracting patient name: $e');
      return 'Unknown';
    }
  }

  // Helper method to extract patient phone from request
  String _getPatientPhoneFromRequest(Map<String, dynamic> request) {
    try {
      // Extract SOS request data (it's nested in sosRequestId when populated)
      final sosRequest = request['sosRequestId'] ?? request;

      // Try multiple ways to get patient phone
      return sosRequest['patientPhone'] ??
          request['patientInfo']?['patientPhone'] ??
          'Not provided';
    } catch (e) {
      print('❌ Error extracting patient phone: $e');
      return 'Not provided';
    }
  }

  // Helper method to extract location address from request
  String _getLocationAddressFromRequest(Map<String, dynamic> request) {
    try {
      // Extract SOS request data (it's nested in sosRequestId when populated)
      final sosRequest = request['sosRequestId'] ?? request;

      // Try multiple ways to get location address
      return sosRequest['address'] ??
          sosRequest['location']?['address'] ??
          request['emergencyDetails']?['location']?['address'] ??
          'Unknown location';
    } catch (e) {
      print('❌ Error extracting location address: $e');
      return 'Unknown location';
    }
  }

  // Helper method to extract coordinates from request
  String _getCoordinatesFromRequest(Map<String, dynamic> request) {
    try {
      // Extract SOS request data (it's nested in sosRequestId when populated)
      final sosRequest = request['sosRequestId'] ?? request;

      // Try multiple ways to get location data
      dynamic location = sosRequest['location'] ??
          sosRequest['emergencyDetails']?['location'] ??
          request['location'] ??
          request['emergencyDetails']?['location'];

      if (location != null) {
        double? lat, lng;

        // Handle different location data formats
        if (location is Map<String, dynamic>) {
          // Format 1: { latitude: number, longitude: number }
          lat = location['latitude']?.toDouble();
          lng = location['longitude']?.toDouble();

          // Format 2: { coordinates: [lng, lat] } (MongoDB format)
          if (lat == null && lng == null && location['coordinates'] != null) {
            final coords = location['coordinates'];
            if (coords is List && coords.length >= 2) {
              lng = coords[0]?.toDouble();
              lat = coords[1]?.toDouble();
            }
          }
        }

        if (lat != null && lng != null && lat != 0 && lng != 0) {
          return '${lat.toStringAsFixed(8)}, ${lng.toStringAsFixed(8)}';
        }
      }

      return 'N/A, N/A';
    } catch (e) {
      print('❌ Error extracting coordinates: $e');
      return 'N/A, N/A';
    }
  }

  // Open Google Maps with patient location
  Future<void> _openGoogleMaps(Map<String, dynamic> request) async {
    try {
      // Extract SOS request data (it's nested in sosRequestId when populated)
      final sosRequest = request['sosRequestId'] ?? request;

      // Try multiple ways to get location data
      dynamic location = sosRequest['location'] ??
          sosRequest['emergencyDetails']?['location'] ??
          request['location'];

      print('🗺️ Opening Google Maps:');
      print('🔍 Request keys: ${request.keys.toList()}');
      print('🔍 SOS Request keys: ${sosRequest.keys.toList()}');
      print('🔍 Location data: $location');

      if (location != null) {
        double? lat, lng;

        // Handle different location data formats
        if (location is Map<String, dynamic>) {
          // Format 1: { latitude: number, longitude: number }
          lat = location['latitude']?.toDouble();
          lng = location['longitude']?.toDouble();

          // Format 2: { coordinates: [lng, lat] } (MongoDB format)
          if (lat == null && lng == null && location['coordinates'] != null) {
            final coords = location['coordinates'];
            if (coords is List && coords.length >= 2) {
              lng = coords[0]?.toDouble();
              lat = coords[1]?.toDouble();
            }
          }
        }

        final address = sosRequest['address'] ?? location['address'] ?? '';

        print('📍 Extracted coordinates: lat=$lat, lng=$lng');
        print('📍 Address: $address');

        if (lat != null && lng != null && lat != 0 && lng != 0) {
          // Use maximum precision coordinates for Google Maps (15 decimal places)
          final url =
              'https://www.google.com/maps/search/?api=1&query=${lat.toStringAsFixed(15)},${lng.toStringAsFixed(15)}';

          print('🗺️ Opening Google Maps with maximum precision coordinates:');
          print('📍 Latitude: ${lat.toStringAsFixed(15)}');
          print('📍 Longitude: ${lng.toStringAsFixed(15)}');
          print('📍 Address: $address');
          print('🔗 URL: $url');

          // Try to open the URL
          if (await canLaunchUrl(Uri.parse(url))) {
            await launchUrl(Uri.parse(url),
                mode: LaunchMode.externalApplication);
            print('✅ Google Maps opened successfully');
          } else {
            print('❌ Cannot open Google Maps URL: $url');
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                    'Cannot open Google Maps. Please check your device settings.'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        } else {
          print('❌ Invalid coordinates: lat=$lat, lng=$lng');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content:
                  Text('Patient location coordinates are invalid or missing.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } else {
        print('❌ No location data found in request');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Patient location data is not available.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      print('❌ Error opening Google Maps: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error opening Google Maps. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Stack(
        children: [
          Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      spreadRadius: 1,
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        // Alarm indicator
                        AnimatedBuilder(
                          animation: _alarmAnimation,
                          builder: (context, child) {
                            return Container(
                              decoration: BoxDecoration(
                                color: _hasNewSOS
                                    ? Colors.red
                                        .withOpacity(_alarmAnimation.value)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding: const EdgeInsets.all(4),
                              child: Icon(
                                Icons.emergency,
                                color:
                                    _hasNewSOS ? Colors.white : Colors.red[600],
                                size: 24,
                              ),
                            );
                          },
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'SOS Emergency',
                            style: GoogleFonts.poppins(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        // Real-time indicator
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color:
                                _realtimeEnabled ? Colors.green : Colors.grey,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _realtimeEnabled ? 'Live' : 'Offline',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color:
                                _realtimeEnabled ? Colors.green : Colors.grey,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => SOSAnalyticsScreen(
                                    hospitalId: widget.hospitalId),
                              ),
                            );
                          },
                          icon: const Icon(Icons.analytics),
                          tooltip: 'SOS Analytics',
                        ),
                        // Alarm dismiss button
                        if (_hasNewSOS)
                          IconButton(
                            onPressed: _stopAlarm,
                            icon: const Icon(Icons.notifications_off),
                            tooltip: 'Dismiss Alarm',
                            color: Colors.red,
                          ),
                        IconButton(
                          onPressed: _loadSOSRequests,
                          icon: const Icon(Icons.refresh),
                          tooltip: 'Refresh',
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Tab Bar
                    TabBar(
                      controller: _tabController,
                      labelColor: Colors.red[600],
                      unselectedLabelColor: Colors.grey[600],
                      indicatorColor: Colors.red[600],
                      tabs: [
                        Tab(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.pending, size: 16),
                              const SizedBox(width: 4),
                              Text('Pending (${_sosRequests.length})'),
                            ],
                          ),
                        ),
                        Tab(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.check_circle, size: 16),
                              const SizedBox(width: 4),
                              Text('Accepted (${_acceptedRequests.length})'),
                            ],
                          ),
                        ),
                        Tab(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.cancel, size: 16),
                              const SizedBox(width: 4),
                              Text('Cancelled (${_cancelledRequests.length})'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Tab Content
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildRequestList(_sosRequests, 'pending'),
                    _buildRequestList(_acceptedRequests, 'accepted'),
                    _buildRequestList(_cancelledRequests, 'cancelled'),
                  ],
                ),
              ),
            ],
          ),
          // Alarm overlay
          if (_hasNewSOS)
            AnimatedBuilder(
              animation: _alarmAnimation,
              builder: (context, child) {
                return Container(
                  color: Colors.red.withOpacity(_alarmAnimation.value * 0.1),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.red.withOpacity(0.5),
                            blurRadius: 20,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.emergency,
                            color: Colors.white,
                            size: 60,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            '🚨 NEW SOS EMERGENCY 🚨',
                            style: GoogleFonts.poppins(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Immediate attention required!',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ElevatedButton.icon(
                                onPressed: () {
                                  widget.onNavigateToSOS();
                                  _stopAlarm();
                                },
                                icon: const Icon(Icons.visibility),
                                label: const Text('VIEW REQUESTS'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: Colors.red,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 12,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              ElevatedButton.icon(
                                onPressed: _stopAlarm,
                                icon: const Icon(Icons.close),
                                label: const Text('DISMISS'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.grey[600],
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 12,
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
              },
            ),
        ],
      ),
    );
  }

  Widget _buildRequestList(List<Map<String, dynamic>> requests, String status) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (requests.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              status == 'pending'
                  ? Icons.emergency_outlined
                  : status == 'accepted'
                      ? Icons.check_circle_outline
                      : Icons.cancel_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              status == 'pending'
                  ? 'No pending SOS requests'
                  : status == 'accepted'
                      ? 'No accepted requests'
                      : 'No cancelled requests',
              style: GoogleFonts.poppins(
                fontSize: 18,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              status == 'pending'
                  ? 'Emergency requests will appear here'
                  : status == 'accepted'
                      ? 'Accepted requests will appear here'
                      : 'Cancelled requests will appear here',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadSOSRequests,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: requests.length,
        itemBuilder: (context, index) {
          final request = requests[index];
          return _buildRequestCard(request, status);
        },
      ),
    );
  }

  Widget _buildRequestCard(Map<String, dynamic> request, String status) {
    Color statusColor;
    String statusText;

    switch (status) {
      case 'pending':
        statusColor = Colors.red[600]!;
        statusText = 'PENDING';
        break;
      case 'accepted':
        statusColor = Colors.green[600]!;
        statusText = 'ACCEPTED';
        break;
      case 'admitted':
        statusColor = Colors.purple[600]!;
        statusText = 'ADMITTED';
        break;
      case 'discharged':
        statusColor = Colors.blue[600]!;
        statusText = 'COMPLETED';
        break;
      case 'cancelled':
        statusColor = Colors.orange[600]!;
        statusText = 'CANCELLED';
        break;
      default:
        statusColor = Colors.grey[600]!;
        statusText = 'UNKNOWN';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
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
                  Icons.emergency,
                  color: statusColor,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Emergency Request',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: statusColor,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    statusText,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Patient: ${_getPatientNameFromRequest(request)}',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Location: ${_getLocationAddressFromRequest(request)}',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Time: ${_formatDateTime(request['createdAt'])}',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.grey[500],
              ),
            ),
            if (status == 'accepted') ...[
              const SizedBox(height: 8),
              Text(
                'Accepted by: ${request['acceptedBy']?['acceptedByStaff']?['name'] ?? 'Staff Member'}',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.green[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (request['responseDetails']?['responseTime'] != null) ...[
                const SizedBox(height: 4),
                Text(
                  'Response Time: ${request['responseDetails']['responseTime']} seconds',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.blue[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
              if (request['hospitalStatus'] == 'admitted') ...[
                const SizedBox(height: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '✅ Patient Confirmed Admission',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.blue[700],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (request['responseDetails']?['responseTime'] != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Response Time: ${request['responseDetails']['responseTime']} seconds',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.blue[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ],
            const SizedBox(height: 16),
            if (status == 'pending')
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _acceptSOSRequest(request),
                  icon: const Icon(Icons.check, size: 16),
                  label: const Text('Accept'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[600],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              )
            else if (status == 'accepted')
              Column(
                children: [
                  // Show admission details if patient is admitted
                  if (request['hospitalStatus'] == 'admitted') ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green[200]!),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.check_circle,
                                  color: Colors.green[600], size: 16),
                              const SizedBox(width: 8),
                              Text(
                                'Patient Admitted',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green[700],
                                ),
                              ),
                            ],
                          ),
                          if (request['admissionDetails'] != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              'Ward: ${request['admissionDetails']['wardNumber'] ?? 'N/A'}',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: Colors.green[600],
                              ),
                            ),
                            Text(
                              'Bed: ${request['admissionDetails']['bedNumber'] ?? 'N/A'}',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: Colors.green[600],
                              ),
                            ),
                            Text(
                              'Admitted by: ${request['admittedBy']?['name'] ?? 'Staff'}',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: Colors.green[600],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Debug logging for button logic
                  Builder(
                    builder: (context) {
                      // Extract SOS request data (it's nested in sosRequestId when populated)
                      final sosRequest = request['sosRequestId'] ?? request;

                      print('🔍 Button Logic Debug:');
                      print('  - Patient: ${sosRequest['patientName']}');
                      print(
                          '  - Hospital Status: ${request['hospitalStatus']}');
                      print(
                          '  - Should show Mark as Admitted: ${request['hospitalStatus'] != 'admitted' && request['hospitalStatus'] != 'discharged'}');
                      print(
                          '  - Should show Discharge: ${request['hospitalStatus'] == 'admitted'}');
                      print('  - SOS Request ID: ${sosRequest['_id']}');
                      print('  - Request keys: ${request.keys.toList()}');
                      print(
                          '  - SOS Request keys: ${sosRequest.keys.toList()}');
                      return const SizedBox.shrink();
                    },
                  ),

                  // Show Mark as Admitted button only if not already admitted or discharged
                  if (request['hospitalStatus'] != 'admitted' &&
                      request['hospitalStatus'] != 'discharged')
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _admitPatient(request),
                        icon: const Icon(Icons.local_hospital, size: 16),
                        label: const Text('Mark as Admitted'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[600],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),

                  // Show Discharge button only if patient is admitted
                  if (request['hospitalStatus'] == 'admitted')
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _dischargePatient(request),
                        icon: const Icon(Icons.exit_to_app, size: 16),
                        label: const Text('Discharge Patient'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green[600],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),

                  // Show response time for completed requests
                  if (request['hospitalStatus'] == 'discharged' &&
                      request['responseDetails']?['responseTime'] != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green[200]!),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.check_circle,
                              color: Colors.green[600], size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Response Time: ${request['responseDetails']['responseTime']} seconds',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: Colors.green[700],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // View Details button for all accepted requests
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _viewSOSDetails(request),
                      icon: const Icon(Icons.visibility, size: 16),
                      label: const Text('View Details'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.blue[600],
                        side: BorderSide(color: Colors.blue[600]!),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _acceptSOSRequest(Map<String, dynamic> request) async {
    try {
      final sosRequestId =
          request['sosRequestId']?['_id'] ?? request['sosRequestId'];
      final staffInfo = {
        'hospitalName': widget.hospital?.fullName ?? 'Hospital',
        'name': 'Staff Member', // Get from current user
        'phone': '000', // Get from current user
        'role': 'Emergency Staff'
      };

      final response = await ApiService.acceptSOSRequest(
        widget.hospitalId,
        sosRequestId.toString(),
        staffInfo,
      );

      if (response['success'] == true) {
        // Stop alarm when request is accepted
        _stopAlarm();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('SOS request accepted successfully'),
            backgroundColor: Colors.green,
          ),
        );
        _loadSOSRequests(); // Refresh the list
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('Failed to accept SOS request: ${response['message']}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print('❌ Error accepting SOS request: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error accepting SOS request: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _admitPatient(Map<String, dynamic> request) async {
    try {
      final sosRequestId =
          request['sosRequestId']?['_id'] ?? request['sosRequestId'];

      // Show admission details dialog
      final admissionDetails = await _showAdmissionDialog();
      if (admissionDetails == null) return;

      final admissionData = {
        'wardNumber': admissionDetails['wardNumber'],
        'bedNumber': admissionDetails['bedNumber'],
        'staffInfo': {
          'name': 'Staff Member', // Get from current user
          'role': 'Doctor/Staff',
          'phone': '000'
        },
        'notes': admissionDetails['notes'] ?? ''
      };

      final response = await ApiService.markPatientAdmitted(
        widget.hospitalId,
        sosRequestId.toString(),
        admissionData,
      );

      if (response['success'] == true) {
        print('✅ Patient admitted successfully: ${response['data']}');
        print('🔄 Refreshing SOS requests to update UI...');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Patient admitted successfully'),
            backgroundColor: Colors.blue,
          ),
        );
        _loadSOSRequests(); // Refresh the list
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to admit patient: ${response['message']}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print('❌ Error admitting patient: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error admitting patient: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _dischargePatient(Map<String, dynamic> request) async {
    try {
      final sosRequestId =
          request['sosRequestId']?['_id'] ?? request['sosRequestId'];

      // Show discharge details dialog
      final dischargeDetails = await _showDischargeDialog();
      if (dischargeDetails == null) return;

      final response = await ApiService.dischargePatient(
        widget.hospitalId,
        sosRequestId.toString(),
        dischargeDetails,
      );

      if (response['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Patient discharged successfully'),
            backgroundColor: Colors.green,
          ),
        );
        _loadSOSRequests(); // Refresh the list
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('Failed to discharge patient: ${response['message']}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print('❌ Error discharging patient: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error discharging patient: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _viewSOSDetails(Map<String, dynamic> request) async {
    // Extract SOS request data (it's nested in sosRequestId when populated)
    final sosRequest = request['sosRequestId'] ?? request;

    // Show detailed SOS request information
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.emergency, color: Colors.red),
            const SizedBox(width: 8),
            const Text('SOS Request Details'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow(
                  'Patient Name', sosRequest['patientName'] ?? 'Unknown'),
              _buildDetailRow(
                  'Patient Phone', sosRequest['patientPhone'] ?? 'Unknown'),
              _buildDetailRow(
                  'Emergency Type', sosRequest['emergencyType'] ?? 'Unknown'),
              _buildDetailRow('Severity', sosRequest['severity'] ?? 'Unknown'),
              _buildDetailRow('Status', request['hospitalStatus'] ?? 'Unknown'),
              _buildDetailRow(
                  'Created At', _formatDateTime(sosRequest['createdAt'])),
              if (request['acceptedAt'] != null)
                _buildDetailRow(
                    'Accepted At', _formatDateTime(request['acceptedAt'])),
              if (request['responseDetails']?['responseTime'] != null)
                _buildDetailRow('Response Time',
                    '${request['responseDetails']['responseTime']} seconds'),
              if (request['admissionDetails'] != null) ...[
                const SizedBox(height: 8),
                Text('Admission Details:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                _buildDetailRow(
                    'Ward', request['admissionDetails']['wardNumber'] ?? 'N/A'),
                _buildDetailRow(
                    'Bed', request['admissionDetails']['bedNumber'] ?? 'N/A'),
                _buildDetailRow(
                    'Admitted At',
                    request['admissionDetails']['admittedAt'] != null
                        ? _formatDateTime(
                            request['admissionDetails']['admittedAt'])
                        : 'N/A'),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
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
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  Future<Map<String, dynamic>?> _showAdmissionDialog() async {
    final wardController = TextEditingController();
    final bedController = TextEditingController();

    return await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('🏥 Patient Admission'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: wardController,
              decoration: const InputDecoration(
                labelText: 'Ward Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: bedController,
              decoration: const InputDecoration(
                labelText: 'Bed Number',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context, {
                'wardNumber': wardController.text.trim(),
                'bedNumber': bedController.text.trim(),
              });
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
            child: const Text('Admit Patient'),
          ),
        ],
      ),
    );
  }

  Future<Map<String, dynamic>?> _showDischargeDialog() async {
    final dischargeReasonController = TextEditingController();
    final dischargeNotesController = TextEditingController();
    final medicationsController = TextEditingController();
    final instructionsController = TextEditingController();
    bool followUpRequired = false;
    DateTime? followUpDate;

    return await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('🏥 Patient Discharge'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: dischargeReasonController,
                  decoration: const InputDecoration(
                    labelText: 'Discharge Reason',
                    hintText: 'e.g., Treatment completed, Stable condition',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: dischargeNotesController,
                  decoration: const InputDecoration(
                    labelText: 'Discharge Notes',
                    hintText: 'Additional notes about the patient',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: medicationsController,
                  decoration: const InputDecoration(
                    labelText: 'Medications Prescribed',
                    hintText: 'List of medications given to patient',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: instructionsController,
                  decoration: const InputDecoration(
                    labelText: 'Follow-up Instructions',
                    hintText: 'Instructions for patient after discharge',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                CheckboxListTile(
                  title: const Text('Follow-up Required'),
                  value: followUpRequired,
                  onChanged: (value) {
                    setState(() {
                      followUpRequired = value ?? false;
                    });
                  },
                ),
                if (followUpRequired) ...[
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate:
                            DateTime.now().add(const Duration(days: 7)),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (date != null) {
                        setState(() {
                          followUpDate = date;
                        });
                      }
                    },
                    child: Text(
                      followUpDate != null
                          ? 'Follow-up: ${followUpDate!.day}/${followUpDate!.month}/${followUpDate!.year}'
                          : 'Select Follow-up Date',
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context, {
                  'dischargeReason': dischargeReasonController.text.trim(),
                  'dischargeNotes': dischargeNotesController.text.trim(),
                  'medications': medicationsController.text
                      .trim()
                      .split(',')
                      .map((e) => e.trim())
                      .toList(),
                  'instructions': instructionsController.text.trim(),
                  'followUpRequired': followUpRequired,
                  'followUpDate': followUpDate?.toIso8601String(),
                });
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: const Text('Discharge Patient'),
            ),
          ],
        ),
      ),
    );
  }
}

@override
Widget build(BuildContext context) {
  return Scaffold(
    backgroundColor: const Color(0xFFF5F6FA),
    appBar: AppBar(
      title: Text(
        'Activity Details',
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
            colors: [Color(0xFF4CAF50), Color(0xFF81C784)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
        ),
      ),
    ),
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Activity Summary Card
          Card(
            elevation: 3,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF4CAF50), Color(0xFF81C784)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Recent Activity Summary',
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _buildActivityStat('Today', '12', Icons.today),
                      const SizedBox(width: 20),
                      _buildActivityStat('This Week', '45', Icons.date_range),
                      const SizedBox(width: 20),
                      _buildActivityStat(
                          'This Month', '180', Icons.calendar_month),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Activity List
          Text(
            'Recent Activities',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF2E2E2E),
            ),
          ),
          const SizedBox(height: 16),

          // Activity Items - Coming Soon
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.timeline,
                  size: 48,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 12),
                Text(
                  'Activity Timeline',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Recent activities will be displayed here',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.grey[500],
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

Widget _buildActivityStat(String label, String value, IconData icon) {
  return Expanded(
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.poppins(
              color: Colors.white.withOpacity(0.8),
              fontSize: 12,
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
