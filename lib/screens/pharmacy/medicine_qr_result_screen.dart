import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MedicineQRResultScreen extends StatefulWidget {
  final Map<String, dynamic> medicineData;
  final bool isUserMode;

  const MedicineQRResultScreen({
    Key? key,
    required this.medicineData,
    this.isUserMode = false,
  }) : super(key: key);

  @override
  State<MedicineQRResultScreen> createState() => _MedicineQRResultScreenState();
}

class _MedicineQRResultScreenState extends State<MedicineQRResultScreen> {
  String? pharmacyName;
  bool isLoadingPharmacy = true;

  @override
  void initState() {
    super.initState();
    _loadPharmacyName();
  }

  Future<void> _loadPharmacyName() async {
    try {
      // Try to get pharmacy name from medicine data first
      String? name = widget.medicineData['pharmacyName'];

      if (name != null && name.isNotEmpty) {
        setState(() {
          pharmacyName = name;
          isLoadingPharmacy = false;
        });
        return;
      }

      // If no pharmacy name in data, check if it's current user's pharmacy
      final pharmacyId = widget.medicineData['pharmacyId'];
      if (pharmacyId != null) {
        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser != null && currentUser.uid == pharmacyId) {
          setState(() {
            pharmacyName = 'Current Pharmacy';
            isLoadingPharmacy = false;
          });
        } else {
          setState(() {
            pharmacyName = 'External Pharmacy';
            isLoadingPharmacy = false;
          });
        }
      } else {
        setState(() {
          pharmacyName = 'Unknown Pharmacy';
          isLoadingPharmacy = false;
        });
      }
    } catch (e) {
      setState(() {
        pharmacyName = 'Current Pharmacy';
        isLoadingPharmacy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          'Medicine Details',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFFE65100),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Medicine Header Card
            _buildMedicineHeaderCard(),
            const SizedBox(height: 16),

            // Basic Information Card
            _buildBasicInfoCard(),
            const SizedBox(height: 16),

            // Medical Information Card
            _buildMedicalInfoCard(),
            const SizedBox(height: 16),

            // Pricing & Stock Card (only show for pharmacy, not for users)
            if (!widget.isUserMode) ...[
              _buildPricingStockCard(),
              const SizedBox(height: 16),
            ],

            // Pharmacy Information Card
            _buildPharmacyInfoCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildMedicineHeaderCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: const LinearGradient(
            colors: [Color(0xFFE65100), Color(0xFFF57C00)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.medication,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.medicineData['medicineName'] ??
                            'Unknown Medicine',
                        style: GoogleFonts.poppins(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Medicine ID: ${widget.medicineData['medicineId'] ?? 'N/A'}',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBasicInfoCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Basic Information',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: const Color(0xFFE65100),
              ),
            ),
            const SizedBox(height: 16),
            _buildInfoRow('Brand', widget.medicineData['brand'] ?? 'N/A'),
            _buildInfoRow('Category', widget.medicineData['category'] ?? 'N/A'),
            _buildInfoRow('Type', widget.medicineData['medicineType'] ?? 'N/A'),
            _buildInfoRow(
                'Manufacturer', widget.medicineData['manufacturer'] ?? 'N/A'),
          ],
        ),
      ),
    );
  }

  Widget _buildMedicalInfoCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Medical Information',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: const Color(0xFFE65100),
              ),
            ),
            const SizedBox(height: 16),
            _buildInfoRow('Dosage', widget.medicineData['dosage'] ?? 'N/A'),
            _buildInfoRow('Strength', widget.medicineData['strength'] ?? 'N/A'),
            _buildInfoRow(
                'Batch Number', widget.medicineData['batchNumber'] ?? 'N/A'),
            _buildInfoRow(
                'Expiry Date', widget.medicineData['expiryDate'] ?? 'N/A'),
          ],
        ),
      ),
    );
  }

  Widget _buildPricingStockCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pricing & Stock',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: const Color(0xFFE65100),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildInfoRow('Unit Price',
                      '₹${widget.medicineData['unitPrice'] ?? 'N/A'}'),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildInfoRow('Selling Price',
                      '₹${widget.medicineData['sellingPrice'] ?? 'N/A'}'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildInfoRow('Current Stock',
                      '${widget.medicineData['stock'] ?? 'N/A'}'),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildInfoRow('Min Stock',
                      '${widget.medicineData['minStock'] ?? 'N/A'}'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildInfoRow(
                'Max Stock', '${widget.medicineData['maxStock'] ?? 'N/A'}'),
          ],
        ),
      ),
    );
  }

  Widget _buildPharmacyInfoCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pharmacy Information',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: const Color(0xFFE65100),
              ),
            ),
            const SizedBox(height: 16),
            _buildInfoRow('Pharmacy Name', pharmacyName ?? 'Loading...'),
            _buildInfoRow(
                'Pharmacy ID', widget.medicineData['pharmacyId'] ?? 'N/A'),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey[800],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
