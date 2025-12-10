import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/api_service.dart';
import 'dart:async';

// Use local doctor colors defined in dashboard/update screens to avoid theme import
const Color kDoctorPrimary = Color(0xFF2196F3);
const Color kDoctorSecondary = Color(0xFF64B5F6);
const Color kDoctorBackground = Color(0xFFF8FBFF);
const Color kDoctorText = Color(0xFF1A237E);
const Color kDoctorTextSecondary = Color(0xFF546E7A);

class DoctorNotificationsScreen extends StatelessWidget {
  const DoctorNotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        appBarTheme: AppBarTheme(
          backgroundColor: kDoctorPrimary,
          foregroundColor: Colors.white,
          titleTextStyle: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        scaffoldBackgroundColor: kDoctorBackground,
      ),
      child: DefaultTabController(
        length: 2,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Notifications'),
            bottom: TabBar(
              labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              unselectedLabelStyle: GoogleFonts.poppins(),
              indicatorColor: Colors.white,
              tabs: const [
                Tab(text: 'All'),
                Tab(text: 'Requests'),
              ],
            ),
          ),
          body: TabBarView(
            children: [
              _NotificationsList(emptyText: 'No notifications yet'),
              _NotificationsList(emptyText: 'No requests yet'),
            ],
          ),
        ),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final String title;
  final String message;
  final String time;
  final String icon;
  final String type;

  const _NotificationTile({
    required this.title,
    required this.message,
    required this.time,
    this.icon = 'notifications',
    this.type = 'general',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: _getIconColor().withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(_getIcon(), color: _getIconColor()),
        ),
        title: Text(
          title,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: kDoctorText,
          ),
        ),
        subtitle: Text(
          message,
          style: GoogleFonts.poppins(color: kDoctorTextSecondary),
        ),
        trailing: Text(
          time,
          style: GoogleFonts.poppins(
            fontSize: 12,
            color: kDoctorTextSecondary,
          ),
        ),
      ),
    );
  }

  IconData _getIcon() {
    switch (icon) {
      case 'calendar_today':
        return Icons.calendar_today;
      case 'schedule':
        return Icons.schedule;
      case 'cancel':
        return Icons.cancel;
      case 'person_add':
        return Icons.person_add;
      default:
        return Icons.notifications;
    }
  }

  Color _getIconColor() {
    switch (type) {
      case 'appointment':
        return kDoctorPrimary;
      case 'assignment':
        return Colors.green;
      default:
        return kDoctorPrimary;
    }
  }
}

class _NotificationsList extends StatefulWidget {
  final String emptyText;
  const _NotificationsList({required this.emptyText});

  @override
  State<_NotificationsList> createState() => _NotificationsListState();
}

class _NotificationsListState extends State<_NotificationsList> {
  List<Map<String, dynamic>> notifications = [];
  bool isLoading = true;
  Timer? _pollTimer;
  final Set<String> _knownIds = {};

  @override
  void initState() {
    super.initState();
    _loadNotifications();
    _startPolling();
  }

  Future<void> _loadNotifications() async {
    try {
      setState(() => isLoading = true);

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() => isLoading = false);
        return;
      }

      // Load appointments for notifications
      final appointments = await ApiService.getDoctorAppointments(user.uid);

      // Load patient assignments (if available)
      // Note: This would need to be implemented in the backend

      List<Map<String, dynamic>> notificationList = [];

      // Add appointment notifications
      for (final appointment in appointments.take(10)) {
        final status = appointment.status.toLowerCase();
        String title = '';
        String message = '';
        String icon = '';

        if (status == 'confirmed') {
          title = 'Appointment Confirmed';
          message =
              'Patient ${appointment.patientName ?? 'Unknown'} confirmed their appointment for ${_formatDate(appointment.dateTime)}';
          icon = 'calendar_today';
        } else if (status == 'pending') {
          title = 'New Appointment Request';
          message =
              'Patient ${appointment.patientName ?? 'Unknown'} requested an appointment for ${_formatDate(appointment.dateTime)}';
          icon = 'schedule';
        } else if (status == 'cancelled') {
          title = 'Appointment Cancelled';
          message =
              'Patient ${appointment.patientName ?? 'Unknown'} cancelled their appointment for ${_formatDate(appointment.dateTime)}';
          icon = 'cancel';
        }

        if (title.isNotEmpty) {
          notificationList.add({
            'title': title,
            'message': message,
            'time': _formatTime(appointment.dateTime),
            'icon': icon,
            'type': 'appointment',
            'appointmentId': appointment.id,
          });
        }
      }

      // No mock notifications; only real appointment-derived notifications are shown

      // Sort by time (most recent first)
      notificationList.sort((a, b) => b['time'].compareTo(a['time']));

      setState(() {
        notifications = notificationList;
        isLoading = false;
        _knownIds
          ..clear()
          ..addAll(notificationList
              .map((e) => (e['appointmentId'] ?? e['title']).toString()));
      });
    } catch (e) {
      setState(() => isLoading = false);
      print('❌ Error loading notifications: $e');
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 20), (_) async {
      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) return;
        final appointments = await ApiService.getDoctorAppointments(user.uid);
        final List<Map<String, dynamic>> incoming = [];
        for (final appointment in appointments.take(10)) {
          final status = appointment.status.toLowerCase();
          if (status == 'confirmed' ||
              status == 'pending' ||
              status == 'scheduled' ||
              status == 'approved') {
            final id = appointment.id;
            if (!_knownIds.contains(id)) {
              incoming.add({
                'title': status == 'pending'
                    ? 'New Appointment Request'
                    : 'Appointment Updated',
                'message':
                    'Patient ${appointment.patientName ?? 'Unknown'} • ${_formatDate(appointment.dateTime)}',
                'time': _formatTime(appointment.dateTime),
                'icon': status == 'pending' ? 'schedule' : 'calendar_today',
                'type': 'appointment',
                'appointmentId': id,
              });
              _knownIds.add(id);
            }
          }
        }
        if (incoming.isNotEmpty && mounted) {
          setState(() {
            notifications = [...incoming, ...notifications];
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(incoming.length == 1
                    ? 'New notification'
                    : '${incoming.length} new notifications')),
          );
        }
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Unknown date';
    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatTime(DateTime? date) {
    if (date == null) return 'Unknown time';
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (notifications.isEmpty) {
      return Center(
        child: Text(
          widget.emptyText,
          style: GoogleFonts.poppins(color: kDoctorTextSecondary),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadNotifications,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: notifications.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final notification = notifications[index];
          return _NotificationTile(
            title: notification['title'] ?? 'Notification',
            message: notification['message'] ?? 'You have a new message',
            time: notification['time'] ?? 'Now',
            icon: notification['icon'] ?? 'notifications',
            type: notification['type'] ?? 'general',
          );
        },
      ),
    );
  }
}
