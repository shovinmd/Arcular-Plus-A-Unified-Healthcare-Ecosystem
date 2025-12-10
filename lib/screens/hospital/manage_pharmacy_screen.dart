import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../models/user_model.dart';
import '../../services/api_service.dart';
import '../../utils/constants.dart';

class ManagePharmacyScreen extends StatefulWidget {
  const ManagePharmacyScreen({super.key});

  @override
  State<ManagePharmacyScreen> createState() => _ManagePharmacyScreenState();
}

class _ManagePharmacyScreenState extends State<ManagePharmacyScreen>
    with TickerProviderStateMixin {
  bool _loading = true;
  List<UserModel> _pharmacies = [];
  List<UserModel> _filteredPharmacies = [];
  List<Map<String, dynamic>> _orders = [];
  List<Map<String, dynamic>> _filteredOrders = [];
  final _arcIdController = TextEditingController();
  final _searchController = TextEditingController();
  late TabController _tabController;

  final _patientArcIdController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _arcIdController.dispose();
    _searchController.dispose();
    _patientArcIdController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      if (mounted) {
        setState(() => _loading = true);
      }
      final hospitalMongoId = await ApiService.getHospitalMongoId(
          FirebaseAuth.instance.currentUser!.uid);
      if (hospitalMongoId == null) {
        if (mounted) {
          setState(() => _loading = false);
        }
        return;
      }
      // Load pharmacies
      final pharmacies =
          await ApiService.getAssociatedPharmacies(hospitalMongoId);

      // Load hospital orders
      final orders = await ApiService.getHospitalOrders(hospitalMongoId);
      print('🏥 Loaded ${orders.length} orders');
      if (orders.isNotEmpty) {
        print('🏥 Sample order data: ${orders.first}');
      }

      if (mounted) {
        setState(() {
          _pharmacies = pharmacies;
          _filteredPharmacies = _pharmacies;
          _orders = orders;
          _filteredOrders = _orders;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to load pharmacies: $e')));
      }
    }
  }

  void _filterPharmacies(String query) {
    if (mounted) {
      setState(() {
        if (query.isEmpty) {
          _filteredPharmacies = _pharmacies;
        } else {
          _filteredPharmacies = _pharmacies.where((pharmacy) {
            final displayName = pharmacy.type == 'pharmacy'
                ? (pharmacy.pharmacyName ?? pharmacy.fullName)
                : pharmacy.fullName;
            return displayName.toLowerCase().contains(query.toLowerCase()) ||
                (pharmacy.role ?? '')
                    .toLowerCase()
                    .contains(query.toLowerCase());
          }).toList();
        }
      });
    }
  }

  void _filterOrders(String query) {
    if (mounted) {
      setState(() {
        if (query.isEmpty) {
          _filteredOrders = _orders;
        } else {
          _filteredOrders = _orders.where((order) {
            return (order['patientArcId'] ?? '')
                    .toLowerCase()
                    .contains(query.toLowerCase()) ||
                (order['medicineName'] ?? '')
                    .toLowerCase()
                    .contains(query.toLowerCase()) ||
                (order['pharmacyName'] ?? '')
                    .toLowerCase()
                    .contains(query.toLowerCase());
          }).toList();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          'Pharmacy Management',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFFE65100), // Orange pharmacy theme
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.local_pharmacy), text: 'Pharmacies'),
            Tab(icon: Icon(Icons.shopping_cart), text: 'Orders'),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _load,
            icon: const Icon(Icons.refresh, color: Colors.white),
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildPharmaciesTab(),
          _buildOrdersTab(),
        ],
      ),
    );
  }

  Widget _buildPharmaciesTab() {
    return Column(
      children: [
        // Add Pharmacy Section
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFFE65100)!.withOpacity(0.1),
                const Color(0xFFE65100)!.withOpacity(0.05)
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border:
                Border.all(color: const Color(0xFFE65100)!.withOpacity(0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.person_add,
                      color: const Color(0xFFE65100), size: 24),
                  const SizedBox(width: 8),
                  Text(
                    'Add Pharmacy',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: kPrimaryText,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _arcIdController,
                      decoration: InputDecoration(
                        hintText: 'Pharmacy ARC ID (e.g., PHARM001)',
                        prefixIcon:
                            Icon(Icons.badge, color: const Color(0xFFE65100)),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                              color: const Color(0xFFE65100).withOpacity(0.3)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              BorderSide(color: const Color(0xFFE65100)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _addPharmacy,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE65100),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Search Section
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            controller: _searchController,
            onChanged: _filterPharmacies,
            decoration: InputDecoration(
              hintText: 'Search pharmacies by name or role...',
              prefixIcon: Icon(Icons.search, color: const Color(0xFFE65100)),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    BorderSide(color: const Color(0xFFE65100).withOpacity(0.3)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: const Color(0xFFE65100)),
              ),
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Pharmacies List
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _filteredPharmacies.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _filteredPharmacies.length,
                      itemBuilder: (context, index) {
                        final pharmacy = _filteredPharmacies[index];
                        return _buildPharmacyCard(pharmacy);
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildOrdersTab() {
    return Column(
      children: [
        // Search Section
        Container(
          margin: const EdgeInsets.all(16),
          child: TextField(
            onChanged: _filterOrders,
            decoration: InputDecoration(
              hintText:
                  'Search orders by patient ARC ID, medicine, or pharmacy...',
              prefixIcon: Icon(Icons.search, color: const Color(0xFFE65100)),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    BorderSide(color: const Color(0xFFE65100).withOpacity(0.3)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: const Color(0xFFE65100)),
              ),
            ),
          ),
        ),

        // Orders List
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _filteredOrders.isEmpty
                  ? _buildEmptyOrdersState()
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _filteredOrders.length,
                      itemBuilder: (context, index) {
                        final order = _filteredOrders[index];
                        return _buildOrderCard(order);
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.local_pharmacy_outlined,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No pharmacies found',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add pharmacies using their ARC ID to get started',
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

  Widget _buildEmptyOrdersState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.shopping_cart_outlined,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No orders found',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Orders will appear here when placed',
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

  Widget _buildPharmacyCard(UserModel pharmacy) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () => _showPharmacyDetails(pharmacy),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              // Pharmacy Avatar
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFFE65100).withOpacity(0.8),
                      const Color(0xFFE65100)
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: const Icon(
                  Icons.local_pharmacy,
                  color: Colors.white,
                  size: 30,
                ),
              ),

              const SizedBox(width: 16),

              // Pharmacy Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pharmacy.type == 'pharmacy'
                          ? (pharmacy.pharmacyName ?? pharmacy.fullName)
                          : pharmacy.fullName,
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: kPrimaryText,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      pharmacy.role ?? 'Pharmacy',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: kSecondaryText,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE65100).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color:
                                    const Color(0xFFE65100).withOpacity(0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.badge,
                                size: 16,
                                color: const Color(0xFFE65100),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'ARC ID: ${(pharmacy.arcId ?? '').isNotEmpty ? pharmacy.arcId : 'N/A'}',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: const Color(0xFFE65100),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Action Buttons
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Order Medicine Button
                  InkWell(
                    onTap: () => _orderMedicine(pharmacy),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE65100).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.shopping_cart,
                        color: const Color(0xFFE65100),
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Remove Button
                  InkWell(
                    onTap: () => _removePharmacyAssociation(pharmacy),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.remove_circle_outline,
                        color: Colors.red,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> order) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFFE65100)!.withOpacity(0.8),
                        const Color(0xFFE65100)!
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: const Icon(
                    Icons.shopping_cart,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order['items'] != null && order['items'].isNotEmpty
                            ? order['items'][0]['medicineName'] ??
                                'Unknown Medicine'
                            : 'Unknown Medicine',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: kPrimaryText,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Patient: ${order['userName'] ?? 'N/A'}',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: kSecondaryText,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _getStatusColor(order['status'] ?? 'pending')
                        .withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: _getStatusColor(order['status'] ?? 'pending')
                            .withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _getStatusIcon(order['status'] ?? 'pending'),
                        size: 14,
                        color: _getStatusColor(order['status'] ?? 'pending'),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _getStatusText(order['status'] ?? 'pending'),
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: _getStatusColor(order['status'] ?? 'pending'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.local_pharmacy,
                    size: 16, color: const Color(0xFFE65100)),
                const SizedBox(width: 8),
                Text(
                  'Pharmacy: ${order['pharmacyName'] ?? 'N/A'}',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                const Spacer(),
                Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  DateFormat('MMM dd, yyyy').format(
                    DateTime.parse(
                        order['createdAt'] ?? DateTime.now().toIso8601String()),
                  ),
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'confirmed':
        return Colors.blue;
      case 'shipped':
        return Colors.purple;
      case 'delivered':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'Pending';
      case 'confirmed':
        return 'Confirmed';
      case 'shipped':
        return 'Shipped';
      case 'delivered':
        return 'Delivered';
      case 'cancelled':
        return 'Cancelled';
      default:
        return 'Unknown';
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Icons.hourglass_empty;
      case 'confirmed':
        return Icons.check_circle_outline;
      case 'shipped':
        return Icons.local_shipping;
      case 'delivered':
        return Icons.done_all;
      case 'cancelled':
        return Icons.cancel;
      default:
        return Icons.help_outline;
    }
  }

  void _showPharmacyDetails(UserModel pharmacy) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.local_pharmacy,
                color: const Color(0xFFE65100), size: 24),
            const SizedBox(width: 8),
            Text(
              'Pharmacy Details',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow(
                'Pharmacy Name',
                pharmacy.type == 'pharmacy'
                    ? (pharmacy.pharmacyName ?? pharmacy.fullName)
                    : pharmacy.fullName),
            _buildDetailRow('ARC ID', pharmacy.arcId ?? 'N/A'),
            _buildDetailRow('Role', pharmacy.role ?? 'Pharmacy'),
            _buildDetailRow('Email', pharmacy.email),
            _buildDetailRow('Phone', pharmacy.mobileNumber),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Close',
              style: GoogleFonts.poppins(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.poppins(color: Colors.grey[800]),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _addPharmacy() async {
    if (_arcIdController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter pharmacy ARC ID'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      print('🏥 Adding pharmacy with ARC ID: ${_arcIdController.text.trim()}');
      await ApiService.associatePharmacyByArcId(_arcIdController.text.trim());

      _arcIdController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 8),
              Text('Pharmacy associated successfully'),
            ],
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
      _load(); // Refresh data
    } catch (e) {
      print('❌ Error adding pharmacy: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(child: Text('Failed to associate pharmacy: $e')),
            ],
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _removePharmacyAssociation(UserModel pharmacy) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Remove Pharmacy',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        content: Text(
          'Are you sure you want to remove ${pharmacy.fullName} from your associated pharmacies?',
          style: GoogleFonts.poppins(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text(
              'Remove',
              style: GoogleFonts.poppins(),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) return;

        print(
            '🏥 Removing pharmacy association: ${pharmacy.fullName} (${pharmacy.uid})');
        final success =
            await ApiService.removePharmacyAssociation(user.uid, pharmacy.uid);

        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 8),
                  Text('${pharmacy.fullName} removed successfully'),
                ],
              ),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
          _load(); // Refresh data
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to remove pharmacy association'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error removing pharmacy: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _orderMedicine(UserModel pharmacy) async {
    // Show medicine order dialog and handle returned order data
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _buildMedicineOrderDialog(pharmacy),
    );

    // If order was created successfully, add it to the orders list
    if (result != null) {
      setState(() {
        _orders.insert(0, result);
        _filteredOrders = _orders;
      });
    }
  }

  Widget _buildMedicineOrderDialog(UserModel pharmacy) {
    return _MedicineOrderDialog(pharmacy: pharmacy);
  }
}

class _MedicineOrderDialog extends StatefulWidget {
  final UserModel pharmacy;

  const _MedicineOrderDialog({required this.pharmacy});

  @override
  State<_MedicineOrderDialog> createState() => _MedicineOrderDialogState();
}

class _MedicineOrderDialogState extends State<_MedicineOrderDialog> {
  final patientArcIdController = TextEditingController();
  final quantityController = TextEditingController();
  final notesController = TextEditingController();
  final addressController = TextEditingController();
  final contactController = TextEditingController();

  List<Map<String, dynamic>> medicines = [];
  bool loadingMedicines = true;
  bool loadingPatient = false;
  bool isPlacingOrder = false;
  bool medicinesLoaded = false;
  String? selectedMedicine;
  int? selectedMedicineIndex;
  Map<String, dynamic>? patientDetails;

  @override
  void initState() {
    super.initState();
    loadMedicines();
  }

  @override
  void dispose() {
    patientArcIdController.dispose();
    quantityController.dispose();
    notesController.dispose();
    addressController.dispose();
    contactController.dispose();
    super.dispose();
  }

  // Load pharmacy medicines
  Future<void> loadMedicines() async {
    if (medicinesLoaded) return; // Prevent multiple calls

    try {
      setState(() {
        loadingMedicines = true;
      });
      print(
          '💊 Loading medicines for pharmacy: ${widget.pharmacy.fullName} (${widget.pharmacy.uid})');
      final response =
          await ApiService.getPharmacyMedicines(widget.pharmacy.uid);
      print(
          '💊 Medicines response: ${response['data']?.length ?? 0} medicines found');

      setState(() {
        medicines = List<Map<String, dynamic>>.from(response['data'] ?? []);
        loadingMedicines = false;
        medicinesLoaded = true;
      });
      print('💊 Medicines loaded: ${medicines.length} medicines');
      print('💊 Medicines list: $medicines');
    } catch (e) {
      print('❌ Error loading medicines: $e');
      setState(() {
        loadingMedicines = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load medicines: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Load patient details by ARC ID
  Future<void> loadPatientDetails(String arcId) async {
    if (arcId.trim().isEmpty) {
      setState(() {
        patientDetails = null;
        loadingPatient = false;
      });
      return;
    }

    try {
      setState(() {
        loadingPatient = true;
      });
      print('👤 Loading patient details for ARC ID: $arcId');
      final response = await ApiService.getUserByArcId(arcId.trim());
      print('👤 Patient response: $response');

      setState(() {
        patientDetails = response;
        loadingPatient = false;
      });

      if (response != null) {
        print('👤 Patient loaded: ${response['fullName']}');
        // Auto-fill address and contact from patient details
        addressController.text = response['address'] ?? '';
        contactController.text = response['mobileNumber'] ?? '';
      } else {
        print('👤 Patient not found');
      }
    } catch (e) {
      print('❌ Error loading patient details: $e');
      setState(() {
        patientDetails = null;
        loadingPatient = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Patient not found with ARC ID: $arcId'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  // Place order function
  Future<void> placeOrder() async {
    if (patientArcIdController.text.trim().isEmpty ||
        selectedMedicine == null ||
        quantityController.text.trim().isEmpty ||
        addressController.text.trim().isEmpty ||
        contactController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill all required fields'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      isPlacingOrder = true;
    });

    try {
      // Get medicine details for pricing
      final medicine = medicines[selectedMedicineIndex!];
      final unitPrice = medicine['unitPrice'] ?? 0.0;
      final quantity = int.tryParse(quantityController.text.trim()) ?? 1;
      final subtotal = unitPrice * quantity;
      final deliveryFee = 30.0;
      final totalAmount = subtotal + deliveryFee;

      // Create order data in the format expected by backend
      final orderData = {
        'pharmacyId': widget.pharmacy.uid,
        'pharmacyName': widget.pharmacy.fullName,
        'patientArcId': patientArcIdController.text.trim(),
        'medicineId': medicine['_id'] ?? medicine['id'],
        'medicineName': selectedMedicine!,
        'quantity': quantity,
        'unitPrice': unitPrice,
        'subtotal': subtotal,
        'deliveryFee': deliveryFee,
        'totalAmount': totalAmount,
        'notes': notesController.text.trim(),
        'patientDetails': patientDetails ??
            {
              'fullName': 'Unknown Patient',
              'mobileNumber': contactController.text.trim(),
              'address': addressController.text.trim(),
              'email': 'hospital@arcular.com',
            },
      };

      // Create the order via API
      final success = await ApiService.createPharmacyOrder(orderData);

      if (success != null) {
        // Add to local orders list for immediate UI update
        final newOrder = {
          'id': DateTime.now().millisecondsSinceEpoch.toString(),
          'patientArcId': orderData['patientArcId'],
          'patientName': patientDetails?['fullName'] ?? 'Unknown Patient',
          'medicineName': orderData['medicineName'],
          'quantity': orderData['quantity'],
          'notes': orderData['notes'],
          'deliveryAddress': addressController.text.trim(),
          'contactNumber': contactController.text.trim(),
          'pharmacyName': orderData['pharmacyName'],
          'status': 'pending',
          'createdAt': DateTime.now().toIso8601String(),
        };

        // Update the parent screen's order list
        if (mounted) {
          // Use a callback to update the parent screen
          Navigator.pop(context, newOrder);
        }

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Text(
                    'Order placed successfully with ${widget.pharmacy.fullName}'),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to create order. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
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
        isPlacingOrder = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Icon(Icons.shopping_cart, color: const Color(0xFFE65100), size: 24),
          const SizedBox(width: 8),
          Text(
            'Order Medicine',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Pharmacy Info
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFE65100).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border:
                    Border.all(color: const Color(0xFFE65100).withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.local_pharmacy,
                      color: const Color(0xFFE65100), size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Pharmacy: ${widget.pharmacy.fullName}',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFFE65100),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Patient ARC ID Input with Search Button
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: patientArcIdController,
                    decoration: const InputDecoration(
                      labelText: 'Patient ARC ID *',
                      hintText: 'Enter patient ARC ID',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: loadingPatient
                      ? null
                      : () {
                          if (patientArcIdController.text.trim().isNotEmpty) {
                            loadPatientDetails(
                                patientArcIdController.text.trim());
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Please enter patient ARC ID'),
                                backgroundColor: Colors.orange,
                              ),
                            );
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE65100),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                  ),
                  child: loadingPatient
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Icon(Icons.search, size: 20),
                ),
              ],
            ),

            // Success indicator when patient is found
            if (patientDetails != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green[200]!),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle,
                        color: Colors.green, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Patient found: ${patientDetails!['fullName'] ?? 'Unknown'}',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.green[700],
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Patient Details Display
            if (patientDetails != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.person, color: Colors.green[600], size: 16),
                        const SizedBox(width: 8),
                        Text(
                          'Patient Details',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            color: Colors.green[700],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Name: ${patientDetails!['fullName'] ?? 'N/A'}',
                      style: GoogleFonts.poppins(fontSize: 14),
                    ),
                    Text(
                      'Phone: ${patientDetails!['mobileNumber'] ?? 'N/A'}',
                      style: GoogleFonts.poppins(fontSize: 14),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 12),

            // Medicine Selection Dropdown
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[400]!),
                borderRadius: BorderRadius.circular(8),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: selectedMedicineIndex != null &&
                          selectedMedicineIndex! < medicines.length
                      ? 'medicine_${medicines[selectedMedicineIndex!]['_id'] ?? medicines[selectedMedicineIndex!]['id'] ?? selectedMedicineIndex}'
                      : null,
                  hint: Text(
                    loadingMedicines
                        ? 'Loading medicines...'
                        : 'Select Medicine *',
                    style: GoogleFonts.poppins(color: Colors.grey[600]),
                  ),
                  isExpanded: true,
                  items: medicines.isEmpty
                      ? []
                      : medicines.map((medicine) {
                          final uniqueValue =
                              'medicine_${medicine['_id'] ?? medicine['id'] ?? medicines.indexOf(medicine)}';
                          print(
                              '💊 Adding medicine to dropdown: ${medicine['name']} (${uniqueValue})');
                          return DropdownMenuItem<String>(
                            value: uniqueValue,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  medicine['name'] ?? 'Unknown Medicine',
                                  style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.w500),
                                ),
                                Text(
                                  'Stock: ${medicine['stock'] ?? 0} | Price: ₹${medicine['unitPrice'] ?? 'N/A'}',
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                  onChanged: (value) {
                    if (!mounted) return;
                    setState(() {
                      selectedMedicineIndex = medicines.indexWhere((medicine) =>
                          'medicine_${medicine['_id'] ?? medicine['id'] ?? medicines.indexOf(medicine)}' ==
                          value);
                      if (selectedMedicineIndex != -1) {
                        selectedMedicine =
                            medicines[selectedMedicineIndex!]['name'];
                      }
                    });
                  },
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Quantity Input
            TextField(
              controller: quantityController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Quantity *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.numbers),
              ),
            ),

            const SizedBox(height: 12),

            // Delivery Address Input
            TextField(
              controller: addressController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Delivery Address *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.location_on),
              ),
            ),

            const SizedBox(height: 12),

            // Contact Number Input
            TextField(
              controller: contactController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Contact Number *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.phone),
              ),
            ),

            const SizedBox(height: 12),

            // Notes Input
            TextField(
              controller: notesController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Notes (Optional)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.note),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: isPlacingOrder ? null : () => Navigator.pop(context),
          child: Text(
            'Cancel',
            style: GoogleFonts.poppins(),
          ),
        ),
        ElevatedButton(
          onPressed: isPlacingOrder ? null : placeOrder,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFE65100),
            foregroundColor: Colors.white,
          ),
          child: isPlacingOrder
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Text(
                  'Place Order',
                  style: GoogleFonts.poppins(),
                ),
        ),
      ],
    );
  }
}
