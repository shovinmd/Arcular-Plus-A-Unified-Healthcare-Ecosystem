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
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/api_service.dart';
import '../universal_qr_scanner_screen.dart';
import 'hospital_update_profile_screen.dart';
import '../../utils/gender_image_helper.dart';

// Add color constants at the top
const Color kBackground = Color(0xFFF9FAFB);
const Color kPrimaryText = Color(0xFF2E2E2E);
const Color kSecondaryText = Color(0xFF6B7280);
const Color kBorder = Color(0xFFE5E7EB);
const Color kSuccess = Color(0xFFA3E635);
const Color kHospitalGreen = Color(0xFF2E7D32);

class HospitalProfileScreen extends StatefulWidget {
  final UserModel hospital;
  const HospitalProfileScreen({super.key, required this.hospital});

  @override
  State<HospitalProfileScreen> createState() => _HospitalProfileScreenState();
}

class _HospitalProfileScreenState extends State<HospitalProfileScreen> {
  late UserModel _hospital;
  final ImagePicker _picker = ImagePicker();
  String? _profileImageUrl;

  @override
  void initState() {
    super.initState();
    _hospital = widget.hospital;
    _profileImageUrl = _hospital.profileImageUrl;
    _loadProfileImage();
  }

  Future<void> _loadProfileImage() async {
    final prefs = await SharedPreferences.getInstance();
    final imageUrl = prefs.getString('hospital_profile_image_url');
    if (imageUrl != null && mounted) {
      setState(() {
        _profileImageUrl = imageUrl;
      });
    }
  }

  Future<void> _pickAndUploadProfileImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile == null) return;

    final file = File(pickedFile.path);
    final uid = _hospital.uid;

    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      // Upload to Firebase Storage
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('hospital_profile_images/$uid.jpg');

      await storageRef.putFile(file);
      final url = await storageRef.getDownloadURL();

      // Update backend
      final success = await ApiService.updateHospitalProfile(uid, {
        'profileImageUrl': url,
      });

      if (success) {
        // Save to SharedPreferences for instant display
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('hospital_profile_image_url', url);

        setState(() {
          _profileImageUrl = url;
        });

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile image updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        throw Exception('Failed to update profile image');
      }
    } catch (e) {
      print('❌ Error uploading profile image: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update profile image: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      // Hide loading indicator
      Navigator.of(context).pop();
    }
  }

  Future<void> _refreshProfile() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      print('🏥 Loading hospital profile data for UID: ${user.uid}');

      // Use universal getUserInfo method which respects user type
      final hospitalModel = await ApiService.getUserInfo(user.uid);

      if (hospitalModel != null) {
        print(
            '✅ Hospital profile data loaded successfully: ${hospitalModel.hospitalName}');
        setState(() {
          _hospital = hospitalModel;
          _profileImageUrl = hospitalModel.profileImageUrl;
        });
      } else {
        print('❌ Hospital profile data not found');
      }
    } catch (e) {
      print('❌ Error loading hospital profile data: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final qrKey = GlobalKey();

    // Generate QR code data with all hospital information
    final qrData = _hospital.getQrCodeData();
    final qrDataString = jsonEncode(qrData);

    Future<void> _shareQr() async {
      if (kIsWeb) {
        await Share.share(
            'My Arcular+ Hospital QR ID: ${_hospital.healthQrId ?? _hospital.uid}');
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
                    name: _hospital.hospitalName ?? 'Hospital Name',
                    email: _hospital.hospitalEmail ?? _hospital.email,
                    phone: _hospital.hospitalPhone ?? _hospital.mobileNumber,
                    altPhone:
                        _hospital.alternateMobile ?? _hospital.altPhoneNumber,
                    address: _hospital.address ?? '',
                    city: _hospital.city ?? '',
                    state: _hospital.state ?? '',
                    pincode: _hospital.pincode ?? '',
                    arcId: _hospital.healthQrId ??
                        _hospital.arcId ??
                        _hospital.uid,
                    hospitalType: _hospital.hospitalType ?? 'Hospital',
                    registrationNumber: _hospital.registrationNumber ?? 'N/A',
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
        final file = await File('${tempDir.path}/hospital_qr_id.png').create();
        await file.writeAsBytes(pngBytes);

        await Share.shareXFiles([XFile(file.path)],
            text: 'My Arcular+ Hospital QR ID');
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
            'Hospital Profile',
            style: GoogleFonts.poppins(
                color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
          ),
          backgroundColor: Colors.transparent,
          iconTheme: const IconThemeData(color: Colors.white),
          elevation: 0,
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [kHospitalGreen, Color(0xFF1B5E20)],
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
                        HospitalUpdateProfileScreen(hospital: _hospital),
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
                  GestureDetector(
                    onTap: _pickAndUploadProfileImage,
                    child: CircleAvatar(
                      radius: 50,
                      backgroundColor: kHospitalGreen,
                      backgroundImage: (_profileImageUrl?.isNotEmpty ?? false)
                          ? NetworkImage(_profileImageUrl!)
                          : null,
                      child: (_profileImageUrl?.isEmpty ?? true)
                          ? FutureBuilder<String?>(
                              future: GenderImageHelper.getGenderBasedImage(
                                  'hospital'),
                              builder: (context, snapshot) {
                                if (snapshot.hasData && snapshot.data != null) {
                                  return ClipOval(
                                    child: Image.asset(
                                      snapshot.data!,
                                      width: 100,
                                      height: 100,
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (context, error, stackTrace) {
                                        return Text(
                                          (_hospital.hospitalName?.isNotEmpty ??
                                                  false)
                                              ? _hospital.hospitalName![0]
                                                  .toUpperCase()
                                              : '?',
                                          style: GoogleFonts.poppins(
                                            fontSize: 36,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        );
                                      },
                                    ),
                                  );
                                } else {
                                  return Text(
                                    (_hospital.hospitalName?.isNotEmpty ??
                                            false)
                                        ? _hospital.hospitalName![0]
                                            .toUpperCase()
                                        : '?',
                                    style: GoogleFonts.poppins(
                                      fontSize: 36,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  );
                                }
                              },
                            )
                          : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                _hospital.hospitalName ?? 'Hospital Name',
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: kPrimaryText,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _hospital.email,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  color: kSecondaryText,
                ),
              ),
              const SizedBox(height: 8),
              // ARC ID
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [kHospitalGreen, Color(0xFF66BB6A)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'ARC ID: ${_hospital.arcId ?? 'ARC-XXXX-XXXX-XXXX'}',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${(_hospital.hospitalType ?? 'HOSPITAL').toUpperCase()} • ${_hospital.numberOfBeds ?? 0} Beds',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  color: kHospitalGreen,
                ),
              ),
              const SizedBox(height: 24),

              // Hospital QR Code Card
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.qr_code, color: kHospitalGreen, size: 24),
                          const SizedBox(width: 8),
                          const Text('Hospital QR Code',
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
                        'Scan this QR code to access complete hospital information',
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
                                colors: [kHospitalGreen, Color(0xFF66BB6A)],
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                              ),
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: [
                                BoxShadow(
                                  color: kHospitalGreen.withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ElevatedButton.icon(
                              icon:
                                  const Icon(Icons.share, color: Colors.white),
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
                                shadowColor: Colors.transparent,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 24, vertical: 12),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Container(
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFFF9800), Color(0xFFFFB74D)],
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                              ),
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      const Color(0xFFFF9800).withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.qr_code_scanner,
                                  color: Colors.white),
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
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const UniversalQRScannerScreen(),
                                  ),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 24, vertical: 12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Basic Information
              _buildInfoCard(
                'Basic Information',
                [
                  _buildInfoRow(
                      'Hospital Owner Name',
                      _hospital.hospitalOwnerName ?? 'Not provided',
                      kPrimaryText),
                  _buildInfoRow('Hospital Name',
                      _hospital.hospitalName ?? 'Not provided', kPrimaryText),
                ],
              ),
              const SizedBox(height: 16),

              // Hospital Information
              _buildInfoCard(
                'Hospital Information',
                [
                  _buildInfoRow(
                      'Registration Number',
                      _hospital.registrationNumber ?? 'Not provided',
                      kPrimaryText),
                  _buildInfoRow(
                      'Hospital Type',
                      _hospital.hospitalType ?? 'Not specified',
                      kSecondaryText),
                  _buildInfoRow(
                      'Number of Beds',
                      _hospital.numberOfBeds?.toString() ?? '0',
                      kSecondaryText),
                  _buildInfoRow(
                      'Pharmacy Available',
                      _hospital.hasPharmacy == true ? 'Yes' : 'No',
                      kSecondaryText),
                  _buildInfoRow('Lab Available',
                      _hospital.hasLab == true ? 'Yes' : 'No', kSecondaryText),
                ],
              ),
              const SizedBox(height: 16),

              // Contact Information
              _buildInfoCard(
                'Contact Information',
                [
                  _buildInfoRow(
                      'Hospital Email', _hospital.email, kSecondaryText),
                  _buildInfoRow(
                      'Hospital Phone Number',
                      _hospital.hospitalPhone ??
                          _hospital.mobileNumber ??
                          'Not provided',
                      kSecondaryText),
                  _buildInfoRow(
                      'Alternate Mobile',
                      _hospital.alternateMobile ??
                          _hospital.altPhoneNumber ??
                          'Not provided',
                      kSecondaryText),
                ],
              ),
              const SizedBox(height: 16),

              // Location Information
              _buildInfoCard(
                'Location Information',
                [
                  _buildInfoRow('Address', _hospital.address, kPrimaryText),
                  _buildInfoRow('City', _hospital.city, kSecondaryText),
                  _buildInfoRow('State', _hospital.state, kSecondaryText),
                  _buildInfoRow('Pincode', _hospital.pincode, kSecondaryText),
                  _buildInfoRow(
                      'Longitude',
                      _hospital.longitude?.toString() ?? 'Not provided',
                      kSecondaryText),
                  _buildInfoRow(
                      'Latitude',
                      _hospital.latitude?.toString() ?? 'Not provided',
                      kSecondaryText),
                ],
              ),
              const SizedBox(height: 16),

              // Departments and Facilities
              _buildInfoCard(
                'Departments & Facilities',
                [
                  _buildInfoRow(
                      'Departments',
                      _hospital.departments?.join(', ') ?? 'Not specified',
                      kSecondaryText),
                  _buildInfoRow(
                      'Special Facilities',
                      _hospital.specialFacilities?.join(', ') ??
                          'Not specified',
                      kSecondaryText),
                ],
              ),
              const SizedBox(height: 16),

              // License Information
              _buildInfoCard(
                'License Information',
                [
                  _buildInfoRow(
                      'License Document',
                      _hospital.licenseDocumentUrl != null
                          ? 'Uploaded'
                          : 'Not uploaded',
                      kSecondaryText),
                  _buildInfoRow(
                      'Registration Certificate',
                      _hospital.registrationCertificateUrl != null
                          ? 'Uploaded'
                          : 'Not uploaded',
                      kSecondaryText),
                  _buildInfoRow(
                      'Building Permit',
                      _hospital.buildingPermitUrl != null
                          ? 'Uploaded'
                          : 'Not uploaded',
                      kSecondaryText),
                  _buildInfoRow('Approval Status',
                      _hospital.approvalStatus ?? 'Pending', kSecondaryText),
                  _buildInfoRow(
                      'Is Approved',
                      _hospital.isApproved == true ? 'Yes' : 'No',
                      kSecondaryText),
                ],
              ),
              const SizedBox(height: 16),

              // QR Code Information
              _buildInfoCard(
                'QR Code Information',
                [
                  _buildInfoRow('Hospital ID', _hospital.uid, kPrimaryText),
                  _buildInfoRow('Account Type', _hospital.type.toUpperCase(),
                      kSecondaryText),
                  _buildInfoRow('ARC ID', _hospital.arcId ?? 'Not assigned',
                      kSecondaryText),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard(String title, List<Widget> children) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: kHospitalGreen,
              ),
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, Color valueColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              '$label:',
              style: GoogleFonts.poppins(
                color: kSecondaryText,
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.poppins(
                color: valueColor,
                fontWeight: FontWeight.w500,
                fontSize: 14,
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
    String? altPhone,
    String? address,
    String? city,
    String? state,
    String? pincode,
    required String arcId,
    required String hospitalType,
    required String registrationNumber,
    String? profileImageUrl,
    required String qrDataString,
    double? maxWidth,
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
            kHospitalGreen,
            Color(0xFF66BB6A)
          ], // Hospital green gradient
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
                        color: kHospitalGreen.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Center(
                        child: CircleAvatar(
                          radius: avatarRadius,
                          backgroundColor: kHospitalGreen,
                          backgroundImage: (profileImageUrl != null &&
                                  profileImageUrl.isNotEmpty)
                              ? NetworkImage(profileImageUrl)
                              : null,
                          child: (profileImageUrl == null ||
                                  profileImageUrl.isEmpty)
                              ? FutureBuilder<String?>(
                                  future: GenderImageHelper.getGenderBasedImage(
                                      'hospital'),
                                  builder: (context, snapshot) {
                                    if (snapshot.hasData &&
                                        snapshot.data != null) {
                                      return ClipOval(
                                        child: Image.asset(
                                          snapshot.data!,
                                          width: avatarRadius * 2,
                                          height: avatarRadius * 2,
                                          fit: BoxFit.cover,
                                          errorBuilder:
                                              (context, error, stackTrace) {
                                            return Icon(Icons.local_hospital,
                                                size: avatarRadius,
                                                color: Colors.white);
                                          },
                                        ),
                                      );
                                    } else {
                                      return Icon(Icons.local_hospital,
                                          size: avatarRadius,
                                          color: Colors.white);
                                    }
                                  },
                                )
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
                              Icon(Icons.local_hospital,
                                  size: lineFont,
                                  color: const Color(0xFF6B7280)),
                              SizedBox(width: width * 0.008),
                              Flexible(
                                child: Text(
                                  'Type: $hospitalType',
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

  Widget _buildDetailRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(
            icon,
            size: 14,
            color: kSecondaryText,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: kSecondaryText,
                fontSize: 12,
                height: 1.2,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
