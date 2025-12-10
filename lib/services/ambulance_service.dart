import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';

class AmbulanceService {
  static AmbulanceService? _instance;
  static AmbulanceService get instance => _instance ??= AmbulanceService._();

  AmbulanceService._();

  /// Dispatch ambulance for SOS request
  static Future<Map<String, dynamic>> dispatchAmbulance({
    required String sosRequestId,
    required String hospitalId,
    required Map<String, dynamic> patientLocation,
    required String emergencyType,
    required String severity,
    String? notes,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        return {'success': false, 'message': 'User not authenticated'};
      }

      final ambulanceData = {
        'sosRequestId': sosRequestId,
        'hospitalId': hospitalId,
        'patientLocation': patientLocation,
        'emergencyType': emergencyType,
        'severity': severity,
        'notes': notes ?? '',
        'dispatchedAt': DateTime.now().toIso8601String(),
        'estimatedArrival':
            _calculateEstimatedArrival(patientLocation, hospitalId),
      };

      // For now, we'll simulate ambulance dispatch
      // In a real implementation, this would integrate with ambulance services
      print('🚑 Dispatching ambulance for SOS: $sosRequestId');
      print('🚑 Ambulance data: $ambulanceData');

      // Simulate API call
      await Future.delayed(const Duration(seconds: 1));

      return {
        'success': true,
        'message': 'Ambulance dispatched successfully',
        'data': {
          'ambulanceId': 'AMB-${DateTime.now().millisecondsSinceEpoch}',
          'estimatedArrival': ambulanceData['estimatedArrival'],
          'status': 'dispatched',
          'trackingNumber': 'TRK-${DateTime.now().millisecondsSinceEpoch}',
        }
      };
    } catch (e) {
      print('❌ Error dispatching ambulance: $e');
      return {'success': false, 'message': 'Failed to dispatch ambulance: $e'};
    }
  }

  /// Calculate estimated arrival time
  static String _calculateEstimatedArrival(
      Map<String, dynamic> patientLocation, String hospitalId) {
    // This would typically use real-time traffic data and distance calculation
    // For now, we'll use a simple estimation based on distance
    final distance = _calculateDistance(patientLocation);

    // Assume average ambulance speed of 60 km/h in city, 80 km/h on highway
    final avgSpeed = distance > 10 ? 80 : 60; // km/h
    final estimatedMinutes = (distance / avgSpeed * 60).round();

    final arrivalTime = DateTime.now().add(Duration(minutes: estimatedMinutes));
    return arrivalTime.toIso8601String();
  }

  /// Calculate distance between patient and hospital
  static double _calculateDistance(Map<String, dynamic> patientLocation) {
    // This would typically use the hospital's location
    // For now, we'll return a random distance between 2-15 km
    return 2 + (DateTime.now().millisecondsSinceEpoch % 13);
  }

  /// Track ambulance status
  static Future<Map<String, dynamic>> trackAmbulance(String ambulanceId) async {
    try {
      // Simulate ambulance tracking
      await Future.delayed(const Duration(seconds: 1));

      return {
        'success': true,
        'data': {
          'ambulanceId': ambulanceId,
          'status': 'en_route',
          'currentLocation': {
            'latitude':
                20.5937 + (DateTime.now().millisecondsSinceEpoch % 100) / 10000,
            'longitude':
                78.9629 + (DateTime.now().millisecondsSinceEpoch % 100) / 10000,
          },
          'estimatedArrival':
              DateTime.now().add(const Duration(minutes: 8)).toIso8601String(),
          'driverName':
              'Driver ${DateTime.now().millisecondsSinceEpoch % 1000}',
          'driverPhone':
              '+91${9000000000 + (DateTime.now().millisecondsSinceEpoch % 1000000000)}',
          'ambulanceNumber':
              'AMB-${DateTime.now().millisecondsSinceEpoch % 10000}',
        }
      };
    } catch (e) {
      print('❌ Error tracking ambulance: $e');
      return {'success': false, 'message': 'Failed to track ambulance: $e'};
    }
  }

  /// Get nearby ambulances
  static Future<List<Map<String, dynamic>>> getNearbyAmbulances({
    required double latitude,
    required double longitude,
    double radius = 10.0,
  }) async {
    try {
      // Simulate getting nearby ambulances
      await Future.delayed(const Duration(milliseconds: 500));

      final ambulances = List.generate(
          3,
          (index) => {
                'ambulanceId':
                    'AMB-${DateTime.now().millisecondsSinceEpoch + index}',
                'driverName': 'Driver ${index + 1}',
                'driverPhone': '+91${9000000000 + index}',
                'ambulanceNumber': 'AMB-${1000 + index}',
                'status': index == 0 ? 'available' : 'busy',
                'distance': '${2 + index * 2} km',
                'estimatedArrival': '${5 + index * 3} minutes',
                'specialization': index == 0
                    ? 'General'
                    : index == 1
                        ? 'Cardiac'
                        : 'Trauma',
                'rating': 4.5 + (index * 0.2),
              });

      return ambulances;
    } catch (e) {
      print('❌ Error getting nearby ambulances: $e');
      return [];
    }
  }

  /// Cancel ambulance dispatch
  static Future<Map<String, dynamic>> cancelAmbulanceDispatch(
      String ambulanceId) async {
    try {
      // Simulate canceling ambulance dispatch
      await Future.delayed(const Duration(milliseconds: 500));

      print('🚑 Canceling ambulance dispatch: $ambulanceId');

      return {
        'success': true,
        'message': 'Ambulance dispatch cancelled successfully',
        'data': {
          'ambulanceId': ambulanceId,
          'status': 'cancelled',
          'cancelledAt': DateTime.now().toIso8601String(),
        }
      };
    } catch (e) {
      print('❌ Error cancelling ambulance dispatch: $e');
      return {
        'success': false,
        'message': 'Failed to cancel ambulance dispatch: $e'
      };
    }
  }

  /// Get ambulance dispatch history
  static Future<List<Map<String, dynamic>>> getAmbulanceHistory(
      String userId) async {
    try {
      // Simulate getting ambulance history
      await Future.delayed(const Duration(milliseconds: 500));

      return [
        {
          'ambulanceId': 'AMB-${DateTime.now().millisecondsSinceEpoch - 1000}',
          'dispatchDate': DateTime.now()
              .subtract(const Duration(days: 1))
              .toIso8601String(),
          'status': 'completed',
          'emergencyType': 'Medical',
          'hospitalName': 'City General Hospital',
          'rating': 4.5,
        },
        {
          'ambulanceId': 'AMB-${DateTime.now().millisecondsSinceEpoch - 2000}',
          'dispatchDate': DateTime.now()
              .subtract(const Duration(days: 7))
              .toIso8601String(),
          'status': 'completed',
          'emergencyType': 'Accident',
          'hospitalName': 'Metropolitan Medical Center',
          'rating': 4.8,
        },
      ];
    } catch (e) {
      print('❌ Error getting ambulance history: $e');
      return [];
    }
  }
}
