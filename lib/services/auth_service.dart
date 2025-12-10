import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/user_model.dart';
import '../utils/health_qr_generator.dart';
import 'api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    // Configure for web deployment
    clientId: kIsWeb
        ? '239874151024-o7pgb84vn0paqdncj95rijqa2ngagd8i.apps.googleusercontent.com'
        : null,
    scopes: ['email', 'profile'],
  );

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Stream of auth changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Register user with new UserModel
  Future<bool> registerUser(UserModel userModel, {String? password}) async {
    try {
      // Generate Health QR ID if not provided
      final healthQrId =
          userModel.healthQrId ?? HealthQrGenerator.generateHealthQrId();

      // Create a new UserModel with the generated healthQrId
      final updatedUserModel = UserModel(
        uid: userModel.uid,
        fullName: userModel.fullName,
        email: userModel.email,
        mobileNumber: userModel.mobileNumber,
        alternateMobile: userModel.alternateMobile,
        gender: userModel.gender,
        dateOfBirth: userModel.dateOfBirth,
        address: userModel.address,
        pincode: userModel.pincode,
        city: userModel.city,
        state: userModel.state,
        aadhaarNumber: userModel.aadhaarNumber,
        profileImageUrl: userModel.profileImageUrl,
        type: userModel.type,
        createdAt: userModel.createdAt,
        healthQrId: healthQrId,

        // Patient fields
        bloodGroup: userModel.bloodGroup,
        height: userModel.height,
        weight: userModel.weight,
        knownAllergies: userModel.knownAllergies,
        chronicConditions: userModel.chronicConditions,
        isPregnant: userModel.isPregnant,
        emergencyContactName: userModel.emergencyContactName,
        emergencyContactNumber: userModel.emergencyContactNumber,
        emergencyContactRelation: userModel.emergencyContactRelation,
        healthInsuranceId: userModel.healthInsuranceId,

        // Hospital fields
        hospitalName: userModel.hospitalName,
        registrationNumber: userModel.registrationNumber,
        hospitalType: userModel.hospitalType,
        hospitalAddress: userModel.hospitalAddress,
        hospitalEmail: userModel.hospitalEmail,
        hospitalPhone: userModel.hospitalPhone,
        numberOfBeds: userModel.numberOfBeds,
        hasPharmacy: userModel.hasPharmacy,
        hasLab: userModel.hasLab,
        departments: userModel.departments,

        // Doctor fields
        medicalRegistrationNumber: userModel.medicalRegistrationNumber,
        specialization: userModel.specialization,
        experienceYears: userModel.experienceYears,
        affiliatedHospitals: userModel.affiliatedHospitals,
        consultationFee: userModel.consultationFee,
        certificateUrl: userModel.certificateUrl,

        // Lab fields
        labName: userModel.labName,
        labLicenseNumber: userModel.labLicenseNumber,
        associatedHospital: userModel.associatedHospital,
        availableTests: userModel.availableTests,
        labAddress: userModel.labAddress,
        homeSampleCollection: userModel.homeSampleCollection,

        // Pharmacy fields
        pharmacyName: userModel.pharmacyName,
        pharmacyLicenseNumber: userModel.pharmacyLicenseNumber,
        pharmacyAddress: userModel.pharmacyAddress,
        operatingHours: userModel.operatingHours,
        homeDelivery: userModel.homeDelivery,
        drugLicenseUrl: userModel.drugLicenseUrl,
      );

      // Create Firebase user with provided password or default
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: updatedUserModel.email,
        password:
            password ?? 'tempPassword123!', // Use provided password or default
      );

      final user = userCredential.user;
      if (user == null) return false;

      // Create final UserModel with UID
      final finalUserModel = UserModel(
        uid: user.uid,
        fullName: updatedUserModel.fullName,
        email: updatedUserModel.email,
        mobileNumber: updatedUserModel.mobileNumber,
        alternateMobile: updatedUserModel.alternateMobile,
        gender: updatedUserModel.gender,
        dateOfBirth: updatedUserModel.dateOfBirth,
        address: updatedUserModel.address,
        pincode: updatedUserModel.pincode,
        city: updatedUserModel.city,
        state: updatedUserModel.state,
        aadhaarNumber: updatedUserModel.aadhaarNumber,
        profileImageUrl: updatedUserModel.profileImageUrl,
        type: updatedUserModel.type,
        createdAt: updatedUserModel.createdAt,
        healthQrId: updatedUserModel.healthQrId,

        // Patient fields
        bloodGroup: updatedUserModel.bloodGroup,
        height: updatedUserModel.height,
        weight: updatedUserModel.weight,
        knownAllergies: updatedUserModel.knownAllergies,
        chronicConditions: updatedUserModel.chronicConditions,
        isPregnant: updatedUserModel.isPregnant,
        emergencyContactName: updatedUserModel.emergencyContactName,
        emergencyContactNumber: updatedUserModel.emergencyContactNumber,
        emergencyContactRelation: updatedUserModel.emergencyContactRelation,
        healthInsuranceId: updatedUserModel.healthInsuranceId,

        // Hospital fields
        hospitalName: updatedUserModel.hospitalName,
        registrationNumber: updatedUserModel.registrationNumber,
        hospitalType: updatedUserModel.hospitalType,
        hospitalAddress: updatedUserModel.hospitalAddress,
        hospitalEmail: updatedUserModel.hospitalEmail,
        hospitalPhone: updatedUserModel.hospitalPhone,
        numberOfBeds: updatedUserModel.numberOfBeds,
        hasPharmacy: updatedUserModel.hasPharmacy,
        hasLab: updatedUserModel.hasLab,
        departments: updatedUserModel.departments,

        // Doctor fields
        medicalRegistrationNumber: updatedUserModel.medicalRegistrationNumber,
        specialization: updatedUserModel.specialization,
        experienceYears: updatedUserModel.experienceYears,
        affiliatedHospitals: updatedUserModel.affiliatedHospitals,
        consultationFee: updatedUserModel.consultationFee,
        certificateUrl: updatedUserModel.certificateUrl,

        // Lab fields
        labName: updatedUserModel.labName,
        labLicenseNumber: updatedUserModel.labLicenseNumber,
        associatedHospital: updatedUserModel.associatedHospital,
        availableTests: updatedUserModel.availableTests,
        labAddress: updatedUserModel.labAddress,
        homeSampleCollection: updatedUserModel.homeSampleCollection,

        // Pharmacy fields
        pharmacyName: updatedUserModel.pharmacyName,
        pharmacyLicenseNumber: updatedUserModel.pharmacyLicenseNumber,
        pharmacyAddress: updatedUserModel.pharmacyAddress,
        operatingHours: updatedUserModel.operatingHours,
        homeDelivery: updatedUserModel.homeDelivery,
        drugLicenseUrl: updatedUserModel.drugLicenseUrl,
      );

      // Store user data in Node.js backend
      final success = await ApiService.updatePatientInfo(finalUserModel);
      if (!success) {
        // If backend storage fails, delete the Firebase user
        await user.delete();
        return false;
      }

      // Store user type in SharedPreferences for proper routing
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_type', finalUserModel.type);
      await prefs.setString('user_uid', finalUserModel.uid);

      return true;
    } catch (e) {
      rethrow;
    }
  }

  // Google Sign In
  Future<UserModel?> signInWithGoogle() async {
    try {
      // Force account selection by signing out first and then signing in
      // This ensures the account chooser is always shown
      await _googleSignIn.signOut();

      // Sign in with Google - this will show the account chooser
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;

      _lastGoogleUser = googleUser;
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      final userCredential = await _auth.signInWithCredential(credential);
      final user = userCredential.user;
      if (user == null) return null;

      // Persist email/uid for session logging and logout flow
      try {
        final prefs = await SharedPreferences.getInstance();
        if (user.email != null) {
          await prefs.setString('user_email', user.email!);
        }
        await prefs.setString('user_uid', user.uid);
      } catch (_) {}

      // Check if user already exists in our database using universal getUserInfo
      // This will respect the selected user type from SharedPreferences
      final existingUser = await ApiService.getUserInfo(user.uid);
      if (existingUser != null) {
        return existingUser;
      }
      // If new user, return null to indicate need for additional registration
      return null;
    } catch (e) {
      rethrow;
    }
  }

  GoogleSignInAccount? _lastGoogleUser;
  GoogleSignInAccount? getLastGoogleUser() => _lastGoogleUser;

  // Force Google Sign-In account selection
  Future<void> forceGoogleAccountSelection() async {
    try {
      // Sign out from Google Sign-In to clear any cached account
      await _googleSignIn.signOut();
      print('✅ Forced Google Sign-In account selection');
    } catch (e) {
      print('❌ Error forcing Google account selection: $e');
    }
  }

  // Sign in with email and password
  Future<UserModel?> signIn(String email, String password) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = userCredential.user;
      if (user == null) return null;

      // Fire-and-forget session log (non-blocking)
      () async {
        try {
          final prefs = await SharedPreferences.getInstance();
          final role = prefs.getString('user_type');
          if (user.email != null) {
            await prefs.setString('user_email', user.email!);
          }
          await _SessionLogger.logEvent(
            uid: user.uid,
            role: role,
            type: 'login',
            email: user.email,
          );
        } catch (_) {}
      }();

      // Get user data from Node.js backend using universal getUserInfo
      // This will respect the selected user type from SharedPreferences
      final userModel = await ApiService.getUserInfo(user.uid);
      return userModel;
    } catch (e) {
      rethrow;
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      // Fire-and-forget logout log using last-known values
      try {
        final prefs = await SharedPreferences.getInstance();
        final lastUid = prefs.getString('user_uid');
        final lastRole = prefs.getString('user_type');
        if (lastUid != null && lastUid.isNotEmpty) {
          // ignore: unawaited_futures
          _SessionLogger.logEvent(uid: lastUid, role: lastRole, type: 'logout');
        }
      } catch (_) {}

      // Sign out from Firebase Auth
      await _auth.signOut();

      // Sign out from Google Sign-In to clear cached account
      await _googleSignIn.signOut();

      // Clear stored auth token
      await ApiService.clearAuthToken();

      // Clear stored user type and other preferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('user_type');
      await prefs.remove('user_uid');
      await prefs.remove('user_gender');

      print('✅ Successfully signed out from all services');
    } catch (e) {
      print('❌ Error during sign out: $e');
      // Continue with sign out even if there's an error
    }
  }

  // Get current user data
  Future<UserModel?> getCurrentUserData() async {
    final user = currentUser;
    if (user == null) return null;

    return await ApiService.getUserInfo(user.uid);
  }

  // Update user profile
  Future<bool> updateUserProfile(UserModel userModel) async {
    try {
      return await ApiService.updatePatientInfo(userModel);
    } catch (e) {
      return false;
    }
  }
}

// Lightweight session logger (non-blocking network)
class _SessionLogger {
  static Future<void> logEvent({
    required String uid,
    String? role,
    required String type,
    String? email,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userEmail = email ?? prefs.getString('user_email');
      final platform = defaultTargetPlatform.name;
      final nowIso = DateTime.now().toIso8601String();
      final lastLat = prefs.getDouble('last_latitude');
      final lastLng = prefs.getDouble('last_longitude');

      final payload = {
        'uid': uid,
        'role': role,
        'type': type,
        'timestamp': nowIso,
        'platform': platform,
        'email': userEmail,
        'location': (lastLat != null && lastLng != null)
            ? {'lat': lastLat, 'lng': lastLng}
            : null,
      };

      final uri = Uri.parse('${ApiService.baseUrl}/api/sessions/event');
      () async {
        try {
          await http
              .post(uri,
                  headers: {'Content-Type': 'application/json'},
                  body: jsonEncode(payload))
              .timeout(const Duration(seconds: 5));
        } catch (e) {
          print('Session log failed (ignored): $e');
        }
      }();
    } catch (e) {
      print('Session log prep failed (ignored): $e');
    }
  }
}
