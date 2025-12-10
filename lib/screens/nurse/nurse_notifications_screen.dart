import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/api_service.dart';

// Nurse theme colors
const Color kNursePrimary = Color(0xFFC084FC);
const Color kNurseSecondary = Color(0xFFA78BFA);
const Color kNurseBackground = Color(0xFFF9FAFB);
const Color kNurseText = Color(0xFF2E2E2E);
const Color kNurseTextSecondary = Color(0xFF6B7280);

class NurseNotificationsScreen extends StatefulWidget {
  const NurseNotificationsScreen({super.key});

  @override
  State<NurseNotificationsScreen> createState() =>
      _NurseNotificationsScreenState();
}

class _NurseNotificationsScreenState extends State<NurseNotificationsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _notifications = [];
  List<Map<String, dynamic>> _requests = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final notifications = await ApiService.getUserNotifications(user.uid);
        setState(() {
          _notifications = notifications;
          _requests =
              notifications.where((n) => n['type'] == 'request').toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading notifications: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kNurseBackground,
      appBar: AppBar(
        title: Text(
          'Notifications',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: kNursePrimary,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white.withOpacity(0.7),
          labelStyle: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
          unselectedLabelStyle: GoogleFonts.poppins(
            fontWeight: FontWeight.w500,
            fontSize: 14,
          ),
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'Requests'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildAllNotificationsTab(),
          _buildRequestsTab(),
        ],
      ),
    );
  }

  Widget _buildAllNotificationsTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _loadNotifications,
      child: _notifications.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_none, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No notifications yet',
                      style: TextStyle(color: Colors.grey)),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _notifications.length,
              itemBuilder: (context, index) {
                final notification = _notifications[index];
                return _buildNotificationCard(
                  icon: _getNotificationIcon(notification['type'] ?? ''),
                  title: notification['title'] ?? 'Notification',
                  message: notification['message'] ?? '',
                  time: _formatTime(notification['createdAt']),
                  isRead: notification['isRead'] ?? false,
                );
              },
            ),
    );
  }

  Widget _buildRequestsTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _loadNotifications,
      child: _requests.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.request_page, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No requests yet', style: TextStyle(color: Colors.grey)),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _requests.length,
              itemBuilder: (context, index) {
                final request = _requests[index];
                return _buildRequestCard(
                  icon: _getRequestIcon(request['type'] ?? ''),
                  title: request['title'] ?? 'Request',
                  message: request['message'] ?? '',
                  time: _formatTime(request['createdAt']),
                  status: request['status'] ?? 'Pending',
                );
              },
            ),
    );
  }

  IconData _getNotificationIcon(String type) {
    switch (type.toLowerCase()) {
      case 'assignment':
        return Icons.person_add;
      case 'medication':
        return Icons.medication;
      case 'schedule':
        return Icons.schedule;
      case 'emergency':
        return Icons.warning;
      case 'request':
        return Icons.request_page;
      default:
        return Icons.notifications;
    }
  }

  IconData _getRequestIcon(String type) {
    switch (type.toLowerCase()) {
      case 'leave':
        return Icons.event_busy;
      case 'shift_swap':
        return Icons.swap_horiz;
      case 'overtime':
        return Icons.schedule;
      default:
        return Icons.request_page;
    }
  }

  String _formatTime(String? timestamp) {
    if (timestamp == null) return 'Unknown time';

    try {
      final dateTime = DateTime.parse(timestamp);
      final now = DateTime.now();
      final difference = now.difference(dateTime);

      if (difference.inDays > 0) {
        return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
      } else if (difference.inHours > 0) {
        return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
      } else {
        return 'Just now';
      }
    } catch (e) {
      return 'Unknown time';
    }
  }

  Widget _buildNotificationCard({
    required IconData icon,
    required String title,
    required String message,
    required String time,
    required bool isRead,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: isRead ? 1 : 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: isRead
              ? null
              : Border.all(color: kNursePrimary.withOpacity(0.3), width: 1),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: kNursePrimary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: kNursePrimary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.poppins(
                        fontWeight: isRead ? FontWeight.w500 : FontWeight.w600,
                        fontSize: 14,
                        color: kNurseText,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      message,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: kNurseTextSecondary,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      time,
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        color: kNurseTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (!isRead)
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: kNursePrimary,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRequestCard({
    required IconData icon,
    required String title,
    required String message,
    required String time,
    required String status,
  }) {
    Color statusColor;
    switch (status.toLowerCase()) {
      case 'approved':
        statusColor = Colors.green;
        break;
      case 'rejected':
        statusColor = Colors.red;
        break;
      default:
        statusColor = Colors.orange;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: statusColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: kNurseText,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border:
                              Border.all(color: statusColor.withOpacity(0.3)),
                        ),
                        child: Text(
                          status,
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: statusColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    message,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: kNurseTextSecondary,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    time,
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      color: kNurseTextSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
