import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

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
          BottomNavigationBarItem(
              icon: Icon(Icons.dashboard), label: 'Dashboard'),
          BottomNavigationBarItem(
              icon: Icon(Icons.inventory_2), label: 'Stock'),
          BottomNavigationBarItem(
              icon: Icon(Icons.shopping_bag), label: 'Orders'),
          BottomNavigationBarItem(
              icon: Icon(Icons.badge), label: 'MRs'),
          BottomNavigationBarItem(
              icon: Icon(Icons.manage_accounts), label: 'Manage'),
        ],
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
            stream: _db
                .collection('leave_requests')
                .where('status', isEqualTo: 'pending')
                .snapshots(),
            builder: (context, snap) {
              final pending = snap.hasData ? snap.data!.docs.length : 0;
              return Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications_outlined),
                    onPressed: () => Navigator.push(context,
                        MaterialPageRoute(
                            builder: (_) => const AdminLeaveApprovalsScreen())),
                  ),
                  if (pending > 0)
                    Positioned(
                      right: 6, top: 6,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                            color: Colors.red, shape: BoxShape.circle),
                        child: Text(
                          pending > 9 ? '9+' : '$pending',
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
                                          .collection('stockists')
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
                                          mainAxisSfitpacing: 12,
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AddDoctorScreen()),
        ),
        icon: const Icon(Icons.add),
        label: const Text('Add Doctor'),
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
                        _latitude != null
                            ? Icons.location_on
                            : Icons.location_off,
                        color: _latitude != null
                            ? Colors.green
                            : Colors.orange,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _latitude != null
                              ? 'Location captured!\nLat: ${_latitude!.toStringAsFixed(6)}\nLng: ${_longitude!.toStringAsFixed(6)}'
                              : 'No location set yet.\nGo to the doctor\'s clinic and tap the button below to capture location.',
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
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isFetchingLocation
                          ? null
                          : _getCurrentLocation,
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
                          ? 'Update Location'
                          : 'Capture Current Location'),
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const AddMrScreen())),
        icon: const Icon(Icons.person_add),
        label: const Text('Add MR'),
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
                      if (value == 'toggle') {
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

      // 🔥 GET ALL PRODUCTS
      final productsSnapshot =
      await db.collection('products').get();

// 🔥 PREPARE STOCK MAP
      Map<String, int> stockData = {};

      for (var doc in productsSnapshot.docs) {
        stockData[doc.id] = 0; // default stock
      }

// 🔥 CREATE STOCK DOCUMENT
      await db.collection('stockist_stock').doc(uid).set(stockData);

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
    _tabController = TabController(length: 6, vsync: this);
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
      case 'billed':     return Colors.purple;
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
            Tab(text: 'Billed'),
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
          _OrderTab(statusFilter: 'billed',     statusColor: _statusColor),
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

class _AdminOrderDetailDialog extends StatelessWidget {
  final String orderId;
  final Map<String, dynamic> data;
  final Color Function(String) statusColor;
  const _AdminOrderDetailDialog(
      {required this.orderId, required this.data, required this.statusColor});

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
          if (data['billNumber'] != null && data['billNumber'].toString().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.purple.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.purple.shade200),
                ),
                child: Row(children: [
                  const Icon(Icons.receipt, color: Colors.purple, size: 16),
                  const SizedBox(width: 8),
                  Text('Bill No: ${data['billNumber']}',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, color: Colors.purple)),
                ]),
              ),
            ),
          Wrap(spacing: 8, runSpacing: 8, children: [
            if (status == 'pending') ...[
              _actionBtn('Approve', Colors.blue, () async {
                await _db.collection('orders').doc(orderId)
                    .update({'status': 'approved', 'approvedAt': FieldValue.serverTimestamp()});
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
              }),
              _actionBtn('Cancel', Colors.red, () async {
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
              }),
            ],
            if (status == 'approved')
              _actionBtn('Generate Bill', Colors.purple, () async {
                final billCtrl = TextEditingController();
                final billNo = await showDialog<String>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Generate Bill'),
                    content: Column(mainAxisSize: MainAxisSize.min, children: [
                      const Text('Enter bill number to mark this order as billed.',
                          style: TextStyle(color: Colors.grey, fontSize: 13)),
                      const SizedBox(height: 12),
                      TextField(
                        controller: billCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Bill Number',
                          prefixIcon: Icon(Icons.receipt),
                        ),
                      ),
                    ]),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel')),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context, billCtrl.text.trim()),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.purple),
                        child: const Text('Mark Billed'),
                      ),
                    ],
                  ),
                );
                if (billNo != null && billNo.isNotEmpty) {
                  await _db.collection('orders').doc(orderId).update({
                    'status': 'billed',
                    'billNumber': billNo,
                    'billedAt': FieldValue.serverTimestamp(),
                  });
                  final mrId = data['mrId']?.toString() ?? '';
                  if (mrId.isNotEmpty) {
                    await _db.collection('notifications').add({
                      'mrId':      mrId,
                      'title':     'Order Billed 🧾',
                      'body':      'Bill #$billNo generated for your order (${data['doctorName'] ?? 'doctor'}).',
                      'type':      'order_billed',
                      'orderId':   orderId,
                      'isRead':    false,
                      'createdAt': FieldValue.serverTimestamp(),
                    });
                  }
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text('✅ Bill #$billNo generated!'),
                        backgroundColor: Colors.purple));
                  }
                }
              }),
            if (status == 'billed')
              _actionBtn('Mark Dispatched', Colors.teal, () async {
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
              }),
            if (status == 'dispatched')
              _actionBtn('Mark Delivered', Colors.green, () async {
                await _db.collection('orders').doc(orderId)
                    .update({'status': 'delivered'});
                if (context.mounted) Navigator.pop(context);
              }),
            OutlinedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ]),
        ]),
      ),
    );
  }

  Widget _actionBtn(String label, Color color, VoidCallback onPressed) =>
      ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
            backgroundColor: color, foregroundColor: Colors.white),
        child: Text(label),
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

  // Stockist filter
  String _selectedStockistView = 'overall'; // 'overall' or stockist UID
  String _selectedStockistLabel = 'Overall (Products)';
  List<Map<String, dynamic>> _stockists = [];
  Map<String, int> _stockistStockData = {};
  bool _loadingStockists = true;
  bool _loadingStockistStock = false;

  @override
  void initState() {
    super.initState();
    _loadStockists();
  }

  Future<void> _loadStockists() async {
    try {
      final snap = await _db
          .collection('stockists')
          .where('isActive', isEqualTo: true)
          .orderBy('name')
          .get();
      if (mounted) {
        setState(() {
          _stockists = snap.docs.map((d) {
            final data = d.data();
            return {
              'id': d.id,
              'uid': data['uid'] ?? '',
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
    setState(() => _loadingStockistStock = true);
    try {
      final doc = await _db.collection('stockist_stock').doc(stockistUid).get();
      if (mounted) {
        final data = doc.exists ? (doc.data() ?? {}) : <String, dynamic>{};
        setState(() {
          _stockistStockData = data.map((k, v) => MapEntry(k, (v as num?)?.toInt() ?? 0));
          _loadingStockistStock = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loadingStockistStock = false);
    }
  }

  void _showAddStockToAllDialog(BuildContext context) async {
    final productsSnap = await _db.collection('products').get();
    String? selectedProductId;
    String? selectedProductName;
    final qtyController = TextEditingController();

    if (!context.mounted) return;
    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
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
                onChanged: (val) => setStateDialog(() {
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
                decoration: const InputDecoration(
                  labelText: 'Quantity to Add',
                  prefixIcon: Icon(Icons.add_box),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (selectedProductId == null) return;
                final qty = int.tryParse(qtyController.text.trim()) ?? 0;
                if (qty <= 0) return;
                final stockistsSnap = await _db.collection('users')
                    .where('role', isEqualTo: 'stockist').get();
                for (final s in stockistsSnap.docs) {
                  final uid = s.id;
                  final stockDoc = await _db
                      .collection('stockist_stock').doc(uid).get();
                  final current = stockDoc.exists
                      ? (stockDoc.data()?[selectedProductId!] as num?)?.toInt() ?? 0
                      : 0;
                  await _db.collection('stockist_stock').doc(uid).set(
                    {selectedProductId!: current + qty},
                    SetOptions(merge: true),
                  );
                }
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('✅ Added $qty units of $selectedProductName to all stockists!'),
                    backgroundColor: Colors.green,
                  ));
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
          IconButton(
            icon: const Icon(Icons.group_add),
            tooltip: 'Add stock to all stockists',
            onPressed: () => _showAddStockToAllDialog(context),
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AddProductScreen()),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AddProductScreen()),
        ),
        icon: const Icon(Icons.add),
        label: const Text('Add Product'),
      ),
      body: Column(
        children: [
          // Stockist selector
          Container(
            margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: showingStockist ? Colors.teal.shade50 : Colors.blue.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: showingStockist ? Colors.teal.shade200 : Colors.blue.shade200),
            ),
            child: Row(children: [
              Icon(showingStockist ? Icons.store : Icons.inventory_2,
                  color: showingStockist ? Colors.teal : Colors.blue, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedStockistView,
                    isExpanded: true,
                    items: [
                      const DropdownMenuItem(
                        value: 'overall',
                        child: Text('Overall (All Products)',
                            style: TextStyle(fontWeight: FontWeight.w600)),
                      ),
                      ..._stockists.map((s) => DropdownMenuItem(
                        value: s['uid'] as String,
                        child: Text('${s['name']}${s['city'] != '' ? ' (${s['city']})' : ''}'),
                      )),
                    ],
                    onChanged: (val) {
                      if (val == null) return;
                      setState(() {
                        _selectedStockistView = val;
                        if (val == 'overall') {
                          _selectedStockistLabel = 'Overall (Products)';
                          _stockistStockData = {};
                        } else {
                          final s = _stockists.firstWhere((x) => x['uid'] == val);
                          _selectedStockistLabel = s['name'] as String;
                          _loadStockistStock(val);
                        }
                      });
                    },
                  ),
                ),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: TextField(
              onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
              decoration: InputDecoration(
                hintText: 'Search products...',
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
          const SizedBox(height: 4),
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
                    onSelected: (_) => setState(() => _filterDivision = div),
                    selectedColor: const Color(0xFF1565C0).withOpacity(0.2),
                    checkmarkColor: const Color(0xFF1565C0),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          // Summary bar
          StreamBuilder<QuerySnapshot>(
            stream: _db.collection('products').snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const SizedBox();
              final docs = snapshot.data!.docs;

              if (showingStockist && _loadingStockistStock) {
                return const Padding(
                  padding: EdgeInsets.all(8),
                  child: LinearProgressIndicator(),
                );
              }

              int total = docs.length;
              int lowStock = 0;
              int outOfStock = 0;

              if (showingStockist) {
                for (final d in docs) {
                  final qty = _stockistStockData[d.id] ?? 0;
                  if (qty == 0) outOfStock++;
                  else if (qty <= (((d.data() as Map<String, dynamic>)['minStock'] as num?)?.toInt() ?? 10)) lowStock++;
                }
              } else {
                lowStock = docs.where((d) {
                  final data = d.data() as Map<String, dynamic>;
                  final stock = data['stock'] ?? 0;
                  final minStock = data['minStock'] ?? 10;
                  return stock <= minStock && stock > 0;
                }).length;
                outOfStock = docs.where((d) {
                  final data = d.data() as Map<String, dynamic>;
                  return (data['stock'] ?? 0) == 0;
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
                    _summaryItem('Low Stock', '$lowStock', Colors.orange),
                    _summaryItem('Out of Stock', '$outOfStock', Colors.red),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 8),
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
                          style: const TextStyle(color: Colors.red)),
                    ),
                  );
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inventory_2_outlined,
                            size: 80, color: Colors.grey.shade300),
                        const SizedBox(height: 16),
                        Text('No products added yet',
                            style: TextStyle(
                                color: Colors.grey.shade500, fontSize: 16)),
                        const SizedBox(height: 8),
                        Text('Tap + Add Product to get started',
                            style: TextStyle(
                                color: Colors.grey.shade400, fontSize: 13)),
                      ],
                    ),
                  );
                }
                var products = snapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final name = (data['name'] ?? '').toString().toLowerCase();
                  final code = (data['code'] ?? '').toString().toLowerCase();
                  final division = (data['division'] ?? '').toString();
                  final matchesSearch = _searchQuery.isEmpty ||
                      name.contains(_searchQuery) ||
                      code.contains(_searchQuery);
                  final matchesDivision =
                      _filterDivision == 'All' || division == _filterDivision;
                  return matchesSearch && matchesDivision;
                }).toList();
                if (products.isEmpty) {
                  return Center(
                    child: Text('No products found',
                        style: TextStyle(
                            color: Colors.grey.shade500, fontSize: 16)),
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
                      final stockistQty = _stockistStockData[docId] ?? 0;
                      final overriddenData = Map<String, dynamic>.from(data);
                      overriddenData['stock'] = stockistQty;
                      return _ProductCard(
                        data: overriddenData,
                        docId: docId,
                        isAdmin: true,
                        stockistLabel: _selectedStockistLabel,
                        stockistUid: _selectedStockistView, // ADD THIS
                      );
                    }

                    return _ProductCard(data: data, docId: docId, isAdmin: true);
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
                fontSize: 20, fontWeight: FontWeight.bold, color: color)),
        Text(label,
            style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }
}

class _ProductCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final String docId;
  final bool isAdmin;
  final String? stockistLabel;
  final String? stockistUid; // ADD THIS

  const _ProductCard({
    required this.data,
    required this.docId,
    required this.isAdmin,
    this.stockistLabel,
    this.stockistUid,
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

  @override
  Widget build(BuildContext context) {
    final division = data['division'] ?? 'General';
    final color = _divisionColor(division);
    final stock = data['stock'] ?? 0;
    final minStock = data['minStock'] ?? 10;
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
                      Text(data['name'] ?? 'Unknown',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15)),
                      Text('Code: ${data['code'] ?? 'N/A'}',
                          style: TextStyle(
                              color: Colors.grey.shade500, fontSize: 12)),
                    ],
                  ),
                ),
                if (isAdmin)
                  PopupMenuButton(
                    icon: const Icon(Icons.more_vert),
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                          value: 'stock', child: Text('Update Stock')),
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
                            builder: (_) => AddProductScreen(
                                existingData: data, docId: docId),
                          ),
                        );
                      } else if (value == 'stock') {
                        if (stockistUid != null) {
                          _showUpdateStockistStockDialog(context, docId, stock, stockistUid!);
                        } else {
                          _showUpdateStockDialog(context, docId, stock);
                        }
                      } else if (value == 'delete') {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: const Text('Delete Product'),
                            content: Text('Delete ${data['name']}?'),
                            actions: [
                              TextButton(
                                  onPressed: () =>
                                      Navigator.pop(context, false),
                                  child: const Text('Cancel')),
                              TextButton(
                                  onPressed: () =>
                                      Navigator.pop(context, true),
                                  child: const Text('Delete',
                                      style:
                                      TextStyle(color: Colors.red))),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          await _db
                              .collection('products')
                              .doc(docId)
                              .delete();
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
                  padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
                  padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
                    Text('₹${data['price'] ?? '0'} | ${data['packSize'] ?? 'N/A'}',
                        style: TextStyle(
                            color: Colors.grey.shade500, fontSize: 11)),
                    if (stockistLabel != null)
                      Text(stockistLabel!,
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
    final controller = TextEditingController(text: '$currentStock');
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
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
              decoration: const InputDecoration(
                labelText: 'New Stock Quantity',
                prefixIcon: Icon(Icons.inventory),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final newStock = int.tryParse(controller.text.trim()) ?? 0;
              await _db
                  .collection('products')
                  .doc(docId)
                  .update({'stock': newStock});
              if (context.mounted) {
                Navigator.pop(context);
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
  void _showUpdateStockistStockDialog(
      BuildContext context, String docId, int currentStock, String stockistUid) {
    final controller = TextEditingController(text: '$currentStock');
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
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
              decoration: const InputDecoration(
                labelText: 'New Stock Quantity',
                prefixIcon: Icon(Icons.inventory),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final newStock = int.tryParse(controller.text.trim()) ?? 0;
              await _db.collection('stockist_stock').doc(stockistUid).set(
                {docId: newStock},
                SetOptions(merge: true),
              );
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('✅ Stockist stock updated!'),
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
  final _nameController = TextEditingController();
  final _codeController = TextEditingController();
  final _priceController = TextEditingController();
  final _packSizeController = TextEditingController();
  final _stockController = TextEditingController();
  final _minStockController = TextEditingController();
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
      _nameController.text = d['name'] ?? '';
      _codeController.text = d['code'] ?? '';
      _priceController.text = '${d['price'] ?? ''}';
      _packSizeController.text = d['packSize'] ?? '';
      _stockController.text = '${d['stock'] ?? 0}';
      _minStockController.text = '${d['minStock'] ?? 10}';
      _descriptionController.text = d['description'] ?? '';
      _selectedDivision = d['division'] ?? 'Ortho';
    }
  }

  Future<void> _saveProduct() async {
    final name = _nameController.text.trim();
    final code = _codeController.text.trim();
    final price = _priceController.text.trim();
    final packSize = _packSizeController.text.trim();
    final stock = int.tryParse(_stockController.text.trim()) ?? 0;
    final minStock = int.tryParse(_minStockController.text.trim()) ?? 10;

    if (name.isEmpty || code.isEmpty) {
      setState(() => _errorMessage = 'Product name and code are required.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final data = {
        'name': name,
        'code': code,
        'price': price,
        'packSize': packSize,
        'stock': stock,
        'minStock': minStock,
        'division': _selectedDivision,
        'description': _descriptionController.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (_isEditing) {
        await _db.collection('products').doc(widget.docId).update(data);
      } else {
        data['createdAt'] = FieldValue.serverTimestamp();
        data['createdBy'] = _auth.currentUser!.uid;
        await _db.collection('products').add(data);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
            Text(_isEditing ? '✅ Product updated!' : '✅ Product added!'),
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
      appBar: AppBar(
          title: Text(_isEditing ? 'Edit Product' : 'Add Product')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Division',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Row(
              children: _divisions.map((div) {
                final isSelected = _selectedDivision == div;
                Color color;
                switch (div) {
                  case 'Ortho':
                    color = Colors.blue;
                    break;
                  case 'Gynec':
                    color = Colors.pink;
                    break;
                  default:
                    color = Colors.green;
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
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            _field('Product Name *', _nameController, Icons.medication,
                'e.g. CalciMax Tablet'),
            _field('Product Code *', _codeController, Icons.qr_code,
                'e.g. ARK-001'),
            _field('Price (₹)', _priceController, Icons.currency_rupee,
                'e.g. 150',
                type: TextInputType.number),
            _field('Pack Size', _packSizeController, Icons.inventory_2,
                'e.g. 10x10, 30ml'),
            _field('Description', _descriptionController, Icons.description,
                'Optional description',
                maxLines: 2),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.inventory, color: Colors.blue),
                      SizedBox(width: 8),
                      Text('Stock Settings',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Current Stock',
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600)),
                            const SizedBox(height: 4),
                            TextField(
                              controller: _stockController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                hintText: '0',
                                prefixIcon: Icon(Icons.numbers, size: 18),
                                contentPadding: EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 10),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Low Stock Alert',
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600)),
                            const SizedBox(height: 4),
                            TextField(
                              controller: _minStockController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                hintText: '10',
                                prefixIcon:
                                Icon(Icons.warning_amber, size: 18),
                                contentPadding: EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 10),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '💡 When stock falls to or below this number, it will be marked as low stock.',
                    style: TextStyle(fontSize: 11, color: Colors.blue),
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
                child: Text(_errorMessage,
                    style:
                    const TextStyle(color: Colors.red, fontSize: 13)),
              ),
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton.icon(
              onPressed: _saveProduct,
              icon: Icon(_isEditing ? Icons.save : Icons.add),
              label: Text(
                _isEditing ? 'Update Product' : 'Add Product',
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

  Widget _field(
      String label,
      TextEditingController controller,
      IconData icon,
      String hint, {
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
          decoration:
          InputDecoration(hintText: hint, prefixIcon: Icon(icon)),
        ),
        const SizedBox(height: 14),
      ],
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
                  .collection('stockists')
                  .orderBy('createdAt', descending: true)
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
                  child: Icon(Icons.store, color: Colors.brown),
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
                        await _db
                            .collection('stockists')
                            .doc(docId)
                            .delete();
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
// ADD / EDIT STOCKIST SCREEN (FIXED)
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
  bool get _isEditing   => widget.existingData != null;

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
        // Just update the Firestore doc — no auth changes
        await _db.collection('stockists').doc(widget.docId).update({
          'name':      name,
          'phone':     phone,
          'email':     email,
          'address':   _addressController.text.trim(),
          'city':      city,
          'pinCode':   _pinCodeController.text.trim(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        // Also update the users collection if uid stored
        final uid = widget.existingData!['uid']?.toString() ?? '';
        if (uid.isNotEmpty) {
          await _db.collection('users').doc(uid).update({
            'name':  name,
            'phone': phone,
            'city':  city,
          });
        }
      } else {
        // Create Firebase Auth account using secondary app
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

        // Save to users collection (for role-based routing)
        await _db.collection('users').doc(newUid).set({
          'name':      name,
          'email':     email,
          'phone':     phone,
          'city':      city,
          'role':      'stockist',
          'isActive':  true,
          'createdAt': FieldValue.serverTimestamp(),
          'createdBy': currentAdmin.uid,
        });

        // Save to stockists collection with uid linked
        await _db.collection('stockists').add({
          'uid':       newUid,
          'name':      name,
          'phone':     phone,
          'email':     email,
          'address':   _addressController.text.trim(),
          'city':      city,
          'pinCode':   _pinCodeController.text.trim(),
          'isActive':  true,
          'createdAt': FieldValue.serverTimestamp(),
          'createdBy': currentAdmin.uid,
        });

        // 🔥 IMPORTANT: Create stock document for this stockist
        // Get all products and initialize with zero stock
        final productsSnapshot = await _db.collection('products').get();
        Map<String, int> stockData = {};
        for (var doc in productsSnapshot.docs) {
          stockData[doc.id] = 0; // default stock for each product
        }
        // Create the stock document in stockist_stock collection
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
      print('Error creating stockist: $e');
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
// ADMIN LEAVE APPROVALS SCREEN
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
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    CircleAvatar(
                      backgroundColor: color.withOpacity(0.15),
                      child: Icon(Icons.event_busy, color: color),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(data['mrName'] ?? 'Unknown MR',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      Text('${data['fromDate']} → ${data['toDate']}  •  ${data['days']} day(s)',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                      Text(data['reason'] ?? '',
                          style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                          maxLines: 2, overflow: TextOverflow.ellipsis),
                    ])),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                          color: color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20)),
                      child: Text(status.toUpperCase(),
                          style: TextStyle(color: color, fontSize: 11,
                              fontWeight: FontWeight.bold)),
                    ),
                  ]),
                  if (status == 'pending') ...[
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            await _db.collection('leave_requests')
                                .doc(doc.id).update({'status': 'rejected'});
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                                  content: Text('Leave rejected.'),
                                  backgroundColor: Colors.red));
                            }
                          },
                          icon: const Icon(Icons.close, size: 16),
                          label: const Text('Reject'),
                          style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                              side: const BorderSide(color: Colors.red)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            await _db.collection('leave_requests')
                                .doc(doc.id).update({'status': 'approved'});
                            final from = DateTime.parse(data['fromDate']);
                            final to   = DateTime.parse(data['toDate']);
                            final mrId = data['mrId'] ?? '';
                            if (mrId.isNotEmpty) {
                              for (var d = from;
                              !d.isAfter(to);
                              d = d.add(const Duration(days: 1))) {
                                final dateKey =
                                    '${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';
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
                          },
                          icon: const Icon(Icons.check, size: 16),
                          label: const Text('Approve'),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                        ),
                      ),
                    ]),
                  ],
                ]),
              ),
            );
          },
        );
      },
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