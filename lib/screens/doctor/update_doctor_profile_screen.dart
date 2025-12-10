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

// Doctor-specific color constants matching the modern design
const Color kDoctorPrimary = Color(0xFF2196F3); // Doctor blue
const Color kDoctorSecondary = Color(0xFF64B5F6);
const Color kDoctorAccent = Color(0xFF90CAF9);
const Color kDoctorBackground = Color(0xFFF8FBFF);
const Color kDoctorSurface = Color(0xFFFFFFFF);
const Color kDoctorText = Color(0xFF1A237E);
const Color kDoctorTextSecondary = Color(0xFF546E7A);
const Color kDoctorSuccess = Color(0xFF4CAF50);
const Color kDoctorWarning = Color(0xFFFF9800);
const Color kDoctorError = Color(0xFFF44336);

class UpdateDoctorProfileScreen extends StatefulWidget {
  final UserModel doctor;
  const UpdateDoctorProfileScreen({Key? key, required this.doctor})
      : super(key: key);

  @override
  State<UpdateDoctorProfileScreen> createState() =>
      _UpdateDoctorProfileScreenState();
}

class _UpdateDoctorProfileScreenState extends State<UpdateDoctorProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _mobileController;
  late TextEditingController _regNumberController;
  late TextEditingController _specializationController;
  late TextEditingController _experienceController;
  late TextEditingController _consultationFeeController;
  late TextEditingController _affiliatedHospitalsController;
  List<String> _affiliatedHospitals = [];
  String _selectedGender = 'Male';
  DateTime? _selectedDateOfBirth;
  File? _selectedImage;
  String? _profileImageUrl;
  final ImagePicker _picker = ImagePicker();
  bool loading = false;
  bool _initialLoading = true; // Add initial loading state

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.doctor.fullName);
    _emailController = TextEditingController(text: widget.doctor.email);
    _mobileController = TextEditingController(text: widget.doctor.mobileNumber);
    _regNumberController = TextEditingController(
        text: widget.doctor.medicalRegistrationNumber ?? '');
    _specializationController =
        TextEditingController(text: widget.doctor.specialization ?? '');
    _experienceController = TextEditingController(
        text: widget.doctor.experienceYears?.toString() ?? '');
    _consultationFeeController = TextEditingController(
        text: widget.doctor.consultationFee?.toString() ?? '');
    _affiliatedHospitals = widget.doctor.affiliatedHospitals ?? [];
    _affiliatedHospitalsController = TextEditingController();
    _selectedGender = widget.doctor.gender;
    _selectedDateOfBirth = widget.doctor.dateOfBirth;
    _profileImageUrl = widget.doctor.profileImageUrl;

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
    _regNumberController.dispose();
    _specializationController.dispose();
    _experienceController.dispose();
    _consultationFeeController.dispose();
    _affiliatedHospitalsController.dispose();
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
            userType: 'doctor',
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

      // Create updated UserModel for doctor
      final updatedDoctor = UserModel(
        uid: user.uid,
        fullName: _nameController.text.trim(),
        email: _emailController.text.trim(),
        mobileNumber: _mobileController.text.trim(),
        gender: _selectedGender,
        dateOfBirth: _selectedDateOfBirth ?? DateTime.now(),
        address:
            '', // Assuming address fields are not in the original UserModel
        city: '',
        state: '',
        pincode: '',
        type: 'doctor',
        createdAt: DateTime.now(),
        medicalRegistrationNumber: _regNumberController.text.trim(),
        specialization: _specializationController.text.trim(),
        experienceYears: int.parse(_experienceController.text.trim()),
        consultationFee: double.parse(_consultationFeeController.text.trim()),
        affiliatedHospitals: _affiliatedHospitals,
        profileImageUrl: profileImageUrl,
        licenseDocumentUrl:
            null, // Assuming licenseDocumentUrl is not in the original UserModel
        isApproved:
            true, // Assuming isApproved is not in the original UserModel
        approvalStatus:
            'approved', // Assuming approvalStatus is not in the original UserModel
      );

      // Update doctor using API service
      final success = await ApiService.updateDoctor(user.uid, updatedDoctor);

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
      finalImagePath =
          gender == 'Male' ? imagePath.replaceAll('Female', 'Male') : imagePath;
    } else {
      if (success) {
        finalImagePath = gender == 'Male'
            ? 'assets/images/Male/doc/love.png'
            : 'assets/images/Female/doc/love.png';
      } else {
        finalImagePath = gender == 'Male'
            ? 'assets/images/Male/doc/angry.png'
            : 'assets/images/Female/doc/angry.png';
      }
    }

    // Doctor-specific gradient colors
    List<Color> gradientColors = success
        ? [kDoctorPrimary, kDoctorSecondary] // Doctor blue
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

  void _addAffiliatedHospital() {
    if (_affiliatedHospitalsController.text.isNotEmpty) {
      setState(() {
        _affiliatedHospitals.add(_affiliatedHospitalsController.text.trim());
        _affiliatedHospitalsController.clear();
      });
    }
  }

  void _removeAffiliatedHospital(String hospital) {
    setState(() {
      _affiliatedHospitals.remove(hospital);
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
              colors: [
                kDoctorPrimary,
                kDoctorSecondary
              ], // Doctor blue gradient
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
                  String imagePath =
                      'assets/images/Female/doc/think.png'; // Default to think for female
                  List<Color> gradientColors = [
                    kDoctorPrimary,
                    kDoctorSecondary
                  ]; // Doctor blue

                  if (snapshot.hasData) {
                    final gender =
                        snapshot.data!.getString('user_gender') ?? 'Female';

                    // Gender-specific thinking image
                    if (gender == 'Male') {
                      imagePath = 'assets/images/Male/doc/think.png';
                    } else {
                      imagePath = 'assets/images/Female/doc/think.png';
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
                            _initialLoading
                                ? 'Loading profile...'
                                : 'Updating profile...',
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
                            backgroundColor: kDoctorPrimary, // Doctor blue
                            backgroundImage: _selectedImage != null
                                ? FileImage(_selectedImage!)
                                : (_profileImageUrl != null &&
                                        _profileImageUrl!.isNotEmpty)
                                    ? NetworkImage(_profileImageUrl!)
                                        as ImageProvider
                                    : null,
                            child: (_selectedImage == null &&
                                    (_profileImageUrl == null ||
                                        _profileImageUrl!.isEmpty))
                                ? const Icon(Icons.person,
                                    size: 50, color: Colors.white)
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
                                  boxShadow: [
                                    BoxShadow(
                                        color: Colors.black26, blurRadius: 2)
                                  ],
                                ),
                                padding: const EdgeInsets.all(6),
                                child: Icon(Icons.camera_alt,
                                    size: 22,
                                    color: kDoctorPrimary), // Doctor blue
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
                        labelStyle: GoogleFonts.poppins(color: kDoctorPrimary),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: kDoctorPrimary),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              BorderSide(color: kDoctorPrimary, width: 2),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                              color: kDoctorPrimary.withOpacity(0.5)),
                        ),
                      ),
                      style: GoogleFonts.poppins(),
                      validator: (v) =>
                          v == null || v.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _emailController,
                      decoration: InputDecoration(
                        labelText: 'Email',
                        labelStyle: GoogleFonts.poppins(color: kDoctorPrimary),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: kDoctorPrimary),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              BorderSide(color: kDoctorPrimary, width: 2),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                              color: kDoctorPrimary.withOpacity(0.5)),
                        ),
                      ),
                      style: GoogleFonts.poppins(),
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) =>
                          v == null || v.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _mobileController,
                      decoration: InputDecoration(
                        labelText: 'Mobile Number',
                        labelStyle: GoogleFonts.poppins(color: kDoctorPrimary),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: kDoctorPrimary),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              BorderSide(color: kDoctorPrimary, width: 2),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                              color: kDoctorPrimary.withOpacity(0.5)),
                        ),
                      ),
                      style: GoogleFonts.poppins(),
                      keyboardType: TextInputType.phone,
                      validator: (v) =>
                          v == null || v.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _selectedGender,
                      decoration: InputDecoration(
                        labelText: 'Gender',
                        labelStyle: GoogleFonts.poppins(color: kDoctorPrimary),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: kDoctorPrimary),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              BorderSide(color: kDoctorPrimary, width: 2),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                              color: kDoctorPrimary.withOpacity(0.5)),
                        ),
                      ),
                      style: GoogleFonts.poppins(color: Colors.black87),
                      items: const [
                        DropdownMenuItem(value: 'Male', child: Text('Male')),
                        DropdownMenuItem(
                            value: 'Female', child: Text('Female')),
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
                      validator: (v) => v == null || v.isEmpty
                          ? 'Please select gender'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: _selectDateOfBirth,
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'Date of Birth',
                          labelStyle:
                              GoogleFonts.poppins(color: kDoctorPrimary),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: kDoctorPrimary),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                BorderSide(color: kDoctorPrimary, width: 2),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                                color: kDoctorPrimary.withOpacity(0.5)),
                          ),
                        ),
                        child: Text(
                          _selectedDateOfBirth != null
                              ? DateFormat('dd/MM/yyyy')
                                  .format(_selectedDateOfBirth!)
                              : 'Select Date',
                          style: GoogleFonts.poppins(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _regNumberController,
                      decoration: InputDecoration(
                        labelText: 'Medical Registration Number',
                        labelStyle: GoogleFonts.poppins(color: kDoctorPrimary),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: kDoctorPrimary),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              BorderSide(color: kDoctorPrimary, width: 2),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                              color: kDoctorPrimary.withOpacity(0.5)),
                        ),
                      ),
                      style: GoogleFonts.poppins(),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _specializationController,
                      decoration: InputDecoration(
                        labelText: 'Specialization',
                        labelStyle: GoogleFonts.poppins(color: kDoctorPrimary),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: kDoctorPrimary),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              BorderSide(color: kDoctorPrimary, width: 2),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                              color: kDoctorPrimary.withOpacity(0.5)),
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
                              labelStyle:
                                  GoogleFonts.poppins(color: kDoctorPrimary),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: kDoctorPrimary),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide:
                                    BorderSide(color: kDoctorPrimary, width: 2),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                    color: kDoctorPrimary.withOpacity(0.5)),
                              ),
                            ),
                            style: GoogleFonts.poppins(),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _consultationFeeController,
                            decoration: InputDecoration(
                              labelText: 'Consultation Fee (₹)',
                              labelStyle:
                                  GoogleFonts.poppins(color: kDoctorPrimary),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: kDoctorPrimary),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide:
                                    BorderSide(color: kDoctorPrimary, width: 2),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                    color: kDoctorPrimary.withOpacity(0.5)),
                              ),
                            ),
                            style: GoogleFonts.poppins(),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Affiliated Hospitals Section
                    Text(
                      'Affiliated Hospitals:',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        color: kDoctorPrimary, // Doctor blue
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _affiliatedHospitalsController,
                            decoration: InputDecoration(
                              labelText: 'Add Affiliated Hospital',
                              labelStyle:
                                  GoogleFonts.poppins(color: kDoctorPrimary),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: kDoctorPrimary),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide:
                                    BorderSide(color: kDoctorPrimary, width: 2),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                    color: kDoctorPrimary.withOpacity(0.5)),
                              ),
                            ),
                            style: GoogleFonts.poppins(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _addAffiliatedHospital,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kDoctorPrimary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            'Add',
                            style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (_affiliatedHospitals.isNotEmpty)
                      Wrap(
                        spacing: 8,
                        children: _affiliatedHospitals
                            .map((hosp) => Chip(
                                  label: Text(
                                    hosp,
                                    style: GoogleFonts.poppins(),
                                  ),
                                  onDeleted: () =>
                                      _removeAffiliatedHospital(hosp),
                                  backgroundColor:
                                      kDoctorPrimary.withOpacity(0.1),
                                  deleteIconColor: kDoctorPrimary,
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
                              colors: [
                                kDoctorPrimary,
                                kDoctorSecondary
                              ], // Doctor blue gradient
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: loading
                                ? const CircularProgressIndicator(
                                    color: Colors.white)
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
