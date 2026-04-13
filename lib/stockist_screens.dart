import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'auth.dart';
import 'notification_service.dart';
import 'package:flutter/services.dart'; // ensure this is at top

// ─────────────────────────────────────────
// SHARED SAFE STOCK LOADER HELPER
// Always use this to parse stockist_stock docs —
// skips nested maps (e.g. lowStockReminders) safely
// ─────────────────────────────────────────
Map<String, int> _parseStockDoc(Map<String, dynamic> raw) {
  return Map.fromEntries(
    raw.entries
        .where((e) => e.value is num)
        .map((e) => MapEntry(e.key, (e.value as num).toInt())),
  );
}

// ─────────────────────────────────────────
// STOCKIST MAIN SCREEN
// ─────────────────────────────────────────
class StockistMainScreen extends StatefulWidget {
  const StockistMainScreen({super.key});

  @override
  State<StockistMainScreen> createState() => _StockistMainScreenState();
}

class _StockistMainScreenState extends State<StockistMainScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const StockistDashboardScreen(),
    const StockistOrdersScreen(),
    const StockistStockScreen(),
    const StockistProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    NotificationService.tabIndexNotifier.addListener(_onNotificationTab);
  }

  @override
  void dispose() {
    NotificationService.tabIndexNotifier.removeListener(_onNotificationTab);
    super.dispose();
  }

  void _onNotificationTab() {
    final idx = NotificationService.tabIndexNotifier.value;
    if (idx != null && mounted) {
      setState(() => _currentIndex = idx);
      NotificationService.tabIndexNotifier.value = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;

        if (_currentIndex != 0) {
          setState(() => _currentIndex = 0);
        } else {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        body: _screens[_currentIndex],
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (i) => setState(() => _currentIndex = i),
          type: BottomNavigationBarType.fixed,
          selectedItemColor: const Color(0xFF1565C0),
          unselectedItemColor: Colors.grey,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Dashboard'),
            BottomNavigationBarItem(icon: Icon(Icons.receipt_long), label: 'Orders'),
            BottomNavigationBarItem(icon: Icon(Icons.inventory_2), label: 'Stock'),
            BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────
// STOCKIST DASHBOARD
// ─────────────────────────────────────────
class StockistDashboardScreen extends StatefulWidget {
  const StockistDashboardScreen({super.key});

  @override
  State<StockistDashboardScreen> createState() =>
      _StockistDashboardScreenState();
}

class _StockistDashboardScreenState extends State<StockistDashboardScreen> {
  String _stockistName = 'Stockist';
  String _stockistId   = '';
  Map<String, int> _myStock = {};
  bool _stockLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final uid = auth.currentUser?.uid;
    if (uid == null) return;

    final doc = await db.collection('users').doc(uid).get();
    if (mounted) setState(() => _stockistName = doc.data()?['name'] ?? 'Stockist');

    final stockDoc = await db.collection('stockist_stock').doc(uid).get();
    if (mounted) {
      setState(() {
        _stockistId = uid;
        // ✅ SAFE: uses _parseStockDoc to skip nested maps
        _myStock = stockDoc.exists
            ? _parseStockDoc(stockDoc.data() as Map<String, dynamic>)
            : {};
        _stockLoaded = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Stockist Dashboard'),
        actions: [
          StreamBuilder<QuerySnapshot>(
            stream: db
                .collection('notifications')
                .where('mrId', isEqualTo: auth.currentUser?.uid ?? '')
                .where('isRead', isEqualTo: false)
                .snapshots(),
            builder: (context, snap) {
              final unread = snap.hasData ? snap.data!.docs.length : 0;
              return Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications_outlined),
                    onPressed: () => Navigator.push(context,
                        MaterialPageRoute(
                            builder: (_) => const StockistNotificationsScreen())),
                  ),
                  if (unread > 0)
                    Positioned(
                      right: 6, top: 6,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                            color: Colors.red, shape: BoxShape.circle),
                        child: Text(
                          unread > 9 ? '9+' : '$unread',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadProfile,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // ── Welcome banner ─────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [Color(0xFF1565C0), Color(0xFF1E88E5)]),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Welcome 👋',
                    style: TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 4),
                Text(_stockistName,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                const Text('Stockist Portal',
                    style: TextStyle(color: Colors.white60, fontSize: 12)),
              ]),
            ),
            const SizedBox(height: 20),
            const Text('Overview',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),

            // ── Row 1: Pending Orders + Total Products ──────
            Row(children: [
              Expanded(
                child: _stockistId.isEmpty
                    ? _statPlaceholder('Pending Orders', Icons.pending_actions, Colors.orange)
                    : StreamBuilder<QuerySnapshot>(
                  stream: db.collection('orders')
                      .where('stockistId', isEqualTo: _stockistId)
                      .where('status', isEqualTo: 'pending')
                      .snapshots(),
                  builder: (context, snap) => _statBox(
                    label: 'Pending Orders',
                    icon: Icons.pending_actions,
                    color: Colors.orange,
                    count: snap.hasData ? snap.data!.docs.length : 0,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: db.collection('products').snapshots(),
                  builder: (context, snap) => _statBox(
                    label: 'Total Products',
                    icon: Icons.inventory_2,
                    color: Colors.blue,
                    count: snap.hasData ? snap.data!.docs.length : 0,
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 12),

            // ── Row 2: Low Stock (MY stock) + Dispatched ───
            Row(children: [
              Expanded(
                child: !_stockLoaded
                    ? _statPlaceholder('Low Stock', Icons.warning_amber, Colors.red)
                    : StreamBuilder<QuerySnapshot>(
                  stream: db.collection('products').snapshots(),
                  builder: (context, snap) {
                    if (!snap.hasData) {
                      return _statBox(
                          label: 'Low Stock',
                          icon: Icons.warning_amber,
                          color: Colors.red,
                          count: 0);
                    }
                    final lowCount = snap.data!.docs.where((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final myQty = _myStock[doc.id] ?? 0;
                      final minStock = (data['minStock'] as num?)?.toInt() ?? 10;
                      return myQty <= minStock;
                    }).length;
                    return _statBox(
                        label: 'Low Stock',
                        icon: Icons.warning_amber,
                        color: Colors.red,
                        count: lowCount);
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _stockistId.isEmpty
                    ? _statPlaceholder('Dispatched', Icons.local_shipping, Colors.teal)
                    : StreamBuilder<QuerySnapshot>(
                  stream: db.collection('orders')
                      .where('stockistId', isEqualTo: _stockistId)
                      .where('status', isEqualTo: 'dispatched')
                      .snapshots(),
                  builder: (context, snap) => _statBox(
                    label: 'Dispatched',
                    icon: Icons.local_shipping,
                    color: Colors.teal,
                    count: snap.hasData ? snap.data!.docs.length : 0,
                  ),
                ),
              ),
            ]),

            const SizedBox(height: 24),
            const Text('Quick Actions',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.5,
              children: [
                _quickAction(context, 'Manage Orders', Icons.receipt_long,
                    Colors.blue, () {
                      final nav = context.findAncestorStateOfType<_StockistMainScreenState>();
                      nav?.setState(() => nav._currentIndex = 1);
                    }),
                _quickAction(context, 'Manage Stock', Icons.inventory_2,
                    Colors.green, () {
                      final nav = context.findAncestorStateOfType<_StockistMainScreenState>();
                      nav?.setState(() => nav._currentIndex = 2);
                    }),
                _quickAction(context, 'Report Low Stock', Icons.warning_amber,
                    Colors.orange, () {
                      Navigator.push(context, MaterialPageRoute(
                          builder: (_) => const StockistReportLowStockScreen()));
                    }),
                _quickAction(context, 'Add Product', Icons.add_box,
                    Colors.purple, () {
                      Navigator.push(context, MaterialPageRoute(
                          builder: (_) => const StockistAddProductScreen()));
                    }),
              ],
            ),
          ]),
        ),
      ),
    );
  }

  Widget _statBox({
    required String label,
    required IconData icon,
    required Color color,
    required int count,
  }) =>
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(children: [
          Icon(icon, color: color, size: 26),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('$count',
                style: TextStyle(
                    fontSize: 22, fontWeight: FontWeight.bold, color: color)),
            Text(label,
                style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ]),
        ]),
      );

  Widget _statPlaceholder(String label, IconData icon, Color color) =>
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(children: [
          Icon(icon, color: color.withOpacity(0.4), size: 26),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('—',
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: color.withOpacity(0.4))),
            Text(label,
                style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ]),
        ]),
      );

  Widget _quickAction(BuildContext context, String label, IconData icon,
      Color color, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 6),
            Text(label,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w600,
                    fontSize: 13)),
          ]),
        ),
      );
}

// ─────────────────────────────────────────
// STOCKIST ORDERS SCREEN
// ─────────────────────────────────────────
class StockistOrdersScreen extends StatefulWidget {
  const StockistOrdersScreen({super.key});

  @override
  State<StockistOrdersScreen> createState() => _StockistOrdersScreenState();
}

class _StockistOrdersScreenState extends State<StockistOrdersScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _stockistDocId = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _loadStockistId();
  }

  Future<void> _loadStockistId() async {
    final uid = auth.currentUser?.uid;
    if (uid != null) {
      setState(() {
        _stockistDocId = uid;
        _loading = false;
      });
    } else {
      setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'pending':    return Colors.orange;
      case 'approved':   return Colors.blue;
      case 'rejected':   return Colors.red;
      case 'dispatched': return Colors.teal;
      case 'delivered':  return Colors.green;
      case 'cancelled':  return Colors.red;
      default:           return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Order Management')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Order Management'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          indicatorColor: Colors.white,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Pending'),
            Tab(text: 'Approved'),
            Tab(text: 'Rejected'),
            Tab(text: 'Dispatched'),
            Tab(text: 'All'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _StockistOrderTab(statusFilter: 'pending',    statusColor: _statusColor, stockistDocId: _stockistDocId),
          _StockistOrderTab(statusFilter: 'approved',   statusColor: _statusColor, stockistDocId: _stockistDocId),
          _StockistOrderTab(statusFilter: 'rejected',   statusColor: _statusColor, stockistDocId: _stockistDocId),
          _StockistOrderTab(statusFilter: 'dispatched', statusColor: _statusColor, stockistDocId: _stockistDocId),
          _StockistOrderTab(statusFilter: null,         statusColor: _statusColor, stockistDocId: _stockistDocId),
        ],
      ),
    );
  }
}

class _StockistOrderTab extends StatelessWidget {
  final String? statusFilter;
  final Color Function(String) statusColor;
  final String stockistDocId;
  const _StockistOrderTab(
      {required this.statusFilter, required this.statusColor, required this.stockistDocId});

  @override
  Widget build(BuildContext context) {
    final Stream<QuerySnapshot> stream = stockistDocId.isNotEmpty
        ? db.collection('orders').where('stockistId', isEqualTo: stockistDocId).snapshots()
        : db.collection('orders').snapshots();

    return StreamBuilder<QuerySnapshot>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        var docs = (snapshot.data?.docs ?? []).where((d) {
          final data = d.data() as Map<String, dynamic>;
          return statusFilter == null || data['status'] == statusFilter;
        }).toList()
          ..sort((a, b) {
            final aTs = (a.data() as Map)['createdAt'];
            final bTs = (b.data() as Map)['createdAt'];
            if (aTs == null && bTs == null) return 0;
            if (aTs == null) return 1;
            if (bTs == null) return -1;
            return (bTs as Timestamp).compareTo(aTs as Timestamp);
          });

        if (docs.isEmpty) {
          return Center(
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.inbox_outlined, size: 70, color: Colors.grey.shade300),
              const SizedBox(height: 16),
              Text(
                statusFilter != null ? 'No $statusFilter orders' : 'No orders yet',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 16),
              ),
            ]),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: docs.length,
          itemBuilder: (context, i) {
            final doc    = docs[i];
            final data   = doc.data() as Map<String, dynamic>;
            final status = data['status'] ?? 'pending';
            final color  = statusColor(status);
            final items  = (data['items'] as List?)?.length ?? 0;

            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: color.withOpacity(0.15),
                  child: Icon(Icons.receipt_long, color: color),
                ),
                title: Text(
                  'Order for ${data['doctorName'] ?? 'Unknown Doctor'}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  'MR: ${data['mrName'] ?? 'N/A'}  •  $items item(s)  •  ${data['date'] ?? ''}',
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(status.toUpperCase(),
                          style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                    if (data['tier'] != null && data['tier'] != 'Normal')
                      Text(data['tier'],
                          style: TextStyle(color: Colors.purple.shade700, fontSize: 9)),
                  ],
                ),
                onTap: () => showDialog(
                  context: context,
                  builder: (_) => _StockistOrderDetailDialog(
                    orderId: doc.id,
                    data: data,
                    statusColor: statusColor,
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _StockistOrderDetailDialog extends StatefulWidget {
  final String orderId;
  final Map<String, dynamic> data;
  final Color Function(String) statusColor;
  const _StockistOrderDetailDialog(
      {required this.orderId, required this.data, required this.statusColor});

  @override
  State<_StockistOrderDetailDialog> createState() => _StockistOrderDetailDialogState();
}

class _StockistOrderDetailDialogState extends State<_StockistOrderDetailDialog> {
  bool _isProcessing = false;

  String get orderId => widget.orderId;
  Map<String, dynamic> get data => widget.data;
  Color Function(String) get statusColor => widget.statusColor;

  Future<void> _runAction(Future<void> Function() action) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = data['status'] ?? 'pending';
    final color  = statusColor(status);
    final items  = (data['items'] as List?) ?? [];

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.receipt_long, color: color, size: 38),
          const SizedBox(height: 8),
          Text(status.toUpperCase(),
              style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('Doctor: ${data['doctorName'] ?? 'N/A'}',
              style: const TextStyle(fontWeight: FontWeight.w600)),
          Text('MR: ${data['mrName'] ?? 'N/A'}',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
          Text('Date: ${data['date'] ?? 'N/A'}',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
          if (data['orderValue'] != null)
            Text('Order Value: ₹${data['orderValue']}',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          if (data['tier'] != null && data['tier'] != 'Normal')
            Container(
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.purple.shade50,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text('Tier: ${data['tier']}',
                  style: TextStyle(color: Colors.purple.shade700, fontSize: 11)),
            ),
          if (data['remarks'] != null && data['remarks'].toString().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text('Remarks: ${data['remarks']}',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
          ],
          if (status == 'rejected' && data['rejectionReason'] != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('Rejected: ${data['rejectionReason']}',
                  style: TextStyle(color: Colors.red.shade700, fontSize: 12)),
            ),
          ],
          const SizedBox(height: 12),
          const Divider(),
          ...items.map((item) => ListTile(
            dense: true,
            leading: const Icon(Icons.medication, color: Color(0xFF1565C0)),
            title: Text(item['productName'] ?? ''),
            subtitle: Text('₹${item['price'] ?? 'N/A'}'),
            trailing: Text('×${item['quantity']}',
                style: const TextStyle(fontWeight: FontWeight.bold)),
          )),
          const Divider(),
          Wrap(spacing: 8, runSpacing: 8, children: [
            if (status == 'pending') ...[
              _actionBtn('Approve', Colors.blue, () => _runAction(() async {
                final stockistUid = data['stockistUid']?.toString() ??
                    auth.currentUser?.uid ?? '';

                try {
                  // ── PRE-CHECK: verify sufficient stock ──────────────
                  final stockDoc = await db
                      .collection('stockist_stock')
                      .doc(stockistUid)
                      .get();
                  // ✅ SAFE cast using helper
                  final stockData = stockDoc.exists
                      ? _parseStockDoc(stockDoc.data() as Map<String, dynamic>)
                      : <String, int>{};

                  final List<String> insufficientItems = [];
                  for (final item in items) {
                    final pid = item['productId']?.toString() ?? '';
                    if (pid.isEmpty) continue;
                    final available = stockData[pid] ?? 0;
                    final ordered   = (item['quantity'] as num?)?.toInt() ?? 0;
                    if (available < ordered) {
                      insufficientItems.add(
                          '${item['productName'] ?? pid}: need $ordered, have $available'
                      );
                    }
                  }

                  if (insufficientItems.isNotEmpty) {
                    if (context.mounted) {
                      showDialog(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: const Row(children: [
                            Icon(Icons.warning_amber, color: Colors.orange),
                            SizedBox(width: 8),
                            Flexible(child: Text('Insufficient Stock')),
                          ]),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Cannot approve — the following items don\'t have enough stock:',
                                style: TextStyle(fontSize: 13, color: Colors.grey),
                              ),
                              const SizedBox(height: 12),
                              ...insufficientItems.map((msg) => Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Row(children: [
                                  const Icon(Icons.remove_circle,
                                      color: Colors.red, size: 16),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(msg,
                                        style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600)),
                                  ),
                                ]),
                              )),
                            ],
                          ),
                          actions: [
                            ElevatedButton(
                              onPressed: () => Navigator.pop(context),
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.orange),
                              child: const Text('OK'),
                            ),
                          ],
                        ),
                      );
                    }
                    return;
                  }

                  // ── Stock is sufficient, proceed ────────────────────
                  await db.runTransaction((txn) async {
                    final stockRef = db.collection('stockist_stock').doc(stockistUid);
                    final stockDocTxn = await txn.get(stockRef);
                    // ✅ SAFE: only update numeric product entries
                    final stockDataTxn = stockDocTxn.exists
                        ? _parseStockDoc(stockDocTxn.data() as Map<String, dynamic>)
                        : <String, int>{};

                    final updatedStock = <String, dynamic>{};
                    // Preserve ALL existing fields (including non-numeric like lowStockReminders
                    // if any remain — though after migration they won't be here)
                    if (stockDocTxn.exists) {
                      updatedStock.addAll(stockDocTxn.data() as Map<String, dynamic>);
                    }
                    // Only update the product quantities
                    for (final item in items) {
                      final pid = item['productId']?.toString() ?? '';
                      if (pid.isEmpty) continue;
                      final currentQty = stockDataTxn[pid] ?? 0;
                      final ordered = (item['quantity'] as num?)?.toInt() ?? 0;
                      updatedStock[pid] = (currentQty - ordered).clamp(0, 999999);
                    }

                    if (stockDocTxn.exists) {
                      txn.update(stockRef, updatedStock);
                    } else {
                      txn.set(stockRef, updatedStock);
                    }

                    txn.update(db.collection('orders').doc(orderId), {
                      'status': 'approved',
                      'approvedAt': FieldValue.serverTimestamp(),
                      'approvedBy': auth.currentUser?.uid,
                    });
                  });

                  final commDocs = await db.collection('allowances')
                      .where('orderId', isEqualTo: orderId)
                      .get();
                  for (final doc in commDocs.docs) {
                    await doc.reference.update({'pending': false});
                  }

                  final mrId = data['mrId']?.toString() ?? '';
                  if (mrId.isNotEmpty) {
                    await db.collection('notifications').add({
                      'mrId':      mrId,
                      'title':     'Order Approved ✅',
                      'body':      'Your order for ${data['doctorName'] ?? 'doctor'} has been approved. Stock deducted.',
                      'type':      'order_approved',
                      'orderId':   orderId,
                      'isRead':    false,
                      'createdAt': FieldValue.serverTimestamp(),
                    });
                  }
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('✅ Order approved & stock deducted!'),
                            backgroundColor: Colors.green));
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text('Error: $e'),
                        backgroundColor: Colors.red));
                  }
                }
              })),
              _actionBtn('Reject', Colors.red, () => _runAction(() async {
                final reasonCtrl = TextEditingController();
                final reason = await showDialog<String>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Reject Order'),
                    content: Column(mainAxisSize: MainAxisSize.min, children: [
                      const Text('Provide a reason for rejection:',
                          style: TextStyle(color: Colors.grey, fontSize: 13)),
                      const SizedBox(height: 12),
                      TextField(
                        controller: reasonCtrl,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Reason',
                          hintText: 'e.g. Insufficient stock, item discontinued...',
                          prefixIcon: Icon(Icons.comment),
                        ),
                      ),
                    ]),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel')),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context, reasonCtrl.text.trim()),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                        child: const Text('Reject'),
                      ),
                    ],
                  ),
                );
                if (reason != null) {
                  await db.collection('orders').doc(orderId).update({
                    'status': 'rejected',
                    'rejectionReason': reason,
                    'rejectedAt': FieldValue.serverTimestamp(),
                    'rejectedBy': auth.currentUser?.uid,
                  });
                  final commDocs = await db.collection('allowances')
                      .where('orderId', isEqualTo: orderId)
                      .get();
                  for (final doc in commDocs.docs) {
                    await doc.reference.delete();
                  }
                  final mrId = data['mrId']?.toString() ?? '';
                  if (mrId.isNotEmpty) {
                    await db.collection('notifications').add({
                      'mrId':      mrId,
                      'title':     'Order Rejected ❌',
                      'body':      'Your order for ${data['doctorName'] ?? 'doctor'} was rejected.${reason.isNotEmpty ? ' Reason: $reason' : ''}',
                      'type':      'order_cancelled',
                      'orderId':   orderId,
                      'isRead':    false,
                      'createdAt': FieldValue.serverTimestamp(),
                    });
                  }
                  if (context.mounted) Navigator.pop(context);
                }
              })),
            ],
            if (status == 'approved')
              _actionBtn('Mark Dispatched', Colors.teal, () => _runAction(() async {
                await db.collection('orders').doc(orderId).update({
                  'status':       'dispatched',
                  'dispatchedAt': FieldValue.serverTimestamp(),
                });
                final mrId = data['mrId']?.toString() ?? '';
                if (mrId.isNotEmpty) {
                  await db.collection('notifications').add({
                    'mrId':      mrId,
                    'title':     'Order Dispatched 🚚',
                    'body':      'Your order has been dispatched.',
                    'type':      'order_dispatched',
                    'orderId':   orderId,
                    'isRead':    false,
                    'createdAt': FieldValue.serverTimestamp(),
                  });
                }
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('✅ Order dispatched!'),
                          backgroundColor: Colors.teal));
                }
              })),
            if (status == 'dispatched')
              _actionBtn('Mark Delivered', Colors.green, () => _runAction(() async {
                await db.collection('orders').doc(orderId)
                    .update({'status': 'delivered'});
                if (context.mounted) Navigator.pop(context);
              })),
            OutlinedButton(
              onPressed: _isProcessing ? null : () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ]),
        ]),
      ),
    );
  }

  Widget _actionBtn(String label, Color color, VoidCallback onPressed) =>
      ElevatedButton(
        onPressed: _isProcessing ? null : onPressed,
        style: ElevatedButton.styleFrom(
            backgroundColor: color, foregroundColor: Colors.white),
        child: _isProcessing
            ? const SizedBox(
            width: 16, height: 16,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : Text(label),
      );
}

// ─────────────────────────────────────────
// STOCKIST STOCK SCREEN
// ─────────────────────────────────────────
class StockistStockScreen extends StatefulWidget {
  const StockistStockScreen({super.key});

  @override
  State<StockistStockScreen> createState() => _StockistStockScreenState();
}

class _StockistStockScreenState extends State<StockistStockScreen> {
  String _search    = '';
  String _filterDiv = 'All';
  final List<String> _divisions = ['All', 'Ortho', 'Gynec', 'General'];

  Map<String, int> _stockistStockData = {};
  bool _loadingStock = true;

  @override
  void initState() {
    super.initState();
    _loadStockistStock();
  }

  Future<void> _loadStockistStock() async {
    final uid = auth.currentUser?.uid;
    if (uid == null) return;

    try {
      final doc = await db.collection('stockist_stock').doc(uid).get();
      if (mounted) {
        setState(() {
          // ✅ SAFE: uses _parseStockDoc helper
          _stockistStockData = doc.exists
              ? _parseStockDoc(doc.data() as Map<String, dynamic>)
              : {};
          _loadingStock = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading stock: $e');
      if (mounted) setState(() => _loadingStock = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Stock'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add Stock / Product',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const StockistAddProductScreen()),
            ).then((_) => _loadStockistStock()),
          ),
        ],
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            onChanged: (v) => setState(() => _search = v.toLowerCase()),
            decoration: InputDecoration(
              hintText: 'Search products...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _search.isNotEmpty
                  ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () => setState(() => _search = ''))
                  : null,
            ),
          ),
        ),
        SizedBox(
          height: 40,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: _divisions.length,
            itemBuilder: (_, i) {
              final d = _divisions[i];
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(d),
                  selected: _filterDiv == d,
                  onSelected: (_) => setState(() => _filterDiv = d),
                  selectedColor: const Color(0xFF1565C0).withOpacity(0.2),
                  checkmarkColor: const Color(0xFF1565C0),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _loadingStock
              ? const Center(child: CircularProgressIndicator())
              : StreamBuilder<QuerySnapshot>(
            stream: db.collection('products').orderBy('name').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Center(
                  child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inventory_2_outlined,
                            size: 80, color: Colors.grey.shade300),
                        const SizedBox(height: 16),
                        Text('No products yet',
                            style: TextStyle(
                                color: Colors.grey.shade500, fontSize: 16)),
                      ]),
                );
              }

              final products = snapshot.data!.docs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final name = (data['name'] ?? '').toString().toLowerCase();
                final div  = (data['division'] ?? '').toString();
                return (_search.isEmpty || name.contains(_search)) &&
                    (_filterDiv == 'All' || div == _filterDiv);
              }).toList();

              int total = products.length;
              int low = 0;
              int out = 0;
              for (final p in products) {
                final stock = _stockistStockData[p.id] ?? 0;
                final minStock =
                    ((p.data() as Map<String, dynamic>)['minStock'] as num?)
                        ?.toInt() ?? 10;
                if (stock == 0) {
                  out++;
                } else if (stock <= minStock) {
                  low++;
                }
              }

              return Column(children: [
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _summaryChip('Total', '$total', Colors.blue),
                      _summaryChip('Low Stock', '$low', Colors.orange),
                      _summaryChip('Out of Stock', '$out', Colors.red),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: products.length,
                    itemBuilder: (context, i) {
                      final data = products[i].data() as Map<String, dynamic>;
                      final docId = products[i].id;
                      final stockistQty = _stockistStockData[docId] ?? 0;
                      return _StockistProductCard(
                        data: data,
                        docId: docId,
                        stockistQty: stockistQty,
                        onStockUpdated: _loadStockistStock,
                      );
                    },
                  ),
                ),
              ]);
            },
          ),
        ),
      ]),
    );
  }

  Widget _summaryChip(String label, String value, Color color) =>
      Column(children: [
        Text(value,
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ]);
}

class _StockistProductCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final String docId;
  final int stockistQty;
  final VoidCallback onStockUpdated;

  const _StockistProductCard({
    required this.data,
    required this.docId,
    required this.stockistQty,
    required this.onStockUpdated,
  });

  Color _divColor(String div) {
    switch (div) {
      case 'Ortho': return Colors.blue;
      case 'Gynec': return Colors.pink;
      default:      return Colors.green;
    }
  }

  void _showUpdateStock(BuildContext context) {
    final ctrl = TextEditingController(text: '$stockistQty');
    final uid  = auth.currentUser!.uid;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Update My Stock'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Current stock: $stockistQty units',
              style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 12),
          TextField(
            controller: ctrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'New Stock Quantity',
              prefixIcon: Icon(Icons.inventory),
            ),
          ),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final newStock = int.tryParse(ctrl.text.trim()) ?? 0;
              await db.collection('stockist_stock').doc(uid).set(
                {docId: newStock},
                SetOptions(merge: true),
              );
              if (context.mounted) {
                Navigator.pop(context);
                onStockUpdated();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('✅ Stock updated!'),
                      backgroundColor: Colors.green),
                );
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  void _showSetLowStockReminder(BuildContext context) async {
    final uid = auth.currentUser!.uid;

    // ✅ Read from separate stockist_reminders collection
    final reminderDoc = await db.collection('stockist_reminders').doc(uid).get();
    final savedThreshold = reminderDoc.exists
        ? (reminderDoc.data() as Map<String, dynamic>)[docId]
        : null;
    final ctrl = TextEditingController(
        text: '${savedThreshold ?? (data['minStock'] as num?)?.toInt() ?? 10}');

    if (!context.mounted) return;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Row(children: [
          Icon(Icons.notifications_active, color: Colors.orange),
          SizedBox(width: 8),
          Flexible(child: Text('Low Stock Reminder')),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(
            'Set the minimum quantity for "${data['name']}" before you get a low-stock warning.',
            style: const TextStyle(color: Colors.grey, fontSize: 13),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: ctrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Alert me when stock falls below',
              prefixIcon: Icon(Icons.warning_amber, color: Colors.orange),
              suffixText: 'units',
            ),
          ),
        ]),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            onPressed: () async {
              final threshold = int.tryParse(ctrl.text.trim());
              if (threshold == null || threshold < 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Enter a valid number')),
                );
                return;
              }
              // ✅ Write to SEPARATE collection — never pollutes stockist_stock
              await db.collection('stockist_reminders').doc(uid).set(
                {docId: threshold},
                SetOptions(merge: true),
              );
              await NotificationService.instance.show(
                id: docId.hashCode,
                title: '🔔 Low Stock Reminder Set',
                body: '"${data['name']}" will alert when stock drops below $threshold units.',
                payload: {'type': 'low_stock', 'productId': docId},
              );
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                        '🔔 Reminder set: alert when "${data['name']}" drops below $threshold units'),
                    backgroundColor: Colors.orange,
                  ),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final div      = data['division'] ?? 'General';
    final color    = _divColor(div);
    final minStock = (data['minStock'] as num?)?.toInt() ?? 10;
    final isOut    = stockistQty == 0;
    final isLow    = stockistQty > 0 && stockistQty <= minStock;

    Color stockColor = Colors.green;
    String stockLabel = 'In Stock';
    if (isOut)      { stockColor = Colors.red;    stockLabel = 'Out of Stock'; }
    else if (isLow) { stockColor = Colors.orange; stockLabel = 'Low Stock'; }

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.medication, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(data['name'] ?? '',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                Text('Code: ${data['code'] ?? 'N/A'}',
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
              ]),
            ),
            PopupMenuButton(
              icon: const Icon(Icons.more_vert),
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'update',   child: Text('Update My Stock')),
                PopupMenuItem(value: 'reminder', child: Text('Set Low Stock Reminder')),
                PopupMenuItem(value: 'edit',     child: Text('Edit Product Info')),
              ],
              onSelected: (value) {
                if (value == 'update') {
                  _showUpdateStock(context);
                } else if (value == 'reminder') {
                  _showSetLowStockReminder(context);
                } else if (value == 'edit') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => StockistAddProductScreen(
                          existingData: data, docId: docId),
                    ),
                  );
                }
              },
            ),
          ]),
          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 10),
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(div,
                  style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: stockColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(stockLabel,
                  style: TextStyle(color: stockColor, fontSize: 11, fontWeight: FontWeight.w600)),
            ),
            const Spacer(),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('$stockistQty units',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: stockColor, fontSize: 14)),
              Text('₹${data['price'] ?? '0'} | ${data['packSize'] ?? 'N/A'}',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
            ]),
          ]),
          if (isLow || isOut) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const StockistReportLowStockScreen())),
                icon: const Icon(Icons.warning_amber, size: 16),
                label: const Text('Report to Admin'),
                style: OutlinedButton.styleFrom(
                    foregroundColor: stockColor,
                    side: BorderSide(color: stockColor)),
              ),
            ),
          ],
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────
// STOCKIST ADD / EDIT PRODUCT SCREEN
// ─────────────────────────────────────────
class StockistAddProductScreen extends StatefulWidget {
  final Map<String, dynamic>? existingData;
  final String? docId;

  const StockistAddProductScreen({super.key, this.existingData, this.docId});

  @override
  State<StockistAddProductScreen> createState() =>
      _StockistAddProductScreenState();
}

class _StockistAddProductScreenState extends State<StockistAddProductScreen> {
  final _nameController        = TextEditingController();
  final _codeController        = TextEditingController();
  final _priceController       = TextEditingController();
  final _packSizeController    = TextEditingController();
  final _descriptionController = TextEditingController();
  final _stockQtyController    = TextEditingController();

  String _selectedDivision = 'Ortho';
  bool _isLoading  = false;
  String _errorMessage = '';
  bool get _isEditing => widget.existingData != null;
  final List<String> _divisions = ['Ortho', 'Gynec', 'General'];

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final d = widget.existingData!;
      _nameController.text        = d['name']        ?? '';
      _codeController.text        = d['code']        ?? '';
      _priceController.text       = '${d['price']    ?? ''}';
      _packSizeController.text    = d['packSize']     ?? '';
      _descriptionController.text = d['description'] ?? '';
      _selectedDivision           = d['division']    ?? 'Ortho';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    _priceController.dispose();
    _packSizeController.dispose();
    _descriptionController.dispose();
    _stockQtyController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    final code = _codeController.text.trim();

    if (name.isEmpty || code.isEmpty) {
      setState(() => _errorMessage = 'Product name and code are required.');
      return;
    }

    setState(() { _isLoading = true; _errorMessage = ''; });

    try {
      final uid = auth.currentUser!.uid;

      final productData = {
        'name':        name,
        'code':        code,
        'price':       _priceController.text.trim(),
        'packSize':    _packSizeController.text.trim(),
        'division':    _selectedDivision,
        'description': _descriptionController.text.trim(),
        'updatedAt':   FieldValue.serverTimestamp(),
      };

      String productId;

      if (_isEditing) {
        await db.collection('products').doc(widget.docId).update(productData);
        productId = widget.docId!;
      } else {
        productData['stock']     = 0;
        productData['minStock']  = 10;
        productData['createdAt'] = FieldValue.serverTimestamp();
        productData['createdBy'] = uid;
        final ref = await db.collection('products').add(productData);
        productId = ref.id;
      }

      final qtyText = _stockQtyController.text.trim();
      if (qtyText.isNotEmpty) {
        final qty = int.tryParse(qtyText) ?? 0;
        // ✅ Only writes a flat numeric value — safe
        await db.collection('stockist_stock').doc(uid).set(
          {productId: qty},
          SetOptions(merge: true),
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_isEditing ? '✅ Product updated!' : '✅ Product added!'),
          backgroundColor: Colors.green,
        ));
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to save. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: Text(_isEditing ? 'Edit Product' : 'Add Product & Stock')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: const Row(children: [
                Icon(Icons.info_outline, color: Colors.blue, size: 16),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Product info is shared. Your stock quantity is private — only you and admin can see it.',
                    style: TextStyle(fontSize: 12, color: Colors.blue),
                  ),
                ),
              ]),
            ),
            const Text('Division', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Row(
              children: _divisions.map((div) {
                final isSelected = _selectedDivision == div;
                Color color;
                switch (div) {
                  case 'Ortho': color = Colors.blue;  break;
                  case 'Gynec': color = Colors.pink;  break;
                  default:      color = Colors.green;
                }
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedDivision = div),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? color.withOpacity(0.15)
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected ? color : Colors.grey.shade300,
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Text(
                          div,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: isSelected ? color : Colors.grey,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            _field('Product Name *', _nameController,
                Icons.medication, 'e.g. CalciMax Tablet'),
            _field('Product Code *', _codeController,
                Icons.qr_code, 'e.g. ARK-001'),
            _field('Price (₹)', _priceController,
                Icons.currency_rupee, 'e.g. 150',
                type: TextInputType.number),
            _field('Pack Size', _packSizeController,
                Icons.inventory_2, 'e.g. 10x10, 30ml'),
            _field('Description', _descriptionController,
                Icons.description, 'Optional description',
                maxLines: 2),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.teal.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.teal.shade200),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Row(children: [
                  Icon(Icons.store, color: Colors.teal, size: 18),
                  SizedBox(width: 8),
                  Text('My Stock Quantity',
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal)),
                ]),
                const SizedBox(height: 4),
                const Text(
                  'This is only visible to you and admin.',
                  style: TextStyle(fontSize: 11, color: Colors.teal),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _stockQtyController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    hintText: _isEditing
                        ? 'Leave blank to keep current stock'
                        : 'Enter your quantity (e.g. 50)',
                    prefixIcon: const Icon(Icons.numbers),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 20),
            if (_errorMessage.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(10),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Text(_errorMessage,
                    style: const TextStyle(color: Colors.red, fontSize: 13)),
              ),
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton.icon(
              onPressed: _save,
              icon: Icon(_isEditing ? Icons.save : Icons.add),
              label: Text(
                _isEditing ? 'Update Product' : 'Add Product',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _field(String label, TextEditingController controller,
      IconData icon, String hint, {
        TextInputType type = TextInputType.text,
        int maxLines = 1,
      }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: type,
          maxLines: maxLines,
          decoration: InputDecoration(hintText: hint, prefixIcon: Icon(icon)),
        ),
        const SizedBox(height: 14),
      ],
    );
  }
}

// ─────────────────────────────────────────
// STOCKIST REPORT LOW STOCK SCREEN
// ─────────────────────────────────────────
class StockistReportLowStockScreen extends StatefulWidget {
  const StockistReportLowStockScreen({super.key});

  @override
  State<StockistReportLowStockScreen> createState() =>
      _StockistReportLowStockScreenState();
}

class _StockistReportLowStockScreenState
    extends State<StockistReportLowStockScreen> {
  final _notesCtrl = TextEditingController();
  final Map<String, String> _stockStatus = {};
  bool _submitting = false;
  Map<String, int> _stockistStockData = {};

  @override
  void initState() {
    super.initState();
    // Migrate first (idempotent), then load
    _migrateReminders().then((_) => _loadStockistStock());
  }

  // ── One-time migration — safe to call repeatedly ──────────────
  Future<void> _migrateReminders() async {
    try {
      final uid = auth.currentUser?.uid;
      if (uid == null) return;

      final stockDoc = await db.collection('stockist_stock').doc(uid).get();
      if (!stockDoc.exists) return;

      final data = stockDoc.data() as Map<String, dynamic>;
      if (!data.containsKey('lowStockReminders')) return;

      final reminders = data['lowStockReminders'];
      if (reminders is! Map) return;

      await db.collection('stockist_reminders').doc(uid).set(
        Map<String, dynamic>.from(reminders),
        SetOptions(merge: true),
      );

      await db.collection('stockist_stock').doc(uid).update({
        'lowStockReminders': FieldValue.delete(),
      });

      debugPrint('✅ Reminders migrated for: $uid');
    } catch (e) {
      debugPrint('Migration error (non-fatal): $e');
    }
  }

  // ── Safe stock loader ─────────────────────────────────────────
  Future<void> _loadStockistStock() async {
    final uid = auth.currentUser?.uid;
    if (uid == null) return;
    try {
      final doc = await db.collection('stockist_stock').doc(uid).get();
      if (mounted) {
        setState(() {
          // ✅ SAFE: uses _parseStockDoc helper
          _stockistStockData = doc.exists
              ? _parseStockDoc(doc.data() as Map<String, dynamic>)
              : {};
        });
      }
    } catch (e) {
      debugPrint('Error loading stock: $e');
    }
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final reported = _stockStatus.entries
        .where((e) => e.value == 'low' || e.value == 'out')
        .toList();
    if (reported.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Mark at least one product as Low or Out.')));
      return;
    }
    setState(() => _submitting = true);
    try {
      final uid     = auth.currentUser!.uid;
      final userDoc = await db.collection('users').doc(uid).get();
      final name    = userDoc.data()?['name'] ?? 'Stockist';
      final now     = DateTime.now();
      final dateKey =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      await db.collection('stock_reports').add({
        'reportedBy':   uid,
        'reporterName': name,
        'reporterRole': 'stockist',
        'items': reported
            .map((e) => {'productId': e.key, 'status': e.value})
            .toList(),
        'notes':     _notesCtrl.text.trim(),
        'date':      dateKey,
        'isRead':    false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('✅ Report sent to admin!'),
          backgroundColor: Colors.green,
        ));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Report Low / Out-of-Stock')),
      body: Column(children: [
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: db.collection('products').orderBy('name').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final products = snapshot.data?.docs ?? [];

              return ListView(padding: const EdgeInsets.all(16), children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: const Row(children: [
                    Icon(Icons.info_outline, color: Colors.orange, size: 16),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Mark products that are low or out of stock. Admin will be notified.',
                        style: TextStyle(fontSize: 12, color: Colors.orange),
                      ),
                    ),
                  ]),
                ),
                ...products.map((p) {
                  final data   = p.data() as Map<String, dynamic>;
                  final stock  = _stockistStockData[p.id] ?? 0;
                  final status = _stockStatus[p.id];

                  Color divColor;
                  switch (data['division'] ?? '') {
                    case 'Ortho': divColor = Colors.blue; break;
                    case 'Gynec': divColor = Colors.pink; break;
                    default:      divColor = Colors.green;
                  }

                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      child: Row(children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: divColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.medication, color: divColor, size: 20),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(data['name'] ?? '',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13)),
                                Text('My Stock: $stock units',
                                    style: TextStyle(
                                        color: stock == 0
                                            ? Colors.red
                                            : Colors.grey.shade600,
                                        fontSize: 11)),
                              ]),
                        ),
                        Row(children: [
                          _chip('Low', status == 'low', Colors.orange,
                                  () => setState(() {
                                if (status == 'low') {
                                  _stockStatus.remove(p.id);
                                } else {
                                  _stockStatus[p.id] = 'low';
                                }
                              })),
                          const SizedBox(width: 6),
                          _chip('Out', status == 'out', Colors.red,
                                  () => setState(() {
                                if (status == 'out') {
                                  _stockStatus.remove(p.id);
                                } else {
                                  _stockStatus[p.id] = 'out';
                                }
                              })),
                        ]),
                      ]),
                    ),
                  );
                }),
                const SizedBox(height: 16),
                const Text('Additional Notes (optional)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 8),
                TextField(
                  controller: _notesCtrl,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'Any info for admin...',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 80),
              ]);
            },
          ),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          child: SafeArea(
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _submitting ? null : _submit,
                icon: _submitting
                    ? const SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.send),
                label: const Text('Send Report to Admin'),
              ),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _chip(String label, bool selected, Color color, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: selected ? color.withOpacity(0.15) : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: selected ? color : Colors.grey.shade300, width: 1.5),
          ),
          child: Text(label,
              style: TextStyle(
                  color: selected ? color : Colors.grey.shade500,
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal)),
        ),
      );
}

// ─────────────────────────────────────────
// STOCKIST NOTIFICATIONS SCREEN
// ─────────────────────────────────────────
class StockistNotificationsScreen extends StatelessWidget {
  const StockistNotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = auth.currentUser?.uid ?? '';
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          TextButton(
            onPressed: () async {
              final unread = await db
                  .collection('notifications')
                  .where('mrId', isEqualTo: uid)
                  .where('isRead', isEqualTo: false)
                  .get();
              for (final doc in unread.docs) {
                await doc.reference.update({'isRead': true});
              }
            },
            child: const Text('Mark all read',
                style: TextStyle(color: Colors.white, fontSize: 13)),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: db
            .collection('notifications')
            .where('mrId', isEqualTo: uid)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.notifications_none,
                    size: 80, color: Colors.grey.shade300),
                const SizedBox(height: 16),
                Text('No notifications yet',
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 16)),
              ]),
            );
          }
          final docs = snapshot.data!.docs;
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            itemBuilder: (context, i) {
              final data   = docs[i].data() as Map<String, dynamic>;
              final isRead = data['isRead'] as bool? ?? false;
              final type   = data['type'] as String? ?? '';

              Color iconColor;
              IconData iconData;
              switch (type) {
                case 'new_order':
                  iconColor = Colors.blue;
                  iconData  = Icons.shopping_cart;
                  break;
                default:
                  iconColor = Colors.orange;
                  iconData  = Icons.notifications;
              }

              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                color: isRead ? Colors.white : Colors.blue.shade50,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: iconColor.withOpacity(0.15),
                    child: Icon(iconData, color: iconColor, size: 20),
                  ),
                  title: Text(data['title'] ?? '',
                      style: TextStyle(
                          fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                          fontSize: 14)),
                  subtitle: Text(data['body'] ?? '',
                      style: const TextStyle(fontSize: 12)),
                  trailing: isRead
                      ? null
                      : Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                        color: Colors.blue, shape: BoxShape.circle),
                  ),
                  onTap: () async {
                    if (!isRead) {
                      await docs[i].reference.update({'isRead': true});
                    }
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────
// STOCKIST PROFILE SCREEN
// ─────────────────────────────────────────
class StockistProfileScreen extends StatelessWidget {
  const StockistProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = auth.currentUser?.uid ?? '';
    return Scaffold(
      appBar: AppBar(title: const Text('My Profile')),
      body: FutureBuilder<DocumentSnapshot>(
        future: db.collection('users').doc(uid).get(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final u = snap.data?.data() as Map<String, dynamic>? ?? {};
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [Color(0xFF1565C0), Color(0xFF1E88E5)]),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(children: [
                  const CircleAvatar(
                    radius: 38,
                    backgroundColor: Colors.white24,
                    child: Icon(Icons.store, size: 44, color: Colors.white),
                  ),
                  const SizedBox(height: 12),
                  Text(u['name'] ?? 'Stockist',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(u['email'] ?? '',
                      style: const TextStyle(color: Colors.white70, fontSize: 13)),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text('Stockist',
                        style: TextStyle(color: Colors.white, fontSize: 12)),
                  ),
                ]),
              ),
              const SizedBox(height: 20),
              _tile(Icons.phone,         'Phone', u['phone'] ?? 'Not set'),
              _tile(Icons.location_city, 'City',  u['city']  ?? 'Not set'),
              const SizedBox(height: 16),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.logout, color: Colors.red),
                  title: const Text('Logout',
                      style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
                  onTap: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('Logout'),
                        content: const Text('Are you sure you want to logout?'),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Cancel')),
                          TextButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text('Logout',
                                  style: TextStyle(color: Colors.red))),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      isLoggingOut = true;
                      await auth.signOut();
                    }
                  },
                ),
              ),
            ]),
          );
        },
      ),
    );
  }

  Widget _tile(IconData icon, String label, String value) => Card(
    margin: const EdgeInsets.only(bottom: 8),
    child: ListTile(
      leading: Icon(icon, color: const Color(0xFF1565C0), size: 22),
      title: Text(label,
          style: const TextStyle(fontSize: 12, color: Colors.grey)),
      subtitle: Text(value,
          style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: Colors.black87)),
    ),
  );
}