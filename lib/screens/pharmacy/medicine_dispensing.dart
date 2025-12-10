import 'package:flutter/material.dart';
import '../../utils/user_type_enum.dart';
import '../../widgets/custom_button.dart';

class MedicineDispensing extends StatefulWidget {
  const MedicineDispensing({Key? key}) : super(key: key);

  @override
  State<MedicineDispensing> createState() => _MedicineDispensingState();
}

class _MedicineDispensingState extends State<MedicineDispensing> {
  List<Map<String, dynamic>> pendingDispensing = [];
  List<Map<String, dynamic>> completedDispensing = [];

  @override
  void initState() {
    super.initState();
    _loadDispensingData();
  }

  void _loadDispensingData() {
    // Mock data
    setState(() {
      pendingDispensing = [
        {
          'id': '1',
          'patientName': 'John Doe',
          'healthId': 'HEALTH_QR_123456789',
          'medicines': ['Paracetamol 500mg', 'Amoxicillin 250mg'],
          'prescribedBy': 'Dr. Sarah Johnson',
          'prescriptionDate': '2024-01-15',
          'status': 'Pending',
          'totalAmount': 17.0,
        },
        {
          'id': '2',
          'patientName': 'Jane Smith',
          'healthId': 'HEALTH_QR_987654321',
          'medicines': ['Omeprazole 20mg', 'Vitamin C 500mg'],
          'prescribedBy': 'Dr. Michael Brown',
          'prescriptionDate': '2024-01-14',
          'status': 'Pending',
          'totalAmount': 12.0,
        },
        {
          'id': '3',
          'patientName': 'Mike Johnson',
          'healthId': 'HEALTH_QR_456789123',
          'medicines': ['Cetirizine 10mg'],
          'prescribedBy': 'Dr. Emily Davis',
          'prescriptionDate': '2024-01-13',
          'status': 'Pending',
          'totalAmount': 6.0,
        },
      ];

      completedDispensing = [
        {
          'id': '4',
          'patientName': 'Sarah Wilson',
          'healthId': 'HEALTH_QR_789123456',
          'medicines': ['Paracetamol 500mg'],
          'prescribedBy': 'Dr. Robert Wilson',
          'prescriptionDate': '2024-01-12',
          'dispensedDate': '2024-01-12',
          'status': 'Completed',
          'totalAmount': 5.0,
        },
      ];
    });
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Medicine Dispensing'),
          backgroundColor: UserType.pharmacy.color,
          foregroundColor: Colors.white,
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Pending', icon: Icon(Icons.pending)),
              Tab(text: 'Completed', icon: Icon(Icons.check_circle)),
            ],
            indicatorColor: Colors.white,
          ),
        ),
        body: TabBarView(
          children: [
            _buildPendingDispensing(),
            _buildCompletedDispensing(),
          ],
        ),
      ),
    );
  }

  Widget _buildPendingDispensing() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: pendingDispensing.length,
      itemBuilder: (context, index) {
        final item = pendingDispensing[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ExpansionTile(
            leading: CircleAvatar(
              backgroundColor: Colors.orange.withOpacity(0.2),
              child: const Icon(Icons.pending, color: Colors.orange),
            ),
            title: Text(
              item['patientName'],
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text('Health ID: ${item['healthId']}'),
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDetailRow('Prescribed By', item['prescribedBy']),
                    _buildDetailRow(
                        'Prescription Date', item['prescriptionDate']),
                    _buildDetailRow('Total Amount', '\$${item['totalAmount']}'),
                    const SizedBox(height: 8),
                    const Text(
                      'Medicines:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    ...item['medicines']
                        .map<Widget>((medicine) => Padding(
                              padding:
                                  const EdgeInsets.only(left: 16, bottom: 2),
                              child: Row(
                                children: [
                                  const Icon(Icons.medication, size: 16),
                                  const SizedBox(width: 8),
                                  Text(medicine),
                                ],
                              ),
                            ))
                        .toList(),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: CustomButton(
                            text: 'Dispense',
                            onPressed: () => _dispenseMedicine(item),
                            color: Colors.green,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: CustomButton(
                            text: 'Notify Patient',
                            onPressed: () => _notifyPatient(item),
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCompletedDispensing() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: completedDispensing.length,
      itemBuilder: (context, index) {
        final item = completedDispensing[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ExpansionTile(
            leading: CircleAvatar(
              backgroundColor: Colors.green.withOpacity(0.2),
              child: const Icon(Icons.check_circle, color: Colors.green),
            ),
            title: Text(
              item['patientName'],
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text('Dispensed on ${item['dispensedDate']}'),
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDetailRow('Prescribed By', item['prescribedBy']),
                    _buildDetailRow(
                        'Prescription Date', item['prescriptionDate']),
                    _buildDetailRow('Dispensed Date', item['dispensedDate']),
                    _buildDetailRow('Total Amount', '\$${item['totalAmount']}'),
                    const SizedBox(height: 8),
                    const Text(
                      'Medicines:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    ...item['medicines']
                        .map<Widget>((medicine) => Padding(
                              padding:
                                  const EdgeInsets.only(left: 16, bottom: 2),
                              child: Row(
                                children: [
                                  const Icon(Icons.medication, size: 16),
                                  const SizedBox(width: 8),
                                  Text(medicine),
                                ],
                              ),
                            ))
                        .toList(),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  void _dispenseMedicine(Map<String, dynamic> item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Dispense Medicine'),
        content: Text(
            'Are you sure you want to dispense medicine for ${item['patientName']}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _confirmDispensing(item);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  void _confirmDispensing(Map<String, dynamic> item) {
    setState(() {
      // Move from pending to completed
      pendingDispensing.removeWhere((element) => element['id'] == item['id']);

      final completedItem = Map<String, dynamic>.from(item);
      completedItem['status'] = 'Completed';
      completedItem['dispensedDate'] = DateTime.now().toString().split(' ')[0];

      completedDispensing.add(completedItem);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Medicine dispensed for ${item['patientName']}!'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _notifyPatient(Map<String, dynamic> item) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Notification sent to ${item['patientName']}!'),
        backgroundColor: Colors.blue,
      ),
    );
  }
}
