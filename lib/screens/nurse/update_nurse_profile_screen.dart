import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../services/api_service.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:glassmorphism/glassmorphism.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/storage_service.dart';

// Nurse-specific color constants matching the modern design
const Color kNursePrimary = Color(0xFF9C27B0); // Nurse purple
const Color kNurseSecondary = Color(0xFFBA68C8);
const Color kNurseAccent = Color(0xFFE1BEE7);
const Color kNurseBackground = Color(0xFFF8F4FF);
const Color kNurseSurface = Color(0xFFFFFFFF);
const Color kNurseText = Color(0xFF4A148C);
const Color kNurseTextSecondary = Color(0xFF6A1B9A);
const Color kNurseSuccess = Color(0xFF4CAF50);
const Color kNurseWarning = Color(0xFFFF9800);
const Color kNurseError = Color(0xFFF44336);

class UpdateNurseProfileScreen extends StatefulWidget {
  final UserModel nurse;
  const UpdateNurseProfileScreen({Key? key, required this.nurse}) : super(key: key);

  @override
  State<UpdateNurseProfileScreen> createState() => _UpdateNurseProfileScreenState();
}

class _UpdateNurseProfileScreenState extends State<UpdateNurseProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _mobileController;
  late TextEditingController _licenseNumberController;
  late TextEditingController _specializationController;
  late TextEditingController _experienceController;
  late TextEditingController _shiftPreferenceController;
  late TextEditingController _assignedWardController;
  List<String> _assignedWards = [];
  String _selectedGender = 'Female';
  DateTime? _selectedDateOfBirth;
  File? _selectedImage;
  String? _profileImageUrl;
  final ImagePicker _picker = ImagePicker();
  bool loading = false;
  bool _initialLoading = true; // Add initial loading state

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.nurse.fullName);
    _emailController = TextEditingController(text: widget.nurse.email);
    _mobileController = TextEditingController(text: widget.nurse.mobileNumber);
    _licenseNumberController = TextEditingController(text: widget.nurse.licenseNumber ?? '');
    _specializationController = TextEditingController(text: widget.nurse.specialization ?? '');
    _experienceController = TextEditingController(text: widget.nurse.experienceYears?.toString() ?? '');
    _shiftPreferenceController = TextEditingController(text: ''); // Will be added to backend later
    _assignedWards = []; // Will be added to backend later
    _assignedWardController = TextEditingController();
    _selectedGender = widget.nurse.gender;
    _selectedDateOfBirth = widget.nurse.dateOfBirth;
    _profileImageUrl = widget.nurse.profileImageUrl;
    
    // Show gradient loading screen briefly
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) {
        setState(() {
          _initialLoading = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _mobileController.dispose();
    _licenseNumberController.dispose();
    _specializationController.dispose();
    _experienceController.dispose();
    _shiftPreferenceController.dispose();
    _assignedWardController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
    }
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      loading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          loading = false;
        });
        return;
      }

      // Upload profile image if selected
      String? profileImageUrl = _profileImageUrl;
      if (_selectedImage != null) {
        try {
          final storageService = StorageService();
          final imageBytes = await _selectedImage!.readAsBytes();
          final uploadedUrl = await storageService.uploadProfilePicture(
            userId: user.uid,
            userType: 'nurse',
            imageBytes: imageBytes,
          );
          if (uploadedUrl != null) {
            profileImageUrl = uploadedUrl;
          }
        } catch (e) {
          print('Profile image upload failed: $e');
          await _showGradientPopup(
            success: false,
            message: 'Profile image upload failed. Please try again.',
          );
          setState(() => loading = false);
          return;
        }
      }

      // Create updates map for nurse profile
      final updates = {
        'fullName': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'mobileNumber': _mobileController.text.trim(),
        'gender': _selectedGender,
        'dateOfBirth': (_selectedDateOfBirth ?? DateTime.now()).toIso8601String(),
        'licenseNumber': _licenseNumberController.text.trim(),
        'specialization': _specializationController.text.trim(),
        'experienceYears': int.parse(_experienceController.text.trim()),
        'profileImageUrl': profileImageUrl,
        'type': 'nurse',
      };

      // Update nurse using API service
      final success = await ApiService.updateUserProfile(user.uid, updates);
      
      if (success) {
        setState(() => loading = false);
        if (mounted) {
          await _showGradientPopup(
            success: true,
            message: 'Profile updated successfully!',
          );
          // Don't navigate back - keep user on update screen
        }
      } else {
        setState(() => loading = false);
        await _showGradientPopup(
          success: false,
          message: 'Failed to update profile. Please try again.',
        );
      }
    } catch (e) {
      setState(() => loading = false);
      await _showGradientPopup(
        success: false,
        message: 'Update failed: $e',
      );
    }
  }

  Future<void> _showGradientPopup({
    required bool success,
    required String message,
    String? imagePath,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final gender = prefs.getString('user_gender') ?? 'Female';
    
    // Default image paths based on success and gender
    String finalImagePath;
    if (imagePath != null) {
      finalImagePath = gender == 'Male' 
          ? imagePath.replaceAll('Female', 'Male')
          : imagePath;
    } else {
      if (success) {
        finalImagePath = gender == 'Male'
            ? 'assets/images/Male/nurs/love.png'
            : 'assets/images/Female/nurs/love.png';
      } else {
        finalImagePath = gender == 'Male'
            ? 'assets/images/Male/nurs/angry.png'
            : 'assets/images/Female/nurs/angry.png';
      }
    }
    
    // Nurse-specific gradient colors
    List<Color> gradientColors = success 
        ? [kNursePrimary, kNurseSecondary] // Nurse purple
        : [Colors.red[400]!, Colors.red[600]!];

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: gradientColors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: gradientColors[0].withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Image with zoom animation
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.8, end: 1.0),
                duration: const Duration(milliseconds: 500),
                builder: (context, value, child) {
                  return Transform.scale(
                    scale: value,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Image.asset(
                        finalImagePath,
                        width: 60,
                        height: 60,
                        fit: BoxFit.contain,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              
              // Message
              Text(
                message,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 20),
              
              // Close button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white.withOpacity(0.2),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'OK',
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

  Future<void> _selectDateOfBirth() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDateOfBirth ?? DateTime(1980, 1, 1),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDateOfBirth) {
      setState(() {
        _selectedDateOfBirth = picked;
      });
    }
  }

  void _addAssignedWard() {
    if (_assignedWardController.text.isNotEmpty) {
      setState(() {
        _assignedWards.add(_assignedWardController.text.trim());
        _assignedWardController.clear();
      });
    }
  }

  void _removeAssignedWard(String ward) {
    setState(() {
      _assignedWards.remove(ward);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Update Profile',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [kNursePrimary, kNurseSecondary], // Nurse purple gradient
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
          ),
        ),
      ),
      body: _initialLoading || loading
          ? Scaffold(
              body: FutureBuilder<SharedPreferences>(
                future: SharedPreferences.getInstance(),
                builder: (context, snapshot) {
                  String imagePath = 'assets/images/Female/nurs/think.png'; // Default to think for female
                  List<Color> gradientColors = [kNursePrimary, kNurseSecondary]; // Nurse purple

                  if (snapshot.hasData) {
                    final gender = snapshot.data!.getString('user_gender') ?? 'Female';

                    // Gender-specific thinking image
                    if (gender == 'Male') {
                      imagePath = 'assets/images/Male/nurs/think.png';
                    } else {
                      imagePath = 'assets/images/Female/nurs/think.png';
                    }
                  }

                  return Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: gradientColors,
                      ),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Gender-specific role image with glassmorphism and zoom animation
                          TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0.8, end: 1.2),
                            duration: const Duration(seconds: 2),
                            builder: (context, value, child) {
                              return Transform.scale(
                                scale: value,
                                child: Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.white.withOpacity(0.3),
                                        blurRadius: 20,
                                        spreadRadius: 5,
                                      ),
                                    ],
                                  ),
                                  child: Image.asset(
                                    imagePath,
                                    width: 120,
                                    height: 120,
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 32),

                          // Loading message
                          Text(
                            _initialLoading ? 'Loading profile...' : 'Updating profile...',
                            style: GoogleFonts.poppins(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 16),
                          
                          // Loading spinner
                          SizedBox(
                            width: 30,
                            height: 30,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Profile image upload and preview
                    Center(
                      child: Stack(
                        children: [
                          CircleAvatar(
                            radius: 50,
                            backgroundColor: kNursePrimary, // Nurse purple
                            backgroundImage: _selectedImage != null
                                ? FileImage(_selectedImage!)
                                : (_profileImageUrl != null && _profileImageUrl!.isNotEmpty)
                                    ? NetworkImage(_profileImageUrl!) as ImageProvider
                                    : null,
                            child: (_selectedImage == null && (_profileImageUrl == null || _profileImageUrl!.isEmpty))
                                ? const Icon(Icons.person, size: 50, color: Colors.white)
                                : null,
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: GestureDetector(
                              onTap: _pickImage,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 2)],
                                ),
                                padding: const EdgeInsets.all(6),
                                child: Icon(Icons.camera_alt, size: 22, color: kNursePrimary), // Nurse purple
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: 'Full Name',
                        labelStyle: GoogleFonts.poppins(color: kNursePrimary),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: kNursePrimary),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: kNursePrimary, width: 2),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: kNursePrimary.withOpacity(0.5)),
                        ),
                      ),
                      style: GoogleFonts.poppins(),
                      validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _emailController,
                      decoration: InputDecoration(
                        labelText: 'Email',
                        labelStyle: GoogleFonts.poppins(color: kNursePrimary),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: kNursePrimary),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: kNursePrimary, width: 2),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: kNursePrimary.withOpacity(0.5)),
                        ),
                      ),
                      style: GoogleFonts.poppins(),
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _mobileController,
                      decoration: InputDecoration(
                        labelText: 'Mobile Number',
                        labelStyle: GoogleFonts.poppins(color: kNursePrimary),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: kNursePrimary),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: kNursePrimary, width: 2),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: kNursePrimary.withOpacity(0.5)),
                        ),
                      ),
                      style: GoogleFonts.poppins(),
                      keyboardType: TextInputType.phone,
                      validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _selectedGender,
                      decoration: InputDecoration(
                        labelText: 'Gender',
                        labelStyle: GoogleFonts.poppins(color: kNursePrimary),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: kNursePrimary),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: kNursePrimary, width: 2),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: kNursePrimary.withOpacity(0.5)),
                        ),
                      ),
                      style: GoogleFonts.poppins(color: Colors.black87),
                      items: const [
                        DropdownMenuItem(value: 'Male', child: Text('Male')),
                        DropdownMenuItem(value: 'Female', child: Text('Female')),
                        DropdownMenuItem(value: 'Other', child: Text('Other')),
                      ],
                      onChanged: (v) async {
                        if (v != null) {
                          setState(() => _selectedGender = v);
                          // Save gender to SharedPreferences
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.setString('user_gender', v);
                        }
                      },
                      validator: (v) => v == null || v.isEmpty ? 'Please select gender' : null,
                    ),
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: _selectDateOfBirth,
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'Date of Birth',
                          labelStyle: GoogleFonts.poppins(color: kNursePrimary),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: kNursePrimary),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: kNursePrimary, width: 2),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: kNursePrimary.withOpacity(0.5)),
                          ),
                        ),
                        child: Text(
                          _selectedDateOfBirth != null
                              ? DateFormat('dd/MM/yyyy').format(_selectedDateOfBirth!)
                              : 'Select Date',
                          style: GoogleFonts.poppins(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _licenseNumberController,
                      decoration: InputDecoration(
                        labelText: 'Nursing License Number',
                        labelStyle: GoogleFonts.poppins(color: kNursePrimary),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: kNursePrimary),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: kNursePrimary, width: 2),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: kNursePrimary.withOpacity(0.5)),
                        ),
                      ),
                      style: GoogleFonts.poppins(),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _specializationController,
                      decoration: InputDecoration(
                        labelText: 'Specialization',
                        labelStyle: GoogleFonts.poppins(color: kNursePrimary),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: kNursePrimary),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: kNursePrimary, width: 2),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: kNursePrimary.withOpacity(0.5)),
                        ),
                      ),
                      style: GoogleFonts.poppins(),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _experienceController,
                            decoration: InputDecoration(
                              labelText: 'Experience (years)',
                              labelStyle: GoogleFonts.poppins(color: kNursePrimary),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: kNursePrimary),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: kNursePrimary, width: 2),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: kNursePrimary.withOpacity(0.5)),
                              ),
                            ),
                            style: GoogleFonts.poppins(),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _shiftPreferenceController,
                            decoration: InputDecoration(
                              labelText: 'Shift Preference',
                              labelStyle: GoogleFonts.poppins(color: kNursePrimary),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: kNursePrimary),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: kNursePrimary, width: 2),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: kNursePrimary.withOpacity(0.5)),
                              ),
                            ),
                            style: GoogleFonts.poppins(),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Assigned Wards Section
                    Text(
                      'Assigned Wards:',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        color: kNursePrimary, // Nurse purple
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _assignedWardController,
                            decoration: InputDecoration(
                              labelText: 'Add Assigned Ward',
                              labelStyle: GoogleFonts.poppins(color: kNursePrimary),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: kNursePrimary),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: kNursePrimary, width: 2),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: kNursePrimary.withOpacity(0.5)),
                              ),
                            ),
                            style: GoogleFonts.poppins(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _addAssignedWard,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kNursePrimary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            'Add',
                            style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (_assignedWards.isNotEmpty)
                      Wrap(
                        spacing: 8,
                        children: _assignedWards
                            .map((ward) => Chip(
                                  label: Text(
                                    ward,
                                    style: GoogleFonts.poppins(),
                                  ),
                                  onDeleted: () => _removeAssignedWard(ward),
                                  backgroundColor: kNursePrimary.withOpacity(0.1),
                                  deleteIconColor: kNursePrimary,
                                ))
                            .toList(),
                      ),
                    const SizedBox(height: 24),
                    // Save button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _updateProfile,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Container(
                          width: double.infinity,
                          height: 50,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [kNursePrimary, kNurseSecondary], // Nurse purple gradient
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: loading
                                ? const CircularProgressIndicator(color: Colors.white)
                                : Text(
                                    'Save Changes',
                                    style: GoogleFonts.poppins(
                                      fontSize: 16, 
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
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
}
