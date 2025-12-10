import 'package:flutter/material.dart';
import 'package:arcular_plus/models/user_model.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../services/api_service.dart';
import '../../services/storage_service.dart';

// Add color constants at the top
const Color kBackground = Color(0xFFF9FAFB);
const Color kPrimaryText = Color(0xFF2E2E2E);
const Color kSecondaryText = Color(0xFF6B7280);
const Color kBorder = Color(0xFFE5E7EB);
const Color kSuccess = Color(0xFFA3E635);
const Color kDoctorBlue = Color(0xFF1976D2);

class DoctorUpdateProfileScreen extends StatefulWidget {
  final UserModel doctor;
  const DoctorUpdateProfileScreen({super.key, required this.doctor});

  @override
  State<DoctorUpdateProfileScreen> createState() =>
      _DoctorUpdateProfileScreenState();
}

class _DoctorUpdateProfileScreenState extends State<DoctorUpdateProfileScreen> {
  late UserModel _doctor;
  final ImagePicker _picker = ImagePicker();
  String? _profileImageUrl;
  File? _selectedImage;
  bool _isLoading = false;
  final _formKey = GlobalKey<FormState>();

  // Form controllers
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _mobileController = TextEditingController();
  final _altMobileController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _pincodeController = TextEditingController();
  final _specializationController = TextEditingController();
  final _medicalRegistrationController = TextEditingController();
  final _licenseNumberController = TextEditingController();
  final _experienceController = TextEditingController();
  final _consultationFeeController = TextEditingController();
  final _qualificationController = TextEditingController();

  // Form values
  String _selectedGender = 'Male';
  DateTime? _selectedDateOfBirth;
  String _selectedBloodGroup = 'A+';

  @override
  void initState() {
    super.initState();
    _doctor = widget.doctor;
    _profileImageUrl = _doctor.profileImageUrl;
    _initializeForm();
  }

  void _initializeForm() {
    _fullNameController.text = _doctor.fullName ?? '';
    _emailController.text = _doctor.email ?? '';
    _mobileController.text = _doctor.mobileNumber ?? '';
    _altMobileController.text = _doctor.altPhoneNumber ?? '';
    _addressController.text = _doctor.address ?? '';
    _cityController.text = _doctor.city ?? '';
    _stateController.text = _doctor.state ?? '';
    _pincodeController.text = _doctor.pincode ?? '';
    _specializationController.text = _doctor.specialization ?? '';
    _medicalRegistrationController.text =
        _doctor.medicalRegistrationNumber ?? '';
    _licenseNumberController.text = _doctor.licenseNumber ?? '';
    _experienceController.text = (_doctor.experienceYears ?? 0).toString();
    _consultationFeeController.text = (_doctor.consultationFee ?? 0).toString();
    _qualificationController.text = _doctor.qualification ?? '';

    _selectedGender = _doctor.gender ?? 'Male';
    _selectedBloodGroup = _doctor.bloodGroup ?? 'A+';

    if (_doctor.dateOfBirth != null) {
      _selectedDateOfBirth = _doctor.dateOfBirth;
    }
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
    print('👨‍⚕️ Doctor Update Screen - Form validation starting...');

    if (!_formKey.currentState!.validate()) {
      print('❌ Form validation failed');
      return;
    }

    print('✅ Form validation passed');

    setState(() {
      _isLoading = true;
    });

    String? imageUrl = _profileImageUrl;

    try {
      // Upload profile image if selected
      if (_selectedImage != null) {
        try {
          final storageService = StorageService();
          final imageBytes = await _selectedImage!.readAsBytes();
          final uploadedUrl = await storageService.uploadProfilePicture(
            userId: _doctor.uid,
            userType: 'doctor',
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

      final updates = {
        'fullName': _fullNameController.text.trim(),
        'email': _emailController.text.trim(),
        'mobileNumber': _mobileController.text.trim(),
        'altPhoneNumber': _altMobileController.text.trim().isEmpty
            ? null
            : _altMobileController.text.trim(),
        'address': _addressController.text.trim(),
        'city': _cityController.text.trim(),
        'state': _stateController.text.trim(),
        'pincode': _pincodeController.text.trim(),
        'specialization': _specializationController.text.trim(),
        'medicalRegistrationNumber': _medicalRegistrationController.text.trim(),
        'licenseNumber': _licenseNumberController.text.trim(),
        'experienceYears': int.tryParse(_experienceController.text) ?? 0,
        'consultationFee':
            double.tryParse(_consultationFeeController.text) ?? 0.0,
        'qualification': _qualificationController.text.trim(),
        'gender': _selectedGender,
        'bloodGroup': _selectedBloodGroup,
        'dateOfBirth': _selectedDateOfBirth?.toIso8601String(),
        'profileImageUrl': imageUrl,
      };

      print('👨‍⚕️ Doctor Update Screen - Starting update...');
      print('👨‍⚕️ Doctor UID: ${_doctor.uid}');
      print('👨‍⚕️ Updates payload: $updates');

      final success =
          await ApiService.updateDoctorProfile(_doctor.uid, updates);

      print('👨‍⚕️ Doctor Update Screen - API call result: $success');

      if (mounted) {
        if (success) {
          await _showCustomPopup(
              success: true, message: 'Doctor profile updated successfully!');
          Navigator.pop(context, true); // Return true to indicate success
        } else {
          await _showCustomPopup(
              success: false,
              message: 'Failed to update doctor profile. Please try again.');
        }
      }
    } catch (e) {
      if (mounted) {
        await _showCustomPopup(
            success: false,
            message: 'Error updating doctor profile: ${e.toString()}');
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
              colors: [kDoctorBlue, Color(0xFF0D47A1)],
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
                      border: Border.all(color: kDoctorBlue, width: 3),
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
                                    return const Icon(Icons.person,
                                        size: 60, color: kDoctorBlue);
                                  },
                                ),
                              )
                            : const Icon(Icons.person,
                                size: 60, color: kDoctorBlue),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  'Tap to change profile image',
                  style: GoogleFonts.poppins(
                    color: kDoctorBlue,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              _sectionTitle('Basic Information'),
              _textField('Full Name', _fullNameController, true),
              _textField(
                  'Email', _emailController, true, TextInputType.emailAddress),
              _textField('Mobile Number', _mobileController, true,
                  TextInputType.phone),
              _textField('Alternate Mobile', _altMobileController, false,
                  TextInputType.phone),
              _dropdownField(
                  'Gender', _selectedGender, ['Male', 'Female', 'Other'],
                  (value) {
                setState(() {
                  _selectedGender = value!;
                });
              }),
              _dateField('Date of Birth', _selectedDateOfBirth, (date) {
                setState(() {
                  _selectedDateOfBirth = date;
                });
              }),
              _dropdownField('Blood Group', _selectedBloodGroup,
                  ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'], (value) {
                setState(() {
                  _selectedBloodGroup = value!;
                });
              }),
              const SizedBox(height: 16),

              _sectionTitle('Professional Information'),
              _textField('Specialization', _specializationController, true),
              _textField('Medical Registration Number',
                  _medicalRegistrationController, true),
              _textField('License Number', _licenseNumberController, true),
              _textField('Experience (Years)', _experienceController, true,
                  TextInputType.number),
              _textField('Consultation Fee', _consultationFeeController, true,
                  TextInputType.number),
              _textField('Qualification', _qualificationController, true),
              const SizedBox(height: 16),

              _sectionTitle('Address Information'),
              _textField('Address', _addressController, true),
              _textField('City', _cityController, true),
              _textField('State', _stateController, true),
              _textField(
                  'Pincode', _pincodeController, true, TextInputType.number),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _updateProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kDoctorBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Update Profile',
                          style: TextStyle(fontSize: 16)),
                ),
              ),
              const SizedBox(height: 16),

              // License and File Update Note
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange[200]!),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Colors.orange[600],
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Note: License and document updates require staff verification. Changes will be reviewed and approved by our team.',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.orange[800],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
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

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: GoogleFonts.poppins(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: kDoctorBlue,
        ),
      ),
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

  Widget _dropdownField(String label, String value, List<String> items,
      Function(String?) onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        value: value,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
        items: items.map((String item) {
          return DropdownMenuItem<String>(
            value: item,
            child: Text(item),
          );
        }).toList(),
        onChanged: onChanged,
      ),
    );
  }

  Widget _dateField(
      String label, DateTime? value, Function(DateTime?) onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () async {
          final date = await showDatePicker(
            context: context,
            initialDate:
                value ?? DateTime.now().subtract(const Duration(days: 10950)),
            firstDate: DateTime(1900),
            lastDate: DateTime.now(),
          );
          if (date != null) {
            onChanged(date);
          }
        },
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: Text(
            value != null
                ? '${value.day}/${value.month}/${value.year}'
                : 'Select Date',
            style: GoogleFonts.poppins(
              color: value != null ? Colors.black87 : Colors.grey[500],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showCustomPopup(
      {required bool success, required String message}) async {
    String imagePath;
    List<Color> gradientColors;

    if (success) {
      imagePath = 'assets/images/doctor/love.png'; // Doctor success image
    } else {
      imagePath = 'assets/images/doctor/angry.png'; // Doctor error image
    }

    // Role-based gradient colors for doctor
    gradientColors = success
        ? [kDoctorBlue, const Color(0xFF0D47A1)] // Doctor blue
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
}
