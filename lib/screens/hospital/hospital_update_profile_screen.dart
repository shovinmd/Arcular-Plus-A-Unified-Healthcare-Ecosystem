import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import '../../models/user_model.dart';
import '../../services/api_service.dart';
import '../../services/storage_service.dart';
import '../../utils/gender_image_helper.dart';

class HospitalUpdateProfileScreen extends StatefulWidget {
  final UserModel hospital;
  const HospitalUpdateProfileScreen({super.key, required this.hospital});

  @override
  State<HospitalUpdateProfileScreen> createState() =>
      _HospitalUpdateProfileScreenState();
}

class _HospitalUpdateProfileScreenState
    extends State<HospitalUpdateProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  // Controllers
  late TextEditingController _fullNameController;
  late TextEditingController _hospitalNameController;
  late TextEditingController _registrationNumberController;
  late TextEditingController _hospitalAddressController;
  late TextEditingController _hospitalEmailController;
  late TextEditingController _hospitalPhoneController;
  late TextEditingController _numberOfBedsController;
  late TextEditingController _mobileNumberController;
  late TextEditingController _alternateMobileController;
  late TextEditingController _addressController;
  late TextEditingController _cityController;
  late TextEditingController _stateController;
  late TextEditingController _pincodeController;
  late TextEditingController _longitudeController;
  late TextEditingController _latitudeController;

  // Gender selection
  String? _selectedGender;

  // Document upload variables
  File? _selectedImage;
  String? _profileImageUrl;
  File? _licenseDocument;
  String? _licenseDocumentUrl;
  File? _registrationCertificate;
  String? _registrationCertificateUrl;
  File? _buildingPermit;
  String? _buildingPermitUrl;
  final ImagePicker _picker = ImagePicker();

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
    'Public',
    'Private',
    'Super-Specialty',
    'Medical College',
    'Research Institute',
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
    _selectedGender = widget.hospital.gender;
    // Ensure gender is one of the valid options or null
    if (_selectedGender != null &&
        !['Male', 'Female', 'Other'].contains(_selectedGender)) {
      _selectedGender = null;
    }
    _profileImageUrl = widget.hospital.profileImageUrl;
    _licenseDocumentUrl = widget.hospital.licenseDocumentUrl;
    _registrationCertificateUrl = widget.hospital.registrationCertificateUrl;
    _buildingPermitUrl = widget.hospital.buildingPermitUrl;
  }

  void _initializeControllers() {
    _fullNameController =
        TextEditingController(text: widget.hospital.hospitalOwnerName ?? '');
    _hospitalNameController =
        TextEditingController(text: widget.hospital.hospitalName ?? '');
    _registrationNumberController =
        TextEditingController(text: widget.hospital.registrationNumber ?? '');
    _hospitalAddressController =
        TextEditingController(text: widget.hospital.hospitalAddress ?? '');
    _hospitalEmailController = TextEditingController(
        text: widget.hospital.email ?? widget.hospital.hospitalEmail ?? '');
    _hospitalPhoneController = TextEditingController(
        text: widget.hospital.hospitalPhone ??
            widget.hospital.mobileNumber ??
            '');
    _numberOfBedsController = TextEditingController(
        text: widget.hospital.numberOfBeds?.toString() ?? '');
    _mobileNumberController =
        TextEditingController(text: widget.hospital.mobileNumber ?? '');
    _alternateMobileController = TextEditingController(
        text: widget.hospital.alternateMobile ??
            widget.hospital.altPhoneNumber ??
            '');
    _addressController =
        TextEditingController(text: widget.hospital.address ?? '');
    _cityController = TextEditingController(text: widget.hospital.city ?? '');
    _stateController = TextEditingController(text: widget.hospital.state ?? '');
    _pincodeController =
        TextEditingController(text: widget.hospital.pincode ?? '');
    _longitudeController = TextEditingController(
        text: widget.hospital.longitude?.toString() ?? '');
    _latitudeController =
        TextEditingController(text: widget.hospital.latitude?.toString() ?? '');

    _selectedHospitalType = widget.hospital.hospitalType ?? 'Hospital';
    // Ensure the hospital type is in our list, if not use the first available type
    if (!_hospitalTypes.contains(_selectedHospitalType)) {
      _selectedHospitalType = _hospitalTypes.first;
    }
    _hasPharmacy = widget.hospital.hasPharmacy ?? false;
    _hasLab = widget.hospital.hasLab ?? false;
    _selectedDepartments = widget.hospital.departments ?? [];
    _selectedSpecialFacilities = widget.hospital.specialFacilities ?? [];
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _hospitalNameController.dispose();
    _registrationNumberController.dispose();
    _hospitalAddressController.dispose();
    _hospitalEmailController.dispose();
    _hospitalPhoneController.dispose();
    _numberOfBedsController.dispose();
    _mobileNumberController.dispose();
    _alternateMobileController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _pincodeController.dispose();
    _longitudeController.dispose();
    _latitudeController.dispose();
    super.dispose();
  }

  Future<void> _pickProfileImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
    }
  }

  Future<void> _updateProfile() async {
    print('🏥 Hospital Update Screen - Form validation starting...');

    if (!_formKey.currentState!.validate()) {
      print('❌ Form validation failed');
      return;
    }

    print('✅ Form validation passed');

    setState(() {
      _isLoading = true;
    });

    String? imageUrl = _profileImageUrl;
    String? licenseUrl = _licenseDocumentUrl;
    String? registrationUrl = _registrationCertificateUrl;
    String? buildingPermitUrl = _buildingPermitUrl;

    try {
      // Upload profile image if selected
      if (_selectedImage != null) {
        try {
          final storageService = StorageService();
          final imageBytes = await _selectedImage!.readAsBytes();
          final uploadedUrl = await storageService.uploadProfilePicture(
            userId: widget.hospital.uid,
            userType: 'hospital',
            imageBytes: imageBytes,
          );
          if (uploadedUrl != null) {
            imageUrl = uploadedUrl;
          }
        } catch (e) {
          print('Profile image upload failed: $e');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content:
                    Text('Profile image upload failed. Please try again.')),
          );
          setState(() => _isLoading = false);
          return;
        }
      }

      // Upload license document if selected
      if (_licenseDocument != null) {
        try {
          final storageService = StorageService();
          final imageBytes = await _licenseDocument!.readAsBytes();
          final uploadedUrl = await storageService.uploadCertificate(
            userId: widget.hospital.uid,
            userType: 'hospital',
            certificateType: 'license_document',
            fileName: 'license_document.jpg',
            fileBytes: imageBytes,
          );
          if (uploadedUrl != null) {
            licenseUrl = uploadedUrl;
          }
        } catch (e) {
          print('License document upload failed: $e');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content:
                    Text('License document upload failed. Please try again.')),
          );
          setState(() => _isLoading = false);
          return;
        }
      }

      // Upload registration certificate if selected
      if (_registrationCertificate != null) {
        try {
          final storageService = StorageService();
          final imageBytes = await _registrationCertificate!.readAsBytes();
          final uploadedUrl = await storageService.uploadCertificate(
            userId: widget.hospital.uid,
            userType: 'hospital',
            certificateType: 'registration_certificate',
            fileName: 'registration_certificate.jpg',
            fileBytes: imageBytes,
          );
          if (uploadedUrl != null) {
            registrationUrl = uploadedUrl;
          }
        } catch (e) {
          print('Registration certificate upload failed: $e');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text(
                    'Registration certificate upload failed. Please try again.')),
          );
          setState(() => _isLoading = false);
          return;
        }
      }

      // Upload building permit if selected
      if (_buildingPermit != null) {
        try {
          final storageService = StorageService();
          final imageBytes = await _buildingPermit!.readAsBytes();
          final uploadedUrl = await storageService.uploadCertificate(
            userId: widget.hospital.uid,
            userType: 'hospital',
            certificateType: 'building_permit',
            fileName: 'building_permit.jpg',
            fileBytes: imageBytes,
          );
          if (uploadedUrl != null) {
            buildingPermitUrl = uploadedUrl;
          }
        } catch (e) {
          print('Building permit upload failed: $e');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content:
                    Text('Building permit upload failed. Please try again.')),
          );
          setState(() => _isLoading = false);
          return;
        }
      }

      final updates = {
        'hospitalOwnerName': _fullNameController.text.trim(),
        'hospitalName': _hospitalNameController.text.trim(),
        'registrationNumber': _registrationNumberController.text.trim(),
        'hospitalType': _selectedHospitalType,
        'gender': _selectedGender,
        'hospitalAddress': _hospitalAddressController.text.trim(),
        'email': _hospitalEmailController.text.trim(),
        'hospitalEmail': _hospitalEmailController.text.trim(),
        'hospitalPhone': _hospitalPhoneController.text.trim(),
        'numberOfBeds': int.tryParse(_numberOfBedsController.text.trim()) ?? 0,
        'hasPharmacy': _hasPharmacy,
        'hasLab': _hasLab,
        'departments': _selectedDepartments,
        'specialFacilities': _selectedSpecialFacilities,
        'mobileNumber': _mobileNumberController.text.trim(),
        'alternateMobile': _alternateMobileController.text.trim().isEmpty
            ? null
            : _alternateMobileController.text.trim(),
        'address': _addressController.text.trim(),
        'city': _cityController.text.trim(),
        'state': _stateController.text.trim(),
        'pincode': _pincodeController.text.trim(),
        'longitude': _longitudeController.text.trim().isEmpty
            ? null
            : double.tryParse(_longitudeController.text.trim()),
        'latitude': _latitudeController.text.trim().isEmpty
            ? null
            : double.tryParse(_latitudeController.text.trim()),
        'profileImageUrl': imageUrl,
        'licenseDocumentUrl': licenseUrl,
        'registrationCertificateUrl': registrationUrl,
        'buildingPermitUrl': buildingPermitUrl,
      };

      print('🏥 Hospital Update Screen - Starting update...');
      print('🏥 Hospital UID: ${widget.hospital.uid}');
      print('🏥 Updates payload: $updates');

      final success =
          await ApiService.updateHospitalProfile(widget.hospital.uid, updates);

      print('🏥 Hospital Update Screen - API call result: $success');

      if (mounted) {
        if (success) {
          // Save gender to SharedPreferences for loading screen
          if (_selectedGender != null) {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('user_gender', _selectedGender!);
          }

          await _showCustomPopup(
              success: true, message: 'Hospital profile updated successfully!');
          Navigator.pop(context, true); // Return true to indicate success
        } else {
          await _showCustomPopup(
              success: false,
              message: 'Failed to update hospital profile. Please try again.');
        }
      }
    } catch (e) {
      if (mounted) {
        await _showCustomPopup(
            success: false,
            message: 'Error updating hospital profile: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _showCustomPopup(
      {required bool success, required String message}) async {
    final prefs = await SharedPreferences.getInstance();
    final userType = prefs.getString('user_type') ?? 'hospital';

    String imagePath;
    List<Color> gradientColors;

    if (success) {
      imagePath = 'assets/images/hospital/love.png'; // Hospital success image
    } else {
      imagePath = 'assets/images/hospital/angry.png'; // Hospital error image
    }

    // Role-based gradient colors for hospital
    gradientColors = success
        ? [const Color(0xFF4CAF50), const Color(0xFF81C784)] // Hospital green
        : [Colors.red[400]!, Colors.red[600]!];

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        content: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: gradientColors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                imagePath,
                width: 80,
                height: 80,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return Icon(
                    success ? Icons.check_circle : Icons.error,
                    size: 80,
                    color: Colors.white,
                  );
                },
              ),
              const SizedBox(height: 16),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Update Hospital Profile',
            style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18)),
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF2E7D32), Color(0xFF1B5E20)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Profile Image Upload Section
              _sectionTitle('Profile Image'),
              Center(
                child: GestureDetector(
                  onTap: _pickProfileImage,
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border:
                          Border.all(color: const Color(0xFF2E7D32), width: 3),
                      color: Colors.grey[100],
                    ),
                    child: _selectedImage != null
                        ? ClipOval(
                            child: Image.file(
                              _selectedImage!,
                              fit: BoxFit.cover,
                              width: 120,
                              height: 120,
                            ),
                          )
                        : _profileImageUrl != null &&
                                _profileImageUrl!.isNotEmpty
                            ? ClipOval(
                                child: Image.network(
                                  _profileImageUrl!,
                                  fit: BoxFit.cover,
                                  width: 120,
                                  height: 120,
                                  errorBuilder: (context, error, stackTrace) {
                                    return const Icon(Icons.local_hospital,
                                        size: 60, color: Color(0xFF2E7D32));
                                  },
                                ),
                              )
                            : const Icon(Icons.local_hospital,
                                size: 60, color: Color(0xFF2E7D32)),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  'Tap to change profile image',
                  style: GoogleFonts.poppins(
                    color: const Color(0xFF2E7D32),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              _sectionTitle('Basic Information'),
              _textField('Hospital Owner Name', _fullNameController, true),
              _genderDropdown(),
              _readOnlyField('Hospital Name', _hospitalNameController.text,
                  'For updating please contact staff'),
              _readOnlyField(
                  'Registration Number',
                  _registrationNumberController.text,
                  'For updating please contact staff'),
              _readOnlyField('Hospital Type', _selectedHospitalType,
                  'For updating please contact staff'),
              const SizedBox(height: 16),

              _sectionTitle('Contact Information'),
              _readOnlyField('Hospital Name', _hospitalNameController.text,
                  'For updating please contact staff'),
              _textField('Hospital Email', _hospitalEmailController, true),
              _textField('Hospital Phone', _hospitalPhoneController, true),
              _textField('Alternate Mobile', _alternateMobileController, false),
              const SizedBox(height: 16),

              _sectionTitle('Location Information'),
              _readOnlyField('Address', _addressController.text,
                  'For updating please contact staff'),
              _readOnlyField('City', _cityController.text,
                  'For updating please contact staff'),
              _readOnlyField('State', _stateController.text,
                  'For updating please contact staff'),
              _readOnlyField('Pincode', _pincodeController.text,
                  'For updating please contact staff'),
              _readOnlyField('Longitude', _longitudeController.text,
                  'For updating please contact staff'),
              _readOnlyField('Latitude', _latitudeController.text,
                  'For updating please contact staff'),
              const SizedBox(height: 16),

              _sectionTitle('Hospital Details'),
              _textField('Number of Beds', _numberOfBedsController, false,
                  TextInputType.number),
              const SizedBox(height: 16),

              _sectionTitle('Facilities'),
              _checkboxField('Has Pharmacy', _hasPharmacy, (value) {
                setState(() {
                  _hasPharmacy = value!;
                });
              }),
              _checkboxField('Has Lab', _hasLab, (value) {
                setState(() {
                  _hasLab = value!;
                });
              }),
              const SizedBox(height: 16),

              _sectionTitle('Departments'),
              _multiSelectField('Select Departments', _selectedDepartments,
                  _availableDepartments, (values) {
                setState(() {
                  _selectedDepartments = values;
                });
              }),
              const SizedBox(height: 16),

              _sectionTitle('Special Facilities'),
              _multiSelectField(
                  'Select Special Facilities',
                  _selectedSpecialFacilities,
                  _availableSpecialFacilities, (values) {
                setState(() {
                  _selectedSpecialFacilities = values;
                });
              }),
              const SizedBox(height: 24),

              // Documents Upload Section
              _sectionTitle('Required Documents'),

              // License Document - Read Only
              _readOnlyDocumentField(
                'License Document',
                _licenseDocumentUrl,
                'For updating please contact staff',
              ),
              const SizedBox(height: 16),

              // Registration Certificate - Read Only
              _readOnlyDocumentField(
                'Registration Certificate',
                _registrationCertificateUrl,
                'For updating please contact staff',
              ),
              const SizedBox(height: 16),

              // Building Permit - Read Only
              _readOnlyDocumentField(
                'Building Permit',
                _buildingPermitUrl,
                'For updating please contact staff',
              ),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _updateProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E7D32),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Update Profile',
                          style: TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text,
          style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF2E7D32))),
    );
  }

  Widget _textField(
      String label, TextEditingController controller, bool isRequired,
      [TextInputType? keyboardType]) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
        validator: isRequired
            ? (value) =>
                value?.isEmpty == true ? 'This field is required' : null
            : null,
      ),
    );
  }

  Widget _checkboxField(String label, bool value, Function(bool?) onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: CheckboxListTile(
        title: Text(label),
        value: value,
        onChanged: onChanged,
        controlAffinity: ListTileControlAffinity.leading,
      ),
    );
  }

  Widget _multiSelectField(String label, List<String> selectedValues,
      List<String> availableValues, Function(List<String>) onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _showMultiSelectDialog(
            label, selectedValues, availableValues, onChanged),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: GoogleFonts.poppins(
                      fontSize: 14, color: Colors.grey[700])),
              const SizedBox(height: 8),
              Text(
                selectedValues.isEmpty
                    ? 'No items selected'
                    : selectedValues.join(', '),
                style: GoogleFonts.poppins(fontSize: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMultiSelectDialog(String title, List<String> selectedValues,
      List<String> availableValues, Function(List<String>) onChanged) {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(title),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: availableValues.map((item) {
                return CheckboxListTile(
                  title: Text(item),
                  value: selectedValues.contains(item),
                  onChanged: (bool? value) {
                    setState(() {
                      if (value == true) {
                        selectedValues.add(item);
                      } else {
                        selectedValues.remove(item);
                      }
                    });
                  },
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                onChanged(selectedValues);
                Navigator.pop(context);
              },
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _readOnlyField(String label, String value, String message) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    value.isEmpty ? 'Not provided' : value,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      color: value.isEmpty ? Colors.grey[500] : Colors.black87,
                    ),
                  ),
                ),
                Icon(
                  Icons.lock,
                  color: Colors.grey[500],
                  size: 16,
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            message,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: Colors.orange[700],
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _readOnlyDocumentField(
      String title, String? documentUrl, String message) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Row(
            children: [
              Icon(
                Icons.description,
                color: Colors.grey[500],
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  documentUrl != null && documentUrl.isNotEmpty
                      ? 'Document uploaded'
                      : 'No document uploaded',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    color: documentUrl != null && documentUrl.isNotEmpty
                        ? Colors.green[700]
                        : Colors.grey[500],
                  ),
                ),
              ),
              Icon(
                Icons.lock,
                color: Colors.grey[500],
                size: 16,
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          message,
          style: GoogleFonts.poppins(
            fontSize: 12,
            color: Colors.orange[700],
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }

  Widget _genderDropdown() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        value: _selectedGender,
        decoration: InputDecoration(
          labelText: 'Gender',
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          prefixIcon: const Icon(Icons.person, color: Color(0xFF2E7D32)),
        ),
        items: const [
          DropdownMenuItem(value: 'Male', child: Text('Male')),
          DropdownMenuItem(value: 'Female', child: Text('Female')),
          DropdownMenuItem(value: 'Other', child: Text('Other')),
        ],
        onChanged: (value) {
          setState(() {
            _selectedGender = value;
          });
        },
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Please select gender';
          }
          return null;
        },
        hint: const Text('Select Gender'),
      ),
    );
  }
}
