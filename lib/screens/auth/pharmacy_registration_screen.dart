import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import '../../services/registration_service.dart';
import '../../services/dashboard_navigation_service.dart';
import 'package:eva_icons_flutter/eva_icons_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../../widgets/hospital_affiliation_selector.dart';

class PharmacyRegistrationScreen extends StatefulWidget {
  final String signupEmail;
  final String signupPhone;
  final String signupPassword;
  final String signupCountryCode;

  const PharmacyRegistrationScreen({
    super.key,
    required this.signupEmail,
    required this.signupPhone,
    required this.signupPassword,
    required this.signupCountryCode,
  });

  @override
  State<PharmacyRegistrationScreen> createState() =>
      _PharmacyRegistrationScreenState();
}

class _PharmacyRegistrationScreenState
    extends State<PharmacyRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();

  // Basic Information Controllers
  final _pharmacyNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _altPhoneController = TextEditingController();
  String? _selectedGender;
  DateTime? _selectedDateOfBirth;

  // Location Details Controllers
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _pincodeController = TextEditingController();

  // Operational Details Controllers
  final _licenseNumberController = TextEditingController();
  final _ownerNameController = TextEditingController();
  final _pharmacistNameController = TextEditingController();
  final _pharmacistLicenseController = TextEditingController();
  final _pharmacistQualificationController = TextEditingController();
  final _pharmacistExperienceController = TextEditingController();

  // Business Information Controllers
  final _openTimeController = TextEditingController();
  final _closeTimeController = TextEditingController();
  List<String> _selectedWorkingDays = [];
  List<String> _selectedServices = [];
  List<String> _selectedDrugsAvailable = [];

  // Services
  bool _homeDelivery = false;

  // Document Upload
  File? _selectedLicenseDocument;
  File? _selectedProfilePicture; // Added profile picture file
  File? _selectedDrugLicenseDocument;
  File? _selectedPremisesCertificate;

  // Upload status tracking
  bool _isLicenseDocumentUploaded = false;
  bool _isProfilePictureUploaded = false;
  bool _isDrugLicenseUploaded = false;
  bool _isPremisesCertificateUploaded = false;
  bool _isUploading = false;

  // Location and Hospital Affiliation
  double? _longitude;
  double? _latitude;
  bool _isGettingLocation = false;
  List<Map<String, dynamic>> _pharmacyAffiliatedHospitals = [];

  // Form State
  bool _isLoading = false;
  int _currentStep =
      1; // 1: Basic Info, 2: Location, 3: Operational, 4: Business, 5: Documents

  // Available options
  final List<String> _availableServices = [
    'Over-the-Counter Medicines',
    'Prescription Medicines',
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

  final List<String> _workingDays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  final List<String> _timeOptions = [
    '06:00',
    '06:30',
    '07:00',
    '07:30',
    '08:00',
    '08:30',
    '09:00',
    '09:30',
    '10:00',
    '10:30',
    '11:00',
    '11:30',
    '12:00',
    '12:30',
    '13:00',
    '13:30',
    '14:00',
    '14:30',
    '15:00',
    '15:30',
    '16:00',
    '16:30',
    '17:00',
    '17:30',
    '18:00',
    '18:30',
    '19:00',
    '19:30',
    '20:00',
    '20:30',
    '21:00',
    '21:30',
    '22:00',
    '22:30',
    '23:00',
    '23:30',
    '24:00'
  ];

  final List<String> _qualificationOptions = [
    'B.Pharm (Bachelor of Pharmacy)',
    'M.Pharm (Master of Pharmacy)',
    'D.Pharm (Diploma in Pharmacy)',
    'Pharm.D (Doctor of Pharmacy)',
    'B.Sc Pharmacy',
    'M.Sc Pharmacy',
    'Ph.D in Pharmacy',
    'Other'
  ];

  final List<String> _genderOptions = ['Male', 'Female', 'Other'];

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

    // Add listeners to trigger UI updates when fields change
    _pharmacyNameController.addListener(() => setState(() {}));
    _emailController.addListener(() => setState(() {}));
    _phoneController.addListener(() => setState(() {}));
    _altPhoneController.addListener(() => setState(() {}));
    _addressController.addListener(() => setState(() {}));
    _cityController.addListener(() => setState(() {}));
    _stateController.addListener(() => setState(() {}));
    _pincodeController.addListener(() => setState(() {}));
    _licenseNumberController.addListener(() => setState(() {}));
    _ownerNameController.addListener(() => setState(() {}));
    _pharmacistNameController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    // Remove listeners
    _pharmacyNameController.removeListener(() => setState(() {}));
    _emailController.removeListener(() => setState(() {}));
    _phoneController.removeListener(() => setState(() {}));
    _altPhoneController.removeListener(() => setState(() {}));
    _addressController.removeListener(() => setState(() {}));
    _cityController.removeListener(() => setState(() {}));
    _stateController.removeListener(() => setState(() {}));
    _pincodeController.removeListener(() => setState(() {}));
    _licenseNumberController.removeListener(() => setState(() {}));
    _ownerNameController.removeListener(() => setState(() {}));
    _pharmacistNameController.removeListener(() => setState(() {}));

    // Dispose controllers
    _pharmacyNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _altPhoneController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _pincodeController.dispose();
    _licenseNumberController.dispose();
    _ownerNameController.dispose();
    _pharmacistNameController.dispose();
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
        return _pharmacyNameController.text.trim().isNotEmpty &&
            _emailController.text.trim().isNotEmpty &&
            _phoneController.text.trim().isNotEmpty &&
            _selectedGender != null &&
            _selectedDateOfBirth != null;
      case 2:
        return _addressController.text.trim().isNotEmpty &&
            _cityController.text.trim().isNotEmpty &&
            _stateController.text.trim().isNotEmpty &&
            _pincodeController.text.trim().isNotEmpty;
      case 3:
        return _licenseNumberController.text.trim().isNotEmpty &&
            _ownerNameController.text.trim().isNotEmpty &&
            _pharmacistNameController.text.trim().isNotEmpty &&
            _pharmacistLicenseController.text.trim().isNotEmpty &&
            _pharmacistQualificationController.text.trim().isNotEmpty;
      case 4:
        return _openTimeController.text.trim().isNotEmpty &&
            _closeTimeController.text.trim().isNotEmpty &&
            _selectedWorkingDays.isNotEmpty &&
            _selectedServices.isNotEmpty;
      case 5:
        return _isLicenseDocumentUploaded &&
            _isProfilePictureUploaded &&
            _isDrugLicenseUploaded &&
            _isPremisesCertificateUploaded;
      default:
        return false;
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

      if (choice == 'image') {
        // Pick image
        final ImagePicker picker = ImagePicker();
        final XFile? image = await picker.pickImage(
          source: ImageSource.gallery,
          maxWidth: 1024,
          maxHeight: 1024,
          imageQuality: 80,
        );

        if (image != null) {
          // Reduced upload delay for faster response
          await Future.delayed(const Duration(milliseconds: 500));

          setState(() {
            _selectedLicenseDocument = File(image.path);
            _isLicenseDocumentUploaded = true;
            _isUploading = false;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('License document uploaded successfully!'),
              backgroundColor: Color(0xFFFA709A),
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
            _selectedLicenseDocument = File(result.files.single.path!);
            _isLicenseDocumentUploaded = true;
            _isUploading = false;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('License PDF uploaded successfully!'),
              backgroundColor: Color(0xFFFA709A),
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
          content: Text('Failed to upload license document: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _pickProfilePicture() async {
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

          setState(() {
            _selectedProfilePicture = File(image.path);
            _isProfilePictureUploaded = true;
            _isUploading = false;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profile picture uploaded successfully!'),
              backgroundColor: Color(0xFFFA709A),
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
          setState(() {
            _isUploading = true;
          });

          // Reduced upload delay for faster response
          await Future.delayed(const Duration(milliseconds: 500));

          setState(() {
            _selectedProfilePicture = File(result.files.single.path!);
            _isProfilePictureUploaded = true;
            _isUploading = false;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profile document PDF uploaded successfully!'),
              backgroundColor: Color(0xFFFA709A),
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
          content: Text('Failed to upload profile document: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _pickDrugLicenseDocument() async {
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
        final ImagePicker picker = ImagePicker();
        final XFile? image = await picker.pickImage(
          source: ImageSource.gallery,
          maxWidth: 1024,
          maxHeight: 1024,
          imageQuality: 80,
        );

        if (image != null) {
          // Reduced upload delay for faster response
          await Future.delayed(const Duration(milliseconds: 500));

          setState(() {
            _selectedDrugLicenseDocument = File(image.path);
            _isDrugLicenseUploaded = true;
            _isUploading = false;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Drug license document uploaded successfully!'),
              backgroundColor: Color(0xFFFA709A),
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
            _selectedDrugLicenseDocument = File(result.files.single.path!);
            _isDrugLicenseUploaded = true;
            _isUploading = false;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Drug license PDF uploaded successfully!'),
              backgroundColor: Color(0xFFFA709A),
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
          content: Text('Failed to upload drug license document: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _pickPremisesCertificate() async {
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
        final ImagePicker picker = ImagePicker();
        final XFile? image = await picker.pickImage(
          source: ImageSource.gallery,
          maxWidth: 1024,
          maxHeight: 1024,
          imageQuality: 80,
        );

        if (image != null) {
          // Reduced upload delay for faster response
          await Future.delayed(const Duration(milliseconds: 500));

          setState(() {
            _selectedPremisesCertificate = File(image.path);
            _isPremisesCertificateUploaded = true;
            _isUploading = false;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Premises certificate uploaded successfully!'),
              backgroundColor: Color(0xFFFA709A),
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
            _selectedPremisesCertificate = File(result.files.single.path!);
            _isPremisesCertificateUploaded = true;
            _isUploading = false;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Premises certificate PDF uploaded successfully!'),
              backgroundColor: Color(0xFFFA709A),
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
          content: Text('Failed to upload premises certificate: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _registerPharmacy() async {
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

      // Create pharmacy user model
      final pharmacyUser = {
        'uid': firebaseUser.uid,
        'fullName': _pharmacyNameController.text.trim(),
        'email': _emailController.text.trim(),
        'mobileNumber': _phoneController.text.trim(),
        'alternateMobile': _altPhoneController.text.trim().isEmpty
            ? null
            : _altPhoneController.text.trim(),
        'gender': _selectedGender ?? 'Other',
        'dateOfBirth': _selectedDateOfBirth?.toIso8601String() ??
            DateTime.now().toIso8601String(),
        'address': _addressController.text.trim(),
        'city': _cityController.text.trim(),
        'state': _stateController.text.trim(),
        'pincode': _pincodeController.text.trim(),
        'longitude': _longitude,
        'latitude': _latitude,
        'geoCoordinates': _longitude != null && _latitude != null
            ? {'lat': _latitude, 'lng': _longitude}
            : null,
        'pharmacyName': _pharmacyNameController.text.trim(),
        'licenseNumber': _licenseNumberController.text.trim(),
        'ownerName': _ownerNameController.text.trim(),
        'pharmacistName': _pharmacistNameController.text.trim(),
        'pharmacistLicenseNumber': _pharmacistLicenseController.text.trim(),
        'pharmacistQualification':
            _pharmacistQualificationController.text.trim(),
        'pharmacistExperienceYears':
            int.tryParse(_pharmacistExperienceController.text.trim()) ?? 0,
        'servicesProvided': _selectedServices, // Use selected services
        'drugsAvailable': _selectedDrugsAvailable, // Use selected drugs
        'homeDelivery': _homeDelivery,
        'operatingHours': {
          'openTime': _openTimeController.text.trim(),
          'closeTime': _closeTimeController.text.trim(),
          'workingDays': _selectedWorkingDays,
        },
        'affiliatedHospitals': _pharmacyAffiliatedHospitals,
      };

      // Prepare documents
      final documents = <File>[];
      final documentTypes = <String>[];

      if (_selectedLicenseDocument != null) {
        documents.add(_selectedLicenseDocument!);
        documentTypes.add('pharmacy_license');
      }
      if (_selectedDrugLicenseDocument != null) {
        documents.add(_selectedDrugLicenseDocument!);
        documentTypes.add('drug_license');
      }
      if (_selectedPremisesCertificate != null) {
        documents.add(_selectedPremisesCertificate!);
        documentTypes.add('premises_certificate');
      }
      if (_selectedProfilePicture != null) {
        documents.add(_selectedProfilePicture!);
        documentTypes.add('profile_picture');
      }

      // Use the registration service
      final result = await RegistrationService.registerUser(
        userType: 'pharmacy',
        userData: pharmacyUser,
        documents: documents,
        documentTypes: documentTypes,
        uploadedDocuments: {},
      );

      if (result['success']) {
        // Save user type to SharedPreferences (following same pattern as other service providers)
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_type', 'pharmacy');
        await prefs.setString('user_uid', firebaseUser.uid);
        await prefs.setString('user_status', 'pending');
        await prefs.setString('user_email', firebaseUser.email ?? '');
        await prefs.setString('user_name', _pharmacyNameController.text.trim());
        await prefs.setString(
            'pharmacy_name', _pharmacyNameController.text.trim());
        await prefs.setString(
            'pharmacy_license', _licenseNumberController.text.trim());
        await prefs.setString(
            'pharmacy_owner', _ownerNameController.text.trim());
        await prefs.setString(
            'pharmacy_pharmacist', _pharmacistNameController.text.trim());

        if (mounted) {
          // Show success popup
          await _showCustomPopup(
            success: true,
            message: result['message'] ??
                'Pharmacy registration successful! Your account is pending approval.',
          );

          // Navigate based on user type and approval status
          await DashboardNavigationService.navigateAfterRegistration(
            context,
            'pharmacy',
            'pending',
          );
        }
      } else {
        if (mounted) {
          await _showCustomPopup(
            success: false,
            message: result['message'] ??
                'Failed to register pharmacy. Please check your internet connection and try again.',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        String errorMessage = 'Registration failed: $e';

        // Handle specific error cases
        if (e.toString().contains('Pharmacy already registered')) {
          errorMessage =
              'This pharmacy is already registered. Please try logging in instead.';
          // Show option to go to login
          _showLoginOptionDialog();
        } else if (e.toString().contains('Email already in use')) {
          errorMessage =
              'This email is already registered. Please try logging in instead.';
          _showLoginOptionDialog();
        } else {
          errorMessage = 'Registration failed: $e';
        }

        await _showCustomPopup(
          success: false,
          message: errorMessage,
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showLoginOptionDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        title: const Text('Pharmacy Already Registered'),
        content: const Text(
          'This pharmacy is already registered in our system. Would you like to go to the login screen?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Stay Here'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Go back to previous screen
              // Navigate to login screen
              Navigator.pushReplacementNamed(context, '/login');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFA709A),
              foregroundColor: Colors.white,
            ),
            child: const Text('Go to Login'),
          ),
        ],
      ),
    );
  }

  Future<void> _showCustomPopup({
    required bool success,
    required String message,
  }) async {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              success ? Icons.check_circle : Icons.error,
              color: success ? const Color(0xFFFA709A) : Colors.red,
              size: 80,
            ),
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
              _buildStepCircle(2, _currentStep >= 2, 'Location'),
              _buildStepLine(_currentStep >= 3),
              _buildStepCircle(3, _currentStep >= 3, 'Operational'),
              _buildStepLine(_currentStep >= 4),
              _buildStepCircle(4, _currentStep >= 4, 'Business'),
              _buildStepLine(_currentStep >= 5),
              _buildStepCircle(5, _currentStep >= 5, 'Documents'),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Basic Info',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                'Location',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.white.withOpacity(0.7),
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                'Operational',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.white.withOpacity(0.7),
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                'Business',
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
            color: isActive ? const Color(0xFFFA709A) : Colors.white,
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

  Widget _buildTimeDropdown({
    required String? value,
    required String label,
    required Function(String?) onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFFFFD700),
            Color(0xFFFFA500)
          ], // Pharmacy gold→orange gradient
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
          value: value,
          decoration: InputDecoration(
            labelText: '$label *',
            prefixIcon:
                Icon(EvaIcons.clockOutline, color: const Color(0xFFFA709A)),
            border: InputBorder.none,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
          items: _timeOptions.map((String time) {
            return DropdownMenuItem<String>(
              value: time,
              child: Text(time),
            );
          }).toList(),
          onChanged: onChanged,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please select $label';
            }
            return null;
          },
        ),
      ),
    );
  }

  Widget _buildQualificationDropdown() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFFFFD700),
            Color(0xFFFFA500)
          ], // Pharmacy gold→orange gradient
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
          value: _pharmacistQualificationController.text.isEmpty
              ? null
              : _pharmacistQualificationController.text,
          decoration: InputDecoration(
            labelText: 'Pharmacist Qualification *',
            prefixIcon:
                Icon(EvaIcons.bookOutline, color: const Color(0xFFFA709A)),
            border: InputBorder.none,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
          items: _qualificationOptions.map((String qualification) {
            return DropdownMenuItem<String>(
              value: qualification,
              child: Text(qualification),
            );
          }).toList(),
          onChanged: (value) {
            _pharmacistQualificationController.text = value ?? '';
          },
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please select Pharmacist Qualification';
            }
            return null;
          },
        ),
      ),
    );
  }

  Widget _buildGenderDropdown() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFFFFD700),
            Color(0xFFFFA500)
          ], // Pharmacy gold→orange gradient
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
          decoration: InputDecoration(
            labelText: 'Gender *',
            prefixIcon:
                Icon(EvaIcons.personOutline, color: const Color(0xFFFA709A)),
            border: InputBorder.none,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
          items: _genderOptions.map((String gender) {
            return DropdownMenuItem<String>(
              value: gender,
              child: Text(gender),
            );
          }).toList(),
          onChanged: (value) {
            setState(() {
              _selectedGender = value;
            });
          },
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please select Gender';
            }
            return null;
          },
        ),
      ),
    );
  }

  Widget _buildDateOfBirthField() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFFFA709A),
            Color(0xFFFEE140)
          ], // Pharmacy pink-yellow gradient
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
              initialDate: _selectedDateOfBirth ??
                  DateTime.now().subtract(const Duration(days: 365 * 25)),
              firstDate: DateTime(1900),
              lastDate: DateTime.now(),
            );
            if (picked != null && picked != _selectedDateOfBirth) {
              setState(() {
                _selectedDateOfBirth = picked;
              });
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                Icon(EvaIcons.calendarOutline, color: const Color(0xFFFA709A)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _selectedDateOfBirth == null
                        ? 'Date of Birth *'
                        : 'Date of Birth: ${_selectedDateOfBirth!.day}/${_selectedDateOfBirth!.month}/${_selectedDateOfBirth!.year}',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      color: _selectedDateOfBirth == null
                          ? Colors.grey[600]
                          : Colors.black,
                    ),
                  ),
                ),
                Icon(Icons.arrow_drop_down, color: const Color(0xFFFA709A)),
              ],
            ),
          ),
        ),
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
      return 'Please enter pharmacy license number';
    }

    // Remove spaces and convert to uppercase for validation
    String cleanValue = value.replaceAll(' ', '').toUpperCase();

    // PCI format: Usually starts with state code followed by numbers
    // Examples: MH12345, DL67890, KA123456, TN789012
    if (!RegExp(r'^[A-Z]{2}[0-9]{4,6}$').hasMatch(cleanValue)) {
      return 'Invalid PCI format. Use format like MH12345 or DL67890';
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
      return 'Invalid state code. Please check your license number';
    }

    return null;
  }

  String? _validatePharmacistLicense(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter pharmacist license number';
    }

    // Remove spaces and convert to uppercase for validation
    String cleanValue = value.replaceAll(' ', '').toUpperCase();

    // Pharmacist license format: Usually starts with state code followed by numbers
    // Examples: MH12345, DL67890, KA123456, TN789012
    if (!RegExp(r'^[A-Z]{2}[0-9]{4,6}$').hasMatch(cleanValue)) {
      return 'Invalid pharmacist license format. Use format like MH12345 or DL67890';
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
      return 'Invalid state code. Please check your pharmacist license number';
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
          colors: [
            Color(0xFFFA709A),
            Color(0xFFFEE140)
          ], // Pharmacy pink-yellow gradient
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
            prefixIcon: Icon(icon, color: const Color(0xFFFA709A)),
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
            color: const Color(0xFFFA709A), // Pharmacy pink-yellow
          ),
        ),
        const SizedBox(height: 16),

        // Pharmacy Name
        _buildInputField(
          controller: _pharmacyNameController,
          label: 'Pharmacy Name',
          icon: EvaIcons.homeOutline,
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
        _buildGenderDropdown(),

        // Date of Birth
        _buildDateOfBirthField(),
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
            color: const Color(0xFFFA709A), // Pharmacy pink-yellow
          ),
        ),
        const SizedBox(height: 16),

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
        color: const Color(0xFFFA709A).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFA709A).withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(EvaIcons.navigationOutline, color: const Color(0xFFFA709A)),
              const SizedBox(width: 8),
              Text(
                'Location Coordinates',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFFFA709A),
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
                    backgroundColor: const Color(0xFFFA709A),
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
                    foregroundColor: const Color(0xFFFA709A),
                    side: BorderSide(color: const Color(0xFFFA709A)),
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
            'Location helps patients find your pharmacy easily and enables distance-based search.',
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
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
            color: const Color(0xFFFA709A), // Pharmacy pink-yellow
          ),
        ),
        const SizedBox(height: 16),

        // License Number
        _buildInputField(
          controller: _licenseNumberController,
          label: 'Pharmacy License Number',
          icon: EvaIcons.awardOutline,
          validator: _validateLicenseNumber,
        ),

        // Owner Name
        _buildInputField(
          controller: _ownerNameController,
          label: 'Owner Name',
          icon: EvaIcons.personOutline,
        ),

        // Pharmacist Name
        _buildInputField(
          controller: _pharmacistNameController,
          label: 'Pharmacist Name',
          icon: EvaIcons.personOutline,
        ),

        // Pharmacist License Number
        _buildInputField(
          controller: _pharmacistLicenseController,
          label: 'Pharmacist License Number',
          icon: EvaIcons.awardOutline,
          validator: _validatePharmacistLicense,
        ),

        // Pharmacist Qualification
        _buildQualificationDropdown(),

        // Pharmacist Experience
        _buildInputField(
          controller: _pharmacistExperienceController,
          label: 'Years of Experience',
          icon: EvaIcons.clockOutline,
          keyboardType: TextInputType.number,
          validator: _validateExperience,
        ),

        // Hospital Affiliations
        HospitalAffiliationSelector(
          selectedHospitals: _pharmacyAffiliatedHospitals,
          onChanged: (hospitals) {
            setState(() {
              _pharmacyAffiliatedHospitals = hospitals;
            });
          },
          userType: 'pharmacy',
          primaryColor: const Color(0xFFFA709A),
        ),

        // Home Delivery
        Row(
          children: [
            Checkbox(
              value: _homeDelivery,
              onChanged: (bool? value) {
                setState(() {
                  _homeDelivery = value ?? false;
                });
              },
              activeColor: const Color(0xFFFA709A),
            ),
            Text(
              'Home Delivery Available',
              style: GoogleFonts.poppins(
                fontSize: 16,
                color: const Color(0xFFFA709A),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBusinessInformation() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Business Information',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: const Color(0xFFFA709A), // Pharmacy pink-yellow
          ),
        ),
        const SizedBox(height: 16),

        // Operating Hours
        Text(
          'Operating Hours',
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: const Color(0xFFFA709A),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildTimeDropdown(
                value: _openTimeController.text.isEmpty
                    ? null
                    : _openTimeController.text,
                label: 'Opening Time',
                onChanged: (value) {
                  _openTimeController.text = value ?? '';
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildTimeDropdown(
                value: _closeTimeController.text.isEmpty
                    ? null
                    : _closeTimeController.text,
                label: 'Closing Time',
                onChanged: (value) {
                  _closeTimeController.text = value ?? '';
                },
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Working Days
        Text(
          'Working Days',
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: const Color(0xFFFA709A),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _workingDays.map((day) {
            final isSelected = _selectedWorkingDays.contains(day);
            return FilterChip(
              label: Text(day),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    _selectedWorkingDays.add(day);
                  } else {
                    _selectedWorkingDays.remove(day);
                  }
                });
              },
              selectedColor: const Color(0xFFFA709A).withOpacity(0.2),
              checkmarkColor: const Color(0xFFFA709A),
            );
          }).toList(),
        ),

        const SizedBox(height: 24),

        // Services Provided
        Text(
          'Services Provided',
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: const Color(0xFFFA709A),
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
              selectedColor: const Color(0xFFFA709A).withOpacity(0.2),
              checkmarkColor: const Color(0xFFFA709A),
            );
          }).toList(),
        ),

        const SizedBox(height: 24),

        // Drugs Available
        Text(
          'Types of Drugs Available',
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: const Color(0xFFFA709A),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _availableDrugs.map((drug) {
            final isSelected = _selectedDrugsAvailable.contains(drug);
            return FilterChip(
              label: Text(drug),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    _selectedDrugsAvailable.add(drug);
                  } else {
                    _selectedDrugsAvailable.remove(drug);
                  }
                });
              },
              selectedColor: const Color(0xFFFA709A).withOpacity(0.2),
              checkmarkColor: const Color(0xFFFA709A),
            );
          }).toList(),
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
            color: const Color(0xFFFA709A), // Pharmacy pink-yellow
          ),
        ),
        const SizedBox(height: 16),

        // Pharmacy License Document
        _buildDocumentUploadField(
          title: 'Pharmacy License Certificate *',
          subtitle:
              'Click to select your pharmacy license certificate (Image or PDF)',
          isUploaded: _isLicenseDocumentUploaded,
          onTap: () => _pickLicenseDocument(),
          icon: EvaIcons.awardOutline,
        ),

        const SizedBox(height: 16),

        // Drug License Document
        _buildDocumentUploadField(
          title: 'Drug License Document *',
          subtitle: 'Click to select your drug license document (Image or PDF)',
          isUploaded: _isDrugLicenseUploaded,
          onTap: () => _pickDrugLicenseDocument(),
          icon: EvaIcons.fileTextOutline,
        ),

        const SizedBox(height: 16),

        // Premises Certificate
        _buildDocumentUploadField(
          title: 'Premises Certificate *',
          subtitle: 'Click to select your premises certificate (Image or PDF)',
          isUploaded: _isPremisesCertificateUploaded,
          onTap: () => _pickPremisesCertificate(),
          icon: EvaIcons.homeOutline,
        ),

        const SizedBox(height: 16),

        // Profile Picture
        _buildDocumentUploadField(
          title: 'Profile Picture *',
          subtitle: 'Click to select your profile picture',
          isUploaded: _isProfilePictureUploaded,
          onTap: () => _pickProfilePicture(),
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
            Color(0xFFFA709A),
            Color(0xFFFEE140)
          ], // Pharmacy pink-yellow gradient
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
                  color: const Color(0xFFFFA500),
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
                              ? const Color(0xFFFFA500)
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
                      color: Color(0xFFFFA500),
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
              Color(0xFFFA709A), // Pharmacy pink-yellow
              Color(0xFFFEE140),
              Color(0xFFFCE4EC),
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
                          'Pharmacy Registration',
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
                          if (_currentStep == 2) _buildLocationDetails(),
                          if (_currentStep == 3) _buildOperationalDetails(),
                          if (_currentStep == 4) _buildBusinessInformation(),
                          if (_currentStep == 5) _buildDocumentUpload(),

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
                                          color: Color(0xFFFA709A)),
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
                                        color: Color(0xFFFA709A),
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
                                              Color(0xFFFA709A),
                                              Color(0xFFFEE140)
                                            ], // Pharmacy pink-yellow gradient
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
                                            if (_currentStep < 5) {
                                              setState(() {
                                                _currentStep++;
                                              });
                                            } else {
                                              _registerPharmacy();
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
                                            _currentStep < 5
                                                ? 'Next'
                                                : 'Register Pharmacy',
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
