import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'auth.dart';

String? _activeCheckInDoctorId;
String? _activeCheckInDoctorName;
DateTime? _activeCheckInTime;

// ─────────────────────────────────────────
// MR MAIN SCREEN WITH BOTTOM NAVIGATION
// ─────────────────────────────────────────
class MrMainScreen extends StatefulWidget {
  const MrMainScreen({super.key});

  @override
  State<MrMainScreen> createState() => _MrMainScreenState();
}

class _MrMainScreenState extends State<MrMainScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const MrDashboardScreen(),
    const MrDoctorsScreen(),
    const MrProductsScreen(),
    const MrOrdersScreen(),
    const MrReportsScreen(),
    const MrProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFF1565C0),
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard),        label: 'Dashboard'),
          BottomNavigationBarItem(icon: Icon(Icons.people),           label: 'Doctors'),
          BottomNavigationBarItem(icon: Icon(Icons.medication),       label: 'Products'),
          BottomNavigationBarItem(icon: Icon(Icons.shopping_cart),    label: 'Orders'),
          BottomNavigationBarItem(icon: Icon(Icons.assignment),       label: 'Reports'),
          BottomNavigationBarItem(icon: Icon(Icons.person),           label: 'Profile'),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────
// MR DASHBOARD  (live Firebase data)
// ─────────────────────────────────────────
class MrDashboardScreen extends StatefulWidget {
  const MrDashboardScreen({super.key});

  @override
  State<MrDashboardScreen> createState() => _MrDashboardScreenState();
}

class _MrDashboardScreenState extends State<MrDashboardScreen> {
  String _mrName        = 'Medical Representative';
  String _todayVisits   = '0';
  String _todayOrders   = '0';
  bool   _reportSubmitted = false;
  int    _presentDays   = 0;
  int    _absentDays    = 0;
  int    _leaveDays     = 0;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    final uid = auth.currentUser?.uid;
    if (uid == null) return;

    try {
      // Load MR name
      final userDoc = await db.collection('users').doc(uid).get();
      if (userDoc.exists && mounted) {
        setState(() => _mrName = userDoc.data()?['name'] ?? 'Medical Representative');
      }

      final today      = _dateKey(DateTime.now());
      final monthStart = DateTime(DateTime.now().year, DateTime.now().month, 1);

      // Today visits — no compound index needed (single where + no orderBy)
      final visits = await db
          .collection('visits')
          .where('mrId',  isEqualTo: uid)
          .where('date',  isEqualTo: today)
          .get();
      if (mounted) setState(() => _todayVisits = visits.docs.length.toString());

      // Today orders
      final orders = await db
          .collection('orders')
          .where('mrId', isEqualTo: uid)
          .where('date', isEqualTo: today)
          .get();
      if (mounted) setState(() => _todayOrders = orders.docs.length.toString());

      // Today report
      final report = await db
          .collection('daily_reports')
          .where('mrId', isEqualTo: uid)
          .where('date', isEqualTo: today)
          .get();
      if (mounted) setState(() => _reportSubmitted = report.docs.isNotEmpty);

      // Attendance this month — single range filter, no compound index needed
      final attendance = await db
          .collection('attendance')
          .where('mrId',  isEqualTo: uid)
          .where('date',  isGreaterThanOrEqualTo: _dateKey(monthStart))
          .get();
      int present = 0, absent = 0, leave = 0;
      for (final doc in attendance.docs) {
        final s = doc['status'] ?? '';
        if (s == 'present') present++;
        else if (s == 'absent') absent++;
        else if (s == 'leave') leave++;
      }
      if (mounted) setState(() {
        _presentDays = present;
        _absentDays  = absent;
        _leaveDays   = leave;
      });
    } catch (e) {
      debugPrint('Dashboard load error: $e');
    }
  }

  String _dateKey(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good Morning! 👋';
    if (h < 17) return 'Good Afternoon! 👋';
    return 'Good Evening! 👋';
  }

  @override
  Widget build(BuildContext context) {
    final now    = DateTime.now();
    final months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    final days   = ['Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday'];
    final dateStr = '${days[now.weekday - 1]}, ${now.day} ${months[now.month - 1]} ${now.year}';
    final workingDays = _workingDaysInMonth(now.year, now.month);

    return Scaffold(
      appBar: AppBar(
        title: const Text('MR Dashboard'),
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
                            builder: (_) => const MrNotificationsScreen())),
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
        onRefresh: _loadDashboardData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

            // Welcome card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [Color(0xFF1565C0), Color(0xFF1E88E5)]),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_greeting(), style: const TextStyle(color: Colors.white70, fontSize: 14)),
                const SizedBox(height: 4),
                Text(_mrName, style: const TextStyle(
                    color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Row(children: [
                  const Icon(Icons.calendar_today, color: Colors.white70, size: 14),
                  const SizedBox(width: 6),
                  Text(dateStr, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                ]),
                if (!_reportSubmitted) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.warning_amber, color: Colors.white, size: 14),
                      SizedBox(width: 6),
                      Text('Daily report pending',
                          style: TextStyle(color: Colors.white, fontSize: 12)),
                    ]),
                  ),
                ],
              ]),
            ),
            const SizedBox(height: 20),

            // Today's Summary
            const Text("Today's Summary",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(children: [
              _statCard('Doctors\nVisited', _todayVisits,  Icons.people,        Colors.blue),
              const SizedBox(width: 12),
              _statCard('Orders\nPlaced',  _todayOrders,  Icons.shopping_cart,  Colors.green),
              const SizedBox(width: 12),
              _statCard('Report\nStatus',
                  _reportSubmitted ? '✓' : '✗',
                  Icons.assignment,
                  _reportSubmitted ? Colors.green : Colors.orange),
            ]),
            const SizedBox(height: 20),

            // Quick actions
            const Text('Quick Actions',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12, mainAxisSpacing: 12,
              childAspectRatio: 1.5,
              children: [
                _quickAction(context, 'Visit Doctor', Icons.add_location, Colors.blue, () {
                  final nav = context.findAncestorStateOfType<_MrMainScreenState>();
                  nav?.setState(() => nav._currentIndex = 1);
                }),
                _quickAction(context, 'Place Order', Icons.add_shopping_cart, Colors.green, () {
                  Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const MrPlaceOrderScreen()));
                }),
                _quickAction(context, 'Daily Report', Icons.edit_note, Colors.orange, () {
                  Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const MrSubmitReportScreen()));
                }),
                _quickAction(context, 'Apply Leave', Icons.event_busy, Colors.red, () {
                  Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const MrApplyLeaveScreen()));
                }),
              ],
            ),
            const SizedBox(height: 20),

            // This month attendance
            const Text('This Month',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(
                    color: Colors.grey.withOpacity(0.1), blurRadius: 6,
                    offset: const Offset(0, 2))],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _monthStat('Present',      _presentDays.toString(), Colors.green),
                  _monthStat('Absent',       _absentDays.toString(),  Colors.red),
                  _monthStat('Leave',        _leaveDays.toString(),   Colors.orange),
                  _monthStat('Working\nDays',workingDays.toString(),  Colors.blue),
                ],
              ),
            ),
          ]),
        ),
      ),
    );
  }

  int _workingDaysInMonth(int year, int month) {
    final daysInMonth = DateUtils.getDaysInMonth(year, month);
    int count = 0;
    for (int d = 1; d <= daysInMonth; d++) {
      if (DateTime(year, month, d).weekday != DateTime.sunday) count++;
    }
    return count;
  }

  Widget _statCard(String label, String value, IconData icon, Color color) =>
      Expanded(
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Column(children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 6),
            Text(value, style: TextStyle(
                fontSize: 22, fontWeight: FontWeight.bold, color: color)),
            Text(label, textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ]),
        ),
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
            Text(label, style: TextStyle(
                color: color, fontWeight: FontWeight.w600, fontSize: 13)),
          ]),
        ),
      );

  Widget _monthStat(String label, String value, Color color) =>
      Column(children: [
        Text(value, style: TextStyle(
            fontSize: 22, fontWeight: FontWeight.bold, color: color)),
        Text(label, textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ]);
}

// ─────────────────────────────────────────
// MR DOCTORS SCREEN
// FIX: Removed .where('isActive') + .orderBy('name') compound query —
//      that requires a composite Firestore index which silently returns 0
//      docs when missing.  We now fetch ALL doctors ordered by name and
//      filter isActive client-side, eliminating the index requirement.
// ─────────────────────────────────────────
class MrDoctorsScreen extends StatefulWidget {
  const MrDoctorsScreen({super.key});

  @override
  State<MrDoctorsScreen> createState() => _MrDoctorsScreenState();
}

class _MrDoctorsScreenState extends State<MrDoctorsScreen> {
  String       _search    = '';
  String       _filterDiv = 'All';
  final List<String> _divisions = ['All', 'Ortho', 'Gynec', 'General'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Doctor List')),
      body: Column(children: [

        // Info banner
        Container(
          width: double.infinity,
          margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          padding: const EdgeInsets.all(10),
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
                'You must be within 200 m of the doctor\'s location to check in.',
                style: TextStyle(fontSize: 12, color: Colors.blue),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 8),

        // Search
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: TextField(
            onChanged: (v) => setState(() => _search = v.toLowerCase()),
            decoration: InputDecoration(
              hintText: 'Search doctors...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _search.isNotEmpty
                  ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () => setState(() => _search = ''))
                  : null,
            ),
          ),
        ),
        const SizedBox(height: 8),

        // Division filter chips
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

        // ── Doctor list ──────────────────────────────────────────────
        // FIX 1: Query only on 'name' (single-field orderBy, no compound
        //         index needed).  isActive filtering done client-side.
        // FIX 2: snapshot.hasError handled — shows the actual Firestore
        //         error so you can diagnose permission / index issues.
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: db
                .collection('doctors')
                .orderBy('name')          // single-field index — always works
                .snapshots(),
            builder: (context, snapshot) {
              // ── Loading ──
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              // ── Error (missing index, permission denied, etc.) ──
              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline,
                              size: 48, color: Colors.red),
                          const SizedBox(height: 12),
                          const Text('Could not load doctors.',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          Text(snapshot.error.toString(),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.grey)),
                        ]),
                  ),
                );
              }

              // ── Empty collection ──
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Center(
                  child: Column(mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.people_outline,
                            size: 80, color: Colors.grey.shade300),
                        const SizedBox(height: 16),
                        Text('No doctors found',
                            style: TextStyle(
                                color: Colors.grey.shade500, fontSize: 16)),
                        const SizedBox(height: 8),
                        Text('Add doctors in the admin panel.',
                            style: TextStyle(
                                color: Colors.grey.shade400, fontSize: 13)),
                      ]),
                );
              }

              // ── Filter client-side ──
              // isActive + search + division — no Firestore index needed
              final docs = snapshot.data!.docs.where((d) {
                final data   = d.data() as Map<String, dynamic>;
                final active = data['isActive'] as bool? ?? true;
                final name   = (data['name'] ?? '').toString().toLowerCase();
                final div    = (data['division'] ?? '').toString();
                return active &&
                    (_search.isEmpty    || name.contains(_search)) &&
                    (_filterDiv == 'All' || div == _filterDiv);
              }).toList();

              if (docs.isEmpty) {
                return Center(
                  child: Text('No doctors match your filter.',
                      style: TextStyle(color: Colors.grey.shade500)),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: docs.length,
                itemBuilder: (context, i) => _DoctorCard(
                  docId: docs[i].id,
                  data:  docs[i].data() as Map<String, dynamic>,
                ),
              );
            },
          ),
        ),
      ]),
    );
  }
}

class _DoctorCard extends StatefulWidget {
  final String               docId;
  final Map<String, dynamic> data;
  const _DoctorCard({required this.docId, required this.data});

  @override
  State<_DoctorCard> createState() => _DoctorCardState();
}

class _DoctorCardState extends State<_DoctorCard> {
  bool _checking = false;

  Color _divColor(String div) {
    switch (div) {
      case 'Ortho': return Colors.blue;
      case 'Gynec': return Colors.pink;
      default:      return Colors.green;
    }
  }

  Future<void> _checkIn() async {
    setState(() => _checking = true);
    try {
      // 1. Permission
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever ||
          perm == LocationPermission.denied) {
        _showMsg('Location permission denied. Enable in settings.', Colors.red);
        return;
      }

      // 2. Current position (with timeout to avoid hanging on GPS-less devices)
      final Position pos;
      try {
        pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        ).timeout(const Duration(seconds: 15));
      } catch (e) {
        _showMsg('Could not get location. Check GPS is enabled.', Colors.red);
        return;
      }

      // 3. Compare with doctor location
      final double? docLat = (widget.data['latitude']  as num?)?.toDouble();
      final double? docLng = (widget.data['longitude'] as num?)?.toDouble();

      if (docLat == null || docLng == null) {
        _showMsg('Doctor location not set. Contact admin.', Colors.orange);
        return;
      }

      final distance = Geolocator.distanceBetween(
          pos.latitude, pos.longitude, docLat, docLng);

      if (distance > 200) {
        _showMsg(
            'You are ${distance.toInt()} m away. Must be within 200 m.',
            Colors.red);
        return;
      }

      // 4. Already visited today?
      final uid   = auth.currentUser!.uid;
      final today = _dateKey(DateTime.now());
      final existing = await db
          .collection('visits')
          .where('mrId',      isEqualTo: uid)
          .where('doctorId',  isEqualTo: widget.docId)
          .where('date',      isEqualTo: today)
          .get();

      if (existing.docs.isNotEmpty) {
        _showMsg('Already checked in with this doctor today.', Colors.orange);
        return;
      }

      // 5. Record visit
      await db.collection('visits').add({
        'mrId':           uid,
        'doctorId':       widget.docId,
        'doctorName':     widget.data['name'],
        'date':           today,
        'timestamp':      FieldValue.serverTimestamp(),
        'mrLat':          pos.latitude,
        'mrLng':          pos.longitude,
        'distanceMeters': distance.toInt(),
      });

      // 6. Mark attendance present (merge so we don't overwrite leave)
      await db.collection('attendance').doc('${uid}_$today').set({
        'mrId':      uid,
        'date':      today,
        'status':    'present',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            title: const Row(children: [
              Icon(Icons.check_circle, color: Colors.green),
              SizedBox(width: 8),
              Text('Check-In Successful'),
            ]),
            content: Text(
                'Checked in with ${widget.data['name']}.\n'
                    '${distance.toInt()} m away.'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(
                    builder: (_) => MrPlaceOrderScreen(
                      preselectedDoctorId:   widget.docId,
                      preselectedDoctorName: widget.data['name'] ?? '',
                    ),
                  ));
                },
                child: const Text('Place Order'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Done'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      _showMsg('Error: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  void _showMsg(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: color));
  }

  String _dateKey(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final div   = widget.data['division'] ?? 'General';
    final color = _divColor(div);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          CircleAvatar(
            backgroundColor: color.withOpacity(0.15),
            child: Icon(Icons.person, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(widget.data['name'] ?? '',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 15)),
              Text(widget.data['specialization'] ?? '',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
              Text(widget.data['hospital'] ?? '',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(div,
                    style: TextStyle(
                        color: color, fontSize: 11,
                        fontWeight: FontWeight.w600)),
              ),
            ]),
          ),
          _checking
              ? const SizedBox(
              width: 36, height: 36,
              child: CircularProgressIndicator(strokeWidth: 2))
              : ElevatedButton(
            onPressed: _checkIn,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(72, 36),
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
            child: const Text('Check In',
                style: TextStyle(fontSize: 12)),
          ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────
// MR PRODUCTS SCREEN
// FIX: Removed compound where+orderBy — fetched by name, filtered client-side
// ─────────────────────────────────────────
class MrProductsScreen extends StatefulWidget {
  const MrProductsScreen({super.key});

  @override
  State<MrProductsScreen> createState() => _MrProductsScreenState();
}

class _MrProductsScreenState extends State<MrProductsScreen> {
  String _filterDivision = 'All';
  String _searchQuery    = '';
  final List<String> _divisions = ['All', 'Ortho', 'Gynec', 'General'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Products & Stock')),
      body: Column(children: [

        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
            decoration: InputDecoration(
              hintText: 'Search products...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () => setState(() => _searchQuery = ''))
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
            itemBuilder: (context, index) {
              final div = _divisions[index];
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(div),
                  selected: _filterDivision == div,
                  onSelected: (_) => setState(() => _filterDivision = div),
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
            // FIX: single-field orderBy only — no composite index required
            stream: db.collection('products').orderBy('name').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline,
                              size: 48, color: Colors.red),
                          const SizedBox(height: 12),
                          const Text('Could not load products.',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          Text(snapshot.error.toString(),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.grey)),
                        ]),
                  ),
                );
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Center(
                  child: Column(mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inventory_2_outlined,
                            size: 80, color: Colors.grey.shade300),
                        const SizedBox(height: 16),
                        Text('No products available',
                            style: TextStyle(
                                color: Colors.grey.shade500, fontSize: 16)),
                      ]),
                );
              }

              // FIX: filter stock > 0 and division client-side
              final products = snapshot.data!.docs.where((doc) {
                final data     = doc.data() as Map<String, dynamic>;
                final name     = (data['name'] ?? '').toString().toLowerCase();
                final division = (data['division'] ?? '').toString();
                return (_searchQuery.isEmpty     || name.contains(_searchQuery)) &&
                    (_filterDivision == 'All' || division == _filterDivision);
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
                itemBuilder: (context, index) {
                  final data      = products[index].data() as Map<String, dynamic>;
                  final stock     = (data['stock']    as num?)?.toInt() ?? 0;
                  final minStock  = (data['minStock'] as num?)?.toInt() ?? 10;
                  final division  = data['division'] ?? 'General';
                  final isOutOfStock = stock == 0;
                  final isLowStock   = stock > 0 && stock <= minStock;

                  Color color;
                  switch (division) {
                    case 'Ortho': color = Colors.blue;  break;
                    case 'Gynec': color = Colors.pink;  break;
                    default:      color = Colors.green;
                  }
                  Color  stockColor = Colors.green;
                  String stockLabel = 'Available';
                  if (isOutOfStock) { stockColor = Colors.red;    stockLabel = 'Out of Stock'; }
                  else if (isLowStock) { stockColor = Colors.orange; stockLabel = 'Low Stock'; }

                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    child: ListTile(
                      leading: Container(
                        width: 44, height: 44,
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.medication, color: color),
                      ),
                      title: Text(data['name'] ?? 'Unknown',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(
                        '${data['packSize'] ?? ''} • ₹${data['price'] ?? 'N/A'}\n$division',
                      ),
                      isThreeLine: true,
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('$stock units',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: stockColor)),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: stockColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(stockLabel,
                                style: TextStyle(
                                    fontSize: 10, color: stockColor,
                                    fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ),
                    ),
                  );
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
// MR ORDERS SCREEN
// FIX: Added hasError handling
// ─────────────────────────────────────────
class MrOrdersScreen extends StatelessWidget {
  const MrOrdersScreen({super.key});

  Color _statusColor(String status) {
    switch (status) {
      case 'pending':    return Colors.orange;
      case 'approved':   return Colors.blue;
      case 'billed':     return Colors.purple;
      case 'dispatched': return Colors.teal;
      case 'delivered':  return Colors.green;
      case 'cancelled':  return Colors.red;
      default:           return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = auth.currentUser?.uid ?? '';
    return Scaffold(
      appBar: AppBar(title: const Text('My Orders')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const MrPlaceOrderScreen())),
        icon: const Icon(Icons.add),
        label: const Text('New Order'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        // FIX: removed .orderBy('createdAt') — sorting client-side avoids
        // the composite index requirement (mrId equality + createdAt orderBy).
        stream: db
            .collection('orders')
            .where('mrId', isEqualTo: uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: Colors.red),
                      const SizedBox(height: 12),
                      const Text('Could not load orders.',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text(snapshot.error.toString(),
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    ]),
              ),
            );
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.shopping_cart_outlined,
                        size: 80, color: Colors.grey.shade300),
                    const SizedBox(height: 16),
                    Text('No orders yet',
                        style: TextStyle(color: Colors.grey.shade500, fontSize: 16)),
                    const SizedBox(height: 8),
                    Text('Tap + New Order to place your first order',
                        style: TextStyle(color: Colors.grey.shade400, fontSize: 13)),
                  ]),
            );
          }
          // client-side sort by createdAt descending (no composite index needed)
          final orderedDocs = List.of(snapshot.data!.docs)
            ..sort((a, b) {
              final aTs = (a.data() as Map)['createdAt'];
              final bTs = (b.data() as Map)['createdAt'];
              if (aTs == null && bTs == null) return 0;
              if (aTs == null) return 1;
              if (bTs == null) return -1;
              return (bTs as Timestamp).compareTo(aTs as Timestamp);
            });
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: orderedDocs.length,
            itemBuilder: (context, i) {
              final doc    = orderedDocs[i];
              final data   = doc.data() as Map<String, dynamic>;
              final status = data['status'] ?? 'pending';
              final color  = _statusColor(status);
              final items  = (data['items'] as List?)?.length ?? 0;
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
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
                    '$items item(s) • ${data['date'] ?? ''}\n${data['remarks'] ?? ''}',
                  ),
                  isThreeLine: data['remarks'] != null &&
                      data['remarks'].toString().isNotEmpty,
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(status.toUpperCase(),
                        style: TextStyle(
                            color: color, fontSize: 11,
                            fontWeight: FontWeight.bold)),
                  ),
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(
                          builder: (_) => MrOrderDetailScreen(
                              orderId: doc.id, data: data))),
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
// MR PLACE ORDER SCREEN (with validation)
// ─────────────────────────────────────────
class MrPlaceOrderScreen extends StatefulWidget {
  final String? preselectedDoctorId;
  final String? preselectedDoctorName;
  const MrPlaceOrderScreen(
      {super.key, this.preselectedDoctorId, this.preselectedDoctorName});

  @override
  State<MrPlaceOrderScreen> createState() => _MrPlaceOrderScreenState();
}

class _MrPlaceOrderScreenState extends State<MrPlaceOrderScreen> {
  String? _selectedDoctorId;
  String? _selectedDoctorName;
  final Map<String, int> _quantities = {};
  final Map<String, Map<String, dynamic>> _productCache = {};
  final _remarksCtrl = TextEditingController();
  bool _submitting = false;
  bool _loadingDoctors = true;
  bool _loadingProducts = true;
  List<QueryDocumentSnapshot> _doctors = [];
  List<QueryDocumentSnapshot> _products = [];

  @override
  void initState() {
    super.initState();

    // Check if this order is coming from a valid check-in
    final hasValidCheckIn = _validateCheckInSession();

    if (!hasValidCheckIn && widget.preselectedDoctorId == null) {
      // No valid check-in session and no doctor preselected - show error
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showOrderBlockedDialog();
      });
    }

    _selectedDoctorId = widget.preselectedDoctorId;
    _selectedDoctorName = widget.preselectedDoctorName;
    debugPrint('Preselected doctor: $_selectedDoctorName ($_selectedDoctorId)');
    _loadData();
  }

  bool _validateCheckInSession() {
    // Check if there's an active check-in session (within last 30 minutes)
    if (_activeCheckInDoctorId != null && _activeCheckInTime != null) {
      final minutesSinceCheckIn = DateTime.now().difference(_activeCheckInTime!).inMinutes;
      if (minutesSinceCheckIn <= 30) {
        return true;
      } else {
        // Session expired
        _activeCheckInDoctorId = null;
        _activeCheckInDoctorName = null;
        _activeCheckInTime = null;
      }
    }
    return false;
  }

  void _showOrderBlockedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.block, color: Colors.red, size: 28),
            SizedBox(width: 8),
            Text('Order Not Allowed'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'You can only place orders after:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),
            Text('✓ Checking in with a doctor'),
            Text('✓ Being within 200m of the doctor\'s clinic'),
            SizedBox(height: 12),
            Text(
              'Please visit a doctor\'s clinic, check in, then place your order.',
              style: TextStyle(fontSize: 13, color: Colors.orange),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context); // Close order screen
            },
            child: const Text('Go Back'),
          ),
        ],
      ),
    );
  }

  Future<void> _loadData() async {
    // Load doctors
    final doctorsSnap = await db.collection('doctors').orderBy('name').get();
    setState(() {
      _doctors = doctorsSnap.docs.where((d) {
        final data = d.data() as Map<String, dynamic>;
        return data['isActive'] as bool? ?? true;
      }).toList();
      _loadingDoctors = false;
    });

    // Load products
    final productsSnap = await db.collection('products').orderBy('name').get();
    setState(() {
      _products = productsSnap.docs.where((p) {
        final data = p.data() as Map<String, dynamic>;
        final stock = (data['stock'] as num?)?.toInt() ?? 0;
        return stock > 0;
      }).toList();
      _loadingProducts = false;
    });
  }

  @override
  void dispose() {
    _remarksCtrl.dispose();
    super.dispose();
  }

  String _dateKey(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  Future<void> _submitOrder() async {
    if (_selectedDoctorId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a doctor first.')));
      return;
    }

    // VALIDATION: Check if this doctor was actually checked in today
    final uid = auth.currentUser!.uid;
    final today = _dateKey(DateTime.now());

    final visitCheck = await db
        .collection('visits')
        .where('mrId', isEqualTo: uid)
        .where('doctorId', isEqualTo: _selectedDoctorId)
        .where('date', isEqualTo: today)
        .get();

    if (visitCheck.docs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ You must check in with this doctor today before placing an order!'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 4),
        ),
      );
      return;
    }

    final orderItems = _quantities.entries
        .where((e) => e.value > 0)
        .map((e) => {
      'productId': e.key,
      'productName': _productCache[e.key]?['name'] ?? '',
      'quantity': e.value,
      'price': _productCache[e.key]?['price'] ?? 0,
    })
        .toList();
    if (orderItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Add at least one product.')));
      return;
    }

    setState(() => _submitting = true);
    try {
      final userDoc = await db.collection('users').doc(uid).get();
      final mrName = userDoc.data()?['name'] ?? '';

      // Verify stock before placing order
      for (final item in _quantities.entries.where((e) => e.value > 0)) {
        final productDoc = await db.collection('products').doc(item.key).get();
        final currentStock = (productDoc.data() as Map<String, dynamic>?)?['stock'] ?? 0;
        if (currentStock < item.value) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Insufficient stock for ${_productCache[item.key]?['name']}. Available: $currentStock'),
              backgroundColor: Colors.red,
            ),
          );
          setState(() => _submitting = false);
          return;
        }
      }

      // Use transaction to reduce stock and place order
      await db.runTransaction((transaction) async {
        // Reduce stock for each product
        for (final item in _quantities.entries.where((e) => e.value > 0)) {
          final productRef = db.collection('products').doc(item.key);
          final productDoc = await transaction.get(productRef);
          final currentStock = (productDoc.data() as Map<String, dynamic>?)?['stock'] ?? 0;
          transaction.update(productRef, {'stock': currentStock - item.value});
        }

        // Add order
        await db.collection('orders').add({
          'mrId': uid,
          'mrName': mrName,
          'doctorId': _selectedDoctorId,
          'doctorName': _selectedDoctorName,
          'items': orderItems,
          'remarks': _remarksCtrl.text.trim(),
          'status': 'pending',
          'date': today,
          'createdAt': FieldValue.serverTimestamp(),
        });
      });

      // Clear the active check-in session after order is placed
      _activeCheckInDoctorId = null;
      _activeCheckInDoctorName = null;
      _activeCheckInTime = null;

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Order placed successfully!'),
            backgroundColor: Colors.green));
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
    final totalItems = _quantities.values.fold(0, (a, b) => a + b);

    // If no valid doctor preselected, show restricted UI
    if (widget.preselectedDoctorId == null && _selectedDoctorId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Place New Order')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.location_off, size: 80, color: Colors.red),
                const SizedBox(height: 20),
                const Text(
                  'Cannot Place Order',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Orders can only be placed after checking in with a doctor.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Please visit a doctor\'s clinic, check in, then place your order.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Colors.orange),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Go Back'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Place New Order'),
        actions: [
          if (_selectedDoctorName != null)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Text(
                  'Dr. ${_selectedDoctorName!.contains(' ') ? _selectedDoctorName!.split(' ').last : _selectedDoctorName!}',
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Info banner - show check-in requirement
          Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'You can order only for the doctor you checked in with today.',
                    style: TextStyle(fontSize: 12, color: Colors.green),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Doctor selection (disabled if preselected) ──
                  const Text(
                    'Select Doctor',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(height: 8),
                  if (_loadingDoctors)
                    const LinearProgressIndicator()
                  else
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButtonFormField<String>(
                          value: _selectedDoctorId,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                            prefixIcon: Icon(Icons.person),
                          ),
                          hint: const Text('Choose a doctor'),
                          items: _doctors.map((d) {
                            final data = d.data() as Map<String, dynamic>;
                            return DropdownMenuItem<String>(
                              value: d.id,
                              child: Text(
                                '${data['name']} (${data['division']})',
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList(),
                          // Set onChanged to null when disabled, otherwise provide the function
                          onChanged: widget.preselectedDoctorId == null
                              ? (val) {
                            if (val == null) return;
                            final doc = _doctors.firstWhere((d) => d.id == val);
                            final data = doc.data() as Map<String, dynamic>;
                            setState(() {
                              _selectedDoctorId = val;
                              _selectedDoctorName = data['name'];
                            });
                          }
                              : null, // Disabled when preselected
                        ),
                      ),
                    ),
                  const SizedBox(height: 24),

                  // ── Products ──
                  const Text(
                    'Select Products',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(height: 8),
                  if (_loadingProducts)
                    const LinearProgressIndicator()
                  else if (_products.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Center(
                        child: Text(
                          'No products in stock.',
                          style: TextStyle(color: Colors.orange),
                        ),
                      ),
                    )
                  else
                    Column(
                      children: _products.map((p) {
                        final data = p.data() as Map<String, dynamic>;
                        _productCache[p.id] = data;
                        final qty = _quantities[p.id] ?? 0;
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        data['name'] ?? '',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold),
                                      ),
                                      Text(
                                        '₹${data['price'] ?? 'N/A'} • ${data['packSize'] ?? ''}',
                                        style: TextStyle(
                                            color: Colors.grey.shade600,
                                            fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                                Row(
                                  children: [
                                    IconButton(
                                      onPressed: qty > 0
                                          ? () => setState(
                                              () => _quantities[p.id] = qty - 1)
                                          : null,
                                      icon: const Icon(Icons.remove_circle_outline),
                                      color: const Color(0xFF1565C0),
                                      iconSize: 22,
                                    ),
                                    SizedBox(
                                      width: 32,
                                      child: Text(
                                        '$qty',
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    IconButton(
                                      onPressed: () => setState(
                                              () => _quantities[p.id] = qty + 1),
                                      icon: const Icon(Icons.add_circle_outline),
                                      color: const Color(0xFF1565C0),
                                      iconSize: 22,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  const SizedBox(height: 16),

                  // Remarks
                  const Text(
                    'Remarks (optional)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _remarksCtrl,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Any special instructions...',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),

          // Submit bar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                    color: Colors.grey.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, -2))
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '$totalItems item(s) selected',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: _submitting ? null : _submitOrder,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(120, 40),
                    ),
                    child: _submitting
                        ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                        : const Text('Submit Order'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────
// MR ORDER DETAIL SCREEN  (unchanged)
// ─────────────────────────────────────────
class MrOrderDetailScreen extends StatelessWidget {
  final String               orderId;
  final Map<String, dynamic> data;
  const MrOrderDetailScreen(
      {super.key, required this.orderId, required this.data});

  Color _statusColor(String s) {
    switch (s) {
      case 'pending':    return Colors.orange;
      case 'approved':   return Colors.blue;
      case 'billed':     return Colors.purple;
      case 'dispatched': return Colors.teal;
      case 'delivered':  return Colors.green;
      case 'cancelled':  return Colors.red;
      default:           return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = data['status'] ?? 'pending';
    final color  = _statusColor(status);
    final items  = (data['items'] as List?) ?? [];

    return Scaffold(
      appBar: AppBar(title: const Text('Order Details')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withOpacity(0.4)),
            ),
            child: Column(children: [
              Icon(Icons.receipt_long, color: color, size: 36),
              const SizedBox(height: 8),
              Text(status.toUpperCase(),
                  style: TextStyle(
                      color: color, fontSize: 18, fontWeight: FontWeight.bold)),
              Text(data['date'] ?? '',
                  style: TextStyle(color: Colors.grey.shade600)),
            ]),
          ),
          const SizedBox(height: 16),

          _detail('Doctor', data['doctorName'] ?? 'N/A'),
          _detail('Date',   data['date']       ?? 'N/A'),
          if (data['remarks'] != null && data['remarks'].toString().isNotEmpty)
            _detail('Remarks', data['remarks']),
          if (data['billNumber'] != null && data['billNumber'].toString().isNotEmpty)
            _detail('Bill No', data['billNumber']),

          const SizedBox(height: 16),
          const Text('Items Ordered',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 8),

          ...items.map((item) => Card(
            margin: const EdgeInsets.only(bottom: 8),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
            child: ListTile(
              leading: const Icon(Icons.medication, color: Color(0xFF1565C0)),
              title:    Text(item['productName'] ?? ''),
              subtitle: Text('₹${item['price'] ?? 'N/A'}'),
              trailing: Text('Qty: ${item['quantity']}',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 15)),
            ),
          )),
        ]),
      ),
    );
  }

  Widget _detail(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(width: 90,
          child: Text(label,
              style: const TextStyle(
                  color: Colors.grey, fontWeight: FontWeight.w500))),
      Expanded(
          child: Text(value,
              style: const TextStyle(fontWeight: FontWeight.w600))),
    ]),
  );
}

// ─────────────────────────────────────────
// MR REPORTS SCREEN
// FIX: Added hasError
// ─────────────────────────────────────────
class MrReportsScreen extends StatelessWidget {
  const MrReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = auth.currentUser?.uid ?? '';
    return Scaffold(
      appBar: AppBar(title: const Text('Daily Reports')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const MrSubmitReportScreen())),
        icon: const Icon(Icons.add),
        label: const Text('Submit Report'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        // FIX: client-side sort — no composite index needed
        stream: db
            .collection('daily_reports')
            .where('mrId', isEqualTo: uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: Colors.red),
                      const SizedBox(height: 12),
                      const Text('Could not load reports.',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text(snapshot.error.toString(),
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    ]),
              ),
            );
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.assignment_outlined,
                        size: 80, color: Colors.grey.shade300),
                    const SizedBox(height: 16),
                    Text('No reports submitted yet',
                        style: TextStyle(color: Colors.grey.shade500, fontSize: 16)),
                    const SizedBox(height: 8),
                    Text('Submit your daily report every evening',
                        style: TextStyle(color: Colors.grey.shade400, fontSize: 13)),
                  ]),
            );
          }
          // client-side sort by date descending (no composite index needed)
          final reportDocs = List.of(snapshot.data!.docs)
            ..sort((a, b) {
              final aDate = (a.data() as Map)['date']?.toString() ?? '';
              final bDate = (b.data() as Map)['date']?.toString() ?? '';
              return bDate.compareTo(aDate);
            });
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: reportDocs.length,
            itemBuilder: (context, i) {
              final doc             = reportDocs[i];
              final data            = doc.data() as Map<String, dynamic>;
              final doctorsVisited  =
                  (data['doctorsVisited'] as List?)?.join(', ') ?? 'None';
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFE3F2FD),
                    child: Icon(Icons.assignment, color: Color(0xFF1565C0)),
                  ),
                  title: Text(data['date'] ?? '',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('Doctors: $doctorsVisited'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(
                          builder: (_) => MrReportDetailScreen(data: data))),
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
// SUBMIT DAILY REPORT  (unchanged logic)
// ─────────────────────────────────────────
class MrSubmitReportScreen extends StatefulWidget {
  const MrSubmitReportScreen({super.key});

  @override
  State<MrSubmitReportScreen> createState() => _MrSubmitReportScreenState();
}

class _MrSubmitReportScreenState extends State<MrSubmitReportScreen> {
  final _notesCtrl    = TextEditingController();
  final _followUpCtrl = TextEditingController();
  bool _submitting      = false;
  bool _alreadySubmitted = false;
  List<String> _visitedDoctorNames = [];

  @override
  void initState() {
    super.initState();
    _checkAndLoad();
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    _followUpCtrl.dispose();
    super.dispose();
  }

  String _dateKey(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  Future<void> _checkAndLoad() async {
    final uid = auth.currentUser?.uid;
    if (uid == null) return;
    final today = _dateKey(DateTime.now());

    final existing = await db
        .collection('daily_reports')
        .where('mrId', isEqualTo: uid)
        .where('date', isEqualTo: today)
        .get();
    if (existing.docs.isNotEmpty) {
      if (mounted) setState(() => _alreadySubmitted = true);
      return;
    }

    final visits = await db
        .collection('visits')
        .where('mrId', isEqualTo: uid)
        .where('date', isEqualTo: today)
        .get();
    if (mounted) setState(() {
      _visitedDoctorNames =
          visits.docs.map((d) => d['doctorName'].toString()).toList();
    });
  }

  Future<void> _submit() async {
    final uid = auth.currentUser?.uid;
    if (uid == null) return;
    setState(() => _submitting = true);
    try {
      final today = _dateKey(DateTime.now());

      // Get MR name
      final userDoc = await db.collection('users').doc(uid).get();
      final mrName = userDoc.data()?['name'] ?? 'Unknown MR';

      await db.collection('daily_reports').add({
        'mrId': uid,
        'mrName': mrName,  // ← ADD THIS
        'date': today,
        'doctorsVisited': _visitedDoctorNames,
        'notes': _notesCtrl.text.trim(),
        'followUp': _followUpCtrl.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      });
      await db.collection('attendance').doc('${uid}_$today').set({
        'mrId':      uid,
        'date':      today,
        'status':    'present',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Daily report submitted!'),
            backgroundColor: Colors.green));
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
    if (_alreadySubmitted) {
      return Scaffold(
        appBar: AppBar(title: const Text('Daily Report')),
        body: Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 80),
            const SizedBox(height: 16),
            const Text('Report already submitted for today!',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('You can view it in the Reports tab.',
                style: TextStyle(color: Colors.grey.shade500)),
          ]),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Submit Daily Report')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(children: [
              const Icon(Icons.calendar_today, color: Color(0xFF1565C0), size: 18),
              const SizedBox(width: 10),
              Text('Report for: ${_dateKey(DateTime.now())}',
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, color: Color(0xFF1565C0))),
            ]),
          ),
          const SizedBox(height: 20),

          const Text('Doctors Visited Today',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 8),
          _visitedDoctorNames.isEmpty
              ? Container(
            padding: const EdgeInsets.all(12),
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
                  'No doctor visits recorded today via check-in.',
                  style: TextStyle(color: Colors.orange, fontSize: 13),
                ),
              ),
            ]),
          )
              : Column(
            children: _visitedDoctorNames.map((name) => ListTile(
              dense: true,
              leading: const Icon(Icons.check_circle,
                  color: Colors.green, size: 20),
              title: Text(name),
            )).toList(),
          ),
          const SizedBox(height: 20),

          const Text('Notes / Work Summary',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 8),
          TextField(
            controller: _notesCtrl,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: 'Products promoted, areas covered, any observations...',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
          const SizedBox(height: 16),

          const Text('Follow-up Notes',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 8),
          TextField(
            controller: _followUpCtrl,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Any doctors to revisit, pending actions...',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
          const SizedBox(height: 30),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _submitting ? null : _submit,
              icon: _submitting
                  ? const SizedBox(
                  width: 18, height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.send),
              label: const Text('Submit Report'),
            ),
          ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────
// REPORT DETAIL  (unchanged)
// ─────────────────────────────────────────
class MrReportDetailScreen extends StatelessWidget {
  final Map<String, dynamic> data;
  const MrReportDetailScreen({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final doctors = (data['doctorsVisited'] as List?) ?? [];
    return Scaffold(
      appBar: AppBar(title: Text('Report – ${data['date'] ?? ''}')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _section('Date', data['date'] ?? 'N/A'),
          const SizedBox(height: 16),
          const Text('Doctors Visited',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 8),
          doctors.isEmpty
              ? const Text('None', style: TextStyle(color: Colors.grey))
              : Column(
            children: doctors.map((d) => ListTile(
              dense: true,
              leading: const Icon(Icons.person, color: Color(0xFF1565C0)),
              title: Text(d.toString()),
            )).toList(),
          ),
          if ((data['notes']    ?? '').toString().isNotEmpty) ...[
            const SizedBox(height: 16), _section('Notes',     data['notes']),
          ],
          if ((data['followUp'] ?? '').toString().isNotEmpty) ...[
            const SizedBox(height: 16), _section('Follow-up', data['followUp']),
          ],
        ]),
      ),
    );
  }

  Widget _section(String label, String value) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(
          fontWeight: FontWeight.bold, fontSize: 15)),
      const SizedBox(height: 4),
      Text(value),
    ],
  );
}

// ─────────────────────────────────────────
// APPLY LEAVE  (unchanged)
// ─────────────────────────────────────────
class MrApplyLeaveScreen extends StatefulWidget {
  const MrApplyLeaveScreen({super.key});

  @override
  State<MrApplyLeaveScreen> createState() => _MrApplyLeaveScreenState();
}

class _MrApplyLeaveScreenState extends State<MrApplyLeaveScreen> {
  DateTime? _fromDate;
  DateTime? _toDate;
  final _reasonCtrl = TextEditingController();
  bool _submitting  = false;

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }

  String _fmt(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';

  String _dateKey(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  Future<void> _pickDate(bool isFrom) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate:   DateTime.now(),
      lastDate:    DateTime.now().add(const Duration(days: 90)),
    );
    if (picked == null) return;
    setState(() {
      if (isFrom) {
        _fromDate = picked;
        if (_toDate != null && _toDate!.isBefore(picked)) _toDate = picked;
      } else {
        _toDate = picked;
      }
    });
  }

  int _leaveDays() {
    if (_fromDate == null || _toDate == null) return 0;
    return _toDate!.difference(_fromDate!).inDays + 1;
  }

  Future<void> _submit() async {
    if (_fromDate == null || _toDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select leave dates.')));
      return;
    }
    if (_reasonCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a reason.')));
      return;
    }
    setState(() => _submitting = true);
    try {
      final uid     = auth.currentUser!.uid;
      final userDoc = await db.collection('users').doc(uid).get();
      final mrName  = userDoc.data()?['name'] ?? '';

      await db.collection('leave_requests').add({
        'mrId':      uid,
        'mrName':    mrName,
        'fromDate':  _dateKey(_fromDate!),
        'toDate':    _dateKey(_toDate!),
        'days':      _leaveDays(),
        'reason':    _reasonCtrl.text.trim(),
        'status':    'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Leave request submitted!'),
            backgroundColor: Colors.green));
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
      appBar: AppBar(title: const Text('Apply for Leave')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          const Text('Leave Dates',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _dateTile(
              label: 'From',
              value: _fromDate != null ? _fmt(_fromDate!) : 'Select',
              onTap: () => _pickDate(true),
            )),
            const SizedBox(width: 12),
            Expanded(child: _dateTile(
              label: 'To',
              value: _toDate != null ? _fmt(_toDate!) : 'Select',
              onTap: () => _pickDate(false),
            )),
          ]),

          if (_fromDate != null && _toDate != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('${_leaveDays()} day(s) of leave',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, color: Color(0xFF1565C0))),
            ),
          ],
          const SizedBox(height: 20),

          const Text('Reason',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 8),
          TextField(
            controller: _reasonCtrl,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: 'Reason for leave...',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
          const SizedBox(height: 30),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _submitting ? null : _submit,
              icon: _submitting
                  ? const SizedBox(
                  width: 18, height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.send),
              label: const Text('Submit Leave Request'),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _dateTile({required String label, required String value,
    required VoidCallback onTap}) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade400),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(
                fontWeight: FontWeight.bold, fontSize: 15)),
          ]),
        ),
      );
}

// ─────────────────────────────────────────
// LEAVE HISTORY  (unchanged, + hasError)
// ─────────────────────────────────────────
class MrLeaveHistoryScreen extends StatelessWidget {
  const MrLeaveHistoryScreen({super.key});

  Color _statusColor(String s) {
    switch (s) {
      case 'approved': return Colors.green;
      case 'rejected': return Colors.red;
      default:         return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = auth.currentUser?.uid ?? '';
    return Scaffold(
      appBar: AppBar(title: const Text('Leave History')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const MrApplyLeaveScreen())),
        icon: const Icon(Icons.add),
        label: const Text('Apply Leave'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        // FIX: client-side sort — no composite index needed
        stream: db
            .collection('leave_requests')
            .where('mrId', isEqualTo: uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text('Error: ${snapshot.error}',
                  style: const TextStyle(color: Colors.red)),
            );
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.event_busy_outlined,
                        size: 80, color: Colors.grey.shade300),
                    const SizedBox(height: 16),
                    Text('No leave requests yet',
                        style: TextStyle(color: Colors.grey.shade500, fontSize: 16)),
                  ]),
            );
          }
          // client-side sort by createdAt descending (no composite index needed)
          final leaveDocs = List.of(snapshot.data!.docs)
            ..sort((a, b) {
              final aTs = (a.data() as Map)['createdAt'];
              final bTs = (b.data() as Map)['createdAt'];
              if (aTs == null && bTs == null) return 0;
              if (aTs == null) return 1;
              if (bTs == null) return -1;
              return (bTs as Timestamp).compareTo(aTs as Timestamp);
            });
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: leaveDocs.length,
            itemBuilder: (context, i) {
              final data   = leaveDocs[i].data() as Map<String, dynamic>;
              final status = data['status'] ?? 'pending';
              final color  = _statusColor(status);
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: color.withOpacity(0.15),
                    child: Icon(Icons.event_busy, color: color),
                  ),
                  title: Text('${data['fromDate']} → ${data['toDate']}',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('${data['days']} day(s) • ${data['reason'] ?? ''}'),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(status.toUpperCase(),
                        style: TextStyle(
                            color: color, fontSize: 11,
                            fontWeight: FontWeight.bold)),
                  ),
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
// ATTENDANCE SCREEN  (unchanged)
// ─────────────────────────────────────────
class MrAttendanceScreen extends StatefulWidget {
  const MrAttendanceScreen({super.key});

  @override
  State<MrAttendanceScreen> createState() => _MrAttendanceScreenState();
}

class _MrAttendanceScreenState extends State<MrAttendanceScreen> {
  int _selectedYear  = DateTime.now().year;
  int _selectedMonth = DateTime.now().month;

  final List<String> _months = [
    'Jan','Feb','Mar','Apr','May','Jun',
    'Jul','Aug','Sep','Oct','Nov','Dec',
  ];

  String _padded(int n) => n.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    final uid          = auth.currentUser?.uid ?? '';
    final start        = '$_selectedYear-${_padded(_selectedMonth)}-01';
    final daysInMonth  = DateUtils.getDaysInMonth(_selectedYear, _selectedMonth);
    final end          =
        '$_selectedYear-${_padded(_selectedMonth)}-${_padded(daysInMonth)}';

    return Scaffold(
      appBar: AppBar(title: const Text('Attendance')),
      body: Column(children: [
        // Month selector
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                onPressed: () => setState(() {
                  if (_selectedMonth == 1) { _selectedMonth = 12; _selectedYear--; }
                  else { _selectedMonth--; }
                }),
                icon: const Icon(Icons.chevron_left),
              ),
              Text('${_months[_selectedMonth - 1]} $_selectedYear',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              IconButton(
                onPressed: () => setState(() {
                  if (_selectedMonth == 12) { _selectedMonth = 1; _selectedYear++; }
                  else { _selectedMonth++; }
                }),
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
        ),

        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            // FIX: only range-filter on 'date' (single-field index) — mrId filtered client-side.
            stream: db
                .collection('attendance')
                .where('date', isGreaterThanOrEqualTo: start)
                .where('date', isLessThanOrEqualTo: end)
                .orderBy('date')
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              // client-side mrId filter (mrId was removed from query to avoid composite index)
              final allDocs = snapshot.data?.docs ?? [];
              final docs = allDocs.where((d) =>
              (d.data() as Map)['mrId']?.toString() == uid).toList();
              final attMap = <String, String>{
                for (var d in docs)
                  (d.data() as Map)['date'].toString():
                  (d.data() as Map)['status'].toString()
              };

              int present = 0, absent = 0, leave = 0;
              for (final s in attMap.values) {
                if (s == 'present') present++;
                else if (s == 'absent') absent++;
                else if (s == 'leave') leave++;
              }

              return Column(children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(children: [
                    _attStat('Present', present, Colors.green),
                    _attStat('Absent',  absent,  Colors.red),
                    _attStat('Leave',   leave,   Colors.orange),
                  ]),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 7,
                      crossAxisSpacing: 6,
                      mainAxisSpacing: 6,
                    ),
                    itemCount: daysInMonth,
                    itemBuilder: (context, i) {
                      final day     = i + 1;
                      final dateStr =
                          '$_selectedYear-${_padded(_selectedMonth)}-${_padded(day)}';
                      final dt      = DateTime(_selectedYear, _selectedMonth, day);
                      final isSunday = dt.weekday == DateTime.sunday;
                      final status   = attMap[dateStr];
                      final isFuture = dt.isAfter(DateTime.now());

                      Color bgColor   = Colors.grey.shade100;
                      Color textColor = Colors.grey.shade700;
                      if (isSunday) {
                        bgColor   = Colors.grey.shade200;
                        textColor = Colors.grey.shade400;
                      } else if (!isFuture) {
                        if (status == 'present') {
                          bgColor   = Colors.green.shade100;
                          textColor = Colors.green.shade800;
                        } else if (status == 'absent') {
                          bgColor   = Colors.red.shade100;
                          textColor = Colors.red.shade800;
                        } else if (status == 'leave') {
                          bgColor   = Colors.orange.shade100;
                          textColor = Colors.orange.shade800;
                        }
                      }

                      return Container(
                        decoration: BoxDecoration(
                          color: bgColor,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('$day', style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: textColor, fontSize: 13)),
                            if (status != null && !isSunday)
                              Text(
                                status == 'present' ? 'P'
                                    : status == 'absent' ? 'A' : 'L',
                                style: TextStyle(
                                    fontSize: 9, color: textColor,
                                    fontWeight: FontWeight.w600),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    _legend('Present', Colors.green),
                    const SizedBox(width: 16),
                    _legend('Absent',  Colors.red),
                    const SizedBox(width: 16),
                    _legend('Leave',   Colors.orange),
                    const SizedBox(width: 16),
                    _legend('Sunday',  Colors.grey),
                  ]),
                ),
              ]);
            },
          ),
        ),
      ]),
    );
  }

  Widget _attStat(String label, int count, Color color) => Expanded(
    child: Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(children: [
        Text('$count', style: TextStyle(
            fontSize: 22, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ]),
    ),
  );

  Widget _legend(String label, Color color) => Row(children: [
    Container(
        width: 12, height: 12,
        decoration: BoxDecoration(
            color: color.withOpacity(0.3),
            borderRadius: BorderRadius.circular(3))),
    const SizedBox(width: 4),
    Text(label, style: const TextStyle(fontSize: 11)),
  ]);
}

// ─────────────────────────────────────────
// ALLOWANCE SCREEN  (unchanged)
// ─────────────────────────────────────────
class MrAllowanceScreen extends StatelessWidget {
  const MrAllowanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = auth.currentUser?.uid ?? '';
    return Scaffold(
      appBar: AppBar(title: const Text('My Allowance')),
      body: FutureBuilder<DocumentSnapshot>(
        future: db.collection('users').doc(uid).get(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final userData       = snap.data?.data() as Map<String, dynamic>? ?? {};
          final fixedAllowance = userData['fixedAllowance'] ?? 0;

          return StreamBuilder<QuerySnapshot>(
            // FIX: client-side sort — no composite index needed
            stream: db
                .collection('allowances')
                .where('mrId', isEqualTo: uid)
                .snapshots(),
            builder: (context, snapshot) {
              // client-side sort by month descending
              final docs = List.of(snapshot.data?.docs ?? [])
                ..sort((a, b) {
                  final aM = (a.data() as Map)['month']?.toString() ?? '';
                  final bM = (b.data() as Map)['month']?.toString() ?? '';
                  return bM.compareTo(aM);
                });
              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                              colors: [Color(0xFF1565C0), Color(0xFF1E88E5)]),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(children: [
                          const Text('Fixed Monthly Allowance',
                              style: TextStyle(color: Colors.white70, fontSize: 14)),
                          const SizedBox(height: 8),
                          Text('₹${fixedAllowance.toString()}',
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 36,
                                  fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          const Text('per month',
                              style: TextStyle(color: Colors.white70)),
                        ]),
                      ),
                      const SizedBox(height: 20),
                      const Text('Allowance History',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 12),
                      if (docs.isEmpty)
                        Center(
                          child: Column(children: [
                            Icon(Icons.account_balance_wallet_outlined,
                                size: 60, color: Colors.grey.shade300),
                            const SizedBox(height: 12),
                            Text('No records yet',
                                style: TextStyle(color: Colors.grey.shade500)),
                          ]),
                        )
                      else
                        ...docs.map((doc) {
                          final d = doc.data() as Map<String, dynamic>;
                          return Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            child: ListTile(
                              leading: const CircleAvatar(
                                backgroundColor: Color(0xFFE3F2FD),
                                child: Icon(Icons.account_balance_wallet,
                                    color: Color(0xFF1565C0)),
                              ),
                              title: Text(d['month'] ?? '',
                                  style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text(
                                  'Working days: ${d['workingDays'] ?? '-'}'),
                              trailing: Text('₹${d['amount'] ?? ''}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16, color: Color(0xFF1565C0))),
                            ),
                          );
                        }),
                    ]),
              );
            },
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────
// NOTIFICATIONS  (unchanged)
// ─────────────────────────────────────────
class MrNotificationsScreen extends StatelessWidget {
  const MrNotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = auth.currentUser?.uid ?? '';
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: StreamBuilder<QuerySnapshot>(
        // FIX: client-side sort — no composite index needed
        stream: db
            .collection('notifications')
            .where('mrId', isEqualTo: uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.notifications_none,
                        size: 80, color: Colors.grey.shade300),
                    const SizedBox(height: 16),
                    Text('No notifications',
                        style: TextStyle(color: Colors.grey.shade500, fontSize: 16)),
                  ]),
            );
          }
          // client-side sort by createdAt descending (no composite index needed)
          final notifDocs = List.of(snapshot.data!.docs)
            ..sort((a, b) {
              final aTs = (a.data() as Map)['createdAt'];
              final bTs = (b.data() as Map)['createdAt'];
              if (aTs == null && bTs == null) return 0;
              if (aTs == null) return 1;
              if (bTs == null) return -1;
              return (bTs as Timestamp).compareTo(aTs as Timestamp);
            });
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: notifDocs.length,
            itemBuilder: (context, i) {
              final data   = notifDocs[i].data() as Map<String, dynamic>;
              final isRead = data['isRead'] ?? false;
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                color: isRead ? Colors.white : Colors.blue.shade50,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: const Color(0xFF1565C0).withOpacity(0.15),
                    child: const Icon(Icons.notifications,
                        color: Color(0xFF1565C0)),
                  ),
                  title: Text(data['title'] ?? '',
                      style: TextStyle(
                          fontWeight: isRead
                              ? FontWeight.normal
                              : FontWeight.bold)),
                  subtitle: Text(data['body'] ?? ''),
                  onTap: () async {
                    await snapshot.data!.docs[i].reference
                        .update({'isRead': true});
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
// MR PROFILE  (unchanged)
// ─────────────────────────────────────────
class MrProfileScreen extends StatelessWidget {
  const MrProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = auth.currentUser?.uid ?? '';
    return Scaffold(
      appBar: AppBar(title: const Text('My Profile')),
      body: FutureBuilder<DocumentSnapshot>(
        future: db.collection('users').doc(uid).get(),
        builder: (context, snap) {
          final userData = snap.data?.data() as Map<String, dynamic>? ?? {};
          final name  = userData['name']  ?? 'Medical Representative';
          final email = userData['email'] ?? auth.currentUser?.email ?? '';
          final phone = userData['phone'] ?? '';
          final area  = userData['area']  ?? '';

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
                    radius: 40,
                    backgroundColor: Colors.white,
                    child: Icon(Icons.person, size: 50, color: Color(0xFF1565C0)),
                  ),
                  const SizedBox(height: 12),
                  Text(name, style: const TextStyle(
                      color: Colors.white, fontSize: 18,
                      fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(email, style: const TextStyle(
                      color: Colors.white70, fontSize: 13)),
                  if (phone.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(phone, style: const TextStyle(
                        color: Colors.white70, fontSize: 13)),
                  ],
                  if (area.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text('Area: $area',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 12)),
                    ),
                  ],
                ]),
              ),
              const SizedBox(height: 20),

              _profileMenuItem(Icons.calendar_today, 'Attendance', () {
                Navigator.push(context, MaterialPageRoute(
                    builder: (_) => const MrAttendanceScreen()));
              }),
              _profileMenuItem(Icons.event_busy, 'Leave History', () {
                Navigator.push(context, MaterialPageRoute(
                    builder: (_) => const MrLeaveHistoryScreen()));
              }),
              _profileMenuItem(Icons.account_balance_wallet, 'My Allowance', () {
                Navigator.push(context, MaterialPageRoute(
                    builder: (_) => const MrAllowanceScreen()));
              }),
              _profileMenuItem(Icons.history, 'Order History', () {
                Navigator.push(context, MaterialPageRoute(
                    builder: (_) => const MrOrdersScreen()));
              }),
              _profileMenuItem(Icons.lock_outline, 'Change Password', () {
                Navigator.push(context, MaterialPageRoute(
                    builder: (_) => const MrChangePasswordScreen()));
              }),
              const SizedBox(height: 10),

              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: const Icon(Icons.logout, color: Colors.red),
                  title: const Text('Logout',
                      style: TextStyle(
                          color: Colors.red, fontWeight: FontWeight.w600)),
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

  Widget _profileMenuItem(IconData icon, String label, VoidCallback onTap) =>
      Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          leading: Icon(icon, color: const Color(0xFF1565C0)),
          title: Text(label),
          trailing: const Icon(Icons.chevron_right, color: Colors.grey),
          onTap: onTap,
        ),
      );
}

// ─────────────────────────────────────────
// CHANGE PASSWORD  (unchanged)
// ─────────────────────────────────────────
class MrChangePasswordScreen extends StatefulWidget {
  const MrChangePasswordScreen({super.key});

  @override
  State<MrChangePasswordScreen> createState() =>
      _MrChangePasswordScreenState();
}

class _MrChangePasswordScreenState extends State<MrChangePasswordScreen> {
  final _currentCtrl  = TextEditingController();
  final _newCtrl      = TextEditingController();
  final _confirmCtrl  = TextEditingController();
  bool _loading        = false;
  bool _obscureCurrent = true;
  bool _obscureNew     = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _changePassword() async {
    if (_newCtrl.text != _confirmCtrl.text) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('New passwords do not match.')));
      return;
    }
    if (_newCtrl.text.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Password must be at least 6 characters.')));
      return;
    }
    setState(() => _loading = true);
    try {
      final user = auth.currentUser!;
      final cred = EmailAuthProvider.credential(
          email: user.email!, password: _currentCtrl.text);
      await user.reauthenticateWithCredential(cred);
      await user.updatePassword(_newCtrl.text);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Password changed successfully!'),
            backgroundColor: Colors.green));
      }
    } on FirebaseAuthException catch (e) {
      String msg = 'Error changing password.';
      if (e.code == 'wrong-password') msg = 'Current password is incorrect.';
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Change Password')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          const SizedBox(height: 20),
          _passwordField('Current Password', _currentCtrl, _obscureCurrent,
                  () => setState(() => _obscureCurrent = !_obscureCurrent)),
          const SizedBox(height: 16),
          _passwordField('New Password', _newCtrl, _obscureNew,
                  () => setState(() => _obscureNew = !_obscureNew)),
          const SizedBox(height: 16),
          _passwordField('Confirm New Password', _confirmCtrl, _obscureConfirm,
                  () => setState(() => _obscureConfirm = !_obscureConfirm)),
          const SizedBox(height: 30),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _loading ? null : _changePassword,
              child: _loading
                  ? const SizedBox(
                  width: 20, height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
                  : const Text('Update Password'),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _passwordField(String label, TextEditingController ctrl,
      bool obscure, VoidCallback toggle) =>
      TextField(
        controller: ctrl,
        obscureText: obscure,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.lock_outline),
          suffixIcon: IconButton(
            icon: Icon(obscure ? Icons.visibility_off : Icons.visibility),
            onPressed: toggle,
          ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
}