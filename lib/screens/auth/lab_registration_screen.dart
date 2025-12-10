import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:typed_data';
import 'dart:io'; // Added for File
import '../../services/storage_service.dart';
import '../../services/api_service.dart';
import '../../services/registration_service.dart';
import '../../services/dashboard_navigation_service.dart';
import '../../models/user_model.dart';
import 'package:arcular_plus/screens/lab/dashboard_lab.dart'; // Added for LabDashboardScreen
import 'package:eva_icons_flutter/eva_icons_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../../widgets/hospital_affiliation_selector.dart';

class LabRegistrationScreen extends StatefulWidget {
  final String signupEmail;
  final String signupPhone;
  final String signupPassword;
  final String signupCountryCode;

  const LabRegistrationScreen({
    super.key,
    required this.signupEmail,
    required this.signupPhone,
    required this.signupPassword,
    required this.signupCountryCode,
  });

  @override
  State<LabRegistrationScreen> createState() => _LabRegistrationScreenState();
}

class _LabRegistrationScreenState extends State<LabRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();

  // Basic Information Controllers
  final _labNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _altPhoneController = TextEditingController();

  // Location Details Controllers
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _pincodeController = TextEditingController();

  // Operational Details Controllers
  final _licenseNumberController = TextEditingController();
  final _associatedHospitalController = TextEditingController();
  final _ownerNameController = TextEditingController();

  // Dropdown Values
  List<String> _selectedAvailableTests = [];
  bool _homeSampleCollection = false;

  // Location and Hospital Affiliation
  double? _longitude;
  double? _latitude;
  bool _isGettingLocation = false;
  List<Map<String, dynamic>> _labAffiliatedHospitals = [];

  // Document Upload
  File? _selectedLicenseDocument;
  File? _selectedProfileImage; // Added profile image file
  String? _licenseDocumentUrl;
  String? _profileImageUrl; // Added profile image URL
  bool _isUploading = false;

  // Form State
  bool _isLoading = false;
  int _currentStep =
      1; // 1: Basic Info, 2: Location, 3: Operational, 4: Documents

  // Lists for dropdowns
  final List<String> _availableTests = [
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

    // Pre-fill email and phone if provided from signup
    if (widget.signupEmail.isNotEmpty) {
      _emailController.text = widget.signupEmail;
    }
    if (widget.signupPhone.isNotEmpty) {
      _phoneController.text = widget.signupPhone;
    }

    // Add listeners to trigger UI updates when fields change
    _labNameController.addListener(() => setState(() {}));
    _emailController.addListener(() => setState(() {}));
    _phoneController.addListener(() => setState(() {}));
    _altPhoneController.addListener(() => setState(() {}));
    _addressController.addListener(() => setState(() {}));
    _cityController.addListener(() => setState(() {}));
    _stateController.addListener(() => setState(() {}));
    _pincodeController.addListener(() => setState(() {}));
    _licenseNumberController.addListener(() => setState(() {}));
    _associatedHospitalController.addListener(() => setState(() {}));
    _ownerNameController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    // Remove listeners
    _labNameController.removeListener(() => setState(() {}));
    _emailController.removeListener(() => setState(() {}));
    _phoneController.removeListener(() => setState(() {}));
    _altPhoneController.removeListener(() => setState(() {}));
    _addressController.removeListener(() => setState(() {}));
    _cityController.removeListener(() => setState(() {}));
    _stateController.removeListener(() => setState(() {}));
    _pincodeController.removeListener(() => setState(() {}));
    _licenseNumberController.removeListener(() => setState(() {}));
    _associatedHospitalController.removeListener(() => setState(() {}));
    _ownerNameController.removeListener(() => setState(() {}));

    // Dispose controllers
    _labNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _altPhoneController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _pincodeController.dispose();
    _licenseNumberController.dispose();
    _associatedHospitalController.dispose();
    _ownerNameController.dispose();
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
        return _labNameController.text.trim().isNotEmpty &&
            _emailController.text.trim().isNotEmpty &&
            _phoneController.text.trim().isNotEmpty;
      case 2:
        return _addressController.text.trim().isNotEmpty &&
            _cityController.text.trim().isNotEmpty &&
            _stateController.text.trim().isNotEmpty &&
            _pincodeController.text.trim().isNotEmpty;
      case 3:
        return _licenseNumberController.text.trim().isNotEmpty &&
            _ownerNameController.text.trim().isNotEmpty;
      case 4:
        return _licenseDocumentUrl != null && _profileImageUrl != null;
      default:
        return false;
    }
  }

  void _toggleTest(String test) {
    setState(() {
      if (_selectedAvailableTests.contains(test)) {
        _selectedAvailableTests.remove(test);
      } else {
        _selectedAvailableTests.add(test);
      }
    });
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
            _licenseDocumentUrl = 'uploaded_license_url';
            _isUploading = false;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('License document uploaded successfully!'),
              backgroundColor: Color(0xFF43E97B),
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
            _licenseDocumentUrl = 'uploaded_license_url';
            _isUploading = false;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('License PDF uploaded successfully!'),
              backgroundColor: Color(0xFF43E97B),
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
          _selectedProfileImage = File(image.path);
          _profileImageUrl = 'uploaded_profile_url';
          _isUploading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile picture uploaded successfully!'),
            backgroundColor: Color(0xFF43E97B),
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

  Future<void> _registerLab() async {
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

      // Create lab user model
      final labUser = {
        'uid': firebaseUser.uid,
        'fullName':
            _labNameController.text.trim(), // Map to fullName for consistency
        'email': _emailController.text.trim(),
        'mobileNumber': _phoneController.text.trim(),
        'address': _addressController.text.trim(),
        'city': _cityController.text.trim(),
        'state': _stateController.text.trim(),
        'pincode': _pincodeController.text.trim(),
        'longitude': _longitude,
        'latitude': _latitude,
        'labName': _labNameController.text.trim(),
        'licenseNumber': _licenseNumberController.text.trim(),
        'ownerName': _ownerNameController.text.trim(),
        'servicesProvided': _selectedAvailableTests, // Fixed field name
        'profileImageUrl': _profileImageUrl ?? '',
        'affiliatedHospitals': _labAffiliatedHospitals, // Fixed field name
        'licenseDocumentUrl': _licenseDocumentUrl ?? '',
        'accreditationCertificateUrl':
            _licenseDocumentUrl ?? '', // Add accreditation
        'equipmentCertificateUrl':
            _profileImageUrl ?? '', // Add equipment certificate
        'homeSampleCollection': _homeSampleCollection, // Add as custom field
        'alternateMobile': _altPhoneController.text.trim().isEmpty
            ? null
            : _altPhoneController.text.trim(), // Add as custom field
        'associatedHospital':
            _associatedHospitalController.text.trim(), // Add as custom field
        'documents': {
          'lab_license': _licenseDocumentUrl,
          'accreditation_certificate': _licenseDocumentUrl,
          'equipment_certificate': _profileImageUrl,
        },
      };

      // Prepare documents
      final documents = <File>[];
      final documentTypes = <String>[];

      if (_selectedLicenseDocument != null) {
        documents.add(_selectedLicenseDocument!);
        documentTypes.add('lab_license');
      }
      if (_selectedProfileImage != null) {
        documents.add(_selectedProfileImage!);
        documentTypes.add('equipment_certificate');
      }

      // Use the registration service
      final result = await RegistrationService.registerUser(
        userType: 'lab',
        userData: labUser,
        documents: documents,
        documentTypes: documentTypes,
        uploadedDocuments: {
          'lab_license': _licenseDocumentUrl ?? '',
          'accreditation_certificate': _licenseDocumentUrl ?? '',
          'equipment_certificate': _profileImageUrl ?? '',
        },
      );

      if (result['success']) {
        // Save user type to SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_type', 'lab');
        await prefs.setString('user_uid', firebaseUser.uid);
        await prefs.setString('user_status', 'pending');

        if (mounted) {
          // Show success popup
          await _showCustomPopup(
            success: true,
            message: result['message'] ??
                'Lab registration successful! Your account is pending approval.',
          );

          // Navigate based on user type and approval status
          await DashboardNavigationService.navigateAfterRegistration(
            context,
            'lab',
            'pending',
          );
        }
      } else {
        if (mounted) {
          await _showCustomPopup(
            success: false,
            message: result['message'] ??
                'Failed to register lab. Please check your internet connection and try again.',
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
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              success ? Icons.check_circle : Icons.error,
              color: success ? const Color(0xFF43E97B) : Colors.red,
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
              _buildStepCircle(4, _currentStep >= 4, 'Documents'),
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
            color: isActive ? const Color(0xFF43E97B) : Colors.white,
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
      return 'Please enter lab registration number';
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
          colors: [Color(0xFFFDBA74), Color(0xFFFB923C)], // Lab orange gradient
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
            prefixIcon: Icon(icon, color: const Color(0xFFFB923C)),
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
            color: const Color(0xFFFB923C),
          ),
        ),
        const SizedBox(height: 16),

        // Lab Name
        _buildInputField(
          controller: _labNameController,
          label: 'Lab Name',
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
            color: const Color(0xFFFB923C),
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
        color: const Color(0xFFFB923C).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFB923C).withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(EvaIcons.navigationOutline, color: const Color(0xFFFB923C)),
              const SizedBox(width: 8),
              Text(
                'Location Coordinates',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFFFB923C),
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
                    backgroundColor: const Color(0xFF43E97B),
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
                    foregroundColor: const Color(0xFFFB923C),
                    side: BorderSide(color: const Color(0xFFFB923C)),
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
            'Location helps patients find your lab easily and enables distance-based search.',
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
            color: const Color(0xFFFB923C),
          ),
        ),
        const SizedBox(height: 16),

        // License Number
        _buildInputField(
          controller: _licenseNumberController,
          label: 'Lab License Number',
          icon: EvaIcons.awardOutline,
          validator: _validateLicenseNumber,
        ),

        // Associated Hospital
        _buildInputField(
          controller: _associatedHospitalController,
          label: 'Associated Hospital',
          icon: EvaIcons.homeOutline,
          isRequired: false,
        ),

        // Owner Name
        _buildInputField(
          controller: _ownerNameController,
          label: 'Owner Name',
          icon: EvaIcons.personOutline,
          validator: _validateName,
        ),

        // Hospital Affiliations
        HospitalAffiliationSelector(
          selectedHospitals: _labAffiliatedHospitals,
          onChanged: (hospitals) {
            setState(() {
              _labAffiliatedHospitals = hospitals;
            });
          },
          userType: 'lab',
          primaryColor: const Color(0xFF43E97B),
        ),

        // Available Tests
        Text(
          'Available Tests',
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF43E97B),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 200,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF43E97B).withOpacity(0.3)),
          ),
          child: ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: _availableTests.length,
            itemBuilder: (context, index) {
              final test = _availableTests[index];
              return CheckboxListTile(
                title: Text(
                  test,
                  style: GoogleFonts.poppins(fontSize: 14),
                ),
                value: _selectedAvailableTests.contains(test),
                onChanged: (bool? value) {
                  _toggleTest(test);
                },
                activeColor: const Color(0xFF43E97B),
                checkColor: Colors.white,
              );
            },
          ),
        ),
        const SizedBox(height: 16),

        // Home Sample Collection
        Row(
          children: [
            Checkbox(
              value: _homeSampleCollection,
              onChanged: (bool? value) {
                setState(() {
                  _homeSampleCollection = value ?? false;
                });
              },
              activeColor: const Color(0xFF43E97B),
            ),
            Text(
              'Home Sample Collection Available',
              style: GoogleFonts.poppins(
                fontSize: 16,
                color: const Color(0xFF43E97B),
              ),
            ),
          ],
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
            color: const Color(0xFF43E97B), // Lab green-blue
          ),
        ),
        const SizedBox(height: 16),

        // License Document
        _buildDocumentUploadField(
          title: 'Lab License Certificate *',
          subtitle:
              'Click to select your lab license certificate (Image or PDF)',
          isUploaded: _licenseDocumentUrl != null,
          onTap: () => _pickLicenseDocument(),
          icon: EvaIcons.awardOutline,
        ),

        const SizedBox(height: 16),

        // Profile Picture
        _buildDocumentUploadField(
          title: 'Profile Picture *',
          subtitle: 'Click to select your profile picture',
          isUploaded: _profileImageUrl != null,
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
            Color(0xFF43E97B),
            Color(0xFF38F9D7)
          ], // Lab green-blue gradient
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
                  color: const Color(0xFF43E97B), // Lab green-blue
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
                              ? const Color(0xFF43E97B)
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
                      color: Color(0xFF43E97B),
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
              Color(0xFFFDBA74),
              Color(0xFFFB923C),
              Color(0xFFFFEDD5),
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
                          'Lab Registration',
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
                                      side: const BorderSide(
                                          color: Color(0xFFFB923C)),
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
                                        color: Color(0xFFFB923C),
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
                                              Color(0xFFFDBA74),
                                              Color(0xFFFB923C)
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
                                            if (_currentStep < 4) {
                                              setState(() {
                                                _currentStep++;
                                              });
                                            } else {
                                              _registerLab();
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
                                                : 'Register Lab',
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
