import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:io';
import 'dart:typed_data';

import '../../models/user_model.dart';
import '../../services/api_service.dart';
import '../../services/storage_service.dart';
import '../../services/registration_service.dart';
import '../../services/dashboard_navigation_service.dart';
import '../../widgets/input_field.dart';
import '../../widgets/custom_button.dart';
import 'package:glassmorphism/glassmorphism.dart';
import 'package:eva_icons_flutter/eva_icons_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../hospital/dashboard_hospital.dart';
import 'approval_pending_screen.dart';

class HospitalRegistrationScreen extends StatefulWidget {
  final String signupEmail;
  final String signupPhone;
  final String signupPassword;
  final String signupCountryCode;

  const HospitalRegistrationScreen({
    super.key,
    required this.signupEmail,
    required this.signupPhone,
    required this.signupPassword,
    required this.signupCountryCode,
  });

  @override
  State<HospitalRegistrationScreen> createState() =>
      _HospitalRegistrationScreenState();
}

class _HospitalRegistrationScreenState
    extends State<HospitalRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _storageService = StorageService();

  // Basic Information Controllers
  final TextEditingController _hospitalNameController = TextEditingController();
  final TextEditingController _hospitalOwnerNameController =
      TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _altPhoneController = TextEditingController();

  // Location Details Controllers
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _stateController = TextEditingController();
  final TextEditingController _pincodeController = TextEditingController();
  final TextEditingController _longitudeController = TextEditingController();
  final TextEditingController _latitudeController = TextEditingController();

  // Operational Details Controllers
  final TextEditingController _registrationNumberController =
      TextEditingController();
  final TextEditingController _numberOfBedsController = TextEditingController();

  // Dropdown Values
  String _selectedHospitalType = 'Private';
  List<String> _selectedDepartments = [];
  List<String> _selectedSpecialFacilities = [];

  // Location coordinates
  double? _longitude;
  double? _latitude;
  bool _isGettingLocation = false;

  // File Upload
  File? _licenseDocument;
  File? _registrationCertificate;
  File? _buildingPermit;
  String? _licenseDocumentUrl;
  String? _registrationCertificateUrl;
  String? _buildingPermitUrl;
  bool _isUploading = false;

  // Form State
  bool _isLoading = false;
  bool _isGoogleSignup = false; // Added for Google signup tracking
  String? _errorMessage;
  int _currentStep =
      1; // 1: Basic Info, 2: Location, 3: Operational, 4: Documents

  // Options for dropdowns
  final List<String> _hospitalTypes = [
    'Public',
    'Private',
    'Clinic',
    'Diagnostic Centre',
    'Multi-Specialty',
    'Super-Specialty',
  ];

  final List<String> _departments = [
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
  ];

  List<String> get _specializationOptions => _departments; // reuse

  final List<String> _specialFacilities = [
    'ICU',
    'NICU',
    'CCU',
    'Dialysis',
    'Blood Bank',
    'Pharmacy',
    'Laboratory',
    'Radiology',
    'Ambulance Service',
    'Emergency Room',
    'Operation Theater',
    'Recovery Room',
    'Maternity Ward',
    'Pediatric Ward',
    'Geriatric Ward',
    'Trauma Center',
    'Burn Unit',
    'Cancer Center',
    'Rehabilitation Center',
    'Telemedicine',
  ];

  @override
  void initState() {
    super.initState();

    // Ensure Firebase user is authenticated
    _ensureUserAuthenticated();

    // Pre-fill email and phone if provided from signup
    if (widget.signupEmail.isNotEmpty) {
      _emailController.text = widget.signupEmail;
      _isGoogleSignup = true;
    }
    if (widget.signupPhone.isNotEmpty) {
      _phoneController.text = widget.signupPhone;
    }

    // Set default values
    _selectedHospitalType = 'Private';
    _selectedDepartments = [];
    _selectedSpecialFacilities = [];

    // Add listeners to trigger UI updates when fields change
    _hospitalNameController.addListener(() => setState(() {}));
    _emailController.addListener(() => setState(() {}));
    _phoneController.addListener(() => setState(() {}));
    _addressController.addListener(() => setState(() {}));
    _cityController.addListener(() => setState(() {}));
    _stateController.addListener(() => setState(() {}));
    _pincodeController.addListener(() => setState(() {}));
    _longitudeController.addListener(() => setState(() {}));
    _latitudeController.addListener(() => setState(() {}));
    _registrationNumberController.addListener(() => setState(() {}));
  }

  Future<void> _ensureUserAuthenticated() async {
    try {
      print('🔍 Checking Firebase authentication state...');

      // Check if user is currently authenticated
      final currentUser = FirebaseAuth.instance.currentUser;
      print('👤 Current user: ${currentUser?.uid ?? 'null'}');
      print('📧 Current user email: ${currentUser?.email ?? 'null'}');

      if (currentUser == null) {
        print(
            '❌ No authenticated user found, attempting to create or sign in...');

        // Try to get the last known user from SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        final lastEmail = prefs.getString('last_signup_email');
        final lastPassword = prefs.getString('last_signup_password');

        print('💾 Stored email: $lastEmail');
        print('💾 Stored password: ${lastPassword != null ? '***' : 'null'}');

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
                print(
                    '✅ Successfully created Firebase user: ${userCredential.user?.uid}');
              } catch (e) {
                print('❌ User creation failed, trying to sign in: $e');
                // If user already exists, try to sign in
                try {
                  final userCredential =
                      await FirebaseAuth.instance.signInWithEmailAndPassword(
                    email: lastEmail,
                    password: lastPassword,
                  );
                  print(
                      '✅ Successfully signed in existing user: ${userCredential.user?.uid}');
                } catch (signInError) {
                  print('❌ Sign in failed: $signInError');
                  // Don't throw here, let the user continue and handle it in registration
                }
              }
            } else {
              print('⚠️ No password stored, this might be a Google signup');
              // For Google signups, we'll handle authentication in the registration method
            }
          } catch (e) {
            print('❌ Authentication failed: $e');
            // Don't throw here, let the user continue and handle it in registration
          }
        } else {
          print('❌ No stored email found');
        }
      } else {
        print('✅ User is already authenticated');
        // Refresh the token to ensure it's valid
        try {
          final token = await currentUser.getIdToken(true);
          print('✅ Token refreshed successfully');
          print('🔑 Token preview: ${token?.substring(0, 20) ?? 'null'}...');
        } catch (e) {
          print('❌ Token refresh failed: $e');
        }
      }
    } catch (e) {
      print('❌ Error ensuring user authentication: $e');
    }
  }

  // Check if email was filled in signup
  bool get _wasEmailFilledInSignup => widget.signupEmail.isNotEmpty;

  // Check if phone was filled in signup
  bool get _wasPhoneFilledInSignup => widget.signupPhone.isNotEmpty;

  @override
  void dispose() {
    // Remove listeners
    _hospitalNameController.removeListener(() => setState(() {}));
    _emailController.removeListener(() => setState(() {}));
    _phoneController.removeListener(() => setState(() {}));
    _addressController.removeListener(() => setState(() {}));
    _cityController.removeListener(() => setState(() {}));
    _stateController.removeListener(() => setState(() {}));
    _pincodeController.removeListener(() => setState(() {}));
    _longitudeController.removeListener(() => setState(() {}));
    _latitudeController.removeListener(() => setState(() {}));
    _registrationNumberController.removeListener(() => setState(() {}));

    // Dispose controllers
    _hospitalNameController.dispose();
    _hospitalOwnerNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _altPhoneController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _pincodeController.dispose();
    _longitudeController.dispose();
    _latitudeController.dispose();

    _registrationNumberController.dispose();
    _numberOfBedsController.dispose();
    super.dispose();
  }

  Future<void> _pickLicenseDocument() async {
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
                  setState(() {
                    _isUploading = false;
                  });
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content:
                            Text('Authentication failed. Please try again.'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                  return;
                }
              }
            } else {
              print('⚠️ No password stored, this might be a Google signup');
              setState(() {
                _isUploading = false;
              });
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Please complete the signup process first.'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
              return;
            }
          } catch (e) {
            print('❌ Authentication failed: $e');
            setState(() {
              _isUploading = false;
            });
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Authentication failed. Please try again.'),
                  backgroundColor: Colors.red,
                ),
              );
            }
            return;
          }
        } else {
          print('❌ No stored email found');
          setState(() {
            _isUploading = false;
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Please complete the signup process first.'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }
      }

      if (currentUser != null) {
        // Verify the user is still authenticated by getting a fresh token
        try {
          final token = await currentUser.getIdToken(true); // Force refresh
          print('✅ User token refreshed successfully');
          print('🔑 Token preview: ${token?.substring(0, 20) ?? 'null'}...');
        } catch (e) {
          print('❌ Token refresh failed: $e');
          setState(() {
            _isUploading = false;
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Authentication expired. Please try again.'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }
      }

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

      Uint8List? selectedBytes;
      String? fileName;

      if (choice == 'image') {
        // Pick image
        final XFile? image = await ImagePicker().pickImage(
          source: ImageSource.gallery,
          maxWidth: 1920,
          maxHeight: 1080,
          imageQuality: 85,
        );

        if (image != null) {
          selectedBytes = await image.readAsBytes();
          fileName =
              'hospital_licenses/${DateTime.now().millisecondsSinceEpoch}_${image.name}';
        }
      } else if (choice == 'pdf') {
        // Pick PDF
        FilePickerResult? result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['pdf'],
        );

        if (result != null && result.files.isNotEmpty) {
          final picked = result.files.single;
          if (picked.bytes != null) {
            selectedBytes = picked.bytes!;
          } else if (picked.path != null) {
            selectedBytes = await File(picked.path!).readAsBytes();
          }
          fileName =
              'hospital_licenses/${DateTime.now().millisecondsSinceEpoch}_${result.files.single.name}';
        }
      }

      if (selectedBytes != null) {
        setState(() {
          _isUploading = true;
        });

        // Ensure user is authenticated before upload
        if (currentUser == null) {
          print('❌ No authenticated user found for document upload');
          setState(() {
            _isUploading = false;
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Authentication error. Please try again.'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }

        print('✅ User authenticated for document upload: ${currentUser.uid}');

        // Upload to Firebase Storage
        try {
          final String? downloadUrl = await _storageService.uploadCertificate(
            userId: currentUser.uid,
            userType: 'hospital',
            certificateType: 'license',
            fileName: fileName ??
                'hospital_license_${DateTime.now().millisecondsSinceEpoch}',
            fileBytes: selectedBytes,
          );

          if (downloadUrl != null) {
            setState(() {
              _licenseDocumentUrl = downloadUrl;
              _isUploading = false;
            });

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'License document uploaded successfully!',
                    style: GoogleFonts.poppins(),
                  ),
                  backgroundColor: const Color(0xFF4CAF50), // Hospital green
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          } else {
            setState(() {
              _isUploading = false;
            });
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Failed to upload license document. Please try again.',
                    style: GoogleFonts.poppins(),
                  ),
                  backgroundColor: Colors.red,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          }
        } catch (e) {
          setState(() {
            _isUploading = false;
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Upload failed: $e',
                  style: GoogleFonts.poppins(),
                ),
                backgroundColor: Colors.red,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        }
      }
    } catch (e) {
      print('❌ Error in _pickLicenseDocument: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to pick document: $e',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _pickRegistrationCertificate() async {
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
        final XFile? image = await ImagePicker().pickImage(
          source: ImageSource.gallery,
          maxWidth: 1024,
          maxHeight: 1024,
          imageQuality: 80,
        );

        if (image != null) {
          // Upload to Firebase Storage
          try {
            final bytes = await image.readAsBytes();
            final fileName = image.path.split('/').last;

            final downloadUrl = await _storageService.uploadCertificate(
              userId: FirebaseAuth.instance.currentUser?.uid ?? '',
              userType: 'hospital',
              certificateType: 'registration',
              fileName: fileName,
              fileBytes: bytes,
            );

            setState(() {
              _registrationCertificate = File(image.path);
              _registrationCertificateUrl = downloadUrl;
              _isUploading = false;
            });

            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content:
                    Text('Registration certificate uploaded successfully!'),
                backgroundColor: Color(0xFF4CAF50),
              ),
            );
          } catch (e) {
            setState(() {
              _isUploading = false;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to upload registration certificate: $e'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } else if (choice == 'pdf') {
        // Pick PDF
        FilePickerResult? result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['pdf'],
        );

        if (result != null && result.files.isNotEmpty) {
          try {
            // Handle file properly for both web and mobile
            final file = result.files.first;
            File? selectedFile;

            if (file.path != null) {
              // Mobile platform
              selectedFile = File(file.path!);
            } else if (file.bytes != null) {
              // Web platform - create a temporary file
              final tempDir = Directory.systemTemp;
              final tempFile = File(
                  '${tempDir.path}/temp_registration_${DateTime.now().millisecondsSinceEpoch}.pdf');
              await tempFile.writeAsBytes(file.bytes!);
              selectedFile = tempFile;
            }

            if (selectedFile != null) {
              // Upload to Firebase Storage
              final bytes = await selectedFile.readAsBytes();
              final fileName = file.name;

              final downloadUrl = await _storageService.uploadCertificate(
                userId: FirebaseAuth.instance.currentUser?.uid ?? '',
                userType: 'hospital',
                certificateType: 'registration',
                fileName: fileName,
                fileBytes: bytes,
              );

              setState(() {
                _registrationCertificate = selectedFile;
                _registrationCertificateUrl = downloadUrl;
                _isUploading = false;
              });

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                      'Registration certificate PDF uploaded successfully!'),
                  backgroundColor: Color(0xFF4CAF50),
                ),
              );
            }
          } catch (e) {
            setState(() {
              _isUploading = false;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to upload registration certificate: $e'),
                backgroundColor: Colors.red,
              ),
            );
          }
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
          content: Text('Failed to upload registration certificate: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _pickBuildingPermit() async {
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
        final XFile? image = await ImagePicker().pickImage(
          source: ImageSource.gallery,
          maxWidth: 1024,
          maxHeight: 1024,
          imageQuality: 80,
        );

        if (image != null) {
          // Upload to Firebase Storage
          try {
            final bytes = await image.readAsBytes();
            final fileName = image.path.split('/').last;

            final downloadUrl = await _storageService.uploadCertificate(
              userId: FirebaseAuth.instance.currentUser?.uid ?? '',
              userType: 'hospital',
              certificateType: 'building',
              fileName: fileName,
              fileBytes: bytes,
            );

            setState(() {
              _buildingPermit = File(image.path);
              _buildingPermitUrl = downloadUrl;
              _isUploading = false;
            });

            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Building permit uploaded successfully!'),
                backgroundColor: Color(0xFF4CAF50),
              ),
            );
          } catch (e) {
            setState(() {
              _isUploading = false;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to upload building permit: $e'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } else if (choice == 'pdf') {
        // Pick PDF
        FilePickerResult? result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['pdf'],
        );

        if (result != null && result.files.isNotEmpty) {
          try {
            // Handle file properly for both web and mobile
            final file = result.files.first;
            File? selectedFile;

            if (file.path != null) {
              // Mobile platform
              selectedFile = File(file.path!);
            } else if (file.bytes != null) {
              // Web platform - create a temporary file
              final tempDir = Directory.systemTemp;
              final tempFile = File(
                  '${tempDir.path}/temp_building_${DateTime.now().millisecondsSinceEpoch}.pdf');
              await tempFile.writeAsBytes(file.bytes!);
              selectedFile = tempFile;
            }

            if (selectedFile != null) {
              // Upload to Firebase Storage
              final bytes = await selectedFile.readAsBytes();
              final fileName = file.name;

              final downloadUrl = await _storageService.uploadCertificate(
                userId: FirebaseAuth.instance.currentUser?.uid ?? '',
                userType: 'hospital',
                certificateType: 'building',
                fileName: fileName,
                fileBytes: bytes,
              );

              setState(() {
                _buildingPermit = selectedFile;
                _buildingPermitUrl = downloadUrl;
                _isUploading = false;
              });

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Building permit PDF uploaded successfully!'),
                  backgroundColor: Color(0xFF4CAF50),
                ),
              );
            }
          } catch (e) {
            setState(() {
              _isUploading = false;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to upload building permit: $e'),
                backgroundColor: Colors.red,
              ),
            );
          }
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
          content: Text('Failed to upload building permit: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _toggleDepartment(String department) {
    setState(() {
      if (_selectedDepartments.contains(department)) {
        _selectedDepartments.remove(department);
      } else {
        _selectedDepartments.add(department);
      }
    });
  }

  void _toggleSpecialFacility(String facility) {
    setState(() {
      if (_selectedSpecialFacilities.contains(facility)) {
        _selectedSpecialFacilities.remove(facility);
      } else {
        _selectedSpecialFacilities.add(facility);
      }
    });
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isGettingLocation = true;
    });

    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Location services are disabled. Please enable location services.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Check location permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                    'Location permissions are denied. Please enable location permissions.'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Location permissions are permanently denied. Please enable them in settings.'),
              backgroundColor: Colors.red,
            ),
          );
        }
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
        _latitudeController.text = _latitude!.toStringAsFixed(6);
        _longitudeController.text = _longitude!.toStringAsFixed(6);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Location fetched successfully: ${_latitude!.toStringAsFixed(4)}, ${_longitude!.toStringAsFixed(4)}'),
            backgroundColor: const Color(0xFF4CAF50),
          ),
        );
      }
    } catch (e) {
      print('❌ Error getting location: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to get location: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isGettingLocation = false;
      });
    }
  }

  bool _canProceedToNextStep() {
    switch (_currentStep) {
      case 1:
        final hospitalNameFilled =
            _hospitalNameController.text.trim().isNotEmpty;
        final emailFilled = _emailController.text.trim().isNotEmpty;
        final phoneFilled = _phoneController.text.trim().isNotEmpty;

        final canProceed = hospitalNameFilled && emailFilled && phoneFilled;

        print('Step 1 validation:');
        print(
            '  Hospital Name: "${_hospitalNameController.text.trim()}" ($hospitalNameFilled)');
        print('  Email: "${_emailController.text.trim()}" ($emailFilled)');
        print('  Phone: "${_phoneController.text.trim()}" ($phoneFilled)');
        print('  Can proceed: $canProceed');

        return canProceed;

      case 2:
        final addressFilled = _addressController.text.trim().isNotEmpty;
        final cityFilled = _cityController.text.trim().isNotEmpty;
        final stateFilled = _stateController.text.trim().isNotEmpty;
        final pincodeFilled = _pincodeController.text.trim().isNotEmpty;

        final canProceed =
            addressFilled && cityFilled && stateFilled && pincodeFilled;

        print('Step 2 validation:');
        print(
            '  Address: "${_addressController.text.trim()}" ($addressFilled)');
        print('  City: "${_cityController.text.trim()}" ($cityFilled)');
        print('  State: "${_stateController.text.trim()}" ($stateFilled)');
        print(
            '  Pincode: "${_pincodeController.text.trim()}" ($pincodeFilled)');
        print('  Can proceed: $canProceed');

        return canProceed;

      case 3:
        final registrationFilled =
            _registrationNumberController.text.trim().isNotEmpty;
        final departmentsSelected = _selectedDepartments.isNotEmpty;

        final canProceed = registrationFilled && departmentsSelected;

        print('Step 3 validation:');
        print(
            '  Registration Number: "${_registrationNumberController.text.trim()}" ($registrationFilled)');
        print(
            '  Departments: ${_selectedDepartments.length} selected ($departmentsSelected)');
        print('  Can proceed: $canProceed');

        return canProceed;

      case 4:
        final licenseUploaded = _licenseDocumentUrl != null;
        final registrationCertificateUploaded =
            _registrationCertificateUrl != null;
        final buildingPermitUploaded = _buildingPermitUrl != null;

        final canProceed = licenseUploaded &&
            registrationCertificateUploaded &&
            buildingPermitUploaded;

        print('Step 4 validation:');
        print('  License Document: ${licenseUploaded}');
        print('  Registration Certificate: ${registrationCertificateUploaded}');
        print('  Building Permit: ${buildingPermitUploaded}');
        print('  Can proceed: $canProceed');

        return canProceed;

      default:
        return false;
    }
  }

  Future<void> _registerHospital() async {
    if (!_formKey.currentState!.validate()) {
      print('❌ Form validation failed');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
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
      print('🚀 Starting hospital registration...');

      // 1. Ensure user is authenticated first
      User? firebaseUser = FirebaseAuth.instance.currentUser;
      String? passwordToUse =
          widget.signupPassword.isNotEmpty ? widget.signupPassword : '';

      print('🔍 Firebase Auth Check:');
      print('📧 Signup Email: ${widget.signupEmail}');
      print(
          '🔑 Signup Password: ${widget.signupPassword.isNotEmpty ? '***' : 'empty'}');
      print('👤 Current Firebase User: ${firebaseUser?.uid ?? 'null'}');

      if (firebaseUser == null) {
        print('🔍 No authenticated user found, creating Firebase user...');
        if (widget.signupEmail.isNotEmpty && passwordToUse.isNotEmpty) {
          // Create password-based account
          try {
            print(
                '🚀 Creating Firebase user with email: ${widget.signupEmail}');
            final userCredential =
                await FirebaseAuth.instance.createUserWithEmailAndPassword(
              email: widget.signupEmail,
              password: passwordToUse,
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
                email: widget.signupEmail,
                password: passwordToUse,
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
              '   Email: ${widget.signupEmail.isEmpty ? 'MISSING' : 'present'}');
          print(
              '   Password: ${passwordToUse.isEmpty ? 'MISSING' : 'present'}');
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

      // Upload license document if selected
      String? licenseDocumentUrl;
      if (_licenseDocumentUrl != null) {
        print('📄 License document already uploaded: $_licenseDocumentUrl');
        licenseDocumentUrl = _licenseDocumentUrl;
      } else if (_licenseDocument != null) {
        print('📄 Uploading license document...');
        try {
          final bytes = await _licenseDocument!.readAsBytes();
          final fileName = _licenseDocument!.path.split('/').last;

          licenseDocumentUrl = await _storageService.uploadCertificate(
            userId: firebaseUser.uid,
            userType: 'hospital',
            certificateType: 'license',
            fileName: fileName,
            fileBytes: bytes,
          );

          print('✅ License document uploaded: $licenseDocumentUrl');
        } catch (e) {
          print('❌ Failed to upload license document: $e');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  Text('Failed to upload license document. Please try again.'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
      } else {
        print('❌ No license document selected');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Please select a license document'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Upload registration certificate if selected
      String? registrationCertificateUrl;
      if (_registrationCertificateUrl != null) {
        print(
            '📄 Registration certificate already uploaded: $_registrationCertificateUrl');
        registrationCertificateUrl = _registrationCertificateUrl;
      } else if (_registrationCertificate != null) {
        print('📄 Uploading registration certificate...');
        try {
          final bytes = await _registrationCertificate!.readAsBytes();
          final fileName = _registrationCertificate!.path.split('/').last;

          registrationCertificateUrl = await _storageService.uploadCertificate(
            userId: firebaseUser.uid,
            userType: 'hospital',
            certificateType: 'registration',
            fileName: fileName,
            fileBytes: bytes,
          );

          print(
              '✅ Registration certificate uploaded: $registrationCertificateUrl');
        } catch (e) {
          print('❌ Failed to upload registration certificate: $e');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Failed to upload registration certificate. Please try again.'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
      } else {
        print('ℹ️ No registration certificate selected (optional)');
      }

      // Upload building permit if selected
      String? buildingPermitUrl;
      if (_buildingPermitUrl != null) {
        print('📄 Building permit already uploaded: $_buildingPermitUrl');
        buildingPermitUrl = _buildingPermitUrl;
      } else if (_buildingPermit != null) {
        print('📄 Uploading building permit...');
        try {
          final bytes = await _buildingPermit!.readAsBytes();
          final fileName = _buildingPermit!.path.split('/').last;

          buildingPermitUrl = await _storageService.uploadCertificate(
            userId: firebaseUser.uid,
            userType: 'hospital',
            certificateType: 'building',
            fileName: fileName,
            fileBytes: bytes,
          );

          print('✅ Building permit uploaded: $buildingPermitUrl');
        } catch (e) {
          print('❌ Failed to upload building permit: $e');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  Text('Failed to upload building permit. Please try again.'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
      } else {
        print('ℹ️ No building permit selected (optional)');
      }

      // Create hospital user model with ALL fields
      // ============================================
      // BASIC INFORMATION:
      // - Hospital Name (hospitalName)
      // - Email (email, hospitalEmail)
      // - Phone (mobileNumber, hospitalPhone)
      // - Alternate Phone (alternateMobile)
      // - Gender (set to 'Other' for hospitals)
      // - Date of Birth (set to current date)
      //
      // LOCATION DETAILS:
      // - Address (address, hospitalAddress)
      // - City (city)
      // - State (state)
      // - Pincode (pincode)

      //
      // OPERATIONAL DETAILS:
      // - Hospital Type (hospitalType: Public/Private/Clinic/etc.)
      // - Registration Number (registrationNumber)
      // - Number of Beds (numberOfBeds)
      // - Departments (departments: Cardiology, Neurology, etc.)
      // - Special Facilities (specialFacilities: ICU, NICU, etc.)
      // - License Document URL (licenseDocumentUrl)
      //
      // APPROVAL STATUS:
      // - Is Approved (isApproved: false initially)
      // - Approval Status (approvalStatus: 'pending' initially)
      //
      // DERIVED FIELDS:
      // - Has Pharmacy (hasPharmacy: based on special facilities)
      // - Has Lab (hasLab: based on special facilities)
      // ============================================

      // Validate required fields before creating model
      final requiredFields = {
        'hospitalOwnerName': _hospitalOwnerNameController.text.trim(),
        'email': _emailController.text.trim(),
        'mobileNumber': _phoneController.text.trim(),
        'hospitalName': _hospitalNameController.text.trim(),
        'registrationNumber': _registrationNumberController.text.trim(),
        'hospitalType': _selectedHospitalType,
        'hospitalAddress': _addressController.text.trim(),
        'hospitalEmail': _emailController.text.trim(),
        'hospitalPhone': _phoneController.text.trim(),
        'numberOfBeds': _numberOfBedsController.text.trim(),
        'hasPharmacy': _selectedSpecialFacilities.contains('Pharmacy'),
        'hasLab': _selectedSpecialFacilities.contains('Laboratory'),
        'departments':
            _selectedDepartments.isNotEmpty ? _selectedDepartments : null,
      };

      // Check for missing required fields
      final missingFields = <String>[];
      requiredFields.forEach((key, value) {
        if (value == null || value.toString().isEmpty) {
          missingFields.add(key);
        }
      });

      // Also check hospital owner name separately
      if (_hospitalOwnerNameController.text.trim().isEmpty) {
        missingFields.add('hospitalOwnerName');
      }

      if (missingFields.isNotEmpty) {
        print('❌ Missing required fields: $missingFields');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Please fill all required fields: ${missingFields.join(', ')}'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final hospitalUser = UserModel(
        uid: firebaseUser.uid,
        fullName: _hospitalOwnerNameController.text.trim(),
        hospitalOwnerName: _hospitalOwnerNameController.text.trim(),
        email: _emailController.text.trim(),
        mobileNumber: _phoneController.text.trim(),
        alternateMobile: _altPhoneController.text.trim().isEmpty
            ? null
            : _altPhoneController.text.trim(),
        gender: 'Other',
        dateOfBirth: DateTime.now(),
        address: _addressController.text.trim(),
        city: _cityController.text.trim(),
        state: _stateController.text.trim(),
        pincode: _pincodeController.text.trim(),
        type: 'hospital',
        createdAt: DateTime.now(),
        hospitalName: _hospitalNameController.text.trim(),
        hospitalType: _selectedHospitalType,
        registrationNumber: _registrationNumberController.text.trim(),
        numberOfBeds: int.tryParse(_numberOfBedsController.text) ?? 0,
        departments: _selectedDepartments,
        specialFacilities: _selectedSpecialFacilities,
        licenseDocumentUrl: licenseDocumentUrl,
        registrationCertificateUrl: registrationCertificateUrl,
        buildingPermitUrl: buildingPermitUrl,
        isApproved: true, // Temporarily auto-approve hospitals
        approvalStatus: 'approved', // Temporarily auto-approve hospitals
        // Additional hospital fields
        hospitalAddress: _addressController.text.trim(),
        hospitalEmail: _emailController.text.trim(),
        hospitalPhone: _phoneController.text.trim(),
        hasPharmacy: _selectedSpecialFacilities.contains('Pharmacy'),
        hasLab: _selectedSpecialFacilities.contains('Laboratory'),
        // Location coordinates (if provided)
        // Note: These fields need to be added to UserModel if not already present
      );

      print('📋 Hospital user model created');
      print('🏥 Hospital Name: ${hospitalUser.hospitalName}');
      print('📧 Email: ${hospitalUser.email}');
      print('📞 Phone: ${hospitalUser.mobileNumber}');
      print('📄 License URL: ${hospitalUser.licenseDocumentUrl}');
      print('🏥 Hospital Type: ${hospitalUser.hospitalType}');
      print('📋 Registration Number: ${hospitalUser.registrationNumber}');
      print('🛏️ Number of Beds: ${hospitalUser.numberOfBeds}');
      print('🏥 Departments: ${hospitalUser.departments}');
      print('🏥 Special Facilities: ${hospitalUser.specialFacilities}');
      print('🏥 Has Pharmacy: ${hospitalUser.hasPharmacy}');
      print('🏥 Has Lab: ${hospitalUser.hasLab}');
      print('🏥 Hospital Address: ${hospitalUser.hospitalAddress}');
      print('🏥 Hospital Email: ${hospitalUser.hospitalEmail}');
      print('🏥 Hospital Phone: ${hospitalUser.hospitalPhone}');
      print('🏥 Approval Status: ${hospitalUser.approvalStatus}');
      print('🏥 Is Approved: ${hospitalUser.isApproved}');

      // Prepare user data for registration service
      final userData = {
        'uid': firebaseUser.uid,
        'hospitalOwnerName': _hospitalOwnerNameController.text.trim(),
        'email': _emailController.text.trim(),
        'mobileNumber': _phoneController.text.trim(),
        'alternateMobile': _altPhoneController.text.trim().isEmpty
            ? null
            : _altPhoneController.text.trim(),
        'gender': 'Other',
        'dateOfBirth': DateTime.now().toIso8601String(),
        'address': _addressController.text.trim(),
        'city': _cityController.text.trim(),
        'state': _stateController.text.trim(),
        'pincode': _pincodeController.text.trim(),
        'longitude': _longitude,
        'latitude': _latitude,
        'type': 'hospital',
        'hospitalName': _hospitalNameController.text.trim(),
        'hospitalType': _selectedHospitalType,
        'registrationNumber': _registrationNumberController.text.trim(),
        'numberOfBeds': int.tryParse(_numberOfBedsController.text) ?? 0,
        'departments': _selectedDepartments,
        'specialFacilities': _selectedSpecialFacilities,
        'hasPharmacy': _selectedSpecialFacilities.contains('Pharmacy'),
        'hasLab': _selectedSpecialFacilities.contains('Laboratory'),
        'hospitalAddress': _addressController.text.trim(),
        'hospitalEmail': _emailController.text.trim(),
        'hospitalPhone': _phoneController.text.trim(),
        'licenseDocumentUrl': licenseDocumentUrl,
        'registrationCertificateUrl': registrationCertificateUrl,
        'buildingPermitUrl': buildingPermitUrl,
      };

      // Prepare documents
      final documents = <File>[];
      final documentTypes = <String>[];

      if (_licenseDocument != null) {
        documents.add(_licenseDocument!);
        documentTypes.add('hospital_license');
      }
      if (_registrationCertificate != null) {
        documents.add(_registrationCertificate!);
        documentTypes.add('registration_certificate');
      }
      if (_buildingPermit != null) {
        documents.add(_buildingPermit!);
        documentTypes.add('building_permit');
      }

      // Also add any already uploaded documents
      final uploadedDocuments = <String, String>{};
      if (_licenseDocumentUrl != null) {
        uploadedDocuments['hospital_license'] = _licenseDocumentUrl!;
      }
      if (_registrationCertificateUrl != null) {
        uploadedDocuments['registration_certificate'] =
            _registrationCertificateUrl!;
      }
      if (_buildingPermitUrl != null) {
        uploadedDocuments['building_permit'] = _buildingPermitUrl!;
      }

      // Verify Firebase user is still authenticated before registration
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null || currentUser.uid != firebaseUser.uid) {
        throw Exception(
            'Firebase user authentication lost during registration process');
      }

      print('🌐 Using new registration service...');
      print('🔑 Firebase UID for registration: ${firebaseUser.uid}');
      print('📧 Firebase Email for registration: ${firebaseUser.email}');

      final result = await RegistrationService.registerUser(
        userType: 'hospital',
        userData: userData,
        documents: documents,
        documentTypes: documentTypes,
        uploadedDocuments: uploadedDocuments,
      );

      if (result['success']) {
        print('✅ Registration successful');

        // Save user type to SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_type', 'hospital');
        await prefs.setString('user_gender', 'Other'); // Default for hospital
        await prefs.setString('user_uid', firebaseUser.uid);
        await prefs.setString('user_status', 'pending');

        // Clean up stored signup credentials
        await prefs.remove('last_signup_email');
        await prefs.remove('last_signup_password');

        print('💾 SharedPreferences saved');

        if (mounted) {
          // Show success popup
          await _showCustomPopup(
              success: true,
              message: result['message'] ??
                  'Hospital registration successful! Your account is pending approval.');

          print('🔄 Navigating to appropriate screen...');
          // Navigate based on user type and approval status
          await DashboardNavigationService.navigateAfterRegistration(
              context, 'hospital', 'pending');
        }
      } else {
        print('❌ Registration failed');
        if (mounted) {
          await _showCustomPopup(
              success: false,
              message: result['message'] ??
                  'Failed to register hospital. Please check your internet connection and try again.');
        }
      }
    } catch (e) {
      print('❌ Registration failed with error: $e');
      if (mounted) {
        await _showCustomPopup(
            success: false, message: 'Registration failed: $e');
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _showCustomPopup(
      {required bool success, required String message}) async {
    final prefs = await SharedPreferences.getInstance();
    final gender = prefs.getString('user_gender') ?? 'Other';
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
            Text(message,
                textAlign: TextAlign.center, style: TextStyle(fontSize: 16)),
          ],
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  Widget _buildStepIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: [
          for (int i = 1; i <= 4; i++)
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                height: 4,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2),
                  gradient: i <= _currentStep
                      ? const LinearGradient(
                          colors: [
                            Color(0xFF4CAF50),
                            Color(0xFF81C784)
                          ], // Hospital green gradient
                        )
                      : null,
                  color: i <= _currentStep ? null : Colors.grey[300],
                ),
              ),
            ),
        ],
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
            color: const Color(0xFF4CAF50), // Hospital green
          ),
        ),
        const SizedBox(height: 16),

        // Hospital Name
        Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                Color(0xFF4CAF50),
                Color(0xFF81C784)
              ], // Hospital green gradient
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
              controller: _hospitalNameController,
              decoration: const InputDecoration(
                labelText: 'Hospital Name *',
                prefixIcon: Icon(EvaIcons.homeOutline,
                    color: Color(0xFF4CAF50)), // Hospital green
                border: InputBorder.none,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter hospital name';
                }
                return null;
              },
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Hospital Owner Name
        Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                Color(0xFF4CAF50),
                Color(0xFF81C784)
              ], // Hospital green gradient
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
              controller: _hospitalOwnerNameController,
              decoration: const InputDecoration(
                labelText: 'Hospital Owner Name *',
                prefixIcon: Icon(EvaIcons.personOutline,
                    color: Color(0xFF4CAF50)), // Hospital green
                border: InputBorder.none,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter hospital owner name';
                }
                return null;
              },
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Email - Only disable if it was filled in signup
        Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                Color(0xFF4CAF50),
                Color(0xFF81C784)
              ], // Hospital green gradient
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Container(
            decoration: BoxDecoration(
              color: _wasEmailFilledInSignup
                  ? Colors.grey[100]
                  : Colors.white, // Disabled background only if filled
              borderRadius: BorderRadius.circular(12),
            ),
            child: TextFormField(
              controller: _emailController,
              enabled:
                  !_wasEmailFilledInSignup, // Disable only if filled in signup
              decoration: InputDecoration(
                labelText:
                    'Email Address *${_wasEmailFilledInSignup ? ' (Pre-filled)' : ''}',
                prefixIcon: const Icon(EvaIcons.emailOutline,
                    color: Color(0xFF4CAF50)), // Hospital green
                border: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              ),
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter email address';
                }
                if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                    .hasMatch(value)) {
                  return 'Please enter a valid email';
                }
                return null;
              },
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Phone Number - Only disable if it was filled in signup
        Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                Color(0xFF4CAF50),
                Color(0xFF81C784)
              ], // Hospital green gradient
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Container(
            decoration: BoxDecoration(
              color: _wasPhoneFilledInSignup
                  ? Colors.grey[100]
                  : Colors.white, // Disabled background only if filled
              borderRadius: BorderRadius.circular(12),
            ),
            child: TextFormField(
              controller: _phoneController,
              enabled:
                  !_wasPhoneFilledInSignup, // Disable only if filled in signup
              decoration: InputDecoration(
                labelText:
                    'Phone Number *${_wasPhoneFilledInSignup ? ' (Pre-filled)' : ''}',
                prefixIcon: const Icon(EvaIcons.phoneOutline,
                    color: Color(0xFF4CAF50)), // Hospital green
                border: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              ),
              keyboardType: TextInputType.phone,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter phone number';
                }
                if (value.length < 10) {
                  return 'Please enter a valid phone number';
                }
                return null;
              },
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Alternate Phone Number (Optional)
        Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                Color(0xFF4CAF50),
                Color(0xFF81C784)
              ], // Hospital green gradient
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
              controller: _altPhoneController,
              decoration: const InputDecoration(
                labelText: 'Alternate Phone Number (Optional)',
                prefixIcon: Icon(EvaIcons.phoneOutline,
                    color: Color(0xFF4CAF50)), // Hospital green
                border: InputBorder.none,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              ),
              keyboardType: TextInputType.phone,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLocationDetails() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Location Details',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF4CAF50), // Hospital green
          ),
        ),
        const SizedBox(height: 16),

        // Address
        Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                Color(0xFF4CAF50),
                Color(0xFF81C784)
              ], // Hospital green gradient
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
              controller: _addressController,
              decoration: const InputDecoration(
                labelText: 'Full Address *',
                prefixIcon: Icon(EvaIcons.mapOutline,
                    color: Color(0xFF4CAF50)), // Hospital green
                border: InputBorder.none,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              ),
              maxLines: 3,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter address';
                }
                return null;
              },
            ),
          ),
        ),
        const SizedBox(height: 16),

        // City and State Row
        Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF4CAF50),
                      Color(0xFF81C784)
                    ], // Hospital green gradient
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
                    controller: _cityController,
                    decoration: const InputDecoration(
                      labelText: 'City *',
                      prefixIcon: Icon(EvaIcons.navigationOutline,
                          color: Color(0xFF4CAF50)), // Hospital green
                      border: InputBorder.none,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter city';
                      }
                      return null;
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF4CAF50),
                      Color(0xFF81C784)
                    ], // Hospital green gradient
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
                    controller: _stateController,
                    decoration: const InputDecoration(
                      labelText: 'State *',
                      prefixIcon: Icon(EvaIcons.navigationOutline,
                          color: Color(0xFF4CAF50)), // Hospital green
                      border: InputBorder.none,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter state';
                      }
                      return null;
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Pincode and Coordinates Row
        Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF4CAF50),
                      Color(0xFF81C784)
                    ], // Hospital green gradient
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
                    controller: _pincodeController,
                    decoration: const InputDecoration(
                      labelText: 'Pincode *',
                      prefixIcon: Icon(EvaIcons.navigationOutline,
                          color: Color(0xFF4CAF50)), // Hospital green
                      border: InputBorder.none,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter pincode';
                      }
                      if (value.length != 6) {
                        return 'Please enter 6-digit pincode';
                      }
                      return null;
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Coordinates Row
        Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF4CAF50),
                      Color(0xFF81C784)
                    ], // Hospital green gradient
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
                    controller: _longitudeController,
                    decoration: const InputDecoration(
                      labelText: 'Longitude (Optional)',
                      prefixIcon: Icon(EvaIcons.navigationOutline,
                          color: Color(0xFF4CAF50)), // Hospital green
                      border: InputBorder.none,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    ),
                    keyboardType:
                        TextInputType.numberWithOptions(decimal: true),
                    onChanged: (value) {
                      _longitude = double.tryParse(value);
                    },
                    validator: (value) {
                      if (value != null && value.isNotEmpty) {
                        final parsed = double.tryParse(value);
                        if (parsed == null) {
                          return 'Please enter a valid longitude';
                        }
                        if (parsed < -180 || parsed > 180) {
                          return 'Longitude must be between -180 and 180';
                        }
                      }
                      return null;
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF4CAF50),
                      Color(0xFF81C784)
                    ], // Hospital green gradient
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
                    controller: _latitudeController,
                    decoration: const InputDecoration(
                      labelText: 'Latitude (Optional)',
                      prefixIcon: Icon(EvaIcons.navigationOutline,
                          color: Color(0xFF4CAF50)), // Hospital green
                      border: InputBorder.none,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    ),
                    keyboardType:
                        TextInputType.numberWithOptions(decimal: true),
                    onChanged: (value) {
                      _latitude = double.tryParse(value);
                    },
                    validator: (value) {
                      if (value != null && value.isNotEmpty) {
                        final parsed = double.tryParse(value);
                        if (parsed == null) {
                          return 'Please enter a valid latitude';
                        }
                        if (parsed < -90 || parsed > 90) {
                          return 'Latitude must be between -90 and 90';
                        }
                      }
                      return null;
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Get Current Location Button
        Center(
          child: Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF4CAF50),
                  Color(0xFF81C784)
                ], // Hospital green gradient
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: ElevatedButton.icon(
              onPressed: _isGettingLocation ? null : _getCurrentLocation,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              icon: _isGettingLocation
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.my_location, size: 20),
              label: Text(
                _isGettingLocation
                    ? 'Getting Location...'
                    : 'Get Current Location',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOperationalDetails() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Operational Details',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF4CAF50), // Hospital green
          ),
        ),
        const SizedBox(height: 16),

        // Hospital Type
        Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                Color(0xFF4CAF50),
                Color(0xFF81C784)
              ], // Hospital green gradient
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
              value: _selectedHospitalType,
              decoration: const InputDecoration(
                labelText: 'Hospital Type *',
                prefixIcon: Icon(EvaIcons.homeOutline,
                    color: Color(0xFF4CAF50)), // Hospital green
                border: InputBorder.none,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              ),
              items: _hospitalTypes.map((String type) {
                return DropdownMenuItem<String>(
                  value: type,
                  child: Text(type),
                );
              }).toList(),
              onChanged: (String? newValue) {
                setState(() {
                  _selectedHospitalType = newValue!;
                });
              },
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Registration Number
        Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                Color(0xFF4CAF50),
                Color(0xFF81C784)
              ], // Hospital green gradient
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
              controller: _registrationNumberController,
              decoration: const InputDecoration(
                labelText: 'Registration Number *',
                prefixIcon: Icon(EvaIcons.fileTextOutline,
                    color: Color(0xFF4CAF50)), // Hospital green
                border: InputBorder.none,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter hospital registration number';
                }

                // Remove spaces and convert to uppercase for validation
                String cleanValue = value.replaceAll(' ', '').toUpperCase();

                // State health authority format: Usually starts with state code followed by numbers
                // Examples: MH12345, DL67890, KA123456, TN789012
                if (!RegExp(r'^[A-Z]{2}[0-9]{4,6}$').hasMatch(cleanValue)) {
                  return 'Invalid format. Use format like MH12345 or DL67890';
                }

                // Validate state codes (common Indian states)
                List<String> validStateCodes = [
                  'AP',
                  'AR',
                  'AS',
                  'BR',
                  'CG',
                  'GA',
                  'GJ',
                  'HR',
                  'HP',
                  'JK',
                  'JH',
                  'KA',
                  'KL',
                  'MP',
                  'MH',
                  'MN',
                  'ML',
                  'MZ',
                  'NL',
                  'OR',
                  'PB',
                  'RJ',
                  'SK',
                  'TN',
                  'TG',
                  'TR',
                  'UP',
                  'UK',
                  'WB',
                  'AN',
                  'CH',
                  'DN',
                  'DD',
                  'DL',
                  'LD',
                  'PY'
                ];

                String stateCode = cleanValue.substring(0, 2);
                if (!validStateCodes.contains(stateCode)) {
                  return 'Invalid state code. Please check your registration number';
                }

                return null;
              },
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Number of Beds
        Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                Color(0xFF4CAF50),
                Color(0xFF81C784)
              ], // Hospital green gradient
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
              controller: _numberOfBedsController,
              decoration: const InputDecoration(
                labelText: 'Number of Beds',
                prefixIcon:
                    Icon(Icons.bed, color: Color(0xFF4CAF50)), // Hospital green
                border: InputBorder.none,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              ),
              keyboardType: TextInputType.number,
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Removed Main Specialization Dropdown (not applicable for hospital)

        // Departments
        Text(
          'Departments *',
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF4CAF50), // Hospital green
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 200,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF4CAF50).withOpacity(0.3)),
          ),
          child: ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: _departments.length,
            itemBuilder: (context, index) {
              final department = _departments[index];
              return CheckboxListTile(
                title: Text(
                  department,
                  style: GoogleFonts.poppins(fontSize: 14),
                ),
                value: _selectedDepartments.contains(department),
                onChanged: (bool? value) {
                  _toggleDepartment(department);
                },
                activeColor: const Color(0xFF4CAF50),
                checkColor: Colors.white,
              );
            },
          ),
        ),
        const SizedBox(height: 24),

        // Special Facilities
        Text(
          'Special Facilities',
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF4CAF50), // Hospital green
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 200,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF4CAF50).withOpacity(0.3)),
          ),
          child: ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: _specialFacilities.length,
            itemBuilder: (context, index) {
              final facility = _specialFacilities[index];
              return CheckboxListTile(
                title: Text(
                  facility,
                  style: GoogleFonts.poppins(fontSize: 14),
                ),
                value: _selectedSpecialFacilities.contains(facility),
                onChanged: (bool? value) {
                  _toggleSpecialFacility(facility);
                },
                activeColor: const Color(0xFF4CAF50),
                checkColor: Colors.white,
              );
            },
          ),
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
            color: const Color(0xFF4CAF50), // Hospital green
          ),
        ),
        const SizedBox(height: 16),

        // License Document Upload
        Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                Color(0xFF4CAF50),
                Color(0xFF81C784)
              ], // Hospital green gradient
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
              onTap: _isUploading ? null : _pickLicenseDocument,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      _isUploading ? Icons.upload : EvaIcons.fileTextOutline,
                      color: const Color(0xFF4CAF50), // Hospital green
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isUploading
                                ? 'Uploading...'
                                : _licenseDocumentUrl != null
                                    ? 'License Document Uploaded ✓'
                                    : 'Upload License Document *',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                              color: _licenseDocumentUrl != null
                                  ? const Color(0xFF4CAF50)
                                  : Colors.grey[600],
                            ),
                          ),
                          if (_licenseDocumentUrl == null)
                            Text(
                              'Click to select hospital license/registration certificate (Image or PDF)',
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
                          color: Color(0xFF4CAF50),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Registration Certificate Upload
        Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                Color(0xFF4CAF50),
                Color(0xFF81C784)
              ], // Hospital green gradient
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
              onTap: _isUploading ? null : _pickRegistrationCertificate,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      _isUploading ? Icons.upload : EvaIcons.fileTextOutline,
                      color: const Color(0xFF4CAF50), // Hospital green
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isUploading
                                ? 'Uploading...'
                                : _registrationCertificateUrl != null
                                    ? 'Registration Certificate Uploaded ✓'
                                    : 'Upload Registration Certificate *',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                              color: _registrationCertificateUrl != null
                                  ? const Color(0xFF4CAF50)
                                  : Colors.grey[600],
                            ),
                          ),
                          if (_registrationCertificateUrl == null)
                            Text(
                              'Click to select hospital registration certificate (Image or PDF)',
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
                          color: Color(0xFF4CAF50),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Building Permit Upload
        Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                Color(0xFF4CAF50),
                Color(0xFF81C784)
              ], // Hospital green gradient
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
              onTap: _isUploading ? null : _pickBuildingPermit,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      _isUploading ? Icons.upload : EvaIcons.fileTextOutline,
                      color: const Color(0xFF4CAF50), // Hospital green
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isUploading
                                ? 'Uploading...'
                                : _buildingPermitUrl != null
                                    ? 'Building Permit Uploaded ✓'
                                    : 'Upload Building Permit *',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                              color: _buildingPermitUrl != null
                                  ? const Color(0xFF4CAF50)
                                  : Colors.grey[600],
                            ),
                          ),
                          if (_buildingPermitUrl != null)
                            Text(
                              'Click to select hospital building permit',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: Colors.grey[500],
                              ),
                            ),
                          if (_buildingPermitUrl == null)
                            Text(
                              'Click to select hospital building permit (Image or PDF)',
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
                          color: Color(0xFF4CAF50),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // Debug: Print current step and validation status
    print('Current step: $_currentStep');
    print('Can proceed: ${_canProceedToNextStep()}');

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Hospital Registration',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF4CAF50), // Hospital green
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF4CAF50),
              Color(0xFF81C784),
              Color(0xFFE8F5E8)
            ], // Hospital green gradient
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                _buildStepIndicator(),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Step Title
                        Text(
                          _currentStep == 1
                              ? 'Basic Information'
                              : _currentStep == 2
                                  ? 'Location Details'
                                  : _currentStep == 3
                                      ? 'Operational Details'
                                      : 'Document Upload',
                          style: GoogleFonts.poppins(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _currentStep == 1
                              ? 'Enter your hospital\'s basic details'
                              : _currentStep == 2
                                  ? 'Provide location information'
                                  : _currentStep == 3
                                      ? 'Configure operational settings'
                                      : 'Upload required documents',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: Colors.white.withOpacity(0.8),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Step Content
                        if (_currentStep == 1) _buildBasicInformation(),
                        if (_currentStep == 2) _buildLocationDetails(),
                        if (_currentStep == 3) _buildOperationalDetails(),
                        if (_currentStep == 4) _buildDocumentUpload(),

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
                                    side: const BorderSide(color: Colors.white),
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
                                      color: Colors.white,
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
                                            Color(0xFF4CAF50),
                                            Color(0xFF81C784)
                                          ], // Hospital green gradient
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
                                          if (_currentStep < 4) {
                                            setState(() {
                                              _currentStep++;
                                            });
                                          } else {
                                            _registerHospital();
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
                                          _currentStep < 4
                                              ? 'Next'
                                              : 'Register Hospital',
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
