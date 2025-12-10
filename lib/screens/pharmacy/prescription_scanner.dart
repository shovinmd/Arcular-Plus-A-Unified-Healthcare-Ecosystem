import 'package:flutter/material.dart';
import '../../utils/user_type_enum.dart';
import '../../widgets/custom_button.dart';
import '../universal_qr_scanner_screen.dart';

class PrescriptionScanner extends StatefulWidget {
  const PrescriptionScanner({Key? key}) : super(key: key);

  @override
  State<PrescriptionScanner> createState() => _PrescriptionScannerState();
}

class _PrescriptionScannerState extends State<PrescriptionScanner> {
  bool isScanning = false;
  String scannedData = '';
  Map<String, dynamic>? prescriptionDetails;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Prescription'),
        backgroundColor: UserType.pharmacy.color,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildScannerSection(),
            const SizedBox(height: 20),
            if (prescriptionDetails != null) _buildPrescriptionDetails(),
          ],
        ),
      ),
    );
  }

  Widget _buildScannerSection() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(
              Icons.qr_code_scanner,
              size: 80,
              color: UserType.pharmacy.color,
            ),
            const SizedBox(height: 16),
            const Text(
              'Scan Prescription QR Code',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Point camera at the prescription QR code to scan and retrieve patient details',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 20),
            Container(
              height: 200,
              decoration: BoxDecoration(
                border: Border.all(color: UserType.pharmacy.color, width: 2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: isScanning
                    ? Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircularProgressIndicator(
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                              SizedBox(height: 16),
                              Text(
                                'Scanning...',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.qr_code,
                            size: 60,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'QR Code Scanner',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 20),
            CustomButton(
              text: 'Scan QR Code',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const UniversalQRScannerScreen()),
                );
              },
              color: UserType.pharmacy.color,
            ),
            const SizedBox(height: 16),
            CustomButton(
              text: 'Simulate Scan',
              onPressed: () => _simulateScan(),
              color: Colors.green,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrescriptionDetails() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.description,
                  color: UserType.pharmacy.color,
                  size: 24,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Prescription Details',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildDetailRow(
                'Patient Name', prescriptionDetails!['patientName']),
            _buildDetailRow('Health ID', prescriptionDetails!['healthId']),
            _buildDetailRow('Doctor Name', prescriptionDetails!['doctorName']),
            _buildDetailRow('Date', prescriptionDetails!['date']),
            _buildDetailRow('Medicines', prescriptionDetails!['medicines']),
            _buildDetailRow(
                'Instructions', prescriptionDetails!['instructions']),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: CustomButton(
                    text: 'Dispense Medicine',
                    onPressed: () => _dispenseMedicine(),
                    color: Colors.green,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: CustomButton(
                    text: 'Notify Patient',
                    onPressed: () => _notifyPatient(),
                    color: Colors.blue,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
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

  void _toggleScanning() {
    setState(() {
      isScanning = !isScanning;
    });
  }

  void _simulateScan() {
    setState(() {
      isScanning = true;
    });

    // Simulate scanning delay
    Future.delayed(const Duration(seconds: 2), () {
      setState(() {
        isScanning = false;
        scannedData = 'HEALTH_QR_123456789';
        prescriptionDetails = {
          'patientName': 'John Doe',
          'healthId': 'HEALTH_QR_123456789',
          'doctorName': 'Dr. Sarah Johnson',
          'date': '2024-01-15',
          'medicines': 'Paracetamol 500mg, Amoxicillin 250mg, Vitamin C',
          'instructions':
              'Take Paracetamol 3 times daily, Amoxicillin 2 times daily with food',
        };
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Prescription scanned successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    });
  }

  void _dispenseMedicine() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Dispense Medicine'),
        content: const Text(
            'Are you sure you want to mark this prescription as dispensed?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _markAsDispensed();
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

  void _markAsDispensed() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Medicine dispensed successfully! Patient notified.'),
        backgroundColor: Colors.green,
      ),
    );

    // Navigate back to dashboard
    Navigator.pop(context);
  }

  void _notifyPatient() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Notification sent to patient!'),
        backgroundColor: Colors.blue,
      ),
    );
  }
}
