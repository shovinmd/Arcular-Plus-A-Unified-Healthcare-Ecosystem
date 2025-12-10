import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../screens/user/dashboard_user.dart';
import '../screens/hospital/dashboard_hospital.dart';
import '../screens/doctor/dashboard_doctor.dart';
import '../screens/nurse/dashboard_nurse.dart';
import '../screens/lab/dashboard_lab.dart';
import '../screens/pharmacy/dashboard_pharmacy.dart';
import '../screens/admin/admin_dashboard_screen.dart';
import '../screens/arcstaff/arcstaff_dashboard_screen.dart';
import '../screens/auth/approval_pending_screen.dart';

class DashboardNavigationService {
  /// Navigate to appropriate dashboard based on user type
  static Future<void> navigateToDashboard(BuildContext context, String userType) async {
    // Store user type in SharedPreferences for future use
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_type', userType);
    
    // Navigate based on user type
    switch (userType.toLowerCase()) {
      case 'patient':
        _navigateToScreen(context, const DashboardUser());
        break;
      case 'hospital':
        _navigateToScreen(context, const HospitalDashboardScreen());
        break;
      case 'doctor':
        _navigateToScreen(context, const DashboardDoctor());
        break;
      case 'nurse':
        _navigateToScreen(context, const NurseDashboardScreen());
        break;
      case 'lab':
        _navigateToScreen(context, const LabDashboardScreen());
        break;
      case 'pharmacy':
        _navigateToScreen(context, const DashboardPharmacy());
        break;
      case 'admin':
        _navigateToScreen(context, const AdminDashboardScreen());
        break;
      case 'arcstaff':
        _navigateToScreen(context, const ArcStaffDashboardScreen());
        break;
      default:
        // For unknown types, go to approval pending screen
        _navigateToScreen(context, const ApprovalPendingScreen());
        break;
    }
  }

  /// Navigate to approval pending screen for users that need approval
  static void navigateToApprovalPending(BuildContext context, {String userType = 'hospital'}) {
    _navigateToScreen(context, ApprovalPendingScreen(userType: userType));
  }

  /// Navigate to user dashboard (for patients)
  static void navigateToUserDashboard(BuildContext context) {
    _navigateToScreen(context, const DashboardUser());
  }

  /// Navigate to hospital dashboard
  static void navigateToHospitalDashboard(BuildContext context) {
    _navigateToScreen(context, const HospitalDashboardScreen());
  }

  /// Navigate to doctor dashboard
  static void navigateToDoctorDashboard(BuildContext context) {
    _navigateToScreen(context, const DashboardDoctor());
  }

  /// Navigate to nurse dashboard
  static void navigateToNurseDashboard(BuildContext context) {
    _navigateToScreen(context, const NurseDashboardScreen());
  }

  /// Navigate to lab dashboard
  static void navigateToLabDashboard(BuildContext context) {
    _navigateToScreen(context, const LabDashboardScreen());
  }

  /// Navigate to pharmacy dashboard
  static void navigateToPharmacyDashboard(BuildContext context) {
    _navigateToScreen(context, const DashboardPharmacy());
  }

  /// Navigate to admin dashboard
  static void navigateToAdminDashboard(BuildContext context) {
    _navigateToScreen(context, const AdminDashboardScreen());
  }

  /// Navigate to arc staff dashboard
  static void navigateToArcStaffDashboard(BuildContext context) {
    _navigateToScreen(context, const ArcStaffDashboardScreen());
  }

  /// Helper method to navigate and replace current screen
  static void _navigateToScreen(BuildContext context, Widget screen) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  /// Get the appropriate dashboard screen based on user type
  static Widget getDashboardScreen(String userType) {
    switch (userType.toLowerCase()) {
      case 'patient':
        return const DashboardUser();
      case 'hospital':
        return const HospitalDashboardScreen();
      case 'doctor':
        return const DashboardDoctor();
      case 'nurse':
        return const NurseDashboardScreen();
      case 'lab':
        return const LabDashboardScreen();
      case 'pharmacy':
        return const DashboardPharmacy();
      case 'admin':
        return const AdminDashboardScreen();
      case 'arcstaff':
        return const ArcStaffDashboardScreen();
      default:
        return ApprovalPendingScreen(userType: userType);
    }
  }

  /// Check if user type needs approval before accessing dashboard
  static bool needsApproval(String userType) {
    // These user types typically need admin approval
    const approvalRequiredTypes = ['hospital', 'doctor', 'nurse', 'lab', 'pharmacy'];
    return approvalRequiredTypes.contains(userType.toLowerCase());
  }

  /// Get appropriate navigation method based on user type and approval status
  static Future<void> navigateAfterRegistration(
    BuildContext context, 
    String userType, 
    String status,
  ) async {
    if (status == 'approved') {
      // User is approved, go directly to dashboard
      await navigateToDashboard(context, userType);
    } else if (needsApproval(userType)) {
      // User needs approval, go to approval pending screen
      navigateToApprovalPending(context, userType: userType);
    } else {
      // User doesn't need approval (like patients), go directly to dashboard
      await navigateToDashboard(context, userType);
    }
  }
}
