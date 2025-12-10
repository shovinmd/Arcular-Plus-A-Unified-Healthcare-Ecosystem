import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../utils/constants.dart';
import '../../models/medicine_model.dart';
import '../../services/api_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class InventoryManagementScreen extends StatefulWidget {
  const InventoryManagementScreen({super.key});

  @override
  State<InventoryManagementScreen> createState() =>
      _InventoryManagementScreenState();
}

class _InventoryManagementScreenState extends State<InventoryManagementScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  List<MedicineModel> _medicines = [];
  bool _isLoading = true;
  String? _pharmacyId;
  List<MedicineModel> _filteredMedicines = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadPharmacyId();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadPharmacyId() async {
    try {
      // Get pharmacy ID from Firebase Auth (same pattern as dashboard)
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        _pharmacyId = user.uid;
        await _loadMedicines();
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('❌ Error loading pharmacy ID: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMedicines() async {
    if (_pharmacyId == null) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await ApiService.getPharmacyMedicines(_pharmacyId!);
      final medicinesData = response['data'] as List<dynamic>? ?? [];
      final medicines =
          medicinesData.map((data) => MedicineModel.fromJson(data)).toList();

      setState(() {
        _medicines = medicines;
        _filteredMedicines = medicines;
        _isLoading = false;
      });
    } catch (e) {
      print('❌ Error loading medicines: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _filterMedicines(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredMedicines = _medicines;
      } else {
        _filteredMedicines = _medicines.where((medicine) {
          return medicine.name.toLowerCase().contains(query.toLowerCase()) ||
              medicine.category?.toLowerCase().contains(query.toLowerCase()) ==
                  true;
        }).toList();
      }
    });
  }

  double _calculateTotalInventoryValue() {
    double totalValue = 0.0;
    for (var medicine in _medicines) {
      totalValue += ((medicine.sellingPrice ?? 0) * (medicine.stock ?? 0));
    }
    return totalValue;
  }

  Widget _buildRecentActivities() {
    if (_medicines.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Center(
          child: Text(
            'No recent activities',
            style: GoogleFonts.poppins(
              color: Colors.grey[600],
              fontSize: 14,
            ),
          ),
        ),
      );
    }

    // Get recent medicines (last 5)
    final recentMedicines = _medicines.take(5).toList();

    return Column(
      children: recentMedicines.map((medicine) {
        final statusColor = _getStatusColor(medicine.status);
        final statusIcon = _getStatusIcon(medicine.status);

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(statusIcon, color: statusColor, size: 16),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      medicine.name,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: kPrimaryText,
                      ),
                    ),
                    Text(
                      '${medicine.category ?? 'Unknown'} • Stock: ${medicine.stock ?? 0}',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: kSecondaryText,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  medicine.status ?? 'Unknown',
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(
        title: Text(
          'Inventory Management',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.green[600], // Green theme like dashboard
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: () {
              _loadMedicines();
            },
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(kToolbarHeight),
          child: Container(
            color: Colors.green[600], // Green theme like dashboard
            child: TabBar(
              controller: _tabController,
              indicatorColor: Colors.white,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              tabs: const [
                Tab(text: 'Overview'),
                Tab(text: 'Medicines'),
                Tab(text: 'Alerts'),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOverviewTab(),
          _buildMedicinesTab(),
          _buildAlertsTab(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _showAddMedicineDialog();
        },
        backgroundColor: Colors.green[600], // Green theme like dashboard
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildOverviewTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final totalMedicines = _medicines.length;
    final inStock = _medicines.where((m) => m.status == 'In Stock').length;
    final lowStock = _medicines.where((m) => m.status == 'Low Stock').length;
    final outOfStock =
        _medicines.where((m) => m.status == 'Out of Stock').length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stats Grid
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            childAspectRatio: 1.8,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            children: [
              _buildStatCard('Total Medicines', totalMedicines.toString(),
                  Icons.medication, Colors.blue),
              _buildStatCard('In Stock', inStock.toString(), Icons.check_circle,
                  Colors.green),
              _buildStatCard('Low Stock', lowStock.toString(), Icons.warning,
                  Colors.orange),
              _buildStatCard('Out of Stock', outOfStock.toString(),
                  Icons.cancel, Colors.red),
            ],
          ),
          const SizedBox(height: 24),

          // Total Inventory Value Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue[50]!, Colors.blue[100]!],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.blue[200]!,
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue[600],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.inventory_2,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Total Inventory Value',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.blue[800],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '₹${_calculateTotalInventoryValue().toStringAsFixed(2)}',
                        style: GoogleFonts.poppins(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[900],
                        ),
                      ),
                      Text(
                        '${_medicines.length} medicines • Total: ₹${_calculateTotalInventoryValue().toStringAsFixed(2)}',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: Colors.blue[700],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.blue[600],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'VALUE',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Recent Inventory Activities
          Text(
            'Recent Inventory Activities',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: kPrimaryText,
            ),
          ),
          const SizedBox(height: 16),
          _buildRecentActivities(),
        ],
      ),
    );
  }

  Widget _buildMedicinesTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        // Search Bar
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            onChanged: _filterMedicines,
            decoration: InputDecoration(
              hintText: 'Search medicines...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),

        // Medicines List
        Expanded(
          child: _filteredMedicines.isEmpty
              ? const Center(
                  child: Text(
                    'No medicines found',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _filteredMedicines.length,
                  itemBuilder: (context, index) {
                    final medicine = _filteredMedicines[index];
                    return _buildMedicineCard(medicine);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildAlertsTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final alerts = _medicines
        .where((m) => m.status == 'Low Stock' || m.status == 'Out of Stock')
        .toList();

    return alerts.isEmpty
        ? const Center(
            child: Text(
              'No alerts found',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          )
        : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: alerts.length,
            itemBuilder: (context, index) {
              final medicine = alerts[index];
              return _buildAlertCard(medicine);
            },
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
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Flexible(
            child: Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: kSecondaryText,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMedicineCard(MedicineModel medicine) {
    final statusColor = _getStatusColor(medicine.status);
    final statusIcon = _getStatusIcon(medicine.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(statusIcon, color: statusColor, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  medicine.name,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: kPrimaryText,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${medicine.category ?? 'Unknown'} • ${medicine.type}',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: kSecondaryText,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.inventory,
                      size: 16,
                      color: kSecondaryText,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Stock: ${medicine.stock ?? 0} units',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: kSecondaryText,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Icon(
                      Icons.access_time,
                      size: 16,
                      color: kSecondaryText,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _formatLastUpdated(medicine.lastUpdated),
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: kSecondaryText,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Action Buttons - ensure no overflow
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 120),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  // Stock Status Badge
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: statusColor.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          statusIcon,
                          color: statusColor,
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _getStockStatusText(
                              medicine.status, medicine.stock ?? 0),
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: statusColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Edit Button
                  GestureDetector(
                    onTap: () => _showEditMedicineDialog(medicine),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.blue.withOpacity(0.3)),
                      ),
                      child: Icon(
                        Icons.edit,
                        color: Colors.blue,
                        size: 14,
                      ),
                    ),
                  ),
                  // Delete Button
                  GestureDetector(
                    onTap: () => _deleteMedicine(medicine),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.red.withOpacity(0.3)),
                      ),
                      child: Icon(
                        Icons.delete,
                        color: Colors.red,
                        size: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertCard(MedicineModel medicine) {
    final statusColor = _getStatusColor(medicine.status);
    final statusIcon = _getStatusIcon(medicine.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(statusIcon, color: statusColor, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  medicine.name,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: kPrimaryText,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${medicine.category ?? 'Unknown'} • ${medicine.status ?? 'In Stock'}',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: kSecondaryText,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Current Stock: ${medicine.stock ?? 0} units',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: statusColor,
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () {
              _showRestockDialog(medicine);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: statusColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Restock'),
          ),
        ],
      ),
    );
  }

  String _formatLastUpdated(dynamic lastUpdated) {
    if (lastUpdated == null) return 'Unknown';

    DateTime? dateTime;
    if (lastUpdated is DateTime) {
      dateTime = lastUpdated;
    } else if (lastUpdated is String) {
      dateTime = DateTime.tryParse(lastUpdated);
    }

    if (dateTime == null) return 'Unknown';

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
  }

  String _getStockStatusText(String? status, int stock) {
    if (stock <= 0) {
      return 'No Stock';
    } else if (status == 'Low Stock') {
      return 'Low Stock';
    } else if (status == 'In Stock') {
      return 'In Stock';
    } else {
      return 'Out of Stock';
    }
  }

  String _getMonthName(String month) {
    switch (month) {
      case '01':
        return 'January';
      case '02':
        return 'February';
      case '03':
        return 'March';
      case '04':
        return 'April';
      case '05':
        return 'May';
      case '06':
        return 'June';
      case '07':
        return 'July';
      case '08':
        return 'August';
      case '09':
        return 'September';
      case '10':
        return 'October';
      case '11':
        return 'November';
      case '12':
        return 'December';
      default:
        return month;
    }
  }

  String _getCategoryDisplayName(String category) {
    switch (category) {
      case 'prescription':
        return 'Prescription';
      case 'over-the-counter':
        return 'Over-the-counter';
      case 'supplement':
        return 'Supplement';
      case 'medical-device':
        return 'Medical Device';
      default:
        return category;
    }
  }

  String _getTypeDisplayName(String type) {
    switch (type) {
      case 'tablet':
        return 'Tablet';
      case 'syrup':
        return 'Syrup';
      case 'capsule':
        return 'Capsule';
      case 'injection':
        return 'Injection';
      case 'cream':
        return 'Cream';
      case 'ointment':
        return 'Ointment';
      case 'drops':
        return 'Drops';
      case 'inhaler':
        return 'Inhaler';
      case 'patch':
        return 'Patch';
      default:
        return type;
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
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String? status) {
    switch (status) {
      case 'In Stock':
        return Icons.check_circle;
      case 'Low Stock':
        return Icons.warning;
      case 'Out of Stock':
        return Icons.cancel;
      default:
        return Icons.help;
    }
  }

  void _showAddMedicineDialog() {
    // Navigate to full screen add medicine
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _AddMedicineScreen(
          onMedicineAdded: () async {
            await _loadMedicines();
            Navigator.pop(context);
          },
        ),
      ),
    );
  }

  void _showEditMedicineDialog(MedicineModel medicine) {
    showDialog(
      context: context,
      builder: (context) => _SimpleEditMedicineDialog(
        medicine: medicine,
        onMedicineUpdated: _loadMedicines,
      ),
    );
  }

  void _deleteMedicine(MedicineModel medicine) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Medicine'),
        content: Text('Are you sure you want to delete "${medicine.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final success =
            await ApiService.deletePharmacyMedicine(_pharmacyId!, medicine.id);
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Medicine deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
          await _loadMedicines();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to delete medicine'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting medicine: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showRestockDialog(MedicineModel medicine) {
    final quantityController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restock Medicine'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Medicine: ${medicine.name}'),
            const SizedBox(height: 16),
            TextField(
              controller: quantityController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Quantity to Add',
                border: OutlineInputBorder(),
              ),
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
              final quantity = int.tryParse(quantityController.text);
              if (quantity == null || quantity <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter a valid quantity'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              Navigator.pop(context);

              try {
                print('💊 Restocking medicine: ${medicine.name}');
                print('💊 Adding quantity: $quantity');
                print('💊 Current stock: ${medicine.stock}');
                print('💊 New stock: ${(medicine.stock ?? 0) + quantity}');

                final success = await ApiService.updatePharmacyMedicine(
                  _pharmacyId!,
                  medicine.id,
                  {
                    'stock': (medicine.stock ?? 0) + quantity,
                  },
                );

                print('💊 Restock response: $success');

                if (success['success'] == true) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content:
                          Text('Added $quantity units to ${medicine.name}'),
                      backgroundColor: Colors.green,
                    ),
                  );
                  await _loadMedicines();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Failed to restock medicine'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error restocking medicine: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('Restock'),
          ),
        ],
      ),
    );
  }
}

class _AddMedicineScreen extends StatefulWidget {
  final VoidCallback onMedicineAdded;

  const _AddMedicineScreen({required this.onMedicineAdded});

  @override
  State<_AddMedicineScreen> createState() => _AddMedicineScreenState();
}

class _AddMedicineScreenState extends State<_AddMedicineScreen> {
  final nameController = TextEditingController();
  final stockController = TextEditingController();
  final minStockController = TextEditingController();
  final maxStockController = TextEditingController();
  final unitPriceController = TextEditingController();
  final sellingPriceController = TextEditingController();
  final supplierController = TextEditingController();
  final batchNumberController = TextEditingController();
  final doseController = TextEditingController();
  final frequencyController = TextEditingController();

  String selectedCategory = 'prescription';
  String selectedType = 'tablet';
  String selectedFrequency = 'Once daily';
  String selectedExpiryMonth = '12';
  String selectedExpiryYear = '2025';
  bool isLoading = false;
  String? _pharmacyId;

  @override
  void initState() {
    super.initState();
    _loadPharmacyId();
  }

  @override
  void dispose() {
    nameController.dispose();
    stockController.dispose();
    minStockController.dispose();
    maxStockController.dispose();
    unitPriceController.dispose();
    sellingPriceController.dispose();
    supplierController.dispose();
    batchNumberController.dispose();
    doseController.dispose();
    frequencyController.dispose();
    super.dispose();
  }

  Future<void> _loadPharmacyId() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        _pharmacyId = user.uid;
      }
    } catch (e) {
      print('❌ Error loading pharmacy ID: $e');
    }
  }

  String _getCategoryDisplayName(String category) {
    switch (category) {
      case 'prescription':
        return 'Prescription';
      case 'over-the-counter':
        return 'Over the Counter';
      case 'supplement':
        return 'Supplement';
      case 'medical-device':
        return 'Medical Device';
      default:
        return category;
    }
  }

  String _getTypeDisplayName(String type) {
    switch (type) {
      case 'tablet':
        return 'Tablet';
      case 'capsule':
        return 'Capsule';
      case 'syrup':
        return 'Syrup';
      case 'injection':
        return 'Injection';
      case 'cream':
        return 'Cream';
      case 'drops':
        return 'Drops';
      default:
        return type;
    }
  }

  Future<void> _addMedicine() async {
    if (nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter medicine name'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final medicineData = {
        'name': nameController.text.trim(),
        'category': selectedCategory,
        'type': selectedType,
        'stock': int.tryParse(stockController.text.trim()) ?? 0,
        'minStock': int.tryParse(minStockController.text.trim()) ?? 0,
        'maxStock': int.tryParse(maxStockController.text.trim()) ?? 100,
        'unitPrice': double.tryParse(unitPriceController.text.trim()) ?? 0.0,
        'sellingPrice':
            double.tryParse(sellingPriceController.text.trim()) ?? 0.0,
        'supplier': supplierController.text.trim(),
        'batchNumber': batchNumberController.text.trim(),
        'expiryDate': '${selectedExpiryYear}-${selectedExpiryMonth}-01',
        'dose': doseController.text.trim(),
        'frequency': frequencyController.text.trim(),
      };

      final response = await ApiService.addPharmacyMedicine(
        _pharmacyId!,
        medicineData,
      );

      if (response['success'] == true) {
        // Generate QR code for the medicine
        final medicineId = response['data']['_id'];
        await _generateMedicineQRCode(medicineId, nameController.text.trim());

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Medicine added successfully with QR code!'),
            backgroundColor: Colors.green,
          ),
        );

        widget.onMedicineAdded();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to add medicine'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error adding medicine: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _generateMedicineQRCode(
      String medicineId, String medicineName) async {
    try {
      // Get the medicine data from the form
      final qrData = {
        'type': 'medicine',
        'medicineId': medicineId,
        'medicineName': medicineName,
        'genericName': nameController.text.trim(), // Using name as generic name
        'brand': nameController.text.trim(), // Using name as brand
        'category': selectedCategory,
        'medicineType': selectedType,
        'dosage': doseController.text.trim(),
        'strength': doseController.text.trim(), // Using dose as strength
        'composition': nameController.text.trim(), // Using name as composition
        'manufacturer':
            supplierController.text.trim(), // Using supplier as manufacturer
        'batchNumber': batchNumberController.text.trim(),
        'expiryDate': '${selectedExpiryMonth}/${selectedExpiryYear}',
        'unitPrice': double.tryParse(unitPriceController.text) ?? 0.0,
        'sellingPrice': double.tryParse(sellingPriceController.text) ?? 0.0,
        'stock': int.tryParse(stockController.text) ?? 0,
        'minStock': int.tryParse(minStockController.text) ?? 0,
        'maxStock': int.tryParse(maxStockController.text) ?? 0,
        'pharmacyId': _pharmacyId,
        'pharmacyName':
            'Current Pharmacy', // You can get this from pharmacy data
        'timestamp': DateTime.now().toIso8601String(),
      };

      print('🔍 Generating QR code for medicine: $medicineName');
      print('🔍 Medicine ID: $medicineId');
      print('🔍 Pharmacy ID: $_pharmacyId');
      print('🔍 QR Data: $qrData');

      print(
          '🔍 Calling ApiService.saveMedicineQRCode with medicineId: $medicineId');
      final success = await ApiService.saveMedicineQRCode(medicineId, qrData);
      print('🔍 ApiService.saveMedicineQRCode returned: $success');

      if (success) {
        print('✅ QR code generated successfully for medicine: $medicineName');
        print('✅ QR data saved: $qrData');
      } else {
        print('❌ Failed to generate QR code for medicine: $medicineName');
        print('❌ API call returned false');
      }
    } catch (e) {
      print('❌ Error generating QR code: $e');
      print('❌ Exception details: ${e.toString()}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.medication, color: Colors.green[600]),
            const SizedBox(width: 8),
            const Text('Add New Medicine'),
          ],
        ),
        backgroundColor: Colors.green[600],
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Medicine Name
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Medicine Name *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.medication),
              ),
            ),
            const SizedBox(height: 16),

            // Category and Type Row
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: selectedCategory,
                    decoration: const InputDecoration(
                      labelText: 'Category *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.category),
                    ),
                    items: [
                      'prescription',
                      'over-the-counter',
                      'supplement',
                      'medical-device',
                      'Pain Relief',
                      'Antibiotic',
                      'Diabetes',
                      'Cardiovascular',
                      'Gastrointestinal',
                      'Respiratory',
                      'Neurological'
                    ]
                        .map((category) => DropdownMenuItem(
                              value: category,
                              child: Text(_getCategoryDisplayName(category)),
                            ))
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        selectedCategory = value!;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: selectedType,
                    decoration: const InputDecoration(
                      labelText: 'Type *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.local_pharmacy),
                    ),
                    items: [
                      'tablet',
                      'syrup',
                      'capsule',
                      'injection',
                      'cream',
                      'ointment',
                      'drops',
                      'inhaler',
                      'patch'
                    ]
                        .map((type) => DropdownMenuItem(
                              value: type,
                              child: Text(_getTypeDisplayName(type)),
                            ))
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        selectedType = value!;
                      });
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Stock Information Row
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: stockController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Stock Quantity *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.inventory),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: minStockController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Min Stock',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.warning),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Price Information Row
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: unitPriceController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Unit Price (₹) *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.attach_money),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: sellingPriceController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Selling Price (₹) *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.sell),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Supplier and Batch Row
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: supplierController,
                    decoration: const InputDecoration(
                      labelText: 'Supplier',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.business),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: batchNumberController,
                    decoration: const InputDecoration(
                      labelText: 'Batch Number',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.grid_view),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Expiry Date Row
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: selectedExpiryMonth,
                    decoration: const InputDecoration(
                      labelText: 'Expiry Month *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.calendar_month),
                    ),
                    items: List.generate(12, (index) {
                      final month = (index + 1).toString().padLeft(2, '0');
                      return DropdownMenuItem(
                        value: month,
                        child: Text(_getMonthName(month)),
                      );
                    }),
                    onChanged: (value) {
                      setState(() {
                        selectedExpiryMonth = value!;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: selectedExpiryYear,
                    decoration: const InputDecoration(
                      labelText: 'Expiry Year *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.calendar_today),
                    ),
                    items: List.generate(10, (index) {
                      final year = (DateTime.now().year + index).toString();
                      return DropdownMenuItem(
                        value: year,
                        child: Text(year),
                      );
                    }),
                    onChanged: (value) {
                      setState(() {
                        selectedExpiryYear = value!;
                      });
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Dose and Frequency Row
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: doseController,
                    decoration: const InputDecoration(
                      labelText: 'Dose',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.medication),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: selectedFrequency,
                    decoration: const InputDecoration(
                      labelText: 'Frequency',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.schedule),
                    ),
                    items: [
                      'Once daily',
                      'Twice daily',
                      'Three times daily',
                      'Four times daily',
                      'As needed',
                      'Before meals',
                      'After meals',
                      'At bedtime'
                    ]
                        .map((frequency) => DropdownMenuItem(
                              value: frequency,
                              child: Text(frequency),
                            ))
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        selectedFrequency = value!;
                      });
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // Add Medicine Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: isLoading ? null : _addMedicine,
                icon: isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(Icons.add, size: 18),
                label: Text(isLoading ? 'Adding Medicine...' : 'Add Medicine'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[600],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getMonthName(String month) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ];
    return months[int.parse(month) - 1];
  }
}

class _SimpleEditMedicineDialog extends StatefulWidget {
  final MedicineModel medicine;
  final VoidCallback onMedicineUpdated;

  const _SimpleEditMedicineDialog({
    required this.medicine,
    required this.onMedicineUpdated,
  });

  @override
  State<_SimpleEditMedicineDialog> createState() =>
      _SimpleEditMedicineDialogState();
}

class _SimpleEditMedicineDialogState extends State<_SimpleEditMedicineDialog> {
  late TextEditingController _nameController;
  late TextEditingController _priceController;
  late TextEditingController _currentStockController;
  late TextEditingController _minStockController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.medicine.name);
    _priceController =
        TextEditingController(text: widget.medicine.sellingPrice.toString());
    _currentStockController =
        TextEditingController(text: widget.medicine.stock.toString());
    _minStockController =
        TextEditingController(text: widget.medicine.minStock.toString());
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _currentStockController.dispose();
    _minStockController.dispose();
    super.dispose();
  }

  Future<void> _updateMedicine() async {
    if (_nameController.text.isEmpty ||
        _priceController.text.isEmpty ||
        _currentStockController.text.isEmpty ||
        _minStockController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in all fields'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final updateData = {
        'name': _nameController.text.trim(),
        'sellingPrice': double.parse(_priceController.text),
        'stock': int.parse(_currentStockController.text),
        'minStock': int.parse(_minStockController.text),
      };

      print('💊 Updating medicine: ${widget.medicine.id}');
      print('💊 Update data: $updateData');

      final success = await ApiService.updatePharmacyMedicine(
        widget.medicine.pharmacyId ?? '',
        widget.medicine.id,
        updateData,
      );

      if (success['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Medicine updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
        widget.onMedicineUpdated();
        Navigator.pop(context);
      } else {
        throw Exception(success['error'] ?? 'Failed to update medicine');
      }
    } catch (e) {
      print('❌ Error updating medicine: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update medicine: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        'Edit Medicine',
        style: GoogleFonts.poppins(
          fontWeight: FontWeight.w600,
          color: const Color(0xFFE65100),
        ),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Medicine Name
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Medicine Name *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.medication),
              ),
            ),
            const SizedBox(height: 16),

            // Price
            TextField(
              controller: _priceController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Selling Price (₹) *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.currency_rupee),
              ),
            ),
            const SizedBox(height: 16),

            // Min Stock
            TextField(
              controller: _minStockController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Minimum Stock *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.inventory_2),
              ),
            ),
            const SizedBox(height: 16),

            // Current Stock
            TextField(
              controller: _currentStockController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Current Stock *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.inventory),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: Text(
            'Cancel',
            style: GoogleFonts.poppins(
              color: Colors.grey[600],
            ),
          ),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _updateMedicine,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFE65100),
            foregroundColor: Colors.white,
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Text(
                  'Update',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
                ),
        ),
      ],
    );
  }
}

class _EditMedicineScreen extends StatefulWidget {
  final MedicineModel medicine;
  final VoidCallback onMedicineUpdated;

  const _EditMedicineScreen({
    required this.medicine,
    required this.onMedicineUpdated,
  });

  @override
  State<_EditMedicineScreen> createState() => _EditMedicineScreenState();
}

class _EditMedicineScreenState extends State<_EditMedicineScreen> {
  final nameController = TextEditingController();
  final stockController = TextEditingController();
  final priceController = TextEditingController();
  final supplierController = TextEditingController();
  final batchController = TextEditingController();
  final doseController = TextEditingController();

  String? selectedCategory;
  String? selectedType;
  String? selectedExpiryMonth;
  String? selectedExpiryYear;
  String? selectedFrequency;
  bool isLoading = false;
  String? _pharmacyId;

  @override
  void initState() {
    super.initState();
    _initializeFields();
    _loadPharmacyId();
  }

  Future<void> _loadPharmacyId() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        _pharmacyId = user.uid;
      }
    } catch (e) {
      print('❌ Error loading pharmacy ID: $e');
    }
  }

  void _initializeFields() {
    nameController.text = widget.medicine.name;
    stockController.text = widget.medicine.stock.toString();
    priceController.text = widget.medicine.unitPrice?.toString() ?? '0';
    supplierController.text = widget.medicine.supplier ?? '';
    batchController.text = widget.medicine.batchNumber ?? '';
    doseController.text = widget.medicine.dose;

    // Ensure selectedCategory is valid for dropdown
    final validCategories = [
      'prescription',
      'over-the-counter',
      'supplement',
      'medical-device',
      'Pain Relief',
      'Antibiotic',
      'Diabetes',
      'Cardiovascular',
      'Gastrointestinal',
      'Respiratory',
      'Neurological',
      'Other'
    ];

    selectedCategory = validCategories.contains(widget.medicine.category)
        ? widget.medicine.category
        : 'prescription'; // Default fallback

    print(
        '🔍 Edit Medicine - Initialized selectedCategory: "$selectedCategory"');
    print(
        '🔍 Edit Medicine - Medicine category: "${widget.medicine.category}"');
    print('🔍 Edit Medicine - Valid categories: $validCategories');

    selectedType = widget.medicine.type;
    selectedFrequency = widget.medicine.frequency;

    // Parse expiry date
    if (widget.medicine.expiryDate != null) {
      final expiry = DateTime.parse(widget.medicine.expiryDate!);
      selectedExpiryMonth = expiry.month.toString();
      selectedExpiryYear = expiry.year.toString();
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    stockController.dispose();
    priceController.dispose();
    supplierController.dispose();
    batchController.dispose();
    doseController.dispose();
    super.dispose();
  }

  Future<void> _updateMedicine() async {
    if (nameController.text.isEmpty ||
        stockController.text.isEmpty ||
        priceController.text.isEmpty ||
        selectedCategory == null ||
        selectedType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill all required fields'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      final updateData = {
        'name': nameController.text.trim(),
        'stock': int.parse(stockController.text),
        'unitPrice': double.parse(priceController.text),
        'category': selectedCategory!,
        'type': selectedType!,
        'supplier': supplierController.text.trim(),
        'batchNumber': batchController.text.trim(),
        'dose': doseController.text.trim(),
        'frequency': selectedFrequency ?? '',
        'expiryDate': selectedExpiryMonth != null && selectedExpiryYear != null
            ? DateTime(
                int.parse(selectedExpiryYear!), int.parse(selectedExpiryMonth!))
            : null,
      };

      print('💊 Updating medicine: ${widget.medicine.name}');
      print('💊 Pharmacy ID: $_pharmacyId');
      print('💊 Medicine ID: ${widget.medicine.id}');
      print('💊 Update data: $updateData');

      final success = await ApiService.updatePharmacyMedicine(
        _pharmacyId!,
        widget.medicine.id,
        updateData,
      );

      print('💊 Update response: $success');

      if (success['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Medicine updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
        widget.onMedicineUpdated();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to update medicine'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating medicine: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.edit, color: Colors.green[600]),
            const SizedBox(width: 8),
            const Text('Edit Medicine'),
          ],
        ),
        backgroundColor: Colors.green[600],
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Medicine Name
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Medicine Name *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.medication),
              ),
            ),
            const SizedBox(height: 16),

            // Category and Type Row
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: selectedCategory,
                    decoration: const InputDecoration(
                      labelText: 'Category *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.category),
                    ),
                    items: const [
                      DropdownMenuItem<String>(
                          value: 'prescription', child: Text('Prescription')),
                      DropdownMenuItem<String>(
                          value: 'over-the-counter',
                          child: Text('Over-the-counter')),
                      DropdownMenuItem<String>(
                          value: 'supplement', child: Text('Supplement')),
                      DropdownMenuItem<String>(
                          value: 'medical-device',
                          child: Text('Medical Device')),
                      DropdownMenuItem<String>(
                          value: 'Pain Relief', child: Text('Pain Relief')),
                      DropdownMenuItem<String>(
                          value: 'Antibiotic', child: Text('Antibiotic')),
                      DropdownMenuItem<String>(
                          value: 'Diabetes', child: Text('Diabetes')),
                      DropdownMenuItem<String>(
                          value: 'Cardiovascular',
                          child: Text('Cardiovascular')),
                      DropdownMenuItem<String>(
                          value: 'Gastrointestinal',
                          child: Text('Gastrointestinal')),
                      DropdownMenuItem<String>(
                          value: 'Respiratory', child: Text('Respiratory')),
                      DropdownMenuItem<String>(
                          value: 'Neurological', child: Text('Neurological')),
                      DropdownMenuItem<String>(
                          value: 'Other', child: Text('Other')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          selectedCategory = value;
                        });
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: selectedType,
                    decoration: const InputDecoration(
                      labelText: 'Type *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.medication_liquid),
                    ),
                    items: [
                      'tablet',
                      'syrup',
                      'capsule',
                      'injection',
                      'cream',
                      'ointment',
                      'drops',
                      'inhaler',
                      'patch'
                    ]
                        .map((type) => DropdownMenuItem(
                              value: type,
                              child: Text(type),
                            ))
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        selectedType = value;
                      });
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Stock and Price Row
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: stockController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Stock *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.inventory),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: priceController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Price (₹) *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.currency_rupee),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Dose and Frequency Row
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: doseController,
                    decoration: const InputDecoration(
                      labelText: 'Dose',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.science),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: selectedFrequency,
                    decoration: const InputDecoration(
                      labelText: 'Frequency',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.schedule),
                    ),
                    items: [
                      'Once daily',
                      'Twice daily',
                      'Three times daily',
                      'Four times daily',
                      'As needed',
                      'At bedtime'
                    ]
                        .map((frequency) => DropdownMenuItem(
                              value: frequency,
                              child: Text(frequency),
                            ))
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        selectedFrequency = value;
                      });
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Supplier and Batch Row
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: supplierController,
                    decoration: const InputDecoration(
                      labelText: 'Supplier',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.business),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: batchController,
                    decoration: const InputDecoration(
                      labelText: 'Batch Number',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.qr_code),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Expiry Date Row
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: selectedExpiryMonth,
                    decoration: const InputDecoration(
                      labelText: 'Expiry Month',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.calendar_today),
                    ),
                    items: List.generate(12, (index) {
                      final month = (index + 1).toString();
                      return DropdownMenuItem(
                        value: month,
                        child: Text(_getMonthName(month)),
                      );
                    }),
                    onChanged: (value) {
                      setState(() {
                        selectedExpiryMonth = value;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: selectedExpiryYear,
                    decoration: const InputDecoration(
                      labelText: 'Expiry Year',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.calendar_today),
                    ),
                    items: List.generate(10, (index) {
                      final year = (DateTime.now().year + index).toString();
                      return DropdownMenuItem(
                        value: year,
                        child: Text(year),
                      );
                    }),
                    onChanged: (value) {
                      setState(() {
                        selectedExpiryYear = value;
                      });
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // Update Medicine Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: isLoading ? null : _updateMedicine,
                icon: isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(Icons.save, size: 18),
                label: Text(
                    isLoading ? 'Updating Medicine...' : 'Update Medicine'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[600],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getMonthName(String month) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ];
    return months[int.parse(month) - 1];
  }
}
