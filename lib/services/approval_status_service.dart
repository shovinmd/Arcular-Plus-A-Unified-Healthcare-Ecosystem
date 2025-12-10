import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

class ApprovalStatusService extends ChangeNotifier {
  Timer? _statusTimer;
  String? _currentUserId;
  String? _currentUserType;
  Map<String, dynamic>? _approvalStatus;
  bool _isLoading = false;

  // Status constants
  static const String STATUS_PENDING = 'pending';
  static const String STATUS_APPROVED = 'approved';
  static const String STATUS_REJECTED = 'rejected';

  ApprovalStatusService() {
    _initializeService();
  }

  Future<void> _initializeService() async {
    final prefs = await SharedPreferences.getInstance();
    _currentUserId = prefs.getString('user_uid');
    _currentUserType = prefs.getString('user_type');
    
    if (_currentUserType == 'hospital') {
      await _checkApprovalStatus();
      _startStatusPolling();
    }
  }

  void _startStatusPolling() {
    // Check status every 30 seconds
    _statusTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _checkApprovalStatus();
    });
  }

  Future<void> _checkApprovalStatus() async {
    if (_currentUserId == null || _currentUserType != 'hospital') return;

    setState(() {
      _isLoading = true;
    });

    try {
      final status = await ApiService.getHospitalApprovalStatus(_currentUserId!);
      
      if (status != null) {
        final oldStatus = _approvalStatus?['approvalStatus'];
        final newStatus = status['approvalStatus'];
        
        _approvalStatus = status;
        
        // Notify if status changed
        if (oldStatus != null && oldStatus != newStatus) {
          _onStatusChanged(oldStatus, newStatus);
        }
      }
    } catch (e) {
      print('Error checking approval status: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _onStatusChanged(String oldStatus, String newStatus) {
    // Handle status change notifications
    if (newStatus == STATUS_APPROVED) {
      _showApprovalNotification();
    } else if (newStatus == STATUS_REJECTED) {
      _showRejectionNotification();
    }
  }

  void _showApprovalNotification() {
    // TODO: Implement local notification
    print('Hospital approved!');
  }

  void _showRejectionNotification() {
    // TODO: Implement local notification
    print('Hospital rejected!');
  }

  void setState(VoidCallback fn) {
    fn();
    notifyListeners();
  }

  // Public methods
  Future<void> refreshStatus() async {
    await _checkApprovalStatus();
  }

  bool get isApproved => _approvalStatus?['isApproved'] ?? false;
  String get approvalStatus => _approvalStatus?['approvalStatus'] ?? STATUS_PENDING;
  String get status => _approvalStatus?['status'] ?? 'pending';
  bool get isLoading => _isLoading;
  Map<String, dynamic>? get approvalStatusData => _approvalStatus;

  // Check if user can access dashboard
  bool get canAccessDashboard {
    if (_currentUserType != 'hospital') return true;
    return isApproved && approvalStatus == STATUS_APPROVED;
  }

  // Get approval message
  String get approvalMessage {
    switch (approvalStatus) {
      case STATUS_APPROVED:
        return 'Your hospital registration has been approved! You can now access all features.';
      case STATUS_REJECTED:
        final reason = _approvalStatus?['rejectionReason'] ?? 'No reason provided';
        return 'Your hospital registration was rejected. Reason: $reason';
      case STATUS_PENDING:
      default:
        return 'Your hospital registration is pending approval. You will be notified once reviewed.';
    }
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    super.dispose();
  }
} 