import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';

class NotificationService {
  FirebaseMessaging get _fcm => FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifs = FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    try {
      // 1. Request Permission
      await _fcm.requestPermission();
      
      // 2. Local Notifications Setup
      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosInit = DarwinInitializationSettings();
      await _localNotifs.initialize(
        const InitializationSettings(android: androidInit, iOS: iosInit),
        onDidReceiveNotificationResponse: (details) {
          // Handle notification click here (Deep Linking)
          debugPrint("Notification Clicked: ${details.payload}");
        },
      );

      // 3. Listen to Foreground Messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        _showLocalNotification(message);
      });
    } catch (e) {
      debugPrint("⚠️ NotificationService Init Failed: $e");
    }
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    await _localNotifs.show(
      notification.hashCode,
      notification.title,
      notification.body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'open_lift_main',
          'General Notifications',
          importance: Importance.max,
          priority: Priority.high,
        ),
      ),
      payload: message.data.toString(),
    );
  }

  Future<String?> getToken() async {
    try {
      return await _fcm.getToken();
    } catch (e) {
      debugPrint("⚠️ Error getting FCM token: $e");
      return null;
    }
  }
}
