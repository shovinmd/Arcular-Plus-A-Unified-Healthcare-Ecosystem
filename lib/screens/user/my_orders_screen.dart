import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:arcular_plus/services/api_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:arcular_plus/screens/user/cart_screen.dart';
import 'package:arcular_plus/screens/user/rating_screen.dart';

class MyOrdersScreen extends StatefulWidget {
  const MyOrdersScreen({super.key});

  @override
  State<MyOrdersScreen> createState() => _MyOrdersScreenState();
}

class _MyOrdersScreenState extends State<MyOrdersScreen>
    with TickerProviderStateMixin {
  List<Map<String, dynamic>> _orders = [];
  bool _isLoading = true;
  String _selectedFilter = 'All';
  late TabController _tabController;

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
    _loadOrders();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadOrders() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      _orders = await ApiService.getOrdersByUser(user.uid);
      print('📦 Loaded ${_orders.length} orders for user');
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Orders'),
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
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadOrders,
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
          : _getFilteredOrders().isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _loadOrders,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _getFilteredOrders().length,
                    itemBuilder: (context, index) {
                      final order = _getFilteredOrders()[index];
                      return _buildOrderCard(order);
                    },
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
                ? 'You haven\'t placed any orders yet'
                : 'No $_selectedFilter orders found',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFA500),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
              ),
            ),
            child: const Text('Browse Medicines'),
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
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Order #${order['orderId'] ?? 'N/A'}',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
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
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: statusColor.withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(statusIcon, size: 14, color: statusColor),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              status,
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: statusColor,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Pharmacy Info
              Row(
                children: [
                  Icon(Icons.local_pharmacy, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      order['pharmacyName'] ?? 'Unknown Pharmacy',
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
                                  color: Color(0xFFFFA500),
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
                      color: const Color(0xFFFFA500),
                    ),
                  ),
                ],
              ),

              // Delivery Info
              if (order['deliveryMethod'] != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      Icon(Icons.delivery_dining,
                          size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 8),
                      Text(
                        order['deliveryMethod'],
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 16),

              // Action Buttons
              _buildActionButtons(order),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _cancelOrder(Map<String, dynamic> order) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Order'),
        content:
            Text('Are you sure you want to cancel order #${order['orderId']}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      // Call API to cancel order
      final result = await ApiService.updateOrderStatus(
        orderId: order['orderId'] ?? order['_id'] ?? order['id'],
        status: 'Cancelled',
        updatedBy: FirebaseAuth.instance.currentUser?.uid ?? '',
        note: 'Order cancelled by user',
      );

      // Hide loading
      Navigator.of(context).pop();

      if (result['success'] == true) {
        // Refresh orders
        await _loadOrders();

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Order cancelled successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        throw Exception(result['message'] ?? 'Failed to cancel order');
      }
    } catch (e) {
      // Hide loading if still showing
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to cancel order: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _orderAgain(Map<String, dynamic> order) async {
    try {
      // Get order items with proper type casting
      final dynamic itemsData = order['items'];
      List<Map<String, dynamic>> items = [];

      if (itemsData is List) {
        items = itemsData.map((item) {
          if (item is Map<String, dynamic>) {
            return item;
          } else if (item is Map) {
            return Map<String, dynamic>.from(item);
          } else {
            return <String, dynamic>{};
          }
        }).toList();
      }

      if (items.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No items found in this order'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Show confirmation dialog
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Order Again'),
          content:
              Text('Add ${items.length} item(s) from this order to your cart?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Add to Cart'),
            ),
          ],
        ),
      );

      if (confirmed != true) return;

      // Add items to cart
      final prefs = await SharedPreferences.getInstance();
      final cartItems = <String>[];

      for (final item in items) {
        try {
          // Ensure item is a Map<String, dynamic>
          final Map<String, dynamic> itemMap = Map<String, dynamic>.from(item);
          final medicineName =
              itemMap['medicineName'] ?? itemMap['name'] ?? 'Unknown Medicine';
          print('🔄 Processing item for reorder: $medicineName');

          // Skip items with empty or invalid data
          if (medicineName == 'Unknown Medicine' || medicineName.isEmpty) {
            print('⚠️ Skipping item with invalid name: $medicineName');
            continue;
          }

          final unitPrice = itemMap['unitPrice']?.toString() ??
              itemMap['sellingPrice']?.toString() ??
              '0';
          final quantity = itemMap['quantity']?.toString() ?? '1';

          // Skip items with zero or invalid prices
          if (unitPrice == '0' || unitPrice.isEmpty) {
            print('⚠️ Skipping item with invalid price: $medicineName');
            continue;
          }

          final cartItem = {
            'id': itemMap['id'] ?? itemMap['_id'] ?? '',
            'name': medicineName, // Use 'name' for cart compatibility
            'medicineName': medicineName, // Keep both for compatibility
            'unitPrice': unitPrice,
            'sellingPrice': unitPrice,
            'price': unitPrice,
            'quantity': quantity,
            'pharmacyName': order['pharmacyName'] ?? 'Pharmacy',
            'pharmacyId': order['pharmacyId'] ?? '',
            'category': itemMap['category'] ?? 'General',
            'type': itemMap['type'] ?? 'tablet',
            'stock': '100', // Assume available
          };

          cartItems.add(
              cartItem.entries.map((e) => '${e.key}:${e.value}').join('|'));
          print('✅ Item added to cart: $medicineName');
        } catch (itemError) {
          print('⚠️ Error processing item: $itemError');
          // Continue with other items
        }
      }

      if (cartItems.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No valid items found to add to cart'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      await prefs.setString('cart_items', cartItems.join('|||'));

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${cartItems.length} item(s) added to cart'),
          backgroundColor: Colors.green,
        ),
      );

      // Navigate to cart
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const CartScreen()),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to add items to cart: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
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

                    // Pharmacy Info
                    _buildDetailSection('Pharmacy Information', [
                      'Name: ${order['pharmacyName']}',
                      'Phone: ${order['pharmacyPhone']}',
                      'Address: ${_formatAddress(order['pharmacyAddress'])}',
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
                                            color: const Color(0xFFFFA500),
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
                        color: const Color(0xFFFFA500).withOpacity(0.1),
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
                                      color: const Color(0xFFFFA500))),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Action Buttons
                    _buildActionButtons(order),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(Map<String, dynamic> order) {
    final status = order['status']?.toString().toLowerCase() ?? '';
    final orderId = order['orderId'] ?? order['_id'];
    final items = order['items'] as List<dynamic>? ?? [];
    final pharmacyName = order['pharmacyName'] ?? 'Pharmacy';

    return Column(
      children: [
        // Cancel Order Button (for non-delivered orders)
        if (status != 'delivered' && status != 'cancelled') ...[
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => _cancelOrder(order),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                'Cancel Order',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],

        // Order Again Button (for delivered orders)
        if (status == 'delivered') ...[
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => _orderAgain(order),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFA500),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                'Order Again',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],

        // Rate Order Button (for delivered orders)
        if (status == 'delivered') ...[
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _rateOrder(orderId, items, pharmacyName),
              icon: const Icon(Icons.star, color: Colors.white),
              label: Text(
                'Rate Order',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  void _rateOrder(String orderId, List<dynamic> items, String pharmacyName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RatingScreen(
          orderId: orderId,
          orderItems: items.cast<Map<String, dynamic>>(),
          pharmacyName: pharmacyName,
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
