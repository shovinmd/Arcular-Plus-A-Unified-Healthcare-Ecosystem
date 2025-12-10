import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class DoctorQRScanResultScreen extends StatefulWidget {
  final Map<String, dynamic> doctorData;

  const DoctorQRScanResultScreen({
    super.key,
    required this.doctorData,
  });

  @override
  State<DoctorQRScanResultScreen> createState() =>
      _DoctorQRScanResultScreenState();
}

class _DoctorQRScanResultScreenState extends State<DoctorQRScanResultScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Doctor Information',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF2196F3), // Doctor blue
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF2196F3), Color(0xFF64B5F6), Color(0xFFE3F2FD)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: _buildDoctorInfo(),
        ),
      ),
    );
  }

  Widget _buildDoctorInfo() {
    if (widget.doctorData.isEmpty) {
      return const Center(
        child: Text('No doctor data available'),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with doctor name and ARC ID
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

          // Location Information
          _buildLocationCard(),
          const SizedBox(height: 24),

          // Specializations
          _buildSpecializationsCard(),
          const SizedBox(height: 24),

          // Services & Affiliations
          _buildServicesCard(),
          const SizedBox(height: 24),

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
          if (widget.doctorData['profileImageUrl'] != null &&
              widget.doctorData['profileImageUrl'].toString().isNotEmpty) ...[
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFF2196F3),
                  width: 4,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF2196F3).withOpacity(0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: ClipOval(
                child: Image.network(
                  widget.doctorData['profileImageUrl'].toString(),
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      color: const Color(0xFF2196F3).withOpacity(0.1),
                      child: Center(
                        child: CircularProgressIndicator(
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded /
                                  loadingProgress.expectedTotalBytes!
                              : null,
                          color: const Color(0xFF2196F3),
                        ),
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: const Color(0xFF2196F3).withOpacity(0.1),
                      child: const Icon(
                        Icons.person,
                        size: 60,
                        color: Color(0xFF2196F3),
                      ),
                    );
                  },
                ),
              ),
            ),
          ] else ...[
            // Default doctor icon
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF2196F3).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.person_outline,
                size: 48,
                color: Color(0xFF2196F3),
              ),
            ),
          ],
          const SizedBox(height: 16),

          // Doctor name
          Text(
            widget.doctorData['fullName'] ?? 'Unknown Doctor',
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
            'ARC ID: ${widget.doctorData['healthQrId'] ?? widget.doctorData['arcId'] ?? widget.doctorData['uid'] ?? 'N/A'}',
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
          widget.doctorData['fullName'] ?? 'Not provided',
        ),
        _buildInfoRow(
          'Email',
          widget.doctorData['email'] ?? 'Not provided',
        ),
        _buildInfoRow(
          'Mobile Number',
          widget.doctorData['mobileNumber'] ?? 'Not provided',
        ),
        _buildInfoRow(
          'Gender',
          widget.doctorData['gender'] ?? 'Not specified',
        ),
        _buildInfoRow(
          'Date of Birth',
          widget.doctorData['dateOfBirth'] != null
              ? DateTime.parse(widget.doctorData['dateOfBirth'])
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
          'Medical Registration Number',
          widget.doctorData['medicalRegistrationNumber'] ?? 'Not provided',
        ),
        _buildInfoRow(
          'License Number',
          widget.doctorData['licenseNumber'] ?? 'Not provided',
        ),
        _buildInfoRow(
          'Experience',
          '${widget.doctorData['experienceYears'] ?? 0} years',
        ),
        _buildInfoRow(
          'Consultation Fee',
          widget.doctorData['consultationFee'] != null
              ? '₹${widget.doctorData['consultationFee']}'
              : 'Not specified',
        ),
        _buildInfoRow(
          'Qualification',
          widget.doctorData['qualification'] ?? 'Not provided',
        ),
      ],
    );
  }

  Widget _buildContactCard() {
    final hasMobile = widget.doctorData['mobileNumber'] != null &&
        widget.doctorData['mobileNumber'].toString().isNotEmpty;
    final hasAltPhone = widget.doctorData['altPhoneNumber'] != null &&
        widget.doctorData['altPhoneNumber'].toString().isNotEmpty;
    final hasEmail = widget.doctorData['email'] != null &&
        widget.doctorData['email'].toString().isNotEmpty;

    if (!hasMobile && !hasAltPhone && !hasEmail) {
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
        if (hasMobile) ...[
          _buildInfoRow(
            'Primary Mobile',
            widget.doctorData['mobileNumber'].toString(),
          ),
        ],
        if (hasAltPhone) ...[
          _buildInfoRow(
            'Alternate Mobile',
            widget.doctorData['altPhoneNumber'].toString(),
          ),
        ],
        if (hasEmail) ...[
          _buildInfoRow(
            'Email',
            widget.doctorData['email'].toString(),
          ),
        ],
      ],
    );
  }

  Widget _buildLocationCard() {
    final hasAddress = widget.doctorData['address'] != null &&
        widget.doctorData['address'].toString().isNotEmpty;
    final hasCity = widget.doctorData['city'] != null &&
        widget.doctorData['city'].toString().isNotEmpty;
    final hasState = widget.doctorData['state'] != null &&
        widget.doctorData['state'].toString().isNotEmpty;
    final hasPincode = widget.doctorData['pincode'] != null &&
        widget.doctorData['pincode'].toString().isNotEmpty;

    if (!hasAddress && !hasCity && !hasState && !hasPincode) {
      return _buildInfoCard(
        title: 'Location Information',
        icon: Icons.location_on_outlined,
        children: [
          _buildInfoRow(
            'Location Information',
            'No location details provided',
            valueColor: Colors.grey,
          ),
        ],
      );
    }

    return _buildInfoCard(
      title: 'Location Information',
      icon: Icons.location_on_outlined,
      children: [
        if (hasAddress) ...[
          _buildInfoRow(
            'Address',
            widget.doctorData['address'].toString(),
            isMultiline: true,
          ),
        ],
        if (hasCity) ...[
          _buildInfoRow(
            'City',
            widget.doctorData['city'].toString(),
          ),
        ],
        if (hasState) ...[
          _buildInfoRow(
            'State',
            widget.doctorData['state'].toString(),
          ),
        ],
        if (hasPincode) ...[
          _buildInfoRow(
            'Pincode',
            widget.doctorData['pincode'].toString(),
          ),
        ],
      ],
    );
  }

  Widget _buildSpecializationsCard() {
    final specialization = widget.doctorData['specialization'] ?? '';
    final specializations = widget.doctorData['specializations'] ?? [];

    String specializationText = '';
    if (specialization.isNotEmpty) {
      specializationText = specialization;
    } else if (specializations.isNotEmpty) {
      specializationText = specializations.join(', ');
    } else {
      specializationText = 'Not specified';
    }

    return _buildInfoCard(
      title: 'Specializations',
      icon: Icons.medical_information,
      children: [
        _buildInfoRow(
          'Specializations',
          specializationText,
          isMultiline: true,
        ),
      ],
    );
  }

  Widget _buildServicesCard() {
    return _buildInfoCard(
      title: 'Services & Affiliations',
      icon: Icons.health_and_safety,
      children: [
        _buildInfoRow(
          'Hospital Affiliation',
          widget.doctorData['hospitalAffiliation'] ?? 'Not specified',
        ),
        _buildInfoRow(
          'About',
          widget.doctorData['about'] ?? 'No additional information provided',
          isMultiline: true,
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
            'Please contact the doctor directly for appointments, '
            'consultations, or detailed medical information.',
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
                color: const Color(0xFF2196F3),
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
