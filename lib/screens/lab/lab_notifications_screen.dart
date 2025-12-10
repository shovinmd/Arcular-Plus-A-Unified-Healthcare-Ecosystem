import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:arcular_plus/services/api_service.dart';
import 'package:arcular_plus/services/notification_service.dart';
import 'package:arcular_plus/screens/lab/lab_test_request_screen.dart';

class LabNotificationsScreen extends StatelessWidget {
  const LabNotificationsScreen({super.key});

  Color get _secondary => const Color(0xFFFB923C);

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Notifications',
              style: GoogleFonts.poppins(
                  color: Colors.white, fontWeight: FontWeight.w600)),
          backgroundColor: _secondary,
          iconTheme: const IconThemeData(color: Colors.white),
          bottom: TabBar(
            indicatorColor: Colors.white,
            tabs: [
              Tab(
                  child: Text('All',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600))),
              Tab(
                  child: Text('Requests',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600))),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _LabNotificationList(),
            _LabRequestList(),
          ],
        ),
      ),
    );
  }
}

class _LabNotificationList extends StatefulWidget {
  const _LabNotificationList();

  @override
  State<_LabNotificationList> createState() => _LabNotificationListState();
}

class _LabNotificationListState extends State<_LabNotificationList> {
  List<Map<String, dynamic>> _notifications = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    try {
      final notifications = await NotificationService.getNotifications('lab');
      setState(() {
        _notifications = notifications;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_notifications.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.notifications_off, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No notifications',
              style: GoogleFonts.poppins(
                fontSize: 18,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadNotifications,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _notifications.length,
        itemBuilder: (context, i) => _card(context, _notifications[i]),
      ),
    );
  }

  Widget _card(BuildContext context, Map<String, dynamic> notification) {
    final title = notification['title'] ?? 'Notification';
    final message = notification['message'] ?? '';
    final timestamp = notification['timestamp'] ?? DateTime.now();
    final type = notification['type'] ?? 'general';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 8,
              offset: const Offset(0, 4))
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [Color(0xFFFDBA74), Color(0xFFFB923C)]),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(_getNotificationIcon(type), color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title,
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(message,
                  style: GoogleFonts.poppins(color: const Color(0xFF6B7280))),
            ]),
          ),
          Text(_formatTimestamp(timestamp),
              style: GoogleFonts.poppins(
                  color: const Color(0xFF9CA3AF), fontSize: 12)),
        ],
      ),
    );
  }

  IconData _getNotificationIcon(String type) {
    switch (type) {
      case 'test_request':
        return Icons.science;
      case 'report_uploaded':
        return Icons.picture_as_pdf;
      case 'appointment':
        return Icons.calendar_today;
      default:
        return Icons.notifications;
    }
  }

  String _formatTimestamp(dynamic timestamp) {
    DateTime dateTime;
    if (timestamp is String) {
      dateTime = DateTime.parse(timestamp);
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
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }
}

class _LabRequestList extends StatefulWidget {
  const _LabRequestList();

  @override
  State<_LabRequestList> createState() => _LabRequestListState();
}

class _LabRequestListState extends State<_LabRequestList> {
  List<Map<String, dynamic>> _testRequests = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadTestRequests();
  }

  Future<void> _loadTestRequests() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() => _loading = false);
        return;
      }

      final labMongoId = await ApiService.getLabMongoId(user.uid);
      if (labMongoId == null) {
        setState(() => _loading = false);
        return;
      }

      final requests = await ApiService.getLabTestRequests(labMongoId);

      // Create notifications for new test requests
      for (final request in requests) {
        final status = request['status'] ?? 'Unknown';
        final urgency = request['urgency'] ?? 'Normal';
        final patientName = request['patientName'] ?? 'Unknown Patient';
        final testName = request['testName'] ?? 'Test';
        final hospitalName = request['hospitalName'] ?? 'Unknown Hospital';

        // Only create notifications for pending requests
        if (status.toLowerCase() == 'pending') {
          await NotificationService.saveNotification(
            userType: 'lab',
            type: NotificationService.notificationTypeTestRequest,
            title: 'New Test Request',
            message: '$urgency: $testName for $patientName from $hospitalName',
            data: {
              'requestId': request['requestId'],
              'patientName': patientName,
              'testName': testName,
              'hospitalName': hospitalName,
              'urgency': urgency,
              'status': status,
            },
          );
        }
      }

      setState(() {
        _testRequests = requests;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_testRequests.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.science_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No test requests',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Test requests from hospitals will appear here',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadTestRequests,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _testRequests.length,
        itemBuilder: (context, i) =>
            _buildTestRequestCard(context, _testRequests[i]),
      ),
    );
  }

  Widget _buildTestRequestCard(
      BuildContext context, Map<String, dynamic> request) {
    final status = request['status'] ?? 'Unknown';
    final urgency = request['urgency'] ?? 'Normal';
    final patientName = request['patientName'] ?? 'Unknown Patient';
    final testName = request['testName'] ?? 'Test';
    final hospitalName = request['hospitalName'] ?? 'Unknown Hospital';
    final createdAt = request['createdAt'] ?? '';

    // Format time
    String timeAgo = 'Unknown';
    if (createdAt.isNotEmpty) {
      try {
        final date = DateTime.parse(createdAt);
        final now = DateTime.now();
        final difference = now.difference(date);

        if (difference.inMinutes < 60) {
          timeAgo = '${difference.inMinutes}m ago';
        } else if (difference.inHours < 24) {
          timeAgo = '${difference.inHours}h ago';
        } else {
          timeAgo = '${difference.inDays}d ago';
        }
      } catch (e) {
        timeAgo = 'Unknown';
      }
    }

    // Get icon and color based on status and urgency
    IconData icon;
    Color iconColor;

    if (urgency == 'Emergency' || urgency == 'High') {
      icon = Icons.priority_high;
      iconColor = Colors.red;
    } else if (status == 'Pending') {
      icon = Icons.science;
      iconColor = Colors.orange;
    } else if (status == 'Admitted') {
      icon = Icons.check_circle;
      iconColor = Colors.green;
    } else if (status == 'Completed') {
      icon = Icons.task_alt;
      iconColor = Colors.blue;
    } else {
      icon = Icons.science;
      iconColor = Colors.grey;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: InkWell(
          onTap: () {
            // Navigate to test request screen
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const LabTestRequestScreen(),
              ),
            );
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: iconColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$urgency: $testName',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$patientName from $hospitalName',
                        style: GoogleFonts.poppins(
                          color: const Color(0xFF6B7280),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Status: $status',
                        style: GoogleFonts.poppins(
                          color: const Color(0xFF9CA3AF),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      timeAgo,
                      style: GoogleFonts.poppins(
                        color: const Color(0xFF9CA3AF),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _getStatusColor(status).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        status,
                        style: GoogleFonts.poppins(
                          color: _getStatusColor(status),
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'admitted':
        return Colors.green;
      case 'completed':
        return Colors.blue;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}
