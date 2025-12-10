import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import '../models/appointment_model.dart';
import '../models/medicine_model.dart';
import '../models/report_model.dart';
import '../models/user_model.dart';
import '../models/lab_report_model.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class ApiService {
  static const String baseUrl = 'https://arcular-plus-backend.onrender.com';
  static const String authTokenKey = 'auth_token';

  // HTTP timeout configuration (optimized for faster loading)
  static const Duration _timeout = Duration(seconds: 20);
  static const Duration _connectTimeout = Duration(seconds: 8);

  // Retry configuration (optimized for faster failure recovery)
  static const int _maxRetries = 3;
  static const Duration _retryDelay = Duration(milliseconds: 800);

  // Shared HTTP client with keep-alive
  static final http.Client _client = _createClient();

  static http.Client _createClient() {
    final client = http.Client();
    // Package http doesn't expose pool tuning; rely on keep-alive headers in backend.
    return client;
  }

  // Network connectivity check
  static Future<bool> _checkConnectivity() async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      return connectivityResult != ConnectivityResult.none;
    } catch (e) {
      print('❌ Connectivity check failed: $e');
      return false;
    }
  }

  // HTTP client with timeout configuration
  static http.Client _getHttpClient() {
    return http.Client();
  }

  // Generic HTTP request method with timeout and retry logic
  static Future<http.Response> _makeHttpRequest(
    String method,
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
    int retryCount = 0,
  }) async {
    try {
      // Check connectivity first
      if (!await _checkConnectivity()) {
        throw Exception('No internet connection available');
      }

      final client = _getHttpClient();
      final request = http.Request(method, uri);

      if (headers != null) {
        request.headers.addAll(headers);
      }

      if (body != null) {
        request.body = body is String ? body : jsonEncode(body);
      }

      final streamedResponse = await client.send(request).timeout(_timeout);
      final response = await http.Response.fromStream(streamedResponse);

      client.close();
      return response;
    } catch (e) {
      if (e is SocketException) {
        throw Exception(
            'Network connection failed. Please check your internet connection.');
      } else if (e is TimeoutException) {
        throw Exception('Request timed out. Please try again.');
      } else if (retryCount < _maxRetries) {
        print('🔄 Retrying request (${retryCount + 1}/$_maxRetries)...');
        await Future.delayed(_retryDelay);
        return _makeHttpRequest(method, uri,
            headers: headers, body: body, retryCount: retryCount + 1);
      } else {
        throw Exception('Request failed after $_maxRetries attempts: $e');
      }
    }
  }

  // Get stored auth token
  static Future<String?> getAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(authTokenKey);
  }

  // Store auth token
  static Future<void> storeAuthToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(authTokenKey, token);
  }

  // Clear auth token
  static Future<void> clearAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(authTokenKey);
  }

  // Helper method to get headers with auth token
  static Future<Map<String, String>> _getHeaders() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('❌ No Firebase user found');
        return {
          'Content-Type': 'application/json',
        };
      }

      // Force refresh token to ensure it's valid
      final idToken = await user.getIdToken(true);
      print('🔑 Token refreshed successfully');

      return {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $idToken',
      };
    } catch (e) {
      print('❌ Error getting auth headers: $e');
      return {
        'Content-Type': 'application/json',
      };
    }
  }

  // ==================== PATIENT ENDPOINTS ====================

  // Get patient info from backend
  static Future<UserModel?> getPatientInfo(String patientId) async {
    try {
      // Get Firebase ID token
      final user = FirebaseAuth.instance.currentUser;
      final idToken = await user?.getIdToken();
      if (idToken == null) return null;

      final response = await _client.get(
        Uri.parse('$baseUrl/api/users/$patientId'),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return UserModel.fromJson(data);
      } else {
        print('Failed to fetch user: ${response.body}');
        return null;
      }
    } catch (e) {
      print('Error fetching user info: $e');
      return null;
    }
  }

  // Add/Update patient info - TEMPORARILY RETURNS SUCCESS
  static Future<bool> updatePatientInfo(UserModel patient) async {
    try {
      // For now, just return success to get the app working
      print('Would save patient info: ${patient.toJson()}');
      return true;
    } catch (e) {
      print('Error updating patient info: $e');
      return false;
    }
  }

  // ==================== APPOINTMENT ENDPOINTS ====================

  // Get appointments for a user from backend
  static Future<List<AppointmentModel>> getAppointments(String userId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final idToken = await user?.getIdToken();
      if (idToken == null) return [];

      final response = await _client.get(
        Uri.parse('$baseUrl/api/appointments/user/$userId'),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        print('📊 Appointments API Response: $responseData');

        // Handle both direct array and wrapped response formats
        List data;
        if (responseData is List) {
          data = responseData;
        } else if (responseData is Map && responseData['data'] != null) {
          data = responseData['data'] as List;
        } else {
          print('❌ Unexpected response format: $responseData');
          return [];
        }

        print('📊 Parsed appointments data: ${data.length} items');
        return data.map((e) => AppointmentModel.fromJson(e)).toList();
      } else {
        print(
            '❌ Failed to fetch appointments: ${response.statusCode} - ${response.body}');
        return [];
      }
    } catch (e) {
      print('Error fetching appointments: $e');
      return [];
    }
  }

  // Cancel appointment
  static Future<Map<String, dynamic>> cancelAppointment(
      String appointmentId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final idToken = await user?.getIdToken();
      if (idToken == null) return {'success': false, 'error': 'No auth token'};

      final response = await _client.delete(
        Uri.parse('$baseUrl/api/appointments/$appointmentId'),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
      );

      print(
          '🔍 Cancel Appointment API Response: ${response.statusCode} - ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 204) {
        return {
          'success': true,
          'message': 'Appointment cancelled successfully'
        };
      } else {
        final errorData = json.decode(response.body);
        return {
          'success': false,
          'error': errorData['error'] ?? 'Failed to cancel appointment'
        };
      }
    } catch (e) {
      print('❌ Error cancelling appointment: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  // Create new appointment - TEMPORARILY RETURNS SUCCESS
  static Future<bool> createAppointmentLegacy(
      AppointmentModel appointment) async {
    try {
      print('Would create appointment: ${appointment.toJson()}');
      return true;
    } catch (e) {
      print('Error creating appointment: $e');
      return false;
    }
  }

  // Update appointment - TEMPORARILY RETURNS SUCCESS
  static Future<bool> updateAppointment(AppointmentModel appointment) async {
    try {
      print('Would update appointment: ${appointment.toJson()}');
      return true;
    } catch (e) {
      print('Error updating appointment: $e');
      return false;
    }
  }

  // Delete appointment
  static Future<bool> deleteAppointment(String appointmentId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;
      final idToken = await user.getIdToken();
      final response = await _makeHttpRequest(
        'DELETE',
        Uri.parse('$baseUrl/api/appointments/$appointmentId'),
        headers: {
          'Authorization': 'Bearer $idToken',
        },
      );
      if (response.statusCode == 200) return true;
      return false;
    } catch (e) {
      print('❌ Error deleting appointment: $e');
      return false;
    }
  }

  // ==================== MEDICATION ENDPOINTS ====================

  // Get medications for a user from backend
  static Future<List<MedicineModel>> getMedications(String userId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final idToken = await user?.getIdToken();
      if (idToken == null) return [];

      final response = await _client.get(
        Uri.parse('$baseUrl/api/medications/user/$userId'),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
      );

      print(
          '🔍 Medicine API Response: ${response.statusCode} - ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);

        // Handle both array and object with data property
        List data;
        if (responseData is Map && responseData.containsKey('data')) {
          data = responseData['data'] ?? [];
        } else if (responseData is List) {
          data = responseData;
        } else {
          print('❌ Unexpected response format: $responseData');
          return [];
        }

        print('🔍 Parsed medicine data: $data');
        return data.map((e) => MedicineModel.fromJson(e)).toList();
      } else {
        print(
            '❌ Failed to fetch medications: ${response.statusCode} - ${response.body}');
        return [];
      }
    } catch (e) {
      print('❌ Error fetching medications: $e');
      return [];
    }
  }

  // Add new medication to backend
  static Future<bool> addMedication(Map<String, dynamic> medicineData) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final idToken = await user?.getIdToken();
      if (idToken == null) return false;

      // Add patientId to the medicine data
      final dataWithPatientId = {
        ...medicineData,
        'patientId': user!.uid,
      };

      final response = await _client.post(
        Uri.parse('$baseUrl/api/medications/user-add'),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
        body: json.encode(dataWithPatientId),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        print('✅ Medicine added successfully: ${response.body}');
        return true;
      } else {
        print(
            '❌ Failed to add medicine: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      print('❌ Error adding medicine: $e');
      return false;
    }
  }

  // Assign medication - TEMPORARILY RETURNS SUCCESS
  static Future<bool> assignMedication(MedicineModel medication) async {
    try {
      print('Would assign medication: ${medication.toJson()}');
      return true;
    } catch (e) {
      print('Error assigning medication: $e');
      return false;
    }
  }

  // Update medication
  static Future<bool> updateMedication(MedicineModel medication) async {
    try {
      final token = await FirebaseAuth.instance.currentUser?.getIdToken();
      if (token == null) {
        print('❌ No auth token available');
        return false;
      }

      final response = await http.put(
        Uri.parse('$baseUrl/api/medications/${medication.id}'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode(medication.toJson()),
      );

      if (response.statusCode == 200) {
        print('✅ Medicine updated successfully: ${medication.name}');
        return true;
      } else {
        print(
            '❌ Failed to update medicine: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      print('❌ Error updating medication: $e');
      return false;
    }
  }

  // Fetch prescriptions by status for a user (Active/Completed/Archived)
  static Future<List<Map<String, dynamic>>> getPrescriptionsByStatus(
      String userId,
      {String? status}) async {
    try {
      final token = await FirebaseAuth.instance.currentUser?.getIdToken();
      if (token == null) return [];

      // Add timestamp to prevent caching
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final uri = status == null || status.isEmpty
          ? Uri.parse(
              '$baseUrl/api/prescriptions/user/$userId/by-status?_t=$timestamp')
          : Uri.parse(
              '$baseUrl/api/prescriptions/user/$userId/by-status?status=$status&_t=$timestamp');

      print('🩺 Fetching prescriptions by status: $uri');

      final res =
          await http.get(uri, headers: {'Authorization': 'Bearer $token'});

      print('🩺 Response status: ${res.statusCode}');
      print('🩺 Response body: ${res.body}');

      if (res.statusCode == 200) {
        final body = json.decode(res.body);
        if (body is Map && body['data'] is List) {
          final data = List<Map<String, dynamic>>.from(body['data']);
          print('🩺 Found prescriptions: ${data.length}');
          return data;
        }
      } else if (res.statusCode == 304) {
        print('🩺 304 Not Modified - caching issue');
        return [];
      }
      return [];
    } catch (e) {
      print('❌ Error fetching prescriptions by status: $e');
      return [];
    }
  }

  // Fetch prescriptions by patient ARC ID (supports optional status)
  static Future<List<Map<String, dynamic>>> getPrescriptionsByPatientArcId(
      String patientArcId,
      {String? status}) async {
    try {
      final token = await FirebaseAuth.instance.currentUser?.getIdToken();
      if (token == null) return [];
      final uri = status == null || status.isEmpty
          ? Uri.parse('$baseUrl/api/prescriptions/patient/$patientArcId')
          : Uri.parse(
              '$baseUrl/api/prescriptions/patient/$patientArcId?status=$status');
      final res =
          await http.get(uri, headers: {'Authorization': 'Bearer $token'});
      if (res.statusCode == 200) {
        final body = json.decode(res.body);
        if (body is Map && body['data'] is List) {
          return List<Map<String, dynamic>>.from(body['data']);
        }
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  // Transform prescription to medicine items (client import helper)
  static Future<List<Map<String, dynamic>>> transformPrescriptionToMedicines(
      String prescriptionId) async {
    try {
      final token = await FirebaseAuth.instance.currentUser?.getIdToken();
      if (token == null) return [];
      final res = await http.get(
        Uri.parse(
            '$baseUrl/api/prescriptions/$prescriptionId/transform-to-medicines'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (res.statusCode == 200) {
        final body = json.decode(res.body);
        if (body is Map && body['data'] is List) {
          return List<Map<String, dynamic>>.from(body['data']);
        }
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  // Request prescription refill
  static Future<bool> requestPrescriptionRefill(String prescriptionId) async {
    try {
      final token = await FirebaseAuth.instance.currentUser?.getIdToken();
      if (token == null) return false;
      final res = await http.post(
        Uri.parse('$baseUrl/api/prescriptions/$prescriptionId/request-refill'),
        headers: {'Authorization': 'Bearer $token'},
      );
      return res.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // Get prescriptions by doctor
  static Future<List<Map<String, dynamic>>> getPrescriptionsByDoctor(
      String doctorId) async {
    try {
      final token = await FirebaseAuth.instance.currentUser?.getIdToken();
      if (token == null) return [];

      final response = await http.get(
        Uri.parse('$baseUrl/api/prescriptions/doctor/$doctorId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data['data'] ?? []);
      } else {
        print('❌ Error fetching doctor prescriptions: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('❌ Error fetching doctor prescriptions: $e');
      return [];
    }
  }

  // Get prescriptions by hospital
  static Future<List<Map<String, dynamic>>> getPrescriptionsByHospital(
      String hospitalId) async {
    try {
      final token = await FirebaseAuth.instance.currentUser?.getIdToken();
      if (token == null) return [];

      final response = await http.get(
        Uri.parse('$baseUrl/api/prescriptions/hospital/$hospitalId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data['data'] ?? []);
      } else {
        print(
            '❌ Error fetching hospital prescriptions: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('❌ Error fetching hospital prescriptions: $e');
      return [];
    }
  }

  // Create new prescription
  static Future<Map<String, dynamic>?> createPrescription(
      Map<String, dynamic> prescriptionData) async {
    try {
      final token = await FirebaseAuth.instance.currentUser?.getIdToken();
      if (token == null) return null;

      final response = await http.post(
        Uri.parse('$baseUrl/api/prescriptions/create'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode(prescriptionData),
      );

      if (response.statusCode == 201) {
        final data = json.decode(response.body);
        return data['data'];
      } else if (response.statusCode == 404) {
        // Fallback: some deployments expose only POST /api/prescriptions
        try {
          final fallbackBody = {
            // Use UID-based body the backend resolves
            'patientArcId': prescriptionData['patientArcId'],
            'hospitalId': prescriptionData['hospitalId'],
            'doctorId': prescriptionData['doctorId'],
            'diagnosis': prescriptionData['diagnosis'],
            'medications': prescriptionData['medications'] ?? [],
            'instructions': prescriptionData['instructions'],
            'followUpDate': prescriptionData['followUpDate'],
            'notes': prescriptionData['notes'],
          };
          final res2 = await http.post(
            Uri.parse('$baseUrl/api/prescriptions'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: json.encode(fallbackBody),
          );
          if (res2.statusCode == 201) {
            final data = json.decode(res2.body);
            return data['data'];
          }
        } catch (_) {}
        return null;
      } else {
        print(
            '❌ Error creating prescription: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      print('❌ Error creating prescription: $e');
      return null;
    }
  }

  // Create lab report
  static Future<bool> createLabReport(Map<String, dynamic> reportData) async {
    try {
      final token = await FirebaseAuth.instance.currentUser?.getIdToken();
      if (token == null) return false;

      final response = await http.post(
        Uri.parse('$baseUrl/api/lab-reports/create'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode(reportData),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        print('✅ Lab report created successfully');
        return true;
      } else {
        print(
            '❌ Error creating lab report: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      print('❌ Error creating lab report: $e');
      return false;
    }
  }

  // Get user by ARC ID
  static Future<Map<String, dynamic>?> getUserByArcId(String arcId) async {
    try {
      final token = await FirebaseAuth.instance.currentUser?.getIdToken();
      if (token == null) return null;

      final response = await http.get(
        Uri.parse('$baseUrl/api/users/arc/$arcId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('✅ User found by ARC ID: ${data['data']?['fullName']}');
        return data['data'];
      } else {
        final errorData = json.decode(response.body);
        print(
            '❌ Error fetching user by ARC ID: ${response.statusCode} - ${errorData['error']}');
        return null;
      }
    } catch (e) {
      print('❌ Error fetching user by ARC ID: $e');
      return null;
    }
  }

  // Get lab reports by patient ARC ID
  static Future<List<Map<String, dynamic>>> getLabReportsByArcId(
      String arcId) async {
    try {
      final token = await FirebaseAuth.instance.currentUser?.getIdToken();
      if (token == null) return [];

      final response = await http.get(
        Uri.parse('$baseUrl/api/lab-reports/patient/$arcId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data['data'] ?? []);
      } else {
        print('❌ Error fetching lab reports by ARC ID: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('❌ Error fetching lab reports by ARC ID: $e');
      return [];
    }
  }

  // Update prescription
  static Future<bool> updatePrescription(
      String prescriptionId, Map<String, dynamic> updates) async {
    try {
      final token = await FirebaseAuth.instance.currentUser?.getIdToken();
      if (token == null) return false;

      final response = await http.put(
        Uri.parse('$baseUrl/api/prescriptions/$prescriptionId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode(updates),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('❌ Error updating prescription: $e');
      return false;
    }
  }

  // Mark prescription as completed
  static Future<bool> completePrescription(String prescriptionId,
      {String? completionNotes}) async {
    try {
      final token = await FirebaseAuth.instance.currentUser?.getIdToken();
      if (token == null) return false;

      final response = await http.put(
        Uri.parse('$baseUrl/api/prescriptions/$prescriptionId/complete'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({'completionNotes': completionNotes}),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('❌ Error completing prescription: $e');
      return false;
    }
  }

  // Get patient records by hospital
  static Future<List<Map<String, dynamic>>> getPatientRecordsByHospital(
      String hospitalId) async {
    try {
      final token = await FirebaseAuth.instance.currentUser?.getIdToken();
      if (token == null) return [];

      // Try UID, then fallback to Mongo _id
      final response = await http.get(
        Uri.parse('$baseUrl/api/patient-records/hospital/$hospitalId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data['data'] ?? []);
      } else {
        // Resolve Mongo _id and retry
        try {
          final hid = await getHospitalMongoId(hospitalId);
          if (hid == null) return [];
          // Also try querying hospital-records directly as fallback
          final response2 = await http.get(
            Uri.parse('$baseUrl/api/patient-records/hospital/$hid'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
          );
          if (response2.statusCode == 200) {
            final data = json.decode(response2.body);
            return List<Map<String, dynamic>>.from(data['data'] ?? []);
          }
        } catch (_) {}
        print('❌ Error fetching patient records: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('❌ Error fetching patient records: $e');
      return [];
    }
  }

  // Create patient record
  static Future<Map<String, dynamic>?> createPatientRecord(
      Map<String, dynamic> recordData) async {
    try {
      final token = await FirebaseAuth.instance.currentUser?.getIdToken();
      if (token == null) return null;

      final response = await http.post(
        Uri.parse('$baseUrl/api/patient-records/create'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode(recordData),
      );

      if (response.statusCode == 201) {
        final data = json.decode(response.body);
        return data['data'];
      } else {
        print('❌ Error creating patient record: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('❌ Error creating patient record: $e');
      return null;
    }
  }

  // Archive patient record
  static Future<bool> archivePatientRecord(String recordId,
      {String? archiveReason}) async {
    try {
      final token = await FirebaseAuth.instance.currentUser?.getIdToken();
      if (token == null) return false;

      final response = await http.put(
        Uri.parse('$baseUrl/api/patient-records/$recordId/archive'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({'archiveReason': archiveReason}),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('❌ Error archiving patient record: $e');
      return false;
    }
  }

  // Get patient records by patient ARC ID
  static Future<List<Map<String, dynamic>>> getPatientRecordsByPatientArcId(
      String patientArcId) async {
    try {
      final token = await FirebaseAuth.instance.currentUser?.getIdToken();
      if (token == null) return [];

      final response = await http.get(
        Uri.parse('$baseUrl/api/patient-records/patient/$patientArcId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data['data'] ?? []);
      } else {
        print('❌ Error fetching patient records: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('❌ Error fetching patient records: $e');
      return [];
    }
  }

  // Pregnancy: doctor weekly notes
  static Future<List<Map<String, dynamic>>> getWeeklyNotes(String userId,
      {int? week}) async {
    try {
      final token = await FirebaseAuth.instance.currentUser?.getIdToken();
      if (token == null) return [];
      final uri = week == null
          ? Uri.parse('$baseUrl/api/pregnancy/$userId/weekly-notes')
          : Uri.parse('$baseUrl/api/pregnancy/$userId/weekly-notes?week=$week');
      final res =
          await http.get(uri, headers: {'Authorization': 'Bearer $token'});
      if (res.statusCode == 200) {
        final body = json.decode(res.body);
        if (body is List) return List<Map<String, dynamic>>.from(body);
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  static Future<bool> upsertWeeklyNote(String userId,
      {required int week, String? title, required String content}) async {
    try {
      final token = await FirebaseAuth.instance.currentUser?.getIdToken();
      if (token == null) return false;
      final res = await http.post(
        Uri.parse('$baseUrl/api/pregnancy/$userId/weekly-notes'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json'
        },
        body: json.encode({'week': week, 'title': title, 'content': content}),
      );
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // Update medication status (taken/skipped)
  static Future<Map<String, dynamic>> updateMedicationStatus(
      String medicationId, Map<String, dynamic> updateData) async {
    try {
      print('🔍 ApiService.updateMedicationStatus called with:');
      print('🔍 - medicationId: $medicationId');
      print('🔍 - medicationId type: ${medicationId.runtimeType}');
      print('🔍 - updateData: $updateData');

      final token = await FirebaseAuth.instance.currentUser?.getIdToken();
      if (token == null) {
        print('❌ No auth token available');
        return {'success': false, 'error': 'No auth token'};
      }

      // Use the correct backend routes based on the action
      String url;
      if (updateData['isTaken'] == true) {
        url = '$baseUrl/api/medications/$medicationId/taken';
        print('🔍 Using "taken" route: $url');
      } else if (updateData['isTaken'] == false) {
        url = '$baseUrl/api/medications/$medicationId/not-taken';
        print('🔍 Using "not-taken" route: $url');
      } else {
        // For other updates, use the general update route
        url = '$baseUrl/api/medications/$medicationId';
        print('🔍 Using general update route: $url');
      }

      // For taken/not-taken routes, don't send Content-Type and body
      if (updateData['isTaken'] != null) {
        final response = await http.patch(
          Uri.parse(url),
          headers: {
            'Authorization': 'Bearer $token',
          },
        );

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          print('✅ Medicine status updated successfully: $medicationId');
          return {'success': true, 'data': data};
        } else {
          print(
              '❌ Failed to update medicine status: ${response.statusCode} - ${response.body}');
          final errorData = json.decode(response.body);
          return {
            'success': false,
            'error': errorData['error'] ?? 'Update failed'
          };
        }
      } else {
        // For other updates, use the general update route with body
        final response = await http.patch(
          Uri.parse(url),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: json.encode(updateData),
        );

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          print('✅ Medicine status updated successfully: $medicationId');
          return {'success': true, 'data': data};
        } else {
          print(
              '❌ Failed to update medicine status: ${response.statusCode} - ${response.body}');
          final errorData = json.decode(response.body);
          return {
            'success': false,
            'error': errorData['error'] ?? 'Update failed'
          };
        }
      }
    } catch (e) {
      print('❌ Error updating medication status: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  // Cleanup expired medications
  static Future<Map<String, dynamic>> cleanupExpiredMedications() async {
    try {
      final token = await FirebaseAuth.instance.currentUser?.getIdToken();
      if (token == null) {
        print('❌ No auth token available');
        return {'success': false, 'error': 'No auth token'};
      }

      final response = await http.post(
        Uri.parse('$baseUrl/api/medications/cleanup-expired'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('✅ Cleanup completed: ${data['message']}');
        return {'success': true, 'data': data};
      } else {
        print(
            '❌ Failed to cleanup expired medications: ${response.statusCode} - ${response.body}');
        final errorData = json.decode(response.body);
        return {
          'success': false,
          'error': errorData['error'] ?? 'Cleanup failed'
        };
      }
    } catch (e) {
      print('❌ Error cleaning up expired medications: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  // Get cleanup status
  static Future<Map<String, dynamic>> getCleanupStatus() async {
    try {
      final token = await FirebaseAuth.instance.currentUser?.getIdToken();
      if (token == null) {
        print('❌ No auth token available');
        return {'success': false, 'error': 'No auth token'};
      }

      final response = await http.get(
        Uri.parse('$baseUrl/api/medications/cleanup-status'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {'success': true, 'data': data['data']};
      } else {
        print(
            '❌ Failed to get cleanup status: ${response.statusCode} - ${response.body}');
        final errorData = json.decode(response.body);
        return {
          'success': false,
          'error': errorData['error'] ?? 'Failed to get status'
        };
      }
    } catch (e) {
      print('❌ Error getting cleanup status: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  // Delete medication
  static Future<bool> deleteMedication(String medicationId) async {
    try {
      print('🔍 ApiService.deleteMedication called with:');
      print('🔍 - medicationId: $medicationId');
      print('🔍 - medicationId type: ${medicationId.runtimeType}');

      final token = await FirebaseAuth.instance.currentUser?.getIdToken();
      if (token == null) {
        print('❌ No auth token available');
        return false;
      }

      final url = '$baseUrl/api/medications/$medicationId';
      print('🔍 Full URL: $url');

      final response = await http.delete(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        print('✅ Medicine deleted successfully: $medicationId');
        return true;
      } else {
        print(
            '❌ Failed to delete medicine: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      print('❌ Error updating medication: $e');
      return false;
    }
  }

  // ==================== REPORT ENDPOINTS ====================

  // Get reports for a user from backend
  static Future<List<ReportModel>> getReports(String userId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final idToken = await user?.getIdToken();
      if (idToken == null) return [];

      final response = await http.get(
        Uri.parse('$baseUrl/api/reports/user/$userId'),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        return data.map((e) => ReportModel.fromJson(e)).toList();
      } else {
        print('Failed to fetch reports: ${response.body}');
        return [];
      }
    } catch (e) {
      print('Error fetching reports: $e');
      return [];
    }
  }

  // Upload report file to backend
  static Future<bool> uploadReport(
      File file, String userId, String description) async {
    try {
      final uri = Uri.parse(
          'https://arcular-plus-backend.onrender.com/api/reports/upload');
      var request = http.MultipartRequest('POST', uri)
        ..fields['userId'] = userId
        ..fields['description'] = description
        ..files.add(await http.MultipartFile.fromPath('file', file.path));
      var response = await request.send();
      if (response.statusCode == 200) {
        return true;
      } else {
        print('Upload failed:  ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('Error uploading report: $e');
      return false;
    }
  }

  // Delete report - TEMPORARILY RETURNS SUCCESS
  static Future<bool> deleteReport(String reportId) async {
    try {
      print('🗑️ ApiService.deleteReport called with ID: $reportId');

      final uri = Uri.parse(
          'https://arcular-plus-backend.onrender.com/api/reports/$reportId');
      print('🔍 Delete URL: $uri');

      final response = await http.delete(uri);
      print('🔍 Delete response status: ${response.statusCode}');
      print('🔍 Delete response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('🔍 Delete response data: $data');
        final success = data['success'] == true;
        print('🔍 Delete success: $success');
        return success;
      } else {
        print('Failed to delete report: ${response.statusCode}');
        print('Failed to delete report body: ${response.body}');
        return false;
      }
    } catch (e) {
      print('Error deleting report: $e');
      return false;
    }
  }

  // ==================== DOCTOR ENDPOINTS ====================

  static Future<bool> registerDoctor(UserModel doctorUser) async {
    try {
      print(
          '🌐 Sending doctor registration request to: $baseUrl/api/doctors/register');

      // Map Flutter UserModel fields to backend Doctor model fields
      final Map<String, dynamic> backendData = {
        'uid': doctorUser.uid,
        'fullName': doctorUser.fullName,
        'email': doctorUser.email,
        'mobileNumber': doctorUser.mobileNumber,
        'gender': doctorUser.gender,
        'dateOfBirth': doctorUser.dateOfBirth?.toIso8601String(),
        'address': doctorUser.address,
        'city': doctorUser.city,
        'state': doctorUser.state,
        'pincode': doctorUser.pincode,
        'medicalRegistrationNumber': doctorUser.medicalRegistrationNumber,
        'licenseNumber': doctorUser.licenseNumber,
        'specialization': doctorUser.specialization,
        'experienceYears': doctorUser.experienceYears,
        'consultationFee': doctorUser.consultationFee,
        'education': doctorUser.qualification, // Map qualification to education
        'bio': doctorUser.about, // Map about to bio
        'currentHospital': doctorUser
            .hospitalAffiliation, // Map hospitalAffiliation to currentHospital
        'licenseDocumentUrl': doctorUser.licenseDocumentUrl,
        'profileImageUrl': doctorUser.profileImageUrl,
      };

      print('📋 Mapped doctor data for backend: $backendData');

      // Get Firebase ID token for authentication
      final user = FirebaseAuth.instance.currentUser;
      final idToken = await user?.getIdToken();
      if (idToken == null) {
        print('❌ No Firebase user or ID token available');
        return false;
      }

      // Register doctor in doctors collection using the new HTTP method
      final doctorResponse = await _makeHttpRequest(
        'POST',
        Uri.parse('$baseUrl/api/doctors/register'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
        body: backendData,
      );

      print('📡 Doctor response status: ${doctorResponse.statusCode}');
      print('📡 Doctor response body: ${doctorResponse.body}');

      if (doctorResponse.statusCode == 201 ||
          doctorResponse.statusCode == 200) {
        print('✅ Doctor registration successful');
        return true;
      } else {
        print('❌ Doctor registration failed: ${doctorResponse.body}');
        return false;
      }
    } catch (e) {
      print('❌ Doctor registration error: $e');
      return false;
    }
  }

  // Get doctor info by UID
  static Future<UserModel?> getDoctorInfo(String doctorId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final idToken = await user?.getIdToken();
      if (idToken == null) return null;

      final response = await http.get(
        Uri.parse('$baseUrl/api/doctors/uid/$doctorId'),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return UserModel.fromJson(data['data']);
      } else {
        print('❌ Failed to fetch doctor info: ${response.body}');
        return null;
      }
    } catch (e) {
      print('❌ Error fetching doctor info: $e');
      return null;
    }
  }

  // Get raw doctor data by UID (for accessing affiliatedHospitals)
  static Future<Map<String, dynamic>?> getDoctorInfoRaw(String doctorId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final idToken = await user?.getIdToken();
      if (idToken == null) return null;

      final response = await http.get(
        Uri.parse('$baseUrl/api/doctors/uid/$doctorId'),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['data'];
      } else {
        print('❌ Failed to fetch raw doctor info: ${response.body}');
        return null;
      }
    } catch (e) {
      print('❌ Error fetching raw doctor info: $e');
      return null;
    }
  }

  // Get all doctors
  static Future<List<UserModel>> getAllDoctors() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final idToken = await user?.getIdToken();
      if (idToken == null) return [];

      final response = await http.get(
        Uri.parse('$baseUrl/api/doctors'),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final doctors =
            (data['data'] as List).map((e) => UserModel.fromJson(e)).toList();

        // Debug: Check specializations field
        print('🔍 API Response - Sample doctor data:');
        if (doctors.isNotEmpty) {
          final sampleDoctor = doctors.first;
          print('  - Name: ${sampleDoctor.fullName}');
          print('  - Specialization: ${sampleDoctor.specialization}');
          print('  - Specializations: ${sampleDoctor.specializations}');
        }

        return doctors;
      } else {
        print('❌ Failed to fetch doctors: ${response.body}');
        return [];
      }
    } catch (e) {
      print('❌ Error fetching doctors: $e');
      return [];
    }
  }

  // Get all specialties
  static Future<List<String>> getAllSpecialties() async {
    try {
      print('🔍 Fetching specialties from API...');
      final user = FirebaseAuth.instance.currentUser;
      final idToken = await user?.getIdToken();
      if (idToken == null) {
        print('❌ No Firebase user token');
        return [];
      }

      final response = await http.get(
        Uri.parse('$baseUrl/api/doctors/specialties'),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
      );

      print('📡 Specialties API response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('📊 Specialties response data: $data');
        if (data['success'] == true && data['data'] != null) {
          final specialties = List<String>.from(data['data']);
          print('✅ Found ${specialties.length} specialties: $specialties');

          // Debug: Check specifically for Cardiology
          print(
              '🔍 Cardiology in specialties: ${specialties.contains('Cardiology')}');
          if (specialties.contains('Cardiology')) {
            print('✅ Cardiology found in specialties list');
          } else {
            print('❌ Cardiology NOT found in specialties list');
            print('🔍 Available specialties: ${specialties.join(', ')}');
          }

          return specialties;
        } else {
          print('❌ Invalid specialties response format');
        }
      } else {
        print(
            '❌ Specialties API error: ${response.statusCode} - ${response.body}');
      }
      return [];
    } catch (e) {
      print('❌ Error fetching specialties: $e');
      return [];
    }
  }

  // Get all hospitals
  static Future<List<UserModel>> getAllHospitals() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final idToken = await user?.getIdToken();
      if (idToken == null) return [];

      final response = await http.get(
        Uri.parse('$baseUrl/api/hospitals'),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null) {
          return (data['data'] as List)
              .map((e) => UserModel.fromJson(e))
              .toList();
        }
      }
      return [];
    } catch (e) {
      print('❌ Error fetching hospitals: $e');
      return [];
    }
  }

  // Get doctors by hospital
  static Future<List<UserModel>> getDoctorsByHospital(String hospitalId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final idToken = await user?.getIdToken();
      if (idToken == null) return [];

      final response = await http.get(
        Uri.parse('$baseUrl/api/doctors/hospital/$hospitalId'),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return (data['data'] as List)
            .map((e) => UserModel.fromJson(e))
            .toList();
      } else {
        print('❌ Failed to fetch doctors by hospital: ${response.body}');
        return [];
      }
    } catch (e) {
      print('❌ Error fetching doctors by hospital: $e');
      return [];
    }
  }

  // Get doctors by specialization
  static Future<List<UserModel>> getDoctorsBySpecialization(
      String specialization) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final idToken = await user?.getIdToken();
      if (idToken == null) return [];

      final response = await http.get(
        Uri.parse('$baseUrl/api/doctors/specialization/$specialization'),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return (data['data'] as List)
            .map((e) => UserModel.fromJson(e))
            .toList();
      } else {
        print('❌ Failed to fetch doctors by specialization: ${response.body}');
        return [];
      }
    } catch (e) {
      print('❌ Error fetching doctors by specialization: $e');
      return [];
    }
  }

  // Search doctors
  static Future<List<UserModel>> searchDoctors(String query) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final idToken = await user?.getIdToken();
      if (idToken == null) return [];

      final response = await http.get(
        Uri.parse('$baseUrl/api/doctors/search?q=$query'),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return (data['data'] as List)
            .map((e) => UserModel.fromJson(e))
            .toList();
      } else {
        print('❌ Failed to search doctors: ${response.body}');
        return [];
      }
    } catch (e) {
      print('❌ Error searching doctors: $e');
      return [];
    }
  }

  // Get pending doctor approvals
  static Future<List<UserModel>> getPendingDoctorApprovals() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final idToken = await user?.getIdToken();
      if (idToken == null) return [];

      final response = await http.get(
        Uri.parse('$baseUrl/api/doctors/pending-approvals'),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return (data['data'] as List)
            .map((e) => UserModel.fromJson(e))
            .toList();
      } else {
        print('❌ Failed to fetch pending doctor approvals: ${response.body}');
        return [];
      }
    } catch (e) {
      print('❌ Error fetching pending doctor approvals: $e');
      return [];
    }
  }

  // Approve doctor
  static Future<bool> approveDoctor(
      String doctorId, String approvedBy, String notes) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final idToken = await user?.getIdToken();
      if (idToken == null) return false;

      final response = await _makeHttpRequest(
        'POST',
        Uri.parse('$baseUrl/api/doctors/$doctorId/approve'),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
        body: {
          'approvedBy': approvedBy,
          'notes': notes,
        },
      );

      if (response.statusCode == 200) {
        print('✅ Doctor approved successfully');
        return true;
      } else {
        print('❌ Failed to approve doctor: ${response.body}');
        return false;
      }
    } catch (e) {
      print('❌ Error approving doctor: $e');
      return false;
    }
  }

  // Reject doctor
  static Future<bool> rejectDoctor(
      String doctorId, String rejectedBy, String reason) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final idToken = await user?.getIdToken();
      if (idToken == null) return false;

      final response = await _makeHttpRequest(
        'POST',
        Uri.parse('$baseUrl/api/doctors/$doctorId/reject'),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
        body: {
          'rejectedBy': rejectedBy,
          'reason': reason,
        },
      );

      if (response.statusCode == 200) {
        print('✅ Doctor rejected successfully');
        return true;
      } else {
        print('❌ Failed to reject doctor: ${response.body}');
        return false;
      }
    } catch (e) {
      print('❌ Error rejecting doctor: $e');
      return false;
    }
  }

  // Get doctor availability
  static Future<List<Map<String, dynamic>>> getDoctorAvailability(
      String doctorId) async {
    try {
      // Mock availability data
      return [
        {
          'date': DateTime.now().add(const Duration(days: 1)).toIso8601String(),
          'slots': ['09:00 AM', '10:00 AM', '11:00 AM', '02:00 PM', '03:00 PM']
        },
        {
          'date': DateTime.now().add(const Duration(days: 2)).toIso8601String(),
          'slots': ['09:00 AM', '10:00 AM', '02:00 PM', '03:00 PM', '04:00 PM']
        },
      ];
    } catch (e) {
      print('Error getting doctor availability: $e');
      return [];
    }
  }

  // Create appointment with real doctor
  static Future<bool> createAppointmentWithDoctor({
    required String doctorId,
    required String patientId,
    required DateTime dateTime,
    required String reason,
    String? notes,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;

      final idToken = await user.getIdToken();

      // Get doctor details first
      final doctorResponse = await http.get(
        Uri.parse('$baseUrl/api/doctors/$doctorId/profile'),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
      );

      if (doctorResponse.statusCode != 200) {
        print('❌ Failed to get doctor details: ${doctorResponse.statusCode}');
        return false;
      }

      final doctorData = jsonDecode(doctorResponse.body);

      // Create appointment
      final response = await http.post(
        Uri.parse('$baseUrl/api/appointments'),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'doctorName': doctorData['fullName'],
          'doctorId': doctorId,
          'patientId': patientId,
          'dateTime': dateTime.toIso8601String(),
          'status': 'Scheduled',
          'notes': notes,
          'duration': 30,
          'type': 'Consultation',
          'reason': reason,
        }),
      );

      if (response.statusCode == 201) {
        print('✅ Appointment created successfully');
        return true;
      } else {
        print('❌ Failed to create appointment: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('❌ Error creating appointment: $e');
      return false;
    }
  }

  // Get appointments for a specific doctor
  static Future<List<AppointmentModel>> getDoctorAppointments(String doctorId,
      {String? status}) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final idToken = await user?.getIdToken();
      if (idToken == null) return [];

      String url = '$baseUrl/api/appointments/doctor/$doctorId';
      if (status != null && status.isNotEmpty) {
        url += '?status=$status';
      }

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('🔍 Doctor appointments API response: $data');
        if (data['success'] == true && data['data'] != null) {
          final appointments = (data['data'] as List)
              .map((e) => AppointmentModel.fromJson(e))
              .toList();
          print('✅ Parsed ${appointments.length} doctor appointments');
          return appointments;
        }
      }

      print(
          '❌ Error fetching doctor appointments: ${response.statusCode} - ${response.body}');
      return [];
    } catch (e) {
      print('❌ Error fetching doctor appointments: $e');
      return [];
    }
  }

  // Search patients by name or ARC ID
  static Future<List<UserModel>> searchPatients(String query) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final idToken = await user?.getIdToken();
      if (idToken == null) return [];

      final response = await http.get(
        Uri.parse('$baseUrl/api/users/search?q=$query'),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null) {
          return (data['data'] as List)
              .map((e) => UserModel.fromJson(e))
              .toList();
        }
      }

      print('❌ Error searching patients: ${response.statusCode}');
      return [];
    } catch (e) {
      print('❌ Error searching patients: $e');
      return [];
    }
  }

  // Get hospital by UID
  static Future<UserModel?> getHospitalByUid(String uid) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final idToken = await user?.getIdToken();
      if (idToken == null) return null;

      final response = await http.get(
        Uri.parse('$baseUrl/api/hospitals/uid/$uid'),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null) {
          return UserModel.fromJson(data['data']);
        }
      }

      print('❌ Error fetching hospital: ${response.statusCode}');
      return null;
    } catch (e) {
      print('❌ Error fetching hospital: $e');
      return null;
    }
  }

  // Get hospital by name (for affiliated hospitals that store names instead of UIDs)
  static Future<UserModel?> getHospitalByName(String hospitalName) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final idToken = await user?.getIdToken();
      if (idToken == null) return null;

      final response = await http.get(
        Uri.parse(
            '$baseUrl/api/hospitals/search?name=${Uri.encodeComponent(hospitalName)}'),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true &&
            data['data'] != null &&
            data['data'].isNotEmpty) {
          // Return the first matching hospital
          return UserModel.fromJson(data['data'][0]);
        }
      }

      print('❌ Error fetching hospital by name: ${response.statusCode}');
      return null;
    } catch (e) {
      print('❌ Error fetching hospital by name: $e');
      return null;
    }
  }

  // Get patient info by QR ID
  static Future<UserModel?> getPatientByQrId(String qrId) async {
    try {
      // Mock patient data - in real app, this would query by QR ID
      return UserModel(
        uid: 'patient_$qrId',
        fullName: 'John Doe',
        email: 'john.doe@example.com',
        mobileNumber: '+1234567890',
        gender: 'Male',
        dateOfBirth: DateTime(1990, 1, 1),
        address: '123 Main St',
        pincode: '123456',
        city: 'Test City',
        state: 'Test State',
        type: 'patient',
        createdAt: DateTime.now(),
        bloodGroup: 'O+',
        height: 175.0,
        weight: 70.0,
      );
    } catch (e) {
      print('Error getting patient by QR ID: $e');
      return null;
    }
  }

  // ==================== HOSPITAL ENDPOINTS ====================

  static Future<bool> registerHospital(UserModel hospitalUser) async {
    try {
      print(
          '🌐 Sending hospital registration request to: $baseUrl/api/hospitals/register');

      // Map Flutter UserModel fields to backend Hospital model fields
      final Map<String, dynamic> backendData = {
        'uid': hospitalUser.uid,
        'fullName': hospitalUser.fullName,
        'email': hospitalUser.email,
        'mobileNumber': hospitalUser.mobileNumber,
        'gender': hospitalUser.gender,
        'dateOfBirth': hospitalUser.dateOfBirth?.toIso8601String(),
        'address': hospitalUser.address,
        'city': hospitalUser.city,
        'state': hospitalUser.state,
        'pincode': hospitalUser.pincode,
        'hospitalName': hospitalUser.hospitalName,
        'registrationNumber': hospitalUser.registrationNumber,
        'hospitalType': hospitalUser.hospitalType,
        'hospitalAddress': hospitalUser.hospitalAddress,
        'hospitalEmail': hospitalUser.hospitalEmail,
        'hospitalPhone': hospitalUser.hospitalPhone,
        'numberOfBeds': hospitalUser.numberOfBeds,
        'hasPharmacy': hospitalUser.hasPharmacy,
        'hasLab': hospitalUser.hasLab,
        'departments': hospitalUser.departments,
        'specialFacilities': hospitalUser.specialFacilities,
        'licenseDocumentUrl': hospitalUser.licenseDocumentUrl,
        'isApproved': hospitalUser.isApproved,
        'approvalStatus': hospitalUser.approvalStatus,
        'profileImageUrl': hospitalUser.profileImageUrl,
      };

      print('📋 Mapped hospital data for backend: $backendData');

      // Get Firebase ID token for authentication
      final user = FirebaseAuth.instance.currentUser;
      final idToken = await user?.getIdToken();
      if (idToken == null) {
        print('❌ No Firebase user or ID token available');
        return false;
      }

      // Register hospital in hospitals collection using the new HTTP method
      final hospitalResponse = await _makeHttpRequest(
        'POST',
        Uri.parse('$baseUrl/api/hospitals/register'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
        body: backendData,
      );

      print('📡 Hospital response status: ${hospitalResponse.statusCode}');
      print('📡 Hospital response body: ${hospitalResponse.body}');

      if (hospitalResponse.statusCode == 201 ||
          hospitalResponse.statusCode == 200) {
        print('✅ Hospital registration successful');
        return true;
      } else {
        print('❌ Hospital registration failed: ${hospitalResponse.body}');
        return false;
      }
    } catch (e) {
      print('❌ Hospital registration error: $e');
      return false;
    }
  }

  // Get nearby hospitals for SOS
  static Future<List<Map<String, dynamic>>> getNearbyHospitals({
    double? latitude,
    double? longitude,
    String? city,
    String? pincode,
    double radius = 10.0,
  }) async {
    try {
      print('🏥 Fetching nearby hospitals for SOS');
      print(
          '📍 Location params: lat=$latitude, lng=$longitude, city=$city, pincode=$pincode, radius=$radius');

      final user = FirebaseAuth.instance.currentUser;
      final idToken = await user?.getIdToken();
      if (idToken == null) {
        print('❌ No Firebase user or ID token available');
        return [];
      }

      // Build query parameters
      final queryParams = <String, String>{};
      if (latitude != null) queryParams['latitude'] = latitude.toString();
      if (longitude != null) queryParams['longitude'] = longitude.toString();
      if (city != null) queryParams['city'] = city;
      if (pincode != null) queryParams['pincode'] = pincode;
      queryParams['radius'] = radius.toString();

      final uri = Uri.parse('$baseUrl/api/hospitals/nearby')
          .replace(queryParameters: queryParams);

      final response = await _makeHttpRequest(
        'GET',
        uri,
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          final hospitals = List<Map<String, dynamic>>.from(data['data'] ?? []);
          print('✅ Successfully fetched ${hospitals.length} nearby hospitals');
          return hospitals;
        } else {
          print('❌ Failed to fetch nearby hospitals: ${data['error']}');
          return [];
        }
      } else {
        print(
            '❌ Failed to fetch nearby hospitals: ${response.statusCode} - ${response.body}');
        return [];
      }
    } catch (e) {
      print('❌ Error fetching nearby hospitals: $e');
      return [];
    }
  }

  // Get nearby labs
  static Future<List<Map<String, dynamic>>> getNearbyLabs({
    double? latitude,
    double? longitude,
    String? city,
    String? pincode,
    double radius = 10.0,
  }) async {
    try {
      print('🧪 Fetching nearby labs');
      print(
          '📍 Location params: lat=$latitude, lng=$longitude, city=$city, pincode=$pincode, radius=$radius');

      final user = FirebaseAuth.instance.currentUser;
      final idToken = await user?.getIdToken();
      if (idToken == null) {
        print('❌ No Firebase user or ID token available');
        return [];
      }

      // Build query parameters
      final queryParams = <String, String>{};
      if (latitude != null) queryParams['latitude'] = latitude.toString();
      if (longitude != null) queryParams['longitude'] = longitude.toString();
      if (city != null) queryParams['city'] = city;
      if (pincode != null) queryParams['pincode'] = pincode;
      queryParams['radius'] = radius.toString();

      final uri = Uri.parse('$baseUrl/api/labs/nearby')
          .replace(queryParameters: queryParams);

      final response = await _makeHttpRequest(
        'GET',
        uri,
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          final labs = List<Map<String, dynamic>>.from(data['data'] ?? []);
          print('✅ Successfully fetched ${labs.length} nearby labs');
          return labs;
        } else {
          print('❌ Failed to fetch nearby labs: ${data['error']}');
          return [];
        }
      } else {
        print('❌ Failed to fetch nearby labs: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('❌ Error fetching nearby labs: $e');
      return [];
    }
  }

  // Get nearby pharmacies
  static Future<List<Map<String, dynamic>>> getNearbyPharmacies({
    double? latitude,
    double? longitude,
    String? city,
    String? pincode,
    double radius = 10.0,
  }) async {
    try {
      print('💊 Fetching nearby pharmacies');
      print(
          '📍 Location params: lat=$latitude, lng=$longitude, city=$city, pincode=$pincode, radius=$radius');

      final user = FirebaseAuth.instance.currentUser;
      final idToken = await user?.getIdToken();
      if (idToken == null) {
        print('❌ No Firebase user or ID token available');
        return [];
      }

      // Build query parameters
      final queryParams = <String, String>{};
      if (latitude != null) queryParams['latitude'] = latitude.toString();
      if (longitude != null) queryParams['longitude'] = longitude.toString();
      if (city != null) queryParams['city'] = city;
      if (pincode != null) queryParams['pincode'] = pincode;
      queryParams['radius'] = radius.toString();

      final uri = Uri.parse('$baseUrl/api/pharmacies/nearby')
          .replace(queryParameters: queryParams);

      final response = await _makeHttpRequest(
        'GET',
        uri,
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          final pharmacies =
              List<Map<String, dynamic>>.from(data['data'] ?? []);
          print(
              '✅ Successfully fetched ${pharmacies.length} nearby pharmacies');
          return pharmacies;
        } else {
          print('❌ Failed to fetch nearby pharmacies: ${data['error']}');
          return [];
        }
      } else {
        print('❌ Failed to fetch nearby pharmacies: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('❌ Error fetching nearby pharmacies: $e');
      return [];
    }
  }

  // Get nearby doctors
  static Future<List<Map<String, dynamic>>> getNearbyDoctors({
    double? latitude,
    double? longitude,
    String? city,
    String? pincode,
    double radius = 10.0,
  }) async {
    try {
      print('👨‍⚕️ Fetching nearby doctors');
      print(
          '📍 Location params: lat=$latitude, lng=$longitude, city=$city, pincode=$pincode, radius=$radius');

      final user = FirebaseAuth.instance.currentUser;
      final idToken = await user?.getIdToken();
      if (idToken == null) {
        print('❌ No Firebase user or ID token available');
        return [];
      }

      // Build query parameters
      final queryParams = <String, String>{};
      if (latitude != null) queryParams['latitude'] = latitude.toString();
      if (longitude != null) queryParams['longitude'] = longitude.toString();
      if (city != null) queryParams['city'] = city;
      if (pincode != null) queryParams['pincode'] = pincode;
      queryParams['radius'] = radius.toString();

      final uri = Uri.parse('$baseUrl/api/doctors/nearby')
          .replace(queryParameters: queryParams);

      final response = await _makeHttpRequest(
        'GET',
        uri,
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          final doctors = List<Map<String, dynamic>>.from(data['data'] ?? []);
          print('✅ Successfully fetched ${doctors.length} nearby doctors');
          return doctors;
        } else {
          print('❌ Failed to fetch nearby doctors: ${data['error']}');
          return [];
        }
      } else {
        print('❌ Failed to fetch nearby doctors: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('❌ Error fetching nearby doctors: $e');
      return [];
    }
  }

  // Get nearby nurses
  static Future<List<Map<String, dynamic>>> getNearbyNurses({
    double? latitude,
    double? longitude,
    String? city,
    String? pincode,
    double radius = 10.0,
  }) async {
    try {
      print('👩‍⚕️ Fetching nearby nurses');
      print(
          '📍 Location params: lat=$latitude, lng=$longitude, city=$city, pincode=$pincode, radius=$radius');

      final user = FirebaseAuth.instance.currentUser;
      final idToken = await user?.getIdToken();
      if (idToken == null) {
        print('❌ No Firebase user or ID token available');
        return [];
      }

      // Build query parameters
      final queryParams = <String, String>{};
      if (latitude != null) queryParams['latitude'] = latitude.toString();
      if (longitude != null) queryParams['longitude'] = longitude.toString();
      if (city != null) queryParams['city'] = city;
      if (pincode != null) queryParams['pincode'] = pincode;
      queryParams['radius'] = radius.toString();

      final uri = Uri.parse('$baseUrl/api/nurses/nearby')
          .replace(queryParameters: queryParams);

      final response = await _makeHttpRequest(
        'GET',
        uri,
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          final nurses = List<Map<String, dynamic>>.from(data['data'] ?? []);
          print('✅ Successfully fetched ${nurses.length} nearby nurses');
          return nurses;
        } else {
          print('❌ Failed to fetch nearby nurses: ${data['error']}');
          return [];
        }
      } else {
        print('❌ Failed to fetch nearby nurses: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('❌ Error fetching nearby nurses: $e');
      return [];
    }
  }

  // Handle SOS escalation (emergency calls and retries)
  static Future<Map<String, dynamic>> handleSOSEscalation(
      String sosRequestId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        return {'success': false, 'message': 'User not authenticated'};
      }

      final idToken = await user.getIdToken();
      final response = await _makeHttpRequest(
        'POST',
        Uri.parse('$baseUrl/api/sos/escalate/$sosRequestId'),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final errorData = jsonDecode(response.body);
        return {
          'success': false,
          'message': errorData['message'] ?? 'Failed to handle SOS escalation',
        };
      }
    } catch (e) {
      print('❌ Error handling SOS escalation: $e');
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // Get SOS escalation status
  static Future<Map<String, dynamic>> getSOSEscalationStatus(
      String sosRequestId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        return {'success': false, 'message': 'User not authenticated'};
      }

      final idToken = await user.getIdToken();
      final response = await _makeHttpRequest(
        'GET',
        Uri.parse('$baseUrl/api/sos/escalation-status/$sosRequestId'),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final errorData = jsonDecode(response.body);
        return {
          'success': false,
          'message':
              errorData['message'] ?? 'Failed to get SOS escalation status',
        };
      }
    } catch (e) {
      print('❌ Error getting SOS escalation status: $e');
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // Handle emergency coordination
  static Future<Map<String, dynamic>> handleEmergencyCoordination(
    String sosRequestId,
    String coordinationAction,
    Map<String, dynamic>? coordinationDetails,
  ) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        return {'success': false, 'message': 'User not authenticated'};
      }

      final idToken = await user.getIdToken();
      final response = await _makeHttpRequest(
        'POST',
        Uri.parse('$baseUrl/api/sos/coordinate/$sosRequestId'),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'coordinationAction': coordinationAction,
          'coordinationDetails': coordinationDetails,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final errorData = jsonDecode(response.body);
        return {
          'success': false,
          'message':
              errorData['message'] ?? 'Failed to handle emergency coordination',
        };
      }
    } catch (e) {
      print('❌ Error handling emergency coordination: $e');
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // Get coordination status
  static Future<Map<String, dynamic>> getCoordinationStatus(
      String sosRequestId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        return {'success': false, 'message': 'User not authenticated'};
      }

      final idToken = await user.getIdToken();
      final response = await _makeHttpRequest(
        'GET',
        Uri.parse('$baseUrl/api/sos/coordination-status/$sosRequestId'),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final errorData = jsonDecode(response.body);
        return {
          'success': false,
          'message':
              errorData['message'] ?? 'Failed to get coordination status',
        };
      }
    } catch (e) {
      print('❌ Error getting coordination status: $e');
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // Discharge patient from hospital
  static Future<Map<String, dynamic>> dischargePatient(
    String hospitalId,
    String sosRequestId,
    Map<String, dynamic> dischargeDetails,
  ) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        return {'success': false, 'message': 'User not authenticated'};
      }

      final idToken = await user.getIdToken();
      final response = await _makeHttpRequest(
        'POST',
        Uri.parse('$baseUrl/api/sos/discharge/$hospitalId'),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'sosRequestId': sosRequestId,
          'dischargeDetails': dischargeDetails,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final errorData = jsonDecode(response.body);
        return {
          'success': false,
          'message': errorData['message'] ?? 'Failed to discharge patient',
        };
      }
    } catch (e) {
      print('❌ Error discharging patient: $e');
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // ==================== ADMIN ENDPOINTS ====================

  static Future<bool> registerAdmin(UserModel adminUser) async {
    try {
      print(
          '🌐 Sending admin registration request to: $baseUrl/api/admins/register');

      // Map Flutter UserModel fields to backend Admin model fields
      final Map<String, dynamic> backendData = {
        'uid': adminUser.uid,
        'fullName': adminUser.fullName,
        'email': adminUser.email,
        'mobileNumber': adminUser.mobileNumber,
        'gender': adminUser.gender,
        'dateOfBirth': adminUser.dateOfBirth?.toIso8601String(),
        'address': adminUser.address,
        'city': adminUser.city,
        'state': adminUser.state,
        'pincode': adminUser.pincode,
        'role': adminUser.role,
        'organization': adminUser.organization,
        'designation': adminUser.designation,
        'profileImageUrl': adminUser.profileImageUrl,
      };

      print('📋 Mapped admin data for backend: $backendData');

      // Get Firebase ID token for authentication
      final user = FirebaseAuth.instance.currentUser;
      final idToken = await user?.getIdToken();
      if (idToken == null) {
        print('❌ No Firebase user or ID token available');
        return false;
      }

      final response = await _makeHttpRequest(
        'POST',
        Uri.parse('$baseUrl/api/admins/register'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
        body: backendData,
      );

      print('📡 Response status: ${response.statusCode}');
      print('📡 Response body: ${response.body}');

      if (response.statusCode == 201 || response.statusCode == 200) {
        print('✅ Admin registration successful');
        return true;
      } else {
        print('❌ Admin registration failed: ${response.body}');
        return false;
      }
    } catch (e) {
      print('❌ Admin registration error: $e');
      return false;
    }
  }

  // Get admin info
  static Future<UserModel?> getAdminInfo(String adminId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final idToken = await user?.getIdToken();
      if (idToken == null) return null;

      final response = await http.get(
        Uri.parse('$baseUrl/api/admins/$adminId'),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return UserModel.fromJson(data);
      } else {
        print('Failed to fetch admin info: ${response.body}');
        return null;
      }
    } catch (e) {
      print('Error getting admin info: $e');
      return null;
    }
  }

  // ==================== ARC STAFF ENDPOINTS ====================

  // Create Arc Staff (by admin)
  static Future<bool> createArcStaff(Map<String, dynamic> staffData) async {
    try {
      print(
          '🌐 Sending Arc Staff creation request to: $baseUrl/api/arc-staff/create');
      print('📋 Staff data: $staffData');

      // Get Firebase ID token for authentication
      final user = FirebaseAuth.instance.currentUser;
      final idToken = await user?.getIdToken();
      if (idToken == null) {
        print('❌ No Firebase user or ID token available');
        return false;
      }

      final response = await _makeHttpRequest(
        'POST',
        Uri.parse('$baseUrl/api/arc-staff/create'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
        body: staffData,
      );

      print('📡 Response status: ${response.statusCode}');
      print('📡 Response body: ${response.body}');

      if (response.statusCode == 201 || response.statusCode == 200) {
        print('✅ Arc Staff created successfully');
        return true;
      } else {
        print('❌ Arc Staff creation failed: ${response.body}');
        return false;
      }
    } catch (e) {
      print('❌ Arc Staff creation error: $e');
      return false;
    }
  }

  // Get all Arc Staff (for admin)
  static Future<List<Map<String, dynamic>>?> getAllArcStaff() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final idToken = await user?.getIdToken();
      if (idToken == null) return null;

      final response = await http.get(
        Uri.parse('$baseUrl/api/arc-staff/all'),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data['staff']);
      } else {
        print('Failed to fetch Arc Staff: ${response.body}');
        return null;
      }
    } catch (e) {
      print('Error getting Arc Staff: $e');
      return null;
    }
  }

  // Get Arc Staff profile
  static Future<Map<String, dynamic>?> getArcStaffProfile() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final idToken = await user?.getIdToken();
      if (idToken == null) return null;

      final response = await http.get(
        Uri.parse('$baseUrl/api/arc-staff/profile'),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['staff'];
      } else {
        print('Failed to fetch Arc Staff profile: ${response.body}');
        return null;
      }
    } catch (e) {
      print('Error getting Arc Staff profile: $e');
      return null;
    }
  }

  // Get pending approvals (for Arc Staff)
  static Future<List<Map<String, dynamic>>?> getPendingApprovals() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final idToken = await user?.getIdToken();
      if (idToken == null) return null;

      final response = await http.get(
        Uri.parse('$baseUrl/api/arc-staff/pending-approvals'),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data['pendingUsers']);
      } else {
        print('Failed to fetch pending approvals: ${response.body}');
        return null;
      }
    } catch (e) {
      print('Error getting pending approvals: $e');
      return null;
    }
  }

  // Approve user (by Arc Staff)
  static Future<bool> approveUser(String userId) async {
    try {
      print(
          '🌐 Sending user approval request to: $baseUrl/api/arc-staff/approve/$userId');

      // Get Firebase ID token for authentication
      final user = FirebaseAuth.instance.currentUser;
      final idToken = await user?.getIdToken();
      if (idToken == null) {
        print('❌ No Firebase user or ID token available');
        return false;
      }

      final response = await _makeHttpRequest(
        'POST',
        Uri.parse('$baseUrl/api/arc-staff/approve/$userId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
      );

      print('📡 Response status: ${response.statusCode}');
      print('📡 Response body: ${response.body}');

      if (response.statusCode == 200) {
        print('✅ User approved successfully');
        return true;
      } else {
        print('❌ User approval failed: ${response.body}');
        return false;
      }
    } catch (e) {
      print('❌ User approval error: $e');
      return false;
    }
  }

  // Reject user (by Arc Staff)
  static Future<bool> rejectUser(String userId, String reason) async {
    try {
      print(
          '🌐 Sending user rejection request to: $baseUrl/api/arc-staff/reject/$userId');
      print('📋 Rejection reason: $reason');

      // Get Firebase ID token for authentication
      final user = FirebaseAuth.instance.currentUser;
      final idToken = await user?.getIdToken();
      if (idToken == null) {
        print('❌ No Firebase user or ID token available');
        return false;
      }

      final response = await _makeHttpRequest(
        'POST',
        Uri.parse('$baseUrl/api/arc-staff/reject/$userId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
        body: {reason: reason},
      );

      print('📡 Response status: ${response.statusCode}');
      print('📡 Response body: ${response.body}');

      if (response.statusCode == 200) {
        print('✅ User rejected successfully');
        return true;
      } else {
        print('❌ User rejection failed: ${response.body}');
        return false;
      }
    } catch (e) {
      print('❌ User rejection error: $e');
      return false;
    }
  }

  // Get hospital info
  static Future<UserModel?> getHospitalInfo(String hospitalId) async {
    try {
      print('🌐 getHospitalInfo called with hospitalId: $hospitalId');
      final user = FirebaseAuth.instance.currentUser;
      final idToken = await user?.getIdToken();
      if (idToken == null) {
        print('❌ No Firebase ID token available');
        return null;
      }

      // Use the current user's UID to fetch hospital data
      final uid = user?.uid ?? hospitalId;
      print('🔍 Fetching hospital data for UID: $uid');

      final url = '$baseUrl/api/hospitals/uid/$uid';
      print('🌐 Making request to: $url');

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
      );

      print('📡 Response status: ${response.statusCode}');
      print('📡 Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('✅ Successfully parsed hospital data');
        try {
          return UserModel.fromJson(data);
        } catch (parseError) {
          print('❌ Error parsing hospital data: $parseError');
          print('📋 Raw data: $data');
          return null;
        }
      } else {
        print('❌ Failed to fetch hospital info: ${response.body}');
        return null;
      }
    } catch (e) {
      print('❌ Error getting hospital info: $e');
      return null;
    }
  }

  // Get pharmacy info
  static Future<UserModel?> getPharmacyInfo(String pharmacyId) async {
    try {
      print('🌐 getPharmacyInfo called with pharmacyId: $pharmacyId');
      final user = FirebaseAuth.instance.currentUser;
      final idToken = await user?.getIdToken();
      if (idToken == null) {
        print('❌ No Firebase ID token available');
        return null;
      }

      // Use the current user's UID to fetch pharmacy data
      final uid = user?.uid ?? pharmacyId;
      print('🔍 Fetching pharmacy data for UID: $uid');

      final url = '$baseUrl/api/pharmacies/uid/$uid';
      print('🌐 Making request to: $url');

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
      );

      print('📡 Response status: ${response.statusCode}');
      print('📡 Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('✅ Successfully parsed pharmacy data');
        try {
          return UserModel.fromJson(data);
        } catch (parseError) {
          print('❌ Error parsing pharmacy data: $parseError');
          print('📋 Raw data: $data');
          return null;
        }
      } else {
        print('❌ Failed to fetch pharmacy info: ${response.body}');
        return null;
      }
    } catch (e) {
      print('❌ Error getting pharmacy info: $e');
      return null;
    }
  }

  // Get hospital doctors
  static Future<List<UserModel>> getHospitalDoctors(String hospitalId) async {
    try {
      // Mock doctors data for hospital
      return [
        UserModel(
          uid: 'doc1',
          fullName: 'Dr. John Smith',
          email: 'john.smith@cityhospital.com',
          mobileNumber: '+1234567891',
          gender: 'Male',
          dateOfBirth: DateTime(1980, 1, 1),
          address: 'City General Hospital',
          pincode: '123456',
          city: 'Medical City',
          state: 'Health State',
          type: 'doctor',
          createdAt: DateTime.now(),
          medicalRegistrationNumber: 'DOC123456',
          specialization: 'Cardiology',
          experienceYears: 15,
          consultationFee: 800.0,
        ),
        UserModel(
          uid: 'doc2',
          fullName: 'Dr. Sarah Johnson',
          email: 'sarah.johnson@cityhospital.com',
          mobileNumber: '+1234567892',
          gender: 'Female',
          dateOfBirth: DateTime(1985, 5, 15),
          address: 'City General Hospital',
          pincode: '123456',
          city: 'Medical City',
          state: 'Health State',
          type: 'doctor',
          createdAt: DateTime.now(),
          medicalRegistrationNumber: 'DOC123457',
          specialization: 'Neurology',
          experienceYears: 12,
          consultationFee: 900.0,
        ),
        UserModel(
          uid: 'doc3',
          fullName: 'Dr. Michael Brown',
          email: 'michael.brown@cityhospital.com',
          mobileNumber: '+1234567893',
          gender: 'Male',
          dateOfBirth: DateTime(1975, 8, 20),
          address: 'City General Hospital',
          pincode: '123456',
          city: 'Medical City',
          state: 'Health State',
          type: 'doctor',
          createdAt: DateTime.now(),
          medicalRegistrationNumber: 'DOC123458',
          specialization: 'Orthopedics',
          experienceYears: 18,
          consultationFee: 1000.0,
        ),
      ];
    } catch (e) {
      print('Error getting hospital doctors: $e');
      return [];
    }
  }

  // Get hospital nurses - fetch real data from affiliated nurses
  static Future<List<UserModel>> getHospitalNurses(String hospitalId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return [];

      final idToken = await user.getIdToken();

      final response = await _makeHttpRequest(
        'GET',
        Uri.parse('$baseUrl/api/nurses/affiliated/$hospitalId'),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null) {
          return (data['data'] as List)
              .map((nurse) => UserModel.fromJson(nurse))
              .toList();
        }
      }
      return [];
    } catch (e) {
      print('Error getting hospital nurses: $e');
      return [];
    }
  }

  // Add nurse to hospital
  static Future<bool> addNurseToHospital({
    required String hospitalId,
    required String fullName,
    required String email,
    required String mobileNumber,
    required String qualification,
    required int experienceYears,
    String? licenseNumber,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;

      final idToken = await user.getIdToken();

      final response = await _makeHttpRequest(
        'POST',
        Uri.parse('$baseUrl/api/nurses/register'),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'uid': 'nurse_${DateTime.now().millisecondsSinceEpoch}',
          'fullName': fullName,
          'email': email,
          'mobileNumber': mobileNumber,
          'qualification': qualification,
          'experienceYears': experienceYears,
          'licenseNumber': licenseNumber,
          'hospitalAffiliation': hospitalId,
          'type': 'nurse',
        }),
      );

      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      print('Error adding nurse to hospital: $e');
      return false;
    }
  }

  // Update nurse information
  static Future<bool> updateNurse({
    required String nurseId,
    required Map<String, dynamic> updates,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;

      final idToken = await user.getIdToken();

      final response = await _makeHttpRequest(
        'PUT',
        Uri.parse('$baseUrl/api/nurses/$nurseId'),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(updates),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Error updating nurse: $e');
      return false;
    }
  }

  // Delete nurse
  static Future<bool> deleteNurse(String nurseId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;

      final idToken = await user.getIdToken();

      final response = await _makeHttpRequest(
        'DELETE',
        Uri.parse('$baseUrl/api/nurses/$nurseId'),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Error deleting nurse: $e');
      return false;
    }
  }

  // Get nurse shifts
  static Future<List<Map<String, dynamic>>> getNurseShifts(
      String nurseId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return [];

      final idToken = await user.getIdToken();

      final response = await _makeHttpRequest(
        'GET',
        Uri.parse('$baseUrl/api/nurses/$nurseId/shifts'),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null) {
          return List<Map<String, dynamic>>.from(data['data']);
        }
      }
      return [];
    } catch (e) {
      print('Error getting nurse shifts: $e');
      return [];
    }
  }

  // Assign shift to nurse
  static Future<bool> assignNurseShift({
    required String nurseId,
    required String shiftType,
    required String startTime,
    required String endTime,
    required String date,
    String? department,
    String? notes,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;

      final idToken = await user.getIdToken();

      final response = await _makeHttpRequest(
        'POST',
        Uri.parse('$baseUrl/api/nurses/$nurseId/shifts'),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'shiftType': shiftType,
          'startTime': startTime,
          'endTime': endTime,
          'date': date,
          'department': department,
          'notes': notes,
        }),
      );

      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      print('Error assigning nurse shift: $e');
      return false;
    }
  }

  // Update nurse shift
  static Future<bool> updateNurseShift({
    required String nurseId,
    required String shiftId,
    required Map<String, dynamic> updates,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;

      final idToken = await user.getIdToken();

      final response = await _makeHttpRequest(
        'PUT',
        Uri.parse('$baseUrl/api/nurses/$nurseId/shifts/$shiftId'),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(updates),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Error updating nurse shift: $e');
      return false;
    }
  }

  // Delete nurse shift
  static Future<bool> deleteNurseShift(String nurseId, String shiftId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;

      final idToken = await user.getIdToken();

      final response = await _makeHttpRequest(
        'DELETE',
        Uri.parse('$baseUrl/api/nurses/$nurseId/shifts/$shiftId'),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Error deleting nurse shift: $e');
      return false;
    }
  }

  // Get hospital departments
  static Future<List<String>> getHospitalDepartments(String hospitalId) async {
    try {
      return [
        'Cardiology',
        'Neurology',
        'Orthopedics',
        'Emergency Medicine',
        'General Surgery',
        'Pediatrics',
        'Obstetrics & Gynecology',
        'Radiology',
        'Pathology',
        'Anesthesiology',
      ];
    } catch (e) {
      print('Error getting hospital departments: $e');
      return [];
    }
  }

  // Get hospital patient admissions
  static Future<List<Map<String, dynamic>>> getHospitalAdmissions(
      String hospitalId) async {
    try {
      return [
        {
          'id': 'adm1',
          'patientName': 'John Doe',
          'patientId': 'PAT001',
          'admissionDate': DateTime.now().subtract(const Duration(days: 2)),
          'dischargeDate': null,
          'department': 'Cardiology',
          'doctor': 'Dr. John Smith',
          'status': 'Admitted',
          'roomNumber': '101',
          'bedNumber': 'A1',
        },
        {
          'id': 'adm2',
          'patientName': 'Jane Smith',
          'patientId': 'PAT002',
          'admissionDate': DateTime.now().subtract(const Duration(days: 1)),
          'dischargeDate': null,
          'department': 'Neurology',
          'doctor': 'Dr. Sarah Johnson',
          'status': 'Admitted',
          'roomNumber': '205',
          'bedNumber': 'B3',
        },
        {
          'id': 'adm3',
          'patientName': 'Mike Wilson',
          'patientId': 'PAT003',
          'admissionDate': DateTime.now().subtract(const Duration(days: 5)),
          'dischargeDate': DateTime.now().subtract(const Duration(days: 1)),
          'department': 'Orthopedics',
          'doctor': 'Dr. Michael Brown',
          'status': 'Discharged',
          'roomNumber': '301',
          'bedNumber': 'C2',
        },
      ];
    } catch (e) {
      print('Error getting hospital admissions: $e');
      return [];
    }
  }

  // Get hospital analytics
  static Future<Map<String, dynamic>> getHospitalAnalytics(
      String hospitalId) async {
    try {
      return {
        'dailyPatients': 45,
        'weeklyPatients': 320,
        'monthlyPatients': 1250,
        'totalDoctors': 25,
        'availableBeds': 350,
        'occupiedBeds': 280,
        'appointmentsToday': 18,
        'appointmentsThisWeek': 95,
        'revenueToday': 45000,
        'revenueThisWeek': 285000,
        'revenueThisMonth': 1200000,
        'departmentStats': {
          'Cardiology': {'patients': 12, 'doctors': 4},
          'Neurology': {'patients': 8, 'doctors': 3},
          'Orthopedics': {'patients': 15, 'doctors': 5},
          'Emergency': {'patients': 10, 'doctors': 6},
        },
        'patientTrends': {
          'lastWeek': [42, 38, 45, 51, 48, 39, 44],
          'lastMonth': [1250, 1180, 1320, 1280],
        },
      };
    } catch (e) {
      print('Error getting hospital analytics: $e');
      return {};
    }
  }

  // Add doctor to hospital
  static Future<bool> addDoctorToHospital({
    required String hospitalId,
    required UserModel doctor,
  }) async {
    try {
      print('Adding doctor ${doctor.fullName} to hospital $hospitalId');
      // Removed artificial delay for faster response
      return true;
    } catch (e) {
      print('Error adding doctor to hospital: $e');
      return false;
    }
  }

  // Remove doctor from hospital
  static Future<bool> removeDoctorFromHospital({
    required String hospitalId,
    required String doctorId,
  }) async {
    try {
      print('Removing doctor $doctorId from hospital $hospitalId');
      // Removed artificial delay for faster response
      return true;
    } catch (e) {
      print('Error removing doctor from hospital: $e');
      return false;
    }
  }

  // Approve appointment
  static Future<bool> approveAppointment({
    required String appointmentId,
    required String status,
  }) async {
    try {
      print('Approving appointment $appointmentId with status $status');
      // Removed artificial delay for faster response
      return true;
    } catch (e) {
      print('Error approving appointment: $e');
      return false;
    }
  }

  // Admit patient
  static Future<bool> admitPatient({
    required String hospitalId,
    required String patientId,
    required String department,
    required String doctorId,
    required String roomNumber,
    required String bedNumber,
  }) async {
    try {
      print('Admitting patient $patientId to hospital $hospitalId');
      // Removed artificial delay for faster response
      return true;
    } catch (e) {
      print('Error admitting patient: $e');
      return false;
    }
  }

  // Get hospital QR records
  static Future<List<Map<String, dynamic>>> getHospitalQrRecords(
      String hospitalId) async {
    try {
      return [
        {
          'id': 'qr1',
          'patientName': 'John Doe',
          'qrId': 'PAT001_QR',
          'department': 'Cardiology',
          'admissionDate': DateTime.now().subtract(const Duration(days: 2)),
          'status': 'Active',
        },
        {
          'id': 'qr2',
          'patientName': 'Jane Smith',
          'qrId': 'PAT002_QR',
          'department': 'Neurology',
          'admissionDate': DateTime.now().subtract(const Duration(days: 1)),
          'status': 'Active',
        },
        {
          'id': 'qr3',
          'patientName': 'Mike Wilson',
          'qrId': 'PAT003_QR',
          'department': 'Orthopedics',
          'admissionDate': DateTime.now().subtract(const Duration(days: 5)),
          'status': 'Discharged',
        },
      ];
    } catch (e) {
      print('Error getting hospital QR records: $e');
      return [];
    }
  }

  // Get real-time reports
  static Future<List<Map<String, dynamic>>> getRealTimeReports(
      String hospitalId) async {
    try {
      return [
        {
          'id': 'rep1',
          'type': 'Emergency Alert',
          'message': 'Emergency admission in Cardiology department',
          'timestamp': DateTime.now().subtract(const Duration(minutes: 5)),
          'priority': 'High',
          'department': 'Cardiology',
        },
        {
          'id': 'rep2',
          'type': 'Bed Availability',
          'message': 'Bed A3 in Room 201 is now available',
          'timestamp': DateTime.now().subtract(const Duration(minutes: 15)),
          'priority': 'Medium',
          'department': 'General',
        },
        {
          'id': 'rep3',
          'type': 'Doctor Assignment',
          'message': 'Dr. Sarah Johnson assigned to Emergency case',
          'timestamp': DateTime.now().subtract(const Duration(minutes: 30)),
          'priority': 'Medium',
          'department': 'Emergency',
        },
      ];
    } catch (e) {
      print('Error getting real-time reports: $e');
      return [];
    }
  }

  // ==================== ADVANCED HOSPITAL FEATURES ====================

  // Get staff chat messages
  static Future<List<Map<String, dynamic>>> getStaffChatMessages(
      String hospitalId) async {
    try {
      return [
        {
          'id': 'msg1',
          'sender': 'Dr. John Smith',
          'senderId': 'doc1',
          'message': 'Emergency case in Cardiology - need assistance',
          'timestamp': DateTime.now().subtract(const Duration(minutes: 5)),
          'priority': 'High',
        },
        {
          'id': 'msg2',
          'sender': 'Nurse Sarah',
          'senderId': 'nurse1',
          'message': 'Bed 205 is ready for new admission',
          'timestamp': DateTime.now().subtract(const Duration(minutes: 15)),
          'priority': 'Medium',
        },
        {
          'id': 'msg3',
          'sender': 'Admin',
          'senderId': 'admin1',
          'message': 'Monthly staff meeting tomorrow at 10 AM',
          'timestamp': DateTime.now().subtract(const Duration(hours: 1)),
          'priority': 'Low',
        },
      ];
    } catch (e) {
      print('Error getting staff chat messages: $e');
      return [];
    }
  }

  // Send staff message
  static Future<bool> sendStaffMessage({
    required String hospitalId,
    required String senderId,
    required String message,
    String priority = 'Medium',
  }) async {
    try {
      print('Sending staff message: $message');
      // Removed artificial delay for faster response
      return true;
    } catch (e) {
      print('Error sending staff message: $e');
      return false;
    }
  }

  // Get shift schedules
  static Future<List<Map<String, dynamic>>> getShiftSchedules(
      String hospitalId) async {
    try {
      return [
        {
          'id': 'shift1',
          'staffName': 'Dr. John Smith',
          'staffId': 'doc1',
          'department': 'Cardiology',
          'shiftType': 'Morning',
          'startTime': '08:00',
          'endTime': '16:00',
          'date': DateTime.now().add(const Duration(days: 1)),
          'status': 'Scheduled',
        },
        {
          'id': 'shift2',
          'staffName': 'Nurse Sarah',
          'staffId': 'nurse1',
          'department': 'Emergency',
          'shiftType': 'Night',
          'startTime': '20:00',
          'endTime': '08:00',
          'date': DateTime.now(),
          'status': 'Active',
        },
        {
          'id': 'shift3',
          'staffName': 'Dr. Sarah Johnson',
          'staffId': 'doc2',
          'department': 'Neurology',
          'shiftType': 'Afternoon',
          'startTime': '14:00',
          'endTime': '22:00',
          'date': DateTime.now().add(const Duration(days: 2)),
          'status': 'Scheduled',
        },
      ];
    } catch (e) {
      print('Error getting shift schedules: $e');
      return [];
    }
  }

  // Create shift schedule
  static Future<bool> createShiftSchedule({
    required String hospitalId,
    required String staffId,
    required String department,
    required String shiftType,
    required String startTime,
    required String endTime,
    required DateTime date,
  }) async {
    try {
      print('Creating shift schedule for staff: $staffId');
      // Removed artificial delay for faster response
      return true;
    } catch (e) {
      print('Error creating shift schedule: $e');
      return false;
    }
  }

  // Get advanced analytics
  static Future<Map<String, dynamic>> getAdvancedAnalytics(
      String hospitalId) async {
    try {
      return {
        'patientTrends': {
          'daily': [45, 52, 48, 61, 55, 49, 58],
          'weekly': [320, 345, 310, 335, 360, 325, 340],
          'monthly': [1250, 1180, 1320, 1280, 1350, 1290, 1310],
        },
        'revenueAnalytics': {
          'daily': [45000, 52000, 48000, 61000, 55000, 49000, 58000],
          'weekly': [320000, 345000, 310000, 335000, 360000, 325000, 340000],
          'monthly': [
            1200000,
            1180000,
            1320000,
            1280000,
            1350000,
            1290000,
            1310000
          ],
        },
        'departmentPerformance': {
          'Cardiology': {'patients': 12, 'revenue': 180000, 'efficiency': 85},
          'Neurology': {'patients': 8, 'revenue': 120000, 'efficiency': 78},
          'Orthopedics': {'patients': 15, 'revenue': 225000, 'efficiency': 92},
          'Emergency': {'patients': 10, 'revenue': 150000, 'efficiency': 88},
        },
        'staffUtilization': {
          'doctors': 85,
          'nurses': 92,
          'support': 78,
        },
      };
    } catch (e) {
      print('Error getting advanced analytics: $e');
      return {};
    }
  }

  // Get billing information
  static Future<List<Map<String, dynamic>>> getBillingRecords(
      String hospitalId) async {
    try {
      return [
        {
          'id': 'bill1',
          'patientName': 'John Doe',
          'patientId': 'PAT001',
          'amount': 25000,
          'status': 'Paid',
          'date': DateTime.now().subtract(const Duration(days: 2)),
          'type': 'Admission',
        },
        {
          'id': 'bill2',
          'patientName': 'Jane Smith',
          'patientId': 'PAT002',
          'amount': 15000,
          'status': 'Pending',
          'date': DateTime.now().subtract(const Duration(days: 1)),
          'type': 'Consultation',
        },
        {
          'id': 'bill3',
          'patientName': 'Mike Wilson',
          'patientId': 'PAT003',
          'amount': 35000,
          'status': 'Overdue',
          'date': DateTime.now().subtract(const Duration(days: 5)),
          'type': 'Surgery',
        },
      ];
    } catch (e) {
      print('Error getting billing records: $e');
      return [];
    }
  }

  // Get documents
  static Future<List<Map<String, dynamic>>> getHospitalDocuments(
      String hospitalId) async {
    try {
      return [
        {
          'id': 'doc1',
          'name': 'Patient Consent Form',
          'type': 'Form',
          'uploadDate': DateTime.now().subtract(const Duration(days: 1)),
          'size': '2.5 MB',
          'uploadedBy': 'Dr. John Smith',
        },
        {
          'id': 'doc2',
          'name': 'Insurance Policy',
          'type': 'Policy',
          'uploadDate': DateTime.now().subtract(const Duration(days: 3)),
          'size': '1.8 MB',
          'uploadedBy': 'Admin',
        },
        {
          'id': 'doc3',
          'name': 'Medical Report',
          'type': 'Report',
          'uploadDate': DateTime.now().subtract(const Duration(days: 5)),
          'size': '3.2 MB',
          'uploadedBy': 'Lab Technician',
        },
      ];
    } catch (e) {
      print('Error getting hospital documents: $e');
      return [];
    }
  }

  // Send notification
  static Future<bool> sendNotification({
    required String hospitalId,
    required String title,
    required String message,
    required String type,
    List<String>? recipients,
  }) async {
    try {
      print('Sending notification: $title - $message');
      // Removed artificial delay for faster response
      return true;
    } catch (e) {
      print('Error sending notification: $e');
      return false;
    }
  }

  // Get role permissions
  static Future<Map<String, List<String>>> getRolePermissions(
      String hospitalId) async {
    try {
      return {
        'admin': ['all'],
        'doctor': [
          'view_patients',
          'manage_appointments',
          'view_reports',
          'send_messages'
        ],
        'nurse': [
          'view_patients',
          'manage_admissions',
          'view_reports',
          'send_messages'
        ],
        'receptionist': [
          'view_appointments',
          'manage_admissions',
          'view_billing'
        ],
        'lab_technician': ['view_lab_tests', 'upload_reports'],
        'pharmacist': ['view_pharmacy', 'manage_inventory'],
      };
    } catch (e) {
      print('Error getting role permissions: $e');
      return {};
    }
  }

  // Search hospital data
  static Future<List<Map<String, dynamic>>> searchHospitalData({
    required String hospitalId,
    required String query,
    String? type,
  }) async {
    try {
      // Mock search results
      return [
        {
          'id': 'result1',
          'type': 'patient',
          'name': 'John Doe',
          'details': 'Patient ID: PAT001, Department: Cardiology',
        },
        {
          'id': 'result2',
          'type': 'doctor',
          'name': 'Dr. John Smith',
          'details': 'Cardiology, Experience: 15 years',
        },
        {
          'id': 'result3',
          'type': 'appointment',
          'name': 'Appointment #APT001',
          'details': 'Patient: John Doe, Date: 2024-06-15',
        },
      ];
    } catch (e) {
      print('Error searching hospital data: $e');
      return [];
    }
  }

  // Check user role
  static Future<String> getUserRole(String userId) async {
    try {
      // Mock role checking - in real app, this would check user permissions
      if (userId.contains('admin')) return 'admin';
      if (userId.contains('receptionist')) return 'receptionist';
      if (userId.contains('doctor')) return 'doctor';
      if (userId.contains('nurse')) return 'nurse';
      return 'staff';
    } catch (e) {
      print('Error checking user role: $e');
      return 'staff';
    }
  }

  static Future<List<UserModel>> fetchAllHospitals() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final idToken = await user?.getIdToken();
      if (idToken == null) return [];
      final response = await http.get(
        Uri.parse('$baseUrl/api/hospitals'),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
      );
      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        return data.map((e) => UserModel.fromJson(e)).toList();
      } else {
        print('Failed to fetch hospitals: ${response.body}');
        return [];
      }
    } catch (e) {
      print('Error fetching hospitals: $e');
      return [];
    }
  }

  static Future<bool> updateHospitalProfile(
      String uid, Map<String, dynamic> updates) async {
    try {
      print('🏥 Starting hospital profile update...');
      print('🏥 UID: $uid');
      print('🏥 Updates: $updates');

      final user = FirebaseAuth.instance.currentUser;
      final idToken = await user?.getIdToken();
      if (idToken == null) {
        print('❌ No Firebase user found');
        return false;
      }

      print('🏥 Firebase user found: ${user?.uid}');
      print('🏥 API URL: $baseUrl/api/hospitals/uid/$uid');

      final response = await http.put(
        Uri.parse('$baseUrl/api/hospitals/uid/$uid'),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(updates),
      );

      print('🏥 Response status: ${response.statusCode}');
      print('🏥 Response body: ${response.body}');

      return response.statusCode == 200;
    } catch (e) {
      print('❌ Error updating hospital profile: $e');
      return false;
    }
  }

  static Future<bool> updateUserProfile(
      String uid, Map<String, dynamic> updates) async {
    try {
      print('Updating user profile for $uid with payload:');
      print(updates);
      final user = FirebaseAuth.instance.currentUser;
      final idToken = await user?.getIdToken();
      if (idToken == null) return false;
      final response = await http.put(
        Uri.parse('$baseUrl/api/users/uid/$uid'),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(updates),
      );
      print('Backend response: ${response.statusCode} ${response.body}');
      return response.statusCode == 200;
    } catch (e) {
      print('Error updating user profile: $e');
      return false;
    }
  }

  static Future<bool> updateDoctorProfile(
      String uid, Map<String, dynamic> updates) async {
    try {
      print('Updating doctor profile for $uid with payload:');
      print(updates);
      final user = FirebaseAuth.instance.currentUser;
      final idToken = await user?.getIdToken();
      if (idToken == null) return false;
      final response = await http.put(
        Uri.parse('$baseUrl/api/doctors/$uid'),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(updates),
      );
      print(
          'Backend response:  [32m${response.statusCode} ${response.body} [0m');
      return response.statusCode == 200;
    } catch (e) {
      print('Error updating doctor profile: $e');
      return false;
    }
  }

  // Update nurse profile
  static Future<bool> updateNurseProfile(
      String uid, Map<String, dynamic> updates) async {
    try {
      print('Updating nurse profile for $uid with payload:');
      print(updates);
      final user = FirebaseAuth.instance.currentUser;
      final idToken = await user?.getIdToken();
      if (idToken == null) return false;
      final response = await http.put(
        Uri.parse('$baseUrl/api/nurses/$uid'),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(updates),
      );
      print(
          'Backend response:  [32m${response.statusCode} ${response.body} [0m');
      return response.statusCode == 200;
    } catch (e) {
      print('Error updating nurse profile: $e');
      return false;
    }
  }

  // Update lab profile
  static Future<bool> updateLabProfile(
      String uid, Map<String, dynamic> updates) async {
    try {
      print('Updating lab profile for $uid with payload:');
      print(updates);
      final user = FirebaseAuth.instance.currentUser;
      final idToken = await user?.getIdToken();
      if (idToken == null) return false;
      // Resolve Mongo _id for the lab first
      final mongoId = await getLabMongoId(uid);
      if (mongoId == null || mongoId.isEmpty) {
        print('❌ Could not resolve Lab Mongo _id for uid: $uid');
        return false;
      }
      final response = await http.put(
        Uri.parse('$baseUrl/api/labs/$mongoId'),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(updates),
      );
      print(
          'Backend response:  [32m${response.statusCode} ${response.body} [0m');
      return response.statusCode == 200;
    } catch (e) {
      print('Error updating lab profile: $e');
      return false;
    }
  }

  // Helper: fetch lab Mongo _id by Firebase UID
  static Future<String?> getLabMongoId(String uid) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final idToken = await user?.getIdToken();
      if (idToken == null) return null;

      // Try dedicated UID route first if available
      final uidUrl = Uri.parse('$baseUrl/api/labs/uid/$uid');
      final uidResp = await http.get(uidUrl, headers: {
        'Authorization': 'Bearer $idToken',
        'Content-Type': 'application/json',
      });
      if (uidResp.statusCode == 200) {
        final data = jsonDecode(uidResp.body);
        final obj = data is Map && data['data'] != null ? data['data'] : data;
        final mongoId = obj['_id'] ?? obj['id'];
        if (mongoId is String && mongoId.isNotEmpty) return mongoId;
      }

      // Fallback: use login/profile fetch already used elsewhere to read _id
      // Attempt generic users uid endpoint that may include type-specific fields
      final profileResp = await http.get(
        Uri.parse('$baseUrl/api/users/uid/$uid'),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
      );
      if (profileResp.statusCode == 200) {
        final data = jsonDecode(profileResp.body);
        final obj = data is Map && data['data'] != null ? data['data'] : data;
        final mongoId = obj['_id'] ?? obj['id'];
        if (mongoId is String && mongoId.isNotEmpty) return mongoId;
      }

      return null;
    } catch (e) {
      print('❌ getLabMongoId error: $e');
      return null;
    }
  }

  // Update pharmacy profile
  static Future<bool> updatePharmacyProfile(
      String uid, Map<String, dynamic> updates) async {
    try {
      print('Updating pharmacy profile for $uid with payload:');
      print(updates);
      final user = FirebaseAuth.instance.currentUser;
      final idToken = await user?.getIdToken();
      if (idToken == null) return false;
      final response = await http.put(
        Uri.parse('$baseUrl/api/pharmacies/uid/$uid'),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(updates),
      );
      print(
          'Backend response:  [32m${response.statusCode} ${response.body} [0m');
      return response.statusCode == 200;
    } catch (e) {
      print('Error updating pharmacy profile: $e');
      return false;
    }
  }

  // Update doctor
  static Future<bool> updateDoctor(String doctorId, UserModel doctor) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final idToken = await user?.getIdToken();
      if (idToken == null) return false;

      final response = await http.put(
        Uri.parse('$baseUrl/api/doctors/$doctorId'),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
        body: json.encode(doctor.toJson()),
      );

      if (response.statusCode == 200) {
        print('✅ Doctor updated successfully');
        return true;
      } else {
        print('❌ Failed to update doctor: ${response.body}');
        return false;
      }
    } catch (e) {
      print('❌ Error updating doctor: $e');
      return false;
    }
  }

  // Get user by ARC ID or UID for QR code scanning
  static Future<Map<String, dynamic>?> getHospitalByArcId(
      String identifier) async {
    try {
      // First try the QR endpoint
      var response = await http.get(
        Uri.parse('$baseUrl/api/hospitals/qr/$identifier'),
        headers: {
          'Content-Type': 'application/json',
        },
      );

      print('🏥 Hospital QR API Response Status: ${response.statusCode}');
      print('🏥 Hospital QR API Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('✅ Hospital QR data received successfully');
        return data;
      } else if (response.statusCode == 404) {
        print('❌ Hospital not found by QR identifier');
        return null;
      } else {
        print('❌ Hospital QR API error: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('❌ Error calling hospital QR API: $e');
      return null;
    }
  }

  // Get doctor by ARC ID or UID for QR code scanning
  static Future<Map<String, dynamic>?> getDoctorByArcId(
      String identifier) async {
    try {
      // First try the QR endpoint
      var response = await http.get(
        Uri.parse('$baseUrl/api/doctors/qr/$identifier'),
        headers: {
          'Content-Type': 'application/json',
        },
      );

      print('👨‍⚕️ Doctor QR API Response Status: ${response.statusCode}');
      print('👨‍⚕️ Doctor QR API Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('✅ Doctor QR data received successfully');
        // Backend now returns data directly, not wrapped in 'data' object
        return data;
      } else if (response.statusCode == 404) {
        print('❌ Doctor not found by QR identifier');
        return null;
      } else {
        print('❌ Doctor QR API error: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('❌ Error calling doctor QR API: $e');
      return null;
    }
  }

  // Get doctor by ARC ID directly from doctor collection
  static Future<Map<String, dynamic>?> getDoctorByArcIdDirect(
      String arcId) async {
    try {
      final token = await FirebaseAuth.instance.currentUser?.getIdToken();
      if (token == null) return null;

      print('👨‍⚕️ Searching doctor by ARC ID: $arcId');

      final response = await http.get(
        Uri.parse('$baseUrl/api/doctors/arc/$arcId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      print('👨‍⚕️ Doctor ARC API Response Status: ${response.statusCode}');
      print('👨‍⚕️ Doctor ARC API Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('✅ Doctor found by ARC ID successfully');
        return data;
      } else if (response.statusCode == 404) {
        print('❌ Doctor not found with ARC ID: $arcId');
        return null;
      } else {
        print('❌ Doctor ARC API error: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('❌ Error calling doctor ARC API: $e');
      return null;
    }
  }

  // Get nurse by ARC ID or UID for QR code scanning
  static Future<Map<String, dynamic>?> getNurseByArcId(
      String identifier) async {
    try {
      // First try the QR endpoint
      var response = await http.get(
        Uri.parse('$baseUrl/api/nurses/qr/$identifier'),
        headers: {
          'Content-Type': 'application/json',
        },
      );

      print('👩‍⚕️ Nurse QR API Response Status: ${response.statusCode}');
      print('👩‍⚕️ Nurse QR API Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('✅ Nurse QR data received successfully');
        // Return the data field from the response
        return data['data'];
      } else if (response.statusCode == 404) {
        print('❌ Nurse not found by QR identifier');
        return null;
      } else {
        print('❌ Nurse QR API error: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('❌ Error calling nurse QR API: $e');
      return null;
    }
  }

  // Get lab by ARC ID or UID for QR code scanning
  static Future<Map<String, dynamic>?> getLabByArcId(String identifier) async {
    try {
      // First try the QR endpoint
      var response = await http.get(
        Uri.parse('$baseUrl/api/labs/qr/$identifier'),
        headers: {
          'Content-Type': 'application/json',
        },
      );

      print('🧪 Lab QR API Response Status: ${response.statusCode}');
      print('🧪 Lab QR API Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('✅ Lab QR data received successfully');
        return data['data'];
      } else if (response.statusCode == 404) {
        print('❌ Lab not found by QR identifier');
        return null;
      } else {
        print('❌ Lab QR API error: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('❌ Error calling lab QR API: $e');
      return null;
    }
  }

  // Get pharmacy by ARC ID or UID for QR code scanning
  static Future<Map<String, dynamic>?> getPharmacyByArcId(
      String identifier) async {
    try {
      // First try the QR endpoint
      var response = await http.get(
        Uri.parse('$baseUrl/api/pharmacies/qr/$identifier'),
        headers: {
          'Content-Type': 'application/json',
        },
      );

      print('💊 Pharmacy QR API Response Status: ${response.statusCode}');
      print('💊 Pharmacy QR API Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('✅ Pharmacy QR data received successfully');
        return data;
      } else if (response.statusCode == 404) {
        print('❌ Pharmacy not found by QR identifier');
        return null;
      } else {
        print('❌ Pharmacy QR API error: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('❌ Error calling pharmacy QR API: $e');
      return null;
    }
  }

  // Get user profile by UID
  static Future<UserModel?> getUserProfile(String uid) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return null;

      final idToken = await user.getIdToken();
      final response = await http.get(
        Uri.parse('$baseUrl/api/users/profile'),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return UserModel.fromJson(data);
      } else {
        print('❌ Failed to get user profile: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('❌ Error getting user profile: $e');
      return null;
    }
  }

  // Get user dashboard statistics
  static Future<Map<String, dynamic>> getUserDashboardStats(String uid) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return {};

      final idToken = await user.getIdToken();
      final response = await http.get(
        Uri.parse('$baseUrl/api/users/$uid/dashboard-stats'),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        print('❌ Failed to get dashboard stats: ${response.statusCode}');
        return {};
      }
    } catch (e) {
      print('❌ Error getting dashboard stats: $e');
      return {};
    }
  }

  // Get user health summary
  static Future<Map<String, dynamic>> getUserHealthSummary(String uid) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return {};

      final idToken = await user.getIdToken();
      final response = await http.get(
        Uri.parse('$baseUrl/api/users/$uid/health-summary'),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        print('❌ Failed to get health summary: ${response.statusCode}');
        return {};
      }
    } catch (e) {
      print('❌ Error getting health summary: $e');
      return {};
    }
  }

  // Get user recent activities
  static Future<List<Map<String, dynamic>>> getUserRecentActivities(
      String uid) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return [];

      final idToken = await user.getIdToken();
      final response = await http.get(
        Uri.parse('$baseUrl/api/users/$uid/recent-activities'),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data);
      } else {
        print('❌ Failed to get recent activities: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('❌ Error getting recent activities: $e');
      return [];
    }
  }

  // Get user notifications
  static Future<List<Map<String, dynamic>>> getUserNotifications(
      String uid) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return [];

      final idToken = await user.getIdToken();
      final response = await http.get(
        Uri.parse('$baseUrl/api/users/$uid/notifications'),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data);
      } else {
        print('❌ Failed to get notifications: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('❌ Error getting notifications: $e');
      return [];
    }
  }

  // Get unread notifications count
  static Future<int> getUnreadNotificationsCount(String uid) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return 0;

      final idToken = await user.getIdToken();
      final response = await http.get(
        Uri.parse('$baseUrl/api/users/$uid/notifications/unread-count'),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['count'] ?? 0;
      } else {
        print(
            '❌ Failed to get unread notifications count: ${response.statusCode}');
        return 0;
      }
    } catch (e) {
      print('❌ Error getting unread notifications count: $e');
      return 0;
    }
  }

  // Get user appointments with details
  static Future<List<Map<String, dynamic>>> getUserAppointmentsWithDetails(
      String uid) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return [];

      final idToken = await user.getIdToken();
      final response = await http.get(
        Uri.parse('$baseUrl/api/users/$uid/appointments-with-details'),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data);
      } else {
        print(
            '❌ Failed to get appointments with details: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('❌ Error getting appointments with details: $e');
      return [];
    }
  }

  // Get user medications with details
  static Future<List<Map<String, dynamic>>> getUserMedicationsWithDetails(
      String uid) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return [];

      final idToken = await user.getIdToken();
      final response = await http.get(
        Uri.parse('$baseUrl/api/users/$uid/medications-with-details'),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data);
      } else {
        print(
            '❌ Failed to get medications with details: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('❌ Error getting medications with details: $e');
      return [];
    }
  }

  // Get user lab reports with details
  static Future<List<Map<String, dynamic>>> getUserLabReportsWithDetails(
      String uid) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return [];

      final idToken = await user.getIdToken();
      final response = await http.get(
        Uri.parse('$baseUrl/api/users/$uid/lab-reports-with-details'),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data);
      } else {
        print(
            '❌ Failed to get lab reports with details: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('❌ Error getting lab reports with details: $e');
      return [];
    }
  }

  // Get user prescriptions with details
  static Future<List<Map<String, dynamic>>> getUserPrescriptionsWithDetails(
      String uid) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return [];

      final idToken = await user.getIdToken();
      final response = await http.get(
        Uri.parse('$baseUrl/api/users/$uid/prescriptions-with-details'),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data);
      } else {
        print(
            '❌ Failed to get prescriptions with details: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('❌ Error getting prescriptions with details: $e');
      return [];
    }
  }

  // Universal user info fetch by UID (works for all user types)
  static Future<UserModel?> getUserInfo(String uid) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('❌ No Firebase user found');
        return null;
      }

      print('🔑 Firebase user found: ${user.uid}');

      // Check user type from SharedPreferences to determine which collection to check first
      final prefs = await SharedPreferences.getInstance();
      final userType = prefs.getString('user_type') ?? 'patient';

      print('🔍 getUserInfo called with UID: $uid, userType: $userType');

      // PRIORITY: First, try the collection based on stored user_type
      UserModel? userModel =
          await _checkCollectionByUserType(uid, userType, '');
      if (userModel != null) {
        print('✅ Found user in $userType collection (priority search)');
        return userModel;
      }

      // If not found in priority collection, check all collections systematically
      print(
          '🔍 User not found in $userType collection, checking all collections...');

      // Create a search order based on the selected user type
      List<String> searchOrder = [];

      // Add the selected user type first (if not already checked)
      if (userType != 'patient') {
        searchOrder.add(userType);
      }

      // Add other collections in logical order
      switch (userType) {
        case 'hospital':
          searchOrder.addAll(['doctor', 'nurse', 'lab', 'pharmacy', 'patient']);
          break;
        case 'doctor':
          searchOrder
              .addAll(['hospital', 'nurse', 'lab', 'pharmacy', 'patient']);
          break;
        case 'nurse':
          searchOrder
              .addAll(['hospital', 'doctor', 'lab', 'pharmacy', 'patient']);
          break;
        case 'lab':
          searchOrder
              .addAll(['hospital', 'doctor', 'nurse', 'pharmacy', 'patient']);
          break;
        case 'pharmacy':
          searchOrder.addAll(['hospital', 'doctor', 'nurse', 'lab', 'patient']);
          break;
        case 'patient':
        default:
          searchOrder
              .addAll(['hospital', 'doctor', 'nurse', 'lab', 'pharmacy']);
          break;
      }

      // Remove duplicates while preserving order
      searchOrder = searchOrder.toSet().toList();

      print('🔍 Search order: $searchOrder');

      // Search in the determined order
      for (String collectionType in searchOrder) {
        print('🔍 Checking $collectionType collection...');
        userModel = await _checkCollectionByUserType(uid, collectionType, '');
        if (userModel != null) {
          await prefs.setString('user_type', userModel.type);
          print('✅ Found user in $collectionType collection');
          return userModel;
        }
      }

      print('❌ User not found in any collection');
      return null;
    } catch (e) {
      print('❌ Error in getUserInfo: $e');
      return null;
    }
  }

  // Check service provider login and approval status
  static Future<UserModel?> checkServiceProviderLogin(
      String email, String userType) async {
    try {
      print(
          '🔍 Checking service provider login for email: $email, type: $userType');

      // Determine the endpoint based on user type (using unprotected login endpoints)
      String endpoint;
      switch (userType) {
        case 'hospital':
          endpoint = '$baseUrl/api/hospitals/login-email/$email';
          break;
        case 'doctor':
          endpoint = '$baseUrl/api/doctors/login-email/$email';
          break;
        case 'nurse':
          endpoint = '$baseUrl/api/nurses/login-email/$email';
          break;
        case 'lab':
          endpoint = '$baseUrl/api/labs/login-email/$email';
          break;
        case 'pharmacy':
          endpoint = '$baseUrl/api/pharmacies/login-email/$email';
          break;
        default:
          print('❌ Unknown user type: $userType');
          return null;
      }

      print('🌐 Calling endpoint: $endpoint');

      // Make the API call (no authentication required for login endpoints)
      final response = await _makeHttpRequest(
        'GET',
        Uri.parse(endpoint),
        headers: {
          'Content-Type': 'application/json',
        },
      );

      print('📡 Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('📋 Response data: $data');

        // Check if user exists and get approval status
        if (data != null && data['success'] == true) {
          final userData = data['data'] ?? data;
          print('📋 User data from backend: $userData');

          // Create UserModel from response
          try {
            final userModel = UserModel.fromJson(userData);
            print('✅ Service provider found: ${userModel.toJson()}');
            return userModel;
          } catch (e) {
            print('❌ Error creating UserModel from pharmacy data: $e');
            print('❌ User data that failed: $userData');
            return null;
          }
        } else {
          print('❌ User not found in response');
          return null;
        }
      } else if (response.statusCode == 404) {
        print('❌ User not found (404)');
        return null;
      } else {
        print('❌ API error: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      print('❌ Error checking service provider login: $e');
      return null;
    }
  }

  // Helper method to check a specific collection
  static Future<UserModel?> _checkCollectionByUserType(
      String uid, String userType, String idToken) async {
    try {
      String endpoint;
      switch (userType) {
        case 'hospital':
          endpoint = '$baseUrl/api/hospitals/uid/$uid';
          break;
        case 'doctor':
          endpoint = '$baseUrl/api/doctors/uid/$uid';
          break;
        case 'lab':
          endpoint = '$baseUrl/api/labs/uid/$uid';
          break;
        case 'nurse':
          endpoint = '$baseUrl/api/nurses/uid/$uid';
          break;
        case 'pharmacy':
          endpoint = '$baseUrl/api/pharmacies/uid/$uid';
          break;
        case 'patient':
        default:
          endpoint = '$baseUrl/api/users/$uid';
          break;
      }

      print('📡 Making request to: $endpoint');

      // Use the improved headers method
      final headers = await _getHeaders();

      final response = await http.get(
        Uri.parse(endpoint),
        headers: headers,
      );

      print('📡 $userType response status: ${response.statusCode}');
      print('📄 Response body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        print('✅ Found user in $userType collection');
        print('📋 Raw response data: $responseData');

        // Handle different response structures
        Map<String, dynamic> userData;
        if (responseData is Map<String, dynamic>) {
          if (responseData.containsKey('data')) {
            // Backend returns { success: true, data: {...} }
            userData = responseData['data'];
            print('📋 Extracted data from response.data');
          } else if (responseData.containsKey('success')) {
            // Backend returns { success: true, ... } without data wrapper
            userData = responseData;
            print('📋 Using response directly');
          } else {
            // Direct user data
            userData = responseData;
            print('📋 Using response as direct user data');
          }
        } else {
          print('❌ Unexpected response structure: $responseData');
          return null;
        }

        print('📋 User data before parsing: $userData');

        try {
          // Add the user type to the data if it's not present
          if (!userData.containsKey('type')) {
            userData['type'] = userType;
            print('🔧 Added missing type field: $userType');
          }

          final userModel = UserModel.fromJson(userData);
          print('✅ Parsed UserModel - type: ${userModel.type}');
          return userModel;
        } catch (parseError) {
          print('❌ Error parsing $userType data: $parseError');
          print('📋 Raw data: $userData');
          return null;
        }
      } else if (response.statusCode == 404) {
        print('❌ User not found in $userType collection (404)');
        return null;
      } else {
        print(
            '❌ Error response from $userType collection (${response.statusCode}): ${response.body}');
        return null;
      }
    } catch (e) {
      print('❌ Error checking $userType collection: $e');
      return null;
    }
  }

  // Get user info by email
  static Future<UserModel?> getUserInfoByEmail(String email) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final idToken = await user?.getIdToken();
      if (idToken == null) return null;
      final response = await http.get(
        Uri.parse('$baseUrl/api/users/email/$email'),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return UserModel.fromJson(data);
      } else {
        print('Failed to fetch user by email: ${response.body}');
        return null;
      }
    } catch (e) {
      print('Error fetching user info by email: $e');
      return null;
    }
  }

  // Get user info by phone
  static Future<UserModel?> getUserInfoByPhone(String phone) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final idToken = await user?.getIdToken();
      if (idToken == null) return null;

      final response = await _makeHttpRequest(
        'GET',
        Uri.parse('$baseUrl/api/users/phone/$phone'),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return UserModel.fromJson(data);
      } else {
        print('❌ Failed to get user by phone: ${response.body}');
        return null;
      }
    } catch (e) {
      print('❌ Error getting user by phone: $e');
      return null;
    }
  }

  static Future<UserModel?> getStaffInfo(String firebaseUid) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final idToken = await user?.getIdToken();
      if (idToken == null) return null;
      final response = await http.get(
        Uri.parse('$baseUrl/api/admin/staff/$firebaseUid'),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return UserModel.fromJson(data);
      } else {
        print('Failed to fetch staff: ${response.body}');
        return null;
      }
    } catch (e) {
      print('Error fetching staff info: $e');
      return null;
    }
  }

  static Future<bool> createStaff({
    required String firebaseUid,
    required String email,
    required String name,
    required String role,
    required String? idToken,
  }) async {
    try {
      final response = await _makeHttpRequest(
        'POST',
        Uri.parse('$baseUrl/api/admin/staff'),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
        body: {
          'firebaseUid': firebaseUid,
          'email': email,
          'name': name,
          'role': role,
        },
      );
      return response.statusCode == 201 || response.statusCode == 200;
    } catch (e) {
      print('Error creating staff: $e');
      return false;
    }
  }

  // Get Pending Hospitals (for admin)
  static Future<List<UserModel>> getPendingHospitals() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/hospitals/admin/pending'),
        headers: {
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => UserModel.fromJson(json)).toList();
      } else {
        print('Failed to get pending hospitals: ${response.body}');
        return [];
      }
    } catch (e) {
      print('Get pending hospitals error: $e');
      return [];
    }
  }

  // Approve Hospital
  static Future<bool> approveHospital(String hospitalId) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/api/hospitals/admin/approve/$hospitalId'),
        headers: {
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        print('Hospital approval failed: ${response.body}');
        return false;
      }
    } catch (e) {
      print('Hospital approval error: $e');
      return false;
    }
  }

  // Reject Hospital
  static Future<bool> rejectHospital(String hospitalId, String reason) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/api/hospitals/admin/reject/$hospitalId'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'reason': reason}),
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        print('Hospital rejection failed: ${response.body}');
        return false;
      }
    } catch (e) {
      print('Hospital rejection error: $e');
      return false;
    }
  }

  // Get Hospital Approval Status
  static Future<Map<String, dynamic>?> getHospitalApprovalStatus(
      String hospitalId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final idToken = await user?.getIdToken();
      if (idToken == null) return null;

      final response = await http.get(
        Uri.parse('$baseUrl/api/hospitals/$hospitalId/approval-status'),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data;
      } else {
        print('Failed to fetch hospital approval status: ${response.body}');
        // Return mock data for testing
        return {
          'approvalStatus': 'pending',
          'isApproved': false,
          'message': 'Your hospital registration is under review by ArcStaff.',
        };
      }
    } catch (e) {
      print('Error fetching hospital approval status: $e');
      // Return mock data for testing
      return {
        'approvalStatus': 'pending',
        'isApproved': false,
        'message': 'Your hospital registration is under review by ArcStaff.',
      };
    }
  }

  // Get Pharmacy Approval Status
  static Future<Map<String, dynamic>?> getPharmacyApprovalStatus(
      String pharmacyId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final idToken = await user?.getIdToken();
      if (idToken == null) return null;

      final response = await http.get(
        Uri.parse('$baseUrl/api/pharmacies/approval-status/$pharmacyId'),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['data'];
      } else {
        print('Failed to fetch pharmacy approval status: ${response.body}');
        // Return mock data for testing
        return {
          'approvalStatus': 'pending',
          'isApproved': false,
          'message': 'Your pharmacy registration is under review by ArcStaff.',
        };
      }
    } catch (e) {
      print('Error fetching pharmacy approval status: $e');
      // Return mock data for testing
      return {
        'approvalStatus': 'pending',
        'isApproved': false,
        'message': 'Your pharmacy registration is under review by ArcStaff.',
      };
    }
  }

  // Get Hospital Profile
  static Future<UserModel?> getHospitalProfile(String uid) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final idToken = await user?.getIdToken();
      if (idToken == null) return null;

      // Use UID-based endpoint to fetch hospital profile
      final response = await http.get(
        Uri.parse('$baseUrl/api/hospitals/uid/$uid'),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return UserModel.fromJson(data);
      } else {
        print('Failed to fetch hospital profile: ${response.body}');
        return null;
      }
    } catch (e) {
      print('Error fetching hospital profile: $e');
      return null;
    }
  }

  // Lab registration
  static Future<bool> registerLab(UserModel labUser) async {
    try {
      print(
          '🌐 Sending lab registration request to: $baseUrl/api/labs/register');

      // Map Flutter UserModel fields to backend Lab model fields
      final Map<String, dynamic> backendData = {
        'uid': labUser.uid,
        'fullName': labUser.fullName,
        'email': labUser.email,
        'mobileNumber': labUser.mobileNumber,
        'gender': labUser.gender,
        'dateOfBirth': labUser.dateOfBirth?.toIso8601String(),
        'address': labUser.address,
        'city': labUser.city,
        'state': labUser.state,
        'pincode': labUser.pincode,
        'qualification': labUser.qualification,
        'experienceYears': labUser.experienceYears,
        'licenseNumber': labUser.labLicenseNumber, // Map to licenseNumber
        'licenseDocumentUrl': labUser.licenseDocumentUrl,
        'labName': labUser.labName,
        'labLicenseNumber': labUser.labLicenseNumber,
        'associatedHospital': labUser.associatedHospital,
        'availableTests': labUser.availableTests,
        'servicesProvided':
            labUser.availableTests, // Map availableTests to servicesProvided
        'ownerName': labUser.ownerName, // Add ownerName field
        'labAddress': labUser.labAddress,
        'homeSampleCollection': labUser.homeSampleCollection,
        'profileImageUrl': labUser.profileImageUrl,
      };

      print('📋 Mapped lab data for backend: $backendData');

      // Get Firebase ID token for authentication
      final user = FirebaseAuth.instance.currentUser;
      final idToken = await user?.getIdToken();
      if (idToken == null) {
        print('❌ No Firebase user or ID token available');
        return false;
      }

      // Register lab in labs collection using the new HTTP method
      final labResponse = await _makeHttpRequest(
        'POST',
        Uri.parse('$baseUrl/api/labs/register'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
        body: backendData,
      );

      print('📡 Lab response status: ${labResponse.statusCode}');
      print('📡 Lab response body: ${labResponse.body}');

      if (labResponse.statusCode == 201 || labResponse.statusCode == 200) {
        print('✅ Lab registration successful');
        return true;
      } else {
        print('❌ Lab registration failed: ${labResponse.body}');
        return false;
      }
    } catch (e) {
      print('❌ Lab registration error: $e');
      return false;
    }
  }

  // Nurse registration
  static Future<bool> registerNurse(UserModel nurseUser) async {
    try {
      print(
          '🌐 Sending nurse registration request to: $baseUrl/api/nurses/register');

      // Map Flutter UserModel fields to backend Nurse model fields
      final Map<String, dynamic> backendData = {
        'uid': nurseUser.uid,
        'fullName': nurseUser.fullName,
        'email': nurseUser.email,
        'mobileNumber': nurseUser.mobileNumber,
        'gender': nurseUser.gender,
        'dateOfBirth': nurseUser.dateOfBirth?.toIso8601String(),
        'address': nurseUser.address,
        'city': nurseUser.city,
        'state': nurseUser.state,
        'pincode': nurseUser.pincode,
        'qualification': nurseUser.qualification,
        'experienceYears': nurseUser.experienceYears,
        'licenseNumber': nurseUser.licenseNumber,
        'licenseDocumentUrl': nurseUser.licenseDocumentUrl,
        'hospitalAffiliation': nurseUser.hospitalAffiliation,
        'profileImageUrl': nurseUser.profileImageUrl,
      };

      print('📋 Mapped nurse data for backend: $backendData');

      // Get Firebase ID token for authentication
      final user = FirebaseAuth.instance.currentUser;
      final idToken = await user?.getIdToken();
      if (idToken == null) {
        print('❌ No Firebase user or ID token available');
        return false;
      }

      // Register nurse in nurses collection using the new HTTP method
      final nurseResponse = await _makeHttpRequest(
        'POST',
        Uri.parse('$baseUrl/api/nurses/register'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
        body: backendData,
      );

      print('📡 Nurse response status: ${nurseResponse.statusCode}');
      print('📡 Nurse response body: ${nurseResponse.body}');

      if (nurseResponse.statusCode == 201 || nurseResponse.statusCode == 200) {
        print('✅ Nurse registration successful');
        return true;
      } else {
        print('❌ Nurse registration failed: ${nurseResponse.body}');
        return false;
      }
    } catch (e) {
      print('❌ Nurse registration error: $e');
      return false;
    }
  }

  // Pharmacy registration
  static Future<bool> registerPharmacy(UserModel pharmacyUser,
      {String? ownerName}) async {
    try {
      print(
          '🌐 Sending pharmacy registration request to: $baseUrl/api/pharmacies/register');

      // Map Flutter UserModel fields to backend Pharmacy model fields
      final Map<String, dynamic> backendData = {
        'uid': pharmacyUser.uid,
        'fullName': pharmacyUser.fullName,
        'email': pharmacyUser.email,
        'mobileNumber': pharmacyUser.mobileNumber,
        'gender': pharmacyUser.gender,
        'dateOfBirth': pharmacyUser.dateOfBirth?.toIso8601String(),
        'address': pharmacyUser.address,
        'city': pharmacyUser.city,
        'state': pharmacyUser.state,
        'pincode': pharmacyUser.pincode,
        'qualification': pharmacyUser.qualification,
        'experienceYears': pharmacyUser.experienceYears,
        'licenseNumber': pharmacyUser.licenseNumber,
        'licenseDocumentUrl': pharmacyUser.licenseDocumentUrl,
        'pharmacyName': pharmacyUser.pharmacyName,
        'pharmacyLicenseNumber': pharmacyUser.pharmacyLicenseNumber,
        'pharmacyAddress': pharmacyUser.pharmacyAddress,
        'operatingHours': pharmacyUser.operatingHours,
        'homeDelivery': pharmacyUser.homeDelivery,
        'drugLicenseUrl': pharmacyUser.drugLicenseUrl,
        'profileImageUrl': pharmacyUser.profileImageUrl,
        'ownerName': ownerName ??
            pharmacyUser
                .fullName, // Use provided ownerName or fallback to fullName
      };

      print('📋 Mapped pharmacy data for backend: $backendData');

      // Get Firebase ID token for authentication
      final user = FirebaseAuth.instance.currentUser;
      final idToken = await user?.getIdToken();
      if (idToken == null) {
        print('❌ No Firebase user or ID token available');
        return false;
      }

      // Register pharmacy in pharmacies collection using the new HTTP method
      final pharmacyResponse = await _makeHttpRequest(
        'POST',
        Uri.parse('$baseUrl/api/pharmacies/register'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
        body: backendData,
      );

      print('📡 Pharmacy response status: ${pharmacyResponse.statusCode}');
      print('📡 Pharmacy response body: ${pharmacyResponse.body}');

      if (pharmacyResponse.statusCode == 201 ||
          pharmacyResponse.statusCode == 200) {
        print('✅ Pharmacy registration successful');
        return true;
      } else {
        print('❌ Pharmacy registration failed: ${pharmacyResponse.body}');
        return false;
      }
    } catch (e) {
      print('❌ Pharmacy registration error: $e');
      return false;
    }
  }

  // ==================== REGISTRATION ENDPOINTS ====================

  // Lab Registration with Firebase Auth and Document Upload
  static Future<Map<String, dynamic>> registerLabWithDocuments({
    required String uid,
    required String labName,
    required String email,
    required String mobileNumber,
    required String licenseNumber,
    required String licenseDocumentUrl,
    required List<String> servicesProvided,
    required String ownerName,
    required String address,
    required String city,
    required String state,
    required String pincode,
    String? profileImageUrl,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final idToken = await user?.getIdToken();
      if (idToken == null) {
        throw Exception('No authenticated user found');
      }

      print('🔧 Registering lab with UID: $uid');
      print('📋 Lab data: $labName, $email, $mobileNumber');

      final response = await _makeHttpRequest(
        'POST',
        Uri.parse('$baseUrl/api/labs/register'),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
        body: {
          "uid": uid,
          "labName": labName,
          "email": email,
          "mobileNumber": mobileNumber,
          "licenseNumber": licenseNumber,
          "licenseDocumentUrl": licenseDocumentUrl,
          "servicesProvided": servicesProvided,
          "ownerName": ownerName,
          "address": address,
          "city": city,
          "state": state,
          "pincode": pincode,
          "profileImageUrl": profileImageUrl,
        },
      );

      print('📡 Lab registration response status: ${response.statusCode}');
      print('📄 Response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'message': 'Lab registered successfully',
          'data': data['data'],
        };
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Lab registration failed');
      }
    } catch (e) {
      print('❌ Lab registration error: $e');
      return {
        'success': false,
        'message': 'Lab registration failed: $e',
      };
    }
  }

  // Pharmacy Registration with Firebase Auth and Document Upload
  static Future<Map<String, dynamic>> registerPharmacyWithDocuments({
    required String uid,
    required String pharmacyName,
    required String email,
    required String ownerName,
    required String mobileNumber,
    required String licenseNumber,
    required String licenseDocumentUrl,
    required String address,
    required String city,
    required String state,
    required String pincode,
    List<String>? drugsAvailable,
    String? profileImageUrl,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final idToken = await user?.getIdToken();
      if (idToken == null) {
        throw Exception('No authenticated user found');
      }

      print('🔧 Registering pharmacy with UID: $uid');
      print('📋 Pharmacy data: $pharmacyName, $email, $mobileNumber');

      final response = await _makeHttpRequest(
        'POST',
        Uri.parse('$baseUrl/api/pharmacies/register'),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
        body: {
          "uid": uid,
          "pharmacyName": pharmacyName,
          "email": email,
          "ownerName": ownerName,
          "mobileNumber": mobileNumber,
          "licenseNumber": licenseNumber,
          "licenseDocumentUrl": licenseDocumentUrl,
          "drugsAvailable": drugsAvailable ?? [],
          "address": address,
          "city": city,
          "state": state,
          "pincode": pincode,
          "profileImageUrl": profileImageUrl,
        },
      );

      print('📡 Pharmacy registration response status: ${response.statusCode}');
      print('📄 Response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'message': 'Pharmacy registered successfully',
          'data': data['data'],
        };
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Pharmacy registration failed');
      }
    } catch (e) {
      print('❌ Pharmacy registration error: $e');
      return {
        'success': false,
        'message': 'Pharmacy registration failed: $e',
      };
    }
  }

  // Nurse Registration with Firebase Auth and Document Upload
  static Future<Map<String, dynamic>> registerNurseWithDocuments({
    required String uid,
    required String fullName,
    required String email,
    required String mobileNumber,
    required String gender,
    required DateTime dateOfBirth,
    required String qualification,
    required int experienceYears,
    required String licenseNumber,
    required String licenseDocumentUrl,
    required String hospitalAffiliation,
    required String address,
    required String city,
    required String state,
    required String pincode,
    String? profileImageUrl,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final idToken = await user?.getIdToken();
      if (idToken == null) {
        throw Exception('No authenticated user found');
      }

      print('🔧 Registering nurse with UID: $uid');
      print('📋 Nurse data: $fullName, $email, $mobileNumber');

      final response = await _makeHttpRequest(
        'POST',
        Uri.parse('$baseUrl/api/nurses/register'),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
        body: {
          "uid": uid,
          "fullName": fullName,
          "email": email,
          "mobileNumber": mobileNumber,
          "gender": gender,
          "dateOfBirth": dateOfBirth.toIso8601String(),
          "qualification": qualification,
          "experienceYears": experienceYears,
          "licenseNumber": licenseNumber,
          "licenseDocumentUrl": licenseDocumentUrl,
          "hospitalAffiliation": hospitalAffiliation,
          "address": address,
          "city": city,
          "state": state,
          "pincode": pincode,
          "profileImageUrl": profileImageUrl,
        },
      );

      print('📡 Nurse registration response status: ${response.statusCode}');
      print('📄 Response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'message': 'Nurse registered successfully',
          'data': data['data'],
        };
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Nurse registration failed');
      }
    } catch (e) {
      print('❌ Nurse registration error: $e');
      return {
        'success': false,
        'message': 'Nurse registration failed: $e',
      };
    }
  }

  // Doctor Registration with Firebase Auth and Document Upload
  static Future<Map<String, dynamic>> registerDoctorWithDocuments({
    required String uid,
    required String fullName,
    required String email,
    required String mobileNumber,
    required String gender,
    required DateTime dateOfBirth,
    required String specialization,
    required String qualification,
    required int experienceYears,
    required String licenseNumber,
    required String licenseDocumentUrl,
    required String hospitalAffiliation,
    required String address,
    required String city,
    required String state,
    required String pincode,
    String? profileImageUrl,
    String? about,
    double? consultationFee,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final idToken = await user?.getIdToken();
      if (idToken == null) {
        throw Exception('No authenticated user found');
      }

      print('🔧 Registering doctor with UID: $uid');
      print('📋 Doctor data: $fullName, $email, $mobileNumber');

      final response = await _makeHttpRequest(
        'POST',
        Uri.parse('$baseUrl/api/doctors/register'),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
        body: {
          "uid": uid,
          "fullName": fullName,
          "email": email,
          "mobileNumber": mobileNumber,
          "gender": gender,
          "dateOfBirth": dateOfBirth.toIso8601String(),
          "specialization": specialization,
          "qualification": qualification,
          "experienceYears": experienceYears,
          "licenseNumber": licenseNumber,
          "licenseDocumentUrl": licenseDocumentUrl,
          "hospitalAffiliation": hospitalAffiliation,
          "address": address,
          "city": city,
          "state": state,
          "pincode": pincode,
          "profileImageUrl": profileImageUrl,
          "about": about,
          "consultationFee": consultationFee,
        },
      );

      print('📡 Doctor registration response status: ${response.statusCode}');
      print('📄 Response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'message': 'Doctor registered successfully',
          'data': data['data'],
        };
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Doctor registration failed');
      }
    } catch (e) {
      print('❌ Doctor registration error: $e');
      return {
        'success': false,
        'message': 'Doctor registration failed: $e',
      };
    }
  }

  // Hospital Registration with Firebase Auth and Document Upload
  static Future<Map<String, dynamic>> registerHospitalWithDocuments({
    required String uid,
    required String fullName,
    required String email,
    required String mobileNumber,
    required String hospitalName,
    required String registrationNumber,
    required String hospitalType,
    required String address,
    required String city,
    required String state,
    required String pincode,
    required int numberOfBeds,
    required List<String> departments,
    required List<String> specialFacilities,
    required bool hasPharmacy,
    required bool hasLab,
    required String licenseDocumentUrl,
    String? profileImageUrl,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final idToken = await user?.getIdToken();
      if (idToken == null) {
        throw Exception('No authenticated user found');
      }

      print('🔧 Registering hospital with UID: $uid');
      print('📋 Hospital data: $hospitalName, $email, $mobileNumber');

      final response = await _makeHttpRequest(
        'POST',
        Uri.parse('$baseUrl/api/hospitals/register'),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
        body: {
          "uid": uid,
          "fullName": fullName,
          "email": email,
          "mobileNumber": mobileNumber,
          "hospitalName": hospitalName,
          "registrationNumber": registrationNumber,
          "hospitalType": hospitalType,
          "address": address,
          "city": city,
          "state": state,
          "pincode": pincode,
          "numberOfBeds": numberOfBeds,
          "departments": departments,
          "specialFacilities": specialFacilities,
          "hasPharmacy": hasPharmacy,
          "hasLab": hasLab,
          "licenseDocumentUrl": licenseDocumentUrl,
          "profileImageUrl": profileImageUrl,
        },
      );

      print('📡 Hospital registration response status: ${response.statusCode}');
      print('📄 Response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'message': 'Hospital registered successfully',
          'data': data['data'],
        };
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Hospital registration failed');
      }
    } catch (e) {
      print('❌ Hospital registration error: $e');
      return {
        'success': false,
        'message': 'Hospital registration failed: $e',
      };
    }
  }

  // Save report metadata after Firebase upload
  static Future<bool> saveReportMetadata({
    required String name,
    required String url,
    required String userId,
    required String type,
    String? description,
    String? category,
    int? fileSize,
    String? mimeType,
    String? uploadedBy,
  }) async {
    try {
      final uri = Uri.parse(
          'https://arcular-plus-backend.onrender.com/api/reports/save-metadata');

      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'name': name,
          'url': url,
          'patientId': userId,
          'type': type,
          'description': description ?? '',
          'category': category ?? 'Other',
          'fileSize': fileSize ?? 0,
          'mimeType': mimeType ?? 'application/octet-stream',
          'uploadedBy': uploadedBy ?? '',
        }),
      );

      if (response.statusCode == 201) {
        return true;
      } else {
        print('Failed to save report metadata: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('Error saving report metadata: $e');
      return false;
    }
  }

  // Search medicines from pharmacy inventory
  static Future<List<Map<String, dynamic>>> searchMedicines(String searchQuery,
      {String? city}) async {
    try {
      final uri =
          Uri.parse('$baseUrl/api/pharmacies/inventory/medicines/search')
              .replace(
        queryParameters: {
          if (searchQuery.isNotEmpty) 'searchQuery': searchQuery,
          if (city != null && city.isNotEmpty) 'city': city,
        },
      );

      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['data'] ?? []);
      } else {
        throw Exception('Failed to search medicines');
      }
    } catch (e) {
      print('❌ Error searching medicines: $e');
      rethrow;
    }
  }

  // Get reports for a specific user
  static Future<List<ReportModel>> getReportsByUser(String userId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final idToken = await user?.getIdToken();
      if (idToken == null) return [];

      final response = await http.get(
        Uri.parse('$baseUrl/api/reports/user/$userId'),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
      );

      print(
          '🔍 Reports API Response: ${response.statusCode} - ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);

        // Handle both array and object with data property
        List data;
        if (responseData is Map && responseData.containsKey('data')) {
          data = responseData['data'] ?? [];
        } else if (responseData is List) {
          data = responseData;
        } else {
          print('❌ Unexpected response format: $responseData');
          return [];
        }

        print('📊 Parsed reports data: ${data.length} items');
        return data.map((report) => ReportModel.fromJson(report)).toList();
      } else {
        print(
            '❌ Failed to fetch reports: ${response.statusCode} - ${response.body}');
        return [];
      }
    } catch (e) {
      print('❌ Error fetching reports: $e');
      return [];
    }
  }

  // Save menstrual cycle data
  static Future<bool> saveMenstrualCycleData(
      String uid, Map<String, dynamic> cycleData) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final idToken = await user?.getIdToken();
      if (idToken == null) return false;

      // Transform data to match backend model
      final backendData = {
        'userId': uid,
        'lastPeriodStartDate': cycleData['lastPeriodStartDate'],
        'cycleLength': cycleData['cycleLength'],
        'periodDuration': cycleData['periodDuration'],
        'cycleHistory': cycleData['cycleHistory'],
        // Store frontend calculated predictions
        'nextPeriod': cycleData['nextPeriod'],
        'ovulationDay': cycleData['ovulationDay'],
        'fertileWindow': cycleData['fertileWindow'],
        'periodEnd': cycleData['periodEnd'],
        // Store reminder preferences directly (not nested)
        'remindNextPeriod': cycleData['remindNextPeriod'] ?? false,
        'remindFertileWindow': cycleData['remindFertileWindow'] ?? false,
        'remindOvulation': cycleData['remindOvulation'] ?? false,
        'reminderTime': cycleData['reminderTime'] is TimeOfDay
            ? '${cycleData['reminderTime'].hour.toString().padLeft(2, '0')}:${cycleData['reminderTime'].minute.toString().padLeft(2, '0')}'
            : cycleData['reminderTime'],
      };

      print('🔍 Saving to backend: ${json.encode(backendData)}');

      final response = await _makeHttpRequest(
        'POST',
        Uri.parse('$baseUrl/api/menstrual-cycle/create'),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
        body: backendData,
      );

      print(
          '🔍 Menstrual cycle save response: ${response.statusCode} ${response.body}');
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      print('❌ Error saving menstrual cycle data: $e');
      return false;
    }
  }

  // Get menstrual cycle data
  static Future<Map<String, dynamic>?> getMenstrualCycleData(String uid) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final idToken = await user?.getIdToken();
      if (idToken == null) return null;

      final response = await _makeHttpRequest(
        'GET',
        Uri.parse('$baseUrl/api/menstrual-cycle/user/$uid'),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('🔍 Raw backend response: $data');

        // Transform backend data to frontend format
        if (data is List && data.isNotEmpty) {
          final latestData = data[0]; // Get the most recent entry
          print('🔍 Latest data from backend: $latestData');
        } else if (data is Map) {
          // If data is already a single object
          final latestData = data;
          print('🔍 Single data object from backend: $latestData');

          // Parse reminder time properly
          String reminderTimeString = '09:00'; // Default
          if (latestData['reminderTime'] != null) {
            try {
              final timeValue = latestData['reminderTime'];
              print(
                  '🔍 Raw reminder time from backend: $timeValue (type: ${timeValue.runtimeType})');

              if (timeValue is String) {
                reminderTimeString = timeValue;
                print('✅ Reminder time is string: $reminderTimeString');
              } else if (timeValue is Map &&
                  timeValue['hour'] != null &&
                  timeValue['minute'] != null) {
                // Handle TimeOfDay object from backend
                final hour = timeValue['hour'].toString().padLeft(2, '0');
                final minute = timeValue['minute'].toString().padLeft(2, '0');
                reminderTimeString = '$hour:$minute';
                print('✅ Converted TimeOfDay to string: $reminderTimeString');
              } else {
                print('⚠️ Unknown reminder time format: $timeValue');
                reminderTimeString = '09:00';
              }
            } catch (e) {
              print('⚠️ Error parsing reminder time: $e');
              reminderTimeString = '09:00';
            }
          } else {
            print('⚠️ No reminder time found in backend data');
            reminderTimeString = '09:00';
          }

          // Transform cycleHistory to match frontend format
          List<Map<String, dynamic>> transformedHistory = [];
          if (latestData['cycleHistory'] != null) {
            print(
                '🔍 Raw cycleHistory from backend: ${latestData['cycleHistory']}');
            for (var entry in latestData['cycleHistory']) {
              print('🔍 Processing cycle history entry: $entry');
              transformedHistory.add({
                'id': entry['_id']?.toString() ??
                    entry['id']?.toString() ??
                    DateTime.now().millisecondsSinceEpoch.toString(),
                'startDate': entry['startDate']?.toString() ?? '',
                'cycleLength': latestData['cycleLength'] ?? 28,
                'periodDuration': latestData['periodDuration'] ?? 5,
                'createdAt': entry['createdAt']?.toString() ??
                    DateTime.now().toIso8601String(),
              });
            }
            print('🔍 Transformed cycleHistory: $transformedHistory');
          } else {
            print('⚠️ No cycleHistory found in backend data');
          }

          print('🔍 Transformed reminder time: $reminderTimeString');
          print('🔍 Transformed history: ${transformedHistory.length} entries');

          final result = {
            'lastPeriodStartDate': latestData['lastPeriodStartDate'],
            'cycleLength': latestData['cycleLength'],
            'periodDuration': latestData['periodDuration'],
            'remindNextPeriod': latestData['remindNextPeriod'] ?? false,
            'remindFertileWindow': latestData['remindFertileWindow'] ?? false,
            'remindOvulation': latestData['remindOvulation'] ?? false,
            'reminderTime': reminderTimeString,
            'cycleHistory': transformedHistory,
          };

          print('🔍 Final transformed data:');
          print('   - lastPeriodStartDate: ${result['lastPeriodStartDate']}');
          print('   - cycleLength: ${result['cycleLength']}');
          print('   - periodDuration: ${result['periodDuration']}');
          print('   - remindNextPeriod: ${result['remindNextPeriod']}');
          print('   - remindFertileWindow: ${result['remindFertileWindow']}');
          print('   - remindOvulation: ${result['remindOvulation']}');
          print('   - reminderTime: ${result['reminderTime']}');
          print('   - cycleHistory: ${result['cycleHistory'].length} entries');

          return result;
        }
        return null;
      } else {
        print('❌ Failed to get menstrual cycle data: ${response.body}');
        return null;
      }
    } catch (e) {
      print('❌ Error getting menstrual cycle data: $e');
      return null;
    }
  }

  // Get upcoming reminders using backend standardized calculations
  static Future<List<Map<String, dynamic>>> getUpcomingRemindersFromBackend(
      String uid) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final idToken = await user?.getIdToken();
      if (idToken == null) return [];

      final response = await _makeHttpRequest(
        'GET',
        Uri.parse('$baseUrl/api/menstrual-cycle/upcoming-reminders/$uid'),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          print('✅ Backend upcoming reminders: ${data['data']}');
          return List<Map<String, dynamic>>.from(data['data']);
        }
      } else {
        print(
            '❌ Failed to get upcoming reminders from backend: ${response.body}');
      }
      return [];
    } catch (e) {
      print('❌ Error getting upcoming reminders from backend: $e');
      return [];
    }
  }

  // Calculate predictions using backend standardized formula
  static Future<Map<String, dynamic>?> calculatePredictionsFromBackend({
    required String lastPeriodStartDate,
    required int cycleLength,
    required int periodDuration,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final idToken = await user?.getIdToken();
      if (idToken == null) return null;

      final response = await _makeHttpRequest(
        'POST',
        Uri.parse('$baseUrl/api/menstrual-cycle/calculate-predictions'),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'lastPeriodStartDate': lastPeriodStartDate,
          'cycleLength': cycleLength,
          'periodDuration': periodDuration,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          print('✅ Backend predictions calculated: ${data['data']}');
          return data['data'];
        }
      } else {
        print(
            '❌ Failed to calculate predictions from backend: ${response.body}');
      }
      return null;
    } catch (e) {
      print('❌ Error calculating predictions from backend: $e');
      return null;
    }
  }

  // Delete menstrual cycle entry
  static Future<bool> deleteMenstrualCycleEntry(
      String uid, String entryId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final idToken = await user?.getIdToken();
      if (idToken == null) return false;

      final response = await _makeHttpRequest(
        'DELETE',
        Uri.parse('$baseUrl/api/menstrual-cycle/$uid/$entryId'),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
      );

      print(
          '🔍 Menstrual cycle delete response: ${response.statusCode} ${response.body}');
      return response.statusCode == 200;
    } catch (e) {
      print('❌ Error deleting menstrual cycle entry: $e');
      return false;
    }
  }

  // Send appointment notification
  static Future<bool> sendAppointmentNotification({
    required String userId,
    required String title,
    required String body,
    required Map<String, dynamic> data,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final idToken = await user?.getIdToken();
      if (idToken == null) return false;

      final response = await _makeHttpRequest(
        'POST',
        Uri.parse('$baseUrl/api/notifications/send'),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
        body: {
          'userId': userId,
          'type': 'appointment',
          'title': title,
          'body': body,
          'data': data,
        },
      );

      print(
          '🔔 Appointment notification response: ${response.statusCode} ${response.body}');
      return response.statusCode == 200;
    } catch (e) {
      print('❌ Error sending appointment notification: $e');
      return false;
    }
  }

  // Send lab report notification
  static Future<bool> sendLabReportNotification({
    required String userId,
    required String title,
    required String body,
    required Map<String, dynamic> data,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final idToken = await user?.getIdToken();
      if (idToken == null) return false;

      final response = await _makeHttpRequest(
        'POST',
        Uri.parse('$baseUrl/api/notifications/send'),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
        body: {
          'userId': userId,
          'type': 'lab_report',
          'title': title,
          'body': body,
          'data': data,
        },
      );

      print(
          '🔔 Lab report notification response: ${response.statusCode} ${response.body}');
      return response.statusCode == 200;
    } catch (e) {
      print('❌ Error sending lab report notification: $e');
      return false;
    }
  }

  // Send hospital update notification
  static Future<bool> sendHospitalUpdateNotification({
    required String userId,
    required String title,
    required String body,
    required Map<String, dynamic> data,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final idToken = await user?.getIdToken();
      if (idToken == null) return false;

      final response = await _makeHttpRequest(
        'POST',
        Uri.parse('$baseUrl/api/notifications/send'),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
        body: {
          'userId': userId,
          'type': 'hospital_update',
          'title': title,
          'body': body,
          'data': data,
        },
      );

      print(
          '🔔 Hospital update notification response: ${response.statusCode} ${response.body}');
      return response.statusCode == 200;
    } catch (e) {
      print('❌ Error sending hospital update notification: $e');
      return false;
    }
  }

  // SOS Emergency System
  static Future<Map<String, dynamic>?> activateSOS({
    required double latitude,
    required double longitude,
    String? city,
    String? state,
    String? pincode,
    Map<String, dynamic>? userInfo,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final idToken = await user?.getIdToken();
      if (idToken == null) return null;

      final response = await _makeHttpRequest(
        'POST',
        Uri.parse('$baseUrl/api/notifications/sos/activate'),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
        body: {
          'latitude': latitude,
          'longitude': longitude,
          'city': city,
          'state': state,
          'pincode': pincode,
          'userInfo': userInfo,
        },
      );

      print(
          '🚨 SOS activation response: ${response.statusCode} ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        return responseData['data'];
      } else {
        print(
            '❌ Failed to activate SOS: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      print('❌ Error activating SOS: $e');
      return null;
    }
  }

  // Accept emergency by hospital
  static Future<bool> acceptEmergency({
    required String emergencyId,
    required String hospitalId,
    required String hospitalName,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final idToken = await user?.getIdToken();
      if (idToken == null) return false;

      final response = await _makeHttpRequest(
        'POST',
        Uri.parse('$baseUrl/api/notifications/sos/accept'),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
        body: {
          'emergencyId': emergencyId,
          'hospitalId': hospitalId,
          'hospitalName': hospitalName,
        },
      );

      print(
          '✅ Emergency acceptance response: ${response.statusCode} ${response.body}');
      return response.statusCode == 200;
    } catch (e) {
      print('❌ Error accepting emergency: $e');
      return false;
    }
  }

  // Get approved hospitals for affiliation selection
  static Future<List<Map<String, dynamic>>>
      getApprovedHospitalsForAffiliation() async {
    try {
      print('🏥 API: Starting to fetch approved hospitals...');

      // Try to get authenticated user, but don't fail if not available (for registration)
      final user = FirebaseAuth.instance.currentUser;
      String? idToken;

      if (user != null) {
        try {
          idToken = await user.getIdToken();
          print('🏥 API: User authenticated, using token');
        } catch (e) {
          print(
              '⚠️ API: Failed to get token, proceeding without authentication');
        }
      } else {
        print(
            '⚠️ API: No user found, proceeding without authentication (registration mode)');
      }

      print(
          '🏥 API: Making request to: $baseUrl/api/hospitals/affiliation/approved');

      // Prepare headers
      final headers = <String, String>{
        'Content-Type': 'application/json',
      };

      // Add authorization header if token is available
      if (idToken != null) {
        headers['Authorization'] = 'Bearer $idToken';
      }

      final response = await _makeHttpRequest(
        'GET',
        Uri.parse('$baseUrl/api/hospitals/affiliation/approved'),
        headers: headers,
      );

      print('🏥 API: Response status: ${response.statusCode}');
      print('🏥 API: Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null) {
          final hospitals =
              List<Map<String, dynamic>>.from(data['data']['hospitals']);
          print('🏥 API: Successfully fetched ${hospitals.length} hospitals');
          return hospitals;
        } else {
          print('⚠️ API: Response success=false or no data');
          return [];
        }
      } else {
        print('❌ API: HTTP error ${response.statusCode}: ${response.body}');
        return [];
      }
    } catch (e) {
      print('❌ API: Error fetching approved hospitals: $e');
      rethrow; // Re-throw to let the widget handle the error
    }
  }

  // Search hospitals for affiliation
  static Future<List<Map<String, dynamic>>> searchHospitalsForAffiliation({
    String? query,
    String? city,
    String? state,
  }) async {
    try {
      print('🔍 API: Starting to search hospitals...');

      // Try to get authenticated user, but don't fail if not available (for registration)
      final user = FirebaseAuth.instance.currentUser;
      String? idToken;

      if (user != null) {
        try {
          idToken = await user.getIdToken();
          print('🔍 API: User authenticated, using token');
        } catch (e) {
          print(
              '⚠️ API: Failed to get token, proceeding without authentication');
        }
      } else {
        print(
            '⚠️ API: No user found, proceeding without authentication (registration mode)');
      }

      final queryParams = <String, String>{};
      if (query != null && query.isNotEmpty) queryParams['query'] = query;
      if (city != null && city.isNotEmpty) queryParams['city'] = city;
      if (state != null && state.isNotEmpty) queryParams['state'] = state;

      final uri =
          Uri.parse('$baseUrl/api/hospitals/affiliation/search').replace(
        queryParameters: queryParams,
      );

      // Prepare headers
      final headers = <String, String>{
        'Content-Type': 'application/json',
      };

      // Add authorization header if token is available
      if (idToken != null) {
        headers['Authorization'] = 'Bearer $idToken';
      }

      print('🔍 API: Making request to: $uri');
      final response = await _makeHttpRequest(
        'GET',
        uri,
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null) {
          return List<Map<String, dynamic>>.from(data['data']['hospitals']);
        }
      }
      return [];
    } catch (e) {
      print('❌ Error searching hospitals: $e');
      return [];
    }
  }

  // Create appointment
  static Future<Map<String, dynamic>> createAppointment(
      Map<String, dynamic> appointmentData) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final idToken = await user.getIdToken();

      // Try known routes in sequence to avoid 404s across environments
      final endpoints = <String>[
        '$baseUrl/api/appointments/create',
        '$baseUrl/api/appointments',
        '$baseUrl/api/appointments/book',
      ];

      // If hospitalId provided, also try hospital-scoped endpoint
      try {
        final hospitalId = appointmentData['hospitalId'];
        if (hospitalId is String && hospitalId.isNotEmpty) {
          endpoints.insert(
              0, '$baseUrl/api/hospitals/$hospitalId/appointments');
        }
      } catch (_) {}

      Map<String, dynamic>? last;
      for (final url in endpoints) {
        try {
          final resp = await http.post(
            Uri.parse(url),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $idToken',
            },
            body: json.encode(appointmentData),
          );

          // Parse response
          Map<String, dynamic> parsed;
          try {
            parsed = json.decode(resp.body) as Map<String, dynamic>;
          } catch (_) {
            parsed = {
              'success': resp.statusCode >= 200 && resp.statusCode < 300,
              'status': resp.statusCode
            };
          }

          // Accept success based on explicit flag or 2xx
          if (parsed['success'] == true ||
              (resp.statusCode >= 200 && resp.statusCode < 300)) {
            return {
              'success': true,
              'data': parsed['data'] ?? parsed,
            };
          }
          last = parsed;
          // On 404 or route mismatch, fall through to next endpoint
          if (resp.statusCode == 404) {
            continue;
          }
        } catch (e) {
          // Try next endpoint
          last = {'success': false, 'error': e.toString()};
        }
      }

      return last ??
          {'success': false, 'error': 'No appointment endpoint available'};
    } catch (e) {
      print('❌ Error creating appointment: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  // Get user appointments
  static Future<List<Map<String, dynamic>>> getUserAppointments({
    String? status,
    int page = 1,
    int limit = 10,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return [];

      final idToken = await user.getIdToken();

      String url = '$baseUrl/api/appointments/user?page=$page&limit=$limit';
      if (status != null) url += '&status=$status';

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null) {
          return List<Map<String, dynamic>>.from(data['data']);
        }
      }
      return [];
    } catch (e) {
      print('❌ Error fetching user appointments: $e');
      return [];
    }
  }

  // Get hospital appointments
  static Future<List<AppointmentModel>> getHospitalAppointments(
      String hospitalId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return [];

      final idToken = await user.getIdToken();

      final response = await http.get(
        Uri.parse('$baseUrl/api/appointments/hospital/$hospitalId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null) {
          return List<AppointmentModel>.from(
              data['data'].map((apt) => AppointmentModel.fromJson(apt)));
        }
      }
      return [];
    } catch (e) {
      print('❌ Error fetching hospital appointments: $e');
      return [];
    }
  }

  // Update appointment status
  static Future<bool> updateAppointmentStatus(
      String appointmentId, String status) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;

      final idToken = await user.getIdToken();

      final response = await http.put(
        Uri.parse('$baseUrl/api/appointments/$appointmentId/status'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
        body: jsonEncode({'status': status}),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('❌ Error updating appointment status: $e');
      return false;
    }
  }

  // SOS Emergency Methods

  // Create SOS request
  static Future<Map<String, dynamic>> createSOSRequest(
      Map<String, dynamic> sosData) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        return {'success': false, 'message': 'User not authenticated'};
      }

      final idToken = await user.getIdToken();
      final response = await _makeHttpRequest(
        'POST',
        Uri.parse('$baseUrl/api/sos/create'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
        body: jsonEncode(sosData),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body);
      } else {
        final errorData = jsonDecode(response.body);
        return {
          'success': false,
          'statusCode': response.statusCode,
          'message': errorData['message'] ?? 'Failed to create SOS request',
          'existingRequestId': errorData['existingRequestId'],
        };
      }
    } catch (e) {
      print('❌ Error creating SOS request: $e');
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // Send alert to specific hospital
  static Future<Map<String, dynamic>> sendHospitalAlert(
      Map<String, dynamic> alertData) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final idToken = await user?.getIdToken();
      if (idToken == null) {
        return {'success': false, 'message': 'User not authenticated'};
      }

      final response = await _makeHttpRequest(
        'POST',
        Uri.parse('$baseUrl/api/sos/send-hospital-alert'),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
        body: json.encode(alertData),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body);
        return data;
      } else {
        final errorData = json.decode(response.body);
        return {
          'success': false,
          'message': errorData['message'] ?? 'Failed to send hospital alert'
        };
      }
    } catch (e) {
      print('❌ Error sendHospitalAlert: $e');
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // Get SOS request status
  static Future<Map<String, dynamic>> getSOSRequestStatus(
      String sosRequestId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        return {'success': false, 'message': 'User not authenticated'};
      }

      final idToken = await user.getIdToken();
      final response = await _makeHttpRequest(
        'GET',
        Uri.parse('$baseUrl/api/sos/request/$sosRequestId'),
        headers: {
          'Authorization': 'Bearer $idToken',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final errorData = jsonDecode(response.body);
        return {
          'success': false,
          'message': errorData['message'] ?? 'Failed to get SOS status'
        };
      }
    } catch (e) {
      print('❌ Error getting SOS status: $e');
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // Cancel SOS request
  static Future<Map<String, dynamic>> cancelSOSRequest(
      String sosRequestId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        return {'success': false, 'message': 'User not authenticated'};
      }

      final idToken = await user.getIdToken();
      final response = await _makeHttpRequest(
        'POST',
        Uri.parse('$baseUrl/api/sos/cancel/$sosRequestId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
        body: jsonEncode({'reason': 'Cancelled by user'}),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final errorData = jsonDecode(response.body);
        return {
          'success': false,
          'message': errorData['message'] ?? 'Failed to cancel SOS request'
        };
      }
    } catch (e) {
      print('❌ Error cancelling SOS request: $e');
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // Get patient SOS history
  static Future<List<Map<String, dynamic>>> getPatientSOSHistory(
      String patientId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return [];

      final idToken = await user.getIdToken();
      final response = await _makeHttpRequest(
        'GET',
        Uri.parse('$baseUrl/api/sos/patient/$patientId'),
        headers: {
          'Authorization': 'Bearer $idToken',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['success'] == true
            ? List<Map<String, dynamic>>.from(data['data'])
            : [];
      }
      return [];
    } catch (e) {
      print('❌ Error getting SOS history: $e');
      return [];
    }
  }

  // Get hospital SOS requests
  static Future<List<Map<String, dynamic>>> getHospitalSOSRequests(
      String hospitalId,
      {String? status}) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return [];

      final idToken = await user.getIdToken();
      final uri = status != null
          ? Uri.parse('$baseUrl/api/sos/hospital/$hospitalId?status=$status')
          : Uri.parse('$baseUrl/api/sos/hospital/$hospitalId');

      final response = await _makeHttpRequest(
        'GET',
        uri,
        headers: {
          'Authorization': 'Bearer $idToken',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['success'] == true
            ? List<Map<String, dynamic>>.from(data['data'])
            : [];
      }
      return [];
    } catch (e) {
      print('❌ Error getting hospital SOS requests: $e');
      return [];
    }
  }

  // Get user SOS history
  static Future<List<Map<String, dynamic>>> getUserSOSHistory(
      String userId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return [];

      final idToken = await user.getIdToken();
      final uri = Uri.parse('$baseUrl/api/sos/patient/$userId');

      final response = await _makeHttpRequest(
        'GET',
        uri,
        headers: {
          'Authorization': 'Bearer $idToken',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['success'] == true
            ? List<Map<String, dynamic>>.from(data['data'])
            : [];
      }
      return [];
    } catch (e) {
      print('❌ Error getUserSOSHistory: $e');
      return [];
    }
  }

  // Accept SOS request (for hospitals)
  static Future<Map<String, dynamic>> acceptSOSRequest(String hospitalId,
      String sosRequestId, Map<String, dynamic> staffInfo) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        return {'success': false, 'message': 'User not authenticated'};
      }

      final idToken = await user.getIdToken();
      final response = await _makeHttpRequest(
        'POST',
        Uri.parse('$baseUrl/api/sos/accept/$hospitalId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
        body: jsonEncode({
          'sosRequestId': sosRequestId,
          'staffInfo': staffInfo,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final errorData = jsonDecode(response.body);
        return {
          'success': false,
          'message': errorData['message'] ?? 'Failed to accept SOS request'
        };
      }
    } catch (e) {
      print('❌ Error accepting SOS request: $e');
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // Mark patient as admitted (for hospitals)
  static Future<Map<String, dynamic>> markPatientAdmitted(String hospitalId,
      String sosRequestId, Map<String, dynamic> admissionDetails) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        return {'success': false, 'message': 'User not authenticated'};
      }

      final idToken = await user.getIdToken();
      final response = await _makeHttpRequest(
        'POST',
        Uri.parse('$baseUrl/api/sos/admit/$hospitalId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
        body: jsonEncode({
          'sosRequestId': sosRequestId,
          'admissionDetails': admissionDetails,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final errorData = jsonDecode(response.body);
        return {
          'success': false,
          'message':
              errorData['message'] ?? 'Failed to mark patient as admitted'
        };
      }
    } catch (e) {
      print('❌ Error marking patient as admitted: $e');
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // Confirm patient admission (for users)
  static Future<Map<String, dynamic>> confirmPatientAdmission(
      String sosRequestId, String hospitalId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        return {'success': false, 'message': 'User not authenticated'};
      }

      final idToken = await user.getIdToken();
      final response = await _makeHttpRequest(
        'POST',
        Uri.parse('$baseUrl/api/sos/confirm-admission'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
        body: jsonEncode({
          'sosRequestId': sosRequestId,
          'hospitalId': hospitalId,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final errorData = jsonDecode(response.body);
        return {
          'success': false,
          'message': errorData['message'] ?? 'Failed to confirm admission'
        };
      }
    } catch (e) {
      print('❌ Error confirming admission: $e');
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // Confirm hospital reached (for users)
  static Future<Map<String, dynamic>> confirmHospitalReached(
      String sosRequestId, String hospitalId, String? doctorId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        return {'success': false, 'message': 'User not authenticated'};
      }

      final idToken = await user.getIdToken();
      final response = await _makeHttpRequest(
        'POST',
        Uri.parse('$baseUrl/api/sos/confirm-hospital-reached'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
        body: jsonEncode({
          'sosRequestId': sosRequestId,
          'hospitalId': hospitalId,
          'doctorId': doctorId,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final errorData = jsonDecode(response.body);
        return {
          'success': false,
          'message':
              errorData['message'] ?? 'Failed to confirm hospital reached'
        };
      }
    } catch (e) {
      print('❌ Error confirming hospital reached: $e');
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // Get SOS statistics for a hospital
  static Future<List<Map<String, dynamic>>> getSOSStatistics(
    String hospitalId, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return [];

      final idToken = await user.getIdToken();
      final String query = (startDate != null && endDate != null)
          ? '?startDate=${Uri.encodeComponent(startDate.toUtc().toIso8601String())}&endDate=${Uri.encodeComponent(endDate.toUtc().toIso8601String())}'
          : '';
      final response = await _makeHttpRequest(
        'GET',
        Uri.parse('$baseUrl/api/sos/statistics/$hospitalId$query'),
        headers: {
          'Authorization': 'Bearer $idToken',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['success'] == true
            ? List<Map<String, dynamic>>.from(data['data'])
            : [];
      }
      return [];
    } catch (e) {
      print('❌ Error getSOSStatistics: $e');
      return [];
    }
  }

  // Get affiliated doctors by hospital Mongo _id
  static Future<List<UserModel>> getAffiliatedDoctors(String hospitalId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return [];
      final idToken = await user.getIdToken();
      final response = await _makeHttpRequest(
        'GET',
        Uri.parse('$baseUrl/api/doctors/affiliated/$hospitalId'),
        headers: {'Authorization': 'Bearer $idToken'},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['data'])
            .map((e) => UserModel.fromJson(e))
            .toList();
      }
      return [];
    } catch (e) {
      print('❌ Error getAffiliatedDoctors: $e');
      return [];
    }
  }

  // Get affiliated nurses by hospital Mongo _id
  static Future<List<UserModel>> getAffiliatedNurses(String hospitalId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return [];
      final idToken = await user.getIdToken();
      final response = await _makeHttpRequest(
        'GET',
        Uri.parse('$baseUrl/api/nurses/affiliated/$hospitalId'),
        headers: {'Authorization': 'Bearer $idToken'},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final nurses = List<Map<String, dynamic>>.from(data['data'])
            .map((e) {
              try {
                return UserModel.fromJson(e);
              } catch (parseError) {
                return null;
              }
            })
            .where((nurse) => nurse != null)
            .cast<UserModel>()
            .toList();
        return nurses;
      }
      return [];
    } catch (e) {
      print('❌ Error getAffiliatedNurses: $e');
      return [];
    }
  }

  // Associate a nurse to current hospital by ARC ID
  static Future<bool> associateNurseByArcId(String arcId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;
      final idToken = await user.getIdToken();
      final response = await _makeHttpRequest(
        'POST',
        Uri.parse('$baseUrl/api/nurses/associate/by-arcid'),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'arcId': arcId}),
      );
      return response.statusCode == 200;
    } catch (e) {
      print('❌ Error associateNurseByArcId: $e');
      rethrow;
    }
  }

  // Update nurse shift (simple version for our backend)
  static Future<bool> updateNurseShiftSimple(String nurseId, String shiftType,
      String startTime, String endTime) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;
      final idToken = await user.getIdToken();
      final response = await _makeHttpRequest(
        'PUT',
        Uri.parse('$baseUrl/api/nurses/shift/$nurseId'),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'shiftType': shiftType,
          'startTime': startTime,
          'endTime': endTime,
        }),
      );
      return response.statusCode == 200;
    } catch (e) {
      print('❌ Error updateNurseShiftSimple: $e');
      rethrow;
    }
  }

  // Lab association
  static Future<void> associateLabByArcId(String arcId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');
      final idToken = await user.getIdToken();

      // Get hospital MongoDB ID first
      final hospitalMongoId = await getHospitalMongoId(user.uid);
      if (hospitalMongoId == null) {
        throw Exception('Hospital not found');
      }

      print('🏥 Associating lab with ARC ID: $arcId');
      print('🏥 Hospital Mongo ID: $hospitalMongoId');
      print('🏥 Request URL: $baseUrl/api/labs/associate/$hospitalMongoId');

      final response = await _makeHttpRequest(
        'POST',
        Uri.parse('$baseUrl/api/labs/associate/$hospitalMongoId'),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(
            {'labArcId': arcId}), // Use labArcId as expected by backend
      );

      print('🏥 Response status: ${response.statusCode}');
      print('🏥 Response body: ${response.body}');

      if (response.statusCode != 200) {
        final error = jsonDecode(response.body);
        throw Exception(
            error['error'] ?? error['message'] ?? 'Failed to associate lab');
      }
    } catch (e) {
      print('❌ Error associateLabByArcId: $e');
      rethrow;
    }
  }

  // Pharmacy association
  static Future<void> associatePharmacyByArcId(String arcId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');
      final idToken = await user.getIdToken();

      print('🏥 Associating pharmacy with ARC ID: $arcId');
      print('🏥 Request URL: $baseUrl/api/pharmacies/associate/by-arcid');

      final response = await _makeHttpRequest(
        'POST',
        Uri.parse('$baseUrl/api/pharmacies/associate/by-arcid'),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'arcId': arcId}),
      );

      print('🏥 Response status: ${response.statusCode}');
      print('🏥 Response body: ${response.body}');

      if (response.statusCode != 200) {
        final error = jsonDecode(response.body);
        throw Exception(error['error'] ??
            error['message'] ??
            'Failed to associate pharmacy');
      }
    } catch (e) {
      print('❌ Error associatePharmacyByArcId: $e');
      rethrow;
    }
  }

  // Remove pharmacy association (legacy method - use removePharmacyAssociation with hospitalId)
  static Future<bool> removePharmacyAssociationLegacy(
      String pharmacyUid) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');
      final idToken = await user.getIdToken();
      final response = await _makeHttpRequest(
        'DELETE',
        Uri.parse('$baseUrl/api/pharmacies/associate/$pharmacyUid'),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
      );
      return response.statusCode == 200;
    } catch (e) {
      print('❌ Error removePharmacyAssociation: $e');
      return false;
    }
  }

  // Get affiliated labs by hospital Mongo _id
  static Future<List<UserModel>> getAffiliatedLabs(String hospitalId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return [];
      final idToken = await user.getIdToken();

      print('🏥 Fetching affiliated labs for hospital: $hospitalId');
      print('🏥 Request URL: $baseUrl/api/labs/affiliated/$hospitalId');

      final response = await _makeHttpRequest(
        'GET',
        Uri.parse('$baseUrl/api/labs/affiliated/$hospitalId'),
        headers: {'Authorization': 'Bearer $idToken'},
      );

      print('🏥 Response status: ${response.statusCode}');
      print('🏥 Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final labs = List<Map<String, dynamic>>.from(data['data'])
            .map((e) {
              try {
                return UserModel.fromJson(e);
              } catch (parseError) {
                print('❌ Error parsing lab: $parseError');
                return null;
              }
            })
            .where((lab) => lab != null)
            .cast<UserModel>()
            .toList();
        print('🏥 Successfully fetched ${labs.length} affiliated labs');
        return labs;
      }
      print('❌ Failed to fetch affiliated labs: ${response.statusCode}');
      return [];
    } catch (e) {
      print('❌ Error getAffiliatedLabs: $e');
      return [];
    }
  }

  // Get affiliated pharmacies by hospital Mongo _id
  static Future<List<UserModel>> getAffiliatedPharmacies(
      String hospitalId) async {
    try {
      print('🔍 getAffiliatedPharmacies called with hospitalId: $hospitalId');
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('❌ No Firebase user found');
        return [];
      }
      final idToken = await user.getIdToken();
      final url = '$baseUrl/api/pharmacies/affiliated/$hospitalId';
      print('🔍 Making request to: $url');
      final response = await _makeHttpRequest(
        'GET',
        Uri.parse(url),
        headers: {'Authorization': 'Bearer $idToken'},
      );
      print('🔍 Response status: ${response.statusCode}');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('🔍 Response data: ${data.toString()}');
        final pharmacies = List<Map<String, dynamic>>.from(data['data'])
            .map((e) {
              try {
                return UserModel.fromJson(e);
              } catch (parseError) {
                print('❌ Error parsing pharmacy: $parseError');
                print('❌ Problematic data: ${e.toString()}');
                return null;
              }
            })
            .where((pharmacy) => pharmacy != null)
            .cast<UserModel>()
            .toList();
        print('🔍 Parsed ${pharmacies.length} pharmacies');
        return pharmacies;
      }
      print('❌ Non-200 response: ${response.statusCode}');
      return [];
    } catch (e) {
      print('❌ Error getAffiliatedPharmacies: $e');
      return [];
    }
  }

  // Helper: get working staff counts (doctors + nurses + labs + pharmacies)
  static Future<int> getWorkingStaffCount(String hospitalId) async {
    try {
      final results = await Future.wait([
        getAffiliatedDoctors(hospitalId),
        getAffiliatedNurses(hospitalId),
        getAffiliatedLabs(hospitalId),
        getAffiliatedPharmacies(hospitalId),
      ]);
      return results.fold<int>(0, (sum, list) => sum + list.length);
    } catch (e) {
      print('❌ Error getWorkingStaffCount: $e');
      return 0;
    }
  }

  // Helper: fetch hospital Mongo _id by Firebase UID
  static Future<String?> getHospitalMongoId(String uid) async {
    try {
      print('🏥 Getting hospital Mongo ID for UID: $uid');
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('❌ No Firebase user found');
        return null;
      }
      // If value already looks like a Mongo ObjectId, return as-is
      final objectIdRegex = RegExp(r'^[a-fA-F0-9]{24}\$');
      if (objectIdRegex.hasMatch(uid)) {
        print('🆔 Input already a MongoId, returning directly');
        return uid;
      }
      final idToken = await user.getIdToken();
      print('🔑 Got Firebase token, calling API...');

      final response = await _makeHttpRequest(
        'GET',
        Uri.parse('$baseUrl/api/hospitals/uid/$uid'),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
      );

      print('📡 Hospital API response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('📊 Hospital data: $data');
        final mongoId = data['_id'] ?? data['id'];
        print('🆔 Hospital Mongo ID: $mongoId');
        if (mongoId is String && mongoId.isNotEmpty) return mongoId;
      } else {
        print(
            '❌ Hospital API error: ${response.statusCode} - ${response.body}');
        // Fallback: treat "uid" as a hospital name and try by name
        try {
          final info = await getHospitalByName(uid);
          if (info != null && info.uid.isNotEmpty) {
            print('🔁 Fallback by name succeeded, returning ${info.uid}');
            return info.uid;
          }
        } catch (e) {
          print('❌ Fallback getHospitalByName failed: $e');
        }
      }
      return null;
    } catch (e) {
      print('❌ Error getHospitalMongoId: $e');
      return null;
    }
  }

  // Hospital appointment management methods
  static Future<void> rescheduleAppointmentByHospital(
    String appointmentId,
    String newDate,
    String newTime,
    String reason,
  ) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');
      final idToken = await user.getIdToken();

      final response = await _makeHttpRequest(
        'PUT',
        Uri.parse('$baseUrl/api/appointments/$appointmentId/reschedule'),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'newDate': newDate,
          'newTime': newTime,
          'reason': reason,
        }),
      );

      if (response.statusCode != 200) {
        final error = jsonDecode(response.body);
        throw Exception(error['message'] ?? 'Failed to reschedule appointment');
      }
    } catch (e) {
      print('❌ Error rescheduleAppointmentByHospital: $e');
      rethrow;
    }
  }

  static Future<void> cancelAppointmentByHospital(
    String appointmentId,
    String reason,
  ) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');
      final idToken = await user.getIdToken();

      final response = await _makeHttpRequest(
        'PUT',
        Uri.parse('$baseUrl/api/appointments/$appointmentId/cancel'),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'reason': reason,
        }),
      );

      if (response.statusCode != 200) {
        final error = jsonDecode(response.body);
        throw Exception(error['message'] ?? 'Failed to cancel appointment');
      }
    } catch (e) {
      print('❌ Error cancelAppointmentByHospital: $e');
      rethrow;
    }
  }

  static Future<void> completeAppointment(
    String appointmentId,
    double billAmount,
    String notes,
    String paymentMethod,
  ) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');
      final idToken = await user.getIdToken();

      final response = await _makeHttpRequest(
        'PUT',
        Uri.parse('$baseUrl/api/appointments/$appointmentId/complete'),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'billAmount': billAmount,
          'notes': notes,
          'paymentMethod': paymentMethod,
        }),
      );

      if (response.statusCode != 200) {
        final error = jsonDecode(response.body);
        throw Exception(error['message'] ?? 'Failed to complete appointment');
      }
    } catch (e) {
      print('❌ Error completeAppointment: $e');
      rethrow;
    }
  }

  static Future<void> completePayment(
    String appointmentId,
    String paymentMethod,
  ) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');
      final idToken = await user.getIdToken();

      final response = await _makeHttpRequest(
        'PUT',
        Uri.parse('$baseUrl/api/appointments/$appointmentId/complete-payment'),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'paymentMethod': paymentMethod,
        }),
      );

      if (response.statusCode != 200) {
        final error = jsonDecode(response.body);
        throw Exception(error['message'] ?? 'Failed to complete payment');
      }
    } catch (e) {
      print('❌ Error completePayment: $e');
      rethrow;
    }
  }

  static Future<void> createOfflineAppointment(
      Map<String, dynamic> appointmentData) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');
      final idToken = await user.getIdToken();

      final response = await _makeHttpRequest(
        'POST',
        Uri.parse('$baseUrl/api/appointments/offline'),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(appointmentData),
      );

      if (response.statusCode != 200) {
        final error = jsonDecode(response.body);
        throw Exception(
            error['message'] ?? 'Failed to create offline appointment');
      }
    } catch (e) {
      print('❌ Error createOfflineAppointment: $e');
      rethrow;
    }
  }

  // Associate a doctor to current hospital by ARC ID
  static Future<bool> associateDoctorByArcId(String arcId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');
      final idToken = await user.getIdToken();

      final response = await _makeHttpRequest(
        'POST',
        Uri.parse('$baseUrl/api/doctors/associate/by-arcid'),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'arcId': arcId}),
      );

      if (response.statusCode == 200) return true;
      final error = jsonDecode(response.body);
      throw Exception(error['error'] ?? error['message'] ?? 'Associate failed');
    } catch (e) {
      print('❌ Error associateDoctorByArcId: $e');
      rethrow;
    }
  }

  static Future<bool> removeDoctorAssociation(String doctorId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');
      final idToken = await user.getIdToken();

      final response = await _makeHttpRequest(
        'DELETE',
        Uri.parse('$baseUrl/api/doctors/remove-association/$doctorId'),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) return true;
      final error = jsonDecode(response.body);
      throw Exception(
          error['error'] ?? error['message'] ?? 'Remove association failed');
    } catch (e) {
      print('❌ Error removeDoctorAssociation: $e');
      rethrow;
    }
  }

  // Remove nurse association
  static Future<bool> removeNurseAssociation(String nurseId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');
      final idToken = await user.getIdToken();

      final response = await _makeHttpRequest(
        'DELETE',
        Uri.parse('$baseUrl/api/nurses/remove-association/$nurseId'),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) return true;
      final error = jsonDecode(response.body);
      throw Exception(
          error['error'] ?? error['message'] ?? 'Remove association failed');
    } catch (e) {
      print('❌ Error removeNurseAssociation: $e');
      rethrow;
    }
  }

  // Remove lab association
  static Future<bool> removeLabAssociation(String labId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');
      final idToken = await user.getIdToken();

      final response = await _makeHttpRequest(
        'DELETE',
        Uri.parse('$baseUrl/api/labs/remove-association/$labId'),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) return true;
      final error = jsonDecode(response.body);
      throw Exception(
          error['error'] ?? error['message'] ?? 'Remove association failed');
    } catch (e) {
      print('❌ Error removeLabAssociation: $e');
      rethrow;
    }
  }

  // Doctor Schedule API Methods
  static Future<String?> getDoctorMongoId(String uid) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('❌ No authenticated user');
        throw Exception('User not authenticated');
      }

      print('👤 Getting ID token for user: ${user.uid}');
      final idToken = await user.getIdToken();
      print('🔑 ID token obtained successfully');

      print('🌐 Making request to: $baseUrl/api/doctors/uid/$uid');
      final response = await _makeHttpRequest(
        'GET',
        Uri.parse('$baseUrl/api/doctors/uid/$uid'),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
      );

      print('📡 Response status: ${response.statusCode}');
      print('📄 Response body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        print('✅ Doctor profile data received: ${responseData.keys}');

        // Extract the actual doctor data from the nested structure
        final doctorData = responseData['data'];
        if (doctorData != null) {
          print('👨‍⚕️ Doctor MongoDB ID: ${doctorData['_id']}');
          return doctorData['_id'];
        } else {
          print('❌ No doctor data found in response');
          return null;
        }
      } else if (response.statusCode == 404) {
        print('❌ Doctor not found with UID: $uid');
        return null;
      } else {
        print(
            '❌ Doctor profile request failed with status: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('❌ Error getDoctorMongoId: $e');
      return null;
    }
  }

  static Future<List<Map<String, dynamic>>> getDoctorSchedule(String doctorId,
      {String? hospitalId}) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');
      final idToken = await user.getIdToken();

      // Build URL with optional hospital filter
      String url = '$baseUrl/api/doctor-schedule/$doctorId';
      if (hospitalId != null) {
        url += '?hospitalId=$hospitalId';
      }

      final response = await _makeHttpRequest(
        'GET',
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['data'] ?? []);
      }
      final error = jsonDecode(response.body);
      throw Exception(error['message'] ?? 'Failed to get doctor schedule');
    } catch (e) {
      print('❌ Error getDoctorSchedule: $e');
      rethrow;
    }
  }

  static Future<void> saveDoctorSchedule(
      Map<String, dynamic> scheduleData) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');
      final idToken = await user.getIdToken();

      final response = await _makeHttpRequest(
        'POST',
        Uri.parse('$baseUrl/api/doctor-schedule'),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(scheduleData),
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        final error = jsonDecode(response.body);
        throw Exception(error['message'] ?? 'Failed to save doctor schedule');
      }
    } catch (e) {
      print('❌ Error saveDoctorSchedule: $e');
      rethrow;
    }
  }

  static Future<List<String>> getAvailableTimeSlots(
      String doctorId, String date,
      {String? hospitalId}) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');
      final idToken = await user.getIdToken();

      // First, get the doctor's MongoDB ID
      final mongoId = await getDoctorMongoId(doctorId);
      if (mongoId == null) {
        throw Exception('Doctor not found');
      }

      print(
          '🕐 Getting time slots for doctor: $doctorId (MongoDB ID: $mongoId), date: $date');

      final response = await _makeHttpRequest(
        'GET',
        Uri.parse(
            '$baseUrl/api/doctor-schedule/$mongoId/available-slots?date=$date${hospitalId != null ? '&hospitalId=$hospitalId' : ''}'),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final timeSlots = List<String>.from(data['data'] ?? []);
        print('✅ API Response: ' +
            jsonEncode({
              'statusCode': response.statusCode,
              'success': data['success'],
              'dataCount': (data['data'] as List?)?.length ?? 0,
              'message': data['message'],
              'timeSlotsCount': timeSlots.length,
              'timeSlots': timeSlots
            }));
        return timeSlots;
      }
      final error = jsonDecode(response.body);
      print('❌ API Error: ' +
          jsonEncode({'statusCode': response.statusCode, 'error': error}));
      throw Exception(error['message'] ?? 'Failed to get available time slots');
    } catch (e) {
      print('❌ Error getAvailableTimeSlots: $e');
      rethrow;
    }
  }

  // Delete a specific time slot from doctor's schedule
  static Future<bool> deleteDoctorTimeSlot({
    required String doctorId,
    required String date,
    required String startTime,
    required String endTime,
    String? hospitalId,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');
      final idToken = await user.getIdToken();

      // doctorId here is already Mongo ID on schedule screen; avoid UID lookup
      final String idForRoute = doctorId;
      final uri =
          Uri.parse('$baseUrl/api/doctor-schedule/$idForRoute/$date/slot');
      final response = await _makeHttpRequest(
        'DELETE',
        uri,
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'startTime': startTime,
          'endTime': endTime,
          if (hospitalId != null) 'hospitalId': hospitalId,
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('❌ Error deleteDoctorTimeSlot: $e');
      return false;
    }
  }

  // Get specialties
  static Future<List<String>> getSpecialties() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');
      final idToken = await user.getIdToken();

      final response = await _makeHttpRequest(
        'GET',
        Uri.parse('$baseUrl/api/doctors/specialties'),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<String>.from(data['data'] ?? []);
      }
      final error = jsonDecode(response.body);
      throw Exception(error['message'] ?? 'Failed to get specialties');
    } catch (e) {
      print('❌ Error getSpecialties: $e');
      rethrow;
    }
  }

  // Get hospitals
  static Future<List<UserModel>> getHospitals() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');
      final idToken = await user.getIdToken();

      final response = await _makeHttpRequest(
        'GET',
        Uri.parse('$baseUrl/api/hospitals'),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final hospitals = List<Map<String, dynamic>>.from(data['data'])
            .map((e) {
              try {
                return UserModel.fromJson(e);
              } catch (parseError) {
                return null;
              }
            })
            .where((hospital) => hospital != null)
            .cast<UserModel>()
            .toList();
        return hospitals;
      }
      final error = jsonDecode(response.body);
      throw Exception(error['message'] ?? 'Failed to get hospitals');
    } catch (e) {
      print('❌ Error getHospitals: $e');
      rethrow;
    }
  }

  // Get doctors by specialty and hospital
  static Future<List<UserModel>> getDoctorsBySpecialtyAndHospital(
      String specialty, String hospitalId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');
      final idToken = await user.getIdToken();

      final response = await _makeHttpRequest(
        'GET',
        Uri.parse(
            '$baseUrl/api/doctors/specialty/$specialty/hospital/$hospitalId'),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final doctors = List<Map<String, dynamic>>.from(data['data'])
            .map((e) {
              try {
                return UserModel.fromJson(e);
              } catch (parseError) {
                return null;
              }
            })
            .where((doctor) => doctor != null)
            .cast<UserModel>()
            .toList();
        return doctors;
      }
      final error = jsonDecode(response.body);
      throw Exception(error['message'] ?? 'Failed to get doctors');
    } catch (e) {
      print('❌ Error getDoctorsBySpecialtyAndHospital: $e');
      rethrow;
    }
  }

  // Hospital Records API Methods
  static Future<Map<String, dynamic>?> createHospitalRecord(
      Map<String, dynamic> recordData) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');
      final idToken = await user.getIdToken();

      final response = await _makeHttpRequest(
        'POST',
        Uri.parse('$baseUrl/api/hospital-records/create'),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(recordData),
      );

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return data['data'];
      }
      final error = jsonDecode(response.body);
      throw Exception(error['message'] ?? 'Failed to create hospital record');
    } catch (e) {
      print('❌ Error createHospitalRecord: $e');
      rethrow;
    }
  }

  static Future<List<dynamic>> getHospitalRecords({
    int page = 1,
    int limit = 10,
    String search = '',
    String status = 'all',
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');
      final idToken = await user.getIdToken();

      final queryParams = {
        'page': page.toString(),
        'limit': limit.toString(),
        if (search.isNotEmpty) 'search': search,
        if (status != 'all') 'status': status,
      };

      final uri = Uri.parse('$baseUrl/api/hospital-records').replace(
        queryParameters: queryParams,
      );

      final response = await _makeHttpRequest(
        'GET',
        uri,
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['data'] ?? [];
      }
      final error = jsonDecode(response.body);
      throw Exception(error['message'] ?? 'Failed to fetch hospital records');
    } catch (e) {
      print('❌ Error getHospitalRecords: $e');
      rethrow;
    }
  }

  static Future<Map<String, dynamic>?> getPatientByArcId(String arcId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');
      final idToken = await user.getIdToken();

      final response = await _makeHttpRequest(
        'GET',
        Uri.parse('$baseUrl/api/hospital-records/patient/arc/$arcId'),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['data'];
      }
      final error = jsonDecode(response.body);
      throw Exception(error['message'] ?? 'Failed to fetch patient by ARC ID');
    } catch (e) {
      print('❌ Error getPatientByArcId: $e');
      rethrow;
    }
  }

  static Future<Map<String, dynamic>?> getHospitalRecordsStats() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');
      final idToken = await user.getIdToken();

      final response = await _makeHttpRequest(
        'GET',
        Uri.parse('$baseUrl/api/hospital-records/stats'),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['data'];
      }
      final error = jsonDecode(response.body);
      throw Exception(
          error['message'] ?? 'Failed to fetch hospital records stats');
    } catch (e) {
      print('❌ Error getHospitalRecordsStats: $e');
      rethrow;
    }
  }

  // Lab Reports API Methods
  static Future<List<LabReportModel>> getLabReportsByHospital(
      String hospitalId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');
      final idToken = await user.getIdToken();

      final response = await http.get(
        Uri.parse('$baseUrl/api/lab-reports/hospital/$hospitalId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          return (data['data'] as List)
              .map((report) => LabReportModel.fromJson(report))
              .toList();
        }
      }
      throw Exception('Failed to fetch lab reports');
    } catch (e) {
      print('❌ Error getLabReportsByHospital: $e');
      rethrow;
    }
  }

  static Future<void> createTestRequest(Map<String, dynamic> testData) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');
      final idToken = await user.getIdToken();

      final response = await http.post(
        Uri.parse('$baseUrl/api/test-requests/create'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
        body: jsonEncode(testData),
      );

      if (response.statusCode != 201) {
        final error = jsonDecode(response.body);
        throw Exception(error['error'] ??
            error['message'] ??
            'Failed to create test request');
      }

      print('✅ Test request created successfully');
    } catch (e) {
      print('❌ Error createTestRequest: $e');
      rethrow;
    }
  }

  static Future<void> updateLabReportStatus(
      String reportId, String status) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');
      final idToken = await user.getIdToken();

      final response = await http.put(
        Uri.parse('$baseUrl/api/lab-reports/$reportId/status'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
        body: jsonEncode({'status': status}),
      );

      if (response.statusCode != 200) {
        final error = jsonDecode(response.body);
        throw Exception(error['message'] ?? 'Failed to update report status');
      }
    } catch (e) {
      print('❌ Error updateLabReportStatus: $e');
      rethrow;
    }
  }

  // Pharmacy medicine management methods
  static Future<Map<String, dynamic>> getPharmacyMedicines(
    String pharmacyId, {
    String? category,
    String? search,
    String? sortBy,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');
      final idToken = await user.getIdToken();

      final queryParams = <String, String>{};
      if (category != null && category != 'All')
        queryParams['category'] = category;
      if (search != null && search.isNotEmpty) queryParams['search'] = search;
      if (sortBy != null) queryParams['sortBy'] = sortBy;

      final uri = Uri.parse('$baseUrl/api/pharmacies/$pharmacyId/medicines')
          .replace(queryParameters: queryParams);

      final response = await _makeHttpRequest(
        'GET',
        uri,
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to fetch pharmacy medicines');
      }
    } catch (e) {
      print('❌ Error getPharmacyMedicines: $e');
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> addPharmacyMedicine(
    String pharmacyId,
    Map<String, dynamic> medicineData,
  ) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');
      final idToken = await user.getIdToken();

      final response = await _makeHttpRequest(
        'POST',
        Uri.parse('$baseUrl/api/pharmacies/$pharmacyId/medicines'),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(medicineData),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to add medicine');
      }
    } catch (e) {
      print('❌ Error addPharmacyMedicine: $e');
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> updatePharmacyMedicine(
    String pharmacyId,
    String medicineId,
    Map<String, dynamic> medicineData,
  ) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');
      final idToken = await user.getIdToken();

      print(
          '🌐 Updating medicine - Pharmacy ID: $pharmacyId, Medicine ID: $medicineId');
      print('🌐 Medicine data: $medicineData');

      final response = await _makeHttpRequest(
        'PUT',
        Uri.parse('$baseUrl/api/pharmacies/$pharmacyId/medicines/$medicineId'),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(medicineData),
      );

      print('🌐 Update response status: ${response.statusCode}');
      print('🌐 Update response body: ${response.body}');

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception(
            'Failed to update medicine: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('❌ Error updatePharmacyMedicine: $e');
      rethrow;
    }
  }

  static Future<bool> deletePharmacyMedicine(
    String pharmacyId,
    String medicineId,
  ) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');
      final idToken = await user.getIdToken();

      print(
          '🌐 Deleting medicine - Pharmacy ID: $pharmacyId, Medicine ID: $medicineId');

      final response = await _makeHttpRequest(
        'DELETE',
        Uri.parse('$baseUrl/api/pharmacies/$pharmacyId/medicines/$medicineId'),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
      );

      print('🌐 Delete response status: ${response.statusCode}');
      print('🌐 Delete response body: ${response.body}');

      return response.statusCode == 200;
    } catch (e) {
      print('❌ Error deletePharmacyMedicine: $e');
      return false;
    }
  }

  static Future<Map<String, dynamic>> getPharmacyMedicineAlerts(
    String pharmacyId,
  ) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');
      final idToken = await user.getIdToken();

      final response = await _makeHttpRequest(
        'GET',
        Uri.parse('$baseUrl/api/pharmacies/$pharmacyId/medicines/alerts'),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to fetch medicine alerts');
      }
    } catch (e) {
      print('❌ Error getPharmacyMedicineAlerts: $e');
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> getPharmacyMedicineOverview(
    String pharmacyId,
  ) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');
      final idToken = await user.getIdToken();

      final response = await _makeHttpRequest(
        'GET',
        Uri.parse('$baseUrl/api/pharmacies/$pharmacyId/medicines/overview'),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to fetch medicine overview');
      }
    } catch (e) {
      print('❌ Error getPharmacyMedicineOverview: $e');
      rethrow;
    }
  }

  // ==================== ORDER MANAGEMENT ====================

  // Place a new order
  static Future<Map<String, dynamic>> placeOrder({
    required String userId,
    required List<Map<String, dynamic>> items,
    required Map<String, dynamic> userAddress,
    required String deliveryMethod,
    required String paymentMethod,
    String? userNotes,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final idToken = await user?.getIdToken();

      final uri = Uri.parse('$baseUrl/api/orders/place');
      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
        body: jsonEncode({
          'userId': userId,
          'items': items,
          'userAddress': userAddress,
          'deliveryMethod': deliveryMethod,
          'paymentMethod': paymentMethod,
          'userNotes': userNotes,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return data;
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to place order');
      }
    } catch (e) {
      print('❌ Error placing order: $e');
      rethrow;
    }
  }

  // Get orders by user
  static Future<List<Map<String, dynamic>>> getOrdersByUser(
      String userId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final idToken = await user?.getIdToken();

      final uri = Uri.parse('$baseUrl/api/orders/user/$userId');
      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['data'] ?? []);
      } else {
        throw Exception('Failed to fetch user orders');
      }
    } catch (e) {
      print('❌ Error fetching user orders: $e');
      rethrow;
    }
  }

  // Get orders by hospital
  static Future<List<Map<String, dynamic>>> getHospitalOrders(
      String hospitalId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final idToken = await user?.getIdToken();

      final uri = Uri.parse('$baseUrl/api/orders/hospital/$hospitalId');
      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['data'] ?? []);
      } else {
        print('❌ Failed to fetch hospital orders: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('❌ Error fetching hospital orders: $e');
      return [];
    }
  }

  // Get orders by pharmacy
  static Future<List<Map<String, dynamic>>> getOrdersByPharmacy(
      String pharmacyId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final idToken = await user?.getIdToken();

      final uri = Uri.parse('$baseUrl/api/orders/pharmacy/$pharmacyId');
      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['data'] ?? []);
      } else {
        throw Exception('Failed to fetch pharmacy orders');
      }
    } catch (e) {
      print('❌ Error fetching pharmacy orders: $e');
      rethrow;
    }
  }

  // Update order status
  static Future<Map<String, dynamic>> updateOrderStatus({
    required String orderId,
    required String status,
    required String updatedBy,
    String? note,
    Map<String, String>? trackingInfo,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final idToken = await user?.getIdToken();

      final uri = Uri.parse('$baseUrl/api/orders/$orderId/status');
      final response = await http.put(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
        body: jsonEncode({
          'status': status,
          'updatedBy': updatedBy,
          'note': note,
          'trackingInfo': trackingInfo,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data;
      } else {
        throw Exception('Failed to update order status');
      }
    } catch (e) {
      print('❌ Error updating order status: $e');
      rethrow;
    }
  }

  // Get order by ID
  static Future<Map<String, dynamic>> getOrderById(String orderId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final idToken = await user?.getIdToken();

      final uri = Uri.parse('$baseUrl/api/orders/$orderId');
      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['data'];
      } else {
        throw Exception('Failed to fetch order');
      }
    } catch (e) {
      print('❌ Error fetching order: $e');
      rethrow;
    }
  }

  // Get order statistics for pharmacy
  static Future<Map<String, dynamic>> getOrderStats(String pharmacyId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final idToken = await user?.getIdToken();

      final uri = Uri.parse('$baseUrl/api/orders/pharmacy/$pharmacyId/stats');
      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['data'];
      } else {
        throw Exception('Failed to fetch order statistics');
      }
    } catch (e) {
      print('❌ Error fetching order statistics: $e');
      rethrow;
    }
  }

  // Rating API methods
  static Future<Map<String, dynamic>> submitRating({
    required String orderId,
    required int rating,
    String? review,
    List<Map<String, dynamic>>? medicineRatings,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Not logged in');

      final idToken = await user.getIdToken();
      final response = await http.post(
        Uri.parse('$baseUrl/api/ratings/submit'),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'orderId': orderId,
          'rating': rating,
          'review': review,
          'medicineRatings': medicineRatings,
        }),
      );

      final data = json.decode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        return data;
      } else {
        throw Exception(data['message'] ?? 'Failed to submit rating');
      }
    } catch (e) {
      print('❌ Error submitting rating: $e');
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> getPharmacyRatings({
    required String pharmacyId,
    int page = 1,
    int limit = 10,
  }) async {
    try {
      final response = await http.get(
        Uri.parse(
            '$baseUrl/api/ratings/pharmacy/$pharmacyId?page=$page&limit=$limit'),
        headers: {'Content-Type': 'application/json'},
      );

      final data = json.decode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        return data['data'];
      } else {
        throw Exception('Failed to fetch pharmacy ratings');
      }
    } catch (e) {
      print('❌ Error fetching pharmacy ratings: $e');
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> getUserRatings({
    int page = 1,
    int limit = 10,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Not logged in');

      final idToken = await user.getIdToken();
      final response = await http.get(
        Uri.parse('$baseUrl/api/ratings/user?page=$page&limit=$limit'),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
      );

      final data = json.decode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        return data['data'];
      } else {
        throw Exception('Failed to fetch user ratings');
      }
    } catch (e) {
      print('❌ Error fetching user ratings: $e');
      rethrow;
    }
  }

  static Future<List<Map<String, dynamic>>> getUserProviderRatings({
    String? appointmentId,
    String? providerType,
    String? providerId,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Not logged in');

      final idToken = await user.getIdToken();
      final queryParams = <String, String>{};
      if (appointmentId != null) queryParams['appointmentId'] = appointmentId;
      if (providerType != null) queryParams['providerType'] = providerType;
      if (providerId != null) queryParams['providerId'] = providerId;

      final uri = Uri.parse('$baseUrl/api/ratings/user/provider').replace(
        queryParameters: queryParams,
      );

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
      );

      final data = json.decode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        return List<Map<String, dynamic>>.from(data['data']);
      } else {
        throw Exception(
            data['message'] ?? 'Failed to fetch user provider ratings');
      }
    } catch (e) {
      print('❌ Error fetching user provider ratings: $e');
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> getPharmacyRatingSummary({
    required String pharmacyId,
  }) async {
    // Retry mechanism for network failures
    for (int attempt = 1; attempt <= 3; attempt++) {
      try {
        final response = await http.get(
          Uri.parse('$baseUrl/api/ratings/pharmacy/$pharmacyId/summary'),
          headers: {'Content-Type': 'application/json'},
        ).timeout(const Duration(seconds: 15));

        final data = json.decode(response.body);
        if (response.statusCode == 200 && data['success'] == true) {
          return data['data'];
        } else if (response.statusCode == 502 || response.statusCode == 503) {
          // Server error - retry
          if (attempt < 3) {
            print(
                '⚠️ Server error ${response.statusCode}, retrying... (attempt $attempt)');
            await Future.delayed(
                Duration(seconds: attempt * 2)); // Exponential backoff
            continue;
          }
        }
        throw Exception('Failed to fetch pharmacy rating summary');
      } catch (e) {
        print(
            '❌ Error fetching pharmacy rating summary (attempt $attempt): $e');
        if (attempt == 3) {
          // Return default data on final failure
          return {
            'averageRating': 0,
            'totalRatings': 0,
            'ratingDistribution': {1: 0, 2: 0, 3: 0, 4: 0, 5: 0}
          };
        }
        await Future.delayed(
            Duration(seconds: attempt * 2)); // Exponential backoff
      }
    }

    // This should never be reached, but just in case
    return {
      'averageRating': 0,
      'totalRatings': 0,
      'ratingDistribution': {1: 0, 2: 0, 3: 0, 4: 0, 5: 0}
    };
  }

  // Provider Rating Methods
  static Future<void> submitProviderRating({
    required String appointmentId,
    required String providerId,
    required String providerType,
    required int rating,
    required String review,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final idToken = await user.getIdToken();
      final response = await http.post(
        Uri.parse('$baseUrl/api/ratings/provider/submit'),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'appointmentId': appointmentId,
          'providerId': providerId,
          'providerType': providerType,
          'rating': rating,
          'review': review,
        }),
      );

      final data = json.decode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        print('✅ Provider rating submitted successfully');
      } else if (response.statusCode == 400 && data['existingRating'] != null) {
        print('⚠️ Rating already exists: ${data['message']}');
        throw Exception('Already rated: ${data['message']}');
      } else {
        throw Exception(data['message'] ?? 'Failed to submit provider rating');
      }
    } catch (e) {
      print('❌ Error submitting provider rating: $e');
      rethrow;
    }
  }

  static Future<List<Map<String, dynamic>>> getProviderRatings({
    required String providerId,
    required String providerType,
    int page = 1,
    int limit = 10,
  }) async {
    try {
      final response = await http.get(
        Uri.parse(
            '$baseUrl/api/ratings/provider/$providerId/$providerType?page=$page&limit=$limit'),
        headers: {'Content-Type': 'application/json'},
      );

      final data = json.decode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        return List<Map<String, dynamic>>.from(data['data']);
      } else {
        throw Exception('Failed to fetch provider ratings');
      }
    } catch (e) {
      print('❌ Error fetching provider ratings: $e');
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> getProviderRatingSummary({
    required String providerId,
    required String providerType,
  }) async {
    // Retry mechanism for network failures
    for (int attempt = 1; attempt <= 3; attempt++) {
      try {
        final response = await http.get(
          Uri.parse(
              '$baseUrl/api/ratings/provider/$providerId/$providerType/summary'),
          headers: {'Content-Type': 'application/json'},
        ).timeout(const Duration(seconds: 15));

        final data = json.decode(response.body);
        if (response.statusCode == 200 && data['success'] == true) {
          return data['data'];
        } else if (response.statusCode == 502 || response.statusCode == 503) {
          // Server error - retry
          if (attempt < 3) {
            print(
                '⚠️ Server error ${response.statusCode}, retrying... (attempt $attempt)');
            await Future.delayed(
                Duration(seconds: attempt * 2)); // Exponential backoff
            continue;
          }
        }
        throw Exception('Failed to fetch provider rating summary');
      } catch (e) {
        print(
            '❌ Error fetching provider rating summary (attempt $attempt): $e');
        if (attempt == 3) {
          // Return default data on final failure
          return {
            'averageRating': 0,
            'totalRatings': 0,
            'ratingDistribution': {1: 0, 2: 0, 3: 0, 4: 0, 5: 0}
          };
        }
        await Future.delayed(
            Duration(seconds: attempt * 2)); // Exponential backoff
      }
    }

    // This should never be reached, but just in case
    return {
      'averageRating': 0,
      'totalRatings': 0,
      'ratingDistribution': {1: 0, 2: 0, 3: 0, 4: 0, 5: 0}
    };
  }

  // Patient Assignment Methods

  // Create patient assignment
  static Future<Map<String, dynamic>?> createPatientAssignment({
    required String patientArcId,
    required String doctorArcId,
    required String nurseId,
    required String ward,
    required String shift,
    required String assignmentDate,
    required String assignmentTime,
    String? notes,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return null;
      final idToken = await user.getIdToken();

      final payload = json.encode({
        'patientArcId': patientArcId,
        'doctorArcId': doctorArcId,
        'nurseId': nurseId,
        'ward': ward,
        'shift': shift,
        'assignmentDate': assignmentDate,
        'assignmentTime': assignmentTime,
        'notes': notes ?? '',
      });

      // Use canonical endpoint only
      final url = '$baseUrl/api/patient-assignments/create';
      final resp = await _makeHttpRequest(
        'POST',
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
        body: payload,
      );

      if (resp.statusCode == 201 || resp.statusCode == 200) {
        try {
          final data = json.decode(resp.body);
          print('✅ Patient assignment created');
          return (data is Map && data['data'] != null) ? data['data'] : data;
        } catch (_) {
          print('✅ Patient assignment created (no-json)');
          return {'success': true};
        }
      }

      // Helpful logging by status
      if (resp.statusCode == 401) {
        print(
            '❌ Unauthorized: Missing/invalid Firebase ID token for patient assignment');
      } else if (resp.statusCode == 404) {
        // Surface backend domain error (e.g., hospital/patient/nurse not found)
        try {
          final body = json.decode(resp.body);
          final msg = (body is Map &&
                  (body['error'] != null || body['message'] != null))
              ? (body['error'] ?? body['message']).toString()
              : resp.body;
          print('❌ Create assignment failed (404): $msg');
        } catch (_) {
          print('❌ Create assignment failed (404): ${resp.body}');
        }
      } else {
        print(
            '❌ Patient assignment create failed: ${resp.statusCode} ${resp.body}');
      }
      return null;
    } catch (e) {
      print('❌ Error creating patient assignment: $e');
      return null;
    }
  }

  // Get doctor assignments
  static Future<List<dynamic>> getDoctorAssignments() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return [];
      final idToken = await user.getIdToken();

      final response = await _makeHttpRequest(
        'GET',
        Uri.parse('$baseUrl/api/patient-assignments/doctor'),
        headers: {
          'Authorization': 'Bearer $idToken',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('✅ Doctor assignments fetched successfully');
        return data['data'] ?? [];
      } else {
        print('❌ Failed to fetch doctor assignments: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('❌ Error fetching doctor assignments: $e');
      return [];
    }
  }

  // Get nurse assignments
  static Future<List<dynamic>> getNurseAssignments() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return [];
      final idToken = await user.getIdToken();

      final response = await _makeHttpRequest(
          'GET', Uri.parse('$baseUrl/api/patient-assignments/nurse'),
          headers: {
            'Authorization': 'Bearer $idToken',
          });

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final list = data['data'] ?? [];
        try {
          print('🩺 Nurse assignments fetched: ${list.length}');
        } catch (_) {}
        return list;
      } else {
        try {
          print(
              '❌ Nurse assignments fetch failed: ${response.statusCode} ${response.body}');
        } catch (_) {}
        return [];
      }
    } catch (e) {
      try {
        print('❌ Error fetching nurse assignments: $e');
      } catch (_) {}
      return [];
    }
  }

  // Get hospital assignments
  static Future<List<dynamic>> getHospitalAssignments() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return [];
      final idToken = await user.getIdToken();

      final response = await _makeHttpRequest(
        'GET',
        Uri.parse('$baseUrl/api/patient-assignments/hospital'),
        headers: {
          'Authorization': 'Bearer $idToken',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('✅ Hospital assignments fetched successfully');
        return data['data'] ?? [];
      } else {
        print('❌ Failed to fetch hospital assignments: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('❌ Error fetching hospital assignments: $e');
      return [];
    }
  }

  // Update assignment status
  static Future<bool> updateAssignmentStatus({
    required String assignmentId,
    required String status,
    String? notes,
    String? completedBy,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;
      final idToken = await user.getIdToken();

      final response = await _makeHttpRequest(
        'PUT',
        Uri.parse('$baseUrl/api/patient-assignments/$assignmentId/status'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
        body: json.encode({
          'status': status,
          'notes': notes,
          'completedBy': completedBy,
        }),
      );

      if (response.statusCode == 200) {
        print('✅ Assignment status updated successfully');
        return true;
      } else {
        print('❌ Failed to update assignment status: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('❌ Error updating assignment status: $e');
      return false;
    }
  }

  // Delete assignment
  static Future<bool> deleteAssignment(String assignmentId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;
      final idToken = await user.getIdToken();

      final response = await _makeHttpRequest(
        'DELETE',
        Uri.parse('$baseUrl/api/patient-assignments/$assignmentId'),
        headers: {
          'Authorization': 'Bearer $idToken',
        },
      );

      if (response.statusCode == 200) {
        print('✅ Assignment deleted successfully');
        return true;
      } else {
        print('❌ Failed to delete assignment: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('❌ Error deleting assignment: $e');
      return false;
    }
  }

  // Get assignment statistics
  static Future<Map<String, dynamic>?> getAssignmentStats() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return null;
      final idToken = await user.getIdToken();

      final response = await _makeHttpRequest(
        'GET',
        Uri.parse('$baseUrl/api/patient-assignments/stats'),
        headers: {
          'Authorization': 'Bearer $idToken',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('✅ Assignment stats fetched successfully');
        return data['data'];
      } else {
        print('❌ Failed to fetch assignment stats: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('❌ Error fetching assignment stats: $e');
      return null;
    }
  }

  // Test Request methods
  static Future<List<Map<String, dynamic>>> getHospitalTestRequests(
      String hospitalMongoId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return [];

      final idToken = await user.getIdToken();

      final response = await _makeHttpRequest(
        'GET',
        Uri.parse('$baseUrl/api/test-requests/hospital'),
        headers: {
          'Authorization': 'Bearer $idToken',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null) {
          return List<Map<String, dynamic>>.from(data['data']);
        }
      }
      return [];
    } catch (e) {
      print('❌ Error fetching hospital test requests: $e');
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> getLabTestRequests(
      String labMongoId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return [];

      final idToken = await user.getIdToken();

      final response = await _makeHttpRequest(
        'GET',
        Uri.parse('$baseUrl/api/test-requests/lab'),
        headers: {
          'Authorization': 'Bearer $idToken',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null) {
          return List<Map<String, dynamic>>.from(data['data']);
        }
      }
      return [];
    } catch (e) {
      print('❌ Error fetching lab test requests: $e');
      return [];
    }
  }

  static Future<void> updateTestRequestStatus(
    String requestId,
    String status, {
    DateTime? scheduledDate,
    String? scheduledTime,
    double? billAmount,
    List<String>? paymentOptions,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final idToken = await user.getIdToken();

      final requestBody = {
        'status': status,
        if (scheduledDate != null)
          'scheduledDate': scheduledDate.toIso8601String(),
        if (scheduledTime != null) 'scheduledTime': scheduledTime,
        if (billAmount != null) 'billAmount': billAmount,
        if (paymentOptions != null) 'paymentOptions': paymentOptions,
      };

      final response = await _makeHttpRequest(
        'PUT',
        Uri.parse('$baseUrl/api/test-requests/$requestId/status'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
        body: json.encode(requestBody),
      );

      if (response.statusCode != 200) {
        final error = json.decode(response.body);
        throw Exception(error['error'] ??
            error['message'] ??
            'Failed to update test request status');
      }

      print('✅ Test request status updated successfully');
    } catch (e) {
      print('❌ Error updating test request status: $e');
      rethrow;
    }
  }

  // Hospital Pharmacy Order API Methods
  static Future<List<Map<String, dynamic>>> getPatientMedicinesFromPharmacies(
      String patientArcId, List<UserModel> pharmacies) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');
      final idToken = await user.getIdToken();

      List<Map<String, dynamic>> allMedicines = [];

      // Search medicines from each associated pharmacy
      for (final pharmacy in pharmacies) {
        try {
          final response = await _makeHttpRequest(
            'GET',
            Uri.parse(
                '$baseUrl/api/pharmacy/${pharmacy.uid}/medicines/patient/$patientArcId'),
            headers: {
              'Authorization': 'Bearer $idToken',
              'Content-Type': 'application/json',
            },
          );

          if (response.statusCode == 200) {
            final data = jsonDecode(response.body);
            if (data['success'] == true && data['data'] != null) {
              final medicines = List<Map<String, dynamic>>.from(data['data']);
              // Add pharmacy info to each medicine
              for (final medicine in medicines) {
                medicine['pharmacyName'] = pharmacy.fullName;
                medicine['pharmacyId'] = pharmacy.uid;
                medicine['pharmacyArcId'] = pharmacy.arcId;
              }
              allMedicines.addAll(medicines);
            }
          }
        } catch (e) {
          print(
              '❌ Error fetching medicines from pharmacy ${pharmacy.fullName}: $e');
          // Continue with other pharmacies
        }
      }

      return allMedicines;
    } catch (e) {
      print('❌ Error getPatientMedicinesFromPharmacies: $e');
      rethrow;
    }
  }

  static Future<bool> createPharmacyOrder(
      Map<String, dynamic> orderData) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');
      final idToken = await user.getIdToken();

      final response = await _makeHttpRequest(
        'POST',
        Uri.parse('$baseUrl/api/orders/hospital-order'),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(orderData),
      );

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        print('✅ Pharmacy order created successfully: ${data['data']['_id']}');
        return true;
      } else {
        print('❌ Failed to create pharmacy order: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('❌ Error createPharmacyOrder: $e');
      return false;
    }
  }

  // Medicine QR Code API Methods
  static Future<bool> saveMedicineQRCode(
      String medicineId, Map<String, dynamic> qrData) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');
      final idToken = await user.getIdToken();

      print('🔍 saveMedicineQRCode - Medicine ID: $medicineId');
      print('🔍 saveMedicineQRCode - QR Data: $qrData');
      print(
          '🔍 saveMedicineQRCode - URL: $baseUrl/api/medicines/$medicineId/qr-code');

      final response = await _makeHttpRequest(
        'POST',
        Uri.parse('$baseUrl/api/medicines/$medicineId/qr-code'),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'qrCodeData': jsonEncode(qrData)}),
      );

      print('🔍 saveMedicineQRCode - Response status: ${response.statusCode}');
      print('🔍 saveMedicineQRCode - Response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        print('✅ Medicine QR code saved successfully');
        return true;
      } else {
        print('❌ Failed to save medicine QR code: ${response.statusCode}');
        print('❌ Response body: ${response.body}');
        return false;
      }
    } catch (e) {
      print('❌ Error saveMedicineQRCode: $e');
      return false;
    }
  }

  static Future<Map<String, dynamic>?> getMedicineByQRCode(
      String qrData) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');
      final idToken = await user.getIdToken();

      final response = await _makeHttpRequest(
        'GET',
        Uri.parse('$baseUrl/api/medicines/qr-scan'),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'qrData': qrData}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data;
      } else {
        print('❌ Failed to get medicine by QR code: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('❌ Error getMedicineByQRCode: $e');
      return null;
    }
  }

  // Hospital-Pharmacy Association API Methods
  static Future<List<UserModel>> getAssociatedPharmacies(
      String hospitalId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');
      final idToken = await user.getIdToken();

      final response = await _makeHttpRequest(
        'GET',
        Uri.parse('$baseUrl/api/pharmacies/affiliated/$hospitalId'),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final pharmacies = (data['data'] as List)
            .map((json) => UserModel.fromJson(json))
            .toList();
        return pharmacies;
      } else {
        print('❌ Failed to get associated pharmacies: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('❌ Error getAssociatedPharmacies: $e');
      return [];
    }
  }

  static Future<bool> removePharmacyAssociation(
      String hospitalFirebaseId, String pharmacyFirebaseId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');
      final idToken = await user.getIdToken();

      // Get hospital MongoDB ID
      final hospitalMongoId = await getHospitalMongoId(hospitalFirebaseId);
      if (hospitalMongoId == null) {
        print('❌ Hospital MongoDB ID not found');
        return false;
      }

      print('🏥 Removing pharmacy association');
      print('🏥 Hospital Firebase ID: $hospitalFirebaseId');
      print('🏥 Hospital MongoDB ID: $hospitalMongoId');
      print('🏥 Pharmacy Firebase ID: $pharmacyFirebaseId');

      final response = await _makeHttpRequest(
        'DELETE',
        Uri.parse('$baseUrl/api/pharmacies/associate/$pharmacyFirebaseId'),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
      );

      print('🏥 Response status: ${response.statusCode}');
      print('🏥 Response body: ${response.body}');

      if (response.statusCode == 200) {
        print('✅ Pharmacy association removed successfully');
        return true;
      } else {
        print(
            '❌ Failed to remove pharmacy association: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('❌ Error removePharmacyAssociation: $e');
      return false;
    }
  }

  // Nurse API Methods
  static Future<List<UserModel>> getNurseAssignedPatients() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');
      final idToken = await user.getIdToken();

      final response = await _makeHttpRequest(
        'GET',
        Uri.parse('$baseUrl/api/nurses/assigned-patients'),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final patients = List<Map<String, dynamic>>.from(data['data'] ?? []);
        return patients.map((patient) => UserModel.fromJson(patient)).toList();
      } else {
        throw Exception('Failed to get assigned patients');
      }
    } catch (e) {
      print('❌ Error getNurseAssignedPatients: $e');
      return [];
    }
  }

  static Future<bool> recordVitalSigns(Map<String, dynamic> vitalData) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');
      final idToken = await user.getIdToken();

      final response = await _makeHttpRequest(
        'POST',
        Uri.parse('$baseUrl/api/vitals/record'),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(vitalData),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('❌ Error recordVitalSigns: $e');
      return false;
    }
  }

  static Future<List<Map<String, dynamic>>> getPatientVitals(
      String patientId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');
      final idToken = await user.getIdToken();

      final response = await _makeHttpRequest(
        'GET',
        Uri.parse('$baseUrl/api/vitals/patient/$patientId'),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['data'] ?? []);
      } else {
        return [];
      }
    } catch (e) {
      print('❌ Error getPatientVitals: $e');
      return [];
    }
  }

  static Future<bool> deleteVital(String id) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;
      final idToken = await user.getIdToken();

      final response = await _makeHttpRequest(
        'DELETE',
        Uri.parse('$baseUrl/api/vitals/$id'),
        headers: {
          'Authorization': 'Bearer $idToken',
        },
      );
      return response.statusCode == 200;
    } catch (e) {
      print('❌ Error deleteVital: $e');
      return false;
    }
  }

  static Future<bool> updateVital(
      String id, Map<String, dynamic> updates) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;
      final idToken = await user.getIdToken();

      final response = await _makeHttpRequest(
        'PATCH',
        Uri.parse('$baseUrl/api/vitals/$id'),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(updates),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('❌ Error updateVital: $e');
      return false;
    }
  }

  static Future<List<Map<String, dynamic>>> getPatientPrescriptions(
      String patientId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');
      final idToken = await user.getIdToken();

      final response = await _makeHttpRequest(
        'GET',
        Uri.parse('$baseUrl/api/prescriptions/patient/$patientId'),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['data'] ?? []);
      } else {
        throw Exception('Failed to get patient prescriptions');
      }
    } catch (e) {
      print('❌ Error getPatientPrescriptions: $e');
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> getPatientPrescriptionsByArc(
      String arcId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');
      final idToken = await user.getIdToken();

      final response = await _makeHttpRequest(
        'GET',
        // Backend route uses /api/prescriptions/patient/:patientArcId
        Uri.parse('$baseUrl/api/prescriptions/patient/$arcId'),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['data'] ?? []);
      } else {
        return [];
      }
    } catch (e) {
      print('❌ Error getPatientPrescriptionsByArc: $e');
      return [];
    }
  }

  // Reminders by patient ARC ID
  static Future<List<Map<String, dynamic>>> getRemindersByArcId(
      String arcId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return [];
      final idToken = await user.getIdToken();
      final res = await http.get(
        Uri.parse('$baseUrl/api/reminders/patient/$arcId'),
        headers: {'Authorization': 'Bearer $idToken'},
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return List<Map<String, dynamic>>.from(data['data'] ?? []);
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  static Future<bool> updateReminderStatus(
      String reminderId, String status) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;
      final idToken = await user.getIdToken();
      final res = await http.patch(
        Uri.parse('$baseUrl/api/reminders/$reminderId'),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'status': status}),
      );
      return res.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // Chats
  static Future<List<Map<String, dynamic>>> getChatsByArcId(
      String arcId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return [];
      final idToken = await user.getIdToken();
      final res = await http.get(
        Uri.parse('$baseUrl/api/chats/patient/$arcId'),
        headers: {'Authorization': 'Bearer $idToken'},
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return List<Map<String, dynamic>>.from(data['data'] ?? []);
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  static Future<bool> sendChatMessage({
    required String arcId,
    required String message,
    String priority = 'Low',
    required String senderRole, // 'doctor' or 'nurse'
    String? receiverName, // Optional receiver name for better targeting
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;
      final idToken = await user.getIdToken();
      final res = await http.post(
        Uri.parse('$baseUrl/api/chats/send'),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'patientArcId': arcId,
          'message': message,
          'priority': priority,
          'senderRole': senderRole,
          'receiverName': receiverName,
        }),
      );
      return res.statusCode == 201;
    } catch (_) {
      return false;
    }
  }

  // Nurse Talk - Nurse to Nurse Communication
  static Future<List<Map<String, dynamic>>> getNurseTalkNurses() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return [];
      final idToken = await user.getIdToken();
      final res = await http.get(
        Uri.parse('$baseUrl/api/nurse-talk/nurses'),
        headers: {'Authorization': 'Bearer $idToken'},
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return List<Map<String, dynamic>>.from(data['data'] ?? []);
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  static Future<bool> sendNurseMessage({
    required String receiverId,
    required String message,
    String? patientArcId,
    String? patientName,
    String messageType = 'chat',
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;
      final idToken = await user.getIdToken();
      final res = await http.post(
        Uri.parse('$baseUrl/api/nurse-talk/send'),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'receiverId': receiverId,
          'message': message,
          'patientArcId': patientArcId,
          'patientName': patientName,
          'messageType': messageType,
        }),
      );
      return res.statusCode == 201;
    } catch (_) {
      return false;
    }
  }

  static Future<List<Map<String, dynamic>>> getNurseMessages(
      String receiverId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return [];
      final idToken = await user.getIdToken();
      final res = await http.get(
        Uri.parse('$baseUrl/api/nurse-talk/messages/$receiverId'),
        headers: {'Authorization': 'Bearer $idToken'},
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return List<Map<String, dynamic>>.from(data['data'] ?? []);
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> getHandoverNotes() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return [];
      final idToken = await user.getIdToken();
      final res = await http.get(
        Uri.parse('$baseUrl/api/nurse-talk/handover'),
        headers: {'Authorization': 'Bearer $idToken'},
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return List<Map<String, dynamic>>.from(data['data'] ?? []);
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  static Future<bool> markNurseMessageAsRead(String messageId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;
      final idToken = await user.getIdToken();
      final res = await http.patch(
        Uri.parse('$baseUrl/api/nurse-talk/read/$messageId'),
        headers: {'Authorization': 'Bearer $idToken'},
      );
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  static Future<int> getNurseUnreadCount() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return 0;
      final idToken = await user.getIdToken();
      final res = await http.get(
        Uri.parse('$baseUrl/api/nurse-talk/unread-count'),
        headers: {'Authorization': 'Bearer $idToken'},
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return data['count'] ?? 0;
      }
      return 0;
    } catch (_) {
      return 0;
    }
  }

  // NurseTalk: set typing indicator for receiver
  static Future<void> sendNurseTyping(String receiverId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final idToken = await user.getIdToken();
      await _makeHttpRequest(
        'POST',
        Uri.parse('$baseUrl/api/nurse-talk/typing'),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'receiverId': receiverId}),
      );
    } catch (_) {}
  }

  // NurseTalk: get typing status from receiver -> is the other typing to me?
  static Future<bool> getNurseTyping(String receiverId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;
      final idToken = await user.getIdToken();
      final res = await _makeHttpRequest(
        'GET',
        Uri.parse('$baseUrl/api/nurse-talk/typing/$receiverId'),
        headers: {
          'Authorization': 'Bearer $idToken',
        },
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return data['typing'] == true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  // Ping nurse presence
  static Future<bool> pingNursePresence() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;
      final idToken = await user.getIdToken();
      final res = await http.post(
        Uri.parse('$baseUrl/api/nurse-talk/ping'),
        headers: {'Authorization': 'Bearer $idToken'},
      );
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // Create reminder by ARC ID (doctor side)
  static Future<bool> createReminderByArcId({
    required String patientArcId,
    required String title,
    String? notes,
    String? dueAtIso,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;
      final idToken = await user.getIdToken();
      final res = await http.post(
        Uri.parse('$baseUrl/api/reminders/create'),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'patientArcId': patientArcId,
          'title': title,
          'notes': notes,
          'dueAt': dueAtIso,
        }),
      );
      return res.statusCode == 200 || res.statusCode == 201;
    } catch (e) {
      return false;
    }
  }
}
