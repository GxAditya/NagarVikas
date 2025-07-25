import 'dart:ui';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    await _requestNotificationPermission();

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );
  }

  Future<void> _requestNotificationPermission() async {
    await Permission.notification.request();
  }

  void _onNotificationTapped(NotificationResponse notificationResponse) {
    print('Notification tapped: ${notificationResponse.payload}');
  }

  Future<void> showComplaintSubmittedNotification({
    required String issueType,
    String? complaintId,
  }) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'complaint_channel',
      'Complaint Notifications',
      channelDescription: 'Notifications for complaint submissions and updates',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      icon: '@mipmap/ic_launcher',
      color: Color(0xFF4CAF50),
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

    await _flutterLocalNotificationsPlugin.show(
      0,
      'Ministry Has Received Your Alert! 🦉',
      'Your owl-delivered $issueType complaint is being reviewed by the Department of Magical Maintenance.',
      platformChannelSpecifics,
      payload: complaintId ?? 'complaint_submitted',
    );
  }

  Future<void> showSubmissionFailedNotification({
    required String issueType,
  }) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'complaint_channel',
      'Complaint Notifications',
      channelDescription: 'Notifications for complaint submissions and updates',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      icon: '@mipmap/ic_launcher',
      color: Color(0xFFF44336),
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

    await _flutterLocalNotificationsPlugin.show(
      1,
      '🦉 Owl Lost Mid Flight!',
      'Failed to submit your $issueType complaint. Please try again.',
      platformChannelSpecifics,
      payload: 'submission_failed',
    );
  }

  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'general_channel',
      'General Notifications',
      channelDescription: 'General app notifications',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      showWhen: true,
      icon: '@mipmap/ic_launcher',
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

    await _flutterLocalNotificationsPlugin.show(
      id,
      title,
      body,
      platformChannelSpecifics,
      payload: payload,
    );
  }

  Future<void> cancelAllNotifications() async {
    await _flutterLocalNotificationsPlugin.cancelAll();
  }

  Future<void> cancelNotification(int id) async {
    await _flutterLocalNotificationsPlugin.cancel(id);
  }

  // Admin notification methods
  Future<void> saveAdminFCMToken(String adminUid, String token) async {
    try {
      DatabaseReference adminRef = FirebaseDatabase.instance.ref("admins/$adminUid/fcmToken");
      await adminRef.set(token);
      print("Admin FCM Token saved successfully for $adminUid");
    } catch (error) {
      print("Error saving admin FCM token: $error");
    }
  }

  Future<List<String>> getAdminFCMTokens() async {
    try {
      DatabaseReference adminsRef = FirebaseDatabase.instance.ref("admins");
      DatabaseEvent event = await adminsRef.once();
      
      List<String> tokens = [];
      if (event.snapshot.exists) {
        Map<dynamic, dynamic> adminsData = event.snapshot.value as Map<dynamic, dynamic>;
        
        adminsData.forEach((adminId, adminData) {
          if (adminData is Map && adminData['fcmToken'] != null) {
            tokens.add(adminData['fcmToken']);
          }
        });
      }
      
      return tokens;
    } catch (error) {
      print("Error fetching admin FCM tokens: $error");
      return [];
    }
  }

  Future<void> sendPushNotificationToAdmins({
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      List<String> adminTokens = await getAdminFCMTokens();
      
      if (adminTokens.isEmpty) {
        print("No admin tokens found for push notification");
        return;
      }

      // Get FCM server key from environment variables
      final String serverKey = dotenv.env['FCM_SERVER_KEY'] ?? '';
      
      if (serverKey.isEmpty) {
        print("FCM_SERVER_KEY not found in environment variables");
        return;
      }
      
      for (String token in adminTokens) {
        await _sendFCMNotification(
          token: token,
          title: title,
          body: body,
          data: data,
          serverKey: serverKey,
        );
      }
    } catch (error) {
      print("Error sending push notification to admins: $error");
    }
  }

  Future<void> _sendFCMNotification({
    required String token,
    required String title,
    required String body,
    Map<String, dynamic>? data,
    required String serverKey,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('https://fcm.googleapis.com/fcm/send'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'key=$serverKey',
        },
        body: jsonEncode({
          'to': token,
          'notification': {
            'title': title,
            'body': body,
            'sound': 'default',
            'badge': '1',
          },
          'data': data ?? {},
          'priority': 'high',
        }),
      );

      if (response.statusCode == 200) {
        print("FCM notification sent successfully");
      } else {
        print("Failed to send FCM notification: ${response.statusCode}");
        print("Response: ${response.body}");
      }
    } catch (error) {
      print("Error sending FCM notification: $error");
    }
  }

  Future<void> notifyAdminsOfNewComplaint({
    required String issueType,
    required String location,
    required String userName,
    required String complaintId,
  }) async {
    await sendPushNotificationToAdmins(
      title: "🚨 New Complaint Filed",
      body: "$userName reported: $issueType in $location",
      data: {
        'type': 'new_complaint',
        'complaint_id': complaintId,
        'issue_type': issueType,
        'location': location,
        'user_name': userName,
      },
    );
  }
}
