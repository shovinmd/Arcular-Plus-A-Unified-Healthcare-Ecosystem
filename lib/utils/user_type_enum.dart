import 'package:flutter/material.dart';

enum UserType {
  patient,
  doctor,
  hospital,
  nurse,
  lab,
  pharmacy,
}

extension UserTypeExtension on UserType {
  String get displayName {
    switch (this) {
      case UserType.patient:
        return "Patient";
      case UserType.doctor:
        return "Doctor";
      case UserType.hospital:
        return "Hospital";
      case UserType.nurse:
        return "Nurse";
      case UserType.lab:
        return "Lab";
      case UserType.pharmacy:
        return "Pharmacy";
    }
  }

  String get value {
    switch (this) {
      case UserType.patient:
        return 'patient';
      case UserType.doctor:
        return 'doctor';
      case UserType.hospital:
        return 'hospital';
      case UserType.nurse:
        return 'nurse';
      case UserType.lab:
        return 'lab';
      case UserType.pharmacy:
        return 'pharmacy';
    }
  }

  IconData get icon {
    switch (this) {
      case UserType.patient:
        return Icons.person;
      case UserType.doctor:
        return Icons.medical_services;
      case UserType.hospital:
        return Icons.local_hospital;
      case UserType.nurse:
        return Icons.medical_services;
      case UserType.lab:
        return Icons.science;
      case UserType.pharmacy:
        return Icons.local_pharmacy;
    }
  }

  Color get color {
    switch (this) {
      case UserType.patient:
        return Colors.blue;
      case UserType.doctor:
        return Colors.green;
      case UserType.hospital:
        return Colors.red;
      case UserType.nurse:
        return Colors.teal;
      case UserType.lab:
        return Colors.purple;
      case UserType.pharmacy:
        return Colors.orange;
    }
  }
} 