import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';


import '../../services/api_service.dart';
import '../../services/fcm_service.dart';

class MenstrualCycleScreen extends StatefulWidget {
  const MenstrualCycleScreen({super.key});

  @override
  State<MenstrualCycleScreen> createState() => _MenstrualCycleScreenState();
}

class _MenstrualCycleScreenState extends State<MenstrualCycleScreen> with WidgetsBindingObserver {
  DateTime? _lastPeriodStartDate;
  int _cycleLength = 28;
  int _periodDuration = 5;
  List<Map<String, dynamic>> _cycleHistory = [];
  bool _remindNextPeriod = false;
  bool _remindFertileWindow = false;
  bool _remindOvulation = false;
  TimeOfDay _reminderTime = const TimeOfDay(hour: 9, minute: 0);
  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  final FCMService _fcmService = FCMService();
  bool _isLoading = false;
  String? _currentUserId;
  String _userGender = 'Female';
  List<Map<String, dynamic>> _upcomingReminders = [];

  // Pink theme colors to match dashboard tab
  static const Color _primaryPink = Color(0xFFEC4899);
  static const Color _secondaryPink = Color(0xFFBE185D);
  static const Color _lightPink = Color(0xFFFCE7F3);
  static const Color _darkPink = Color(0xFF9D174D);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initNotifications();
    tz.initializeTimeZones();
    _initializeData();
    _setupGenderListener();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // No auto-save or auto-load - only when explicitly requested
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      // Check if gender has changed when app resumes
      _loadUserGender();
    }
  }

  Future<void> _initializeData() async {
    try {
      await _getCurrentUserId();
      if (_currentUserId != null) {
        // Auto-load cycle data when screen opens
        await _loadUserGender();
        await _loadCycleData();
      } else {
        print('⚠️ No current user ID found during initialization');
      }
    } catch (e) {
      print('❌ Error during data initialization: $e');
      // Show error message to user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error initializing data: $e'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _getCurrentUserId() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      setState(() {
        _currentUserId = user.uid;
      });
    }
  }

  Future<void> _loadUserGender() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userGender = prefs.getString('user_gender') ?? 'Female';
      setState(() {
        _userGender = userGender;
      });
      print('🔍 Loaded user gender: $_userGender');
      
      // Don't auto-load reminders when gender changes
      // User will manually load data when needed
    } catch (e) {
      print('❌ Error loading user gender: $e');
    }
  }

  Future<void> _setupGenderListener() async {
    try {
      // Listen for gender changes in SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      // This will be called when gender changes
      await _loadUserGender();
    } catch (e) {
      print('❌ Error setting up gender listener: $e');
      // Continue without gender listener if there's an error
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _loadCycleData() async {
    if (_currentUserId == null) return;
    
    try {
      setState(() => _isLoading = true);
      
      print('🔍 Loading cycle data for user: $_currentUserId');
      final cycleData = await ApiService.getMenstrualCycleData(_currentUserId!);
      print('🔍 API response: $cycleData');
      if (cycleData != null && cycleData.isNotEmpty) {
        print('🔍 Loaded cycle data: ${cycleData}');
        print('🔍 Reminder time from backend: ${cycleData['reminderTime']}');
        print('🔍 Cycle history from backend: ${cycleData['cycleHistory']}');
        print('🔍 Reminder preferences from backend:');
        print('   - remindNextPeriod: ${cycleData['remindNextPeriod']}');
        print('   - remindFertileWindow: ${cycleData['remindFertileWindow']}');
        print('   - remindOvulation: ${cycleData['remindOvulation']}');
        
        // Load reminder preferences from backend, with fallback to local preferences
        final prefs = await SharedPreferences.getInstance();
        final localRemindNextPeriod = prefs.getBool('remind_next_period') ?? false;
        final localRemindFertileWindow = prefs.getBool('remind_fertile_window') ?? false;
        final localRemindOvulation = prefs.getBool('remind_ovulation') ?? false;
        
        setState(() {
          _lastPeriodStartDate = cycleData['lastPeriodStartDate'] != null 
              ? DateTime.parse(cycleData['lastPeriodStartDate']) 
              : null;
          _cycleLength = cycleData['cycleLength'] ?? 28;
          _periodDuration = cycleData['periodDuration'] ?? 5;
          // Use backend preferences if available, otherwise fallback to local preferences
          _remindNextPeriod = cycleData['remindNextPeriod'] ?? localRemindNextPeriod;
          _remindFertileWindow = cycleData['remindFertileWindow'] ?? localRemindFertileWindow;
          _remindOvulation = cycleData['remindOvulation'] ?? localRemindOvulation;
          _reminderTime = cycleData['reminderTime'] != null 
              ? _parseTimeFromString(cycleData['reminderTime'])
              : const TimeOfDay(hour: 9, minute: 0);
          _cycleHistory = List<Map<String, dynamic>>.from(cycleData['cycleHistory'] ?? []);
        });
        
        print('🔍 Set state values:');
        print('   - _lastPeriodStartDate: $_lastPeriodStartDate');
        print('   - _cycleLength: $_cycleLength');
        print('   - _periodDuration: $_periodDuration');
        print('   - _remindNextPeriod: $_remindNextPeriod');
        print('   - _remindFertileWindow: $_remindFertileWindow');
        print('   - _remindOvulation: $_remindOvulation');
        print('   - _reminderTime: $_reminderTime');
        print('   - _cycleHistory length: ${_cycleHistory.length}');
        
        // Note: Reminder preferences will be saved when user clicks "Save Everything & Schedule Reminders"
        
        print('🔍 Set reminder preferences:');
        print('   - _remindNextPeriod: $_remindNextPeriod');
        print('   - _remindFertileWindow: $_remindFertileWindow');
        print('   - _remindOvulation: $_remindOvulation');
        print('🔍 Set reminder time to: $_reminderTime');
        print('🔍 Set cycle history to: ${_cycleHistory.length} entries');
        
        // Don't auto-schedule reminders when loading data
        
        // Load upcoming reminders from FCM service
        await _loadUpcomingReminders();
      } else {
        print('🔍 No cycle data found - user needs to save data first');
        // Show helpful message to user
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('No cycle data found. Please set your cycle information and save to get started.'),
              backgroundColor: Colors.blue,
              duration: Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      print('❌ Error loading cycle data: $e');
      // Show error message to user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading cycle data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
  
  Future<void> _loadUpcomingReminders() async {
    try {
      // Check if user is female - only show menstrual reminders for females
      if (_userGender != 'Female') {
        setState(() {
          _upcomingReminders = [];
        });
        print('⚠️ User is male, skipping menstrual reminders');
        return;
      }
      
      // Generate upcoming reminders based on current cycle data
      final reminders = _generateUpcomingReminders();
      
      setState(() {
        _upcomingReminders = reminders;
      });
      
      print('✅ Menstrual Screen: Generated ${reminders.length} upcoming reminders based on cycle data');
    } catch (e) {
      print('❌ Error generating upcoming reminders: $e');
      setState(() {
        _upcomingReminders = [];
      });
    }
  }

  List<Map<String, dynamic>> _generateUpcomingReminders() {
    try {
      if (_lastPeriodStartDate == null) {
        print('⚠️ No last period start date, returning empty reminders');
        return [];
      }

      final reminders = <Map<String, dynamic>>[];
      final today = DateTime.now();
      final next30Days = today.add(Duration(days: 30));

      print('🔍 Generating reminders:');
      print('   - Today: $today');
      print('   - Next 30 days: $next30Days');
      print('   - _remindNextPeriod: $_remindNextPeriod');
      print('   - _remindFertileWindow: $_remindFertileWindow');
      print('   - _remindOvulation: $_remindOvulation');
      print('   - _nextPeriod: $_nextPeriod');

      // Next period reminder
      if (_remindNextPeriod) {
        print('🔍 Checking next period reminder...');
        print('   - _nextPeriod.isAfter(today): ${_nextPeriod.isAfter(today)}');
        print('   - _nextPeriod.isBefore(next30Days): ${_nextPeriod.isBefore(next30Days)}');
        
        if (_nextPeriod.isAfter(today) && _nextPeriod.isBefore(next30Days)) {
          final daysUntil = _nextPeriod.difference(today).inDays;
          reminders.add({
            'type': 'next_period',
            'title': '🩸 Next Period',
            'body': 'Your next period is predicted to start',
            'date': _nextPeriod,
            'daysUntil': daysUntil,
            'reminderTime': _reminderTime,
          });
          print('✅ Added next period reminder for ${_nextPeriod.toIso8601String()}');
        } else {
          print('⚠️ Next period not within next 30 days or in the past');
        }
      } else {
        print('⚠️ Next period reminder not enabled');
      }

    // Ovulation reminder - look for next occurrence
    if (_remindOvulation) {
      print('🔍 Checking ovulation reminder...');
      DateTime nextOvulation = _ovulationDay;
      print('   - Original ovulation day: $nextOvulation');
      
      // If ovulation date is in the past, calculate the next one
      while (nextOvulation.isBefore(today)) {
        nextOvulation = nextOvulation.add(Duration(days: _cycleLength));
        print('   - Moved to next cycle: $nextOvulation');
      }
      
      print('   - Final ovulation day: $nextOvulation');
      print('   - isBefore(next30Days): ${nextOvulation.isBefore(next30Days)}');
      
      if (nextOvulation.isBefore(next30Days)) {
        final daysUntil = nextOvulation.difference(today).inDays;
        reminders.add({
          'type': 'ovulation',
          'title': '🥚 Ovulation Day',
          'body': 'Your ovulation day is predicted',
          'date': nextOvulation,
          'daysUntil': daysUntil,
          'reminderTime': _reminderTime,
        });
        print('✅ Added ovulation reminder for ${nextOvulation.toIso8601String()}');
      } else {
        print('⚠️ Next ovulation not within next 30 days');
      }
    } else {
      print('⚠️ Ovulation reminder not enabled');
    }

    // Fertile window reminder
    print('🔍 Checking fertile window reminder:');
    print('   - _remindFertileWindow: $_remindFertileWindow');
    print('   - _fertileWindow length: ${_fertileWindow.length}');
    if (_fertileWindow.isNotEmpty) {
      print('   - First fertile day: ${_fertileWindow.first}');
      print('   - Today: $today');
      print('   - Next 30 days: $next30Days');
    }
    
    if (_remindFertileWindow && _fertileWindow.isNotEmpty) {
      print('🔍 Checking fertile window reminder...');
      DateTime nextFertileStart = _fertileWindow.first;
      print('   - Original fertile start: $nextFertileStart');
      
      // If fertile window start is in the past, calculate the next one
      while (nextFertileStart.isBefore(today)) {
        nextFertileStart = nextFertileStart.add(Duration(days: _cycleLength));
        print('   - Moved to next cycle: $nextFertileStart');
      }
      
      print('   - Final fertile start: $nextFertileStart');
      print('   - isBefore(next30Days): ${nextFertileStart.isBefore(next30Days)}');
      
      if (nextFertileStart.isBefore(next30Days)) {
        final daysUntil = nextFertileStart.difference(today).inDays;
        reminders.add({
          'type': 'fertile_window',
          'title': '🌱 Fertile Window',
          'body': 'Your fertile window starts',
          'date': nextFertileStart,
          'daysUntil': daysUntil,
          'reminderTime': _reminderTime,
        });
        print('✅ Added fertile window reminder for ${nextFertileStart.toIso8601String()}');
      } else {
        print('⚠️ Next fertile window start date not within next 30 days');
      }
    } else {
      print('⚠️ Fertile window reminder not enabled or no fertile window dates');
    }

      // Sort by date
      reminders.sort((a, b) => (a['date'] as DateTime).compareTo(b['date'] as DateTime));
      
      print('✅ Generated ${reminders.length} total reminders:');
      for (final reminder in reminders) {
        print('   - ${reminder['title']}: ${reminder['date']} (${reminder['daysUntil']} days)');
      }
      
      return reminders;
    } catch (e) {
      print('❌ Error generating upcoming reminders: $e');
      return [];
    }
  }

  // Public method to get upcoming reminders for dashboard and calendar
  List<Map<String, dynamic>> getUpcomingReminders() {
    return _upcomingReminders;
  }

  // Public method to refresh cycle data and reminders
  Future<void> refreshCycleData() async {
    await _loadCycleData();
  }
  
  IconData _getReminderIcon(String type) {
    switch (type.toLowerCase()) {
      case 'next period':
        return Icons.bloodtype;
      case 'ovulation':
        return Icons.egg;
      case 'fertile window':
        return Icons.favorite;
      default:
        return Icons.notifications;
    }
  }

  // Filter reminders based on individual user preferences
  Future<List<Map<String, dynamic>>> _filterRemindersByPreferences(List<Map<String, dynamic>> allReminders) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<Map<String, dynamic>> filteredReminders = [];
      
      for (final reminder in allReminders) {
        final type = reminder['type']?.toString().toLowerCase() ?? '';
        bool shouldShow = false;
        
        switch (type) {
          case 'next period':
            shouldShow = prefs.getBool('remind_next_period') ?? true;
            break;
          case 'ovulation':
            shouldShow = prefs.getBool('remind_ovulation') ?? true;
            break;
          case 'fertile window':
            shouldShow = prefs.getBool('remind_fertile_window') ?? true;
            break;
          default:
            shouldShow = true; // Show unknown types by default
        }
        
        if (shouldShow) {
          filteredReminders.add(reminder);
          print('✅ Menstrual Screen: Including $type reminder (enabled)');
        } else {
          print('⚠️ Menstrual Screen: Skipping $type reminder (disabled)');
        }
      }
      
      print('✅ Menstrual Screen: Filtered ${allReminders.length} reminders to ${filteredReminders.length} based on preferences');
      return filteredReminders;
    } catch (e) {
      print('❌ Menstrual Screen: Error filtering reminders by preferences: $e');
      return allReminders; // Return all reminders if filtering fails
    }
  }

  Future<void> _initNotifications() async {
    try {
    const AndroidInitializationSettings androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initSettings = InitializationSettings(android: androidInit);
    await _notifications.initialize(initSettings);
      print('✅ Local notifications initialized successfully');
    } catch (e) {
      print('❌ Error initializing local notifications: $e');
      // Continue without notifications if there's an error
    }
  }

  Future<tz.TZDateTime> _nextInstanceOf(DateTime date, TimeOfDay time) async {
    final location = tz.local;
    return tz.TZDateTime(location, date.year, date.month, date.day, time.hour, time.minute);
  }

  Future<void> _scheduleReminders() async {
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reminders are not supported on web.')));
      return;
    }

    // Validate required data
    if (_lastPeriodStartDate == null || _currentUserId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Please select a start date first'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    setState(() => _isLoading = true);

    try {
      print('🔍 Saving everything: cycle data + predictions + reminder preferences');
      
      // Create new cycle entry first
      final newCycleEntry = {
        'id': DateTime.now().millisecondsSinceEpoch.toString(), // Generate unique ID
        'startDate': _lastPeriodStartDate!.toIso8601String(),
        'cycleLength': _cycleLength,
        'periodDuration': _periodDuration,
        'createdAt': DateTime.now().toIso8601String(),
      };
      
      // Create updated cycle history with new entry
      final updatedCycleHistory = List<Map<String, dynamic>>.from(_cycleHistory);
      updatedCycleHistory.add(newCycleEntry);
      
      print('✅ Created new cycle entry: ${newCycleEntry}');
      print('✅ Updated cycle history will have ${updatedCycleHistory.length} entries');
      
      // Save everything to backend: cycle data + frontend predictions + reminder preferences + updated cycle history
      final completeData = {
        'userId': _currentUserId, // Required for backend to identify user
        'lastPeriodStartDate': _lastPeriodStartDate!.toIso8601String(),
        'cycleLength': _cycleLength,
        'periodDuration': _periodDuration,
        'cycleHistory': updatedCycleHistory, // Send updated cycle history to backend
        // Store frontend calculated predictions
        'nextPeriod': _nextPeriod.toIso8601String(),
        'ovulationDay': _ovulationDay.toIso8601String(),
        'fertileWindow': _fertileWindow.map((date) => date.toIso8601String()).toList(),
        'periodEnd': _periodEnd.toIso8601String(),
        // Store reminder preferences
        'remindNextPeriod': _remindNextPeriod,
        'remindFertileWindow': _remindFertileWindow,
        'remindOvulation': _remindOvulation,
        'reminderTime': '${_reminderTime.hour.toString().padLeft(2, '0')}:${_reminderTime.minute.toString().padLeft(2, '0')}',
      };
      
      // Save to backend
      final success = await ApiService.saveMenstrualCycleData(_currentUserId!, completeData);
      
      if (!success) {
        throw Exception('Failed to save data to backend');
      }
      
      print('✅ All data saved to backend successfully');
      
      // Update local cycle history with the new entry
      setState(() {
        _cycleHistory.add(newCycleEntry);
      });
      
      print('✅ Updated local cycle history with new entry');
      print('✅ Total cycle history entries: ${_cycleHistory.length}');
      
      // Also save individual preferences locally for FCM service
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('remind_next_period', _remindNextPeriod);
      await prefs.setBool('remind_fertile_window', _remindFertileWindow);
      await prefs.setBool('remind_ovulation', _remindOvulation);
      
      // Update upcoming reminders after saving
      await _loadUpcomingReminders();
      
      // Local notification preferences saved
      print('✅ Local notification preferences saved');
      
      // Schedule local notifications for reminders
    await _notifications.cancelAll();
      
      print('🔔 Scheduling local notifications for reminders...');
      
    if (_remindNextPeriod) {
        try {
      final nextPeriod = _nextPeriod;
      final tzTime = await _nextInstanceOf(nextPeriod, _reminderTime);
      await _notifications.zonedSchedule(
        1,
            '🩸 Next Period Reminder',
        'Your next period is predicted to start today.',
        tzTime,
            const NotificationDetails(
              android: AndroidNotificationDetails(
                'period', 
                'Period', 
                importance: Importance.max,
                icon: '@drawable/notify_icon',
                color: Color(0xFFEC4899),
              ),
            ),
            androidScheduleMode: AndroidScheduleMode.inexact,
        matchDateTimeComponents: DateTimeComponents.dateAndTime,
      );
          print('✅ Scheduled next period reminder for ${nextPeriod.toIso8601String()}');
        } catch (e) {
          print('❌ Error scheduling next period reminder: $e');
        }
    }
      
    if (_remindFertileWindow && _fertileWindow.isNotEmpty) {
        try {
      final fertileStart = _fertileWindow.first;
      final tzTime = await _nextInstanceOf(fertileStart, _reminderTime);
      await _notifications.zonedSchedule(
        2,
            '🌱 Fertile Window Reminder',
        'Your fertile window starts today.',
        tzTime,
            const NotificationDetails(
              android: AndroidNotificationDetails(
                'fertile', 
                'Fertile', 
                importance: Importance.max,
                icon: '@drawable/notify_icon',
                color: Color(0xFF10B981),
              ),
            ),
            androidScheduleMode: AndroidScheduleMode.inexact,
        matchDateTimeComponents: DateTimeComponents.dateAndTime,
      );
          print('✅ Scheduled fertile window reminder for ${fertileStart.toIso8601String()}');
        } catch (e) {
          print('❌ Error scheduling fertile window reminder: $e');
        }
    }
      
    if (_remindOvulation) {
        try {
      final ovulation = _ovulationDay;
      final tzTime = await _nextInstanceOf(ovulation, _reminderTime);
      await _notifications.zonedSchedule(
        3,
            '🥚 Ovulation Day Reminder',
        'Today is your predicted ovulation day.',
        tzTime,
            const NotificationDetails(
              android: AndroidNotificationDetails(
                'ovulation', 
                'Ovulation', 
                importance: Importance.max,
                icon: '@drawable/notify_icon',
                color: Color(0xFFF59E0B),
              ),
            ),
            androidScheduleMode: AndroidScheduleMode.inexact,
        matchDateTimeComponents: DateTimeComponents.dateAndTime,
      );
          print('✅ Scheduled ovulation reminder for ${ovulation.toIso8601String()}');
        } catch (e) {
          print('❌ Error scheduling ovulation reminder: $e');
        }
      }
      
      print('✅ All local notifications scheduled successfully');
      
      // Schedule FCM notifications for reliable delivery
      await _scheduleFCMReminders();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('All data saved and reminders scheduled successfully!'),
            backgroundColor: _secondaryPink,
            duration: Duration(seconds: 3),
          ),
        );
      }
      
      // Refresh data from backend to show latest information
      await _loadCycleData();
      await _loadUpcomingReminders();
      
    } catch (e) {
      print('❌ Error saving data and scheduling reminders: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving data: $e'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }




  Future<void> _pickReminderTime() async {
    final picked = await showTimePicker(context: context, initialTime: _reminderTime);
    if (picked != null) {
      setState(() => _reminderTime = picked);
      // Only update local state, don't save to backend yet
      // Data will be saved when user clicks "Save Everything & Schedule Reminders"
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Reminder time set to ${picked.format(context)} (will be saved when you click Save)'),
            backgroundColor: _secondaryPink,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }








  Future<void> _deleteCycleEntry(String entryId) async {
    if (_currentUserId == null) return;
    
    try {
      final success = await ApiService.deleteMenstrualCycleEntry(_currentUserId!, entryId);
      
      if (success) {
        // Refresh data from backend to ensure consistency
        await _loadCycleData();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Cycle entry deleted successfully!'),
              backgroundColor: _secondaryPink,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete cycle entry. Please try again.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      print('❌ Error deleting cycle entry: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting cycle entry: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Calculate predictions using standardized formula
  DateTime get _nextPeriod {
    if (_lastPeriodStartDate == null) return DateTime.now();
    // NextPeriod = LMP + CycleLength
    return _lastPeriodStartDate!.add(Duration(days: _cycleLength));
  }

  DateTime get _ovulationDay {
    if (_lastPeriodStartDate == null) return DateTime.now();
    // OvulationDay = NextPeriod - 14
    return _nextPeriod.subtract(const Duration(days: 14));
  }

  List<DateTime> get _fertileWindow {
    if (_lastPeriodStartDate == null) return [];
    // FertileWindow = [OvulationDay - 5, OvulationDay + 1]
    final ovulation = _ovulationDay;
    final start = ovulation.subtract(const Duration(days: 5));
    final end = ovulation.add(const Duration(days: 1));
    
    List<DateTime> dates = [];
    DateTime current = start;
    while (current.isBefore(end) || current.isAtSameMomentAs(end)) {
      dates.add(current);
      current = current.add(const Duration(days: 1));
    }
    return dates;
  }

  DateTime get _periodEnd {
    if (_lastPeriodStartDate == null) return DateTime.now();
    // PeriodEnd = NextPeriod + (PeriodDuration - 1)
    return _nextPeriod.add(Duration(days: _periodDuration - 1));
  }

  // Parse time string (HH:MM) to TimeOfDay
  TimeOfDay _parseTimeFromString(String timeString) {
    try {
      final parts = timeString.split(':');
      if (parts.length == 2) {
        final hour = int.parse(parts[0]);
        final minute = int.parse(parts[1]);
        return TimeOfDay(hour: hour, minute: minute);
      }
    } catch (e) {
      print('❌ Error parsing time string "$timeString": $e');
    }
    return const TimeOfDay(hour: 9, minute: 0);
  }

  // Safely format cycle date with error handling
  String _formatCycleDate(dynamic dateValue) {
    try {
      if (dateValue == null) return 'Date not set';
      
      DateTime date;
      if (dateValue is String) {
        date = DateTime.parse(dateValue);
      } else if (dateValue is DateTime) {
        date = dateValue;
      } else {
        return 'Invalid date format';
      }
      
      return DateFormat('yMMMd').format(date);
    } catch (e) {
      print('❌ Error formatting cycle date: $e');
      return 'Invalid date';
    }
  }

  // Safely format reminder date with error handling
  String _formatReminderDate(dynamic dateValue) {
    try {
      if (dateValue == null) return 'Date not set';
      
      DateTime date;
      if (dateValue is String) {
        date = DateTime.parse(dateValue);
      } else if (dateValue is DateTime) {
        date = dateValue;
      } else {
        return 'Invalid date format';
      }
      
      return DateFormat('yMMMd').format(date);
    } catch (e) {
      print('❌ Error formatting reminder date: $e');
      return 'Invalid date';
    }
  }










  @override
  Widget build(BuildContext context) {
    try {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Menstrual Cycle Tracker'),
          backgroundColor: _primaryPink,
          foregroundColor: Colors.white,
          elevation: 0,
          actions: [

          ],
        ),
        backgroundColor: _lightPink,
        body: Stack(
          children: [
            SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
                if (_userGender != 'Female')
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade100,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade300),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.info, color: Colors.blue.shade700, size: 24),
                        const SizedBox(height: 8),
                        Text(
                          'Switch to Female in Settings to access menstrual cycle features',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: Colors.blue.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                else
                  Text(
                    'Track your menstrual cycle for better health insights.',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      color: _darkPink,
                    ),
                  ),

                if (_userGender == 'Female') ...[
              const SizedBox(height: 24),
                  Text(
                    'Last Period Start Date',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: _darkPink,
                    ),
                  ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _lastPeriodStartDate ?? DateTime.now(),
                          firstDate: DateTime.now().subtract(const Duration(days: 365)),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null) setState(() => _lastPeriodStartDate = picked);
                      },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _secondaryPink,
                          side: BorderSide(color: _secondaryPink),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      child: Text(_lastPeriodStartDate != null ? DateFormat('yMMMd').format(_lastPeriodStartDate!) : 'Select Date'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
                Text(
                  'Average Cycle Length (days)',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: _darkPink,
                  ),
                ),

              Slider(
                value: _cycleLength.toDouble(),
                min: 21,
                max: 35,
                divisions: 14,
                label: '$_cycleLength',
                  activeColor: _secondaryPink,
                  inactiveColor: _lightPink,
                onChanged: (v) => setState(() => _cycleLength = v.round()),
              ),
              const SizedBox(height: 8),
                Text(
                  'Average Period Duration (days)',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: _darkPink,
                  ),
                ),
              Slider(
                value: _periodDuration.toDouble(),
                min: 2,
                max: 10,
                divisions: 8,
                label: '$_periodDuration',
                  activeColor: _secondaryPink,
                  inactiveColor: _lightPink,
                onChanged: (v) => setState(() => _periodDuration = v.round()),
              ),

              const SizedBox(height: 24),
              
              Text(
                'Reminders',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: _darkPink,
                ),
              ),
              SwitchListTile(
                  title: Text(
                    'Remind me on next period start',
                    style: GoogleFonts.poppins(
                      color: _darkPink,
                      fontSize: 14,
                    ),
                  ),
                value: _remindNextPeriod,
                  activeColor: _secondaryPink,
                                onChanged: (v) {
                  setState(() => _remindNextPeriod = v);
                  // Only update local state, don't save to backend yet
                  // Data will be saved when user clicks "Save Everything & Schedule Reminders"
                },
              ),
              SwitchListTile(
                  title: Text(
                    'Remind me on fertile window',
                    style: GoogleFonts.poppins(
                      color: _darkPink,
                      fontSize: 14,
                    ),
                  ),
                value: _remindFertileWindow,
                  activeColor: _secondaryPink,
                                onChanged: (v) {
                  setState(() => _remindFertileWindow = v);
                  // Only update local state, don't save to backend yet
                  // Data will be saved when user clicks "Save Everything & Schedule Reminders"
                },
              ),
              SwitchListTile(
                  title: Text(
                    'Remind me on ovulation day',
                    style: GoogleFonts.poppins(
                      color: _darkPink,
                      fontSize: 14,
                    ),
                  ),
                value: _remindOvulation,
                  activeColor: _secondaryPink,
                                onChanged: (v) {
                  setState(() => _remindOvulation = v);
                  // Only update local state, don't save to backend yet
                  // Data will be saved when user clicks "Save Everything & Schedule Reminders"
                },
                ),
                // Only show reminder time if any reminder is enabled
                if (_remindNextPeriod || _remindFertileWindow || _remindOvulation) ...[
              ListTile(
                title: const Text('Reminder Time'),
                subtitle: Text('${_reminderTime.format(context)}'),
                    titleTextStyle: GoogleFonts.poppins(
                      color: _darkPink,
                      fontSize: 14,
                    ),
                    subtitleTextStyle: GoogleFonts.poppins(
                      color: _darkPink.withOpacity(0.7),
                      fontSize: 12,
                    ),
                trailing: IconButton(
                  icon: const Icon(Icons.access_time),
                      color: _secondaryPink,
                  onPressed: _pickReminderTime,
                ),
              ),
                ],
              ElevatedButton.icon(
                icon: _isLoading 
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(Icons.save),
                label: _isLoading 
                    ? const Text('Saving...')
                    : const Text('Save Everything & Schedule Reminders'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _secondaryPink,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                onPressed: _isLoading ? null : () async {
                  print('🔍 Save button clicked!');
                  try {
                  await _scheduleReminders();
                    print('✅ Save operation completed successfully');
                  } catch (e) {
                    print('❌ Error in save button: $e');
                    // Error handling is done inside _scheduleReminders
                  }
                },
              ),
              if (kIsWeb) ...[
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text('Reminders are not supported on web.', style: TextStyle(color: Colors.red)),
                ),
              ],
              if (_lastPeriodStartDate != null) ...[
                  Text(
                    'Predictions',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: _darkPink,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _secondaryPink.withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                                                 Text(
                           'Next Period: ${DateFormat('yMMMd').format(_nextPeriod)}',
                           style: GoogleFonts.poppins(
                             color: _darkPink,
                             fontSize: 14,
                           ),
                         ),
                         const SizedBox(height: 8),
                         Text(
                           'Period End: ${DateFormat('yMMMd').format(_periodEnd)}',
                           style: GoogleFonts.poppins(
                             color: _darkPink,
                             fontSize: 14,
                           ),
                         ),
                         const SizedBox(height: 8),
                         Text(
                           'Ovulation Day: ${DateFormat('yMMMd').format(_ovulationDay)}',
                           style: GoogleFonts.poppins(
                             color: _darkPink,
                             fontSize: 14,
                           ),
                         ),
                         const SizedBox(height: 8),
                         Text(
                           'Fertile Window: ${_fertileWindow.map((d) => DateFormat('yMMMd').format(d)).join(' - ')}',
                           style: GoogleFonts.poppins(
                             color: _darkPink,
                             fontSize: 14,
                           ),
                         ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
                ], // Close the main content conditional
                // Upcoming Reminders Section
                if (_upcomingReminders.isNotEmpty) ...[
                  Text(
                    'Upcoming Reminders',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: _darkPink,
                    ),
                  ),
                const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _secondaryPink.withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final reminder in _upcomingReminders.take(5)) // Show next 5 reminders
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                Icon(
                                  _getReminderIcon(reminder['type']),
                                  color: _secondaryPink,
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        reminder['title'] ?? 'Reminder',
                                        style: GoogleFonts.poppins(
                                          color: _darkPink,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      Text(
                                        '${reminder['body']} on ${_formatReminderDate(reminder['date'])}',
                                        style: GoogleFonts.poppins(
                                          color: _darkPink.withOpacity(0.7),
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                const SizedBox(height: 24),
              ],
                if (_userGender == 'Female') ...[
                  Text(
                    'Cycle History',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: _darkPink,
                    ),
                  ),
              const SizedBox(height: 8),
              if (_cycleHistory.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _secondaryPink.withOpacity(0.3)),
                    ),
                    child: Text(
                      'No cycles logged yet.',
                      style: GoogleFonts.poppins(
                        color: _darkPink.withOpacity(0.7),
                        fontSize: 14,
                      ),
                    ),
                  ),
                ...(_cycleHistory.map((cycle) => Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _secondaryPink.withOpacity(0.3)),
                    boxShadow: [
                      BoxShadow(
                        color: _secondaryPink.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ListTile(
                    title: Text('Start: ${_formatCycleDate(cycle['startDate'])}'),
                    subtitle: Text('Length: ${cycle['cycleLength']} days, Period: ${cycle['periodDuration']} days'),
                    titleTextStyle: GoogleFonts.poppins(
                      color: _darkPink,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    subtitleTextStyle: GoogleFonts.poppins(
                      color: _darkPink.withOpacity(0.7),
                      fontSize: 12,
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _deleteCycleEntry(cycle['id']),
                    ),
                  ),
                )).toList()),
                ], // Close the Cycle History conditional
              ],
            ),
          ),
          // Loading overlay
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
    } catch (e) {
      print('❌ Error in build method: $e');
      // Return a simple error widget if there's a build error
      return Scaffold(
        appBar: AppBar(
          title: const Text('Error'),
          backgroundColor: Colors.red,
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                'Something went wrong',
                style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Please try again or contact support',
                style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    // Trigger a rebuild
                  });
                },
                child: Text('Retry'),
                ),
            ],
          ),
        ),
      );
    }
  }

  // Schedule FCM notifications for menstrual cycle reminders
  Future<void> _scheduleFCMReminders() async {
    try {
      print('📱 FCM: Scheduling menstrual cycle reminders...');
      
      // Get FCM token
      final String? token = await _fcmService.getToken();
      if (token == null) {
        print('⚠️ FCM: Token not available for menstrual reminders');
        return;
      }

      // Schedule FCM notifications for each reminder type
      if (_remindNextPeriod) {
        await _scheduleFCMReminder(
          token: token,
          type: 'next_period',
          title: '🩸 Next Period Reminder',
          body: 'Your next period is predicted to start today.',
          scheduledTime: _nextPeriod,
          reminderTime: _reminderTime,
        );
      }

      if (_remindFertileWindow && _fertileWindow.isNotEmpty) {
        await _scheduleFCMReminder(
          token: token,
          type: 'fertile_window',
          title: '🌱 Fertile Window Reminder',
          body: 'Your fertile window starts today.',
          scheduledTime: _fertileWindow.first,
          reminderTime: _reminderTime,
        );
      }

      if (_remindOvulation) {
        await _scheduleFCMReminder(
          token: token,
          type: 'ovulation',
          title: '🥚 Ovulation Day Reminder',
          body: 'Today is your predicted ovulation day.',
          scheduledTime: _ovulationDay,
          reminderTime: _reminderTime,
        );
      }

      print('✅ FCM: All menstrual cycle reminders scheduled successfully');
    } catch (e) {
      print('❌ FCM: Error scheduling menstrual cycle reminders: $e');
    }
  }

  // Schedule individual FCM reminder
  Future<void> _scheduleFCMReminder({
    required String token,
    required String type,
    required String title,
    required String body,
    required DateTime scheduledTime,
    required TimeOfDay reminderTime,
  }) async {
    try {
      // Calculate the exact notification time
      final notificationTime = DateTime(
        scheduledTime.year,
        scheduledTime.month,
        scheduledTime.day,
        reminderTime.hour,
        reminderTime.minute,
      );

      // Skip if the time is in the past
      if (notificationTime.isBefore(DateTime.now())) {
        print('⚠️ FCM: Skipping $type reminder - time is in the past');
        return;
      }

      // Send to backend for FCM scheduling
      final response = await _fcmService.scheduleNotification(
        title: title,
        body: body,
        scheduledTime: notificationTime,
        data: {
          'type': 'menstrual_cycle',
          'reminder_type': type,
          'scheduled_date': scheduledTime.toIso8601String(),
        },
      );

      if (response) {
        print('✅ FCM: Scheduled $type reminder for ${notificationTime.toIso8601String()}');
      } else {
        print('❌ FCM: Failed to schedule $type reminder');
      }
    } catch (e) {
      print('❌ FCM: Error scheduling $type reminder: $e');
    }
  }
} 