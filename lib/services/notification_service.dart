import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class NotificationService {
  static const String _notificationKeyPrefix = 'notifications_';
  static const String _lastCheckKeyPrefix = 'last_check_';

  // Notification types
  static const String notificationTypeTestRequest = 'test_request';
  static const String notificationTypeAppointment = 'appointment';
  static const String notificationTypeAssignment = 'assignment';
  static const String notificationTypeOrder = 'order';
  static const String notificationTypeReport = 'report';

  // Save notification
  static Future<void> saveNotification({
    required String userType,
    required String type,
    required String title,
    required String message,
    required Map<String, dynamic> data,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final notificationKey = '${_notificationKeyPrefix}$userType';

      // Get existing notifications
      final existingNotificationsJson = prefs.getString(notificationKey);
      List<Map<String, dynamic>> notifications = [];

      if (existingNotificationsJson != null) {
        final List<dynamic> decoded = json.decode(existingNotificationsJson);
        notifications = decoded.cast<Map<String, dynamic>>();
      }

      // Add new notification
      final newNotification = {
        'id': '${DateTime.now().millisecondsSinceEpoch}_$userType',
        'type': type,
        'title': title,
        'message': message,
        'data': data,
        'timestamp': DateTime.now().toIso8601String(),
        'isRead': false,
      };

      notifications.insert(0, newNotification); // Add to beginning

      // Keep only the most recent 50 notifications
      if (notifications.length > 50) {
        notifications = notifications.take(50).toList();
      }

      // Save back to preferences
      await prefs.setString(notificationKey, json.encode(notifications));

      print('✅ Notification saved for $userType: $title');
    } catch (e) {
      print('❌ Error saving notification: $e');
    }
  }

  // Get notifications for a user type
  static Future<List<Map<String, dynamic>>> getNotifications(
      String userType) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final notificationKey = '${_notificationKeyPrefix}$userType';

      final notificationsJson = prefs.getString(notificationKey);
      if (notificationsJson != null) {
        final List<dynamic> decoded = json.decode(notificationsJson);
        return decoded.cast<Map<String, dynamic>>();
      }

      return [];
    } catch (e) {
      print('❌ Error getting notifications: $e');
      return [];
    }
  }

  // Get unread notifications count
  static Future<int> getUnreadCount(String userType) async {
    try {
      final notifications = await getNotifications(userType);
      return notifications
          .where((notification) => !notification['isRead'])
          .length;
    } catch (e) {
      print('❌ Error getting unread count: $e');
      return 0;
    }
  }

  // Mark notification as read
  static Future<void> markAsRead(String userType, String notificationId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final notificationKey = '${_notificationKeyPrefix}$userType';

      final notificationsJson = prefs.getString(notificationKey);
      if (notificationsJson != null) {
        final List<dynamic> decoded = json.decode(notificationsJson);
        List<Map<String, dynamic>> notifications =
            decoded.cast<Map<String, dynamic>>();

        // Find and mark notification as read
        for (int i = 0; i < notifications.length; i++) {
          if (notifications[i]['id'] == notificationId) {
            notifications[i]['isRead'] = true;
            break;
          }
        }

        // Save back
        await prefs.setString(notificationKey, json.encode(notifications));
      }
    } catch (e) {
      print('❌ Error marking notification as read: $e');
    }
  }

  // Mark all notifications as read
  static Future<void> markAllAsRead(String userType) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final notificationKey = '${_notificationKeyPrefix}$userType';

      final notificationsJson = prefs.getString(notificationKey);
      if (notificationsJson != null) {
        final List<dynamic> decoded = json.decode(notificationsJson);
        List<Map<String, dynamic>> notifications =
            decoded.cast<Map<String, dynamic>>();

        // Mark all as read
        for (int i = 0; i < notifications.length; i++) {
          notifications[i]['isRead'] = true;
        }

        // Save back
        await prefs.setString(notificationKey, json.encode(notifications));
      }
    } catch (e) {
      print('❌ Error marking all notifications as read: $e');
    }
  }

  // Clear all notifications
  static Future<void> clearAllNotifications(String userType) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final notificationKey = '${_notificationKeyPrefix}$userType';
      await prefs.remove(notificationKey);
      print('✅ All notifications cleared for $userType');
    } catch (e) {
      print('❌ Error clearing notifications: $e');
    }
  }

  // Check if there are new notifications since last check
  static Future<bool> hasNewNotifications(String userType) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastCheckKey = '${_lastCheckKeyPrefix}$userType';
      final notifications = await getNotifications(userType);

      if (notifications.isEmpty) return false;

      final lastCheckTime = prefs.getString(lastCheckKey);
      if (lastCheckTime == null) return notifications.isNotEmpty;

      final lastCheck = DateTime.parse(lastCheckTime);
      final latestNotification =
          DateTime.parse(notifications.first['timestamp']);

      return latestNotification.isAfter(lastCheck);
    } catch (e) {
      print('❌ Error checking for new notifications: $e');
      return false;
    }
  }

  // Update last check time
  static Future<void> updateLastCheckTime(String userType) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastCheckKey = '${_lastCheckKeyPrefix}$userType';
      await prefs.setString(lastCheckKey, DateTime.now().toIso8601String());
    } catch (e) {
      print('❌ Error updating last check time: $e');
    }
  }

  // Get notification statistics
  static Future<Map<String, int>> getNotificationStats(String userType) async {
    try {
      final notifications = await getNotifications(userType);
      final unreadCount = notifications.where((n) => !n['isRead']).length;
      final totalCount = notifications.length;

      return {
        'total': totalCount,
        'unread': unreadCount,
        'read': totalCount - unreadCount,
      };
    } catch (e) {
      print('❌ Error getting notification stats: $e');
      return {
        'total': 0,
        'unread': 0,
        'read': 0,
      };
    }
  }
}
