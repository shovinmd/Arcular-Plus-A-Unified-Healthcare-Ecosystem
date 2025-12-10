import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class HospitalQRScanResultScreen extends StatefulWidget {
  final Map<String, dynamic> hospitalData;

  const HospitalQRScanResultScreen({
    super.key,
    required this.hospitalData,
  });

  @override
  State<HospitalQRScanResultScreen> createState() =>
      _HospitalQRScanResultScreenState();
}

class _HospitalQRScanResultScreenState
    extends State<HospitalQRScanResultScreen> {
  String _getServiceProviderTitle() {
    final type = widget.hospitalData['type'] ?? 'hospital';
    switch (type) {
      case 'doctor':
        return 'Doctor Information';
      case 'nurse':
        return 'Nurse Information';
      case 'lab':
        return 'Lab Information';
      case 'pharmacy':
        return 'Pharmacy Information';
      case 'hospital':
      default:
        return 'Hospital Information';
    }
  }

  String _getServiceProviderName() {
    final type = widget.hospitalData['type'] ?? 'hospital';
    switch (type) {
      case 'doctor':
        return widget.hospitalData['fullName'] ?? 'Unknown Doctor';
      case 'nurse':
        return widget.hospitalData['fullName'] ?? 'Unknown Nurse';
      case 'lab':
        return widget.hospitalData['labName'] ?? 'Lab';
      case 'pharmacy':
        return widget.hospitalData['pharmacyName'] ?? 'Unknown Pharmacy';
      case 'hospital':
      default:
        return widget.hospitalData['hospitalName'] ?? 'Unknown Hospital';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _getServiceProviderTitle(),
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF2E7D32), // Hospital green
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF2E7D32), Color(0xFF4CAF50), Color(0xFFE8F5E8)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: _buildHospitalInfo(),
        ),
      ),
    );
  }

  Widget _buildHospitalInfo() {
    if (widget.hospitalData.isEmpty) {
      return const Center(
        child: Text('No hospital data available'),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with hospital name and ARC ID
          _buildHeader(),
          const SizedBox(height: 24),

          // Basic Information
          _buildBasicInfoCard(),
          const SizedBox(height: 24),

          // Hospital Information
          _buildHospitalInfoCard(),
          const SizedBox(height: 24),

          // Contact Information
          _buildContactCard(),
          const SizedBox(height: 24),

          // Location Information
          _buildLocationCard(),
          const SizedBox(height: 24),

          // Departments and Facilities
          _buildDepartmentsCard(),
          const SizedBox(height: 24),

          // Services Available
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
          if (widget.hospitalData['profileImageUrl'] != null &&
              widget.hospitalData['profileImageUrl'].toString().isNotEmpty) ...[
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFF2E7D32),
                  width: 4,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF2E7D32).withOpacity(0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: ClipOval(
                child: Image.network(
                  widget.hospitalData['profileImageUrl'].toString(),
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      color: const Color(0xFF2E7D32).withOpacity(0.1),
                      child: Center(
                        child: CircularProgressIndicator(
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded /
                                  loadingProgress.expectedTotalBytes!
                              : null,
                          color: const Color(0xFF2E7D32),
                        ),
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: const Color(0xFF2E7D32).withOpacity(0.1),
                      child: const Icon(
                        Icons.local_hospital,
                        size: 60,
                        color: Color(0xFF2E7D32),
                      ),
                    );
                  },
                ),
              ),
            ),
          ] else ...[
            // Default hospital icon
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF2E7D32).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.local_hospital_outlined,
                size: 48,
                color: Color(0xFF2E7D32),
              ),
            ),
          ],
          const SizedBox(height: 16),

          // Service provider name
          Text(
            _getServiceProviderName(),
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
            'ARC ID: ${widget.hospitalData['arcId'] ?? 'N/A'}',
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
          widget.hospitalData['fullName'] ?? 'Not provided',
        ),
        _buildInfoRow(
          'Hospital Type',
          widget.hospitalData['hospitalType'] ?? 'Not specified',
        ),
        _buildInfoRow(
          'Registration Number',
          widget.hospitalData['registrationNumber'] ?? 'Not provided',
        ),
        _buildInfoRow(
          'Approval Status',
          widget.hospitalData['approvalStatus'] ?? 'Unknown',
          valueColor: widget.hospitalData['isApproved'] == true
              ? Colors.green
              : Colors.orange,
        ),
      ],
    );
  }

  Widget _buildHospitalInfoCard() {
    return _buildInfoCard(
      title: 'Hospital Details',
      icon: Icons.local_hospital,
      children: [
        _buildInfoRow(
          'Number of Beds',
          widget.hospitalData['numberOfBeds']?.toString() ?? 'Not specified',
        ),
        _buildInfoRow(
          'Pharmacy Available',
          widget.hospitalData['hasPharmacy'] == true ? 'Yes' : 'No',
          valueColor: widget.hospitalData['hasPharmacy'] == true
              ? Colors.green
              : Colors.red,
        ),
        _buildInfoRow(
          'Laboratory Available',
          widget.hospitalData['hasLab'] == true ? 'Yes' : 'No',
          valueColor:
              widget.hospitalData['hasLab'] == true ? Colors.green : Colors.red,
        ),
      ],
    );
  }

  Widget _buildContactCard() {
    final hasMobile = widget.hospitalData['mobileNumber'] != null &&
        widget.hospitalData['mobileNumber'].toString().isNotEmpty;
    final hasAlternate = widget.hospitalData['alternateMobile'] != null &&
        widget.hospitalData['alternateMobile'].toString().isNotEmpty;
    final hasEmail = widget.hospitalData['email'] != null &&
        widget.hospitalData['email'].toString().isNotEmpty;
    final hasHospitalPhone = widget.hospitalData['hospitalPhone'] != null &&
        widget.hospitalData['hospitalPhone'].toString().isNotEmpty;
    final hasHospitalEmail = widget.hospitalData['hospitalEmail'] != null &&
        widget.hospitalData['hospitalEmail'].toString().isNotEmpty;

    if (!hasMobile &&
        !hasAlternate &&
        !hasEmail &&
        !hasHospitalPhone &&
        !hasHospitalEmail) {
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
            widget.hospitalData['mobileNumber'].toString(),
          ),
        ],
        if (hasAlternate) ...[
          _buildInfoRow(
            'Alternate Mobile',
            widget.hospitalData['alternateMobile'].toString(),
          ),
        ],
        if (hasHospitalPhone) ...[
          _buildInfoRow(
            'Hospital Phone',
            widget.hospitalData['hospitalPhone'].toString(),
          ),
        ],
        if (hasEmail) ...[
          _buildInfoRow(
            'Personal Email',
            widget.hospitalData['email'].toString(),
          ),
        ],
        if (hasHospitalEmail) ...[
          _buildInfoRow(
            'Hospital Email',
            widget.hospitalData['hospitalEmail'].toString(),
          ),
        ],
      ],
    );
  }

  Widget _buildLocationCard() {
    final hasAddress = widget.hospitalData['address'] != null &&
        widget.hospitalData['address'].toString().isNotEmpty;
    final hasCity = widget.hospitalData['city'] != null &&
        widget.hospitalData['city'].toString().isNotEmpty;
    final hasState = widget.hospitalData['state'] != null &&
        widget.hospitalData['state'].toString().isNotEmpty;
    final hasPincode = widget.hospitalData['pincode'] != null &&
        widget.hospitalData['pincode'].toString().isNotEmpty;
    final hasHospitalAddress = widget.hospitalData['hospitalAddress'] != null &&
        widget.hospitalData['hospitalAddress'].toString().isNotEmpty;

    if (!hasAddress &&
        !hasCity &&
        !hasState &&
        !hasPincode &&
        !hasHospitalAddress) {
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
        if (hasHospitalAddress) ...[
          _buildInfoRow(
            'Hospital Address',
            widget.hospitalData['hospitalAddress'].toString(),
            isMultiline: true,
          ),
        ] else if (hasAddress) ...[
          _buildInfoRow(
            'Address',
            widget.hospitalData['address'].toString(),
            isMultiline: true,
          ),
        ],
        if (hasCity) ...[
          _buildInfoRow(
            'City',
            widget.hospitalData['city'].toString(),
          ),
        ],
        if (hasState) ...[
          _buildInfoRow(
            'State',
            widget.hospitalData['state'].toString(),
          ),
        ],
        if (hasPincode) ...[
          _buildInfoRow(
            'Pincode',
            widget.hospitalData['pincode'].toString(),
          ),
        ],
      ],
    );
  }

  Widget _buildDepartmentsCard() {
    final departments = widget.hospitalData['departments'] ?? [];
    final specialFacilities = widget.hospitalData['specialFacilities'] ?? [];

    return _buildInfoCard(
      title: 'Departments & Facilities',
      icon: Icons.medical_services,
      children: [
        if (departments.isNotEmpty) ...[
          _buildInfoRow(
            'Departments',
            departments.join(', '),
            isMultiline: true,
          ),
          const SizedBox(height: 12),
        ],
        if (specialFacilities.isNotEmpty) ...[
          _buildInfoRow(
            'Special Facilities',
            specialFacilities.join(', '),
            isMultiline: true,
          ),
        ],
        if (departments.isEmpty && specialFacilities.isEmpty)
          _buildInfoRow(
            'Departments & Facilities',
            'No departments or facilities specified',
            valueColor: Colors.grey,
          ),
      ],
    );
  }

  Widget _buildServicesCard() {
    return _buildInfoCard(
      title: 'Available Services',
      icon: Icons.health_and_safety,
      children: [
        _buildInfoRow(
          'Pharmacy',
          widget.hospitalData['hasPharmacy'] == true
              ? 'Available'
              : 'Not Available',
          valueColor: widget.hospitalData['hasPharmacy'] == true
              ? Colors.green
              : Colors.red,
        ),
        _buildInfoRow(
          'Laboratory',
          widget.hospitalData['hasLab'] == true ? 'Available' : 'Not Available',
          valueColor:
              widget.hospitalData['hasLab'] == true ? Colors.green : Colors.red,
        ),
        _buildInfoRow(
          'Emergency Services',
          'Contact hospital for details',
          valueColor: Colors.blue,
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
            'Please contact the hospital directly for appointments, '
            'emergency services, or detailed information.',
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
                color: const Color(0xFF2E7D32),
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
