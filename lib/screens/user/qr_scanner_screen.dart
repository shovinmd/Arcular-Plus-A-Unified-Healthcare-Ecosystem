import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:arcular_plus/screens/user/qr_scan_result_screen.dart';
import 'package:arcular_plus/screens/hospital/hospital_qr_scan_result_screen.dart';
import 'package:arcular_plus/screens/doctor/doctor_qr_scan_result_screen.dart';
import 'package:arcular_plus/screens/pharmacy/pharmacy_qr_scan_result_screen.dart';
import 'package:arcular_plus/screens/nurse/nurse_qr_scan_result_screen.dart';
import 'package:arcular_plus/screens/lab/lab_qr_scan_result_screen.dart';
import 'package:arcular_plus/services/api_service.dart';

class QRScannerScreen extends StatefulWidget {
  const QRScannerScreen({super.key});

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
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

  void _processQRCode(String code) {
    // Stop scanning to prevent multiple scans
    controller.stop();
    setState(() => _isScanning = false);

    // Validate that this is a legitimate Arcular Plus QR code
    if (_isValidArcularQRCode(code)) {
      // Process the QR code to determine type and navigate accordingly
      _determineQRTypeAndNavigate(code);
    } else {
      // Show error for invalid QR code
      _showInvalidQRDialog();
    }
  }

  String _extractIdentifier(String raw) {
    try {
      final trimmed = raw.trim();
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
      if (trimmed.contains('://')) {
        final uri = Uri.tryParse(trimmed);
        if (uri != null) {
          final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
          if (segments.isNotEmpty) return segments.last;
        }
      }
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

      // Try to fetch as user first
      final userInfo = await ApiService.getUserByArcId(identifier);
      if (userInfo != null) {
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

      // Try to fetch as nurse
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
                // Normalize payload to match universal scanner shape
                PharmacyQRScanResultScreen(
                    pharmacyData: pharmacyInfo['data'] ?? pharmacyInfo),
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

  // Validate that the QR code is from Arcular Plus app
  bool _isValidArcularQRCode(String code) {
    // Accept any non-empty string that could be a user ID
    if (code.isNotEmpty && code.trim().isNotEmpty) {
      return true;
    }

    return false;
  }

  void _showInvalidQRDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Invalid QR Code'),
        content: const Text(
          'This QR code is not a valid Arcular+ health QR code. '
          'Please scan a QR code generated from the Arcular+ app. '
          'Only legitimate health QR codes from our platform are accepted.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // Resume scanning
              controller.start();
              setState(() => _isScanning = true);
            },
            child: const Text('OK'),
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
          'No user or service provider found with this QR code. Please make sure you are scanning a valid Arcular+ health QR code.',
          style: GoogleFonts.poppins(
            fontSize: 14,
            color: const Color(0xFF6B7280),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // Resume scanning
              controller.start();
              setState(() => _isScanning = true);
            },
            child: Text(
              'Try Again',
              style: GoogleFonts.poppins(
                color: const Color(0xFF32CCBC),
                fontWeight: FontWeight.w600,
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
              Navigator.pop(context);
              // Resume scanning
              controller.start();
              setState(() => _isScanning = true);
            },
            child: Text(
              'Try Again',
              style: GoogleFonts.poppins(
                color: const Color(0xFF32CCBC),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Scan Health QR Code',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF32CCBC), // Patient teal
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: Icon(_isScanning ? Icons.pause : Icons.play_arrow),
            onPressed: () {
              if (_isScanning) {
                controller.pause();
                setState(() => _isScanning = false);
              } else {
                controller.start();
                setState(() => _isScanning = true);
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.flip_camera_ios),
            onPressed: () => controller.switchCamera(),
          ),
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => const QRScannerScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF32CCBC), Color(0xFF90F7EC), Color(0xFFE8F5E8)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: Column(
          children: [
            // Instructions
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Icon(
                    Icons.qr_code_scanner,
                    size: 48,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Scan Health QR Code',
                    style: GoogleFonts.poppins(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Point your camera at a health QR code to view medical information',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      color: Colors.white.withOpacity(0.9),
                    ),
                    textAlign: TextAlign.center,
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
                    'Make sure the QR code is clearly visible in the frame',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.8),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
