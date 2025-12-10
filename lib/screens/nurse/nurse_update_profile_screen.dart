import 'package:flutter/material.dart';
import 'package:arcular_plus/models/user_model.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:io';
import '../../services/api_service.dart';

// Add color constants at the top
const Color kBackground = Color(0xFFF9FAFB);
const Color kPrimaryText = Color(0xFF2E2E2E);
const Color kSecondaryText = Color(0xFF6B7280);
const Color kBorder = Color(0xFFE5E7EB);
const Color kSuccess = Color(0xFFA3E635);
const Color kNursePurple = Color(0xFF9C27B0);

class NurseUpdateProfileScreen extends StatefulWidget {
  final UserModel nurse;
  const NurseUpdateProfileScreen({super.key, required this.nurse});

  @override
  State<NurseUpdateProfileScreen> createState() =>
      _NurseUpdateProfileScreenState();
}

class _NurseUpdateProfileScreenState extends State<NurseUpdateProfileScreen> {
  late UserModel _nurse;
  final ImagePicker _picker = ImagePicker();
  String? _profileImageUrl;
  bool _isLoading = false;

  // Form controllers
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _altPhoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _pincodeController = TextEditingController();
  final _specializationController = TextEditingController();
  final _licenseNumberController = TextEditingController();
  final _experienceController = TextEditingController();
  final _qualificationController = TextEditingController();
  final _currentHospitalController = TextEditingController();

  // Form values
  String _selectedGender = 'Female';
  DateTime? _selectedDateOfBirth;
  String _selectedRole = 'Staff';

  @override
  void initState() {
    super.initState();
    _nurse = widget.nurse;
    _profileImageUrl = _nurse.profileImageUrl;
    _initializeForm();
  }

  void _initializeForm() {
    _fullNameController.text = _nurse.fullName ?? '';
    _emailController.text = _nurse.email ?? '';
    _phoneController.text = _nurse.mobileNumber ?? '';
    _altPhoneController.text = _nurse.altPhoneNumber ?? '';
    _addressController.text = _nurse.address ?? '';
    _cityController.text = _nurse.city ?? '';
    _stateController.text = _nurse.state ?? '';
    _pincodeController.text = _nurse.pincode ?? '';
    _specializationController.text = _nurse.specialization ?? '';
    _licenseNumberController.text = _nurse.licenseNumber ?? '';
    _experienceController.text = (_nurse.experienceYears ?? 0).toString();
    _qualificationController.text = _nurse.qualification ?? '';
    _currentHospitalController.text = '';

    _selectedGender = _nurse.gender ?? 'Female';
    _selectedRole = _nurse.role ?? 'Staff';

    if (_nurse.dateOfBirth != null) {
      _selectedDateOfBirth = _nurse.dateOfBirth!;
    }
  }

  Future<void> _pickAndUploadProfileImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile == null) return;

    final file = File(pickedFile.path);
    final uid = _nurse.uid;

    try {
      setState(() {
        _isLoading = true;
      });

      // Upload to Firebase Storage
      final storageRef =
          FirebaseStorage.instance.ref().child('nurse_profile_images/$uid.jpg');

      await storageRef.putFile(file);
      final url = await storageRef.getDownloadURL();

      setState(() {
        _profileImageUrl = url;
      });

      // Persist to backend so dashboard/profile fetch it everywhere
      await ApiService.updateNurseProfile(uid, {
        'profileImageUrl': url,
      });

      // Cache for instant display across app
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('nurse_profile_image_url', url);

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile image updated successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('❌ Error uploading profile image: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update profile image: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _updateProfile() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final updateData = {
        'fullName': _fullNameController.text.trim(),
        'email': _emailController.text.trim(),
        'mobileNumber': _phoneController.text.trim(),
        'altPhoneNumber': _altPhoneController.text.trim().isEmpty
            ? null
            : _altPhoneController.text.trim(),
        'address': _addressController.text.trim(),
        'city': _cityController.text.trim(),
        'state': _stateController.text.trim(),
        'pincode': _pincodeController.text.trim(),
        'specialization': _specializationController.text.trim(),
        'licenseNumber': _licenseNumberController.text.trim(),
        'experienceYears': int.tryParse(_experienceController.text) ?? 0,
        'qualification': _qualificationController.text.trim(),
        'currentHospital': _currentHospitalController.text.trim(),
        'gender': _selectedGender,
        'role': _selectedRole,
        'dateOfBirth': _selectedDateOfBirth?.toIso8601String(),
        if (_profileImageUrl != null) 'profileImageUrl': _profileImageUrl,
      };

      final success =
          await ApiService.updateNurseProfile(_nurse.uid, updateData);

      if (success) {
        // Save profile image URL to SharedPreferences
        if (_profileImageUrl != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('nurse_profile_image_url', _profileImageUrl!);
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully!'),
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
              colors: [kNursePurple, Color(0xFF6A1B9A)],
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
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Profile Image Section
                  Stack(
                    children: [
                      GestureDetector(
                        onTap: _pickAndUploadProfileImage,
                        child: CircleAvatar(
                          radius: 50,
                          backgroundColor: kNursePurple,
                          backgroundImage:
                              (_profileImageUrl?.isNotEmpty ?? false)
                                  ? NetworkImage(_profileImageUrl!)
                                  : null,
                          child: (_profileImageUrl?.isEmpty ?? true)
                              ? Text(
                                  (_nurse.fullName?.isNotEmpty ?? false)
                                      ? _nurse.fullName![0].toUpperCase()
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
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          decoration: BoxDecoration(
                            color: kNursePurple,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Icon(
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
                          _fullNameController, 'Full Name', Icons.person),
                      _buildTextField(_emailController, 'Email', Icons.email,
                          keyboardType: TextInputType.emailAddress),
                      _buildTextField(
                          _phoneController, 'Phone Number', Icons.phone,
                          keyboardType: TextInputType.phone),
                      _buildTextField(
                          _altPhoneController, 'Alternate Phone', Icons.phone,
                          keyboardType: TextInputType.phone, required: false),
                      _buildDropdown('Gender', _selectedGender,
                          ['Male', 'Female', 'Other'], (value) {
                        setState(() {
                          _selectedGender = value!;
                        });
                      }),
                      _buildDateField('Date of Birth', _selectedDateOfBirth,
                          (date) {
                        setState(() {
                          _selectedDateOfBirth = date;
                        });
                      }),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Professional Information Card
                  _buildInfoCard(
                    'Professional Information',
                    [
                      _buildTextField(_specializationController,
                          'Specialization', Icons.medical_services),
                      _buildTextField(
                        _licenseNumberController,
                        'License Number (contact staff to update)',
                        Icons.verified,
                        required: false,
                        readOnly: true,
                      ),
                      _buildTextField(_experienceController,
                          'Experience (Years)', Icons.work,
                          keyboardType: TextInputType.number),
                      _buildTextField(_qualificationController, 'Qualification',
                          Icons.school),
                      _buildTextField(_currentHospitalController,
                          'Current Hospital', Icons.local_hospital,
                          required: false),
                      _buildDropdown('Role', _selectedRole, [
                        'Primary',
                        'Secondary',
                        'Staff',
                        'Senior',
                        'Emergency',
                        'ICU'
                      ], (value) {
                        setState(() {
                          _selectedRole = value!;
                        });
                      }),
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
                  const SizedBox(height: 32),

                  // Update Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _updateProfile,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kNursePurple,
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
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange[200]!),
                    ),
                    child: Text(
                      'Note: Updating license or official documents requires staff verification. Please contact ARC staff for assistance.',
                      style: GoogleFonts.poppins(
                        color: Colors.orange[800],
                        fontSize: 12,
                        height: 1.3,
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
      {TextInputType? keyboardType,
      bool required = true,
      bool readOnly = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        readOnly: readOnly,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: kNursePurple),
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
            borderSide: BorderSide(color: kNursePurple, width: 2),
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

  Widget _buildDropdown(String label, String value, List<String> items,
      Function(String?) onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: DropdownButtonFormField<String>(
        value: value,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(Icons.arrow_drop_down, color: kNursePurple),
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
            borderSide: BorderSide(color: kNursePurple, width: 2),
          ),
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

  Widget _buildDateField(
      String label, DateTime? value, Function(DateTime?) onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () async {
          final date = await showDatePicker(
            context: context,
            initialDate: value ??
                DateTime.now()
                    .subtract(const Duration(days: 10950)), // 30 years ago
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
            prefixIcon: Icon(Icons.calendar_today, color: kNursePurple),
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
              borderSide: BorderSide(color: kNursePurple, width: 2),
            ),
          ),
          child: Text(
            value != null
                ? '${value.day}/${value.month}/${value.year}'
                : 'Select Date',
            style: GoogleFonts.poppins(
              color: value != null ? kPrimaryText : kSecondaryText,
            ),
          ),
        ),
      ),
    );
  }
}
