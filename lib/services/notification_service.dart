import 'dart:async';
import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationPayload {
  final String? type;
  final String? chatId;
  final String? groupId;
  final String? senderId;

  const NotificationPayload({
    this.type,
    this.chatId,
    this.groupId,
    this.senderId,
  });

  factory NotificationPayload.fromMap(Map<String, dynamic> map) {
    return NotificationPayload(
      type: map['type']?.toString(),
      chatId: map['chatId']?.toString(),
      groupId: map['groupId']?.toString(),
      senderId: map['senderId']?.toString(),
    );
  }

  Map<String, dynamic> toMap() => {
        'type': type,
        'chatId': chatId,
        'groupId': groupId,
        'senderId': senderId,
      };
}

class NotificationService {
  static NotificationService? _instance;

  static NotificationService? get instance => _instance;

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  final StreamController<NotificationPayload> _tapController =
      StreamController<NotificationPayload>.broadcast();

  Stream<NotificationPayload> get onNotificationTapped => _tapController.stream;

  Future<void> initialize() async {
    _instance = this;

    await _firebaseMessaging.requestPermission();

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    const settings =
        InitializationSettings(android: androidSettings, iOS: iosSettings);

    await _localNotifications.initialize(
      settings,
      onDidReceiveNotificationResponse: (response) {
        final payloadRaw = response.payload;
        if (payloadRaw == null || payloadRaw.isEmpty) return;

        try {
          final payload = NotificationPayload.fromMap(jsonDecode(payloadRaw));
          _tapController.add(payload);
        } catch (_) {
          // Ignore malformed payload.
        }
      },
    );

    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
  }

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    const androidDetails = AndroidNotificationDetails(
      'chat_channel',
      'Chat Notifications',
      importance: Importance.high,
      priority: Priority.high,
    );

    const details = NotificationDetails(android: androidDetails);

    final payload = NotificationPayload.fromMap(message.data);

    await _localNotifications.show(
      message.hashCode,
      message.notification?.title ?? 'New Message',
      message.notification?.body ?? '',
      details,
      payload: jsonEncode(payload.toMap()),
    );
  }

  Future<String?> getFCMToken() async {
    return _firebaseMessaging.getToken();
  }

  Future<void> subscribeToTopic(String topic) async {
    await _firebaseMessaging.subscribeToTopic(topic);
  }

  Future<void> unsubscribeFromTopic(String topic) async {
    await _firebaseMessaging.unsubscribeFromTopic(topic);
  }

  Future<void> sendUrgentNotification(String title, String body) async {
    const androidDetails = AndroidNotificationDetails(
      'urgent_channel',
      'Urgent Notifications',
      importance: Importance.max,
      priority: Priority.max,
      sound: RawResourceAndroidNotificationSound('urgent'),
    );

    const details = NotificationDetails(android: androidDetails);

    await _localNotifications.show(
      1,
      title,
      body,
      details,
    );
  }

  Future<void> sendNewMessageNotification(
      String senderId, String content) async {
    const androidDetails = AndroidNotificationDetails(
      'chat_channel',
      'Chat Notifications',
      importance: Importance.high,
      priority: Priority.high,
    );

    const details = NotificationDetails(android: androidDetails);

    await _localNotifications.show(
      2,
      'New Message from $senderId',
      content,
      details,
      payload: jsonEncode(
        const NotificationPayload(type: 'chat').toMap(),
      ),
    );
  }

  Future<void> sendNewMessageNotificationWithUsername(
    String username,
    String uid,
    String content,
  ) async {
    const androidDetails = AndroidNotificationDetails(
      'chat_channel',
      'Chat Notifications',
      importance: Importance.high,
      priority: Priority.high,
    );

    const details = NotificationDetails(android: androidDetails);

    await _localNotifications.show(
      2,
      'New Message from $username',
      content,
      details,
      payload: jsonEncode(
        NotificationPayload(type: 'chat', senderId: uid).toMap(),
      ),
    );
  }

  Future<void> sendUnblockRequestNotification(String fromUser) async {
    const androidDetails = AndroidNotificationDetails(
      'unblock_request_channel',
      'Unblock Requests',
      importance: Importance.high,
      priority: Priority.high,
    );

    const details = NotificationDetails(android: androidDetails);

    await _localNotifications.show(
      3,
      'Unblock Request',
      'You have received an unblock request from $fromUser.',
      details,
    );
  }

  void dispose() {
    _tapController.close();
  }
}

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {}
