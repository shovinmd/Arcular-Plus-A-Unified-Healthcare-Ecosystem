import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:glassmorphism/glassmorphism.dart';

import '../../services/api_service.dart';

// Doctor color constants
// Override to orange theme across the screen
const Color kDoctorPrimary = Color(0xFFFF9800);
const Color kDoctorSecondary = Color(0xFFF57C00);
const Color kDoctorAccent = Color(0xFF90CAF9);
const Color kDoctorText = Color(0xFF1A237E);
const Color kDoctorTextSecondary = Color(0xFF546E7A);
const Color kDoctorSuccess = Color(0xFF4CAF50);

class DoctorScheduleScreen extends StatefulWidget {
  const DoctorScheduleScreen({super.key});

  @override
  State<DoctorScheduleScreen> createState() => _DoctorScheduleScreenState();
}

class _DoctorScheduleScreenState extends State<DoctorScheduleScreen> {
  // Local schedule screen theme (orange)
  final Color schedulePrimary = const Color(0xFFFF9800); // orange
  final Color scheduleSecondary = const Color(0xFFF57C00);
  bool _loading = true;
  List<Map<String, dynamic>> _schedules = [];
  DateTime _selectedDate = DateTime.now();
  String? _doctorId;
  Map<String, List<Map<String, dynamic>>> _dailySchedules = {};

  // Hospital selection variables
  List<Map<String, dynamic>> _affiliatedHospitals = [];
  String? _selectedHospitalId;
  String? _selectedHospitalName;
  bool _loadingHospitals = false;

  @override
  void initState() {
    super.initState();
    _loadDoctorSchedule();
    _loadAffiliatedHospitals();
  }

  Future<void> _loadDoctorSchedule() async {
    try {
      setState(() => _loading = true);

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Get doctor's MongoDB ID
      _doctorId = await ApiService.getDoctorMongoId(user.uid);
      if (_doctorId == null) {
        setState(() => _loading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to load doctor profile. Please try again.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Load doctor's schedule (optionally filtered by hospital)
      final schedules = await ApiService.getDoctorSchedule(_doctorId!,
          hospitalId: _selectedHospitalId);

      setState(() {
        _schedules = schedules;
        _organizeSchedulesByDate();
        _loading = false;
      });
    } catch (e) {
      print('Error loading doctor schedule: $e');
      setState(() => _loading = false);
    }
  }

  Future<void> _loadAffiliatedHospitals() async {
    try {
      setState(() => _loadingHospitals = true);

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Get raw doctor data to extract affiliated hospitals
      final rawDoctorData = await ApiService.getDoctorInfoRaw(user.uid);
      print('🏥 Raw doctor data loaded: ${rawDoctorData != null}');
      print(
          '🏥 Affiliated hospitals in raw data: ${rawDoctorData?['affiliatedHospitals']}');

      if (rawDoctorData != null &&
          rawDoctorData['affiliatedHospitals'] != null) {
        final hospitals = List<Map<String, dynamic>>.from(
            rawDoctorData['affiliatedHospitals']);
        print('🏥 Hospitals found: ${hospitals.length}');

        setState(() {
          _affiliatedHospitals = hospitals
              .where((hospital) => hospital['isActive'] == true)
              .toList();
          _loadingHospitals = false;
        });

        // Auto-select first hospital if available
        if (_affiliatedHospitals.isNotEmpty) {
          _selectedHospitalId = _affiliatedHospitals.first['hospitalId'];
          _selectedHospitalName = _affiliatedHospitals.first['hospitalName'];
        } else {
          print('🏥 No active hospitals found for doctor');
        }
      } else {
        print('🏥 Raw doctor data or affiliated hospitals is null');
        setState(() => _loadingHospitals = false);
      }
    } catch (e) {
      print('Error loading affiliated hospitals: $e');
      setState(() => _loadingHospitals = false);
    }
  }

  void _organizeSchedulesByDate() {
    _dailySchedules.clear();
    for (var schedule in _schedules) {
      final date = schedule['date'] as String;
      if (!_dailySchedules.containsKey(date)) {
        _dailySchedules[date] = [];
      }
      _dailySchedules[date]!.add(schedule);
    }
  }

  Future<void> _addSchedule() async {
    if (_doctorId == null) {
      // Try to reload the doctor ID
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        _doctorId = await ApiService.getDoctorMongoId(user.uid);
      }

      if (_doctorId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Failed to load doctor profile. Please refresh and try again.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    // Check if a hospital is selected
    if (_selectedHospitalId == null || _selectedHospitalName == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please select a hospital before adding schedule'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _ScheduleDialog(
        selectedDate: _selectedDate,
        doctorId: _doctorId!,
        hospitalId: _selectedHospitalId,
        hospitalName: _selectedHospitalName,
      ),
    );

    if (result != null) {
      try {
        await ApiService.saveDoctorSchedule(result);
        await _loadDoctorSchedule();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Schedule added successfully!'),
              backgroundColor: kDoctorPrimary,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error adding schedule: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kDoctorPrimary,
      appBar: AppBar(
        title: Text(
          'My Schedule',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: schedulePrimary,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loadDoctorSchedule,
            icon: const Icon(Icons.refresh, color: Colors.white),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              schedulePrimary,
              scheduleSecondary,
              Colors.white,
            ],
            stops: const [0.0, 0.3, 0.3],
          ),
        ),
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(color: Colors.white))
            : Column(
                children: [
                  _buildDateSelector(),
                  _buildHospitalSelector(),
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.only(top: 20),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(30),
                          topRight: Radius.circular(30),
                        ),
                      ),
                      child: _buildScheduleContent(),
                    ),
                  ),
                ],
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addSchedule,
        backgroundColor: kDoctorPrimary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: Text(
          'Add Schedule',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildDateSelector() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Text(
            'Select Date',
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Only weekdays (Monday-Friday) are available for scheduling',
            style: GoogleFonts.poppins(
              color: Colors.white70,
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  DateFormat('EEEE, MMMM d, y').format(_selectedDate),
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                IconButton(
                  onPressed: _selectDate,
                  icon: const Icon(Icons.calendar_today, color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHospitalSelector() {
    if (_loadingHospitals) {
      return Container(
        padding: const EdgeInsets.all(20),
        child: const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    if (_affiliatedHospitals.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(
              'No affiliated hospitals found',
              style: GoogleFonts.poppins(
                color: Colors.white70,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Please contact your hospital administrator to add hospital affiliations to your profile.',
              style: GoogleFonts.poppins(
                color: Colors.white60,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Column(
        children: [
          Text(
            'Select Hospital',
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _selectedHospitalId,
            isExpanded: true,
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.white, width: 0.8),
              ),
            ),
            icon: Icon(Icons.arrow_drop_down, color: kDoctorPrimary),
            dropdownColor: Colors.white,
            style: GoogleFonts.poppins(
              color: kDoctorText,
              fontSize: 16,
            ),
            items: _affiliatedHospitals.map((hospital) {
              return DropdownMenuItem<String>(
                value: hospital['hospitalId'],
                child: Text(
                  hospital['hospitalName'] ?? 'Unknown Hospital',
                  style: GoogleFonts.poppins(
                    color: kDoctorText,
                    fontSize: 16,
                  ),
                ),
              );
            }).toList(),
            onChanged: (String? newValue) async {
              if (newValue != null) {
                final selectedHospital = _affiliatedHospitals.firstWhere(
                  (hospital) => hospital['hospitalId'] == newValue,
                );
                setState(() {
                  _selectedHospitalId = newValue;
                  _selectedHospitalName = selectedHospital['hospitalName'];
                });
                await _loadDoctorSchedule();
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleContent() {
    final dateKey = DateFormat('yyyy-MM-dd').format(_selectedDate);
    final daySchedules = _dailySchedules[dateKey] ?? [];

    if (daySchedules.isEmpty) {
      return _buildEmptyState();
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Schedule for ${DateFormat('MMM d, y').format(_selectedDate)}',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: kDoctorText,
                    ),
                  ),
                  if (_selectedHospitalName != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Hospital: $_selectedHospitalName',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: kDoctorTextSecondary,
                      ),
                    ),
                  ],
                ],
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: kDoctorPrimary.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${daySchedules.length} slots',
                  style: GoogleFonts.poppins(
                    color: kDoctorPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: daySchedules.length,
            itemBuilder: (context, index) {
              return _buildScheduleCard(daySchedules[index]);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildScheduleCard(Map<String, dynamic> schedule) {
    final timeSlots = schedule['timeSlots'] as List<dynamic>? ?? [];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: GlassmorphicContainer(
        width: double.infinity,
        height: 120 +
            (timeSlots.length * 40)
                .toDouble(), // Dynamic height based on content
        borderRadius: 16,
        blur: 10,
        alignment: Alignment.center,
        border: 2,
        linearGradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            schedulePrimary.withOpacity(0.1),
            scheduleSecondary.withOpacity(0.05),
          ],
        ),
        borderGradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            schedulePrimary.withOpacity(0.3),
            scheduleSecondary.withOpacity(0.2),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Time Slots',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: kDoctorText,
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: schedule['isActive'] == true
                          ? kDoctorSuccess.withOpacity(0.2)
                          : Colors.grey.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      schedule['isActive'] == true ? 'Active' : 'Inactive',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: schedule['isActive'] == true
                            ? kDoctorSuccess
                            : Colors.grey,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if ((schedule['hospitalName'] ?? '').toString().isNotEmpty)
                Row(
                  children: [
                    Icon(Icons.local_hospital,
                        size: 16, color: schedulePrimary),
                    const SizedBox(width: 6),
                    Text(
                      schedule['hospitalName'],
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: kDoctorTextSecondary,
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: timeSlots.map<Widget>((slot) {
                  final slotData = slot as Map<String, dynamic>;
                  final isAvailable = slotData['isAvailable'] == true;
                  final currentBookings = slotData['currentBookings'] ?? 0;
                  final maxBookings = slotData['maxBookings'] ?? 1;

                  return GestureDetector(
                    onLongPress: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Delete time slot'),
                          content: Text(
                              'Delete ${slotData['startTime']} - ${slotData['endTime']}?'),
                          actions: [
                            TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('Cancel')),
                            TextButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text('Delete')),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        final success = await ApiService.deleteDoctorTimeSlot(
                          doctorId: _doctorId!,
                          date: DateFormat('yyyy-MM-dd').format(_selectedDate),
                          startTime: slotData['startTime'],
                          endTime: slotData['endTime'],
                          hospitalId: (_selectedHospitalId?.isNotEmpty == true)
                              ? _selectedHospitalId
                              : null,
                        );
                        if (success) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Time slot deleted')),
                            );
                          }
                          _loadDoctorSchedule();
                        } else {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Failed to delete time slot')),
                            );
                          }
                        }
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isAvailable
                            ? schedulePrimary.withOpacity(0.1)
                            : Colors.grey.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isAvailable ? schedulePrimary : Colors.grey,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${slotData['startTime']} - ${slotData['endTime']}',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: kDoctorText,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Icon(
                            isAvailable ? Icons.check_circle : Icons.cancel,
                            color: isAvailable ? kDoctorSuccess : Colors.grey,
                            size: 14,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            '$currentBookings/$maxBookings',
                            style: GoogleFonts.poppins(
                              fontSize: 10,
                              color: kDoctorTextSecondary,
                            ),
                          ),
                          const SizedBox(width: 6),
                          InkWell(
                            onTap: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Delete time slot'),
                                  content: Text(
                                      'Delete ${slotData['startTime']} - ${slotData['endTime']}?'),
                                  actions: [
                                    TextButton(
                                        onPressed: () =>
                                            Navigator.pop(context, false),
                                        child: const Text('Cancel')),
                                    TextButton(
                                        onPressed: () =>
                                            Navigator.pop(context, true),
                                        child: const Text('Delete')),
                                  ],
                                ),
                              );
                              if (confirm == true) {
                                final success =
                                    await ApiService.deleteDoctorTimeSlot(
                                  doctorId: _doctorId!,
                                  date: DateFormat('yyyy-MM-dd')
                                      .format(_selectedDate),
                                  startTime: slotData['startTime'],
                                  endTime: slotData['endTime'],
                                  hospitalId:
                                      (_selectedHospitalId?.isNotEmpty == true)
                                          ? _selectedHospitalId
                                          : null,
                                );
                                if (success) {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content: Text('Time slot deleted')),
                                    );
                                  }
                                  _loadDoctorSchedule();
                                } else {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content: Text(
                                              'Failed to delete time slot')),
                                    );
                                  }
                                }
                              }
                            },
                            child: const Padding(
                              padding: EdgeInsets.all(2),
                              child: Icon(Icons.close,
                                  size: 14, color: Colors.redAccent),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final hasHospitalSelected = _selectedHospitalId != null;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            hasHospitalSelected ? Icons.local_hospital : Icons.schedule,
            size: 80,
            color: kDoctorPrimary.withOpacity(0.5),
          ),
          const SizedBox(height: 20),
          Text(
            hasHospitalSelected
                ? 'No schedule for $_selectedHospitalName'
                : 'No schedule for this date',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: kDoctorText,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            hasHospitalSelected
                ? 'Select a different hospital or add schedule for this hospital'
                : 'Tap the + button to add your availability',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: kDoctorTextSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now()
          .add(const Duration(days: 90)), // Limit to 3 months ahead
      selectableDayPredicate: (DateTime date) {
        // Prevent selecting past dates and weekends
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final selectedDay = DateTime(date.year, date.month, date.day);

        // Don't allow past dates
        if (selectedDay.isBefore(today)) return false;

        // Don't allow weekends (Saturday = 6, Sunday = 7)
        if (date.weekday == DateTime.saturday ||
            date.weekday == DateTime.sunday) {
          return false;
        }

        return true;
      },
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: kDoctorPrimary,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: kDoctorText,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }
}

class _ScheduleDialog extends StatefulWidget {
  final DateTime selectedDate;
  final String doctorId;
  final String? hospitalId;
  final String? hospitalName;

  const _ScheduleDialog({
    required this.selectedDate,
    required this.doctorId,
    this.hospitalId,
    this.hospitalName,
  });

  @override
  State<_ScheduleDialog> createState() => _ScheduleDialogState();
}

class _ScheduleDialogState extends State<_ScheduleDialog> {
  final List<Map<String, dynamic>> _timeSlots = [];
  bool _isActive = true;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        'Add Schedule',
        style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Date: ${DateFormat('MMM d, y').format(widget.selectedDate)}',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: kDoctorText,
              ),
            ),
            if (widget.hospitalName != null) ...[
              const SizedBox(height: 8),
              Text(
                'Hospital: ${widget.hospitalName}',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: kDoctorTextSecondary,
                ),
              ),
            ],
            const SizedBox(height: 20),
            Row(
              children: [
                Text(
                  'Active: ',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
                ),
                Switch(
                  value: _isActive,
                  onChanged: (value) => setState(() => _isActive = value),
                  activeColor: kDoctorPrimary,
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Time Slots',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                ),
                TextButton.icon(
                  onPressed: _addTimeSlot,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add Slot'),
                  style: TextButton.styleFrom(foregroundColor: kDoctorPrimary),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ..._timeSlots.asMap().entries.map((entry) {
              final index = entry.key;
              final slot = entry.value;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: kDoctorAccent),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => _selectStartTime(index),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 16),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.access_time,
                                  color: kDoctorPrimary, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                slot['startTime']?.isNotEmpty == true
                                    ? slot['startTime']
                                    : 'Select Start Time',
                                style: GoogleFonts.poppins(
                                  color: slot['startTime']?.isNotEmpty == true
                                      ? kDoctorText
                                      : Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: InkWell(
                        onTap: () => _selectEndTime(index),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 16),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.access_time,
                                  color: kDoctorPrimary, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                slot['endTime']?.isNotEmpty == true
                                    ? slot['endTime']
                                    : 'Select End Time',
                                style: GoogleFonts.poppins(
                                  color: slot['endTime']?.isNotEmpty == true
                                      ? kDoctorText
                                      : Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => _removeTimeSlot(index),
                      icon: const Icon(Icons.remove_circle, color: Colors.red),
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _timeSlots.isEmpty ? null : _saveSchedule,
          style: ElevatedButton.styleFrom(backgroundColor: kDoctorPrimary),
          child: const Text('Save', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }

  void _addTimeSlot() {
    setState(() {
      _timeSlots.add({
        'startTime': '',
        'endTime': '',
        'isAvailable': true,
        'maxBookings': 1,
        'currentBookings': 0,
      });
    });
  }

  Future<void> _selectStartTime(int index) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: kDoctorPrimary,
                ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _timeSlots[index]['startTime'] = picked.format(context);
      });
      _validateTimeSlot(index);
    }
  }

  Future<void> _selectEndTime(int index) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: kDoctorPrimary,
                ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _timeSlots[index]['endTime'] = picked.format(context);
      });
      _validateTimeSlot(index);
    }
  }

  void _removeTimeSlot(int index) {
    setState(() {
      _timeSlots.removeAt(index);
    });
  }

  void _validateTimeSlot(int index) {
    if (index >= _timeSlots.length) return;

    final slot = _timeSlots[index];
    final startTime = slot['startTime'] as String;
    final endTime = slot['endTime'] as String;

    if (startTime.isNotEmpty && endTime.isNotEmpty) {
      // Parse times for comparison (TimeOfDay.format() returns format like "9:00 AM" or "21:00")
      try {
        // Convert to 24-hour format for comparison
        final start24Hour = _convertTo24Hour(startTime);
        final end24Hour = _convertTo24Hour(endTime);

        final startParts = start24Hour.split(':');
        final endParts = end24Hour.split(':');
        final startMinutes =
            int.parse(startParts[0]) * 60 + int.parse(startParts[1]);
        final endMinutes = int.parse(endParts[0]) * 60 + int.parse(endParts[1]);

        if (endMinutes <= startMinutes) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('End time must be after start time'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 2),
            ),
          );
          return;
        }

        // Check for overlapping slots
        for (int i = 0; i < _timeSlots.length; i++) {
          if (i == index) continue;

          final otherSlot = _timeSlots[i];
          final otherStart = otherSlot['startTime'] as String;
          final otherEnd = otherSlot['endTime'] as String;

          if (otherStart.isNotEmpty && otherEnd.isNotEmpty) {
            try {
              final otherStart24Hour = _convertTo24Hour(otherStart);
              final otherEnd24Hour = _convertTo24Hour(otherEnd);

              final otherStartParts = otherStart24Hour.split(':');
              final otherEndParts = otherEnd24Hour.split(':');
              final otherStartMinutes = int.parse(otherStartParts[0]) * 60 +
                  int.parse(otherStartParts[1]);
              final otherEndMinutes = int.parse(otherEndParts[0]) * 60 +
                  int.parse(otherEndParts[1]);

              // Check for overlap
              if ((startMinutes < otherEndMinutes &&
                  endMinutes > otherStartMinutes)) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Time slots cannot overlap'),
                    backgroundColor: Colors.red,
                    duration: Duration(seconds: 2),
                  ),
                );
                return;
              }
            } catch (e) {
              // Skip invalid time formats
              continue;
            }
          }
        }
      } catch (e) {
        // If parsing fails, show error
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Invalid time format'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
        return;
      }
    }
  }

  void _saveSchedule() {
    if (_timeSlots.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please add at least one time slot'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Validate all time slots before saving
    for (int i = 0; i < _timeSlots.length; i++) {
      final slot = _timeSlots[i];
      final startTime = slot['startTime'] as String;
      final endTime = slot['endTime'] as String;

      if (startTime.isEmpty || endTime.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Please fill in all time fields'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Validate time format by trying to convert
      try {
        _convertTo24Hour(startTime);
        _convertTo24Hour(endTime);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Please select valid times'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Check if end time is after start time
      final start24Hour = _convertTo24Hour(startTime);
      final end24Hour = _convertTo24Hour(endTime);
      final startParts = start24Hour.split(':');
      final endParts = end24Hour.split(':');
      final startMinutes =
          int.parse(startParts[0]) * 60 + int.parse(startParts[1]);
      final endMinutes = int.parse(endParts[0]) * 60 + int.parse(endParts[1]);

      if (endMinutes <= startMinutes) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('End time must be after start time for all slots'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    final scheduleData = {
      'doctorId': widget.doctorId,
      'date': DateFormat('yyyy-MM-dd').format(widget.selectedDate),
      'timeSlots': _timeSlots,
      'isActive': _isActive,
      'hospitalId': widget.hospitalId,
      'hospitalName': widget.hospitalName,
    };

    Navigator.pop(context, scheduleData);
  }

  String _convertTo24Hour(String time12Hour) {
    // Convert 12-hour format to 24-hour format
    final parts = time12Hour.split(' ');
    final timePart = parts[0];
    final period = parts.length > 1 ? parts[1] : '';

    final timeComponents = timePart.split(':');
    int hour = int.parse(timeComponents[0]);
    final minute = timeComponents[1];

    if (period.toUpperCase() == 'PM' && hour != 12) {
      hour += 12;
    } else if (period.toUpperCase() == 'AM' && hour == 12) {
      hour = 0;
    }

    return '${hour.toString().padLeft(2, '0')}:$minute';
  }
}
