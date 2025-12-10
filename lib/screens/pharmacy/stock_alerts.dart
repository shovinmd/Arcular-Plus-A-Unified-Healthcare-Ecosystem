import 'package:flutter/material.dart';
import '../../utils/user_type_enum.dart';
import '../../widgets/custom_button.dart';

class StockAlerts extends StatefulWidget {
  const StockAlerts({Key? key}) : super(key: key);

  @override
  State<StockAlerts> createState() => _StockAlertsState();
}

class _StockAlertsState extends State<StockAlerts> {
  List<Map<String, dynamic>> lowStockAlerts = [];
  List<Map<String, dynamic>> expiryAlerts = [];
  List<Map<String, dynamic>> refillAlerts = [];
  String selectedAlertType = 'All';

  @override
  void initState() {
    super.initState();
    _loadAlerts();
  }

  void _loadAlerts() {
    // Mock alert data
    setState(() {
      lowStockAlerts = [
        {
          'id': '1',
          'medicine': 'Paracetamol 500mg',
          'currentStock': 15,
          'minStock': 50,
          'category': 'Pain Relief',
          'priority': 'High',
          'lastUpdated': '2024-01-15',
        },
        {
          'id': '2',
          'medicine': 'Amoxicillin 250mg',
          'currentStock': 8,
          'minStock': 30,
          'category': 'Antibiotic',
          'priority': 'Critical',
          'lastUpdated': '2024-01-14',
        },
        {
          'id': '3',
          'medicine': 'Cetirizine 10mg',
          'currentStock': 25,
          'minStock': 40,
          'category': 'Allergy',
          'priority': 'Medium',
          'lastUpdated': '2024-01-13',
        },
      ];

      expiryAlerts = [
        {
          'id': '4',
          'medicine': 'Vitamin C 500mg',
          'expiryDate': '2024-02-15',
          'currentStock': 45,
          'category': 'Vitamins',
          'daysUntilExpiry': 31,
          'priority': 'Medium',
        },
        {
          'id': '5',
          'medicine': 'Omeprazole 20mg',
          'expiryDate': '2024-01-30',
          'currentStock': 120,
          'category': 'Gastric',
          'daysUntilExpiry': 15,
          'priority': 'High',
        },
      ];

      refillAlerts = [
        {
          'id': '6',
          'patientName': 'John Doe',
          'medicine': 'Paracetamol 500mg',
          'refillDate': '2024-01-20',
          'quantity': 30,
          'status': 'Pending',
          'priority': 'Medium',
        },
        {
          'id': '7',
          'patientName': 'Jane Smith',
          'medicine': 'Amoxicillin 250mg',
          'refillDate': '2024-01-18',
          'quantity': 20,
          'status': 'Pending',
          'priority': 'High',
        },
      ];
    });
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Stock Alerts'),
          backgroundColor: UserType.pharmacy.color,
          foregroundColor: Colors.white,
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Low Stock', icon: Icon(Icons.warning)),
              Tab(text: 'Expiry', icon: Icon(Icons.schedule)),
              Tab(text: 'Refill', icon: Icon(Icons.refresh)),
            ],
            indicatorColor: Colors.white,
          ),
        ),
        body: TabBarView(
          children: [
            _buildLowStockAlerts(),
            _buildExpiryAlerts(),
            _buildRefillAlerts(),
          ],
        ),
      ),
    );
  }

  Widget _buildLowStockAlerts() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: lowStockAlerts.length,
      itemBuilder: (context, index) {
        final alert = lowStockAlerts[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: _getPriorityColor(alert['priority']).withOpacity(0.2),
              child: Icon(
                Icons.warning,
                color: _getPriorityColor(alert['priority']),
              ),
            ),
            title: Text(
              alert['medicine'],
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Current Stock: ${alert['currentStock']} | Min Stock: ${alert['minStock']}'),
                Text('Category: ${alert['category']}'),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: _getPriorityColor(alert['priority']).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    alert['priority'],
                    style: TextStyle(
                      color: _getPriorityColor(alert['priority']),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            trailing: PopupMenuButton(
                             itemBuilder: (context) => [
                 const PopupMenuItem(
                   value: 'restock',
                   child: Row(
                     children: [
                       Icon(Icons.add_shopping_cart),
                       SizedBox(width: 8),
                       Text('Restock'),
                     ],
                   ),
                 ),
                 const PopupMenuItem(
                   value: 'ignore',
                   child: Row(
                     children: [
                       Icon(Icons.cancel),
                       SizedBox(width: 8),
                       Text('Ignore'),
                     ],
                   ),
                 ),
               ],
              onSelected: (value) {
                switch (value) {
                  case 'restock':
                    _showRestockDialog(alert);
                    break;
                  case 'ignore':
                    _ignoreAlert(alert['id'], 'lowStock');
                    break;
                }
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildExpiryAlerts() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: expiryAlerts.length,
      itemBuilder: (context, index) {
        final alert = expiryAlerts[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: _getPriorityColor(alert['priority']).withOpacity(0.2),
              child: Icon(
                Icons.schedule,
                color: _getPriorityColor(alert['priority']),
              ),
            ),
            title: Text(
              alert['medicine'],
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Expiry Date: ${alert['expiryDate']}'),
                Text('Days Until Expiry: ${alert['daysUntilExpiry']}'),
                Text('Current Stock: ${alert['currentStock']}'),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: _getPriorityColor(alert['priority']).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    alert['priority'],
                    style: TextStyle(
                      color: _getPriorityColor(alert['priority']),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            trailing: PopupMenuButton(
                             itemBuilder: (context) => [
                 const PopupMenuItem(
                   value: 'discount',
                   child: Row(
                     children: [
                       Icon(Icons.local_offer),
                       SizedBox(width: 8),
                       Text('Apply Discount'),
                     ],
                   ),
                 ),
                 const PopupMenuItem(
                   value: 'return',
                   child: Row(
                     children: [
                       Icon(Icons.assignment_return),
                       SizedBox(width: 8),
                       Text('Return to Supplier'),
                     ],
                   ),
                 ),
                 const PopupMenuItem(
                   value: 'ignore',
                   child: Row(
                     children: [
                       Icon(Icons.cancel),
                       SizedBox(width: 8),
                       Text('Ignore'),
                     ],
                   ),
                 ),
               ],
              onSelected: (value) {
                switch (value) {
                  case 'discount':
                    _showDiscountDialog(alert);
                    break;
                  case 'return':
                    _returnToSupplier(alert);
                    break;
                  case 'ignore':
                    _ignoreAlert(alert['id'], 'expiry');
                    break;
                }
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildRefillAlerts() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: refillAlerts.length,
      itemBuilder: (context, index) {
        final alert = refillAlerts[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: _getPriorityColor(alert['priority']).withOpacity(0.2),
              child: Icon(
                Icons.refresh,
                color: _getPriorityColor(alert['priority']),
              ),
            ),
            title: Text(
              alert['patientName'],
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Medicine: ${alert['medicine']}'),
                Text('Refill Date: ${alert['refillDate']}'),
                Text('Quantity: ${alert['quantity']}'),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: _getPriorityColor(alert['priority']).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    alert['priority'],
                    style: TextStyle(
                      color: _getPriorityColor(alert['priority']),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            trailing: PopupMenuButton(
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'notify',
                  child: Row(
                    children: [
                      Icon(Icons.notifications),
                      SizedBox(width: 8),
                      Text('Notify Patient'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'prepare',
                  child: Row(
                    children: [
                      Icon(Icons.medication),
                      SizedBox(width: 8),
                      Text('Prepare Refill'),
                    ],
                  ),
                ),
                                 const PopupMenuItem(
                   value: 'ignore',
                   child: Row(
                     children: [
                       Icon(Icons.cancel),
                       SizedBox(width: 8),
                       Text('Ignore'),
                     ],
                   ),
                 ),
              ],
              onSelected: (value) {
                switch (value) {
                  case 'notify':
                    _notifyPatient(alert);
                    break;
                  case 'prepare':
                    _prepareRefill(alert);
                    break;
                  case 'ignore':
                    _ignoreAlert(alert['id'], 'refill');
                    break;
                }
              },
            ),
          ),
        );
      },
    );
  }

  Color _getPriorityColor(String priority) {
    switch (priority) {
      case 'Critical':
        return Colors.red;
      case 'High':
        return Colors.orange;
      case 'Medium':
        return Colors.yellow[700]!;
      case 'Low':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  void _showRestockDialog(Map<String, dynamic> alert) {
    final quantityController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Restock ${alert['medicine']}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Current stock: ${alert['currentStock']}'),
            Text('Minimum required: ${alert['minStock']}'),
            const SizedBox(height: 16),
            TextField(
              controller: quantityController,
              decoration: const InputDecoration(
                labelText: 'Quantity to order',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final quantity = int.tryParse(quantityController.text) ?? 0;
              _placeRestockOrder(alert, quantity);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Order'),
          ),
        ],
      ),
    );
  }

  void _showDiscountDialog(Map<String, dynamic> alert) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Apply Discount for ${alert['medicine']}'),
        content: Text('This medicine expires in ${alert['daysUntilExpiry']} days. Apply discount to clear stock?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              _applyDiscount(alert);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('Apply 20% Discount'),
          ),
        ],
      ),
    );
  }

  void _placeRestockOrder(Map<String, dynamic> alert, int quantity) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Restock order placed for ${alert['medicine']} (${quantity} units)'),
        backgroundColor: Colors.green,
      ),
    );
    
    // Remove alert from list
    setState(() {
      lowStockAlerts.removeWhere((item) => item['id'] == alert['id']);
    });
  }

  void _applyDiscount(Map<String, dynamic> alert) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('20% discount applied to ${alert['medicine']}'),
        backgroundColor: Colors.orange,
      ),
    );
    
    // Remove alert from list
    setState(() {
      expiryAlerts.removeWhere((item) => item['id'] == alert['id']);
    });
  }

  void _returnToSupplier(Map<String, dynamic> alert) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Return request sent to supplier for ${alert['medicine']}'),
        backgroundColor: Colors.blue,
      ),
    );
    
    // Remove alert from list
    setState(() {
      expiryAlerts.removeWhere((item) => item['id'] == alert['id']);
    });
  }

  void _notifyPatient(Map<String, dynamic> alert) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Refill reminder sent to ${alert['patientName']}'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  void _prepareRefill(Map<String, dynamic> alert) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Refill prepared for ${alert['patientName']}'),
        backgroundColor: Colors.green,
      ),
    );
    
    // Remove alert from list
    setState(() {
      refillAlerts.removeWhere((item) => item['id'] == alert['id']);
    });
  }

  void _ignoreAlert(String id, String type) {
    setState(() {
      switch (type) {
        case 'lowStock':
          lowStockAlerts.removeWhere((item) => item['id'] == id);
          break;
        case 'expiry':
          expiryAlerts.removeWhere((item) => item['id'] == id);
          break;
        case 'refill':
          refillAlerts.removeWhere((item) => item['id'] == id);
          break;
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Alert ignored'),
        backgroundColor: Colors.grey,
      ),
    );
  }
} 