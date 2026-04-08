import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';

// ── Background / killed-state handler ────────────────────────────────────────
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
  FlutterLocalNotificationsPlugin();

  static GlobalKey<NavigatorState>? navigatorKey;

  // All active Firestore subscriptions — cancelled and replaced on each login
  final List<StreamSubscription> _subs = [];

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
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);

    // 2. Initialise flutter_local_notifications
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

    // 3. Request FCM permission
    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    // 4. iOS foreground banners
    await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // 5. Android 13+ local notification permission
    await _plugin
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    // 6. FCM handlers (OS uses these for background/killed delivery)
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    FirebaseMessaging.onMessage.listen(_handleFCMForeground);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleFCMTap);

    // 7. Cold-start tap
    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _handleFCMTap(initial));
    }
  }

  // ── Call on every login ───────────────────────────────────────────────────
  Future<void> onUserLogin() async {
    await saveFcmToken();
    await startFirestoreListeners();
  }

  // ── Save FCM token ────────────────────────────────────────────────────────
  Future<void> saveFcmToken() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    String? token;
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

    // Evict token from any other user doc (shared device protection)
    final stale = await FirebaseFirestore.instance
        .collection('users')
        .where('fcmToken', isEqualTo: token)
        .get();
    for (final doc in stale.docs) {
      if (doc.id != uid) {
        await doc.reference.update({'fcmToken': FieldValue.delete()});
        print("🧹 Cleared stale token from user ${doc.id}");
      }
    }

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

  // ── Firestore real-time listeners (foreground in-app banners) ─────────────
  // Listens directly to source collections so banners fire instantly when
  // the app is open — no server round-trip needed.
  // Each listener skips existing docs on first load (isFirstLoad flag).
  Future<void> startFirestoreListeners() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    // Cancel all previous subscriptions
    for (final sub in _subs) {
      await sub.cancel();
    }
    _subs.clear();

    // Read role from Firestore
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();
    final role = userDoc.data()?['role'] ?? 'mr';

    print("🔔 Starting Firestore listeners for role: $role");

    if (role == 'mr') {
      _listenAsMr(uid);
    } else if (role == 'stockist') {
      _listenAsStockist(uid);
    } else if (role == 'admin') {
      _listenAsAdmin(uid);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // MR LISTENERS — order status changes + leave updates
  // ─────────────────────────────────────────────────────────────────────────
  void _listenAsMr(String uid) {
    final Map<String, String> statusCache = {};
    bool isFirstLoad = true;

    final orderSub = FirebaseFirestore.instance
        .collection('orders')
        .where('mrId', isEqualTo: uid)
        .snapshots()
        .listen((snapshot) {
      if (isFirstLoad) {
        for (final doc in snapshot.docs) {
          statusCache[doc.id] = doc.data()['status'] ?? '';
        }
        isFirstLoad = false;
        return;
      }

      for (final change in snapshot.docChanges) {
        final order = change.doc.data();
        final orderId = change.doc.id;
        final currentStatus = order?['status'] ?? '';
        final doctorName = order?['doctorName'] ?? 'a doctor';

        if (change.type == DocumentChangeType.added) {
          statusCache[orderId] = currentStatus;
          continue;
        }

        if (change.type == DocumentChangeType.modified) {
          final prevStatus = statusCache[orderId];
          if (prevStatus == currentStatus) continue;
          statusCache[orderId] = currentStatus;

          final messages = {
            'approved':   ['✅ Order Approved',   'Your order for Dr. $doctorName has been approved.'],
            'rejected':   ['❌ Order Rejected',   'Your order for Dr. $doctorName was rejected.'],
            'billed':     ['🧾 Order Billed',     'Bill generated for Dr. $doctorName.'],
            'dispatched': ['🚚 Order Dispatched', 'Your order for Dr. $doctorName has been dispatched.'],
            'delivered':  ['✅ Order Delivered',  'Your order for Dr. $doctorName has been delivered.'],
            'cancelled':  ['🚫 Order Cancelled',  'Your order for Dr. $doctorName has been cancelled.'],
          };

          final msg = messages[currentStatus];
          if (msg == null) continue;

          show(
            id: orderId.hashCode,
            title: msg[0],
            body: msg[1],
            payload: {'type': 'order_update', 'orderId': orderId},
          );
        }
      }
    });
    _subs.add(orderSub);

    // Leave request status updates
    bool leaveFirstLoad = true;
    final leaveSub = FirebaseFirestore.instance
        .collection('leave_requests')
        .where('mrId', isEqualTo: uid)
        .snapshots()
        .listen((snapshot) {
      if (leaveFirstLoad) {
        leaveFirstLoad = false;
        return;
      }
      for (final change in snapshot.docChanges) {
        if (change.type != DocumentChangeType.modified) continue;
        final leave = change.doc.data();
        final status = leave?['status'] ?? '';
        final from = leave?['fromDate'] ?? '';
        final to = leave?['toDate'] ?? '';

        if (status == 'approved') {
          show(
            id: change.doc.id.hashCode,
            title: '✅ Leave Approved',
            body: 'Your leave from $from to $to has been approved.',
            payload: {'type': 'leave_update'},
          );
        } else if (status == 'rejected') {
          show(
            id: change.doc.id.hashCode,
            title: '❌ Leave Rejected',
            body: 'Your leave from $from to $to was rejected.',
            payload: {'type': 'leave_update'},
          );
        }
      }
    });
    _subs.add(leaveSub);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // STOCKIST LISTENERS — new orders + low stock alerts
  // ─────────────────────────────────────────────────────────────────────────
  void _listenAsStockist(String uid) {
    bool isFirstLoad = true;

    final orderSub = FirebaseFirestore.instance
        .collection('orders')
        .where('stockistUid', isEqualTo: uid)
        .snapshots()
        .listen((snapshot) {
      if (isFirstLoad) {
        isFirstLoad = false;
        return;
      }
      for (final change in snapshot.docChanges) {
        if (change.type != DocumentChangeType.added) continue;
        final order = change.doc.data();
        show(
          id: change.doc.id.hashCode,
          title: '📦 New Order Received',
          body: 'Order for Dr. ${order?['doctorName'] ?? 'a doctor'} from MR ${order?['mrName'] ?? ''}',
          payload: {'type': 'new_order', 'orderId': change.doc.id},
        );
      }
    });
    _subs.add(orderSub);

    // Stock level monitoring
    final Map<String, dynamic> stockCache = {};
    bool stockFirstLoad = true;

    final stockSub = FirebaseFirestore.instance
        .collection('stockist_stock')
        .doc(uid)
        .snapshots()
        .listen((snapshot) async {
      if (!snapshot.exists) return;
      final currentData = snapshot.data()!;

      if (stockFirstLoad) {
        stockCache.addAll(currentData);
        stockFirstLoad = false;
        return;
      }

      final reminders =
          (currentData['lowStockReminders'] as Map<String, dynamic>?) ?? {};

      for (final entry in currentData.entries) {
        final productId = entry.key;
        if (productId == 'lowStockReminders') continue;
        final newQty = entry.value;
        if (newQty is! num) continue;

        final oldQty = stockCache[productId];
        stockCache[productId] = newQty;
        if (oldQty == null || newQty >= (oldQty as num)) continue;

        final threshold = (reminders[productId] as num?)?.toInt() ?? 10;
        final productDoc = await FirebaseFirestore.instance
            .collection('products')
            .doc(productId)
            .get();
        final productName = productDoc.data()?['name'] ?? 'A product';

        if (newQty == 0) {
          show(
            id: productId.hashCode,
            title: '🚨 Out of Stock!',
            body: '$productName is now completely out of stock.',
            payload: {'type': 'low_stock', 'productId': productId},
          );
        } else if (newQty <= threshold) {
          show(
            id: productId.hashCode,
            title: '⚠️ Low Stock Alert',
            body: '$productName is running low — only $newQty units left.',
            payload: {'type': 'low_stock', 'productId': productId},
          );
        }
      }
    });
    _subs.add(stockSub);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // ADMIN LISTENERS — new orders, status changes, leave, reports
  // ─────────────────────────────────────────────────────────────────────────
  void _listenAsAdmin(String uid) {
    // ── Single listener for both new orders AND status changes ──
    final Map<String, String> statusCache = {};
    bool ordersFirst = true;

    final orderSub = FirebaseFirestore.instance
        .collection('orders')
        .snapshots()
        .listen((snapshot) {
      if (ordersFirst) {
        // Seed status cache on first load — don't fire any notifications
        for (final doc in snapshot.docs) {
          statusCache[doc.id] = doc.data()['status'] ?? '';
        }
        ordersFirst = false;
        return;
      }

      for (final change in snapshot.docChanges) {
        final order = change.doc.data();
        final orderId = change.doc.id;

        if (change.type == DocumentChangeType.added) {
          // Cache the initial status of the new order
          statusCache[orderId] = order?['status'] ?? '';
          show(
            id: orderId.hashCode,
            title: '📋 New Order Placed',
            body: 'MR ${order?['mrName'] ?? ''} placed an order for Dr. ${order?['doctorName'] ?? ''}',
            payload: {'type': 'new_order', 'orderId': orderId},
          );
        }

        if (change.type == DocumentChangeType.modified) {
          final currentStatus = order?['status'] ?? '';
          final prevStatus = statusCache[orderId];
          if (prevStatus == currentStatus) continue;
          statusCache[orderId] = currentStatus;

          final cap = currentStatus.isEmpty
              ? ''
              : currentStatus[0].toUpperCase() + currentStatus.substring(1);
          show(
            id: ('status_$orderId').hashCode,
            title: '📋 Order $cap',
            body: 'Order for Dr. ${order?['doctorName'] ?? ''} by MR ${order?['mrName'] ?? ''} is now $currentStatus.',
            payload: {'type': 'order_update', 'orderId': orderId},
          );
        }
      }
    });
    _subs.add(orderSub); // only ONE sub added, not two


    // New leave requests
    bool leaveFirst = true;
    final leaveSub = FirebaseFirestore.instance
        .collection('leave_requests')
        .snapshots()
        .listen((snapshot) {
      if (leaveFirst) {
        leaveFirst = false;
        return;
      }
      for (final change in snapshot.docChanges) {
        if (change.type != DocumentChangeType.added) continue;
        final leave = change.doc.data();
        show(
          id: change.doc.id.hashCode,
          title: '🗓️ New Leave Request',
          body:
          '${leave?['mrName'] ?? 'An MR'} applied for leave from ${leave?['fromDate'] ?? ''} to ${leave?['toDate'] ?? ''}.',
          payload: {'type': 'leave_request'},
        );
      }
    });
    _subs.add(leaveSub);

    // Daily reports
    bool reportsFirst = true;
    final reportSub = FirebaseFirestore.instance
        .collection('daily_reports')
        .snapshots()
        .listen((snapshot) {
      if (reportsFirst) {
        reportsFirst = false;
        return;
      }
      for (final change in snapshot.docChanges) {
        if (change.type != DocumentChangeType.added) continue;
        final report = change.doc.data();
        show(
          id: change.doc.id.hashCode,
          title: '📝 Daily Report Submitted',
          body:
          '${report?['mrName'] ?? 'An MR'} submitted their report for ${report?['date'] ?? 'today'}.',
          payload: {'type': 'daily_report'},
        );
      }
    });
    _subs.add(reportSub);

    // Stock reports
    bool stockFirst = true;
    final stockSub = FirebaseFirestore.instance
        .collection('stock_reports')
        .snapshots()
        .listen((snapshot) {
      if (stockFirst) {
        stockFirst = false;
        return;
      }
      for (final change in snapshot.docChanges) {
        if (change.type != DocumentChangeType.added) continue;
        final report = change.doc.data();
        show(
          id: change.doc.id.hashCode,
          title: '⚠️ Stock Report Filed',
          body:
          '${report?['reporterName'] ?? 'Stockist'} reported ${(report?['items'] as List?)?.length ?? 0} low/out-of-stock items.',
          payload: {'type': 'stock_report'},
        );
      }
    });
    _subs.add(stockSub);
  }

  // ── Show a local notification banner ──────────────────────────────────────
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

  void _handleFCMTap(RemoteMessage message) {
    _navigate(jsonEncode({...message.data}));
  }

  // ── Navigate on notification tap ──────────────────────────────────────────
  static void _navigate(String? payloadStr) {
    if (payloadStr == null || navigatorKey == null) return;
    try {
      final data = jsonDecode(payloadStr) as Map<String, dynamic>;
      final type = data['type'] as String?;

      final context = navigatorKey!.currentContext;
      if (context == null) {
        WidgetsBinding.instance
            .addPostFrameCallback((_) => _navigate(payloadStr));
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

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _tabIndexNotifier.value = null;
      });
    } catch (_) {}
  }
}