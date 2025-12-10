import 'package:flutter/material.dart';
import 'package:arcular_plus/models/user_model.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/api_service.dart';

// Add color constants at the top
const Color kBackground = Color(0xFFF9FAFB);
const Color kPrimaryText = Color(0xFF2E2E2E);
const Color kSecondaryText = Color(0xFF6B7280);
const Color kBorder = Color(0xFFE5E7EB);
const Color kSuccess = Color(0xFFA3E635);
const Color kPharmacyOrange = Color(0xFFFF9800);

class PharmacyUpdateProfileScreen extends StatefulWidget {
  final UserModel pharmacy;
  const PharmacyUpdateProfileScreen({super.key, required this.pharmacy});

  @override
  State<PharmacyUpdateProfileScreen> createState() =>
      _PharmacyUpdateProfileScreenState();
}

class _PharmacyUpdateProfileScreenState
    extends State<PharmacyUpdateProfileScreen> {
  late UserModel _pharmacy;
  final ImagePicker _picker = ImagePicker();
  String? _profileImageUrl;
  bool _isLoading = false;

  // Form controllers
  final _pharmacyNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _altPhoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _pincodeController = TextEditingController();
  final _licenseNumberController = TextEditingController();
  final _ownerNameController = TextEditingController();
  final _pharmacistNameController = TextEditingController();
  final _genderController = TextEditingController();
  final _dateOfBirthController = TextEditingController();

  // Form values
  bool _homeDelivery = false;
  List<String> _selectedServices = [];
  List<String> _selectedDrugs = [];
  bool _isUploadingImage = false;
  String _selectedGender = 'Male';
  DateTime? _selectedDateOfBirth;

  final List<String> _availableServices = [
    'Prescription Medicines',
    'Over-the-Counter Medicines',
    'Health Supplements',
    'Medical Devices',
    'First Aid Supplies',
    'Baby Care Products',
    'Personal Care Products',
    'Home Health Care',
    'Chronic Disease Management',
    'Vaccination Services',
    'Health Consultations',
    'Medicine Delivery',
    'Emergency Medicine Supply',
    'Compounding Services',
    'Health Monitoring',
  ];

  final List<String> _availableDrugs = [
    'Prescription Drugs',
    'Over-the-Counter (OTC)',
    'Generic Medicines',
    'Branded Medicines',
    'Ayurvedic Medicines',
    'Homeopathic Medicines',
    'Health Supplements',
    'Vitamins & Minerals',
    'Herbal Products',
    'Medical Devices',
    'Surgical Supplies',
    'Diagnostic Kits',
  ];

  @override
  void initState() {
    super.initState();
    _pharmacy = widget.pharmacy;
    _profileImageUrl = _pharmacy.profileImageUrl;
    _initializeForm();
  }

  void _initializeForm() {
    _pharmacyNameController.text = _pharmacy.fullName ?? '';
    _emailController.text = _pharmacy.email ?? '';
    _phoneController.text = _pharmacy.mobileNumber ?? '';
    _altPhoneController.text = _pharmacy.alternateMobile ?? '';
    _addressController.text = _pharmacy.address ?? '';
    _cityController.text = _pharmacy.city ?? '';
    _stateController.text = _pharmacy.state ?? '';
    _pincodeController.text = _pharmacy.pincode ?? '';
    _licenseNumberController.text = _pharmacy.licenseNumber ?? '';
    _ownerNameController.text = _pharmacy.ownerName ?? '';
    _pharmacistNameController.text = _pharmacy.pharmacistName ?? '';
    _genderController.text = _pharmacy.gender ?? 'Male';
    _selectedGender = _pharmacy.gender ?? 'Male';
    _selectedDateOfBirth = _pharmacy.dateOfBirth;
    if (_selectedDateOfBirth != null) {
      _dateOfBirthController.text =
          '${_selectedDateOfBirth!.day}/${_selectedDateOfBirth!.month}/${_selectedDateOfBirth!.year}';
    }

    _homeDelivery = _pharmacy.homeDelivery ?? false;
    _selectedServices =
        List<String>.from(_pharmacy.pharmacyServicesProvided ?? []);
    _selectedDrugs = List<String>.from(_pharmacy.drugsAvailable ?? []);
  }

  Future<void> _pickAndUploadProfileImage() async {
    try {
      final pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );

      if (pickedFile == null) return;

      setState(() {
        _isUploadingImage = true;
      });

      // Upload to Firebase Storage
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('pharmacy_profile_images/${_pharmacy.uid}.jpg');

      // Convert to bytes for better compatibility
      final bytes = await pickedFile.readAsBytes();
      final metadata = SettableMetadata(
        contentType: 'image/jpeg',
        customMetadata: {
          'pharmacy_uid': _pharmacy.uid,
          'uploaded_at': DateTime.now().toIso8601String(),
        },
      );

      await storageRef.putData(bytes, metadata);
      final url = await storageRef.getDownloadURL();

      setState(() {
        _profileImageUrl = url;
        _isUploadingImage = false;
      });

      // Don't show success message here - only after profile update
    } catch (e) {
      setState(() {
        _isUploadingImage = false;
      });
      print('❌ Error uploading profile image: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update profile image: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _updateProfile() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final updateData = {
        'fullName': _pharmacyNameController.text.trim(),
        'pharmacyName': _pharmacyNameController.text.trim(),
        'email': _emailController.text.trim(),
        'pharmacistName': _pharmacistNameController.text.trim(),
        'mobileNumber': _phoneController.text.trim(),
        'alternateMobile': _altPhoneController.text.trim().isEmpty
            ? null
            : _altPhoneController.text.trim(),
        'address': _addressController.text.trim(),
        'city': _cityController.text.trim(),
        'state': _stateController.text.trim(),
        'pincode': _pincodeController.text.trim(),
        'gender': _selectedGender,
        'dateOfBirth': _selectedDateOfBirth?.toIso8601String(),
        'servicesProvided': _selectedServices,
        'drugsAvailable': _selectedDrugs,
        'homeDelivery': _homeDelivery,
        if (_profileImageUrl != null) 'profileImageUrl': _profileImageUrl,
      };

      final success =
          await ApiService.updatePharmacyProfile(_pharmacy.uid, updateData);

      if (success) {
        // Save profile image URL to SharedPreferences
        if (_profileImageUrl != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(
              'pharmacy_profile_image_url', _profileImageUrl!);
        }

        String successMessage = 'Profile updated successfully!';
        if (_profileImageUrl != null) {
          successMessage = 'Profile and image updated successfully!';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(successMessage),
            backgroundColor: Colors.green,
          ),
        );

        Navigator.of(context).pop(true);
      } else {
        throw Exception('Failed to update profile');
      }
    } catch (e) {
      print('❌ Error updating profile: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update profile: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(
        title: Text(
          'Update Profile',
          style: GoogleFonts.poppins(
              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [kPharmacyOrange, Color(0xFFE65100)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _updateProfile,
            child: Text(
              'Save',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
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
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Loading pharmacy profile...',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Profile Image Section
                  Stack(
                    children: [
                      GestureDetector(
                        onTap: _isUploadingImage
                            ? null
                            : _pickAndUploadProfileImage,
                        child: AnimatedOpacity(
                          opacity: _isUploadingImage ? 0.6 : 1.0,
                          duration: const Duration(milliseconds: 200),
                          child: CircleAvatar(
                            radius: 50,
                            backgroundColor: kPharmacyOrange,
                            backgroundImage:
                                (_profileImageUrl?.isNotEmpty ?? false)
                                    ? NetworkImage(_profileImageUrl!)
                                    : null,
                            child: (_profileImageUrl?.isEmpty ?? true)
                                ? Text(
                                    (_pharmacy.fullName?.isNotEmpty ?? false)
                                        ? _pharmacy.fullName![0].toUpperCase()
                                        : '?',
                                    style: GoogleFonts.poppins(
                                      color: Colors.white,
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  )
                                : null,
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          decoration: BoxDecoration(
                            color: kPharmacyOrange,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: _isUploadingImage
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white),
                                  ),
                                )
                              : const Icon(
                                  Icons.camera_alt,
                                  color: Colors.white,
                                  size: 20,
                                ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // Basic Information Card
                  _buildInfoCard(
                    'Basic Information',
                    [
                      _buildTextField(
                          _pharmacyNameController, 'Pharmacy Name', Icons.home),
                      _buildTextField(_emailController, 'Email', Icons.email,
                          keyboardType: TextInputType.emailAddress),
                      _buildTextField(_pharmacistNameController,
                          'Pharmacist Name', Icons.medical_services),
                      _buildGenderDropdown(),
                      _buildDateOfBirthField(),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Contact Information Card
                  _buildInfoCard(
                    'Contact Information',
                    [
                      _buildTextField(
                          _phoneController, 'Phone Number', Icons.phone,
                          keyboardType: TextInputType.phone),
                      _buildTextField(
                          _altPhoneController, 'Alternate Phone', Icons.phone,
                          keyboardType: TextInputType.phone, required: false),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Address Information Card
                  _buildInfoCard(
                    'Address Information',
                    [
                      _buildTextField(
                          _addressController, 'Address', Icons.location_on),
                      _buildTextField(
                          _cityController, 'City', Icons.location_city),
                      _buildTextField(_stateController, 'State', Icons.map),
                      _buildTextField(
                          _pincodeController, 'Pincode', Icons.pin_drop,
                          keyboardType: TextInputType.number),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Services and Drugs Card
                  _buildInfoCard(
                    'Services & Products',
                    [
                      _buildServicesSelector(),
                      _buildDrugsSelector(),
                      _buildSwitchField(
                          'Home Delivery Available', _homeDelivery, (value) {
                        setState(() {
                          _homeDelivery = value;
                        });
                      }),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Professional Information Card (Read-Only)
                  _buildInfoCard(
                    'Professional Information (Read-Only)',
                    [
                      _buildReadOnlyField('License Number',
                          _pharmacy.licenseNumber ?? 'N/A', Icons.verified),
                      _buildReadOnlyField('Owner Name',
                          _pharmacy.ownerName ?? 'N/A', Icons.person),
                      _buildContactStaffMessage(),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // Update Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _updateProfile,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kPharmacyOrange,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text(
                              'Update Profile',
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildInfoCard(String title, List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: kPrimaryText,
            ),
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildTextField(
      TextEditingController controller, String label, IconData icon,
      {TextInputType? keyboardType, bool required = true}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: kPharmacyOrange),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: kBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: kBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: kPharmacyOrange, width: 2),
          ),
        ),
        validator: required
            ? (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter $label';
                }
                return null;
              }
            : null,
      ),
    );
  }

  Widget _buildGenderDropdown() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: DropdownButtonFormField<String>(
        value: _selectedGender,
        decoration: InputDecoration(
          labelText: 'Gender',
          prefixIcon: Icon(Icons.person, color: kPharmacyOrange),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: kBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: kBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: kPharmacyOrange, width: 2),
          ),
        ),
        items: ['Male', 'Female', 'Other'].map((String gender) {
          return DropdownMenuItem<String>(
            value: gender,
            child: Text(gender),
          );
        }).toList(),
        onChanged: (String? newValue) {
          setState(() {
            _selectedGender = newValue!;
            _genderController.text = newValue;
          });
        },
      ),
    );
  }

  Widget _buildDateOfBirthField() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: _dateOfBirthController,
        readOnly: true,
        decoration: InputDecoration(
          labelText: 'Date of Birth',
          prefixIcon: Icon(Icons.calendar_today, color: kPharmacyOrange),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: kBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: kBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: kPharmacyOrange, width: 2),
          ),
          suffixIcon: IconButton(
            icon: Icon(Icons.calendar_today, color: kPharmacyOrange),
            onPressed: _selectDateOfBirth,
          ),
        ),
        onTap: _selectDateOfBirth,
      ),
    );
  }

  Future<void> _selectDateOfBirth() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDateOfBirth ?? DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDateOfBirth) {
      setState(() {
        _selectedDateOfBirth = picked;
        _dateOfBirthController.text =
            '${picked.day}/${picked.month}/${picked.year}';
      });
    }
  }

  Widget _buildServicesSelector() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Services Provided',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: kPrimaryText,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _availableServices.map((service) {
              final isSelected = _selectedServices.contains(service);
              return FilterChip(
                label: Text(service),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _selectedServices.add(service);
                    } else {
                      _selectedServices.remove(service);
                    }
                  });
                },
                selectedColor: kPharmacyOrange.withOpacity(0.2),
                checkmarkColor: kPharmacyOrange,
                side: BorderSide(
                  color: isSelected ? kPharmacyOrange : kBorder,
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildDrugsSelector() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Types of Drugs Available',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: kPrimaryText,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _availableDrugs.map((drug) {
              final isSelected = _selectedDrugs.contains(drug);
              return FilterChip(
                label: Text(drug),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _selectedDrugs.add(drug);
                    } else {
                      _selectedDrugs.remove(drug);
                    }
                  });
                },
                selectedColor: kPharmacyOrange.withOpacity(0.2),
                checkmarkColor: kPharmacyOrange,
                side: BorderSide(
                  color: isSelected ? kPharmacyOrange : kBorder,
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchField(String label, bool value, Function(bool) onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: kPrimaryText,
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: kPharmacyOrange,
          ),
        ],
      ),
    );
  }

  Widget _buildReadOnlyField(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        initialValue: value,
        enabled: false,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: Colors.grey),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          disabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          filled: true,
          fillColor: Colors.grey.shade100,
        ),
      ),
    );
  }

  Widget _buildContactStaffMessage() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kPharmacyOrange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: kPharmacyOrange.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: kPharmacyOrange, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'To update license, address, or other professional information, please contact our support staff.',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: kPharmacyOrange,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
