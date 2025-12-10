import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:arcular_plus/services/api_service.dart';
import 'package:arcular_plus/screens/user/qr_scan_result_screen.dart';
import 'package:arcular_plus/screens/hospital/hospital_qr_scan_result_screen.dart';
import 'package:arcular_plus/screens/pharmacy/pharmacy_qr_scan_result_screen.dart';
import 'package:arcular_plus/screens/doctor/doctor_qr_scan_result_screen.dart';
import 'package:arcular_plus/screens/lab/lab_qr_scan_result_screen.dart';
import 'package:arcular_plus/screens/nurse/nurse_qr_scan_result_screen.dart';

class UniversalQRScannerScreen extends StatefulWidget {
  const UniversalQRScannerScreen({super.key});

  @override
  State<UniversalQRScannerScreen> createState() =>
      _UniversalQRScannerScreenState();
}

class _UniversalQRScannerScreenState extends State<UniversalQRScannerScreen> {
  MobileScannerController controller = MobileScannerController();
  bool _isScanning = true;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    final List<Barcode> barcodes = capture.barcodes;

    for (final barcode in barcodes) {
      final String? code = barcode.rawValue;
      if (code != null) {
        _processQRCode(code);
        break;
      }
    }
  }

  void _processQRCode(String code) async {
    // Stop scanning to prevent multiple scans
    controller.stop();
    setState(() => _isScanning = false);

    // Validate that this is a legitimate Arcular Plus QR code
    if (_isValidArcularQRCode(code)) {
      // Try to determine the type of QR code by attempting to fetch data
      await _determineQRTypeAndNavigate(code);
    } else {
      // Show error for invalid QR code
      _showInvalidQRDialog();
    }
  }

  // Validate that the QR code is from Arcular Plus app
  bool _isValidArcularQRCode(String code) {
    // Accept any non-empty string that could be a user ID
    if (code.isNotEmpty && code.trim().isNotEmpty) {
      return true;
    }

    return false;
  }

  String _extractIdentifier(String raw) {
    try {
      final trimmed = raw.trim();
      // If JSON payload, try to parse and pick common id keys
      if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
        final dynamic decoded = jsonDecode(trimmed);
        if (decoded is Map) {
          final candidateKeys = [
            'arcId',
            'healthQrId',
            'id',
            'uid',
            'userId',
            'providerId',
          ];
          for (final key in candidateKeys) {
            final value = decoded[key];
            if (value is String && value.trim().isNotEmpty) {
              return value.trim();
            }
          }
        }
      }
      // If it's a URL, take the last non-empty path segment
      if (trimmed.contains('://')) {
        final uri = Uri.tryParse(trimmed);
        if (uri != null) {
          final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
          if (segments.isNotEmpty) {
            return segments.last;
          }
        }
      }
      // Fallback: return as-is
      return trimmed;
    } catch (_) {
      return raw;
    }
  }

  Future<void> _determineQRTypeAndNavigate(String code) async {
    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      final identifier = _extractIdentifier(code);

      // Prefer service providers first to avoid routing nurses as generic users
      // Try to fetch as nurse FIRST
      final nurseInfo = await ApiService.getNurseByArcId(identifier);
      if (nurseInfo != null) {
        Navigator.of(context).pop(); // Close loading dialog
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => NurseQRScanResultScreen(nurseData: nurseInfo),
          ),
        );
        return;
      }

      // Then generic user
      final userInfo = await ApiService.getUserByArcId(identifier);
      if (userInfo != null) {
        // If user looks like a nurse, route to nurse result instead
        if ((userInfo is Map &&
            ((userInfo['type'] == 'nurse') ||
                (userInfo['role'] == 'Nurse') ||
                (userInfo['userType'] == 'nurse')))) {
          Navigator.of(context).pop();
          // Attempt to fetch enriched nurse info by arcId
          final enrichedNurse =
              await ApiService.getNurseByArcId(identifier) ?? userInfo;
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  NurseQRScanResultScreen(nurseData: enrichedNurse),
            ),
          );
          return;
        }
        Navigator.of(context).pop(); // Close loading dialog
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => QRScanResultScreen(arcId: identifier),
          ),
        );
        return;
      }

      // Try to fetch as hospital
      final hospitalInfo = await ApiService.getHospitalByArcId(identifier);
      if (hospitalInfo != null) {
        Navigator.of(context).pop(); // Close loading dialog
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) =>
                HospitalQRScanResultScreen(hospitalData: hospitalInfo),
          ),
        );
        return;
      }

      // Try to fetch as doctor
      final doctorInfo = await ApiService.getDoctorByArcId(identifier);
      if (doctorInfo != null) {
        Navigator.of(context).pop(); // Close loading dialog
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) =>
                DoctorQRScanResultScreen(doctorData: doctorInfo),
          ),
        );
        return;
      }

      // Try to fetch as lab
      final labInfo = await ApiService.getLabByArcId(identifier);
      if (labInfo != null) {
        Navigator.of(context).pop(); // Close loading dialog
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => LabQRScanResultScreen(labData: labInfo),
          ),
        );
        return;
      }

      // Try to fetch as pharmacy
      final pharmacyInfo = await ApiService.getPharmacyByArcId(identifier);
      if (pharmacyInfo != null) {
        Navigator.of(context).pop(); // Close loading dialog
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) =>
                PharmacyQRScanResultScreen(pharmacyData: pharmacyInfo['data']),
          ),
        );
        return;
      }

      // If no service provider found
      Navigator.of(context).pop(); // Close loading dialog
      _showNotFoundDialog();
    } catch (e) {
      Navigator.of(context).pop(); // Close loading dialog
      _showErrorDialog('Error processing QR code: $e');
    }
  }

  void _showInvalidQRDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Invalid QR Code',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF2E2E2E),
          ),
        ),
        content: Text(
          'This QR code is not from Arcular Plus app. Please scan a valid health QR code.',
          style: GoogleFonts.poppins(
            fontSize: 14,
            color: const Color(0xFF6B7280),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _restartScanner();
            },
            child: Text(
              'Try Again',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF32CCBC),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showNotFoundDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Not Found',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF2E2E2E),
          ),
        ),
        content: Text(
          'No user or hospital found with this QR code. Please check if the QR code is valid and try again.',
          style: GoogleFonts.poppins(
            fontSize: 14,
            color: const Color(0xFF6B7280),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _restartScanner();
            },
            child: Text(
              'Try Again',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF32CCBC),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Error',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF2E2E2E),
          ),
        ),
        content: Text(
          message,
          style: GoogleFonts.poppins(
            fontSize: 14,
            color: const Color(0xFF6B7280),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _restartScanner();
            },
            child: Text(
              'Try Again',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF32CCBC),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _restartScanner() {
    setState(() {
      _isScanning = true;
    });
    controller.start();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF32CCBC), Color(0xFF2E7D32), Color(0xFF1B5E20)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(
                            Icons.arrow_back,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            'Universal QR Scanner',
                            style: GoogleFonts.poppins(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(width: 48), // Balance the back button
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Scan any Arcular Plus QR code',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
              ),

              // Scanner
              Expanded(
                child: Container(
                  margin: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white,
                      width: 3,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(13),
                    child: MobileScanner(
                      controller: controller,
                      onDetect: _onDetect,
                    ),
                  ),
                ),
              ),

              // Bottom info
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Text(
                      'Status: ${_isScanning ? 'Scanning...' : 'Paused'}',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Scan user QR codes, hospital QR codes, pharmacy QR codes, lab QR codes, or any Arcular Plus QR code',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.8),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildInfoChip('👤 Users', Colors.blue),
                        _buildInfoChip('🏥 Hospitals', Colors.green),
                        _buildInfoChip('👨‍⚕️ Doctors', Colors.purple),
                        _buildInfoChip('👩‍⚕️ Nurses', Colors.orange),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildInfoChip('💊 Pharmacies', Colors.amber),
                        _buildInfoChip('🧪 Labs', Colors.teal),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: Colors.white,
        ),
      ),
    );
  }
}
