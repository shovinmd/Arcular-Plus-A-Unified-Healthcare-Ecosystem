import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import '../../models/appointment_model.dart';
import '../../models/user_model.dart';
import '../../services/api_service.dart';

class AppointmentManagementScreen extends StatefulWidget {
  const AppointmentManagementScreen({super.key});

  @override
  State<AppointmentManagementScreen> createState() =>
      _AppointmentManagementScreenState();
}

class _AppointmentManagementScreenState
    extends State<AppointmentManagementScreen> {
  bool _loading = true;
  List<AppointmentModel> _appointments = [];
  Future<List<Map<String, dynamic>>>? _ratingsFuture;

  @override
  void initState() {
    super.initState();
    _loadAppointments();
    _ratingsFuture = _loadHospitalRatings();
  }

  Future<void> _showOfflineBookingSheet() async {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final emailController = TextEditingController();
    final doctorController = TextEditingController();
    String? selectedDoctorUid;
    String? selectedDepartment;
    final notesController = TextEditingController();
    DateTime? pickedDateTime;

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
            left: 16,
            right: 16,
            top: 16,
          ),
          child: StatefulBuilder(
            builder: (context, setSheetState) => SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Book Offline Appointment',
                      style: GoogleFonts.poppins(
                          fontSize: 18, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                        labelText: 'Patient full name',
                        prefixIcon: Icon(Icons.person_outline)),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                        labelText: 'Patient email (for confirmation)',
                        prefixIcon: Icon(Icons.email_outlined)),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                        labelText: 'Patient phone',
                        prefixIcon: Icon(Icons.phone_outlined)),
                  ),
                  const SizedBox(height: 8),
                  FutureBuilder<List<UserModel>>(
                    future: () async {
                      final uid = FirebaseAuth.instance.currentUser?.uid;
                      if (uid == null) return <UserModel>[];
                      final hid = await ApiService.getHospitalMongoId(uid);
                      if (hid == null) return <UserModel>[];
                      return ApiService.getAffiliatedDoctors(hid);
                    }(),
                    builder: (context, snap) {
                      final items = snap.data ?? [];
                      return DropdownButtonFormField<String?>(
                        value: selectedDoctorUid,
                        items: [
                          const DropdownMenuItem<String?>(
                              value: null, child: Text('No specific doctor')),
                          ...items
                              .map((d) => DropdownMenuItem<String?>(
                                  value: d.uid, child: Text(d.fullName)))
                              .toList(),
                        ],
                        onChanged: (String? v) =>
                            setSheetState(() => selectedDoctorUid = v),
                        decoration: const InputDecoration(
                            labelText: 'Doctor (optional)',
                            prefixIcon: Icon(Icons.local_hospital_outlined)),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  FutureBuilder<List<String>>(
                    future: () async {
                      final uid = FirebaseAuth.instance.currentUser?.uid;
                      if (uid == null) return <String>[];
                      final hid = await ApiService.getHospitalMongoId(uid);
                      if (hid == null) return <String>[];
                      return ApiService.getHospitalDepartments(hid);
                    }(),
                    builder: (context, snap) {
                      final items = snap.data ?? [];
                      return DropdownButtonFormField<String?>(
                        value: selectedDepartment,
                        items: [
                          const DropdownMenuItem<String?>(
                              value: null, child: Text('No department')),
                          ...items
                              .map((d) => DropdownMenuItem<String?>(
                                  value: d, child: Text(d)))
                              .toList(),
                        ],
                        onChanged: (String? v) =>
                            setSheetState(() => selectedDepartment = v),
                        decoration: const InputDecoration(
                            labelText: 'Department (optional)',
                            prefixIcon: Icon(Icons.apartment_outlined)),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () async {
                      final d = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (d == null) return;
                      final t = await showTimePicker(
                        context: context,
                        initialTime: const TimeOfDay(hour: 9, minute: 0),
                      );
                      if (t == null) return;
                      setSheetState(() {
                        pickedDateTime =
                            DateTime(d.year, d.month, d.day, t.hour, t.minute);
                      });
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Date & time',
                        prefixIcon: Icon(Icons.schedule_outlined),
                        border: OutlineInputBorder(),
                      ),
                      child: Text(
                        pickedDateTime == null
                            ? 'Select date & time'
                            : DateFormat('MMM dd, yyyy • hh:mm a')
                                .format(pickedDateTime!),
                        style: GoogleFonts.poppins(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: notesController,
                    decoration: const InputDecoration(
                        labelText: 'Notes (optional)',
                        prefixIcon: Icon(Icons.note_alt_outlined)),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel')),
                      ElevatedButton(
                        onPressed: () async {
                          final name = nameController.text.trim();
                          final phone = phoneController.text.trim();
                          final email = emailController.text.trim();
                          if (name.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('Enter patient name')));
                            return;
                          }
                          if (phone.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('Enter patient phone')));
                            return;
                          }
                          if (pickedDateTime == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('Select date & time')));
                            return;
                          }
                          Navigator.pop(context, true);
                          await _createOfflineAppointment(
                            name: name,
                            phone: phone,
                            email: email,
                            doctorName: doctorController.text.trim(),
                            department: selectedDepartment ?? '',
                            doctorUid: selectedDoctorUid,
                            dateTime: pickedDateTime!,
                            notes: notesController.text.trim(),
                          );
                        },
                        child: const Text('Book'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    nameController.dispose();
    phoneController.dispose();
    emailController.dispose();
    doctorController.dispose();
    notesController.dispose();

    if (result == true) {
      await _loadAppointments();
    }
  }

  Future<void> _createOfflineAppointment({
    required String name,
    required String phone,
    required String email,
    required String doctorName,
    required String department,
    String? doctorUid,
    required DateTime dateTime,
    required String notes,
  }) async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) throw Exception('User not authenticated');
      final hospitalMongoId = await ApiService.getHospitalMongoId(uid);
      if (hospitalMongoId == null) throw Exception('Hospital not found');

      final payload = {
        'patientName': name,
        'patientPhone': phone,
        if (email.isNotEmpty) 'patientEmail': email,
        'hospitalId': hospitalMongoId,
        'doctorName': doctorName,
        'doctorId': doctorUid,
        'department': department,
        'appointmentDate': DateFormat('yyyy-MM-dd').format(dateTime),
        'appointmentTime': DateFormat('HH:mm').format(dateTime),
        'notes': notes,
        'source': 'offline',
        'notifyDoctor': true,
        'sendEmail': email.isNotEmpty,
      };
      await ApiService.createOfflineAppointment(payload);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Offline appointment created')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Failed to create offline appointment: $e')));
      }
    }
  }

  Future<void> _loadAppointments() async {
    try {
      if (mounted) setState(() => _loading = true);
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        if (mounted) {
          setState(() => _loading = false);
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('User not authenticated')));
        }
        return;
      }
      final hospitalMongoId = await ApiService.getHospitalMongoId(uid);
      if (hospitalMongoId == null) {
        if (mounted) {
          setState(() => _loading = false);
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Hospital not found')));
        }
        return;
      }

      // Get all appointments and affiliated doctors
      print('🔍 Loading appointments for hospital: $hospitalMongoId');
      final allAppointments =
          await ApiService.getHospitalAppointments(hospitalMongoId);
      print('📋 Loaded ${allAppointments.length} total appointments');

      final affiliatedDoctors =
          await ApiService.getAffiliatedDoctors(hospitalMongoId);
      print('👨‍⚕️ Loaded ${affiliatedDoctors.length} affiliated doctors');

      // Filter appointments to only show those from affiliated doctors
      final affiliatedDoctorUids = affiliatedDoctors.map((d) => d.uid).toSet();
      final filteredAppointments = allAppointments.where((apt) {
        return affiliatedDoctorUids.contains(apt.doctorId.trim());
      }).toList();

      print(
          '🔍 Filtered to ${filteredAppointments.length} appointments from affiliated doctors');
      print(
          '📊 Appointment statuses: ${filteredAppointments.map((apt) => '${apt.patientName}: ${apt.status}').join(', ')}');

      if (mounted) {
        setState(() {
          _appointments = filteredAppointments;
          _loading = false;
        });
        print('✅ Appointments state updated successfully');
      }
    } catch (e) {
      print('❌ Error loading appointments: $e');
      if (mounted) {
        setState(() => _loading = false);
        // Only show error message if this is not a refresh after completion
        if (!e.toString().contains('refresh')) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to load appointments: $e')));
        }
      }
    }
  }

  Future<List<Map<String, dynamic>>> _loadHospitalRatings() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
      if (uid.isEmpty) return [];
      final mongoId = await ApiService.getHospitalMongoId(uid);
      final byUid = await ApiService.getProviderRatings(
        providerId: uid,
        providerType: 'hospital',
      );
      if (mongoId == null || mongoId.isEmpty) return byUid;
      final byMongo = await ApiService.getProviderRatings(
        providerId: mongoId,
        providerType: 'hospital',
      );
      final Map<String, Map<String, dynamic>> dedup = {};
      for (final r in [...byUid, ...byMongo]) {
        final key = '${r['appointmentId']}_${r['userId']}_${r['providerId']}';
        dedup[key] = r;
      }
      return dedup.values.toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _confirmComplete(AppointmentModel apt) async {
    // Prevent multiple completion attempts
    if (apt.status.toLowerCase() == 'completed') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This appointment is already completed'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final data = await _showCompleteSheet();
    if (data == null) return;

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            children: [
              const CircularProgressIndicator(),
              const SizedBox(width: 16),
              Text(
                'Completing appointment...',
                style: GoogleFonts.poppins(fontSize: 16),
              ),
            ],
          ),
        ),
      ),
    );

    try {
      // Complete the appointment with timeout
      print('🔄 Completing appointment: ${apt.id}');
      await ApiService.completeAppointment(
              apt.id, data.billAmount, data.notes, data.paymentMethod)
          .timeout(const Duration(seconds: 30));
      print('✅ Appointment completed successfully');

      // Create hospital record (non-blocking for success flow)
      print('🔄 Creating hospital record...');
      try {
        await _createHospitalRecord(apt, data.billAmount, data.notes);
        print('✅ Hospital record created');
      } catch (e) {
        // Swallow errors so completion UX isn't interrupted
        print('⚠️ Non-fatal hospital record error: $e');
      }

      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Appointment Completed Successfully!',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      'Patient has been notified and record created',
                      style: GoogleFonts.poppins(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );

      // Add a small delay to ensure database consistency
      await Future.delayed(const Duration(milliseconds: 500));
      print('🔄 Refreshing appointments after completion...');

      // Safely refresh appointments with error handling
      if (mounted) {
        try {
          await _loadAppointments();
          print('✅ Appointments refreshed, count: ${_appointments.length}');
        } catch (refreshError) {
          print('⚠️ Error refreshing appointments: $refreshError');
          // Don't show error to user as appointment was completed successfully
        }
      }
    } catch (e) {
      print('❌ Error completing appointment: $e');
      if (mounted) {
        Navigator.pop(context); // Close loading dialog

        String errorMessage = 'Failed to complete appointment';
        if (e.toString().contains('TimeoutException')) {
          errorMessage = 'Request timed out. Please try again.';
        } else if (e.toString().contains('SocketException')) {
          errorMessage = 'Network error. Please check your connection.';
        } else if (e.toString().contains('Exception')) {
          errorMessage = 'Server error. Please try again later.';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text(errorMessage)),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<void> _createHospitalRecord(
      AppointmentModel apt, double billAmount, String notes) async {
    try {
      final hospitalId = FirebaseAuth.instance.currentUser?.uid;
      if (hospitalId == null) return;

      // Try to enrich with patient ARC ID (health QR) for reliable backend lookup
      String? patientArcId;
      try {
        final patient = await ApiService.getUserInfo(apt.patientId);
        patientArcId = patient?.healthQrId ?? patient?.arcId;
      } catch (_) {}

      final recordData = {
        'patientId': apt.patientId,
        if (patientArcId != null && patientArcId.isNotEmpty)
          'patientArcId': patientArcId,
        'patientName': apt.patientName ?? 'Unknown Patient',
        'patientPhone': apt.patientPhone ?? '',
        'doctorId': apt.doctorId,
        'doctorName': apt.doctorName,
        'hospitalId': hospitalId,
        'appointmentId': apt.appointmentId ?? apt.id,
        'visitDate': apt.dateTime.toIso8601String(),
        'consultationFee': billAmount,
        'diagnosis': notes,
        'treatment': notes,
        'medications': [],
        'vitalSigns': {},
        'status': 'completed',
        'visitType': 'consultation',
      };

      await ApiService.createHospitalRecord(recordData);
    } catch (e) {
      print('Error creating hospital record: $e');
      // Don't throw error as appointment completion is more important
    }
  }

  Future<void> _confirmCancel(AppointmentModel apt) async {
    final reason = await _showCancelDialog(apt);
    if (reason == null) return;

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            children: [
              const CircularProgressIndicator(),
              const SizedBox(width: 16),
              Text(
                'Cancelling appointment...',
                style: GoogleFonts.poppins(fontSize: 16),
              ),
            ],
          ),
        ),
      ),
    );

    try {
      await ApiService.cancelAppointmentByHospital(apt.id, reason);

      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.cancel, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Appointment Cancelled Successfully!',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      'Patient has been notified of the cancellation',
                      style: GoogleFonts.poppins(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );

      // Add a small delay to ensure database consistency
      await Future.delayed(const Duration(milliseconds: 500));
      print('🔄 Refreshing appointments after cancellation...');
      await _loadAppointments();
      print(
          '✅ Appointments refreshed after cancellation, count: ${_appointments.length}');
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        print('❌ Cancellation error: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 8),
                Text('Failed to cancel appointment: $e'),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _reschedule(AppointmentModel apt) async {
    final result = await _showRescheduleDialog(apt);
    if (result == null) return;

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            children: [
              const CircularProgressIndicator(),
              const SizedBox(width: 16),
              Text(
                'Rescheduling appointment...',
                style: GoogleFonts.poppins(fontSize: 16),
              ),
            ],
          ),
        ),
      ),
    );

    try {
      await ApiService.rescheduleAppointmentByHospital(
        apt.id,
        DateFormat('yyyy-MM-dd').format(result.newDateTime),
        DateFormat('HH:mm').format(result.newDateTime),
        result.reason,
      );

      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.schedule, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Appointment Rescheduled Successfully!',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      'Patient has been notified of the new date/time',
                      style: GoogleFonts.poppins(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );

      // Add a small delay to ensure database consistency
      await Future.delayed(const Duration(milliseconds: 500));
      print('🔄 Refreshing appointments after reschedule...');
      await _loadAppointments();
      print(
          '✅ Appointments refreshed after reschedule, count: ${_appointments.length}');
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        print('❌ Reschedule error: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 8),
                Text('Failed to reschedule appointment: $e'),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<String?> _showCancelDialog(AppointmentModel apt) async {
    final reasonController = TextEditingController();

    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.cancel,
                        color: Colors.red,
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Cancel Appointment',
                            style: GoogleFonts.poppins(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Provide a reason for cancelling this appointment',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Current Appointment Info
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Appointment Details',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[700],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Patient: ${apt.patientName ?? 'Unknown'}',
                        style: GoogleFonts.poppins(fontSize: 14),
                      ),
                      Text(
                        'Doctor: ${apt.doctorName}',
                        style: GoogleFonts.poppins(fontSize: 14),
                      ),
                      Text(
                        'Date: ${DateFormat('MMM dd, yyyy • hh:mm a').format(apt.dateTime)}',
                        style: GoogleFonts.poppins(fontSize: 14),
                      ),
                      if ((apt.department ?? '').isNotEmpty)
                        Text(
                          'Department: ${apt.department}',
                          style: GoogleFonts.poppins(fontSize: 14),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Warning Message
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red[200]!),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning, color: Colors.red, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'This action will notify the patient and mark the appointment as cancelled.',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: Colors.red[700],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Reason Field
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TextField(
                    controller: reasonController,
                    maxLines: 3,
                    style: GoogleFonts.poppins(fontSize: 16),
                    decoration: InputDecoration(
                      labelText: 'Cancellation Reason *',
                      labelStyle: GoogleFonts.poppins(color: Colors.grey[600]),
                      prefixIcon: const Icon(Icons.note_alt_outlined,
                          color: Colors.red),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.all(16),
                      hintText:
                          'Enter reason for cancelling this appointment...',
                      hintStyle: GoogleFonts.poppins(color: Colors.grey[400]),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          side: BorderSide(color: Colors.grey[400]!),
                        ),
                        child: Text(
                          'Keep Appointment',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey[600],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          final reason = reasonController.text.trim();
                          if (reason.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Row(
                                  children: [
                                    const Icon(Icons.error,
                                        color: Colors.white),
                                    const SizedBox(width: 8),
                                    const Text(
                                        'Please enter a cancellation reason'),
                                  ],
                                ),
                                backgroundColor: Colors.red,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                            return;
                          }
                          Navigator.pop(context, reason);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Cancel Appointment',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
    reasonController.dispose();
    return result;
  }

  Future<_RescheduleData?> _showRescheduleDialog(AppointmentModel apt) async {
    DateTime selectedDate = apt.dateTime;
    TimeOfDay selectedTime = TimeOfDay.fromDateTime(apt.dateTime);
    final reasonController = TextEditingController();

    final result = await showDialog<_RescheduleData>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) => Dialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Container(
              width: MediaQuery.of(context).size.width * 0.9,
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.schedule,
                          color: Colors.orange,
                          size: 32,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Reschedule Appointment',
                              style: GoogleFonts.poppins(
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Select new date and time for the appointment',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Current Appointment Info
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Current Appointment',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[700],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Patient: ${apt.patientName ?? 'Unknown'}',
                          style: GoogleFonts.poppins(fontSize: 14),
                        ),
                        Text(
                          'Doctor: ${apt.doctorName}',
                          style: GoogleFonts.poppins(fontSize: 14),
                        ),
                        Text(
                          'Date: ${DateFormat('MMM dd, yyyy • hh:mm a').format(apt.dateTime)}',
                          style: GoogleFonts.poppins(fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // New Date Selection
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: InkWell(
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime.now(),
                          lastDate:
                              DateTime.now().add(const Duration(days: 365)),
                        );
                        if (date != null) {
                          setState(() {
                            selectedDate = date;
                          });
                        }
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today,
                                color: Colors.orange),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'New Date',
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  Text(
                                    DateFormat('MMM dd, yyyy')
                                        .format(selectedDate),
                                    style: GoogleFonts.poppins(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.arrow_drop_down),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // New Time Selection
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: InkWell(
                      onTap: () async {
                        final time = await showTimePicker(
                          context: context,
                          initialTime: selectedTime,
                        );
                        if (time != null) {
                          setState(() {
                            selectedTime = time;
                          });
                        }
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            const Icon(Icons.access_time, color: Colors.orange),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'New Time',
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  Text(
                                    selectedTime.format(context),
                                    style: GoogleFonts.poppins(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.arrow_drop_down),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Reason Field
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TextField(
                      controller: reasonController,
                      maxLines: 3,
                      style: GoogleFonts.poppins(fontSize: 16),
                      decoration: InputDecoration(
                        labelText: 'Reschedule Reason *',
                        labelStyle:
                            GoogleFonts.poppins(color: Colors.grey[600]),
                        prefixIcon: const Icon(Icons.note_alt_outlined,
                            color: Colors.orange),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.all(16),
                        hintText: 'Enter reason for rescheduling...',
                        hintStyle: GoogleFonts.poppins(color: Colors.grey[400]),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            side: BorderSide(color: Colors.grey[400]!),
                          ),
                          child: Text(
                            'Cancel',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey[600],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            final reason = reasonController.text.trim();
                            if (reason.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Row(
                                    children: [
                                      const Icon(Icons.error,
                                          color: Colors.white),
                                      const SizedBox(width: 8),
                                      const Text(
                                          'Please enter a reschedule reason'),
                                    ],
                                  ),
                                  backgroundColor: Colors.red,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                              return;
                            }

                            final newDateTime = DateTime(
                              selectedDate.year,
                              selectedDate.month,
                              selectedDate.day,
                              selectedTime.hour,
                              selectedTime.minute,
                            );

                            Navigator.pop(
                                context,
                                _RescheduleData(
                                  newDateTime: newDateTime,
                                  reason: reason,
                                ));
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            'Reschedule Appointment',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
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
      },
    );
    reasonController.dispose();
    return result;
  }

  Color _getStatusTextColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return Colors.green[800]!;
      case 'consultation_completed':
        return Colors.orange[800]!;
      case 'cancelled':
        return Colors.red[800]!;
      case 'rescheduled':
        return Colors.orange[800]!;
      case 'scheduled':
        return Colors.blue[800]!;
      case 'pending':
        return Colors.blue[800]!;
      default:
        return Colors.blue[800]!;
    }
  }

  Color _getStatusBackgroundColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return Colors.green[50]!;
      case 'consultation_completed':
        return Colors.orange[50]!;
      case 'cancelled':
        return Colors.red[50]!;
      case 'rescheduled':
        return Colors.orange[50]!;
      case 'scheduled':
        return Colors.blue[50]!;
      case 'pending':
        return Colors.blue[50]!;
      default:
        return Colors.blue[50]!;
    }
  }

  Future<_CompleteData?> _showCompleteSheet() async {
    final billController = TextEditingController();
    final notesController = TextEditingController();
    String selectedPaymentMethod = 'cash';
    final result = await showDialog<_CompleteData>(
      context: context,
      builder: (context) {
        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.check_circle,
                        color: Colors.green,
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Complete Appointment',
                            style: GoogleFonts.poppins(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Enter consultation details and bill amount',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Bill Amount Field
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TextField(
                    controller: billController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    style: GoogleFonts.poppins(fontSize: 16),
                    decoration: InputDecoration(
                      labelText: 'Consultation Fee (₹)',
                      labelStyle: GoogleFonts.poppins(color: Colors.grey[600]),
                      prefixIcon:
                          const Icon(Icons.receipt_long, color: Colors.green),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.all(16),
                      hintText: 'Enter amount (e.g., 500)',
                      hintStyle: GoogleFonts.poppins(color: Colors.grey[400]),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Notes Field
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TextField(
                    controller: notesController,
                    maxLines: 3,
                    style: GoogleFonts.poppins(fontSize: 16),
                    decoration: InputDecoration(
                      labelText: 'Consultation Notes *',
                      labelStyle: GoogleFonts.poppins(color: Colors.grey[600]),
                      prefixIcon: const Icon(Icons.note_alt_outlined,
                          color: Colors.green),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.all(16),
                      hintText:
                          'Enter diagnosis, treatment, or recommendations...',
                      hintStyle: GoogleFonts.poppins(color: Colors.grey[400]),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Payment Method Field
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: DropdownButtonFormField<String>(
                    value: selectedPaymentMethod,
                    decoration: InputDecoration(
                      labelText: 'Payment Method',
                      labelStyle: GoogleFonts.poppins(color: Colors.grey[600]),
                      prefixIcon:
                          const Icon(Icons.payment, color: Colors.green),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.all(16),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'cash', child: Text('Cash')),
                      DropdownMenuItem(value: 'card', child: Text('Card')),
                      DropdownMenuItem(value: 'upi', child: Text('UPI')),
                      DropdownMenuItem(value: 'online', child: Text('Online')),
                    ],
                    onChanged: (value) {
                      selectedPaymentMethod = value ?? 'cash';
                    },
                  ),
                ),
                const SizedBox(height: 24),

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          side: BorderSide(color: Colors.grey[400]!),
                        ),
                        child: Text(
                          'Cancel',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey[600],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          final bill =
                              double.tryParse(billController.text.trim());
                          final notes = notesController.text.trim();
                          if (bill == null || bill <= 0) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Row(
                                  children: [
                                    const Icon(Icons.error,
                                        color: Colors.white),
                                    const SizedBox(width: 8),
                                    const Text(
                                        'Enter a valid bill amount greater than ₹0'),
                                  ],
                                ),
                                backgroundColor: Colors.red,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                            return;
                          }
                          if (notes.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Row(
                                  children: [
                                    const Icon(Icons.error,
                                        color: Colors.white),
                                    const SizedBox(width: 8),
                                    const Text('Please add consultation notes'),
                                  ],
                                ),
                                backgroundColor: Colors.red,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                            return;
                          }
                          Navigator.pop(
                              context,
                              _CompleteData(
                                  billAmount: bill,
                                  notes: notes,
                                  paymentMethod: selectedPaymentMethod));
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Complete Appointment',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
    billController.dispose();
    notesController.dispose();
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Appointment Management',
              style: GoogleFonts.poppins(color: Colors.white)),
          backgroundColor: Colors.blue[600],
          flexibleSpace: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue[600]!, Colors.blue[400]!],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          bottom: const TabBar(
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: [
              Tab(text: 'List'),
              Tab(text: 'Ratings'),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _showOfflineBookingSheet,
          backgroundColor: Colors.blue[600],
          icon: const Icon(Icons.add),
          label: const Text('Book Offline'),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  // List tab
                  _appointments.isEmpty
                      ? const Center(child: Text('No appointments found'))
                      : RefreshIndicator(
                          onRefresh: _loadAppointments,
                          child: ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _appointments.length,
                            itemBuilder: (context, index) {
                              final a = _appointments[index];
                              return Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                elevation: a.status == 'completed' ? 4 : 2,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16)),
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(16),
                                    gradient: a.status == 'completed'
                                        ? LinearGradient(
                                            colors: [
                                              Colors.green.shade50,
                                              Colors.white
                                            ],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          )
                                        : null,
                                    border: a.status == 'completed'
                                        ? Border.all(
                                            color: Colors.green.shade200,
                                            width: 1)
                                        : null,
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                  a.patientName ??
                                                      'Unknown Patient',
                                                  style: GoogleFonts.poppins(
                                                      fontWeight:
                                                          FontWeight.w700),
                                                  overflow:
                                                      TextOverflow.ellipsis),
                                            ),
                                            const SizedBox(width: 8),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 12,
                                                      vertical: 6),
                                              decoration: BoxDecoration(
                                                color: a.status == 'completed'
                                                    ? Colors.green
                                                    : _getStatusBackgroundColor(
                                                        a.status),
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                                boxShadow: a.status ==
                                                        'completed'
                                                    ? [
                                                        BoxShadow(
                                                          color: Colors.green
                                                              .withOpacity(0.3),
                                                          blurRadius: 4,
                                                          offset: Offset(0, 2),
                                                        )
                                                      ]
                                                    : null,
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  if (a.status == 'completed')
                                                    Icon(Icons.check_circle,
                                                        size: 14,
                                                        color: Colors.white),
                                                  SizedBox(
                                                      width: a.status ==
                                                              'completed'
                                                          ? 4
                                                          : 0),
                                                  Text(
                                                    a.status == 'completed'
                                                        ? 'COMPLETED'
                                                        : a.status,
                                                    style: GoogleFonts.poppins(
                                                        fontSize: 12,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: a.status ==
                                                                'completed'
                                                            ? Colors.white
                                                            : _getStatusTextColor(
                                                                a.status)),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Text('Doctor: ${a.doctorName}',
                                            style: GoogleFonts.poppins(
                                                fontSize: 13)),
                                        Text(
                                            DateFormat('MMM dd, yyyy • hh:mm a')
                                                .format(a.dateTime),
                                            style: GoogleFonts.poppins(
                                                fontSize: 12,
                                                color: Colors.grey[700])),
                                        if ((a.reason ?? '').isNotEmpty)
                                          Container(
                                            margin:
                                                const EdgeInsets.only(top: 4),
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: Colors.blue[50],
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              border: Border.all(
                                                  color: Colors.blue[200]!),
                                            ),
                                            child: Row(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Icon(Icons.info_outline,
                                                    size: 14,
                                                    color: Colors.blue[700]),
                                                const SizedBox(width: 4),
                                                Expanded(
                                                  child: Text(
                                                    'Reason: ${a.reason}',
                                                    style: GoogleFonts.poppins(
                                                      fontSize: 12,
                                                      color: Colors.blue[700],
                                                      fontWeight:
                                                          FontWeight.w500,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        if ((a.department ?? '').isNotEmpty)
                                          Text('Dept: ${a.department}',
                                              style: GoogleFonts.poppins(
                                                  fontSize: 12)),
                                        if ((a.patientPhone ?? '').isNotEmpty)
                                          Text('Phone: ${a.patientPhone}',
                                              style: GoogleFonts.poppins(
                                                  fontSize: 12)),
                                        if ((a.notes ?? '').isNotEmpty)
                                          Text('Notes: ${a.notes}',
                                              style: GoogleFonts.poppins(
                                                  fontSize: 12)),
                                        const SizedBox(height: 12),
                                        // Only show action buttons if appointment is not completed
                                        if (a.status.toLowerCase() !=
                                            'completed')
                                          Row(
                                            children: [
                                              Expanded(
                                                child: ElevatedButton.icon(
                                                  onPressed: () =>
                                                      _confirmComplete(a),
                                                  icon: const Icon(
                                                      Icons.check_circle,
                                                      size: 16),
                                                  label: const Text('Complete'),
                                                  style:
                                                      ElevatedButton.styleFrom(
                                                    backgroundColor:
                                                        Colors.green,
                                                    foregroundColor:
                                                        Colors.white,
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        horizontal: 8,
                                                        vertical: 8),
                                                    textStyle:
                                                        GoogleFonts.poppins(
                                                            fontSize: 12,
                                                            fontWeight:
                                                                FontWeight
                                                                    .w500),
                                                    minimumSize:
                                                        const Size(0, 36),
                                                    shape:
                                                        RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              8),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: OutlinedButton.icon(
                                                  onPressed: () =>
                                                      _reschedule(a),
                                                  icon: const Icon(
                                                      Icons.schedule,
                                                      size: 16),
                                                  label:
                                                      const Text('Reschedule'),
                                                  style:
                                                      OutlinedButton.styleFrom(
                                                    foregroundColor:
                                                        Colors.orange,
                                                    side: const BorderSide(
                                                        color: Colors.orange),
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        horizontal: 8,
                                                        vertical: 8),
                                                    textStyle:
                                                        GoogleFonts.poppins(
                                                            fontSize: 12,
                                                            fontWeight:
                                                                FontWeight
                                                                    .w500),
                                                    minimumSize:
                                                        const Size(0, 36),
                                                    shape:
                                                        RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              8),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: OutlinedButton.icon(
                                                  onPressed: () =>
                                                      _confirmCancel(a),
                                                  icon: const Icon(Icons.cancel,
                                                      size: 16),
                                                  label: const Text('Cancel'),
                                                  style:
                                                      OutlinedButton.styleFrom(
                                                    foregroundColor: Colors.red,
                                                    side: const BorderSide(
                                                        color: Colors.red),
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        horizontal: 8,
                                                        vertical: 8),
                                                    textStyle:
                                                        GoogleFonts.poppins(
                                                            fontSize: 12,
                                                            fontWeight:
                                                                FontWeight
                                                                    .w500),
                                                    minimumSize:
                                                        const Size(0, 36),
                                                    shape:
                                                        RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              8),
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
                            },
                          ),
                        ),
                  // Ratings tab (show rating per appointment, matched by appointmentId)
                  FutureBuilder<List<Map<String, dynamic>>>(
                    future: _ratingsFuture,
                    builder: (context, snap) {
                      final ratings = snap.data ?? [];
                      final Map<String, Map<String, dynamic>> byApt = {
                        for (final r in ratings)
                          if ((r['appointmentId'] ?? '').toString().isNotEmpty)
                            (r['appointmentId'] as String): r
                      };

                      return ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _appointments.length,
                        itemBuilder: (context, index) {
                          final a = _appointments[index];
                          final key = a.appointmentId ?? a.id;
                          final r = byApt[key];
                          final rated = r != null;
                          final ratingValue = rated ? (r['rating'] ?? 0) : 0;
                          final review = rated ? (r['review'] ?? '') : '';
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
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
                                          a.patientName ?? 'Unknown Patient',
                                          style: GoogleFonts.poppins(
                                              fontWeight: FontWeight.w600),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      Row(
                                        children: List.generate(5, (i) {
                                          return Icon(
                                            i < ratingValue
                                                ? Icons.star
                                                : Icons.star_border,
                                            color: Colors.amber,
                                            size: 18,
                                          );
                                        }),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                      'Appointment: ${a.appointmentId ?? a.id}',
                                      style: GoogleFonts.poppins(fontSize: 12)),
                                  Text(
                                    DateFormat('MMM dd, yyyy • hh:mm a')
                                        .format(a.dateTime),
                                    style: GoogleFonts.poppins(
                                        fontSize: 12, color: Colors.grey[700]),
                                  ),
                                  if ((a.reason ?? '').isNotEmpty)
                                    Text('Reason: ${a.reason}',
                                        style:
                                            GoogleFonts.poppins(fontSize: 12)),
                                  if (rated && review.toString().isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 6.0),
                                      child: Text('"$review"',
                                          style: GoogleFonts.poppins(
                                              fontSize: 12,
                                              fontStyle: FontStyle.italic)),
                                    ),
                                  if (!rated)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 6.0),
                                      child: Text('Not rated',
                                          style: GoogleFonts.poppins(
                                              fontSize: 12,
                                              color: Colors.grey[600])),
                                    ),
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
      ),
    );
  }
}

class _CompleteData {
  final double billAmount;
  final String notes;
  final String paymentMethod;
  _CompleteData(
      {required this.billAmount,
      required this.notes,
      required this.paymentMethod});
}

class _RescheduleData {
  final DateTime newDateTime;
  final String reason;
  _RescheduleData({required this.newDateTime, required this.reason});
}
