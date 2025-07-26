import 'dart:ui';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

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
  Future<bool> saveAdminFCMToken(String adminUid, String token) async {
    // Input validation
    if (adminUid.isEmpty) {
      throw ArgumentError('Admin UID cannot be empty');
    }
    
    if (token.isEmpty) {
      throw ArgumentError('FCM token cannot be empty');
    }
    
    // Validate UID format (basic Firebase UID format check)
    if (adminUid.length < 10 || adminUid.length > 128) {
      throw ArgumentError('Invalid admin UID format');
    }
    
    // Validate token format (basic FCM token format check)
    if (!token.startsWith(RegExp(r'[a-zA-Z0-9_-]{100,}'))) {
      throw ArgumentError('Invalid FCM token format');
    }
    
    try {
      // Get current user for authentication
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception('No authenticated user found');
      }
      
      // Verify the current user has permission to update this admin's token
      // This could be checking if the user is the admin themselves or has admin privileges
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();
          
      if (!userDoc.exists) {
        throw Exception('User document not found');
      }
      
      final userData = userDoc.data();
      final userRole = userData?['role'] as String?;
      
      // Allow if the user is updating their own token or is an admin
      if (currentUser.uid != adminUid && userRole != 'admin') {
        throw Exception('Insufficient permissions to update admin FCM token');
      }
      
      // Verify the admin exists in the database
      final adminDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(adminUid)
          .get();
          
      if (!adminDoc.exists) {
        throw Exception('Admin user not found');
      }
      
      final adminData = adminDoc.data();
      final adminRole = adminData?['role'] as String?;
      
      if (adminRole != 'admin') {
        throw Exception('Specified user is not an admin');
      }
      
      // All validations passed, save the token


      // Also update in Firestore for consistency
      await FirebaseFirestore.instance
          .collection('users')
          .doc(adminUid)
          .update({'fcmToken': token});
          
      return true;
    } on ArgumentError catch (e) {
      // Re-throw validation errors
      throw ArgumentError('Validation error: ${e.message}');
    } on FirebaseException catch (e) {
      // Handle Firebase-specific errors
      throw Exception('Database error: ${e.message}');
    } catch (e) {
      // Handle other unexpected errors
      throw Exception('Failed to save admin FCM token: ${e.toString()}');
    }
  }

  Future<List<String>> getAdminFCMTokens({int limit = 50, String? lastAdminId}) async {
    try {
      // Use Firestore instead of Realtime Database for better type safety and pagination
      Query query = FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'admin')
          .where('isActive', isEqualTo: true)
          .orderBy(FieldPath.documentId)
          .limit(limit);
      
      // Implement cursor-based pagination if lastAdminId is provided
      if (lastAdminId != null) {
        query = query.startAfter([lastAdminId]);
      }
      
      final QuerySnapshot snapshot = await query.get();
      
      final List<String> tokens = [];
      
      for (final doc in snapshot.docs) {
        final adminData = doc.data() as Map<String, dynamic>;
        final token = adminData['fcmToken'] as String?;
        
        if (token != null && token.isNotEmpty) {
          // Validate token format before adding
          if (_isValidFCMToken(token)) {
            tokens.add(token);
          }
        }
      }
      
      return tokens;
    } on FirebaseException catch (e) {
      print("Firebase error fetching admin FCM tokens: ${e.message}");
      return [];
    } catch (e) {
      print("Error fetching admin FCM tokens: ${e.toString()}");
      return [];
    }
  }
  
  // Helper method to validate FCM token format
  bool _isValidFCMToken(String token) {
    // Basic FCM token validation - typically 152-180 chars, alphanumeric with specific chars
    final tokenRegex = RegExp(r'^[a-zA-Z0-9:_-]{100,}$');
    return tokenRegex.hasMatch(token);
  }
  
  // Alternative method to get tokens with explicit type safety
  Future<List<String>> getAdminFCMTokensSafe() async {
    try {
      final QuerySnapshot snapshot = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'admin')
          .where('isActive', isEqualTo: true)
          .get();
      
      final List<String> tokens = [];
      
      for (final doc in snapshot.docs) {
        final adminData = doc.data() as Map<String, dynamic>;
        
        // Extract data with type safety
        final String? fcmToken = adminData['fcmToken'] as String?;
        final bool? isActive = adminData['isActive'] as bool?;
        final String? role = adminData['role'] as String?;
        
        // Validate admin status and token
        if (role == 'admin' && isActive == true && 
            fcmToken != null && _isValidFCMToken(fcmToken)) {
          tokens.add(fcmToken);
        }
      }
      
      return tokens;
    } catch (e) {
      print("Error fetching admin FCM tokens: $e");
      return [];
    }
  }

  Future<void> sendPushNotificationToAdmins({
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      final admins = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'admin')
          .where('isActive', isEqualTo: true)
          .get();

      for (final admin in admins.docs) {
        final token = admin.data()['fcmToken'] as String?;
        if (token != null && token.isNotEmpty) {
          await _sendNotificationToBackend(
            token: token,
            title: title,
            body: body,
            data: data,
          );
        }
      }
    } catch (e) {
      print("Error sending notifications to admins: $e");
    }
  }

  Future<void> _sendNotificationToBackend({
    required String token,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      // Validate notification content before sending
      if (title.trim().isEmpty) {
        throw ArgumentError('Notification title cannot be empty');
      }
      if (body.trim().isEmpty) {
        throw ArgumentError('Notification body cannot be empty');
      }
      if (data != null && data.keys.any((k) => k.toString().trim().isEmpty)) {
        throw ArgumentError('Notification data contains empty keys');
      }

      // Read backend base URL from environment variables
      final backendBaseUrl = dotenv.env['BACKEND_API_URL'];
      if (backendBaseUrl == null || backendBaseUrl.isEmpty) {
        throw Exception('BACKEND_API_URL is not set in environment variables');
      }

      final uri = Uri.parse('$backendBaseUrl/notifications/send');

      // Retrieve Firebase user auth token at runtime
      final user = FirebaseAuth.instance.currentUser;
      final String? authToken = user != null ? await user.getIdToken() : null;

      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          if (authToken != null) 'Authorization': 'Bearer $authToken',
        },
        body: jsonEncode({
          'targetToken': token,
          'title': title,
          'body': body,
          'data': data ?? {},
          'priority': 'high',
        }),
      );

      if (response.statusCode == 200) {
        print("Notification request sent to backend successfully");
      } else {
        print("Failed to send notification request: ${response.statusCode}");
        print("Response: ${response.body}");
      }
    } catch (error) {
      print("Error sending notification request: $error");
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
