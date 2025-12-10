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
import 'pharmacy_update_profile_screen.dart';
import '../../widgets/service_provider_share_card.dart';

// Add color constants at the top
const Color kBackground = Color(0xFFF9FAFB);
const Color kPrimaryText = Color(0xFF2E2E2E);
const Color kSecondaryText = Color(0xFF6B7280);
const Color kBorder = Color(0xFFE5E7EB);
const Color kSuccess = Color(0xFFA3E635);
const Color kPharmacyOrange = Color(0xFFFF9800);

class PharmacyProfileScreen extends StatefulWidget {
  final UserModel pharmacy;
  const PharmacyProfileScreen({super.key, required this.pharmacy});

  @override
  State<PharmacyProfileScreen> createState() => _PharmacyProfileScreenState();
}

class _PharmacyProfileScreenState extends State<PharmacyProfileScreen> {
  late UserModel _pharmacy;
  String? _profileImageUrl;

  @override
  void initState() {
    super.initState();
    _pharmacy = widget.pharmacy;
    _profileImageUrl = _pharmacy.profileImageUrl;
    _loadProfileImage();
  }

  Future<void> _loadProfileImage() async {
    final prefs = await SharedPreferences.getInstance();
    final imageUrl = prefs.getString('pharmacy_profile_image_url');
    if (imageUrl != null && mounted) {
      setState(() {
        _profileImageUrl = imageUrl;
      });
    }
  }

  // Profile image is read-only in profile screen
  // Image can only be updated in the update profile screen

  Future<void> _refreshProfile() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      print('💊 Loading pharmacy profile data for UID: ${user.uid}');

      // Use universal getUserInfo method which respects user type
      final pharmacyModel = await ApiService.getUserInfo(user.uid);

      if (pharmacyModel != null) {
        print(
            '✅ Pharmacy profile data loaded successfully: ${pharmacyModel.fullName}');
        setState(() {
          _pharmacy = pharmacyModel;
          _profileImageUrl = pharmacyModel.profileImageUrl;
        });
      } else {
        print('❌ Pharmacy profile data not found');
      }
    } catch (e) {
      print('❌ Error loading pharmacy profile data: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final qrKey = GlobalKey();

    // Generate QR code data with all pharmacy information
    final qrData = _pharmacy.getQrCodeData();
    final qrDataString = jsonEncode(qrData);

    Future<void> _shareQr() async {
      if (kIsWeb) {
        await Share.share(
            'My Arcular+ Pharmacy QR ID: ${_pharmacy.healthQrId ?? _pharmacy.uid}');
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
                  child: ServiceProviderShareCard(
                    name: _pharmacy.pharmacyName ??
                        _pharmacy.fullName ??
                        'Pharmacy Name',
                    email: _pharmacy.email ?? '',
                    phone: _pharmacy.mobileNumber ?? '',
                    altPhone: _pharmacy.alternateMobile,
                    address: _pharmacy.address,
                    city: _pharmacy.city,
                    state: _pharmacy.state,
                    pincode: _pharmacy.pincode,
                    arcId: _pharmacy.healthQrId ??
                        _pharmacy.arcId ??
                        _pharmacy.uid,
                    providerType: 'Pharmaceutical Store',
                    registrationNumber: _pharmacy.registrationNumber ?? 'N/A',
                    profileImageUrl: _profileImageUrl,
                    qrDataString: qrDataString,
                    maxWidth: screenWidth - 24,
                    primaryColor: const Color(0xFFFFD700),
                    secondaryColor: const Color(0xFFFFA500),
                    providerIcon: Icons.local_pharmacy,
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
        final file = await File('${tempDir.path}/pharmacy_qr_id.png').create();
        await file.writeAsBytes(pngBytes);

        await Share.shareXFiles([XFile(file.path)],
            text: 'My Arcular+ Pharmacy QR ID');
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
      child: Stack(
        children: [
          Scaffold(
            backgroundColor: kBackground,
            appBar: AppBar(
              title: Text(
                'Pharmacy Profile',
                style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18),
              ),
              backgroundColor: Colors.transparent,
              iconTheme: const IconThemeData(color: Colors.white),
              elevation: 0,
              flexibleSpace: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
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
                            PharmacyUpdateProfileScreen(pharmacy: _pharmacy),
                      ),
                    );
                    if (result == true) {
                      await _refreshProfile();
                      await _loadProfileImage(); // Also refresh the image from SharedPreferences
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
                  // Profile Header (read-only)
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: const Color(0xFFFFD700),
                    backgroundImage: (_profileImageUrl?.isNotEmpty ?? false)
                        ? NetworkImage(_profileImageUrl!)
                        : null,
                    child: (_profileImageUrl?.isEmpty ?? true)
                        ? Text(
                            (_pharmacy.fullName?.isNotEmpty ?? false)
                                ? _pharmacy.fullName![0].toUpperCase()
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

                  // Pharmacy Name and Type
                  Text(
                    _pharmacy.pharmacyName ??
                        _pharmacy.fullName ??
                        'Pharmacy Name',
                    style: GoogleFonts.poppins(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: kPrimaryText,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFFD700).withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      'ARC ID: ${_pharmacy.arcId ?? _pharmacy.healthQrId ?? 'N/A'}',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Pharmaceutical Store',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      color: kSecondaryText,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),

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
                          'Pharmacy QR Code',
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
                            foregroundColor: const Color(0xFF1F2937),
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
                                backgroundColor: const Color(0xFFFFD700),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                            ElevatedButton.icon(
                              onPressed: _shareQr,
                              icon:
                                  const Icon(Icons.share, color: Colors.white),
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
                      _buildInfoRow(
                          'Pharmacy Name',
                          _pharmacy.pharmacyName ??
                              _pharmacy.fullName ??
                              'N/A'),
                      _buildInfoRow('Email', _pharmacy.email ?? 'N/A'),
                      _buildInfoRow('Phone', _pharmacy.mobileNumber ?? 'N/A'),
                      _buildInfoRow(
                          'Alt Phone', _pharmacy.alternateMobile ?? 'N/A'),
                      _buildInfoRow('Owner Name', _pharmacy.ownerName ?? 'N/A'),
                      _buildInfoRow(
                          'Pharmacist Name', _pharmacy.pharmacistName ?? 'N/A'),
                      _buildInfoRow('Gender', _pharmacy.gender ?? 'N/A'),
                      _buildInfoRow(
                          'Date of Birth',
                          _pharmacy.dateOfBirth != null
                              ? '${_pharmacy.dateOfBirth!.day}/${_pharmacy.dateOfBirth!.month}/${_pharmacy.dateOfBirth!.year}'
                              : 'N/A'),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Pharmacy Information Card
                  _buildInfoCard(
                    'Pharmacy Information',
                    [
                      _buildInfoRow(
                          'License Number', _pharmacy.licenseNumber ?? 'N/A'),
                      _buildInfoRow('Pharmacy License Number',
                          _pharmacy.pharmacyLicenseNumber ?? 'N/A'),
                      _buildInfoRow('Pharmacist License Number',
                          _pharmacy.pharmacistLicenseNumber ?? 'N/A'),
                      _buildInfoRow('Pharmacist Qualification',
                          _pharmacy.pharmacistQualification ?? 'N/A'),
                      _buildInfoRow(
                          'Experience Years',
                          _pharmacy.pharmacistExperienceYears?.toString() ??
                              'N/A'),
                      _buildInfoRow('Home Delivery',
                          _pharmacy.homeDelivery == true ? 'Yes' : 'No'),
                      _buildInfoRow(
                          'Operating Hours',
                          _pharmacy.operatingHoursDetails != null
                              ? '${_pharmacy.operatingHoursDetails!['openTime'] ?? 'N/A'} - ${_pharmacy.operatingHoursDetails!['closeTime'] ?? 'N/A'}'
                              : 'N/A'),
                      _buildInfoRow(
                          'Working Days',
                          _pharmacy.operatingHoursDetails != null
                              ? (_pharmacy.operatingHoursDetails!['workingDays']
                                          as List?)
                                      ?.join(', ') ??
                                  'N/A'
                              : 'N/A'),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Contact Information Card
                  _buildInfoCard(
                    'Contact Information',
                    [
                      _buildInfoRow('Email', _pharmacy.email ?? 'N/A'),
                      _buildInfoRow('Phone', _pharmacy.mobileNumber ?? 'N/A'),
                      _buildInfoRow(
                          'Alt Phone', _pharmacy.alternateMobile ?? 'N/A'),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Location Information Card
                  _buildInfoCard(
                    'Location Information',
                    [
                      _buildInfoRow('Address', _pharmacy.address ?? 'N/A'),
                      _buildInfoRow('City', _pharmacy.city ?? 'N/A'),
                      _buildInfoRow('State', _pharmacy.state ?? 'N/A'),
                      _buildInfoRow('Pincode', _pharmacy.pincode ?? 'N/A'),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Services and Drugs Card
                  _buildInfoCard(
                    'Services Provided & Drugs Available',
                    [
                      _buildInfoRow(
                          'Services Provided',
                          _pharmacy.pharmacyServicesProvided?.join(', ') ??
                              'N/A'),
                      _buildInfoRow('Drugs Available',
                          _pharmacy.drugsAvailable?.join(', ') ?? 'N/A'),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // License Information Card
                  _buildInfoCard(
                    'License Information',
                    [
                      _buildInfoRow(
                          'Pharmacy License',
                          _pharmacy.licenseDocumentUrl != null &&
                                  _pharmacy.licenseDocumentUrl!.isNotEmpty
                              ? 'Uploaded'
                              : 'Not Uploaded'),
                      _buildInfoRow(
                          'Drug License',
                          _pharmacy.drugLicenseUrl != null &&
                                  _pharmacy.drugLicenseUrl!.isNotEmpty
                              ? 'Uploaded'
                              : 'Not Uploaded'),
                      _buildInfoRow(
                          'Premises Certificate',
                          _pharmacy.premisesCertificateUrl != null &&
                                  _pharmacy.premisesCertificateUrl!.isNotEmpty
                              ? 'Uploaded'
                              : 'Not Uploaded'),
                      if (_pharmacy.isApproved == true) ...[
                        _buildInfoRow('Approval Status', 'Approved'),
                      ],
                    ],
                  ),
                  const SizedBox(height: 16),

                  // QR Code Information Card
                  _buildInfoCard(
                    'QR Code Information',
                    [
                      _buildInfoRow('Pharmacy ID', _pharmacy.arcId ?? 'N/A'),
                      _buildInfoRow('Account Type', 'Pharmacy'),
                      _buildInfoRow('ARC ID',
                          _pharmacy.healthQrId ?? _pharmacy.arcId ?? 'N/A'),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
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
}
