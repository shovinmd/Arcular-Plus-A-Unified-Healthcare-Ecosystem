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
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/api_service.dart';
import '../universal_qr_scanner_screen.dart';
import 'doctor_update_profile_screen.dart';

// Add color constants at the top
const Color kBackground = Color(0xFFF9FAFB);
const Color kPrimaryText = Color(0xFF2E2E2E);
const Color kSecondaryText = Color(0xFF6B7280);
const Color kBorder = Color(0xFFE5E7EB);
const Color kSuccess = Color(0xFFA3E635);
const Color kDoctorBlue = Color(0xFF1976D2);

class DoctorProfileScreen extends StatefulWidget {
  final UserModel doctor;
  const DoctorProfileScreen({super.key, required this.doctor});

  @override
  State<DoctorProfileScreen> createState() => _DoctorProfileScreenState();
}

class _DoctorProfileScreenState extends State<DoctorProfileScreen> {
  late UserModel _doctor;
  String? _profileImageUrl;

  @override
  void initState() {
    super.initState();
    _doctor = widget.doctor;
    _profileImageUrl = _doctor.profileImageUrl;
    _loadProfileImage();
  }

  Future<void> _loadProfileImage() async {
    final prefs = await SharedPreferences.getInstance();
    final imageUrl = prefs.getString('doctor_profile_image_url');
    if (imageUrl != null && mounted) {
      setState(() {
        _profileImageUrl = imageUrl;
      });
    }
  }

  Future<void> _refreshProfile() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      print('👨‍⚕️ Loading doctor profile data for UID: ${user.uid}');

      // Use universal getUserInfo method which respects user type
      final doctorModel = await ApiService.getUserInfo(user.uid);

      if (doctorModel != null) {
        print(
            '✅ Doctor profile data loaded successfully: ${doctorModel.fullName}');
        setState(() {
          _doctor = doctorModel;
          _profileImageUrl = doctorModel.profileImageUrl;
        });
      } else {
        print('❌ Doctor profile data not found');
      }
    } catch (e) {
      print('❌ Error loading doctor profile data: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final qrKey = GlobalKey();

    // Generate QR code data with all doctor information
    final qrData = _doctor.getQrCodeData();
    final qrDataString = jsonEncode(qrData);

    Future<void> _shareQr() async {
      if (kIsWeb) {
        await Share.share(
            'My Arcular+ Doctor QR ID: ${_doctor.healthQrId ?? _doctor.uid}');
        return;
      }
      try {
        // Render ID card in an overlay to ensure it lays out with a real size
        final overlay = Overlay.of(context);

        final captureKey = GlobalKey();
        late OverlayEntry entry;
        entry = OverlayEntry(
          builder: (context) {
            final screenWidth = MediaQuery.of(context).size.width;
            return Material(
              type: MaterialType.transparency,
              child: Center(
                child: RepaintBoundary(
                  key: captureKey,
                  child: _buildShareIdCard(
                    context: context,
                    name: _doctor.fullName ?? 'Doctor Name',
                    email: _doctor.email ?? '',
                    phone: _doctor.mobileNumber ?? '',
                    altPhone: _doctor.altPhoneNumber ?? '',
                    address: _doctor.address ?? '',
                    city: _doctor.city ?? '',
                    state: _doctor.state ?? '',
                    pincode: _doctor.pincode ?? '',
                    arcId: _doctor.healthQrId ?? _doctor.arcId ?? _doctor.uid,
                    specialization:
                        _doctor.specialization ?? 'General Medicine',
                    registrationNumber:
                        _doctor.medicalRegistrationNumber ?? 'N/A',
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

        // Wait for the widget to be laid out (reduced delay for faster response)
        await Future.delayed(const Duration(milliseconds: 200));

        // Capture the image
        final RenderRepaintBoundary boundary = captureKey.currentContext!
            .findRenderObject() as RenderRepaintBoundary;
        final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
        final ByteData? byteData =
            await image.toByteData(format: ui.ImageByteFormat.png);
        final Uint8List pngBytes = byteData!.buffer.asUint8List();

        // Remove the overlay
        entry.remove();

        // Save to temporary file and share
        final tempDir = await getTemporaryDirectory();
        final file = await File('${tempDir.path}/doctor_qr_id.png').create();
        await file.writeAsBytes(pngBytes);

        await Share.shareXFiles([XFile(file.path)],
            text: 'My Arcular+ Doctor QR ID');
      } catch (e) {
        print('Error sharing QR: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sharing QR: $e')),
        );
      }
    }

    return WillPopScope(
      onWillPop: () async {
        // Always allow going back to dashboard
        Navigator.of(context).pop();
        return false; // Don't use default back behavior
      },
      child: Scaffold(
        backgroundColor: kBackground,
        appBar: AppBar(
          title: Text(
            'Doctor Profile',
            style: GoogleFonts.poppins(
                color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
          ),
          backgroundColor: Colors.transparent,
          iconTheme: const IconThemeData(color: Colors.white),
          elevation: 0,
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [kDoctorBlue, Color(0xFF0D47A1)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.white),
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        DoctorUpdateProfileScreen(doctor: _doctor),
                  ),
                );
                if (result == true) {
                  await _refreshProfile();
                }
              },
              tooltip: 'Edit Profile',
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Profile Header (centered like user profile)
              CircleAvatar(
                radius: 50,
                backgroundColor: kDoctorBlue,
                backgroundImage: (_profileImageUrl?.isNotEmpty ?? false)
                    ? NetworkImage(_profileImageUrl!)
                    : null,
                child: (_profileImageUrl?.isEmpty ?? true)
                    ? Text(
                        (_doctor.fullName?.isNotEmpty ?? false)
                            ? _doctor.fullName![0].toUpperCase()
                            : '?',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
              ),
              const SizedBox(height: 16),

              // Name
              Text(
                _doctor.fullName ?? 'Doctor Name',
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: kPrimaryText,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              // ARC ID badge with doctor blue gradient
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2196F3), Color(0xFF64B5F6)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF2196F3).withOpacity(0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.badge, size: 16, color: Colors.white),
                    const SizedBox(width: 6),
                    Text(
                      'ARC ID: ' +
                          (_doctor.healthQrId ?? _doctor.arcId ?? _doctor.uid),
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              if ((_doctor.email ?? '').isNotEmpty)
                Text(
                  _doctor.email!,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: kSecondaryText,
                  ),
                  textAlign: TextAlign.center,
                ),
              const SizedBox(height: 4),
              // Specialization subtitle
              Text(
                (_doctor.specializations != null &&
                        _doctor.specializations!.isNotEmpty)
                    ? _doctor.specializations!.join(', ')
                    : (_doctor.specialization ?? 'General Medicine'),
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: kSecondaryText,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              // QR Code Section
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Text(
                      'Doctor QR Code',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: kPrimaryText,
                      ),
                    ),
                    const SizedBox(height: 16),
                    RepaintBoundary(
                      key: qrKey,
                      child: QrImageView(
                        data: qrDataString,
                        version: QrVersions.auto,
                        size: 200.0,
                        backgroundColor: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    UniversalQRScannerScreen(),
                              ),
                            );
                          },
                          icon: const Icon(Icons.qr_code_scanner,
                              color: Colors.white),
                          label: Text(
                            'Scan QR',
                            style: GoogleFonts.poppins(color: Colors.white),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kDoctorBlue,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: _shareQr,
                          icon: const Icon(Icons.share, color: Colors.white),
                          label: Text(
                            'Share QR',
                            style: GoogleFonts.poppins(color: Colors.white),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kSuccess,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Basic Information Card
              _buildInfoCard(
                'Basic Information',
                [
                  _buildInfoRow('Full Name', _doctor.fullName ?? 'N/A'),
                  _buildInfoRow('Gender', _doctor.gender ?? 'N/A'),
                  _buildInfoRow(
                      'Date of Birth',
                      _doctor.dateOfBirth != null
                          ? _doctor.dateOfBirth!
                              .toLocal()
                              .toString()
                              .split(' ')[0]
                          : 'N/A'),
                ],
              ),
              const SizedBox(height: 16),

              // Contact Information Card
              _buildInfoCard(
                'Contact Information',
                [
                  _buildInfoRow('Email', _doctor.email ?? 'N/A'),
                  _buildInfoRow('Phone', _doctor.mobileNumber ?? 'N/A'),
                  _buildInfoRow('Alt Phone', _doctor.altPhoneNumber ?? 'N/A'),
                ],
              ),
              const SizedBox(height: 16),

              // Professional Information Card
              _buildInfoCard(
                'Professional Information',
                [
                  _buildInfoRow(
                      'Specializations',
                      (_doctor.specializations != null &&
                              _doctor.specializations!.isNotEmpty)
                          ? _doctor.specializations!.join(', ')
                          : (_doctor.specialization ?? 'N/A')),
                  _buildInfoRow('Medical Registration',
                      _doctor.medicalRegistrationNumber ?? 'N/A'),
                  _buildInfoRow(
                      'License Number', _doctor.licenseNumber ?? 'N/A'),
                  _buildInfoRow(
                      'Experience', '${_doctor.experienceYears ?? 0} years'),
                  _buildInfoRow(
                      'Consultation Fee', '₹${_doctor.consultationFee ?? 0}'),
                  _buildInfoRow(
                      'Qualification', _doctor.qualification ?? 'N/A'),
                ],
              ),
              const SizedBox(height: 16),

              // Address Information Card
              _buildInfoCard(
                'Address Information',
                [
                  _buildInfoRow('Address', _doctor.address ?? 'N/A'),
                  _buildInfoRow('City', _doctor.city ?? 'N/A'),
                  _buildInfoRow('State', _doctor.state ?? 'N/A'),
                  _buildInfoRow('Pincode', _doctor.pincode ?? 'N/A'),
                ],
              ),
              const SizedBox(height: 16),

              // License & Approval
              _buildInfoCard(
                'License & Approval',
                [
                  _buildInfoRow('Medical Registration',
                      _doctor.medicalRegistrationNumber ?? 'N/A'),
                  _buildInfoRow(
                      'License Number', _doctor.licenseNumber ?? 'N/A'),
                  _buildInfoRow(
                      'Approval Status', _doctor.approvalStatus ?? 'pending'),
                  _buildInfoRow('Is Approved',
                      (_doctor.isApproved == true) ? 'Yes' : 'No'),
                ],
              ),
              const SizedBox(height: 16),

              // Account & QR
              _buildInfoCard(
                'Account & QR',
                [
                  _buildInfoRow('ARC ID',
                      _doctor.healthQrId ?? _doctor.arcId ?? _doctor.uid),
                  _buildInfoRow('Account Type', _doctor.type ?? 'N/A'),
                  _buildInfoRow('Doctor ID', _doctor.uid),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard(String title, List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: kPrimaryText,
            ),
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: kSecondaryText,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: kPrimaryText,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShareIdCard({
    required BuildContext context,
    required String name,
    required String email,
    required String phone,
    required String altPhone,
    required String address,
    required String city,
    required String state,
    required String pincode,
    required String arcId,
    required String specialization,
    required String registrationNumber,
    required String? profileImageUrl,
    required String qrDataString,
    required double maxWidth,
  }) {
    // Mirror hospital share card layout with doctor theme
    final double targetWidth = (maxWidth > 0) ? maxWidth : 1080;
    final double width = targetWidth.clamp(600, 1080);
    final double height = width * 0.56;
    final double leftPanelWidth = width * 0.16;
    final double qrBoxSize = width * 0.22;
    final double avatarRadius = width * 0.065;
    final double nameFont = width * 0.042;
    final double lineFont = width * 0.026;
    final double subtleLineFont = lineFont * 0.92;

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [kDoctorBlue, Color(0xFF0D47A1)],
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
                        color: const Color(0xFF1976D2).withOpacity(0.08),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Center(
                        child: CircleAvatar(
                          radius: avatarRadius,
                          backgroundColor: kDoctorBlue,
                          backgroundImage: (profileImageUrl != null &&
                                  profileImageUrl.isNotEmpty)
                              ? NetworkImage(profileImageUrl)
                              : null,
                          child: (profileImageUrl == null ||
                                  profileImageUrl.isEmpty)
                              ? Icon(Icons.person,
                                  size: avatarRadius, color: Colors.white)
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
                              color: const Color(0xFF111827),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: width * 0.01),
                          Row(
                            children: [
                              Icon(Icons.badge,
                                  size: lineFont + 2,
                                  color: const Color(0xFF6B7280)),
                              SizedBox(width: width * 0.008),
                              Flexible(
                                child: Text(
                                  'ARC ID: $arcId',
                                  style: TextStyle(
                                    fontSize: lineFont,
                                    color: const Color(0xFF374151),
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
                              Icon(Icons.medical_services,
                                  size: lineFont,
                                  color: const Color(0xFF6B7280)),
                              SizedBox(width: width * 0.008),
                              Flexible(
                                child: Text(
                                  'Specialization: $specialization',
                                  style: TextStyle(
                                      fontSize: lineFont,
                                      color: const Color(0xFF374151),
                                      fontWeight: FontWeight.w600),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: width * 0.008),
                          Row(
                            children: [
                              Icon(Icons.verified,
                                  size: lineFont,
                                  color: const Color(0xFF6B7280)),
                              SizedBox(width: width * 0.008),
                              Flexible(
                                child: Text(
                                  'Registration: $registrationNumber',
                                  style: TextStyle(
                                      fontSize: lineFont,
                                      color: const Color(0xFF374151)),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: width * 0.008),
                          Row(
                            children: [
                              Icon(Icons.phone,
                                  size: lineFont,
                                  color: const Color(0xFF6B7280)),
                              SizedBox(width: width * 0.008),
                              Flexible(
                                child: Text(
                                  phone,
                                  style: TextStyle(
                                      fontSize: lineFont,
                                      color: const Color(0xFF374151)),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          if (altPhone.isNotEmpty) ...[
                            SizedBox(height: width * 0.008),
                            Row(
                              children: [
                                Icon(Icons.phone_in_talk,
                                    size: lineFont,
                                    color: const Color(0xFF6B7280)),
                                SizedBox(width: width * 0.008),
                                Flexible(
                                  child: Text(
                                    altPhone,
                                    style: TextStyle(
                                        fontSize: lineFont,
                                        color: const Color(0xFF374151)),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                          SizedBox(height: width * 0.008),
                          Row(
                            children: [
                              Icon(Icons.email,
                                  size: lineFont,
                                  color: const Color(0xFF6B7280)),
                              SizedBox(width: width * 0.008),
                              Flexible(
                                child: Text(
                                  email,
                                  style: TextStyle(
                                      fontSize: lineFont,
                                      color: const Color(0xFF374151)),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          if (address.isNotEmpty) ...[
                            SizedBox(height: width * 0.008),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(Icons.location_on,
                                    size: subtleLineFont,
                                    color: const Color(0xFF6B7280)),
                                SizedBox(width: width * 0.008),
                                Expanded(
                                  child: Text(
                                    address,
                                    style: TextStyle(
                                        fontSize: subtleLineFont,
                                        color: const Color(0xFF374151)),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                          if (city.isNotEmpty ||
                              state.isNotEmpty ||
                              pincode.isNotEmpty) ...[
                            SizedBox(height: width * 0.008),
                            Row(
                              children: [
                                Icon(Icons.map,
                                    size: subtleLineFont,
                                    color: const Color(0xFF6B7280)),
                                SizedBox(width: width * 0.008),
                                Flexible(
                                  child: Text(
                                    [city, state, pincode]
                                        .where((e) => e.isNotEmpty)
                                        .join(', '),
                                    style: TextStyle(
                                        fontSize: subtleLineFont,
                                        color: const Color(0xFF374151)),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    SizedBox(width: width * 0.02),
                    // Right side: QR code
                    Container(
                      width: qrBoxSize,
                      height: qrBoxSize,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: Center(
                        child: QrImageView(
                          data: qrDataString,
                          version: QrVersions.auto,
                          size: qrBoxSize - 20,
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

  Widget _buildShareInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: GoogleFonts.poppins(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: kSecondaryText,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 10,
                color: kPrimaryText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
