import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:arcular_plus/models/user_model.dart';
import 'package:arcular_plus/utils/health_qr_generator.dart';
import 'package:arcular_plus/services/auth_service.dart';
import 'package:arcular_plus/services/registration_service.dart';
import 'package:arcular_plus/screens/user/dashboard_user.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';

class PatientRegistrationScreen extends StatefulWidget {
  final String? signupEmail;
  final String? signupPhone;
  final String? signupPassword;
  final String? signupCountryCode;
  const PatientRegistrationScreen({
    super.key,
    this.signupEmail,
    this.signupPhone,
    this.signupPassword,
    this.signupCountryCode,
  });

  @override
  State<PatientRegistrationScreen> createState() =>
      _PatientRegistrationScreenState();
}

class _PatientRegistrationScreenState extends State<PatientRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _authService = AuthService();
  // Form State
  bool _isLoading = false;
  bool _isGoogleSignup = false;

  // Common fields
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _mobileController = TextEditingController();
  final _alternateMobileController = TextEditingController();
  final _addressController = TextEditingController();
  final _pincodeController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _aadhaarController = TextEditingController();
  String _countryCode = '+91';

  // Password fields (only for non-Google signup)
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _verifyPasswordController =
      TextEditingController();
  List<String> _cityOptions = [];
  List<String> _stateOptions = [
    'State1',
    'State2',
    'State3'
  ]; // Replace with real states
  bool _hideEmailField = false;
  bool _hidePhoneField = false;

  // Patient-specific fields
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  final _emergencyContactNameController = TextEditingController();
  final _emergencyContactNumberController = TextEditingController();
  final _healthInsuranceController = TextEditingController();
  final _allergiesController = TextEditingController();
  final _chronicConditionsController = TextEditingController();

  // Dropdown values
  String _selectedGender = 'Male';
  String _selectedBloodGroup = 'A+';
  String _selectedEmergencyRelation = 'Spouse';
  DateTime? _selectedDateOfBirth;
  bool _isPregnant = false;

  // Lists for multiple selections
  List<String> _knownAllergies = [];
  List<String> _chronicConditions = [];

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
    if (widget.signupEmail != null && widget.signupEmail!.isNotEmpty) {
      _emailController.text = widget.signupEmail!;
      _hideEmailField = true;
    }
    if (widget.signupPhone != null && widget.signupPhone!.isNotEmpty) {
      _mobileController.text = widget.signupPhone!;
      _hidePhoneField = true;
    }

    // Check if this is a Google user (no password provided)
    if (widget.signupPassword == null || widget.signupPassword!.isEmpty) {
      _isGoogleSignup = true; // Mark as Google user
    }

    // Removed auto-fill from pincode to avoid loading mock data
  }

  void _handlePincodeChange() async {
    // Disabled: do not auto-fill or fetch mock data from pincode.
  }

  Future<void> _fetchCityStateFromGoogle() async {
    final pin = _pincodeController.text.trim();
    if (pin.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid 6-digit PIN code')),
      );
      return;
    }
    try {
      setState(() => _isLoading = true);
      const country = 'IN';
      const apiKeyEnvVar = 'GOOGLE_MAPS_API_KEY';
      // Read from env via dart-define if present; else use provided fallback key
      final String apiKey =
          const String.fromEnvironment(apiKeyEnvVar, defaultValue: '')
                  .isNotEmpty
              ? const String.fromEnvironment(apiKeyEnvVar)
              : 'AIzaSyCsf05KoRB9yQ1SQVO9UStgGBafjLK1gvU';

      // Prefer postal_code component with country bias; add region hint
      final uri = Uri.parse(
          'https://maps.googleapis.com/maps/api/geocode/json?components=postal_code:$pin|country:$country&region=in&key=$apiKey');
      final res = await http.get(uri);
      if (res.statusCode != 200) {
        print('Geocode HTTP error: ${res.statusCode} ${res.body}');
        throw Exception('Geocode failed');
      }
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final status = (body['status'] as String?) ?? '';
      if (status.isNotEmpty && status != 'OK') {
        print(
            'Geocode status: $status, error_message: ${body['error_message']}');
      }
      final results = (body['results'] as List?) ?? [];
      if (results.isEmpty) {
        print('Geocode zero results for PIN: $pin');
        throw Exception('No results');
      }
      final comps = (results.first['address_components'] as List).cast<Map>();
      String? city;
      String? state;
      for (final c in comps) {
        final types = (c['types'] as List).cast<String>();
        if (types.contains('locality') ||
            types.contains('postal_town') ||
            types.contains('administrative_area_level_2') ||
            types.contains('sublocality') ||
            types.contains('sublocality_level_1')) {
          city ??= c['long_name'] as String?;
        }
        if (types.contains('administrative_area_level_1')) {
          state ??= c['long_name'] as String?;
        }
      }
      if (mounted) {
        setState(() {
          if (city != null) _cityController.text = city!;
          if (state != null) _stateController.text = state!;
        });
      }
    } catch (e) {
      // Keep UI message simple; details are printed for logs/backlog
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Could not fetch address. Please enter city and state manually.')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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
    _aadhaarController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _emergencyContactNameController.dispose();
    _emergencyContactNumberController.dispose();
    _healthInsuranceController.dispose();
    _allergiesController.dispose();
    _chronicConditionsController.dispose();
    super.dispose();
  }

  Future<void> _selectDateOfBirth() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate:
          DateTime.now().subtract(const Duration(days: 6570)), // 18 years ago
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

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDateOfBirth == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select your date of birth')),
      );
      return;
    }

    // Only validate passwords if not a Google user (Google users don't need passwords)
    if (widget.signupPassword != null && widget.signupPassword!.isNotEmpty) {
      if (_passwordController.text != _verifyPasswordController.text) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Passwords do not match')),
        );
        return;
      }
    }

    setState(() => _isLoading = true);
    try {
      // 1. Create Firebase Auth user if not already signed in
      User? firebaseUser = FirebaseAuth.instance.currentUser;
      String? passwordToUse = widget.signupPassword ?? _passwordController.text;

      if (firebaseUser == null) {
        if (widget.signupEmail != null && widget.signupEmail!.isNotEmpty) {
          // For Google users, we don't need to create a password-based account
          // since they're already authenticated via Google
          if (passwordToUse.isEmpty) {
            // This is a Google user - they're already authenticated
            // We can proceed with backend registration
          } else {
            // This is a regular user - create password-based account
            firebaseUser =
                (await FirebaseAuth.instance.createUserWithEmailAndPassword(
              email: widget.signupEmail!,
              password: passwordToUse,
            ))
                    .user;
          }
        } else if (widget.signupPhone != null &&
            widget.signupPhone!.isNotEmpty) {
          // TODO: Implement phone/OTP signup here if needed
          // For now, skip
        }
      }

      // For Google users, firebaseUser might still be null, but that's okay
      // We'll use the current user or proceed with backend registration
      if (firebaseUser == null) {
        firebaseUser = FirebaseAuth.instance.currentUser;
      }

      if (firebaseUser == null) throw Exception('User creation failed');

      // 2. Get Firebase ID token
      final idToken = await firebaseUser.getIdToken();

      // 3. Call backend to sync user (always use Firebase UID)
      final genderToSend =
          _selectedGender.isNotEmpty ? _selectedGender : 'Other';

      // Prepare user data for registration service
      final userData = {
        "uid": firebaseUser.uid, // Always send Firebase UID
        "type": "patient",
        "fullName": _fullNameController.text.trim(),
        "email": _emailController.text.trim(),
        "mobileNumber": _mobileController.text.trim(),
        "alternateMobile": _alternateMobileController.text.trim(),
        "gender": genderToSend,
        "dateOfBirth": _selectedDateOfBirth?.toIso8601String() ?? '',
        "address": _addressController.text.trim(),
        "pincode": _pincodeController.text.trim(),
        "city": _cityController.text.trim(),
        "state": _stateController.text.trim(),
        "aadhaarNumber": _aadhaarController.text.trim(),
        "bloodGroup": _selectedBloodGroup,
        "height": double.tryParse(_heightController.text.trim()),
        "weight": double.tryParse(_weightController.text.trim()),
        "knownAllergies": _knownAllergies,
        "chronicConditions": _chronicConditions,
        "isPregnant": _isPregnant,
        "emergencyContactName": _emergencyContactNameController.text.trim(),
        "emergencyContactNumber": _emergencyContactNumberController.text.trim(),
        "emergencyContactRelation": _selectedEmergencyRelation,
        "healthInsuranceId": _healthInsuranceController.text.trim(),
      };

      // Use the new registration service
      final result = await RegistrationService.registerUser(
        userType: 'patient',
        userData: userData,
        documents: [], // Patients don't need document uploads for basic registration
        documentTypes: [],
      );

      if (result['success']) {
        // Registration successful
        if (mounted) {
          // Store gender and type in SharedPreferences for loading image logic
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('user_gender', genderToSend);
          await prefs.setString('user_type', 'patient');
          await prefs.setString('user_status', 'pending');

          await _showCustomPopup(
              success: true,
              message: result['message'] ?? 'Registration successful!');
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => DashboardUser()),
          );
        }
      } else {
        setState(() => _isLoading = false);
        await _showCustomPopup(
            success: false,
            message: result['message'] ?? 'Registration failed');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] ?? 'Registration failed')),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      await _showCustomPopup(
          success: false, message: 'Registration failed: ${e.toString()}');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Registration failed: ${e.toString()}')),
      );
    }
  }

  Future<void> _showCustomPopup(
      {required bool success, required String message}) async {
    final prefs = await SharedPreferences.getInstance();
    final gender = prefs.getString('user_gender') ?? 'Female';
    String imagePath;
    if (success) {
      imagePath = gender == 'Male'
          ? 'assets/images/Male/pat/love.png'
          : 'assets/images/Female/pat/love.png';
    } else {
      imagePath = gender == 'Male'
          ? 'assets/images/Male/pat/angry.png'
          : 'assets/images/Female/pat/angry.png';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Patient Registration',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF32CCBC), // Patient teal
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF32CCBC),
              Color(0xFF90F7EC),
              Color(0xFFE8F5E8)
            ], // Patient teal gradient
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
                          'Personal Information',
                          style: GoogleFonts.poppins(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Complete your health profile with accurate information',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: Colors.white.withOpacity(0.8),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Form Content
                        _buildBasicInformation(),
                        const SizedBox(height: 24),
                        _buildHealthInformation(),
                        const SizedBox(height: 24),
                        _buildEmergencyContact(),
                        const SizedBox(height: 32),

                        // Register Button
                        Container(
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
                            borderRadius: BorderRadius.circular(28),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF32CCBC).withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _register,
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
                                    'Complete Registration',
                                    style: GoogleFonts.poppins(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                          ),
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

  Widget _buildStepIndicator() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Row(
            children: [
              _buildStepCircle(1, true, 'Basic'),
              _buildStepLine(true),
              _buildStepCircle(2, false, 'Health'),
              _buildStepLine(false),
              _buildStepCircle(3, false, 'Emergency'),
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
                'Health Details',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.white.withOpacity(0.7),
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                'Emergency Contact',
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
        border: Border.all(
          color: Colors.white,
          width: 2,
        ),
      ),
      child: Center(
        child: Text(
          step.toString(),
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: isActive ? const Color(0xFF32CCBC) : Colors.white,
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

  Widget _buildBasicInformation() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Basic Information',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF32CCBC), // Patient teal
          ),
        ),
        const SizedBox(height: 16),

        // Full Name
        Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                Color(0xFF32CCBC),
                Color(0xFF90F7EC)
              ], // Patient teal gradient
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
              controller: _fullNameController,
              decoration: const InputDecoration(
                labelText: 'Full Name *',
                prefixIcon: Icon(Icons.person_outline,
                    color: Color(0xFF32CCBC)), // Patient teal
                border: InputBorder.none,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter your full name';
                }
                return null;
              },
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Email and Phone Row
        Row(
          children: [
            if (!_hideEmailField) ...[
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFF32CCBC),
                        Color(0xFF90F7EC)
                      ], // Patient teal gradient
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
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      readOnly:
                          _isGoogleSignup && _emailController.text.isNotEmpty,
                      decoration: const InputDecoration(
                        labelText: 'Email Address',
                        prefixIcon: Icon(Icons.email_outlined,
                            color: Color(0xFF32CCBC)), // Patient teal
                        border: InputBorder.none,
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      ),
                      validator: (value) {
                        if ((value == null || value.trim().isEmpty) &&
                            _mobileController.text.trim().isEmpty) {
                          return 'Please enter your email or phone';
                        }
                        if (value != null &&
                            value.isNotEmpty &&
                            !RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$')
                                .hasMatch(value)) {
                          return 'Please enter a valid email';
                        }
                        return null;
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
            ],
            if (!_hidePhoneField) ...[
              Expanded(
                child: _buildPhoneInput(),
              ),
            ],
          ],
        ),
        const SizedBox(height: 16),

        // Date of Birth and Gender Row
        Row(
          children: [
            Expanded(
              child: _buildDatePickerField(),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildDropdownField(
                value: _selectedGender,
                label: 'Gender *',
                icon: Icons.person_outline,
                items: _genderOptions,
                onChanged: (value) {
                  setState(() {
                    _selectedGender = value!;
                  });
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Address
        Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                Color(0xFF32CCBC),
                Color(0xFF90F7EC)
              ], // Patient teal gradient
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
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Address *',
                prefixIcon: Icon(Icons.location_on_outlined,
                    color: Color(0xFF32CCBC)), // Patient teal
                border: InputBorder.none,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter your address';
                }
                return null;
              },
            ),
          ),
        ),
        const SizedBox(height: 16),

        // City, State, Pincode Row
        Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF32CCBC),
                      Color(0xFF90F7EC)
                    ], // Patient teal gradient
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
                      prefixIcon: Icon(Icons.location_city_outlined,
                          color: Color(0xFF32CCBC)), // Patient teal
                      border: InputBorder.none,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter your city';
                      }
                      return null;
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF32CCBC),
                      Color(0xFF90F7EC)
                    ], // Patient teal gradient
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
                      prefixIcon: Icon(Icons.map_outlined,
                          color: Color(0xFF32CCBC)), // Patient teal
                      border: InputBorder.none,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter your state';
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

        // Pincode and Aadhaar Row
        Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF32CCBC),
                      Color(0xFF90F7EC)
                    ], // Patient teal gradient
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
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Pincode *',
                      prefixIcon: const Icon(Icons.pin_drop_outlined,
                          color: Color(0xFF32CCBC)), // Patient teal
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 16),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.download_for_offline,
                            color: Color(0xFF32CCBC)),
                        tooltip: 'Fetch city/state from Google',
                        onPressed: _fetchCityStateFromGoogle,
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter your pincode';
                      }
                      if (value.length != 6) {
                        return 'Pincode must be 6 digits';
                      }
                      return null;
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF32CCBC),
                      Color(0xFF90F7EC)
                    ], // Patient teal gradient
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TextFormField(
                    controller: _aadhaarController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Aadhaar Number',
                      prefixIcon: Icon(Icons.credit_card_outlined,
                          color: Color(0xFF32CCBC)), // Patient teal
                      border: InputBorder.none,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildHealthInformation() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Health Information',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF32CCBC), // Patient teal
          ),
        ),
        const SizedBox(height: 16),

        // Blood Group and Height Row
        Row(
          children: [
            Expanded(
              child: _buildDropdownField(
                value: _selectedBloodGroup,
                label: 'Blood Group',
                icon: Icons.bloodtype_outlined,
                items: _bloodGroups,
                onChanged: (value) {
                  setState(() {
                    _selectedBloodGroup = value!;
                  });
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF32CCBC),
                      Color(0xFF90F7EC)
                    ], // Patient teal gradient
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
                    controller: _heightController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Height (cm)',
                      prefixIcon: Icon(Icons.height_outlined,
                          color: Color(0xFF32CCBC)), // Patient teal
                      border: InputBorder.none,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Weight and Health Insurance Row
        Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF32CCBC),
                      Color(0xFF90F7EC)
                    ], // Patient teal gradient
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
                    controller: _weightController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Weight (kg)',
                      prefixIcon: Icon(Icons.monitor_weight_outlined,
                          color: Color(0xFF32CCBC)), // Patient teal
                      border: InputBorder.none,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF32CCBC),
                      Color(0xFF90F7EC)
                    ], // Patient teal gradient
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
                    controller: _healthInsuranceController,
                    decoration: const InputDecoration(
                      labelText: 'Health Insurance',
                      prefixIcon: Icon(Icons.health_and_safety_outlined,
                          color: Color(0xFF32CCBC)), // Patient teal
                      border: InputBorder.none,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Allergies
        Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                Color(0xFF32CCBC),
                Color(0xFF90F7EC)
              ], // Patient teal gradient
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
              controller: _allergiesController,
              decoration: const InputDecoration(
                labelText: 'Known Allergies',
                prefixIcon: Icon(Icons.warning_outlined,
                    color: Color(0xFF32CCBC)), // Patient teal
                border: InputBorder.none,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              ),
              onFieldSubmitted: (_) => _addAllergy(),
            ),
          ),
        ),
        if (_knownAllergies.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: _knownAllergies
                .map((allergy) => Chip(
                      label: Text(allergy),
                      deleteIcon: const Icon(Icons.close, size: 16),
                      onDeleted: () => _removeAllergy(allergy),
                      backgroundColor: const Color(0xFF32CCBC).withOpacity(0.1),
                      deleteIconColor: const Color(0xFF32CCBC),
                    ))
                .toList(),
          ),
          const SizedBox(height: 16),
        ],

        // Chronic Conditions
        Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                Color(0xFF32CCBC),
                Color(0xFF90F7EC)
              ], // Patient teal gradient
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
              controller: _chronicConditionsController,
              decoration: const InputDecoration(
                labelText: 'Chronic Conditions',
                prefixIcon: Icon(Icons.medical_services_outlined,
                    color: Color(0xFF32CCBC)), // Patient teal
                border: InputBorder.none,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              ),
              onFieldSubmitted: (_) => _addChronicCondition(),
            ),
          ),
        ),
        if (_chronicConditions.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: _chronicConditions
                .map((condition) => Chip(
                      label: Text(condition),
                      deleteIcon: const Icon(Icons.close, size: 16),
                      onDeleted: () => _removeChronicCondition(condition),
                      backgroundColor: const Color(0xFF32CCBC).withOpacity(0.1),
                      deleteIconColor: const Color(0xFF32CCBC),
                    ))
                .toList(),
          ),
          const SizedBox(height: 16),
        ],

        // Pregnancy Checkbox (for females)
        if (_selectedGender == 'Female') ...[
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border:
                  Border.all(color: const Color(0xFF32CCBC).withOpacity(0.3)),
            ),
            child: CheckboxListTile(
              title: Text(
                'Are you pregnant?',
                style: GoogleFonts.poppins(fontSize: 14),
              ),
              value: _isPregnant,
              onChanged: (value) {
                setState(() {
                  _isPregnant = value ?? false;
                });
              },
              activeColor: const Color(0xFF32CCBC),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ],
    );
  }

  Widget _buildEmergencyContact() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Emergency Contact',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF32CCBC), // Patient teal
          ),
        ),
        const SizedBox(height: 16),

        // Emergency Contact Name and Number
        Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF32CCBC),
                      Color(0xFF90F7EC)
                    ], // Patient teal gradient
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
                    controller: _emergencyContactNameController,
                    decoration: const InputDecoration(
                      labelText: 'Emergency Contact Name',
                      prefixIcon: Icon(Icons.emergency_outlined,
                          color: Color(0xFF32CCBC)), // Patient teal
                      border: InputBorder.none,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF32CCBC),
                      Color(0xFF90F7EC)
                    ], // Patient teal gradient
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
                    controller: _emergencyContactNumberController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Emergency Contact Number',
                      prefixIcon: Icon(Icons.phone_outlined,
                          color: Color(0xFF32CCBC)), // Patient teal
                      border: InputBorder.none,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Relationship
        _buildDropdownField(
          value: _selectedEmergencyRelation,
          label: 'Relationship',
          icon: Icons.family_restroom_outlined,
          items: _emergencyRelations,
          onChanged: (value) {
            setState(() {
              _selectedEmergencyRelation = value!;
            });
          },
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2), // Slightly more opaque background
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            color: Colors.white,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white, // White text for better contrast
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMultiInputSection(
    String title,
    TextEditingController controller,
    List<String> items,
    VoidCallback onAdd,
    Function(String) onRemove,
    IconData icon,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white
                .withOpacity(0.2), // Slightly more opaque background
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.white.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    color: Colors.white, // White text for better contrast
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: controller,
                decoration: InputDecoration(
                  prefixIcon:
                      Icon(icon, color: const Color(0xFF32CCBC)), // Green teal
                  filled: true,
                  fillColor: Colors.white, // White background
                  border: OutlineInputBorder(
                    borderSide: const BorderSide(
                        color: Color(0xFF32CCBC)), // Green teal
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderSide: const BorderSide(
                        color: Color(0xFF32CCBC)), // Green teal
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: const BorderSide(
                        color: Color(0xFF90F7EC), width: 2), // Light teal
                  ),
                  hintText: 'Enter ${title.toLowerCase()}',
                  hintStyle: GoogleFonts.poppins(color: Colors.grey[600]),
                ),
                style: GoogleFonts.poppins(
                    color: Colors.black87), // Dark text for visibility
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: onAdd,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF32CCBC), // Green teal
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                'Add',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        if (items.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: items.map((item) {
              return Chip(
                label: Text(
                  item,
                  style: GoogleFonts.poppins(color: Colors.white),
                ),
                backgroundColor: const Color(0xFF32CCBC), // Green teal
                deleteIcon:
                    const Icon(Icons.close, size: 18, color: Colors.white),
                onDeleted: () => onRemove(item),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildPhoneInput() {
    return Row(
      children: [
        SizedBox(
          width: 80, // Reduced width to prevent overflow
          child: Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF32CCBC),
                  Color(0xFF90F7EC)
                ], // Patient teal gradient
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
                value: _countryCode,
                decoration: const InputDecoration(
                  labelText: 'Code',
                  prefixIcon: Icon(Icons.phone,
                      color: Color(0xFF32CCBC)), // Patient teal
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 16), // Reduced horizontal padding
                ),
                items: ['+91', '+1', '+44', '+61', '+971', '+81', '+86']
                    .map((code) => DropdownMenuItem(
                          value: code,
                          child: Text(
                            code,
                            style: GoogleFonts.poppins(
                              color: Colors.black87,
                              fontSize: 12, // Smaller font size
                            ),
                          ),
                        ))
                    .toList(),
                onChanged: _isGoogleSignup
                    ? null
                    : (val) {
                        setState(() {
                          _countryCode = val!;
                        });
                      },
                icon: const Icon(Icons.arrow_drop_down,
                    color: Color(0xFF32CCBC)), // Smaller dropdown icon
                isExpanded: true, // Prevent expansion
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF32CCBC),
                  Color(0xFF90F7EC)
                ], // Patient teal gradient
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
                controller: _mobileController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Mobile Number',
                  prefixIcon: Icon(Icons.phone,
                      color: Color(0xFF32CCBC)), // Patient teal
                  border: InputBorder.none,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                ),
                validator: (value) {
                  if ((value == null || value.trim().isEmpty) &&
                      _emailController.text.trim().isEmpty) {
                    return 'Please enter your email or phone';
                  }
                  if (value != null && value.isNotEmpty && value.length < 10) {
                    return 'Please enter a valid mobile number';
                  }
                  return null;
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDatePickerField() {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF32CCBC),
            Color(0xFF90F7EC)
          ], // Patient teal gradient
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
          child: InputDecorator(
            decoration: const InputDecoration(
              labelText: 'Date of Birth *',
              prefixIcon: Icon(Icons.calendar_today,
                  color: Color(0xFF32CCBC)), // Patient teal
              border: InputBorder.none,
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
            child: Text(
              _selectedDateOfBirth != null
                  ? DateFormat('dd/MM/yyyy').format(_selectedDateOfBirth!)
                  : 'Select Date',
              style: GoogleFonts.poppins(
                color: _selectedDateOfBirth != null
                    ? Colors.black87
                    : Colors.grey[600],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDropdownField({
    required String value,
    required String label,
    required IconData icon,
    required List<String> items,
    String? Function(String?)? validator,
    void Function(String?)? onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF32CCBC),
            Color(0xFF90F7EC)
          ], // Patient teal gradient
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
            labelText: label,
            prefixIcon:
                Icon(icon, color: const Color(0xFF32CCBC)), // Patient teal
            border: InputBorder.none,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
          style: GoogleFonts.poppins(
              color: Colors.black87), // Dark text for visibility
          items: items.map((item) {
            return DropdownMenuItem(
              value: item,
              child: Text(item,
                  style:
                      GoogleFonts.poppins(color: Colors.black87)), // Dark text
            );
          }).toList(),
          onChanged: onChanged,
          validator: validator,
        ),
      ),
    );
  }
}
