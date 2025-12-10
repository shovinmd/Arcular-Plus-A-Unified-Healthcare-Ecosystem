import 'package:arcular_plus/services/api_service.dart';
import 'package:arcular_plus/services/fcm_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'dart:collection';
import 'package:glassmorphism/glassmorphism.dart';
import 'package:arcular_plus/config/themes.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CalendarEvent {
  final String title;
  final String type; // 'medication', 'appointment', or 'menstrual'
  final DateTime date;
  final Color? color; // Custom color for different event types

  const CalendarEvent(this.title, this.type, this.date, {this.color});

  @override
  String toString() => title;
}

class CalendarUserScreen extends StatefulWidget {
  const CalendarUserScreen({super.key});

  @override
  State<CalendarUserScreen> createState() => _CalendarUserScreenState();
}

class _CalendarUserScreenState extends State<CalendarUserScreen>
    with WidgetsBindingObserver {
  final _auth = FirebaseAuth.instance;
  late final ValueNotifier<List<CalendarEvent>> _selectedEvents;
  final LinkedHashMap<DateTime, List<CalendarEvent>> _events = LinkedHashMap(
    equals: isSameDay,
    hashCode: (key) => key.day * 1000000 + key.month * 10000 + key.year,
  );

  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  String _userGender = 'Female'; // Default to female
  bool _isLoadingEvents = true;

  // FCM service for upcoming reminders
  final FCMService _fcmService = FCMService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _selectedDay = _focusedDay;
    _selectedEvents = ValueNotifier(_getEventsForDay(_selectedDay!));
    _loadUserGender();
    _loadEvents();

    // Listen for FCM events to refresh calendar
    _fcmService.events.listen((event) {
      final type = (event['type'] ?? '').toString().toLowerCase();
      print('📅 Calendar: FCM Event received: $type');
      if (type.contains('appointment') ||
          type.contains('order') ||
          type.contains('medication')) {
        print('🔄 Calendar: Refreshing events due to $type event');
        _loadEvents();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _selectedEvents.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      // Check if gender has changed when app resumes
      _loadUserGender();
    }
  }

  // Load user gender from SharedPreferences
  Future<void> _loadUserGender() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userGender = prefs.getString('user_gender') ?? 'Female';
      setState(() {
        _userGender = userGender;
      });
      print('🔍 Calendar: Loaded user gender: $_userGender');

      // Reload events if gender changed
      if (_userGender == 'Female') {
        await _loadEvents();
      }
    } catch (e) {
      print('❌ Calendar: Error loading user gender: $e');
    }
  }

  Future<void> _loadEvents() async {
    setState(() {
      _isLoadingEvents = true;
    });

    try {
      final userId = _auth.currentUser?.uid ?? '';

      // Clear existing events
      _events.clear();

      // Load Medications - Show individual medicine names
      final medications = await ApiService.getMedications(userId);

      for (var med in medications) {
        if (med.startDate != null && med.endDate != null) {
          DateTime currentDate = DateTime(
              med.startDate!.year, med.startDate!.month, med.startDate!.day);
          final endDate =
              DateTime(med.endDate!.year, med.endDate!.month, med.endDate!.day);

          while (currentDate.isBefore(endDate) ||
              currentDate.isAtSameMomentAs(endDate)) {
            final eventDate = DateTime.utc(
                currentDate.year, currentDate.month, currentDate.day);

            // Create individual medicine event with actual name
            final event = CalendarEvent(
                '💊 ${med.name}', 'medication', eventDate,
                color: Colors.blue);
            if (_events[eventDate] == null) _events[eventDate] = [];
            _events[eventDate]!.add(event);

            currentDate = currentDate.add(const Duration(days: 1));
          }
        } else {
          // Fallback: show for today if dates are missing
          final eventDate = DateTime.utc(
              DateTime.now().year, DateTime.now().month, DateTime.now().day);

          final event = CalendarEvent('💊 ${med.name}', 'medication', eventDate,
              color: Colors.blue);
          if (_events[eventDate] == null) _events[eventDate] = [];
          _events[eventDate]!.add(event);
        }
      }

      // Load Appointments
      final appointments = await ApiService.getAppointments(userId);
      print('📅 Calendar: Loaded ${appointments.length} appointments');
      for (var appointment in appointments) {
        final eventDate = DateTime.utc(appointment.dateTime.year,
            appointment.dateTime.month, appointment.dateTime.day);

        // Determine color based on appointment status
        Color appointmentColor;
        String statusEmoji;
        switch (appointment.status.toLowerCase()) {
          case 'completed':
            appointmentColor = Colors.green;
            statusEmoji = '✅';
            break;
          case 'consultation_completed':
            appointmentColor = Colors.orange;
            statusEmoji = '🟠';
            break;
          case 'cancelled':
            appointmentColor = Colors.red;
            statusEmoji = '❌';
            break;
          case 'rescheduled':
            appointmentColor = Colors.orange;
            statusEmoji = '🔄';
            break;
          default:
            appointmentColor = Colors.blue;
            statusEmoji = '📅';
        }

        final event = CalendarEvent(
            '$statusEmoji ${appointment.doctorName}', 'appointment', eventDate,
            color: appointmentColor);
        if (_events[eventDate] == null) _events[eventDate] = [];
        _events[eventDate]!.add(event);
        print(
            '📅 Calendar: Added ${appointment.status} appointment for ${eventDate.toString().split(' ')[0]}');
      }

      // Load Menstrual Cycle Events (only for female users)
      if (_userGender == 'Female') {
        await _loadMenstrualCycleEvents(userId);
        await _loadUpcomingReminders(userId);
      }

      // Refresh the events for the selected day
      _selectedEvents.value = _getEventsForDay(_selectedDay!);

      // Force UI update
      setState(() {
        _isLoadingEvents = false;
      });
    } catch (e) {
      print('Error loading events: $e');
      setState(() {
        _isLoadingEvents = false;
      });
    }
  }

  // Load menstrual cycle events for the calendar
  Future<void> _loadMenstrualCycleEvents(String userId) async {
    try {
      // Get menstrual cycle data from backend (including stored calculations)
      final cycleData = await ApiService.getMenstrualCycleData(userId);
      if (cycleData == null) return;

      // Use stored frontend calculations if available, otherwise fallback to local calculation
      List<DateTime> fertileWindow = [];
      DateTime? ovulationDay;
      DateTime? nextPeriod;
      DateTime? periodEnd;

      if (cycleData['fertileWindow'] != null &&
          cycleData['ovulationDay'] != null &&
          cycleData['nextPeriod'] != null &&
          cycleData['periodEnd'] != null) {
        // Use stored backend calculations
        fertileWindow = (cycleData['fertileWindow'] as List)
            .map((date) => DateTime.parse(date))
            .toList();
        ovulationDay = DateTime.parse(cycleData['ovulationDay']);
        nextPeriod = DateTime.parse(cycleData['nextPeriod']);
        periodEnd = DateTime.parse(cycleData['periodEnd']);
        print('✅ Calendar: Using stored backend calculations');
      } else {
        // Fallback to local calculation
        final lastPeriodStart = cycleData['lastPeriodStartDate'];
        final cycleLength = cycleData['cycleLength'] ?? 28;
        final periodDuration = cycleData['periodDuration'] ?? 5;

        if (lastPeriodStart == null) return;

        final startDate = DateTime.parse(lastPeriodStart);
        nextPeriod = startDate.add(Duration(days: cycleLength));
        ovulationDay = nextPeriod.subtract(const Duration(days: 14));
        periodEnd = nextPeriod.add(Duration(days: periodDuration - 1));

        // Calculate fertile window
        final fertileStart = ovulationDay.subtract(const Duration(days: 5));
        final fertileEnd = ovulationDay.add(const Duration(days: 1));

        DateTime current = fertileStart;
        while (current.isBefore(fertileEnd) ||
            current.isAtSameMomentAs(fertileEnd)) {
          fertileWindow.add(current);
          current = current.add(const Duration(days: 1));
        }
        print('⚠️ Calendar: Using fallback local calculations');
      }

      // Add events to calendar
      if (nextPeriod != null) {
        // Add period start date
        final periodStartDate =
            DateTime.utc(nextPeriod.year, nextPeriod.month, nextPeriod.day);

        final periodEvent = CalendarEvent(
          'Period Start',
          'menstrual',
          periodStartDate,
          color: const Color(0xFFEC4899), // Pink color
        );

        if (_events[periodStartDate] == null) _events[periodStartDate] = [];
        _events[periodStartDate]!.add(periodEvent);

        // Add period end date
        if (periodEnd != null) {
          final periodEndCalendarDate =
              DateTime.utc(periodEnd.year, periodEnd.month, periodEnd.day);

          final periodEndEvent = CalendarEvent(
            'Period End',
            'menstrual',
            periodEndCalendarDate,
            color: const Color(0xFFEC4899), // Pink color
          );

          if (_events[periodEndCalendarDate] == null)
            _events[periodEndCalendarDate] = [];
          _events[periodEndCalendarDate]!.add(periodEndEvent);
        }

        // Add ovulation day
        if (ovulationDay != null) {
          final ovulationCalendarDate = DateTime.utc(
              ovulationDay.year, ovulationDay.month, ovulationDay.day);

          final ovulationEvent = CalendarEvent(
            'Ovulation Day',
            'menstrual',
            ovulationCalendarDate,
            color: const Color(0xFFF59E0B), // Amber color
          );

          if (_events[ovulationCalendarDate] == null)
            _events[ovulationCalendarDate] = [];
          _events[ovulationCalendarDate]!.add(ovulationEvent);
        }

        // Add fertile window dates
        for (final fertileDate in fertileWindow) {
          final fertileCalendarDate = DateTime.utc(
              fertileDate.year, fertileDate.month, fertileDate.day);

          final fertileEvent = CalendarEvent(
            'Fertile Window',
            'menstrual',
            fertileCalendarDate,
            color: const Color(0xFF10B981), // Green color
          );

          if (_events[fertileCalendarDate] == null)
            _events[fertileCalendarDate] = [];
          _events[fertileCalendarDate]!.add(fertileEvent);
        }
      }

      print('✅ Calendar: Loaded ${_events.length} menstrual cycle events');
    } catch (e) {
      print('❌ Calendar: Error loading menstrual cycle events: $e');
    }
  }

  // Load upcoming reminders and add them to calendar events
  Future<void> _loadUpcomingReminders(String userId) async {
    try {
      print('🔍 Calendar: Loading upcoming reminders for user: $userId');

      // Get upcoming reminders from FCM service
      final allReminders = await _fcmService.getUpcomingReminders();

      // Filter reminders based on user preferences (same logic as dashboard)
      final filteredReminders =
          await _filterRemindersByPreferences(allReminders);

      // Store filtered reminders for calendar events

      print(
          '✅ Calendar: Loaded ${filteredReminders.length} filtered upcoming reminders');

      // Add upcoming reminders as calendar events
      for (final reminder in filteredReminders) {
        final reminderDate = DateTime.parse(reminder['date']);
        final calendarDate = DateTime.utc(
          reminderDate.year,
          reminderDate.month,
          reminderDate.day,
        );

        String eventTitle = '';
        Color eventColor = const Color(0xFFEC4899); // Default pink

        // Set title and color based on reminder type
        switch (reminder['type']) {
          case 'next_period':
          case 'next period':
            eventTitle = '🩸 Next Period';
            eventColor = const Color(0xFFEC4899); // Pink
            break;
          case 'ovulation':
            eventTitle = '🥚 Ovulation Day';
            eventColor = const Color(0xFFF59E0B); // Amber
            break;
          case 'fertile_window':
          case 'fertile window':
            eventTitle = '🌱 Fertile Window';
            eventColor = const Color(0xFF10B981); // Green
            break;
          default:
            eventTitle = '📋 ${reminder['type'] ?? 'Reminder'}';
            eventColor = const Color(0xFF6B7280); // Gray
        }

        final reminderEvent = CalendarEvent(
          eventTitle,
          'reminder',
          calendarDate,
          color: eventColor,
        );

        if (_events[calendarDate] == null) _events[calendarDate] = [];
        _events[calendarDate]!.add(reminderEvent);
      }

      print(
          '✅ Calendar: Added ${filteredReminders.length} upcoming reminders to calendar');
    } catch (e) {
      print('❌ Calendar: Error loading upcoming reminders: $e');
    }
  }

  // Filter reminders based on user preferences (same logic as dashboard)
  Future<List<Map<String, dynamic>>> _filterRemindersByPreferences(
      List<Map<String, dynamic>> reminders) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final remindNextPeriod = prefs.getBool('remind_next_period') ?? false;
      final remindFertileWindow =
          prefs.getBool('remind_fertile_window') ?? false;
      final remindOvulation = prefs.getBool('remind_ovulation') ?? false;

      return reminders.where((reminder) {
        switch (reminder['type']) {
          case 'next period':
            return remindNextPeriod;
          case 'fertile window':
            return remindFertileWindow;
          case 'ovulation':
            return remindOvulation;
          default:
            return true;
        }
      }).toList();
    } catch (e) {
      print('❌ Calendar: Error in _filterRemindersByPreferences: $e');
      return reminders; // Return all reminders if error occurs
    }
  }

  // Get event color based on type
  Color _getEventColor(String eventType) {
    switch (eventType) {
      case 'medication':
        return Colors.blue;
      case 'appointment':
        return Colors.purple;
      case 'menstrual':
        return const Color(0xFFEC4899); // Pink for menstrual events
      case 'reminder':
        return const Color(0xFFEC4899); // Pink for reminder events
      default:
        return Colors.grey;
    }
  }

  // Get event description based on type
  String _getEventDescription(CalendarEvent event) {
    switch (event.type) {
      case 'medication':
        return 'Take your medication as prescribed';
      case 'appointment':
        return 'Medical appointment';
      case 'menstrual':
        if (event.title == 'Period Start') {
          return 'Your period is predicted to start today';
        } else if (event.title == 'Period End') {
          return 'Your period is predicted to end today';
        } else if (event.title == 'Ovulation Day') {
          return 'Today is your predicted ovulation day';
        } else if (event.title == 'Fertile Window') {
          return 'Your fertile window - best time for conception';
        }
        return 'Menstrual cycle event';
      case 'reminder':
        if (event.title.contains('Next Period')) {
          return 'Your period is predicted to start';
        } else if (event.title.contains('Ovulation')) {
          return 'Your ovulation day is predicted';
        } else if (event.title.contains('Fertile Window')) {
          return 'Your fertile window starts';
        }
        return 'Scheduled reminder';
      default:
        return 'Event';
    }
  }

  List<CalendarEvent> _getEventsForDay(DateTime day) {
    return _events[day] ?? [];
  }

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    if (!isSameDay(_selectedDay, selectedDay)) {
      setState(() {
        _selectedDay = selectedDay;
        _focusedDay = focusedDay;
      });
      _selectedEvents.value = _getEventsForDay(selectedDay);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: const Text('Calendar', style: TextStyle(color: Colors.black87)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: Colors.black87),
        actions: [
          IconButton(
            onPressed: () async {
              await _loadUserGender();
              await _loadEvents();
            },
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Calendar',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: GlassmorphicContainer(
          width: double.infinity,
          height: MediaQuery.of(context).size.height * 0.85,
          borderRadius: 32,
          blur: 12,
          alignment: Alignment.topCenter,
          border: 1.5,
          linearGradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withOpacity(0.85),
              Colors.white.withOpacity(0.7),
            ],
            stops: [0.1, 1],
          ),
          borderGradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.grey.withOpacity(0.2),
              Colors.white.withOpacity(0.2),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Your Health Calendar',
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87)),
                const SizedBox(height: 16),
                Expanded(
                  child: _isLoadingEvents
                      ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircularProgressIndicator(),
                              SizedBox(height: 16),
                              Text('Loading calendar events...',
                                  style: TextStyle(color: Colors.grey)),
                            ],
                          ),
                        )
                      : TableCalendar(
                          firstDay: DateTime.utc(2020, 1, 1),
                          lastDay: DateTime.utc(2030, 12, 31),
                          focusedDay: _focusedDay,
                          selectedDayPredicate: (day) =>
                              isSameDay(_selectedDay, day),
                          calendarFormat: _calendarFormat,
                          eventLoader: _getEventsForDay,
                          startingDayOfWeek: StartingDayOfWeek.monday,
                          calendarStyle: CalendarStyle(
                            outsideDaysVisible: false,
                            todayDecoration: BoxDecoration(
                              color: userAccent,
                              shape: BoxShape.circle,
                            ),
                            selectedDecoration: BoxDecoration(
                              color: userPrimary,
                              shape: BoxShape.circle,
                            ),
                            defaultTextStyle:
                                const TextStyle(color: Colors.black87),
                            weekendTextStyle:
                                const TextStyle(color: Colors.black54),
                            // Add event markers
                            markerDecoration: BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            markerSize: 6,
                            markerMargin:
                                const EdgeInsets.symmetric(horizontal: 0.3),
                          ),
                          // Custom event marker builder to show proper counts
                          calendarBuilders: CalendarBuilders(
                            markerBuilder: (context, date, events) {
                              if (events.isEmpty) return null;

                              // Filter out spacing events and cast to CalendarEvent
                              final realEvents = events
                                  .where((e) =>
                                      e is CalendarEvent && e.type != 'spacing')
                                  .cast<CalendarEvent>()
                                  .toList();
                              if (realEvents.isEmpty) return null;

                              // Show count badge for multiple events
                              if (realEvents.length > 1) {
                                return Positioned(
                                  right: 1,
                                  top: 1,
                                  child: Container(
                                    padding: const EdgeInsets.all(2),
                                    decoration: BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Text(
                                      '${realEvents.length}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                );
                              }

                              // Single event marker with type-specific color
                              final firstEvent = realEvents.first;
                              return Container(
                                decoration: BoxDecoration(
                                  color: firstEvent.color ??
                                      _getEventColor(firstEvent.type),
                                  shape: BoxShape.circle,
                                ),
                                width: 8,
                                height: 8,
                              );
                            },
                          ),
                          onDaySelected: _onDaySelected,
                          onFormatChanged: (format) {
                            if (_calendarFormat != format) {
                              setState(() {
                                _calendarFormat = format;
                              });
                            }
                          },
                          onPageChanged: (focusedDay) {
                            _focusedDay = focusedDay;
                          },
                        ),
                ),

                // Show selected day events details
                if (_selectedDay != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.95),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.withOpacity(0.2)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: userPrimary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(Icons.event_note,
                                  color: userPrimary, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Events for ${DateFormat('MMM dd, yyyy').format(_selectedDay!)}',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Events list
                        if (_getEventsForDay(_selectedDay!)
                            .where((event) => event.type != 'spacing')
                            .isEmpty)
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.grey.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: Column(
                                children: [
                                  Icon(Icons.event_available,
                                      color: Colors.grey[400], size: 48),
                                  const SizedBox(height: 8),
                                  Text(
                                    'No events scheduled',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.grey[600],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else
                          // Scrollable events list with height constraint
                          Container(
                            constraints: BoxConstraints(
                              maxHeight: MediaQuery.of(context).size.height *
                                  0.4, // Increased height
                            ),
                            child: SingleChildScrollView(
                              child: Column(
                                children: _getEventsForDay(_selectedDay!)
                                    .where((event) =>
                                        event.type !=
                                        'spacing') // Filter out spacing events
                                    .map((event) => Container(
                                          margin:
                                              const EdgeInsets.only(bottom: 12),
                                          padding: const EdgeInsets.all(16),
                                          decoration: BoxDecoration(
                                            color: (event.color ??
                                                    _getEventColor(event.type))
                                                .withOpacity(0.1),
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            border: Border.all(
                                              color: (event.color ??
                                                      _getEventColor(
                                                          event.type))
                                                  .withOpacity(0.3),
                                              width: 1.5,
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              Container(
                                                width: 16,
                                                height: 16,
                                                decoration: BoxDecoration(
                                                  color: event.color ??
                                                      _getEventColor(
                                                          event.type),
                                                  shape: BoxShape.circle,
                                                ),
                                              ),
                                              const SizedBox(width: 16),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      event.title,
                                                      style: TextStyle(
                                                        fontSize: 15,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: Colors.black87,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 6),
                                                    Text(
                                                      _getEventDescription(
                                                          event),
                                                      style: TextStyle(
                                                        fontSize: 13,
                                                        color: Colors.black54,
                                                        height: 1.3,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ))
                                    .toList(),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
