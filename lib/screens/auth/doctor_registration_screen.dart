import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:arcular_plus/services/registration_service.dart';
import 'package:arcular_plus/services/dashboard_navigation_service.dart';
import 'package:arcular_plus/screens/doctor/dashboard_doctor.dart';
import 'package:eva_icons_flutter/eva_icons_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../../widgets/hospital_affiliation_selector.dart';

class DoctorRegistrationScreen extends StatefulWidget {
  final String? signupEmail;
  final String? signupPhone;
  final String? signupPassword;
  final String? signupCountryCode;

  const DoctorRegistrationScreen({
    super.key,
    this.signupEmail,
    this.signupPhone,
    this.signupPassword,
    this.signupCountryCode,
  });

  @override
  State<DoctorRegistrationScreen> createState() =>
      _DoctorRegistrationScreenState();
}

class _DoctorRegistrationScreenState extends State<DoctorRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _imagePicker = ImagePicker();

  // Form State
  bool _isLoading = false;
  bool _isGoogleSignup = false;
  int _currentStep = 1; // 1: Basic Info, 2: Professional, 3: Documents

  // Common fields
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _mobileController = TextEditingController();
  final _alternateMobileController = TextEditingController();
  final _addressController = TextEditingController();
  final _pincodeController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  String _countryCode = '+91';

  // Password fields (only for non-Google signup)
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _verifyPasswordController =
      TextEditingController();

  // Doctor-specific fields
  final _medicalRegistrationNumberController = TextEditingController();
  final _specializationController = TextEditingController();
  final _experienceYearsController = TextEditingController();
  final _consultationFeeController = TextEditingController();
  final _qualificationController = TextEditingController();
  List<String> _selectedQualifications = [];
  final _affiliatedHospitalsController = TextEditingController();
  final _licenseCertificateController =
      TextEditingController(); // Added missing licenseCertificateController
  final _licenseNumberController =
      TextEditingController(); // Separate controller for license number

  // Dropdown values
  String _selectedGender = 'Male';
  String _selectedBloodGroup = 'A+';
  DateTime? _selectedDateOfBirth;

  // Lists for multiple selections
  List<String> _affiliatedHospitals = [];
  List<String> _selectedSpecializations = [];
  List<Map<String, dynamic>> _enhancedAffiliatedHospitals = [];
  String? _primarySpecialization; // Single-select primary specialization

  // Location fields
  double? _longitude;
  double? _latitude;
  bool _isGettingLocation = false;

  // Location capture methods
  Future<void> _getCurrentLocation() async {
    setState(() => _isGettingLocation = true);

    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showLocationError(
            'Location services are disabled. Please enable location services.');
        return;
      }

      // Check location permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showLocationError(
              'Location permissions are denied. Please enable location permissions.');
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _showLocationError(
            'Location permissions are permanently denied. Please enable them in settings.');
        return;
      }

      // Get current position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
        _isGettingLocation = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Location captured successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      setState(() => _isGettingLocation = false);
      _showLocationError('Failed to get location: $e');
    }
  }

  void _showLocationError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        action: SnackBarAction(
          label: 'Enter Manually',
          textColor: Colors.white,
          onPressed: _showManualLocationDialog,
        ),
      ),
    );
  }

  void _showManualLocationDialog() {
    final longitudeController = TextEditingController();
    final latitudeController = TextEditingController();

    if (_longitude != null) longitudeController.text = _longitude.toString();
    if (_latitude != null) latitudeController.text = _latitude.toString();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enter Location Manually'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: latitudeController,
              decoration: const InputDecoration(
                labelText: 'Latitude',
              ),
              keyboardType: TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: longitudeController,
              decoration: const InputDecoration(
                labelText: 'Longitude',
              ),
              keyboardType: TextInputType.numberWithOptions(decimal: true),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final lat = double.tryParse(latitudeController.text);
              final lng = double.tryParse(longitudeController.text);

              if (lat != null &&
                  lng != null &&
                  lat >= -90 &&
                  lat <= 90 &&
                  lng >= -180 &&
                  lng <= 180) {
                setState(() {
                  _latitude = lat;
                  _longitude = lng;
                });
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Location updated successfully!'),
                    backgroundColor: Colors.green,
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter valid coordinates'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  // File uploads
  File? _medicalDegreeFile;
  File? _licenseCertificateFile;
  File? _identityProofFile;
  String? _medicalDegreeUrl;
  String? _licenseCertificateUrl;
  String? _identityProofUrl;
  bool _isUploading = false;

  // Document Upload Files (matching other registration screens pattern)
  File? _selectedMedicalDegree;
  File? _selectedLicenseCertificate;
  File? _selectedIdentityProof;
  File? _selectedProfileImage;

  // Search functionality
  String _specializationSearchQuery = '';

  final List<String> _genderOptions = ['Male', 'Female', 'Other'];
  final List<String> _bloodGroups = [
    'A+',
    'A-',
    'B+',
    'B-',
    'AB+',
    'AB-',
    'O+',
    'O-'
  ];
  final List<String> _specializationOptions = [
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
    'ENT',
    'Ophthalmology',
    'Urology',
    'Nephrology',
    'Gastroenterology',
    'Pulmonology',
    'Endocrinology',
    'Rheumatology',
    'Hematology',
    'Infectious Disease',
    'Physical Medicine',
    'Plastic Surgery',
    'Vascular Surgery',
    'Thoracic Surgery',
    'Neurosurgery',
    'Cardiothoracic Surgery',
    'General Practice',
    'Family Medicine',
    'Geriatrics',
    'Sports Medicine',
    'Occupational Medicine',
    'Preventive Medicine',
    'Public Health',
    'Community Medicine',
    'Forensic Medicine',
    'Alternative Medicine',
    'Allergy and Immunology',
    'Critical Care Medicine',
    'Pain Management',
    'Sleep Medicine',
    'Travel Medicine',
    'Tropical Medicine',
    'Nuclear Medicine',
    'Radiation Oncology',
    'Medical Oncology',
    'Surgical Oncology',
    'Pediatric Surgery',
    'Pediatric Cardiology',
    'Pediatric Neurology',
    'Pediatric Oncology',
    'Pediatric Endocrinology',
    'Maternal-Fetal Medicine',
    'Reproductive Endocrinology',
    'Gynecologic Oncology',
    'Minimally Invasive Surgery',
    'Robotic Surgery',
    'Laparoscopic Surgery',
    'Microsurgery',
    'Transplant Surgery',
    'Hand Surgery',
    'Foot and Ankle Surgery',
    'Spine Surgery',
    'Joint Replacement Surgery',
    'Sports Orthopedics',
    'Pediatric Orthopedics',
    'Trauma Surgery',
    'Burn Surgery',
    'Cosmetic Surgery',
    'Reconstructive Surgery',
    'Craniofacial Surgery',
    'Oral and Maxillofacial Surgery',
    'Head and Neck Surgery',
    'Laryngology',
    'Rhinology',
    'Otology',
    'Neurotology',
    'Pediatric ENT',
    'Cornea and External Disease',
    'Retina and Vitreous',
    'Glaucoma',
    'Pediatric Ophthalmology',
    'Oculoplastic Surgery',
    'Neuro-Ophthalmology',
    'Uveitis',
    'Pediatric Urology',
    'Female Urology',
    'Urologic Oncology',
    'Andrology',
    'Infertility',
    'Sexual Medicine',
    'Pediatric Nephrology',
    'Transplant Nephrology',
  ];

  final List<String> _qualificationOptions = [
    'MBBS',
    'BDS',
    'BAMS',
    'BHMS',
    'BUMS',
    'BPT',
    'B.Pharm',
    'B.Sc Nursing',
    'MD',
    'MS',
    'MDS',
    'MCh',
    'DM',
    'DNB',
    'MRCP',
    'FRCS',
    'MRCS',
    'MRCOG',
    'FRCOG',
    'MRCPCH',
    'FRCPCH',
    'MRCPath',
    'FRCPath',
    'MRCPsych',
    'FRCPsych',
    'FRCP',
    'MSc',
    'PhD',
    'Diploma',
    'Certificate',
    'Fellowship',
    'Other'
  ];

  // Validation functions
  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter email';
    }
    if (!RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$')
        .hasMatch(value)) {
      return 'Please enter a valid email';
    }
    return null;
  }

  String? _validateMobile(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter mobile number';
    }
    if (!RegExp(r'^[6-9]\d{9}$').hasMatch(value)) {
      return 'Please enter valid 10-digit mobile number';
    }
    return null;
  }

  String? _validateName(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter name';
    }
    if (value.length < 2 || value.length > 50) {
      return 'Name must be 2-50 characters';
    }
    if (!RegExp(r'^[a-zA-Z\s\-\.]+$').hasMatch(value)) {
      return 'Name can only contain letters, spaces, hyphens';
    }
    return null;
  }

  String? _validatePincode(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter pincode';
    }
    if (!RegExp(r'^[1-9][0-9]{5}$').hasMatch(value)) {
      return 'Please enter valid 6-digit pincode';
    }
    return null;
  }

  String? _validateNMCNumber(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter medical registration number';
    }
    // NMC format: Usually 5-15 alphanumeric characters
    if (value.length < 5 || value.length > 15) {
      return 'Registration number must be 5-15 characters';
    }
    if (!RegExp(r'^[A-Z0-9]+$').hasMatch(value.toUpperCase())) {
      return 'Registration number must be alphanumeric';
    }
    return null;
  }

  String? _validateLicenseNumber(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter license number';
    }
    // License format: Usually 5-15 alphanumeric characters
    if (value.length < 5 || value.length > 15) {
      return 'License number must be 5-15 characters';
    }
    if (!RegExp(r'^[A-Z0-9]+$').hasMatch(value.toUpperCase())) {
      return 'License number must be alphanumeric';
    }
    return null;
  }

  String? _validateExperience(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter years of experience';
    }
    final exp = int.tryParse(value);
    if (exp == null) {
      return 'Please enter valid number';
    }
    if (exp < 0 || exp > 50) {
      return 'Experience must be 0-50 years';
    }
    return null;
  }

  String? _validateConsultationFee(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter consultation fee';
    }
    final fee = double.tryParse(value);
    if (fee == null) {
      return 'Please enter valid amount';
    }
    if (fee < 100 || fee > 10000) {
      return 'Fee must be ₹100-₹10000';
    }
    return null;
  }

  @override
  void initState() {
    super.initState();

    // Pre-fill email and phone if provided from signup
    if (widget.signupEmail != null && widget.signupEmail!.isNotEmpty) {
      _emailController.text = widget.signupEmail!;
      _isGoogleSignup = true;
    }
    if (widget.signupPhone != null && widget.signupPhone!.isNotEmpty) {
      _mobileController.text = widget.signupPhone!;
    }

    // Set default date of birth (30 years ago)
    _selectedDateOfBirth = DateTime.now().subtract(const Duration(days: 10950));

    // Add listeners to trigger UI updates when fields change
    _fullNameController.addListener(() => setState(() {}));
    _emailController.addListener(() => setState(() {}));
    _mobileController.addListener(() => setState(() {}));
    _addressController.addListener(() => setState(() {}));
    _cityController.addListener(() => setState(() {}));
    _stateController.addListener(() => setState(() {}));
    _pincodeController.addListener(() => setState(() {}));
    _medicalRegistrationNumberController.addListener(() => setState(() {}));
    _specializationController.addListener(() => setState(() {}));
    _experienceYearsController.addListener(() => setState(() {}));
    _consultationFeeController.addListener(() => setState(() {}));
    _qualificationController.addListener(() => setState(() {}));
    _licenseCertificateController.addListener(() =>
        setState(() {})); // Added listener for licenseCertificateController
    _licenseNumberController.addListener(
        () => setState(() {})); // Added listener for licenseNumberController
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _mobileController.dispose();
    _alternateMobileController.dispose();
    _addressController.dispose();
    _pincodeController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _passwordController.dispose();
    _verifyPasswordController.dispose();
    _medicalRegistrationNumberController.dispose();
    _specializationController.dispose();
    _experienceYearsController.dispose();
    _consultationFeeController.dispose();
    _qualificationController.dispose();
    _affiliatedHospitalsController.dispose();
    _licenseCertificateController
        .dispose(); // Dispose licenseCertificateController
    _licenseNumberController.dispose(); // Dispose licenseNumberController
    super.dispose();
  }

  bool _canProceedToNextStep() {
    switch (_currentStep) {
      case 1:
        return _fullNameController.text.trim().isNotEmpty &&
            _emailController.text.trim().isNotEmpty &&
            _mobileController.text.trim().isNotEmpty &&
            _addressController.text.trim().isNotEmpty &&
            _cityController.text.trim().isNotEmpty &&
            _stateController.text.trim().isNotEmpty &&
            _pincodeController.text.trim().isNotEmpty &&
            _selectedDateOfBirth != null;
      case 2:
        return _medicalRegistrationNumberController.text.trim().isNotEmpty &&
            _licenseNumberController.text.trim().isNotEmpty &&
            _selectedSpecializations.isNotEmpty &&
            _experienceYearsController.text.trim().isNotEmpty &&
            _consultationFeeController.text.trim().isNotEmpty &&
            _selectedQualifications.isNotEmpty;
      case 3:
        return _medicalDegreeUrl != null &&
            _licenseCertificateUrl != null &&
            _identityProofUrl != null;
      default:
        return false;
    }
  }

  void _toggleSpecialization(String specialization) {
    setState(() {
      if (_selectedSpecializations.contains(specialization)) {
        _selectedSpecializations.remove(specialization);
      } else {
        _selectedSpecializations.add(specialization);
      }
    });
  }

  List<String> _getFilteredSpecializations() {
    if (_specializationSearchQuery.isEmpty) {
      return _specializationOptions;
    }
    return _specializationOptions
        .where((specialization) => specialization
            .toLowerCase()
            .contains(_specializationSearchQuery.toLowerCase()))
        .toList();
  }

  void _toggleAffiliatedHospital(String hospital) {
    setState(() {
      if (_affiliatedHospitals.contains(hospital)) {
        _affiliatedHospitals.remove(hospital);
      } else {
        _affiliatedHospitals.add(hospital);
      }
    });
  }

  void _showQualificationSelectionDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(
                'Select Qualifications',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF2196F3),
                ),
              ),
              content: SizedBox(
                width: double.maxFinite,
                height: 400,
                child: ListView.builder(
                  itemCount: _qualificationOptions.length,
                  itemBuilder: (context, index) {
                    final qualification = _qualificationOptions[index];
                    final isSelected =
                        _selectedQualifications.contains(qualification);

                    return CheckboxListTile(
                      title: Text(
                        qualification,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: isSelected
                              ? const Color(0xFF2196F3)
                              : Colors.grey[700],
                        ),
                      ),
                      value: isSelected,
                      activeColor: const Color(0xFF2196F3),
                      onChanged: (bool? value) {
                        setDialogState(() {
                          if (value == true) {
                            if (!_selectedQualifications
                                .contains(qualification)) {
                              _selectedQualifications.add(qualification);
                            }
                          } else {
                            _selectedQualifications.remove(qualification);
                          }
                        });
                      },
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.poppins(
                      color: Colors.grey[600],
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    setState(() {});
                    Navigator.of(context).pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2196F3),
                    foregroundColor: Colors.white,
                  ),
                  child: Text(
                    'Done',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _pickDocument(String documentType) async {
    try {
      // Show dialog to choose between image and PDF
      final String? choice = await showDialog<String>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Select Document Type'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.image, color: Colors.blue),
                  title: const Text('Image (JPG, PNG)'),
                  onTap: () => Navigator.of(context).pop('image'),
                ),
                ListTile(
                  leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
                  title: const Text('PDF Document'),
                  onTap: () => Navigator.of(context).pop('pdf'),
                ),
              ],
            ),
          );
        },
      );

      if (choice == null) return;

      setState(() {
        _isUploading = true;
      });

      if (choice == 'image') {
        // Pick image
        final XFile? image = await _imagePicker.pickImage(
          source: ImageSource.gallery,
          maxWidth: 1024,
          maxHeight: 1024,
          imageQuality: 80,
        );

        if (image != null) {
          // Reduced upload delay for faster response
          await Future.delayed(const Duration(milliseconds: 500));

          setState(() {
            switch (documentType) {
              case 'medical_degree':
                _medicalDegreeFile = File(image.path);
                _medicalDegreeUrl = 'uploaded_medical_degree_url';
                break;
              case 'license_certificate':
                _licenseCertificateFile = File(image.path);
                _licenseCertificateUrl = 'uploaded_license_certificate_url';
                break;
              case 'identity_proof':
                _identityProofFile = File(image.path);
                _identityProofUrl = 'uploaded_identity_proof_url';
                break;
            }
            _isUploading = false;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$documentType uploaded successfully!'),
              backgroundColor: const Color(0xFF2196F3),
            ),
          );
        }
      } else if (choice == 'pdf') {
        // Pick PDF
        FilePickerResult? result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['pdf'],
        );

        if (result != null && result.files.single.path != null) {
          // Reduced upload delay for faster response
          await Future.delayed(const Duration(milliseconds: 500));

          setState(() {
            switch (documentType) {
              case 'medical_degree':
                _medicalDegreeFile = File(result.files.single.path!);
                _medicalDegreeUrl = 'uploaded_medical_degree_url';
                break;
              case 'license_certificate':
                _licenseCertificateFile = File(result.files.single.path!);
                _licenseCertificateUrl = 'uploaded_license_certificate_url';
                break;
              case 'identity_proof':
                _identityProofFile = File(result.files.single.path!);
                _identityProofUrl = 'uploaded_identity_proof_url';
                break;
            }
            _isUploading = false;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$documentType PDF uploaded successfully!'),
              backgroundColor: const Color(0xFF2196F3),
            ),
          );
        }
      }

      setState(() {
        _isUploading = false;
      });
    } catch (e) {
      setState(() {
        _isUploading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to upload $documentType: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _registerDoctor() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill all required fields correctly'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      print('🚀 Starting doctor registration...');

      // 1. Ensure user is authenticated first
      User? firebaseUser = FirebaseAuth.instance.currentUser;
      String? passwordToUse = widget.signupPassword?.isNotEmpty == true
          ? widget.signupPassword
          : '';

      print('🔍 Firebase Auth Check:');
      print('📧 Signup Email: ${widget.signupEmail ?? 'null'}');
      print(
          '🔑 Signup Password: ${passwordToUse?.isNotEmpty == true ? '***' : 'empty'}');
      print('👤 Current Firebase User: ${firebaseUser?.uid ?? 'null'}');

      if (firebaseUser == null) {
        print('🔍 No authenticated user found, creating Firebase user...');
        if (widget.signupEmail != null &&
            widget.signupEmail!.isNotEmpty &&
            passwordToUse?.isNotEmpty == true) {
          // Create password-based account
          try {
            print(
                '🚀 Creating Firebase user with email: ${widget.signupEmail}');
            final userCredential =
                await FirebaseAuth.instance.createUserWithEmailAndPassword(
              email: widget.signupEmail!,
              password: passwordToUse!,
            );
            firebaseUser = userCredential.user;
            print('✅ Firebase user created: ${firebaseUser?.uid}');
            print('📧 Firebase user email: ${firebaseUser?.email}');
          } catch (e) {
            print('❌ Firebase user creation failed: $e');
            // Try to sign in if user already exists
            try {
              print('🔄 Trying to sign in existing user...');
              final userCredential =
                  await FirebaseAuth.instance.signInWithEmailAndPassword(
                email: widget.signupEmail!,
                password: passwordToUse!,
              );
              firebaseUser = userCredential.user;
              print('✅ Firebase user signed in: ${firebaseUser?.uid}');
              print('📧 Firebase user email: ${firebaseUser?.email}');
            } catch (signInError) {
              print('❌ Firebase sign in failed: $signInError');
              throw Exception('Authentication failed: $signInError');
            }
          }
        } else {
          print('❌ Missing credentials:');
          print(
              '   Email: ${widget.signupEmail?.isEmpty ?? true ? 'MISSING' : 'present'}');
          print(
              '   Password: ${passwordToUse?.isEmpty == true ? 'MISSING' : 'present'}');
          throw Exception('No email or password provided for authentication');
        }
      }

      if (firebaseUser == null) {
        throw Exception('User creation failed');
      }

      // Verify the user is properly authenticated
      await firebaseUser.reload();
      firebaseUser = FirebaseAuth.instance.currentUser;

      if (firebaseUser == null) {
        throw Exception('User authentication verification failed');
      }

      print('✅ User authenticated and verified: ${firebaseUser.uid}');
      print('📧 User email: ${firebaseUser.email}');
      print('🔑 User email verified: ${firebaseUser.emailVerified}');

      // Create doctor user model
      final doctorUser = {
        'uid': firebaseUser.uid,
        'fullName': _fullNameController.text.trim(),
        'email': _emailController.text.trim(),
        'mobileNumber': _mobileController.text.trim(),
        'altPhoneNumber': _alternateMobileController.text.trim().isEmpty
            ? null
            : _alternateMobileController.text.trim(),
        'gender': _selectedGender,
        'dateOfBirth': _selectedDateOfBirth?.toIso8601String(),
        'address': _addressController.text.trim(),
        'city': _cityController.text.trim(),
        'state': _stateController.text.trim(),
        'pincode': _pincodeController.text.trim(),
        'longitude': _longitude, // Add separate longitude field
        'latitude': _latitude, // Add separate latitude field
        'geoCoordinates': _longitude != null && _latitude != null
            ? {'lat': _latitude, 'lng': _longitude} // Fixed field names
            : null,
        'medicalRegistrationNumber':
            _medicalRegistrationNumberController.text.trim(),
        'licenseNumber': _licenseNumberController.text.trim(),
        // Keep single specialization for compatibility and also send array
        'specialization': _selectedSpecializations.isNotEmpty
            ? _selectedSpecializations.first
            : '',
        'specializations': _selectedSpecializations,
        'experienceYears': int.tryParse(_experienceYearsController.text) ?? 0,
        'consultationFee':
            double.tryParse(_consultationFeeController.text) ?? 0.0,
        'qualification': _selectedQualifications.join(', '),
        'qualifications': _selectedQualifications,
        'affiliatedHospitals':
            _enhancedAffiliatedHospitals, // Use correct field name
        'currentHospital': '', // Add current hospital field
        'workingHours': {}, // Add working hours field
        'education': _selectedQualifications.join(', '), // Add education field
        'bio': '', // Add bio field
        'licenseDocumentUrl': _licenseCertificateUrl ?? '',
        'profileImageUrl': _identityProofUrl ?? '',
        'bloodGroup': _selectedBloodGroup, // Add as custom field
        'documents': {
          'medical_degree': _medicalDegreeUrl,
          'license_certificate': _licenseCertificateUrl,
          'identity_proof': _identityProofUrl,
        },
      };

      // Prepare documents
      print('📄 Preparing documents for upload...');
      final documents = <File>[];
      final documentTypes = <String>[];

      if (_medicalDegreeFile != null) {
        print('📄 Medical degree file: ${_medicalDegreeFile!.path}');
        documents.add(_medicalDegreeFile!);
        documentTypes.add('medical_degree');
      }
      if (_licenseCertificateFile != null) {
        print('📄 License certificate file: ${_licenseCertificateFile!.path}');
        documents.add(_licenseCertificateFile!);
        documentTypes.add('license_certificate');
      }
      if (_identityProofFile != null) {
        print('📄 Identity proof file: ${_identityProofFile!.path}');
        documents.add(_identityProofFile!);
        documentTypes.add('identity_proof');
      }

      print('📄 Total documents to upload: ${documents.length}');
      print('📄 Document types: $documentTypes');

      // Use the registration service
      print('🚀 Calling RegistrationService.registerUser...');
      print('👤 User UID: ${firebaseUser.uid}');
      print('📧 User Email: ${firebaseUser.email}');
      print('📄 Documents to upload: ${documents.length}');
      print(
          '📄 Uploaded documents: ${_medicalDegreeUrl != null ? 'medical_degree' : 'none'}, ${_licenseCertificateUrl != null ? 'license_certificate' : 'none'}, ${_identityProofUrl != null ? 'identity_proof' : 'none'}');

      final result = await RegistrationService.registerUser(
        userType: 'doctor',
        userData: doctorUser,
        documents: documents,
        documentTypes: documentTypes,
        uploadedDocuments: {
          'medical_degree': _medicalDegreeUrl ?? '',
          'license_certificate': _licenseCertificateUrl ?? '',
          'identity_proof': _identityProofUrl ?? '',
        },
      );

      print('📊 Registration result: $result');

      if (result['success']) {
        // Save user type to SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_type', 'doctor');
        await prefs.setString('user_gender', _selectedGender);
        await prefs.setString('user_uid', firebaseUser.uid);
        await prefs.setString('user_status', 'pending');

        if (mounted) {
          // Show success popup
          await _showCustomPopup(
            success: true,
            message: result['message'] ??
                'Doctor registration successful! Your account is pending approval.',
          );

          // Navigate based on user type and approval status
          await DashboardNavigationService.navigateAfterRegistration(
            context,
            'doctor',
            'pending',
          );
        }
      } else {
        if (mounted) {
          await _showCustomPopup(
            success: false,
            message: result['message'] ??
                'Failed to register doctor. Please check your internet connection and try again.',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        await _showCustomPopup(
          success: false,
          message: 'Registration failed: $e',
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _showCustomPopup({
    required bool success,
    required String message,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final gender = prefs.getString('user_gender') ?? 'Male';
    String imagePath;
    if (success) {
      imagePath = gender == 'Male'
          ? 'assets/images/Male/doc/love.png'
          : 'assets/images/Female/doc/love.png';
    } else {
      imagePath = gender == 'Male'
          ? 'assets/images/Male/doc/angry.png'
          : 'assets/images/Female/doc/angry.png';
    }
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(imagePath, width: 80, height: 80, fit: BoxFit.contain),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
          ],
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  Widget _buildStepIndicator() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Row(
            children: [
              _buildStepCircle(1, _currentStep >= 1, 'Basic'),
              _buildStepLine(_currentStep >= 2),
              _buildStepCircle(2, _currentStep >= 2, 'Professional'),
              _buildStepLine(_currentStep >= 3),
              _buildStepCircle(3, _currentStep >= 3, 'Documents'),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Personal Info',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                'Medical Details',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.white.withOpacity(0.7),
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                'Documents',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.white.withOpacity(0.7),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStepCircle(int step, bool isActive, String label) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: isActive ? Colors.white : Colors.white.withOpacity(0.3),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: Center(
        child: Text(
          step.toString(),
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: isActive ? const Color(0xFF2196F3) : Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildStepLine(bool isActive) {
    return Expanded(
      child: Container(
        height: 2,
        color: isActive ? Colors.white : Colors.white.withOpacity(0.3),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    bool isRequired = true,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF2196F3),
            Color(0xFF64B5F6)
          ], // Doctor blue gradient
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          validator: validator ??
              (isRequired
                  ? (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter $label';
                      }
                      return null;
                    }
                  : null),
          decoration: InputDecoration(
            labelText: isRequired ? '$label *' : label,
            prefixIcon: Icon(icon, color: const Color(0xFF2196F3)),
            border: InputBorder.none,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            errorStyle: TextStyle(
              color: Colors.red[600],
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBasicInformation() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Basic Information',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF2196F3), // Doctor blue
          ),
        ),
        const SizedBox(height: 16),

        // Full Name
        _buildInputField(
          controller: _fullNameController,
          label: 'Full Name',
          icon: EvaIcons.personOutline,
          validator: _validateName,
        ),

        // Email
        _buildInputField(
          controller: _emailController,
          label: 'Email',
          icon: EvaIcons.emailOutline,
          keyboardType: TextInputType.emailAddress,
          validator: _validateEmail,
        ),

        // Mobile Number
        _buildInputField(
          controller: _mobileController,
          label: 'Mobile Number',
          icon: EvaIcons.phoneOutline,
          keyboardType: TextInputType.phone,
          validator: _validateMobile,
        ),

        // Alternate Mobile
        _buildInputField(
          controller: _alternateMobileController,
          label: 'Alternate Mobile',
          icon: EvaIcons.phoneOutline,
          keyboardType: TextInputType.phone,
          isRequired: false,
        ),

        // Gender
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF2196F3), Color(0xFF64B5F6)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: DropdownButtonFormField<String>(
              value: _selectedGender,
              decoration: const InputDecoration(
                labelText: 'Gender *',
                prefixIcon:
                    Icon(EvaIcons.personOutline, color: Color(0xFF2196F3)),
                border: InputBorder.none,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              ),
              items: _genderOptions.map((String gender) {
                return DropdownMenuItem<String>(
                  value: gender,
                  child: Text(gender),
                );
              }).toList(),
              onChanged: (String? newValue) {
                setState(() {
                  _selectedGender = newValue!;
                });
              },
            ),
          ),
        ),

        // Date of Birth
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF2196F3), Color(0xFF64B5F6)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: InkWell(
              onTap: () async {
                final DateTime? picked = await showDatePicker(
                  context: context,
                  initialDate: _selectedDateOfBirth ?? DateTime.now(),
                  firstDate: DateTime(1900),
                  lastDate: DateTime.now(),
                );
                if (picked != null && picked != _selectedDateOfBirth) {
                  setState(() {
                    _selectedDateOfBirth = picked;
                  });
                }
              },
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(EvaIcons.calendarOutline,
                        color: Color(0xFF2196F3)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _selectedDateOfBirth != null
                            ? DateFormat('dd/MM/yyyy')
                                .format(_selectedDateOfBirth!)
                            : 'Select Date of Birth *',
                        style: GoogleFonts.poppins(
                          color: _selectedDateOfBirth != null
                              ? Colors.black87
                              : Colors.grey[600],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // Blood Group
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF2196F3), Color(0xFF64B5F6)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: DropdownButtonFormField<String>(
              value: _selectedBloodGroup,
              decoration: const InputDecoration(
                labelText: 'Blood Group *',
                prefixIcon:
                    Icon(EvaIcons.dropletOutline, color: Color(0xFF2196F3)),
                border: InputBorder.none,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              ),
              items: _bloodGroups.map((String group) {
                return DropdownMenuItem<String>(
                  value: group,
                  child: Text(group),
                );
              }).toList(),
              onChanged: (String? newValue) {
                setState(() {
                  _selectedBloodGroup = newValue!;
                });
              },
            ),
          ),
        ),

        // Address
        _buildInputField(
          controller: _addressController,
          label: 'Address',
          icon: EvaIcons.homeOutline,
        ),

        // City
        _buildInputField(
          controller: _cityController,
          label: 'City',
          icon: EvaIcons.homeOutline,
        ),

        // State
        _buildInputField(
          controller: _stateController,
          label: 'State',
          icon: EvaIcons.homeOutline,
        ),

        // Pincode
        _buildInputField(
          controller: _pincodeController,
          label: 'Pincode',
          icon: EvaIcons.homeOutline,
          keyboardType: TextInputType.number,
          validator: _validatePincode,
        ),

        // Location Capture
        _buildLocationCapture(),
      ],
    );
  }

  Widget _buildLocationCapture() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2196F3), Color(0xFF64B5F6)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(EvaIcons.navigationOutline,
                    color: Color(0xFF2196F3)),
                const SizedBox(width: 8),
                const Text(
                  'Location Coordinates',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2196F3),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_latitude != null && _longitude != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Location Captured:',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.green.shade700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Latitude: ${_latitude!.toStringAsFixed(6)}',
                      style: TextStyle(color: Colors.green.shade600),
                    ),
                    Text(
                      'Longitude: ${_longitude!.toStringAsFixed(6)}',
                      style: TextStyle(color: Colors.green.shade600),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isGettingLocation ? null : _getCurrentLocation,
                    icon: _isGettingLocation
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.my_location),
                    label: Text(_isGettingLocation
                        ? 'Getting Location...'
                        : 'Get Current Location'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2196F3),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _showManualLocationDialog,
                    icon: const Icon(Icons.edit_location),
                    label: const Text('Enter Manually'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF2196F3),
                      side: const BorderSide(color: Color(0xFF2196F3)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Location helps patients find you easily. You can capture automatically or enter manually.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfessionalDetails() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Professional Details',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF2196F3), // Doctor blue
          ),
        ),
        const SizedBox(height: 16),

        // Medical Registration Number
        _buildInputField(
          controller: _medicalRegistrationNumberController,
          label: 'Medical Registration Number',
          icon: EvaIcons.fileTextOutline,
          validator: _validateNMCNumber,
        ),

        // License Number
        _buildInputField(
          controller: _licenseNumberController,
          label: 'License Number',
          icon: EvaIcons.awardOutline,
          validator: _validateLicenseNumber,
        ),

        // Primary Specialization (single-select)
        const SizedBox(height: 16),
        Text(
          'Primary Specialization *',
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF2196F3), // Doctor blue
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border:
                Border.all(color: const Color(0xFF2196F3).withOpacity(0.25)),
          ),
          child: DropdownButtonFormField<String>(
            value: _primarySpecialization,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Select primary specialization',
              border: InputBorder.none,
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
            items: _specializationOptions
                .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                .toList(),
            onChanged: (value) {
              setState(() {
                _primarySpecialization = value;
                if (value != null && value.isNotEmpty) {
                  // Ensure primary appears first in the multi-select list
                  _selectedSpecializations.remove(value);
                  _selectedSpecializations.insert(0, value);
                }
              });
            },
          ),
        ),

        // Specializations
        Text(
          'Specializations *',
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF2196F3),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 300, // Increased height to show more specialties
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF2196F3).withOpacity(0.3)),
          ),
          child: Column(
            children: [
              // Search bar for specializations
              Padding(
                padding: const EdgeInsets.all(8),
                child: TextField(
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search, size: 20),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _specializationSearchQuery = value;
                    });
                  },
                ),
              ),
              // Specializations list
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  itemCount: _getFilteredSpecializations().length,
                  itemBuilder: (context, index) {
                    final specialization = _getFilteredSpecializations()[index];
                    return CheckboxListTile(
                      title: Text(
                        specialization,
                        style: GoogleFonts.poppins(fontSize: 14),
                      ),
                      value: _selectedSpecializations.contains(specialization),
                      onChanged: (bool? value) {
                        _toggleSpecialization(specialization);
                      },
                      activeColor: const Color(0xFF2196F3),
                      checkColor: Colors.white,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Experience Years
        _buildInputField(
          controller: _experienceYearsController,
          label: 'Years of Experience',
          icon: EvaIcons.clockOutline,
          keyboardType: TextInputType.number,
          validator: _validateExperience,
        ),

        // Consultation Fee
        _buildInputField(
          controller: _consultationFeeController,
          label: 'Consultation Fee',
          icon: EvaIcons.creditCardOutline,
          keyboardType: TextInputType.number,
          validator: _validateConsultationFee,
        ),

        // Qualifications (Multiple Selection)
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF2196F3), Color(0xFF64B5F6)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(EvaIcons.awardOutline,
                          color: Color(0xFF2196F3)),
                      const SizedBox(width: 12),
                      Text(
                        'Qualifications *',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                ),
                if (_selectedQualifications.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _selectedQualifications.map((qualification) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2196F3).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFF2196F3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                qualification,
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: const Color(0xFF2196F3),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(width: 4),
                              GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _selectedQualifications
                                        .remove(qualification);
                                  });
                                },
                                child: const Icon(
                                  Icons.close,
                                  size: 16,
                                  color: Color(0xFF2196F3),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: GestureDetector(
                    onTap: _showQualificationSelectionDialog,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 12, horizontal: 16),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.add, color: Color(0xFF2196F3)),
                          const SizedBox(width: 8),
                          Text(
                            _selectedQualifications.isEmpty
                                ? 'Select Qualifications'
                                : 'Add More Qualifications',
                            style: GoogleFonts.poppins(
                              color: _selectedQualifications.isEmpty
                                  ? Colors.grey[500]
                                  : const Color(0xFF2196F3),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Hospital Affiliations
        HospitalAffiliationSelector(
          selectedHospitals: _enhancedAffiliatedHospitals,
          onChanged: (hospitals) {
            setState(() {
              _enhancedAffiliatedHospitals = hospitals;
            });
          },
          userType: 'doctor',
          primaryColor: const Color(0xFF2196F3),
        ),
      ],
    );
  }

  Widget _buildDocumentUpload() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Document Upload',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF2196F3), // Doctor blue
          ),
        ),
        const SizedBox(height: 16),

        // Medical Degree
        _buildDocumentUploadField(
          title: 'Medical Degree Certificate *',
          subtitle:
              'Click to select your medical degree certificate (Image or PDF)',
          isUploaded: _medicalDegreeUrl != null,
          onTap: () => _pickDocument('medical_degree'),
          icon: EvaIcons.fileTextOutline,
        ),

        const SizedBox(height: 16),

        // License Certificate
        _buildDocumentUploadField(
          title: 'Medical License Certificate *',
          subtitle:
              'Click to select your medical license certificate (Image or PDF)',
          isUploaded: _licenseCertificateUrl != null,
          onTap: () => _pickDocument('license_certificate'),
          icon: EvaIcons.awardOutline,
        ),

        const SizedBox(height: 16),

        // Identity Proof
        _buildDocumentUploadField(
          title: 'Identity Proof *',
          subtitle:
              'Click to select your identity proof document (Image or PDF)',
          isUploaded: _identityProofUrl != null,
          onTap: () => _pickDocument('identity_proof'),
          icon: EvaIcons.personOutline,
        ),
      ],
    );
  }

  Widget _buildDocumentUploadField({
    required String title,
    required String subtitle,
    required bool isUploaded,
    required VoidCallback onTap,
    required IconData icon,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF2196F3),
            Color(0xFF64B5F6)
          ], // Doctor blue gradient
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: InkWell(
          onTap: _isUploading ? null : onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  _isUploading ? Icons.upload : icon,
                  color: const Color(0xFF2196F3), // Doctor blue
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isUploading
                            ? 'Uploading...'
                            : isUploaded
                                ? '$title Uploaded ✓'
                                : title,
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          color: isUploaded
                              ? const Color(0xFF2196F3)
                              : Colors.grey[600],
                        ),
                      ),
                      if (!isUploaded)
                        Text(
                          subtitle,
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.grey[500],
                          ),
                        ),
                    ],
                  ),
                ),
                if (_isUploading)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF2196F3),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF2196F3), // Doctor blue
              Color(0xFF1976D2),
              Color(0xFF0D47A1),
            ],
          ),
        ),
        child: SafeArea(
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(24),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                      Expanded(
                        child: Text(
                          'Doctor Registration',
                          style: GoogleFonts.poppins(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Step Indicator
                _buildStepIndicator(),

                // Form Content
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.all(24),
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_currentStep == 1) _buildBasicInformation(),
                          if (_currentStep == 2) _buildProfessionalDetails(),
                          if (_currentStep == 3) _buildDocumentUpload(),

                          const SizedBox(height: 32),

                          // Navigation Buttons
                          Row(
                            children: [
                              if (_currentStep > 1)
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () {
                                      setState(() {
                                        _currentStep--;
                                      });
                                    },
                                    style: OutlinedButton.styleFrom(
                                      side: const BorderSide(
                                          color: Color(0xFF2196F3)),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(28),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 16),
                                    ),
                                    child: Text(
                                      'Previous',
                                      style: GoogleFonts.poppins(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF2196F3),
                                      ),
                                    ),
                                  ),
                                ),
                              if (_currentStep > 1) const SizedBox(width: 16),
                              Expanded(
                                child: Container(
                                  height: 50,
                                  decoration: BoxDecoration(
                                    gradient: _canProceedToNextStep()
                                        ? const LinearGradient(
                                            colors: [
                                              Color(0xFF2196F3),
                                              Color(0xFF64B5F6)
                                            ], // Doctor blue gradient
                                            begin: Alignment.centerLeft,
                                            end: Alignment.centerRight,
                                          )
                                        : null,
                                    borderRadius: BorderRadius.circular(28),
                                    color: _canProceedToNextStep()
                                        ? null
                                        : Colors.grey[300],
                                  ),
                                  child: ElevatedButton(
                                    onPressed: _canProceedToNextStep()
                                        ? () {
                                            if (_currentStep < 3) {
                                              setState(() {
                                                _currentStep++;
                                              });
                                            } else {
                                              _registerDoctor();
                                            }
                                          }
                                        : null,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.transparent,
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(28),
                                      ),
                                      shadowColor: Colors.transparent,
                                    ),
                                    child: _isLoading
                                        ? const CircularProgressIndicator(
                                            color: Colors.white)
                                        : Text(
                                            _currentStep < 3
                                                ? 'Next'
                                                : 'Register Doctor',
                                            style: GoogleFonts.poppins(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
