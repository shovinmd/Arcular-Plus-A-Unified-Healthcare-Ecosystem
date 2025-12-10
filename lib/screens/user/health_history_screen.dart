import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:arcular_plus/services/api_service.dart';
import 'package:arcular_plus/services/fcm_service.dart';
import 'package:arcular_plus/models/user_model.dart';
import 'package:arcular_plus/models/report_model.dart';
import 'package:arcular_plus/models/appointment_model.dart';
import 'package:arcular_plus/models/medicine_model.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HealthHistoryScreen extends StatefulWidget {
  const HealthHistoryScreen({super.key});

  @override
  State<HealthHistoryScreen> createState() => _HealthHistoryScreenState();
}

class _HealthHistoryScreenState extends State<HealthHistoryScreen> {
  int _selectedIndex = 0;

  UserModel? _user;
  bool _isLoading = true;
  List<ReportModel> _reports = [];
  List<AppointmentModel> _appointments = [];
  List<MedicineModel> _medications = [];
  List<Map<String, dynamic>> _prescriptions = [];
  List<Map<String, dynamic>> _patientRecords = [];
  Map<String, dynamic>? _menstrualData;
  final FCMService _fcmForMenstrual = FCMService();
  DateTime? _remNextPeriod;
  DateTime? _remOvulation;

  // Persistent filter settings (defaults: all true)
  bool _showAppointments = true;
  bool _showMedications = true;
  bool _showReports = true;
  bool _showEmergency = true;
  bool _showMenstrual = true; // respected only for female users

  @override
  void initState() {
    super.initState();
    _initialize();
    // Listen for appointment/order updates to refresh history
    FCMService().events.listen((event) {
      final type = (event['type'] ?? '').toString().toLowerCase();
      if (type.contains('appointment') || type.contains('order')) {
        _loadUserData();
      }
    });
  }

  Future<void> _initialize() async {
    await _loadFilters();
    await _loadUserData();
  }

  Future<void> _loadFilters() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _showAppointments = prefs.getBool('hh_show_appointments') ?? true;
        _showMedications = prefs.getBool('hh_show_medications') ?? true;
        _showReports = prefs.getBool('hh_show_reports') ?? true;
        _showEmergency = prefs.getBool('hh_show_emergency') ?? true;
        _showMenstrual = prefs.getBool('hh_show_menstrual') ?? true;
      });
    } catch (e) {
      // Fallback to defaults silently
    }
  }

  Future<void> _saveFilters() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('hh_show_appointments', _showAppointments);
      await prefs.setBool('hh_show_medications', _showMedications);
      await prefs.setBool('hh_show_reports', _showReports);
      await prefs.setBool('hh_show_emergency', _showEmergency);
      await prefs.setBool('hh_show_menstrual', _showMenstrual);
    } catch (_) {}
  }

  // ===== Menstrual helpers: robust field/date extraction =====
  DateTime? _parseFlexibleDate(dynamic value) {
    try {
      if (value == null) return null;
      if (value is DateTime) return value;
      if (value is int) {
        // epoch seconds vs milliseconds
        if (value > 100000000000) {
          return DateTime.fromMillisecondsSinceEpoch(value, isUtc: false);
        } else if (value > 1000000000) {
          return DateTime.fromMillisecondsSinceEpoch(value * 1000,
              isUtc: false);
        } else {
          return DateTime.fromMillisecondsSinceEpoch(value, isUtc: false);
        }
      }
      if (value is String) {
        final v = value.trim();
        if (v.isEmpty) return null;
        // Try ISO or common formats
        try {
          return DateTime.parse(v);
        } catch (_) {
          // Try yyyymmdd or yymmdd
          final digits = v.replaceAll(RegExp(r'[^0-9]'), '');
          if (digits.length == 8) {
            final year = int.parse(digits.substring(0, 4));
            final month = int.parse(digits.substring(4, 6));
            final day = int.parse(digits.substring(6, 8));
            return DateTime(year, month, day);
          }
          if (digits.length == 6) {
            final year = int.parse('20${digits.substring(0, 2)}');
            final month = int.parse(digits.substring(2, 4));
            final day = int.parse(digits.substring(4, 6));
            return DateTime(year, month, day);
          }
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  String _formatDateOrUnknown(DateTime? date) {
    if (date == null) return 'Unknown';
    return DateFormat('MMM d, y').format(date);
  }

  dynamic _firstNonNull(Map<String, dynamic> map, List<String> keys) {
    for (final k in keys) {
      if (map.containsKey(k) && map[k] != null) return map[k];
    }
    return null;
  }

  dynamic _firstNonNullDeep(Map<String, dynamic> map, List<String> paths) {
    for (final path in paths) {
      final parts = path.split('.');
      dynamic current = map;
      bool found = true;
      for (final part in parts) {
        if (current is Map && current.containsKey(part)) {
          current = current[part];
        } else if (current is List) {
          final idx = int.tryParse(part);
          if (idx != null && idx >= 0 && idx < current.length) {
            current = current[idx];
          } else {
            found = false;
            break;
          }
        } else {
          found = false;
          break;
        }
      }
      if (found && current != null) return current;
    }
    return null;
  }

  DateTime? _extractDateField(Map<String, dynamic> data, List<String> keys) {
    final direct = _firstNonNull(data, keys);
    if (direct != null) return _parseFlexibleDate(direct);
    final nested = _firstNonNullDeep(data, [
      'menstrual.lastPeriod',
      'menstrual.nextPeriod',
      'menstrual.ovulation',
      'data.lastPeriod',
      'data.nextPeriod',
      'data.ovulation',
      'cycle.lastPeriod',
      'cycle.nextPeriod',
      'cycle.ovulation',
      'prediction.nextPeriod',
      'prediction.ovulation',
      'nextPeriod',
      'ovulationDay',
      'fertileWindow.0',
      'periodEnd'
    ]);
    return _parseFlexibleDate(nested);
  }

  int? _extractIntField(Map<String, dynamic> data, List<String> keys) {
    final raw = _firstNonNull(data, keys);
    if (raw == null) return null;
    if (raw is int) return raw;
    if (raw is double) return raw.round();
    if (raw is String) {
      final digits = RegExp(r'-?\d+').firstMatch(raw)?.group(0);
      if (digits != null) return int.tryParse(digits);
    }
    return null;
  }

  Future<void> _loadUserData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Load user data first
      final userModel = await ApiService.getUserInfo(user.uid);

      // Load all health history data in parallel
      final futures = await Future.wait([
        ApiService.getReportsByUser(user.uid),
        ApiService.getAppointments(user.uid),
        ApiService.getMedications(user.uid),
        ApiService.getPrescriptionsByPatientArcId(userModel?.healthQrId ?? ''),
        ApiService.getPatientRecordsByPatientArcId(userModel?.healthQrId ?? ''),
        if ((userModel?.gender ?? '').toLowerCase() == 'female')
          ApiService.getMenstrualCycleData(user.uid)
        else
          Future.value(null),
      ]);

      if (mounted) {
        setState(() {
          _user = userModel;
          _reports = futures[0] as List<ReportModel>;
          _appointments = futures[1] as List<AppointmentModel>;
          _medications = futures[2] as List<MedicineModel>;
          _prescriptions = futures[3] as List<Map<String, dynamic>>;
          _patientRecords = futures[4] as List<Map<String, dynamic>>;
          _menstrualData = futures[5] as Map<String, dynamic>?;
          _isLoading = false;
        });
      }
      // Load reminder-based predicted dates (same source used by menstrual screen reminders)
      await _loadMenstrualPredictionsFromReminders();
    } catch (e) {
      print('Error loading health history data: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadMenstrualPredictionsFromReminders() async {
    try {
      if ((_user?.gender.toLowerCase() ?? '') != 'female') {
        _remNextPeriod = null;
        _remOvulation = null;
        return;
      }
      final reminders = await _fcmForMenstrual.getUpcomingReminders();
      for (final r in reminders) {
        final t = (r['type'] ?? '').toString().toLowerCase();
        final d = r['date'];
        DateTime? when;
        if (d is DateTime)
          when = d;
        else if (d is String) {
          try {
            when = DateTime.parse(d);
          } catch (_) {}
        }
        if (when == null) continue;
        if (t.contains('next period')) _remNextPeriod = when;
        if (t.contains('ovulation')) _remOvulation = when;
      }
      // Final safeguard: compute locally if still missing and raw fields exist
      if (_remNextPeriod == null && _menstrualData != null) {
        final lp = _extractDateField(_menstrualData!,
            ['lastPeriodStartDate', 'lastPeriod', 'last_period', 'lmp']);
        final cl = _extractIntField(_menstrualData!, [
          'cycleLength',
          'cycle_length',
          'cycleDays',
          'cycle_days',
          'avgCycle'
        ]);
        if (lp != null && cl != null && cl > 0) {
          _remNextPeriod = lp.add(Duration(days: cl));
        }
      }
      if (_remOvulation == null && _remNextPeriod != null) {
        _remOvulation = _remNextPeriod!.subtract(const Duration(days: 14));
      }
      if (mounted) setState(() {});
    } catch (e) {
      // Silent fallback if reminders not available
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Health History'),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF2E7D32), Color(0xFF1B5E20)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
          ),
        ),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _loadUserData,
          ),
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: _showSearchDialog,
          ),
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(
                    valueColor:
                        AlwaysStoppedAnimation<Color>(Color(0xFF2E7D32)),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Loading your health history...',
                    style: TextStyle(
                      fontSize: 16,
                      color: Color(0xFF2E7D32),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                // Tab Bar
                Container(
                  color: Colors.grey[100],
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildTabButton('Timeline', 0),
                      ),
                      Expanded(
                        child: _buildTabButton('Appointments', 1),
                      ),
                      Expanded(
                        child: _buildTabButton('Medications', 2),
                      ),
                      Expanded(
                        child: _buildTabButton('Reports', 3),
                      ),
                      // Add Menstrual tab only for female users
                      if (_user?.gender.toLowerCase() == 'female')
                        Expanded(
                          child: _buildTabButton('Menstrual', 4),
                        ),
                    ],
                  ),
                ),

                // Content
                Expanded(
                  child: _buildContent(),
                ),
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
        decoration: isSelected && (title == 'Menstrual' || index == 4)
            ? BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFFE91E63),
                    Color(0xFFF06292)
                  ], // red-pink gradient
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                border: Border(
                  bottom: BorderSide(
                    color: const Color(0xFFE91E63),
                    width: 2,
                  ),
                ),
              )
            : BoxDecoration(
                color:
                    isSelected ? const Color(0xFF2E7D32) : Colors.transparent,
                border: Border(
                  bottom: BorderSide(
                    color: isSelected
                        ? const Color(0xFF2E7D32)
                        : Colors.grey[300]!,
                    width: 2,
                  ),
                ),
              ),
        child: Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey[600],
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    switch (_selectedIndex) {
      case 0:
        return _buildTimeline();
      case 1:
        return _buildAppointmentsHistory();
      case 2:
        return _buildMedicationsHistory();
      case 3:
        return _buildReportsHistory();
      case 4:
        return _buildMenstrualHistory();
      default:
        return _buildTimeline();
    }
  }

  Widget _buildTimeline() {
    final events = _getTimelineEvents();

    if (events.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.timeline,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No health events found',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your health timeline will appear here as you add appointments, medications, and reports.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: events.length,
      itemBuilder: (context, index) {
        final event = events[index];
        return _buildTimelineEvent(event, index == events.length - 1);
      },
    );
  }

  Widget _buildAppointmentsHistory() {
    if (!_showAppointments) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.filter_list_off,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Appointments are hidden by filter',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }
    if (_appointments.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.calendar_today,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No appointments found',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your appointment history will appear here.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _appointments.length,
      itemBuilder: (context, index) {
        final appointment = _appointments[index];
        return _buildAppointmentCard(appointment);
      },
    );
  }

  Widget _buildMedicationsHistory() {
    if (!_showMedications) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.filter_list_off,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Medications are hidden by filter',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }
    if (_medications.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.medication,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No medications found',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your medication history will appear here.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _medications.length,
      itemBuilder: (context, index) {
        final medication = _medications[index];
        return _buildMedicationCard(medication);
      },
    );
  }

  Widget _buildReportsHistory() {
    if (!_showReports) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.filter_list_off,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Reports are hidden by filter',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }
    if (_reports.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.description,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No reports found',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your lab reports and medical documents will appear here.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _reports.length,
      itemBuilder: (context, index) {
        final report = _reports[index];
        return _buildReportCard(report);
      },
    );
  }

  Widget _buildMenstrualHistory() {
    try {
      // Respect filter and gender
      final isFemale = (_user?.gender.toLowerCase() == 'female');
      if ((!_showMenstrual) || !isFemale) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.filter_list_off,
                size: 64,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Text(
                isFemale
                    ? 'Menstrual data hidden by filter'
                    : 'Menstrual tab not available',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        );
      }
      if (_menstrualData == null) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.water_drop,
                size: 64,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Text(
                'No menstrual data found',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Your menstrual cycle tracking data will appear here.',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[500],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      }

      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildMenstrualCard(_menstrualData!),
        ],
      );
    } catch (e) {
      print('❌ Error building menstrual history: $e');
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Error loading menstrual data',
              style: TextStyle(
                fontSize: 18,
                color: Colors.red[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'There was an error loading your menstrual cycle data. Please try again.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  // Trigger a rebuild
                });
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildTimelineEvent(Map<String, dynamic> event, bool isLast) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Timeline line and dot
        Column(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: _getEventColor(event['type']),
                shape: BoxShape.circle,
              ),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 80,
                color: Colors.grey[300],
              ),
          ],
        ),
        const SizedBox(width: 16),

        // Event content
        Expanded(
          child: Card(
            elevation: 2,
            margin: const EdgeInsets.only(bottom: 16),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        _getEventIcon(event['type']),
                        color: _getEventColor(event['type']),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          event['title'],
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _getEventColor(event['type']).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          event['type'].toUpperCase(),
                          style: TextStyle(
                            color: _getEventColor(event['type']),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    event['description'],
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    DateFormat('MMM d, y - h:mm a').format(event['date']),
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 12,
                    ),
                  ),
                  if (event['details'] != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Details:',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          ...event['details'].map<Widget>((detail) => Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 2),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('• '),
                                    Expanded(child: Text(detail)),
                                  ],
                                ),
                              )),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAppointmentCard(AppointmentModel appointment) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getAppointmentStatusColor(appointment.status),
          child: Icon(
            Icons.calendar_today,
            color: Colors.white,
          ),
        ),
        title: Text(appointment.doctorName),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Medical appointment'),
            Text(
              DateFormat('MMM d, y - h:mm a').format(appointment.dateTime),
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color:
                _getAppointmentStatusColor(appointment.status).withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            appointment.status.toUpperCase(),
            style: TextStyle(
              color: _getAppointmentStatusColor(appointment.status),
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        onTap: () => _viewAppointmentDetails(appointment),
      ),
    );
  }

  Widget _buildMedicationCard(MedicineModel medication) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: _getMedicationStatusColor(
              medication.isTaken ? 'completed' : 'active'),
          child: Icon(
            Icons.medication,
            color: Colors.white,
          ),
        ),
        title: Text(medication.name),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                '${medication.dosage ?? medication.dose} - ${medication.frequency}'),
            Text(
              'Type: ${medication.type}',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: _getMedicationStatusColor(
                    medication.isTaken ? 'completed' : 'active')
                .withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            (medication.isTaken ? 'completed' : 'active').toUpperCase(),
            style: TextStyle(
              color: _getMedicationStatusColor(
                  medication.isTaken ? 'completed' : 'active'),
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Duration: ${medication.duration ?? 'Unknown'}'),
                if (medication.instructions != null)
                  Text('Instructions: ${medication.instructions}'),
                if (medication.startDate != null)
                  Text(
                      'Start Date: ${DateFormat('MMM d, y').format(medication.startDate!)}'),
                if (medication.endDate != null)
                  Text(
                      'End Date: ${DateFormat('MMM d, y').format(medication.endDate!)}'),
                if (medication.lastTakenAt != null)
                  Text(
                      'Last Taken: ${DateFormat('MMM d, y - h:mm a').format(medication.lastTakenAt!)}'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportCard(ReportModel report) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getReportStatusColor('normal'),
          child: Icon(
            Icons.description,
            color: Colors.white,
          ),
        ),
        title: Text(report.name),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(report.category ?? 'Lab Report'),
            Text(
              DateFormat('MMM d, y')
                  .format(report.createdAt ?? report.uploadedAt),
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: _getReportStatusColor('normal').withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            report.type.toUpperCase(),
            style: TextStyle(
              color: _getReportStatusColor('normal'),
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        onTap: () => _viewReportDetails(report),
      ),
    );
  }

  Widget _buildMenstrualCard(Map<String, dynamic> data) {
    try {
      // Safely extract data with fallbacks
      final String title = data['title'] ?? 'Menstrual Cycle Data';
      final String description =
          data['description'] ?? 'Menstrual cycle information';
      final String type = data['type'] ?? 'menstrual';
      final DateTime date =
          data['date'] is DateTime ? data['date'] as DateTime : DateTime.now();

      // Try to render meaningful subtitle with Last/Next Period
      final lp = _extractDateField(data, [
        'lastPeriod',
        'last_period',
        'lastPeriodDate',
        'last_period_date',
        'lastMenses',
        'last_menses',
        'lmp',
        'lastPeriodStartDate'
      ]);
      DateTime? np = _extractDateField(data, [
        'nextPeriod',
        'next_period',
        'nextPeriodDate',
        'predictedNextPeriod',
        'expectedNextPeriod',
        'next_menses'
      ]);
      np ??= _remNextPeriod;

      return Card(
        elevation: 2,
        margin: const EdgeInsets.only(bottom: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: _getMenstrualStatusColor(type),
            child: Icon(
              _getMenstrualIcon(type),
              color: Colors.white,
            ),
          ),
          title: Text(title),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(description),
              if (lp != null || np != null) ...[
                Text(
                  'Last: ${_formatDateOrUnknown(lp)} • Next: ${_formatDateOrUnknown(np)}',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ] else ...[
                Text(
                  DateFormat('MMM d, y').format(date),
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ]
            ],
          ),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _getMenstrualStatusColor(type).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              type.toUpperCase(),
              style: TextStyle(
                color: _getMenstrualStatusColor(type),
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          onTap: () => _viewMenstrualDetails(data),
        ),
      );
    } catch (e) {
      print('❌ Error building menstrual card: $e');
      return Card(
        elevation: 2,
        margin: const EdgeInsets.only(bottom: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: ListTile(
          leading: const CircleAvatar(
            backgroundColor: Colors.purple,
            child: Icon(Icons.water_drop, color: Colors.white),
          ),
          title: const Text('Menstrual Cycle Data'),
          subtitle: const Text('Menstrual cycle information'),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.purple.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'MENSTRUAL',
              style: TextStyle(
                color: Colors.purple,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          onTap: () => _viewMenstrualDetails(data),
        ),
      );
    }
  }

  List<Map<String, dynamic>> _getTimelineEvents() {
    List<Map<String, dynamic>> events = [];

    // Add appointments to timeline
    if (_showAppointments) {
      for (var appointment in _appointments) {
        events.add({
          'type': 'appointment',
          'title': 'Appointment with ${appointment.doctorName}',
          'description': appointment.hospitalName != null
              ? 'At ${appointment.hospitalName}'
              : 'Medical appointment',
          'date': appointment.dateTime,
          'details': [
            'Status: ${appointment.status}',
            'Time: ${DateFormat('HH:mm').format(appointment.dateTime)}',
            if (appointment.reason != null) 'Reason: ${appointment.reason}',
            if (appointment.appointmentType != null)
              'Type: ${appointment.appointmentType}',
          ],
        });
      }
    }

    // Add medications to timeline
    if (_showMedications) {
      for (var medication in _medications) {
        events.add({
          'type': 'medication',
          'title': medication.name,
          'description':
              '${medication.dosage ?? medication.dose} - ${medication.frequency}',
          'date': medication.startDate ?? DateTime.now(),
          'details': [
            'Status: ${medication.isTaken ? 'Completed' : 'Active'}',
            'Type: ${medication.type}',
            if (medication.instructions != null)
              'Instructions: ${medication.instructions}',
          ],
        });
      }
    }

    // Add reports to timeline
    if (_showReports) {
      for (var report in _reports) {
        events.add({
          'type': 'report',
          'title': report.name,
          'description': report.category ?? 'Lab Report',
          'date': report.createdAt ?? report.uploadedAt,
          'details': [
            'Type: ${report.type}',
            'File Size: ${report.fileSize != null ? '${(report.fileSize! / 1024).toStringAsFixed(1)} KB' : 'Unknown'}',
          ],
        });
      }
    }

    // Add menstrual data to timeline (for female users)
    if (_menstrualData != null &&
        _showMenstrual &&
        (_user?.gender.toLowerCase() == 'female')) {
      final data = _menstrualData!;
      final lastPeriod = _extractDateField(data, [
        'lastPeriod',
        'last_period',
        'lastPeriodDate',
        'last_period_date',
        'lastMenses',
        'last_menses',
        'lmp',
        'lastPeriodStartDate'
      ]);
      DateTime? nextPeriod = _extractDateField(data, [
        'nextPeriod',
        'next_period',
        'nextPeriodDate',
        'predictedNextPeriod',
        'expectedNextPeriod',
        'next_menses'
      ]);
      DateTime? ovulation = _extractDateField(data, [
        'ovulationDate',
        'ovulation_date',
        'nextOvulation',
        'predictedOvulation'
      ]);
      nextPeriod ??= _remNextPeriod;
      ovulation ??= _remOvulation;
      final cycleLength = _extractIntField(data, [
        'cycleLength',
        'cycle_length',
        'cycleDays',
        'cycle_days',
        'avgCycle',
        'averageCycle'
      ]);

      final List<String> details = [];
      details.add('Last Period: ${_formatDateOrUnknown(lastPeriod)}');
      if (cycleLength != null) details.add('Cycle Length: $cycleLength days');
      details.add('Next Period: ${_formatDateOrUnknown(nextPeriod)}');
      if (ovulation != null)
        details.add('Ovulation: ${_formatDateOrUnknown(ovulation)}');

      events.add({
        'type': 'menstrual',
        'title': 'Menstrual Cycle Data',
        'description': 'Cycle tracking information',
        'date': lastPeriod ?? nextPeriod ?? DateTime.now(),
        'details': details,
      });
    }

    // Sort events by date (newest first)
    events.sort(
        (a, b) => (b['date'] as DateTime).compareTo(a['date'] as DateTime));

    return events;
  }

  Color _getEventColor(String type) {
    switch (type) {
      case 'appointment':
        return const Color(0xFF2E7D32);
      case 'medication':
        return const Color(0xFF1B5E20);
      case 'report':
        return Colors.green;
      case 'menstrual':
        return Colors.pink;
      case 'emergency':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getEventIcon(String type) {
    switch (type) {
      case 'appointment':
        return Icons.calendar_today;
      case 'medication':
        return Icons.medication;
      case 'report':
        return Icons.description;
      case 'menstrual':
        return Icons.water_drop;
      case 'emergency':
        return Icons.emergency;
      default:
        return Icons.event;
    }
  }

  Color _getAppointmentStatusColor(String status) {
    switch (status) {
      case 'completed':
        return Colors.green;
      case 'consultation_completed':
        return Colors.orange;
      case 'scheduled':
        return Colors.blue;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Color _getMedicationStatusColor(String status) {
    switch (status) {
      case 'active':
        return Colors.green;
      case 'completed':
        return Colors.blue;
      case 'discontinued':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Color _getReportStatusColor(String status) {
    switch (status) {
      case 'normal':
        return Colors.green;
      case 'abnormal':
        return Colors.red;
      case 'pending':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  Color _getMenstrualStatusColor(String type) {
    switch (type) {
      case 'period':
        return Colors.red;
      case 'ovulation':
        return Colors.pink;
      case 'symptom':
        return Colors.purple;
      case 'fertile':
        return Colors.green;
      case 'menstrual':
        return Colors.pink;
      default:
        return Colors.grey;
    }
  }

  IconData _getMenstrualIcon(String type) {
    switch (type) {
      case 'period':
        return Icons.water_drop;
      case 'ovulation':
        return Icons.favorite;
      case 'symptom':
        return Icons.health_and_safety;
      case 'fertile':
        return Icons.eco;
      case 'menstrual':
        return Icons.water_drop;
      default:
        return Icons.event;
    }
  }

  void _showSearchDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Search Health History'),
        content: TextField(
          decoration: const InputDecoration(
            hintText: 'Search by doctor, medication, or condition...',
            border: OutlineInputBorder(),
          ),
          onChanged: (value) {
            // TODO: Implement search functionality
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Implement search functionality
            },
            child: const Text('Search'),
          ),
        ],
      ),
    );
  }

  void _showFilterDialog() {
    // Capture current values to allow cancel without saving
    bool tempAppointments = _showAppointments;
    bool tempMedications = _showMedications;
    bool tempReports = _showReports;
    bool tempEmergency = _showEmergency;
    bool tempMenstrual = _showMenstrual;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter Health History'),
        content: StatefulBuilder(
          builder: (context, setLocal) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CheckboxListTile(
                  title: const Text('Appointments'),
                  value: tempAppointments,
                  onChanged: (value) {
                    setLocal(() => tempAppointments = value ?? true);
                  },
                ),
                CheckboxListTile(
                  title: const Text('Medications'),
                  value: tempMedications,
                  onChanged: (value) {
                    setLocal(() => tempMedications = value ?? true);
                  },
                ),
                CheckboxListTile(
                  title: const Text('Lab Reports'),
                  value: tempReports,
                  onChanged: (value) {
                    setLocal(() => tempReports = value ?? true);
                  },
                ),
                CheckboxListTile(
                  title: const Text('Emergency Events'),
                  value: tempEmergency,
                  onChanged: (value) {
                    setLocal(() => tempEmergency = value ?? true);
                  },
                ),
                if (_user?.gender.toLowerCase() == 'female')
                  CheckboxListTile(
                    title: const Text('Menstrual Cycle'),
                    value: tempMenstrual,
                    onChanged: (value) {
                      setLocal(() => tempMenstrual = value ?? true);
                    },
                  ),
              ],
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _showAppointments = tempAppointments;
                _showMedications = tempMedications;
                _showReports = tempReports;
                _showEmergency = tempEmergency;
                _showMenstrual = tempMenstrual;
              });
              _saveFilters();
              Navigator.pop(context);
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }

  void _viewAppointmentDetails(AppointmentModel appointment) {
    // TODO: Navigate to appointment details
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Viewing appointment with ${appointment.doctorName}'),
        backgroundColor: const Color(0xFF2E7D32),
      ),
    );
  }

  Future<void> _viewReportDetails(ReportModel report) async {
    try {
      print('🔍 Opening report: ${report.name}');
      print('🔍 Report URL: ${report.url}');

      if (report.url.isEmpty) {
        throw Exception('Report URL is empty');
      }

      final Uri url = Uri.parse(report.url);

      if (await canLaunchUrl(url)) {
        print('✅ Can launch URL, opening in external app');
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        print('⚠️ Cannot launch URL externally, trying in-app webview');
        await launchUrl(url, mode: LaunchMode.platformDefault);
      }
    } catch (e) {
      print('❌ Error opening report: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open report: $e'),
            backgroundColor: const Color(0xFF2E7D32),
            action: SnackBarAction(
              label: 'Try Again',
              textColor: Colors.white,
              onPressed: () => _viewReportDetails(report),
            ),
          ),
        );
      }
    }
  }

  void _viewMenstrualDetails(Map<String, dynamic> data) {
    _openMenstrualDetailsSheet(data);
  }

  void _openMenstrualDetailsSheet(Map<String, dynamic> data) {
    try {
      final lastPeriod = _extractDateField(data, [
        'lastPeriod',
        'last_period',
        'lastPeriodDate',
        'last_period_date',
        'lastMenses',
        'last_menses',
        'lmp',
        'lastPeriodStartDate'
      ]);
      DateTime? nextPeriod = _extractDateField(data, [
        'nextPeriod',
        'next_period',
        'nextPeriodDate',
        'predictedNextPeriod',
        'expectedNextPeriod',
        'next_menses'
      ]);
      DateTime? ovulation = _extractDateField(data, [
        'ovulationDate',
        'ovulation_date',
        'nextOvulation',
        'predictedOvulation'
      ]);
      nextPeriod ??= _remNextPeriod;
      ovulation ??= _remOvulation;
      final cycleLength = _extractIntField(data, [
        'cycleLength',
        'cycle_length',
        'cycleDays',
        'cycle_days',
        'avgCycle',
        'averageCycle'
      ]);
      final periodLength = _extractIntField(data, [
        'periodLength',
        'period_length',
        'bleedDays',
        'bleed_days',
        'periodDuration'
      ]);
      final flow =
          _firstNonNull(data, ['flow', 'flowLevel', 'flow_level', 'intensity'])
              ?.toString();
      final symptoms =
          (_firstNonNull(data, ['symptoms', 'symptomList']) as List?)
                  ?.cast<String>() ??
              [];

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (context) {
          return Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: MediaQuery.of(context).viewInsets.bottom + 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    Text(
                      'Menstrual Details',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _detailRow('Last Period', _formatDateOrUnknown(lastPeriod)),
                _detailRow('Next Period', _formatDateOrUnknown(nextPeriod)),
                _detailRow('Ovulation', _formatDateOrUnknown(ovulation)),
                _detailRow('Cycle Length',
                    cycleLength != null ? '$cycleLength days' : 'Unknown'),
                _detailRow('Period Length',
                    periodLength != null ? '$periodLength days' : 'Unknown'),
                if (flow != null && flow.isNotEmpty) _detailRow('Flow', flow),
                if (symptoms.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  const Text('Symptoms',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children:
                        symptoms.map((s) => Chip(label: Text(s))).toList(),
                  ),
                ],
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE91E63),
                    ),
                    child: const Text('Close'),
                  ),
                ),
              ],
            ),
          );
        },
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not open menstrual details: $e'),
          backgroundColor: const Color(0xFF2E7D32),
        ),
      );
    }
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: const TextStyle(color: Colors.grey),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrescriptionsHistory() {
    if (_prescriptions.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.medication, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No prescriptions found',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            SizedBox(height: 8),
            Text(
              'Prescriptions from doctors will appear here',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _prescriptions.length,
      itemBuilder: (context, index) {
        final prescription = _prescriptions[index];
        return _buildPrescriptionCard(prescription);
      },
    );
  }

  Widget _buildPatientRecordsHistory() {
    if (_patientRecords.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.local_hospital, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No hospital records found',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            SizedBox(height: 8),
            Text(
              'Hospital admission records will appear here',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _patientRecords.length,
      itemBuilder: (context, index) {
        final record = _patientRecords[index];
        return _buildPatientRecordCard(record);
      },
    );
  }

  Widget _buildPrescriptionCard(Map<String, dynamic> prescription) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        leading: const CircleAvatar(
          backgroundColor: Colors.green,
          child: Icon(Icons.medication, color: Colors.white),
        ),
        title: Text(
          'Prescription by ${prescription['doctor'] ?? 'Doctor'}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Diagnosis: ${prescription['diagnosis'] ?? 'Not specified'}'),
            Text(
                'Date: ${DateFormat('MMM d, y').format(prescription['date'])}'),
            Text('Status: ${prescription['status'] ?? 'Active'}'),
          ],
        ),
        children: [
          if (prescription['medications'] != null &&
              prescription['medications'].isNotEmpty)
            ...prescription['medications'].map<Widget>((medication) => ListTile(
                  title: Text(medication['name'] ?? 'Unknown Medication'),
                  subtitle: Text(
                      '${medication['dose'] ?? 'N/A'} - ${medication['frequency'] ?? 'N/A'}'),
                )),
          if (prescription['instructions'] != null &&
              prescription['instructions'].isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Instructions: ${prescription['instructions']}',
                style: const TextStyle(fontStyle: FontStyle.italic),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPatientRecordCard(Map<String, dynamic> record) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        leading: const CircleAvatar(
          backgroundColor: Colors.blue,
          child: Icon(Icons.local_hospital, color: Colors.white),
        ),
        title: Text(
          'Hospital Record - ${record['hospital'] ?? 'Hospital'}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Reason: ${record['description'] ?? 'Not specified'}'),
            Text('Date: ${DateFormat('MMM d, y').format(record['date'])}'),
            Text('Status: ${record['status'] ?? 'Active'}'),
          ],
        ),
        children: [
          if (record['diagnosis'] != null && record['diagnosis'].isNotEmpty)
            ListTile(
              title: const Text('Diagnosis'),
              subtitle: Text(record['diagnosis']),
            ),
          if (record['treatmentPlan'] != null &&
              record['treatmentPlan'].isNotEmpty)
            ListTile(
              title: const Text('Treatment Plan'),
              subtitle: Text(record['treatmentPlan']),
            ),
          if (record['prescriptions'] != null &&
              record['prescriptions'].isNotEmpty)
            ListTile(
              title: const Text('Prescriptions'),
              subtitle: Text('${record['prescriptions'].length} prescriptions'),
            ),
          if (record['labReports'] != null && record['labReports'].isNotEmpty)
            ListTile(
              title: const Text('Lab Reports'),
              subtitle: Text('${record['labReports'].length} reports'),
            ),
        ],
      ),
    );
  }
}
