import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:arcular_plus/services/api_service.dart';
import 'package:arcular_plus/services/realtime_sos_service.dart';
import 'package:arcular_plus/models/user_model.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'dart:io' show Platform;
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class EmergencySOSScreen extends StatefulWidget {
  const EmergencySOSScreen({super.key});

  @override
  State<EmergencySOSScreen> createState() => _EmergencySOSScreenState();
}

class _EmergencySOSScreenState extends State<EmergencySOSScreen> {
  static const String kTestEmergencyNumber = '123';
  Position? _currentPosition;
  String _currentAddress = 'Getting location...';
  bool _isLoading = false;
  bool _sosActivated = false;
  String? _activeSosId;
  String? _activeSosStatus;
  bool _isDischarged = false;
  String? _acceptedHospitalName;
  String? _acceptedHospitalPhone;
  String? _acceptedHospitalId;
  DateTime? _sosCreatedAt;
  DateTime? _sosAcceptedAt;
  List<Map<String, dynamic>> _nearbyHospitals = [];
  int _nearbyHospitalsCount = 0; // Track actual hospital count from SOS data
  // Additional providers to display on map
  List<Map<String, dynamic>> _labs = [];
  List<Map<String, dynamic>> _pharmacies = [];
  List<Map<String, dynamic>> _doctors = [];
  List<Map<String, dynamic>> _nurses = [];
  final List<String> _sosActivityLog = [];
  UserModel? _user; // Added for user data
  String? _emergencyId;
  List<String> _emergencyContacts =
      []; // Emergency contacts list (loaded from user settings)
  String _selectedEmergencyType = 'Medical';
  String _selectedSeverity = 'High';
  // Removed City/State/Pincode filters per requirement

  // Google Maps
  Set<Marker> _hospitalMarkers = {};
  Set<Marker> _userMarker = {};

  // SOS Escalation System
  Timer? _escalationTimer;
  bool _escalationTriggered = false;
  List<Map<String, dynamic>> _emergencyCallsTriggered = [];
  int _retryCount = 0;

  // SOS State Sync Timer
  Timer? _syncTimer;

  @override
  void initState() {
    super.initState();
    _loadPersistentSOSState(); // Load SOS state first
    _checkDischargeStatus(); // Check if user is discharged
    _initializeLocationAndProviders(); // Initialize location and load providers
    _loadUserData(); // Call new method
    _startRealtimeMonitoring();
    _startSOSStateSync(); // Start periodic SOS state sync
  }

  @override
  void dispose() {
    RealtimeSOSService.instance.stopRealtimeMonitoring();
    _escalationTimer?.cancel(); // Cancel escalation timer
    _syncTimer?.cancel(); // Cancel sync timer
    super.dispose();
  }

  // Calculate distance between two coordinates using Haversine formula
  double _calculateDistance(
      double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371; // Earth's radius in kilometers

    final double dLat = _degreesToRadians(lat2 - lat1);
    final double dLon = _degreesToRadians(lon2 - lon1);

    final double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degreesToRadians(lat1)) *
            math.cos(_degreesToRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);

    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    final double distance = earthRadius * c;

    return distance;
  }

  // Convert degrees to radians
  double _degreesToRadians(double degrees) {
    return degrees * (math.pi / 180);
  }

  // Start periodic SOS state synchronization
  void _startSOSStateSync() {
    // Sync SOS state every 30 seconds to ensure cross-platform consistency
    _syncTimer = Timer.periodic(const Duration(seconds: 30), (timer) async {
      if (!mounted) {
        timer.cancel();
        return;
      }

      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) return;

        // Get user's SOS history to check for active requests
        final sosHistory = await ApiService.getPatientSOSHistory(user.uid);

        if (sosHistory.isNotEmpty) {
          // Check if there's an active SOS request or recently discharged
          final activeSOS = sosHistory.firstWhere(
            (sos) =>
                sos['status'] == 'pending' ||
                sos['status'] == 'accepted' ||
                sos['status'] == 'discharged',
            orElse: () => {},
          );

          if (activeSOS.isNotEmpty) {
            // Found active SOS in backend
            final backendSosId = activeSOS['_id'] ?? activeSOS['sosRequestId'];
            final backendStatus = activeSOS['status'] ?? 'pending';

            // Update state if different from current state
            if (_activeSosId != backendSosId ||
                _activeSosStatus != backendStatus) {
              // Handle discharged status specially
              if (backendStatus == 'discharged') {
                setState(() {
                  _sosActivated = false; // Clear SOS state
                  _emergencyId = null;
                  _activeSosId = null;
                  _activeSosStatus = 'discharged';
                  _isDischarged = false; // User can use SOS again
                });

                // Clear local storage
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool('sos_activated', false);
                await prefs.remove('emergency_id');
                await prefs.remove('active_sos_id');
                await prefs.setString('active_sos_status', 'discharged');
                await prefs.setBool('is_discharged', false);

                print('🔄 Synced discharged status: User can use SOS again');
              } else {
                setState(() {
                  _sosActivated = true;
                  _emergencyId = backendSosId;
                  _activeSosId = backendSosId;
                  _activeSosStatus = backendStatus;
                });

                // Update local storage
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool('sos_activated', true);
                await prefs.setString('emergency_id', backendSosId);
                await prefs.setString('active_sos_id', backendSosId);
                await prefs.setString('active_sos_status', backendStatus);

                print(
                    '🔄 Synced SOS state: ID=$backendSosId, Status=$backendStatus');
              }
            }
          } else if (_sosActivated) {
            // No active SOS in backend but local state shows active
            // This means SOS was cancelled/completed on another platform
            setState(() {
              _sosActivated = false;
              _emergencyId = null;
              _activeSosId = null;
              _activeSosStatus = null;
            });

            // Clear local storage
            final prefs = await SharedPreferences.getInstance();
            await prefs.remove('sos_activated');
            await prefs.remove('emergency_id');
            await prefs.remove('active_sos_id');
            await prefs.remove('active_sos_status');

            print('🔄 SOS state cleared - no active SOS in backend');
          }
        }
      } catch (e) {
        print('❌ Error syncing SOS state: $e');
      }
    });
  }

  // Helper function to extract coordinates from any provider
  LatLng? _extractCoordinates(Map<String, dynamic> provider) {
    double? lat;
    double? lng;

    // Try different coordinate formats
    // Format 1: geoCoordinates.lat/lng
    if (provider['geoCoordinates'] != null) {
      lat = provider['geoCoordinates']['lat']?.toDouble();
      lng = provider['geoCoordinates']['lng']?.toDouble();
    }

    // Format 2: geoCoordinates.latitude/longitude
    if ((lat == null || lng == null) && provider['geoCoordinates'] != null) {
      lat = provider['geoCoordinates']['latitude']?.toDouble();
      lng = provider['geoCoordinates']['longitude']?.toDouble();
    }

    // Format 3: location.coordinates [lng, lat]
    if ((lat == null || lng == null) && provider['location'] != null) {
      final coords = provider['location']['coordinates'];
      if (coords is List && coords.length == 2) {
        lng = (coords[0] as num).toDouble();
        lat = (coords[1] as num).toDouble();
      }
    }

    // Format 4: Direct latitude/longitude fields
    if (lat == null || lng == null) {
      lat = provider['latitude']?.toDouble();
      lng = provider['longitude']?.toDouble();
    }

    // Format 5: Direct lat/lng fields
    if (lat == null || lng == null) {
      lat = provider['lat']?.toDouble();
      lng = provider['lng']?.toDouble();
    }

    // Validate coordinates
    if (lat != null &&
        lng != null &&
        lat >= -90 &&
        lat <= 90 &&
        lng >= -180 &&
        lng <= 180) {
      return LatLng(lat, lng);
    }

    return null;
  }

  // Check if user is discharged from hospital
  Future<void> _checkDischargeStatus() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Check if user has any recent SOS requests with discharged status
      final response = await ApiService.getPatientSOSHistory(user.uid);
      if (response.isNotEmpty) {
        // Check if the most recent SOS request is discharged
        final latestSOS = response.first;
        final status = latestSOS['status'] ?? '';

        if (status == 'discharged') {
          setState(() {
            _isDischarged = false; // User is discharged, can use SOS again
            _activeSosStatus = 'discharged';
          });

          // Get hospital name from SOS data
          final hospitalName =
              latestSOS['acceptedBy']?['hospitalName'] ?? 'hospital';

          // Show discharge notification with hospital name
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  '🏥 You have been discharged from $hospitalName. SOS is now available.'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 5),
            ),
          );
        } else if (status == 'admitted') {
          setState(() {
            _isDischarged = true; // User is admitted, cannot use SOS
            _activeSosStatus = 'admitted';
          });
        }
      }
    } catch (e) {
      print('❌ Error checking discharge status: $e');
    }
  }

  // Start SOS escalation monitoring
  void _startSOSEscalationMonitoring() {
    if (_activeSosId == null) return;

    print('🚨 Starting SOS escalation monitoring for: $_activeSosId');

    // Cancel existing timer
    _escalationTimer?.cancel();

    // Start monitoring every 30 seconds
    _escalationTimer =
        Timer.periodic(const Duration(seconds: 30), (timer) async {
      if (_activeSosId == null) {
        timer.cancel();
        return;
      }

      try {
        print('🔍 Checking SOS escalation status for: $_activeSosId');

        // Check escalation status
        final escalationStatus =
            await ApiService.getSOSEscalationStatus(_activeSosId!);

        if (escalationStatus['success'] == true) {
          final data = escalationStatus['data'];
          final hasAcceptedHospital = data['hasAcceptedHospital'] ?? false;

          // If hospital has accepted, stop escalation
          if (hasAcceptedHospital) {
            print(
                '✅ Hospital has accepted SOS, stopping escalation monitoring');
            timer.cancel();
            return;
          }

          // Handle escalation
          final escalationResponse =
              await ApiService.handleSOSEscalation(_activeSosId!);

          if (escalationResponse['success'] == true) {
            final escalationData = escalationResponse['data'];
            final action = escalationData['action'] ?? 'none';
            final emergencyCalls = escalationData['emergencyCalls'] ?? [];
            final shouldRetry = escalationData['shouldRetry'] ?? false;
            final retryCount = escalationData['retryCount'] ?? 0;

            print('🚨 SOS escalation action: $action');
            print('📞 Emergency calls triggered: $emergencyCalls');
            print('🔄 Should retry: $shouldRetry (attempt $retryCount)');

            // Update UI state
            setState(() {
              _escalationTriggered = true;
              _emergencyCallsTriggered = emergencyCalls;
              _retryCount = retryCount;
            });

            // Check if coordination is required
            if (escalationData['coordinationRequired'] == true) {
              print(
                  '🤝 Coordination required: ${escalationData['coordinationReason']}');

              // Show coordination dialog to user
              _showCoordinationDialog(escalationData);
            }

            // Handle emergency calls
            if (emergencyCalls.isNotEmpty) {
              for (final call in emergencyCalls) {
                final number = call['number'] ?? '';
                final type = call['type'] ?? '';
                final reason = call['reason'] ?? '';

                print(
                    '📞 Triggering emergency call: $number ($type) - $reason');

                // Show different notifications based on call type
                Color backgroundColor;
                String message;

                if (type == 'emergency_services') {
                  backgroundColor = Colors.red;
                  message = '🚨 Emergency services called (123): $reason';
                } else if (type == 'emergency_contact') {
                  backgroundColor = Colors.orange;
                  message = '📞 Emergency contact called: $reason';
                } else {
                  backgroundColor = Colors.red;
                  message = '🚨 Emergency call triggered: $number ($reason)';
                }

                // Show notification to user
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(message),
                    backgroundColor: backgroundColor,
                    duration: const Duration(seconds: 5),
                  ),
                );

                // Log the emergency call
                _logSos('Emergency call triggered: $number ($type) - $reason');
              }
            }

            // Handle retry
            if (shouldRetry) {
              _logSos('SOS request retried (attempt $retryCount)');

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('🔄 SOS request retried (attempt $retryCount)'),
                  backgroundColor: Colors.orange,
                  duration: const Duration(seconds: 3),
                ),
              );
            }
          }
        }
      } catch (e) {
        print('❌ Error in SOS escalation monitoring: $e');
      }
    });
  }

  // Stop SOS escalation monitoring
  void _stopSOSEscalationMonitoring() {
    _escalationTimer?.cancel();
    _escalationTimer = null;
    print('🛑 Stopped SOS escalation monitoring');
  }

  // Show coordination dialog when both emergency services and hospital are responding
  Future<void> _showCoordinationDialog(
      Map<String, dynamic> escalationData) async {
    if (!mounted) return;

    // final coordinationReason =
    //     escalationData['coordinationReason'] ?? 'Coordination required';
    final acceptedHospital =
        escalationData['acceptedHospital'] ?? 'Unknown Hospital';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.orange),
            const SizedBox(width: 8),
            const Text('🤝 Emergency Coordination Required'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Both emergency services (123) and hospital are responding to your SOS request.',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Current Status:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.orange[700],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                      '🚨 Emergency services (123): On the way (cannot be cancelled)'),
                  Text('🏥 Hospital: $acceptedHospital (Accepted)'),
                  const SizedBox(height: 8),
                  Text(
                    'Emergency services (123) are real responders who cannot be cancelled through the app. Choose how to coordinate when they arrive.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.orange[600],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();

              // Handle coordination - hospital will manage
              await _handleCoordination('emergency_services_cancelled', {
                'reason': 'User chose hospital to manage the case',
                'timestamp': DateTime.now().toIso8601String(),
              });
            },
            child: const Text('Hospital Will Manage'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();

              // Handle coordination - hospital cancelled
              await _handleCoordination('hospital_cancelled', {
                'reason': 'User chose emergency services to handle',
                'timestamp': DateTime.now().toIso8601String(),
              });
            },
            child: const Text('Emergency Services Will Handle'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();

              // Handle coordination - both responding
              await _handleCoordination('both_responding', {
                'reason': 'User chose both services to coordinate',
                'timestamp': DateTime.now().toIso8601String(),
              });
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
            child: const Text('Coordinate When They Arrive'),
          ),
        ],
      ),
    );
  }

  // Handle coordination action
  Future<void> _handleCoordination(
      String action, Map<String, dynamic> details) async {
    if (_activeSosId == null) return;

    try {
      print('🤝 Handling coordination: $action');

      final response = await ApiService.handleEmergencyCoordination(
        _activeSosId!,
        action,
        details,
      );

      if (response['success'] == true) {
        final data = response['data'];
        final message = data['message'] ?? 'Coordination handled';

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🤝 $message'),
            backgroundColor: Colors.blue,
            duration: const Duration(seconds: 5),
          ),
        );

        // Log coordination action
        _logSos('Coordination handled: $action - $message');

        // Handle emergency calls if any
        final emergencyCalls = data['emergencyCalls'] ?? [];
        if (emergencyCalls.isNotEmpty) {
          for (final call in emergencyCalls) {
            final number = call['number'] ?? '';
            final reason = call['reason'] ?? '';

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('📞 $reason'),
                backgroundColor: Colors.orange,
                duration: const Duration(seconds: 3),
              ),
            );

            _logSos('Emergency call: $number - $reason');
          }
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '❌ ${response['message'] ?? 'Failed to handle coordination'}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print('❌ Error handling coordination: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error handling coordination: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Initialize location and load providers in sequence
  Future<void> _initializeLocationAndProviders() async {
    try {
      // First get current location
      await _getCurrentLocation();

      // Wait a bit for location to be set
      await Future.delayed(const Duration(milliseconds: 500));

      // Then load providers with location
      await _loadNearbyHospitals();
      await _loadAllProviders();
    } catch (e) {
      print('❌ Error initializing location and providers: $e');
    }
  }

  // Load persistent SOS state from SharedPreferences and sync with backend
  Future<void> _loadPersistentSOSState() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Load SOS activation state from local storage
      final sosActivated = prefs.getBool('sos_activated') ?? false;
      final emergencyId = prefs.getString('emergency_id');
      final activeSosId = prefs.getString('active_sos_id');
      final activeSosStatus = prefs.getString('active_sos_status');

      // Always check backend for active SOS requests to ensure sync across platforms
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        try {
          // Get user's SOS history to check for active requests
          final sosHistory = await ApiService.getPatientSOSHistory(user.uid);

          if (sosHistory.isNotEmpty) {
            // Check if there's an active SOS request
            final activeSOS = sosHistory.firstWhere(
              (sos) =>
                  sos['status'] == 'pending' || sos['status'] == 'accepted',
              orElse: () => {},
            );

            if (activeSOS.isNotEmpty) {
              // Found active SOS in backend
              final backendSosId =
                  activeSOS['_id'] ?? activeSOS['sosRequestId'];
              final backendStatus = activeSOS['status'] ?? 'pending';

              setState(() {
                _sosActivated = true;
                _emergencyId = backendSosId;
                _activeSosId = backendSosId;
                _activeSosStatus = backendStatus;
              });

              // Update local storage with backend data
              await prefs.setBool('sos_activated', true);
              await prefs.setString('emergency_id', backendSosId);
              await prefs.setString('active_sos_id', backendSosId);
              await prefs.setString('active_sos_status', backendStatus);

              print(
                  '🔄 Synced SOS state from backend: ID=$backendSosId, Status=$backendStatus');

              // Resume monitoring for the active SOS
              _monitorSOSStatus();

              // Show user that SOS is still active
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('🔄 SOS still active (ID: $backendSosId)'),
                  backgroundColor: Colors.orange,
                  duration: const Duration(seconds: 3),
                ),
              );
              return;
            }
          }
        } catch (e) {
          print('❌ Error checking backend SOS status: $e');
        }
      }

      // If no active SOS in backend, use local storage
      if (sosActivated && emergencyId != null && activeSosId != null) {
        // Load accepted hospital data from local storage
        final acceptedHospitalName = prefs.getString('accepted_hospital_name');
        final acceptedHospitalPhone =
            prefs.getString('accepted_hospital_phone');
        final acceptedHospitalId = prefs.getString('accepted_hospital_id');
        final sosCreatedAtStr = prefs.getString('sos_created_at');
        final sosAcceptedAtStr = prefs.getString('sos_accepted_at');
        final isDischarged = prefs.getBool('is_discharged') ?? false;

        setState(() {
          _sosActivated = sosActivated;
          _emergencyId = emergencyId;
          _activeSosId = activeSosId;
          _activeSosStatus = activeSosStatus;
          _acceptedHospitalName = acceptedHospitalName;
          _acceptedHospitalPhone = acceptedHospitalPhone;
          _acceptedHospitalId = acceptedHospitalId;
          _isDischarged = isDischarged;

          if (sosCreatedAtStr != null) {
            _sosCreatedAt = DateTime.tryParse(sosCreatedAtStr);
          }
          if (sosAcceptedAtStr != null) {
            _sosAcceptedAt = DateTime.tryParse(sosAcceptedAtStr);
          }
        });

        print(
            '🔄 Restored SOS state from local storage: ID=$activeSosId, Status=$activeSosStatus');

        // Resume monitoring for the active SOS
        _monitorSOSStatus();

        // Show user that SOS is still active
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🔄 SOS still active (ID: $activeSosId)'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      print('❌ Error loading persistent SOS state: $e');
    }
  }

  // Save SOS state to SharedPreferences
  Future<void> _saveSOSState() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      await prefs.setBool('sos_activated', _sosActivated);
      await prefs.setString('emergency_id', _emergencyId ?? '');
      await prefs.setString('active_sos_id', _activeSosId ?? '');
      await prefs.setString('active_sos_status', _activeSosStatus ?? '');
      await prefs.setString(
          'accepted_hospital_name', _acceptedHospitalName ?? '');
      await prefs.setString(
          'accepted_hospital_phone', _acceptedHospitalPhone ?? '');
      await prefs.setString('accepted_hospital_id', _acceptedHospitalId ?? '');
      await prefs.setString(
          'sos_created_at', _sosCreatedAt?.toIso8601String() ?? '');
      await prefs.setString(
          'sos_accepted_at', _sosAcceptedAt?.toIso8601String() ?? '');
      await prefs.setBool('is_discharged', _isDischarged);

      print('💾 Saved SOS state: activated=$_sosActivated, id=$_activeSosId');
    } catch (e) {
      print('❌ Error saving SOS state: $e');
    }
  }

  // Clear SOS state from SharedPreferences
  Future<void> _clearSOSState() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      await prefs.remove('sos_activated');
      await prefs.remove('emergency_id');
      await prefs.remove('active_sos_id');
      await prefs.remove('active_sos_status');

      print('🗑️ Cleared SOS state from storage');
    } catch (e) {
      print('❌ Error clearing SOS state: $e');
    }
  }

  Future<void> _startRealtimeMonitoring() async {
    try {
      await RealtimeSOSService.instance.startRealtimeMonitoring(
        userType: 'user',
        onAccepted: (request) {
          if (mounted) {
            _handleHospitalAcceptance(request);
          }
        },
        onAdmitted: (request) {
          if (mounted) {
            _handlePatientAdmission(request);
          }
        },
        onStatusUpdated: (request) {
          if (mounted) {
            setState(() {
              _sosActivated = request['status'] == 'accepted' ||
                  request['status'] == 'admitted';
            });
          }
        },
      );

      print('✅ Real-time SOS monitoring started for user');
    } catch (e) {
      print('❌ Error starting real-time SOS monitoring: $e');
    }
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isLoading = true);

    try {
      // Check permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _currentAddress = 'Location permission denied';
            _isLoading = false;
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _currentAddress = 'Location permission permanently denied';
          _isLoading = false;
        });
        return;
      }

      // Get current position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _currentPosition = position;
        _isLoading = false;
      });

      // Get address from coordinates
      await _getAddressFromCoordinates(position);
    } catch (e) {
      setState(() {
        _currentAddress = 'Error getting location';
        _isLoading = false;
      });
    }
  }

  Future<void> _getAddressFromCoordinates(Position position) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        setState(() {
          _currentAddress =
              '${place.street}, ${place.locality}, ${place.administrativeArea}';
        });
      }
    } catch (e) {
      setState(() {
        _currentAddress = 'Address not available';
      });
    }
  }

  void _logSos(String message) {
    final ts = DateTime.now().toLocal().toString().split('.').first;
    setState(() {
      _sosActivityLog.insert(0, '[$ts] $message');
      if (_sosActivityLog.length > 50) {
        _sosActivityLog.removeRange(50, _sosActivityLog.length);
      }
    });
  }

  Future<void> _loadNearbyHospitals() async {
    try {
      setState(() => _isLoading = true);

      // Get current location for API call
      double? latitude;
      String? city;
      String? pincode;

      if (_currentPosition != null) {
        latitude = _currentPosition!.latitude;
        // Get city and pincode from current address
        if (_user?.city != null) city = _user!.city;
        if (_user?.pincode != null) pincode = _user!.pincode;
      }

      print(
          '🏥 Loading nearby hospitals with location: lat=$latitude, city=$city, pincode=$pincode');

      final hospitals = await ApiService.getNearbyHospitals(
        latitude: latitude,
        longitude: _currentPosition?.longitude,
        city: city,
        pincode: pincode,
        radius: 15.0,
      );

      print('🏥 API Response for 15km radius:');
      print('🔍 Hospitals returned: ${hospitals.length}');
      print(
          '🔍 First hospital data: ${hospitals.isNotEmpty ? hospitals.first : 'No hospitals'}');

      // Debug: Print all hospital data
      for (int i = 0; i < hospitals.length; i++) {
        print('🏥 Hospital $i: ${hospitals[i]}');
      }

      List<Map<String, dynamic>> results = hospitals;

      // Calculate distances for all hospitals
      if (_currentPosition != null) {
        print(
            '📍 User location: ${_currentPosition!.latitude}, ${_currentPosition!.longitude}');
        for (var hospital in results) {
          final hospitalCoords = _extractCoordinates(hospital);
          print('🏥 Hospital: ${hospital['hospitalName'] ?? hospital['name']}');
          print('🏥 Hospital data: ${hospital.keys.toList()}');
          if (hospitalCoords != null) {
            final distance = _calculateDistance(
              _currentPosition!.latitude,
              _currentPosition!.longitude,
              hospitalCoords.latitude,
              hospitalCoords.longitude,
            );
            hospital['distance'] = distance;
            print('✅ Distance calculated: ${distance.toStringAsFixed(2)} km');
          } else {
            print('❌ No valid coordinates found for hospital');
            print('🏥 Available fields: ${hospital.keys.toList()}');
            if (hospital['geoCoordinates'] != null) {
              print('🏥 geoCoordinates: ${hospital['geoCoordinates']}');
            }
            if (hospital['location'] != null) {
              print('🏥 location: ${hospital['location']}');
            }
            if (hospital['latitude'] != null) {
              print('🏥 latitude: ${hospital['latitude']}');
            }
            if (hospital['longitude'] != null) {
              print('🏥 longitude: ${hospital['longitude']}');
            }
          }
        }

        // Sort hospitals by distance
        results.sort((a, b) {
          final distanceA = a['distance'] ?? double.infinity;
          final distanceB = b['distance'] ?? double.infinity;
          return distanceA.compareTo(distanceB);
        });
      }

      // If none found in 15km radius, try 25km radius
      if (results.isEmpty) {
        print('⚠️ No hospitals found in 15km radius, trying 25km radius');
        try {
          final fallbackHospitals = await ApiService.getNearbyHospitals(
            latitude: latitude,
            longitude: _currentPosition?.longitude,
            city: city,
            pincode: pincode,
            radius: 25.0,
          );

          results = fallbackHospitals;
          print('📍 Found ${results.length} hospitals in 25km radius');

          // Calculate distances for 25km radius hospitals
          if (_currentPosition != null && results.isNotEmpty) {
            print(
                '📍 Calculating distances for ${results.length} hospitals in 25km radius');
            for (var hospital in results) {
              final hospitalCoords = _extractCoordinates(hospital);
              if (hospitalCoords != null) {
                final distance = _calculateDistance(
                  _currentPosition!.latitude,
                  _currentPosition!.longitude,
                  hospitalCoords.latitude,
                  hospitalCoords.longitude,
                );
                hospital['distance'] = distance;
                print(
                    '✅ 25km radius hospital distance: ${hospital['hospitalName'] ?? hospital['name']} - ${distance.toStringAsFixed(2)} km');
              } else {
                print(
                    '❌ 25km radius hospital no coordinates: ${hospital['hospitalName'] ?? hospital['name']}');
              }
            }

            // Sort 25km radius hospitals by distance
            results.sort((a, b) {
              final distanceA = a['distance'] ?? double.infinity;
              final distanceB = b['distance'] ?? double.infinity;
              return distanceA.compareTo(distanceB);
            });
          }
        } catch (e) {
          print('❌ Error fetching 25km radius hospitals: $e');
        }
      }

      // If still none found, fetch all approved/active hospitals (no radius)
      if (results.isEmpty) {
        try {
          final user = FirebaseAuth.instance.currentUser;
          final idToken = await user?.getIdToken();
          if (idToken != null) {
            final uri = Uri.parse('${ApiService.baseUrl}/api/hospitals');
            final resp = await http.get(uri, headers: {
              'Authorization': 'Bearer $idToken',
              'Content-Type': 'application/json',
            });
            if (resp.statusCode == 200) {
              final data = json.decode(resp.body);
              final list = List<Map<String, dynamic>>.from(
                  data['data'] ?? data['hospitals'] ?? []);
              // Prefer only approved+active if flags exist
              results = list.where((h) {
                final approved = h['isApproved'] == true ||
                    h['approvalStatus'] == 'approved';
                final active = (h['status'] ?? 'active') == 'active';
                return approved && active;
              }).toList();
            }
          }
        } catch (_) {}

        // Calculate distances for final fallback hospitals too
        if (_currentPosition != null && results.isNotEmpty) {
          print(
              '📍 Calculating distances for ${results.length} final fallback hospitals (all approved/active)');
          for (var hospital in results) {
            final hospitalCoords = _extractCoordinates(hospital);
            if (hospitalCoords != null) {
              final distance = _calculateDistance(
                _currentPosition!.latitude,
                _currentPosition!.longitude,
                hospitalCoords.latitude,
                hospitalCoords.longitude,
              );
              hospital['distance'] = distance;
              print(
                  '✅ Final fallback hospital distance: ${hospital['hospitalName'] ?? hospital['name']} - ${distance.toStringAsFixed(2)} km');
            } else {
              print(
                  '❌ Final fallback hospital no coordinates: ${hospital['hospitalName'] ?? hospital['name']}');
            }
          }

          // Sort final fallback hospitals by distance
          results.sort((a, b) {
            final distanceA = a['distance'] ?? double.infinity;
            final distanceB = b['distance'] ?? double.infinity;
            return distanceA.compareTo(distanceB);
          });
        }
      }

      // Removed client-side City/State/Pincode filtering

      setState(() {
        _nearbyHospitals = results;
        _isLoading = false;
      });

      // Get hospital count from SOS request data if available
      int hospitalCount = 0;
      if (_activeSosId != null) {
        try {
          // Get SOS request details to get hospital count
          final sosDetails =
              await ApiService.getSOSRequestStatus(_activeSosId!);
          if (sosDetails['success'] == true) {
            hospitalCount = sosDetails['data']['nearbyHospitals'] ?? 0;
            print('🏥 Hospital count from SOS data: $hospitalCount');
          }
        } catch (e) {
          print('❌ Error getting SOS details for hospital count: $e');
        }
      }

      // Update hospital count in UI
      setState(() {
        _nearbyHospitalsCount = hospitalCount;
      });

      // If no hospitals found, show a message
      if (results.isEmpty) {
        print('⚠️ No hospitals found - this might indicate an API issue');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'No hospitals found nearby. Please try again or contact support.'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      print('❌ Error loading nearby hospitals: $e');
      setState(() => _isLoading = false);

      // Show error message to user
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load hospitals: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'Retry',
            textColor: Colors.white,
            onPressed: () {
              _loadNearbyHospitals();
            },
          ),
        ),
      );

      // Fallback to mock data if API fails
      _loadMockHospitals();
    }
  }

  Future<void> _loadAllProviders() async {
    try {
      // Get current location for radius filtering
      double? latitude;
      double? longitude;
      String? city;
      String? pincode;

      if (_currentPosition != null) {
        latitude = _currentPosition!.latitude;
        longitude = _currentPosition!.longitude;
        // Get city and pincode from current address
        if (_user?.city != null) city = _user!.city;
        if (_user?.pincode != null) pincode = _user!.pincode;
      }

      print(
          '🏥 Loading all service providers with location: lat=$latitude, lng=$longitude, city=$city, pincode=$pincode');

      await Future.wait([
        _loadLabs(
            latitude: latitude,
            longitude: longitude,
            city: city,
            pincode: pincode),
        _loadPharmacies(
            latitude: latitude,
            longitude: longitude,
            city: city,
            pincode: pincode),
        _loadDoctors(
            latitude: latitude,
            longitude: longitude,
            city: city,
            pincode: pincode),
        _loadNurses(
            latitude: latitude,
            longitude: longitude,
            city: city,
            pincode: pincode),
      ]);
      _updateMapMarkers();
    } catch (e) {
      print('❌ Error loading providers: $e');
    }
  }

  Future<void> _loadLabs({
    double? latitude,
    double? longitude,
    String? city,
    String? pincode,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final idToken = await user?.getIdToken();
      if (idToken == null) return;

      List<Map<String, dynamic>> labs = [];

      // Try to get nearby labs first if location is available
      if (latitude != null && longitude != null) {
        try {
          final nearbyLabs = await ApiService.getNearbyLabs(
            latitude: latitude,
            longitude: longitude,
            city: city,
            pincode: pincode,
            radius: 15.0,
          );
          labs = nearbyLabs;
          print('✅ Loaded ${labs.length} nearby labs');
        } catch (e) {
          print('⚠️ Nearby labs API failed, falling back to all labs: $e');
        }
      }

      // Fallback to all labs if nearby search failed or no location
      if (labs.isEmpty) {
        final uri = Uri.parse('${ApiService.baseUrl}/api/labs');
        final resp = await http.get(uri, headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        });
        if (resp.statusCode == 200) {
          final data = json.decode(resp.body);
          final list = List<Map<String, dynamic>>.from(data['data'] ?? []);
          labs = list
              .where((e) => (e['isApproved'] == true ||
                  e['approvalStatus'] == 'approved'))
              .toList();
          print('✅ Loaded ${labs.length} total labs (fallback)');
        }
      }

      setState(() {
        _labs = labs;
      });
    } catch (e) {
      print('❌ Error loading labs: $e');
    }
  }

  Future<void> _loadPharmacies({
    double? latitude,
    double? longitude,
    String? city,
    String? pincode,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final idToken = await user?.getIdToken();
      if (idToken == null) return;

      List<Map<String, dynamic>> pharmacies = [];

      // Try to get nearby pharmacies first if location is available
      if (latitude != null && longitude != null) {
        try {
          final nearbyPharmacies = await ApiService.getNearbyPharmacies(
            latitude: latitude,
            longitude: longitude,
            city: city,
            pincode: pincode,
            radius: 15.0,
          );
          pharmacies = nearbyPharmacies;
          print('✅ Loaded ${pharmacies.length} nearby pharmacies');
        } catch (e) {
          print(
              '⚠️ Nearby pharmacies API failed, falling back to all pharmacies: $e');
        }
      }

      // Fallback to all pharmacies if nearby search failed or no location
      if (pharmacies.isEmpty) {
        final uri = Uri.parse('${ApiService.baseUrl}/api/pharmacies');
        final resp = await http.get(uri, headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        });
        if (resp.statusCode == 200) {
          final data = json.decode(resp.body);
          final list = List<Map<String, dynamic>>.from(data['data'] ?? []);
          pharmacies = list
              .where((e) => (e['isApproved'] == true ||
                  e['approvalStatus'] == 'approved'))
              .toList();
          print('✅ Loaded ${pharmacies.length} total pharmacies (fallback)');
        }
      }

      setState(() {
        _pharmacies = pharmacies;
      });
    } catch (e) {
      print('❌ Error loading pharmacies: $e');
    }
  }

  Future<void> _loadDoctors({
    double? latitude,
    double? longitude,
    String? city,
    String? pincode,
  }) async {
    try {
      List<Map<String, dynamic>> doctors = [];

      // Try to get nearby doctors first if location is available
      if (latitude != null && longitude != null) {
        try {
          final nearbyDoctors = await ApiService.getNearbyDoctors(
            latitude: latitude,
            longitude: longitude,
            city: city,
            pincode: pincode,
            radius: 15.0,
          );
          doctors = nearbyDoctors;
          print('✅ Loaded ${doctors.length} nearby doctors');
        } catch (e) {
          print(
              '⚠️ Nearby doctors API failed, falling back to all doctors: $e');
        }
      }

      // Fallback to all doctors if nearby search failed or no location
      if (doctors.isEmpty) {
        final allDoctors = await ApiService.getAllDoctors();
        doctors = allDoctors
            .map((u) => {
                  'uid': u.uid,
                  'fullName': u.fullName,
                  'email': u.email,
                  'mobileNumber': u.mobileNumber,
                  'address': u.address,
                  'city': u.city,
                  'state': u.state,
                  'pincode': u.pincode,
                })
            .toList();
        print('✅ Loaded ${doctors.length} total doctors (fallback)');
      }

      setState(() {
        _doctors = doctors;
      });
    } catch (e) {
      print('❌ Error loading doctors: $e');
    }
  }

  Future<void> _loadNurses({
    double? latitude,
    double? longitude,
    String? city,
    String? pincode,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final idToken = await user?.getIdToken();
      if (idToken == null) return;

      List<Map<String, dynamic>> nurses = [];

      // Try to get nearby nurses first if location is available
      if (latitude != null && longitude != null) {
        try {
          final nearbyNurses = await ApiService.getNearbyNurses(
            latitude: latitude,
            longitude: longitude,
            city: city,
            pincode: pincode,
            radius: 15.0,
          );
          nurses = nearbyNurses;
          print('✅ Loaded ${nurses.length} nearby nurses');
        } catch (e) {
          print('⚠️ Nearby nurses API failed, falling back to all nurses: $e');
        }
      }

      // Fallback to all nurses if nearby search failed or no location
      if (nurses.isEmpty) {
        final uri = Uri.parse('${ApiService.baseUrl}/api/nurses');
        final resp = await http.get(uri, headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        });
        if (resp.statusCode == 200) {
          final data = json.decode(resp.body);
          final list = List<Map<String, dynamic>>.from(data['data'] ?? []);
          nurses = list
              .where((e) => (e['isApproved'] == true ||
                  e['approvalStatus'] == 'approved'))
              .toList();
          print('✅ Loaded ${nurses.length} total nurses (fallback)');
        }
      }

      setState(() {
        _nurses = nurses;
      });
    } catch (e) {
      print('❌ Error loading nurses: $e');
    }
  }

  void _loadMockHospitals() {
    // Mock data - fallback when API fails
    _nearbyHospitals = [
      {
        'name': 'City General Hospital',
        'distance': '0.5 km',
        'phone': '+1234567890',
        'address': '123 Main St, City Center, Pincode 12345',
        'rating': 4.5,
        'specialties': ['Emergency', 'Cardiology', 'Trauma'],
        'available': true,
      },
      {
        'name': 'Metropolitan Medical Center',
        'distance': '1.2 km',
        'phone': '+1234567891',
        'address': '456 Oak Ave, Downtown, Pincode 12346',
        'rating': 4.3,
        'specialties': ['Emergency', 'Neurology', 'Surgery'],
        'available': true,
      },
      {
        'name': 'Community Health Hospital',
        'distance': '2.1 km',
        'phone': '+1234567892',
        'address': '789 Pine Rd, Suburb, Pincode 12347',
        'rating': 4.1,
        'specialties': ['Emergency', 'Pediatrics', 'Orthopedics'],
        'available': false,
      },
      {
        'name': 'University Medical Center',
        'distance': '3.5 km',
        'phone': '+1234567893',
        'address': '321 Campus Dr, University District, Pincode 12348',
        'rating': 4.7,
        'specialties': ['Emergency', 'Research', 'Specialized Care'],
        'available': true,
      },
    ];

    // Update map markers after loading mock data
    _updateMapMarkers();
  }

  // Update map markers for hospitals and user
  void _updateMapMarkers() {
    final Set<Marker> hospitalMarkers = {};
    final Set<Marker> userMarker = {};

    // Add user marker if position is available
    if (_currentPosition != null) {
      userMarker.add(
        Marker(
          markerId: const MarkerId('user_location'),
          position:
              LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          infoWindow: const InfoWindow(
            title: 'Your Location',
            snippet: 'Current position',
          ),
        ),
      );
    }

    // Add hospital markers
    for (int i = 0; i < _nearbyHospitals.length; i++) {
      final hospital = _nearbyHospitals[i];

      // Extract real coordinates
      final coordinates = _extractCoordinates(hospital);

      // Only add marker if we have valid coordinates
      if (coordinates != null) {
        final isAvailable =
            hospital['status'] == 'active' || hospital['available'] == true;
        final hospitalName =
            hospital['hospitalName'] ?? hospital['name'] ?? 'Hospital';
        final address = hospital['address'] ?? 'Address not available';

        hospitalMarkers.add(
          Marker(
            markerId: MarkerId('hospital_$i'),
            position: coordinates,
            icon: BitmapDescriptor.defaultMarkerWithHue(
              isAvailable ? BitmapDescriptor.hueGreen : BitmapDescriptor.hueRed,
            ),
            infoWindow: InfoWindow(
              title: hospitalName,
              snippet: address,
            ),
          ),
        );
      }
    }

    // Add lab markers (azure)
    for (int i = 0; i < _labs.length; i++) {
      final lab = _labs[i];
      final coordinates = _extractCoordinates(lab);

      // Only add marker if we have valid coordinates
      if (coordinates != null) {
        final name = lab['labName'] ?? lab['fullName'] ?? 'Lab';
        final address = lab['address'] ?? 'Address not available';
        hospitalMarkers.add(
          Marker(
            markerId: MarkerId('lab_$i'),
            position: coordinates,
            icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueAzure),
            infoWindow:
                InfoWindow(title: name.toString(), snippet: 'Lab • $address'),
          ),
        );
      }
    }

    // Add pharmacy markers (yellow)
    for (int i = 0; i < _pharmacies.length; i++) {
      final ph = _pharmacies[i];
      final coordinates = _extractCoordinates(ph);

      // Only add marker if we have valid coordinates
      if (coordinates != null) {
        final name = ph['pharmacyName'] ?? 'Pharmacy';
        final address = ph['address'] ?? 'Address not available';
        hospitalMarkers.add(
          Marker(
            markerId: MarkerId('pharmacy_$i'),
            position: coordinates,
            icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueYellow),
            infoWindow: InfoWindow(
                title: name.toString(), snippet: 'Pharmacy • $address'),
          ),
        );
      }
    }

    // Add doctor markers (violet)
    for (int i = 0; i < _doctors.length; i++) {
      final d = _doctors[i];
      final coordinates = _extractCoordinates(d);

      // Only add marker if we have valid coordinates
      if (coordinates != null) {
        final name = d['fullName'] ?? 'Doctor';
        final address = d['address'] ?? 'Address not available';
        hospitalMarkers.add(
          Marker(
            markerId: MarkerId('doctor_$i'),
            position: coordinates,
            icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueViolet),
            infoWindow: InfoWindow(
                title: name.toString(), snippet: 'Doctor • $address'),
          ),
        );
      }
    }

    // Add nurse markers (orange)
    for (int i = 0; i < _nurses.length; i++) {
      final n = _nurses[i];
      final coordinates = _extractCoordinates(n);

      // Only add marker if we have valid coordinates
      if (coordinates != null) {
        final name = n['fullName'] ?? 'Nurse';
        final address = n['address'] ?? 'Address not available';
        hospitalMarkers.add(
          Marker(
            markerId: MarkerId('nurse_$i'),
            position: coordinates,
            icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueOrange),
            infoWindow:
                InfoWindow(title: name.toString(), snippet: 'Nurse • $address'),
          ),
        );
      }
    }

    setState(() {
      _hospitalMarkers = hospitalMarkers;
      _userMarker = userMarker;
    });
  }

  // Open driving route in Google Maps from user to hospital
  Future<void> _openHospitalDirections(Map<String, dynamic> hospital) async {
    try {
      final coordinates = _extractCoordinates(hospital);

      if (coordinates == null || _currentPosition == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location not available to open directions'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      final destLat = coordinates.latitude;
      final destLng = coordinates.longitude;
      final origin =
          '${_currentPosition!.latitude},${_currentPosition!.longitude}';
      final destination = '$destLat,$destLng';
      final url =
          'https://www.google.com/maps/dir/?api=1&origin=$origin&destination=$destination&travelmode=driving';
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to open directions: $e')),
      );
    }
  }

  Future<void> _loadUserData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      print('🚨 Loading emergency SOS data for UID: ${user.uid}');

      // Use universal getUserInfo method which respects user type
      final userModel = await ApiService.getUserInfo(user.uid);

      if (userModel != null) {
        print(
            '✅ Emergency SOS data loaded successfully: ${userModel.fullName}');
        print('🔍 User data debug:');
        print('  - Full Name: ${userModel.fullName}');
        print('  - Mobile Number: ${userModel.mobileNumber}');
        print('  - Gender: ${userModel.gender}');
        print('  - Email: ${userModel.email}');
        print('  - Emergency Contact Name: ${userModel.emergencyContactName}');
        print(
            '  - Emergency Contact Number: ${userModel.emergencyContactNumber}');
        print(
            '  - Emergency Contact Relation: ${userModel.emergencyContactRelation}');
        setState(() {
          _user = userModel;
          // Update emergency contacts from user settings
          _emergencyContacts = [];

          // Add user's emergency contact if available
          if (userModel.emergencyContactNumber != null &&
              userModel.emergencyContactNumber!.isNotEmpty) {
            _emergencyContacts.add(userModel.emergencyContactNumber!);
            print(
                '📞 Added emergency contact: ${userModel.emergencyContactNumber}');
          }

          // Always add non-emergency test number as fallback
          _emergencyContacts.add(kTestEmergencyNumber);
          print('📞 Emergency contacts list: $_emergencyContacts');
        });
      } else {
        print('❌ Emergency SOS data not found');
        // Keep default emergency contacts (test number) if user data not found
        setState(() {
          _emergencyContacts = [kTestEmergencyNumber];
        });
      }
    } catch (e) {
      print('❌ Error loading emergency SOS data: $e');
      // Keep default emergency contacts (test number) if error occurs
      setState(() {
        _emergencyContacts = [kTestEmergencyNumber];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Emergency SOS',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.red[600],
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: _sosActivated
                ? const [
                    Color(0xFF4CAF50),
                    Color(0xFF66BB6A),
                    Color(0xFFE8F5E9)
                  ] // green gradient when active
                : const [
                    Color(0xFFFF6B6B),
                    Color(0xFFFF8E8E),
                    Color(0xFFFFE5E5)
                  ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Emergency SOS Button
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: _sosActivated
                        ? [Colors.green, Colors.green.shade700]
                        : [Colors.red, Colors.red.shade700],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      _sosActivated ? Icons.check_circle : Icons.emergency,
                      size: 80,
                      color: Colors.white,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _sosActivated ? 'SOS ACTIVATED' : 'EMERGENCY SOS',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _sosActivated
                          ? 'Help is on the way!'
                          : 'Tap to send emergency alert',
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: 200,
                      height: 60,
                      child: ElevatedButton(
                        onPressed: () async {
                          if (_sosActivated) {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Cancel SOS?'),
                                content: const Text(
                                    'An SOS is active. Do you want to cancel it now?'),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, false),
                                    child: const Text('No'),
                                  ),
                                  ElevatedButton(
                                    onPressed: () =>
                                        Navigator.pop(context, true),
                                    style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.red),
                                    child: const Text('Cancel SOS'),
                                  ),
                                ],
                              ),
                            );
                            if (confirm == true) {
                              await _cancelSOS();
                            }
                          } else {
                            // Check if user is discharged
                            if (_isDischarged) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                      '🚫 SOS not available: You are currently admitted in hospital. Please contact hospital staff for discharge.'),
                                  backgroundColor: Colors.orange,
                                  duration: Duration(seconds: 5),
                                ),
                              );
                              return;
                            }
                            _activateSOS();
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: _sosActivated
                              ? Colors.green
                              : _isDischarged
                                  ? Colors.orange
                                  : Colors.red,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        child: Text(
                          _sosActivated
                              ? 'CANCEL SOS'
                              : _isDischarged
                                  ? 'ADMITTED IN HOSPITAL'
                                  : 'ACTIVATE SOS',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Current Location
              Container(
                padding: const EdgeInsets.all(16),
                child: Card(
                  elevation: 3,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.location_on, color: Colors.red),
                            const SizedBox(width: 8),
                            const Text(
                              'Your Location',
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (_isLoading)
                          const Row(
                            children: [
                              CircularProgressIndicator(),
                              SizedBox(width: 12),
                              Text('Getting your location...'),
                            ],
                          )
                        else ...[
                          Text(
                            _currentAddress,
                            style: const TextStyle(fontSize: 16),
                          ),
                          if (_currentPosition != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              'Coordinates: ${_currentPosition!.latitude.toStringAsFixed(4)}, ${_currentPosition!.longitude.toStringAsFixed(4)}',
                              style: TextStyle(
                                  color: Colors.grey[600], fontSize: 12),
                            ),
                          ],
                        ],
                      ],
                    ),
                  ),
                ),
              ),

              // Active SOS summary (only show when hospital accepts, admits, or discharges)
              if (_activeSosId != null &&
                  (_activeSosStatus == 'accepted' ||
                      _activeSosStatus == 'admitted' ||
                      _activeSosStatus == 'discharged'))
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Card(
                    elevation: 3,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                  _activeSosStatus == 'discharged'
                                      ? Icons.check_circle
                                      : _activeSosStatus == 'admitted'
                                          ? Icons.local_hospital
                                          : Icons.health_and_safety,
                                  color: _activeSosStatus == 'discharged'
                                      ? Colors.blue
                                      : _activeSosStatus == 'admitted'
                                          ? Colors.purple
                                          : Colors.green),
                              const SizedBox(width: 8),
                              Text(
                                  _activeSosStatus == 'discharged'
                                      ? 'SOS Completed'
                                      : _activeSosStatus == 'admitted'
                                          ? 'SOS Admitted'
                                          : 'SOS Accepted',
                                  style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'ID: ${_activeSosId}',
                            style: const TextStyle(fontSize: 14),
                          ),
                          Text(
                            'Status: ${_activeSosStatus ?? 'Unknown'}',
                            style: const TextStyle(fontSize: 14),
                          ),
                          if (_acceptedHospitalName != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Hospital: $_acceptedHospitalName',
                              style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.green),
                            ),
                          ],
                          if (_sosCreatedAt != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Created: ${_sosCreatedAt!.toLocal().toString().split('.')[0]}',
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.grey),
                            ),
                          ],
                          if (_sosAcceptedAt != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Accepted: ${_sosAcceptedAt!.toLocal().toString().split('.')[0]}',
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.green),
                            ),
                          ],
                          // Show escalation status if triggered
                          if (_escalationTriggered) ...[
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.red[50],
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.red[200]!),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.warning,
                                          color: Colors.red[600], size: 16),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Emergency Escalation Active',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.red[700],
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (_retryCount > 0) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      'Retry Attempt: $_retryCount',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.red[600],
                                      ),
                                    ),
                                  ],
                                  if (_emergencyCallsTriggered.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      'Emergency Calls Triggered: ${_emergencyCallsTriggered.length}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.red[600],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.green[50],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.green[200]!),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '✅ ${_acceptedHospitalName ?? 'Hospital'} has accepted your emergency request!',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green[700],
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Help is on the way! Stay calm and wait for assistance.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.green[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          // Hospital Reached Button
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () async {
                                await _showHospitalReachedDialog();
                              },
                              icon: const Icon(Icons.location_on),
                              label: const Text('Hospital Reached'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange,
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          // Only show Cancel SOS button - Mark as Admitted is handled by hospital
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () async {
                                await _showCancelSOSDialog();
                              },
                              icon: const Icon(Icons.cancel),
                              label: const Text('Cancel SOS'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              // Quick Actions
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Quick Actions',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildQuickActionCard(
                            'Call 123',
                            Icons.phone,
                            Colors.red,
                            () => _callEmergency(),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildQuickActionCard(
                            'Send SMS',
                            Icons.sms,
                            Colors.orange,
                            () => _sendEmergencySMS(),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Nearby Hospitals
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Nearby Hospitals (${_nearbyHospitalsCount > 0 ? _nearbyHospitalsCount : _nearbyHospitals.length})',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          onPressed: _loadNearbyHospitals,
                          icon: const Icon(Icons.refresh),
                          tooltip: 'Refresh hospitals',
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Removed City/State/Pincode filters and Apply Filter button
                    const SizedBox(height: 12),

                    // Google Maps (disabled on web; open external maps instead)
                    if (_currentPosition != null && !kIsWeb)
                      GestureDetector(
                        onTap: () => _showFullscreenMap(),
                        child: Container(
                          height: 200,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey[300]!),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Stack(
                              children: [
                                GoogleMap(
                                  onMapCreated:
                                      (GoogleMapController controller) {
                                    // Map controller for future use
                                  },
                                  initialCameraPosition: CameraPosition(
                                    target: _currentPosition != null
                                        ? LatLng(_currentPosition!.latitude,
                                            _currentPosition!.longitude)
                                        : const LatLng(20.5937,
                                            78.9629), // Default to India center
                                    zoom: 13.0,
                                  ),
                                  markers: {
                                    ..._userMarker,
                                    ..._hospitalMarkers
                                  },
                                  myLocationEnabled:
                                      !kIsWeb, // Disable on web for better performance
                                  myLocationButtonEnabled:
                                      !kIsWeb, // Disable on web for better performance
                                  mapType: MapType.normal,
                                  // Web-specific optimizations
                                  zoomControlsEnabled:
                                      !kIsWeb, // Disable zoom controls on web
                                  mapToolbarEnabled:
                                      !kIsWeb, // Disable toolbar on web
                                ),
                                Positioned(
                                  top: 8,
                                  right: 8,
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.9),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(
                                      Icons.fullscreen,
                                      color: Colors.blue,
                                      size: 20,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    if (_sosActivityLog.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(top: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'SOS Activity',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              ..._sosActivityLog.take(10).map((e) => Padding(
                                    padding:
                                        const EdgeInsets.symmetric(vertical: 2),
                                    child: Text(
                                      e,
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[700]),
                                    ),
                                  )),
                            ],
                          ),
                        ),
                      ),
                    if (_currentPosition != null && kIsWeb)
                      Container(
                        height: 200,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[300]!),
                          color: Colors.white,
                        ),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.map,
                                  color: Colors.red, size: 28),
                              const SizedBox(height: 8),
                              const Text('Map preview unavailable on web'),
                              const SizedBox(height: 6),
                              TextButton(
                                onPressed: () {
                                  final mapsUrl =
                                      'https://www.google.com/maps/search/?api=1&query=${_currentPosition!.latitude},${_currentPosition!.longitude}';
                                  launchUrl(Uri.parse(mapsUrl),
                                      mode: LaunchMode.externalApplication);
                                },
                                child: const Text('Open in Google Maps'),
                              )
                            ],
                          ),
                        ),
                      ),

                    const SizedBox(height: 16),

                    // Hospital List
                    if (_isLoading)
                      const Center(child: CircularProgressIndicator())
                    else
                      ..._nearbyHospitals
                          .map((hospital) => _buildHospitalCard(hospital)),
                  ],
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActionCard(
      String title, IconData icon, Color color, VoidCallback onTap) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Icon(icon, color: color, size: 40),
              const SizedBox(height: 8),
              Text(
                title.replaceAll('108', '000'),
                style: const TextStyle(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHospitalCard(Map<String, dynamic> hospital) {
    // Debug logging to see what data we're receiving
    print('🏥 Building hospital card with data:');
    print('🔍 Hospital keys: ${hospital.keys.toList()}');
    print('🔍 Hospital name: ${hospital['hospitalName'] ?? hospital['name']}');
    print('🔍 Hospital address: ${hospital['address']}');
    print(
        '🔍 Hospital phone: ${hospital['mobileNumber'] ?? hospital['phone']}');

    // Handle both API data and mock data
    final hospitalName =
        hospital['hospitalName'] ?? hospital['name'] ?? 'Hospital';
    final address = hospital['address'] ?? 'Address not available';
    final phone =
        hospital['mobileNumber'] ?? hospital['phone'] ?? 'Phone not available';
    // Handle both numeric distance and string distance
    String distance;
    if (hospital['distance'] != null) {
      if (hospital['distance'] is String) {
        distance = hospital['distance'];
      } else {
        distance = '${hospital['distance'].toStringAsFixed(1)} km';
      }
    } else {
      // Try to calculate distance if coordinates are available
      if (_currentPosition != null) {
        final hospitalCoords = _extractCoordinates(hospital);
        if (hospitalCoords != null) {
          final calculatedDistance = _calculateDistance(
            _currentPosition!.latitude,
            _currentPosition!.longitude,
            hospitalCoords.latitude,
            hospitalCoords.longitude,
          );
          distance = '${calculatedDistance.toStringAsFixed(1)} km';
        } else {
          distance = 'Distance not available';
        }
      } else {
        distance = 'Distance not available';
      }
    }
    final isAvailable =
        hospital['status'] == 'active' || hospital['available'] == true;
    final departments =
        hospital['departments'] ?? hospital['specialties'] ?? ['Emergency'];

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _openHospitalDirections(hospital),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          hospitalName,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          address,
                          style:
                              TextStyle(color: Colors.grey[600], fontSize: 12),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.location_on,
                                color: Colors.blue, size: 16),
                            Text(
                              ' $distance',
                              style: TextStyle(
                                  color: Colors.blue[700],
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.phone, color: Colors.green, size: 16),
                            Text(
                              ' $phone',
                              style: TextStyle(
                                  color: Colors.grey[600], fontSize: 12),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isAvailable
                          ? Colors.green.withOpacity(0.1)
                          : Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      isAvailable ? 'AVAILABLE' : 'BUSY',
                      style: TextStyle(
                        color: isAvailable ? Colors.green : Colors.red,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Departments/Specialties
              if (departments.isNotEmpty)
                Wrap(
                  spacing: 8,
                  children: departments
                      .map<Widget>((dept) => Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              dept.toString(),
                              style:
                                  TextStyle(color: Colors.blue, fontSize: 10),
                            ),
                          ))
                      .toList(),
                ),

              const SizedBox(height: 12),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _callHospital(hospital),
                      icon: const Icon(Icons.phone),
                      label: const Text('Call'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _alertHospital(hospital),
                      icon: const Icon(Icons.notification_important),
                      label: const Text('Alert'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _openHospitalDirections(hospital),
                      icon: const Icon(Icons.directions),
                      label: const Text('Directions'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _activateSOS() async {
    if (_currentPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location not available')),
      );
      return;
    }

    // Show emergency type selection dialog first
    final emergencyDetails = await _showEmergencyTypeDialog();
    if (emergencyDetails == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('🚨 Confirm SOS'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
                'Are you sure you want to send an emergency alert to nearby hospitals?'),
            const SizedBox(height: 12),
            Text('Emergency Type: ${emergencyDetails['type']}'),
            Text('Severity: ${emergencyDetails['severity']}'),
            if (emergencyDetails['description'].isNotEmpty)
              Text('Description: ${emergencyDetails['description']}'),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Send SOS'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _isLoading = true);

    try {
      // Get address components with safe defaults
      List<Placemark> placemarks = [];
      try {
        placemarks = await placemarkFromCoordinates(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
        );
      } catch (_) {}

      String city = 'Unknown City';
      String state = 'Unknown State';
      String pincode = '000000';
      if (placemarks.isNotEmpty) {
        final place = placemarks[0];
        city = (place.locality?.toString().trim().isNotEmpty == true)
            ? place.locality!.trim()
            : city;
        state = (place.administrativeArea?.toString().trim().isNotEmpty == true)
            ? place.administrativeArea!.trim()
            : state;
        pincode = (place.postalCode?.toString().trim().isNotEmpty == true)
            ? place.postalCode!.trim()
            : pincode;
      }

      // Create SOS request using new backend API
      final firebaseUid = FirebaseAuth.instance.currentUser?.uid;
      final String patientId = (firebaseUid ?? _user?.uid ?? '').isNotEmpty
          ? (firebaseUid ?? _user!.uid)
          : 'anonymous';
      // Prepare safe patient fields
      final currentUser = _user;
      final String candidateName = (currentUser?.fullName ?? '').trim();
      final String patientName =
          candidateName.isNotEmpty ? candidateName : 'Unknown';
      final String candidatePhone = (currentUser?.mobileNumber ?? '').trim();
      final String patientPhone =
          candidatePhone.isNotEmpty ? candidatePhone : 'N/A';

      final sosRequestData = {
        'patientId': patientId,
        'patientName': patientName,
        'patientPhone': patientPhone,
        'patientEmail': _user?.email ?? '',
        'patientAge': _user?.age ?? 0,
        'patientGender': _user?.gender ?? 'Unknown',
        'emergencyContact': {
          'name': _user?.emergencyContactName ?? '',
          'phone': _user?.emergencyContactNumber ?? '',
          'relation': _user?.emergencyContactRelation ?? 'Family'
        },
        'location': {
          'longitude': _currentPosition!.longitude,
          'latitude': _currentPosition!.latitude
        },
        'address': (_currentAddress.trim().isNotEmpty
                ? _currentAddress
                : 'Address not available')
            .toString(),
        'city': city,
        'state': state,
        'pincode': pincode,
        'emergencyType': emergencyDetails['type'],
        'description': emergencyDetails['description'],
        'severity': emergencyDetails['severity']
      };

      print('🚨 Creating SOS request with data: $sosRequestData');

      // Call new SOS API
      final response = await ApiService.createSOSRequest(sosRequestData);

      if (response['success'] == true) {
        setState(() {
          _sosActivated = true;
          _emergencyId = response['data']['sosRequestId'];
          _activeSosId = _emergencyId;
          _activeSosStatus = response['data']['status'] ?? 'pending';
          _sosCreatedAt = DateTime.now();

          // Get hospital count from SOS response
          _nearbyHospitalsCount = response['data']['nearbyHospitals'] ?? 0;
          print('🏥 Hospital count from SOS creation: $_nearbyHospitalsCount');
        });

        // Save SOS state to persistent storage
        await _saveSOSState();

        // Check if this is a new request or updated existing request
        final isNewRequest = response['message']?.contains('created') ?? false;
        final isUpdatedRequest =
            response['message']?.contains('updated') ?? false;

        if (isNewRequest) {
          _logSos('SOS created (ID: ${_activeSosId ?? ''})');
        } else if (isUpdatedRequest) {
          _logSos('SOS updated (ID: ${_activeSosId ?? ''})');
        } else {
          _logSos('SOS active (ID: ${_activeSosId ?? ''})');
        }

        // Send SMS to emergency contacts when SOS is activated
        _sendEmergencySMS();

        // Start SOS escalation monitoring
        _startSOSEscalationMonitoring();

        // Show simple confirmation snackbar instead of blocking dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(isNewRequest
                    ? '🚨 SOS Activated! Emergency services notified.'
                    : '🔄 SOS Updated! Emergency services notified.'),
                Text('📍 Location: $_currentAddress'),
                Text('🏥 Nearby hospitals: ${_nearbyHospitals.length}'),
                if (_nearbyHospitals.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  ...(_nearbyHospitals.take(3).map((hospital) => Text(
                      '• ${hospital['hospitalName'] ?? hospital['name'] ?? 'Hospital'}',
                      style: const TextStyle(fontSize: 12)))),
                  if (_nearbyHospitals.length > 3)
                    Text('• ... and ${_nearbyHospitals.length - 3} more',
                        style: const TextStyle(fontSize: 12)),
                ],
                const Text('📱 SMS ready to send to emergency contacts'),
                const Text(
                    'Help is on the way! Stay calm and wait for assistance.'),
              ],
            ),
            backgroundColor: Colors.green[700],
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Cancel SOS',
              textColor: Colors.white,
              onPressed: () => _cancelSOS(),
            ),
          ),
        );

        // Start monitoring for hospital acceptance
        _monitorSOSStatus();
      } else {
        // Check if this is an existing active request (idempotent)
        if (response['success'] == true &&
            response['data'] != null &&
            response['data']['sosRequestId'] != null) {
          setState(() {
            _sosActivated = true;
            _emergencyId = response['data']['sosRequestId'];
            _activeSosId = _emergencyId;
            _activeSosStatus = response['data']['status'] ?? 'pending';
          });
          _logSos('SOS active (existing) (ID: ${_activeSosId ?? ''})');
          _sendEmergencySMS();
          _monitorSOSStatus();
          return;
        }

        // Generic failure - show detailed error message
        print(
            '❌ SOS creation failed: ${response['message'] ?? 'Unknown error'}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Unable to activate SOS: ${response['message'] ?? 'Please try again.'}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      print('❌ Error activating SOS: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Error activating SOS. Please try again.')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _callEmergency() async {
    try {
      final Uri telUri = Uri.parse('tel:123');
      if (await canLaunchUrl(telUri)) {
        await launchUrl(telUri, mode: LaunchMode.externalApplication);
      } else {
        throw 'No dialer available';
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to call emergency: $e')),
      );
    }
  }

  void _showFullscreenMap() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog.fullscreen(
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Hospital Locations'),
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            leading: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.of(context).pop(),
            ),
            actions: [
              // Add external map link for web
              if (kIsWeb && _currentPosition != null)
                IconButton(
                  icon: const Icon(Icons.open_in_new),
                  onPressed: () {
                    final mapsUrl =
                        'https://www.google.com/maps/search/?api=1&query=${_currentPosition!.latitude},${_currentPosition!.longitude}';
                    launchUrl(Uri.parse(mapsUrl),
                        mode: LaunchMode.externalApplication);
                  },
                  tooltip: 'Open in Google Maps',
                ),
            ],
          ),
          body: _currentPosition != null
              ? GoogleMap(
                  onMapCreated: (GoogleMapController controller) {
                    // Map controller for future use
                  },
                  initialCameraPosition: CameraPosition(
                    target: LatLng(_currentPosition!.latitude,
                        _currentPosition!.longitude),
                    zoom: 13.0,
                  ),
                  markers: {..._userMarker, ..._hospitalMarkers},
                  myLocationEnabled:
                      !kIsWeb, // Disable on web for better performance
                  myLocationButtonEnabled:
                      !kIsWeb, // Disable on web for better performance
                  mapType: MapType.normal,
                  // Web-specific optimizations
                  zoomControlsEnabled: !kIsWeb, // Disable zoom controls on web
                  mapToolbarEnabled: !kIsWeb, // Disable toolbar on web
                )
              : const Center(
                  child: Text('Location not available'),
                ),
        ),
      ),
    );
  }

  void _sendEmergencySMS() async {
    // SMS compose is not supported on web; skip gracefully
    if (kIsWeb) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'SMS sending not supported in web browser. Test on a device.'),
          ),
        );
      }
      return;
    }
    try {
      String message = '🚨 EMERGENCY ALERT 🚨\n\n';
      message += 'I need immediate medical assistance!\n\n';

      if (_currentPosition != null) {
        message += '📍 LOCATION COORDINATES:\n';
        message += 'Latitude: ${_currentPosition!.latitude}\n';
        message += 'Longitude: ${_currentPosition!.longitude}\n\n';
        message += '📍 ADDRESS: $_currentAddress\n\n';
        // Add Google Maps link for quick navigation
        final mapsUrl =
            'https://www.google.com/maps/search/?api=1&query=${_currentPosition!.latitude},${_currentPosition!.longitude}';
        message += '🗺️ Map: $mapsUrl\n\n';
      }

      message += '⏰ Time: ${DateTime.now().toString()}\n';
      message += '👤 Patient: ${_user?.fullName ?? 'Unknown'}\n';
      message += '📞 Contact: ${_user?.mobileNumber ?? 'Unknown'}\n';

      // Add emergency contact info if available
      if ((_user?.emergencyContactName != null &&
              _user!.emergencyContactName!.isNotEmpty) ||
          (_user?.emergencyContactNumber != null &&
              _user!.emergencyContactNumber!.isNotEmpty)) {
        final String ecName =
            _user?.emergencyContactName?.trim() ?? 'Emergency Contact';
        final String ecRel =
            _user?.emergencyContactRelation?.trim().isNotEmpty == true
                ? _user!.emergencyContactRelation!.trim()
                : 'Family/Friend';
        final String ecPhone = _user?.emergencyContactNumber?.trim() ?? '';
        message += '👥 Emergency Contact: $ecName ($ecRel)';
        if (ecPhone.isNotEmpty) {
          message += '\n📞 Emergency Contact Phone: $ecPhone';
        }
        message += '\n';
      }

      message += '\nPlease send help immediately!';

      print('📱 Preparing to send emergency SMS...');
      print('📱 Message: $message');
      // Ask user who to send to (contact or 123)
      final choice = await showModalBottomSheet<String>(
        context: context,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (ctx) {
          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.contacts, color: Colors.orange),
                  title: const Text('Send to emergency contact'),
                  subtitle: Text(_user?.emergencyContactName ?? 'Contact'),
                  onTap: () => Navigator.pop(ctx, 'contact'),
                ),
                ListTile(
                  leading: const Icon(Icons.policy, color: Colors.red),
                  title: const Text('Send to test number (123)'),
                  onTap: () => Navigator.pop(ctx, 'test'),
                ),
                const SizedBox(height: 8),
              ],
            ),
          );
        },
      );

      if (choice == null) return;

      bool launched = false;
      final targets = choice == 'contact'
          ? [
              if (_user?.emergencyContactNumber != null &&
                  _user!.emergencyContactNumber!.isNotEmpty)
                _user!.emergencyContactNumber!
            ]
          : [kTestEmergencyNumber];

      for (final contact in targets) {
        try {
          await _sendSMS(contact, message);
          launched = true;
          break;
        } catch (_) {}
      }

      if (!launched) {
        await Share.share(message, subject: 'Emergency SOS');
        launched = true;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(launched
                ? 'Opened app chooser with emergency details'
                : 'Could not open any app.'),
            backgroundColor: launched ? Colors.green : Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      print('❌ Error sending emergency SMS: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send SMS: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _sendSMS(String phoneNumber, String message) async {
    try {
      // Prefer explicit chooser via url_launcher on Android by using smsto:
      if (!kIsWeb && Platform.isAndroid) {
        final Uri chooserUri = Uri.parse(
            'smsto:$phoneNumber?body=${Uri.encodeComponent(message)}');
        final bool can = await canLaunchUrl(chooserUri);
        if (can) {
          await launchUrl(chooserUri, mode: LaunchMode.externalApplication);
          return;
        }
      }

      // Build candidates using structured URI to avoid encoding issues
      final String encodedBody = Uri.encodeComponent(message);

      final List<Uri> candidates = [
        // Android preferred
        if (Platform.isAndroid)
          Uri.parse('smsto:$phoneNumber?body=$encodedBody'),
        if (Platform.isAndroid) Uri.parse('sms:$phoneNumber?body=$encodedBody'),
        // iOS often ignores body parameter, but we still try
        if (!Platform.isAndroid)
          Uri.parse('sms:$phoneNumber&body=$encodedBody'),
        // No body fallback for strict OEMs
        Uri.parse('sms:$phoneNumber'),
        Uri.parse('smsto:$phoneNumber'),
      ];

      bool launched = false;
      for (final uri in candidates) {
        if (await canLaunchUrl(uri)) {
          if (await launchUrl(uri, mode: LaunchMode.externalApplication)) {
            launched = true;
            break;
          }
          if (await launchUrl(uri, mode: LaunchMode.platformDefault)) {
            launched = true;
            break;
          }
        }
      }

      if (!launched) {
        // Do not fallback to dialer; rely on Share chooser above
        throw Exception('No SMS handler available');
      }
    } catch (e) {
      print('❌ Error sending SMS to $phoneNumber: $e');
      throw e;
    }
  }

  Future<void> _sendHospitalAcceptanceSMS(
      String hospitalName, String hospitalPhone) async {
    try {
      String message = '✅ EMERGENCY UPDATE ✅\n\n';
      message +=
          'Good news! A hospital has accepted your emergency request.\n\n';
      message += '🏥 Hospital: $hospitalName\n';
      message += '📞 Hospital Contact: $hospitalPhone\n\n';

      if (_currentPosition != null) {
        message += '📍 Your Location:\n';
        message += 'Latitude: ${_currentPosition!.latitude}\n';
        message += 'Longitude: ${_currentPosition!.longitude}\n';
        message += 'Address: $_currentAddress\n';
        final mapsUrl =
            'https://www.google.com/maps/search/?api=1&query=${_currentPosition!.latitude},${_currentPosition!.longitude}';
        message += '🗺️ Map: $mapsUrl\n\n';
      }

      message += '⏰ Time: ${DateTime.now().toString()}\n\n';
      message += 'Help is on the way! Stay calm and wait for the ambulance.';

      // Send SMS to emergency contacts
      for (String contact in _emergencyContacts) {
        await _sendSMS(contact, message);
      }

      print('✅ Hospital acceptance SMS sent to emergency contacts');
    } catch (e) {
      print('❌ Error sending hospital acceptance SMS: $e');
    }
  }

  // Monitor SOS status for updates
  void _monitorSOSStatus() {
    if (_emergencyId == null) return;

    // Poll every 5 seconds for status updates
    Timer.periodic(const Duration(seconds: 5), (timer) async {
      if (!mounted || !_sosActivated) {
        timer.cancel();
        return;
      }

      try {
        final response = await ApiService.getSOSRequestStatus(_emergencyId!);
        if (response['success'] == true) {
          final status = response['data']['status'];

          if (status == 'accepted') {
            timer.cancel();
            _handleHospitalAcceptance(response['data']);
          } else if (status == 'timeout') {
            timer.cancel();
            _handleSOSTimeout();
          } else if (status == 'admitted') {
            timer.cancel();
            _handlePatientAdmission(response['data']);
          }
        }
      } catch (e) {
        print('❌ Error monitoring SOS status: $e');
      }
    });
  }

  // Handle hospital acceptance
  void _handleHospitalAcceptance(Map<String, dynamic> sosData) {
    if (!mounted) return;

    print('🏥 Hospital acceptance data received:');
    print('🔍 Full SOS data: $sosData');
    print('🔍 acceptedBy: ${sosData['acceptedBy']}');

    // Try different ways to extract hospital name and ID
    String hospitalName = 'Hospital';
    String hospitalPhone = '000';
    String? acceptedHospitalId;

    if (sosData['acceptedBy'] != null) {
      final acceptedBy = sosData['acceptedBy'];

      // Extract hospital ID
      acceptedHospitalId = acceptedBy['hospitalId']?.toString();

      // Try different hospital name fields
      hospitalName = acceptedBy['hospitalName'] ??
          acceptedBy['name'] ??
          acceptedBy['hospital'] ??
          'Hospital';

      // Try different phone fields
      if (acceptedBy['acceptedByStaff'] != null) {
        final staff = acceptedBy['acceptedByStaff'];
        hospitalPhone = staff['phone'] ??
            staff['mobileNumber'] ??
            staff['contact'] ??
            '000';
      }
    }

    // Fallback: try to get hospital name from other fields
    if (hospitalName == 'Hospital') {
      hospitalName = sosData['hospitalName'] ??
          sosData['acceptedHospitalName'] ??
          'Hospital';
    }

    print('🏥 Extracted hospital name: $hospitalName');
    print('🏥 Extracted hospital phone: $hospitalPhone');

    // Update SOS status to accepted
    setState(() {
      _activeSosStatus = 'accepted';
      _acceptedHospitalName = hospitalName;
      _acceptedHospitalPhone = hospitalPhone;
      _acceptedHospitalId = acceptedHospitalId;
      _sosAcceptedAt = DateTime.now();
    });

    // Save updated SOS state to persistent storage
    _saveSOSState();

    // Stop SOS escalation monitoring when hospital accepts
    _stopSOSEscalationMonitoring();

    // Send SMS notification about hospital acceptance
    _sendHospitalAcceptanceSMS(hospitalName, hospitalPhone);

    // Show notification to user
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✅ $hospitalName has accepted your emergency request!'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 5),
      ),
    );
    _logSos('Accepted by $hospitalName (${hospitalPhone.toString()})');
  }

  // Handle SOS timeout
  void _handleSOSTimeout() {
    if (!mounted) return;

    setState(() {
      _sosActivated = false;
      _emergencyId = null;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
            '⏰ SOS request timed out. Please try again or call emergency services directly.'),
        backgroundColor: Colors.orange,
        duration: Duration(seconds: 5),
      ),
    );
    _logSos('SOS timed out');
  }

  // Handle patient admission
  Future<void> _handlePatientAdmission(Map<String, dynamic> sosData) async {
    if (!mounted) return;

    final hospitalName = sosData['acceptedBy']['hospitalName'] ?? 'Hospital';
    final wardNumber = sosData['admissionDetails']['wardNumber'] ?? '';
    final bedNumber = sosData['admissionDetails']['bedNumber'] ?? '';

    setState(() {
      _sosActivated = false;
      _emergencyId = null;
      _activeSosId = null;
      _activeSosStatus = 'admitted';
      _isDischarged = true; // User is admitted, SOS should be disabled
    });

    // Save admission state to persistent storage
    await _saveSOSState();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            '🏥 You have been admitted to $hospitalName${wardNumber.isNotEmpty ? ' - Ward: $wardNumber, Bed: $bedNumber' : ''}'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 5),
      ),
    );
    _logSos(
        'Admitted to $hospitalName${wardNumber.isNotEmpty ? ' - Ward: $wardNumber, Bed: $bedNumber' : ''}');
  }

  // Confirm admission (user confirms they reached hospital)
  // Show hospital reached dialog
  Future<void> _showHospitalReachedDialog() async {
    final doctorIdController = TextEditingController();
    bool includeDoctorId = false;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('🏥 ${_acceptedHospitalName ?? 'Hospital'} Reached'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${_acceptedHospitalName ?? 'Hospital'} staff has reached your location. Please confirm:',
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: TextEditingController(
                    text: _acceptedHospitalId ?? 'Hospital ID not available'),
                decoration: const InputDecoration(
                  labelText: 'Hospital ID',
                  border: OutlineInputBorder(),
                ),
                enabled: false,
              ),
              const SizedBox(height: 16),
              CheckboxListTile(
                title: const Text('Include Doctor ARC ID'),
                subtitle: const Text('Optional - if doctor is present'),
                value: includeDoctorId,
                onChanged: (value) {
                  setState(() {
                    includeDoctorId = value ?? false;
                  });
                },
              ),
              if (includeDoctorId) ...[
                const SizedBox(height: 8),
                TextField(
                  controller: doctorIdController,
                  decoration: const InputDecoration(
                    labelText: 'Doctor ARC ID',
                    border: OutlineInputBorder(),
                    hintText: 'Enter doctor ARC ID (optional)',
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (_acceptedHospitalId != null) {
                  Navigator.pop(context);
                  _confirmHospitalReached(_acceptedHospitalId!,
                      includeDoctorId ? doctorIdController.text.trim() : null);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content:
                          Text('Hospital ID not available. Please try again.'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              child: const Text('Confirm Reached'),
            ),
          ],
        ),
      ),
    );
  }

  // Confirm hospital reached
  Future<void> _confirmHospitalReached(
      String hospitalId, String? doctorId) async {
    if (_emergencyId == null) return;

    try {
      final response = await ApiService.confirmHospitalReached(
        _emergencyId!,
        hospitalId,
        doctorId,
      );

      if (response['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Hospital reached confirmed!'),
            backgroundColor: Colors.orange,
          ),
        );
        _logSos(
            'Hospital reached - Hospital ID: $hospitalId${doctorId != null ? ', Doctor ID: $doctorId' : ''}');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Failed to confirm hospital reached: ${response['message']}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print('❌ Error confirming hospital reached: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to confirm hospital reached'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Show cancel SOS dialog with hospital details
  Future<void> _showCancelSOSDialog() async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('🚨 Cancel SOS Request'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Are you sure you want to cancel this SOS request?',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Current Status:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text('✅ Hospital has accepted your request'),
                  const SizedBox(height: 4),
                  Text('📞 Hospital staff is on the way'),
                  const SizedBox(height: 4),
                  Text('🚑 Emergency services are responding'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'If you cancel now, the hospital will be notified that you no longer need assistance.',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Keep SOS Active'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _cancelSOS();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Cancel SOS'),
          ),
        ],
      ),
    );
  }

  // Cancel SOS request
  Future<void> _cancelSOS() async {
    if (_emergencyId == null) return;

    try {
      final response = await ApiService.cancelSOSRequest(_emergencyId!);
      if (response['success'] == true) {
        setState(() {
          _sosActivated = false;
          _emergencyId = null;
          _activeSosStatus = 'cancelled';
          // Clear active summary so user can immediately activate again without confusion
          _activeSosId = null;
          _escalationTriggered = false;
          _emergencyCallsTriggered = [];
          _retryCount = 0;
        });

        // Clear SOS state from persistent storage
        await _clearSOSState();

        // Stop SOS escalation monitoring
        _stopSOSEscalationMonitoring();

        // Refresh hospitals after cancel to keep list/map up to date
        _loadNearbyHospitals();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('SOS request cancelled successfully'),
            backgroundColor: Colors.orange,
          ),
        );
        _logSos('SOS cancelled');
      } else {
        // Even if backend cancel fails, clear frontend state to allow retry
        setState(() {
          _sosActivated = false;
          _emergencyId = null;
          _activeSosStatus = 'cancelled';
          _activeSosId = null;
          _escalationTriggered = false;
          _emergencyCallsTriggered = [];
          _retryCount = 0;
        });

        // Clear SOS state from persistent storage
        await _clearSOSState();

        // Stop SOS escalation monitoring
        _stopSOSEscalationMonitoring();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('SOS cancelled locally. ${response['message'] ?? ''}'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      print('❌ Error cancelling SOS: $e');

      // Even if cancel fails, clear frontend state to allow retry
      setState(() {
        _sosActivated = false;
        _emergencyId = null;
        _activeSosStatus = 'cancelled';
        _activeSosId = null;
      });

      // Clear SOS state from persistent storage
      await _clearSOSState();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('SOS cancelled locally. You can now create a new SOS.'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  void _callHospital(Map<String, dynamic> hospital) async {
    try {
      final phone = hospital['mobileNumber'] ?? hospital['phone'];
      if (phone != null) {
        final Uri telUri = Uri.parse('tel:$phone');
        if (await canLaunchUrl(telUri)) {
          await launchUrl(telUri, mode: LaunchMode.externalApplication);
        } else {
          throw 'No dialer available';
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Phone number not available for this hospital')),
        );
      }
    } catch (e) {
      final hospitalName =
          hospital['hospitalName'] ?? hospital['name'] ?? 'Hospital';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to call $hospitalName: $e')),
      );
    }
  }

  // Alert specific hospital
  Future<void> _alertHospital(Map<String, dynamic> hospital) async {
    try {
      final hospitalName =
          hospital['hospitalName'] ?? hospital['name'] ?? 'Hospital';
      final hospitalId = hospital['_id'] ?? hospital['id'];

      if (hospitalId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Hospital ID not found'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Show confirmation dialog
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('🚨 Send Alert to Hospital'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Send emergency alert to:'),
              const SizedBox(height: 8),
              Text(
                hospitalName,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              Text('Address: ${hospital['address'] ?? 'Not available'}'),
              Text(
                  'Phone: ${hospital['mobileNumber'] ?? hospital['phone'] ?? 'Not available'}'),
              const SizedBox(height: 12),
              const Text(
                'This will send a direct alert to this specific hospital about your emergency.',
                style: TextStyle(fontSize: 14),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Send Alert'),
            ),
          ],
        ),
      );

      if (confirm != true) return;

      // Send alert to specific hospital
      final alertData = {
        'hospitalId': hospitalId,
        'hospitalName': hospitalName,
        'patientId': _user?.uid,
        'patientName': _user?.fullName ?? 'Unknown Patient',
        'patientPhone': _user?.mobileNumber ?? 'Unknown',
        'location': {
          'latitude': _currentPosition?.latitude,
          'longitude': _currentPosition?.longitude,
        },
        'address': _currentAddress,
        'alertType': 'direct_hospital_alert',
        'timestamp': DateTime.now().toIso8601String(),
      };

      // Call API to send alert to specific hospital
      final response = await ApiService.sendHospitalAlert(alertData);

      if (response['success'] == true) {
        // Log the alert in SOS activity
        _logSos('Alert sent to $hospitalName');

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Alert sent to $hospitalName'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      } else {
        throw Exception(response['message'] ?? 'Failed to send alert');
      }
    } catch (e) {
      print('❌ Error sending hospital alert: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Failed to send alert: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<Map<String, dynamic>?> _showEmergencyTypeDialog() async {
    String selectedType = _selectedEmergencyType;
    String selectedSeverity = _selectedSeverity;
    final descriptionController = TextEditingController();

    return await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('🚨 Emergency Details'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Emergency Type:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: selectedType,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: [
                    'Medical',
                    'Accident',
                    'Cardiac',
                    'Respiratory',
                    'Trauma',
                    'Stroke',
                    'Seizure',
                    'Allergic Reaction',
                    'Poisoning',
                    'Burn',
                    'Drowning',
                    'Other'
                  ]
                      .map((type) => DropdownMenuItem(
                            value: type,
                            child: Text(type),
                          ))
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      selectedType = value!;
                    });
                  },
                ),
                const SizedBox(height: 16),
                const Text('Severity:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: selectedSeverity,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: ['Low', 'Medium', 'High', 'Critical']
                      .map((severity) => DropdownMenuItem(
                            value: severity,
                            child: Text(severity),
                          ))
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      selectedSeverity = value!;
                    });
                  },
                ),
                const SizedBox(height: 16),
                const Text('Additional Details (Optional):',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'Describe the emergency situation...',
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  maxLines: 3,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context, {
                  'type': selectedType,
                  'severity': selectedSeverity,
                  'description': descriptionController.text.trim(),
                });
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Continue'),
            ),
          ],
        ),
      ),
    );
  }
}
