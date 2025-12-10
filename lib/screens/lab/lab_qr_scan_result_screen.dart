import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LabQRScanResultScreen extends StatefulWidget {
  final Map<String, dynamic> labData;
  const LabQRScanResultScreen({super.key, required this.labData});

  @override
  State<LabQRScanResultScreen> createState() => _LabQRScanResultScreenState();
}

class _LabQRScanResultScreenState extends State<LabQRScanResultScreen> {
  Color get _primary => const Color(0xFFFDBA74);
  Color get _secondary => const Color(0xFFFB923C);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Lab Information',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: _secondary,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [_secondary, _primary, const Color(0xFFFFF3E0)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: _buildLabInfo(),
        ),
      ),
    );
  }

  Widget _buildLabInfo() {
    if (widget.labData.isEmpty) {
      return const Center(
        child: Text('No lab data available'),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with lab name and ARC ID
          _buildHeader(),
          const SizedBox(height: 24),

          // Basic Information
          _buildBasicInfoCard(),
          const SizedBox(height: 16),

          // Contact Information
          _buildContactCard(),
          const SizedBox(height: 16),

          // Professional Information
          _buildProfessionalInfoCard(),
          const SizedBox(height: 16),

          // Associated Hospitals
          _buildAssociatedHospitalsCard(),
          const SizedBox(height: 16),

          // QR Section
          _buildQRSection(),
          const SizedBox(height: 16),

          // Disclaimer
          _buildDisclaimerCard(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
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
          // Profile Image or Icon
          FutureBuilder<SharedPreferences>(
            future: SharedPreferences.getInstance(),
            builder: (context, snapshot) {
              final prefs = snapshot.data;
              final cachedImageUrl = prefs?.getString('lab_profile_image_url');
              final networkImageUrl =
                  widget.labData['profileImageUrl']?.toString();
              final profileImageUrl =
                  (cachedImageUrl != null && cachedImageUrl.isNotEmpty)
                      ? cachedImageUrl
                      : (networkImageUrl != null && networkImageUrl.isNotEmpty
                          ? networkImageUrl
                          : null);

              if (profileImageUrl != null && profileImageUrl.isNotEmpty) {
                return Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _secondary,
                      width: 4,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _secondary.withOpacity(0.3),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: Image.network(
                      profileImageUrl,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(
                          color: _secondary.withOpacity(0.1),
                          child: Center(
                            child: CircularProgressIndicator(
                              value: loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded /
                                      loadingProgress.expectedTotalBytes!
                                  : null,
                              color: _secondary,
                            ),
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: _secondary.withOpacity(0.1),
                          child: const Icon(
                            Icons.science,
                            size: 60,
                            color: Color(0xFFFB923C),
                          ),
                        );
                      },
                    ),
                  ),
                );
              } else {
                return Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: _secondary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.science_outlined,
                    size: 48,
                    color: Color(0xFFFB923C),
                  ),
                );
              }
            },
          ),
          const SizedBox(height: 16),

          // Lab name
          Text(
            widget.labData['labName'] ?? widget.labData['fullName'] ?? 'Lab',
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF2E2E2E),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),

          // ARC ID
          Text(
            'ARC ID: ${widget.labData['healthQrId'] ?? widget.labData['arcId'] ?? 'N/A'}',
            style: GoogleFonts.poppins(
              fontSize: 16,
              color: const Color(0xFF6B7280),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBasicInfoCard() {
    return _buildInfoCard(
      title: 'Basic Information',
      icon: Icons.info_outline,
      children: [
        _buildInfoRow(
          'Lab Name',
          widget.labData['labName'] ??
              widget.labData['fullName'] ??
              'Not provided',
        ),
        _buildInfoRow(
          'Owner Name',
          widget.labData['ownerName'] ?? 'Not provided',
        ),
      ],
    );
  }

  Widget _buildProfessionalInfoCard() {
    return _buildInfoCard(
      title: 'Professional Information',
      icon: Icons.work_outline,
      children: [
        _buildInfoRow(
          'License Number',
          widget.labData['licenseNumber'] ?? 'Not provided',
        ),
        _buildInfoRow(
          'Services Provided',
          widget.labData['servicesProvided'] != null
              ? (widget.labData['servicesProvided'] is List
                  ? widget.labData['servicesProvided'].join(', ')
                  : widget.labData['servicesProvided'].toString())
              : 'Not provided',
        ),
        _buildInfoRow(
          'Home Sample Collection',
          widget.labData['homeSampleCollection'] == true ? 'Yes' : 'No',
          valueColor: widget.labData['homeSampleCollection'] == true
              ? Colors.green
              : Colors.red,
        ),
      ],
    );
  }

  Widget _buildContactCard() {
    return _buildInfoCard(
      title: 'Contact Information',
      icon: Icons.phone_outlined,
      children: [
        _buildInfoRow(
          'Email',
          widget.labData['email'] ?? 'Not provided',
        ),
        _buildInfoRow(
          'Phone',
          widget.labData['mobileNumber'] ?? 'Not provided',
        ),
        _buildInfoRow(
          'Alt Phone',
          widget.labData['alternateMobile'] ?? 'Not provided',
        ),
      ],
    );
  }

  Widget _buildAssociatedHospitalsCard() {
    final associatedHospital = widget.labData['associatedHospital'];
    final affiliatedHospitals = widget.labData['affiliatedHospitals'];

    List<String> hospitals = [];

    if (associatedHospital != null &&
        associatedHospital.toString().isNotEmpty) {
      hospitals.add(associatedHospital.toString());
    }

    if (affiliatedHospitals != null && affiliatedHospitals is List) {
      for (var hospital in affiliatedHospitals) {
        if (hospital != null && hospital.toString().isNotEmpty) {
          hospitals.add(hospital.toString());
        }
      }
    }

    if (hospitals.isEmpty) {
      return _buildInfoCard(
        title: 'Associated Hospitals',
        icon: Icons.local_hospital_outlined,
        children: [
          _buildInfoRow(
            'Associated Hospitals',
            'No associated hospitals',
            valueColor: Colors.grey,
          ),
        ],
      );
    }

    return _buildInfoCard(
      title: 'Associated Hospitals',
      icon: Icons.local_hospital_outlined,
      children: hospitals
          .map((hospital) => _buildInfoRow(
                'Hospital',
                hospital,
              ))
          .toList(),
    );
  }

  Widget _buildQRSection() {
    return _buildInfoCard(
      title: 'QR Section',
      icon: Icons.qr_code,
      children: [
        _buildInfoRow(
          'ARC ID',
          widget.labData['arcId'] ?? 'Not provided',
        ),
        _buildInfoRow(
          'Lab ID',
          widget.labData['uid'] ?? 'Not provided',
        ),
        _buildInfoRow(
          'Account Type',
          'Lab',
        ),
      ],
    );
  }

  Widget _buildDisclaimerCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.orange.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline,
                color: Colors.orange[700],
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                'Important Notice',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange[700],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'This information is provided for reference purposes only. '
            'Please contact the lab directly for appointments, '
            'test bookings, or detailed information.',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.orange[700],
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
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
          Row(
            children: [
              Icon(
                icon,
                color: _secondary,
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF2E2E2E),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(
    String label,
    String value, {
    bool isMultiline = false,
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF6B7280),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: valueColor ?? const Color(0xFF2E2E2E),
              ),
              maxLines: isMultiline ? null : 1,
              overflow: isMultiline ? null : TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
