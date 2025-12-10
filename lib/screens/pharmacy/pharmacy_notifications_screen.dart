import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/api_service.dart';

class PharmacyNotificationsScreen extends StatefulWidget {
  const PharmacyNotificationsScreen({Key? key}) : super(key: key);

  @override
  State<PharmacyNotificationsScreen> createState() =>
      _PharmacyNotificationsScreenState();
}

class _PharmacyNotificationsScreenState
    extends State<PharmacyNotificationsScreen> {
  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = true;
  String _selectedFilter = 'All';

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    try {
      setState(() => _isLoading = true);

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Load recent orders as notifications
      final orders = await ApiService.getOrdersByPharmacy(user.uid);

      // Load pharmacy medicines for low stock alerts
      final medicinesResponse = await ApiService.getPharmacyMedicines(user.uid);
      final medicines = medicinesResponse['data'] != null
          ? (medicinesResponse['data'] as List)
              .map((json) => json as Map<String, dynamic>)
              .toList()
          : <Map<String, dynamic>>[];

      List<Map<String, dynamic>> notifications = [];

      // Add order notifications
      for (var order in orders.take(10)) {
        final status = order['status'] ?? 'Unknown';
        final orderId = order['orderId'] ?? 'Unknown';
        final patientName =
            order['patientName'] ?? order['userName'] ?? 'Unknown Patient';
        final createdAt =
            order['createdAt'] ?? DateTime.now().toIso8601String();

        String title = '';
        String description = '';
        IconData icon = Icons.shopping_cart;
        Color color = Colors.blue;

        switch (status) {
          case 'Pending':
            title = 'New Order Received';
            description = 'Order $orderId from $patientName needs confirmation';
            icon = Icons.pending_actions;
            color = Colors.orange;
            break;
          case 'Confirmed':
            title = 'Order Confirmed';
            description =
                'Order $orderId from $patientName is confirmed and ready for processing';
            icon = Icons.check_circle;
            color = Colors.green;
            break;
          case 'in_transit':
            title = 'Order Shipped';
            description = 'Order $orderId from $patientName has been shipped';
            icon = Icons.local_shipping;
            color = Colors.blue;
            break;
          case 'Delivered':
            title = 'Order Delivered';
            description = 'Order $orderId from $patientName has been delivered';
            icon = Icons.done_all;
            color = Colors.green;
            break;
          case 'Cancelled':
            title = 'Order Cancelled';
            description = 'Order $orderId from $patientName has been cancelled';
            icon = Icons.cancel;
            color = Colors.red;
            break;
          default:
            title = 'Order Update';
            description =
                'Order $orderId from $patientName status updated to $status';
            icon = Icons.info;
            color = Colors.grey;
        }

        notifications.add({
          'id': order['_id'] ?? orderId,
          'title': title,
          'description': description,
          'time': _formatTimeAgo(createdAt),
          'icon': icon,
          'color': color,
          'type': 'order',
          'orderId': orderId,
          'patientName': patientName,
          'status': status,
          'isRead': false,
        });
      }

      // Add low stock alerts
      for (var medicine in medicines) {
        final stock = medicine['stock'] ?? 0;
        final name = medicine['name'] ?? 'Unknown Medicine';

        if (stock <= 10) {
          // Low stock threshold
          notifications.add({
            'id': 'stock_${medicine['_id']}',
            'title': 'Low Stock Alert',
            'description': '$name is running low (${stock} units remaining)',
            'time': 'Just now',
            'icon': Icons.warning,
            'color': Colors.red,
            'type': 'inventory',
            'medicineName': name,
            'stock': stock,
            'isRead': false,
          });
        }
      }

      // Add system notifications
      notifications.addAll([
        {
          'id': 'system_1',
          'title': 'Welcome to Arcular Plus',
          'description':
              'Your pharmacy dashboard is now active and ready to use',
          'time': '1 day ago',
          'icon': Icons.info,
          'color': Colors.blue,
          'type': 'system',
          'isRead': true,
        },
        {
          'id': 'system_2',
          'title': 'Inventory Management',
          'description': 'Remember to update your medicine inventory regularly',
          'time': '2 days ago',
          'icon': Icons.inventory,
          'color': Colors.orange,
          'type': 'system',
          'isRead': true,
        },
      ]);

      // Sort by time (most recent first)
      notifications.sort((a, b) {
        if (a['time'] == 'Just now') return -1;
        if (b['time'] == 'Just now') return 1;
        return 0; // For now, keep simple ordering
      });

      setState(() {
        _notifications = notifications;
        _isLoading = false;
      });
    } catch (e) {
      print('❌ Error loading notifications: $e');
      setState(() => _isLoading = false);
    }
  }

  String _formatTimeAgo(String isoString) {
    try {
      final date = DateTime.parse(isoString);
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
    } catch (e) {
      return 'Recently';
    }
  }

  List<Map<String, dynamic>> _getFilteredNotifications() {
    if (_selectedFilter == 'All') {
      return _notifications;
    }
    return _notifications
        .where((notification) =>
            notification['type'] == _selectedFilter.toLowerCase())
        .toList();
  }

  void _markAsRead(String notificationId) {
    setState(() {
      final index = _notifications.indexWhere((n) => n['id'] == notificationId);
      if (index != -1) {
        _notifications[index]['isRead'] = true;
      }
    });
  }

  void _markAllAsRead() {
    setState(() {
      for (var notification in _notifications) {
        notification['isRead'] = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Notifications',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        foregroundColor: Colors.white,
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'mark_all_read') {
                _markAllAsRead();
              }
            },
            icon: const Icon(Icons.more_vert, color: Colors.white),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'mark_all_read',
                child: Row(
                  children: [
                    Icon(Icons.done_all, color: Colors.grey),
                    SizedBox(width: 8),
                    Text('Mark all as read'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter chips
          Container(
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('All'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Order'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Inventory'),
                  const SizedBox(width: 8),
                  _buildFilterChip('System'),
                ],
              ),
            ),
          ),

          // Notifications list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _getFilteredNotifications().isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        onRefresh: _loadNotifications,
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _getFilteredNotifications().length,
                          itemBuilder: (context, index) {
                            final notification =
                                _getFilteredNotifications()[index];
                            return _buildNotificationCard(notification);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label) {
    final isSelected = _selectedFilter == label;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedFilter = label;
        });
      },
      selectedColor: const Color(0xFFFFA500),
      checkmarkColor: Colors.white,
      labelStyle: GoogleFonts.poppins(
        color: isSelected ? Colors.white : Colors.grey.shade700,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  Widget _buildNotificationCard(Map<String, dynamic> notification) {
    final isRead = notification['isRead'] ?? false;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: isRead ? 1 : 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _markAsRead(notification['id']),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: isRead ? Colors.grey.shade50 : Colors.white,
            border: isRead
                ? null
                : Border.all(
                    color: const Color(0xFFFFA500).withOpacity(0.3),
                    width: 1,
                  ),
          ),
          child: Row(
            children: [
              // Icon
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: notification['color'].withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  notification['icon'],
                  color: notification['color'],
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            notification['title'],
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight:
                                  isRead ? FontWeight.w500 : FontWeight.bold,
                              color: Colors.grey.shade800,
                            ),
                          ),
                        ),
                        if (!isRead)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Color(0xFFFFA500),
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notification['description'],
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notification['time'],
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),

              // Arrow
              Icon(
                Icons.chevron_right,
                color: Colors.grey.shade400,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_none,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'No notifications',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'You\'ll see notifications for new orders,\nlow stock alerts, and system updates here',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }
}
