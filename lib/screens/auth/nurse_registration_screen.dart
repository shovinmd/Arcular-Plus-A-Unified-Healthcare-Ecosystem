import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:typed_data';
import 'dart:io';
import '../../services/storage_service.dart';
import '../../services/registration_service.dart';
import '../../services/dashboard_navigation_service.dart';
import 'package:eva_icons_flutter/eva_icons_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../../widgets/hospital_affiliation_selector.dart';

class NurseRegistrationScreen extends StatefulWidget {
  final String signupEmail;
  final String signupPhone;
  final String signupPassword;
  final String signupCountryCode;

  const NurseRegistrationScreen({
    super.key,
    required this.signupEmail,
    required this.signupPhone,
    required this.signupPassword,
    required this.signupCountryCode,
  });

  @override
  State<NurseRegistrationScreen> createState() =>
      _NurseRegistrationScreenState();
}

class _NurseRegistrationScreenState extends State<NurseRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();

  // Basic Information Controllers
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _altPhoneController = TextEditingController();

  // Personal Details Controllers
  String _selectedGender = 'Female';
  DateTime? _selectedDateOfBirth; // Changed to nullable, no default value
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _pincodeController = TextEditingController();

  // Professional Details Controllers
  final _licenseNumberController = TextEditingController();
  final _qualificationController = TextEditingController();
  final _experienceController = TextEditingController();
  final _specializationController = TextEditingController(); // Optional
  final _currentHospitalIdController = TextEditingController();

  // Document Upload
  String? _licenseDocumentUrl;
  String? _profilePictureUrl;
  String? _nursingDegreeUrl;
  String? _identityProofUrl;
  bool _isUploading = false;

  // Location and Hospital Affiliation
  double? _longitude;
  double? _latitude;
  bool _isGettingLocation = false;
  List<Map<String, dynamic>> _nurseAffiliatedHospitals = [];

  // Form State
  bool _isLoading = false;
  int _currentStep = 1; // 1: Basic Info, 2: Professional, 3: Documents

  // Ensure Firebase user exists before uploads (fixes web 403)
  Future<void> _ensureFirebaseAuthForUpload() async {
    try {
      // First, check if Firebase is properly initialized
      print('🔍 Checking Firebase initialization...');
      try {
        await FirebaseAuth.instance.authStateChanges().first;
        print('✅ Firebase Auth is initialized');
      } catch (e) {
        print('❌ Firebase Auth initialization error: $e');
        return;
      }

      // Check current user state
      User? currentUser = FirebaseAuth.instance.currentUser;
      print('👤 Current user: ${currentUser?.uid ?? 'null'}');
      print('📧 Current user email: ${currentUser?.email ?? 'null'}');

      if (currentUser == null) {
        print(
            '🔍 No authenticated user found, attempting to create or sign in...');

        // Try to get the last known user from SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        final lastEmail = prefs.getString('last_signup_email');
        final lastPassword = prefs.getString('last_signup_password');

        if (lastEmail != null && lastEmail.isNotEmpty) {
          print(
              '🔄 Attempting to create or sign in with stored credentials...');
          try {
            // If password is available, try to create or sign in
            if (lastPassword != null && lastPassword.isNotEmpty) {
              try {
                final userCredential =
                    await FirebaseAuth.instance.createUserWithEmailAndPassword(
                  email: lastEmail,
                  password: lastPassword,
                );
                currentUser = userCredential.user;
                print(
                    '✅ Successfully created Firebase user: ${currentUser?.uid}');
              } catch (e) {
                print('❌ User creation failed, trying to sign in: $e');
                // If user already exists, try to sign in
                try {
                  final userCredential =
                      await FirebaseAuth.instance.signInWithEmailAndPassword(
                    email: lastEmail,
                    password: lastPassword,
                  );
                  currentUser = userCredential.user;
                  print(
                      '✅ Successfully signed in existing user: ${currentUser?.uid}');
                } catch (signInError) {
                  print('❌ Sign in failed: $signInError');
                  throw Exception('Authentication failed: $signInError');
                }
              }
            } else {
              print('⚠️ No password stored, this might be a Google signup');
              throw Exception('Please complete the signup process first.');
            }
          } catch (e) {
            print('❌ Authentication failed: $e');
            throw Exception('Authentication failed: $e');
          }
        } else {
          print('⚠️ No stored credentials found');
          throw Exception(
              'No stored credentials found. Please complete signup first.');
        }
      } else {
        print('✅ User already authenticated: ${currentUser.uid}');
      }
    } catch (e) {
      print('❌ Error in _ensureFirebaseAuthForUpload: $e');
      rethrow;
    }
  }

  // Lists for dropdowns
  final List<String> _genderOptions = ['Male', 'Female', 'Other'];
  final List<String> _specializations = [
    'General Nursing',
    'Critical Care Nursing',
    'Emergency Nursing',
    'Pediatric Nursing',
    'Maternal Health Nursing',
    'Mental Health Nursing',
    'Oncology Nursing',
    'Cardiac Nursing',
    'Neurological Nursing',
    'Orthopedic Nursing',
    'Surgical Nursing',
    'Community Health Nursing',
    'Geriatric Nursing',
    'Intensive Care Nursing',
  ];

  final List<String> _qualificationOptions = [
    'GNM (General Nursing and Midwifery)',
    'B.Sc Nursing',
    'M.Sc Nursing',
    'ANM (Auxiliary Nurse and Midwifery)',
    'Post Basic B.Sc Nursing',
    'Diploma in Nursing',
    'Other'
  ];

  @override
  void initState() {
    super.initState();

    // Pre-fill email and phone if provided from signup
    if (widget.signupEmail.isNotEmpty) {
      _emailController.text = widget.signupEmail;
    }
    if (widget.signupPhone.isNotEmpty) {
      _phoneController.text = widget.signupPhone;
    }

    // Set default values
    _selectedGender = 'Female';
    _selectedDateOfBirth =
        DateTime.now().subtract(const Duration(days: 10950)); // 30 years ago

    // Add listeners to trigger UI updates when fields change
    _fullNameController.addListener(() => setState(() {}));
    _emailController.addListener(() => setState(() {}));
    _phoneController.addListener(() => setState(() {}));
    _addressController.addListener(() => setState(() {}));
    _cityController.addListener(() => setState(() {}));
    _stateController.addListener(() => setState(() {}));
    _pincodeController.addListener(() => setState(() {}));
    _licenseNumberController.addListener(() => setState(() {}));
    _specializationController.addListener(() => setState(() {}));
    _experienceController.addListener(() => setState(() {}));
    _currentHospitalIdController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    // Remove listeners
    _fullNameController.removeListener(() => setState(() {}));
    _emailController.removeListener(() => setState(() {}));
    _phoneController.removeListener(() => setState(() {}));
    _addressController.removeListener(() => setState(() {}));
    _cityController.removeListener(() => setState(() {}));
    _stateController.removeListener(() => setState(() {}));
    _pincodeController.removeListener(() => setState(() {}));
    _licenseNumberController.removeListener(() => setState(() {}));
    _specializationController.removeListener(() => setState(() {}));
    _experienceController.removeListener(() => setState(() {}));
    _currentHospitalIdController.removeListener(() => setState(() {}));

    // Dispose controllers
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _pincodeController.dispose();
    _licenseNumberController.dispose();
    _specializationController.dispose();
    _experienceController.dispose();
    _currentHospitalIdController.dispose();
    super.dispose();
  }

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
        backgroundColor: Colors.orange,
        action: SnackBarAction(
          label: 'Enter Manually',
          textColor: Colors.white,
          onPressed: _showManualLocationDialog,
        ),
      ),
    );
  }

  void _showManualLocationDialog() {
    final latController = TextEditingController();
    final lngController = TextEditingController();

    if (_latitude != null) latController.text = _latitude.toString();
    if (_longitude != null) lngController.text = _longitude.toString();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enter Location Manually'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: latController,
              decoration: const InputDecoration(
                labelText: 'Latitude',
              ),
              keyboardType: TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: lngController,
              decoration: const InputDecoration(
                labelText: 'Longitude',
              ),
              keyboardType: TextInputType.numberWithOptions(decimal: true),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final lat = double.tryParse(latController.text);
              final lng = double.tryParse(lngController.text);

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
                Navigator.of(context).pop();
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

  bool _canProceedToNextStep() {
    switch (_currentStep) {
      case 1:
        return _fullNameController.text.trim().isNotEmpty &&
            _emailController.text.trim().isNotEmpty &&
            _phoneController.text.trim().isNotEmpty &&
            _addressController.text.trim().isNotEmpty &&
            _cityController.text.trim().isNotEmpty &&
            _stateController.text.trim().isNotEmpty &&
            _pincodeController.text.trim().isNotEmpty &&
            _selectedDateOfBirth != null;
      case 2:
        return _licenseNumberController.text.trim().isNotEmpty &&
            _qualificationController.text.trim().isNotEmpty &&
            _experienceController.text.trim().isNotEmpty &&
            _currentHospitalIdController.text.trim().isNotEmpty;
      case 3:
        return _licenseDocumentUrl != null &&
            _profilePictureUrl != null &&
            _nursingDegreeUrl != null &&
            _identityProofUrl != null;
      default:
        return false;
    }
  }

  Future<void> _selectDateOfBirth() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate:
          _selectedDateOfBirth ?? DateTime.now(), // Use current date if null
      firstDate:
          DateTime.now().subtract(const Duration(days: 36500)), // 100 years ago
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDateOfBirth) {
      setState(() {
        _selectedDateOfBirth = picked;
      });
    }
  }

  Future<void> _pickLicenseDocument() async {
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

      Uint8List? selectedBytes;
      String generatedName =
          'nurse_license_${DateTime.now().millisecondsSinceEpoch}';

      if (choice == 'image') {
        final XFile? image = await ImagePicker().pickImage(
          source: ImageSource.gallery,
          maxWidth: 1024,
          maxHeight: 1024,
          imageQuality: 80,
        );
        if (image != null) {
          selectedBytes = await image.readAsBytes();
          generatedName = '${generatedName}.jpg';
        }
      } else if (choice == 'pdf') {
        final FilePickerResult? result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['pdf'],
        );
        if (result != null && result.files.isNotEmpty) {
          if (result.files.single.bytes != null) {
            selectedBytes = result.files.single.bytes!;
          } else if (result.files.single.path != null) {
            selectedBytes = await File(result.files.single.path!).readAsBytes();
          }
          generatedName = '${generatedName}.pdf';
        }
      }

      if (selectedBytes != null) {
        await _ensureFirebaseAuthForUpload();
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) throw Exception('Not authenticated');

        print('✅ User authenticated for document upload: ${user.uid}');

        final String? downloadUrl = await StorageService().uploadCertificate(
          userId: user.uid,
          userType: 'nurse',
          certificateType: 'license',
          fileName: generatedName,
          fileBytes: selectedBytes,
        );

        if (downloadUrl == null) {
          throw Exception('Failed to upload license document');
        }

        setState(() {
          _licenseDocumentUrl = downloadUrl;
          _isUploading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('License document uploaded successfully!'),
            backgroundColor: Color(0xFF9C27B0),
          ),
        );
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
          content: Text('Failed to upload license document: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _pickNursingDegree() async {
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

      Uint8List? selectedBytes;
      String generatedName =
          'nurse_degree_${DateTime.now().millisecondsSinceEpoch}';

      if (choice == 'image') {
        final XFile? image = await ImagePicker().pickImage(
          source: ImageSource.gallery,
          maxWidth: 1024,
          maxHeight: 1024,
          imageQuality: 80,
        );
        if (image != null) {
          selectedBytes = await image.readAsBytes();
          generatedName = '${generatedName}.jpg';
        }
      } else if (choice == 'pdf') {
        final FilePickerResult? result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['pdf'],
        );
        if (result != null && result.files.isNotEmpty) {
          if (result.files.single.bytes != null) {
            selectedBytes = result.files.single.bytes!;
          } else if (result.files.single.path != null) {
            selectedBytes = await File(result.files.single.path!).readAsBytes();
          }
          generatedName = '${generatedName}.pdf';
        }
      }

      if (selectedBytes != null) {
        await _ensureFirebaseAuthForUpload();
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) throw Exception('Not authenticated');

        print('✅ User authenticated for document upload: ${user.uid}');

        final String? downloadUrl = await StorageService().uploadCertificate(
          userId: user.uid,
          userType: 'nurse',
          certificateType: 'degree',
          fileName: generatedName,
          fileBytes: selectedBytes,
        );

        if (downloadUrl == null) {
          throw Exception('Failed to upload nursing degree document');
        }

        setState(() {
          _nursingDegreeUrl = downloadUrl;
          _isUploading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Nursing degree uploaded successfully!'),
            backgroundColor: Color(0xFF9C27B0),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isUploading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to upload nursing degree: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _pickIdentityProof() async {
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

      Uint8List? selectedBytes;
      String generatedName =
          'nurse_identity_${DateTime.now().millisecondsSinceEpoch}';

      if (choice == 'image') {
        final XFile? image = await ImagePicker().pickImage(
          source: ImageSource.gallery,
          maxWidth: 1024,
          maxHeight: 1024,
          imageQuality: 80,
        );
        if (image != null) {
          selectedBytes = await image.readAsBytes();
          generatedName = '${generatedName}.jpg';
        }
      } else if (choice == 'pdf') {
        final FilePickerResult? result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['pdf'],
        );
        if (result != null && result.files.isNotEmpty) {
          if (result.files.single.bytes != null) {
            selectedBytes = result.files.single.bytes!;
          } else if (result.files.single.path != null) {
            selectedBytes = await File(result.files.single.path!).readAsBytes();
          }
          generatedName = '${generatedName}.pdf';
        }
      }

      if (selectedBytes != null) {
        await _ensureFirebaseAuthForUpload();
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) throw Exception('Not authenticated');

        print('✅ User authenticated for document upload: ${user.uid}');

        final String? downloadUrl = await StorageService().uploadCertificate(
          userId: user.uid,
          userType: 'nurse',
          certificateType: 'identity',
          fileName: generatedName,
          fileBytes: selectedBytes,
        );

        if (downloadUrl == null) {
          throw Exception('Failed to upload identity proof document');
        }

        setState(() {
          _identityProofUrl = downloadUrl;
          _isUploading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Identity proof uploaded successfully!'),
            backgroundColor: Color(0xFF9C27B0),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isUploading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to upload identity proof: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _pickProfilePicture() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );

      if (image != null) {
        setState(() {
          _isUploading = true;
        });

        // Reduced upload delay for faster response
        await Future.delayed(const Duration(milliseconds: 500));

        await _ensureFirebaseAuthForUpload();
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) throw Exception('Not authenticated');

        print('✅ User authenticated for profile picture upload: ${user.uid}');
        final bytes = await image.readAsBytes();
        final String? downloadUrl = await StorageService().uploadProfilePicture(
          userId: user.uid,
          userType: 'nurse',
          imageBytes: bytes,
        );

        if (downloadUrl == null) {
          throw Exception('Failed to upload profile picture');
        }

        setState(() {
          _profilePictureUrl = downloadUrl;
          _isUploading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile picture uploaded successfully!'),
            backgroundColor: Color(0xFF9C27B0),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isUploading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to upload profile picture: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _registerNurse() async {
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
      // Ensure user is authenticated first
      User? firebaseUser = FirebaseAuth.instance.currentUser;

      if (firebaseUser == null) {
        // Try to create or sign in user if not authenticated
        if (widget.signupEmail.isNotEmpty && widget.signupPassword.isNotEmpty) {
          try {
            // Try to create user first
            final userCredential =
                await FirebaseAuth.instance.createUserWithEmailAndPassword(
              email: widget.signupEmail,
              password: widget.signupPassword,
            );
            firebaseUser = userCredential.user;
          } catch (e) {
            // If user already exists, try to sign in
            try {
              final userCredential =
                  await FirebaseAuth.instance.signInWithEmailAndPassword(
                email: widget.signupEmail,
                password: widget.signupPassword,
              );
              firebaseUser = userCredential.user;
            } catch (signInError) {
              throw Exception('Authentication failed: $signInError');
            }
          }
        } else {
          throw Exception('No email/password provided for authentication');
        }
      }

      if (firebaseUser == null) {
        throw Exception('Failed to authenticate user');
      }

      // Create nurse user model
      final nurseUser = {
        'uid': firebaseUser.uid,
        'fullName': _fullNameController.text.trim(),
        'email': _emailController.text.trim(),
        'mobileNumber': _phoneController.text.trim(),
        'gender': _selectedGender,
        'dateOfBirth': _selectedDateOfBirth?.toIso8601String() ?? '',
        'address': _addressController.text.trim(),
        'city': _cityController.text.trim(),
        'state': _stateController.text.trim(),
        'pincode': _pincodeController.text.trim(),
        'longitude': _longitude,
        'latitude': _latitude,
        'qualification': _qualificationController.text.trim(),
        'experienceYears': int.tryParse(_experienceController.text) ?? 0,
        'licenseNumber': _licenseNumberController.text.trim(),
        'registrationNumber':
            'REG-${_licenseNumberController.text.trim()}', // Create unique registration number
        'licenseDocumentUrl': _licenseDocumentUrl ?? '',
        'hospitalAffiliation': _currentHospitalIdController.text.trim(),
        'profileImageUrl': _profilePictureUrl ?? '',
        'affiliatedHospitals': _nurseAffiliatedHospitals, // Fixed field name
        'shifts': [], // Initialize empty shifts array
        'currentHospital':
            _currentHospitalIdController.text.trim(), // Add current hospital
        'role': 'Staff', // Add default role
        'bio': '', // Add empty bio field
        'education':
            _qualificationController.text.trim(), // Add education field
        'specialization': _specializationController.text.trim(),
        'workingHours': {}, // Add empty working hours
        'nursingDegreeUrl': _nursingDegreeUrl ?? '', // Add nursing degree URL
        'identityProofUrl': _identityProofUrl ?? '', // Add identity proof URL
      };

      // Use the registration service
      final result = await RegistrationService.registerUser(
        userType: 'nurse',
        userData: nurseUser,
        documents: [], // No documents needed since we're sending direct URLs
        documentTypes: [],
        uploadedDocuments: {},
      );

      if (result['success']) {
        // Save user type to SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_type', 'nurse');
        await prefs.setString('user_gender', _selectedGender);
        await prefs.setString('user_uid', firebaseUser.uid);
        await prefs.setString('user_status', 'pending');

        if (mounted) {
          // Show success popup
          await _showCustomPopup(
            success: true,
            message: result['message'] ??
                'Nurse registration successful! Your account is pending approval.',
          );

          // Navigate based on user type and approval status
          await DashboardNavigationService.navigateAfterRegistration(
            context,
            'nurse',
            'pending',
          );
        }
      } else {
        if (mounted) {
          await _showCustomPopup(
            success: false,
            message: result['message'] ??
                'Failed to register nurse. Please check your internet connection and try again.',
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
    final gender = prefs.getString('user_gender') ?? 'Female';
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
                'Professional',
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
            color: isActive ? const Color(0xFF9C27B0) : Colors.white,
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

  String? _validateLicenseNumber(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter nursing license number';
    }

    // Remove spaces and convert to uppercase for validation
    String cleanValue = value.replaceAll(' ', '').toUpperCase();

    // INC format: Usually starts with RN (Registered Nurse) or RNRM (Registered Nurse and Registered Midwife)
    // Examples: RN12345, RNRM67890, RN123456, RNRM789012
    if (!RegExp(r'^(RN|RNRM)[0-9]{4,6}$').hasMatch(cleanValue)) {
      return 'Invalid INC format. Use format like RN12345 or RNRM67890';
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
          colors: [Color(0xFFEFD5FF), Color(0xFF515ADA)],
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
            prefixIcon: Icon(icon, color: const Color(0xFF515ADA)),
            border: InputBorder.none,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
            color: const Color(0xFF515ADA),
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

        // Phone Number
        _buildInputField(
          controller: _phoneController,
          label: 'Phone Number',
          icon: EvaIcons.phoneOutline,
          keyboardType: TextInputType.phone,
          validator: _validateMobile,
        ),

        // Alternate Phone
        _buildInputField(
          controller: _altPhoneController,
          label: 'Alternate Phone',
          icon: EvaIcons.phoneOutline,
          keyboardType: TextInputType.phone,
          isRequired: false,
        ),

        // Gender
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFEFD5FF), Color(0xFF515ADA)],
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
                    Icon(EvaIcons.personOutline, color: Color(0xFF515ADA)),
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
              colors: [Color(0xFFEFD5FF), Color(0xFF515ADA)],
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
              onTap: _selectDateOfBirth,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today, color: Color(0xFF515ADA)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _selectedDateOfBirth == null
                            ? 'Select Date of Birth'
                            : '${_selectedDateOfBirth!.day}/${_selectedDateOfBirth!.month}/${_selectedDateOfBirth!.year}',
                        style: GoogleFonts.poppins(
                          color: Colors.black87,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
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
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF515ADA).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF515ADA).withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(EvaIcons.navigationOutline, color: const Color(0xFF515ADA)),
              const SizedBox(width: 8),
              Text(
                'Location Coordinates',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF515ADA),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Location buttons
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
                      ? 'Getting...'
                      : 'Get Current Location'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF515ADA),
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
                    foregroundColor: const Color(0xFF515ADA),
                    side: BorderSide(color: const Color(0xFF515ADA)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),

          // Display captured coordinates
          if (_latitude != null && _longitude != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Captured Location:',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Latitude: ${_latitude!.toStringAsFixed(6)}',
                    style: GoogleFonts.poppins(fontSize: 12),
                  ),
                  Text(
                    'Longitude: ${_longitude!.toStringAsFixed(6)}',
                    style: GoogleFonts.poppins(fontSize: 12),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 8),
          Text(
            'Location helps patients find you easily and enables distance-based search.',
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
        ],
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
            color: const Color(0xFF515ADA),
          ),
        ),
        const SizedBox(height: 16),

        // License Number
        _buildInputField(
          controller: _licenseNumberController,
          label: 'Nursing License Number',
          icon: EvaIcons.awardOutline,
          validator: _validateLicenseNumber,
        ),

        // Qualification
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFEFD5FF), Color(0xFF515ADA)],
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
              value: _qualificationController.text.isEmpty
                  ? null
                  : _qualificationController.text,
              decoration: const InputDecoration(
                labelText: 'Qualification *',
                prefixIcon:
                    Icon(EvaIcons.awardOutline, color: Color(0xFF515ADA)),
                border: InputBorder.none,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              ),
              items: _qualificationOptions.map((String qualification) {
                return DropdownMenuItem<String>(
                  value: qualification,
                  child: Text(qualification),
                );
              }).toList(),
              onChanged: (String? newValue) {
                setState(() {
                  _qualificationController.text = newValue ?? '';
                });
              },
            ),
          ),
        ),

        // Experience
        _buildInputField(
          controller: _experienceController,
          label: 'Years of Experience',
          icon: EvaIcons.clockOutline,
          keyboardType: TextInputType.number,
          validator: _validateExperience,
        ),

        // Specialization (optional)
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: DropdownButtonFormField<String>(
            value: _specializationController.text.isNotEmpty
                ? _specializationController.text
                : null,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Specialization (Optional)',
              prefixIcon: Icon(EvaIcons.heartOutline, color: Color(0xFF515ADA)),
              border: InputBorder.none,
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
            items: _specializations
                .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                .toList(),
            onChanged: (String? newValue) {
              setState(() {
                _specializationController.text = newValue ?? '';
              });
            },
          ),
        ),

        // Current Hospital
        _buildInputField(
          controller: _currentHospitalIdController,
          label: 'Current Hospital *',
          icon: EvaIcons.homeOutline,
          isRequired: true,
        ),

        // Hospital Affiliations
        HospitalAffiliationSelector(
          selectedHospitals: _nurseAffiliatedHospitals,
          onChanged: (hospitals) {
            setState(() {
              _nurseAffiliatedHospitals = hospitals;
            });
          },
          userType: 'nurse',
          primaryColor: const Color(0xFF515ADA),
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
            color: const Color(0xFF515ADA),
          ),
        ),
        const SizedBox(height: 16),

        // License Document
        _buildDocumentUploadField(
          title: 'Nursing License Certificate *',
          subtitle:
              'Click to select your nursing license certificate (Image or PDF)',
          isUploaded: _licenseDocumentUrl != null,
          onTap: () => _pickLicenseDocument(),
          icon: EvaIcons.awardOutline,
        ),

        const SizedBox(height: 16),

        // Profile Picture
        _buildDocumentUploadField(
          title: 'Profile Picture *',
          subtitle: 'Click to select your profile picture',
          isUploaded: _profilePictureUrl != null,
          onTap: () => _pickProfilePicture(),
          icon: EvaIcons.personOutline,
        ),

        const SizedBox(height: 16),

        // Nursing Degree
        _buildDocumentUploadField(
          title: 'Nursing Degree Certificate *',
          subtitle:
              'Click to select your nursing degree certificate (Image or PDF)',
          isUploaded: _nursingDegreeUrl != null,
          onTap: () => _pickNursingDegree(),
          icon: EvaIcons.bookOutline,
        ),

        const SizedBox(height: 16),

        // Identity Proof
        _buildDocumentUploadField(
          title: 'Identity Proof *',
          subtitle:
              'Click to select your identity proof document (Image or PDF)',
          isUploaded: _identityProofUrl != null,
          onTap: () => _pickIdentityProof(),
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
          colors: [Color(0xFFEFD5FF), Color(0xFF515ADA)],
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
                  color: const Color(0xFF515ADA),
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
                              ? const Color(0xFF515ADA)
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
                      color: Color(0xFF515ADA),
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
              Color(0xFFEFD5FF),
              Color(0xFFBFA9FF),
              Color(0xFF515ADA),
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
                          'Nurse Registration',
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
                                          color: Color(0xFF515ADA)),
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
                                        color: Color(0xFF515ADA),
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
                                              Color(0xFFEFD5FF),
                                              Color(0xFF515ADA)
                                            ],
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
                                              _registerNurse();
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
                                                : 'Register Nurse',
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
