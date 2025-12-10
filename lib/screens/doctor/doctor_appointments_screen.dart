import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:arcular_plus/services/api_service.dart';
import 'package:arcular_plus/models/user_model.dart';
import 'package:arcular_plus/models/appointment_model.dart';
import 'dart:async';

class DoctorAppointmentsScreen extends StatefulWidget {
  const DoctorAppointmentsScreen({super.key});

  @override
  State<DoctorAppointmentsScreen> createState() =>
      _DoctorAppointmentsScreenState();
}

class _DoctorAppointmentsScreenState extends State<DoctorAppointmentsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<AppointmentModel> _appointments = [];
  List<UserModel> _associatedHospitals = [];
  bool _isLoading = true;
  String _selectedHospitalId = '';
  final Map<String, UserModel?> _patientCache = {};
  String _dateFilter = 'all';
  final Set<String> _knownAppointmentKeys = {};
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() {
          // Trigger rebuild to update appointment counts
        });
      }
      // When switching to Confirmed tab, fetch fresh confirmed from backend
      if (!_tabController.indexIsChanging && _tabController.index == 1) {
        _loadByStatus('confirmed');
      }
    });
    _loadData();
    _startPolling();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      _checkForUpdates();
    });
  }

  Future<void> _checkForUpdates() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      // Fetch direct doctor appointments
      final doctorAssigned =
          await ApiService.getDoctorAppointments(currentUser.uid);

      // Infer hospitals from existing and doctor-assigned items
      final Set<String> hospitalIds = {
        for (final a in doctorAssigned) (a.hospitalId ?? '').trim(),
        for (final a in _appointments) (a.hospitalId ?? '').trim(),
      }..removeWhere((e) => e.isEmpty);

      // Fetch hospital appointments and filter roughly by status
      final List<AppointmentModel> hospitalCollected = [];
      for (final hid in hospitalIds) {
        try {
          final mongoId = await ApiService.getHospitalMongoId(hid);
          if (mongoId == null || mongoId.isEmpty) continue;
          final apts = await ApiService.getHospitalAppointments(mongoId);
          hospitalCollected.addAll(apts);
        } catch (_) {}
      }

      // Merge
      final Map<String, AppointmentModel> merged = {};
      for (final a in [...doctorAssigned, ...hospitalCollected]) {
        final key = (a.appointmentId != null && a.appointmentId!.isNotEmpty)
            ? a.appointmentId!
            : a.id;
        merged[key] = a;
      }

      // Detect new active appointments
      int newActive = 0;
      for (final entry in merged.entries) {
        final key = entry.key;
        final s = entry.value.status.trim().toLowerCase();
        final isActive = s == 'confirmed' ||
            s == 'pending' ||
            s == 'scheduled' ||
            s == 'approved';
        if (!_knownAppointmentKeys.contains(key) && isActive) {
          newActive++;
        }
      }

      // Update state and keys
      setState(() {
        _appointments = merged.values.toList();
        _knownAppointmentKeys
          ..clear()
          ..addAll(merged.keys);
      });

      if (newActive > 0 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(newActive == 1
                ? 'New appointment received'
                : '$newActive new appointments received'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (_) {}
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      // Load appointments and associated hospitals in parallel
      await Future.wait([
        _loadAppointments(),
        _loadAssociatedHospitals(),
      ]);

      // Render immediately
      if (mounted) setState(() => _isLoading = false);

      // Preload confirmed appointments in background (non-blocking)
      // ignore: unawaited_futures
      _loadByStatus('confirmed');
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadAppointments() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      // 1) Appointments directly assigned to this doctor (includes confirmed/pending/completed)
      // Fetch all statuses (backend is case-insensitive now)
      final doctorAssigned =
          await ApiService.getDoctorAppointments(currentUser.uid);
      try {
        print('🧪 DoctorAssigned raw count: ${doctorAssigned.length}');
        for (final a in doctorAssigned) {
          print('🧪 [Direct] id=${a.id} apptId=${a.appointmentId ?? '-'} '
              'status="${a.status}" date=${a.dateTime.toIso8601String()} '
              'hospitalId=${a.hospitalId ?? '-'}');
        }
      } catch (_) {}

      // 2) Include hospital appointments for affiliated hospitals
      final doctorInfo = await ApiService.getUserInfo(currentUser.uid);
      final doctorFullName = (doctorInfo?.fullName ?? '').trim().toLowerCase();
      print('🧪 Doctor identity uid=${doctorInfo?.uid} name="$doctorFullName"');
      final List<AppointmentModel> offlineMatched = [];
      try {
        // Build hospital list: affiliated + any hospitalIds present on direct appointments
        final inferredHospitalIds = <String>{};
        for (final a in doctorAssigned) {
          final hid = (a.hospitalId ?? '').trim();
          if (hid.isNotEmpty) inferredHospitalIds.add(hid);
        }
        final hospitalUids = (doctorInfo?.affiliatedHospitals ?? [])
          ..addAll(inferredHospitalIds);
        print('🧪 Affiliated hospital UIDs: ${hospitalUids.join(', ')}');
        for (final hospitalUid in hospitalUids) {
          try {
            final mongoId = await ApiService.getHospitalMongoId(hospitalUid);
            if (mongoId == null || mongoId.isEmpty) continue;
            print('🧪 Resolving hospitalUid=$hospitalUid -> mongoId=$mongoId');
            final hospitalApts =
                await ApiService.getHospitalAppointments(mongoId);
            print(
                '🧪 Hospital $mongoId returned ${hospitalApts.length} appointments');
            final Map<String, int> hs = {};
            for (final a in hospitalApts) {
              final s = a.status.trim().toLowerCase();
              hs[s] = (hs[s] ?? 0) + 1;
              if (!(s == 'confirmed' ||
                  s == 'pending' ||
                  s == 'scheduled' ||
                  s == 'approved' ||
                  s == 'completed')) {
                continue;
              }
              final did = (a.doctorId).toString();
              final matchesDoctorId =
                  did == currentUser.uid || did == (doctorInfo?.uid ?? '');
              final an = (a.doctorName ?? '').trim().toLowerCase();
              final normA = an.replaceFirst(RegExp(r'^dr\.?\s+'), '');
              final normD =
                  doctorFullName.replaceFirst(RegExp(r'^dr\.?\s+'), '');
              final matchesByName = normA.isNotEmpty &&
                  (normA == normD ||
                      normA.contains(normD) ||
                      normD.contains(normA));
              if (matchesDoctorId || matchesByName) {
                offlineMatched.add(a);
              }
            }
            print(
                '🧪 Hospital $mongoId status summary: $hs | matched=${offlineMatched.length}');
          } catch (_) {}
        }
      } catch (_) {}

      try {
        print(
            '🧪 HospitalMatched raw count (before merge): ${offlineMatched.length}');
        for (final a in offlineMatched) {
          print('🧪 [Hospital] id=${a.id} apptId=${a.appointmentId ?? '-'} '
              'status="${a.status}" date=${a.dateTime.toIso8601String()} '
              'hospitalId=${a.hospitalId ?? '-'}');
        }
      } catch (_) {}

      // 3) Merge unique by appointmentId/id
      final Map<String, AppointmentModel> merged = {};
      for (final a in [...doctorAssigned, ...offlineMatched]) {
        final key = (a.appointmentId != null && a.appointmentId!.isNotEmpty)
            ? a.appointmentId!
            : a.id;
        merged[key] = a;
      }

      setState(() {
        _appointments = merged.values.toList();
      });

      // Debug distribution of statuses to console
      final Map<String, int> statusCounts = {};
      for (final a in _appointments) {
        final s = (a.status).trim().toLowerCase();
        statusCounts[s] = (statusCounts[s] ?? 0) + 1;
      }
      final confirmedC = statusCounts['confirmed'] ?? 0;
      final pendingC = statusCounts['pending'] ?? 0;
      final scheduledC = statusCounts['scheduled'] ?? 0;
      final approvedC = statusCounts['approved'] ?? 0;
      final completedC = statusCounts['completed'] ?? 0;
      print('🩺 Appointments loaded: total=${_appointments.length} | '
          'confirmed=$confirmedC pending=$pendingC scheduled=$scheduledC '
          'approved=$approvedC completed=$completedC');
      for (final a in _appointments) {
        print('🩺 [Merged] id=${a.id} apptId=${a.appointmentId ?? '-'} '
            'status="${a.status}" date=${a.dateTime.toIso8601String()} '
            'hospitalId=${a.hospitalId ?? '-'}');
      }
    } catch (e) {
      print('❌ Error loading appointments: $e');
    }
  }

  Future<void> _loadByStatus(String status) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;
      final list = await ApiService.getDoctorAppointments(currentUser.uid,
          status: status);
      if (list.isEmpty) return;
      final Map<String, AppointmentModel> merged = {
        for (final a in _appointments)
          ((a.appointmentId != null && a.appointmentId!.isNotEmpty)
              ? a.appointmentId!
              : a.id): a,
      };
      for (final a in list) {
        final key = (a.appointmentId != null && a.appointmentId!.isNotEmpty)
            ? a.appointmentId!
            : a.id;
        merged[key] = a;
      }
      setState(() {
        _appointments = merged.values.toList();
        _knownAppointmentKeys
          ..clear()
          ..addAll(merged.keys);
      });
      print(
          '✅ Loaded ${list.length} "$status" appointments directly from backend');
    } catch (e) {
      print('❌ Error loading "$status" appointments: $e');
    }
  }

  Future<void> _loadAssociatedHospitals() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      // Get doctor info to find associated hospitals
      final doctorInfo = await ApiService.getUserInfo(currentUser.uid);
      if (doctorInfo?.affiliatedHospitals != null) {
        final hospitalIds = doctorInfo!.affiliatedHospitals!;
        final hospitals = <UserModel>[];

        for (final hospitalId in hospitalIds) {
          try {
            // Try to get hospital by UID first, then by name if that fails
            UserModel? hospital = await ApiService.getHospitalByUid(hospitalId);
            if (hospital == null) {
              // If UID lookup fails, try searching by name
              hospital = await ApiService.getHospitalByName(hospitalId);
            }
            if (hospital != null) {
              hospitals.add(hospital);
            }
          } catch (e) {
            print('❌ Error loading hospital $hospitalId: $e');
          }
        }

        setState(() {
          _associatedHospitals = hospitals;
          // Default to "All Hospitals" so pending/confirmed from all are visible by default
          _selectedHospitalId = '';
        });
      }
    } catch (e) {
      print('❌ Error loading associated hospitals: $e');
    }
  }

  List<AppointmentModel> _filterAppointments(String tab) {
    print('🔎 Filtering appointments for tab: $tab');
    switch (tab) {
      case 'All':
        // Show all appointment statuses including pending, confirmed, completed, and offline
        return _appointments.where((a) {
          final s = a.status.trim().toLowerCase();
          return s == 'pending' ||
              s == 'confirmed' ||
              s == 'scheduled' ||
              s == 'approved' ||
              s == 'completed' ||
              s == 'offline';
        }).toList();
      case 'Completed':
        return _appointments
            .where((a) => a.status.trim().toLowerCase() == 'completed')
            .toList();
      case 'Confirmed':
        final list = _appointments.where((a) {
          final s = a.status.trim().toLowerCase();
          return s == 'confirmed' ||
              s == 'pending' ||
              s == 'scheduled' ||
              s == 'approved';
        }).toList();
        try {
          print('🔎 Confirmed tab count: ${list.length}');
          for (final a in list) {
            print(
                '🔎 [ConfirmedTab] id=${a.id} apptId=${a.appointmentId ?? '-'} '
                'status="${a.status}" date=${a.dateTime.toIso8601String()} '
                'hospitalId=${a.hospitalId ?? '-'}');
          }
        } catch (_) {}
        return list;
      default:
        return _appointments;
    }
  }

  List<AppointmentModel> _getFilteredAppointmentsForTab(String tab) {
    return _filterAppointments(tab);
  }

  List<AppointmentModel> _applyHospitalFilter(List<AppointmentModel> list) {
    if (_selectedHospitalId.isEmpty) return list;
    final selected = _associatedHospitals.firstWhere(
      (h) => h.uid == _selectedHospitalId,
      orElse: () => UserModel(
        uid: _selectedHospitalId,
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
        createdAt: DateTime.now(),
      ),
    );
    final selectedName =
        (selected.hospitalName ?? selected.fullName).trim().toLowerCase();
    return list.where((a) {
      final hid = (a.hospitalId ?? '').trim();
      final hname = (a.hospitalName ?? '').trim().toLowerCase();
      return hid == selected.uid ||
          (selectedName.isNotEmpty && hname == selectedName);
    }).toList();
  }

  List<AppointmentModel> _applyDateFilter(List<AppointmentModel> list) {
    print(
        '📅 Applying date filter: "$_dateFilter" to ${list.length} appointments');
    if (_dateFilter == 'all') {
      print('📅 Returning all appointments (no filter)');
      return list;
    }

    final now = DateTime.now();
    late DateTime start;
    late DateTime end;

    if (_dateFilter == 'today') {
      start = DateTime(now.year, now.month, now.day);
      end = start.add(const Duration(days: 1));
      print('📅 Today filter: $start to $end');
    } else if (_dateFilter == 'week') {
      // Get start of current week (Monday)
      final int weekday = now.weekday;
      start = DateTime(now.year, now.month, now.day)
          .subtract(Duration(days: weekday - 1));
      end = start.add(const Duration(days: 7));
      print('📅 Week filter: $start to $end');
    } else if (_dateFilter == 'month') {
      start = DateTime(now.year, now.month, 1);
      end = DateTime(now.year, now.month + 1, 1);
      print('📅 Month filter: $start to $end');
    } else {
      print('📅 Unknown filter, returning all');
      return list; // Unknown filter, return all
    }

    final filteredList = list.where((a) {
      final appointmentDate = a.dateTime;
      // Use inclusive comparison for better accuracy
      final isInRange = appointmentDate.isAtSameMomentAs(start) ||
          (appointmentDate.isAfter(start) && appointmentDate.isBefore(end));
      if (isInRange) {
        print(
            '📅 Appointment ${a.patientName} on ${appointmentDate} matches filter');
      }
      return isInRange;
    }).toList();

    print(
        '📅 Date filter "$_dateFilter": ${list.length} -> ${filteredList.length} appointments');
    return filteredList;
  }

  Future<UserModel?> _getPatient(String uid) async {
    // Handle empty or null UIDs (common in offline appointments)
    if (uid.isEmpty ||
        uid.toLowerCase() == 'null' ||
        uid.toLowerCase() == 'undefined') {
      return null;
    }

    if (_patientCache.containsKey(uid)) {
      return _patientCache[uid];
    }

    try {
      final patient = await ApiService.getUserInfo(uid);
      _patientCache[uid] = patient;
      return patient;
    } catch (e) {
      print('❌ Error loading patient $uid: $e');
      return null;
    }
  }

  Widget _buildChip(String label, String value) {
    final bool selected = _dateFilter == value;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        gradient: selected
            ? LinearGradient(
                colors: [
                  Colors.blue[600]!,
                  Colors.blue[700]!,
                  Colors.blue[800]!
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                stops: const [0.0, 0.5, 1.0],
              )
            : LinearGradient(
                colors: [Colors.white, Colors.blue[50]!],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(
          color: selected ? Colors.blue[800]! : Colors.blue.withOpacity(0.4),
          width: selected ? 2.0 : 1.5,
        ),
        boxShadow: selected
            ? [
                BoxShadow(
                  color: Colors.blue.withOpacity(0.4),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                  spreadRadius: 1,
                ),
                BoxShadow(
                  color: Colors.blue.withOpacity(0.2),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                  spreadRadius: 2,
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.blue.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(25),
          onTap: () {
            print('📅 Filter changed from "$_dateFilter" to "$value"');
            setState(() {
              _dateFilter = value;
            });
            print('📅 Filter updated: $_dateFilter');
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    _getFilterIcon(value),
                    key: ValueKey('${value}_${selected}'),
                    size: 16,
                    color: selected ? Colors.white : Colors.blue[600],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                    color: selected ? Colors.white : Colors.blue[700],
                    letterSpacing: 0.5,
                  ),
                ),
                if (selected) ...[
                  const SizedBox(width: 6),
                  Icon(
                    Icons.check_circle,
                    size: 14,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _getFilterIcon(String value) {
    switch (value) {
      case 'all':
        return Icons.apps;
      case 'today':
        return Icons.today;
      case 'week':
        return Icons.date_range;
      case 'month':
        return Icons.calendar_month;
      default:
        return Icons.filter_list;
    }
  }

  // Booking entry removed

  void _updateAppointmentStatus(
      AppointmentModel appointment, String newStatus) {
    // TODO: Implement appointment status update
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Appointment $newStatus!'),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue[50],
      appBar: AppBar(
        title: Text(
          'My Appointments',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1976D2), Color(0xFF42A5F5), Color(0xFF64B5F6)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'Confirmed'),
            Tab(text: 'Completed'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Date filter chips
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.blue[50]!, Colors.white],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.blue.withOpacity(0.2),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildChip('All', 'all'),
                        const SizedBox(width: 12),
                        _buildChip('Today', 'today'),
                        const SizedBox(width: 12),
                        _buildChip('This Week', 'week'),
                        const SizedBox(width: 12),
                        _buildChip('This Month', 'month'),
                      ],
                    ),
                  ),
                ),
                // Hospital Selection (show when available)
                if (_associatedHospitals.isNotEmpty) ...[
                  Container(
                    margin: const EdgeInsets.all(16),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.white, Colors.blue[50]!],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.blue.withOpacity(0.3),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blue.withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedHospitalId,
                        isExpanded: true,
                        dropdownColor: Colors.white,
                        iconEnabledColor: Colors.black87,
                        style: GoogleFonts.poppins(color: Colors.black87),
                        items: [
                          DropdownMenuItem<String>(
                            value: '',
                            child: Text(
                              'All Hospitals (${_getFilteredAppointmentsForTab(_tabController.index == 0 ? 'All' : 'Completed').length})',
                              style: GoogleFonts.poppins(),
                            ),
                          ),
                          ..._associatedHospitals.map((hospital) {
                            final filteredAppointments =
                                _getFilteredAppointmentsForTab(
                                    _tabController.index == 0
                                        ? 'All'
                                        : 'Completed');
                            final count = filteredAppointments
                                .where((a) =>
                                    (a.hospitalId ?? '').trim() ==
                                        hospital.uid.trim() ||
                                    (a.hospitalName ?? '')
                                            .trim()
                                            .toLowerCase() ==
                                        (hospital.hospitalName ??
                                                hospital.fullName)
                                            .trim()
                                            .toLowerCase())
                                .length;
                            return DropdownMenuItem<String>(
                              value: hospital.uid,
                              child: Text(
                                '${hospital.hospitalName ?? hospital.fullName} ($count)',
                                style: GoogleFonts.poppins(),
                              ),
                            );
                          }).toList(),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _selectedHospitalId = value!;
                          });
                        },
                      ),
                    ),
                  ),
                ],

                // Appointments List
                Expanded(
                  child: TabBarView(
                    key: ValueKey('$_dateFilter-$_selectedHospitalId'),
                    controller: _tabController,
                    children: ['All', 'Confirmed', 'Completed'].map((tab) {
                      var appointments = _filterAppointments(tab);
                      appointments = _applyHospitalFilter(appointments);
                      appointments = _applyDateFilter(appointments);
                      return _buildAppointmentsList(appointments, tab);
                    }).toList(),
                  ),
                ),
              ],
            ),
      // Booking FAB removed as per requirement
    );
  }

  Widget _buildAppointmentsList(
      List<AppointmentModel> appointments, String tab) {
    if (appointments.isEmpty) {
      return _buildEmptyState(tab);
    }

    return RefreshIndicator(
      onRefresh: _loadAppointments,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: appointments.length,
        itemBuilder: (context, index) {
          final appointment = appointments[index];
          return _buildAppointmentCard(appointment);
        },
      ),
    );
  }

  Widget _buildEmptyState(String tab) {
    String message;
    IconData icon;

    switch (tab) {
      case 'Upcoming':
        message = 'No upcoming appointments';
        icon = Icons.schedule;
        break;
      case 'Completed':
        message = 'No completed appointments';
        icon = Icons.check_circle_outline;
        break;
      case 'Cancelled':
        message = 'No cancelled appointments';
        icon = Icons.cancel_outlined;
        break;
      default:
        message = 'No appointments found';
        icon = Icons.calendar_today;
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          if (tab == 'All')
            Text(
              'Book your first appointment to get started',
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
    return GestureDetector(
      onTap: () => _showAppointmentDetails(appointment),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.white, Colors.blue[50]!],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.blue.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(
            color: Colors.blue.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: FutureBuilder<UserModel?>(
                      future: _getPatient(appointment.patientId),
                      builder: (context, snapshot) {
                        final patient = snapshot.data;
                        String patientName;
                        String? patientArcId;
                        String? patientPhone;

                        // Handle offline appointments or missing patient data
                        if (patient?.fullName != null &&
                            patient!.fullName.isNotEmpty) {
                          patientName = patient.fullName;
                          patientArcId = patient.healthQrId ?? patient.arcId;
                          patientPhone = patient.mobileNumber;
                        } else if (appointment.patientName != null &&
                            appointment.patientName!.isNotEmpty) {
                          // Use patientName from appointment if available (for offline appointments)
                          patientName = appointment.patientName!;
                          patientArcId = appointment
                              .patientPhone; // Use patientPhone as fallback
                          patientPhone = appointment.patientPhone;
                        } else {
                          patientName = 'Offline Patient';
                        }

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              patientName,
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                            if (patientArcId != null &&
                                patientArcId.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                'ARC: $patientArcId',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: Colors.blue[600],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                            if (patientPhone != null &&
                                patientPhone.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                '📞 $patientPhone',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ],
                        );
                      },
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          _getStatusColor(appointment.status).withOpacity(0.1),
                          _getStatusColor(appointment.status).withOpacity(0.05),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _getStatusColor(appointment.status)
                            .withOpacity(0.3),
                        width: 1.5,
                      ),
                    ),
                    child: Text(
                      appointment.status.toUpperCase(),
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: _getStatusColor(appointment.status),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.calendar_today,
                    size: 16,
                    color: Colors.blue[600],
                  ),
                  const SizedBox(width: 6),
                  Text(
                    DateFormat('MMM dd, yyyy • hh:mm a')
                        .format(appointment.dateTime),
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.blue[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              if (appointment.reason != null &&
                  appointment.reason!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 16,
                      color: Colors.blue[600],
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Reason: ${appointment.reason}',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: Colors.blue[600],
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.location_on,
                    size: 16,
                    color: Colors.blue[600],
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'At ${appointment.hospitalName ?? 'Hospital'}',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: Colors.blue[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  if (appointment.status.toLowerCase() == 'pending') ...[
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.green[600]!, Colors.green[500]!],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.green.withOpacity(0.3),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: () => _updateAppointmentStatus(
                              appointment, 'confirmed'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            'Confirm',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.red[400]!,
                            width: 2,
                          ),
                        ),
                        child: OutlinedButton(
                          onPressed: () => _updateAppointmentStatus(
                              appointment, 'cancelled'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red[600],
                            side: BorderSide.none,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            'Cancel',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAppointmentDetails(AppointmentModel appointment) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue[600]!, Colors.blue[800]!, Colors.blue[900]!],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Appointment Details',
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, color: Colors.white),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _buildDetailRow(
                    'Patient', appointment.patientName ?? 'Unknown Patient'),
                _buildDetailRow('ARC ID', appointment.patientPhone ?? 'N/A'),
                _buildDetailRow('Date',
                    DateFormat('MMM dd, yyyy').format(appointment.dateTime)),
                _buildDetailRow(
                    'Time', DateFormat('hh:mm a').format(appointment.dateTime)),
                _buildDetailRow('Status', appointment.status.toUpperCase()),
                _buildDetailRow(
                    'Hospital', appointment.hospitalName ?? 'Hospital'),
                if (appointment.reason != null &&
                    appointment.reason!.isNotEmpty)
                  _buildDetailRow('Reason', appointment.reason!),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      'Close',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
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

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white.withOpacity(0.9),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'confirmed':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'completed':
        return Colors.blue;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}
