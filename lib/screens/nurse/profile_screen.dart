import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:arcular_plus/models/user_model.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:arcular_plus/screens/scanner_screen.dart';
import 'package:arcular_plus/services/api_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../auth/login_screen.dart';
import 'package:arcular_plus/services/auth_service.dart';
import 'update_nurse_profile_screen.dart';
import 'package:google_fonts/google_fonts.dart';

// Nurse-specific color constants
const Color kNurseBackground = Color(0xFFF8F4FF);
const Color kNursePrimary = Color(0xFF9C27B0);
const Color kNurseSecondary = Color(0xFFBA68C8);
const Color kNurseText = Color(0xFF4A148C);
const Color kNurseTextSecondary = Color(0xFF6A1B9A);

class NurseProfileScreen extends StatefulWidget {
  final UserModel user;
  const NurseProfileScreen({super.key, required this.user});

  @override
  State<NurseProfileScreen> createState() => _NurseProfileScreenState();
}

class _NurseProfileScreenState extends State<NurseProfileScreen> {
  late UserModel _user;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _user = widget.user;
  }

  Future<void> _refreshProfile() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      print('👩‍⚕️ Loading nurse profile data for UID: ${user.uid}');

      // Use universal getUserInfo method which respects user type
      final userModel = await ApiService.getUserInfo(user.uid);

      if (userModel != null) {
        print(
            '✅ Nurse profile data loaded successfully: ${userModel.fullName}');
        setState(() {
          _user = userModel;
        });
      } else {
        print('❌ Nurse profile data not found');
      }
    } catch (e) {
      print('❌ Error loading nurse profile data: $e');
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
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UpdateNurseProfileScreen(nurse: _user),
      ),
    );
  }

  Future<void> _generateAndShareQR() async {
    try {
      final qrData = {
        'uid': _user.uid,
        'name': _user.fullName,
        'role': 'nurse',
        'email': _user.email,
        'mobile': _user.mobileNumber,
      };

      final qrString = jsonEncode(qrData);
      final qrImage = await _generateQRImage(qrString);
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/nurse_qr.png');
      await file.writeAsBytes(qrImage);
      await Share.shareXFiles([XFile(file.path)], text: 'My Nurse QR Code');
    } catch (e) {
      print('Error sharing QR code: $e');
    }
  }

  Future<Uint8List> _generateQRImage(String data) async {
    final qrPainter = QrPainter(
      data: data,
      version: QrVersions.auto,
      color: kNursePrimary,
      emptyColor: Colors.white,
    );

    final qrImage = await qrPainter.toImageData(2048);
    return qrImage!.buffer.asUint8List();
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [kNursePrimary, kNurseSecondary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: kNursePrimary.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.logout,
                    size: 48,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Logout',
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Are you sure you want to logout?',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 45,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            'Cancel',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        height: 45,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: () async {
                            Navigator.pop(context);
                            await AuthService().signOut();
                            if (mounted) {
                              Navigator.pushAndRemoveUntil(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => const LoginScreen()),
                                (route) => false,
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            foregroundColor: kNursePrimary,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            'Logout',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: kNursePrimary,
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kNurseBackground,
      appBar: AppBar(
        title: Text(
          'Nurse Profile',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [kNursePrimary, kNurseSecondary],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.white),
            onPressed: _showUpdateDialog,
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: _showLogoutDialog,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshProfile,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Profile Header Card
              _buildProfileHeaderCard(),
              const SizedBox(height: 24),

              // Quick Actions
              _buildQuickActionsCard(),
              const SizedBox(height: 24),

              // Personal Information
              _buildPersonalInfoCard(),
              const SizedBox(height: 24),

              // Professional Information
              _buildProfessionalInfoCard(),
              const SizedBox(height: 24),

              // QR Code Section
              _buildQRCodeCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileHeaderCard() {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [kNursePrimary, kNurseSecondary],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Profile Image Section
            Stack(
              children: [
                CircleAvatar(
                  radius: 60,
                  backgroundColor: Colors.white.withOpacity(0.2),
                  backgroundImage: (_user.profileImageUrl != null &&
                          (_user.profileImageUrl ?? '').isNotEmpty)
                      ? NetworkImage(_user.profileImageUrl!)
                      : null,
                  child: (_user.profileImageUrl == null ||
                          (_user.profileImageUrl ?? '').isEmpty)
                      ? Icon(
                          Icons.person,
                          color: Colors.white,
                          size: 60,
                        )
                      : null,
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: IconButton(
                      icon: Icon(Icons.camera_alt, color: kNursePrimary),
                      onPressed: _pickAndUploadProfileImage,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Name and Role
            Text(
              _user.fullName,
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Registered Nurse',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionsCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Quick Actions',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: kNurseText,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildActionButton(
                    icon: Icons.edit,
                    label: 'Edit Profile',
                    onTap: _showUpdateDialog,
                    color: kNursePrimary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildActionButton(
                    icon: Icons.qr_code,
                    label: 'Share QR',
                    onTap: _generateAndShareQR,
                    color: kNurseSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required Color color,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              label,
              style: GoogleFonts.poppins(
                color: color,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPersonalInfoCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Personal Information',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: kNurseText,
              ),
            ),
            const SizedBox(height: 16),
            _buildInfoRow('Email', _user.email, Icons.email),
            _buildInfoRow('Mobile', _user.mobileNumber, Icons.phone),
            _buildInfoRow('Gender', _user.gender, Icons.person),
            _buildInfoRow('Date of Birth',
                _user.dateOfBirth.toIso8601String().split('T')[0], Icons.cake),
            if (_user.alternateMobile != null &&
                _user.alternateMobile!.isNotEmpty)
              _buildInfoRow('Alternate Mobile', _user.alternateMobile!,
                  Icons.phone_android),
          ],
        ),
      ),
    );
  }

  Widget _buildProfessionalInfoCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Professional Information',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: kNurseText,
              ),
            ),
            const SizedBox(height: 16),
            if (_user.licenseNumber != null && _user.licenseNumber!.isNotEmpty)
              _buildInfoRow(
                  'Nursing License', _user.licenseNumber!, Icons.verified_user),
            if (_user.specialization != null &&
                _user.specialization!.isNotEmpty)
              _buildInfoRow('Specialization', _user.specialization!,
                  Icons.medical_services),
            if (_user.experienceYears != null && _user.experienceYears! > 0)
              _buildInfoRow(
                  'Experience', '${_user.experienceYears} years', Icons.work),
            if (_user.qualification != null && _user.qualification!.isNotEmpty)
              _buildInfoRow(
                  'Qualification', _user.qualification!, Icons.school),
          ],
        ),
      ),
    );
  }

  Widget _buildQRCodeCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Nurse QR Code',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: kNurseText,
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: QrImageView(
                  data: jsonEncode({
                    'uid': _user.uid,
                    'name': _user.fullName,
                    'role': 'nurse',
                    'email': _user.email,
                    'mobile': _user.mobileNumber,
                  }),
                  version: QrVersions.auto,
                  size: 200,
                  backgroundColor: Colors.white,
                  foregroundColor: kNursePrimary,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: ElevatedButton.icon(
                onPressed: _generateAndShareQR,
                icon: const Icon(Icons.share),
                label: Text(
                  'Share QR Code',
                  style: GoogleFonts.poppins(fontSize: 16),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kNursePrimary,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: kNursePrimary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: kNursePrimary, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    color: kNurseTextSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  value,
                  style: GoogleFonts.poppins(
                    color: kNurseText,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
