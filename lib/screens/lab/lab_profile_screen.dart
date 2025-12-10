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
import 'lab_update_profile_screen.dart';

// Add color constants at the top
const Color kBackground = Color(0xFFF9FAFB);
const Color kPrimaryText = Color(0xFF2E2E2E);
const Color kSecondaryText = Color(0xFF6B7280);
const Color kBorder = Color(0xFFE5E7EB);
const Color kSuccess = Color(0xFF34D399);
const Color kLabPrimary = Color(0xFFFDBA74);
const Color kLabSecondary = Color(0xFFFB923C);

class LabProfileScreen extends StatefulWidget {
  final UserModel lab;
  const LabProfileScreen({super.key, required this.lab});

  @override
  State<LabProfileScreen> createState() => _LabProfileScreenState();
}

class _LabProfileScreenState extends State<LabProfileScreen> {
  late UserModel _lab;
  final ImagePicker _picker = ImagePicker();
  String? _profileImageUrl;

  @override
  void initState() {
    super.initState();
    _lab = widget.lab;
    _profileImageUrl = _lab.profileImageUrl;
    _loadProfileImage();
  }

  Future<void> _loadProfileImage() async {
    final prefs = await SharedPreferences.getInstance();
    final imageUrl = prefs.getString('lab_profile_image_url');
    if (imageUrl != null && imageUrl.isNotEmpty && mounted) {
      setState(() {
        _profileImageUrl = imageUrl;
      });
    }
  }

  Future<void> _pickAndUploadProfileImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile == null) return;

    final file = File(pickedFile.path);
    final uid = _lab.uid;

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
      final storageRef =
          FirebaseStorage.instance.ref().child('lab_profile_images/$uid.jpg');

      await storageRef.putFile(file);
      final url = await storageRef.getDownloadURL();

      // Update backend
      final success = await ApiService.updateLabProfile(uid, {
        'profileImageUrl': url,
      });

      if (success) {
        // Save to SharedPreferences for instant display
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('lab_profile_image_url', url);

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

      print('🧪 Loading lab profile data for UID: ${user.uid}');

      // Use universal getUserInfo method which respects user type
      final labModel = await ApiService.getUserInfo(user.uid);

      if (labModel != null) {
        print('✅ Lab profile data loaded successfully: ${labModel.fullName}');
        setState(() {
          _lab = labModel;
          _profileImageUrl = labModel.profileImageUrl;
        });
      } else {
        print('❌ Lab profile data not found');
      }
    } catch (e) {
      print('❌ Error loading lab profile data: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final qrKey = GlobalKey();

    // Generate QR code data with all lab information
    final qrData = _lab.getQrCodeData();
    final qrDataString = jsonEncode(qrData);

    Future<void> _shareQr() async {
      if (kIsWeb) {
        await Share.share(
            'My Arcular+ Lab QR ID: ${_lab.healthQrId ?? _lab.uid}');
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
                    name: _lab.fullName ?? 'Lab Name',
                    email: _lab.email ?? '',
                    phone: _lab.mobileNumber ?? '',
                    altPhone: _lab.alternateMobile ?? '',
                    address: _lab.address ?? '',
                    city: _lab.city ?? '',
                    state: _lab.state ?? '',
                    pincode: _lab.pincode ?? '',
                    arcId: _lab.healthQrId ?? _lab.arcId ?? _lab.uid,
                    labName: _lab.labName ?? _lab.fullName ?? 'Lab Name',
                    registrationNumber: _lab.registrationNumber ?? 'N/A',
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
        final file = await File('${tempDir.path}/lab_qr_id.png').create();
        await file.writeAsBytes(pngBytes);

        await Share.shareXFiles([XFile(file.path)],
            text: 'My Arcular+ Lab QR ID');
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
            'Lab Profile',
            style: GoogleFonts.poppins(
                color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
          ),
          backgroundColor: Colors.transparent,
          iconTheme: const IconThemeData(color: Colors.white),
          elevation: 0,
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [kLabSecondary, kLabPrimary],
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
                    builder: (context) => LabUpdateProfileScreen(lab: _lab),
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
                    backgroundColor: kLabSecondary,
                    backgroundImage: (_profileImageUrl?.isNotEmpty ?? false)
                        ? NetworkImage(_profileImageUrl!)
                        : null,
                    child: (_profileImageUrl?.isEmpty ?? true)
                        ? Text(
                            ((_lab.labName ?? _lab.fullName)?.isNotEmpty ??
                                    false)
                                ? (_lab.labName ?? _lab.fullName)![0]
                                    .toUpperCase()
                                : '?',
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : null,
                  ),
                  // Camera overlay removed on profile screen (updates happen in Update screen)
                ],
              ),
              const SizedBox(height: 16),

              // Lab Name and Type
              Text(
                _lab.labName ?? _lab.fullName ?? 'Lab Name',
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: kPrimaryText,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Diagnostic Laboratory',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  color: kSecondaryText,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              // ARC ID
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFDBA74), Color(0xFFFB923C)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'ARC ID: ${_lab.arcId ?? 'ARC-XXXX-XXXX-XXXX'}',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
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
                      'Lab QR Code',
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
                            backgroundColor: kLabSecondary,
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
                            backgroundColor: kLabSecondary,
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
                  _buildInfoRow(
                      'Lab Name', _lab.labName ?? _lab.fullName ?? 'N/A'),
                  _buildInfoRow('Owner Name', _lab.ownerName ?? 'N/A'),
                ],
              ),
              const SizedBox(height: 16),

              // Contact Information Card
              _buildInfoCard(
                'Contact Information',
                [
                  _buildInfoRow('Email', _lab.email ?? 'N/A'),
                  _buildInfoRow('Phone', _lab.mobileNumber ?? 'N/A'),
                  _buildInfoRow('Alt Phone', _lab.alternateMobile ?? 'N/A'),
                ],
              ),
              const SizedBox(height: 16),

              // Professional Information Card
              _buildInfoCard(
                'Professional Information',
                [
                  _buildInfoRow('Services Provided',
                      _lab.servicesProvided?.join(', ') ?? 'N/A'),
                  _buildInfoRow('Home Sample Collection',
                      _lab.homeSampleCollection == true ? 'Yes' : 'No'),
                ],
              ),
              const SizedBox(height: 16),

              // Associated Hospitals Card
              _buildInfoCard(
                'Associated Hospitals',
                [
                  _buildInfoRow('Hospitals',
                      _lab.associatedHospital ?? 'No hospitals associated'),
                ],
              ),
              const SizedBox(height: 16),

              // Address Information Card
              _buildInfoCard(
                'Address Information',
                [
                  _buildInfoRow('Address', _lab.address ?? 'N/A'),
                  _buildInfoRow('City', _lab.city ?? 'N/A'),
                  _buildInfoRow('State', _lab.state ?? 'N/A'),
                  _buildInfoRow('Pincode', _lab.pincode ?? 'N/A'),
                ],
              ),
              const SizedBox(height: 16),

              // License Information Card
              _buildInfoCard(
                'License Information',
                [
                  _buildInfoRow('License Number', _lab.licenseNumber ?? 'N/A'),
                  _buildInfoRow(
                      'Documents Uploaded',
                      _lab.licenseNumber != null &&
                              _lab.licenseNumber!.isNotEmpty
                          ? 'Yes'
                          : 'No'),
                  _buildInfoRow('Approval Status',
                      _lab.isApproved == true ? 'Approved' : 'Pending'),
                ],
              ),
              const SizedBox(height: 16),

              // QR Section Card
              _buildInfoCard(
                'QR Section',
                [
                  _buildInfoRow('ARC ID', _lab.arcId ?? 'N/A'),
                  _buildInfoRow('Lab ID', _lab.uid ?? 'N/A'),
                  _buildInfoRow('Account Type', 'Lab'),
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
    required String labName,
    required String registrationNumber,
    required String? profileImageUrl,
    required String qrDataString,
    required double maxWidth,
  }) {
    return Container(
      width: maxWidth,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kLabSecondary, width: 4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header with name and ARC ID (like hospital/pharmacy)
          Row(
            children: [
              // Lab icon/avatar
              CircleAvatar(
                radius: 20,
                backgroundColor: kLabSecondary,
                backgroundImage: (profileImageUrl?.isNotEmpty ?? false)
                    ? NetworkImage(profileImageUrl!)
                    : null,
                child: (profileImageUrl?.isEmpty ?? true)
                    ? const Icon(Icons.science, color: Colors.white, size: 20)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      labName,
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: kPrimaryText,
                      ),
                    ),
                    Row(
                      children: [
                        Icon(Icons.badge_outlined,
                            size: 14, color: kSecondaryText),
                        const SizedBox(width: 4),
                        Text(
                          'ARC ID: $arcId',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: kSecondaryText,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Main content row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Details section
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildShareInfoRow(
                        'Type', 'Diagnostic Laboratory', Icons.add),
                    _buildShareInfoRow('Phone', phone, Icons.phone),
                    if (altPhone.isNotEmpty)
                      _buildShareInfoRow('Phone', altPhone, Icons.phone),
                    _buildShareInfoRow('Email', email, Icons.mail),
                    _buildShareInfoRow(
                        'Address',
                        '$address, $city, $state - $pincode',
                        Icons.location_on),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // QR Code section
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: kLabSecondary.withOpacity(0.3)),
                ),
                child: Center(
                  child: QrImageView(
                    data: qrDataString,
                    version: QrVersions.auto,
                    size: 100.0,
                    backgroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildShareInfoRow(String label, String value, [IconData? icon]) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: kSecondaryText),
            const SizedBox(width: 8),
          ],
          SizedBox(
            width: 60,
            child: Text(
              '$label:',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: kSecondaryText,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: kPrimaryText,
                fontWeight: FontWeight.w400,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
