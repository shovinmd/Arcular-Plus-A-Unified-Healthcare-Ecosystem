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
const Color kSuccess = Color(0xFF34D399);
const Color kLabPrimary = Color(0xFFFDBA74);
const Color kLabSecondary = Color(0xFFFB923C);

class LabUpdateProfileScreen extends StatefulWidget {
  final UserModel lab;
  const LabUpdateProfileScreen({super.key, required this.lab});

  @override
  State<LabUpdateProfileScreen> createState() => _LabUpdateProfileScreenState();
}

class _LabUpdateProfileScreenState extends State<LabUpdateProfileScreen> {
  late UserModel _lab;
  final ImagePicker _picker = ImagePicker();
  String? _profileImageUrl;
  bool _isLoading = false;

  // Form controllers
  final _labNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _altPhoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _pincodeController = TextEditingController();
  final _licenseNumberController = TextEditingController();
  final _ownerNameController = TextEditingController();
  final _associatedHospitalController = TextEditingController();

  // Form values
  bool _homeSampleCollection = false;
  List<String> _selectedServices = [];
  String? _selectedGender;

  final List<String> _availableServices = [
    'Blood Tests',
    'Urine Analysis',
    'X-Ray',
    'MRI',
    'CT Scan',
    'Ultrasound',
    'ECG',
    'EEG',
    'Biopsy',
    'Culture Tests',
    'PCR Tests',
    'Allergy Tests',
    'Hormone Tests',
    'Tumor Markers',
    'Genetic Tests',
    'Microbiology Tests',
    'Histopathology',
    'Cytology',
  ];

  @override
  void initState() {
    super.initState();
    _lab = widget.lab;
    _profileImageUrl = _lab.profileImageUrl;
    _initializeForm();
  }

  void _initializeForm() {
    _labNameController.text = _lab.labName ?? _lab.fullName ?? '';
    _emailController.text = _lab.email ?? '';
    _phoneController.text = _lab.mobileNumber ?? '';
    _altPhoneController.text = _lab.alternateMobile ?? '';
    _addressController.text = _lab.address ?? '';
    _cityController.text = _lab.city ?? '';
    _stateController.text = _lab.state ?? '';
    _pincodeController.text = _lab.pincode ?? '';
    _licenseNumberController.text = _lab.licenseNumber ?? '';
    _ownerNameController.text = _lab.ownerName ?? '';
    _associatedHospitalController.text = _lab.associatedHospital ?? '';

    _homeSampleCollection = _lab.homeSampleCollection ?? false;
    _selectedServices = List<String>.from(_lab.servicesProvided ?? []);
    _selectedGender = _lab.gender;

    // Validate gender value
    if (_selectedGender != null &&
        !['Male', 'Female', 'Other'].contains(_selectedGender)) {
      _selectedGender = null;
    }
  }

  Future<void> _pickAndUploadProfileImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile == null) return;

    final file = File(pickedFile.path);
    final uid = _lab.uid;

    try {
      setState(() {
        _isLoading = true;
      });

      // Upload to Firebase Storage
      final storageRef =
          FirebaseStorage.instance.ref().child('lab_profile_images/$uid.jpg');

      await storageRef.putFile(file);
      final url = await storageRef.getDownloadURL();

      // Update backend with new image URL
      final success = await ApiService.updateLabProfile(uid, {
        'profileImageUrl': url,
      });

      if (success) {
        // Save to SharedPreferences for instant display
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('lab_profile_image_url', url);

        setState(() {
          _profileImageUrl = url;
        });

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile image updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        throw Exception('Failed to update profile image in backend');
      }
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
        'fullName': _labNameController.text.trim(),
        'labName': _labNameController.text.trim(),
        'email': _emailController.text.trim(),
        'mobileNumber': _phoneController.text.trim(),
        'alternateMobile': _altPhoneController.text.trim().isEmpty
            ? null
            : _altPhoneController.text.trim(),
        'address': _addressController.text.trim(),
        'city': _cityController.text.trim(),
        'state': _stateController.text.trim(),
        'pincode': _pincodeController.text.trim(),
        'licenseNumber': _licenseNumberController.text.trim(),
        'ownerName': _ownerNameController.text.trim(),
        'gender': _selectedGender,
        'associatedHospital': _associatedHospitalController.text.trim(),
        'homeSampleCollection': _homeSampleCollection,
        'servicesProvided': _selectedServices,
        if (_profileImageUrl != null) 'profileImageUrl': _profileImageUrl,
      };

      final success = await ApiService.updateLabProfile(_lab.uid, updateData);

      if (success) {
        // Save profile image URL to SharedPreferences
        if (_profileImageUrl != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('lab_profile_image_url', _profileImageUrl!);
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
              colors: [kLabSecondary, kLabPrimary],
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
                          backgroundColor: kLabSecondary,
                          backgroundImage:
                              (_profileImageUrl?.isNotEmpty ?? false)
                                  ? NetworkImage(_profileImageUrl!)
                                  : null,
                          child: (_profileImageUrl?.isEmpty ?? true)
                              ? Text(
                                  ((_lab.labName ?? _lab.fullName)
                                              ?.isNotEmpty ??
                                          false)
                                      ? (_lab.labName ?? _lab.fullName)![0]
                                          .toUpperCase()
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
                            color: kLabSecondary,
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
                          _labNameController, 'Lab Name', Icons.home),
                      _buildTextField(_emailController, 'Email', Icons.email,
                          keyboardType: TextInputType.emailAddress),
                      _buildTextField(
                          _phoneController, 'Phone Number', Icons.phone,
                          keyboardType: TextInputType.phone),
                      _buildTextField(
                          _altPhoneController, 'Alternate Phone', Icons.phone,
                          keyboardType: TextInputType.phone, required: false),
                      _buildTextField(
                          _ownerNameController, 'Owner Name', Icons.person),
                      _buildGenderDropdown(),
                      _buildTextField(_associatedHospitalController,
                          'Associated Hospital', Icons.local_hospital,
                          required: false),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Professional Information Card
                  _buildInfoCard(
                    'Professional Information',
                    [
                      _buildTextField(_licenseNumberController,
                          'License Number', Icons.verified,
                          readOnly: true),
                      _buildServicesSelector(),
                      _buildSwitchField(
                          'Home Sample Collection', _homeSampleCollection,
                          (value) {
                        setState(() {
                          _homeSampleCollection = value;
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
                        backgroundColor: kLabSecondary,
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
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF7ED),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFFDBA74)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.info, color: Color(0xFFFB923C)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'For license and uploaded document changes, please contact staff for verification. These fields are read-only here.',
                            style: GoogleFonts.poppins(
                              color: kSecondaryText,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
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
        keyboardType: keyboardType,
        readOnly: readOnly,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: kLabSecondary),
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
            borderSide: BorderSide(color: kLabSecondary, width: 2),
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
                selectedColor: kLabSecondary.withOpacity(0.2),
                checkmarkColor: kLabSecondary,
                side: BorderSide(
                  color: isSelected ? kLabSecondary : kBorder,
                ),
              );
            }).toList(),
          ),
        ],
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
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          prefixIcon: const Icon(Icons.person, color: kLabSecondary),
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
            activeColor: kLabSecondary,
          ),
        ],
      ),
    );
  }
}
