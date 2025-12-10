import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NurseQRScanResultScreen extends StatefulWidget {
  final Map<String, dynamic> nurseData;

  const NurseQRScanResultScreen({
    super.key,
    required this.nurseData,
  });

  @override
  State<NurseQRScanResultScreen> createState() =>
      _NurseQRScanResultScreenState();
}

class _NurseQRScanResultScreenState extends State<NurseQRScanResultScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Nurse Information',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFFC084FC), // Nurse purple
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFC084FC), Color(0xFFA78BFA), Color(0xFFF6F0FF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: _buildNurseInfo(),
        ),
      ),
    );
  }

  Widget _buildNurseInfo() {
    if (widget.nurseData.isEmpty) {
      return const Center(
        child: Text('No nurse data available'),
      );
    }

    return FutureBuilder<SharedPreferences>(
      future: SharedPreferences.getInstance(),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          final cachedUrl = snapshot.data!.getString('nurse_profile_image_url');
          if (cachedUrl != null && cachedUrl.isNotEmpty) {
            widget.nurseData['cachedProfileImageUrl'] = cachedUrl;
          }
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with nurse name and ARC ID
              _buildHeader(),
              const SizedBox(height: 24),

              // Basic Information
              _buildBasicInfoCard(),
              const SizedBox(height: 24),

              // Professional Information
              _buildProfessionalInfoCard(),
              const SizedBox(height: 24),

              // Contact Information
              _buildContactCard(),
              const SizedBox(height: 24),

              // Hospital Affiliation
              _buildHospitalAffiliationCard(),
              const SizedBox(height: 24),

              // License & Approval
              _buildLicenseApprovalCard(),
              const SizedBox(height: 24),

              // Disclaimer
              _buildDisclaimerCard(),
            ],
          ),
        );
      },
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
          // Profile Image or Icon (prefer locally cached URL if available)
          if ((widget.nurseData['cachedProfileImageUrl'] ??
                      widget.nurseData['profileImageUrl']) !=
                  null &&
              (widget.nurseData['cachedProfileImageUrl'] ??
                      widget.nurseData['profileImageUrl'])
                  .toString()
                  .isNotEmpty) ...[
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFFC084FC),
                  width: 4,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFC084FC).withOpacity(0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: ClipOval(
                child: Image.network(
                  (widget.nurseData['cachedProfileImageUrl'] ??
                          widget.nurseData['profileImageUrl'])
                      .toString(),
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      color: const Color(0xFFC084FC).withOpacity(0.1),
                      child: Center(
                        child: CircularProgressIndicator(
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded /
                                  loadingProgress.expectedTotalBytes!
                              : null,
                          color: const Color(0xFFC084FC),
                        ),
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: const Color(0xFFC084FC).withOpacity(0.1),
                      child: const Icon(
                        Icons.person,
                        size: 60,
                        color: Color(0xFFC084FC),
                      ),
                    );
                  },
                ),
              ),
            ),
          ] else ...[
            // Default nurse icon
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFC084FC).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.person_outline,
                size: 48,
                color: Color(0xFFC084FC),
              ),
            ),
          ],
          const SizedBox(height: 16),

          // Nurse name
          Text(
            widget.nurseData['fullName'] ?? 'Unknown Nurse',
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
            'ARC ID: ${widget.nurseData['healthQrId'] ?? widget.nurseData['arcId'] ?? widget.nurseData['uid'] ?? 'N/A'}',
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
          'Full Name',
          widget.nurseData['fullName'] ?? 'Not provided',
        ),
        _buildInfoRow(
          'Email',
          widget.nurseData['email'] ?? 'Not provided',
        ),
        _buildInfoRow(
          'Mobile Number',
          widget.nurseData['mobileNumber'] ?? 'Not provided',
        ),
        _buildInfoRow(
          'Gender',
          widget.nurseData['gender'] ?? 'Not specified',
        ),
        _buildInfoRow(
          'Date of Birth',
          widget.nurseData['dateOfBirth'] != null
              ? DateTime.parse(widget.nurseData['dateOfBirth'])
                  .toString()
                  .split(' ')[0]
              : 'Not provided',
        ),
      ],
    );
  }

  Widget _buildProfessionalInfoCard() {
    return _buildInfoCard(
      title: 'Professional Information',
      icon: Icons.medical_services,
      children: [
        _buildInfoRow(
          'Qualification',
          widget.nurseData['qualification'] ?? 'Not provided',
        ),
        _buildInfoRow(
          'Experience',
          '${widget.nurseData['experienceYears'] ?? 0} years',
        ),
        _buildInfoRow(
          'License Number',
          widget.nurseData['licenseNumber'] ?? 'Not provided',
        ),
        _buildInfoRow(
          'Registration Number',
          widget.nurseData['registrationNumber'] ?? 'Not provided',
        ),
        _buildInfoRow(
          'Specialization',
          widget.nurseData['specialization'] ?? 'Not specified',
        ),
      ],
    );
  }

  Widget _buildContactCard() {
    final hasAddress = widget.nurseData['address'] != null &&
        widget.nurseData['address'].toString().isNotEmpty;
    final hasCity = widget.nurseData['city'] != null &&
        widget.nurseData['city'].toString().isNotEmpty;
    final hasState = widget.nurseData['state'] != null &&
        widget.nurseData['state'].toString().isNotEmpty;
    final hasPincode = widget.nurseData['pincode'] != null &&
        widget.nurseData['pincode'].toString().isNotEmpty;

    if (!hasAddress && !hasCity && !hasState && !hasPincode) {
      return _buildInfoCard(
        title: 'Contact Information',
        icon: Icons.phone_outlined,
        children: [
          _buildInfoRow(
            'Contact Information',
            'No contact details provided',
            valueColor: Colors.grey,
          ),
        ],
      );
    }

    return _buildInfoCard(
      title: 'Contact Information',
      icon: Icons.phone_outlined,
      children: [
        if (hasAddress) ...[
          _buildInfoRow(
            'Address',
            widget.nurseData['address'].toString(),
            isMultiline: true,
          ),
        ],
        if (hasCity) ...[
          _buildInfoRow(
            'City',
            widget.nurseData['city'].toString(),
          ),
        ],
        if (hasState) ...[
          _buildInfoRow(
            'State',
            widget.nurseData['state'].toString(),
          ),
        ],
        if (hasPincode) ...[
          _buildInfoRow(
            'Pincode',
            widget.nurseData['pincode'].toString(),
          ),
        ],
      ],
    );
  }

  Widget _buildHospitalAffiliationCard() {
    final affiliatedHospitals =
        widget.nurseData['affiliatedHospitals'] as List<dynamic>? ?? [];
    final currentHospital =
        widget.nurseData['hospitalAffiliation'] ?? 'Not specified';

    return _buildInfoCard(
      title: 'Hospital Affiliation',
      icon: Icons.local_hospital,
      children: [
        _buildInfoRow(
          'Current Hospital',
          currentHospital,
        ),
        _buildInfoRow(
          'Role',
          widget.nurseData['role'] ?? 'Nurse',
        ),
        if (affiliatedHospitals.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            'All Affiliated Hospitals:',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF2E2E2E),
            ),
          ),
          const SizedBox(height: 8),
          ...affiliatedHospitals
              .map((hospital) => _buildHospitalItem(hospital))
              .toList(),
        ],
      ],
    );
  }

  Widget _buildHospitalItem(dynamic hospital) {
    final hospitalName = hospital['hospitalName'] ?? 'Unknown Hospital';
    final role = hospital['role'] ?? 'Staff';
    final startDate = hospital['startDate'] != null
        ? DateTime.tryParse(hospital['startDate'].toString())
        : null;
    final isActive = hospital['isActive'] ?? true;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  hospitalName,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF2E2E2E),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isActive ? Colors.green[100] : Colors.grey[200],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  isActive ? 'Active' : 'Inactive',
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: isActive ? Colors.green[700] : Colors.grey[600],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Role: $role',
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: const Color(0xFF6B7280),
            ),
          ),
          if (startDate != null) ...[
            const SizedBox(height: 2),
            Text(
              'Since: ${startDate.day}/${startDate.month}/${startDate.year}',
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: const Color(0xFF6B7280),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLicenseApprovalCard() {
    return _buildInfoCard(
      title: 'License & Approval',
      icon: Icons.verified_user,
      children: [
        _buildInfoRow(
          'Approval Status',
          widget.nurseData['isApproved'] == true ? 'Approved' : 'Pending',
          valueColor: widget.nurseData['isApproved'] == true
              ? Colors.green
              : Colors.orange,
        ),
        _buildInfoRow(
          'Registration Date',
          widget.nurseData['registrationDate'] != null
              ? DateTime.parse(widget.nurseData['registrationDate'])
                  .toString()
                  .split(' ')[0]
              : 'Not provided',
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
            'Please contact the nurse directly for appointments, '
            'medical assistance, or detailed information.',
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
                color: const Color(0xFFC084FC),
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
