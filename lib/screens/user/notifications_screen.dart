import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/api_service.dart';
import '../../services/fcm_service.dart';
import '../../models/medicine_model.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> with WidgetsBindingObserver {
  int _selectedIndex = 0;
  List<Map<String, dynamic>> _notifications = [];
  List<Map<String, dynamic>> _upcomingReminders = [];
  bool _isLoading = true;
  String? _currentUserId;
  String _userGender = 'Female'; // Default to Female
  final FCMService _fcmService = FCMService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _getCurrentUserId();
    _loadUserGender();
    _loadNotifications();
    
    // Listen for FCM events to refresh notifications
    _fcmService.events.listen((event) {
      final type = (event['type'] ?? '').toString().toLowerCase();
      if (type.contains('order') || type.contains('appointment') || type.contains('notification')) {
        _loadNotifications();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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
        // Reset selected index if it's invalid for current user
        if (_userGender != 'Female' && _selectedIndex == 4) {
          _selectedIndex = 0; // Reset to All tab for male users
        }
      });
      print('🔍 Loaded user gender: $_userGender');
    } catch (e) {
      print('❌ Error loading user gender: $e');
    }
  }

  Future<void> _loadNotifications() async {
    if (_currentUserId == null) return;
    
    try {
      setState(() => _isLoading = true);
      
      // Load real notifications from backend
      final notifications = await ApiService.getUserNotifications(_currentUserId!);
      
      // Add order and appointment notifications
      final orderNotifications = await _loadOrderNotifications();
      final appointmentNotifications = await _loadAppointmentNotifications();
      
      // Load upcoming reminders from FCM service
      await _loadUpcomingReminders();
      
      setState(() {
        _notifications = [
          ...(notifications ?? []),
          ...orderNotifications,
          ...appointmentNotifications,
        ];
        _isLoading = false;
      });
    } catch (e) {
      print('❌ Error loading notifications: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<List<Map<String, dynamic>>> _loadOrderNotifications() async {
    try {
      final orders = await ApiService.getOrdersByUser(_currentUserId!);
      return orders.map((order) => {
        'id': order['_id'] ?? order['id'],
        'type': 'order',
        'title': 'Order Update',
        'message': 'Your order #${order['_id'] ?? order['id']} status: ${order['status']}',
        'timestamp': order['updatedAt'] ?? order['createdAt'] ?? DateTime.now().toIso8601String(),
        'isRead': false,
        'data': order,
      }).toList();
    } catch (e) {
      print('❌ Error loading order notifications: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _loadAppointmentNotifications() async {
    try {
      final appointments = await ApiService.getAppointments(_currentUserId!);
      print('🔔 Notifications: Loaded ${appointments.length} appointments for notifications');
      
      List<Map<String, dynamic>> notifications = [];
      
      for (var appointment in appointments) {
        try {
          final now = DateTime.now();
          final appointmentDate = appointment.dateTime;
          final daysUntil = appointmentDate.difference(now).inDays;
        
        // Create different notification types based on appointment timing
        if (daysUntil == 0) {
          // Today's appointment
          notifications.add({
            'id': '${appointment.id}_today',
            'type': 'appointment',
            'title': 'Appointment Today',
            'message': 'You have an appointment with ${appointment.doctorName} today at ${DateFormat('HH:mm').format(appointmentDate)}',
            'timestamp': now.toIso8601String(),
            'isRead': false,
            'priority': 'high',
            'data': appointment.toJson(),
          });
        } else if (daysUntil == 1) {
          // Tomorrow's appointment
          notifications.add({
            'id': '${appointment.id}_tomorrow',
            'type': 'appointment',
            'title': 'Appointment Tomorrow',
            'message': 'You have an appointment with ${appointment.doctorName} tomorrow at ${DateFormat('HH:mm').format(appointmentDate)}',
            'timestamp': now.toIso8601String(),
            'isRead': false,
            'priority': 'medium',
            'data': appointment.toJson(),
          });
        } else if (daysUntil <= 7 && daysUntil > 0) {
          // This week's appointment
          notifications.add({
            'id': '${appointment.id}_upcoming',
            'type': 'appointment',
            'title': 'Upcoming Appointment',
            'message': 'You have an appointment with ${appointment.doctorName} on ${DateFormat('MMM d, y').format(appointmentDate)}',
            'timestamp': now.toIso8601String(),
            'isRead': false,
            'priority': 'low',
            'data': appointment.toJson(),
          });
        }
        
        // Add appointment status notification
        notifications.add({
          'id': '${appointment.id}_status',
          'type': 'appointment',
          'title': 'Appointment Status',
          'message': 'Appointment with ${appointment.doctorName} - Status: ${appointment.status}',
          'timestamp': appointmentDate.toIso8601String(),
          'isRead': false,
          'priority': 'low',
          'data': appointment.toJson(),
        });
        } catch (e) {
          print('❌ Error processing appointment ${appointment.id}: $e');
          // Continue with next appointment
        }
      }
      
      return notifications;
    } catch (e) {
      print('❌ Error loading appointment notifications: $e');
      return [];
    }
  }

  Future<void> _loadUpcomingReminders() async {
    // Only load menstrual reminders for female users
    if (_userGender != 'Female') {
      setState(() {
        _upcomingReminders = [];
      });
      print('⚠️ User is male, skipping menstrual reminders');
      return;
    }
    
    try {
      await _fcmService.initialize();
      final reminders = await _fcmService.getUpcomingReminders();
      setState(() {
        _upcomingReminders = reminders;
      });
      print('✅ Loaded ${reminders.length} upcoming reminders for female user');
      
      // Debug: Print reminder details
      for (final reminder in reminders) {
        print('🔍 Reminder: ${reminder['type']} - ${reminder['title']} - ${reminder['body']} - ${reminder['date']}');
      }
    } catch (e) {
      print('❌ Error loading upcoming reminders: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue.shade600, Colors.blue.shade800],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadNotifications,
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _openNotificationSettings,
          ),
        ],
      ),
      body: Column(
        children: [
          // Tab Bar
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue.shade400, Colors.blue.shade700],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildTabButton('All', 0),
                ),
                Expanded(
                  child: _buildTabButton('Medication', 1),
                ),
                Expanded(
                  child: _buildTabButton('Appointments', 2),
                ),
                Expanded(
                  child: _buildTabButton('Reports', 3),
                ),
                Expanded(
                  child: _buildTabButton('Completed', 4),
                ),
                // Only show Menstrual tab for female users
                if (_userGender == 'Female') ...[
                  Expanded(
                    child: _buildTabButton('Menstrual', 5),
                  ),
                ],

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
        decoration: BoxDecoration(
          color: isSelected ? Colors.white.withOpacity(0.2) : Colors.transparent,
          border: Border(
            bottom: BorderSide(
              color: isSelected ? Colors.white : Colors.white.withOpacity(0.3),
              width: 3,
            ),
          ),
        ),
        child: Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white.withOpacity(0.8),
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 10,
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    // Adjust tab index based on user gender
    if (_userGender == 'Female') {
      // Female users have all tabs including Menstrual
      switch (_selectedIndex) {
        case 0:
          return _buildAllNotifications();
        case 1:
          return _buildMedicationNotifications();
        case 2:
          return _buildAppointmentNotifications();
        case 3:
          return _buildReportNotifications();
        case 4:
          return _buildCompletedMedicines();
        case 5:
          return _buildMenstrualCycleNotifications();
        default:
          return _buildAllNotifications();
      }
    } else {
      // Male users don't have Menstrual tab
      switch (_selectedIndex) {
        case 0:
          return _buildAllNotifications();
        case 1:
          return _buildMedicationNotifications();
        case 2:
          return _buildAppointmentNotifications();
        case 3:
          return _buildReportNotifications();
        case 4:
          return _buildCompletedMedicines();
        default:
          return _buildAllNotifications();
      }
    }
  }

  Widget _buildAllNotifications() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    return _buildNotificationList(_notifications);
  }

  Widget _buildMedicationNotifications() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    
    // Show both notifications and active medicines
    return FutureBuilder<List<dynamic>>(
      future: _loadMedicinesForNotifications(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        
        final medicines = snapshot.data ?? [];
        
        if (medicines.isEmpty) {
          return const Center(
            child: Text(
              'No active medicines found',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          );
        }
        
        return ListView.builder(
          itemCount: medicines.length,
          itemBuilder: (context, index) {
            final medicine = medicines[index];
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ListTile(
                leading: Icon(
                  medicine['isTaken'] ? Icons.check_circle : Icons.medication,
                  color: medicine['isTaken'] ? Colors.green : Colors.blue,
                ),
                title: Text(
                  medicine['name'],
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (medicine['dosage'] != null) Text('Dosage: ${medicine['dosage']}'),
                    if (medicine['frequency'] != null) Text('Frequency: ${medicine['frequency']}'),
                    if (medicine['instructions'] != null) Text('Instructions: ${medicine['instructions']}'),
                    if (medicine['times'] != null && medicine['times'].isNotEmpty) 
                      Text('Times: ${medicine['times'].join(', ')}'),
                  ],
                ),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: medicine['isTaken'] ? Colors.green : Colors.orange,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    medicine['isTaken'] ? 'Taken' : 'Pending',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
  
  // Load medicines for notification screen
  Future<List<dynamic>> _loadMedicinesForNotifications() async {
    try {
      final userId = _currentUserId;
      if (userId == null) return [];
      
      final medicines = await ApiService.getMedications(userId);
      return medicines.map((med) => med.toJson()).toList();
    } catch (e) {
      print('❌ Error loading medicines for notifications: $e');
      return [];
    }
  }
  
  // Build completed medicines tab
  Widget _buildCompletedMedicines() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    
    return FutureBuilder<List<dynamic>>(
      future: _loadCompletedMedicines(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        
        final medicines = snapshot.data ?? [];
        
        if (medicines.isEmpty) {
          return const Center(
            child: Text(
              'No completed medicines found',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          );
        }
        
        return ListView.builder(
          itemCount: medicines.length,
          itemBuilder: (context, index) {
            final medicine = medicines[index];
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ListTile(
                leading: const Icon(
                  Icons.check_circle,
                  color: Colors.green,
                ),
                title: Text(
                  medicine['name'],
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (medicine['dosage'] != null) Text('Dosage: ${medicine['dosage']}'),
                    if (medicine['frequency'] != null) Text('Frequency: ${medicine['frequency']}'),
                    if (medicine['instructions'] != null) Text('Instructions: ${medicine['instructions']}'),
                    Text('Status: Completed', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
  
  // Load completed medicines
  Future<List<dynamic>> _loadCompletedMedicines() async {
    try {
      final userId = _currentUserId;
      if (userId == null) return [];
      
      final medicines = await ApiService.getMedications(userId);
      return medicines.where((med) => med.isTaken).map((med) => med.toJson()).toList();
    } catch (e) {
      print('❌ Error loading completed medicines: $e');
      return [];
    }
  }
  
  // Update medicine status
  Future<void> _updateMedicineStatus(String medicineId, bool isTaken) async {
    try {
      // Update medicine status in the backend
      final medicines = await _loadMedicinesForNotifications();
      final medicine = medicines.firstWhere((m) => m['id'] == medicineId);
      
      if (medicine != null) {
        // Create updated medicine model
        final updatedMedicine = MedicineModel(
          id: medicine['id'],
          name: medicine['name'],
          dose: medicine['dose'] ?? '',
          frequency: medicine['frequency'] ?? '',
          type: medicine['type'] ?? 'tablet',
          isTaken: isTaken,
          dosage: medicine['dosage'],
          duration: medicine['duration'],
          times: medicine['times'] != null ? List<String>.from(medicine['times']) : null,
          instructions: medicine['instructions'],
          startDate: medicine['startDate'] != null ? DateTime.parse(medicine['startDate']) : null,
          endDate: medicine['endDate'] != null ? DateTime.parse(medicine['endDate']) : null,
        );
        
        // Update in backend
        await ApiService.updateMedication(updatedMedicine);
        
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Medicine marked as ${isTaken ? "taken" : "not taken"}'),
            backgroundColor: isTaken ? Colors.green : Colors.orange,
          ),
        );
        
        // Refresh medicines
        setState(() {});
        await _loadMedicinesForNotifications();
      }
    } catch (e) {
      print('❌ Error updating medicine status: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update medicine status'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  


  Widget _buildAppointmentNotifications() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    final notifications = _notifications
        .where((notification) => notification['type'] == 'appointment')
        .toList();
    return _buildNotificationList(notifications);
  }

  Widget _buildReportNotifications() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    final notifications = _notifications
        .where((notification) => notification['type'] == 'report')
        .toList();
    return _buildNotificationList(notifications);
  }

  Widget _buildMenstrualCycleNotifications() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Upcoming Reminders Section
          if (_upcomingReminders.isNotEmpty) ...[
            Text(
              'Upcoming Reminders',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.pink[700],
              ),
            ),
            const SizedBox(height: 12),
            ...(_upcomingReminders.map((reminder) => Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.pink.withOpacity(0.3)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.pink.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(
                    _getReminderIcon(reminder['type'] ?? ''),
                    color: Colors.pink[600],
                    size: 24,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          reminder['title'] ?? 'Reminder',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          reminder['body'] ?? '',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Date: ${DateFormat('MMM dd, yyyy').format(DateTime.parse(reminder['date']))}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[500],
                          ),
                        ),
                        if (reminder['time'] != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Time: ${reminder['time']}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            )).toList()),
            const SizedBox(height: 24),
          ],

          // Menstrual Cycle Notifications Section
          Text(
            'Recent Notifications',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.pink[700],
            ),
          ),
          const SizedBox(height: 12),
          
          // Show actual notifications if any
          ...(_notifications.where((notification) => 
            notification['type'] == 'menstrual_cycle'
          ).map((notification) => _buildNotificationCard(notification)).toList()),

          // Show empty state if no notifications
          if (_notifications.where((notification) => 
            notification['type'] == 'menstrual_cycle'
          ).isEmpty && _upcomingReminders.isEmpty) ...[
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.bloodtype,
                    size: 64,
                    color: Colors.pink.withOpacity(0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No menstrual cycle notifications',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'You\'ll receive notifications for period reminders, ovulation alerts, and fertile window notifications.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNotificationList(List<Map<String, dynamic>> notifications) {
    if (notifications.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.notifications_none, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No notifications',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: notifications.length,
      itemBuilder: (context, index) {
        final notification = notifications[index];
        return _buildNotificationCard(notification);
      },
    );
  }

  Widget _buildNotificationCard(Map<String, dynamic> notification) {
    final isRead = notification['isRead'] ?? false;
    
    return Card(
      elevation: isRead ? 1 : 3,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: isRead ? Colors.white : Colors.blue[50],
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getNotificationColor(notification['type']),
          child: Icon(
            _getNotificationIcon(notification['type']),
            color: Colors.white,
          ),
        ),
        title: Text(
          notification['title'],
          style: TextStyle(
            fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(notification['message']),
            const SizedBox(height: 4),
            Text(
              _formatTime(notification['timestamp']),
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) => _handleNotificationAction(value, notification),
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'mark_read',
              child: Row(
                children: [
                  Icon(Icons.check_circle_outline),
                  SizedBox(width: 8),
                  Text('Mark as read'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete_outline, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Delete', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ],
        ),
        onTap: () => _handleNotificationTap(notification),
      ),
    );
  }

  // Mock data removed - now using real backend data from ApiService.getUserNotifications()

  Color _getNotificationColor(String type) {
    switch (type) {
      case 'medication':
        return Colors.orange;
      case 'appointment':
        return Colors.blue;
      case 'report':
        return Colors.green;
      case 'emergency':
        return Colors.red;
      case 'menstrual_cycle':
        return Colors.pink;
      default:
        return Colors.grey;
    }
  }

  IconData _getNotificationIcon(String type) {
    switch (type) {
      case 'medication':
        return Icons.medication;
      case 'appointment':
        return Icons.calendar_today;
      case 'report':
        return Icons.description;
      case 'emergency':
        return Icons.emergency;
      case 'menstrual_cycle':
        return Icons.bloodtype;
      default:
        return Icons.notifications;
    }
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

  String _formatTime(dynamic timestamp) {
    DateTime dateTime;
    
    // Handle both string and DateTime inputs
    if (timestamp is String) {
      try {
        dateTime = DateTime.parse(timestamp);
      } catch (e) {
        print('❌ Error parsing timestamp: $timestamp - $e');
        return 'Unknown time';
      }
    } else if (timestamp is DateTime) {
      dateTime = timestamp;
    } else {
      print('❌ Invalid timestamp type: ${timestamp.runtimeType}');
      return 'Unknown time';
    }
    
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return DateFormat('MMM d, y').format(dateTime);
    }
  }

  void _handleNotificationTap(Map<String, dynamic> notification) {
    // Mark as read
    notification['isRead'] = true;
    setState(() {});

    // Handle the notification action
    _handleNotificationAction(notification['action'], notification);
  }

  void _handleNotificationAction(String action, Map<String, dynamic> notification) {
    switch (action) {
      case 'mark_read':
        notification['isRead'] = true;
        setState(() {});
        break;
      case 'delete':
        _deleteNotification(notification);
        break;
      case 'take_medication':
        _takeMedication(notification);
        break;
      case 'view_appointment':
        _viewAppointment(notification);
        break;
      case 'view_report':
        _viewReport(notification);
        break;
      case 'refill_medication':
        _refillMedication(notification);
        break;
      case 'report_side_effect':
        _reportSideEffect(notification);
        break;
      case 'reschedule_appointment':
        _rescheduleAppointment(notification);
        break;
    }
  }

  void _deleteNotification(Map<String, dynamic> notification) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Notification'),
        content: const Text('Are you sure you want to delete this notification?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Implement delete functionality
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Notification deleted')),
              );
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _takeMedication(Map<String, dynamic> notification) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Take Medication'),
        content: Text('Did you take ${notification['title']}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              notification['isRead'] = true;
              setState(() {});
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Medication logged')),
              );
            },
            child: const Text('Yes'),
          ),
        ],
      ),
    );
  }

  void _viewAppointment(Map<String, dynamic> notification) {
    // TODO: Navigate to appointment details
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Viewing appointment ${notification['appointmentId']}')),
    );
  }

  void _viewReport(Map<String, dynamic> notification) {
    // TODO: Navigate to report details
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Viewing report ${notification['reportId']}')),
    );
  }

  void _refillMedication(Map<String, dynamic> notification) {
    // TODO: Navigate to medication refill
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Refilling medication ${notification['medicationId']}')),
    );
  }

  void _reportSideEffect(Map<String, dynamic> notification) {
    // TODO: Navigate to side effect reporting
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Reporting side effects for ${notification['medicationId']}')),
    );
  }

  void _rescheduleAppointment(Map<String, dynamic> notification) {
    // TODO: Navigate to appointment rescheduling
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Rescheduling appointment ${notification['appointmentId']}')),
    );
  }

  void _openNotificationSettings() async {
    // Load current prefs
    final prefs = await SharedPreferences.getInstance();
    bool med = prefs.getBool('notif_medication') ?? true;
    bool appt = prefs.getBool('notif_appointments') ?? true;
    bool lab = prefs.getBool('notif_lab') ?? true;
    bool emerg = prefs.getBool('notif_emergency') ?? true;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Notification Settings'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SwitchListTile(
                title: const Text('Medication Reminders'),
                subtitle: const Text('Get notified when it\'s time to take medication'),
                value: med,
                onChanged: (value) async {
                  setState(() => med = value);
                  await prefs.setBool('notif_medication', value);
                },
              ),
              SwitchListTile(
                title: const Text('Appointment Reminders'),
                subtitle: const Text('Get notified about upcoming appointments'),
                value: appt,
                onChanged: (value) async {
                  setState(() => appt = value);
                  await prefs.setBool('notif_appointments', value);
                },
              ),
              SwitchListTile(
                title: const Text('Lab Reports'),
                subtitle: const Text('Get notified when reports are ready'),
                value: lab,
                onChanged: (value) async {
                  setState(() => lab = value);
                  await prefs.setBool('notif_lab', value);
                },
              ),
              SwitchListTile(
                title: const Text('Emergency Alerts'),
                subtitle: const Text('Get notified about urgent health matters'),
                value: emerg,
                onChanged: (value) async {
                  setState(() => emerg = value);
                  await prefs.setBool('notif_emergency', value);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }
} 