import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'auth.dart';
import 'notification_service.dart';
import 'package:flutter/services.dart';

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
            BottomNavigationBarItem(icon: Icon(Icons.dashboard),    label: 'Dashboard'),
            BottomNavigationBarItem(icon: Icon(Icons.receipt_long), label: 'Orders'),
            BottomNavigationBarItem(icon: Icon(Icons.inventory_2),  label: 'Stock'),
            BottomNavigationBarItem(icon: Icon(Icons.person),       label: 'Profile'),
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
  State<StockistDashboardScreen> createState() => _StockistDashboardScreenState();
}

class _StockistDashboardScreenState extends State<StockistDashboardScreen> {
  String _stockistName = 'Stockist';
  String _stockistId   = '';

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final uid = auth.currentUser?.uid;
    if (uid == null) return;
    final doc = await db.collection('users').doc(uid).get();
    if (mounted) {
      setState(() {
        _stockistName = doc.data()?['name'] ?? 'Stockist';
        _stockistId   = uid;
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
              return Stack(children: [
                IconButton(
                  icon: const Icon(Icons.notifications_outlined),
                  onPressed: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const StockistNotificationsScreen())),
                ),
                if (unread > 0)
                  Positioned(
                    right: 6, top: 6,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                      child: Text(
                        unread > 9 ? '9+' : '$unread',
                        style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
              ]);
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
            // ── Welcome banner ──────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF1565C0), Color(0xFF1E88E5)]),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Welcome 👋', style: TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 4),
                Text(_stockistName,
                    style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                const Text('Stockist Portal', style: TextStyle(color: Colors.white60, fontSize: 12)),
              ]),
            ),
            const SizedBox(height: 20),
            const Text('Overview', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),

            // ── Row 1: Pending + Approved ───────────────────────────
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
                child: _stockistId.isEmpty
                    ? _statPlaceholder('Accepted', Icons.check_circle, Colors.green)
                    : StreamBuilder<QuerySnapshot>(
                  stream: db.collection('orders')
                      .where('stockistId', isEqualTo: _stockistId)
                      .where('status', isEqualTo: 'accepted')
                      .snapshots(),
                  builder: (context, snap) => _statBox(
                    label: 'Accepted',
                    icon: Icons.check_circle,
                    color: Colors.green,
                    count: snap.hasData ? snap.data!.docs.length : 0,
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 12),

            // ── Row 2: Total Products + Total Orders ────────────────
            Row(children: [
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
              const SizedBox(width: 12),
              Expanded(
                child: _stockistId.isEmpty
                    ? _statPlaceholder('All Orders', Icons.receipt_long, Colors.purple)
                    : StreamBuilder<QuerySnapshot>(
                  stream: db.collection('orders')
                      .where('stockistId', isEqualTo: _stockistId)
                      .snapshots(),
                  builder: (context, snap) => _statBox(
                    label: 'All Orders',
                    icon: Icons.receipt_long,
                    color: Colors.purple,
                    count: snap.hasData ? snap.data!.docs.length : 0,
                  ),
                ),
              ),
            ]),

            const SizedBox(height: 24),
            const Text('Quick Actions', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                return GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.5,
                  children: [
                    _quickAction(context, 'Manage Orders', Icons.receipt_long, Colors.blue, () {
                      final nav = context.findAncestorStateOfType<_StockistMainScreenState>();
                      nav?.setState(() => nav._currentIndex = 1);
                    }),
                    _quickAction(context, 'Products', Icons.inventory_2, Colors.green, () {
                      final nav = context.findAncestorStateOfType<_StockistMainScreenState>();
                      nav?.setState(() => nav._currentIndex = 2);
                    }),
                    _quickAction(context, 'Report Low Stock', Icons.warning_amber, Colors.orange, () {
                      Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const StockistReportLowStockScreen()));
                    }),
                  ],
                );
              },
            )]),
        ),
      ),
    );
  }

  Widget _statBox({required String label, required IconData icon, required Color color, required int count}) =>
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
            Text('$count', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
            Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
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
            Text('—', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color.withOpacity(0.4))),
            Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ]),
        ]),
      );

  Widget _quickAction(BuildContext context, String label, IconData icon, Color color, VoidCallback onTap) =>
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
            Text(label, textAlign: TextAlign.center,
                style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 13)),
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
    _tabController = TabController(length: 2, vsync: this);
    _loadId();
  }

  Future<void> _loadId() async {
    final uid = auth.currentUser?.uid;
    setState(() {
      _stockistDocId = uid ?? '';
      _loading = false;
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'pending':  return Colors.orange;
      case 'approved': return Colors.green;
      case 'rejected': return Colors.red;
      default:         return Colors.grey;
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
          tabs: const [
            Tab(text: 'Pending'),
            Tab(text: 'All Orders'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _StockistOrderTab(statusFilter: 'pending', statusColor: _statusColor, stockistDocId: _stockistDocId),
          _StockistOrderTab(statusFilter: null,      statusColor: _statusColor, stockistDocId: _stockistDocId),
        ],
      ),
    );
  }
}

class _StockistOrderTab extends StatelessWidget {
  final String? statusFilter;
  final Color Function(String) statusColor;
  final String stockistDocId;

  const _StockistOrderTab({
    required this.statusFilter,
    required this.statusColor,
    required this.stockistDocId,
  });

  @override
  Widget build(BuildContext context) {
    final stream = stockistDocId.isNotEmpty
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
                subtitle: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'MR: ${data['mrName'] ?? 'N/A'}  •  $items item(s)  •  ${data['date'] ?? ''}',
                    ),
                    if (data['orderValue'] != null)
                      Text('Value: ₹${data['orderValue']}',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                  ],
                ),
                isThreeLine: true,
                trailing: Column(
                  mainAxisSize: MainAxisSize.min,
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
                          style: TextStyle(color: color, fontSize: 10,
                              fontWeight: FontWeight.bold)),
                    ),
                    if (data['tier'] != null && data['tier'] != 'Normal')
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(data['tier'],
                            style: TextStyle(color: Colors.purple.shade700, fontSize: 9)),
                      ),
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

// ─────────────────────────────────────────
// STOCKIST ORDER DETAIL DIALOG
// Only shows order details + Accept button for pending orders
// ─────────────────────────────────────────
class _StockistOrderDetailDialog extends StatefulWidget {
  final String orderId;
  final Map<String, dynamic> data;
  final Color Function(String) statusColor;

  const _StockistOrderDetailDialog({
    required this.orderId,
    required this.data,
    required this.statusColor,
  });

  @override
  State<_StockistOrderDetailDialog> createState() => _StockistOrderDetailDialogState();
}

class _StockistOrderDetailDialogState extends State<_StockistOrderDetailDialog> {
  bool _isProcessing = false;

  Future<void> _accept() async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);
    try {
      // 1. Update order status to 'approved'
      await db.collection('orders').doc(widget.orderId).update({
        'status':     'approved',
        'approvedAt': FieldValue.serverTimestamp(),
        'approvedBy': auth.currentUser?.uid,
      });

      // 2. Mark any pending incentive/allowance records for this order as paid
      final allowSnap = await db
          .collection('allowances')
          .where('orderId', isEqualTo: widget.orderId)
          .get();
      for (final doc in allowSnap.docs) {
        await doc.reference.update({'pending': false});
      }

      // 3. Notify MR
      final mrId = widget.data['mrId']?.toString() ?? '';
      if (mrId.isNotEmpty) {
        await db.collection('notifications').add({
          'mrId':      mrId,
          'title':     'Order Approved ✅',
          'body':      'Your order for ${widget.data['doctorName'] ?? 'doctor'} has been approved by the stockist.',
          'type':      'order_approved',
          'orderId':   widget.orderId,
          'isRead':    false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('✅ Order approved!'), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.data['status'] ?? 'pending';
    final color  = widget.statusColor(status);
    final items  = (widget.data['items'] as List?) ?? [];

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
          Text('Doctor: ${widget.data['doctorName'] ?? 'N/A'}',
              style: const TextStyle(fontWeight: FontWeight.w600)),
          Text('MR: ${widget.data['mrName'] ?? 'N/A'}',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
          Text('Date: ${widget.data['date'] ?? 'N/A'}',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
          if (widget.data['orderValue'] != null)
            Text('Order Value: ₹${widget.data['orderValue']}',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          if (widget.data['tier'] != null && widget.data['tier'] != 'Normal')
            Container(
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                  color: Colors.purple.shade50, borderRadius: BorderRadius.circular(20)),
              child: Text('Tier: ${widget.data['tier']}',
                  style: TextStyle(color: Colors.purple.shade700, fontSize: 11)),
            ),
          if (widget.data['remarks'] != null && widget.data['remarks'].toString().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text('Remarks: ${widget.data['remarks']}',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
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
          const SizedBox(height: 8),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            OutlinedButton(
              onPressed: _isProcessing ? null : () => Navigator.pop(context),
              child: const Text('Close'),
            ),
            if (status == 'pending') ...[
              const SizedBox(width: 10),
              ElevatedButton.icon(
                onPressed: _isProcessing ? null : _accept,
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green, foregroundColor: Colors.white),
                icon: _isProcessing
                    ? const SizedBox(width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.check_circle_outline, size: 18),
                label: const Text('Approve Order'),
              ),
            ],
          ]),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────
// STOCKIST STOCK SCREEN
// Shows product catalogue — no quantity management
// ─────────────────────────────────────────
class StockistStockScreen extends StatefulWidget {
  const StockistStockScreen({super.key});

  @override
  State<StockistStockScreen> createState() => _StockistStockScreenState();
}

class _StockistStockScreenState extends State<StockistStockScreen> {
  String _search    = '';
  String _filterDiv = 'All';
  final List<String> _divisions = ['All', 'Osteon', 'Ceflon', 'Generic'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Products'),
        actions: [
          IconButton(
            icon: const Icon(Icons.warning_amber),
            tooltip: 'Report Low Stock',
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const StockistReportLowStockScreen())),
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
          child: StreamBuilder<QuerySnapshot>(
            stream: db.collection('products').orderBy('name').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Center(
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.inventory_2_outlined, size: 80, color: Colors.grey.shade300),
                    const SizedBox(height: 16),
                    Text('No products yet',
                        style: TextStyle(color: Colors.grey.shade500, fontSize: 16)),
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

              if (products.isEmpty) {
                return Center(
                  child: Text('No products match your filter.',
                      style: TextStyle(color: Colors.grey.shade500)),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: products.length,
                itemBuilder: (context, i) {
                  final data  = products[i].data() as Map<String, dynamic>;
                  final docId = products[i].id;
                  return _StockistProductCard(data: data, docId: docId);
                },
              );
            },
          ),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────
// STOCKIST PRODUCT CARD
// Read-only — shows product info only, no quantity
// ─────────────────────────────────────────
class _StockistProductCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final String docId;

  const _StockistProductCard({required this.data, required this.docId});

  Color _divColor(String div) {
    switch (div) {
      case 'Osteon': return Colors.blue;
      case 'Ceflon': return Colors.teal;
      default:       return Colors.green;
    }
  }

  @override
  Widget build(BuildContext context) {
    final div   = data['division'] ?? 'General';
    final color = _divColor(div);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
                color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            child: Icon(Icons.medication, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(data['name'] ?? '',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              Text('Code: ${data['code'] ?? 'N/A'}',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
              const SizedBox(height: 4),
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                      color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                  child: Text(div,
                      style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
                ),
                const SizedBox(width: 8),
                Text('MRP: ₹${data['mrp'] ?? data['price'] ?? '0'} | ${data['packSize'] ?? 'N/A'}',
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────
// STOCKIST REPORT LOW STOCK SCREEN
// Stockist marks products as low/out and sends report to admin
// ─────────────────────────────────────────
class StockistReportLowStockScreen extends StatefulWidget {
  const StockistReportLowStockScreen({super.key});

  @override
  State<StockistReportLowStockScreen> createState() => _StockistReportLowStockScreenState();
}

class _StockistReportLowStockScreenState extends State<StockistReportLowStockScreen> {
  final _notesCtrl = TextEditingController();
  final Map<String, String> _stockStatus = {};
  bool _submitting = false;

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
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Mark at least one product as Low or Out.')));
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
        'items':        reported.map((e) => {'productId': e.key, 'status': e.value}).toList(),
        'notes':        _notesCtrl.text.trim(),
        'date':         dateKey,
        'isRead':       false,
        'createdAt':    FieldValue.serverTimestamp(),
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('✅ Report sent to admin!'), backgroundColor: Colors.green));
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
                  final status = _stockStatus[p.id];

                  Color divColor;
                  switch (data['division'] ?? '') {
                    case 'Osteon': divColor = Colors.blue; break;
                    case 'Ceflon': divColor = Colors.teal; break;
                    default:       divColor = Colors.green;
                  }

                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      child: Row(children: [
                        Container(
                          width: 36, height: 36,
                          decoration: BoxDecoration(
                              color: divColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                          child: Icon(Icons.medication, color: divColor, size: 20),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(data['name'] ?? '',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        ),
                        Row(children: [
                          _chip('Low', status == 'low', Colors.orange, () => setState(() {
                            if (status == 'low') _stockStatus.remove(p.id);
                            else _stockStatus[p.id] = 'low';
                          })),
                          const SizedBox(width: 6),
                          _chip('Out', status == 'out', Colors.red, () => setState(() {
                            if (status == 'out') _stockStatus.remove(p.id);
                            else _stockStatus[p.id] = 'out';
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
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
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
                    ? const SizedBox(width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
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
            border: Border.all(color: selected ? color : Colors.grey.shade300, width: 1.5),
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
                Icon(Icons.notifications_none, size: 80, color: Colors.grey.shade300),
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
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: iconColor.withOpacity(0.15),
                    child: Icon(iconData, color: iconColor, size: 20),
                  ),
                  title: Text(data['title'] ?? '',
                      style: TextStyle(
                          fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                          fontSize: 14)),
                  subtitle: Text(data['body'] ?? '', style: const TextStyle(fontSize: 12)),
                  trailing: isRead
                      ? null
                      : Container(
                      width: 8, height: 8,
                      decoration: const BoxDecoration(color: Colors.blue, shape: BoxShape.circle)),
                  onTap: () async {
                    if (!isRead) await docs[i].reference.update({'isRead': true});
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
                  gradient: const LinearGradient(colors: [Color(0xFF1565C0), Color(0xFF1E88E5)]),
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
                          color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(u['email'] ?? '',
                      style: const TextStyle(color: Colors.white70, fontSize: 13)),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    decoration: BoxDecoration(
                        color: Colors.white24, borderRadius: BorderRadius.circular(20)),
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
      title: Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      subtitle: Text(value,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Colors.black87)),
    ),
  );
}