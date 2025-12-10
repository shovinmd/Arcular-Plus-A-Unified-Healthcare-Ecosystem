import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../services/api_service.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';

import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/storage_service.dart'; // Added import for StorageService

class UpdateProfileScreen extends StatefulWidget {
  final UserModel user;
  const UpdateProfileScreen({Key? key, required this.user}) : super(key: key);

  @override
  State<UpdateProfileScreen> createState() => _UpdateProfileScreenState();
}

class _UpdateProfileScreenState extends State<UpdateProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _mobileController;
  late TextEditingController _alternateMobileController;
  late TextEditingController _addressController;
  late TextEditingController _cityController;
  late TextEditingController _stateController;
  late TextEditingController _pincodeController;
  late TextEditingController _aadhaarController;
  late TextEditingController _heightController;
  late TextEditingController _weightController;
  late TextEditingController _emergencyContactNameController;
  late TextEditingController _emergencyContactNumberController;
  late TextEditingController _healthInsuranceController;
  late TextEditingController _policyNumberController;
  late TextEditingController _allergiesController;
  late TextEditingController _chronicConditionsController;
  late TextEditingController _babyNameController;
  late TextEditingController _babyWeightController;
  late TextEditingController _numberOfPreviousPregnanciesController;
  late TextEditingController _lastPregnancyYearController;
  late TextEditingController _pregnancyHealthNotesController;
  List<String> _knownAllergies = [];
  List<String> _chronicConditions = [];
  String _selectedBloodGroup = 'A+';
  String _selectedEmergencyRelation = 'Spouse';
  bool _isPregnant = false;
  DateTime? _pregnancyStartDate;
  DateTime? _dueDate;
  bool _pregnancyPrivacyConsent = false;
  DateTime? _policyExpiryDate;
  File? _selectedImage;
  String? _profileImageUrl;
  File? _aadhaarFrontImage;
  File? _aadhaarBackImage;
  String? _aadhaarFrontUrl;
  String? _aadhaarBackUrl;
  File? _insuranceCardImage;
  String? _insuranceCardImageUrl;
  final ImagePicker _picker = ImagePicker();

  late String gender;
  late DateTime dob;
  bool loading = false;
  bool _initialLoading = true; // Add initial loading state

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
  final List<String> _emergencyRelations = [
    'Spouse',
    'Parent',
    'Child',
    'Sibling',
    'Friend',
    'Other'
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.user.fullName);
    _emailController = TextEditingController(text: widget.user.email);
    _mobileController = TextEditingController(text: widget.user.mobileNumber);
    _alternateMobileController =
        TextEditingController(text: widget.user.alternateMobile ?? '');
    _addressController = TextEditingController(text: widget.user.address);
    _cityController = TextEditingController(text: widget.user.city);
    _stateController = TextEditingController(text: widget.user.state);
    _pincodeController = TextEditingController(text: widget.user.pincode);
    _aadhaarController =
        TextEditingController(text: widget.user.aadhaarNumber ?? '');
    gender = widget.user.gender.trim();
    dob = widget.user.dateOfBirth;
    _heightController =
        TextEditingController(text: widget.user.height?.toString() ?? '');
    _weightController =
        TextEditingController(text: widget.user.weight?.toString() ?? '');
    _selectedBloodGroup = widget.user.bloodGroup ?? 'A+';
    _knownAllergies = widget.user.knownAllergies ?? [];
    _chronicConditions = widget.user.chronicConditions ?? [];
    _allergiesController = TextEditingController();
    _chronicConditionsController = TextEditingController();
    _emergencyContactNameController =
        TextEditingController(text: widget.user.emergencyContactName ?? '');
    _emergencyContactNumberController =
        TextEditingController(text: widget.user.emergencyContactNumber ?? '');
    _selectedEmergencyRelation =
        widget.user.emergencyContactRelation ?? 'Spouse';
    _healthInsuranceController =
        TextEditingController(text: widget.user.healthInsuranceId ?? '');
    _policyNumberController =
        TextEditingController(); // Will be added to backend later
    _babyNameController =
        TextEditingController(text: widget.user.babyName ?? '');
    _babyWeightController = TextEditingController(
        text: widget.user.babyWeightAtBirth?.toString() ?? '');
    _numberOfPreviousPregnanciesController = TextEditingController(
        text: widget.user.numberOfPreviousPregnancies?.toString() ?? '');
    _lastPregnancyYearController = TextEditingController(
        text: widget.user.lastPregnancyYear?.toString() ?? '');
    _pregnancyHealthNotesController =
        TextEditingController(text: widget.user.pregnancyHealthNotes ?? '');
    _isPregnant = widget.user.isPregnant ?? false;
    _pregnancyStartDate = widget.user.pregnancyStartDate;
    _dueDate = widget.user.dueDate;
    _pregnancyPrivacyConsent = widget.user.pregnancyPrivacyConsent ?? false;
    _profileImageUrl = widget.user.profileImageUrl;
    _aadhaarFrontUrl = widget.user.aadhaarFrontImageUrl;
    _aadhaarBackUrl = widget.user.aadhaarBackImageUrl;
    _insuranceCardImageUrl = widget.user.insuranceCardImageUrl;

    // Show gradient loading screen briefly
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) {
        setState(() {
          _initialLoading = false;
        });
      }
    });
  }

  // Refresh user data after successful updates
  Future<void> _refreshUserData() async {
    try {
      // Fetch updated user data from the backend
      final updatedUser = await ApiService.getUserProfile(widget.user.uid);
      if (updatedUser != null) {
        // Update the widget.user with new data
        // This ensures the profile screen shows the latest data
        setState(() {
          // Update controllers with new values
          _nameController.text = updatedUser.fullName;
          _emailController.text = updatedUser.email;
          _mobileController.text = updatedUser.mobileNumber;
          _alternateMobileController.text = updatedUser.alternateMobile ?? '';
          _addressController.text = updatedUser.address;
          _cityController.text = updatedUser.city;
          _stateController.text = updatedUser.state;
          _pincodeController.text = updatedUser.pincode;
          _aadhaarController.text = updatedUser.aadhaarNumber ?? '';
          _heightController.text = updatedUser.height?.toString() ?? '';
          _weightController.text = updatedUser.weight?.toString() ?? '';
          _emergencyContactNameController.text =
              updatedUser.emergencyContactName ?? '';
          _emergencyContactNumberController.text =
              updatedUser.emergencyContactNumber ?? '';
          _healthInsuranceController.text = updatedUser.healthInsuranceId ?? '';
          _babyNameController.text = updatedUser.babyName ?? '';
          _babyWeightController.text =
              updatedUser.babyWeightAtBirth?.toString() ?? '';
          _numberOfPreviousPregnanciesController.text =
              updatedUser.numberOfPreviousPregnancies?.toString() ?? '';
          _lastPregnancyYearController.text =
              updatedUser.lastPregnancyYear?.toString() ?? '';
          _pregnancyHealthNotesController.text =
              updatedUser.pregnancyHealthNotes ?? '';

          // Update other fields
          gender = updatedUser.gender.trim();
          dob = updatedUser.dateOfBirth;
          _selectedBloodGroup = updatedUser.bloodGroup ?? 'A+';
          _knownAllergies = updatedUser.knownAllergies ?? [];
          _chronicConditions = updatedUser.chronicConditions ?? [];
          _selectedEmergencyRelation =
              updatedUser.emergencyContactRelation ?? 'Spouse';
          _isPregnant = updatedUser.isPregnant ?? false;
          _pregnancyPrivacyConsent =
              updatedUser.pregnancyPrivacyConsent ?? false;

          // Update image URLs
          _profileImageUrl = updatedUser.profileImageUrl;
          _aadhaarFrontUrl = updatedUser.aadhaarFrontImageUrl;
          _aadhaarBackUrl = updatedUser.aadhaarBackImageUrl;
          _insuranceCardImageUrl = updatedUser.insuranceCardImageUrl;
        });

        print('✅ User data refreshed successfully');
      }
    } catch (e) {
      print('❌ Error refreshing user data: $e');
      // Don't show error to user for refresh failure
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _mobileController.dispose();
    _alternateMobileController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _pincodeController.dispose();
    _aadhaarController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _emergencyContactNameController.dispose();
    _emergencyContactNumberController.dispose();
    _healthInsuranceController.dispose();
    _policyNumberController.dispose();
    _babyNameController.dispose();
    _babyWeightController.dispose();
    _numberOfPreviousPregnanciesController.dispose();
    _lastPregnancyYearController.dispose();
    _pregnancyHealthNotesController.dispose();
    _allergiesController.dispose();
    _chronicConditionsController.dispose();
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

  Future<void> _pickAadhaarFrontImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _aadhaarFrontImage = File(pickedFile.path);
      });
    }
  }

  Future<void> _pickAadhaarBackImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _aadhaarBackImage = File(pickedFile.path);
      });
    }
  }

  Future<void> _pickInsuranceCardImage() async {
    // Show file type selection dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Select File Type',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.image, color: Colors.blue),
              title: const Text('Image File'),
              subtitle: const Text('JPG, PNG'),
              onTap: () {
                Navigator.pop(context);
                _pickImageFile();
              },
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
              title: const Text('PDF Document'),
              subtitle: const Text('PDF files'),
              onTap: () {
                Navigator.pop(context);
                _pickPdfFile();
              },
            ),
            ListTile(
              leading: const Icon(Icons.description, color: Colors.green),
              title: const Text('Word Document'),
              subtitle: const Text('DOC, DOCX files'),
              onTap: () {
                Navigator.pop(context);
                _pickDocumentFile();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImageFile() async {
    final pickedFile = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 80,
    );

    if (pickedFile != null) {
      setState(() {
        _insuranceCardImage = File(pickedFile.path);
      });
    }
  }

  Future<void> _pickPdfFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = File(result.files.first.path!);
        setState(() {
          _insuranceCardImage = file;
        });
      }
    } catch (e) {
      print('Error picking PDF file: $e');
    }
  }

  Future<void> _pickDocumentFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['doc', 'docx'],
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = File(result.files.first.path!);
        setState(() {
          _insuranceCardImage = file;
        });
      }
    } catch (e) {
      print('Error picking document file: $e');
    }
  }

  Widget _buildFilePreview(File file) {
    final extension = file.path.split('.').last.toLowerCase();

    if (['jpg', 'jpeg', 'png'].contains(extension)) {
      // Image preview
      return Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.file(
              file,
              fit: BoxFit.cover,
              width: double.infinity,
            ),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _insuranceCardImage = null;
                });
              },
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.close,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ),
          ),
        ],
      );
    } else {
      // Document preview
      return Stack(
        children: [
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  extension == 'pdf' ? Icons.picture_as_pdf : Icons.description,
                  color: extension == 'pdf' ? Colors.red : Colors.green,
                  size: 32,
                ),
                const SizedBox(height: 8),
                Text(
                  file.path.split('/').last,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[700],
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _insuranceCardImage = null;
                });
              },
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.close,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ),
          ),
        ],
      );
    }
  }

  Widget _buildUrlFilePreview(String url) {
    final extension = url.split('.').last.toLowerCase();

    if (['jpg', 'jpeg', 'png'].contains(extension)) {
      // Image preview from URL
      return Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              url,
              fit: BoxFit.cover,
              width: double.infinity,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  color: Colors.grey[200],
                  child: const Center(
                    child: Icon(
                      Icons.image_not_supported,
                      color: Colors.grey,
                      size: 32,
                    ),
                  ),
                );
              },
            ),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _insuranceCardImageUrl = null;
                });
              },
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.close,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ),
          ),
        ],
      );
    } else {
      // Document preview from URL
      return Stack(
        children: [
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  extension == 'pdf' ? Icons.picture_as_pdf : Icons.description,
                  color: extension == 'pdf' ? Colors.red : Colors.green,
                  size: 32,
                ),
                const SizedBox(height: 8),
                Text(
                  'Insurance Document',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[700],
                  ),
                ),
                Text(
                  extension.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _insuranceCardImageUrl = null;
                });
              },
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.close,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ),
          ),
        ],
      );
    }
  }

  Future<void> _saveProfile() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    setState(() => loading = true);
    String? imageUrl = _profileImageUrl;
    String? aadhaarFrontUrl = _aadhaarFrontUrl;
    String? aadhaarBackUrl = _aadhaarBackUrl;
    String? insuranceCardUrl = null;

    try {
      // Upload profile image if selected
      if (_selectedImage != null) {
        try {
          final storageService = StorageService();
          final imageBytes = await _selectedImage!.readAsBytes();
          final uploadedUrl = await storageService.uploadProfilePicture(
            userId: widget.user.uid,
            userType: 'patient',
            imageBytes: imageBytes,
          );
          if (uploadedUrl != null) {
            imageUrl = uploadedUrl;
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

      // Upload Aadhaar front image if selected
      if (_aadhaarFrontImage != null) {
        try {
          final storageService = StorageService();
          final imageBytes = await _aadhaarFrontImage!.readAsBytes();
          final uploadedUrl = await storageService.uploadCertificate(
            userId: widget.user.uid,
            userType: 'patient',
            certificateType: 'aadhaar_front',
            fileName: 'aadhaar_front.jpg',
            fileBytes: imageBytes,
          );
          if (uploadedUrl != null) {
            aadhaarFrontUrl = uploadedUrl;
          }
        } catch (e) {
          print('Aadhaar front image upload failed: $e');
          await _showGradientPopup(
            success: false,
            message: 'Aadhaar front image upload failed. Please try again.',
          );
          setState(() => loading = false);
          return;
        }
      }

      // Upload Aadhaar back image if selected
      if (_aadhaarBackImage != null) {
        try {
          final storageService = StorageService();
          final imageBytes = await _aadhaarBackImage!.readAsBytes();
          final uploadedUrl = await storageService.uploadCertificate(
            userId: widget.user.uid,
            userType: 'patient',
            certificateType: 'aadhaar_back',
            fileName: 'aadhaar_back.jpg',
            fileBytes: imageBytes,
          );
          if (uploadedUrl != null) {
            aadhaarBackUrl = uploadedUrl;
          }
        } catch (e) {
          print('Aadhaar back image upload failed: $e');
          await _showGradientPopup(
            success: false,
            message: 'Aadhaar back image upload failed. Please try again.',
          );
          setState(() => loading = false);
          return;
        }
      }

      // Upload insurance card file if selected
      if (_insuranceCardImage != null) {
        try {
          final storageService = StorageService();
          final fileBytes = await _insuranceCardImage!.readAsBytes();
          final extension =
              _insuranceCardImage!.path.split('.').last.toLowerCase();
          final fileName = 'insurance_card.$extension';

          final uploadedUrl = await storageService.uploadCertificate(
            userId: widget.user.uid,
            userType: 'patient',
            certificateType: 'insurance_card',
            fileName: fileName,
            fileBytes: fileBytes,
            contentType: extension == 'pdf'
                ? 'application/pdf'
                : ['doc', 'docx'].contains(extension)
                    ? 'application/msword'
                    : 'image/jpeg',
          );
          if (uploadedUrl != null) {
            insuranceCardUrl = uploadedUrl;
          }
        } catch (e) {
          print('Insurance card file upload failed: $e');
          await _showGradientPopup(
            success: false,
            message: 'Insurance card file upload failed. Please try again.',
          );
          setState(() => loading = false);
          return;
        }
      }

      final updates = {
        'fullName': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'mobileNumber': _mobileController.text.trim(),
        'alternateMobile': _alternateMobileController.text.trim().isNotEmpty
            ? _alternateMobileController.text.trim()
            : null,
        'gender': gender, // Add gender to updates
        'dateOfBirth': dob.toIso8601String(), // Add date of birth to updates
        'aadhaarNumber': _aadhaarController.text.trim().isNotEmpty
            ? _aadhaarController.text.trim()
            : null,
        'address': _addressController.text.trim(),
        'city': _cityController.text.trim(),
        'state': _stateController.text.trim(),
        'pincode': _pincodeController.text.trim(),
        'height': double.tryParse(_heightController.text) ?? 0.0,
        'weight': double.tryParse(_weightController.text) ?? 0.0,
        'healthInsuranceId': _healthInsuranceController.text.trim().isNotEmpty
            ? _healthInsuranceController.text.trim()
            : null,
        'policyNumber': _policyNumberController.text.trim().isNotEmpty
            ? _policyNumberController.text.trim()
            : null,
        'policyExpiryDate': _policyExpiryDate?.toIso8601String(),
        'emergencyContactName':
            _emergencyContactNameController.text.trim().isNotEmpty
                ? _emergencyContactNameController.text.trim()
                : null,
        'emergencyContactNumber':
            _emergencyContactNumberController.text.trim().isNotEmpty
                ? _emergencyContactNumberController.text.trim()
                : null,
        'knownAllergies': _knownAllergies,
        'chronicConditions': _chronicConditions,
        'aadhaarFrontImageUrl':
            _aadhaarFrontImage != null ? aadhaarFrontUrl : _aadhaarFrontUrl,
        'aadhaarBackImageUrl':
            _aadhaarBackImage != null ? aadhaarBackUrl : _aadhaarBackUrl,
        'insuranceCardImageUrl': _insuranceCardImage != null
            ? insuranceCardUrl
            : _insuranceCardImageUrl,
        'isPregnant': _isPregnant,
        'pregnancyTrackingEnabled': _isPregnant,
        'pregnancyStartDate': _pregnancyStartDate?.toIso8601String(),
        'pregnancyPrivacyConsent': _pregnancyPrivacyConsent,
        'profileImageUrl': imageUrl,
        // Preserve existing values for fields that might not be in the form
        'babyName': _babyNameController.text.trim().isNotEmpty
            ? _babyNameController.text.trim()
            : null,
        'babyWeightAtBirth': _babyWeightController.text.trim().isEmpty
            ? null
            : double.tryParse(_babyWeightController.text),
        'numberOfPreviousPregnancies':
            _numberOfPreviousPregnanciesController.text.trim().isEmpty
                ? null
                : int.tryParse(_numberOfPreviousPregnanciesController.text),
        'lastPregnancyYear': _lastPregnancyYearController.text.trim().isEmpty
            ? null
            : int.tryParse(_lastPregnancyYearController.text),
        'pregnancyHealthNotes':
            _pregnancyHealthNotesController.text.trim().isNotEmpty
                ? _pregnancyHealthNotesController.text.trim()
                : null,
      };

      // Filter out null values to prevent overwriting existing data with null
      final filteredUpdates = Map<String, dynamic>.from(updates)
        ..removeWhere((key, value) => value == null);

      print('🔍 Sending filtered updates: $filteredUpdates');

      final success =
          await ApiService.updateUserProfile(widget.user.uid, filteredUpdates);

      if (success) {
        setState(() => loading = false);
        if (mounted) {
          // Refresh user data to show updated values
          await _refreshUserData();
          await _showGradientPopup(
            success: true,
            message: 'Profile updated successfully!',
          );
          // Navigate back to profile screen with update result
          Navigator.pop(context, true);
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

  void _addAllergy() {
    if (_allergiesController.text.isNotEmpty) {
      setState(() {
        _knownAllergies.add(_allergiesController.text.trim());
        _allergiesController.clear();
      });
    }
  }

  void _removeAllergy(String allergy) {
    setState(() {
      _knownAllergies.remove(allergy);
    });
  }

  void _addChronicCondition() {
    if (_chronicConditionsController.text.isNotEmpty) {
      setState(() {
        _chronicConditions.add(_chronicConditionsController.text.trim());
        _chronicConditionsController.clear();
      });
    }
  }

  void _removeChronicCondition(String condition) {
    setState(() {
      _chronicConditions.remove(condition);
    });
  }

  Future<void> _showGradientPopup({
    required bool success,
    required String message,
    String? imagePath,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final gender = prefs.getString('user_gender') ?? 'Female';
    final userType = prefs.getString('user_type') ?? 'patient';

    // Default image paths based on success and gender
    String finalImagePath;
    if (imagePath != null) {
      finalImagePath =
          gender == 'Male' ? imagePath.replaceAll('Female', 'Male') : imagePath;
    } else {
      if (success) {
        finalImagePath = gender == 'Male'
            ? 'assets/images/Male/pat/love.png'
            : 'assets/images/Female/pat/love.png';
      } else {
        finalImagePath = gender == 'Male'
            ? 'assets/images/Male/pat/angry.png'
            : 'assets/images/Female/pat/angry.png';
      }
    }

    // Role-based gradient colors
    List<Color> gradientColors;
    switch (userType) {
      case 'doctor':
        gradientColors = success
            ? [const Color(0xFF2196F3), const Color(0xFF64B5F6)] // Doctor blue
            : [Colors.red[400]!, Colors.red[600]!];
        break;
      case 'hospital':
        gradientColors = success
            ? [
                const Color(0xFF4CAF50),
                const Color(0xFF81C784)
              ] // Hospital green
            : [Colors.red[400]!, Colors.red[600]!];
        break;
      case 'lab':
        gradientColors = success
            ? [const Color(0xFFFF9800), const Color(0xFFFFB74D)] // Lab orange
            : [Colors.red[400]!, Colors.red[600]!];
        break;
      case 'nurse':
        gradientColors = success
            ? [const Color(0xFF9C27B0), const Color(0xFFBA68C8)] // Nurse purple
            : [Colors.red[400]!, Colors.red[600]!];
        break;
      case 'pharmacy':
        gradientColors = success
            ? [
                const Color(0xFFFFD700),
                const Color(0xFFFFA500)
              ] // Pharmacy orange/yellow theme
            : [Colors.red[400]!, Colors.red[600]!];
        break;
      default: // patient
        gradientColors = success
            ? [const Color(0xFF32CCBC), const Color(0xFF90F7EC)] // Patient teal
            : [Colors.red[400]!, Colors.red[600]!];
        break;
    }

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
                Color(0xFF32CCBC),
                Color(0xFF90F7EC)
              ], // Patient teal gradient
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
                      'assets/images/Female/pat/cry.png'; // Default to cry for female
                  List<Color> gradientColors = [
                    const Color(0xFF32CCBC), // Patient teal
                    const Color(0xFF90F7EC),
                  ];

                  if (snapshot.hasData) {
                    final gender =
                        snapshot.data!.getString('user_gender') ?? 'Female';
                    final userType =
                        snapshot.data!.getString('user_type') ?? 'patient';

                    // Gender-specific thinking image (use cry for females)
                    if (gender == 'Male') {
                      imagePath = 'assets/images/Male/pat/think.png';
                    } else {
                      // For females, use cry image consistently
                      imagePath = 'assets/images/Female/pat/cry.png';
                    }

                    // Role-based gradient colors
                    switch (userType) {
                      case 'doctor':
                        gradientColors = [
                          const Color(0xFF2196F3),
                          const Color(0xFF64B5F6)
                        ]; // Doctor blue
                        break;
                      case 'hospital':
                        gradientColors = [
                          const Color(0xFF4CAF50),
                          const Color(0xFF81C784)
                        ]; // Hospital green
                        break;
                      case 'lab':
                        gradientColors = [
                          const Color(0xFFFF9800),
                          const Color(0xFFFFB74D)
                        ]; // Lab orange
                        break;
                      case 'nurse':
                        gradientColors = [
                          const Color(0xFF9C27B0),
                          const Color(0xFFBA68C8)
                        ]; // Nurse purple
                        break;
                      case 'pharmacy':
                        gradientColors = [
                          const Color(0xFFFFD700),
                          const Color(0xFFFFA500)
                        ]; // Pharmacy orange/yellow theme
                        break;
                      default: // patient
                        gradientColors = [
                          const Color(0xFF32CCBC),
                          const Color(0xFF90F7EC)
                        ]; // Patient teal
                        break;
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
                            backgroundColor:
                                const Color(0xFF32CCBC), // Patient teal
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
                                child: const Icon(Icons.camera_alt,
                                    size: 22,
                                    color: Color(0xFF32CCBC)), // Patient teal
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
                        labelStyle:
                            GoogleFonts.poppins(color: const Color(0xFF32CCBC)),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: Color(0xFF32CCBC)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                              color: Color(0xFF32CCBC), width: 2),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                              color: const Color(0xFF32CCBC).withOpacity(0.5)),
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
                        labelStyle:
                            GoogleFonts.poppins(color: const Color(0xFF32CCBC)),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: Color(0xFF32CCBC)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                              color: Color(0xFF32CCBC), width: 2),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                              color: const Color(0xFF32CCBC).withOpacity(0.5)),
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
                        labelStyle:
                            GoogleFonts.poppins(color: const Color(0xFF32CCBC)),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: Color(0xFF32CCBC)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                              color: Color(0xFF32CCBC), width: 2),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                              color: const Color(0xFF32CCBC).withOpacity(0.5)),
                        ),
                      ),
                      style: GoogleFonts.poppins(),
                      keyboardType: TextInputType.phone,
                      validator: (v) =>
                          v == null || v.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _alternateMobileController,
                      decoration: InputDecoration(
                        labelText: 'Alternate Mobile',
                        labelStyle:
                            GoogleFonts.poppins(color: const Color(0xFF32CCBC)),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: Color(0xFF32CCBC)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                              color: Color(0xFF32CCBC), width: 2),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                              color: const Color(0xFF32CCBC).withOpacity(0.5)),
                        ),
                      ),
                      style: GoogleFonts.poppins(),
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _aadhaarController,
                      decoration: InputDecoration(
                        labelText: 'Aadhaar Number',
                        labelStyle:
                            GoogleFonts.poppins(color: const Color(0xFF32CCBC)),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: Color(0xFF32CCBC)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                              color: Color(0xFF32CCBC), width: 2),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                              color: const Color(0xFF32CCBC).withOpacity(0.5)),
                        ),
                      ),
                      style: GoogleFonts.poppins(),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 12),

                    // Aadhaar Card Upload Section
                    Text(
                      'Aadhaar Card Images',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF32CCBC), // Patient teal
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Upload front and back images of your Aadhaar card',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Aadhaar Front Image
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Front Side',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              GestureDetector(
                                onTap: _pickAadhaarFrontImage,
                                child: Container(
                                  height: 120,
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.grey),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: _aadhaarFrontImage != null
                                      ? ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          child: Image.file(
                                            _aadhaarFrontImage!,
                                            fit: BoxFit.cover,
                                            width: double.infinity,
                                          ),
                                        )
                                      : _aadhaarFrontUrl != null &&
                                              _aadhaarFrontUrl!.isNotEmpty
                                          ? Stack(
                                              children: [
                                                ClipRRect(
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                  child: Image.network(
                                                    _aadhaarFrontUrl!,
                                                    fit: BoxFit.cover,
                                                    width: double.infinity,
                                                    errorBuilder: (context,
                                                        error, stackTrace) {
                                                      return Column(
                                                        mainAxisAlignment:
                                                            MainAxisAlignment
                                                                .center,
                                                        children: [
                                                          Icon(
                                                              Icons.add_a_photo,
                                                              color: Colors
                                                                  .grey[400]),
                                                          const SizedBox(
                                                              height: 4),
                                                          Text(
                                                            'Upload Front',
                                                            style: TextStyle(
                                                                color: Colors
                                                                    .grey[600],
                                                                fontSize: 12),
                                                          ),
                                                        ],
                                                      );
                                                    },
                                                  ),
                                                ),
                                                Positioned(
                                                  top: 4,
                                                  right: 4,
                                                  child: GestureDetector(
                                                    onTap: () {
                                                      setState(() {
                                                        _aadhaarFrontUrl = null;
                                                      });
                                                    },
                                                    child: Container(
                                                      padding:
                                                          const EdgeInsets.all(
                                                              4),
                                                      decoration: BoxDecoration(
                                                        color: Colors.red,
                                                        shape: BoxShape.circle,
                                                      ),
                                                      child: const Icon(
                                                        Icons.close,
                                                        color: Colors.white,
                                                        size: 16,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            )
                                          : Column(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Icon(Icons.add_a_photo,
                                                    color: Colors.grey[400]),
                                                const SizedBox(height: 4),
                                                Text(
                                                  'Upload Front',
                                                  style: TextStyle(
                                                      color: Colors.grey[600],
                                                      fontSize: 12),
                                                ),
                                              ],
                                            ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Back Side',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              GestureDetector(
                                onTap: _pickAadhaarBackImage,
                                child: Container(
                                  height: 120,
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.grey),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: _aadhaarBackImage != null
                                      ? ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          child: Image.file(
                                            _aadhaarBackImage!,
                                            fit: BoxFit.cover,
                                            width: double.infinity,
                                          ),
                                        )
                                      : _aadhaarBackUrl != null &&
                                              _aadhaarBackUrl!.isNotEmpty
                                          ? Stack(
                                              children: [
                                                ClipRRect(
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                  child: Image.network(
                                                    _aadhaarBackUrl!,
                                                    fit: BoxFit.cover,
                                                    width: double.infinity,
                                                    errorBuilder: (context,
                                                        error, stackTrace) {
                                                      return Column(
                                                        mainAxisAlignment:
                                                            MainAxisAlignment
                                                                .center,
                                                        children: [
                                                          Icon(
                                                              Icons.add_a_photo,
                                                              color: Colors
                                                                  .grey[400]),
                                                          const SizedBox(
                                                              height: 4),
                                                          Text(
                                                            'Upload Back',
                                                            style: TextStyle(
                                                                color: Colors
                                                                    .grey[600],
                                                                fontSize: 12),
                                                          ),
                                                        ],
                                                      );
                                                    },
                                                  ),
                                                ),
                                                Positioned(
                                                  top: 4,
                                                  right: 4,
                                                  child: GestureDetector(
                                                    onTap: () {
                                                      setState(() {
                                                        _aadhaarBackUrl = null;
                                                      });
                                                    },
                                                    child: Container(
                                                      padding:
                                                          const EdgeInsets.all(
                                                              4),
                                                      decoration: BoxDecoration(
                                                        color: Colors.red,
                                                        shape: BoxShape.circle,
                                                      ),
                                                      child: const Icon(
                                                        Icons.close,
                                                        color: Colors.white,
                                                        size: 16,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            )
                                          : Column(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Icon(Icons.add_a_photo,
                                                    color: Colors.grey[400]),
                                                const SizedBox(height: 4),
                                                Text(
                                                  'Upload Back',
                                                  style: TextStyle(
                                                      color: Colors.grey[600],
                                                      fontSize: 12),
                                                ),
                                              ],
                                            ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: gender,
                      decoration: InputDecoration(
                        labelText: 'Gender',
                        labelStyle:
                            GoogleFonts.poppins(color: const Color(0xFF32CCBC)),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: Color(0xFF32CCBC)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                              color: Color(0xFF32CCBC), width: 2),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                              color: const Color(0xFF32CCBC).withOpacity(0.5)),
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
                          setState(() => gender = v.trim());
                          // Save gender to SharedPreferences
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.setString('user_gender', v.trim());
                        }
                      },
                      validator: (v) => v == null || v.isEmpty
                          ? 'Please select gender'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Text('Date of Birth: '),
                        TextButton(
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: dob,
                              firstDate: DateTime(1900),
                              lastDate: DateTime.now(),
                            );
                            if (picked != null) setState(() => dob = picked);
                          },
                          child: Text(DateFormat('dd/MM/yyyy').format(dob)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _addressController,
                      decoration: InputDecoration(
                        labelText: 'Address',
                        labelStyle:
                            GoogleFonts.poppins(color: const Color(0xFF32CCBC)),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: Color(0xFF32CCBC)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                              color: Color(0xFF32CCBC), width: 2),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                              color: const Color(0xFF32CCBC).withOpacity(0.5)),
                        ),
                      ),
                      style: GoogleFonts.poppins(),
                      validator: (v) =>
                          v == null || v.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _cityController,
                      decoration: InputDecoration(
                        labelText: 'City',
                        labelStyle:
                            GoogleFonts.poppins(color: const Color(0xFF32CCBC)),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: Color(0xFF32CCBC)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                              color: Color(0xFF32CCBC), width: 2),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                              color: const Color(0xFF32CCBC).withOpacity(0.5)),
                        ),
                      ),
                      style: GoogleFonts.poppins(),
                      validator: (v) =>
                          v == null || v.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _stateController,
                      decoration: InputDecoration(
                        labelText: 'State',
                        labelStyle:
                            GoogleFonts.poppins(color: const Color(0xFF32CCBC)),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: Color(0xFF32CCBC)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                              color: Color(0xFF32CCBC), width: 2),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                              color: const Color(0xFF32CCBC).withOpacity(0.5)),
                        ),
                      ),
                      style: GoogleFonts.poppins(),
                      validator: (v) =>
                          v == null || v.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _pincodeController,
                      decoration: InputDecoration(
                        labelText: 'Pincode',
                        labelStyle:
                            GoogleFonts.poppins(color: const Color(0xFF32CCBC)),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: Color(0xFF32CCBC)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                              color: Color(0xFF32CCBC), width: 2),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                              color: const Color(0xFF32CCBC).withOpacity(0.5)),
                        ),
                      ),
                      style: GoogleFonts.poppins(),
                      keyboardType: TextInputType.number,
                      validator: (v) =>
                          v == null || v.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Text('Blood Group: '),
                        const SizedBox(width: 8),
                        DropdownButton<String>(
                          value: _selectedBloodGroup,
                          items: _bloodGroups
                              .map((bg) =>
                                  DropdownMenuItem(value: bg, child: Text(bg)))
                              .toList(),
                          onChanged: (v) {
                            if (v != null)
                              setState(() => _selectedBloodGroup = v);
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _heightController,
                            decoration: InputDecoration(
                              labelText: 'Height (cm)',
                              labelStyle: GoogleFonts.poppins(
                                  color: const Color(0xFF32CCBC)),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide:
                                    const BorderSide(color: Color(0xFF32CCBC)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                    color: Color(0xFF32CCBC), width: 2),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                    color: const Color(0xFF32CCBC)
                                        .withOpacity(0.5)),
                              ),
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _weightController,
                            decoration: InputDecoration(
                              labelText: 'Weight (kg)',
                              labelStyle: GoogleFonts.poppins(
                                  color: const Color(0xFF32CCBC)),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide:
                                    const BorderSide(color: Color(0xFF32CCBC)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                    color: Color(0xFF32CCBC), width: 2),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                    color: const Color(0xFF32CCBC)
                                        .withOpacity(0.5)),
                              ),
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Allergies
                    const Text('Known Allergies:'),
                    Wrap(
                      spacing: 8,
                      children: _knownAllergies
                          .map((a) => Chip(
                                label: Text(a),
                                onDeleted: () => _removeAllergy(a),
                              ))
                          .toList(),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _allergiesController,
                            decoration: InputDecoration(
                              labelText: 'Add Allergy',
                              labelStyle: GoogleFonts.poppins(
                                  color: const Color(0xFF32CCBC)),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide:
                                    const BorderSide(color: Color(0xFF32CCBC)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                    color: Color(0xFF32CCBC), width: 2),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                    color: const Color(0xFF32CCBC)
                                        .withOpacity(0.5)),
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add),
                          onPressed: _addAllergy,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Chronic Conditions
                    const Text('Chronic Conditions:'),
                    Wrap(
                      spacing: 8,
                      children: _chronicConditions
                          .map((c) => Chip(
                                label: Text(c),
                                onDeleted: () => _removeChronicCondition(c),
                              ))
                          .toList(),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _chronicConditionsController,
                            decoration: InputDecoration(
                              labelText: 'Add Condition',
                              labelStyle: GoogleFonts.poppins(
                                  color: const Color(0xFF32CCBC)),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide:
                                    const BorderSide(color: Color(0xFF32CCBC)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                    color: Color(0xFF32CCBC), width: 2),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                    color: const Color(0xFF32CCBC)
                                        .withOpacity(0.5)),
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add),
                          onPressed: _addChronicCondition,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Emergency Contact
                    const Text('Emergency Contact:'),
                    TextFormField(
                      controller: _emergencyContactNameController,
                      decoration: InputDecoration(
                        labelText: 'Name',
                        labelStyle:
                            GoogleFonts.poppins(color: const Color(0xFF32CCBC)),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: Color(0xFF32CCBC)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                              color: Color(0xFF32CCBC), width: 2),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                              color: const Color(0xFF32CCBC).withOpacity(0.5)),
                        ),
                      ),
                      style: GoogleFonts.poppins(),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _emergencyContactNumberController,
                      decoration: InputDecoration(
                        labelText: 'Number',
                        labelStyle:
                            GoogleFonts.poppins(color: const Color(0xFF32CCBC)),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: Color(0xFF32CCBC)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                              color: Color(0xFF32CCBC), width: 2),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                              color: const Color(0xFF32CCBC).withOpacity(0.5)),
                        ),
                      ),
                      style: GoogleFonts.poppins(),
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Text('Relation: '),
                        const SizedBox(width: 8),
                        DropdownButton<String>(
                          value: _selectedEmergencyRelation,
                          items: _emergencyRelations
                              .map((r) =>
                                  DropdownMenuItem(value: r, child: Text(r)))
                              .toList(),
                          onChanged: (v) {
                            if (v != null)
                              setState(() => _selectedEmergencyRelation = v);
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Health Insurance Section
                    const SizedBox(height: 16),
                    Text(
                      'Health Insurance:',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF32CCBC), // Patient teal
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Health Insurance Provider
                    TextFormField(
                      controller: _healthInsuranceController,
                      decoration: InputDecoration(
                        labelText: 'Health Insurance Provider',
                        labelStyle:
                            GoogleFonts.poppins(color: const Color(0xFF32CCBC)),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: Color(0xFF32CCBC)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                              color: Color(0xFF32CCBC), width: 2),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                              color: const Color(0xFF32CCBC).withOpacity(0.5)),
                        ),
                      ),
                      style: GoogleFonts.poppins(),
                    ),
                    const SizedBox(height: 8),

                    // Policy Number
                    TextFormField(
                      controller: _policyNumberController,
                      decoration: InputDecoration(
                        labelText: 'Policy Number',
                        labelStyle:
                            GoogleFonts.poppins(color: const Color(0xFF32CCBC)),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: Color(0xFF32CCBC)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                              color: Color(0xFF32CCBC), width: 2),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                              color: const Color(0xFF32CCBC).withOpacity(0.5)),
                        ),
                      ),
                      style: GoogleFonts.poppins(),
                    ),
                    const SizedBox(height: 8),

                    // Policy Expiry Date
                    Row(
                      children: [
                        Text(
                          'Policy Expiry Date: ',
                          style: GoogleFonts.poppins(),
                        ),
                        TextButton(
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate:
                                  DateTime.now().add(const Duration(days: 365)),
                              firstDate: DateTime.now(),
                              lastDate: DateTime.now()
                                  .add(const Duration(days: 3650)),
                            );
                            if (picked != null) {
                              setState(() {
                                _policyExpiryDate = picked;
                              });
                            }
                          },
                          child: Text(
                            _policyExpiryDate != null
                                ? '${_policyExpiryDate!.day}/${_policyExpiryDate!.month}/${_policyExpiryDate!.year}'
                                : 'Select Expiry Date',
                            style: GoogleFonts.poppins(
                              color: const Color(0xFF32CCBC), // Patient teal
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Health Insurance Certificate Upload
                    const SizedBox(height: 16),
                    Text(
                      'Insurance Certificate',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF32CCBC), // Patient teal
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Upload your health insurance card or certificate (JPG, PNG, PDF, DOC)',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Insurance Card File Upload
                    GestureDetector(
                      onTap: _pickInsuranceCardImage,
                      child: Container(
                        height: 120,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: _insuranceCardImage != null
                            ? _buildFilePreview(_insuranceCardImage!)
                            : _insuranceCardImageUrl != null &&
                                    _insuranceCardImageUrl!.isNotEmpty
                                ? _buildUrlFilePreview(_insuranceCardImageUrl!)
                                : Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.upload_file,
                                          color: Colors.grey[400]),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Upload Insurance Document',
                                        style: TextStyle(
                                            color: Colors.grey[600],
                                            fontSize: 12),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'JPG, PNG, PDF, DOC',
                                        style: TextStyle(
                                            color: Colors.grey[500],
                                            fontSize: 10),
                                      ),
                                    ],
                                  ),
                      ),
                    ),

                    // Pregnancy and Baby Info Section
                    if (gender == 'Female') ...[
                      const SizedBox(height: 16),
                      Text(
                        'Pregnancy & Health Tracking:',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF32CCBC), // Patient teal
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Privacy Notice
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue[200]!),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.privacy_tip,
                                    color: Colors.blue[700], size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  'Privacy Notice',
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue[700],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Baby health tracking is managed separately after birth under pediatric care. No newborn personal data is collected here.',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: Colors.blue[700],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),

                      if (DateTime.now().year - dob.year >= 12 &&
                          DateTime.now().year - dob.year <= 50) ...[
                        // Privacy Consent Checkbox
                        Row(
                          children: [
                            Checkbox(
                              value: _pregnancyPrivacyConsent,
                              onChanged: (v) => setState(() {
                                _pregnancyPrivacyConsent = v ?? false;
                                // When consent is checked, allow both current pregnancy and history fields
                                if (_pregnancyPrivacyConsent) {
                                  _isPregnant = _isPregnant; // keep as is
                                }
                              }),
                              activeColor:
                                  const Color(0xFF32CCBC), // Patient teal
                            ),
                            Expanded(
                              child: Text(
                                'I consent to share pregnancy-related health information',
                                style: GoogleFonts.poppins(fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // Current Pregnancy Status
                        Row(
                          children: [
                            Checkbox(
                              value: _isPregnant,
                              onChanged: _pregnancyPrivacyConsent
                                  ? (v) async {
                                      setState(() => _isPregnant = v ?? false);

                                      // Auto-save pregnancy status when checkbox is clicked
                                      if (v == true) {
                                        // Save pregnancy status immediately without popup
                                        try {
                                          // Save pregnancy status immediately
                                          final pregnancyUpdates = {
                                            'isPregnant': true,
                                            'pregnancyTrackingEnabled': true,
                                            'pregnancyPrivacyConsent':
                                                _pregnancyPrivacyConsent,
                                          };

                                          final success = await ApiService
                                              .updateUserProfile(
                                                  widget.user.uid,
                                                  pregnancyUpdates);

                                          if (!success) {
                                            await _showGradientPopup(
                                              success: false,
                                              message:
                                                  'Failed to save pregnancy status. Please try again.',
                                            );
                                          }
                                        } catch (e) {
                                          await _showGradientPopup(
                                            success: false,
                                            message:
                                                'Error saving pregnancy status: $e',
                                          );
                                        }
                                      }
                                    }
                                  : null, // Disable if consent not given
                              activeColor:
                                  const Color(0xFF32CCBC), // Patient teal
                            ),
                            Text(
                              'Currently Pregnant',
                              style: GoogleFonts.poppins(
                                color: _pregnancyPrivacyConsent
                                    ? Colors.black
                                    : Colors.grey,
                              ),
                            ),
                            if (!_pregnancyPrivacyConsent) ...[
                              const SizedBox(width: 8),
                              Icon(
                                Icons.info_outline,
                                color: Colors.orange,
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '(Consent required)',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: Colors.orange,
                                ),
                              ),
                            ],
                          ],
                        ),

                        if (_isPregnant && _pregnancyPrivacyConsent) ...[
                          // Current Pregnancy Fields
                          const SizedBox(height: 12),
                          Text(
                            'Current Pregnancy Details:',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),

                          // Baby Reference (not actual name)
                          TextFormField(
                            controller: _babyNameController,
                            decoration: InputDecoration(
                              labelText: 'Baby Reference/Nickname (optional)',
                              hintText: 'e.g., Baby A, Little One',
                              labelStyle: GoogleFonts.poppins(
                                  color: const Color(0xFF32CCBC)),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide:
                                    const BorderSide(color: Color(0xFF32CCBC)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                    color: Color(0xFF32CCBC), width: 2),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                    color: const Color(0xFF32CCBC)
                                        .withOpacity(0.5)),
                              ),
                            ),
                            style: GoogleFonts.poppins(),
                            onChanged: (value) async {
                              // Auto-save baby name when entered (silent save)
                              if (value.isNotEmpty && _isPregnant) {
                                try {
                                  final pregnancyUpdates = {
                                    'isPregnant': true,
                                    'pregnancyTrackingEnabled': true,
                                    'babyName': value.trim(),
                                    'dueDate': _dueDate?.toIso8601String(),
                                    'pregnancyPrivacyConsent':
                                        _pregnancyPrivacyConsent,
                                  };

                                  final success =
                                      await ApiService.updateUserProfile(
                                          widget.user.uid, pregnancyUpdates);

                                  if (!success) {
                                    await _showGradientPopup(
                                      success: false,
                                      message: 'Failed to save baby reference.',
                                    );
                                  }
                                } catch (e) {
                                  // Silent error handling for auto-save
                                  print('Error auto-saving baby name: $e');
                                }
                              }
                            },
                          ),
                          const SizedBox(height: 8),

                          // Pregnancy Start Date
                          Row(
                            children: [
                              Text(
                                'Pregnancy Start Date (LMP): ',
                                style: GoogleFonts.poppins(),
                              ),
                              TextButton(
                                onPressed: () async {
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate: _pregnancyStartDate ??
                                        DateTime.now().subtract(
                                            const Duration(days: 280)),
                                    firstDate: DateTime.now()
                                        .subtract(const Duration(days: 365)),
                                    lastDate: DateTime.now(),
                                  );
                                  if (picked != null) {
                                    setState(() {
                                      _pregnancyStartDate = picked;
                                      // Auto-calculate due date (280 days from LMP)
                                      _dueDate =
                                          picked.add(const Duration(days: 280));
                                    });

                                    // Auto-save pregnancy start date and due date when selected (silent save)
                                    try {
                                      final pregnancyUpdates = {
                                        'isPregnant': true,
                                        'pregnancyTrackingEnabled': true,
                                        'pregnancyStartDate':
                                            picked.toIso8601String(),
                                        'dueDate': _dueDate!.toIso8601String(),
                                        'babyName':
                                            _babyNameController.text.trim(),
                                        'pregnancyPrivacyConsent':
                                            _pregnancyPrivacyConsent,
                                      };

                                      final success =
                                          await ApiService.updateUserProfile(
                                              widget.user.uid,
                                              pregnancyUpdates);

                                      if (!success) {
                                        await _showGradientPopup(
                                          success: false,
                                          message:
                                              'Failed to save pregnancy start date. Please try again.',
                                        );
                                      }
                                    } catch (e) {
                                      await _showGradientPopup(
                                        success: false,
                                        message:
                                            'Error saving pregnancy start date: $e',
                                      );
                                    }
                                  }
                                },
                                child: Text(
                                  _pregnancyStartDate != null
                                      ? DateFormat('MMM dd, yyyy')
                                          .format(_pregnancyStartDate!)
                                      : 'Select Start Date',
                                  style: GoogleFonts.poppins(
                                    color:
                                        const Color(0xFF32CCBC), // Patient teal
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),

                          // Due Date (Auto-calculated)
                          Row(
                            children: [
                              Text(
                                'Expected Due Date: ',
                                style: GoogleFonts.poppins(),
                              ),
                              Text(
                                _dueDate != null
                                    ? DateFormat('MMM dd, yyyy')
                                        .format(_dueDate!)
                                    : 'Set start date first',
                                style: GoogleFonts.poppins(
                                  color: _dueDate != null
                                      ? const Color(0xFF32CCBC)
                                      : Colors.grey,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),

                          // Baby Weight at Birth - Only show if due date has passed
                          if (_dueDate != null &&
                              _dueDate!.isBefore(DateTime.now())) ...[
                            TextFormField(
                              controller: _babyWeightController,
                              decoration: InputDecoration(
                                labelText: 'Baby Weight at Birth (kg)',
                                hintText: 'e.g., 3.2',
                                labelStyle: GoogleFonts.poppins(
                                    color: const Color(0xFF32CCBC)),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                      color: Color(0xFF32CCBC)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                      color: Color(0xFF32CCBC), width: 2),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                      color: const Color(0xFF32CCBC)
                                          .withOpacity(0.5)),
                                ),
                              ),
                              style: GoogleFonts.poppins(),
                              keyboardType: TextInputType.numberWithOptions(
                                  decimal: true),
                              onChanged: (value) async {
                                // Auto-save baby weight when entered (silent save)
                                if (value.isNotEmpty && _isPregnant) {
                                  try {
                                    final pregnancyUpdates = {
                                      'isPregnant': true,
                                      'pregnancyTrackingEnabled': true,
                                      'babyWeightAtBirth':
                                          double.tryParse(value.trim()),
                                      'babyName':
                                          _babyNameController.text.trim(),
                                      'dueDate': _dueDate?.toIso8601String(),
                                      'pregnancyPrivacyConsent':
                                          _pregnancyPrivacyConsent,
                                    };

                                    final success =
                                        await ApiService.updateUserProfile(
                                            widget.user.uid, pregnancyUpdates);

                                    if (!success) {
                                      await _showGradientPopup(
                                        success: false,
                                        message: 'Failed to save baby weight.',
                                      );
                                    }
                                  } catch (e) {
                                    // Silent error handling for auto-save
                                    print('Error auto-saving baby weight: $e');
                                  }
                                }
                              },
                            ),
                          ] else if (_dueDate != null &&
                              _dueDate!.isAfter(DateTime.now())) ...[
                            // Show message that baby is still in womb
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.blue.shade200),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.info_outline,
                                      color: Colors.blue.shade600, size: 20),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Baby weight will be available after birth (Due: ${DateFormat('MMM dd, yyyy').format(_dueDate!)})',
                                      style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        color: Colors.blue.shade700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 8),
                        ],

                        if (_isPregnant && !_pregnancyPrivacyConsent) ...[
                          // Show message when pregnancy is selected but consent not given
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: Colors.orange.withOpacity(0.3)),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  color: Colors.orange,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Please provide consent to share pregnancy-related health information to access pregnancy details.',
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      color: Colors.orange[700],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        if (!_isPregnant) ...[
                          // Previous Pregnancy History
                          const SizedBox(height: 12),
                          Text(
                            'Previous Pregnancy History (Optional):',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),

                          // Number of Previous Pregnancies
                          TextFormField(
                            controller: _numberOfPreviousPregnanciesController,
                            decoration: InputDecoration(
                              labelText: 'Number of Previous Pregnancies',
                              labelStyle: GoogleFonts.poppins(
                                  color: const Color(0xFF32CCBC)),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide:
                                    const BorderSide(color: Color(0xFF32CCBC)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                    color: Color(0xFF32CCBC), width: 2),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                    color: const Color(0xFF32CCBC)
                                        .withOpacity(0.5)),
                              ),
                            ),
                            style: GoogleFonts.poppins(),
                            keyboardType: TextInputType.number,
                          ),
                          const SizedBox(height: 8),

                          // Last Pregnancy Year
                          TextFormField(
                            controller: _lastPregnancyYearController,
                            decoration: InputDecoration(
                              labelText: 'Last Pregnancy Year (optional)',
                              labelStyle: GoogleFonts.poppins(
                                  color: const Color(0xFF32CCBC)),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide:
                                    const BorderSide(color: Color(0xFF32CCBC)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                    color: Color(0xFF32CCBC), width: 2),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                    color: const Color(0xFF32CCBC)
                                        .withOpacity(0.5)),
                              ),
                            ),
                            style: GoogleFonts.poppins(),
                            keyboardType: TextInputType.number,
                          ),
                          const SizedBox(height: 8),

                          // Health Notes
                          TextFormField(
                            controller: _pregnancyHealthNotesController,
                            decoration: InputDecoration(
                              labelText: 'Health Notes (complications, etc.)',
                              labelStyle: GoogleFonts.poppins(
                                  color: const Color(0xFF32CCBC)),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide:
                                    const BorderSide(color: Color(0xFF32CCBC)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                    color: Color(0xFF32CCBC), width: 2),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                    color: const Color(0xFF32CCBC)
                                        .withOpacity(0.5)),
                              ),
                            ),
                            style: GoogleFonts.poppins(),
                            maxLines: 3,
                          ),
                        ],
                      ],
                    ],

                    const SizedBox(height: 24),
                    // Save button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _saveProfile,
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
                                Color(0xFF32CCBC),
                                Color(0xFF90F7EC)
                              ], // Patient teal gradient
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
                                    'Save',
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
