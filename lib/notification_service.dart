import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';

// ── Background / killed-state handler ────────────────────────────────────────
// When the app is KILLED, FCM wakes a separate Dart isolate and calls this.
// Because server.js sends a `notification` block, the OS has already shown
// the notification by the time this runs — we do NOT need to show it again.
// Just initialise Firebase so FCM internals work, then return.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // OS already displayed the notification from the `notification` block.
  // Nothing else needed here.
}

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
    // 1. Create Android notification channel.
    //    This MUST exist before any notification arrives.
    //    The channelId here must match android.notification.channelId in server.js
    //    AND com.google.firebase.messaging.default_notification_channel_id in AndroidManifest.
    const androidChannel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDesc,
      importance: Importance.max,
      playSound: true,
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);

    // 2. Initialise flutter_local_notifications (used for foreground display only)
    const androidSettings =
    AndroidInitializationSettings('@mipmap/ic_launcher');
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

    // 3. Request FCM permission.
    //    On iOS this is mandatory — without it getToken() returns null and
    //    the server has no token to push to.
    //    On Android 13+ this controls the POST_NOTIFICATIONS permission dialog.
    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    // 4. On iOS, FCM hides notification banners when app is foreground by default.
    //    This opts in so banners show even when the app is open.
    await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // 5. Also request local notification permission (Android 13+)
    await _plugin
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    // 6. Register FCM handlers
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    FirebaseMessaging.onMessage.listen(_handleFCMForeground);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleFCMTap);

    // 7. Handle tap when app was launched from a killed-state notification
    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null) {
      // Delay until widget tree is mounted
      WidgetsBinding.instance.addPostFrameCallback((_) => _handleFCMTap(initial));
    }
  }

  // ── Call this on every login (fresh login AND auto-login on app restart) ──
  Future<void> onUserLogin() async {
    await saveFcmToken();
    startFirestoreListeners();
  }

  // ── Save FCM token to Firestore so the server can push to this device ─────
  Future<void> saveFcmToken() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    String? token;

    // 🔥 WAIT until token is available
    for (int i = 0; i < 5; i++) {
      token = await FirebaseMessaging.instance.getToken();
      if (token != null) break;
      await Future.delayed(const Duration(seconds: 1));
    }

    if (token == null) {
      print("❌ FCM TOKEN STILL NULL AFTER RETRY");
      return;
    }

    print("✅ FCM TOKEN: $token");

    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .set({'fcmToken': token}, SetOptions(merge: true));

    // 🔥 VERY IMPORTANT — token refresh
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
      FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .set({'fcmToken': newToken}, SetOptions(merge: true));
    });
  }

  // ── Firestore listeners (in-app display only — app is already open) ───────
  // The server handles FCM push for killed/background state.
  // These listeners are only reached when the app IS open, so showing a
  // local notification here is safe and not a duplicate.
  void startFirestoreListeners() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    // Unread notification docs → show in-app banner for MR
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
  }

  // ── Show a system bar notification (foreground use only) ──────────────────
  Future<void> show({
    required int id,
    required String title,
    required String body,
    Map<String, dynamic>? payload,
  }) async {
    await _plugin.show(
      id,
      title,
      body,
      const NotificationDetails(
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
      ),
      payload: payload != null ? jsonEncode(payload) : null,
    );
  }

  // ── Tap handlers ──────────────────────────────────────────────────────────
  static void _onTap(NotificationResponse response) {
    _navigate(response.payload);
  }

  @pragma('vm:entry-point')
  static void _onTapBackground(NotificationResponse response) {
    _navigate(response.payload);
  }

  // ── FCM foreground: app is open, show manually via flutter_local_notifications
  // Server sends a `notification` block so message.notification is not null.
  void _handleFCMForeground(RemoteMessage message) {
    final title = message.notification?.title ?? message.data['title'] ?? 'Arka';
    final body  = message.notification?.body  ?? message.data['body']  ?? '';
    show(
      id: message.hashCode,
      title: title,
      body: body,
      payload: {...message.data, 'type': message.data['type'] ?? 'general'},
    );
  }

  // ── FCM tap: user tapped notification while app was background/killed ─────
  void _handleFCMTap(RemoteMessage message) {
    _navigate(jsonEncode({...message.data}));
  }

  // ── Navigate to the correct tab based on notification type ────────────────
  static void _navigate(String? payloadStr) {
    if (payloadStr == null || navigatorKey == null) return;
    try {
      final data = jsonDecode(payloadStr) as Map<String, dynamic>;
      final type = data['type'] as String?;

      // If context not ready yet (cold start), retry after next frame
      final context = navigatorKey!.currentContext;
      if (context == null) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _navigate(payloadStr));
        return;
      }

      Navigator.of(context).popUntil((r) => r.isFirst);

      switch (type) {
        case 'low_stock':
          _tabIndexNotifier.value = 2;
          break;
        case 'new_order':
        case 'order_update':
        case 'order_approved':
        case 'order_rejected':
        case 'order_billed':
        case 'order_dispatched':
          _tabIndexNotifier.value = 1;
          break;
        default:
          _tabIndexNotifier.value = 0;
      }
    } catch (_) {}
  }
}