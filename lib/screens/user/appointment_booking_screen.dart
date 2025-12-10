import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:arcular_plus/widgets/chatarc_floating_button.dart';
import 'package:arcular_plus/services/api_service.dart';
import 'package:arcular_plus/services/fcm_service.dart';
import 'package:arcular_plus/models/user_model.dart';
import 'package:arcular_plus/models/appointment_model.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:arcular_plus/screens/user/provider_rating_screen.dart';
import 'dart:math' as math;

class AppointmentBookingScreen extends StatefulWidget {
  const AppointmentBookingScreen({super.key});

  @override
  State<AppointmentBookingScreen> createState() =>
      _AppointmentBookingScreenState();
}

class _AppointmentBookingScreenState extends State<AppointmentBookingScreen>
    with TickerProviderStateMixin {
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

  // Location-based features
  double? userLatitude;
  double? userLongitude;
  bool isGettingLocation = false;
  bool sortByDistance = true;

  // Local notifications
  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  // Booked appointments
  List<AppointmentModel> _bookedAppointments = [];
  bool _loadingAppointments = true;

  String _safeInitials(String fullName) {
    if (fullName.trim().isEmpty) return '?';
    final parts = fullName
        .trim()
        .split(RegExp(r"\s+"))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    final chars = parts.take(2).map((p) => p.characters.first).join();
    return chars.toUpperCase();
  }

  // Tab controller
  late TabController _tabController;

  // Dynamic specialties/hospitals are computed from backend doctors
  // Comprehensive list of medical specialties
  final List<String> allSpecialties = [
    'Cardiology',
    'Neurology',
    'Orthopedics',
    'Pediatrics',
    'Gynecology',
    'Oncology',
    'Dermatology',
    'Psychiatry',
    'Emergency Medicine',
    'General Surgery',
    'Internal Medicine',
    'Radiology',
    'Pathology',
    'Anesthesiology',
    'ENT',
    'Ophthalmology',
    'Urology',
    'Nephrology',
    'Gastroenterology',
    'Pulmonology',
    'Endocrinology',
    'Rheumatology',
    'Hematology',
    'Infectious Disease',
    'Physical Medicine',
    'Plastic Surgery',
    'Vascular Surgery',
    'Thoracic Surgery',
    'Neurosurgery',
    'Cardiothoracic Surgery',
    'General Practice',
    'Family Medicine',
    'Geriatrics',
    'Sports Medicine',
    'Occupational Medicine',
    'Preventive Medicine',
    'Public Health',
    'Community Medicine',
    'Forensic Medicine',
    'Alternative Medicine',
    'Allergy and Immunology',
    'Critical Care Medicine',
    'Pain Management',
    'Sleep Medicine',
    'Travel Medicine',
    'Tropical Medicine',
    'Nuclear Medicine',
    'Radiation Oncology',
    'Medical Oncology',
    'Surgical Oncology',
    'Pediatric Surgery',
    'Pediatric Cardiology',
    'Pediatric Neurology',
    'Pediatric Oncology',
    'Pediatric Endocrinology',
    'Maternal-Fetal Medicine',
    'Reproductive Endocrinology',
    'Gynecologic Oncology',
    'Minimally Invasive Surgery',
    'Robotic Surgery',
    'Laparoscopic Surgery',
    'Microsurgery',
    'Transplant Surgery',
    'Hand Surgery',
    'Foot and Ankle Surgery',
    'Spine Surgery',
    'Joint Replacement Surgery',
    'Sports Orthopedics',
    'Pediatric Orthopedics',
    'Trauma Surgery',
    'Burn Surgery',
    'Cosmetic Surgery',
    'Reconstructive Surgery',
    'Craniofacial Surgery',
    'Oral and Maxillofacial Surgery',
    'Head and Neck Surgery',
    'Laryngology',
    'Rhinology',
    'Otology',
    'Neurotology',
    'Pediatric ENT',
    'Cornea and External Disease',
    'Retina and Vitreous',
    'Glaucoma',
    'Pediatric Ophthalmology',
    'Oculoplastic Surgery',
    'Neuro-Ophthalmology',
    'Uveitis',
    'Pediatric Urology',
    'Female Urology',
    'Urologic Oncology',
    'Andrology',
    'Infertility',
    'Sexual Medicine',
    'Pediatric Nephrology',
    'Transplant Nephrology',
  ];

  final List<String> reasons = [
    'General Checkup',
    'Follow-up',
    'Consultation',
    'Emergency',
    'Routine Visit',
    'Vaccination',
    'Lab Test',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initializeNotifications();
    _getCurrentLocation();
    _loadAllData();
    _loadBookedAppointments();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // Initialize local notifications
  Future<void> _initializeNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    await _notifications.initialize(initializationSettings);
  }

  // Load booked appointments
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

  // Build My Appointments Tab
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
                icon: Icon(
                  Icons.refresh,
                  color: const Color(0xFF32CCBC),
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

  // Build individual appointment card
  Widget _buildAppointmentCard(AppointmentModel appointment) {
    final now = DateTime.now();
    final appointmentDate = appointment.dateTime;
    final isUpcoming = appointmentDate.isAfter(now) &&
        appointment.status.toLowerCase() != 'completed' &&
        appointment.status.toLowerCase() != 'cancelled';
    final isToday = appointmentDate.day == now.day &&
        appointmentDate.month == now.month &&
        appointmentDate.year == now.year;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: appointment.status.toLowerCase() == 'completed'
            ? Colors.green.shade50
            : isToday
                ? const Color(0xFFE8F5E8)
                : Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: appointment.status.toLowerCase() == 'completed'
              ? Colors.green.shade200
              : isToday
                  ? const Color(0xFF32CCBC)
                  : Colors.grey[300]!,
          width: appointment.status.toLowerCase() == 'completed' || isToday
              ? 2
              : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.medical_services,
                  color: const Color(0xFF32CCBC),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Dr. ${appointment.doctorName}',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF2C3E50),
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: appointment.status.toLowerCase() == 'completed'
                        ? Colors.green
                        : isUpcoming
                            ? const Color(0xFF32CCBC)
                            : Colors.grey[400],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    appointment.status,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Booking ID
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.confirmation_number,
                    size: 14,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'ID: ${appointment.appointmentId ?? appointment.id}',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[700],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            if (appointment.hospitalName != null) ...[
              Row(
                children: [
                  Icon(
                    Icons.local_hospital,
                    size: 16,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      appointment.hospitalName!,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Doctor Contact Information
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
                    Text(
                      'Doctor Contact',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.green[800],
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (appointment.doctorEmail != null) ...[
                      Row(
                        children: [
                          Icon(
                            Icons.email,
                            size: 14,
                            color: Colors.green[600],
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              appointment.doctorEmail!,
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: Colors.green[700],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                    ],
                    if (appointment.doctorPhone != null) ...[
                      Row(
                        children: [
                          Icon(
                            Icons.phone,
                            size: 14,
                            color: Colors.green[600],
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              appointment.doctorPhone!,
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: Colors.green[700],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ] else ...[
                      // Fallback contact info
                      Row(
                        children: [
                          Icon(
                            Icons.phone,
                            size: 14,
                            color: Colors.green[600],
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Contact hospital for doctor details',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: Colors.green[700],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
            Row(
              children: [
                Icon(
                  Icons.access_time,
                  size: 16,
                  color: Colors.grey[600],
                ),
                const SizedBox(width: 8),
                Text(
                  DateFormat('MMM d, y • HH:mm').format(appointmentDate),
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            if (appointment.reason != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 16,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      appointment.reason!,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            // Show action buttons based on appointment status
            if (appointment.status.toLowerCase() == 'completed')
              // Rating button for completed appointments
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _rateProvider(appointment),
                  icon: const Icon(Icons.star, size: 16),
                  label: Text(
                    'Rate Your Visit',
                    style: GoogleFonts.poppins(fontSize: 12),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF32CCBC),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              )
            else if (appointment.status.toLowerCase() != 'completed')
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: isUpcoming
                          ? () => _cancelAppointment(appointment)
                          : null,
                      icon: const Icon(Icons.cancel_outlined, size: 16),
                      label: Text(
                        'Cancel',
                        style: GoogleFonts.poppins(fontSize: 12),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red[600],
                        side: BorderSide(color: Colors.red[300]!),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _showRescheduleInfo(appointment),
                      icon: const Icon(Icons.schedule, size: 16),
                      label: Text(
                        'Reschedule',
                        style: GoogleFonts.poppins(fontSize: 12),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF32CCBC),
                        side: const BorderSide(color: Color(0xFF32CCBC)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
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
  }

  // Cancel appointment
  Future<void> _cancelAppointment(AppointmentModel appointment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Cancel Appointment',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        content: Text(
          'Are you sure you want to cancel your appointment with Dr. ${appointment.doctorName} on ${DateFormat('MMM d, y • HH:mm').format(appointment.dateTime)}?',
          style: GoogleFonts.poppins(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'No',
              style: GoogleFonts.poppins(color: Colors.grey[600]),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              'Yes, Cancel',
              style: GoogleFonts.poppins(color: Colors.red[600]),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        // Show loading indicator
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: CircularProgressIndicator(
              color: Color(0xFF32CCBC),
            ),
          ),
        );

        // Call API to cancel appointment
        final result = await ApiService.cancelAppointment(appointment.id);

        // Close loading dialog
        Navigator.of(context).pop();

        if (result['success'] == true) {
          // Remove from local list
          setState(() {
            _bookedAppointments.removeWhere((apt) => apt.id == appointment.id);
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Appointment cancelled successfully',
                style: GoogleFonts.poppins(),
              ),
              backgroundColor: Colors.green[600],
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                result['error'] ?? 'Failed to cancel appointment',
                style: GoogleFonts.poppins(),
              ),
              backgroundColor: Colors.red[600],
            ),
          );
        }
      } catch (e) {
        // Close loading dialog if still open
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to cancel appointment: $e',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.red[600],
          ),
        );
      }
    }
  }

  // Show reschedule information
  void _showRescheduleInfo(AppointmentModel appointment) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Reschedule Appointment',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'To reschedule your appointment with Dr. ${appointment.doctorName}, please contact the hospital directly:',
              style: GoogleFonts.poppins(),
            ),
            const SizedBox(height: 16),
            if (appointment.hospitalName != null) ...[
              Row(
                children: [
                  Icon(Icons.local_hospital,
                      size: 20, color: const Color(0xFF32CCBC)),
                  const SizedBox(width: 8),
                  Text(
                    appointment.hospitalName!,
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(height: 16),
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
                    Text(
                      'Doctor Contact Details:',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        color: Colors.green[800],
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (appointment.doctorPhone != null) ...[
                      Row(
                        children: [
                          Icon(Icons.phone, size: 16, color: Colors.green[600]),
                          const SizedBox(width: 8),
                          Text(
                            appointment.doctorPhone!,
                            style: GoogleFonts.poppins(
                              color: Colors.green[700],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                    ],
                    if (appointment.doctorEmail != null) ...[
                      Row(
                        children: [
                          Icon(Icons.email, size: 16, color: Colors.green[600]),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              appointment.doctorEmail!,
                              style: GoogleFonts.poppins(
                                color: Colors.green[700],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ] else ...[
                      Text(
                        'Contact hospital reception for rescheduling',
                        style: GoogleFonts.poppins(
                          color: Colors.green[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Text(
                'Note: Rescheduling requires hospital approval and may be subject to availability.',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.blue[800],
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Got it',
              style: GoogleFonts.poppins(color: const Color(0xFF32CCBC)),
            ),
          ),
        ],
      ),
    );
  }

  // Rate provider after completed appointment
  void _rateProvider(AppointmentModel appointment) {
    // Show dialog to choose which provider to rate
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Rate Your Visit',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Which provider would you like to rate?',
              style: GoogleFonts.poppins(),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.person, color: Color(0xFF32CCBC)),
              title: Text('Dr. ${appointment.doctorName}'),
              subtitle: const Text('Doctor'),
              trailing: FutureBuilder<Map<String, dynamic>?>(
                future: _getExistingRating(
                  appointment.appointmentId ?? appointment.id,
                  'doctor',
                  appointment.doctorId,
                ),
                builder: (context, snapshot) {
                  if (snapshot.hasData && snapshot.data != null) {
                    return const Icon(Icons.star,
                        color: Colors.amber, size: 20);
                  }
                  return const Icon(Icons.star_border,
                      color: Colors.grey, size: 20);
                },
              ),
              onTap: () {
                Navigator.pop(context);
                _navigateToRatingScreen(
                  appointment,
                  'doctor',
                  appointment.doctorId,
                  appointment.doctorName,
                );
              },
            ),
            if (appointment.hospitalId != null &&
                appointment.hospitalName != null)
              ListTile(
                leading:
                    const Icon(Icons.local_hospital, color: Color(0xFF32CCBC)),
                title: Text(appointment.hospitalName!),
                subtitle: const Text('Hospital'),
                trailing: FutureBuilder<Map<String, dynamic>?>(
                  future: _getExistingRating(
                    appointment.appointmentId ?? appointment.id,
                    'hospital',
                    appointment.hospitalId!,
                  ),
                  builder: (context, snapshot) {
                    if (snapshot.hasData && snapshot.data != null) {
                      return const Icon(Icons.star,
                          color: Colors.amber, size: 20);
                    }
                    return const Icon(Icons.star_border,
                        color: Colors.grey, size: 20);
                  },
                ),
                onTap: () {
                  Navigator.pop(context);
                  _navigateToRatingScreen(
                    appointment,
                    'hospital',
                    appointment.hospitalId,
                    appointment.hospitalName,
                  );
                },
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(color: Colors.grey[600]),
            ),
          ),
        ],
      ),
    );
  }

  // Check if provider is already rated
  Future<Map<String, dynamic>?> _getExistingRating(
    String appointmentId,
    String providerType,
    String providerId,
  ) async {
    try {
      final ratings = await ApiService.getUserProviderRatings(
        appointmentId: appointmentId,
        providerType: providerType,
        providerId: providerId,
      );

      // Return the first rating found (should be only one for this combination)
      if (ratings.isNotEmpty) {
        return ratings.first;
      }
      return null;
    } catch (e) {
      print('❌ Error checking existing rating: $e');
      return null;
    }
  }

  // Navigate to rating screen with specific provider details
  void _navigateToRatingScreen(
    AppointmentModel appointment,
    String providerType,
    String? providerId,
    String? providerName,
  ) async {
    if (providerId == null || providerName == null) return;

    final appointmentId = appointment.appointmentId ?? appointment.id;

    // Check if already rated
    final existingRating = await _getExistingRating(
      appointmentId,
      providerType,
      providerId,
    );

    if (existingRating != null) {
      // Show existing rating dialog
      _showExistingRatingDialog(existingRating, providerName, providerType);
    } else {
      // Navigate to rating screen
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ProviderRatingScreen(
            appointmentId: appointmentId,
            providerType: providerType,
            providerId: providerId,
            providerName: providerName,
          ),
        ),
      );
    }
  }

  // Show existing rating dialog
  void _showExistingRatingDialog(
    Map<String, dynamic> rating,
    String providerName,
    String providerType,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Your Rating for $providerName',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Rating: ',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
                ...List.generate(5, (index) {
                  return Icon(
                    index < rating['rating'] ? Icons.star : Icons.star_border,
                    color: Colors.amber,
                    size: 20,
                  );
                }),
                Text(' (${rating['rating']}/5)', style: GoogleFonts.poppins()),
              ],
            ),
            if (rating['review']?.isNotEmpty == true) ...[
              const SizedBox(height: 12),
              Text('Review:',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
              const SizedBox(height: 4),
              Text(
                rating['review'],
                style: GoogleFonts.poppins(),
              ),
            ],
            const SizedBox(height: 12),
            Text(
              'You have already rated this ${providerType}.',
              style: GoogleFonts.poppins(color: Colors.grey[600]),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Close',
              style: GoogleFonts.poppins(color: const Color(0xFF32CCBC)),
            ),
          ),
        ],
      ),
    );
  }

  // Location capture methods
  Future<void> _getCurrentLocation() async {
    setState(() => isGettingLocation = true);

    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showLocationError(
            'Location services are disabled. Please enable location services.');
        return;
      }

      // Check location permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showLocationError(
              'Location permissions are denied. Please enable location permissions.');
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _showLocationError(
            'Location permissions are permanently denied. Please enable them in settings.');
        return;
      }

      // Get current position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      setState(() {
        userLatitude = position.latitude;
        userLongitude = position.longitude;
        isGettingLocation = false;
      });

      // Reload doctors with location-based sorting
      _loadDoctors();
    } catch (e) {
      setState(() => isGettingLocation = false);
      _showLocationError('Failed to get location: $e');
    }
  }

  void _showLocationError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.orange,
        action: SnackBarAction(
          label: 'Retry',
          textColor: Colors.white,
          onPressed: _getCurrentLocation,
        ),
      ),
    );
  }

  // Calculate distance between two coordinates (Haversine formula)
  double _calculateDistance(
      double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371; // Earth's radius in kilometers
    final double dLat = _toRadians(lat2 - lat1);
    final double dLon = _toRadians(lon2 - lon1);

    final double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) *
            math.cos(_toRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);

    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }

  double _toRadians(double degrees) {
    return degrees * (math.pi / 180);
  }

  // Sort doctors by distance if location is available
  List<UserModel> _sortDoctorsByDistance(List<UserModel> doctors) {
    if (!sortByDistance || userLatitude == null || userLongitude == null) {
      return doctors;
    }

    final doctorDistanceList = doctors.map((doctor) {
      double? distance;
      if (doctor.latitude != null && doctor.longitude != null) {
        distance = _calculateDistance(
          userLatitude!,
          userLongitude!,
          doctor.latitude!,
          doctor.longitude!,
        );
      }
      return {
        'doctor': doctor,
        'distance': distance,
      };
    }).toList();

    doctorDistanceList.sort((a, b) {
      final double? distA = a['distance'] as double?;
      final double? distB = b['distance'] as double?;

      // Put doctors without location at the end
      if (distA == null && distB == null) return 0;
      if (distA == null) return 1;
      if (distB == null) return -1;

      return distA.compareTo(distB);
    });

    return doctorDistanceList
        .map((item) => item['doctor'] as UserModel)
        .toList();
  }

  Future<void> _loadAllData() async {
    setState(() => isLoading = true);
    try {
      print('🔍 Loading appointment booking data...');

      // Load all data in parallel
      final results = await Future.wait([
        ApiService.getAllDoctors(),
        ApiService.getAllSpecialties(),
        ApiService.getAllHospitals(),
      ]);

      final doctors = results[0] as List<UserModel>;
      final specialties = results[1] as List<String>;
      final hospitals = results[2] as List<UserModel>;

      print('📊 Loaded data:');
      print('  - Doctors: ${doctors.length}');
      print('  - Specialties: ${specialties.length}');
      print('  - Hospitals: ${hospitals.length}');
      print('  - Specialties list: $specialties');

      // Debug: Check specifically for Cardiology
      print('🔍 Checking for Cardiology specialty:');
      print('  - In specialties list: ${specialties.contains('Cardiology')}');
      final cardiologyDoctors = doctors
          .where((d) =>
              d.specialization?.toLowerCase() == 'cardiology' ||
              (d.specializations?.any((s) => s.toLowerCase() == 'cardiology') ??
                  false))
          .toList();
      print('  - Cardiology doctors found: ${cardiologyDoctors.length}');
      for (final doctor in cardiologyDoctors) {
        print('    - ${doctor.fullName} (${doctor.specialization})');
      }

      // Debug: Show sample doctors and their affiliations
      print('👨‍⚕️ Sample doctors:');
      for (int i = 0; i < doctors.length && i < 3; i++) {
        final doctor = doctors[i];
        print('  ${i + 1}. ${doctor.fullName}');
        print('     - Specialization: ${doctor.specialization}');
        print('     - Specializations: ${doctor.specializations}');
        print('     - Hospital Affiliation: ${doctor.hospitalAffiliation}');
        print('     - Affiliated Hospitals: ${doctor.affiliatedHospitals}');
      }

      // Debug: Check for doctors with Internal Medicine specifically
      print('🔍 Checking for Internal Medicine doctors:');
      final internalMedicineDoctors = doctors.where((doctor) {
        final hasPrimary = doctor.specialization == 'Internal Medicine';
        final hasInArray = doctor.specializations != null &&
            doctor.specializations!.contains('Internal Medicine');
        return hasPrimary || hasInArray;
      }).toList();
      print(
          '  Found ${internalMedicineDoctors.length} Internal Medicine doctors');
      for (final doctor in internalMedicineDoctors) {
        print(
            '    - ${doctor.fullName} (Primary: ${doctor.specialization}, Array: ${doctor.specializations})');
      }

      // Debug: Show sample hospitals
      print('🏥 Sample hospitals:');
      for (int i = 0; i < hospitals.length && i < 3; i++) {
        final hospital = hospitals[i];
        print(
            '  ${i + 1}. ${hospital.hospitalName} (Approved: ${hospital.isApproved})');
      }

      final sortedDoctors = _sortDoctorsByDistance(doctors);

      setState(() {
        availableDoctors = sortedDoctors;
        allSpecialtiesList =
            specialties.isNotEmpty ? specialties : allSpecialties;
        allHospitalsList = hospitals;
        isLoading = false;

        print('📋 Final specialties: ${_specialties.length}');
        print('📋 Final hospitals: ${allHospitalsList.length}');

        // Reset selections if they no longer exist
        if (selectedSpecialty != null &&
            !_specialties.contains(selectedSpecialty)) {
          selectedSpecialty = null;
          selectedHospital = null;
          selectedDoctor = null;
          selectedTime = null;
        }
      });
    } catch (e) {
      print('❌ Error loading appointment data: $e');
      setState(() => isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load data: $e')),
        );
      }
    }
  }

  Future<void> _loadDoctors() async {
    setState(() => isLoading = true);
    try {
      final doctors = await ApiService.getAllDoctors();
      final sortedDoctors = _sortDoctorsByDistance(doctors);
      setState(() {
        availableDoctors = sortedDoctors;
        isLoading = false;
        // Reset selections if they no longer exist
        if (selectedSpecialty != null &&
            !_specialties.contains(selectedSpecialty)) {
          selectedSpecialty = null;
          selectedHospital = null;
          selectedDoctor = null;
          selectedTime = null;
        }
      });
    } catch (e) {
      setState(() => isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load doctors: $e')),
        );
      }
    }
  }

  Future<void> _loadAvailableTimeSlots() async {
    if (selectedDoctor == null || selectedDate == null) return;

    setState(() => isLoading = true);
    try {
      final dateString = DateFormat('yyyy-MM-dd').format(selectedDate!);
      print(
          '🔍 Loading time slots for doctor: ${selectedDoctor!.uid}, date: $dateString');

      // Resolve hospital MongoDB ID (backend expects Mongo ID for hospital filter)
      String? hospitalIdParam;
      try {
        final h = selectedHospital;
        String? hospitalUid;
        if (h is String) {
          hospitalUid = h;
        } else if (h != null) {
          try {
            hospitalUid = (h as dynamic).uid as String?;
          } catch (_) {}
          if (hospitalUid == null) {
            try {
              hospitalUid = (h as dynamic)['uid'] as String?;
            } catch (_) {}
          }
        }
        if (hospitalUid != null && hospitalUid.isNotEmpty) {
          hospitalIdParam = await ApiService.getHospitalMongoId(hospitalUid);
        }
      } catch (_) {}

      final timeSlots = await ApiService.getAvailableTimeSlots(
        selectedDoctor!.uid,
        dateString,
        hospitalId: hospitalIdParam,
      );

      print('✅ Loaded ${timeSlots.length} time slots: $timeSlots');
      setState(() {
        availableTimeSlots = timeSlots;
        isLoading = false;
      });
    } catch (e) {
      print('❌ Error loading time slots: $e');
      setState(() => isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load time slots: $e')),
        );
      }
    }
  }

  Future<void> _bookAppointment() async {
    if (selectedDoctor == null ||
        selectedHospital == null ||
        selectedDate == null ||
        selectedTime == null ||
        selectedReason == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all required fields')),
      );
      return;
    }

    setState(() => isLoading = true);
    try {
      // Find the hospital ID for the selected hospital name
      String? hospitalId;
      if (selectedDoctor!.enhancedAffiliatedHospitals != null) {
        for (final hospital in selectedDoctor!.enhancedAffiliatedHospitals!) {
          if (hospital['hospitalName'] == selectedHospital) {
            hospitalId = hospital['hospitalId'] as String?;
            break;
          }
        }
      }

      // For now, we'll use the selected hospital name as fallback
      // The backend will resolve the actual hospital ID
      if (hospitalId == null) {
        hospitalId = selectedHospital;
      }

      final appointmentData = {
        'doctorId': selectedDoctor!.uid,
        'hospitalId': hospitalId ?? selectedDoctor!.hospitalAffiliation,
        'appointmentDate': selectedDate!.toIso8601String(),
        'appointmentTime': selectedTime!,
        'reason': selectedReason!,
        'symptoms': '',
        'medicalHistory': '',
        'appointmentType': 'consultation'
      };

      final result = await ApiService.createAppointment(appointmentData);

      if (result['success']) {
        // Get appointment details for notifications
        final appointmentId = result['data']?['appointmentId'] ??
            'APT-${DateTime.now().millisecondsSinceEpoch}';
        final doctorName = selectedDoctor!.fullName;
        final hospitalName = selectedHospital ?? 'Hospital';

        // Schedule reminder notifications using FCM service
        final fcmService = FCMService();
        await fcmService.scheduleAppointmentReminders(
          appointmentId: appointmentId,
          doctorName: doctorName,
          hospitalName: hospitalName,
          appointmentDate: selectedDate!,
          appointmentTime: selectedTime!,
          reason: selectedReason!,
        );

        // Send reminder email for the day of appointment
        await fcmService.sendAppointmentReminderEmail(
          appointmentId: appointmentId,
          doctorName: doctorName,
          hospitalName: hospitalName,
          appointmentDate: selectedDate!,
          appointmentTime: selectedTime!,
          reason: selectedReason!,
        );

        // Show success dialog with appointment details
        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 28),
                  SizedBox(width: 12),
                  Text(
                    'Appointment Booked!',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Your appointment has been successfully booked.',
                    style: GoogleFonts.poppins(fontSize: 14),
                  ),
                  SizedBox(height: 16),
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Appointment Details:',
                            style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600, fontSize: 12)),
                        SizedBox(height: 8),
                        Container(
                          padding:
                              EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.green.shade100,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.green.shade300),
                          ),
                          child: Text(
                            'Booking ID: $appointmentId',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.green.shade800,
                            ),
                          ),
                        ),
                        SizedBox(height: 8),
                        Text('Doctor: Dr. $doctorName',
                            style: GoogleFonts.poppins(fontSize: 12)),
                        Text('Hospital: $hospitalName',
                            style: GoogleFonts.poppins(fontSize: 12)),
                        Text(
                            'Date: ${DateFormat('MMM dd, yyyy').format(selectedDate!)}',
                            style: GoogleFonts.poppins(fontSize: 12)),
                        Text('Time: $selectedTime',
                            style: GoogleFonts.poppins(fontSize: 12)),
                        Text('Reason: $selectedReason',
                            style: GoogleFonts.poppins(fontSize: 12)),
                      ],
                    ),
                  ),
                  SizedBox(height: 12),
                  Text(
                    '• You will receive email confirmation\n• Reminder notifications are scheduled\n• Appointment will appear in your health summary',
                    style: GoogleFonts.poppins(
                        fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop(); // Close dialog
                    _loadBookedAppointments(); // Refresh the appointments list
                    Navigator.of(context).pop(); // Go back to previous screen
                  },
                  child: Text(
                    'Done',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      color: Colors.blue,
                    ),
                  ),
                ),
              ],
            ),
          );
        }
      } else {
        throw Exception(result['error'] ?? 'Failed to book appointment');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to book appointment: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _loadDoctorAvailability() async {
    if (selectedDoctor == null) return;

    // Load time slots when doctor is selected
    await _loadAvailableTimeSlots();
  }

  // Get all doctors for a specialty (without hospital filter)
  List<UserModel> _getDoctorsForSpecialty(String specialty) {
    print('🔍 Finding doctors for specialty: $specialty');
    print('📊 Total available doctors: ${availableDoctors.length}');

    final doctors = availableDoctors.where((doctor) {
      print('👨‍⚕️ Checking doctor: ${doctor.fullName}');
      print('  - Primary specialization: ${doctor.specialization}');
      print('  - Specializations array: ${doctor.specializations}');

      // Check primary specialization
      final matchesPrimary = (doctor.specialization != null &&
          doctor.specialization!.trim().toLowerCase() ==
              specialty.trim().toLowerCase());

      // Check specializations array
      final matchesArray = (doctor.specializations != null &&
          doctor.specializations!.isNotEmpty &&
          doctor.specializations!.any((spec) =>
              spec.trim().toLowerCase() == specialty.trim().toLowerCase()));

      final matchesSpecialty = matchesPrimary || matchesArray;

      if (!matchesSpecialty) {
        print(
            '❌ Doctor ${doctor.fullName} doesn\'t match specialty $specialty');
        print('  - Primary match: $matchesPrimary');
        print('  - Array match: $matchesArray');
        return false;
      }

      print('✅ Doctor ${doctor.fullName} matches specialty $specialty');
      print('  - Primary match: $matchesPrimary');
      print('  - Array match: $matchesArray');
      return true;
    }).toList();

    print('👨‍⚕️ Found ${doctors.length} doctors for $specialty');

    if (doctors.isEmpty) {
      print('⚠️ No doctors found for specialty: $specialty');
      print('🔍 Available specializations:');
      final allSpecs = <String>{};
      for (final doctor in availableDoctors) {
        if (doctor.specialization != null) allSpecs.add(doctor.specialization!);
        if (doctor.specializations != null)
          allSpecs.addAll(doctor.specializations!);
      }
      print('  - All specializations: ${allSpecs.toList()}');
    }

    return doctors;
  }

  // Get hospitals for selected doctor (returns hospital objects)
  List<UserModel> _getHospitalsForSelectedDoctor() {
    if (selectedDoctor == null) return [];

    print('🔍 Finding hospitals for doctor: ${selectedDoctor!.fullName}');

    final hospitalNames = _hospitalsForSelectedDoctor;
    final hospitals = <UserModel>[];

    // Find hospital objects from allHospitalsList
    for (final hospitalName in hospitalNames) {
      final hospital = allHospitalsList.firstWhere(
        (h) => h.hospitalName == hospitalName,
        orElse: () => UserModel(
          uid: '',
          fullName: hospitalName,
          email: '',
          mobileNumber: '',
          gender: '',
          dateOfBirth: DateTime.now(),
          address: '',
          pincode: '',
          city: '',
          state: '',
          type: 'hospital',
          createdAt: DateTime.now(),
          hospitalName: hospitalName,
        ),
      );
      hospitals.add(hospital);
    }

    return hospitals;
  }

  // Get hospitals for selected doctor (returns names only - kept for compatibility)
  List<String> get _hospitalsForSelectedDoctor {
    if (selectedDoctor == null) return [];

    print('🔍 Finding hospitals for doctor: ${selectedDoctor!.fullName}');
    print('  - hospitalAffiliation: ${selectedDoctor!.hospitalAffiliation}');
    print('  - affiliatedHospitals: ${selectedDoctor!.affiliatedHospitals}');
    print(
        '  - enhancedAffiliatedHospitals: ${selectedDoctor!.enhancedAffiliatedHospitals}');

    final set = <String>{};

    // Add primary hospital affiliation
    if ((selectedDoctor!.hospitalAffiliation ?? '').isNotEmpty) {
      set.add(selectedDoctor!.hospitalAffiliation!);
      print('  ✅ Added hospital: ${selectedDoctor!.hospitalAffiliation}');
    }

    // Add affiliated hospitals (handle both string and object formats)
    if (selectedDoctor!.affiliatedHospitals != null) {
      print(
          '  🔍 Processing ${selectedDoctor!.affiliatedHospitals!.length} affiliated hospitals');
      for (int i = 0; i < selectedDoctor!.affiliatedHospitals!.length; i++) {
        final hospital = selectedDoctor!.affiliatedHospitals![i];
        print('    Hospital $i: $hospital (type: ${hospital.runtimeType})');

        // Handle both string and object formats from backend
        // Note: Backend sends objects but frontend model expects strings
        try {
          final hospitalValue = hospital as dynamic;
          if (hospitalValue is String) {
            if (hospitalValue.isNotEmpty) {
              set.add(hospitalValue);
              print('  ✅ Added affiliated hospital (string): $hospitalValue');
            } else {
              print('  ❌ Empty hospital string');
            }
          } else if (hospitalValue is Map) {
            // Handle object format from backend
            final hospitalMap = hospitalValue as Map<String, dynamic>;
            print('    Hospital object keys: ${hospitalMap.keys.toList()}');
            final hospitalName = hospitalMap['hospitalName'] as String?;
            if (hospitalName != null && hospitalName.isNotEmpty) {
              set.add(hospitalName);
              print('  ✅ Added affiliated hospital (object): $hospitalName');
            } else {
              print('  ❌ Hospital object has no valid hospitalName');
            }
          } else {
            print('  ❌ Unknown hospital type: ${hospitalValue.runtimeType}');
          }
        } catch (e) {
          print('  ❌ Error processing hospital: $e');
        }
      }
    }

    // Add enhanced affiliated hospitals
    if (selectedDoctor!.enhancedAffiliatedHospitals != null) {
      for (final hospital in selectedDoctor!.enhancedAffiliatedHospitals!) {
        final hospitalName = hospital['hospitalName'] as String?;
        if (hospitalName != null && hospitalName.isNotEmpty) {
          set.add(hospitalName);
          print('  ✅ Added enhanced affiliated hospital: $hospitalName');
        }
      }
    }

    final list = set.toList()..sort();
    print(
        '🏥 Found ${list.length} hospitals for doctor ${selectedDoctor!.fullName}');
    print('🏥 Hospital list: $list');
    return list;
  }

  // Get specialties from loaded data or fallback to comprehensive list
  List<String> get _specialties {
    print('🔍 Getting specialties...');
    print('  - allSpecialtiesList: ${allSpecialtiesList.length}');
    print('  - availableDoctors: ${availableDoctors.length}');

    if (allSpecialtiesList.isNotEmpty) {
      print('✅ Using API specialties: ${allSpecialtiesList.length}');
      return allSpecialtiesList;
    }

    // Fallback: compute from doctors
    final set = <String>{};
    for (final d in availableDoctors) {
      final s = d.specialization;
      if (s != null && s.isNotEmpty) {
        set.add(s);
        print('  - Added specialization: $s');
      }
      // Also add from specializations array
      if (d.specializations != null) {
        for (final spec in d.specializations!) {
          if (spec.isNotEmpty) {
            set.add(spec);
            print('  - Added from specializations: $spec');
          }
        }
      }
    }

    // If no specialties found, use comprehensive list
    if (set.isEmpty) {
      print('⚠️ No specialties from doctors, using comprehensive list');
      return allSpecialties;
    }

    // Add any specialties from comprehensive list that aren't already included
    for (final specialty in allSpecialties) {
      set.add(specialty);
    }

    final list = set.toList()..sort();
    print('✅ Final specialties: ${list.length}');
    print('📋 Specialties: $list');
    return list;
  }

  // Get hospitals for selected specialty

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Appointments',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            if (userLatitude != null && userLongitude != null)
              Text(
                '📍 Location-based sorting enabled',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.white70,
                ),
              )
            else if (isGettingLocation)
              Text(
                '📍 Getting your location...',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.white70,
                ),
              )
            else
              Text(
                '📍 Location unavailable',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.white70,
                ),
              ),
          ],
        ),
        backgroundColor: const Color(0xFF32CCBC),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
          unselectedLabelStyle: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w400,
          ),
          tabs: const [
            Tab(
              icon: Icon(Icons.add_circle_outline),
              text: 'Book Appointment',
            ),
            Tab(
              icon: Icon(Icons.event_note),
              text: 'My Appointments',
            ),
          ],
        ),
        actions: [
          if (userLatitude != null && userLongitude != null)
            IconButton(
              icon:
                  Icon(sortByDistance ? Icons.location_on : Icons.location_off),
              onPressed: () {
                setState(() {
                  sortByDistance = !sortByDistance;
                });
                _loadAllData();
              },
              tooltip: sortByDistance
                  ? 'Disable distance sorting'
                  : 'Enable distance sorting',
            ),
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: _getCurrentLocation,
            tooltip: 'Refresh location',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAllData,
            tooltip: 'Refresh all data',
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF32CCBC), Color(0xFF90F7EC), Color(0xFFE8F5E8)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: Stack(
          children: [
            TabBarView(
              controller: _tabController,
              children: [
                // Book Appointment Tab
                SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      _buildHeader(),
                      const SizedBox(height: 24),

                      // Specialty Selection
                      _buildSpecialtySelection(),
                      const SizedBox(height: 20),

                      // Doctor Selection
                      if (selectedSpecialty != null) ...[
                        _buildDoctorSelection(),
                        const SizedBox(height: 20),
                      ],

                      // Hospital Selection
                      if (selectedSpecialty != null &&
                          selectedDoctor != null) ...[
                        _buildHospitalSelection(),
                        const SizedBox(height: 20),
                      ],

                      // Appointment Details
                      if (selectedDoctor != null &&
                          selectedHospital != null) ...[
                        _buildAppointmentDetails(),
                        const SizedBox(height: 20),
                      ],

                      // Book Appointment Button
                      _buildBookButton(),
                    ],
                  ),
                ),
                // My Appointments Tab
                _buildMyAppointmentsTab(),
              ],
            ),
            const ChatArcFloatingButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
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
            'Book Your Appointment',
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF32CCBC),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Select your preferred doctor and appointment details',
            style: GoogleFonts.poppins(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpecialtySelection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select Specialty',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF2E2E2E),
              ),
            ),
            const SizedBox(height: 12),
            _buildSearchableSpecialtyDropdown(),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchableSpecialtyDropdown() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
        color: Colors.grey[50],
      ),
      child: InkWell(
        onTap: () => _showSpecialtySearchDialog(),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.medical_services, color: Colors.grey),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  selectedSpecialty ?? 'Choose Specialty',
                  style: TextStyle(
                    fontSize: 16,
                    color: selectedSpecialty != null
                        ? Colors.black87
                        : Colors.grey[600],
                  ),
                ),
              ),
              const Icon(Icons.arrow_drop_down, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  void _showSpecialtySearchDialog() {
    showDialog(
      context: context,
      builder: (context) => _SpecialtySearchDialog(
        specialties: _specialties,
        selectedSpecialty: selectedSpecialty,
        onSpecialtySelected: (specialty) {
          setState(() {
            selectedSpecialty = specialty;
            selectedDoctor = null;
            selectedHospital = null;
            selectedTime = null;
          });

          // Debug: Show available doctors for this specialty
          final doctors = _getDoctorsForSpecialty(specialty);
          print('👨‍⚕️ Available doctors for $specialty: ${doctors.length}');
          for (final doctor in doctors) {
            print('  - ${doctor.fullName} (${doctor.specialization})');
          }
        },
      ),
    );
  }

  Widget _buildHospitalSelection() {
    final hospitals = _getHospitalsForSelectedDoctor();

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select Hospital',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF2E2E2E),
              ),
            ),
            const SizedBox(height: 12),
            if (hospitals.isEmpty)
              const Text('No hospitals available for this doctor')
            else
              ...hospitals.map((hospital) => _buildHospitalCard(hospital)),
          ],
        ),
      ),
    );
  }

  Widget _buildDoctorSelection() {
    final doctors = _getDoctorsForSpecialty(selectedSpecialty!);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select Doctor',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF2E2E2E),
              ),
            ),
            const SizedBox(height: 12),
            if (doctors.isEmpty)
              const Text('No doctors available for this specialty')
            else
              ...doctors.map((doctor) => _buildDoctorCard(doctor)),
          ],
        ),
      ),
    );
  }

  Widget _buildDoctorCard(UserModel doctor) {
    final isSelected = selectedDoctor?.uid == doctor.uid;

    // Calculate distance if location is available
    double? distance;
    if (userLatitude != null &&
        userLongitude != null &&
        doctor.latitude != null &&
        doctor.longitude != null) {
      distance = _calculateDistance(
        userLatitude!,
        userLongitude!,
        doctor.latitude!,
        doctor.longitude!,
      );
    }

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isSelected ? Colors.green : const Color(0xFF32CCBC),
          child: Text(
            _safeInitials(doctor.fullName),
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                doctor.fullName,
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              ),
            ),
            if (distance != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF32CCBC).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.location_on,
                        size: 14, color: Color(0xFF32CCBC)),
                    const SizedBox(width: 4),
                    Text(
                      '${distance.toStringAsFixed(1)} km',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF32CCBC),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Show all specializations
            if (doctor.specializations != null &&
                doctor.specializations!.isNotEmpty)
              Text('Specialties: ${doctor.specializations!.join(', ')}')
            else if (doctor.specialization != null &&
                doctor.specialization!.isNotEmpty)
              Text('Specialty: ${doctor.specialization}'),

            // Location information
            Text('Location: ${doctor.city}, ${doctor.state}'),

            if (doctor.hospitalAffiliation != null)
              Text('Hospital: ${doctor.hospitalAffiliation}'),
            // Show affiliated hospitals count
            if (doctor.affiliatedHospitals != null &&
                doctor.affiliatedHospitals!.isNotEmpty)
              Text(
                  'Affiliated Hospitals: ${doctor.affiliatedHospitals!.length}'),
            Text('Experience: ${doctor.experienceYears}+ years'),
            Text('Consultation Fee: ₹${doctor.consultationFee}'),
            Row(
              children: [
                Expanded(
                  child: Builder(
                    builder: (context) {
                      if (doctor.uid.isEmpty) {
                        return const Text('Rating: ⭐⭐⭐⭐⭐ (No ratings)');
                      }

                      return FutureBuilder<Map<String, dynamic>?>(
                        future: ApiService.getProviderRatingSummary(
                          providerId: doctor.uid,
                          providerType: 'doctor',
                        ),
                        builder: (context, snapshot) {
                          if (snapshot.hasError) {
                            return const Text('Rating: ⭐⭐⭐⭐⭐ (Error loading)');
                          }

                          final avg = snapshot.data?['averageRating'] ?? 0;
                          final total = snapshot.data?['totalRatings'] ?? 0;
                          return Text(
                            'Rating: ⭐⭐⭐⭐⭐ (${avg.toString()})${total > 0 ? ' ($total)' : ''}',
                          );
                        },
                      );
                    },
                  ),
                ),
                if (distance != null) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: distance <= 5
                          ? Colors.green.withOpacity(0.1)
                          : distance <= 10
                              ? Colors.orange.withOpacity(0.1)
                              : Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      distance <= 5
                          ? 'Nearby'
                          : distance <= 10
                              ? 'Moderate'
                              : 'Far',
                      style: TextStyle(
                        fontSize: 10,
                        color: distance <= 5
                            ? Colors.green
                            : distance <= 10
                                ? Colors.orange
                                : Colors.red,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
        trailing: ElevatedButton(
          onPressed: () {
            print('👨‍⚕️ Doctor selected: ${doctor.fullName}');
            setState(() {
              selectedDoctor = doctor;
              selectedHospital = null; // Reset hospital when doctor changes
              selectedTime = null;
            });
            _loadDoctorAvailability();
          },
          style: ElevatedButton.styleFrom(
            backgroundColor:
                isSelected ? Colors.green : const Color(0xFF32CCBC),
            foregroundColor: Colors.white,
          ),
          child: Text(isSelected ? 'Selected' : 'Select'),
        ),
      ),
    );
  }

  Widget _buildHospitalCard(UserModel hospital) {
    final isSelected = selectedHospital == hospital.hospitalName;

    // Calculate distance if location is available
    double? distance;
    if (userLatitude != null &&
        userLongitude != null &&
        hospital.latitude != null &&
        hospital.longitude != null) {
      distance = _calculateDistance(
        userLatitude!,
        userLongitude!,
        hospital.latitude!,
        hospital.longitude!,
      );
    }

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isSelected ? Colors.green : const Color(0xFF32CCBC),
          child: Icon(
            Icons.local_hospital,
            color: Colors.white,
            size: 24,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                hospital.hospitalName ?? hospital.fullName,
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              ),
            ),
            if (distance != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF32CCBC).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.location_on,
                        size: 14, color: Color(0xFF32CCBC)),
                    const SizedBox(width: 4),
                    Text(
                      '${distance.toStringAsFixed(1)} km',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF32CCBC),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hospital type and address
            if (hospital.hospitalType != null)
              Text('Type: ${hospital.hospitalType}'),
            if (hospital.hospitalAddress != null &&
                hospital.hospitalAddress!.isNotEmpty)
              Text('Address: ${hospital.hospitalAddress}'),
            if (hospital.address != null && hospital.address!.isNotEmpty)
              Text('Location: ${hospital.address}'),
            Text('Location: ${hospital.city}, ${hospital.state}'),

            // Hospital facilities
            Row(
              children: [
                if (hospital.numberOfBeds != null)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    margin: const EdgeInsets.only(right: 8, top: 4),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${hospital.numberOfBeds} Beds',
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.blue,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                if (hospital.hasPharmacy == true)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    margin: const EdgeInsets.only(right: 8, top: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Pharmacy',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.green,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                if (hospital.hasLab == true)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    margin: const EdgeInsets.only(right: 8, top: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Lab',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.orange,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),

            // Departments
            if (hospital.departments != null &&
                hospital.departments!.isNotEmpty)
              Text('Departments: ${hospital.departments!.join(', ')}'),

            // Contact info
            if (hospital.hospitalPhone != null)
              Text('Phone: ${hospital.hospitalPhone}'),

            // Rating and distance status
            Row(
              children: [
                Expanded(
                  child: Builder(
                    builder: (context) {
                      if (hospital.uid.isEmpty) {
                        return const Text('Rating: ⭐⭐⭐⭐⭐ (No ratings)');
                      }

                      return FutureBuilder<Map<String, dynamic>?>(
                        future: hospital.uid.isNotEmpty
                            ? ApiService.getProviderRatingSummary(
                                providerId: hospital.uid,
                                providerType: 'hospital',
                              )
                            : Future.value(null),
                        builder: (context, snapshot) {
                          if (snapshot.hasError) {
                            return const Text('Rating: ⭐⭐⭐⭐⭐ (Error loading)');
                          }

                          final avg = snapshot.data?['averageRating'] ?? 0;
                          final total = snapshot.data?['totalRatings'] ?? 0;
                          return Text(
                            'Rating: ⭐⭐⭐⭐⭐ (${avg.toString()})${total > 0 ? ' ($total)' : ''}',
                          );
                        },
                      );
                    },
                  ),
                ),
                if (distance != null) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: distance <= 5
                          ? Colors.green.withOpacity(0.1)
                          : distance <= 10
                              ? Colors.orange.withOpacity(0.1)
                              : Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      distance <= 5
                          ? 'Nearby'
                          : distance <= 10
                              ? 'Moderate'
                              : 'Far',
                      style: TextStyle(
                        fontSize: 10,
                        color: distance <= 5
                            ? Colors.green
                            : distance <= 10
                                ? Colors.orange
                                : Colors.red,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
        trailing: ElevatedButton(
          onPressed: () {
            print(
                '🏥 Hospital selected: ${hospital.hospitalName ?? hospital.fullName}');
            setState(() {
              selectedHospital = hospital.hospitalName ?? hospital.fullName;
              selectedTime = null;
            });
          },
          style: ElevatedButton.styleFrom(
            backgroundColor:
                isSelected ? Colors.green : const Color(0xFF32CCBC),
            foregroundColor: Colors.white,
          ),
          child: Text(isSelected ? 'Selected' : 'Select'),
        ),
      ),
    );
  }

  Widget _buildAppointmentDetails() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Appointment Details',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF2E2E2E),
              ),
            ),
            const SizedBox(height: 16),

            // Date Selection
            GestureDetector(
              onTap: () async {
                final DateTime? picked = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now().add(const Duration(days: 1)),
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 30)),
                );
                if (picked != null && picked != selectedDate) {
                  setState(() {
                    selectedDate = picked;
                    selectedTime = null;
                  });
                  _loadDoctorAvailability();
                }
              },
              child: AbsorbPointer(
                child: TextFormField(
                  decoration: InputDecoration(
                    labelText: 'Select Date',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                    prefixIcon: const Icon(Icons.calendar_today),
                    suffixIcon: const Icon(Icons.arrow_drop_down),
                    filled: true,
                    fillColor: Colors.grey[50],
                  ),
                  controller: TextEditingController(
                    text: selectedDate != null
                        ? DateFormat('EEEE, MMMM d, y').format(selectedDate!)
                        : '',
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Time Selection
            if (selectedDate != null) ...[
              DropdownButtonFormField<String>(
                value: selectedTime,
                decoration: InputDecoration(
                  labelText: 'Select Time',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                  prefixIcon: const Icon(Icons.access_time),
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
                items: availableTimeSlots.map((time) {
                  return DropdownMenuItem(
                    value: time,
                    child: Text(time),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    selectedTime = value;
                  });
                },
              ),
              const SizedBox(height: 16),
            ],

            // Reason Selection
            DropdownButtonFormField<String>(
              value: selectedReason,
              decoration: InputDecoration(
                labelText: 'Appointment Reason',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                prefixIcon: const Icon(Icons.note),
                filled: true,
                fillColor: Colors.grey[50],
              ),
              items: reasons.map((reason) {
                return DropdownMenuItem(
                  value: reason,
                  child: Text(reason),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  selectedReason = value;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBookButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: _canBookAppointment() ? _bookAppointment : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF32CCBC),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          elevation: 2,
        ),
        child: isLoading
            ? const CircularProgressIndicator(color: Colors.white)
            : Text(
                'Book Appointment',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }

  bool _canBookAppointment() {
    return selectedSpecialty != null &&
        selectedHospital != null &&
        selectedDoctor != null &&
        selectedDate != null &&
        selectedTime != null &&
        selectedReason != null &&
        !isLoading;
  }
}

class _SpecialtySearchDialog extends StatefulWidget {
  final List<String> specialties;
  final String? selectedSpecialty;
  final Function(String) onSpecialtySelected;

  const _SpecialtySearchDialog({
    required this.specialties,
    required this.selectedSpecialty,
    required this.onSpecialtySelected,
  });

  @override
  State<_SpecialtySearchDialog> createState() => _SpecialtySearchDialogState();
}

class _SpecialtySearchDialogState extends State<_SpecialtySearchDialog> {
  late TextEditingController _searchController;
  List<String> _filteredSpecialties = [];

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _filteredSpecialties = widget.specialties;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterSpecialties(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredSpecialties = widget.specialties;
      } else {
        _filteredSpecialties = widget.specialties
            .where((specialty) =>
                specialty.toLowerCase().contains(query.toLowerCase()))
            .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.7,
        width: MediaQuery.of(context).size.width * 0.9,
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Header
            Row(
              children: [
                Text(
                  'Select Specialty',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF2E2E2E),
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Search bar
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search specialties...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                filled: true,
                fillColor: Colors.grey[50],
              ),
              onChanged: _filterSpecialties,
            ),
            const SizedBox(height: 16),

            // Results count
            Text(
              '${_filteredSpecialties.length} specialties found',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 16),

            // Specialties list
            Expanded(
              child: ListView.builder(
                itemCount: _filteredSpecialties.length,
                itemBuilder: (context, index) {
                  final specialty = _filteredSpecialties[index];
                  final isSelected = specialty == widget.selectedSpecialty;

                  return ListTile(
                    title: Text(
                      specialty,
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.normal,
                        color: isSelected
                            ? const Color(0xFF32CCBC)
                            : Colors.black87,
                      ),
                    ),
                    trailing: isSelected
                        ? const Icon(Icons.check_circle,
                            color: Color(0xFF32CCBC))
                        : null,
                    onTap: () {
                      widget.onSpecialtySelected(specialty);
                      Navigator.of(context).pop();
                    },
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    tileColor: isSelected
                        ? const Color(0xFF32CCBC).withOpacity(0.1)
                        : null,
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
