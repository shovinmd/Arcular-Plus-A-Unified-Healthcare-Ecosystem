import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:arcular_plus/widgets/chatarc_floating_button.dart';
import 'package:arcular_plus/services/api_service.dart';
import 'package:arcular_plus/models/user_model.dart';
import 'package:arcular_plus/models/appointment_model.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';

class AppointmentBookingNewScreen extends StatefulWidget {
  const AppointmentBookingNewScreen({super.key});

  @override
  State<AppointmentBookingNewScreen> createState() =>
      _AppointmentBookingNewScreenState();
}

class _AppointmentBookingNewScreenState
    extends State<AppointmentBookingNewScreen> with TickerProviderStateMixin {
  String? selectedSpecialty;
  String? selectedHospital;
  UserModel? selectedDoctor;
  DateTime? selectedDate;
  String? selectedTime;
  String? selectedReason;
  bool isLoading = false;

  List<UserModel> availableDoctors = [];
  List<String> availableTimeSlots = [];
  List<String> availableHospitals = [];
  List<String> allSpecialtiesList = [];
  List<UserModel> allHospitalsList = [];

  // Booked appointments
  List<AppointmentModel> _bookedAppointments = [];
  bool _loadingAppointments = true;

  // Tab controller
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadInitialData();
    _loadBookedAppointments();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    try {
      setState(() => isLoading = true);

      // Load specialties and hospitals
      final specialties = await ApiService.getSpecialties();
      final hospitals = await ApiService.getHospitals();

      setState(() {
        allSpecialtiesList = specialties;
        allHospitalsList = hospitals;
        availableHospitals =
            hospitals.map((h) => h.hospitalName ?? 'Unknown').toList();
      });
    } catch (e) {
      print('❌ Error loading initial data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading data: $e')),
        );
      }
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _loadBookedAppointments() async {
    try {
      setState(() => _loadingAppointments = true);
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final appointments = await ApiService.getAppointments(user.uid);
      setState(() {
        _bookedAppointments = appointments;
        _loadingAppointments = false;
      });
    } catch (e) {
      print('❌ Error loading booked appointments: $e');
      setState(() => _loadingAppointments = false);
    }
  }

  Future<void> _loadDoctors() async {
    if (selectedSpecialty == null || selectedHospital == null) return;

    try {
      setState(() => isLoading = true);

      final hospital = allHospitalsList.firstWhere(
        (h) => h.hospitalName == selectedHospital,
        orElse: () => allHospitalsList.first,
      );

      final doctors = await ApiService.getDoctorsBySpecialtyAndHospital(
        selectedSpecialty!,
        hospital.uid,
      );

      setState(() {
        availableDoctors = doctors;
      });
    } catch (e) {
      print('❌ Error loading doctors: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading doctors: $e')),
        );
      }
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _loadTimeSlots() async {
    if (selectedDoctor == null || selectedDate == null) return;

    try {
      setState(() => isLoading = true);

      final dateString = DateFormat('yyyy-MM-dd').format(selectedDate!);
      print(
          '🕐 Loading time slots for doctor: ${selectedDoctor!.uid}, date: $dateString');

      // Resolve hospital Mongo ID (backend filter expects Mongo ID)
      String? hospitalIdParam;
      try {
        final hospital = allHospitalsList.firstWhere(
          (h) => (h.hospitalName ?? '') == (selectedHospital ?? ''),
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
              type: 'hospital',
              createdAt: DateTime.now()),
        );
        if (hospital.uid.isNotEmpty) {
          hospitalIdParam = await ApiService.getHospitalMongoId(hospital.uid);
        }
      } catch (_) {}

      final timeSlots = await ApiService.getAvailableTimeSlots(
        selectedDoctor!.uid,
        dateString,
        hospitalId: hospitalIdParam,
      );

      print('✅ Loaded ${timeSlots.length} time slots: $timeSlots');
      print('🔍 API Response details: ' +
          jsonEncode({
            'doctorId': selectedDoctor!.uid,
            'date': dateString,
            'hospitalId': hospitalIdParam,
            'timeSlotsCount': timeSlots.length,
            'timeSlots': timeSlots
          }));

      setState(() {
        availableTimeSlots = timeSlots;
      });

      // Show a toast/snackbar if no slots available for the selected hospital/date
      if (mounted && (timeSlots.isEmpty)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'No slots available for this date at the selected hospital'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      print('❌ Error loading time slots: $e');

      // Fallback: Use default time slots if API fails
      print('🔄 Using fallback time slots');
      const fallbackSlots = [
        '09:00',
        '09:30',
        '10:00',
        '10:30',
        '11:00',
        '11:30',
        '14:00',
        '14:30',
        '15:00',
        '15:30',
        '16:00',
        '16:30'
      ];

      setState(() {
        availableTimeSlots = fallbackSlots;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('Using default time slots (API temporarily unavailable)'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _bookAppointment() async {
    if (selectedDoctor == null ||
        selectedDate == null ||
        selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select all required fields')),
      );
      return;
    }

    try {
      setState(() => isLoading = true);

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final appointmentData = {
        'doctorId': selectedDoctor!.uid,
        'doctorName': selectedDoctor!.fullName,
        'patientId': user.uid,
        'patientName': user.displayName ?? 'Unknown',
        'patientPhone': user.phoneNumber ?? '',
        'dateTime': DateTime(
          selectedDate!.year,
          selectedDate!.month,
          selectedDate!.day,
          int.parse(selectedTime!.split(':')[0]),
          int.parse(selectedTime!.split(':')[1]),
        ).toIso8601String(),
        'reason': selectedReason ?? 'General consultation',
        'status': 'scheduled',
      };

      await ApiService.createAppointment(appointmentData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Appointment booked successfully!'),
            backgroundColor: Colors.green,
          ),
        );

        // Reset form
        setState(() {
          selectedDoctor = null;
          selectedDate = null;
          selectedTime = null;
          selectedReason = null;
          availableTimeSlots = [];
        });

        // Refresh appointments
        _loadBookedAppointments();

        // Switch to My Appointments tab
        _tabController.animateTo(1);
      }
    } catch (e) {
      print('❌ Error booking appointment: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error booking appointment: $e')),
        );
      }
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Book Appointment',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF32CCBC),
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Book Appointment'),
            Tab(text: 'My Appointments'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildBookingTab(),
          _buildMyAppointmentsTab(),
        ],
      ),
      floatingActionButton: const ChatArcFloatingButton(),
    );
  }

  Widget _buildBookingTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Specialty Selection
          _buildSectionTitle('Select Specialty'),
          _buildSpecialtyDropdown(),
          const SizedBox(height: 20),

          // Hospital Selection
          _buildSectionTitle('Select Hospital'),
          _buildHospitalDropdown(),
          const SizedBox(height: 20),

          // Doctor Selection
          if (selectedSpecialty != null && selectedHospital != null) ...[
            _buildSectionTitle('Select Doctor'),
            _buildDoctorSelection(),
            const SizedBox(height: 20),
          ],

          // Date Selection
          if (selectedDoctor != null) ...[
            _buildSectionTitle('Select Date'),
            _buildDateSelection(),
            const SizedBox(height: 20),
          ],

          // Time Selection
          if (selectedDate != null) ...[
            _buildSectionTitle('Select Time'),
            _buildTimeSelection(),
            const SizedBox(height: 20),
          ],

          // Reason Input
          if (selectedTime != null) ...[
            _buildSectionTitle('Reason for Visit'),
            _buildReasonInput(),
            const SizedBox(height: 20),
          ],

          // Book Button
          if (selectedTime != null) ...[
            _buildBookButton(),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.poppins(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: const Color(0xFF2C3E50),
      ),
    );
  }

  Widget _buildSpecialtyDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
        color: Colors.white,
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selectedSpecialty,
          hint: const Text('Choose specialty'),
          isExpanded: true,
          items: allSpecialtiesList.map((specialty) {
            return DropdownMenuItem(
              value: specialty,
              child: Text(specialty),
            );
          }).toList(),
          onChanged: (value) {
            setState(() {
              selectedSpecialty = value;
              selectedHospital = null;
              selectedDoctor = null;
              selectedDate = null;
              selectedTime = null;
              availableTimeSlots = [];
            });
            _loadDoctors();
          },
        ),
      ),
    );
  }

  Widget _buildHospitalDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
        color: Colors.white,
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selectedHospital,
          hint: const Text('Choose hospital'),
          isExpanded: true,
          items: availableHospitals.map((hospital) {
            return DropdownMenuItem(
              value: hospital,
              child: Text(hospital),
            );
          }).toList(),
          onChanged: (value) {
            setState(() {
              selectedHospital = value;
              selectedDoctor = null;
              selectedDate = null;
              selectedTime = null;
              availableTimeSlots = [];
            });
            _loadDoctors();
          },
        ),
      ),
    );
  }

  Widget _buildDoctorSelection() {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (availableDoctors.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: const Text(
            'No doctors available for selected specialty and hospital'),
      );
    }

    return Column(
      children: availableDoctors.map((doctor) {
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: const Color(0xFF32CCBC),
              child: Text(
                doctor.fullName?.substring(0, 1).toUpperCase() ?? 'D',
                style: const TextStyle(color: Colors.white),
              ),
            ),
            title: Text(doctor.fullName ?? 'Unknown Doctor'),
            subtitle: Text(doctor.specialization ?? 'General Practice'),
            trailing: selectedDoctor?.uid == doctor.uid
                ? const Icon(Icons.check_circle, color: Color(0xFF32CCBC))
                : null,
            onTap: () {
              setState(() {
                selectedDoctor = doctor;
                selectedDate = null;
                selectedTime = null;
                availableTimeSlots = [];
              });
            },
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDateSelection() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFF32CCBC), width: 2),
        borderRadius: BorderRadius.circular(8),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF32CCBC).withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: () async {
          print('📅 Date picker tapped');
          final date = await showDatePicker(
            context: context,
            initialDate: DateTime.now().add(const Duration(days: 1)),
            firstDate: DateTime.now(),
            lastDate: DateTime.now().add(const Duration(days: 30)),
            builder: (context, child) {
              return Theme(
                data: Theme.of(context).copyWith(
                  colorScheme: const ColorScheme.light(
                    primary: Color(0xFF32CCBC),
                    onPrimary: Colors.white,
                    surface: Colors.white,
                    onSurface: Colors.black,
                  ),
                ),
                child: child!,
              );
            },
          );
          if (date != null) {
            print('📅 Date selected: $date');
            setState(() {
              selectedDate = date;
              selectedTime = null;
              availableTimeSlots = [];
            });
            _loadTimeSlots();
          }
        },
        child: Row(
          children: [
            const Icon(Icons.calendar_today,
                color: Color(0xFF32CCBC), size: 24),
            const SizedBox(width: 12),
            Text(
              selectedDate != null
                  ? DateFormat('MMM dd, yyyy').format(selectedDate!)
                  : 'Tap to select date',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: selectedDate != null
                    ? Colors.black87
                    : const Color(0xFF32CCBC),
              ),
            ),
            const Spacer(),
            const Icon(Icons.arrow_drop_down, color: Color(0xFF32CCBC)),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeSelection() {
    if (isLoading) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Color(0xFF32CCBC)),
            SizedBox(width: 12),
            Text('Loading time slots...'),
          ],
        ),
      );
    }

    if (availableTimeSlots.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.orange[50],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.orange[300]!),
        ),
        child: Column(
          children: [
            Icon(Icons.schedule, color: Colors.orange[600], size: 32),
            const SizedBox(height: 8),
            Text(
              'No time slots available for selected date',
              style: GoogleFonts.poppins(
                fontSize: 16,
                color: Colors.orange[800],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Please select a different date or contact the doctor',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.orange[600],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.schedule, color: Colors.green[600], size: 20),
              const SizedBox(width: 8),
              Text(
                'Available Time Slots (${availableTimeSlots.length})',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.green[800],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: availableTimeSlots.map((time) {
              final isSelected = selectedTime == time;
              return InkWell(
                onTap: () {
                  print('🕐 Time selected: $time');
                  setState(() {
                    selectedTime = time;
                  });
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFF32CCBC) : Colors.white,
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFF32CCBC)
                          : Colors.green[300]!,
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(25),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: const Color(0xFF32CCBC).withOpacity(0.3),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Text(
                    time,
                    style: GoogleFonts.poppins(
                      color: isSelected ? Colors.white : Colors.green[800],
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildReasonInput() {
    return TextField(
      decoration: InputDecoration(
        hintText: 'Enter reason for visit (optional)',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        filled: true,
        fillColor: Colors.grey[50],
      ),
      onChanged: (value) {
        selectedReason = value;
      },
    );
  }

  Widget _buildBookButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: isLoading ? null : _bookAppointment,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF32CCBC),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: isLoading
            ? const CircularProgressIndicator(color: Colors.white)
            : Text(
                'Book Appointment',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }

  Widget _buildMyAppointmentsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'My Appointments',
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF2C3E50),
                ),
              ),
              IconButton(
                onPressed: _loadBookedAppointments,
                icon: const Icon(
                  Icons.refresh,
                  color: Color(0xFF32CCBC),
                ),
                tooltip: 'Refresh appointments',
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Appointments List
          if (_loadingAppointments)
            const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF32CCBC),
              ),
            )
          else if (_bookedAppointments.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.event_available,
                    size: 48,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No appointments booked yet',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Switch to "Book Appointment" tab to schedule',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            )
          else
            ..._bookedAppointments
                .map((appointment) => _buildAppointmentCard(appointment)),
        ],
      ),
    );
  }

  Widget _buildAppointmentCard(AppointmentModel appointment) {
    final appointmentDate = appointment.dateTime;
    final statusColor = _getStatusColor(appointment.status);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  appointment.doctorName ?? 'Unknown Doctor',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF2C3E50),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: statusColor),
                  ),
                  child: Text(
                    appointment.status.toUpperCase(),
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              DateFormat('MMM dd, yyyy • hh:mm a').format(appointmentDate),
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            if (appointment.reason != null) ...[
              const SizedBox(height: 8),
              Text(
                'Reason: ${appointment.reason}',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey[700],
                ),
              ),
            ],
            const SizedBox(height: 12),
            // Cancel button for scheduled appointments
            if (appointment.status.toLowerCase() == 'scheduled') ...[
              // Only show cancel button if appointment is not completed
              if (appointment.status.toLowerCase() != 'completed')
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => _cancelAppointment(appointment),
                      icon: const Icon(Icons.cancel, size: 16),
                      label: const Text('Cancel'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                      ),
                    ),
                  ],
                ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _cancelAppointment(AppointmentModel appointment) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Appointment'),
        content: Text(
            'Are you sure you want to cancel your appointment with ${appointment.doctorName}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Yes, Cancel'),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      setState(() => isLoading = true);

      // Call the cancel appointment API
      final result = await ApiService.cancelAppointment(appointment.id);

      if (result['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Appointment cancelled successfully'),
              backgroundColor: Colors.green,
            ),
          );

          // Refresh appointments list
          _loadBookedAppointments();
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['error'] ?? 'Failed to cancel appointment'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      print('❌ Error cancelling appointment: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error cancelling appointment: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => isLoading = false);
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return Colors.green;
      case 'consultation_completed':
        return Colors.orange;
      case 'cancelled':
        return Colors.red;
      case 'rescheduled':
        return Colors.orange;
      default:
        return Colors.blue;
    }
  }
}
