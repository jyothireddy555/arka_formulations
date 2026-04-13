import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'notification_service.dart'; // Added for notification deep-link fix
import 'admin_mr_visit_history_screen.dart';
import 'package:flutter/services.dart'; // ensure this is at top
import 'package:url_launcher/url_launcher.dart';


final FirebaseAuth _auth = FirebaseAuth.instance;
final FirebaseFirestore _db = FirebaseFirestore.instance;

// ─────────────────────────────────────────
// ADMIN MAIN SCREEN
// ─────────────────────────────────────────
class AdminMainScreen extends StatefulWidget {
  const AdminMainScreen({super.key});

  @override
  State<AdminMainScreen> createState() => _AdminMainScreenState();
}

class _AdminMainScreenState extends State<AdminMainScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const AdminDashboardScreen(),
    const AdminStockScreen(),
    const AdminOrdersScreen(),
    const AdminMrManagementScreen(),
    const AdminProfileScreen(),
  ];

  // Handler for notification deep-links
  void _onNotificationTab() {
    final idx = NotificationService.tabIndexNotifier.value;
    if (idx != null && idx < _screens.length) {
      setState(() => _currentIndex = idx);
      NotificationService.tabIndexNotifier.value = null;
    }
  }

  @override
  void initState() {
    super.initState();
    // Add listener for notification deep-links
    NotificationService.tabIndexNotifier.addListener(_onNotificationTab);
  }

  @override
  void dispose() {
    // Remove listener to prevent memory leaks
    NotificationService.tabIndexNotifier.removeListener(_onNotificationTab);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;

        // If not on dashboard (index 0), go to dashboard
        if (_currentIndex != 0) {
          setState(() => _currentIndex = 0);
          return;
        }

        // If on dashboard, show exit confirmation dialog
        final shouldExit = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(children: [
              Icon(Icons.exit_to_app, color: Colors.red),
              SizedBox(width: 8),
              Text('Exit App'),
            ]),
            content: const Text('Are you sure you want to exit?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Exit', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        );

        if (shouldExit == true && context.mounted) {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        body: _screens[_currentIndex],
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          type: BottomNavigationBarType.fixed,
          selectedItemColor: const Color(0xFF1565C0),
          unselectedItemColor: Colors.grey,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Dashboard'),
            BottomNavigationBarItem(icon: Icon(Icons.inventory_2), label: 'Stock'),
            BottomNavigationBarItem(icon: Icon(Icons.shopping_bag), label: 'Orders'),
            BottomNavigationBarItem(icon: Icon(Icons.badge), label: 'MRs'),
            BottomNavigationBarItem(icon: Icon(Icons.manage_accounts), label: 'Manage'),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────
// ADMIN DASHBOARD
// ─────────────────────────────────────────
class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        actions: [
          StreamBuilder<QuerySnapshot>(
            stream: _db.collection('leave_requests')
                .where('status', isEqualTo: 'pending')
                .snapshots(),
            builder: (context, leaveSnap) {
              return StreamBuilder<QuerySnapshot>(
                stream: _db.collection('gps_override_requests')
                    .where('status', isEqualTo: 'pending')
                    .snapshots(),
                builder: (context, gpsSnap) {
                  final pendingLeave = leaveSnap.hasData ? leaveSnap.data!.docs.length : 0;
                  final pendingGps   = gpsSnap.hasData ? gpsSnap.data!.docs.length : 0;
                  final total        = pendingLeave + pendingGps;

                  return Stack(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.notifications_outlined),
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AdminApprovalsScreen(),
                          ),
                        ),
                      ),
                      if (total > 0)
                        Positioned(
                          right: 6,
                          top: 6,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              total > 9 ? '9+' : '$total',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              );
            },
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [Color(0xFF1565C0), Color(0xFF1E88E5)]),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Welcome, Admin 👋',
                      style:
                      TextStyle(color: Colors.white70, fontSize: 14)),
                  SizedBox(height: 4),
                  Text('Arka Formulations',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Text('Overview',
                style:
                TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            StreamBuilder<QuerySnapshot>(
              stream: _db
                  .collection('users')
                  .where('role', isEqualTo: 'mr')
                  .snapshots(),
              builder: (context, mrSnap) {
                final mrCount =
                mrSnap.hasData ? mrSnap.data!.docs.length : 0;
                return StreamBuilder<QuerySnapshot>(
                  stream: _db.collection('doctors').snapshots(),
                  builder: (context, docSnap) {
                    final doctorCount =
                    docSnap.hasData ? docSnap.data!.docs.length : 0;
                    return StreamBuilder<QuerySnapshot>(
                      stream: _db
                          .collection('orders')
                          .where('status', isEqualTo: 'pending')
                          .snapshots(),
                      builder: (context, orderSnap) {
                        final pendingOrders = orderSnap.hasData
                            ? orderSnap.data!.docs.length
                            : 0;
                        return StreamBuilder<QuerySnapshot>(
                          stream: _db
                              .collection('leave_requests')
                              .where('status', isEqualTo: 'pending')
                              .snapshots(),
                          builder: (context, leaveSnap) {
                            final pendingLeaves = leaveSnap.hasData
                                ? leaveSnap.data!.docs.length
                                : 0;
                            final today =
                                '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}';
                            return StreamBuilder<QuerySnapshot>(
                              stream: _db
                                  .collection('orders')
                                  .where('status', isEqualTo: 'dispatched')
                                  .snapshots(),
                              builder: (context, dispatchSnap) {
                                final dispatched = dispatchSnap.hasData
                                    ? dispatchSnap.data!.docs.length
                                    : 0;
                                return StreamBuilder<QuerySnapshot>(
                                  stream: _db
                                      .collection('daily_reports')
                                      .where('date', isEqualTo: today)
                                      .snapshots(),
                                  builder: (context, reportSnap) {
                                    final todayReports = reportSnap.hasData
                                        ? reportSnap.data!.docs.length
                                        : 0;
                                    return StreamBuilder<QuerySnapshot>(
                                      stream: _db
                                          .collection('users')
                                          .where('role', isEqualTo: 'stockist')
                                          .snapshots(),
                                      builder: (context, stockistSnap) {
                                        final stockistCount = stockistSnap.hasData
                                            ? stockistSnap.data!.docs.length
                                            : 0;
                                        return GridView.count(
                                          crossAxisCount: 2,
                                          shrinkWrap: true,
                                          physics:
                                          const NeverScrollableScrollPhysics(),
                                          crossAxisSpacing: 12,
                                          mainAxisSpacing: 12,
                                          childAspectRatio: 1.6,
                                          children: [
                                            _statCard('Total MRs', '$mrCount',
                                                Icons.badge, Colors.blue),
                                            _statCard(
                                                'Total Doctors',
                                                '$doctorCount',
                                                Icons.people,
                                                Colors.green),
                                            _statCard(
                                                'Pending Orders',
                                                '$pendingOrders',
                                                Icons.pending_actions,
                                                Colors.orange),
                                            _statCard(
                                                'Leave Requests',
                                                '$pendingLeaves',
                                                Icons.event_busy,
                                                Colors.red),
                                            _statCard(
                                                'Dispatched',
                                                '$dispatched',
                                                Icons.local_shipping,
                                                Colors.teal),
                                            _statCard(
                                                'Reports Today',
                                                '$todayReports',
                                                Icons.assignment_turned_in,
                                                Colors.purple),
                                            _statCard(
                                                'Stockists',
                                                '$stockistCount',
                                                Icons.store,
                                                Colors.brown),
                                          ],
                                        );
                                      },
                                    );
                                  },
                                );
                              },
                            );
                          },
                        );
                      },
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _statCard(
      String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(value,
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: color)),
              Text(label,
                  style: const TextStyle(
                      fontSize: 11, color: Colors.grey)),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────
// ADMIN DOCTORS SCREEN
// ─────────────────────────────────────────
class AdminDoctorsScreen extends StatefulWidget {
  const AdminDoctorsScreen({super.key});

  @override
  State<AdminDoctorsScreen> createState() => _AdminDoctorsScreenState();
}

class _AdminDoctorsScreenState extends State<AdminDoctorsScreen> {
  String _searchQuery = '';
  String _filterDivision = 'All';
  String _filterTier = 'All';
  final List<String> _divisions = [
    'All', 'Ortho', 'Gynec', 'General'
  ];
  final List<String> _tiers = [
    'All', 'Core', 'Super Core', 'Premium'
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Doctor Management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AddDoctorScreen()),
            ),
          ),
        ],
      ),

      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              onChanged: (val) =>
                  setState(() => _searchQuery = val.toLowerCase()),
              decoration: InputDecoration(
                hintText: 'Search doctors...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () =>
                      setState(() => _searchQuery = ''),
                )
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
                final isSelected = _filterDivision == div;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(div),
                    selected: isSelected,
                    onSelected: (_) =>
                        setState(() => _filterDivision = div),
                    selectedColor:
                    const Color(0xFF1565C0).withOpacity(0.2),
                    checkmarkColor: const Color(0xFF1565C0),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 4),
          SizedBox(
            height: 40,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: _tiers.length,
              itemBuilder: (context, index) {
                final tier = _tiers[index];
                final isSelected = _filterTier == tier;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(tier),
                    selected: isSelected,
                    onSelected: (_) =>
                        setState(() => _filterTier = tier),
                    selectedColor: Colors.purple.withOpacity(0.2),
                    checkmarkColor: Colors.purple,
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _db
                  .collection('doctors')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text('Error: ${snapshot.error}',
                          style: const TextStyle(color: Colors.red)),
                    ),
                  );
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.people_outline,
                            size: 80, color: Colors.grey.shade300),
                        const SizedBox(height: 16),
                        Text('No doctors added yet',
                            style: TextStyle(
                                color: Colors.grey.shade500,
                                fontSize: 16)),
                        const SizedBox(height: 8),
                        Text('Tap + Add Doctor to get started',
                            style: TextStyle(
                                color: Colors.grey.shade400,
                                fontSize: 13)),
                      ],
                    ),
                  );
                }

                var docs = snapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final name =
                  (data['name'] ?? '').toString().toLowerCase();
                  final hospital = (data['hospital'] ?? '')
                      .toString()
                      .toLowerCase();
                  final division =
                  (data['division'] ?? '').toString();
                  final tier =
                  (data['tier'] ?? 'Normal').toString();

                  final matchesSearch = _searchQuery.isEmpty ||
                      name.contains(_searchQuery) ||
                      hospital.contains(_searchQuery);

                  final matchesDivision =
                      _filterDivision == 'All' ||
                          division == _filterDivision;

                  final matchesTier =
                      _filterTier == 'All' || tier == _filterTier;

                  return matchesSearch && matchesDivision && matchesTier;
                }).toList();

                if (docs.isEmpty) {
                  return Center(
                    child: Text(
                      'No doctors found',
                      style: TextStyle(
                          color: Colors.grey.shade500, fontSize: 16),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data =
                    docs[index].data() as Map<String, dynamic>;
                    final docId = docs[index].id;
                    return _AdminDoctorCard(
                      data: data,
                      docId: docId,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────
// ADMIN DOCTOR CARD WIDGET
// ─────────────────────────────────────────
class _AdminDoctorCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final String docId;

  const _AdminDoctorCard({
    required this.data,
    required this.docId,
  });

  Color _divisionColor(String division) {
    switch (division) {
      case 'Ortho':
        return Colors.blue;
      case 'Gynec':
        return Colors.pink;
      default:
        return Colors.green;
    }
  }

  Color _tierColor(String tier) {
    switch (tier) {
      case 'Premium':
        return Colors.purple;
      case 'Super Core':
        return Colors.orange;
      case 'Core':
        return Colors.teal;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final division = data['division'] ?? 'General';
    final color = _divisionColor(division);
    final tier = data['tier'] ?? 'Normal';
    final tierColor = _tierColor(tier);
    final hasLocation = data['latitude'] != null &&
        data['longitude'] != null;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: color.withOpacity(0.15),
                  child: Icon(Icons.person, color: color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data['name'] ?? 'Unknown',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15),
                      ),
                      Text(
                        data['specialization'] ?? '',
                        style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 13),
                      ),
                      Text(
                        data['hospital'] ?? '',
                        style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 12),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton(
                  icon: const Icon(Icons.more_vert),
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                        value: 'orders', child: Row(children: [
                      Icon(Icons.bar_chart, size: 18, color: Colors.blue),
                      SizedBox(width: 8),
                      Text('Order Summary'),
                    ])),
                    const PopupMenuItem(
                        value: 'edit', child: Row(children: [
                      Icon(Icons.edit, size: 18, color: Colors.orange),
                      SizedBox(width: 8),
                      Text('Edit'),
                    ])),
                    const PopupMenuItem(
                        value: 'delete',
                        child: Row(children: [
                          Icon(Icons.delete, size: 18, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Delete',
                              style: TextStyle(color: Colors.red)),
                        ])),
                  ],
                  onSelected: (value) async {
                    if (value == 'orders') {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => DoctorOrderSummaryScreen(
                            doctorId:   docId,
                            doctorName: data['name'] ?? 'Doctor',
                          ),
                        ),
                      );
                    } else if (value == 'edit') {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AddDoctorScreen(
                            existingData: data,
                            docId: docId,
                          ),
                        ),
                      );
                    } else if (value == 'delete') {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: const Text('Delete Doctor'),
                          content: Text(
                              'Are you sure you want to delete ${data['name']}?'),
                          actions: [
                            TextButton(
                                onPressed: () =>
                                    Navigator.pop(context, false),
                                child: const Text('Cancel')),
                            TextButton(
                                onPressed: () =>
                                    Navigator.pop(context, true),
                                child: const Text('Delete',
                                    style: TextStyle(
                                        color: Colors.red))),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        await _db
                            .collection('doctors')
                            .doc(docId)
                            .delete();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Doctor deleted'),
                                backgroundColor: Colors.red),
                          );
                        }
                      }
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(division,
                      style: TextStyle(
                          color: color,
                          fontSize: 11,
                          fontWeight: FontWeight.w600)),
                ),
                if (tier != 'Normal')
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: tierColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: tierColor.withOpacity(0.5)),
                    ),
                    child: Text(tier,
                        style: TextStyle(
                            color: tierColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w600)),
                  ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: hasLocation
                        ? Colors.green.withOpacity(0.1)
                        : Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        hasLocation
                            ? Icons.location_on
                            : Icons.location_off,
                        size: 12,
                        color:
                        hasLocation ? Colors.green : Colors.orange,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        hasLocation
                            ? 'Location set'
                            : 'No location',
                        style: TextStyle(
                          fontSize: 11,
                          color: hasLocation
                              ? Colors.green
                              : Colors.orange,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (data['totalOrderValue'] != null && data['totalOrderValue'] > 0)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Total Orders: ₹${data['totalOrderValue']}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.purple.shade700,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────
// ADD / EDIT DOCTOR SCREEN
// ─────────────────────────────────────────
class AddDoctorScreen extends StatefulWidget {
  final Map<String, dynamic>? existingData;
  final String? docId;

  const AddDoctorScreen({super.key, this.existingData, this.docId});

  @override
  State<AddDoctorScreen> createState() => _AddDoctorScreenState();
}

class _AddDoctorScreenState extends State<AddDoctorScreen> {
  final _nameController = TextEditingController();
  final _specializationController = TextEditingController();
  final _hospitalController = TextEditingController();
  final _areaController = TextEditingController();
  final _addressController = TextEditingController();
  final _contactController    = TextEditingController();
  final _licence20bController = TextEditingController();
  final _licence21bController = TextEditingController();
  final _gstController        = TextEditingController();

  String _selectedDivision = 'Ortho';
  double? _latitude;
  double? _longitude;
  bool _isLoading = false;
  bool _isFetchingLocation = false;
  String _errorMessage = '';
  bool get _isEditing => widget.existingData != null;

  final List<String> _divisions = ['Ortho', 'Gynec', 'General'];
  final List<String> _specializations = [
    'Orthopedic Surgeon',
    'Gynecologist',
    'General Physician',
    'Pediatrician',
    'Cardiologist',
    'Dermatologist',
    'ENT Specialist',
    'Other',
  ];
  String _selectedSpecialization = 'Orthopedic Surgeon';

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final d = widget.existingData!;
      _nameController.text = d['name'] ?? '';
      _hospitalController.text = d['hospital'] ?? '';
      _areaController.text = d['area'] ?? '';
      _addressController.text = d['address'] ?? '';
      _selectedDivision = d['division'] ?? 'Ortho';
      _selectedSpecialization =
          d['specialization'] ?? 'Orthopedic Surgeon';
      _latitude = d['latitude'];
      _longitude = d['longitude'];
      _contactController.text    = d['contact']    ?? '';
      _licence20bController.text = d['licence20b'] ?? '';
      _licence21bController.text = d['licence21b'] ?? '';
      _gstController.text        = d['gst']        ?? '';
    }
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isFetchingLocation = true);

    try {
      LocationPermission permission =
      await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _isFetchingLocation = false;
            _errorMessage = 'Location permission denied.';
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _isFetchingLocation = false;
          _errorMessage =
          'Location permission permanently denied. Please enable in settings.';
        });
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
        _isFetchingLocation = false;
        _errorMessage = '';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '✅ Location captured: ${_latitude!.toStringAsFixed(4)}, ${_longitude!.toStringAsFixed(4)}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isFetchingLocation = false;
        _errorMessage = 'Failed to get location. Please try again.';
      });
    }
  }

  // ── ADD THIS METHOD to _AddDoctorScreenState ──────────────
  void _showManualCoordinatesDialog() {
    final latCtrl = TextEditingController(
        text: _latitude != null ? _latitude!.toStringAsFixed(6) : '');
    final lngCtrl = TextEditingController(
        text: _longitude != null ? _longitude!.toStringAsFixed(6) : '');

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Row(children: [
          Icon(Icons.location_on, color: Color(0xFF1565C0)),
          SizedBox(width: 8),
          Text('Enter Coordinates'),
        ]),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(children: [
                Icon(Icons.info_outline, color: Colors.blue, size: 14),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Open Google Maps → long press on location → copy coordinates.',
                    style: TextStyle(fontSize: 11, color: Colors.blue),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 14),
            const Text('Latitude', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 6),
            TextField(
              controller: latCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                  decimal: true, signed: true),
              decoration: const InputDecoration(
                hintText: 'e.g. 14.442453',
                prefixIcon: Icon(Icons.my_location, size: 18),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
            const SizedBox(height: 12),
            const Text('Longitude', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 6),
            TextField(
              controller: lngCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                  decimal: true, signed: true),
              decoration: const InputDecoration(
                hintText: 'e.g. 79.986450',
                prefixIcon: Icon(Icons.my_location, size: 18),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
            ],
          ),  // Column
        ), // SingleChildScrollView
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final lat = double.tryParse(latCtrl.text.trim());
              final lng = double.tryParse(lngCtrl.text.trim());
              if (lat == null || lng == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Please enter valid numbers for both fields.'),
                      backgroundColor: Colors.red),
                );
                return;
              }
              if (lat < -90 || lat > 90) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Latitude must be between -90 and 90.'),
                      backgroundColor: Colors.red),
                );
                return;
              }
              if (lng < -180 || lng > 180) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Longitude must be between -180 and 180.'),
                      backgroundColor: Colors.red),
                );
                return;
              }
              setState(() {
                _latitude  = lat;
                _longitude = lng;
                _errorMessage = '';
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                      '✅ Location set: ${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: const Text('Set Location'),
          ),
        ],
      ),
    );
  }

  Future<void> _openInMaps(double lat, double lng) async {
    final uri = Uri.parse('https://www.google.com/maps?q=$lat,$lng');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open Google Maps.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _saveDoctor() async {
    final name = _nameController.text.trim();
    final hospital = _hospitalController.text.trim();
    final area = _areaController.text.trim();

    if (name.isEmpty || hospital.isEmpty || area.isEmpty) {
      setState(
              () => _errorMessage = 'Please fill name, hospital and area.');
      return;
    }

    if (_latitude == null || _longitude == null) {
      setState(() =>
      _errorMessage = 'Please capture the doctor\'s location first.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final data = {
        'name': name,
        'specialization': _selectedSpecialization,
        'hospital': hospital,
        'area': area,
        'address': _addressController.text.trim(),
        'contact':    _contactController.text.trim(),
        'licence20b': _licence20bController.text.trim(),
        'licence21b': _licence21bController.text.trim(),
        'gst':        _gstController.text.trim(),
        'division': _selectedDivision,
        'latitude': _latitude,
        'longitude': _longitude,
        'tier': 'Normal',
        'totalOrderValue': 0,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (_isEditing) {
        await _db
            .collection('doctors')
            .doc(widget.docId)
            .update(data);
      } else {
        data['isActive'] = true;
        data['createdAt'] = FieldValue.serverTimestamp();
        data['createdBy'] = _auth.currentUser!.uid;
        await _db.collection('doctors').add(data);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEditing
                ? '✅ Doctor updated successfully!'
                : '✅ Doctor added successfully!'),
            backgroundColor: Colors.green,
          ),
        );
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
  void dispose() {
    _nameController.dispose();
    _specializationController.dispose();
    _hospitalController.dispose();
    _areaController.dispose();
    _addressController.dispose();
    _contactController.dispose();
    _licence20bController.dispose();
    _licence21bController.dispose();
    _gstController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: Text(_isEditing ? 'Edit Doctor' : 'Add Doctor')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _label('Doctor Name'),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                hintText: 'e.g. Dr. Ramesh Kumar',
                prefixIcon: Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: 14),
            _label('Specialization'),
            DropdownButtonFormField<String>(
              value: _selectedSpecialization,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.medical_information_outlined),
              ),
              items: _specializations
                  .map((s) =>
                  DropdownMenuItem(value: s, child: Text(s)))
                  .toList(),
              onChanged: (val) =>
                  setState(() => _selectedSpecialization = val!),
            ),
            const SizedBox(height: 14),
            _label('Hospital / Clinic Name'),
            TextField(
              controller: _hospitalController,
              decoration: const InputDecoration(
                hintText: 'e.g. City Hospital',
                prefixIcon: Icon(Icons.local_hospital_outlined),
              ),
            ),
            const SizedBox(height: 14),
            _label('Area'),
            TextField(
              controller: _areaController,
              decoration: const InputDecoration(
                hintText: 'e.g. Nellore North',
                prefixIcon: Icon(Icons.map_outlined),
              ),
            ),
            const SizedBox(height: 14),
            _label('Full Address (Optional)'),
            TextField(
              controller: _addressController,
              maxLines: 2,
              decoration: const InputDecoration(
                hintText: 'Enter full address...',
                prefixIcon: Icon(Icons.location_on_outlined),
              ),
            ),
            const SizedBox(height: 14),
            _label('Contact Number (Optional)'),
            TextField(
              controller: _contactController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                hintText: 'e.g. 9876543210',
                prefixIcon: Icon(Icons.phone_outlined),
              ),
            ),
            const SizedBox(height: 14),
            _label('Drug Licence (Optional)'),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.blue.shade100),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('20B Licence No.',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _licence20bController,
                    decoration: const InputDecoration(
                      hintText: 'e.g. DL-20B-XXXXX',
                      prefixIcon: Icon(Icons.badge_outlined, size: 18),
                      contentPadding:
                      EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text('21B Licence No.',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _licence21bController,
                    decoration: const InputDecoration(
                      hintText: 'e.g. DL-21B-XXXXX',
                      prefixIcon: Icon(Icons.badge_outlined, size: 18),
                      contentPadding:
                      EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _label('GST Number (Optional)'),
            TextField(
              controller: _gstController,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                hintText: 'e.g. 29ABCDE1234F1Z5',
                prefixIcon: Icon(Icons.receipt_long_outlined),
              ),
            ),
            const SizedBox(height: 14),
            _label('Division'),
            DropdownButtonFormField<String>(
              value: _selectedDivision,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.category_outlined),
              ),
              items: _divisions
                  .map((d) =>
                  DropdownMenuItem(value: d, child: Text(d)))
                  .toList(),
              onChanged: (val) =>
                  setState(() => _selectedDivision = val!),
            ),
            const SizedBox(height: 20),
            // REPLACE the existing location Container with this:
            _label('Doctor\'s Location'),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _latitude != null
                    ? Colors.green.shade50
                    : Colors.orange.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _latitude != null
                      ? Colors.green.shade200
                      : Colors.orange.shade200,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        _latitude != null ? Icons.location_on : Icons.location_off,
                        color: _latitude != null ? Colors.green : Colors.orange,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _latitude != null
                              ? 'Location set ✅\nLat: ${_latitude!.toStringAsFixed(6)}\nLng: ${_longitude!.toStringAsFixed(6)}'
                              : 'No location set yet.\nCapture your current location or enter coordinates manually.',
                          style: TextStyle(
                            fontSize: 13,
                            color: _latitude != null
                                ? Colors.green.shade700
                                : Colors.orange.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // ── Button 1: Capture GPS ──────────────────────────
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isFetchingLocation ? null : _getCurrentLocation,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _latitude != null
                            ? Colors.green
                            : const Color(0xFF1565C0),
                      ),
                      icon: _isFetchingLocation
                          ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      )
                          : const Icon(Icons.my_location),
                      label: Text(_isFetchingLocation
                          ? 'Getting location...'
                          : _latitude != null
                          ? 'Update via GPS'
                          : 'Capture Current Location'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // ── Button 2: Enter manually ───────────────────────
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _isFetchingLocation ? null : _showManualCoordinatesDialog,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF1565C0),
                        side: const BorderSide(color: Color(0xFF1565C0)),
                      ),
                      icon: const Icon(Icons.edit_location_alt, size: 18),
                      label: const Text('Enter Coordinates Manually'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            if (_latitude != null)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _openInMaps(_latitude!, _longitude!),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.green.shade700,
                    side: BorderSide(color: Colors.green.shade400),
                  ),
                  icon: const Icon(Icons.map, size: 18),
                  label: const Text('View on Google Maps'),
                ),
              ),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue, size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'GPS: Go to clinic and tap "Capture Current Location".\nManual: Open Google Maps → long press the location → copy the coordinates shown.',
                      style: TextStyle(fontSize: 11, color: Colors.blue),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline,
                      color: Colors.blue, size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Tip: Go to the doctor\'s clinic physically and then tap "Capture Current Location" for accurate location.',
                      style:
                      TextStyle(fontSize: 11, color: Colors.blue),
                    ),
                  ),
                ],
              ),
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
                child: Row(
                  children: [
                    const Icon(Icons.error_outline,
                        color: Colors.red, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(_errorMessage,
                          style: const TextStyle(
                              color: Colors.red, fontSize: 13)),
                    ),
                  ],
                ),
              ),
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton.icon(
              onPressed: _saveDoctor,
              icon: Icon(
                  _isEditing ? Icons.save : Icons.person_add),
              label: Text(
                _isEditing ? 'Update Doctor' : 'Save Doctor',
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(text,
          style: const TextStyle(fontWeight: FontWeight.w600)),
    );
  }
}

// ─────────────────────────────────────────
// MR MANAGEMENT SCREEN
// ─────────────────────────────────────────
class AdminMrManagementScreen extends StatelessWidget {
  const AdminMrManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MR Management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add),
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const AddMrScreen())),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _db
            .collection('users')
            .where('role', isEqualTo: 'mr')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.badge_outlined,
                      size: 80, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  Text('No MRs added yet',
                      style: TextStyle(
                          color: Colors.grey.shade500, fontSize: 16)),
                ],
              ),
            );
          }
          final mrs = snapshot.data!.docs;
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: mrs.length,
            itemBuilder: (context, index) {
              final mr = mrs[index].data() as Map<String, dynamic>;
              final docId = mrs[index].id;
              final isActive = mr['isActive'] ?? true;
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: ExpansionTile(
                  leading: CircleAvatar(
                    backgroundColor: isActive
                        ? Colors.blue.shade50
                        : Colors.grey.shade100,
                    child: Icon(Icons.person,
                        color: isActive ? Colors.blue : Colors.grey),
                  ),
                  title: Row(children: [
                    Expanded(
                      child: Text(mr['name'] ?? 'Unknown',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isActive
                            ? Colors.green.withOpacity(0.1)
                            : Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        isActive ? 'Active' : 'Inactive',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isActive ? Colors.green : Colors.red,
                        ),
                      ),
                    ),
                  ]),
                  subtitle: Text(
                      '${mr['email']}\n📍 ${mr['area'] ?? 'N/A'}'),
                  trailing: PopupMenuButton(
                    itemBuilder: (_) => [
                      PopupMenuItem(
                          value: 'edit',
                          child: Row(children: [
                            const Icon(Icons.edit, size: 18, color: Colors.blue),
                            const SizedBox(width: 8),
                            const Text('Edit'),
                          ])),
                      PopupMenuItem(
                          value: 'toggle',
                          child: Row(children: [
                            Icon(
                              isActive ? Icons.block : Icons.check_circle,
                              color: isActive ? Colors.red : Colors.green,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(isActive ? 'Deactivate' : 'Activate',
                                style: TextStyle(
                                    color: isActive ? Colors.red : Colors.green)),
                          ])),
                    ],
                    onSelected: (value) async {
                      if (value == 'edit') {
                        Navigator.push(context,
                            MaterialPageRoute(
                              builder: (_) => EditMrScreen(mrId: docId, mrData: mr),
                            ));
                      } else if (value == 'toggle') {
                        await _db
                            .collection('users')
                            .doc(docId)
                            .update({'isActive': !isActive});
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text(isActive
                                ? '${mr['name']} deactivated'
                                : '${mr['name']} activated'),
                            backgroundColor: isActive ? Colors.red : Colors.green,
                          ));
                        }
                      }
                    },
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Divider(height: 20),
                          // Quick stats row
                          StreamBuilder<QuerySnapshot>(
                            stream: _db
                                .collection('allowances')
                                .where('mrId', isEqualTo: docId)
                                .snapshots(),
                            builder: (context, allowanceSnap) {
                              final allDocs = allowanceSnap.data?.docs ?? [];
                              double total = 0;
                              for (final d in allDocs) {
                                total += (d.data() as Map)['amount'] as num? ?? 0;
                              }
                              return Row(children: [
                                _mrStatChip('Orders', '${allDocs.length}', Colors.blue),
                                const SizedBox(width: 8),
                                _mrStatChip('Total Bonus', '₹${total.toStringAsFixed(0)}',
                                    Colors.green),
                              ]);
                            },
                          ),
                          const SizedBox(height: 12),
                          // View full details button
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => AdminMrDetailScreen(
                                    mrId: docId,
                                    mrData: mr,
                                  ),
                                ),
                              ),
                              icon: const Icon(Icons.open_in_new, size: 16),
                              label: const Text('View Full Details & History'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}


class EditMrScreen extends StatefulWidget {
  final String mrId;
  final Map<String, dynamic> mrData;
  const EditMrScreen({super.key, required this.mrId, required this.mrData});

  @override
  State<EditMrScreen> createState() => _EditMrScreenState();
}

class _EditMrScreenState extends State<EditMrScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _areaController;
  String _selectedDivision = 'Ortho';
  bool _isLoading = false;
  String _errorMessage = '';
  final List<String> _divisions = ['Ortho', 'Gynec', 'General', 'Both'];

  @override
  void initState() {
    super.initState();
    _nameController  = TextEditingController(text: widget.mrData['name']  ?? '');
    _phoneController = TextEditingController(text: widget.mrData['phone'] ?? '');
    _areaController  = TextEditingController(text: widget.mrData['area']  ?? '');
    _selectedDivision = widget.mrData['division'] ?? 'Ortho';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _areaController.dispose();
    super.dispose();
  }

  Future<void> _saveMr() async {
    final name  = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    final area  = _areaController.text.trim();

    if (name.isEmpty || phone.isEmpty || area.isEmpty) {
      setState(() => _errorMessage = 'Please fill all fields.');
      return;
    }

    setState(() { _isLoading = true; _errorMessage = ''; });

    try {
      await _db.collection('users').doc(widget.mrId).update({
        'name':      name,
        'phone':     phone,
        'area':      area,
        'division':  _selectedDivision,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('✅ MR updated successfully!'),
            backgroundColor: Colors.green));
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() { _isLoading = false; _errorMessage = 'Failed to update. Try again.'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit MR')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Email (read-only)
            const Text('Email', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            TextField(
              readOnly: true,
              controller: TextEditingController(text: widget.mrData['email'] ?? ''),
              style: const TextStyle(color: Colors.grey),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.email_outlined),
                filled: true,
                fillColor: Colors.grey.shade100,
              ),
            ),
            const SizedBox(height: 14),
            _field('Full Name', _nameController, Icons.person_outline, 'Enter MR full name'),
            _field('Phone', _phoneController, Icons.phone_outlined, 'Enter phone', type: TextInputType.phone),
            _field('Area', _areaController, Icons.location_on_outlined, 'e.g. Nellore North'),
            const Text('Division', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              value: _selectedDivision,
              decoration: const InputDecoration(prefixIcon: Icon(Icons.category_outlined)),
              items: _divisions.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
              onChanged: (val) => setState(() => _selectedDivision = val!),
            ),
            const SizedBox(height: 20),
            if (_errorMessage.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(10),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200)),
                child: Text(_errorMessage,
                    style: const TextStyle(color: Colors.red, fontSize: 13)),
              ),
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton.icon(
              onPressed: _saveMr,
              icon: const Icon(Icons.save),
              label: const Text('Save Changes',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _field(String label, TextEditingController controller,
      IconData icon, String hint, {TextInputType type = TextInputType.text}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: type,
          decoration: InputDecoration(hintText: hint, prefixIcon: Icon(icon)),
        ),
        const SizedBox(height: 14),
      ],
    );
  }
}


// ─────────────────────────────────────────
// ADMIN MR DETAIL SCREEN  (full page)
// ─────────────────────────────────────────
class AdminMrDetailScreen extends StatelessWidget {
  final String mrId;
  final Map<String, dynamic> mrData;
  const AdminMrDetailScreen(
      {super.key, required this.mrId, required this.mrData});

  Color _tierColor(String tier) {
    switch (tier) {
      case 'Premium':    return Colors.purple;
      case 'Super Core': return Colors.orange;
      case 'Core':       return Colors.teal;
      default:           return Colors.grey;
    }
  }

  IconData _tierIcon(String tier) {
    switch (tier) {
      case 'Premium':    return Icons.workspace_premium;
      case 'Super Core': return Icons.star;
      case 'Core':       return Icons.verified;
      default:           return Icons.attach_money;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isActive = mrData['isActive'] ?? true;

    return Scaffold(
      appBar: AppBar(
        title: Text(mrData['name'] ?? 'MR Details'),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isActive ? Colors.green.shade100 : Colors.red.shade100,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              isActive ? 'Active' : 'Inactive',
              style: TextStyle(
                  color: isActive ? Colors.green.shade800 : Colors.red.shade800,
                  fontWeight: FontWeight.bold,
                  fontSize: 12),
            ),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _db
            .collection('allowances')
            .where('mrId', isEqualTo: mrId)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data?.docs ?? [];
          double totalBonus = 0;
          int coreCount = 0, superCoreCount = 0, premiumCount = 0;
          for (final doc in docs) {
            final d = doc.data() as Map<String, dynamic>;
            totalBonus += (d['amount'] as num?)?.toDouble() ?? 0;
            final t = d['tier'] ?? '';
            if (t == 'Core')       coreCount++;
            if (t == 'Super Core') superCoreCount++;
            if (t == 'Premium')    premiumCount++;
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

              // ── MR info card ─────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [Color(0xFF1565C0), Color(0xFF1E88E5)]),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    const CircleAvatar(
                      radius: 28,
                      backgroundColor: Colors.white24,
                      child: Icon(Icons.person, color: Colors.white, size: 32),
                    ),
                    const SizedBox(width: 14),
                    Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(mrData['name'] ?? '',
                              style: const TextStyle(color: Colors.white,
                                  fontSize: 18, fontWeight: FontWeight.bold)),
                          Text(mrData['email'] ?? '',
                              style: const TextStyle(color: Colors.white70, fontSize: 13)),
                        ])),
                  ]),
                  const SizedBox(height: 14),
                  Wrap(spacing: 16, runSpacing: 8, children: [
                    _infoChip(Icons.phone, mrData['phone'] ?? 'N/A'),
                    _infoChip(Icons.location_on, mrData['area'] ?? 'N/A'),
                    _infoChip(Icons.category, mrData['division'] ?? 'N/A'),
                  ]),
                ]),
              ),
              const SizedBox(height: 16),

              // ── Commission summary row ────────────────────
              Row(children: [
                _summaryBox('Total Bonus', '₹${totalBonus.toStringAsFixed(0)}',
                    Colors.green, Icons.account_balance_wallet),
                const SizedBox(width: 10),
                _summaryBox('Records', '${docs.length}',
                    Colors.blue, Icons.receipt_long),
                const SizedBox(width: 10),
                _summaryBox('Fixed/mo',
                    '₹${(mrData['fixedAllowance'] as num?)?.toInt() ?? 0}',
                    Colors.purple, Icons.payments),
              ]),
              const SizedBox(height: 16),

              // ── Tier breakdown ────────────────────────────
              if (docs.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Tier Breakdown',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 10),
                    Row(children: [
                      _tierChip('Core',       coreCount,       Colors.teal),
                      const SizedBox(width: 8),
                      _tierChip('Super Core', superCoreCount,  Colors.orange),
                      const SizedBox(width: 8),
                      _tierChip('Premium',    premiumCount,    Colors.purple),
                    ]),
                  ]),
                ),
                const SizedBox(height: 20),
              ],
// ── Assigned Stockists ────────────────────────
              StreamBuilder<DocumentSnapshot>(
                stream: _db.collection('users').doc(mrId).snapshots(),
                builder: (context, snap) {
                  final assignedStockists =
                      (snap.data?.data() as Map<String, dynamic>?)?['assignedStockists']
                      as List? ?? [];
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Assigned Stockists',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          TextButton.icon(
                            onPressed: () => _showAssignStockistDialog(
                                context, mrId, assignedStockists),
                            icon: const Icon(Icons.edit, size: 16),
                            label: const Text('Assign'),
                          ),
                        ],
                      ),
                      if (assignedStockists.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.orange.shade200),
                          ),
                          child: const Row(children: [
                            Icon(Icons.warning_amber, color: Colors.orange, size: 16),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text('No stockists assigned yet',
                                  style: TextStyle(color: Colors.orange, fontSize: 13)),
                            ),
                          ]),
                        )
                      else
                        FutureBuilder<QuerySnapshot>(
                          future: _db
                              .collection('users')
                              .where(FieldPath.documentId,
                              whereIn: assignedStockists.cast<String>())
                              .get(),
                          builder: (context, snap) {
                            if (!snap.hasData) return const LinearProgressIndicator();
                            return Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: snap.data!.docs.map((doc) {
                                final data = doc.data() as Map<String, dynamic>;
                                return Chip(
                                  avatar: const Icon(Icons.store,
                                      size: 16, color: Colors.brown),
                                  label: Text(data['name'] ?? '',
                                      style: const TextStyle(fontSize: 12)),
                                  backgroundColor: Colors.brown.withOpacity(0.08),
                                  side: BorderSide(color: Colors.brown.withOpacity(0.3)),
                                );
                              }).toList(),
                            );
                          },
                        ),
                      const SizedBox(height: 16),
                    ],
                  );
                },
              ),
              // ── History header ────────────────────────────
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('Commission History',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                if (docs.isNotEmpty)
                  Text('${docs.length} record(s)',
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
              ]),
              const SizedBox(height: 12),

              // ── History list ──────────────────────────────
              if (docs.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Column(children: [
                      Icon(Icons.account_balance_wallet_outlined,
                          size: 60, color: Colors.grey.shade300),
                      const SizedBox(height: 12),
                      Text('No commission records yet',
                          style: TextStyle(color: Colors.grey.shade500)),
                    ]),
                  ),
                )
              else
                ...docs.map((doc) {
                  final d        = doc.data() as Map<String, dynamic>;
                  final tier     = (d['tier'] as String?) ?? 'Normal';
                  final tColor   = _tierColor(tier);
                  final amount   = (d['amount'] as num?)?.toInt() ?? 0;
                  final orderVal = (d['orderValue'] as num?)?.toInt() ?? 0;
                  final docName  = d['doctorName'] as String? ?? 'N/A';
                  final date     = d['orderDate'] as String? ?? '';

                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    elevation: 1.5,
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(children: [
                        // Tier icon
                        Container(
                          width: 42, height: 42,
                          decoration: BoxDecoration(
                            color: tColor.withOpacity(0.12),
                            shape: BoxShape.circle,
                            border: Border.all(color: tColor.withOpacity(0.35)),
                          ),
                          child: Icon(_tierIcon(tier), color: tColor, size: 20),
                        ),
                        const SizedBox(width: 12),

                        // Info
                        Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Date
                                Text(date,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13)),
                                const SizedBox(height: 2),
                                // Doctor
                                Text(docName,
                                    style: TextStyle(
                                        color: Colors.grey.shade700,
                                        fontSize: 12)),
                                const SizedBox(height: 4),
                                // Deal value + tier badge
                                Row(children: [
                                  Text('Deal: ₹$orderVal',
                                      style: TextStyle(
                                          color: Colors.grey.shade600,
                                          fontSize: 11)),
                                  const SizedBox(width: 8),
                                  if (tier != 'Normal')
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: tColor.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                            color: tColor.withOpacity(0.4)),
                                      ),
                                      child: Text(tier,
                                          style: TextStyle(
                                              color: tColor,
                                              fontSize: 9,
                                              fontWeight: FontWeight.bold)),
                                    ),
                                ]),
                              ]),
                        ),

                        // Bonus
                        Column(crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('+₹$amount',
                                  style: TextStyle(
                                      color: tColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16)),
                              Text('bonus',
                                  style: TextStyle(
                                      color: Colors.grey.shade500,
                                      fontSize: 10)),
                            ]),
                      ]),
                    ),
                  );
                }),
              const SizedBox(height: 20),
            ]),
          );
        },
      ),
    );
  }

  void _showAssignStockistDialog(BuildContext context, String mrId, List<dynamic> currentStockists) async {
    final stockistsSnap = await _db.collection('users')
        .where('role', isEqualTo: 'stockist')
        .where('isActive', isEqualTo: true)
        .get();

    List<String> selectedIds = List<String>.from(currentStockists);

    if (!context.mounted) return;
    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const Text('Assign Stockists to MR'),
          content: SizedBox(
            width: double.maxFinite,
            child: stockistsSnap.docs.isEmpty
                ? const Text('No stockists found.')
                : ListView(
              shrinkWrap: true,
              children: stockistsSnap.docs.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final isSelected = selectedIds.contains(doc.id);
                return CheckboxListTile(
                  value: isSelected,
                  title: Text(data['name'] ?? ''),
                  subtitle: Text(data['city'] ?? ''),
                  onChanged: (val) => setD(() {
                    if (val == true) {
                      selectedIds.add(doc.id);
                    } else {
                      selectedIds.remove(doc.id);
                    }
                  }),
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                await _db.collection('users').doc(mrId)
                    .update({'assignedStockists': selectedIds});
                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Stockists assigned successfully!'),
                    backgroundColor: Colors.green,
                  ));
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoChip(IconData icon, String text) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 13, color: Colors.white70),
      const SizedBox(width: 4),
      Text(text, style: const TextStyle(color: Colors.white70, fontSize: 12)),
    ],
  );

  Widget _summaryBox(String label, String value, Color color, IconData icon) =>
      Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withOpacity(0.25)),
          ),
          child: Column(children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 4),
            Text(value,
                style: TextStyle(
                    color: color, fontSize: 15, fontWeight: FontWeight.bold)),
            Text(label,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 10)),
          ]),
        ),
      );

  Widget _tierChip(String label, int count, Color color) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(children: [
        Text('$count',
            style: TextStyle(
                color: color, fontWeight: FontWeight.bold, fontSize: 18)),
        Text(label,
            style:
            TextStyle(color: Colors.grey.shade600, fontSize: 9)),
      ]),
    ),
  );
}

// helper used inside AdminMrManagementScreen's ExpansionTile
Widget _mrStatChip(String label, String value, Color color) => Container(
  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
  decoration: BoxDecoration(
    color: color.withOpacity(0.08),
    borderRadius: BorderRadius.circular(20),
    border: Border.all(color: color.withOpacity(0.3)),
  ),
  child: Row(mainAxisSize: MainAxisSize.min, children: [
    Text(label,
        style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
    const SizedBox(width: 6),
    Text(value,
        style: TextStyle(
            color: color, fontWeight: FontWeight.bold, fontSize: 13)),
  ]),
);

// ─────────────────────────────────────────
// MR ALLOWANCE HISTORY SCREEN  (kept for backward compat)
// ─────────────────────────────────────────
class MrAllowanceHistoryScreen extends StatelessWidget {
  final String mrId;
  final String mrName;
  const MrAllowanceHistoryScreen(
      {super.key, required this.mrId, required this.mrName});

  @override
  Widget build(BuildContext context) {
    // Redirect to the new full detail screen with a dummy mrData shell
    return FutureBuilder<DocumentSnapshot>(
      future: _db.collection('users').doc(mrId).get(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        final data = snap.data?.data() as Map<String, dynamic>? ?? {'name': mrName};
        return AdminMrDetailScreen(mrId: mrId, mrData: data);
      },
    );
  }
}

// ─────────────────────────────────────────
// ADD MR SCREEN
// ─────────────────────────────────────────
class AddMrScreen extends StatefulWidget {
  const AddMrScreen({super.key});

  @override
  State<AddMrScreen> createState() => _AddMrScreenState();
}

class _AddMrScreenState extends State<AddMrScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _areaController = TextEditingController();
  final _passwordController = TextEditingController();
  String _selectedDivision = 'Ortho';
  bool _isLoading = false;
  bool _obscurePassword = true;
  String _errorMessage = '';
  final List<String> _divisions = ['Ortho', 'Gynec', 'General', 'Both'];

  Future<void> _createMr() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();
    final area = _areaController.text.trim();
    final password = _passwordController.text.trim();

    if (name.isEmpty ||
        email.isEmpty ||
        phone.isEmpty ||
        area.isEmpty ||
        password.isEmpty) {
      setState(() => _errorMessage = 'Please fill in all fields.');
      return;
    }
    if (password.length < 6) {
      setState(() =>
      _errorMessage = 'Password must be at least 6 characters.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final currentAdmin = _auth.currentUser!;

      FirebaseApp secondaryApp;
      try {
        secondaryApp = Firebase.app('secondary');
      } catch (_) {
        secondaryApp = await Firebase.initializeApp(
          name: 'secondary',
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }

      final secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);

      final userCredential = await secondaryAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final newUid = userCredential.user!.uid;
      final uid = userCredential.user!.uid;

      await _db.collection('users').doc(newUid).set({
        'name': name,
        'email': email,
        'phone': phone,
        'area': area,
        'division': _selectedDivision,
        'role': 'mr',
        'isActive': true,
        'fixedAllowance': 0,
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': currentAdmin.uid,
      });

      final productsSnapshot =
      await _db.collection('products').get();

      Map<String, int> stockData = {};
      for (var doc in productsSnapshot.docs) {
        stockData[doc.id] = 0;
      }
      await _db.collection('stockist_stock').doc(uid).set(stockData);

      await secondaryAuth.signOut();
      await secondaryApp.delete();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ MR created successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.code == 'email-already-in-use'
            ? 'This email is already registered.'
            : 'Failed: ${e.message}';
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Something went wrong. Please try again.';
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _areaController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add New MR')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _field('Full Name', _nameController, Icons.person_outline,
                'Enter MR full name'),
            _field('Email', _emailController, Icons.email_outlined,
                'Enter email',
                type: TextInputType.emailAddress),
            _field('Phone', _phoneController, Icons.phone_outlined,
                'Enter phone',
                type: TextInputType.phone),
            _field('Area', _areaController, Icons.location_on_outlined,
                'e.g. Nellore North'),
            const SizedBox(height: 4),
            const Text('Division',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              value: _selectedDivision,
              decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.category_outlined)),
              items: _divisions
                  .map((d) =>
                  DropdownMenuItem(value: d, child: Text(d)))
                  .toList(),
              onChanged: (val) =>
                  setState(() => _selectedDivision = val!),
            ),
            const SizedBox(height: 14),
            const Text('Password',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            TextField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              decoration: InputDecoration(
                hintText: 'Set login password',
                prefixIcon: const Icon(Icons.lock_outlined),
                suffixIcon: IconButton(
                  icon: Icon(_obscurePassword
                      ? Icons.visibility_off
                      : Icons.visibility),
                  onPressed: () => setState(
                          () => _obscurePassword = !_obscurePassword),
                ),
              ),
            ),
            const SizedBox(height: 20),
            if (_errorMessage.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(10),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200)),
                child: Text(_errorMessage,
                    style: const TextStyle(
                        color: Colors.red, fontSize: 13)),
              ),
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton.icon(
              onPressed: _createMr,
              icon: const Icon(Icons.person_add),
              label: const Text('Create MR Account',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _field(String label, TextEditingController controller,
      IconData icon, String hint,
      {TextInputType type = TextInputType.text}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: type,
          decoration:
          InputDecoration(hintText: hint, prefixIcon: Icon(icon)),
        ),
        const SizedBox(height: 14),
      ],
    );
  }
}

// ─────────────────────────────────────────
// ADMIN ORDERS SCREEN
// ─────────────────────────────────────────
class AdminOrdersScreen extends StatefulWidget {
  const AdminOrdersScreen({super.key});

  @override
  State<AdminOrdersScreen> createState() => _AdminOrdersScreenState();
}

class _AdminOrdersScreenState extends State<AdminOrdersScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
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
          _OrderTab(statusFilter: 'pending',    statusColor: _statusColor),
          _OrderTab(statusFilter: 'approved',   statusColor: _statusColor),
          _OrderTab(statusFilter: 'rejected',   statusColor: _statusColor),
          _OrderTab(statusFilter: 'dispatched', statusColor: _statusColor),
          _OrderTab(statusFilter: null,         statusColor: _statusColor),
        ],
      ),
    );
  }
}

class _OrderTab extends StatelessWidget {
  final String? statusFilter;
  final Color Function(String) statusColor;
  const _OrderTab({required this.statusFilter, required this.statusColor});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _db.collection('orders').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text('Error: ${snapshot.error}',
                  style: const TextStyle(color: Colors.red)),
            ),
          );
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
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inbox_outlined, size: 80, color: Colors.grey.shade300),
                const SizedBox(height: 16),
                Text(
                  statusFilter != null
                      ? 'No ${statusFilter!} orders'
                      : 'No orders yet',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 16),
                ),
              ],
            ),
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'MR: ${data['mrName'] ?? 'N/A'}  •  $items item(s)  •  ${data['date'] ?? ''}',
                    ),
                    if (data['stockistName'] != null && data['stockistName'].toString().isNotEmpty)
                      Text('Stockist: ${data['stockistName']}',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                    if (data['orderValue'] != null)
                      Text('Value: ₹${data['orderValue']}',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                  ],
                ),
                isThreeLine: true,
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
                  builder: (_) => _AdminOrderDetailDialog(
                      orderId: doc.id, data: data,
                      statusColor: statusColor),
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
// ADMIN ORDER DETAIL DIALOG — FIXED
// Converted to StatefulWidget to prevent double-tap / multiple submissions
// ─────────────────────────────────────────
class _AdminOrderDetailDialog extends StatefulWidget {
  final String orderId;
  final Map<String, dynamic> data;
  final Color Function(String) statusColor;
  const _AdminOrderDetailDialog(
      {required this.orderId, required this.data, required this.statusColor});

  @override
  State<_AdminOrderDetailDialog> createState() =>
      _AdminOrderDetailDialogState();
}

class _AdminOrderDetailDialogState extends State<_AdminOrderDetailDialog> {
  bool _isProcessing = false;

  String get orderId => widget.orderId;
  Map<String, dynamic> get data => widget.data;
  Color Function(String) get statusColor => widget.statusColor;

  /// Runs an async action with processing guard — prevents double-tap.
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
          Icon(Icons.receipt_long, color: color, size: 40),
          const SizedBox(height: 8),
          Text(status.toUpperCase(),
              style: TextStyle(color: color, fontSize: 18,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('Doctor: ${data['doctorName'] ?? 'N/A'}',
              style: const TextStyle(fontWeight: FontWeight.w600)),
          Text('MR: ${data['mrName'] ?? 'N/A'}',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
          if (data['stockistName'] != null && data['stockistName'].toString().isNotEmpty)
            Text('Stockist: ${data['stockistName']}',
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
              child: Text('Doctor Tier: ${data['tier']} • Commission: ₹${data['commission'] ?? 0}',
                  style: TextStyle(color: Colors.purple.shade700, fontSize: 11)),
            ),
          if (status == 'rejected' && data['rejectionReason'] != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(children: [
                const Icon(Icons.block, color: Colors.red, size: 16),
                const SizedBox(width: 6),
                Expanded(child: Text(
                  'Rejected: ${data['rejectionReason']}',
                  style: TextStyle(color: Colors.red.shade700, fontSize: 12),
                )),
              ]),
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
          if (data['remarks'] != null && data['remarks'].toString().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text('Remarks: ${data['remarks']}',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
            ),
          Wrap(spacing: 8, runSpacing: 8, children: [
            if (status == 'pending') ...[
              _actionBtn('Approve', Colors.blue, () => _runAction(() async {
                final stockistUid = data['stockistId']?.toString() ?? '';
                try {
                  // ── PRE-CHECK: verify sufficient stock ──────────────
                  if (stockistUid.isNotEmpty) {
                    final stockDoc = await _db
                        .collection('stockist_stock')
                        .doc(stockistUid)
                        .get();
                    final stockData = stockDoc.exists
                        ? (stockDoc.data() as Map<String, dynamic>)
                        : <String, dynamic>{};

                    final List<String> insufficientItems = [];
                    for (final item in items) {
                      final pid = item['productId']?.toString() ?? '';
                      if (pid.isEmpty) continue;
                      final available = (stockData[pid] as num?)?.toInt() ?? 0;
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
                              Text('Insufficient Stock'),
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
                      return; // ← stop, don't approve
                    }
                  }

                  // ── Stock is sufficient (or no stockist assigned), proceed ──
                  await _db.runTransaction((txn) async {
                    if (stockistUid.isNotEmpty) {
                      final stockRef = _db.collection('stockist_stock').doc(stockistUid);
                      final stockDoc = await txn.get(stockRef);
                      final stockData = stockDoc.exists
                          ? (stockDoc.data() as Map<String, dynamic>)
                          : <String, dynamic>{};

                      final updated = Map<String, dynamic>.from(stockData);
                      for (final item in items) {
                        final pid = item['productId']?.toString() ?? '';
                        if (pid.isEmpty) continue;
                        final current = (updated[pid] as num?)?.toInt() ?? 0;
                        final ordered = (item['quantity'] as num?)?.toInt() ?? 0;
                        updated[pid] = (current - ordered).clamp(0, 999999);
                      }
                      if (stockDoc.exists) {
                        txn.update(stockRef, updated);
                      } else {
                        txn.set(stockRef, updated);
                      }
                    }

                    txn.update(_db.collection('orders').doc(orderId), {
                      'status': 'approved',
                      'approvedAt': FieldValue.serverTimestamp(),
                    });
                  });

                  final mrId = data['mrId']?.toString() ?? '';
                  if (mrId.isNotEmpty) {
                    await _db.collection('notifications').add({
                      'mrId':      mrId,
                      'title':     'Order Approved ✅',
                      'body':      'Your order for ${data['doctorName'] ?? 'doctor'} has been approved.',
                      'type':      'order_approved',
                      'orderId':   orderId,
                      'isRead':    false,
                      'createdAt': FieldValue.serverTimestamp(),
                    });
                  }
                  if (context.mounted) Navigator.pop(context);
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
                  }
                }
              })),
              _actionBtn('Cancel', Colors.red, () => _runAction(() async {
                await _db.collection('orders').doc(orderId)
                    .update({'status': 'cancelled'});
                final mrId = data['mrId']?.toString() ?? '';
                if (mrId.isNotEmpty) {
                  await _db.collection('notifications').add({
                    'mrId':      mrId,
                    'title':     'Order Cancelled ❌',
                    'body':      'Your order for ${data['doctorName'] ?? 'doctor'} was cancelled.',
                    'type':      'order_cancelled',
                    'orderId':   orderId,
                    'isRead':    false,
                    'createdAt': FieldValue.serverTimestamp(),
                  });
                }
                if (context.mounted) Navigator.pop(context);
              })),
            ],
            if (status == 'approved')
              _actionBtn('Mark Dispatched', Colors.teal, () => _runAction(() async {
                try {
                  await _db.runTransaction((txn) async {
                    final productRefs = <String, DocumentReference>{};
                    final productSnaps = <String, DocumentSnapshot>{};
                    for (final item in items) {
                      final pid = item['productId']?.toString() ?? '';
                      if (pid.isNotEmpty && !productRefs.containsKey(pid)) {
                        final ref = _db.collection('products').doc(pid);
                        productRefs[pid] = ref;
                        productSnaps[pid] = await txn.get(ref);
                      }
                    }
                    txn.update(_db.collection('orders').doc(orderId),
                        {'status': 'dispatched', 'dispatchedAt': FieldValue.serverTimestamp()});
                    for (final item in items) {
                      final pid = item['productId']?.toString() ?? '';
                      if (pid.isEmpty) continue;
                      final snap = productSnaps[pid];
                      if (snap == null || !snap.exists) continue;
                      final currentStock =
                          ((snap.data() as Map<String, dynamic>)['stock'] as num?)?.toInt() ?? 0;
                      final ordered = (item['quantity'] as num?)?.toInt() ?? 0;
                      final newStock = (currentStock - ordered).clamp(0, 999999);
                      txn.update(productRefs[pid]!, {'stock': newStock});
                    }
                  });
                  final mrId = data['mrId']?.toString() ?? '';
                  if (mrId.isNotEmpty) {
                    await _db.collection('notifications').add({
                      'mrId':      mrId,
                      'title':     'Order Dispatched 🚚',
                      'body':      'Your order for ${data['doctorName'] ?? 'doctor'} has been dispatched.',
                      'type':      'order_dispatched',
                      'orderId':   orderId,
                      'isRead':    false,
                      'createdAt': FieldValue.serverTimestamp(),
                    });
                  }
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('✅ Order dispatched & stock updated!'),
                        backgroundColor: Colors.teal));
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text('Error: $e'), backgroundColor: Colors.red));
                  }
                }
              })),
            if (status == 'dispatched')
              _actionBtn('Mark Delivered', Colors.green, () => _runAction(() async {
                await _db.collection('orders').doc(orderId)
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
// ADMIN MR REPORTS SCREEN
// ─────────────────────────────────────────
class AdminMrReportsScreen extends StatefulWidget {
  const AdminMrReportsScreen({super.key});

  @override
  State<AdminMrReportsScreen> createState() => _AdminMrReportsScreenState();
}

class _AdminMrReportsScreenState extends State<AdminMrReportsScreen> {
  String _searchQuery = '';
  String _filterMr = 'All';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MR Daily Reports'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() {}),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
              decoration: InputDecoration(
                hintText: 'Search by MR name or doctor...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () => setState(() => _searchQuery = ''),
                )
                    : null,
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _db
                  .collection('daily_reports')
                  .orderBy('date', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text('Error: ${snapshot.error}',
                          style: const TextStyle(color: Colors.red)),
                    ),
                  );
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.assignment_outlined, size: 80, color: Colors.grey),
                        SizedBox(height: 16),
                        Text('No reports submitted yet',
                            style: TextStyle(color: Colors.grey, fontSize: 16)),
                      ],
                    ),
                  );
                }

                final allReports = snapshot.data!.docs;
                final mrNames = <String>{'All'};
                for (final doc in allReports) {
                  final data = doc.data() as Map<String, dynamic>;
                  final mrName = data['mrName']?.toString() ?? 'Unknown';
                  mrNames.add(mrName);
                }

                var reports = allReports.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final mrName = (data['mrName'] ?? '').toString().toLowerCase();
                  final doctorsVisited = (data['doctorsVisited'] as List?)?.join(' ').toLowerCase() ?? '';
                  final notes = (data['notes'] ?? '').toString().toLowerCase();

                  final matchesSearch = _searchQuery.isEmpty ||
                      mrName.contains(_searchQuery) ||
                      doctorsVisited.contains(_searchQuery) ||
                      notes.contains(_searchQuery);

                  final matchesMr = _filterMr == 'All' ||
                      (data['mrName']?.toString() ?? '') == _filterMr;

                  return matchesSearch && matchesMr;
                }).toList();

                return Column(
                  children: [
                    if (mrNames.length > 1)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: Row(
                          children: [
                            const Text('Filter by MR: ', style: TextStyle(fontWeight: FontWeight.w500)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: _filterMr,
                                decoration: const InputDecoration(
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  border: OutlineInputBorder(),
                                ),
                                items: mrNames.map((name) {
                                  return DropdownMenuItem(value: name, child: Text(name));
                                }).toList(),
                                onChanged: (val) => setState(() => _filterMr = val!),
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (reports.isEmpty)
                      Expanded(
                        child: Center(
                          child: Text('No reports match your filter',
                              style: TextStyle(color: Colors.grey.shade500)),
                        ),
                      )
                    else
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: reports.length,
                          itemBuilder: (context, index) {
                            final doc = reports[index];
                            final data = doc.data() as Map<String, dynamic>;
                            final doctorsVisited = (data['doctorsVisited'] as List?) ?? [];

                            return Card(
                              margin: const EdgeInsets.only(bottom: 10),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              child: ExpansionTile(
                                leading: CircleAvatar(
                                  backgroundColor: const Color(0xFF1565C0).withOpacity(0.1),
                                  child: const Icon(Icons.assignment, color: Color(0xFF1565C0)),
                                ),
                                title: Text(
                                  data['mrName'] ?? 'Unknown MR',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Date: ${data['date'] ?? 'N/A'}'),
                                    Text('Doctors visited: ${doctorsVisited.length}',
                                        style: const TextStyle(fontSize: 12)),
                                  ],
                                ),
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Divider(),
                                        const SizedBox(height: 8),
                                        const Text('Doctors Visited:',
                                            style: TextStyle(fontWeight: FontWeight.bold)),
                                        const SizedBox(height: 4),
                                        ...doctorsVisited.map((d) => Padding(
                                          padding: const EdgeInsets.only(left: 8, bottom: 4),
                                          child: Row(
                                            children: [
                                              const Icon(Icons.person, size: 16, color: Colors.blue),
                                              const SizedBox(width: 8),
                                              Expanded(child: Text(d.toString())),
                                            ],
                                          ),
                                        )),
                                        if (doctorsVisited.isEmpty)
                                          const Padding(
                                            padding: EdgeInsets.only(left: 8),
                                            child: Text('No doctors visited', style: TextStyle(color: Colors.grey)),
                                          ),
                                        const SizedBox(height: 12),
                                        if ((data['notes'] ?? '').toString().isNotEmpty) ...[
                                          const Text('Work Summary:',
                                              style: TextStyle(fontWeight: FontWeight.bold)),
                                          const SizedBox(height: 4),
                                          Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: Colors.grey.shade50,
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Text(data['notes'] ?? ''),
                                          ),
                                          const SizedBox(height: 12),
                                        ],
                                        if ((data['followUp'] ?? '').toString().isNotEmpty) ...[
                                          const Text('Follow-up Notes:',
                                              style: TextStyle(fontWeight: FontWeight.bold)),
                                          const SizedBox(height: 4),
                                          Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: Colors.orange.shade50,
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Text(data['followUp'] ?? ''),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
// ─────────────────────────────────────────
// ADMIN STOCK SCREEN
// ─────────────────────────────────────────
class AdminStockScreen extends StatefulWidget {
  const AdminStockScreen({super.key});

  @override
  State<AdminStockScreen> createState() => _AdminStockScreenState();
}

class _AdminStockScreenState extends State<AdminStockScreen> {
  String _filterDivision = 'All';
  String _searchQuery = '';
  final List<String> _divisions = ['All', 'Ortho', 'Gynec', 'General'];

  String _selectedStockistView = 'overall';
  String _selectedStockistLabel = 'Overall (Products)';
  List<Map<String, dynamic>> _stockists = [];
  Map<String, int> _stockistStockData = {};
  bool _loadingStockists = true;
  bool _loadingStockistStock = false;
  bool _addingToAll = false; // ← prevent double-tap on "Add to All"

  @override
  void initState() {
    super.initState();
    _loadStockists();
  }

  Future<void> _loadStockists() async {
    try {
      // Admin should see ALL stockists, not just assigned ones
      final snap = await db
          .collection('users')
          .where('role', isEqualTo: 'stockist')
          .where('isActive', isEqualTo: true)
          .orderBy('name')
          .get();

      if (mounted) {
        setState(() {
          _stockists = snap.docs.map((d) {
            final data = d.data() as Map<String, dynamic>;
            return {
              'id': d.id,
              'uid': d.id,
              'name': data['name'] ?? 'Unknown',
              'city': data['city'] ?? '',
            };
          }).toList();
          _loadingStockists = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loadingStockists = false);
    }
  }

  Future<void> _loadStockistStock(String stockistUid) async {
    if (!mounted) return;
    setState(() {
      _loadingStockistStock = true;
      _stockistStockData = {}; // clear stale data while loading
    });
    try {
      final doc =
      await _db.collection('stockist_stock').doc(stockistUid).get();
      if (mounted) {
        final data =
        doc.exists ? (doc.data() ?? {}) : <String, dynamic>{};
        setState(() {
          _stockistStockData =
              data.map((k, v) => MapEntry(k, (v as num?)?.toInt() ?? 0));
          _loadingStockistStock = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loadingStockistStock = false);
    }
  }

  // Called by _ProductCard after a successful stockist-stock update
  // so the list refreshes immediately without navigation
  void _onStockistStockUpdated(String productId, int newQty) {
    if (!mounted) return;
    setState(() {
      _stockistStockData[productId] = newQty;
    });
  }

  void _showAddStockToAllDialog(BuildContext context) async {
    if (_addingToAll) return; // guard double-tap
    final productsSnap = await _db.collection('products').get();
    String? selectedProductId;
    String? selectedProductName;
    final qtyController = TextEditingController();
    bool saving = false;

    if (!context.mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          title: const Text('Add Stock to All Stockists'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                hint: const Text('Select Product'),
                value: selectedProductId,
                items: productsSnap.docs.map((d) {
                  final data = d.data();
                  return DropdownMenuItem(
                    value: d.id,
                    child: Text(data['name'] ?? ''),
                  );
                }).toList(),
                onChanged: saving
                    ? null // disable while saving
                    : (val) => setStateDialog(() {
                  selectedProductId = val;
                  selectedProductName = productsSnap.docs
                      .firstWhere((d) => d.id == val)
                      .data()['name'];
                }),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: qtyController,
                keyboardType: TextInputType.number,
                enabled: !saving,
                decoration: const InputDecoration(
                  labelText: 'Quantity to Add',
                  prefixIcon: Icon(Icons.add_box),
                ),
              ),
              if (saving) ...[
                const SizedBox(height: 16),
                const Row(
                  children: [
                    SizedBox(
                        width: 18,
                        height: 18,
                        child:
                        CircularProgressIndicator(strokeWidth: 2)),
                    SizedBox(width: 10),
                    Text('Adding to all stockists…',
                        style: TextStyle(fontSize: 13)),
                  ],
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed:
              saving ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: saving
                  ? null // prevent double-tap
                  : () async {
                if (selectedProductId == null) return;
                final qty =
                    int.tryParse(qtyController.text.trim()) ?? 0;
                if (qty <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content:
                        Text('Please enter a valid quantity'),
                        backgroundColor: Colors.orange),
                  );
                  return;
                }
                setStateDialog(() => saving = true);
                setState(() => _addingToAll = true);
                try {
                  final stockistsSnap = await _db
                      .collection('users')
                      .where('role', isEqualTo: 'stockist')
                      .get();
                  final batch = _db.batch();
                  for (final s in stockistsSnap.docs) {
                    final uid = s.id;
                    final stockRef = _db
                        .collection('stockist_stock')
                        .doc(uid);
                    final stockDoc = await stockRef.get();
                    final current = stockDoc.exists
                        ? (stockDoc.data()?[selectedProductId!]
                    as num?)
                        ?.toInt() ??
                        0
                        : 0;
                    batch.set(
                      stockRef,
                      {selectedProductId!: current + qty},
                      SetOptions(merge: true),
                    );
                  }
                  await batch.commit();

                  // If currently viewing a stockist, refresh immediately
                  if (_selectedStockistView != 'overall') {
                    await _loadStockistStock(
                        _selectedStockistView);
                  }

                  if (ctx.mounted) Navigator.pop(ctx);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                            '✅ Added $qty units of $selectedProductName to all stockists!'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  if (ctx.mounted)
                    setStateDialog(() => saving = false);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('❌ Failed. Try again.'),
                          backgroundColor: Colors.red),
                    );
                  }
                } finally {
                  if (mounted) setState(() => _addingToAll = false);
                }
              },
              child: const Text('Add to All'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool showingStockist = _selectedStockistView != 'overall';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Stock Management'),
        actions: [
          // "Add to all stockists" button — only icon, no add-product duplicate
          _addingToAll
              ? const Padding(
            padding: EdgeInsets.all(12),
            child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white)),
          )
              : IconButton(
            icon: const Icon(Icons.group_add),
            tooltip: 'Add stock to all stockists',
            onPressed: () => _showAddStockToAllDialog(context),
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add new product',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AddProductScreen()),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Stockist selector ──────────────────────────────
          _loadingStockists
              ? const Padding(
            padding: EdgeInsets.all(16),
            child: LinearProgressIndicator(),
          )
              : Container(
            margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: showingStockist
                  ? Colors.teal.shade50
                  : Colors.blue.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: showingStockist
                      ? Colors.teal.shade200
                      : Colors.blue.shade200),
            ),
            child: Row(children: [
              Icon(
                  showingStockist
                      ? Icons.store
                      : Icons.inventory_2,
                  color: showingStockist
                      ? Colors.teal
                      : Colors.blue,
                  size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedStockistView,
                    isExpanded: true,
                    items: [
                      const DropdownMenuItem(
                        value: 'overall',
                        child: Text(
                          'Overall (All Products)',
                          style: TextStyle(
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                      // Only real stockists appear here (admin excluded
                      // because _loadStockists filters role == 'stockist')
                      ..._stockists.map((s) => DropdownMenuItem(
                        value: s['uid'] as String,
                        child: Text(
                            '${s['name']}${s['city'] != '' ? ' (${s['city']})' : ''}'),
                      )),
                    ],
                    onChanged: (val) {
                      if (val == null) return;
                      setState(() {
                        _selectedStockistView = val;
                        if (val == 'overall') {
                          _selectedStockistLabel =
                          'Overall (Products)';
                          _stockistStockData = {};
                        } else {
                          final s = _stockists.firstWhere(
                                  (x) => x['uid'] == val);
                          _selectedStockistLabel =
                          s['name'] as String;
                          _loadStockistStock(val);
                        }
                      });
                    },
                  ),
                ),
              ),
            ]),
          ),

          // ── Search ─────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: TextField(
              onChanged: (val) =>
                  setState(() => _searchQuery = val.toLowerCase()),
              decoration: InputDecoration(
                hintText: 'Search products…',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () =>
                      setState(() => _searchQuery = ''),
                )
                    : null,
              ),
            ),
          ),
          const SizedBox(height: 4),

          // ── Division chips ──────────────────────────────────
          SizedBox(
            height: 40,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: _divisions.length,
              itemBuilder: (context, index) {
                final div = _divisions[index];
                final isSelected = _filterDivision == div;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(div),
                    selected: isSelected,
                    onSelected: (_) =>
                        setState(() => _filterDivision = div),
                    selectedColor:
                    const Color(0xFF1565C0).withOpacity(0.2),
                    checkmarkColor: const Color(0xFF1565C0),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),

          // ── Summary bar ─────────────────────────────────────
          StreamBuilder<QuerySnapshot>(
            stream: _db.collection('products').snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const SizedBox();
              final docs = snapshot.data!.docs;

              if (showingStockist && _loadingStockistStock) {
                return const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: LinearProgressIndicator(),
                );
              }

              int total = docs.length;
              int lowStock = 0;
              int outOfStock = 0;

              if (showingStockist) {
                for (final d in docs) {
                  final qty = _stockistStockData[d.id] ?? 0;
                  if (qty == 0) {
                    outOfStock++;
                  } else if (qty <=
                      (((d.data() as Map<String, dynamic>)['minStock']
                      as num?)
                          ?.toInt() ??
                          10)) {
                    lowStock++;
                  }
                }
              } else {
                // Overall view: use product-level stock field
                lowStock = docs.where((d) {
                  final data = d.data() as Map<String, dynamic>;
                  final stock = (data['stock'] as num?)?.toInt() ?? 0;
                  final minStock =
                      (data['minStock'] as num?)?.toInt() ?? 10;
                  return stock <= minStock && stock > 0;
                }).length;
                outOfStock = docs.where((d) {
                  final data = d.data() as Map<String, dynamic>;
                  return ((data['stock'] as num?)?.toInt() ?? 0) == 0;
                }).length;
              }

              return Container(
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
                    _summaryItem('Total', '$total', Colors.blue),
                    _summaryItem(
                        'Low Stock', '$lowStock', Colors.orange),
                    _summaryItem(
                        'Out of Stock', '$outOfStock', Colors.red),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 8),

          // ── Product list ────────────────────────────────────
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _db
                  .collection('products')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text('Error: ${snapshot.error}',
                          style:
                          const TextStyle(color: Colors.red)),
                    ),
                  );
                }
                if (!snapshot.hasData ||
                    snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inventory_2_outlined,
                            size: 80, color: Colors.grey.shade300),
                        const SizedBox(height: 16),
                        Text('No products added yet',
                            style: TextStyle(
                                color: Colors.grey.shade500,
                                fontSize: 16)),
                        const SizedBox(height: 8),
                        Text('Tap + Add Product to get started',
                            style: TextStyle(
                                color: Colors.grey.shade400,
                                fontSize: 13)),
                      ],
                    ),
                  );
                }

                // Stockist-loading overlay while stock data arrives
                if (showingStockist && _loadingStockistStock) {
                  return const Center(child: CircularProgressIndicator());
                }

                var products = snapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final name =
                  (data['name'] ?? '').toString().toLowerCase();
                  final code =
                  (data['code'] ?? '').toString().toLowerCase();
                  final division =
                  (data['division'] ?? '').toString();
                  final matchesSearch = _searchQuery.isEmpty ||
                      name.contains(_searchQuery) ||
                      code.contains(_searchQuery);
                  final matchesDivision = _filterDivision == 'All' ||
                      division == _filterDivision;
                  return matchesSearch && matchesDivision;
                }).toList();

                if (products.isEmpty) {
                  return Center(
                    child: Text('No products found',
                        style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 16)),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: products.length,
                  itemBuilder: (context, index) {
                    final data =
                    products[index].data() as Map<String, dynamic>;
                    final docId = products[index].id;

                    if (showingStockist) {
                      final stockistQty =
                          _stockistStockData[docId] ?? 0;
                      final overriddenData =
                      Map<String, dynamic>.from(data);
                      overriddenData['stock'] = stockistQty;
                      return _ProductCard(
                        key: ValueKey('$docId-$stockistQty'), // force rebuild on qty change
                        data: overriddenData,
                        docId: docId,
                        isAdmin: true,
                        stockistLabel: _selectedStockistLabel,
                        stockistUid: _selectedStockistView,
                        onStockistStockUpdated: _onStockistStockUpdated, // ← callback
                      );
                    }

                    // Overall view: normal product-level stock, no stockist context
                    return _ProductCard(
                      key: ValueKey(docId),
                      data: data,
                      docId: docId,
                      isAdmin: true,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color)),
        Text(label,
            style:
            const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }
}

// ─────────────────────────────────────────
// PRODUCT CARD
// ─────────────────────────────────────────
class _ProductCard extends StatefulWidget {
  final Map<String, dynamic> data;
  final String docId;
  final bool isAdmin;
  final String? stockistLabel;
  final String? stockistUid;
  final void Function(String productId, int newQty)? onStockistStockUpdated;

  const _ProductCard({
    super.key,
    required this.data,
    required this.docId,
    required this.isAdmin,
    this.stockistLabel,
    this.stockistUid,
    this.onStockistStockUpdated,
  });

  @override
  State<_ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<_ProductCard> {
  bool _menuBusy = false; // prevent double popup actions

  Color _divisionColor(String division) {
    switch (division) {
      case 'Ortho':
        return Colors.blue;
      case 'Gynec':
        return Colors.pink;
      default:
        return Colors.green;
    }
  }

  @override
  Widget build(BuildContext context) {
    final division = widget.data['division'] ?? 'General';
    final color = _divisionColor(division);
    final stock = (widget.data['stock'] as num?)?.toInt() ?? 0;
    final minStock = (widget.data['minStock'] as num?)?.toInt() ?? 10;
    final isOutOfStock = stock == 0;
    final isLowStock = stock > 0 && stock <= minStock;

    Color stockColor = Colors.green;
    String stockLabel = 'In Stock';
    if (isOutOfStock) {
      stockColor = Colors.red;
      stockLabel = 'Out of Stock';
    } else if (isLowStock) {
      stockColor = Colors.orange;
      stockLabel = 'Low Stock';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape:
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.medication, color: color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.data['name'] ?? 'Unknown',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15)),
                      Text('Code: ${widget.data['code'] ?? 'N/A'}',
                          style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 12)),
                    ],
                  ),
                ),
                if (widget.isAdmin)
                  _menuBusy
                      ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                          strokeWidth: 2))
                      : PopupMenuButton(
                    icon: const Icon(Icons.more_vert),
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                          value: 'stock',
                          child: Text('Update Stock')),
                      const PopupMenuItem(
                          value: 'edit',
                          child: Text('Edit Product')),
                      const PopupMenuItem(
                          value: 'delete',
                          child: Text('Delete',
                              style: TextStyle(
                                  color: Colors.red))),
                    ],
                    onSelected: (value) async {
                      if (_menuBusy) return;
                      if (value == 'edit') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AddProductScreen(
                                existingData: widget.data,
                                docId: widget.docId),
                          ),
                        );
                      } else if (value == 'stock') {
                        if (widget.stockistUid != null) {
                          _showUpdateStockistStockDialog(
                              context,
                              widget.docId,
                              stock,
                              widget.stockistUid!);
                        } else {
                          _showUpdateStockDialog(
                              context, widget.docId, stock);
                        }
                      } else if (value == 'delete') {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (_) => AlertDialog(
                            title:
                            const Text('Delete Product'),
                            content: Text(
                                'Delete ${widget.data['name']}?'),
                            actions: [
                              TextButton(
                                  onPressed: () => Navigator.pop(
                                      context, false),
                                  child:
                                  const Text('Cancel')),
                              TextButton(
                                  onPressed: () => Navigator.pop(
                                      context, true),
                                  child: const Text('Delete',
                                      style: TextStyle(
                                          color: Colors.red))),
                            ],
                          ),
                        );
                        if (confirm == true && mounted) {
                          setState(() => _menuBusy = true);
                          try {
                            await _db
                                .collection('products')
                                .doc(widget.docId)
                                .delete();
                          } finally {
                            if (mounted)
                              setState(() =>
                              _menuBusy = false);
                          }
                        }
                      }
                    },
                  ),
              ],
            ),
            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 10),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(division,
                      style: TextStyle(
                          color: color,
                          fontSize: 11,
                          fontWeight: FontWeight.w600)),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: stockColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(stockLabel,
                      style: TextStyle(
                          color: stockColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w600)),
                ),
                const Spacer(),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('$stock units',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: stockColor,
                            fontSize: 14)),
                    Text(
                        '₹${widget.data['price'] ?? '0'} | ${widget.data['packSize'] ?? 'N/A'}',
                        style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 11)),
                    if (widget.stockistLabel != null)
                      Text(widget.stockistLabel!,
                          style: TextStyle(
                              color: Colors.teal.shade700,
                              fontSize: 10,
                              fontWeight: FontWeight.w600)),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showUpdateStockDialog(
      BuildContext context, String docId, int currentStock) {
    final controller =
    TextEditingController(text: '$currentStock');
    bool saving = false;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const Text('Update Stock'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Current stock: $currentStock units',
                  style: const TextStyle(color: Colors.grey)),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                enabled: !saving,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'New Stock Quantity',
                  prefixIcon: Icon(Icons.inventory),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed:
                saving ? null : () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            ElevatedButton(
              onPressed: saving
                  ? null
                  : () async {
                final newStock =
                    int.tryParse(controller.text.trim()) ??
                        0;
                setD(() => saving = true);
                try {
                  await _db
                      .collection('products')
                      .doc(docId)
                      .update({'stock': newStock});
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('✅ Stock updated!'),
                          backgroundColor: Colors.green),
                    );
                  }
                } catch (e) {
                  setD(() => saving = false);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content:
                          Text('❌ Failed. Try again.'),
                          backgroundColor: Colors.red),
                    );
                  }
                }
              },
              child: saving
                  ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
                  : const Text('Update'),
            ),
          ],
        ),
      ),
    );
  }

  void _showUpdateStockistStockDialog(BuildContext context,
      String docId, int currentStock, String stockistUid) {
    final controller =
    TextEditingController(text: '$currentStock');
    bool saving = false;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const Text('Update Stockist Stock'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Current stock: $currentStock units',
                  style: const TextStyle(color: Colors.grey)),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                enabled: !saving,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'New Stock Quantity',
                  prefixIcon: Icon(Icons.inventory),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed:
                saving ? null : () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            ElevatedButton(
              onPressed: saving
                  ? null
                  : () async {
                final newStock =
                    int.tryParse(controller.text.trim()) ??
                        0;
                setD(() => saving = true);
                try {
                  await _db
                      .collection('stockist_stock')
                      .doc(stockistUid)
                      .set(
                    {docId: newStock},
                    SetOptions(merge: true),
                  );
                  // ← Immediately update parent list without re-fetching
                  widget.onStockistStockUpdated
                      ?.call(docId, newStock);
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text(
                              '✅ Stockist stock updated!'),
                          backgroundColor: Colors.green),
                    );
                  }
                } catch (e) {
                  setD(() => saving = false);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content:
                          Text('❌ Failed. Try again.'),
                          backgroundColor: Colors.red),
                    );
                  }
                }
              },
              child: saving
                  ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
                  : const Text('Update'),
            ),
          ],
        ),
      ),
    );
  }
}
// ─────────────────────────────────────────
// ADMIN PROFILE SCREEN
// ─────────────────────────────────────────
class AdminProfileScreen extends StatelessWidget {
  const AdminProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final adminEmail = _auth.currentUser?.email ?? 'Administrator';
    return Scaffold(
      appBar: AppBar(title: const Text('Manage')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [Color(0xFF1565C0), Color(0xFF1E88E5)]),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  const CircleAvatar(
                    radius: 40,
                    backgroundColor: Colors.white,
                    child: Icon(Icons.admin_panel_settings,
                        size: 50, color: Color(0xFF1565C0)),
                  ),
                  const SizedBox(height: 12),
                  const Text('Administrator',
                      style: TextStyle(color: Colors.white,
                          fontSize: 18, fontWeight: FontWeight.bold)),
                  Text(adminEmail,
                      style: const TextStyle(color: Colors.white70, fontSize: 13)),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _menuItem(context, Icons.badge, 'MR Management', Colors.blue, () {
              Navigator.push(context, MaterialPageRoute(
                  builder: (_) => const AdminMrManagementScreen()));
            }),
            _menuItem(context, Icons.people, 'Doctor Management', Colors.green, () {
              Navigator.push(context, MaterialPageRoute(
                  builder: (_) => const AdminDoctorsScreen()));
            }),
            _menuItem(context, Icons.store, 'Stockist Management', Colors.brown, () {
              Navigator.push(context, MaterialPageRoute(
                  builder: (_) => const AdminStockistScreen()));
            }),
            _menuItem(context, Icons.calendar_today, 'Attendance Records', Colors.orange, () {
              Navigator.push(context, MaterialPageRoute(
                  builder: (_) => const AdminAttendanceScreen()));
            }),
            _menuItem(context, Icons.event_busy, 'Leave Approvals', Colors.red, () {
              Navigator.push(context, MaterialPageRoute(
                  builder: (_) => const AdminLeaveApprovalsScreen()));
            }),
            _menuItem(context, Icons.account_balance_wallet,
                'Allowance Management', Colors.purple, () {
                  Navigator.push(context, MaterialPageRoute(
                      builder: (_) => const AdminAllowanceScreen()));
                }),
            _menuItem(context, Icons.assignment, 'MR Daily Reports', Colors.teal, () {
              Navigator.push(context, MaterialPageRoute(
                  builder: (_) => const AdminMrReportsScreen()));
            }),
            _menuItem(context, Icons.inventory_2, 'Stock Reports', Colors.deepOrange, () {
              Navigator.push(context, MaterialPageRoute(
                  builder: (_) => const AdminStockReportsScreen()));
            }),
            _menuItem(context, Icons.lock_outline, 'Change Password', Colors.blueGrey, () {
              Navigator.push(context, MaterialPageRoute(
                  builder: (_) => const AdminChangePasswordScreen()));
            }),
            _menuItem(context, Icons.route, 'MR Visit History', Colors.indigo, () {
              Navigator.push(context, MaterialPageRoute(
                  builder: (_) => const AdminMrVisitHistoryScreen()));
            }),
            const SizedBox(height: 10),
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
                        TextButton(onPressed: () => Navigator.pop(context, false),
                            child: const Text('Cancel')),
                        TextButton(onPressed: () => Navigator.pop(context, true),
                            child: const Text('Logout',
                                style: TextStyle(color: Colors.red))),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    isLoggingOut = true;
                    await _auth.signOut();
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _menuItem(BuildContext context, IconData icon, String label,
      Color color, VoidCallback onTap) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(label, style: const TextStyle(fontSize: 14)),
        trailing:
        const Icon(Icons.chevron_right, color: Colors.grey),
        onTap: onTap,
      ),
    );
  }
}

// ─────────────────────────────────────────
// ADMIN STOCKIST SCREEN
// ─────────────────────────────────────────
class AdminStockistScreen extends StatefulWidget {
  const AdminStockistScreen({super.key});

  @override
  State<AdminStockistScreen> createState() => _AdminStockistScreenState();
}

class _AdminStockistScreenState extends State<AdminStockistScreen> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Stockist Management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AddStockistScreen()),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AddStockistScreen()),
        ),
        icon: const Icon(Icons.add),
        label: const Text('Add Stockist'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
              decoration: InputDecoration(
                hintText: 'Search stockists...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () => setState(() => _searchQuery = ''),
                )
                    : null,
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _db
                  .collection('users').where('role', isEqualTo: 'stockist').orderBy('createdAt', descending: true).snapshots(),
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
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.store_outlined,
                            size: 80, color: Colors.grey.shade300),
                        const SizedBox(height: 16),
                        Text('No stockists added yet',
                            style: TextStyle(
                                color: Colors.grey.shade500, fontSize: 16)),
                        const SizedBox(height: 8),
                        Text('Tap + Add Stockist to get started',
                            style: TextStyle(
                                color: Colors.grey.shade400, fontSize: 13)),
                      ],
                    ),
                  );
                }

                var docs = snapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final name = (data['name'] ?? '').toString().toLowerCase();
                  final city = (data['city'] ?? '').toString().toLowerCase();
                  return _searchQuery.isEmpty ||
                      name.contains(_searchQuery) ||
                      city.contains(_searchQuery);
                }).toList();

                if (docs.isEmpty) {
                  return Center(
                    child: Text('No stockists found',
                        style: TextStyle(color: Colors.grey.shade500)),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    final docId = docs[index].id;
                    return _StockistCard(data: data, docId: docId);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _StockistCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final String docId;

  const _StockistCard({
    required this.data,
    required this.docId,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.brown.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.store, color: Colors.brown),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(data['name'] ?? 'Unknown',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15)),
                      Text(data['city'] ?? '',
                          style: TextStyle(
                              color: Colors.grey.shade500, fontSize: 12)),
                      Text(data['address'] ?? '',
                          style: TextStyle(
                              color: Colors.grey.shade400, fontSize: 11),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                PopupMenuButton(
                  icon: const Icon(Icons.more_vert),
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                        value: 'edit', child: Text('Edit')),
                    const PopupMenuItem(
                        value: 'delete',
                        child: Text('Delete',
                            style: TextStyle(color: Colors.red))),
                  ],
                  onSelected: (value) async {
                    if (value == 'edit') {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AddStockistScreen(
                            existingData: data,
                            docId: docId,
                          ),
                        ),
                      );
                    } else if (value == 'delete') {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: const Text('Delete Stockist'),
                          content: Text('Delete ${data['name']}?'),
                          actions: [
                            TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('Cancel')),
                            TextButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text('Delete',
                                    style: TextStyle(color: Colors.red))),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        await _db.collection('users').doc(docId).delete();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Stockist deleted'),
                                backgroundColor: Colors.red),
                          );
                        }
                      }
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.phone, size: 14, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(data['phone'] ?? 'No phone',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                const SizedBox(width: 16),
                Icon(Icons.email, size: 14, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(data['email'] ?? 'No email',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────
// ADD / EDIT STOCKIST SCREEN
// ─────────────────────────────────────────
class AddStockistScreen extends StatefulWidget {
  final Map<String, dynamic>? existingData;
  final String? docId;

  const AddStockistScreen({super.key, this.existingData, this.docId});

  @override
  State<AddStockistScreen> createState() => _AddStockistScreenState();
}

class _AddStockistScreenState extends State<AddStockistScreen> {
  final _nameController     = TextEditingController();
  final _phoneController    = TextEditingController();
  final _emailController    = TextEditingController();
  final _addressController  = TextEditingController();
  final _cityController     = TextEditingController();
  final _pinCodeController  = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading       = false;
  bool _obscurePassword = true;
  String _errorMessage  = '';
  bool get _isEditing  => widget.existingData != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final d = widget.existingData!;
      _nameController.text    = d['name']    ?? '';
      _phoneController.text   = d['phone']   ?? '';
      _emailController.text   = d['email']   ?? '';
      _addressController.text = d['address'] ?? '';
      _cityController.text    = d['city']    ?? '';
      _pinCodeController.text = d['pinCode'] ?? '';
    }
  }

  Future<void> _saveStockist() async {
    final name  = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    final email = _emailController.text.trim();
    final city  = _cityController.text.trim();

    if (name.isEmpty || phone.isEmpty || city.isEmpty) {
      setState(() => _errorMessage = 'Please fill name, phone and city.');
      return;
    }

    if (!_isEditing) {
      if (email.isEmpty) {
        setState(() => _errorMessage = 'Email is required to create login.');
        return;
      }
      if (_passwordController.text.trim().length < 6) {
        setState(() => _errorMessage = 'Password must be at least 6 characters.');
        return;
      }
    }

    setState(() { _isLoading = true; _errorMessage = ''; });

    try {
      if (_isEditing) {
        await _db.collection('users').doc(widget.docId).update({
          'name':      name,
          'phone':     phone,
          'email':     email,
          'address':   _addressController.text.trim(),
          'city':      city,
          'pinCode':   _pinCodeController.text.trim(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        final currentAdmin = _auth.currentUser!;
        FirebaseApp secondaryApp;
        try {
          secondaryApp = Firebase.app('secondary');
        } catch (_) {
          secondaryApp = await Firebase.initializeApp(
            name: 'secondary',
            options: DefaultFirebaseOptions.currentPlatform,
          );
        }
        final secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);
        final cred = await secondaryAuth.createUserWithEmailAndPassword(
          email: email,
          password: _passwordController.text.trim(),
        );
        final newUid = cred.user!.uid;

        await _db.collection('users').doc(newUid).set({
          'name':      name,
          'email':     email,
          'phone':     phone,
          'city':      city,
          'address':   _addressController.text.trim(),
          'pinCode':   _pinCodeController.text.trim(),
          'role':      'stockist',
          'isActive':  true,
          'createdAt': FieldValue.serverTimestamp(),
          'createdBy': currentAdmin.uid,
        });

        final productsSnapshot = await _db.collection('products').get();
        Map<String, int> stockData = {};
        for (var doc in productsSnapshot.docs) {
          stockData[doc.id] = 0;
        }
        await _db.collection('stockist_stock').doc(newUid).set(stockData);

        await secondaryAuth.signOut();
        await secondaryApp.delete();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_isEditing ? '✅ Stockist updated!' : '✅ Stockist account created!'),
          backgroundColor: Colors.green,
        ));
        Navigator.pop(context);
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.code == 'email-already-in-use'
            ? 'This email is already registered.'
            : 'Failed: ${e.message}';
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to save. Please try again.';
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _pinCodeController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Edit Stockist' : 'Add Stockist')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _field('Stockist Name *', _nameController, Icons.store,
                'e.g. Sharma Medical Store'),
            _field('Phone Number *', _phoneController, Icons.phone,
                'e.g. 9876543210', type: TextInputType.phone),
            _field('Email ${_isEditing ? "" : "*"}', _emailController,
                Icons.email, 'e.g. stockist@example.com',
                type: TextInputType.emailAddress,
                readOnly: _isEditing),
            _field('City *', _cityController, Icons.location_city, 'e.g. Nellore'),
            _field('Address', _addressController, Icons.location_on,
                'Full address', maxLines: 2),
            _field('Pin Code', _pinCodeController, Icons.pin, 'e.g. 524001',
                type: TextInputType.number),
            if (!_isEditing) ...[
              const SizedBox(height: 14),
              const Text('Password *',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              TextField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  hintText: 'Set login password',
                  prefixIcon: const Icon(Icons.lock_outlined),
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePassword
                        ? Icons.visibility_off
                        : Icons.visibility),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(children: [
                  Icon(Icons.info_outline, color: Colors.blue, size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This will create a login account for the stockist and initialize their stock.',
                      style: TextStyle(fontSize: 12, color: Colors.blue),
                    ),
                  ),
                ]),
              ),
            ],
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
              onPressed: _saveStockist,
              icon: Icon(_isEditing ? Icons.save : Icons.add_business),
              label: Text(
                _isEditing ? 'Update Stockist' : 'Create Stockist Account',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _field(
      String label,
      TextEditingController controller,
      IconData icon,
      String hint, {
        TextInputType type = TextInputType.text,
        int maxLines = 1,
        bool readOnly = false,
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
          readOnly: readOnly,
          style: TextStyle(color: readOnly ? Colors.grey : Colors.black),
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon),
            filled: readOnly,
            fillColor: readOnly ? Colors.grey.shade100 : null,
          ),
        ),
        const SizedBox(height: 14),
      ],
    );
  }
}

// ─────────────────────────────────────────
// ADMIN ATTENDANCE SCREEN
// ─────────────────────────────────────────
class AdminAttendanceScreen extends StatefulWidget {
  const AdminAttendanceScreen({super.key});
  @override
  State<AdminAttendanceScreen> createState() => _AdminAttendanceScreenState();
}

class _AdminAttendanceScreenState extends State<AdminAttendanceScreen> {
  int _year  = DateTime.now().year;
  int _month = DateTime.now().month;
  final _months = ['Jan','Feb','Mar','Apr','May','Jun',
    'Jul','Aug','Sep','Oct','Nov','Dec'];
  String _padded(int n) => n.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    final start      = '$_year-${_padded(_month)}-01';
    final daysInMonth = DateUtils.getDaysInMonth(_year, _month);
    final end        = '$_year-${_padded(_month)}-${_padded(daysInMonth)}';

    return Scaffold(
      appBar: AppBar(title: const Text('Attendance Records')),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            IconButton(
              onPressed: () => setState(() {
                if (_month == 1) { _month = 12; _year--; }
                else { _month--; }
              }),
              icon: const Icon(Icons.chevron_left),
            ),
            Text('${_months[_month - 1]} $_year',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            IconButton(
              onPressed: () => setState(() {
                if (_month == 12) { _month = 1; _year++; }
                else { _month++; }
              }),
              icon: const Icon(Icons.chevron_right),
            ),
          ]),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _db.collection('users').where('role', isEqualTo: 'mr').snapshots(),
            builder: (context, mrSnap) {
              if (mrSnap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!mrSnap.hasData || mrSnap.data!.docs.isEmpty) {
                return const Center(child: Text('No MRs found.'));
              }
              final mrs = mrSnap.data!.docs;
              return StreamBuilder<QuerySnapshot>(
                stream: _db
                    .collection('attendance')
                    .where('date', isGreaterThanOrEqualTo: start)
                    .where('date', isLessThanOrEqualTo: end)
                    .snapshots(),
                builder: (context, attSnap) {
                  final attMap = <String, Map<String, String>>{};
                  for (final d in attSnap.data?.docs ?? []) {
                    final data  = d.data() as Map<String, dynamic>;
                    final mrId  = data['mrId']?.toString() ?? '';
                    final date  = data['date']?.toString() ?? '';
                    final status = data['status']?.toString() ?? '';
                    if (mrId.isNotEmpty && date.isNotEmpty) {
                      attMap.putIfAbsent(mrId, () => {})[date] = status;
                    }
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: mrs.length,
                    itemBuilder: (context, i) {
                      final mr   = mrs[i].data() as Map<String, dynamic>;
                      final mrId = mrs[i].id;
                      final att  = attMap[mrId] ?? {};
                      final present = att.values.where((s) => s == 'present').length;
                      final absent  = att.values.where((s) => s == 'absent').length;
                      final leave   = att.values.where((s) => s == 'leave').length;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: ExpansionTile(
                          leading: const CircleAvatar(
                            backgroundColor: Color(0xFFE3F2FD),
                            child: Icon(Icons.person, color: Color(0xFF1565C0)),
                          ),
                          title: Text(mr['name'] ?? 'Unknown',
                              style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('📍 ${mr['area'] ?? 'N/A'}'),
                          trailing: Wrap(spacing: 8, children: [
                            _attChip('P: $present', Colors.green),
                            _attChip('A: $absent',  Colors.red),
                            _attChip('L: $leave',   Colors.orange),
                          ]),
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                              child: GridView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 7, crossAxisSpacing: 4, mainAxisSpacing: 4,
                                ),
                                itemCount: daysInMonth,
                                itemBuilder: (context, d) {
                                  final day    = d + 1;
                                  final key    = '$_year-${_padded(_month)}-${_padded(day)}';
                                  final dt     = DateTime(_year, _month, day);
                                  final isSun  = dt.weekday == DateTime.sunday;
                                  final status = att[key];
                                  Color bg = isSun ? Colors.grey.shade200 : Colors.grey.shade100;
                                  if (!isSun && status == 'present') bg = Colors.green.shade100;
                                  if (!isSun && status == 'absent')  bg = Colors.red.shade100;
                                  if (!isSun && status == 'leave')   bg = Colors.orange.shade100;
                                  return Container(
                                    decoration: BoxDecoration(
                                        color: bg, borderRadius: BorderRadius.circular(4)),
                                    child: Center(
                                      child: Text('$day',
                                          style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: isSun ? Colors.grey.shade400 : Colors.black87)),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ]),
    );
  }

  Widget _attChip(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
        color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
    child: Text(label, style: TextStyle(fontSize: 10, color: color,
        fontWeight: FontWeight.bold)),
  );
}

// ─────────────────────────────────────────
// ADMIN LEAVE APPROVALS SCREEN — FIXED
// Approve/Reject buttons now use StatefulWidget to prevent double-tap
// ─────────────────────────────────────────
class AdminLeaveApprovalsScreen extends StatelessWidget {
  const AdminLeaveApprovalsScreen({super.key});

  Color _statusColor(String s) {
    switch (s) {
      case 'approved': return Colors.green;
      case 'rejected': return Colors.red;
      default:         return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Leave Approvals'),
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white60,
            indicatorColor: Colors.white,
            tabs: [Tab(text: 'Pending'), Tab(text: 'All')],
          ),
        ),
        body: TabBarView(children: [
          _LeaveList(statusFilter: 'pending',  statusColor: _statusColor),
          _LeaveList(statusFilter: null,       statusColor: _statusColor),
        ]),
      ),
    );
  }
}

class _LeaveList extends StatelessWidget {
  final String? statusFilter;
  final Color Function(String) statusColor;
  const _LeaveList({required this.statusFilter, required this.statusColor});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _db.collection('leave_requests').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}',
              style: const TextStyle(color: Colors.red)));
        }

        final docs = (snapshot.data?.docs ?? []).where((d) {
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
              Icon(Icons.event_busy_outlined, size: 80, color: Colors.grey.shade300),
              const SizedBox(height: 16),
              Text(statusFilter != null ? 'No pending leave requests' : 'No leave requests',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 16)),
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
            return _LeaveCard(
              doc: doc,
              data: data,
              status: status,
              color: color,
            );
          },
        );
      },
    );
  }
}

// Stateful leave card to prevent double-tap on Approve/Reject
class _LeaveCard extends StatefulWidget {
  final QueryDocumentSnapshot doc;
  final Map<String, dynamic> data;
  final String status;
  final Color color;

  const _LeaveCard({
    required this.doc,
    required this.data,
    required this.status,
    required this.color,
  });

  @override
  State<_LeaveCard> createState() => _LeaveCardState();
}

class _LeaveCardState extends State<_LeaveCard> {
  bool _isProcessing = false;

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
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            CircleAvatar(
              backgroundColor: widget.color.withOpacity(0.15),
              child: Icon(Icons.event_busy, color: widget.color),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(widget.data['mrName'] ?? 'Unknown MR',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              Text('${widget.data['fromDate']} → ${widget.data['toDate']}  •  ${widget.data['days']} day(s)',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
              Text(widget.data['reason'] ?? '',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                  maxLines: 2, overflow: TextOverflow.ellipsis),
            ])),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                  color: widget.color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20)),
              child: Text(widget.status.toUpperCase(),
                  style: TextStyle(color: widget.color, fontSize: 11,
                      fontWeight: FontWeight.bold)),
            ),
          ]),
          if (widget.status == 'pending') ...[
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isProcessing ? null : () => _runAction(() async {
                    await _db.collection('leave_requests')
                        .doc(widget.doc.id).update({'status': 'rejected'});
                    final mrId = widget.data['mrId'] ?? '';
                    if (mrId.isNotEmpty) {
                      // Fix #6: Notify MR of rejection
                      await _db.collection('notifications').add({
                        'mrId':      mrId,
                        'title':     'Leave Rejected ❌',
                        'body':      'Your leave request from ${widget.data['fromDate']} to ${widget.data['toDate']} was not approved.',
                        'type':      'leave_rejected',
                        'isRead':    false,
                        'createdAt': FieldValue.serverTimestamp(),
                      });
                    }
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('Leave rejected.'),
                          backgroundColor: Colors.red));
                    }
                  }),
                  icon: _isProcessing
                      ? const SizedBox(width: 14, height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.red))
                      : const Icon(Icons.close, size: 16),
                  label: const Text('Reject'),
                  style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isProcessing ? null : () => _runAction(() async {
                    await _db.collection('leave_requests')
                        .doc(widget.doc.id).update({'status': 'approved'});
                    final from = DateTime.parse(widget.data['fromDate']);
                    final to   = DateTime.parse(widget.data['toDate']);
                    final mrId = widget.data['mrId'] ?? '';
                    if (mrId.isNotEmpty) {
                      for (var d = from;
                      !d.isAfter(to);
                      d = d.add(const Duration(days: 1))) {
                        // Fix #4: Skip Sundays — don't mark non-working days as leave
                        if (d.weekday == DateTime.sunday) continue;

                        final dateKey =
                            '${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';

                        // Fix #2: Don't overwrite existing 'present' attendance
                        final existingDoc = await _db.collection('attendance')
                            .doc('${mrId}_$dateKey').get();
                        if (existingDoc.exists) {
                          final existingStatus =
                          (existingDoc.data() as Map<String, dynamic>?)?['status'];
                          if (existingStatus == 'present') continue; // MR already worked this day
                        }

                        await _db.collection('attendance')
                            .doc('${mrId}_$dateKey')
                            .set({
                          'mrId':      mrId,
                          'date':      dateKey,
                          'status':    'leave',
                          'updatedAt': FieldValue.serverTimestamp(),
                        }, SetOptions(merge: true));
                      }
                    }
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('Leave approved!'),
                          backgroundColor: Colors.green));
                    }
                    // Fix #6: Notify MR of approval
                    await _db.collection('notifications').add({
                      'mrId':      mrId,
                      'title':     'Leave Approved ✅',
                      'body':      'Your leave from ${widget.data['fromDate']} to ${widget.data['toDate']} has been approved.',
                      'type':      'leave_approved',
                      'isRead':    false,
                      'createdAt': FieldValue.serverTimestamp(),
                    });
                  }),
                  icon: _isProcessing
                      ? const SizedBox(width: 14, height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.check, size: 16),
                  label: const Text('Approve'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                ),
              ),
            ]),
          ],
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────
// ADMIN ALLOWANCE MANAGEMENT SCREEN
// ─────────────────────────────────────────
class AdminAllowanceScreen extends StatelessWidget {
  const AdminAllowanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Allowance Management')),
      body: StreamBuilder<QuerySnapshot>(
        stream: _db.collection('users').where('role', isEqualTo: 'mr').snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snap.hasData || snap.data!.docs.isEmpty) {
            return const Center(child: Text('No MRs found.'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: snap.data!.docs.length,
            itemBuilder: (context, i) {
              final doc  = snap.data!.docs[i];
              final mr   = doc.data() as Map<String, dynamic>;
              final fixed = mr['fixedAllowance'] ?? 0;
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFE3F2FD),
                    child: Icon(Icons.person, color: Color(0xFF1565C0)),
                  ),
                  title: Text(mr['name'] ?? 'Unknown',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('📍 ${mr['area'] ?? 'N/A'}'),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('₹$fixed/mo',
                          style: const TextStyle(fontWeight: FontWeight.bold,
                              color: Color(0xFF1565C0), fontSize: 15)),
                      const Text('fixed', style: TextStyle(fontSize: 10, color: Colors.grey)),
                    ],
                  ),
                  onTap: () => _showAllowanceDialog(context, doc.id, mr, fixed),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showAllowanceDialog(BuildContext context, String mrDocId,
      Map<String, dynamic> mr, dynamic currentFixed) {
    final ctrl = TextEditingController(text: '$currentFixed');
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Set Allowance — ${mr['name'] ?? ''}'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Current fixed allowance: ₹$currentFixed/month',
              style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 12),
          TextField(
            controller: ctrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Fixed Monthly Allowance (₹)',
              prefixIcon: Icon(Icons.currency_rupee),
            ),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final newAmount = int.tryParse(ctrl.text.trim()) ?? 0;
              await _db.collection('users').doc(mrDocId)
                  .update({'fixedAllowance': newAmount});
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('Allowance set to ₹$newAmount/month'),
                    backgroundColor: Colors.green));
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}


// ─────────────────────────────────────────
// ADD / EDIT PRODUCT SCREEN
// ─────────────────────────────────────────
class AddProductScreen extends StatefulWidget {
  final Map<String, dynamic>? existingData;
  final String? docId;

  const AddProductScreen({super.key, this.existingData, this.docId});

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  final _nameController        = TextEditingController();
  final _codeController        = TextEditingController();
  final _priceController       = TextEditingController();
  final _packSizeController    = TextEditingController();
  final _stockController       = TextEditingController();
  final _minStockController    = TextEditingController();
  final _descriptionController = TextEditingController();

  String _selectedDivision = 'Ortho';
  bool _isLoading = false;
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
      _stockController.text       = '${d['stock']    ?? 0}';
      _minStockController.text    = '${d['minStock'] ?? 10}';
      _descriptionController.text = d['description'] ?? '';
      _selectedDivision           = d['division']    ?? 'Ortho';
    }
  }

  Future<void> _saveProduct() async {
    final name     = _nameController.text.trim();
    final code     = _codeController.text.trim();
    final price    = _priceController.text.trim();
    final packSize = _packSizeController.text.trim();
    final stock    = int.tryParse(_stockController.text.trim())    ?? 0;
    final minStock = int.tryParse(_minStockController.text.trim()) ?? 10;

    if (name.isEmpty || code.isEmpty) {
      setState(() => _errorMessage = 'Product name and code are required.');
      return;
    }

    setState(() { _isLoading = true; _errorMessage = ''; });

    try {
      final data = {
        'name':        name,
        'code':        code,
        'price':       price,
        'packSize':    packSize,
        'stock':       stock,
        'minStock':    minStock,
        'division':    _selectedDivision,
        'description': _descriptionController.text.trim(),
        'updatedAt':   FieldValue.serverTimestamp(),
      };

      if (_isEditing) {
        await _db.collection('products').doc(widget.docId).update(data);
      } else {
        data['createdAt'] = FieldValue.serverTimestamp();
        data['createdBy'] = _auth.currentUser!.uid;
        await _db.collection('products').add(data);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_isEditing ? '✅ Product updated!' : '✅ Product added!'),
          backgroundColor: Colors.green,
        ));
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() { _isLoading = false; _errorMessage = 'Failed to save. Please try again.'; });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    _priceController.dispose();
    _packSizeController.dispose();
    _stockController.dispose();
    _minStockController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Edit Product' : 'Add Product')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Division', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Row(
              children: _divisions.map((div) {
                final isSelected = _selectedDivision == div;
                Color color;
                switch (div) {
                  case 'Ortho': color = Colors.blue; break;
                  case 'Gynec': color = Colors.pink; break;
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
                          color: isSelected ? color.withOpacity(0.15) : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected ? color : Colors.grey.shade300,
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Text(div,
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
            _field('Product Name *', _nameController, Icons.medication,    'e.g. CalciMax Tablet'),
            _field('Product Code *', _codeController, Icons.qr_code,       'e.g. ARK-001'),
            _field('Price (₹)',      _priceController, Icons.currency_rupee,'e.g. 150', type: TextInputType.number),
            _field('Pack Size',      _packSizeController, Icons.inventory_2,'e.g. 10x10, 30ml'),
            _field('Description',   _descriptionController, Icons.description, 'Optional', maxLines: 2),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Row(children: [
                  Icon(Icons.inventory, color: Colors.blue),
                  SizedBox(width: 8),
                  Text('Stock Settings',
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Current Stock',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    TextField(
                      controller: _stockController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        hintText: '0',
                        prefixIcon: Icon(Icons.numbers, size: 18),
                        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                      ),
                    ),
                  ])),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Low Stock Alert',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    TextField(
                      controller: _minStockController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        hintText: '10',
                        prefixIcon: Icon(Icons.warning_amber, size: 18),
                        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                      ),
                    ),
                  ])),
                ]),
                const SizedBox(height: 8),
                const Text(
                  '💡 When stock falls to or below this number, it will be marked as low stock.',
                  style: TextStyle(fontSize: 11, color: Colors.blue),
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
              onPressed: _saveProduct,
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
      IconData icon, String hint,
      {TextInputType type = TextInputType.text, int maxLines = 1}) {
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
// ADMIN CHANGE PASSWORD SCREEN
// ─────────────────────────────────────────
class AdminChangePasswordScreen extends StatefulWidget {
  const AdminChangePasswordScreen({super.key});

  @override
  State<AdminChangePasswordScreen> createState() =>
      _AdminChangePasswordScreenState();
}

class _AdminChangePasswordScreenState
    extends State<AdminChangePasswordScreen> {
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
      final user = _auth.currentUser!;
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
      if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        msg = 'Current password is incorrect.';
      }
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

// ─────────────────────────────────────────
// ADMIN STOCK REPORTS SCREEN
// ─────────────────────────────────────────
class AdminStockReportsScreen extends StatelessWidget {
  const AdminStockReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Stock Reports')),
      body: StreamBuilder<QuerySnapshot>(
        stream: _db
            .collection('stock_reports')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.inventory_2_outlined, size: 80, color: Colors.grey.shade300),
                const SizedBox(height: 16),
                Text('No stock reports yet',
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 16)),
              ]),
            );
          }

          final docs = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            itemBuilder: (context, i) {
              final data    = docs[i].data() as Map<String, dynamic>;
              final isRead  = data['isRead'] as bool? ?? false;
              final items   = (data['items'] as List?) ?? [];
              final lowCount = items.where((e) => e['status'] == 'low').length;
              final outCount = items.where((e) => e['status'] == 'out').length;
              final role    = data['reporterRole'] ?? 'mr';
              final roleColor = role == 'stockist' ? Colors.brown : Colors.blue;
              final rolLabel  = role == 'stockist' ? 'Stockist' : 'MR';

              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                color: isRead ? Colors.white : Colors.orange.shade50,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: ExpansionTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.deepOrange.withOpacity(0.15),
                    child: const Icon(Icons.warning_amber, color: Colors.deepOrange),
                  ),
                  title: Row(children: [
                    Expanded(
                      child: Text(data['reporterName'] ?? data['mrName'] ?? 'Unknown',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: roleColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(rolLabel,
                          style: TextStyle(color: roleColor, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                  ]),
                  subtitle: Text(
                    '${data['stockistName'] != null ? "Stockist: ${data['stockistName']}  •  " : ""}'
                        'Date: ${data['date'] ?? 'N/A'}  •  '
                        '${lowCount > 0 ? "$lowCount Low  " : ""}'
                        '${outCount > 0 ? "$outCount Out" : ""}',
                  ),
                  trailing: !isRead
                      ? Container(
                      width: 10, height: 10,
                      decoration: const BoxDecoration(
                          color: Colors.orange, shape: BoxShape.circle))
                      : null,
                  onExpansionChanged: (expanded) async {
                    if (expanded && !isRead) {
                      await docs[i].reference.update({'isRead': true});
                    }
                  },
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Divider(),
                        ...items.map((item) {
                          final isOut = item['status'] == 'out';
                          return ListTile(
                            dense: true,
                            leading: Icon(
                              isOut ? Icons.remove_circle : Icons.warning_amber,
                              color: isOut ? Colors.red : Colors.orange,
                              size: 20,
                            ),
                            title: FutureBuilder<DocumentSnapshot>(
                              future: _db.collection('products')
                                  .doc(item['productId']).get(),
                              builder: (context, snap) {
                                final name = snap.hasData && snap.data!.exists
                                    ? (snap.data!.data() as Map<String, dynamic>)['name'] ?? item['productId']
                                    : item['productId'] ?? '';
                                return Text(name,
                                    style: const TextStyle(fontSize: 13));
                              },
                            ),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: isOut
                                    ? Colors.red.withOpacity(0.1)
                                    : Colors.orange.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                isOut ? 'OUT OF STOCK' : 'LOW STOCK',
                                style: TextStyle(
                                    color: isOut ? Colors.red : Colors.orange,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                          );
                        }),
                        if ((data['notes'] ?? '').toString().isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text('Note: ${data['notes']}',
                                style: const TextStyle(fontSize: 13)),
                          ),
                        ],
                      ]),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

}

class AdminApprovalsScreen extends StatelessWidget {
  const AdminApprovalsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Approvals'),
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white60,
            indicatorColor: Colors.white,
            tabs: [
              Tab(icon: Icon(Icons.event_busy,     size: 16), text: 'Leave'),
              Tab(icon: Icon(Icons.gps_not_fixed,  size: 16), text: 'GPS Override'),
            ],
          ),
        ),
        body: const TabBarView(children: [
          // Reuse the existing leave tab content
          _LeaveTabBody(),
          // New GPS override tab
          _GpsOverrideTabBody(),
        ]),
      ),
    );
  }
}

// Wraps existing leave approval UI so it can live inside a tab
class _LeaveTabBody extends StatelessWidget {
  const _LeaveTabBody();

  Color _statusColor(String s) {
    switch (s) {
      case 'approved': return Colors.green;
      case 'rejected': return Colors.red;
      default:         return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(children: [
        Material(
          color: const Color(0xFF1565C0),
          child: TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white60,
            indicatorColor: Colors.white,
            tabs: const [Tab(text: 'Pending'), Tab(text: 'All')],
          ),
        ),
        Expanded(
          child: TabBarView(children: [
            _LeaveList(statusFilter: 'pending', statusColor: _statusColor),
            _LeaveList(statusFilter: null,      statusColor: _statusColor),
          ]),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────
// GPS OVERRIDE TAB BODY
// ─────────────────────────────────────────
class _GpsOverrideTabBody extends StatelessWidget {
  const _GpsOverrideTabBody();

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(children: [
        Material(
          color: const Color(0xFF1565C0),
          child: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white60,
            indicatorColor: Colors.white,
            tabs: [Tab(text: 'Pending'), Tab(text: 'All')],
          ),
        ),
        Expanded(
          child: TabBarView(children: [
            _GpsOverrideList(statusFilter: 'pending'),
            _GpsOverrideList(statusFilter: null),
          ]),
        ),
      ]),
    );
  }
}

class _GpsOverrideList extends StatelessWidget {
  final String? statusFilter;
  const _GpsOverrideList({required this.statusFilter});

  @override
  Widget build(BuildContext context) {
    Query query = _db.collection('gps_override_requests')
        .orderBy('createdAt', descending: true);
    if (statusFilter != null) {
      query = query.where('status', isEqualTo: statusFilter);
    }
    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return Center(
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.gps_off, size: 80, color: Colors.grey.shade300),
              const SizedBox(height: 16),
              Text(
                statusFilter == 'pending'
                    ? 'No pending GPS override requests'
                    : 'No GPS override requests',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 16),
              ),
            ]),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: docs.length,
          itemBuilder: (context, i) => _GpsOverrideCard(doc: docs[i]),
        );
      },
    );
  }
}


// ─────────────────────────────────────────
// DOCTOR ORDER SUMMARY SCREEN
// ─────────────────────────────────────────
class DoctorOrderSummaryScreen extends StatelessWidget {
  final String doctorId;
  final String doctorName;

  const DoctorOrderSummaryScreen({
    super.key,
    required this.doctorId,
    required this.doctorName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(doctorName),
      ),
      body: FutureBuilder<QuerySnapshot>(
        future: FirebaseFirestore.instance
            .collection('orders')
            .where('doctorId', isEqualTo: doctorId)
            .where('status', isEqualTo: 'delivered')
            .get(),
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

          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inventory_2_outlined,
                      size: 80, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  Text(
                    'No delivered orders yet',
                    style: TextStyle(
                        color: Colors.grey.shade500, fontSize: 16),
                  ),
                ],
              ),
            );
          }

          // ── Aggregate quantities per product ──────────────────────
          final Map<String, int>    qtyMap  = {};
          final Map<String, String> nameMap = {};

          for (final doc in docs) {
            final data  = doc.data() as Map<String, dynamic>;
            final items = (data['items'] as List?) ?? [];
            for (final item in items) {
              final pid  = item['productId']?.toString()   ?? '';
              final name = item['productName']?.toString() ?? pid;
              final qty  = (item['quantity'] as num?)?.toInt() ?? 0;
              if (pid.isEmpty) continue;
              qtyMap[pid]  = (qtyMap[pid]  ?? 0) + qty;
              nameMap[pid] = name;
            }
          }

          if (qtyMap.isEmpty) {
            return Center(
              child: Text(
                'No product data found.',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 16),
              ),
            );
          }

          // ── Sort by quantity descending ───────────────────────────
          final sorted = qtyMap.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value));

          final totalQty = qtyMap.values.fold(0, (a, b) => a + b);

          return Column(
            children: [
              // ── Header ─────────────────────────────────────────────
              Container(
                width: double.infinity,
                margin: const EdgeInsets.all(12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [Color(0xFF1565C0), Color(0xFF1E88E5)]),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _headerStat('Products', '${sorted.length}', Icons.medication),
                    _headerStat('Total Units', '$totalQty', Icons.inventory_2),
                    _headerStat('Orders', '${docs.length}', Icons.receipt_long),
                  ],
                ),
              ),

              // ── Table header ───────────────────────────────────────
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 12),
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF1565C0).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Expanded(
                      child: Text('Product',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
                    Text('Qty',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 13)),
                  ],
                ),
              ),
              const SizedBox(height: 6),

              // ── Product rows ───────────────────────────────────────
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: sorted.length,
                  itemBuilder: (context, i) {
                    final entry   = sorted[i];
                    final name    = nameMap[entry.key] ?? entry.key;
                    final qty     = entry.value;
                    final isEven  = i % 2 == 0;
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: isEven
                            ? Colors.white
                            : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        children: [
                          // Rank
                          Container(
                            width: 24,
                            height: 24,
                            margin: const EdgeInsets.only(right: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1565C0).withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                '${i + 1}',
                                style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1565C0)),
                              ),
                            ),
                          ),
                          // Product name
                          Expanded(
                            child: Text(
                              name,
                              style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500),
                            ),
                          ),
                          // Qty badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1565C0).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: const Color(0xFF1565C0)
                                      .withOpacity(0.3)),
                            ),
                            child: Text(
                              '$qty units',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1565C0),
                                  fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

              // ── Total row ──────────────────────────────────────────
              Container(
                margin: const EdgeInsets.all(12),
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1565C0).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: const Color(0xFF1565C0).withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Total',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                    ),
                    Text(
                      '$totalQty units',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: Color(0xFF1565C0)),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _headerStat(String label, String value, IconData icon) => Column(
    children: [
      Icon(icon, color: Colors.white70, size: 20),
      const SizedBox(height: 4),
      Text(value,
          style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 18)),
      Text(label,
          style: const TextStyle(color: Colors.white70, fontSize: 11)),
    ],
  );
}

// ─────────────────────────────────────────
// GPS OVERRIDE CARD  (admin view)
// ─────────────────────────────────────────
class _GpsOverrideCard extends StatefulWidget {
  final QueryDocumentSnapshot doc;
  const _GpsOverrideCard({required this.doc});

  @override
  State<_GpsOverrideCard> createState() => _GpsOverrideCardState();
}

class _GpsOverrideCardState extends State<_GpsOverrideCard> {
  bool _processing = false;

  Future<void> _approve() async {
    if (_processing) return;
    setState(() => _processing = true);
    try {
      final data    = widget.doc.data() as Map<String, dynamic>;
      final mrId    = data['mrId']     as String? ?? '';
      final docId   = data['doctorId'] as String? ?? '';
      final docName = data['doctorName'] as String? ?? '';
      final today   = data['date']     as String? ?? '';

      // ── SINGLE combined write — status + approvedAt together ──────────────
      await widget.doc.reference.update({
        'status':     'approved',
        'approvedAt': FieldValue.serverTimestamp(),
      });

      // ── Record visit + mark attendance (no notification write here) ───────
      if (mrId.isNotEmpty && docId.isNotEmpty) {
        final existing = await _db
            .collection('visits')
            .where('mrId',     isEqualTo: mrId)
            .where('doctorId', isEqualTo: docId)
            .where('date',     isEqualTo: today)
            .get();

        if (existing.docs.isEmpty) {
          await _db.collection('visits').add({
            'mrId':        mrId,
            'doctorId':    docId,
            'doctorName':  docName,
            'date':        today,
            'timestamp':   FieldValue.serverTimestamp(),
            'gpsOverride': true,
          });
        }

        await _db.collection('attendance').doc('${mrId}_$today').set({
          'mrId':      mrId,
          'date':      today,
          'status':    'present',
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('GPS override approved. MR will be notified.'),
            backgroundColor: Colors.green));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  Future<void> _reject() async {
    if (_processing) return;
    setState(() => _processing = true);
    try {
      await widget.doc.reference.update({'status': 'rejected'});

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Request rejected. MR will be notified.'),
            backgroundColor: Colors.red));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'approved': return Colors.green;
      case 'rejected': return Colors.red;
      default:         return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    final data      = widget.doc.data() as Map<String, dynamic>;
    final status    = data['status']        as String? ?? 'pending';
    final color     = _statusColor(status);
    final distance  = data['distanceMeters'] as int? ?? 0;
    final createdAt = data['createdAt'] as Timestamp?;
    final timeStr   = createdAt != null
        ? '${createdAt.toDate().hour.toString().padLeft(2,'0')}:${createdAt.toDate().minute.toString().padLeft(2,'0')}'
        : '';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // Title row
          Row(children: [
            CircleAvatar(
              backgroundColor: color.withOpacity(0.12),
              child: Icon(Icons.gps_not_fixed, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(data['mrName'] ?? 'Unknown MR',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              Text('Doctor: ${data['doctorName'] ?? ''}',
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
              Text('Date: ${data['date'] ?? ''}  •  Time: $timeStr',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
            ])),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(status.toUpperCase(),
                  style: TextStyle(color: color, fontSize: 11,
                      fontWeight: FontWeight.bold)),
            ),
          ]),

          const SizedBox(height: 8),

          // Distance info
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: Row(children: [
              const Icon(Icons.location_on, size: 14, color: Colors.orange),
              const SizedBox(width: 6),
              Flexible(   // ← ADD THIS
                child: Text(
                  'MR was $distance m away from doctor\'s registered location.',
                  style: const TextStyle(fontSize: 12, color: Colors.orange),
                ),
              ),
            ]),
          ),

          // Action buttons (only for pending)
          if (status == 'pending') ...[
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _processing ? null : _reject,
                  icon: _processing
                      ? const SizedBox(width: 14, height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.red))
                      : const Icon(Icons.close, size: 16),
                  label: const Text('Reject'),
                  style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _processing ? null : _approve,
                  icon: _processing
                      ? const SizedBox(width: 14, height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.check, size: 16),
                  label: const Text('Approve'),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green),
                ),
              ),
            ]),
          ],
        ]),
      ),
    );
  }
}