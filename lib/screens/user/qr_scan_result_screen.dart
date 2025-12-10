import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:arcular_plus/services/api_service.dart';
import 'package:arcular_plus/widgets/custom_button.dart';

class QRScanResultScreen extends StatefulWidget {
  final String arcId;

  const QRScanResultScreen({super.key, required this.arcId});

  @override
  State<QRScanResultScreen> createState() => _QRScanResultScreenState();
}

class _QRScanResultScreenState extends State<QRScanResultScreen> {
  Map<String, dynamic>? _userInfo;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    try {
      setState(() => _isLoading = true);
      
      print('🔍 Loading user info for identifier: ${widget.arcId}');
      final userInfo = await ApiService.getUserByArcId(widget.arcId);
      
      if (userInfo != null) {
        print('✅ User info loaded successfully:');
        print('   - Name: ${userInfo['fullName'] ?? 'Unknown'}');
        print('   - ARC ID: ${userInfo['arcId'] ?? 'N/A'}');
        print('   - UID: ${userInfo['uid'] ?? 'N/A'}');
        print('   - Profile Image: ${userInfo['profileImageUrl'] ?? 'N/A'}');
        print('   - Mobile: ${userInfo['mobileNumber'] ?? 'N/A'}');
        print('   - Address: ${userInfo['address'] ?? 'N/A'}');
        print('   - Blood Group: ${userInfo['bloodGroup'] ?? 'N/A'}');
        print('   - Insurance ID: ${userInfo['healthInsuranceId'] ?? 'N/A'}');
        print('   - Policy Number: ${userInfo['policyNumber'] ?? 'N/A'}');
        print('   - Allergies: ${userInfo['knownAllergies'] ?? []}');
        print('   - Conditions: ${userInfo['chronicConditions'] ?? []}');
        print('🔍 Detailed Contact & Address Debug:');
        print('   - Mobile Number: "${userInfo['mobileNumber']}" (type: ${userInfo['mobileNumber'].runtimeType})');
        print('   - Alternate Mobile: "${userInfo['alternateMobile']}" (type: ${userInfo['alternateMobile']?.runtimeType})');
        print('   - Address: "${userInfo['address']}" (type: ${userInfo['address']?.runtimeType})');
        print('   - City: "${userInfo['city']}" (type: ${userInfo['city']?.runtimeType})');
        print('   - State: "${userInfo['state']}" (type: ${userInfo['state']?.runtimeType})');
        print('   - Pincode: "${userInfo['pincode']}" (type: ${userInfo['pincode']?.runtimeType})');
        print('   - Emergency Contact Name: "${userInfo['emergencyContactName']}" (type: ${userInfo['emergencyContactName']?.runtimeType})');
        print('   - Emergency Contact Number: "${userInfo['emergencyContactNumber']}" (type: ${userInfo['emergencyContactNumber']?.runtimeType})');
        print('   - Emergency Contact Relation: "${userInfo['emergencyContactRelation']}" (type: ${userInfo['emergencyContactRelation']?.runtimeType})');
        print('   - All keys in userInfo: ${userInfo.keys.toList()}');
        
        setState(() {
          _userInfo = userInfo;
          _isLoading = false;
        });
      } else {
        print('❌ User info is null');
        setState(() {
          _error = 'User not found';
          _isLoading = false;
        });
      }
    } catch (e) {
      print('❌ Error loading user information: $e');
      setState(() {
        _error = 'Error loading user information: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Health Information',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF32CCBC), // Patient teal
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF32CCBC),
              Color(0xFF90F7EC),
              Color(0xFFE8F5E8)
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: _isLoading
              ? _buildLoadingState()
              : _error != null
                  ? _buildErrorState()
                  : _buildUserInfo(),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: Colors.white,
            strokeWidth: 3,
          ),
          SizedBox(height: 16),
          Text(
            'Loading health information...',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.white,
          ),
          const SizedBox(height: 16),
          Text(
            _error!,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          CustomButton(
            text: 'Retry',
            onPressed: _loadUserInfo,
            color: Colors.white,
            textColor: const Color(0xFF32CCBC),
          ),
        ],
      ),
    );
  }

  Widget _buildUserInfo() {
    if (_userInfo == null) return const SizedBox.shrink();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with user name and ARC ID
          _buildHeader(),
          const SizedBox(height: 24),

          // Profile Information
          _buildProfileCard(),
          const SizedBox(height: 24),

          // Contact Information
          _buildContactCard(),
          const SizedBox(height: 24),

          // Address Information
          _buildAddressCard(),
          const SizedBox(height: 24),

          // Emergency Contact Information
          _buildEmergencyContactCard(),
          const SizedBox(height: 24),

          // Enhanced Health Summary
          _buildEnhancedHealthSummaryCard(),
          const SizedBox(height: 24),

          // Health History
          _buildHealthHistoryCard(),
          const SizedBox(height: 24),

          // Last Medical Report
          _buildLastReportCard(),
          const SizedBox(height: 24),

          // Allergies and Conditions
          _buildAllergiesConditionsCard(),
          const SizedBox(height: 24),

          // Health Insurance Information
          if (_userInfo!['healthInsuranceId'] != null || _userInfo!['policyNumber'] != null) ...[
            _buildInsuranceCard(),
            const SizedBox(height: 24),
          ],

          // Pregnancy Information (if applicable)
          if (_userInfo!['isPregnant'] == true) ...[
            _buildPregnancyCard(),
            const SizedBox(height: 24),
          ],

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
          if (_userInfo!['profileImageUrl'] != null && _userInfo!['profileImageUrl'].toString().isNotEmpty) ...[
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFF32CCBC),
                  width: 4,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF32CCBC).withOpacity(0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: ClipOval(
                child: Image.network(
                  _userInfo!['profileImageUrl'].toString(),
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      color: const Color(0xFF32CCBC).withOpacity(0.1),
                      child: Center(
                        child: CircularProgressIndicator(
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                              : null,
                          color: const Color(0xFF32CCBC),
                        ),
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    print('❌ Error loading profile image: $error');
                    print('   - URL: ${_userInfo!['profileImageUrl']}');
                    return Container(
                      color: const Color(0xFF32CCBC).withOpacity(0.1),
                      child: const Icon(
                        Icons.person,
                        size: 60,
                        color: Color(0xFF32CCBC),
                      ),
                    );
                  },
                ),
              ),
            ),
          ] else ...[
            // Default profile icon
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF32CCBC).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.person_outline,
                size: 48,
                color: Color(0xFF32CCBC),
              ),
            ),
          ],
          const SizedBox(height: 16),

          // User name
          Text(
            _userInfo!['fullName'] ?? 'Unknown User',
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
            'ARC ID: ${_userInfo!['arcId'] ?? 'N/A'}',
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

  Widget _buildProfileCard() {
    return _buildInfoCard(
      title: 'Profile Information',
      icon: Icons.person_outline,
      children: [
        _buildInfoRow(
          'Full Name',
          _userInfo!['fullName'] ?? 'Not provided',
        ),
        _buildInfoRow(
          'Age',
          _calculateAge(_userInfo!['dateOfBirth']),
        ),
        _buildInfoRow(
          'Gender',
          _userInfo!['gender'] ?? 'Not specified',
        ),
        _buildInfoRow(
          'Blood Group',
          _userInfo!['bloodGroup'] ?? 'Not specified',
        ),
        _buildInfoRow(
          'Height',
          _userInfo!['height'] != null ? '${_userInfo!['height']} cm' : 'Not specified',
        ),
        _buildInfoRow(
          'Weight',
          _userInfo!['weight'] != null ? '${_userInfo!['weight']} kg' : 'Not specified',
        ),
        if (_userInfo!['height'] != null && _userInfo!['weight'] != null) ...[
          _buildInfoRow(
            'BMI',
            _calculateBMI(_userInfo!['height'], _userInfo!['weight']),
          ),
        ],
      ],
    );
  }

  Widget _buildContactCard() {
    final hasMobile = _userInfo!['mobileNumber'] != null && _userInfo!['mobileNumber'].toString().isNotEmpty;
    final hasAlternate = _userInfo!['alternateMobile'] != null && _userInfo!['alternateMobile'].toString().isNotEmpty;
    final hasEmail = _userInfo!['email'] != null && _userInfo!['email'].toString().isNotEmpty;
    
    print('🔍 Contact Card Debug:');
    print('   - hasMobile: $hasMobile, value: "${_userInfo!['mobileNumber']}"');
    print('   - hasAlternate: $hasAlternate, value: "${_userInfo!['alternateMobile']}"');
    print('   - hasEmail: $hasEmail, value: "${_userInfo!['email']}"');
    
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
            'Mobile Number',
            _userInfo!['mobileNumber'].toString(),
          ),
        ],
        if (hasAlternate) ...[
          _buildInfoRow(
            'Alternate Mobile',
            _userInfo!['alternateMobile'].toString(),
          ),
        ],
        if (hasEmail) ...[
          _buildInfoRow(
            'Email',
            _userInfo!['email'].toString(),
          ),
        ],
      ],
    );
  }

  Widget _buildAddressCard() {
    final hasAddress = _userInfo!['address'] != null && _userInfo!['address'].toString().isNotEmpty;
    final hasCity = _userInfo!['city'] != null && _userInfo!['city'].toString().isNotEmpty;
    final hasState = _userInfo!['state'] != null && _userInfo!['state'].toString().isNotEmpty;
    final hasPincode = _userInfo!['pincode'] != null && _userInfo!['pincode'].toString().isNotEmpty;
    
    print('🔍 Address Card Debug:');
    print('   - hasAddress: $hasAddress, value: "${_userInfo!['address']}"');
    print('   - hasCity: $hasCity, value: "${_userInfo!['city']}"');
    print('   - hasState: $hasState, value: "${_userInfo!['state']}"');
    print('   - hasPincode: $hasPincode, value: "${_userInfo!['pincode']}"');
    
    if (!hasAddress && !hasCity && !hasState && !hasPincode) {
      return _buildInfoCard(
        title: 'Address Information',
        icon: Icons.location_on_outlined,
        children: [
          _buildInfoRow(
            'Address Information',
            'No address details provided',
            valueColor: Colors.grey,
          ),
        ],
      );
    }
    
    return _buildInfoCard(
      title: 'Address Information',
      icon: Icons.location_on_outlined,
      children: [
        if (hasAddress) ...[
          _buildInfoRow(
            'Full Address',
            _userInfo!['address'].toString(),
            isMultiline: true,
          ),
        ],
        if (hasCity) ...[
          _buildInfoRow(
            'City',
            _userInfo!['city'].toString(),
          ),
        ],
        if (hasState) ...[
          _buildInfoRow(
            'State',
            _userInfo!['state'].toString(),
          ),
        ],
        if (hasPincode) ...[
          _buildInfoRow(
            'Pincode',
            _userInfo!['pincode'].toString(),
          ),
        ],
      ],
    );
  }

  Widget _buildEmergencyContactCard() {
    return _buildInfoCard(
      title: 'Emergency Contact',
      icon: Icons.emergency_outlined,
      children: [
        _buildInfoRow(
          'Name',
          _userInfo!['emergencyContactName'] ?? 'Not provided',
        ),
        _buildInfoRow(
          'Phone',
          _userInfo!['emergencyContactNumber'] ?? 'Not provided',
        ),
        _buildInfoRow(
          'Relation',
          _userInfo!['emergencyContactRelation'] ?? 'Not provided',
        ),
      ],
    );
  }

  Widget _buildEnhancedHealthSummaryCard() {
    final healthSummary = _userInfo!['healthSummary'] ?? {};
    
    return _buildInfoCard(
      title: 'Enhanced Health Summary',
      icon: Icons.health_and_safety_outlined,
      children: [
        _buildInfoRow(
          'Blood Group',
          _userInfo!['bloodGroup'] ?? 'Not specified',
        ),
        _buildInfoRow(
          'Allergies',
          healthSummary['hasAllergies'] == true ? 'Yes' : 'No',
        ),
        _buildInfoRow(
          'Chronic Conditions',
          healthSummary['hasChronicConditions'] == true ? 'Yes' : 'No',
        ),
        _buildInfoRow(
          'Pregnancy Status',
          healthSummary['isPregnant'] == true ? 'Pregnant' : 'Not pregnant',
        ),
        _buildInfoRow(
          'Health Insurance',
          _userInfo!['healthInsuranceId'] != null ? 'Yes' : 'No',
        ),
        if (_userInfo!['healthInsuranceId'] != null) ...[
          _buildInfoRow(
            'Insurance ID',
            _userInfo!['healthInsuranceId'],
          ),
        ],
        if (_userInfo!['policyNumber'] != null && _userInfo!['policyNumber'].isNotEmpty) ...[
          _buildInfoRow(
            'Policy Number',
            _userInfo!['policyNumber'],
          ),
        ],
        if (_userInfo!['policyExpiryDate'] != null) ...[
          _buildInfoRow(
            'Policy Expiry',
            _formatDate(_userInfo!['policyExpiryDate']),
          ),
        ],
      ],
    );
  }

  Widget _buildHealthHistoryCard() {
    return _buildInfoCard(
      title: 'Health History',
      icon: Icons.history,
      children: [
        _buildInfoRow(
          'Previous Pregnancies',
          _userInfo!['numberOfPreviousPregnancies']?.toString() ?? '0',
        ),
        if (_userInfo!['lastPregnancyYear'] != null) ...[
          _buildInfoRow(
            'Last Pregnancy Year',
            _userInfo!['lastPregnancyYear'].toString(),
          ),
        ],
        if (_userInfo!['pregnancyHealthNotes'] != null && _userInfo!['pregnancyHealthNotes'].isNotEmpty) ...[
          _buildInfoRow(
            'Pregnancy Health Notes',
            _userInfo!['pregnancyHealthNotes'],
            isMultiline: true,
          ),
        ],
        _buildInfoRow(
          'Menstrual Cycle Tracking',
          _userInfo!['lastPeriodStartDate'] != null ? 'Enabled' : 'Not enabled',
        ),
      ],
    );
  }

  Widget _buildLastReportCard() {
    return _buildInfoCard(
      title: 'Last Medical Report',
      icon: Icons.description,
      children: [
        _buildInfoRow(
          'Report Status',
          'No recent reports available',
        ),
        _buildInfoRow(
          'Note',
          'Medical reports are not displayed in QR scan results for privacy reasons. Contact the patient or healthcare provider for detailed reports.',
          isMultiline: true,
          valueColor: Colors.orange,
        ),
      ],
    );
  }

  Widget _buildAllergiesConditionsCard() {
    final allergies = _userInfo!['knownAllergies'] ?? [];
    final conditions = _userInfo!['chronicConditions'] ?? [];

    return _buildInfoCard(
      title: 'Medical Information',
      icon: Icons.medical_information_outlined,
      children: [
        if (allergies.isNotEmpty) ...[
          _buildInfoRow(
            'Known Allergies',
            allergies.join(', '),
            isMultiline: true,
          ),
          const SizedBox(height: 12),
        ],
        if (conditions.isNotEmpty) ...[
          _buildInfoRow(
            'Chronic Conditions',
            conditions.join(', '),
            isMultiline: true,
          ),
        ],
        if (allergies.isEmpty && conditions.isEmpty)
          _buildInfoRow(
            'Medical Information',
            'No allergies or chronic conditions reported',
          ),
      ],
    );
  }

  Widget _buildInsuranceCard() {
    return _buildInfoCard(
      title: 'Health Insurance',
      icon: Icons.health_and_safety_outlined,
      children: [
        if (_userInfo!['healthInsuranceId'] != null) ...[
          _buildInfoRow(
            'Insurance ID',
            _userInfo!['healthInsuranceId'],
          ),
        ],
        if (_userInfo!['policyNumber'] != null && _userInfo!['policyNumber'].isNotEmpty) ...[
          _buildInfoRow(
            'Policy Number',
            _userInfo!['policyNumber'],
          ),
        ],
        if (_userInfo!['policyExpiryDate'] != null) ...[
          _buildInfoRow(
            'Policy Expiry Date',
            _formatDate(_userInfo!['policyExpiryDate']),
            valueColor: Colors.orange,
          ),
        ],
        _buildInfoRow(
          'Insurance Status',
          _userInfo!['policyExpiryDate'] != null && 
          DateTime.parse(_userInfo!['policyExpiryDate'].toString()).isAfter(DateTime.now())
              ? 'Active'
              : 'Expired/Not Available',
          valueColor: _userInfo!['policyExpiryDate'] != null && 
                     DateTime.parse(_userInfo!['policyExpiryDate'].toString()).isAfter(DateTime.now())
                         ? Colors.green
                         : Colors.red,
        ),
      ],
    );
  }

  Widget _buildPregnancyCard() {
    return _buildInfoCard(
      title: 'Pregnancy Information',
      icon: Icons.pregnant_woman_outlined,
      children: [
        _buildInfoRow(
          'Status',
          'Currently Pregnant',
          valueColor: Colors.orange,
        ),
        _buildInfoRow(
          'Note',
          'This person is currently pregnant. Please provide appropriate care and attention.',
          isMultiline: true,
          valueColor: Colors.orange,
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
            'This information is provided for emergency medical purposes only. '
            'Please respect the privacy of this individual and use this information '
            'responsibly in medical situations.',
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
                color: const Color(0xFF32CCBC),
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

  // Helper method to calculate age from date of birth
  String _calculateAge(dynamic dateOfBirth) {
    if (dateOfBirth == null) return 'Not specified';
    
    try {
      DateTime dob;
      if (dateOfBirth is String) {
        dob = DateTime.parse(dateOfBirth);
      } else if (dateOfBirth is DateTime) {
        dob = dateOfBirth;
      } else {
        return 'Not specified';
      }
      
      final now = DateTime.now();
      int age = now.year - dob.year;
      if (now.month < dob.month || (now.month == dob.month && now.day < dob.day)) {
        age--;
      }
      return '$age years';
    } catch (e) {
      return 'Not specified';
    }
  }

  // Helper method to calculate BMI
  String _calculateBMI(dynamic height, dynamic weight) {
    if (height == null || weight == null) return 'Not calculated';
    
    try {
      final h = double.parse(height.toString());
      final w = double.parse(weight.toString());
      
      if (h <= 0 || w <= 0) return 'Invalid data';
      
      // Convert height from cm to meters
      final heightInMeters = h / 100;
      // Calculate BMI: weight (kg) / height (m)²
      final bmi = w / (heightInMeters * heightInMeters);
      
      return '${bmi.toStringAsFixed(1)}';
    } catch (e) {
      return 'Error calculating';
    }
  }

  // Helper method to format dates
  String _formatDate(dynamic date) {
    if (date == null) return 'Not specified';
    
    try {
      DateTime dateTime;
      if (date is String) {
        dateTime = DateTime.parse(date);
      } else if (date is DateTime) {
        dateTime = date;
      } else {
        return 'Invalid date';
      }
      
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    } catch (e) {
      return 'Invalid date';
    }
  }
}
