import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {}

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
  FlutterLocalNotificationsPlugin();

  static GlobalKey<NavigatorState>? navigatorKey;

  static const _channelId   = 'arka_high_importance';
  static const _channelName = 'Arka Alerts';
  static const _channelDesc = 'Low stock and order alerts';

  static final ValueNotifier<int?> _tabIndexNotifier = ValueNotifier(null);
  static ValueNotifier<int?> get tabIndexNotifier => _tabIndexNotifier;

  // ── Init — call once from main() ─────────────────────────────────────────
  Future<void> init() async {
    // 1. Create Android notification channel
    const androidChannel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDesc,
      importance: Importance.max,
      playSound: true,
    );
    await _plugin
        .resolvePlatformSpecificImplementation
    <AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);

    // 2. Init plugin settings
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    await _plugin.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
      onDidReceiveNotificationResponse: _onTap,
      onDidReceiveBackgroundNotificationResponse: _onTapBackground,
    );

    // 3. Request permission (Android 13+)
    await _plugin
        .resolvePlatformSpecificImplementation
    <AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    // 4. FCM handlers
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    FirebaseMessaging.onMessage.listen(_handleFCMForeground);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleFCMTap);

    // 5. App launched from killed state via notification tap
    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null) _handleFCMTap(initial);
  }

  // ── Call this right after login ───────────────────────────────────────────
  Future<void> onUserLogin() async {
    await saveFcmToken();
    startFirestoreListeners();
  }

  // ── Save FCM token to Firestore ───────────────────────────────────────────
  Future<void> saveFcmToken() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final token = await FirebaseMessaging.instance.getToken();
    if (token == null) return;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .set({'fcmToken': token}, SetOptions(merge: true));

    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
      FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .set({'fcmToken': newToken}, SetOptions(merge: true));
    });
  }

  // ── Firestore listeners — foreground & background notifications ───────────
  void startFirestoreListeners() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    // Listen for new Firestore notification docs (for MR order updates)
    FirebaseFirestore.instance
        .collection('notifications')
        .where('mrId', isEqualTo: uid)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .listen((snapshot) {
      for (final change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final data = change.doc.data()!;
          show(
            id: change.doc.id.hashCode,
            title: data['title'] ?? 'Arka',
            body: data['body'] ?? '',
            payload: {
              'type': data['type'] ?? 'general',
              'orderId': data['orderId'] ?? '',
            },
          );
        }
      }
    });

    // Listen for new orders (for stockist)
    FirebaseFirestore.instance
        .collection('orders')
        .where('stockistUid', isEqualTo: uid)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .listen((snapshot) {
      for (final change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final data = change.doc.data()!;
          show(
            id: change.doc.id.hashCode,
            title: '📦 New Order Received',
            body:
            'Order for Dr. ${data['doctorName'] ?? ''} from MR ${data['mrName'] ?? ''}',
            payload: {'type': 'new_order', 'orderId': change.doc.id},
          );
        }
      }
    });
  }

  // ── Show system bar notification ──────────────────────────────────────────
  Future<void> show({
    required int id,
    required String title,
    required String body,
    Map<String, dynamic>? payload,
  }) async {
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDesc,
        importance: Importance.max,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );
    await _plugin.show(
      id,
      title,
      body,
      details,
      payload: payload != null ? jsonEncode(payload) : null,
    );
  }

  // ── Notification tap handlers ─────────────────────────────────────────────
  static void _onTap(NotificationResponse response) {
    _navigate(response.payload);
  }

  @pragma('vm:entry-point')
  static void _onTapBackground(NotificationResponse response) {
    _navigate(response.payload);
  }

  static void _navigate(String? payloadStr) {
    if (payloadStr == null || navigatorKey == null) return;
    try {
      final data = jsonDecode(payloadStr) as Map<String, dynamic>;
      final type = data['type'] as String?;
      final context = navigatorKey!.currentContext;
      if (context == null) return;

      Navigator.of(context).popUntil((r) => r.isFirst);

      switch (type) {
        case 'low_stock':
          _tabIndexNotifier.value = 2; // Stock tab
          break;
        case 'new_order':
          _tabIndexNotifier.value = 1; // Orders tab
          break;
        case 'order_update':
        case 'order_approved':
        case 'order_rejected':
        case 'order_billed':
        case 'order_dispatched':
          _tabIndexNotifier.value = 1; // Orders tab (for MR)
          break;
        case 'stock_report':
          _tabIndexNotifier.value = 0; // Dashboard
          break;
        default:
          _tabIndexNotifier.value = 0;
      }
    } catch (_) {}
  }

  // ── FCM foreground ────────────────────────────────────────────────────────
  void _handleFCMForeground(RemoteMessage message) {
    final n = message.notification;
    if (n == null) return;
    show(
      id: message.hashCode,
      title: n.title ?? 'Arka',
      body: n.body ?? '',
      payload: {...message.data, 'type': message.data['type'] ?? 'general'},
    );
  }

  void _handleFCMTap(RemoteMessage message) {
    _navigate(jsonEncode({...message.data}));
  }
}