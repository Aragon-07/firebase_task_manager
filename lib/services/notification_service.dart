import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// Top-level background message handler required by Firebase Messaging
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (kDebugMode) {
    print('Handling background message: ${message.messageId}');
  }
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
  FlutterLocalNotificationsPlugin();

  // Notification channel definition for Android 8.0+
  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'task_channel', // Matches the metadata in AndroidManifest.xml
    'Task Notifications',
    description: 'Notifications for Task Management updates and alerts',
    importance: Importance.max,
    playSound: true,
  );

  // Callback to trigger navigation when a notification is clicked
  Function(String? taskId)? onNotificationSelected;

  Future<void> initialize({Function(String? taskId)? onSelectNotification}) async {
    onNotificationSelected = onSelectNotification;

    // 1. Request permissions (Android 13+ & iOS)
    NotificationSettings settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    if (kDebugMode) {
      print('User granted notification permission: ${settings.authorizationStatus}');
    }

    // 2. Initialize Flutter Local Notifications
    const AndroidInitializationSettings androidSettings =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initSettings =
    InitializationSettings(android: androidSettings);

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        if (response.payload != null && onNotificationSelected != null) {
          onNotificationSelected!(response.payload);
        }
      },
    );

    // 3. Register notification channel in Android
    await _localNotifications
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);

    // 4. Print FCM Device Token (Needed for testing notifications)
    String? token = await _fcm.getToken();
    if (kDebugMode) {
      print('========================================');
      print('FCM DEVICE TOKEN:');
      print(token);
      print('========================================');
    }

    // 5. Listen to token refresh
    _fcm.onTokenRefresh.listen((newToken) {
      if (kDebugMode) {
        print('FCM Token Refreshed: $newToken');
      }
    });

    // 6. Handle FOREGROUND notifications (Convert FCM -> Local Notification)
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (kDebugMode) {
        print('Received message in FOREGROUND: ${message.data}');
      }
      showForegroundNotification(message);
    });

    // 7. Handle notification click when app is opened from BACKGROUND
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      if (kDebugMode) {
        print('Notification tapped from BACKGROUND state: ${message.data}');
      }
      _handleMessageClick(message);
    });

    // 8. Handle notification click when app is opened from TERMINATED state
    RemoteMessage? initialMessage = await _fcm.getInitialMessage();
    if (initialMessage != null) {
      if (kDebugMode) {
        print('App opened from TERMINATED state via notification: ${initialMessage.data}');
      }
      _handleMessageClick(initialMessage);
    }
  }

  // Display a local heads-up notification when the app is in the foreground
  Future<void> showForegroundNotification(RemoteMessage message) async {
    RemoteNotification? notification = message.notification;
    AndroidNotification? android = message.notification?.android;

    String title = notification?.title ?? message.data['title'] ?? 'New Task Alert';
    String body = notification?.body ?? message.data['body'] ?? 'You have a task update';
    String? taskId = message.data['taskId'];

    AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      _channel.id,
      _channel.name,
      channelDescription: _channel.description,
      importance: Importance.max,
      priority: Priority.high,
      icon: android?.smallIcon ?? '@mipmap/ic_launcher',
      playSound: true,
    );

    NotificationDetails platformDetails = NotificationDetails(android: androidDetails);

    await _localNotifications.show(
      message.hashCode,
      title,
      body,
      platformDetails,
      payload: taskId,
    );
  }

  void _handleMessageClick(RemoteMessage message) {
    String? taskId = message.data['taskId'];
    if (onNotificationSelected != null) {
      onNotificationSelected!(taskId);
    }
  }
}