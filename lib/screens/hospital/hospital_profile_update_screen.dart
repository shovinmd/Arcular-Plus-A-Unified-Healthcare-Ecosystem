import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/user_model.dart';
import '../../services/api_service.dart';
import '../../utils/constants.dart';

class HospitalProfileUpdateScreen extends StatefulWidget {
  final UserModel hospital;
  
  const HospitalProfileUpdateScreen({
    Key? key,
    required this.hospital,
  }) : super(key: key);

  @override
  State<HospitalProfileUpdateScreen> createState() => _HospitalProfileUpdateScreenState();
}

class _HospitalProfileUpdateScreenState extends State<HospitalProfileUpdateScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  // Controllers
  late TextEditingController _hospitalNameController;
  late TextEditingController _registrationNumberController;
  late TextEditingController _hospitalAddressController;
  late TextEditingController _hospitalEmailController;
  late TextEditingController _hospitalPhoneController;
  late TextEditingController _numberOfBedsController;
  late TextEditingController _mobileNumberController;

  String _selectedHospitalType = 'Hospital';
  bool _hasPharmacy = false;
  bool _hasLab = false;
  List<String> _selectedDepartments = [];
  List<String> _selectedSpecialFacilities = [];

  final List<String> _hospitalTypes = [
    'Hospital',
    'Clinic',
    'Multi-specialty Hospital',
    'Diagnostic Centre',
    'Nursing Home',
  ];

  final List<String> _availableDepartments = [
    'Cardiology',
    'Neurology',
    'Orthopedics',
    'Pediatrics',
    'Gynecology',
    'Oncology',
    'Dermatology',
    'Psychiatry',
    'Emergency Medicine',
    'General Surgery',
    'Internal Medicine',
    'Radiology',
    'Pathology',
    'Anesthesiology',
  ];

  final List<String> _availableSpecialFacilities = [
    'NICU',
    'CCU',
    'ICU',
    'Emergency',
    'Trauma Center',
    'Burn Unit',
    'Cancer Center',
    'Cardiac Care',
    'Neonatal Care',
    'Pediatric ICU',
    'Surgical ICU',
    'Medical ICU',
  ];

  @override
  void initState() {
    super.initState();
    _initializeControllers();
  }

  void _initializeControllers() {
    _hospitalNameController = TextEditingController(text: widget.hospital.hospitalName ?? '');
    _registrationNumberController = TextEditingController(text: widget.hospital.registrationNumber ?? '');
    _hospitalAddressController = TextEditingController(text: widget.hospital.hospitalAddress ?? '');
    _hospitalEmailController = TextEditingController(text: widget.hospital.hospitalEmail ?? '');
    _hospitalPhoneController = TextEditingController(text: widget.hospital.hospitalPhone ?? '');
    _numberOfBedsController = TextEditingController(text: widget.hospital.numberOfBeds?.toString() ?? '');
    _mobileNumberController = TextEditingController(text: widget.hospital.mobileNumber);

    _selectedHospitalType = widget.hospital.hospitalType ?? 'Hospital';
    _hasPharmacy = widget.hospital.hasPharmacy ?? false;
    _hasLab = widget.hospital.hasLab ?? false;
    _selectedDepartments = widget.hospital.departments ?? [];
    _selectedSpecialFacilities = widget.hospital.specialFacilities ?? [];
  }

  @override
  void dispose() {
    _hospitalNameController.dispose();
    _registrationNumberController.dispose();
    _hospitalAddressController.dispose();
    _hospitalEmailController.dispose();
    _hospitalPhoneController.dispose();
    _numberOfBedsController.dispose();
    _mobileNumberController.dispose();
    super.dispose();
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final updatedHospital = UserModel(
        uid: widget.hospital.uid,
        fullName: widget.hospital.fullName,
        email: widget.hospital.email,
        mobileNumber: _mobileNumberController.text.trim(),
        alternateMobile: widget.hospital.alternateMobile,
        gender: widget.hospital.gender,
        dateOfBirth: widget.hospital.dateOfBirth,
        address: widget.hospital.address,
        pincode: widget.hospital.pincode,
        city: widget.hospital.city,
        state: widget.hospital.state,
        aadhaarNumber: widget.hospital.aadhaarNumber,
        aadhaarFrontImageUrl: widget.hospital.aadhaarFrontImageUrl,
        aadhaarBackImageUrl: widget.hospital.aadhaarBackImageUrl,
        profileImageUrl: widget.hospital.profileImageUrl,
        type: 'hospital',
        role: widget.hospital.role,
        createdAt: widget.hospital.createdAt,
        healthQrId: widget.hospital.healthQrId,
        arcId: widget.hospital.arcId,
        qrCode: widget.hospital.qrCode,
        // Hospital-specific fields
        hospitalName: _hospitalNameController.text.trim(),
        registrationNumber: _registrationNumberController.text.trim(),
        hospitalType: _selectedHospitalType,
        hospitalAddress: _hospitalAddressController.text.trim(),
        hospitalEmail: _hospitalEmailController.text.trim(),
        hospitalPhone: _hospitalPhoneController.text.trim(),
        numberOfBeds: int.tryParse(_numberOfBedsController.text.trim()) ?? 0,
        hasPharmacy: _hasPharmacy,
        hasLab: _hasLab,
        departments: _selectedDepartments,
        specialFacilities: _selectedSpecialFacilities,
        licenseDocumentUrl: widget.hospital.licenseDocumentUrl,
        isApproved: widget.hospital.isApproved,
        approvalStatus: widget.hospital.approvalStatus,
      );

      // TODO: Implement API call to update hospital profile
      // await ApiService.updateHospitalProfile(updatedHospital);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      print('Error updating profile: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating profile: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Update Hospital Profile',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF4CAF50), Color(0xFF81C784)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Hospital Information Section
                    _buildSectionTitle('Hospital Information'),
                    const SizedBox(height: 16),
                    
                    TextFormField(
                      controller: _hospitalNameController,
                      decoration: InputDecoration(
                        labelText: 'Hospital Name',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        prefixIcon: const Icon(Icons.local_hospital),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Hospital name is required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    
                    TextFormField(
                      controller: _registrationNumberController,
                      decoration: InputDecoration(
                        labelText: 'Registration Number',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        prefixIcon: const Icon(Icons.numbers),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Registration number is required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    
                    DropdownButtonFormField<String>(
                      value: _selectedHospitalType,
                      decoration: InputDecoration(
                        labelText: 'Hospital Type',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        prefixIcon: const Icon(Icons.category),
                      ),
                      items: _hospitalTypes.map((type) {
                        return DropdownMenuItem(value: type, child: Text(type));
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedHospitalType = value!;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    
                    TextFormField(
                      controller: _numberOfBedsController,
                      decoration: InputDecoration(
                        labelText: 'Number of Beds',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        prefixIcon: const Icon(Icons.bed),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Number of beds is required';
                        }
                        if (int.tryParse(value.trim()) == null) {
                          return 'Please enter a valid number';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    
                    // Contact Information Section
                    _buildSectionTitle('Contact Information'),
                    const SizedBox(height: 16),
                    
                    TextFormField(
                      controller: _hospitalAddressController,
                      decoration: InputDecoration(
                        labelText: 'Hospital Address',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        prefixIcon: const Icon(Icons.location_on),
                      ),
                      maxLines: 3,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Hospital address is required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    
                    TextFormField(
                      controller: _hospitalEmailController,
                      decoration: InputDecoration(
                        labelText: 'Hospital Email',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        prefixIcon: const Icon(Icons.email),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Hospital email is required';
                        }
                        if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value.trim())) {
                          return 'Please enter a valid email';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    
                    TextFormField(
                      controller: _hospitalPhoneController,
                      decoration: InputDecoration(
                        labelText: 'Hospital Phone',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        prefixIcon: const Icon(Icons.phone),
                      ),
                      keyboardType: TextInputType.phone,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Hospital phone is required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    
                    TextFormField(
                      controller: _mobileNumberController,
                      decoration: InputDecoration(
                        labelText: 'Mobile Number',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        prefixIcon: const Icon(Icons.mobile_friendly),
                      ),
                      keyboardType: TextInputType.phone,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Mobile number is required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    
                    // Facilities Section
                    _buildSectionTitle('Facilities'),
                    const SizedBox(height: 16),
                    
                    // Checkboxes for facilities
                    CheckboxListTile(
                      title: const Text('Has Pharmacy'),
                      value: _hasPharmacy,
                      onChanged: (value) {
                        setState(() {
                          _hasPharmacy = value!;
                        });
                      },
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                    
                    CheckboxListTile(
                      title: const Text('Has Laboratory'),
                      value: _hasLab,
                      onChanged: (value) {
                        setState(() {
                          _hasLab = value!;
                        });
                      },
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                    const SizedBox(height: 16),
                    
                    // Departments
                    Text(
                      'Departments',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: _availableDepartments.map((dept) {
                        final isSelected = _selectedDepartments.contains(dept);
                        return FilterChip(
                          label: Text(dept),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                _selectedDepartments.add(dept);
                              } else {
                                _selectedDepartments.remove(dept);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    
                    // Special Facilities
                    Text(
                      'Special Facilities',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: _availableSpecialFacilities.map((facility) {
                        final isSelected = _selectedSpecialFacilities.contains(facility);
                        return FilterChip(
                          label: Text(facility),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                _selectedSpecialFacilities.add(facility);
                              } else {
                                _selectedSpecialFacilities.remove(facility);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 32),
                    
                    // Update Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _updateProfile,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4CAF50),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Update Profile',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.poppins(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: const Color(0xFF4CAF50),
      ),
    );
  }
} 