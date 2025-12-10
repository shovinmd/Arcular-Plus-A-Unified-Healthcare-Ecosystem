import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:arcular_plus/services/api_service.dart';
import 'package:arcular_plus/services/notification_service.dart';
import 'dart:async';

class NotificationScreen extends StatefulWidget {
  final String hospitalId;

  const NotificationScreen({Key? key, required this.hospitalId})
      : super(key: key);

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Load real-time notifications from NotificationService
      await NotificationService.getNotifications('hospital');

      // Also load test request notifications
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final hospitalMongoId = await ApiService.getHospitalMongoId(user.uid);
        if (hospitalMongoId != null) {
          final testRequests =
              await ApiService.getHospitalTestRequests(hospitalMongoId);

          // Create notifications for new test requests
          for (final request in testRequests) {
            final status = request['status'] ?? 'Unknown';
            final urgency = request['urgency'] ?? 'Normal';
            final patientName = request['patientName'] ?? 'Unknown Patient';
            final testName = request['testName'] ?? 'Test';
            final labName = request['labName'] ?? 'Unknown Lab';

            // Create notifications for different test request statuses
            if (status.toLowerCase() == 'pending') {
              await NotificationService.saveNotification(
                userType: 'hospital',
                type: NotificationService.notificationTypeTestRequest,
                title: 'New Test Request',
                message: '$urgency: $testName for $patientName from $labName',
                data: {
                  'requestId': request['requestId'],
                  'patientName': patientName,
                  'testName': testName,
                  'labName': labName,
                  'urgency': urgency,
                  'status': status,
                },
              );
            } else if (status.toLowerCase() == 'admitted') {
              await NotificationService.saveNotification(
                userType: 'hospital',
                type: 'lab_admitted',
                title: 'Test Request Admitted',
                message:
                    '$testName for $patientName has been admitted by $labName',
                data: {
                  'requestId': request['requestId'],
                  'patientName': patientName,
                  'testName': testName,
                  'labName': labName,
                  'status': status,
                },
              );
            } else if (status.toLowerCase() == 'completed') {
              await NotificationService.saveNotification(
                userType: 'hospital',
                type: 'lab_completed',
                title: 'Test Completed',
                message:
                    '$testName for $patientName has been completed by $labName',
                data: {
                  'requestId': request['requestId'],
                  'patientName': patientName,
                  'testName': testName,
                  'labName': labName,
                  'status': status,
                },
              );
            }
          }

          // Load real SOS requests and create notifications
          try {
            final sosRequests =
                await ApiService.getHospitalSOSRequests(user.uid);

            for (final request in sosRequests) {
              final status = request['hospitalStatus'] ?? 'unknown';
              final patientName =
                  request['patientInfo']?['patientName'] ?? 'Unknown Patient';
              final emergencyType =
                  request['emergencyDetails']?['emergencyType'] ?? 'Medical';
              final severity =
                  request['emergencyDetails']?['severity'] ?? 'High';
              final address = request['emergencyDetails']?['location']
                      ?['address'] ??
                  'Unknown location';

              if (status == 'notified') {
                await NotificationService.saveNotification(
                  userType: 'hospital',
                  type: 'sos',
                  title: '🚨 SOS Emergency Alert',
                  message:
                      '$severity $emergencyType emergency from $patientName at $address',
                  data: {
                    'type': 'sos',
                    'priority': 'high',
                    'sosRequestId': request['sosRequestId'],
                    'patientName': patientName,
                    'emergencyType': emergencyType,
                    'severity': severity,
                    'address': address,
                    'timestamp': DateTime.now().toIso8601String(),
                  },
                );
              }
            }
          } catch (e) {
            print('❌ Error loading SOS requests for notifications: $e');
          }

          // Add appointment notification (mock for now)
          await NotificationService.saveNotification(
            userType: 'hospital',
            type: 'appointment_confirmed',
            title: 'Appointment Confirmed',
            message: 'New appointment confirmed for patient',
            data: {
              'type': 'appointment',
              'status': 'confirmed',
            },
          );

          // Add pharmacy order notification (mock for now)
          await NotificationService.saveNotification(
            userType: 'hospital',
            type: 'order_completed',
            title: 'Order Completed',
            message: 'Medicine order completed by pharmacy',
            data: {
              'type': 'order',
              'status': 'completed',
            },
          );
        }
      }

      // Get updated notifications
      final updatedNotifications =
          await NotificationService.getNotifications('hospital');

      setState(() {
        _notifications = updatedNotifications;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading notifications: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _formatTimestamp(dynamic timestamp) {
    DateTime dateTime;

    // Handle both string and DateTime inputs
    if (timestamp is String) {
      try {
        dateTime = DateTime.parse(timestamp);
      } catch (e) {
        return 'Unknown';
      }
    } else if (timestamp is DateTime) {
      dateTime = timestamp;
    } else {
      return 'Unknown';
    }

    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes} min ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours} hours ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }

  IconData _getNotificationIcon(String type) {
    switch (type) {
      case 'sos':
        return Icons.emergency;
      case 'appointment':
      case 'appointment_confirmed':
        return Icons.calendar_today;
      case 'staff':
        return Icons.people;
      case 'system':
        return Icons.info;
      case 'test_request':
        return Icons.science;
      case 'lab_admitted':
        return Icons.check_circle;
      case 'lab_completed':
        return Icons.done_all;
      case 'order_completed':
        return Icons.local_pharmacy;
      default:
        return Icons.notifications;
    }
  }

  Color _getNotificationColor(String type) {
    switch (type) {
      case 'sos':
        return Colors.red.shade400;
      case 'appointment':
      case 'appointment_confirmed':
        return Colors.blue.shade400;
      case 'staff':
        return Colors.green.shade400;
      case 'system':
        return Colors.orange.shade400;
      case 'test_request':
        return Colors.purple.shade400;
      case 'lab_admitted':
        return Colors.blue.shade400;
      case 'lab_completed':
        return Colors.green.shade400;
      case 'order_completed':
        return Colors.yellow.shade600;
      default:
        return Colors.grey.shade400;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: Text(
          'Notifications',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xFF4CAF50),
                Color(0xFF81C784),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadNotifications,
            tooltip: 'Refresh notifications',
          ),
          IconButton(
            icon: const Icon(Icons.mark_email_read, color: Colors.white),
            onPressed: () async {
              await NotificationService.markAllAsRead('hospital');
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'All notifications marked as read!',
                    style: GoogleFonts.poppins(),
                  ),
                  backgroundColor: const Color(0xFF4CAF50),
                ),
              );
            },
            tooltip: 'Mark all as read',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4CAF50)),
              ),
            )
          : _notifications.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.notifications_off,
                        size: 80,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No new notifications',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadNotifications,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _notifications.length,
                    itemBuilder: (context, index) {
                      final notification = _notifications[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 3,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: InkWell(
                          onTap: () {
                            // TODO: Handle notification tap (e.g., navigate to relevant screen)
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Tapped on: ${notification['title']}',
                                  style: GoogleFonts.poppins(),
                                ),
                                backgroundColor: const Color(0xFF4CAF50),
                              ),
                            );
                            setState(() {
                              notification['read'] =
                                  true; // Mark as read on tap
                            });
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CircleAvatar(
                                  backgroundColor: _getNotificationColor(
                                      notification['type']),
                                  child: Icon(
                                    _getNotificationIcon(notification['type']),
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        notification['title'],
                                        style: GoogleFonts.poppins(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: (notification['read'] ?? false)
                                              ? Colors.grey[700]
                                              : Colors.black87,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        notification['message'],
                                        style: GoogleFonts.poppins(
                                          fontSize: 14,
                                          color: (notification['read'] ?? false)
                                              ? Colors.grey[500]
                                              : Colors.grey[700],
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        _formatTimestamp(
                                            notification['timestamp']),
                                        style: GoogleFonts.poppins(
                                          fontSize: 12,
                                          color: Colors.grey[400],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (!(notification['read'] ?? false))
                                  Container(
                                    width: 10,
                                    height: 10,
                                    decoration: const BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
