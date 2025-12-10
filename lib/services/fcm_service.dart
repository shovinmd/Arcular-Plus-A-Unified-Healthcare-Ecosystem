import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'dart:async';

class FCMService {
  static FCMService? _instance;
  factory FCMService() {
    _instance ??= FCMService._internal();
    return _instance!;
  }
  FCMService._internal();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  
  String? _fcmToken;
  bool _isInitialized = false;

  // Broadcast in-app events for screens to react (e.g., refresh lists)
  final StreamController<Map<String, dynamic>> _eventController = StreamController.broadcast();
  Stream<Map<String, dynamic>> get events => _eventController.stream;

  // Notification channels for Android
  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'high_importance_channel',
    'High Importance Notifications',
    description: 'This channel is used for important notifications.',
    importance: Importance.high,
    playSound: true,
    enableVibration: true,
    enableLights: true,
  );

  // Initialize FCM service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Initialize timezone
      tz.initializeTimeZones();
      
      // Check if we're on web and handle FCM limitations
      if (kIsWeb) {
        print('⚠️ FCM: Running on web, FCM functionality will be limited');
        _isInitialized = true;
        return;
      }

      // Request permission for iOS
      NotificationSettings settings = await _firebaseMessaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        print('✅ FCM: User granted permission');
      } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
        print('⚠️ FCM: User granted provisional permission');
      } else {
        print('❌ FCM: User declined or has not accepted permission');
        // Still mark as initialized to avoid blocking the app
        _isInitialized = true;
        return;
      }

      // Initialize local notifications
      await _initializeLocalNotifications();

      // Get FCM token with error handling
      try {
        _fcmToken = await _firebaseMessaging.getToken();
        print('🔍 FCM: Token request result: $_fcmToken');
        
        if (_fcmToken != null) {
          print('✅ FCM: Token obtained: ${_fcmToken!.substring(0, 20)}...');
          await _saveFCMToken();
          await _registerTokenWithBackend();
        } else {
          print('⚠️ FCM: No token obtained, but continuing initialization');
        }
      } catch (tokenError) {
        print('⚠️ FCM: Token error (continuing without FCM): $tokenError');
        // Continue without FCM token
      }

      // Handle token refresh with error handling
      try {
        _firebaseMessaging.onTokenRefresh.listen((newToken) async {
          _fcmToken = newToken;
          await _saveFCMToken();
          await _registerTokenWithBackend();
          print('🔄 FCM: Token refreshed');
        });
      } catch (e) {
        print('⚠️ FCM: Token refresh listener error: $e');
      }

      // Handle foreground messages with error handling
      try {
        FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
      } catch (e) {
        print('⚠️ FCM: Foreground message listener error: $e');
      }

      // Handle background messages with error handling
      try {
        FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
      } catch (e) {
        print('⚠️ FCM: Background message handler error: $e');
      }

      // Handle notification taps when app is in background
      try {
        FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);
      } catch (e) {
        print('⚠️ FCM: Message opened app listener error: $e');
      }

      // Handle notification tap when app is terminated
      try {
        RemoteMessage? initialMessage = await _firebaseMessaging.getInitialMessage();
        if (initialMessage != null) {
          _handleNotificationTap(initialMessage);
        }
      } catch (e) {
        print('⚠️ FCM: Initial message error: $e');
      }

      _isInitialized = true;
      print('✅ FCM: Service initialized successfully (with fallbacks)');
    } catch (e) {
      print('❌ FCM: Critical error initializing service: $e');
      // Mark as initialized anyway to prevent blocking the app
      _isInitialized = true;
      print('⚠️ FCM: Marking service as initialized with fallback mode');
    }
  }

  // Initialize local notifications
  Future<void> _initializeLocalNotifications() async {
    // If we're on web, skip local notification initialization
    if (kIsWeb) {
      print('⚠️ FCM: Local notification initialization skipped on web');
      return;
    }
    
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@drawable/notify_icon');

    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _localNotifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    // Create notification channel for Android
    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);
  }

  // Handle foreground messages
  void _handleForegroundMessage(RemoteMessage message) {
    print('📱 FCM: Foreground message received: ${message.messageId}');
    
    // Show local notification (will be skipped on web)
    _showLocalNotification(message);
    
    // You can also update UI here if needed
    // For example, update notification count in dashboard

    // Emit event for in-app listeners
    try {
      final payload = <String, dynamic>{
        'type': message.data['type'] ?? message.notification?.title ?? 'notification',
        'data': message.data,
      };
      _eventController.add(payload);
    } catch (_) {}
  }

  // Handle notification taps
  void _handleNotificationTap(RemoteMessage message) {
    print('👆 FCM: Notification tapped: ${message.messageId}');
    
    // Handle navigation based on notification data
    if (message.data.containsKey('screen')) {
      // Navigate to specific screen
      // This will be handled by the main app navigation
    }

    // Emit event so relevant screens can refresh
    try {
      final payload = <String, dynamic>{
        'type': message.data['type'] ?? message.notification?.title ?? 'notification',
        'data': message.data,
      };
      _eventController.add(payload);
    } catch (_) {}
  }

  // Handle local notification taps
  void _onNotificationTap(NotificationResponse response) {
    print('👆 FCM: Local notification tapped: ${response.payload}');
    
    // Handle navigation based on notification payload
    if (response.payload != null) {
      // Navigate to specific screen
      // This will be handled by the main app navigation
    }
  }

  // Show local notification
  Future<void> _showLocalNotification(RemoteMessage message) async {
    // If we're on web, skip local notification
    if (kIsWeb) {
      print('⚠️ FCM: Local notification display skipped on web');
      return;
    }
    
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'high_importance_channel',
      'High Importance Notifications',
      channelDescription: 'This channel is used for important notifications.',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
      enableVibration: true,
      enableLights: true,
      color: Color(0xFF32CCBC), // Patient teal color
      icon: '@drawable/notify_icon', // Use custom notification icon
    );

    const DarwinNotificationDetails iOSPlatformChannelSpecifics =
        DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
    );

    await _localNotifications.show(
      message.hashCode,
      message.notification?.title ?? 'New Notification',
      message.notification?.body ?? 'You have a new notification',
      platformChannelSpecifics,
      payload: json.encode(message.data),
    );
  }

  // Save FCM token locally
  Future<void> _saveFCMToken() async {
    if (_fcmToken != null && !kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('fcm_token', _fcmToken!);
    }
  }

  // Get FCM token
  String? get token => _fcmToken;
  
  // Get FCM token (async method for compatibility)
  Future<String?> getToken() async {
    if (kIsWeb) {
      print('⚠️ FCM: getToken() skipped on web');
      return null;
    }
    return _fcmToken ?? await refreshToken();
  }
  
  // Check if FCM service is ready
  bool get isReady => _isInitialized; // Allow service to be ready even without FCM token



  // Force token refresh
  Future<String?> refreshToken() async {
    try {
      // If we're on web, don't try to get FCM token
      if (kIsWeb) {
        print('⚠️ FCM: Token refresh skipped on web');
        return null;
      }
      
      _fcmToken = await _firebaseMessaging.getToken();
      print('🔍 FCM: Token refresh result: $_fcmToken');
      return _fcmToken;
    } catch (e) {
      print('❌ FCM: Error refreshing token: $e');
      return null;
    }
  }

  // Register token with backend
  Future<void> _registerTokenWithBackend() async {
    if (_fcmToken == null || kIsWeb) return;

    try {
      // Get Firebase ID token directly (same as API service)
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('❌ FCM: No Firebase user found for token registration');
        return;
      }

      final idToken = await user.getIdToken(true);
      if (idToken == null) {
        print('❌ FCM: Failed to get Firebase ID token for registration');
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id');
      final userType = prefs.getString('user_type');

      if (userId != null && userType != null) {
        // Get user's notification preferences
        final notificationPreferences = {
          'menstrualReminders': prefs.getBool('menstrual_reminders') ?? true,
          'reminderTime': prefs.getString('reminder_time') ?? '09:00',
          'timezone': 'Asia/Kolkata', // Default to Indian timezone
        };

        final response = await http.post(
          Uri.parse('https://arcular-plus-backend.onrender.com/api/fcm/register-token'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $idToken',
          },
          body: json.encode({
            'fcmToken': _fcmToken,
            'notificationPreferences': notificationPreferences,
          }),
        );

        if (response.statusCode == 200) {
          print('✅ FCM: Token registered with backend');
        } else {
          print('⚠️ FCM: Failed to register token with backend: ${response.statusCode}');
        }
      }
    } catch (e) {
      print('❌ FCM: Error registering token with backend: $e');
      // Don't fail the entire initialization process
    }
  }

  // Subscribe to topics
  Future<void> subscribeToTopic(String topic) async {
    if (kIsWeb) {
      print('⚠️ FCM: Topic subscription skipped on web');
      return;
    }
    try {
      await _firebaseMessaging.subscribeToTopic(topic);
      print('✅ FCM: Subscribed to topic: $topic');
    } catch (e) {
      print('❌ FCM: Error subscribing to topic $topic: $e');
    }
  }

  // Unsubscribe from topics
  Future<void> unsubscribeFromTopic(String topic) async {
    if (kIsWeb) {
      print('⚠️ FCM: Topic unsubscription skipped on web');
      return;
    }
    try {
      await _firebaseMessaging.unsubscribeFromTopic(topic);
      print('✅ FCM: Unsubscribed from topic: $topic');
    } catch (e) {
      print('❌ FCM: Error unsubscribing from topic $topic: $e');
    }
  }

  // Get notification settings
  Future<NotificationSettings> getNotificationSettings() async {
    if (kIsWeb) {
      print('⚠️ FCM: Get notification settings skipped on web');
      // Return a default settings object for web
      return const NotificationSettings(
        authorizationStatus: AuthorizationStatus.authorized,
        alert: AppleNotificationSetting.enabled,
        announcement: AppleNotificationSetting.disabled,
        badge: AppleNotificationSetting.enabled,
        carPlay: AppleNotificationSetting.disabled,
        criticalAlert: AppleNotificationSetting.disabled,
        lockScreen: AppleNotificationSetting.enabled,
        notificationCenter: AppleNotificationSetting.enabled,
        sound: AppleNotificationSetting.enabled,
        showPreviews: AppleShowPreviewSetting.always,
        timeSensitive: AppleNotificationSetting.disabled,
        providesAppNotificationSettings: AppleNotificationSetting.disabled,
      );
    }
    return await _firebaseMessaging.getNotificationSettings();
  }

  // Update notification settings
  Future<void> updateNotificationSettings({
    bool? alert,
    bool? announcement,
    bool? badge,
    bool? carPlay,
    bool? criticalAlert,
    bool? provisional,
    bool? sound,
  }) async {
    if (kIsWeb) {
      print('⚠️ FCM: Notification settings update skipped on web');
      return;
    }
    await _firebaseMessaging.requestPermission(
      alert: alert ?? true,
      announcement: announcement ?? false,
      badge: badge ?? true,
      carPlay: carPlay ?? false,
      criticalAlert: criticalAlert ?? false,
      provisional: provisional ?? false,
      sound: sound ?? true,
    );
  }

  // Clear all notifications
  Future<void> clearAllNotifications() async {
    if (kIsWeb) {
      print('⚠️ FCM: Clear notifications skipped on web');
      return;
    }
    await _localNotifications.cancelAll();
  }

  // Get badge count
  Future<int> getBadgeCount() async {
    if (kIsWeb) {
      print('⚠️ FCM: Get badge count skipped on web');
      return 0;
    }
    return await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.getNotificationAppLaunchDetails()
        .then((_) => 0) ?? 0;
  }

  // Set badge count
  Future<void> setBadgeCount(int count) async {
    if (kIsWeb) {
      print('⚠️ FCM: Set badge count skipped on web');
      return;
    }
    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  // Update notification preferences for menstrual reminders
  Future<bool> updateMenstrualReminderPreferences({
    required bool menstrualReminders,
    required String reminderTime,
    String timezone = 'Asia/Kolkata',
  }) async {
    try {
      // Always save preferences locally first
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('menstrual_reminders', menstrualReminders);
      await prefs.setString('reminder_time', reminderTime);
      
      print('✅ FCM: Preferences saved locally');

      // If we're on web or don't have FCM token, just return success
      if (kIsWeb || _fcmToken == null) {
        print('⚠️ FCM: Skipping backend update (web or no FCM token)');
        return true;
      }

      // Get Firebase ID token directly (same as API service)
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('❌ FCM: No Firebase user found');
        return false;
      }

      final idToken = await user.getIdToken(true);
      if (idToken == null) {
        print('❌ FCM: Failed to get Firebase ID token');
        return false;
      }

      print('🔍 FCM: Got Firebase ID token successfully');
      print('🔍 FCM: FCM token exists: ${_fcmToken != null}');

      print('🔍 FCM: Sending request to backend...');
      print('🔍 FCM: Request body: ${json.encode({
        'fcmToken': _fcmToken,
        'notificationPreferences': {
          'menstrualReminders': menstrualReminders,
          'reminderTime': reminderTime,
          'timezone': timezone,
        },
      })}');

      // Update backend
      final response = await http.post(
        Uri.parse('https://arcular-plus-backend.onrender.com/api/fcm/register-token'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
        body: json.encode({
          'fcmToken': _fcmToken,
          'notificationPreferences': {
            'menstrualReminders': menstrualReminders,
            'reminderTime': reminderTime,
            'timezone': timezone,
          },
        }),
      );

      print('🔍 FCM: Backend response status: ${response.statusCode}');
      print('🔍 FCM: Backend response body: ${response.body}');

      if (response.statusCode == 200) {
        print('✅ FCM: Menstrual reminder preferences updated in backend');
        return true;
      } else {
        print('⚠️ FCM: Failed to update preferences in backend: ${response.statusCode}');
        // Still return true since local preferences were saved
        return true;
      }
    } catch (e) {
      print('❌ FCM: Error updating menstrual reminder preferences: $e');
      // Still return true since local preferences were saved
      return true;
    }
  }

  // Get upcoming reminders from backend
  Future<List<Map<String, dynamic>>> getUpcomingReminders() async {
    try {
      // Check if user is female - only show menstrual reminders for females
      final prefs = await SharedPreferences.getInstance();
      final userGender = prefs.getString('user_gender') ?? 'Female';
      
      if (userGender != 'Female') {
        print('⚠️ FCM: User is male, skipping menstrual reminders');
        return [];
      }
      
      // Check if menstrual reminders are enabled
      final isEnabled = prefs.getBool('menstrual_reminders') ?? true;
      
      if (!isEnabled) {
        print('⚠️ FCM: Menstrual reminders disabled, returning empty list');
        return [];
      }

      // Get Firebase ID token directly (same as API service)
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('❌ FCM: No Firebase user found');
        return [];
      }

      final idToken = await user.getIdToken(true);
      if (idToken == null) {
        print('❌ FCM: Failed to get Firebase ID token');
        return [];
      }

      final response = await http.get(
        Uri.parse('https://arcular-plus-backend.onrender.com/api/fcm/upcoming-reminders'),
        headers: {
          'Authorization': 'Bearer $idToken',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          final allReminders = List<Map<String, dynamic>>.from(data['data']);
          
          // Filter reminders based on individual user preferences
          final filteredReminders = await _filterRemindersByPreferences(allReminders);
          
          // Only schedule local notifications if FCM is properly initialized
          if (_fcmToken != null && !kIsWeb) {
            await _scheduleReminderNotifications(filteredReminders);
          } else {
            print('⚠️ FCM: Skipping local notification scheduling (FCM not available or on web)');
          }
          
          return filteredReminders;
        }
      }
      
      return [];
    } catch (e) {
      print('❌ FCM: Error getting upcoming reminders: $e');
      return [];
    }
  }

  // Filter reminders based on individual user preferences
  Future<List<Map<String, dynamic>>> _filterRemindersByPreferences(List<Map<String, dynamic>> allReminders) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<Map<String, dynamic>> filteredReminders = [];
      
      for (final reminder in allReminders) {
        final type = reminder['type']?.toString().toLowerCase() ?? '';
        bool shouldShow = false;
        
        switch (type) {
          case 'next period':
            shouldShow = prefs.getBool('remind_next_period') ?? true;
            break;
          case 'ovulation':
            shouldShow = prefs.getBool('remind_ovulation') ?? true;
            break;
          case 'fertile window':
            shouldShow = prefs.getBool('remind_fertile_window') ?? true;
            break;
          default:
            shouldShow = true; // Show unknown types by default
        }
        
        if (shouldShow) {
          filteredReminders.add(reminder);
          print('✅ FCM: Including $type reminder (enabled)');
        } else {
          print('⚠️ FCM: Skipping $type reminder (disabled)');
        }
      }
      
      print('✅ FCM: Filtered ${allReminders.length} reminders to ${filteredReminders.length} based on preferences');
      return filteredReminders;
    } catch (e) {
      print('❌ FCM: Error filtering reminders by preferences: $e');
      return allReminders; // Return all reminders if filtering fails
    }
  }

  // Schedule local notifications for reminders
  Future<void> _scheduleReminderNotifications(List<Map<String, dynamic>> reminders) async {
    try {
      // If we're on web, don't try to schedule local notifications
      if (kIsWeb) {
        print('⚠️ FCM: Local notification scheduling skipped on web');
        return;
      }
      
      // Cancel existing reminder notifications
      await _localNotifications.cancelAll();
      
      for (final reminder in reminders) {
        await _scheduleReminderNotification(reminder);
      }
      
      print('✅ FCM: Scheduled ${reminders.length} reminder notifications');
    } catch (e) {
      print('❌ FCM: Error scheduling reminder notifications: $e');
      // Don't fail the entire process
    }
  }

  // Schedule notification via backend
  Future<bool> scheduleNotification({
    required String title,
    required String body,
    required DateTime scheduledTime,
    Map<String, dynamic>? data,
  }) async {
    try {
      // If we're on web, return false
      if (kIsWeb) {
        print('⚠️ FCM: scheduleNotification() skipped on web');
        return false;
      }

      // Get Firebase ID token
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('❌ FCM: No Firebase user found for scheduling notification');
        return false;
      }

      final idToken = await user.getIdToken(true);
      if (idToken == null) {
        print('❌ FCM: Failed to get Firebase ID token for scheduling notification');
        return false;
      }

      // Send notification request to backend
      final response = await http.post(
        Uri.parse('https://arcular-plus-backend.onrender.com/api/fcm/schedule-notification'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
        body: json.encode({
          'title': title,
          'body': body,
          'scheduledTime': scheduledTime.toIso8601String(),
          'data': data ?? {},
        }),
      );

      if (response.statusCode == 200) {
        print('✅ FCM: Notification scheduled successfully');
        return true;
      } else {
        print('⚠️ FCM: Failed to schedule notification: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('❌ FCM: Error scheduling notification: $e');
      return false;
    }
  }

  // Schedule a single reminder notification
  Future<void> _scheduleReminderNotification(Map<String, dynamic> reminder) async {
    try {
      // If we're on web, don't try to schedule local notifications
      if (kIsWeb) {
        print('⚠️ FCM: Local notification scheduling skipped on web');
        return;
      }
      
      // Check if notifications are enabled for this reminder type
      final prefs = await SharedPreferences.getInstance();
      final isEnabled = prefs.getBool('menstrual_reminders') ?? true;
      
      if (!isEnabled) {
        print('⚠️ FCM: Menstrual reminders disabled, skipping notification');
        return;
      }

      // Check specific reminder type preferences
      final reminderType = reminder['type']?.toString().toLowerCase() ?? '';
      bool shouldSchedule = false;
      
      switch (reminderType) {
        case 'next period':
          shouldSchedule = prefs.getBool('remind_next_period') ?? true;
          break;
        case 'ovulation':
          shouldSchedule = prefs.getBool('remind_ovulation') ?? true;
          break;
        case 'fertile window':
          shouldSchedule = prefs.getBool('remind_fertile_window') ?? true;
          break;
        default:
          shouldSchedule = true; // Default to true for unknown types
      }
      
      if (!shouldSchedule) {
        print('⚠️ FCM: $reminderType reminders disabled, skipping notification');
        return;
      }

      final date = reminder['date'];
      final time = reminder['time'];
      final type = reminder['type'] ?? 'reminder';
      final title = reminder['title'] ?? 'Reminder';
      final description = reminder['description'] ?? '';

      if (date == null) return;

      final scheduledDate = DateTime.parse(date);
      final now = DateTime.now();
      
      // Only schedule if the date is in the future
      if (scheduledDate.isBefore(now)) return;

      // Parse time if provided
      DateTime scheduledDateTime = scheduledDate;
      if (time != null && time.isNotEmpty) {
        final timeParts = time.split(':');
        if (timeParts.length == 2) {
          scheduledDateTime = DateTime(
            scheduledDate.year,
            scheduledDate.month,
            scheduledDate.day,
            int.parse(timeParts[0]),
            int.parse(timeParts[1]),
          );
        }
      }

      // Create notification details
      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'menstrual_reminders',
        'Menstrual Cycle Reminders',
        channelDescription: 'Notifications for menstrual cycle tracking',
        importance: Importance.high,
        priority: Priority.high,
        color: Color(0xFFEC4899), // Pink color
        enableVibration: true,
        enableLights: true,
        playSound: true,
        icon: '@drawable/notify_icon', // Use custom notification icon
      );

      const DarwinNotificationDetails iOSDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const NotificationDetails details = NotificationDetails(
        android: androidDetails,
        iOS: iOSDetails,
      );

      // Schedule the notification
      await _localNotifications.zonedSchedule(
        reminder.hashCode,
        title,
        description,
        tz.TZDateTime.from(scheduledDateTime, tz.local),
        details,
        androidScheduleMode: AndroidScheduleMode.inexact,
      );

      print('✅ FCM: Scheduled notification for $type on ${scheduledDateTime.toString()}');
    } catch (e) {
      print('❌ FCM: Error scheduling reminder notification: $e');
    }
  }

  
}

// Background message handler (must be top-level function)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('📱 FCM: Background message received: ${message.messageId}');
  
  // Handle background message processing
  // You can perform database updates, API calls, etc. here
  
  // Skip local notifications on web
  if (kIsWeb) {
    print('⚠️ FCM: Background message handler skipped on web');
    return;
  }
  
  // Show local notification
  final FlutterLocalNotificationsPlugin localNotifications = FlutterLocalNotificationsPlugin();
  
  const AndroidNotificationDetails androidPlatformChannelSpecifics =
      AndroidNotificationDetails(
    'high_importance_channel',
    'High Importance Notifications',
    channelDescription: 'This channel is used for important notifications.',
    importance: Importance.max,
    priority: Priority.high,
    showWhen: true,
    enableVibration: true,
    enableLights: true,
    color: Color(0xFF32CCBC),
    icon: '@drawable/notify_icon', // Use custom notification icon
  );

  const DarwinNotificationDetails iOSPlatformChannelSpecifics =
      DarwinNotificationDetails(
    presentAlert: true,
    presentBadge: true,
    presentSound: true,
  );

  const NotificationDetails platformChannelSpecifics = NotificationDetails(
    android: androidPlatformChannelSpecifics,
    iOS: iOSPlatformChannelSpecifics,
  );

  await localNotifications.show(
    message.hashCode,
    message.notification?.title ?? 'New Notification',
    message.notification?.body ?? 'You have a new notification',
    platformChannelSpecifics,
    payload: json.encode(message.data),
  );
}

// Appointment reminder functionality
extension AppointmentReminders on FCMService {
  // Schedule appointment reminder notifications
  Future<void> scheduleAppointmentReminders({
    required String appointmentId,
    required String doctorName,
    required String hospitalName,
    required DateTime appointmentDate,
    required String appointmentTime,
    required String reason,
  }) async {
    try {
      print('📅 FCM: Scheduling appointment reminders for $appointmentId');
      
      // Schedule reminder for 1 day before
      final dayBefore = appointmentDate.subtract(const Duration(days: 1));
      if (dayBefore.isAfter(DateTime.now())) {
        await _scheduleAppointmentReminder(
          id: appointmentId.hashCode + 1,
          title: 'Appointment Reminder',
          body: 'You have an appointment tomorrow with Dr. $doctorName at $hospitalName',
          scheduledDate: dayBefore,
          appointmentId: appointmentId,
          doctorName: doctorName,
          hospitalName: hospitalName,
          appointmentDate: appointmentDate,
          appointmentTime: appointmentTime,
        );
      }

      // Schedule reminder for 2 hours before
      final twoHoursBefore = appointmentDate.subtract(const Duration(hours: 2));
      if (twoHoursBefore.isAfter(DateTime.now())) {
        await _scheduleAppointmentReminder(
          id: appointmentId.hashCode + 2,
          title: 'Appointment Soon',
          body: 'Your appointment with Dr. $doctorName is in 2 hours at $appointmentTime',
          scheduledDate: twoHoursBefore,
          appointmentId: appointmentId,
          doctorName: doctorName,
          hospitalName: hospitalName,
          appointmentDate: appointmentDate,
          appointmentTime: appointmentTime,
        );
      }

      // Schedule reminder for 30 minutes before
      final thirtyMinutesBefore = appointmentDate.subtract(const Duration(minutes: 30));
      if (thirtyMinutesBefore.isAfter(DateTime.now())) {
        await _scheduleAppointmentReminder(
          id: appointmentId.hashCode + 3,
          title: 'Appointment Starting Soon',
          body: 'Your appointment with Dr. $doctorName starts in 30 minutes',
          scheduledDate: thirtyMinutesBefore,
          appointmentId: appointmentId,
          doctorName: doctorName,
          hospitalName: hospitalName,
          appointmentDate: appointmentDate,
          appointmentTime: appointmentTime,
        );
      }

      // Schedule reminder for the day of appointment (morning)
      final appointmentDay = DateTime(appointmentDate.year, appointmentDate.month, appointmentDate.day, 9, 0);
      if (appointmentDay.isAfter(DateTime.now())) {
        await _scheduleAppointmentReminder(
          id: appointmentId.hashCode + 4,
          title: 'Appointment Today',
          body: 'You have an appointment today with Dr. $doctorName at $appointmentTime',
          scheduledDate: appointmentDay,
          appointmentId: appointmentId,
          doctorName: doctorName,
          hospitalName: hospitalName,
          appointmentDate: appointmentDate,
          appointmentTime: appointmentTime,
        );
      }

      print('✅ FCM: Scheduled appointment reminders for $appointmentId');
    } catch (e) {
      print('❌ FCM: Error scheduling appointment reminders: $e');
    }
  }

  // Schedule a single appointment reminder
  Future<void> _scheduleAppointmentReminder({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    required String appointmentId,
    required String doctorName,
    required String hospitalName,
    required DateTime appointmentDate,
    required String appointmentTime,
  }) async {
    try {
      // Skip on web
      if (kIsWeb) {
        print('⚠️ FCM: Appointment reminder scheduling skipped on web');
        return;
      }

      final scheduledDateTime = tz.TZDateTime.from(scheduledDate, tz.local);
      
      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'appointment_reminders',
        'Appointment Reminders',
        channelDescription: 'Reminders for upcoming appointments',
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
        enableVibration: true,
        enableLights: true,
        color: Color(0xFF32CCBC),
        icon: '@drawable/notify_icon',
      );

      const DarwinNotificationDetails iOSDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        sound: 'default',
      );

      const NotificationDetails details = NotificationDetails(
        android: androidDetails,
        iOS: iOSDetails,
      );

      await _localNotifications.zonedSchedule(
        id,
        title,
        body,
        scheduledDateTime,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: json.encode({
          'type': 'appointment_reminder',
          'appointmentId': appointmentId,
          'doctorName': doctorName,
          'hospitalName': hospitalName,
          'appointmentDate': appointmentDate.toIso8601String(),
          'appointmentTime': appointmentTime,
        }),
      );

      print('✅ FCM: Scheduled appointment reminder: $title for ${scheduledDateTime.toString()}');
    } catch (e) {
      print('❌ FCM: Error scheduling appointment reminder: $e');
    }
  }

  // Send appointment reminder email via backend
  Future<void> sendAppointmentReminderEmail({
    required String appointmentId,
    required String doctorName,
    required String hospitalName,
    required DateTime appointmentDate,
    required String appointmentTime,
    required String reason,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final idToken = await user.getIdToken();
      
      final response = await http.post(
        Uri.parse('https://arcular-plus-backend.onrender.com/api/fcm/send-appointment-reminder'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
        body: json.encode({
          'appointmentId': appointmentId,
          'doctorName': doctorName,
          'hospitalName': hospitalName,
          'appointmentDate': appointmentDate.toIso8601String(),
          'appointmentTime': appointmentTime,
          'reason': reason,
        }),
      );

      if (response.statusCode == 200) {
        print('✅ FCM: Appointment reminder email sent successfully');
      } else {
        print('❌ FCM: Failed to send appointment reminder email: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ FCM: Error sending appointment reminder email: $e');
    }
  }
}
