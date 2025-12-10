import 'dart:convert';

class UserModel {
  // Common fields for all users
  final String uid;
  final String fullName;
  final String?
      hospitalOwnerName; // For hospital owner name (required for hospitals)
  final String email;
  final String mobileNumber;
  final String? alternateMobile;
  final String?
      altPhoneNumber; // Alternative field name for backend compatibility
  final String gender; // Male/Female/Other
  final DateTime dateOfBirth;
  final String address;
  final String pincode;
  final String city;
  final String state;
  final String? aadhaarNumber;
  final String? aadhaarFrontImageUrl;
  final String? aadhaarBackImageUrl;
  final String? profileImageUrl;
  final String? ownerName; // Added for lab and pharmacy owner names
  final String type; // 'patient', 'doctor', 'hospital', 'lab', 'pharmacy'
  final String? role; // Added for ARC Staff/Superadmin support
  final DateTime createdAt;
  final String? healthQrId; // Auto-generated unique health ID
  final String? arcId;
  final String? qrCode; // QR code data URL

  // Patient-specific fields
  final String? bloodGroup;
  final double? height; // in cm
  final double? weight; // in kg
  final List<String>? knownAllergies;
  final List<String>? chronicConditions;
  final bool? isPregnant;
  final bool?
      pregnancyTrackingEnabled; // New field for pregnancy tracking toggle
  final DateTime?
      pregnancyStartDate; // New field for pregnancy start date (LMP or conception date)
  final String? babyName; // New field for baby's name
  final DateTime? dueDate; // New field for due date
  final double? babyWeightAtBirth; // New field for baby's birth weight
  // Baby measurements
  final double? bpd; // Biparietal Diameter
  final double? hc; // Head Circumference
  final double? ac; // Abdominal Circumference
  final double? fl; // Femur Length
  final int? numberOfPreviousPregnancies; // New field for pregnancy history
  final int? lastPregnancyYear; // New field for last pregnancy year
  final String? pregnancyHealthNotes; // New field for pregnancy health notes
  final bool? pregnancyPrivacyConsent; // New field for privacy consent
  final String? emergencyContactName;
  final String? emergencyContactNumber;
  final String? emergencyContactRelation;
  final String? healthInsuranceId;
  final String? policyNumber; // Health insurance policy number
  final DateTime? policyExpiryDate; // Health insurance expiry date
  final String? insuranceCardImageUrl; // Health insurance certificate image URL
  final DateTime? lastPeriodStartDate;
  final int? cycleLength;
  final int? periodDuration;
  final List<Map<String, dynamic>>? cycleHistory;

  // Location fields
  final double? longitude;
  final double? latitude;

  // Hospital-specific fields
  final String? hospitalName;
  final String? registrationNumber;
  final String? hospitalType; // Clinic/Hospital/Multi-specialty
  final String? hospitalAddress;
  final String? hospitalEmail;
  final String? hospitalPhone;
  final int? numberOfBeds;
  final bool? hasPharmacy;
  final bool? hasLab;
  final List<String>? departments;
  final List<String>? specialFacilities;
  final String? licenseDocumentUrl;
  final String? registrationCertificateUrl;
  final String? buildingPermitUrl;
  final bool? isApproved;
  final String? approvalStatus;

  // Doctor-specific fields
  final String? medicalRegistrationNumber;
  final String? licenseNumber; // Added for license number
  final String? qualification; // Added for qualification (MBBS, MD, etc.)
  final String? specialization;
  final List<String>? specializations; // New: multiple specializations
  final int? experienceYears;
  final String? hospitalAffiliation; // Added for hospital affiliation
  final String? hospitalId; // Added for hospital ID reference
  final List<String>? affiliatedHospitals;
  final List<Map<String, dynamic>>?
      enhancedAffiliatedHospitals; // Enhanced hospital affiliations
  final double? consultationFee;
  final String? certificateUrl;
  final String? about; // Added for doctor bio/about

  // Lab-specific fields
  final String? labName;
  final String? labLicenseNumber;
  final String? associatedHospital;
  final List<String>? availableTests;
  final String? labAddress;
  final bool? homeSampleCollection;
  final List<String>? servicesProvided; // Added for lab services
  final List<Map<String, dynamic>>?
      labAffiliatedHospitals; // Lab hospital affiliations

  // Pharmacy-specific fields
  final String? pharmacyName;
  final String? pharmacyLicenseNumber;
  final String? pharmacyAddress;
  final String? operatingHours;
  final bool? homeDelivery;
  final String? drugLicenseUrl;
  final String? premisesCertificateUrl; // New: premises certificate URL
  final Map<String, dynamic>?
      operatingHoursDetails; // New: detailed operating hours
  final List<String>?
      pharmacyServicesProvided; // New: services provided by pharmacy
  final List<String>? drugsAvailable; // New: types of drugs available
  final String? pharmacistName; // New: pharmacist name
  final String? pharmacistLicenseNumber; // New: pharmacist license number
  final String? pharmacistQualification; // New: pharmacist qualification
  final int? pharmacistExperienceYears; // New: pharmacist experience years
  final String? registrationDate; // New: registration date
  final String? approvedAt; // New: approval date
  final String? approvedBy; // New: approved by
  final String? approvalNotes; // New: approval notes

  // Admin-specific fields
  final String? organization;
  final String? designation;

  UserModel({
    required this.uid,
    required this.fullName,
    this.hospitalOwnerName,
    required this.email,
    required this.mobileNumber,
    this.alternateMobile,
    this.altPhoneNumber,
    required this.gender,
    required this.dateOfBirth,
    required this.address,
    required this.pincode,
    required this.city,
    required this.state,
    this.aadhaarNumber,
    this.aadhaarFrontImageUrl,
    this.aadhaarBackImageUrl,
    this.profileImageUrl,
    this.ownerName, // Added for lab and pharmacy owner names
    required this.type,
    this.role, // Added for ARC Staff/Superadmin support
    required this.createdAt,
    this.healthQrId,
    this.arcId,
    this.qrCode, // QR code data URL

    // Patient fields
    this.bloodGroup,
    this.height,
    this.weight,
    this.knownAllergies,
    this.chronicConditions,
    this.isPregnant,
    this.pregnancyTrackingEnabled,
    this.pregnancyStartDate,
    this.babyName,
    this.dueDate,
    this.babyWeightAtBirth,
    this.bpd,
    this.hc,
    this.ac,
    this.fl,
    this.numberOfPreviousPregnancies,
    this.lastPregnancyYear,
    this.pregnancyHealthNotes,
    this.pregnancyPrivacyConsent,
    this.emergencyContactName,
    this.emergencyContactNumber,
    this.emergencyContactRelation,
    this.healthInsuranceId,
    this.policyNumber, // Health insurance policy number
    this.policyExpiryDate, // Health insurance expiry date
    this.insuranceCardImageUrl,
    this.lastPeriodStartDate,
    this.cycleLength,
    this.periodDuration,
    this.cycleHistory,

    // Location fields
    this.longitude,
    this.latitude,

    // Hospital fields
    this.hospitalName,
    this.registrationNumber,
    this.hospitalType,
    this.hospitalAddress,
    this.hospitalEmail,
    this.hospitalPhone,
    this.numberOfBeds,
    this.hasPharmacy,
    this.hasLab,
    this.departments,
    this.specialFacilities,
    this.licenseDocumentUrl,
    this.registrationCertificateUrl,
    this.buildingPermitUrl,
    this.isApproved,
    this.approvalStatus,

    // Doctor fields
    this.medicalRegistrationNumber,
    this.licenseNumber,
    this.qualification,
    this.specialization,
    this.experienceYears,
    this.specializations,
    this.hospitalAffiliation,
    this.hospitalId,
    this.affiliatedHospitals,
    this.enhancedAffiliatedHospitals,
    this.consultationFee,
    this.certificateUrl,
    this.about,

    // Lab fields
    this.labName,
    this.labLicenseNumber,
    this.associatedHospital,
    this.availableTests,
    this.labAddress,
    this.homeSampleCollection,
    this.servicesProvided, // Added for lab services
    this.labAffiliatedHospitals,

    // Pharmacy fields
    this.pharmacyName,
    this.pharmacyLicenseNumber,
    this.pharmacyAddress,
    this.operatingHours,
    this.homeDelivery,
    this.drugLicenseUrl,
    this.premisesCertificateUrl,
    this.operatingHoursDetails,
    this.pharmacyServicesProvided,
    this.drugsAvailable,
    this.pharmacistName,
    this.pharmacistLicenseNumber,
    this.pharmacistQualification,
    this.pharmacistExperienceYears,
    this.registrationDate,
    this.approvedAt,
    this.approvedBy,
    this.approvalNotes,

    // Admin fields
    this.organization,
    this.designation,
  });

  // Calculate age from date of birth
  int get age {
    final now = DateTime.now();
    int age = now.year - dateOfBirth.year;
    if (now.month < dateOfBirth.month ||
        (now.month == dateOfBirth.month && now.day < dateOfBirth.day)) {
      age--;
    }
    return age;
  }

  // Calculate BMI for patients
  double? get bmi {
    if (height != null && weight != null && height! > 0) {
      final heightInMeters = height! / 100;
      return weight! / (heightInMeters * heightInMeters);
    }
    return null;
  }

  // Get BMI category
  String? get bmiCategory {
    final bmiValue = bmi;
    if (bmiValue == null) return null;

    if (bmiValue < 18.5) return 'Underweight';
    if (bmiValue < 25) return 'Normal weight';
    if (bmiValue < 30) return 'Overweight';
    return 'Obese';
  }

  // Method for JSON API
  factory UserModel.fromJson(Map<String, dynamic> json) {
    try {
      // Determine the type based on the data structure
      String determineType(Map<String, dynamic> data) {
        // If type is explicitly set, use it
        if (data['type'] != null && data['type'].toString().isNotEmpty) {
          print('🔍 Using explicit type: ${data['type']}');
          return data['type'].toString();
        }

        // Detect type based on presence of type-specific fields
        if (data['hospitalName'] != null ||
            data['registrationNumber'] != null ||
            data['hospitalType'] != null) {
          print('🔍 Detected hospital type from fields');
          return 'hospital';
        }
        if (data['medicalRegistrationNumber'] != null ||
            data['specialization'] != null ||
            data['consultationFee'] != null) {
          print(
              '🔍 Detected doctor type from fields: medicalRegistrationNumber=${data['medicalRegistrationNumber']}, specialization=${data['specialization']}');
          return 'doctor';
        }
        if (data['labName'] != null || data['labLicenseNumber'] != null) {
          print('🔍 Detected lab type from fields');
          return 'lab';
        }
        if (data['pharmacyName'] != null ||
            data['pharmacyLicenseNumber'] != null) {
          print('🔍 Detected pharmacy type from fields');
          return 'pharmacy';
        }
        if (data['organization'] != null || data['designation'] != null) {
          print('🔍 Detected admin type from fields');
          return 'admin';
        }

        // Default to patient
        print('🔍 Defaulting to patient type');
        return 'patient';
      }

      final detectedType = determineType(json);
      print('🔍 Detected user type: $detectedType from data structure');

      return UserModel(
        uid: json['uid'] ?? '',
        fullName: json['fullName'] ?? json['name'] ?? '',
        hospitalOwnerName: json['hospitalOwnerName'],
        email: json['email'] ?? '',
        mobileNumber: json['mobileNumber'] ?? json['phone'] ?? '',
        alternateMobile: json['alternateMobile'],
        altPhoneNumber: json['altPhoneNumber'],
        gender: json['gender'] ?? '',
        dateOfBirth: DateTime.parse(
            json['dateOfBirth'] ?? DateTime.now().toIso8601String()),
        address: json['address'] ?? '',
        pincode: json['pincode'] ?? '',
        city: json['city'] ?? '',
        state: json['state'] ?? '',
        aadhaarNumber: json['aadhaarNumber'],
        aadhaarFrontImageUrl: json['aadhaarFrontImageUrl'],
        aadhaarBackImageUrl: json['aadhaarBackImageUrl'],
        profileImageUrl: json['profileImageUrl'],
        ownerName: json['ownerName'], // Added for lab and pharmacy owner names
        type: detectedType,
        role: json['role'], // Added for ARC Staff/Superadmin support
        createdAt: DateTime.parse(
            json['createdAt'] ?? DateTime.now().toIso8601String()),
        healthQrId: json['healthQrId'],
        arcId: json['arcId'],
        qrCode: json['qrCode'], // QR code data URL

        // Patient fields
        bloodGroup: json['bloodGroup'],
        height: json['height']?.toDouble(),
        weight: json['weight']?.toDouble(),
        knownAllergies: json['knownAllergies'] != null
            ? List<String>.from(json['knownAllergies'])
            : null,
        chronicConditions: json['chronicConditions'] != null
            ? List<String>.from(json['chronicConditions'])
            : null,
        isPregnant: json['isPregnant'],
        pregnancyTrackingEnabled: json['pregnancyTrackingEnabled'],
        pregnancyStartDate: json['pregnancyStartDate'] != null
            ? DateTime.parse(json['pregnancyStartDate'])
            : null,
        babyName: json['babyName'],
        dueDate:
            json['dueDate'] != null ? DateTime.parse(json['dueDate']) : null,
        babyWeightAtBirth: json['babyWeightAtBirth']?.toDouble(),
        bpd: json['bpd']?.toDouble(),
        hc: json['hc']?.toDouble(),
        ac: json['ac']?.toDouble(),
        fl: json['fl']?.toDouble(),
        numberOfPreviousPregnancies: json['numberOfPreviousPregnancies'],
        lastPregnancyYear: json['lastPregnancyYear'],
        pregnancyHealthNotes: json['pregnancyHealthNotes'],
        pregnancyPrivacyConsent: json['pregnancyPrivacyConsent'],
        emergencyContactName: json['emergencyContactName'],
        emergencyContactNumber: json['emergencyContactNumber'],
        emergencyContactRelation: json['emergencyContactRelation'],
        healthInsuranceId: json['healthInsuranceId'],
        policyNumber: json['policyNumber'], // Health insurance policy number
        policyExpiryDate: json['policyExpiryDate'] != null
            ? DateTime.parse(json['policyExpiryDate'])
            : null, // Health insurance expiry date
        insuranceCardImageUrl: json['insuranceCardImageUrl'],
        lastPeriodStartDate: json['lastPeriodStartDate'] != null
            ? DateTime.parse(json['lastPeriodStartDate'])
            : null,
        cycleLength: json['cycleLength'],
        periodDuration: json['periodDuration'],
        cycleHistory: json['cycleHistory'] != null
            ? List<Map<String, dynamic>>.from(json['cycleHistory'])
            : null,

        // Location fields
        longitude: json['longitude']?.toDouble(),
        latitude: json['latitude']?.toDouble(),

        // Hospital fields
        hospitalName: json['hospitalName'],
        registrationNumber: json['registrationNumber'],
        hospitalType: json['hospitalType'],
        hospitalAddress: json['hospitalAddress'],
        hospitalEmail: json['hospitalEmail'],
        hospitalPhone: json['hospitalPhone'],
        numberOfBeds: json['numberOfBeds'],
        hasPharmacy: json['hasPharmacy'],
        hasLab: json['hasLab'],
        departments: json['departments'] != null
            ? List<String>.from(json['departments'])
            : null,
        specialFacilities: json['specialFacilities'] != null
            ? List<String>.from(json['specialFacilities'])
            : null,
        licenseDocumentUrl: json['licenseDocumentUrl'],
        registrationCertificateUrl: json['registrationCertificateUrl'],
        buildingPermitUrl: json['buildingPermitUrl'],
        isApproved: json['isApproved'],
        approvalStatus: json['approvalStatus'],

        // Doctor fields
        medicalRegistrationNumber: json['medicalRegistrationNumber'],
        licenseNumber: json['licenseNumber'],
        qualification: json['qualification'],
        specialization: json['specialization'],
        specializations: json['specializations'] != null
            ? List<String>.from(json['specializations'])
            : null,
        experienceYears: json['experienceYears'],
        hospitalAffiliation: json['hospitalAffiliation'],
        hospitalId: json['hospitalId'],
        affiliatedHospitals: json['affiliatedHospitals'] != null
            ? (json['affiliatedHospitals'] is List)
                ? List<String>.from(json['affiliatedHospitals'].map((item) =>
                    item is String
                        ? item
                        : item['hospitalName'] ?? item.toString()))
                : null
            : null,
        enhancedAffiliatedHospitals: json['enhancedAffiliatedHospitals'] != null
            ? List<Map<String, dynamic>>.from(
                json['enhancedAffiliatedHospitals'])
            : null,
        consultationFee: json['consultationFee']?.toDouble(),
        certificateUrl: json['certificateUrl'],
        about: json['about'],

        // Lab fields
        labName: json['labName'],
        labLicenseNumber: json['labLicenseNumber'],
        associatedHospital: json['associatedHospital'],
        availableTests: json['availableTests'] != null
            ? List<String>.from(json['availableTests'])
            : null,
        labAddress: json['labAddress'],
        homeSampleCollection: json['homeSampleCollection'],
        servicesProvided: json['servicesProvided'] != null
            ? List<String>.from(json['servicesProvided'])
            : null, // Added for lab services
        labAffiliatedHospitals: json['labAffiliatedHospitals'] != null
            ? List<Map<String, dynamic>>.from(json['labAffiliatedHospitals'])
            : null,

        // Pharmacy fields
        pharmacyName: json['pharmacyName'],
        pharmacyLicenseNumber: json['pharmacyLicenseNumber'],
        pharmacyAddress: json['pharmacyAddress'],
        operatingHours: json['operatingHours'] != null
            ? (json['operatingHours'] is String
                ? json['operatingHours']
                : jsonEncode(json['operatingHours']))
            : null,
        homeDelivery: json['homeDelivery'],
        drugLicenseUrl: json['drugLicenseUrl'],
        premisesCertificateUrl: json['premisesCertificateUrl'],
        operatingHoursDetails: json['operatingHours'] != null
            ? (json['operatingHours'] is String
                ? Map<String, dynamic>.from(jsonDecode(json['operatingHours']))
                : Map<String, dynamic>.from(json['operatingHours']))
            : null,
        pharmacyServicesProvided: json['servicesProvided'] != null
            ? List<String>.from(json['servicesProvided'])
            : null,
        drugsAvailable: json['drugsAvailable'] != null
            ? List<String>.from(json['drugsAvailable'])
            : null,
        pharmacistName: json['pharmacistName'],
        pharmacistLicenseNumber: json['pharmacistLicenseNumber'],
        pharmacistQualification: json['pharmacistQualification'],
        pharmacistExperienceYears: json['pharmacistExperienceYears'],
        registrationDate: json['registrationDate'],
        approvedAt: json['approvedAt'],
        approvedBy: json['approvedBy'],
        approvalNotes: json['approvalNotes'],

        // Admin fields
        organization: json['organization'],
        designation: json['designation'],
      );
    } catch (e) {
      print('❌ Error in UserModel.fromJson: $e');
      print('❌ Problematic field in JSON: ${json.toString()}');
      rethrow;
    }
  }

  // Method for JSON API
  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'fullName': fullName,
      'hospitalOwnerName': hospitalOwnerName,
      'email': email,
      'mobileNumber': mobileNumber,
      'alternateMobile': alternateMobile,
      'altPhoneNumber': altPhoneNumber,
      'gender': gender,
      'dateOfBirth': dateOfBirth.toIso8601String(),
      'address': address,
      'pincode': pincode,
      'city': city,
      'state': state,
      'aadhaarNumber': aadhaarNumber,
      'aadhaarFrontImageUrl': aadhaarFrontImageUrl,
      'aadhaarBackImageUrl': aadhaarBackImageUrl,
      'profileImageUrl': profileImageUrl,
      'type': type,
      'createdAt': createdAt.toIso8601String(),
      'healthQrId': healthQrId,
      'qrCode': qrCode, // QR code data URL

      // Patient fields
      if (type == 'patient') ...{
        'bloodGroup': bloodGroup,
        'height': height,
        'weight': weight,
        'knownAllergies': knownAllergies,
        'chronicConditions': chronicConditions,
        'isPregnant': isPregnant,
        'pregnancyTrackingEnabled': pregnancyTrackingEnabled,
        'pregnancyStartDate': pregnancyStartDate?.toIso8601String(),
        'babyName': babyName,
        'dueDate': dueDate?.toIso8601String(),
        'babyWeightAtBirth': babyWeightAtBirth,
        'bpd': bpd, // Baby measurements
        'hc': hc,
        'ac': ac,
        'fl': fl,
        'numberOfPreviousPregnancies': numberOfPreviousPregnancies,
        'lastPregnancyYear': lastPregnancyYear,
        'pregnancyHealthNotes': pregnancyHealthNotes,
        'pregnancyPrivacyConsent': pregnancyPrivacyConsent,
        'emergencyContactName': emergencyContactName,
        'emergencyContactNumber': emergencyContactNumber,
        'emergencyContactRelation': emergencyContactRelation,
        'healthInsuranceId': healthInsuranceId,
        'policyNumber': policyNumber, // Health insurance policy number
        'policyExpiryDate':
            policyExpiryDate?.toIso8601String(), // Health insurance expiry date
        'insuranceCardImageUrl': insuranceCardImageUrl,
        'lastPeriodStartDate': lastPeriodStartDate?.toIso8601String(),
        'cycleLength': cycleLength,
        'periodDuration': periodDuration,
        'cycleHistory': cycleHistory,
      },

      // Hospital fields
      if (type == 'hospital') ...{
        'fullName': fullName,
        'email': email,
        'mobileNumber': mobileNumber,
        'address': address,
        'city': city,
        'state': state,
        'pincode': pincode,
        'hospitalName': hospitalName,
        'registrationNumber': registrationNumber,
        'hospitalType': hospitalType,
        'hospitalAddress': hospitalAddress,
        'hospitalEmail': hospitalEmail,
        'hospitalPhone': hospitalPhone,
        'numberOfBeds': numberOfBeds,
        'hasPharmacy': hasPharmacy,
        'hasLab': hasLab,
        'departments': departments,
        'specialFacilities': specialFacilities,
        'licenseDocumentUrl': licenseDocumentUrl,
        'registrationCertificateUrl': registrationCertificateUrl,
        'buildingPermitUrl': buildingPermitUrl,
        'isApproved': isApproved,
        'approvalStatus': approvalStatus,
      },

      // Doctor fields
      if (type == 'doctor') ...{
        'medicalRegistrationNumber': medicalRegistrationNumber,
        'licenseNumber': licenseNumber,
        'qualification': qualification,
        'specialization': specialization,
        'specializations': specializations,
        'experienceYears': experienceYears,
        'hospitalAffiliation': hospitalAffiliation,
        'hospitalId': hospitalId,
        'affiliatedHospitals': affiliatedHospitals,
        'consultationFee': consultationFee,
        'licenseDocumentUrl': certificateUrl,
        'profileImageUrl': profileImageUrl,
        'about': about,
        'isApproved': isApproved,
        'approvalStatus': approvalStatus,
      },

      // Lab fields
      if (type == 'lab') ...{
        'labName': labName,
        'labLicenseNumber': labLicenseNumber,
        'associatedHospital': associatedHospital,
        'availableTests': availableTests,
        'labAddress': labAddress,
        'homeSampleCollection': homeSampleCollection,
        'servicesProvided': servicesProvided, // Added for lab services
      },

      // Pharmacy fields
      if (type == 'pharmacy') ...{
        'pharmacyName': pharmacyName,
        'pharmacyLicenseNumber': pharmacyLicenseNumber,
        'pharmacyAddress': pharmacyAddress,
        'operatingHours': operatingHours,
        'homeDelivery': homeDelivery,
        'drugLicenseUrl': drugLicenseUrl,
        'premisesCertificateUrl': premisesCertificateUrl,
        'ownerName': ownerName, // Added for pharmacy owner name
        'operatingHoursDetails': operatingHoursDetails,
        'servicesProvided': pharmacyServicesProvided,
        'drugsAvailable': drugsAvailable,
        'pharmacistName': pharmacistName,
        'pharmacistLicenseNumber': pharmacistLicenseNumber,
        'pharmacistQualification': pharmacistQualification,
        'pharmacistExperienceYears': pharmacistExperienceYears,
        'registrationDate': registrationDate,
        'approvedAt': approvedAt,
        'approvedBy': approvedBy,
        'approvalNotes': approvalNotes,
      },

      // Admin fields
      if (type == 'admin') ...{
        'organization': organization,
        'designation': designation,
      },
    };
  }

  // Generate QR code data with all profile and health information
  Map<String, dynamic> getQrCodeData() {
    // Base QR data for all user types
    Map<String, dynamic> baseData = {
      'uid': uid,
      'fullName': fullName,
      'type': type,
      'healthQrId': healthQrId,
      'arcId': arcId,
      'contactInfo': {
        'mobile': mobileNumber,
        'alternateMobile': alternateMobile,
        'email': email,
      },
      'address': {
        'full': address,
        'pincode': pincode,
        'city': city,
        'state': state,
      },
      'timestamp': DateTime.now().toIso8601String(),
    };

    // Add type-specific information
    if (type == 'pharmacy') {
      baseData.addAll({
        'pharmacyInfo': {
          'pharmacyName': pharmacyName,
          'ownerName': ownerName,
          'pharmacistName': pharmacistName,
          'licenseNumber': licenseNumber,
          'pharmacyLicenseNumber': pharmacyLicenseNumber,
          'pharmacistLicenseNumber': pharmacistLicenseNumber,
          'pharmacistQualification': pharmacistQualification,
          'pharmacistExperienceYears': pharmacistExperienceYears,
          'homeDelivery': homeDelivery,
          'operatingHours': operatingHoursDetails,
          'servicesProvided': pharmacyServicesProvided,
          'drugsAvailable': drugsAvailable,
          'isApproved': isApproved,
          'approvalStatus': approvalStatus,
        },
        'location': {
          'latitude': latitude,
          'longitude': longitude,
        },
      });
    } else if (type == 'hospital') {
      baseData.addAll({
        'hospitalInfo': {
          'hospitalName': hospitalName,
          'ownerName': hospitalOwnerName,
          'licenseNumber': licenseNumber,
          'servicesProvided': servicesProvided,
          'isApproved': isApproved,
          'approvalStatus': approvalStatus,
        },
      });
    } else if (type == 'doctor') {
      baseData.addAll({
        'doctorInfo': {
          'specialization': specialization,
          'qualification': qualification,
          'experienceYears': experienceYears,
          'consultationFee': consultationFee,
          'hospitalAffiliation': hospitalAffiliation,
          'isApproved': isApproved,
          'approvalStatus': approvalStatus,
        },
      });
    } else if (type == 'lab') {
      baseData.addAll({
        'labInfo': {
          'labName': labName,
          'ownerName': ownerName,
          'licenseNumber': licenseNumber,
          'servicesProvided': servicesProvided,
          'homeSampleCollection': homeSampleCollection,
          'isApproved': isApproved,
          'approvalStatus': approvalStatus,
        },
      });
    } else if (type == 'doctor') {
      baseData.addAll({
        'doctorInfo': {
          'specialization': specialization,
          'specializations': specializations,
          'qualification': qualification,
          'medicalRegistrationNumber': medicalRegistrationNumber,
          'licenseNumber': licenseNumber,
          'experienceYears': experienceYears,
          'consultationFee': consultationFee,
          'about': about,
          'hospitalAffiliation': hospitalAffiliation,
          'hospitalId': hospitalId,
          'profileImageUrl': profileImageUrl,
          'isApproved': isApproved,
          'approvalStatus': approvalStatus,
        },
      });
    } else if (type == 'nurse') {
      baseData.addAll({
        'nurseInfo': {
          'qualification': qualification,
          'experienceYears': experienceYears,
          'specialization': specialization,
          'hospitalAffiliation': hospitalAffiliation,
          'isApproved': isApproved,
          'approvalStatus': approvalStatus,
        },
      });
    } else {
      // Patient/user specific data
      baseData.addAll({
        'age': age,
        'gender': gender,
        'bloodGroup': bloodGroup,
        'emergencyContact': {
          'name': emergencyContactName,
          'number': emergencyContactNumber,
          'relation': emergencyContactRelation,
        },
        'healthInfo': {
          'height': height,
          'weight': weight,
          'bmi': bmi,
          'bmiCategory': bmiCategory,
          'knownAllergies': knownAllergies,
          'chronicConditions': chronicConditions,
          'isPregnant': isPregnant,
        },
      });
    }

    return baseData;
  }

  UserModel copyWith({
    String? uid,
    String? fullName,
    String? hospitalOwnerName,
    String? email,
    String? mobileNumber,
    String? alternateMobile,
    String? altPhoneNumber,
    String? gender,
    DateTime? dateOfBirth,
    String? address,
    String? pincode,
    String? city,
    String? state,
    String? aadhaarNumber,
    String? profileImageUrl,
    String? type,
    DateTime? createdAt,
    String? healthQrId,
    String? arcId,
    String? qrCode, // QR code data URL
    String? bloodGroup,
    double? height,
    double? weight,
    List<String>? knownAllergies,
    List<String>? chronicConditions,
    bool? isPregnant,
    bool? pregnancyTrackingEnabled,
    DateTime? pregnancyStartDate,
    String? babyName,
    DateTime? dueDate,
    double? babyWeightAtBirth,
    double? bpd,
    double? hc,
    double? ac,
    double? fl,
    String? emergencyContactName,
    String? emergencyContactNumber,
    String? emergencyContactRelation,
    String? healthInsuranceId,
    String? policyNumber, // Health insurance policy number
    DateTime? policyExpiryDate, // Health insurance expiry date
    String? insuranceCardImageUrl,
    DateTime? lastPeriodStartDate,
    int? cycleLength,
    int? periodDuration,
    List<Map<String, dynamic>>? cycleHistory,
    String? hospitalName,
    String? registrationNumber,
    String? hospitalType,
    String? hospitalAddress,
    String? hospitalEmail,
    String? hospitalPhone,
    int? numberOfBeds,
    bool? hasPharmacy,
    bool? hasLab,
    List<String>? departments,
    String? medicalRegistrationNumber,
    String? licenseNumber,
    String? qualification,
    String? specialization,
    int? experienceYears,
    String? hospitalAffiliation,
    String? hospitalId,
    List<String>? affiliatedHospitals,
    double? consultationFee,
    String? certificateUrl,
    String? about,
    String? labName,
    String? labLicenseNumber,
    String? associatedHospital,
    List<String>? availableTests,
    String? labAddress,
    bool? homeSampleCollection,
    List<String>? servicesProvided, // Added for lab services
    String? pharmacyName,
    String? pharmacyLicenseNumber,
    String? pharmacyAddress,
    String? operatingHours,
    bool? homeDelivery,
    String? drugLicenseUrl,
    String? premisesCertificateUrl,
    String? ownerName, // Added for pharmacy owner name
    Map<String, dynamic>? operatingHoursDetails,
    List<String>? pharmacyServicesProvided,
    List<String>? drugsAvailable,
    String? pharmacistName,
    String? pharmacistLicenseNumber,
    String? pharmacistQualification,
    int? pharmacistExperienceYears,
    String? registrationDate,
    String? approvedAt,
    String? approvedBy,
    String? approvalNotes,
    String? organization,
    String? designation,
    String? licenseDocumentUrl,
    String? registrationCertificateUrl,
    String? buildingPermitUrl,
    bool? isApproved,
    String? approvalStatus,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      fullName: fullName ?? this.fullName,
      hospitalOwnerName: hospitalOwnerName ?? this.hospitalOwnerName,
      email: email ?? this.email,
      mobileNumber: mobileNumber ?? this.mobileNumber,
      alternateMobile: alternateMobile ?? this.alternateMobile,
      altPhoneNumber: altPhoneNumber ?? this.altPhoneNumber,
      gender: gender ?? this.gender,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      address: address ?? this.address,
      pincode: pincode ?? this.pincode,
      city: city ?? this.city,
      state: state ?? this.state,
      aadhaarNumber: aadhaarNumber ?? this.aadhaarNumber,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      ownerName:
          ownerName ?? this.ownerName, // Added for lab and pharmacy owner names
      type: type ?? this.type,
      createdAt: createdAt ?? this.createdAt,
      healthQrId: healthQrId ?? this.healthQrId,
      arcId: arcId ?? this.arcId,
      qrCode: qrCode ?? this.qrCode, // QR code data URL
      bloodGroup: bloodGroup ?? this.bloodGroup,
      height: height ?? this.height,
      weight: weight ?? this.weight,
      knownAllergies: knownAllergies ?? this.knownAllergies,
      chronicConditions: chronicConditions ?? this.chronicConditions,
      isPregnant: isPregnant ?? this.isPregnant,
      pregnancyTrackingEnabled:
          pregnancyTrackingEnabled ?? this.pregnancyTrackingEnabled,
      pregnancyStartDate: pregnancyStartDate ?? this.pregnancyStartDate,
      babyName: babyName ?? this.babyName,
      dueDate: dueDate ?? this.dueDate,
      babyWeightAtBirth: babyWeightAtBirth ?? this.babyWeightAtBirth,
      bpd: bpd ?? this.bpd,
      hc: hc ?? this.hc,
      ac: ac ?? this.ac,
      fl: fl ?? this.fl,
      emergencyContactName: emergencyContactName ?? this.emergencyContactName,
      emergencyContactNumber:
          emergencyContactNumber ?? this.emergencyContactNumber,
      emergencyContactRelation:
          emergencyContactRelation ?? this.emergencyContactRelation,
      healthInsuranceId: healthInsuranceId ?? this.healthInsuranceId,
      policyNumber:
          policyNumber ?? this.policyNumber, // Health insurance policy number
      policyExpiryDate: policyExpiryDate ??
          this.policyExpiryDate, // Health insurance expiry date
      insuranceCardImageUrl:
          insuranceCardImageUrl ?? this.insuranceCardImageUrl,
      lastPeriodStartDate: lastPeriodStartDate ?? this.lastPeriodStartDate,
      cycleLength: cycleLength ?? this.cycleLength,
      periodDuration: periodDuration ?? this.periodDuration,
      cycleHistory: cycleHistory ?? this.cycleHistory,
      hospitalName: hospitalName ?? this.hospitalName,
      registrationNumber: registrationNumber ?? this.registrationNumber,
      hospitalType: hospitalType ?? this.hospitalType,
      hospitalAddress: hospitalAddress ?? this.hospitalAddress,
      hospitalEmail: hospitalEmail ?? this.hospitalEmail,
      hospitalPhone: hospitalPhone ?? this.hospitalPhone,
      numberOfBeds: numberOfBeds ?? this.numberOfBeds,
      hasPharmacy: hasPharmacy ?? this.hasPharmacy,
      hasLab: hasLab ?? this.hasLab,
      departments: departments ?? this.departments,
      medicalRegistrationNumber:
          medicalRegistrationNumber ?? this.medicalRegistrationNumber,
      licenseNumber: licenseNumber ?? this.licenseNumber,
      qualification: qualification ?? this.qualification,
      specialization: specialization ?? this.specialization,
      experienceYears: experienceYears ?? this.experienceYears,
      hospitalAffiliation: hospitalAffiliation ?? this.hospitalAffiliation,
      hospitalId: hospitalId ?? this.hospitalId,
      affiliatedHospitals: affiliatedHospitals ?? this.affiliatedHospitals,
      consultationFee: consultationFee ?? this.consultationFee,
      certificateUrl: certificateUrl ?? this.certificateUrl,
      about: about ?? this.about,
      labName: labName ?? this.labName,
      labLicenseNumber: labLicenseNumber ?? this.labLicenseNumber,
      associatedHospital: associatedHospital ?? this.associatedHospital,
      availableTests: availableTests ?? this.availableTests,
      labAddress: labAddress ?? this.labAddress,
      homeSampleCollection: homeSampleCollection ?? this.homeSampleCollection,
      servicesProvided:
          servicesProvided ?? this.servicesProvided, // Added for lab services
      pharmacyName: pharmacyName ?? this.pharmacyName,
      pharmacyLicenseNumber:
          pharmacyLicenseNumber ?? this.pharmacyLicenseNumber,
      pharmacyAddress: pharmacyAddress ?? this.pharmacyAddress,
      operatingHours: operatingHours ?? this.operatingHours,
      homeDelivery: homeDelivery ?? this.homeDelivery,
      drugLicenseUrl: drugLicenseUrl ?? this.drugLicenseUrl,
      premisesCertificateUrl:
          premisesCertificateUrl ?? this.premisesCertificateUrl,
      operatingHoursDetails:
          operatingHoursDetails ?? this.operatingHoursDetails,
      pharmacyServicesProvided:
          pharmacyServicesProvided ?? this.pharmacyServicesProvided,
      drugsAvailable: drugsAvailable ?? this.drugsAvailable,
      pharmacistName: pharmacistName ?? this.pharmacistName,
      pharmacistLicenseNumber:
          pharmacistLicenseNumber ?? this.pharmacistLicenseNumber,
      pharmacistQualification:
          pharmacistQualification ?? this.pharmacistQualification,
      pharmacistExperienceYears:
          pharmacistExperienceYears ?? this.pharmacistExperienceYears,
      registrationDate: registrationDate ?? this.registrationDate,
      approvedAt: approvedAt ?? this.approvedAt,
      approvedBy: approvedBy ?? this.approvedBy,
      approvalNotes: approvalNotes ?? this.approvalNotes,
      organization: organization ?? this.organization,
      designation: designation ?? this.designation,
      licenseDocumentUrl: licenseDocumentUrl ?? this.licenseDocumentUrl,
      registrationCertificateUrl:
          registrationCertificateUrl ?? this.registrationCertificateUrl,
      buildingPermitUrl: buildingPermitUrl ?? this.buildingPermitUrl,
      isApproved: isApproved ?? this.isApproved,
      approvalStatus: approvalStatus ?? this.approvalStatus,
    );
  }
}

class NurseProfile {
  final String id;
  final String name;
  final String email;
  final String hospitalId;
  final String nurseId;
  final List<String> assignedPatientIds;

  NurseProfile({
    required this.id,
    required this.name,
    required this.email,
    required this.hospitalId,
    required this.nurseId,
    required this.assignedPatientIds,
  });

  factory NurseProfile.fromJson(Map<String, dynamic> json) {
    return NurseProfile(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      hospitalId: json['hospitalId'] ?? '',
      nurseId: json['nurseId'] ?? '',
      assignedPatientIds: List<String>.from(json['assignedPatientIds'] ?? []),
    );
  }
}

class NursePatientAssignment {
  final String patientId;
  final String patientName;
  final String room;
  final String doctorId;
  final String status;

  NursePatientAssignment({
    required this.patientId,
    required this.patientName,
    required this.room,
    required this.doctorId,
    required this.status,
  });

  factory NursePatientAssignment.fromJson(Map<String, dynamic> json) {
    return NursePatientAssignment(
      patientId: json['patientId'] ?? '',
      patientName: json['patientName'] ?? '',
      room: json['room'] ?? '',
      doctorId: json['doctorId'] ?? '',
      status: json['status'] ?? '',
    );
  }
}
