import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:arcular_plus/services/storage_service.dart';

class RegistrationService {
  static const String baseUrl = 'https://arcular-plus-backend.onrender.com';
  static final StorageService _storageService = StorageService();

  // Common registration method for all user types
  static Future<Map<String, dynamic>> registerUser({
    required String userType,
    required Map<String, dynamic> userData,
    required List<File> documents,
    required List<String> documentTypes,
    Map<String, String>? uploadedDocuments,
  }) async {
    try {
      print('🚀 RegistrationService.registerUser called for $userType');

      // 1. Get Firebase user
      final firebaseUser = FirebaseAuth.instance.currentUser;
      if (firebaseUser == null) {
        print('❌ No Firebase user found');
        throw Exception('User not authenticated');
      }

      print('✅ Firebase user found: ${firebaseUser.uid}');
      print('📧 User email: ${firebaseUser.email}');

      // 2. Get Firebase ID token
      final idToken = await firebaseUser.getIdToken();
      print('🔑 ID token obtained: ${idToken?.substring(0, 20)}...');

      // 3. Upload documents if any
      Map<String, String> documentUrls = {};

      // Add already uploaded documents
      if (uploadedDocuments != null) {
        print(
            '📄 Adding already uploaded documents: ${uploadedDocuments.keys}');
        documentUrls.addAll(uploadedDocuments);
      }

      // Upload new documents if any
      if (documents.isNotEmpty) {
        print('📄 Uploading ${documents.length} new documents...');
        for (int i = 0; i < documents.length; i++) {
          print(
              '📄 Uploading document ${i + 1}/${documents.length}: ${documentTypes[i]}');
          final url = await _storageService.uploadFile(
            documents[i],
            '${userType}_documents/${firebaseUser.uid}/${documentTypes[i]}',
          );
          if (url != null) {
            documentUrls[documentTypes[i]] = url;
            print('✅ Document uploaded: ${documentTypes[i]} -> $url');
          } else {
            print('❌ Failed to upload document: ${documentTypes[i]}');
          }
        }
      } else {
        print('📄 No new documents to upload');
      }

      print('📄 Final document URLs: $documentUrls');

      // 4. Prepare registration data
      final registrationData = {
        ...userData,
        'uid': firebaseUser.uid,
        'type': userType,
        'status': 'pending', // All registrations start as pending
        'documents': documentUrls,
        'registrationDate': DateTime.now().toIso8601String(),
      };

      // 5. Call appropriate backend endpoint based on user type
      final endpoint = _getRegistrationEndpoint(userType);
      print('🌐 Calling backend endpoint: $baseUrl$endpoint');
      print('📊 Registration data keys: ${registrationData.keys.toList()}');

      final response = await http.post(
        Uri.parse('$baseUrl$endpoint'),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(registrationData),
      );

      print('📡 Backend response status: ${response.statusCode}');
      print('📡 Backend response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = jsonDecode(response.body);

        // 6. Store user info in SharedPreferences
        await _storeUserInfo(userType, userData, responseData);

        return {
          'success': true,
          'data': responseData,
          'message':
              'Registration successful! Your account is pending approval.',
        };
      } else {
        throw Exception('Registration failed: ${response.body}');
      }
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Registration failed: $e',
      };
    }
  }

  // Get registration endpoint based on user type
  static String _getRegistrationEndpoint(String userType) {
    switch (userType) {
      case 'patient':
        return '/api/users/register';
      case 'hospital':
        return '/api/hospitals/register';
      case 'doctor':
        return '/api/doctors/register';
      case 'nurse':
        return '/api/nurses/register';
      case 'lab':
        return '/api/labs/register';
      case 'pharmacy':
        return '/api/pharmacies/register';
      case 'admin':
        return '/api/admin/register';
      case 'arcstaff':
        return '/api/arc-staff/register';
      default:
        return '/api/users/register';
    }
  }

  // Store user information in SharedPreferences
  static Future<void> _storeUserInfo(
    String userType,
    Map<String, dynamic> userData,
    Map<String, dynamic> responseData,
  ) async {
    final prefs = await SharedPreferences.getInstance();

    // Store basic user info
    await prefs.setString('user_type', userType);
    await prefs.setString('user_uid', userData['uid'] ?? '');
    await prefs.setString('user_status', 'pending');

    // Store user-specific info
    if (userData['fullName'] != null) {
      await prefs.setString('user_name', userData['fullName']);
    }
    if (userData['email'] != null) {
      await prefs.setString('user_email', userData['email']);
    }
    if (userData['gender'] != null) {
      await prefs.setString('user_gender', userData['gender']);
    }

    // Store registration response data
    if (responseData['arcId'] != null) {
      await prefs.setString('user_arc_id', responseData['arcId']);
    }
    if (responseData['qrCode'] != null) {
      await prefs.setString('user_qr_code', responseData['qrCode']);
    }
  }

  // Check registration status
  static Future<String> checkRegistrationStatus(String uid) async {
    try {
      final firebaseUser = FirebaseAuth.instance.currentUser;
      if (firebaseUser == null) return 'not_authenticated';

      final idToken = await firebaseUser.getIdToken();
      final response = await http.get(
        Uri.parse('$baseUrl/api/users/$uid/status'),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['status'] ?? 'unknown';
      }

      return 'unknown';
    } catch (e) {
      return 'error';
    }
  }

  // Get required documents for user type
  static List<String> getRequiredDocuments(String userType) {
    switch (userType) {
      case 'patient':
        return ['aadhaar_front', 'aadhaar_back'];
      case 'hospital':
        return [
          'hospital_license',
          'registration_certificate',
          'building_permit'
        ];
      case 'doctor':
        return ['medical_degree', 'license_certificate', 'identity_proof'];
      case 'nurse':
        return ['nursing_degree', 'license_certificate', 'identity_proof'];
      case 'lab':
        return [
          'lab_license',
          'accreditation_certificate',
          'equipment_certificate'
        ];
      case 'pharmacy':
        return ['pharmacy_license', 'drug_license', 'premises_certificate'];
      case 'admin':
        return ['identity_proof', 'authorization_letter'];
      case 'arcstaff':
        return ['identity_proof', 'employment_letter'];
      default:
        return [];
    }
  }

  // Validate required fields for user type
  static List<String> getRequiredFields(String userType) {
    final commonFields = [
      'fullName',
      'email',
      'mobileNumber',
      'address',
      'pincode',
      'city',
      'state',
    ];

    switch (userType) {
      case 'patient':
        return [
          ...commonFields,
          'gender',
          'dateOfBirth',
          'aadhaarNumber',
        ];
      case 'hospital':
        return [
          ...commonFields,
          'hospitalName',
          'registrationNumber',
          'hospitalType',
          'numberOfBeds',
        ];
      case 'doctor':
        return [
          ...commonFields,
          'medicalRegistrationNumber',
          'specialization',
          'experienceYears',
          'consultationFee',
        ];
      case 'nurse':
        return [
          ...commonFields,
          'nursingRegistrationNumber',
          'specialization',
          'experienceYears',
        ];
      case 'lab':
        return [
          ...commonFields,
          'labName',
          'labLicenseNumber',
          'availableTests',
        ];
      case 'pharmacy':
        return [
          ...commonFields,
          'pharmacyName',
          'pharmacyLicenseNumber',
          'operatingHours',
        ];
      case 'admin':
        return [
          ...commonFields,
          'organization',
          'designation',
          'authorizationLevel',
        ];
      case 'arcstaff':
        return [
          ...commonFields,
          'employeeId',
          'department',
          'designation',
        ];
      default:
        return commonFields;
    }
  }

  // Generate ARC ID (if not provided by backend)
  static String generateArcId(String userType) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = (timestamp % 10000).toString().padLeft(4, '0');
    return 'ARC-${userType.toUpperCase()}-$random';
  }
}
