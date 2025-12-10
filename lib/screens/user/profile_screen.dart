import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:arcular_plus/models/user_model.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path_provider_android/path_provider_android.dart';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

import 'package:arcular_plus/screens/user/qr_scanner_screen.dart'; // Added import for QRScannerScreen

import 'package:arcular_plus/services/api_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../auth/login_screen.dart'; // Added import for LoginScreen
import 'package:arcular_plus/services/auth_service.dart'; // Added import for AuthService

import 'package:arcular_plus/screens/auth/signup_user.dart'; // For update form
import 'update_profile_screen.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

// Add color constants at the top
const Color kBackground = Color(0xFFF9FAFB);
const Color kPrimaryText = Color(0xFF2E2E2E);
const Color kSecondaryText = Color(0xFF6B7280);
const Color kBorder = Color(0xFFE5E7EB);
const Color kSuccess = Color(0xFFA3E635);
const Color kUserBlue = Color(0xFF0057A0);

class UserProfileScreen extends StatefulWidget {
  final UserModel user;
  const UserProfileScreen({super.key, required this.user});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  late UserModel _user;
  final ImagePicker _picker = ImagePicker();
  String? _profileImageUrl;

  @override
  void initState() {
    super.initState();
    _user = widget.user;
    _profileImageUrl = _user.profileImageUrl;
    _loadHealthSummary();
  }

  Future<void> _refreshProfile() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      print('👤 Loading user profile data for UID: ${user.uid}');

      // Use universal getUserInfo method which respects user type
      final userModel = await ApiService.getUserInfo(user.uid);

      if (userModel != null) {
        print('✅ User profile data loaded successfully: ${userModel.fullName}');
        setState(() {
          _user = userModel;
        });
      } else {
        print('❌ User profile data not found');
      }
    } catch (e) {
      print('❌ Error loading user profile data: $e');
    }
  }

  Future<void> _loadHealthSummary() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final healthSummary = await ApiService.getUserHealthSummary(user.uid);
      if (healthSummary.isNotEmpty) {
        // Update profile with health summary data
        setState(() {
          // Update relevant fields if they exist in health summary
          if (healthSummary['bloodGroup'] != null) {
            _user = _user.copyWith(bloodGroup: healthSummary['bloodGroup']);
          }
          if (healthSummary['height'] != null) {
            _user = _user.copyWith(height: healthSummary['height']);
          }
          if (healthSummary['weight'] != null) {
            _user = _user.copyWith(weight: healthSummary['weight']);
          }
        });
      }
    } catch (e) {
      print('❌ Error loading health summary: $e');
    }
  }

  Future<void> _pickAndUploadProfileImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile == null) return;
    final file = File(pickedFile.path);
    final uid = _user.uid;
    final storageRef =
        FirebaseStorage.instance.ref().child('profile_images/$uid.jpg');
    await storageRef.putFile(file);
    final url = await storageRef.getDownloadURL();
    // Save to backend
    final success =
        await ApiService.updateUserProfile(uid, {'profileImageUrl': url});
    if (success) {
      // Save to SharedPreferences for instant display
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('profile_image_url', url);
      await _refreshProfile();
    }
  }

  void _showUpdateDialog() {
    final formKey = GlobalKey<FormState>();
    final fullNameController = TextEditingController(text: _user.fullName);
    final emailController = TextEditingController(text: _user.email);
    final mobileController = TextEditingController(text: _user.mobileNumber);
    final genderController = TextEditingController(text: _user.gender);
    final dobController = TextEditingController(
        text: _user.dateOfBirth.toIso8601String().split('T')[0]);
    final addressController = TextEditingController(text: _user.address);
    final pincodeController = TextEditingController(text: _user.pincode);
    final cityController = TextEditingController(text: _user.city);
    final stateController = TextEditingController(text: _user.state);
    final bloodGroupController =
        TextEditingController(text: _user.bloodGroup ?? '');
    final emergencyNameController =
        TextEditingController(text: _user.emergencyContactName ?? '');
    final emergencyNumberController =
        TextEditingController(text: _user.emergencyContactNumber ?? '');
    final emergencyRelationController =
        TextEditingController(text: _user.emergencyContactRelation ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Update Profile'),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                    controller: fullNameController,
                    decoration: const InputDecoration(labelText: 'Full Name'),
                    validator: (v) => v!.isEmpty ? 'Required' : null),
                TextFormField(
                    controller: emailController,
                    decoration: const InputDecoration(labelText: 'Email'),
                    validator: (v) => v!.isEmpty ? 'Required' : null),
                TextFormField(
                    controller: mobileController,
                    decoration:
                        const InputDecoration(labelText: 'Mobile Number')),
                TextFormField(
                    controller: genderController,
                    decoration: const InputDecoration(labelText: 'Gender')),
                TextFormField(
                    controller: dobController,
                    decoration: const InputDecoration(
                        labelText: 'Date of Birth (YYYY-MM-DD)')),
                TextFormField(
                    controller: addressController,
                    decoration: const InputDecoration(labelText: 'Address')),
                TextFormField(
                    controller: pincodeController,
                    decoration: const InputDecoration(labelText: 'Pincode')),
                TextFormField(
                    controller: cityController,
                    decoration: const InputDecoration(labelText: 'City')),
                TextFormField(
                    controller: stateController,
                    decoration: const InputDecoration(labelText: 'State')),
                TextFormField(
                    controller: bloodGroupController,
                    decoration:
                        const InputDecoration(labelText: 'Blood Group')),
                TextFormField(
                    controller: emergencyNameController,
                    decoration: const InputDecoration(
                        labelText: 'Emergency Contact Name')),
                TextFormField(
                    controller: emergencyNumberController,
                    decoration: const InputDecoration(
                        labelText: 'Emergency Contact Number')),
                TextFormField(
                    controller: emergencyRelationController,
                    decoration: const InputDecoration(
                        labelText: 'Emergency Contact Relation')),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              final updates = {
                'fullName': fullNameController.text,
                'email': emailController.text,
                'mobileNumber': mobileController.text,
                'gender': genderController.text,
                'dateOfBirth': dobController.text,
                'address': addressController.text,
                'pincode': pincodeController.text,
                'city': cityController.text,
                'state': stateController.text,
                'bloodGroup': bloodGroupController.text,
                'emergencyContactName': emergencyNameController.text,
                'emergencyContactNumber': emergencyNumberController.text,
                'emergencyContactRelation': emergencyRelationController.text,
              };
              final success =
                  await ApiService.updateUserProfile(_user.uid, updates);
              if (success) {
                Navigator.pop(context);
                await _refreshProfile();
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Profile updated!')));
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Failed to update profile.')));
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final qrKey = GlobalKey();
    final idCardKey = GlobalKey();

    // Generate QR code data with all profile and health information
    final qrData = _user.getQrCodeData();
    final qrDataString = jsonEncode(qrData);

    Future<void> _shareQr() async {
      if (kIsWeb) {
        await Share.share(
            'My Arcular+ Health QR ID: ${_user.healthQrId ?? _user.uid}');
        return;
      }
      try {
       // Render ID card in an overlay to ensure it lays out with a real size
        final overlay = Overlay.of(context);
        if (overlay == null) {
          throw Exception('Overlay not available');
        }

        final captureKey = GlobalKey();
        late OverlayEntry entry;
        entry = OverlayEntry(
          builder: (context) {
            final screenWidth = MediaQuery.of(context).size.width;
            final dobStr = '${_user.dateOfBirth.day}/${_user.dateOfBirth.month}/${_user.dateOfBirth.year}';
            return Material(
              type: MaterialType.transparency,
              child: Center(
                child: RepaintBoundary(
                  key: captureKey,
                  child: _buildShareIdCard(
                    context: context,
                    name: _user.fullName,
                    email: _user.email,
                    phone: _user.mobileNumber,
                    arcId: _user.healthQrId ?? _user.arcId ?? _user.uid,
                    dob: dobStr,
                    bloodGroup: _user.bloodGroup,
                    profileImageUrl: _profileImageUrl,
                    qrDataString: qrDataString,
                    maxWidth: screenWidth - 24,
                  ),
                ),
              ),
            );
          },
        );

        overlay.insert(entry);
        // wait for frames to ensure layout and image paints are done
        await Future.delayed(const Duration(milliseconds: 120));
        await WidgetsBinding.instance.endOfFrame;

        final boundary = captureKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
        final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
        final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
        final pngBytes = byteData!.buffer.asUint8List();

        // remove overlay ASAP
        entry.remove();

        final tempDir = await getTemporaryDirectory();
        final file = await File('${tempDir.path}/arcular_plus_id_card.png').create();
        await file.writeAsBytes(pngBytes);
        await Share.shareXFiles([XFile(file.path)], text: 'My Arcular+ ID Card');
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to share: $e')));
      }
    }




    // Try to get from SharedPreferences for instant display
    SharedPreferences.getInstance().then((prefs) {
      final cachedUrl = prefs.getString('profile_image_url');
      if (cachedUrl != null && cachedUrl != _profileImageUrl) {
        if (mounted) {
          setState(() {
            _profileImageUrl = cachedUrl;
          });
        }
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'My Health Profile',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
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
        actions: [
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.white),
            tooltip: 'Edit Profile',
            onPressed: () async {
              final updated = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => UpdateProfileScreen(user: _user),
                ),
              );
              if (updated == true) {
                await _refreshProfile();
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Profile Header (no upload)
            Stack(
              children: [
                CircleAvatar(
                  radius: 50,
                  backgroundColor: const Color(0xFF32CCBC), // Patient teal
                  backgroundImage: (_profileImageUrl?.isNotEmpty ?? false)
                      ? NetworkImage(_profileImageUrl!)
                      : null,
                  child: (_profileImageUrl?.isEmpty ?? true)
                      ? Text(
                          _user.fullName.isNotEmpty
                              ? _user.fullName[0].toUpperCase()
                              : '?',
                          style: GoogleFonts.poppins(
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        )
                      : null,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              _user.fullName,
              style: GoogleFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: kPrimaryText,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _user.email,
              style: GoogleFonts.poppins(
                fontSize: 16,
                color: kSecondaryText,
              ),
            ),
            const SizedBox(height: 8),
            // ARC ID
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF32CCBC),
                    Color(0xFF90F7EC)
                  ], // Patient teal gradient
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'ARC ID: ${_user.healthQrId ?? _user.arcId ?? 'ARC-XXXX-XXXX-XXXX'}',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${_user.type.toUpperCase()} • Age: ${_user.age} years',
              style: GoogleFonts.poppins(
                fontSize: 16,
                color: const Color(0xFF32CCBC), // Patient teal
              ),
            ),
            const SizedBox(height: 24),

            // Health QR Code Card (remove ARC ID from here)
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    // Offstage composed ID card for sharing
                    Offstage(
                      offstage: true,
                      child: RepaintBoundary(
                        key: idCardKey,
                        child: _buildShareIdCard(
                          context: context,
                          name: _user.fullName,
                          email: _user.email,
                          phone: _user.mobileNumber,
                          arcId: _user.healthQrId ?? _user.arcId ?? _user.uid,
                          dob: '${_user.dateOfBirth.day}/${_user.dateOfBirth.month}/${_user.dateOfBirth.year}',
                          bloodGroup: _user.bloodGroup,
                          profileImageUrl: _profileImageUrl,
                          qrDataString: qrDataString,
                        ),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.qr_code, color: kUserBlue, size: 24),
                        const SizedBox(width: 8),
                        const Text('Health QR Code',
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: kPrimaryText)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: kBorder),
                      ),
                      child: RepaintBoundary(
                        key: qrKey,
                        child: QrImageView(
                          data: qrDataString,
                          version: QrVersions.auto,
                          size: 200.0,
                          backgroundColor: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Scan this QR code to access complete health information',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: kSecondaryText),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
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
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF32CCBC).withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.share, color: Colors.white),
                            label: Text(
                              'Share',
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            onPressed: _shareQr,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Container(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xFFFF6B35),
                                Color(0xFFFF8E53)
                              ], // Orange gradient
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFFF6B35).withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.qr_code_scanner, color: Colors.white),
                            label: Text(
                              'Scan QR',
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const QRScannerScreen()),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),

                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),


            // Personal Information Card
            _buildInfoCard(
              'Personal Information',
              [
                _buildInfoRow('Full Name', _user.fullName, kPrimaryText),
                _buildInfoRow('Gender', _user.gender, kSecondaryText),
                _buildInfoRow(
                    'Date of Birth',
                    '${_user.dateOfBirth.day}/${_user.dateOfBirth.month}/${_user.dateOfBirth.year}',
                    kSecondaryText),
                _buildInfoRow('Age', '${_user.age} years', kSecondaryText),
                _buildInfoRow('Mobile', _user.mobileNumber, kPrimaryText),
                if (_user.alternateMobile != null)
                  _buildInfoRow('Alternate Mobile', _user.alternateMobile!,
                      kSecondaryText),
                _buildInfoRow(
                    'Address',
                    '${_user.address}, ${_user.city}, ${_user.state} - ${_user.pincode}',
                    kSecondaryText),
              ],
            ),
            const SizedBox(height: 16),

            // Health Information Card (for patients)
            if (_user.type == 'patient') ...[
              _buildInfoCard(
                'Health Information',
                [
                  if (_user.bloodGroup != null)
                    _buildInfoRow(
                        'Blood Group', _user.bloodGroup!, kPrimaryText),
                  if (_user.height != null)
                    _buildInfoRow(
                        'Height', '${_user.height} cm', kSecondaryText),
                  if (_user.weight != null)
                    _buildInfoRow(
                        'Weight', '${_user.weight} kg', kSecondaryText),
                  if (_user.bmi != null)
                    _buildInfoRow(
                        'BMI',
                        '${_user.bmi!.toStringAsFixed(1)} (${_user.bmiCategory})',
                        kSecondaryText),
                  if (_user.isPregnant == true)
                    _buildInfoRow('Pregnancy Status', 'Currently Pregnant',
                        kSecondaryText),
                  if (_user.numberOfPreviousPregnancies != null &&
                      _user.numberOfPreviousPregnancies! > 0)
                    _buildInfoRow(
                        'Previous Pregnancies',
                        '${_user.numberOfPreviousPregnancies} pregnancy(ies)',
                        kSecondaryText),
                  if (_user.lastPregnancyYear != null)
                    _buildInfoRow('Last Pregnancy Year',
                        _user.lastPregnancyYear.toString(), kSecondaryText),
                  if (_user.pregnancyHealthNotes != null &&
                      _user.pregnancyHealthNotes!.isNotEmpty)
                    _buildInfoRow('Pregnancy Health Notes',
                        _user.pregnancyHealthNotes!, kSecondaryText),
                  if (_user.healthInsuranceId != null &&
                      _user.healthInsuranceId!.isNotEmpty)
                    _buildInfoRow('Health Insurance ID',
                        _user.healthInsuranceId!, kSecondaryText),
                  if (_user.policyNumber != null &&
                      _user.policyNumber!.isNotEmpty)
                    _buildInfoRow(
                        'Policy Number', _user.policyNumber!, kSecondaryText),
                  if (_user.policyExpiryDate != null)
                    _buildInfoRow(
                        'Policy Expiry',
                        '${_user.policyExpiryDate!.day}/${_user.policyExpiryDate!.month}/${_user.policyExpiryDate!.year}',
                        kSecondaryText),
                  if (_user.insuranceCardImageUrl != null &&
                      _user.insuranceCardImageUrl!.isNotEmpty) ...[
                    _buildInfoRow('Insurance Certificate', 'Certificate Available', kSecondaryText),
                    const SizedBox(height: 12),
                    _buildInsuranceViewButton(),
                  ],
                  if (_user.knownAllergies != null &&
                      _user.knownAllergies!.isNotEmpty)
                    _buildInfoRow('Known Allergies',
                        _user.knownAllergies!.join(', '), kSecondaryText),
                  if (_user.chronicConditions != null &&
                      _user.chronicConditions!.isNotEmpty)
                    _buildInfoRow('Chronic Conditions',
                        _user.chronicConditions!.join(', '), kSecondaryText),
                ],
              ),
              const SizedBox(height: 16),

              // Aadhaar Card Section
              if (_user.aadhaarFrontImageUrl != null &&
                  _user.aadhaarFrontImageUrl!.isNotEmpty) ...[
                _buildInfoCard(
                  'Aadhaar Card',
                  [
                    _buildInfoRow('Aadhaar Number',
                        _user.aadhaarNumber ?? 'Not provided', kPrimaryText),
                    const SizedBox(height: 16),
                    // Display Aadhaar front image
                    Container(
                      width: double.infinity,
                      height: 200,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: kBorder),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          _user.aadhaarFrontImageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: Colors.grey[200],
                              child: const Center(
                                child: Icon(
                                  Icons.image_not_supported,
                                  size: 48,
                                  color: Colors.grey,
                                ),
                              ),
                            );
                          },
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Container(
                              color: Colors.grey[200],
                              child: const Center(
                                child: CircularProgressIndicator(),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
            ],

            // Emergency Contact Card (for patients)
            if (_user.type == 'patient' &&
                _user.emergencyContactName != null) ...[
              _buildInfoCard(
                'Emergency Contact',
                [
                  _buildInfoRow(
                      'Name', _user.emergencyContactName!, kPrimaryText),
                  _buildInfoRow(
                      'Number', _user.emergencyContactNumber!, kSecondaryText),
                  _buildInfoRow('Relation', _user.emergencyContactRelation!,
                      kSecondaryText),
                ],
              ),
              const SizedBox(height: 16),
            ],

            // Professional Information (for doctors, hospitals, labs, pharmacies)
            if (_user.type != 'patient') ...[
              _buildInfoCard(
                'Professional Information',
                _getProfessionalInfo(),
              ),
              const SizedBox(height: 16),
            ],

            // QR Code Information
            _buildInfoCard(
              'QR Code Information',
              [
                _buildInfoRow('User ID', _user.uid, kPrimaryText),
                _buildInfoRow(
                    'Account Type', _user.type.toUpperCase(), kSecondaryText),
                _buildInfoRow(
                    'Created',
                    '${_user.createdAt.day}/${_user.createdAt.month}/${_user.createdAt.year}',
                    kSecondaryText),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(String title, List<Widget> children) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF32CCBC), // Patient teal
              ),
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, Color? textColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w500,
                color: kSecondaryText,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w400,
                color: textColor ?? kPrimaryText,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClickableInfoRow(String label, String value, Color? textColor, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w500,
                color: kSecondaryText,
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: onTap,
              child: Text(
                value,
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w400,
                  color: textColor ?? kPrimaryText,
                  decoration: TextDecoration.underline,
                  decorationColor: textColor ?? kPrimaryText,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInsuranceViewButton() {
    return Container(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () => _openInsuranceCertificate(),
        icon: const Icon(Icons.open_in_new, size: 18, color: Colors.white),
        label: Text(
          'View Certificate',
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: kUserBlue,
          foregroundColor: Colors.white,
          elevation: 2,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  void _openInsuranceCertificate() async {
    try {
      if (_user.insuranceCardImageUrl == null || _user.insuranceCardImageUrl!.isEmpty) {
        throw Exception('Insurance certificate URL is empty');
      }
      
      final url = Uri.parse(_user.insuranceCardImageUrl!);
      
      // Check if URL is valid
      if (!url.hasScheme || !url.hasAuthority) {
        throw Exception('Invalid insurance certificate URL');
      }
      
      // Try to open the file directly like the reports screen
      final canExternal = await canLaunchUrl(url);
      
      if (canExternal) {
        final launched = await launchUrl(url, mode: LaunchMode.externalApplication);
        if (!launched) {
          // Fallback to in-app webview
          final fallback = await launchUrl(url, mode: LaunchMode.inAppBrowserView);
          if (!fallback) throw Exception('No app available to open this file');
        }
      } else {
        // Directly try in-app webview
        final fallback = await launchUrl(url, mode: LaunchMode.inAppBrowserView);
        if (!fallback) throw Exception('No app available to open this file');
      }
      
      print('✅ Insurance certificate opened successfully');
    } catch (e) {
      print('❌ Error opening insurance certificate: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cannot open certificate: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }







  List<Widget> _getProfessionalInfo() {
    switch (_user.type) {
      case 'doctor':
        return [
          if (_user.medicalRegistrationNumber != null)
            _buildInfoRow('Medical Reg. No.', _user.medicalRegistrationNumber!,
                kPrimaryText),
          if (_user.specialization != null)
            _buildInfoRow(
                'Specialization', _user.specialization!, kSecondaryText),
          if (_user.experienceYears != null)
            _buildInfoRow(
                'Experience', '${_user.experienceYears} years', kSecondaryText),
          if (_user.consultationFee != null)
            _buildInfoRow('Consultation Fee', '₹${_user.consultationFee}',
                kSecondaryText),
        ];
      case 'hospital':
        return [
          if (_user.hospitalName != null)
            _buildInfoRow('Hospital Name', _user.hospitalName!, kPrimaryText),
          if (_user.registrationNumber != null)
            _buildInfoRow(
                'Registration No.', _user.registrationNumber!, kSecondaryText),
          if (_user.hospitalType != null)
            _buildInfoRow('Type', _user.hospitalType!, kSecondaryText),
          if (_user.numberOfBeds != null)
            _buildInfoRow('Number of Beds', _user.numberOfBeds.toString(),
                kSecondaryText),
        ];
      case 'lab':
        return [
          if (_user.labName != null)
            _buildInfoRow('Lab Name', _user.labName!, kPrimaryText),
          if (_user.labLicenseNumber != null)
            _buildInfoRow(
                'License No.', _user.labLicenseNumber!, kSecondaryText),
          if (_user.homeSampleCollection == true)
            _buildInfoRow('Home Collection', 'Available', kSecondaryText),
        ];
      case 'pharmacy':
        return [
          if (_user.pharmacyName != null)
            _buildInfoRow('Pharmacy Name', _user.pharmacyName!, kPrimaryText),
          if (_user.pharmacyLicenseNumber != null)
            _buildInfoRow(
                'License No.', _user.pharmacyLicenseNumber!, kSecondaryText),
          if (_user.homeDelivery == true)
            _buildInfoRow('Home Delivery', 'Available', kSecondaryText),
        ];
      default:
        return [];
    }
  }

  Widget _buildShareIdCard({
    required BuildContext context,
    required String name,
    required String email,
    required String phone,
    required String arcId,
    required String dob,
    String? bloodGroup,
    String? profileImageUrl,
    required String qrDataString,
    double? maxWidth,
  }) {
    // Responsive size to avoid clipping on small screens
    final double targetWidth = (maxWidth != null && maxWidth > 0) ? maxWidth : 1080;
    final double width = targetWidth.clamp(600, 1080);
    final double height = width * 0.56; // aspect ratio ~ 1080x600
    final double leftPanelWidth = width * 0.16; // left panel for profile image
    final double qrBoxSize = width * 0.22; // wider QR box for better scanning
    final double avatarRadius = width * 0.065; // avatar size
    final double nameFont = width * 0.036; // slightly smaller to fit full name in one line
    final double lineFont = width * 0.024; // slightly smaller

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF32CCBC), Color(0xFF22D3EE)],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: EdgeInsets.all(width * 0.02),
        child: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: EdgeInsets.all(width * 0.025),
            child: Column(
              children: [
                // Top row: Profile image and name
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Profile image in top-left
                    Container(
                      width: leftPanelWidth,
                      height: leftPanelWidth,
                      decoration: BoxDecoration(
                        color: const Color(0xFF32CCBC).withOpacity(0.08),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Center(
                        child: CircleAvatar(
                          radius: avatarRadius,
                          backgroundColor: const Color(0xFF32CCBC),
                          backgroundImage: (profileImageUrl != null && profileImageUrl.isNotEmpty)
                              ? NetworkImage(profileImageUrl)
                              : null,
                          child: (profileImageUrl == null || profileImageUrl.isEmpty)
                              ? Icon(Icons.person, size: avatarRadius, color: Colors.white)
                              : null,
                        ),
                      ),
                    ),
                    SizedBox(width: width * 0.025),
                    // Name and basic info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: TextStyle(
                              fontSize: nameFont,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF111827),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: width * 0.01),
                          Row(
                            children: [
                              Icon(Icons.badge, size: lineFont + 2, color: const Color(0xFF6B7280)),
                              SizedBox(width: width * 0.008),
                              Flexible(
                                child: Text(
                                  'ARC ID: $arcId',
                                  style: TextStyle(
                                    fontSize: lineFont,
                                    color: Color(0xFF374151),
                                    fontWeight: FontWeight.w600,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: width * 0.02),
                // Middle row: Details and QR code
                Row(
                  children: [
                    // Left side: Details
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.event, size: lineFont, color: const Color(0xFF6B7280)),
                              SizedBox(width: width * 0.008),
                              Flexible(
                                child: Text(
                                  'DOB: $dob',
                                  style: TextStyle(fontSize: lineFont, color: const Color(0xFF374151), fontWeight: FontWeight.w600),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: width * 0.008),
                          Row(
                            children: [
                              Icon(Icons.phone, size: lineFont, color: const Color(0xFF6B7280)),
                              SizedBox(width: width * 0.008),
                              Flexible(
                                child: Text(
                                  phone,
                                  style: TextStyle(fontSize: lineFont, color: const Color(0xFF374151)),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: width * 0.008),
                          Row(
                            children: [
                              Icon(Icons.email, size: lineFont, color: const Color(0xFF6B7280)),
                              SizedBox(width: width * 0.008),
                              Flexible(
                                child: Text(
                                  email,
                                  style: TextStyle(fontSize: lineFont * 1.2, color: const Color(0xFF374151), fontWeight: FontWeight.w500),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 2,
                                ),
                              ),
                            ],
                          ),
                          if (bloodGroup != null) ...[
                            SizedBox(height: width * 0.01),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF32CCBC).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                'Blood Group: $bloodGroup',
                                style: TextStyle(
                                  fontSize: lineFont * 0.8,
                                  color: Color(0xFF065F46),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    SizedBox(width: width * 0.025),
                    // Right side: QR code
                    Container(
                      width: qrBoxSize,
                      height: qrBoxSize,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x11000000),
                            blurRadius: 10,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Center(
                        child: QrImageView(
                          data: qrDataString,
                          version: QrVersions.auto,
                          size: qrBoxSize - 40,
                          backgroundColor: Colors.white,
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
    );
  }
}
