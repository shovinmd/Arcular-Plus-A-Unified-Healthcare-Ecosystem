import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class QRGeneratorScreen extends StatefulWidget {
  const QRGeneratorScreen({super.key});

  @override
  State<QRGeneratorScreen> createState() => _QRGeneratorScreenState();
}

class _QRGeneratorScreenState extends State<QRGeneratorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _medicineNameController = TextEditingController();
  final _medicineTypeController = TextEditingController();
  final _manufacturerController = TextEditingController();
  final _batchNumberController = TextEditingController();
  final _expiryDateController = TextEditingController();
  final _unitPriceController = TextEditingController();
  final _sellingPriceController = TextEditingController();
  final _stockController = TextEditingController();
  final _descriptionController = TextEditingController();

  String? _generatedQRData;
  bool _isGenerating = false;

  @override
  void dispose() {
    _medicineNameController.dispose();
    _medicineTypeController.dispose();
    _manufacturerController.dispose();
    _batchNumberController.dispose();
    _expiryDateController.dispose();
    _unitPriceController.dispose();
    _sellingPriceController.dispose();
    _stockController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _generateQR() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isGenerating = true;
    });

    try {
      // Create medicine data map
      final medicineData = {
        'medicineName': _medicineNameController.text.trim(),
        'medicineType': _medicineTypeController.text.trim(),
        'manufacturer': _manufacturerController.text.trim(),
        'batchNumber': _batchNumberController.text.trim(),
        'expiryDate': _expiryDateController.text.trim(),
        'unitPrice': double.tryParse(_unitPriceController.text) ?? 0.0,
        'sellingPrice': double.tryParse(_sellingPriceController.text) ?? 0.0,
        'stock': int.tryParse(_stockController.text) ?? 0,
        'description': _descriptionController.text.trim(),
        'generatedAt': DateTime.now().toIso8601String(),
        'pharmacyId':
            'current_pharmacy', // This should be the actual pharmacy ID
      };

      // Convert to JSON string for QR code
      _generatedQRData = jsonEncode(medicineData);

      setState(() {
        _isGenerating = false;
      });

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('QR Code generated successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      setState(() {
        _isGenerating = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error generating QR code: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _addToInventory() async {
    if (_generatedQRData == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please generate QR code first!'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();

      // Get existing medicines
      final existingMedicines = prefs.getStringList('pharmacy_medicines') ?? [];

      // Add new medicine
      existingMedicines.add(_generatedQRData!);

      // Save back to preferences
      await prefs.setStringList('pharmacy_medicines', existingMedicines);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Medicine added to inventory successfully!'),
          backgroundColor: Colors.green,
        ),
      );

      // Clear form
      _clearForm();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error adding to inventory: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _clearForm() {
    _medicineNameController.clear();
    _medicineTypeController.clear();
    _manufacturerController.clear();
    _batchNumberController.clear();
    _expiryDateController.clear();
    _unitPriceController.clear();
    _sellingPriceController.clear();
    _stockController.clear();
    _descriptionController.clear();
    setState(() {
      _generatedQRData = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'QR Generator',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        backgroundColor: const Color(0xFFE65100),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Text(
              'Generate QR Code for Medicine',
              style: GoogleFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Enter medicine details to generate a QR code',
              style: GoogleFonts.poppins(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 24),

            // Form
            Form(
              key: _formKey,
              child: Column(
                children: [
                  // Medicine Name
                  _buildTextField(
                    controller: _medicineNameController,
                    label: 'Medicine Name',
                    hint: 'Enter medicine name',
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter medicine name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Medicine Type
                  _buildTextField(
                    controller: _medicineTypeController,
                    label: 'Medicine Type',
                    hint: 'e.g., Tablet, Syrup, Injection',
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter medicine type';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Manufacturer
                  _buildTextField(
                    controller: _manufacturerController,
                    label: 'Manufacturer',
                    hint: 'Enter manufacturer name',
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter manufacturer';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Batch Number
                  _buildTextField(
                    controller: _batchNumberController,
                    label: 'Batch Number',
                    hint: 'Enter batch number',
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter batch number';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Expiry Date
                  _buildTextField(
                    controller: _expiryDateController,
                    label: 'Expiry Date',
                    hint: 'DD/MM/YYYY',
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter expiry date';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Price Row
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          controller: _unitPriceController,
                          label: 'Unit Price (₹)',
                          hint: '0.00',
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Required';
                            }
                            if (double.tryParse(value) == null) {
                              return 'Invalid price';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildTextField(
                          controller: _sellingPriceController,
                          label: 'Selling Price (₹)',
                          hint: '0.00',
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Required';
                            }
                            if (double.tryParse(value) == null) {
                              return 'Invalid price';
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Stock
                  _buildTextField(
                    controller: _stockController,
                    label: 'Stock Quantity',
                    hint: 'Enter stock quantity',
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter stock quantity';
                      }
                      if (int.tryParse(value) == null) {
                        return 'Invalid quantity';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Description
                  _buildTextField(
                    controller: _descriptionController,
                    label: 'Description',
                    hint: 'Enter medicine description (optional)',
                    maxLines: 3,
                  ),
                  const SizedBox(height: 24),

                  // Generate QR Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isGenerating ? null : _generateQR,
                      icon: _isGenerating
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Icon(Icons.qr_code_2),
                      label: Text(
                        _isGenerating ? 'Generating...' : 'Generate QR Code',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                      ),
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
            ),

            // Generated QR Code Section
            if (_generatedQRData != null) ...[
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  children: [
                    Text(
                      'Generated QR Code',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: QrImageView(
                        data: _generatedQRData!,
                        version: QrVersions.auto,
                        size: 200.0,
                        backgroundColor: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _addToInventory,
                            icon: const Icon(Icons.add_box),
                            label: const Text('Add to Inventory'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF4CAF50),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _clearForm,
                            icon: const Icon(Icons.clear),
                            label: const Text('Clear Form'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFFE65100),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          validator: validator,
          keyboardType: keyboardType,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.poppins(color: Colors.grey.shade400),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE65100), width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.red),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
          ),
        ),
      ],
    );
  }
}
