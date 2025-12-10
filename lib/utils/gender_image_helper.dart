import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GenderImageHelper {
  /// Get gender-based profile image based on user type and gender
  static Future<String?> getGenderBasedImage(String userType) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final gender = prefs.getString('user_gender') ?? 'Female';

      // Return the appropriate image path based on gender and user type
      if (gender == 'Male') {
        switch (userType) {
          case 'doctor':
            return 'assets/images/Male/doc/happy.png';
          case 'hospital':
            return 'assets/images/Male/hosp/happy.png';
          case 'lab':
            return 'assets/images/Male/lab/happy.png';
          case 'nurse':
            return 'assets/images/Male/nurs/happy.png';
          case 'pharmacy':
            return 'assets/images/Male/pharm/happy.png';
          case 'patient':
            return 'assets/images/Male/pat/happy.png';
          default:
            return 'assets/images/Male/pat/happy.png';
        }
      } else {
        switch (userType) {
          case 'doctor':
            return 'assets/images/Female/doc/happy.png';
          case 'hospital':
            return 'assets/images/Female/hosp/happy.png';
          case 'lab':
            return 'assets/images/Female/lab/happy.png';
          case 'nurse':
            return 'assets/images/Female/nurs/happy.png';
          case 'pharmacy':
            return 'assets/images/Female/pharm/happy.png';
          case 'patient':
            return 'assets/images/Female/pat/happy.png';
          default:
            return 'assets/images/Female/pat/happy.png';
        }
      }
    } catch (e) {
      print('Error getting gender-based image: $e');
      return null;
    }
  }

  /// Get gender-based profile image widget
  static Future<Widget> getGenderBasedImageWidget(String userType,
      {double size = 50}) async {
    final imagePath = await getGenderBasedImage(userType);

    if (imagePath != null) {
      return Image.asset(
        imagePath,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Icon(
            _getDefaultIcon(userType),
            size: size,
            color: Colors.white,
          );
        },
      );
    } else {
      return Icon(
        _getDefaultIcon(userType),
        size: size,
        color: Colors.white,
      );
    }
  }

  /// Get default icon for user type
  static IconData _getDefaultIcon(String userType) {
    switch (userType) {
      case 'doctor':
        return Icons.medical_services;
      case 'hospital':
        return Icons.local_hospital;
      case 'lab':
        return Icons.science;
      case 'nurse':
        return Icons.person;
      case 'pharmacy':
        return Icons.local_pharmacy;
      case 'patient':
        return Icons.person;
      default:
        return Icons.person;
    }
  }
}
