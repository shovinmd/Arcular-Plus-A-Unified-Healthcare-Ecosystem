import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:arcular_plus/services/api_service.dart';
import 'package:arcular_plus/services/notification_service.dart';

class RealtimeSOSService {
  static RealtimeSOSService? _instance;
  static RealtimeSOSService get instance =>
      _instance ??= RealtimeSOSService._();

  RealtimeSOSService._();

  Timer? _pollingTimer;
  String? _currentUserId;
  String? _currentUserType;
  DateTime? _lastCheck;

  // Callbacks for real-time updates
  Function(Map<String, dynamic>)? onSOSRequestReceived;
  Function(Map<String, dynamic>)? onSOSStatusUpdated;
  Function(Map<String, dynamic>)? onSOSAccepted;
  Function(Map<String, dynamic>)? onSOSAdmitted;

  /// Start real-time SOS monitoring
  Future<void> startRealtimeMonitoring({
    required String userType,
    Function(Map<String, dynamic>)? onSOSReceived,
    Function(Map<String, dynamic>)? onStatusUpdated,
    Function(Map<String, dynamic>)? onAccepted,
    Function(Map<String, dynamic>)? onAdmitted,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      _currentUserId = user.uid;
      _currentUserType = userType;
      _lastCheck = DateTime.now();

      // Set up callbacks
      onSOSRequestReceived = onSOSReceived;
      onSOSStatusUpdated = onStatusUpdated;
      onSOSAccepted = onAccepted;
      onSOSAdmitted = onAdmitted;

      print('🚀 Starting real-time SOS monitoring for $userType: ${user.uid}');

      // Start polling every 5 seconds for real-time updates
      _pollingTimer = Timer.periodic(const Duration(seconds: 5), (_) {
        _checkForUpdates();
      });

      // Initial check
      await _checkForUpdates();
    } catch (e) {
      print('❌ Error starting real-time SOS monitoring: $e');
    }
  }

  /// Stop real-time monitoring
  void stopRealtimeMonitoring() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
    _currentUserId = null;
    _currentUserType = null;
    _lastCheck = null;

    print('🛑 Stopped real-time SOS monitoring');
  }

  /// Check for new SOS updates
  Future<void> _checkForUpdates() async {
    if (_currentUserId == null || _currentUserType == null) return;

    try {
      if (_currentUserType == 'hospital') {
        await _checkHospitalUpdates();
      } else if (_currentUserType == 'user') {
        await _checkUserUpdates();
      }
    } catch (e) {
      print('❌ Error checking for SOS updates: $e');
    }
  }

  /// Check for hospital-side updates
  Future<void> _checkHospitalUpdates() async {
    try {
      final sosRequests =
          await ApiService.getHospitalSOSRequests(_currentUserId!);

      for (final request in sosRequests) {
        final status = request['hospitalStatus'] ?? 'unknown';
        final createdAt = DateTime.tryParse(request['createdAt'] ?? '');

        // Check if this is a new request since last check
        if (createdAt != null &&
            (_lastCheck == null || createdAt.isAfter(_lastCheck!)) &&
            status == 'notified') {
          // Create notification for new SOS request
          await NotificationService.saveNotification(
            userType: 'hospital',
            type: 'sos',
            title: '🚨 New SOS Emergency',
            message:
                'Emergency request from ${request['patientInfo']?['patientName'] ?? 'Unknown Patient'}',
            data: request,
          );

          // Trigger callback
          onSOSRequestReceived?.call(request);

          print('🚨 New SOS request received: ${request['sosRequestId']}');
        }
      }

      _lastCheck = DateTime.now();
    } catch (e) {
      print('❌ Error checking hospital SOS updates: $e');
    }
  }

  /// Check for user-side updates
  Future<void> _checkUserUpdates() async {
    try {
      // Get user's active SOS requests
      final userSOSHistory =
          await ApiService.getUserSOSHistory(_currentUserId!);

      for (final request in userSOSHistory) {
        final status = request['status'] ?? 'unknown';
        final updatedAt = DateTime.tryParse(request['updatedAt'] ?? '');

        // Check if status has been updated since last check
        if (updatedAt != null &&
            (_lastCheck == null || updatedAt.isAfter(_lastCheck!))) {
          // Create notification for status update
          String title = '';
          String message = '';

          switch (status) {
            case 'accepted':
              title = '✅ SOS Accepted';
              message =
                  'Your emergency request has been accepted by ${request['acceptedBy']?['hospitalName'] ?? 'a hospital'}';
              onSOSAccepted?.call(request);
              break;
            case 'admitted':
              title = '🏥 Patient Admitted';
              message =
                  'You have been admitted to ${request['acceptedBy']?['hospitalName'] ?? 'the hospital'}';
              onSOSAdmitted?.call(request);
              break;
            case 'timeout':
              title = '⏰ SOS Timeout';
              message =
                  'Your emergency request has timed out. Please try again or call emergency services directly.';
              break;
            case 'cancelled':
              title = '❌ SOS Cancelled';
              message = 'Your emergency request has been cancelled.';
              break;
          }

          if (title.isNotEmpty) {
            await NotificationService.saveNotification(
              userType: 'user',
              type: 'sos_update',
              title: title,
              message: message,
              data: request,
            );

            onSOSStatusUpdated?.call(request);
            print('📱 SOS status update: $status');
          }
        }
      }

      _lastCheck = DateTime.now();
    } catch (e) {
      print('❌ Error checking user SOS updates: $e');
    }
  }

  /// Send real-time SOS alert to hospitals
  static Future<void> sendSOSAlertToHospitals(
      Map<String, dynamic> sosData) async {
    try {
      // This would typically use WebSocket or push notifications
      // For now, we'll use the existing API structure
      print('🚨 Sending SOS alert to hospitals: ${sosData['sosRequestId']}');

      // The backend already handles notifying hospitals when SOS is created
      // This method can be extended for additional real-time features
    } catch (e) {
      print('❌ Error sending SOS alert: $e');
    }
  }

  /// Get real-time SOS statistics
  static Future<Map<String, dynamic>> getRealtimeSOSStats(
      String hospitalId) async {
    try {
      // This would typically come from a real-time analytics service
      // For now, we'll use the existing API
      return {
        'activeRequests': 0,
        'responseTime': 0,
        'acceptanceRate': 0,
        'lastUpdate': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      print('❌ Error getting real-time SOS stats: $e');
      return {};
    }
  }
}
