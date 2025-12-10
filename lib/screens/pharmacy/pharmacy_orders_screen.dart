import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:arcular_plus/services/api_service.dart';
import 'package:google_fonts/google_fonts.dart';

class PharmacyOrdersScreen extends StatefulWidget {
  const PharmacyOrdersScreen({super.key});

  @override
  State<PharmacyOrdersScreen> createState() => _PharmacyOrdersScreenState();
}

class _PharmacyOrdersScreenState extends State<PharmacyOrdersScreen>
    with TickerProviderStateMixin {
  List<Map<String, dynamic>> _orders = [];
  Map<String, dynamic> _stats = {};
  bool _isLoading = true;
  String _selectedFilter = 'All';
  late TabController _tabController;
  String? _pharmacyId;

  final List<String> _statusFilters = [
    'All',
    'Pending',
    'Confirmed',
    'Shipped',
    'Delivered',
    'Cancelled'
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _statusFilters.length, vsync: this);
    _loadPharmacyId();
  }

  Future<void> _showShippingDialog(String orderId) async {
    final courierController = TextEditingController();
    final trackingIdController = TextEditingController();
    final trackingUrlController = TextEditingController();
    DateTime? estimatedDate;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Enter Shipping Details',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: courierController,
              decoration: const InputDecoration(
                  labelText: 'Courier Service (optional)'),
            ),
            TextField(
              controller: trackingIdController,
              decoration: const InputDecoration(labelText: 'Tracking ID'),
            ),
            TextField(
              controller: trackingUrlController,
              decoration: const InputDecoration(labelText: 'Tracking URL'),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    estimatedDate == null
                        ? 'Estimated Delivery: Not set'
                        : 'Estimated: ${estimatedDate!.toLocal().toString().split(' ')[0]}',
                    style: GoogleFonts.poppins(
                        fontSize: 12, color: Colors.grey[700]),
                  ),
                ),
                TextButton(
                  onPressed: () async {
                    final now = DateTime.now();
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: now,
                      firstDate: now,
                      lastDate: now.add(const Duration(days: 60)),
                    );
                    if (picked != null) {
                      setState(() {
                        estimatedDate = picked;
                      });
                    }
                  },
                  child: const Text('Pick Date'),
                )
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await ApiService.updateOrderStatus(
                orderId: orderId,
                status: 'Shipped',
                updatedBy: 'pharmacy',
                note: 'Order shipped',
                trackingInfo: {
                  'courierService': courierController.text.trim(),
                  'trackingId': trackingIdController.text.trim(),
                  'trackingUrl': trackingUrlController.text.trim(),
                  'estimatedDelivery':
                      (estimatedDate ?? DateTime.now()).toIso8601String(),
                },
              );
              await _loadOrders();
              await _forceRefreshStats();
            },
            child: const Text('Save & Ship'),
          )
        ],
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadPharmacyId() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Get pharmacy ID from user UID
      _pharmacyId = user.uid;
      await _loadOrders();
      await _loadStats();
    } catch (e) {
      print('❌ Error loading pharmacy ID: $e');
    }
  }

  Future<void> _loadOrders() async {
    if (_pharmacyId == null) return;

    try {
      setState(() {
        _isLoading = true;
      });

      _orders = await ApiService.getOrdersByPharmacy(_pharmacyId!);
      print('📦 Loaded ${_orders.length} orders for pharmacy');
    } catch (e) {
      print('❌ Error loading orders: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load orders: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadStats() async {
    if (_pharmacyId == null) return;

    try {
      print('📊 Loading order stats for pharmacy: $_pharmacyId');
      // Use backend API for stats (same as analytics screen)
      final stats = await ApiService.getOrderStats(_pharmacyId!);
      print('📊 Received stats from API: $stats');

      if (mounted) {
        setState(() {
          _stats = stats;
        });
        print('📊 Updated stats in state: $_stats');
      }
    } catch (e) {
      print('❌ Error loading stats from API: $e');
      // Set default values on error
      if (mounted) {
        setState(() {
          _stats = {
            'totalOrders': 0,
            'pendingOrders': 0,
            'totalRevenue': 0.0,
          };
        });
      }
    }
  }

  Future<void> _forceRefreshStats() async {
    if (_pharmacyId == null) return;

    try {
      print('🔄 Force refreshing stats for pharmacy: $_pharmacyId');
      // Add a small delay to ensure backend has processed the order update
      await Future.delayed(const Duration(milliseconds: 500));

      final stats = await ApiService.getOrderStats(_pharmacyId!);
      print('🔄 Force refresh - Received stats from API: $stats');

      if (mounted) {
        setState(() {
          _stats = stats;
        });
        print('🔄 Force refresh - Updated stats in state: $_stats');
      }
    } catch (e) {
      print('❌ Error force refreshing stats: $e');
    }
  }

  Future<Map<String, dynamic>?> _getOrderRating(String orderId) async {
    try {
      print('🔍 Fetching rating for order: $orderId');
      final ratingsData =
          await ApiService.getPharmacyRatings(pharmacyId: _pharmacyId!)
              .timeout(const Duration(seconds: 5));

      // Handle different response structures
      List<dynamic> ratings = [];
      if (ratingsData is List) {
        ratings = ratingsData as List<dynamic>;
      } else {
        // ratingsData is Map<String, dynamic>
        if (ratingsData.containsKey('ratings')) {
          ratings = ratingsData['ratings'] as List<dynamic>? ?? [];
        } else if (ratingsData.containsKey('data')) {
          ratings = ratingsData['data'] as List<dynamic>? ?? [];
        } else {
          // If it's a Map but no 'ratings' or 'data' key, treat the whole map as a single rating
          ratings = [ratingsData];
        }
      }

      print(
          '🔍 Looking for rating for order: $orderId in ${ratings.length} ratings');

      for (final rating in ratings) {
        if (rating['orderId'] == orderId) {
          print('✅ Found rating for order $orderId: ${rating['rating']} stars');
          return rating as Map<String, dynamic>;
        }
      }

      print('ℹ️ No rating found for order $orderId');
      return null;
    } catch (e) {
      print('❌ Error fetching order rating: $e');
      return null;
    }
  }

  List<Map<String, dynamic>> _getFilteredOrders() {
    if (_selectedFilter == 'All') {
      return _orders;
    }
    return _orders
        .where((order) => order['status'] == _selectedFilter)
        .toList();
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Pending':
        return Colors.orange;
      case 'Confirmed':
        return Colors.blue;
      case 'Shipped':
        return Colors.purple;
      case 'Delivered':
        return Colors.green;
      case 'Cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'Pending':
        return Icons.schedule;
      case 'Confirmed':
        return Icons.check_circle_outline;
      case 'Shipped':
        return Icons.local_shipping;
      case 'Delivered':
        return Icons.done_all;
      case 'Cancelled':
        return Icons.cancel;
      default:
        return Icons.help_outline;
    }
  }

  Future<void> _updateOrderStatus(String orderId, String newStatus) async {
    try {
      await ApiService.updateOrderStatus(
        orderId: orderId,
        status: newStatus,
        updatedBy: 'pharmacy',
        note: 'Status updated by pharmacy',
      );

      // Reload orders and force refresh stats
      await _loadOrders();
      await _forceRefreshStats();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Order status updated to $newStatus'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('❌ Error updating order status: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update order status: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Orders'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF4CAF50), Color(0xFF2E7D32)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              await _loadOrders();
              await _forceRefreshStats();
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: _statusFilters.map((filter) => Tab(text: filter)).toList(),
          onTap: (index) {
            setState(() {
              _selectedFilter = _statusFilters[index];
            });
          },
        ),
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading orders...'),
                ],
              ),
            )
          : Column(
              children: [
                // Stats Cards
                if (_stats.isNotEmpty) _buildStatsCards(),

                // Orders List
                Expanded(
                  child: _getFilteredOrders().isEmpty
                      ? _buildEmptyState()
                      : RefreshIndicator(
                          onRefresh: () async {
                            await _loadOrders();
                            await _forceRefreshStats();
                          },
                          child: ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _getFilteredOrders().length,
                            itemBuilder: (context, index) {
                              final order = _getFilteredOrders()[index];
                              return _buildOrderCard(order);
                            },
                          ),
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildStatsCards() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: _buildStatCard(
              'Total Orders',
              '${_stats['totalOrders'] ?? 0}',
              Icons.shopping_bag,
              Colors.blue,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              'Pending',
              '${_stats['pendingOrders'] ?? 0}',
              Icons.schedule,
              Colors.orange,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
      String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.shopping_bag_outlined,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No orders found',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _selectedFilter == 'All'
                ? 'No orders have been placed yet'
                : 'No $_selectedFilter orders found',
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

  Widget _buildOrderCard(Map<String, dynamic> order) {
    final status = order['status'] ?? 'Pending';
    final statusColor = _getStatusColor(status);
    final statusIcon = _getStatusIcon(status);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _showOrderDetails(order),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Order Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Order #${order['orderId'] ?? 'N/A'}',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Placed on ${_formatDate(order['orderDate'])}',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                  Flexible(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                            border:
                                Border.all(color: statusColor.withOpacity(0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(statusIcon, size: 16, color: statusColor),
                              const SizedBox(width: 4),
                              Text(
                                status,
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: statusColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Customer Info
              Row(
                children: [
                  Icon(Icons.person, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      order['userName'] ?? 'Unknown Customer',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.grey[700],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Order Items Preview
              Text(
                '${order['items']?.length ?? 0} item(s)',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 8),

              // Order Items List (first 2 items)
              if (order['items'] != null && order['items'].isNotEmpty)
                ...order['items']
                    .take(2)
                    .map<Widget>((item) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            children: [
                              Container(
                                width: 4,
                                height: 4,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF4CAF50),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '${item['medicineName']} (${item['quantity']}x)',
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ))
                    .toList(),

              if (order['items'] != null && order['items'].length > 2)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '+${order['items'].length - 2} more items',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.grey[500],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),

              const SizedBox(height: 16),

              // Order Total
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total Amount',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '₹${(order['totalAmount'] ?? 0).toStringAsFixed(2)}',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF4CAF50),
                    ),
                  ),
                ],
              ),

              // Rating Section (only for delivered orders)
              if (status == 'Delivered') ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.star, size: 16, color: Colors.amber),
                    const SizedBox(width: 8),
                    Text(
                      'Customer Rating:',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(width: 8),
                    FutureBuilder<Map<String, dynamic>?>(
                      future: _getOrderRating(order['orderId']),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return Text(
                            'Loading...',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.grey[500],
                            ),
                          );
                        } else if (snapshot.hasData && snapshot.data != null) {
                          final rating = snapshot.data!['rating'] ?? 0;
                          final review = snapshot.data!['review'] ?? '';
                          return Expanded(
                            child: Row(
                              children: [
                                ...List.generate(5, (index) {
                                  return Icon(
                                    index < rating
                                        ? Icons.star
                                        : Icons.star_border,
                                    color: Colors.amber,
                                    size: 16,
                                  );
                                }),
                                if (review.isNotEmpty) ...[
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      '"$review"',
                                      style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                        fontStyle: FontStyle.italic,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          );
                        } else if (snapshot.hasError) {
                          return Text(
                            'No rating yet',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.grey[500],
                            ),
                          );
                        } else {
                          return Text(
                            'No rating yet',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.grey[500],
                            ),
                          );
                        }
                      },
                    ),
                  ],
                ),
              ],

              // Action Buttons
              if (status == 'Pending' ||
                  status == 'Confirmed' ||
                  status == 'Shipped')
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Row(
                    children: [
                      if (status == 'Pending')
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => _updateOrderStatus(
                                order['orderId'], 'Confirmed'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                            ),
                            child: const Text('Confirm'),
                          ),
                        ),
                      if (status == 'Confirmed')
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () =>
                                _showShippingDialog(order['orderId']),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.purple,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                            ),
                            child: const Text('Ship'),
                          ),
                        ),
                      if (status == 'Shipped')
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => _updateOrderStatus(
                                order['orderId'], 'Delivered'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                            ),
                            child: const Text('Deliver'),
                          ),
                        ),
                      const SizedBox(width: 8),
                      if (status == 'Pending')
                        ElevatedButton(
                          onPressed: () =>
                              _updateOrderStatus(order['orderId'], 'Cancelled'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                vertical: 8, horizontal: 16),
                          ),
                          child: const Text('Cancel'),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showOrderDetails(Map<String, dynamic> order) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Order Details',
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Order Info
                    _buildDetailSection('Order Information', [
                      'Order ID: ${order['orderId']}',
                      'Order Date: ${_formatDate(order['orderDate'])}',
                      'Status: ${order['status']}',
                      'Payment Method: ${order['paymentMethod']}',
                      'Delivery Method: ${order['deliveryMethod']}',
                    ]),

                    const SizedBox(height: 20),

                    // Customer Info
                    _buildDetailSection('Customer Information', [
                      'Name: ${order['userName']}',
                      'Email: ${order['userEmail']}',
                      'Phone: ${order['userPhone']}',
                      'Address: ${_formatAddress(order['userAddress'])}',
                    ]),

                    const SizedBox(height: 20),

                    // Order Items
                    Text(
                      'Order Items',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),

                    if (order['items'] != null)
                      ...order['items']
                          .map<Widget>((item) => Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.grey[50],
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.grey[200]!),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item['medicineName'] ??
                                                'Unknown Medicine',
                                            style: GoogleFonts.poppins(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '${item['category']} • ${item['type']}',
                                            style: GoogleFonts.poppins(
                                              fontSize: 12,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          'Qty: ${item['quantity']}',
                                          style: GoogleFonts.poppins(
                                            fontSize: 12,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '₹${(item['totalPrice'] ?? 0).toStringAsFixed(2)}',
                                          style: GoogleFonts.poppins(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: const Color(0xFF4CAF50),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ))
                          .toList(),

                    const SizedBox(height: 20),

                    // Order Summary
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4CAF50).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Subtotal:',
                                  style: GoogleFonts.poppins(fontSize: 14)),
                              Text(
                                  '₹${(order['subtotal'] ?? 0).toStringAsFixed(2)}',
                                  style: GoogleFonts.poppins(fontSize: 14)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Delivery Fee:',
                                  style: GoogleFonts.poppins(fontSize: 14)),
                              Text(
                                  '₹${(order['deliveryFee'] ?? 0).toStringAsFixed(2)}',
                                  style: GoogleFonts.poppins(fontSize: 14)),
                            ],
                          ),
                          const Divider(),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Total:',
                                  style: GoogleFonts.poppins(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold)),
                              Text(
                                  '₹${(order['totalAmount'] ?? 0).toStringAsFixed(2)}',
                                  style: GoogleFonts.poppins(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF4CAF50))),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailSection(String title, List<String> details) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        ...details
            .map((detail) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    detail,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.grey[700],
                    ),
                  ),
                ))
            .toList(),
      ],
    );
  }

  String _formatDate(dynamic date) {
    if (date == null) return 'Unknown';
    try {
      final dateTime = DateTime.parse(date.toString());
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    } catch (e) {
      return 'Unknown';
    }
  }

  String _formatAddress(Map<String, dynamic>? address) {
    if (address == null) return 'Not provided';
    return '${address['street']}, ${address['city']}, ${address['state']} - ${address['pincode']}';
  }
}
