import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class PharmacyQRScanResultScreen extends StatefulWidget {
  final Map<String, dynamic> pharmacyData;

  const PharmacyQRScanResultScreen({
    super.key,
    required this.pharmacyData,
  });

  @override
  State<PharmacyQRScanResultScreen> createState() =>
      _PharmacyQRScanResultScreenState();
}

class _PharmacyQRScanResultScreenState
    extends State<PharmacyQRScanResultScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Pharmacy Information',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFFFFD700), // Pharmacy yellow
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFFFD700), Color(0xFFFFA500), Color(0xFFFFF8E1)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: _buildPharmacyInfo(),
        ),
      ),
    );
  }

  Widget _buildPharmacyInfo() {
    if (widget.pharmacyData.isEmpty) {
      return const Center(
        child: Text('No pharmacy data available'),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with pharmacy name and ARC ID
          _buildHeader(),
          const SizedBox(height: 24),

          // Basic Information
          _buildBasicInfoCard(),
          const SizedBox(height: 24),

          // Pharmacy Information
          _buildPharmacyInfoCard(),
          const SizedBox(height: 24),

          // Contact Information
          _buildContactCard(),
          const SizedBox(height: 24),

          // Location Information
          _buildLocationCard(),
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
          if (widget.pharmacyData['profileImageUrl'] != null &&
              widget.pharmacyData['profileImageUrl'].toString().isNotEmpty) ...[
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFFFFD700),
                  width: 4,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFFD700).withOpacity(0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: ClipOval(
                child: Image.network(
                  widget.pharmacyData['profileImageUrl'].toString(),
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      color: const Color(0xFFFFD700).withOpacity(0.1),
                      child: Center(
                        child: CircularProgressIndicator(
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded /
                                  loadingProgress.expectedTotalBytes!
                              : null,
                          color: const Color(0xFFFFD700),
                        ),
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: const Color(0xFFFFD700).withOpacity(0.1),
                      child: const Icon(
                        Icons.local_pharmacy,
                        size: 60,
                        color: Color(0xFFFFD700),
                      ),
                    );
                  },
                ),
              ),
            ),
          ] else ...[
            // Default pharmacy icon
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFFFD700).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.local_pharmacy_outlined,
                size: 48,
                color: Color(0xFFFFD700),
              ),
            ),
          ],
          const SizedBox(height: 16),

          // Pharmacy name
          Text(
            widget.pharmacyData['pharmacyName'] ?? 'Unknown Pharmacy',
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
            'ARC ID: ${widget.pharmacyData['arcId'] ?? 'N/A'}',
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
          'Pharmacy Name',
          widget.pharmacyData['pharmacyName'] ?? 'Not provided',
        ),
        _buildInfoRow(
          'Pharmacist Name',
          widget.pharmacyData['pharmacistName'] ?? 'Not provided',
        ),
        _buildInfoRow(
          'License Number',
          widget.pharmacyData['licenseNumber'] ?? 'Not provided',
        ),
        _buildInfoRow(
          'Approval Status',
          widget.pharmacyData['approvalStatus'] ?? 'Unknown',
          valueColor: widget.pharmacyData['isApproved'] == true
              ? Colors.green
              : Colors.orange,
        ),
      ],
    );
  }

  Widget _buildPharmacyInfoCard() {
    return _buildInfoCard(
      title: 'Pharmacy Details',
      icon: Icons.local_pharmacy,
      children: [
        _buildInfoRow(
          'Pharmacist Qualification',
          widget.pharmacyData['pharmacistQualification'] ?? 'Not specified',
        ),
        _buildInfoRow(
          'License Number',
          widget.pharmacyData['licenseNumber'] ?? 'Not specified',
        ),
        _buildInfoRow(
          'License Expiry',
          widget.pharmacyData['licenseExpiry'] ?? 'Not specified',
        ),
      ],
    );
  }

  Widget _buildContactCard() {
    final hasMobile = widget.pharmacyData['mobileNumber'] != null &&
        widget.pharmacyData['mobileNumber'].toString().isNotEmpty;
    final hasAlternate = widget.pharmacyData['alternateMobile'] != null &&
        widget.pharmacyData['alternateMobile'].toString().isNotEmpty;
    final hasEmail = widget.pharmacyData['email'] != null &&
        widget.pharmacyData['email'].toString().isNotEmpty;

    if (!hasMobile && !hasAlternate && !hasEmail) {
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
            widget.pharmacyData['mobileNumber'].toString(),
          ),
        ],
        if (hasAlternate) ...[
          _buildInfoRow(
            'Alternate Mobile',
            widget.pharmacyData['alternateMobile'].toString(),
          ),
        ],
        if (hasEmail) ...[
          _buildInfoRow(
            'Email',
            widget.pharmacyData['email'].toString(),
          ),
        ],
      ],
    );
  }

  Widget _buildLocationCard() {
    final hasAddress = widget.pharmacyData['address'] != null &&
        widget.pharmacyData['address'].toString().isNotEmpty;
    final hasCity = widget.pharmacyData['city'] != null &&
        widget.pharmacyData['city'].toString().isNotEmpty;
    final hasState = widget.pharmacyData['state'] != null &&
        widget.pharmacyData['state'].toString().isNotEmpty;
    final hasPincode = widget.pharmacyData['pincode'] != null &&
        widget.pharmacyData['pincode'].toString().isNotEmpty;

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
            widget.pharmacyData['address'].toString(),
            isMultiline: true,
          ),
        ],
        if (hasCity) ...[
          _buildInfoRow(
            'City',
            widget.pharmacyData['city'].toString(),
          ),
        ],
        if (hasState) ...[
          _buildInfoRow(
            'State',
            widget.pharmacyData['state'].toString(),
          ),
        ],
        if (hasPincode) ...[
          _buildInfoRow(
            'Pincode',
            widget.pharmacyData['pincode'].toString(),
          ),
        ],
      ],
    );
  }

  Widget _buildServicesCard() {
    final services = widget.pharmacyData['services'] ?? [];
    final drugsAvailable = widget.pharmacyData['drugsAvailable'] ?? [];

    return _buildInfoCard(
      title: 'Services & Products',
      icon: Icons.medical_services,
      children: [
        if (services.isNotEmpty) ...[
          _buildInfoRow(
            'Services Provided',
            services.join(', '),
            isMultiline: true,
          ),
          const SizedBox(height: 12),
        ],
        if (drugsAvailable.isNotEmpty) ...[
          _buildInfoRow(
            'Drugs Available',
            drugsAvailable.join(', '),
            isMultiline: true,
          ),
        ],
        if (services.isEmpty && drugsAvailable.isEmpty)
          _buildInfoRow(
            'Services & Products',
            'No services or products specified',
            valueColor: Colors.grey,
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
            'Please contact the pharmacy directly for medicine availability, '
            'pricing, or detailed information.',
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
                color: const Color(0xFFFFD700),
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
