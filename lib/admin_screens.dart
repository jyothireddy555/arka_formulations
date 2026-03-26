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
          IconButton(
              icon: const Icon(Icons.notifications_outlined),
              onPressed: () {}),
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
                              ],
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
  final List<String> _divisions = [
    'All', 'Ortho', 'Gynec', 'General'
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
          // Search bar
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

          // Division filter chips
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

          // Doctor list
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _db
                  .collection('doctors')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const Center(
                      child: CircularProgressIndicator());
                }

                if (!snapshot.hasData ||
                    snapshot.data!.docs.isEmpty) {
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

                // Filter doctors
                var docs = snapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final name =
                  (data['name'] ?? '').toString().toLowerCase();
                  final hospital = (data['hospital'] ?? '')
                      .toString()
                      .toLowerCase();
                  final division =
                  (data['division'] ?? '').toString();

                  final matchesSearch = _searchQuery.isEmpty ||
                      name.contains(_searchQuery) ||
                      hospital.contains(_searchQuery);

                  final matchesDivision =
                      _filterDivision == 'All' ||
                          division == _filterDivision;

                  return matchesSearch && matchesDivision;
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
                    return _DoctorCard(
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
}

// ─────────────────────────────────────────
// DOCTOR CARD WIDGET (shared by admin & MR)
// ─────────────────────────────────────────
class _DoctorCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final String docId;
  final bool isAdmin;

  const _DoctorCard({
    required this.data,
    required this.docId,
    required this.isAdmin,
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
                if (isAdmin)
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
                const Spacer(),
                Text(
                  '📍 ${data['area'] ?? 'N/A'}',
                  style: TextStyle(
                      fontSize: 11, color: Colors.grey.shade500),
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
      // Check permission
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

      // Get position
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
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (_isEditing) {
        await _db
            .collection('doctors')
            .doc(widget.docId)
            .update(data);
      } else {
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
            // Doctor Name
            _label('Doctor Name'),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                hintText: 'e.g. Dr. Ramesh Kumar',
                prefixIcon: Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: 14),

            // Specialization
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

            // Hospital
            _label('Hospital / Clinic Name'),
            TextField(
              controller: _hospitalController,
              decoration: const InputDecoration(
                hintText: 'e.g. City Hospital',
                prefixIcon: Icon(Icons.local_hospital_outlined),
              ),
            ),
            const SizedBox(height: 14),

            // Area
            _label('Area'),
            TextField(
              controller: _areaController,
              decoration: const InputDecoration(
                hintText: 'e.g. Nellore North',
                prefixIcon: Icon(Icons.map_outlined),
              ),
            ),
            const SizedBox(height: 14),

            // Address
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

            // Division
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

            // Location section
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

            // Error
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

            // Save button
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
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isActive
                        ? Colors.blue.shade50
                        : Colors.grey.shade100,
                    child: Icon(Icons.person,
                        color:
                        isActive ? Colors.blue : Colors.grey),
                  ),
                  title: Text(mr['name'] ?? 'Unknown',
                      style:
                      const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(
                      '${mr['email']}\n📍 ${mr['area'] ?? 'N/A'}'),
                  isThreeLine: true,
                  trailing: PopupMenuButton(
                    itemBuilder: (_) => [
                      PopupMenuItem(
                          value: 'toggle',
                          child: Text(
                              isActive ? 'Deactivate' : 'Activate')),
                    ],
                    onSelected: (value) async {
                      if (value == 'toggle') {
                        await _db
                            .collection('users')
                            .doc(docId)
                            .update({'isActive': !isActive});
                      }
                    },
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

      // Safely get or create the secondary Firebase app
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

      // Create MR in secondary app — admin session is never touched
      final userCredential = await secondaryAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final newUid = userCredential.user!.uid;

      // Write MR data to Firestore
      await _db.collection('users').doc(newUid).set({
        'name': name,
        'email': email,
        'phone': phone,
        'area': area,
        'division': _selectedDivision,
        'role': 'mr',
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': currentAdmin.uid,
      });

      // Sign out secondary only, then delete it cleanly
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
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
          tabs: const [
            Tab(text: 'Pending'),
            Tab(text: 'Approved'),
            Tab(text: 'Dispatched'),
            Tab(text: 'All'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _emptyState('No pending orders'),
          _emptyState('No approved orders'),
          _emptyState('No dispatched orders'),
          _emptyState('No orders yet'),
        ],
      ),
    );
  }

  Widget _emptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox_outlined,
              size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(message,
              style: TextStyle(
                  color: Colors.grey.shade500, fontSize: 16)),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Stock Management'),
        actions: [
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
          Padding(
            padding: const EdgeInsets.all(12),
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
          StreamBuilder<QuerySnapshot>(
            stream: _db.collection('products').snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const SizedBox();
              final docs = snapshot.data!.docs;
              final total = docs.length;
              final lowStock = docs.where((d) {
                final data = d.data() as Map<String, dynamic>;
                final stock = data['stock'] ?? 0;
                final minStock = data['minStock'] ?? 10;
                return stock <= minStock && stock > 0;
              }).length;
              final outOfStock = docs.where((d) {
                final data = d.data() as Map<String, dynamic>;
                return (data['stock'] ?? 0) == 0;
              }).length;
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

// ─────────────────────────────────────────
// PRODUCT CARD
// ─────────────────────────────────────────
class _ProductCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final String docId;
  final bool isAdmin;

  const _ProductCard({
    required this.data,
    required this.docId,
    required this.isAdmin,
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
                      const PopupMenuItem(value: 'edit', child: Text('Edit')),
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
                        _showUpdateStockDialog(context, docId, stock);
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
              child: const Column(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: Colors.white,
                    child: Icon(Icons.admin_panel_settings,
                        size: 50, color: Color(0xFF1565C0)),
                  ),
                  SizedBox(height: 12),
                  Text('Administrator',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold)),
                  Text('admin@arka.com',
                      style: TextStyle(
                          color: Colors.white70, fontSize: 13)),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _menuItem(context, Icons.badge, 'MR Management',
                Colors.blue, () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                          const AdminMrManagementScreen()));
                }),
            _menuItem(context, Icons.people, 'Doctor Management',
                Colors.green, () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const AdminDoctorsScreen()));
                }),
            _menuItem(context, Icons.calendar_today,
                'Attendance Records', Colors.orange, () {}),
            _menuItem(context, Icons.event_busy, 'Leave Approvals',
                Colors.red, () {}),
            _menuItem(
                context,
                Icons.account_balance_wallet,
                'Allowance Management',
                Colors.purple,
                    () {}),
            const SizedBox(height: 10),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Logout',
                  style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.w600)),
              onTap: () async {
                isLoggingOut = true;
                await _auth.signOut();
              },
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