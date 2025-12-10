import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  String? _scanResult;
  bool _scanned = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan QR/Barcode'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          MobileScanner(
            onDetect: (capture) {
              if (_scanned) return;
              final barcode = capture.barcodes.first;
              setState(() {
                _scanResult = barcode.rawValue;
                _scanned = true;
              });
              if (_scanResult != null) {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Scan Result'),
                    content: Text(_scanResult!),
                    actions: [
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          Navigator.of(context).pop(_scanResult);
                        },
                        child: const Text('OK'),
                      ),
                    ],
                  ),
                );
              }
            },
          ),
          if (_scanResult != null)
            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                color: Colors.black54,
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Result: $_scanResult',
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            ),
        ],
      ),
    );
  }
} 