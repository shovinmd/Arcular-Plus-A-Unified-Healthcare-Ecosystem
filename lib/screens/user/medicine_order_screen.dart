import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:arcular_plus/services/api_service.dart';
import 'package:arcular_plus/services/fcm_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:arcular_plus/screens/user/cart_screen.dart';
import 'package:arcular_plus/screens/user/my_orders_screen.dart';
import 'package:arcular_plus/screens/pharmacy/qr_medicine_scanner_screen.dart';

class MedicineOrderScreen extends StatefulWidget {
  final String? searchQuery;

  const MedicineOrderScreen({super.key, this.searchQuery});

  @override
  State<MedicineOrderScreen> createState() => _MedicineOrderScreenState();
}

class _MedicineOrderScreenState extends State<MedicineOrderScreen> {
  int _selectedIndex = 0;
  String _searchQuery = '';
  List<Map<String, dynamic>> _medicines = [];
  List<Map<String, dynamic>> _prescriptions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // Initialize search query from widget parameter
    if (widget.searchQuery != null && widget.searchQuery!.isNotEmpty) {
      _searchQuery = widget.searchQuery!;
    }
    _loadData();
    // Refresh orders when FCM emits order updates
    FCMService().events.listen((event) {
      final type = (event['type'] ?? '').toString().toLowerCase();
      if (type.contains('order')) {}
    });
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // If there's a search query, perform search instead of loading all medicines
        if (_searchQuery.isNotEmpty) {
          await _performSearch();
        } else {
          // Load medicines from pharmacy
          await _loadMedicines();
        }
        // Load prescriptions
        await _loadPrescriptions(user.uid);
      }
    } catch (e) {
      print('❌ Error loading data: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMedicines() async {
    try {
      // Load medicines from pharmacy inventory
      _medicines = await ApiService.searchMedicines('');
      print('🔍 Loaded ${_medicines.length} medicines for user order screen');
      if (_medicines.isNotEmpty) {
        print('📋 First medicine: ${_medicines.first}');
      }
    } catch (e) {
      print('❌ Error loading medicines: $e');
      _medicines = [];
    }
  }

  Future<void> _loadPrescriptions(String userId) async {
    try {
      print('🩺 Loading prescriptions for user: $userId');

      // Resolve user's ARC ID then fetch prescriptions by ARC ID (doctor-created)
      String? arcId;
      try {
        final me = await ApiService.getUserInfo(userId);
        arcId = me?.healthQrId ?? me?.arcId;
        print('🩺 User ARC ID: $arcId');
      } catch (_) {}

      final prescriptions = arcId != null && arcId.isNotEmpty
          ? await ApiService.getPrescriptionsByPatientArcId(arcId,
              status: 'Active')
          : await ApiService.getPrescriptionsByStatus(userId, status: 'Active');

      print(
          '🩺 Found ${prescriptions.length} prescriptions for medicine order');
      if (prescriptions.isNotEmpty) {
        print(
            '🩺 Sample prescription for medicine order: ${prescriptions.first}');
        print(
            '🩺 Sample prescription medications: ${prescriptions.first['medications']}');
      }
      _prescriptions = prescriptions
          .map((p) => {
                'id': p['id'] ?? p['_id'],
                'doctor': p['doctorName'] ?? 'Unknown Doctor',
                'department': p['department'] ?? 'General',
                'date': DateTime.tryParse(p['createdAt']?.toString() ?? '') ??
                    DateTime.now(),
                'medicines': (p['medications'] as List? ?? [])
                    .map((m) => {
                          'name': m['name'] ?? 'Unknown Medicine',
                          'dosage': m['dosage'] ?? 'As directed',
                          'quantity': m['quantity'] ?? 1,
                          'instructions':
                              m['instructions'] ?? 'Take as prescribed',
                        })
                    .toList(),
              })
          .toList();

      print('🩺 Mapped prescriptions count: ${_prescriptions.length}');
      if (_prescriptions.isNotEmpty) {
        print('🩺 Sample mapped prescription: ${_prescriptions.first}');
      }
    } catch (e) {
      print('❌ Error loading prescriptions: $e');
      // Use mock data as fallback
      _prescriptions = [
        {
          'id': 'P001',
          'doctor': 'Dr. John Smith',
          'department': 'Cardiology',
          'date': DateTime.now().subtract(const Duration(days: 5)),
          'medicines': [
            {
              'name': 'Amlodipine 5mg',
              'dosage': 'Once daily',
              'quantity': 30,
              'instructions': 'Take with food'
            },
            {
              'name': 'Metoprolol 25mg',
              'dosage': 'Twice daily',
              'quantity': 60,
              'instructions': 'Take with water'
            },
          ],
        },
      ];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Order Medicines'),
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
            icon: const Icon(Icons.qr_code_scanner),
            onPressed: _openMedicineScanner,
            tooltip: 'Scan Medicine QR Code',
          ),
          IconButton(
            icon: const Icon(Icons.shopping_cart),
            onPressed: _viewCart,
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar (restored)
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search medicines...',
                prefixIcon: const Icon(Icons.search),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.grey[100],
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
                // Perform search with debounce
                Future.delayed(const Duration(milliseconds: 500), () {
                  if (_searchQuery == value) {
                    _performSearch();
                  }
                });
              },
            ),
          ),
          // Tab Bar
          Container(
            color: Colors.grey[100],
            child: Row(
              children: [
                Expanded(
                  child: _buildTabButton('Browse', 0),
                ),
                Expanded(
                  child: _buildTabButton('My Orders', 1),
                ),
                Expanded(
                  child: _buildTabButton('Prescriptions', 2),
                ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: _isLoading
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Loading medicines...',
                            style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  )
                : _buildContent(),
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
          gradient: isSelected
              ? const LinearGradient(
                  colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: isSelected ? null : Colors.transparent,
          border: Border(
            bottom: BorderSide(
              color: isSelected ? const Color(0xFFFFA500) : Colors.grey[300]!,
              width: 2,
            ),
          ),
        ),
        child: Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey[600],
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    switch (_selectedIndex) {
      case 0:
        return _buildBrowseMedicines();
      case 1:
        // Navigate directly to My Orders screen
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const MyOrdersScreen(),
            ),
          );
          // Reset to Browse tab after navigation
          setState(() {
            _selectedIndex = 0;
          });
        });
        return _buildBrowseMedicines(); // Show browse while navigating
      case 2:
        return _buildPrescriptions();
      default:
        return _buildBrowseMedicines();
    }
  }

  Widget _buildBrowseMedicines() {
    final medicines = _getFilteredMedicines();

    if (medicines.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.medication, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('No medicines found',
                style: TextStyle(fontSize: 18, color: Colors.grey)),
            SizedBox(height: 8),
            Text('Try adjusting your search or check back later',
                style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: medicines.length,
      itemBuilder: (context, index) {
        final medicine = medicines[index];
        return _buildMedicineCard(medicine);
      },
    );
  }

  Widget _buildPrescriptions() {
    print('🩺 Building prescriptions UI - count: ${_prescriptions.length}');
    if (_prescriptions.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.medication, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('No active prescriptions found',
                style: TextStyle(fontSize: 18, color: Colors.grey)),
            SizedBox(height: 8),
            Text(
                'Active prescriptions from your doctor will appear here for easy ordering',
                style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _prescriptions.length,
      itemBuilder: (context, index) {
        final prescription = _prescriptions[index];
        return _buildPrescriptionCard(prescription);
      },
    );
  }

  List<Map<String, dynamic>> _getFilteredMedicines() {
    // For now, return all medicines since we're loading from API
    // In the future, we can implement client-side filtering or server-side search
    return _medicines;
  }

  Future<void> _performSearch() async {
    if (_searchQuery.isNotEmpty) {
      setState(() {
        _isLoading = true;
      });

      try {
        _medicines = await ApiService.searchMedicines(_searchQuery);
      } catch (e) {
        print('❌ Error searching medicines: $e');
        _medicines = [];
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    } else {
      // If search is empty, load all medicines
      await _loadMedicines();
    }
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'In Stock':
        return Colors.green;
      case 'Low Stock':
        return Colors.orange;
      case 'Out of Stock':
        return Colors.red;
      default:
        return Colors.green;
    }
  }

  Widget _buildMedicineCard(Map<String, dynamic> medicine) {
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
              width: 60,
              height: 60,
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
                size: 30,
              ),
            ),
            const SizedBox(width: 16),

            // Medicine Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    medicine['name'] ?? 'Unknown Medicine',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    medicine['category'] ?? 'General',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    medicine['pharmacy']?['name'] ??
                        medicine['pharmacy']?['pharmacyName'] ??
                        'Unknown Pharmacy',
                    style: TextStyle(
                        color: Colors.grey[700],
                        fontSize: 12,
                        fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${medicine['pharmacyCity'] ?? medicine['pharmacy']?['city'] ?? 'Unknown City'}, ${medicine['pharmacyState'] ?? medicine['pharmacy']?['state'] ?? 'Unknown State'}',
                    style: TextStyle(color: Colors.grey[500], fontSize: 11),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${medicine['type'] ?? 'tablet'} • Stock: ${medicine['stock'] ?? 0}',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.star, color: Colors.amber, size: 16),
                      Builder(
                        builder: (context) {
                          final pharmacyId = medicine['pharmacy']?['id'] ??
                              medicine['pharmacyId'] ??
                              medicine['pharmacy_id'] ??
                              '';

                          if (pharmacyId.isEmpty) {
                            return Text(
                              ' No ratings',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey[600]),
                            );
                          }

                          return FutureBuilder<Map<String, dynamic>?>(
                            future: ApiService.getPharmacyRatingSummary(
                                pharmacyId: pharmacyId),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return Text(
                                  ' Loading...',
                                  style: TextStyle(
                                      fontSize: 12, color: Colors.grey[500]),
                                );
                              }

                              if (snapshot.hasError) {
                                return Text(
                                  ' Network error',
                                  style: TextStyle(
                                      fontSize: 12, color: Colors.orange[600]),
                                );
                              }

                              final avg = snapshot.data?['averageRating'] ?? 0;
                              final total = snapshot.data?['totalRatings'] ?? 0;
                              return Text(
                                ' ${avg.toString()} (${total})',
                                style: TextStyle(
                                    fontSize: 12, color: Colors.grey[600]),
                              );
                            },
                          );
                        },
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: _getStatusColor(medicine['status'])
                              .withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          medicine['status'] ?? 'In Stock',
                          style: TextStyle(
                              color: _getStatusColor(medicine['status']),
                              fontSize: 10,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Price and Add Button
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '₹${(medicine['sellingPrice'] ?? medicine['unitPrice'] ?? 0.0).toStringAsFixed(2)}',
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFFFA500)),
                ),
                const SizedBox(height: 8),
                if ((medicine['status'] ?? 'In Stock') != 'Out of Stock')
                  ElevatedButton(
                    onPressed: () => _addToCart(medicine),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFFA500),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(80, 32),
                    ),
                    child: const Text('Add'),
                  )
                else
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Out of Stock',
                      style: TextStyle(color: Colors.grey, fontSize: 10),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrescriptionCard(Map<String, dynamic> prescription) {
    return Card(
      elevation: 3,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ExpansionTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Colors.green, Colors.lightGreen],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.medication, color: Colors.white, size: 24),
        ),
        title: Text(
          'Prescription #${prescription['id']}',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.person, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text('Dr. ${prescription['doctor']}'),
              ],
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                    'Date: ${DateFormat('MMM d, y').format(prescription['date'])}'),
              ],
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.withOpacity(0.3)),
              ),
              child: const Text(
                'Active',
                style: TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.05),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Medications:',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 12),
                ...prescription['medicines']
                    .map<Widget>((medicine) => Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border:
                                Border.all(color: Colors.grey.withOpacity(0.2)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.withOpacity(0.1),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      medicine['name'],
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Dosage: ${medicine['dosage']}',
                                      style: const TextStyle(
                                        color: Colors.grey,
                                        fontSize: 14,
                                      ),
                                    ),
                                    if (medicine['instructions'] != null &&
                                        medicine['instructions'].isNotEmpty)
                                      Text(
                                        'Instructions: ${medicine['instructions']}',
                                        style: const TextStyle(
                                          color: Colors.grey,
                                          fontSize: 12,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              // Removed direct Order button as requested
                            ],
                          ),
                        )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _addToCart(Map<String, dynamic> medicine) async {
    try {
      // Add medicine to cart using SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final cartData = prefs.getString('cart_items') ?? '';

      // Check if medicine already exists in cart
      final existingItems =
          cartData.split('|||').where((item) => item.isNotEmpty).toList();
      bool itemExists = false;

      for (int i = 0; i < existingItems.length; i++) {
        final itemData = existingItems[i].split('|');
        final itemMap = <String, String>{};
        for (final pair in itemData) {
          final parts = pair.split(':');
          if (parts.length >= 2) {
            itemMap[parts[0]] = parts.sublist(1).join(':');
          }
        }

        if (itemMap['id'] == medicine['id']) {
          // Update quantity
          final newQuantity =
              (int.tryParse(itemMap['quantity'] ?? '1') ?? 1) + 1;
          itemMap['quantity'] = newQuantity.toString();
          existingItems[i] =
              itemMap.entries.map((e) => '${e.key}:${e.value}').join('|');
          itemExists = true;
          break;
        }
      }

      if (!itemExists) {
        // Add new item
        final newItem = {
          'id': medicine['id'],
          'name': medicine['name'],
          'sellingPrice': medicine['sellingPrice']?.toString() ?? '0',
          'unitPrice': medicine['unitPrice']?.toString() ?? '0',
          'price': medicine['sellingPrice']?.toString() ??
              medicine['unitPrice']?.toString() ??
              '0',
          'quantity': '1',
          'pharmacyName': medicine['pharmacy']?['name'] ??
              medicine['pharmacy']?['pharmacyName'] ??
              'Unknown Pharmacy',
          'pharmacyId': medicine['pharmacy']?['id'] ?? '',
          'pharmacyCity': medicine['pharmacy']?['city'] ?? 'Unknown City',
          'pharmacyState': medicine['pharmacy']?['state'] ?? 'Unknown State',
          'category': medicine['category'] ?? 'General',
          'type': medicine['type'] ?? 'tablet',
          'stock': medicine['stock']?.toString() ?? '0',
          'status': medicine['status'] ?? 'In Stock',
        };
        existingItems
            .add(newItem.entries.map((e) => '${e.key}:${e.value}').join('|'));
      }

      // Save updated cart
      await prefs.setString('cart_items', existingItems.join('|||'));

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${medicine['name']} added to cart'),
          backgroundColor: const Color(0xFFFFA500),
        ),
      );
    } catch (e) {
      print('❌ Error adding to cart: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to add to cart: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _viewCart() {
    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const CartScreen()),
      );
    }
  }

  void _openMedicineScanner() {
    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const QRMedicineScannerScreen(isUserMode: true),
        ),
      );
    }
  }

  // Removed _orderFromPrescription as direct order from prescriptions is disabled
}
