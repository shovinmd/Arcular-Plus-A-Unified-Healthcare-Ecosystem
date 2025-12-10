import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:arcular_plus/services/api_service.dart';
import 'package:arcular_plus/widgets/chatarc_floating_button.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'dart:convert';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'medicine_qr_result_screen.dart';

class QRMedicineScannerScreen extends StatefulWidget {
  final bool isUserMode;

  const QRMedicineScannerScreen({
    Key? key,
    this.isUserMode = false,
  }) : super(key: key);

  @override
  State<QRMedicineScannerScreen> createState() =>
      _QRMedicineScannerScreenState();
}

class _QRMedicineScannerScreenState extends State<QRMedicineScannerScreen>
    with TickerProviderStateMixin {
  String? scannedData;
  bool isScanning = true;
  bool isLoading = false;
  List<Map<String, dynamic>> medicinesWithQR = [];
  List<Map<String, dynamic>> filteredMedicines = [];
  final TextEditingController _searchController = TextEditingController();
  late TabController _tabController;
  MobileScannerController? _scannerController;

  @override
  void initState() {
    super.initState();
    // Show only 1 tab for users, 2 tabs for pharmacy
    _tabController =
        TabController(length: widget.isUserMode ? 1 : 2, vsync: this);

    // Only load medicines with QR for pharmacy users
    if (!widget.isUserMode) {
      _loadMedicinesWithQR();
      _searchController.addListener(_filterMedicines);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    _scannerController?.dispose();
    super.dispose();
  }

  Future<void> _loadMedicinesWithQR() async {
    try {
      setState(() => isLoading = true);
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      print('💊 Loading medicines with QR codes for pharmacy: ${user.uid}');
      final response = await ApiService.getPharmacyMedicines(user.uid);

      print('💊 Full response: $response');

      if (response['data'] != null) {
        final medicines = List<Map<String, dynamic>>.from(response['data']);
        print('💊 Total medicines loaded: ${medicines.length}');

        // Debug each medicine's QR code status
        for (int i = 0; i < medicines.length; i++) {
          final medicine = medicines[i];
          print(
              '💊 Medicine $i: ${medicine['name']} - QR Data: ${medicine['qrCodeData']} - QR Generated At: ${medicine['qrCodeGeneratedAt']}');
        }

        // Filter medicines that have QR codes
        final medicinesWithQRCodes = medicines.where((medicine) {
          final hasQRData = medicine['qrCodeData'] != null &&
              medicine['qrCodeData'].toString().isNotEmpty;
          print('💊 Medicine ${medicine['name']} has QR data: $hasQRData');
          return hasQRData;
        }).toList();

        print('💊 Medicines with QR codes: ${medicinesWithQRCodes.length}');

        setState(() {
          medicinesWithQR = medicinesWithQRCodes;
          filteredMedicines = medicinesWithQRCodes;
          isLoading = false;
        });
      }
    } catch (e) {
      print('❌ Error loading medicines with QR: $e');
      setState(() => isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load medicines: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _filterMedicines() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        filteredMedicines = medicinesWithQR;
      } else {
        filteredMedicines = medicinesWithQR.where((medicine) {
          return (medicine['name']?.toString().toLowerCase().contains(query) ??
                  false) ||
              (medicine['category']?.toString().toLowerCase().contains(query) ??
                  false) ||
              (medicine['batchNumber']
                      ?.toString()
                      .toLowerCase()
                      .contains(query) ??
                  false);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'QR Medicine Scanner',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFFE65100), // Orange theme
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: widget.isUserMode
              ? const [
                  Tab(
                    icon: Icon(Icons.qr_code_scanner),
                    text: 'Scan Medicine QR',
                  ),
                ]
              : const [
                  Tab(
                    icon: Icon(Icons.qr_code_scanner),
                    text: 'QR Scanner',
                  ),
                  Tab(
                    icon: Icon(Icons.medication),
                    text: 'My QR Codes',
                  ),
                ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: widget.isUserMode
            ? [
                // User Mode: Only QR Scanner Tab
                Stack(
                  children: [
                    // QR Scanner View
                    if (isScanning) _buildQRScannerView(),

                    // Medicine Details View
                    if (!isScanning && scannedData != null)
                      _buildMedicineDetailsView(),

                    // Floating Chat Button for users
                    const ChatArcFloatingButton(userType: 'user'),
                  ],
                ),
              ]
            : [
                // Pharmacy Mode: Both tabs
                Stack(
                  children: [
                    // QR Scanner View
                    if (isScanning) _buildQRScannerView(),

                    // Medicine Details View
                    if (!isScanning && scannedData != null)
                      _buildMedicineDetailsView(),

                    // Floating Chat Button for pharmacy
                    const ChatArcFloatingButton(userType: 'pharmacy'),
                  ],
                ),
                // My QR Codes Tab (only for pharmacy)
                _buildMyQRCodesView(),
              ],
      ),
    );
  }

  Widget _buildQRScannerView() {
    return Column(
      children: [
        // Instructions
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          color: const Color(0xFFE65100).withOpacity(0.1),
          child: Column(
            children: [
              Icon(
                Icons.qr_code_scanner,
                color: const Color(0xFFE65100),
                size: 32,
              ),
              const SizedBox(height: 8),
              Text(
                'Scan Medicine QR Code',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFFE65100),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Point your camera at the medicine QR code to get details',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),

        // QR Scanner Camera View
        Expanded(
          child: Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border:
                  Border.all(color: const Color(0xFFE65100).withOpacity(0.3)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: MobileScanner(
                controller: _scannerController ??= MobileScannerController(),
                onDetect: (capture) {
                  final List<Barcode> barcodes = capture.barcodes;
                  for (final barcode in barcodes) {
                    if (barcode.rawValue != null && mounted) {
                      final qrDataString = barcode.rawValue!;

                      // Stop the scanner
                      _scannerController?.stop();

                      // Try to parse QR data as JSON
                      try {
                        Map<String, dynamic> qrData;

                        // Check if it's a JSON string or URL query parameters
                        if (qrDataString.startsWith('{')) {
                          // It's a JSON string - parse it directly
                          qrData = jsonDecode(qrDataString);
                        } else {
                          // It's URL query parameters
                          qrData = Map<String, dynamic>.from(
                              Uri.splitQueryString(qrDataString));
                        }

                        print('🔍 Parsed QR data: $qrData');

                        // Check if it's a medicine QR code
                        if (qrData['type'] == 'medicine') {
                          // Navigate to medicine result screen
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => MedicineQRResultScreen(
                                medicineData: qrData,
                                isUserMode:
                                    widget.isUserMode, // Pass user mode status
                              ),
                            ),
                          );
                        } else {
                          // Show generic QR data
                          _showQRDataDialog(qrDataString);
                        }
                      } catch (e) {
                        print('❌ Error parsing QR data: $e');
                        // If parsing fails, show raw data
                        _showQRDataDialog(qrDataString);
                      }

                      // Show success message
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Row(
                            children: [
                              const Icon(Icons.check_circle,
                                  color: Colors.white),
                              const SizedBox(width: 8),
                              Text('QR Code scanned successfully!'),
                            ],
                          ),
                          backgroundColor: Colors.green,
                          duration: const Duration(seconds: 2),
                        ),
                      );
                      break;
                    }
                  }
                },
              ),
            ),
          ),
        ),

        // Scan Another Button
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          child: ElevatedButton.icon(
            onPressed: () {
              setState(() {
                scannedData = null;
              });
              _scannerController?.start();
            },
            icon: const Icon(Icons.qr_code_scanner),
            label: const Text('Scan Another QR Code'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE65100),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMedicineDetailsView() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFFE65100).withOpacity(0.1),
                  const Color(0xFFE65100).withOpacity(0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border:
                  Border.all(color: const Color(0xFFE65100).withOpacity(0.2)),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.medication,
                  color: const Color(0xFFE65100),
                  size: 48,
                ),
                const SizedBox(height: 12),
                Text(
                  'Medicine Details',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFFE65100),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'QR Code scanned successfully!',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Medicine Information
          Expanded(
            child: _buildMedicineInfo(),
          ),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      isScanning = true;
                      scannedData = null;
                    });
                  },
                  icon: const Icon(Icons.qr_code_scanner),
                  label: const Text('Scan Another'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[600],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content:
                            Text('Please scan a QR code first to download'),
                        backgroundColor: Color(0xFFE65100),
                      ),
                    );
                  },
                  icon: const Icon(Icons.download),
                  label: const Text('Download QR'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE65100),
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
        ],
      ),
    );
  }

  Widget _buildMedicineInfo() {
    return FutureBuilder<Map<String, dynamic>?>(
      future: ApiService.getMedicineByQRCode(scannedData!),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFE65100)),
            ),
          );
        }

        if (snapshot.hasError || snapshot.data == null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  color: Colors.red,
                  size: 64,
                ),
                const SizedBox(height: 16),
                Text(
                  'Medicine not found',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.red,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'The QR code does not contain valid medicine information',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        final medicine = snapshot.data!;
        return Card(
          elevation: 4,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Medicine Name
                Text(
                  medicine['name'] ?? 'Unknown Medicine',
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFFE65100),
                  ),
                ),
                const SizedBox(height: 16),

                // Medicine Details
                _buildInfoRow('Category', medicine['category'] ?? 'N/A'),
                _buildInfoRow('Dose',
                    '${medicine['dose'] ?? 'N/A'} ${medicine['unit'] ?? ''}'),
                _buildInfoRow('Frequency', medicine['frequency'] ?? 'N/A'),
                _buildInfoRow('Stock', '${medicine['stock'] ?? 0} units'),
                _buildInfoRow('Price', '₹${medicine['unitPrice'] ?? 'N/A'}'),
                _buildInfoRow('Batch Number', medicine['batchNumber'] ?? 'N/A'),
                _buildInfoRow('Expiry Date', medicine['expiryDate'] ?? 'N/A'),

                if (medicine['instructions'] != null &&
                    medicine['instructions'].isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue[200]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Instructions:',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.blue[800],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          medicine['instructions'],
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.blue[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoRow(String label, String value) {
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
                fontSize: 14,
                fontWeight: FontWeight.w600,
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

  Widget _buildMyQRCodesView() {
    return Column(
      children: [
        // Search Bar
        Container(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search medicines...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
            ),
          ),
        ),

        // Medicines List
        Expanded(
          child: isLoading
              ? const Center(
                  child: CircularProgressIndicator(
                    valueColor:
                        AlwaysStoppedAnimation<Color>(Color(0xFFE65100)),
                  ),
                )
              : filteredMedicines.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.qr_code,
                            size: 80,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No QR Codes Generated',
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Generate QR codes for your medicines in the inventory management screen',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: Colors.grey[500],
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadMedicinesWithQR,
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: filteredMedicines.length,
                        itemBuilder: (context, index) {
                          final medicine = filteredMedicines[index];
                          return _buildMedicineQRCard(medicine);
                        },
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _buildMedicineQRCard(Map<String, dynamic> medicine) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Medicine Header
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        medicine['name'] ?? 'Unknown Medicine',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFFE65100),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        medicine['category'] ?? 'N/A',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                // QR Code Preview
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: QrImageView(
                    data: medicine['qrCodeData'] ?? '',
                    version: QrVersions.auto,
                    size: 60,
                    backgroundColor: Colors.white,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Medicine Details
            Row(
              children: [
                Expanded(
                  child: _buildDetailChip('Stock', '${medicine['stock'] ?? 0}'),
                ),
                Expanded(
                  child: _buildDetailChip(
                      'Price', '₹${medicine['unitPrice'] ?? 'N/A'}'),
                ),
                Expanded(
                  child: _buildDetailChip(
                      'Batch', medicine['batchNumber'] ?? 'N/A'),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Action Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _shareMedicineQRCode(medicine),
                icon: const Icon(Icons.share, size: 18),
                label: const Text('Share QR Code'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE65100),
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 10,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey[800],
            ),
          ),
        ],
      ),
    );
  }

  void _shareMedicineQRCode(Map<String, dynamic> medicine) async {
    try {
      // Show loading indicator
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              const SizedBox(width: 16),
              const Text('Preparing QR card for sharing...'),
            ],
          ),
          backgroundColor: const Color(0xFFE65100),
          duration: const Duration(seconds: 2),
        ),
      );

      // Render QR card in an overlay to ensure it lays out with a real size
      final overlay = Overlay.of(context);
      final captureKey = GlobalKey();
      late OverlayEntry entry;

      entry = OverlayEntry(
        builder: (context) {
          final screenWidth = MediaQuery.of(context).size.width;
          return Material(
            type: MaterialType.transparency,
            child: Center(
              child: RepaintBoundary(
                key: captureKey,
                child: _buildShareableQRCard(medicine, screenWidth - 24),
              ),
            ),
          );
        },
      );

      overlay.insert(entry);

      // Wait for the widget to be laid out
      await Future.delayed(const Duration(milliseconds: 200));

      // Capture the image
      final RenderRepaintBoundary boundary = captureKey.currentContext!
          .findRenderObject() as RenderRepaintBoundary;
      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      final Uint8List pngBytes = byteData!.buffer.asUint8List();

      // Remove the overlay
      entry.remove();

      // Save to temporary file and share
      final tempDir = await getTemporaryDirectory();
      final file = await File(
              '${tempDir.path}/medicine_qr_card_${medicine['name']?.replaceAll(' ', '_') ?? 'unknown'}.png')
          .create();
      await file.writeAsBytes(pngBytes);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Medicine QR Code Card - ${medicine['name']}',
        subject: 'QR Code Card - ${medicine['name']}',
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 8),
              Text('QR card shared successfully!'),
            ],
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to share QR card: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildShareableQRCard(Map<String, dynamic> medicine, double maxWidth) {
    return Container(
      width: maxWidth,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Text(
            'Medicine QR Code',
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: const Color(0xFFE65100),
            ),
          ),
          const SizedBox(height: 20),

          // Medicine Info
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFE65100).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Text(
                  medicine['name'] ?? 'Unknown Medicine',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFFE65100),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  medicine['category'] ?? 'N/A',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // QR Code
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: QrImageView(
              data: medicine['qrCodeData'] ?? '',
              version: QrVersions.auto,
              size: 200,
              backgroundColor: Colors.white,
            ),
          ),
          const SizedBox(height: 16),

          // Medicine Details
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildDetailChip('Stock', '${medicine['stock'] ?? 0}'),
              _buildDetailChip('Price', '₹${medicine['unitPrice'] ?? 'N/A'}'),
              _buildDetailChip('Batch', medicine['batchNumber'] ?? 'N/A'),
            ],
          ),
          const SizedBox(height: 16),

          // Footer
          Text(
            'Scan this QR code to get medicine details',
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

  void _showQRDataDialog(String qrData) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'QR Code Data',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: const Color(0xFFE65100),
          ),
        ),
        content: SingleChildScrollView(
          child: Text(
            qrData,
            style: GoogleFonts.poppins(fontSize: 14),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Close',
              style: GoogleFonts.poppins(
                color: const Color(0xFFE65100),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
