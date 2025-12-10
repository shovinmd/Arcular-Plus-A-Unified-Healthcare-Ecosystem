import 'package:flutter/material.dart';
import 'package:arcular_plus/services/api_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  List<Map<String, dynamic>> _cartItems = [];
  bool _isLoading = true;
  bool _isPlacingOrder = false;

  @override
  void initState() {
    super.initState();
    _loadCartItems();
  }

  Future<void> _loadCartItems() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final cartData = prefs.getString('cart_items');

      if (cartData != null) {
        final List<dynamic> cartList =
            await Future.value((await Future.value(cartData))
                .split('|||')
                .map((item) {
                  try {
                    return Map<String, dynamic>.from(
                        Map<String, dynamic>.fromEntries(
                            item.split('|').map((pair) {
                      final parts = pair.split(':');
                      return MapEntry(
                          parts[0], parts.length > 1 ? parts[1] : '');
                    })));
                  } catch (e) {
                    return null;
                  }
                })
                .where((item) => item != null)
                .toList());

        setState(() {
          _cartItems = cartList.cast<Map<String, dynamic>>();
        });
      }
    } catch (e) {
      print('❌ Error loading cart items: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _saveCartItems() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cartData = _cartItems
          .map((item) =>
              item.entries.map((e) => '${e.key}:${e.value}').join('|'))
          .join('|||');
      await prefs.setString('cart_items', cartData);
    } catch (e) {
      print('❌ Error saving cart items: $e');
    }
  }

  void _updateQuantity(int index, int newQuantity) {
    if (newQuantity <= 0) {
      _removeItem(index);
      return;
    }

    setState(() {
      _cartItems[index]['quantity'] = newQuantity.toString();
    });
    _saveCartItems();
  }

  void _removeItem(int index) {
    setState(() {
      _cartItems.removeAt(index);
    });
    _saveCartItems();
  }

  String _formatPrice(dynamic price) {
    if (price == null) return '0.00';

    double priceValue;
    if (price is num) {
      priceValue = price.toDouble();
    } else {
      priceValue = double.tryParse(price.toString()) ?? 0.0;
    }

    return priceValue.toStringAsFixed(2);
  }

  double _getItemPrice(Map<String, dynamic> item) {
    // Try to get price from sellingPrice first, then unitPrice, then price
    final sellingPrice = (item['sellingPrice'] is num)
        ? (item['sellingPrice'] as num).toDouble()
        : double.tryParse(item['sellingPrice']?.toString() ?? '0') ?? 0.0;
    final unitPrice = (item['unitPrice'] is num)
        ? (item['unitPrice'] as num).toDouble()
        : double.tryParse(item['unitPrice']?.toString() ?? '0') ?? 0.0;
    final price = (item['price'] is num)
        ? (item['price'] as num).toDouble()
        : double.tryParse(item['price']?.toString() ?? '0') ?? 0.0;

    // Use the first available price
    final finalPrice =
        sellingPrice > 0 ? sellingPrice : (unitPrice > 0 ? unitPrice : price);

    return finalPrice.isFinite ? finalPrice : 0.0;
  }

  double _calculateSubtotal() {
    return _cartItems.fold(0.0, (total, item) {
      // Try to get price from sellingPrice first, then unitPrice, then price
      final sellingPrice = (item['sellingPrice'] is num)
          ? (item['sellingPrice'] as num).toDouble()
          : double.tryParse(item['sellingPrice']?.toString() ?? '0') ?? 0.0;
      final unitPrice = (item['unitPrice'] is num)
          ? (item['unitPrice'] as num).toDouble()
          : double.tryParse(item['unitPrice']?.toString() ?? '0') ?? 0.0;
      final price = (item['price'] is num)
          ? (item['price'] as num).toDouble()
          : double.tryParse(item['price']?.toString() ?? '0') ?? 0.0;

      // Use the first available price
      final finalPrice =
          sellingPrice > 0 ? sellingPrice : (unitPrice > 0 ? unitPrice : price);

      final qty = (item['quantity'] is num)
          ? (item['quantity'] as num).toInt()
          : int.tryParse(item['quantity']?.toString() ?? '1') ?? 1;

      // Ensure we have valid numbers
      final validPrice = finalPrice.isFinite ? finalPrice : 0.0;
      final validQty = qty > 0 ? qty : 1;

      return total + (validPrice * validQty);
    });
  }

  double _calculateDeliveryFee() {
    // Fixed delivery fee of ₹30
    return 30.0;
  }

  double _calculateTotal() {
    return _calculateSubtotal() + _calculateDeliveryFee();
  }

  Future<void> _placeOrder() async {
    if (_cartItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Your cart is empty')),
      );
      return;
    }

    setState(() {
      _isPlacingOrder = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not logged in');
      }

      // Get user details
      final userModel = await ApiService.getUserInfo(user.uid);
      if (userModel == null) {
        throw Exception('User details not found');
      }

      // Prepare order items
      final orderItems = _cartItems.map((item) {
        final sellingPrice = (item['sellingPrice'] is num)
            ? (item['sellingPrice'] as num).toDouble()
            : double.tryParse(item['sellingPrice']?.toString() ?? '0') ?? 0.0;
        final unitPrice = (item['unitPrice'] is num)
            ? (item['unitPrice'] as num).toDouble()
            : double.tryParse(item['unitPrice']?.toString() ?? '0') ?? 0.0;
        final qty = (item['quantity'] is num)
            ? (item['quantity'] as num).toInt()
            : int.tryParse(item['quantity']?.toString() ?? '1') ?? 1;

        return {
          'id': item['id'],
          'name': item['name'],
          'category': item['category'] ?? 'General',
          'type': item['type'] ?? 'tablet',
          'quantity': qty,
          'unitPrice': unitPrice,
          'sellingPrice': sellingPrice,
          'pharmacyId': item['pharmacyId'] ?? '',
        };
      }).toList();

      // Prepare user address
      final userAddress = {
        'street': userModel.address,
        'city': userModel.city,
        'state': userModel.state,
        'pincode': userModel.pincode,
      };

      // Place order via API
      final response = await ApiService.placeOrder(
        userId: user.uid,
        items: orderItems,
        userAddress: userAddress,
        deliveryMethod: 'Home Delivery',
        paymentMethod: 'Cash on Delivery',
        userNotes: 'Payment on delivery - Cash/UPI/Card accepted',
      );

      if (response['success'] == true || response['data'] != null) {
        // Clear cart
        await _clearCart();

        // Get order ID from response
        final orderId = response['orderId'] ??
            response['data']?['_id'] ??
            response['data']?['id'] ??
            'N/A';

        // Show success popup
        _showSuccessDialog(orderId);
      } else {
        throw Exception(response['message'] ?? 'Failed to place order');
      }
    } catch (e) {
      print('❌ Error placing order: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to place order: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isPlacingOrder = false;
      });
    }
  }

  Future<void> _clearCart() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('cart_items');
      setState(() {
        _cartItems.clear();
      });
    } catch (e) {
      print('❌ Error clearing cart: $e');
    }
  }

  void _showSuccessDialog(String orderId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Success Icon
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle,
                  color: Colors.green,
                  size: 50,
                ),
              ),
              const SizedBox(height: 20),

              // Success Title
              Text(
                'Order Placed Successfully!',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 15),

              // Order ID
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Text(
                      'Order ID',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      orderId,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFFFA500),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 15),

              // Message
              Text(
                'You will receive email confirmation shortly. You can track your order in the "My Orders" section.',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),

              // OK Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop(); // Close dialog
                    Navigator.of(context).pop(); // Close cart screen
                    // Navigate to My Orders screen
                    Navigator.pushNamed(context, '/my_orders');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFA500),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'View My Orders',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Shopping Cart'),
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
          if (_cartItems.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear_all),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Clear Cart'),
                    content: const Text(
                        'Are you sure you want to remove all items from your cart?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _clearCart();
                        },
                        child: const Text('Clear',
                            style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _cartItems.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.shopping_cart_outlined,
                          size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('Your cart is empty',
                          style: TextStyle(fontSize: 18, color: Colors.grey)),
                      SizedBox(height: 8),
                      Text('Add some medicines to get started',
                          style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                )
              : Column(
                  children: [
                    // Cart Items
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _cartItems.length,
                        itemBuilder: (context, index) {
                          final item = _cartItems[index];
                          return _buildCartItem(item, index);
                        },
                      ),
                    ),

                    // Order Summary
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, -2),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Subtotal:'),
                                  Text(
                                      '₹${_calculateSubtotal().toStringAsFixed(2)}'),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Delivery Fee:'),
                                  Text(
                                      '₹${_calculateDeliveryFee().toStringAsFixed(2)}'),
                                ],
                              ),
                              const Divider(),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Total Amount:',
                                    style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    '₹${_calculateTotal().toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFFFFA500),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: Colors.blue.withOpacity(0.3)),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.info_outline,
                                    color: Colors.blue, size: 20),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Payment on delivery - Cash, UPI, or Card accepted',
                                    style: TextStyle(
                                        color: Colors.blue, fontSize: 12),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              onPressed: _isPlacingOrder ? null : _placeOrder,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFFFA500),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: _isPlacingOrder
                                  ? const Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2,
                                          ),
                                        ),
                                        SizedBox(width: 12),
                                        Text('Placing Order...'),
                                      ],
                                    )
                                  : const Text(
                                      'Place Order',
                                      style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildCartItem(Map<String, dynamic> item, int index) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Medicine Icon
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.medication,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),

            // Medicine Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item['name'] ?? 'Unknown Medicine',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${item['pharmacyName'] ?? 'Pharmacy'} • ₹${_formatPrice(_getItemPrice(item))}',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                  if (item['requiresPrescription'] == true)
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Rx Required',
                        style: TextStyle(
                            color: Colors.red,
                            fontSize: 10,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                ],
              ),
            ),

            // Quantity Controls
            Row(
              children: [
                IconButton(
                  onPressed: () {
                    final currentQty =
                        int.tryParse(item['quantity']?.toString() ?? '1') ?? 1;
                    _updateQuantity(index, currentQty - 1);
                  },
                  icon: const Icon(Icons.remove_circle_outline),
                  color: const Color(0xFFFFA500),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${item['quantity'] ?? 1}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  onPressed: () {
                    final currentQty =
                        int.tryParse(item['quantity']?.toString() ?? '1') ?? 1;
                    _updateQuantity(index, currentQty + 1);
                  },
                  icon: const Icon(Icons.add_circle_outline),
                  color: const Color(0xFFFFA500),
                ),
              ],
            ),

            // Remove Button
            IconButton(
              onPressed: () => _removeItem(index),
              icon: const Icon(Icons.delete_outline),
              color: Colors.red,
            ),
          ],
        ),
      ),
    );
  }
}
