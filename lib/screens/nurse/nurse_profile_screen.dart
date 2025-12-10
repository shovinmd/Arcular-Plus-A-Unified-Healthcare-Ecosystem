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
import 'nurse_update_profile_screen.dart';

// Add color constants at the top
const Color kBackground = Color(0xFFF9FAFB);
const Color kPrimaryText = Color(0xFF2E2E2E);
const Color kSecondaryText = Color(0xFF6B7280);
const Color kBorder = Color(0xFFE5E7EB);
const Color kSuccess = Color(0xFFA3E635);
const Color kNursePurple = Color(0xFF9C27B0);

class NurseProfileScreen extends StatefulWidget {
  final UserModel nurse;
  const NurseProfileScreen({super.key, required this.nurse});

  @override
  State<NurseProfileScreen> createState() => _NurseProfileScreenState();
}

class _NurseProfileScreenState extends State<NurseProfileScreen> {
  late UserModel _nurse;
  String? _profileImageUrl;

  @override
  void initState() {
    super.initState();
    _nurse = widget.nurse;
    _profileImageUrl = _nurse.profileImageUrl;
    _loadProfileImage();
  }

  Future<void> _loadProfileImage() async {
    final prefs = await SharedPreferences.getInstance();
    final imageUrl = prefs.getString('nurse_profile_image_url');
    if (imageUrl != null && mounted) {
      setState(() {
        _profileImageUrl = imageUrl;
      });
    }
  }

  // Profile image changes are restricted to the update screen.

  Future<void> _refreshProfile() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      print('👩‍⚕️ Loading nurse profile data for UID: ${user.uid}');

      // Use universal getUserInfo method which respects user type
      final nurseModel = await ApiService.getUserInfo(user.uid);

      if (nurseModel != null) {
        print(
            '✅ Nurse profile data loaded successfully: ${nurseModel.fullName}');
        setState(() {
          _nurse = nurseModel;
          _profileImageUrl = nurseModel.profileImageUrl;
        });
      } else {
        print('❌ Nurse profile data not found');
      }
    } catch (e) {
      print('❌ Error loading nurse profile data: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final qrKey = GlobalKey();

    // Generate QR code data with all nurse information
    final qrData = _nurse.getQrCodeData();
    final qrDataString = jsonEncode(qrData);

    Future<void> _shareQr() async {
      if (kIsWeb) {
        await Share.share(
            'My Arcular+ Nurse QR ID: ${_nurse.healthQrId ?? _nurse.uid}');
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
                    name: _nurse.fullName ?? 'Nurse Name',
                    email: _nurse.email ?? '',
                    phone: _nurse.mobileNumber ?? '',
                    altPhone: _nurse.altPhoneNumber ?? '',
                    address: _nurse.address ?? '',
                    city: _nurse.city ?? '',
                    state: _nurse.state ?? '',
                    pincode: _nurse.pincode ?? '',
                    arcId: _nurse.healthQrId ?? _nurse.arcId ?? _nurse.uid,
                    specialization: _nurse.specialization ?? 'General Nursing',
                    registrationNumber: _nurse.registrationNumber ?? 'N/A',
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
        final file = await File('${tempDir.path}/nurse_qr_id.png').create();
        await file.writeAsBytes(pngBytes);

        await Share.shareXFiles([XFile(file.path)],
            text: 'My Arcular+ Nurse QR ID');
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
            'Nurse Profile',
            style: GoogleFonts.poppins(
                color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
          ),
          backgroundColor: Colors.transparent,
          iconTheme: const IconThemeData(color: Colors.white),
          elevation: 0,
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [kNursePurple, Color(0xFF6A1B9A)],
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
                        NurseUpdateProfileScreen(nurse: _nurse),
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
              Stack(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: kNursePurple,
                    backgroundImage: (_profileImageUrl?.isNotEmpty ?? false)
                        ? NetworkImage(_profileImageUrl!)
                        : null,
                    child: (_profileImageUrl?.isEmpty ?? true)
                        ? Text(
                            (_nurse.fullName?.isNotEmpty ?? false)
                                ? _nurse.fullName![0].toUpperCase()
                                : '?',
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : null,
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Header texts aligned to match hospital style
              Text(
                _nurse.fullName ?? 'Nurse Name',
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: kPrimaryText,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                _nurse.email ?? '',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: kSecondaryText,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              if ((_nurse.arcId ?? _nurse.healthQrId ?? _nurse.uid) != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFC084FC), Color(0xFFA855F7)],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'ARC ID: ${_nurse.healthQrId ?? _nurse.arcId ?? _nurse.uid}',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
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
                      'Nurse QR Code',
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
                            backgroundColor: kNursePurple,
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

              // Basic Information Card (Name, Gender, DOB only)
              _buildInfoCard(
                'Basic Information',
                [
                  _buildInfoRow('Full Name', _nurse.fullName ?? 'N/A'),
                  _buildInfoRow('Gender', _nurse.gender ?? 'N/A'),
                  _buildInfoRow(
                    'Date of Birth',
                    _nurse.dateOfBirth != null
                        ? _nurse.dateOfBirth!.toLocal().toString().split(' ')[0]
                        : 'N/A',
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Contact Information (Email and contact numbers)
              _buildInfoCard(
                'Contact Information',
                [
                  _buildInfoRow('Email', _nurse.email ?? 'N/A'),
                  _buildInfoRow('Phone', _nurse.mobileNumber ?? 'N/A'),
                  _buildInfoRow('Alt Phone', _nurse.altPhoneNumber ?? 'N/A'),
                ],
              ),
              const SizedBox(height: 16),

              // Associated Hospitals
              _buildInfoCard(
                'Associated Hospitals',
                _buildAssociatedHospitalsRows(),
              ),
              const SizedBox(height: 16),

              // Professional Information Card
              _buildInfoCard(
                'Professional Information',
                [
                  _buildInfoRow(
                      'Specialization', _nurse.specialization ?? 'N/A'),
                  _buildInfoRow('Registration Number',
                      _nurse.registrationNumber ?? 'N/A'),
                  _buildInfoRow(
                      'License Number', _nurse.licenseNumber ?? 'N/A'),
                  _buildInfoRow(
                      'Experience', '${_nurse.experienceYears ?? 0} years'),
                  _buildInfoRow('Qualification', _nurse.qualification ?? 'N/A'),
                  _buildInfoRow('Current Role', _nurse.role ?? 'Staff'),
                ],
              ),
              const SizedBox(height: 16),

              // Address Information Card
              _buildInfoCard(
                'Address Information',
                [
                  _buildInfoRow('Address', _nurse.address ?? 'N/A'),
                  _buildInfoRow('City', _nurse.city ?? 'N/A'),
                  _buildInfoRow('State', _nurse.state ?? 'N/A'),
                  _buildInfoRow('Pincode', _nurse.pincode ?? 'N/A'),
                ],
              ),
              const SizedBox(height: 16),

              // License Information (approval + docs uploaded)
              _buildInfoCard(
                'License Information',
                [
                  _buildInfoRow(
                    'License Document',
                    (_nurse.licenseDocumentUrl ?? _nurse.certificateUrl) != null
                        ? 'Uploaded'
                        : 'Not uploaded',
                  ),
                  _buildInfoRow(
                      'Approval Status', _nurse.approvalStatus ?? 'Pending'),
                  _buildInfoRow(
                      'Is Approved', _nurse.isApproved == true ? 'Yes' : 'No'),
                ],
              ),
              const SizedBox(height: 16),

              // QR Section (moved below License Information)
              _buildInfoCard(
                'QR Section',
                [
                  _buildInfoRow('ARC ID',
                      _nurse.healthQrId ?? _nurse.arcId ?? _nurse.uid),
                  _buildInfoRow('Account Type', 'Nurse'),
                  _buildInfoRow('Nurse ID', _nurse.uid),
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

  List<Widget> _buildAssociatedHospitalsRows() {
    final List<Widget> rows = [];
    if ((_nurse.enhancedAffiliatedHospitals != null &&
        _nurse.enhancedAffiliatedHospitals!.isNotEmpty)) {
      for (final Map<String, dynamic> h
          in _nurse.enhancedAffiliatedHospitals!) {
        final name = h['hospitalName'] ?? h['name'] ?? 'Hospital';
        final role = h['role'] ?? 'Staff';
        final active = h['isActive'] == true;
        rows.add(_buildInfoRow(
            name, active ? 'Active • $role' : 'Inactive • $role'));
      }
    } else if (_nurse.affiliatedHospitals != null &&
        _nurse.affiliatedHospitals!.isNotEmpty) {
      for (final String name in _nurse.affiliatedHospitals!) {
        rows.add(_buildInfoRow(name, 'Affiliated'));
      }
    } else if (_nurse.hospitalAffiliation != null &&
        _nurse.hospitalAffiliation!.isNotEmpty) {
      rows.add(_buildInfoRow(_nurse.hospitalAffiliation!, 'Current'));
    } else {
      rows.add(_buildInfoRow('Hospitals', 'No affiliations'));
    }
    return rows;
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
    // Responsive size to avoid clipping on small screens
    final double targetWidth =
        (maxWidth != null && maxWidth > 0) ? maxWidth : 1080;
    final double width = targetWidth.clamp(600, 1080);
    final double height = width * 0.56; // aspect ratio ~ 1080x600
    final double leftPanelWidth = width * 0.16; // left panel for profile image
    final double qrBoxSize = width * 0.22; // wider QR box for better scanning
    final double avatarRadius = width * 0.065; // avatar size
    final double nameFont = width * 0.042; // larger title font
    final double lineFont = width * 0.026; // slightly larger line font
    final double subtleLineFont =
        lineFont * 0.92; // smaller for long address/location

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFC084FC), // Nurse purple
            Color(0xFFA78BFA)
          ],
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
                        color: const Color(0xFFC084FC).withOpacity(0.08),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Center(
                        child: CircleAvatar(
                          radius: avatarRadius,
                          backgroundColor: const Color(0xFFC084FC),
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
                              color: Color(0xFF111827),
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
                          if ((altPhone ?? '').isNotEmpty) ...[
                            SizedBox(height: width * 0.008),
                            Row(
                              children: [
                                Icon(Icons.phone_in_talk,
                                    size: lineFont,
                                    color: const Color(0xFF6B7280)),
                                SizedBox(width: width * 0.008),
                                Flexible(
                                  child: Text(
                                    altPhone!,
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
                          if ((address ?? '').isNotEmpty) ...[
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
                                    address!,
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
                          if (((city ?? '').isNotEmpty) ||
                              ((state ?? '').isNotEmpty) ||
                              ((pincode ?? '').isNotEmpty)) ...[
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
                                        .where((e) => (e ?? '').isNotEmpty)
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
}
