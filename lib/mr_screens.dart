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
// MR DASHBOARD
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
  double _totalCommission = 0;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    final uid = auth.currentUser?.uid;
    if (uid == null) return;

    try {
      final userDoc = await db.collection('users').doc(uid).get();
      if (userDoc.exists && mounted) {
        setState(() => _mrName = userDoc.data()?['name'] ?? 'Medical Representative');
      }

      final today      = _dateKey(DateTime.now());
      final monthStart = DateTime(DateTime.now().year, DateTime.now().month, 1);

      final visits = await db
          .collection('visits')
          .where('mrId',  isEqualTo: uid)
          .where('date',  isEqualTo: today)
          .get();
      if (mounted) setState(() => _todayVisits = visits.docs.length.toString());

      final orders = await db
          .collection('orders')
          .where('mrId', isEqualTo: uid)
          .where('date', isEqualTo: today)
          .get();
      if (mounted) setState(() => _todayOrders = orders.docs.length.toString());

      final report = await db
          .collection('daily_reports')
          .where('mrId', isEqualTo: uid)
          .where('date', isEqualTo: today)
          .get();
      if (mounted) setState(() => _reportSubmitted = report.docs.isNotEmpty);

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

      // Load total commission
      final allowances = await db
          .collection('allowances')
          .where('mrId', isEqualTo: uid)
          .get();
      double totalComm = 0;
      for (final doc in allowances.docs) {
        totalComm += (doc['amount'] as num?)?.toDouble() ?? 0;
      }

      if (mounted) setState(() {
        _presentDays = present;
        _absentDays  = absent;
        _leaveDays   = leave;
        _totalCommission = totalComm;
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
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.purple.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.purple.shade200),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total Commission Earned',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  Text('₹${_totalCommission.toStringAsFixed(0)}',
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold, color: Colors.purple)),
                ],
              ),
            ),
            const SizedBox(height: 20),

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
                _quickAction(context, 'Add Doctor', Icons.person_add, Colors.teal, () {
                  Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const MrAddDoctorScreen()));
                }),
              ],
            ),
            const SizedBox(height: 20),

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
// MR ADD DOCTOR SCREEN
// ─────────────────────────────────────────
class MrAddDoctorScreen extends StatefulWidget {
  const MrAddDoctorScreen({super.key});

  @override
  State<MrAddDoctorScreen> createState() => _MrAddDoctorScreenState();
}

class _MrAddDoctorScreenState extends State<MrAddDoctorScreen> {
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

  Future<void> _getCurrentLocation() async {
    setState(() => _isFetchingLocation = true);

    try {
      LocationPermission permission = await Geolocator.checkPermission();
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
          _errorMessage = 'Location permission permanently denied.';
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
            content: Text('✅ Location captured!'),
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
      setState(() => _errorMessage = 'Please fill name, hospital and area.');
      return;
    }

    if (_latitude == null || _longitude == null) {
      setState(() => _errorMessage = 'Please capture the doctor\'s location first.');
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
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': auth.currentUser!.uid,
      };

      await db.collection('doctors').add(data);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Doctor added successfully!'),
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
      appBar: AppBar(title: const Text('Add New Doctor')),
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
                  .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                  .toList(),
              onChanged: (val) => setState(() => _selectedSpecialization = val!),
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
                  .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                  .toList(),
              onChanged: (val) => setState(() => _selectedDivision = val!),
            ),
            const SizedBox(height: 20),
            _label('Doctor\'s Location'),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _latitude != null ? Colors.green.shade50 : Colors.orange.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _latitude != null ? Colors.green.shade200 : Colors.orange.shade200,
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
                              ? 'Location captured!'
                              : 'No location set yet.\nGo to the doctor\'s clinic and tap below.',
                          style: TextStyle(
                            fontSize: 13,
                            color: _latitude != null ? Colors.green.shade700 : Colors.orange.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isFetchingLocation ? null : _getCurrentLocation,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _latitude != null ? Colors.green : const Color(0xFF1565C0),
                      ),
                      icon: _isFetchingLocation
                          ? const SizedBox(
                          width: 16, height: 16,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.my_location),
                      label: Text(_isFetchingLocation
                          ? 'Getting location...'
                          : _latitude != null ? 'Update Location' : 'Capture Current Location'),
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
                    const Icon(Icons.error_outline, color: Colors.red, size: 18),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_errorMessage, style: const TextStyle(color: Colors.red, fontSize: 13))),
                  ],
                ),
              ),
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton.icon(
              onPressed: _saveDoctor,
              icon: const Icon(Icons.person_add),
              label: const Text('Save Doctor', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.w600)),
    );
  }
}

// ─────────────────────────────────────────
// MR DOCTORS SCREEN
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
      appBar: AppBar(
        title: const Text('Doctor List'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MrAddDoctorScreen()),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const MrAddDoctorScreen()),
        ),
        icon: const Icon(Icons.add),
        label: const Text('Add Doctor'),
      ),
      body: Column(children: [
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
            stream: db.collection('doctors').orderBy('name').snapshots(),
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
                          const Text('Could not load doctors.',
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
                        Icon(Icons.people_outline, size: 80, color: Colors.grey.shade300),
                        const SizedBox(height: 16),
                        Text('No doctors found',
                            style: TextStyle(color: Colors.grey.shade500, fontSize: 16)),
                        const SizedBox(height: 8),
                        Text('Tap + Add Doctor to add a new doctor',
                            style: TextStyle(color: Colors.grey.shade400, fontSize: 13)),
                      ]),
                );
              }

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
                itemBuilder: (context, i) => _MrDoctorCard(
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

class _MrDoctorCard extends StatefulWidget {
  final String               docId;
  final Map<String, dynamic> data;
  const _MrDoctorCard({required this.docId, required this.data});

  @override
  State<_MrDoctorCard> createState() => _MrDoctorCardState();
}

class _MrDoctorCardState extends State<_MrDoctorCard> {
  bool _checking = false;

  Color _divColor(String div) {
    switch (div) {
      case 'Ortho': return Colors.blue;
      case 'Gynec': return Colors.pink;
      default:      return Colors.green;
    }
  }

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
      default:           return Icons.person;
    }
  }

  Future<void> _checkIn() async {
    setState(() => _checking = true);
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever || perm == LocationPermission.denied) {
        _showMsg('Location permission denied. Enable in settings.', Colors.red);
        return;
      }

      final Position pos;
      try {
        pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        ).timeout(const Duration(seconds: 15));
      } catch (e) {
        _showMsg('Could not get location. Check GPS is enabled.', Colors.red);
        return;
      }

      final double? docLat = (widget.data['latitude'] as num?)?.toDouble();
      final double? docLng = (widget.data['longitude'] as num?)?.toDouble();

      if (docLat == null || docLng == null) {
        _showMsg('Doctor location not set. Contact admin.', Colors.orange);
        return;
      }

      final distance = Geolocator.distanceBetween(pos.latitude, pos.longitude, docLat, docLng);

      if (distance > 200) {
        _showMsg('You are ${distance.toInt()} m away. Must be within 200 m.', Colors.red);
        return;
      }

      final uid = auth.currentUser!.uid;
      final today = _dateKey(DateTime.now());
      final existing = await db
          .collection('visits')
          .where('mrId', isEqualTo: uid)
          .where('doctorId', isEqualTo: widget.docId)
          .where('date', isEqualTo: today)
          .get();

      if (existing.docs.isNotEmpty) {
        _showMsg('Already checked in with this doctor today.', Colors.orange);
        return;
      }

      // Store active check-in session
      _activeCheckInDoctorId = widget.docId;
      _activeCheckInDoctorName = widget.data['name'];
      _activeCheckInTime = DateTime.now();

      await db.collection('visits').add({
        'mrId': uid,
        'doctorId': widget.docId,
        'doctorName': widget.data['name'],
        'date': today,
        'timestamp': FieldValue.serverTimestamp(),
        'mrLat': pos.latitude,
        'mrLng': pos.longitude,
        'distanceMeters': distance.toInt(),
      });

      await db.collection('attendance').doc('${uid}_$today').set({
        'mrId': uid,
        'date': today,
        'status': 'present',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(children: [
              Icon(Icons.check_circle, color: Colors.green),
              SizedBox(width: 8),
              Text('Check-In Successful'),
            ]),
            content: Text('Checked in with ${widget.data['name']}.\n${distance.toInt()} m away.'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(
                    builder: (_) => MrPlaceOrderScreen(
                      preselectedDoctorId: widget.docId,
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
    final div       = widget.data['division'] ?? 'General';
    final color     = _divColor(div);
    final tier      = widget.data['tier'] ?? 'Normal';
    final tierColor = _tierColor(tier);

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
              Row(
                children: [
                  Flexible(
                    child: Text(widget.data['name'] ?? '',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  ),
                  if (tier != 'Normal') ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: tierColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: tierColor.withOpacity(0.4)),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(_tierIcon(tier), size: 10, color: tierColor),
                        const SizedBox(width: 3),
                        Text(tier,
                            style: TextStyle(color: tierColor, fontSize: 9,
                                fontWeight: FontWeight.bold)),
                      ]),
                    ),
                  ],
                ],
              ),
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
                    style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
              ),
            ]),
          ),
          _checking
              ? const SizedBox(width: 36, height: 36, child: CircularProgressIndicator(strokeWidth: 2))
              : ElevatedButton(
            onPressed: _checkIn,
            style: ElevatedButton.styleFrom(minimumSize: const Size(72, 36), padding: const EdgeInsets.symmetric(horizontal: 12)),
            child: const Text('Check In', style: TextStyle(fontSize: 12)),
          ),
        ]),
      ),
    );
  }
}
// ─────────────────────────────────────────
// MR PRODUCTS SCREEN
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

  List<Map<String, dynamic>> _stockists = [];
  String? _selectedStockistUid;
  String? _selectedStockistName;
  Map<String, int> _stockistStockData = {};
  bool _loadingStockists = true;
  bool _loadingStock = false;

  @override
  void initState() {
    super.initState();
    _loadStockists();
  }

  Future<void> _loadStockists() async {
    try {
      final snap = await db.collection('stockists')
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
            };
          }).toList();
          _loadingStockists = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loadingStockists = false);
    }
  }

  Future<void> _loadStockistStock(String uid) async {
    setState(() => _loadingStock = true);
    try {
      final doc = await db.collection('stockist_stock').doc(uid).get();
      if (mounted) {
        setState(() {
          _stockistStockData = doc.exists
              ? (doc.data() as Map<String, dynamic>)
              .map((k, v) => MapEntry(k, (v as num?)?.toInt() ?? 0))
              : {};
          _loadingStock = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loadingStock = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Products & Stock')),
      body: Column(children: [
        if (_loadingStockists)
          const LinearProgressIndicator()
        else
          Container(
            margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                hint: const Text('Select Stockist to view stock'),
                value: _selectedStockistUid,
                items: _stockists.map((s) => DropdownMenuItem<String>(
                  value: s['uid'] as String,
                  child: Text(s['name'] as String),
                )).toList(),
                onChanged: (val) {
                  if (val == null) return;
                  final s = _stockists.firstWhere((x) => x['uid'] == val);
                  setState(() {
                    _selectedStockistUid = val;
                    _selectedStockistName = s['name'] as String;
                  });
                  _loadStockistStock(val);
                },
              ),
            ),
          ),
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
                          const Icon(Icons.error_outline, size: 48, color: Colors.red),
                          const SizedBox(height: 12),
                          const Text('Could not load products.',
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
                        Icon(Icons.inventory_2_outlined,
                            size: 80, color: Colors.grey.shade300),
                        const SizedBox(height: 16),
                        Text('No products available',
                            style: TextStyle(
                                color: Colors.grey.shade500, fontSize: 16)),
                      ]),
                );
              }

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
              if (_loadingStock) {
                return const Center(child: CircularProgressIndicator());
              }
              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: products.length,
                itemBuilder: (context, index) {
                  final data      = products[index].data() as Map<String, dynamic>;
                  final stock = _selectedStockistUid != null
                      ? (_stockistStockData[products[index].id] ?? 0)
                      : (data['stock'] as num?)?.toInt() ?? 0;
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
// MR PLACE ORDER SCREEN (FIXED - Stockist aware)
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
  // ── Doctor selection ──
  String? _selectedDoctorId;
  String? _selectedDoctorName;

  // ── Stockist selection ──
  String? _selectedStockistId;
  String? _selectedStockistName;
  List<Map<String, dynamic>> _stockists = [];
  bool _loadingStockists = true;

  // ── Products / quantities ──
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
    final hasValidCheckIn = _validateCheckInSession();

    if (!hasValidCheckIn && widget.preselectedDoctorId == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showOrderBlockedDialog();
      });
    }

    _selectedDoctorId = widget.preselectedDoctorId;
    _selectedDoctorName = widget.preselectedDoctorName;
    _loadStockists();  // Load stockists first
    _loadData();
  }

  // ── Load all stockists from stockists collection ──
  Future<void> _loadStockists() async {
    try {
      // Query from stockists collection (not users)
      final snap = await db
          .collection('stockists')
          .where('isActive', isEqualTo: true)
          .orderBy('name')
          .get();

      if (mounted) {
        setState(() {
          _stockists = snap.docs.map((d) {
            final data = d.data() as Map<String, dynamic>;
            return {
              'id': d.id,
              'uid': data['uid'] ?? '',  // Store the actual UID for stock lookup
              'name': data['name'] ?? 'Unknown',
              'city': data['city'] ?? '',
            };
          }).toList();
          _loadingStockists = false;
        });
      }
    } catch (e) {
      print('Error loading stockists: $e');
      if (mounted) setState(() => _loadingStockists = false);
    }
  }

  // ── When a stockist is selected, load products with their stock levels ──
  Future<void> _loadProductsForStockist(String stockistUid) async {
    setState(() {
      _loadingProducts = true;
      _products = [];
      _quantities.clear();
      _productCache.clear();
    });

    try {
      // Get all products
      final productsSnap = await db.collection('products').orderBy('name').get();

      // Fetch this stockist's stock levels from stockist_stock collection
      final stockDoc = await db
          .collection('stockist_stock')
          .doc(stockistUid)
          .get();
      final stockData = stockDoc.exists
          ? (stockDoc.data() as Map<String, dynamic>)
          : <String, dynamic>{};

      if (mounted) {
        setState(() {
          _products = productsSnap.docs;
          // Embed stockist qty into cache for display
          for (final p in productsSnap.docs) {
            final data = p.data() as Map<String, dynamic>;
            final stockistQty = (stockData[p.id] as num?)?.toInt() ?? 0;
            _productCache[p.id] = {
              ...data,
              'stockistQty': stockistQty,
            };
          }
          _loadingProducts = false;
        });
      }
    } catch (e) {
      print('Error loading products: $e');
      if (mounted) setState(() => _loadingProducts = false);
    }
  }

  bool _validateCheckInSession() {
    if (_activeCheckInDoctorId != null && _activeCheckInTime != null) {
      final minutesSinceCheckIn = DateTime.now().difference(_activeCheckInTime!).inMinutes;
      if (minutesSinceCheckIn <= 30) {
        return true;
      } else {
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
            Text('You can only place orders after:', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 12),
            Text('✓ Checking in with a doctor'),
            Text('✓ Being within 200m of the doctor\'s clinic'),
            SizedBox(height: 12),
            Text('Please visit a doctor\'s clinic, check in, then place your order.',
                style: TextStyle(fontSize: 13, color: Colors.orange)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('Go Back'),
          ),
        ],
      ),
    );
  }

  Future<void> _loadData() async {
    final doctorsSnap = await db.collection('doctors').orderBy('name').get();
    setState(() {
      _doctors = doctorsSnap.docs.where((d) {
        final data = d.data() as Map<String, dynamic>;
        return data['isActive'] as bool? ?? true;
      }).toList();
      _loadingDoctors = false;
    });
  }

  @override
  void dispose() {
    _remarksCtrl.dispose();
    super.dispose();
  }

  String _dateKey(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  // Calculate order value and determine tier and commission
  (int orderValue, String tier, int commission) _calculateOrderDetails(Map<String, int> quantities) {
    int totalValue = 0;
    for (final entry in quantities.entries.where((e) => e.value > 0)) {
      final product = _productCache[entry.key];
      final price = num.tryParse(product?['price']?.toString() ?? '0')?.toInt() ?? 0;
      totalValue += price * entry.value;
    }

    String tier = 'Normal';
    int commission = 0;

    if (totalValue >= 15000 && totalValue <= 20000) {
      tier = 'Premium';
      commission = 1500;
    } else if (totalValue >= 10000 && totalValue < 15000) {
      tier = 'Super Core';
      commission = 1000;
    } else if (totalValue >= 5000 && totalValue < 10000) {
      tier = 'Core';
      commission = 500;
    }

    return (totalValue, tier, commission);
  }

  Future<void> _submitOrder() async {
    if (_selectedDoctorId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a doctor first.')));
      return;
    }
    if (_selectedStockistId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a stockist first.')));
      return;
    }

    final uid = auth.currentUser!.uid;
    final today = _dateKey(DateTime.now());

    // Verify doctor check-in
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

    final (orderValue, tier, commission) = _calculateOrderDetails(_quantities);

    setState(() => _submitting = true);
    try {
      final userDoc = await db.collection('users').doc(uid).get();
      final mrName = userDoc.data()?['name'] ?? '';

      // Find the stockist's auth UID for notifications
      final stockistData = _stockists.firstWhere(
            (s) => s['id'] == _selectedStockistId,
        orElse: () => <String, dynamic>{},
      );
      final stockistUid = stockistData['uid'] as String? ?? '';

      // Save order — status is 'pending', awaiting stockist approval.
      // NO stock deduction here - stockist will deduct on approval.
      final orderRef = await db.collection('orders').add({
        'mrId': uid,
        'mrName': mrName,
        'doctorId': _selectedDoctorId,
        'doctorName': _selectedDoctorName,
        'stockistId': _selectedStockistId,
        'stockistName': _selectedStockistName,
        'stockistUid': stockistUid,
        'items': orderItems,
        'remarks': _remarksCtrl.text.trim(),
        'status': 'pending',
        'date': today,
        'orderValue': orderValue,
        'tier': tier,
        'commission': commission,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Update doctor stats
      final doctorRef = db.collection('doctors').doc(_selectedDoctorId);
      final doctorDoc = await doctorRef.get();
      final currentTotal =
          (doctorDoc.data() as Map<String, dynamic>?)?['totalOrderValue'] ?? 0;
      await doctorRef.update({
        'totalOrderValue': currentTotal + orderValue,
        'tier': tier,
        'lastOrderDate': today,
      });

      // Commission stored but only paid when stockist approves
      if (commission > 0) {
        await db.collection('allowances').add({
          'mrId': uid,
          'mrName': mrName,
          'doctorId': _selectedDoctorId,
          'doctorName': _selectedDoctorName,
          'stockistId': _selectedStockistId,
          'stockistName': _selectedStockistName,
          'stockistUid': stockistUid,
          'orderId': orderRef.id,
          'orderValue': orderValue,
          'amount': commission,
          'tier': tier,
          'orderDate': today,
          'type': 'commission',
          'pending': true,   // becomes false when stockist approves
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      // Notify MR that order is pending approval
      await db.collection('notifications').add({
        'mrId': uid,
        'title': '🕐 Order Sent for Approval',
        'body': 'Order worth ₹$orderValue sent to $_selectedStockistName. Awaiting approval.',
        'type': 'order_pending',
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Also notify stockist about new order (use auth UID so stockist can see it)
      if (stockistUid.isNotEmpty) {
        await db.collection('notifications').add({
          'mrId': stockistUid,  // Use stockist's auth UID
          'title': '📦 New Order Received',
          'body': 'New order from $mrName for ₹$orderValue. Please review and approve.',
          'type': 'new_order',
          'orderId': orderRef.id,
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      _activeCheckInDoctorId = null;
      _activeCheckInDoctorName = null;
      _activeCheckInTime = null;

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Order sent to stockist for approval! ✓'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
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
    final (orderValue, tier, commission) = _calculateOrderDetails(_quantities);

    if (widget.preselectedDoctorId == null && _selectedDoctorId == null
        && !_validateCheckInSession()) {
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
                const Text('Cannot Place Order',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                const Text('Orders can only be placed after checking in with a doctor.',
                    textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: Colors.grey)),
                const SizedBox(height: 16),
                const Text('Please visit a doctor\'s clinic, check in, then place your order.',
                    textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: Colors.orange)),
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
                    style: const TextStyle(fontSize: 14)),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Info banner
          Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue, size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                      'Select a stockist first, then add products. The stockist will approve or reject the order based on their available stock.',
                      style: TextStyle(fontSize: 12, color: Colors.blue)),
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
                  // ── STEP 1: Stockist ──────────────────────────
                  Row(children: [
                    Container(
                      width: 26, height: 26,
                      decoration: const BoxDecoration(
                          color: Color(0xFF1565C0), shape: BoxShape.circle),
                      child: const Center(
                          child: Text('1',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13))),
                    ),
                    const SizedBox(width: 8),
                    const Text('Select Stockist',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15)),
                  ]),
                  const SizedBox(height: 10),
                  if (_loadingStockists)
                    const LinearProgressIndicator()
                  else if (_stockists.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(10)),
                      child: const Text('No stockists found. Contact admin.',
                          style: TextStyle(color: Colors.red)),
                    )
                  else
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButtonFormField<String>(
                          value: _selectedStockistId,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 12, vertical: 14),
                            prefixIcon: Icon(Icons.store),
                          ),
                          hint: const Text('Choose a stockist'),
                          items: _stockists.map((s) {
                            return DropdownMenuItem<String>(
                              value: s['id'] as String,
                              child: Text(
                                  '${s['name']}${s['city'] != '' ? ' (${s['city']})' : ''}',
                                  overflow: TextOverflow.ellipsis),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val == null) return;
                            final s = _stockists.firstWhere((x) => x['id'] == val);
                            setState(() {
                              _selectedStockistId = val;
                              _selectedStockistName = s['name'] as String;
                              _quantities.clear();
                              _products = [];
                              _loadingProducts = true;
                            });
                            // Pass the UID for stock lookup
                            _loadProductsForStockist(s['uid'] as String);
                          },
                        ),
                      ),
                    ),

                  // Show selected stockist chip
                  if (_selectedStockistName != null) ...[
                    const SizedBox(height: 8),
                    Wrap(children: [
                      Chip(
                        avatar: const Icon(Icons.store,
                            size: 16, color: Color(0xFF1565C0)),
                        label: Text(_selectedStockistName!,
                            style: const TextStyle(
                                color: Color(0xFF1565C0), fontSize: 12)),
                        backgroundColor:
                        const Color(0xFF1565C0).withOpacity(0.08),
                        side: const BorderSide(
                            color: Color(0xFF1565C0), width: 0.8),
                        padding: EdgeInsets.zero,
                      ),
                    ]),
                  ],
                  const SizedBox(height: 20),

                  // ── STEP 2: Doctor ────────────────────────────
                  Row(children: [
                    Container(
                      width: 26, height: 26,
                      decoration: const BoxDecoration(
                          color: Color(0xFF1565C0), shape: BoxShape.circle),
                      child: const Center(
                          child: Text('2',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13))),
                    ),
                    const SizedBox(width: 8),
                    const Text('Select Doctor',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15)),
                  ]),
                  const SizedBox(height: 10),
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
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 12, vertical: 14),
                            prefixIcon: Icon(Icons.person),
                          ),
                          hint: const Text('Choose a doctor'),
                          items: _doctors.map((d) {
                            final data = d.data() as Map<String, dynamic>;
                            return DropdownMenuItem<String>(
                              value: d.id,
                              child: Text(
                                  '${data['name']} (${data['division']})',
                                  overflow: TextOverflow.ellipsis),
                            );
                          }).toList(),
                          onChanged: widget.preselectedDoctorId == null
                              ? (val) {
                            if (val == null) return;
                            final doc = _doctors
                                .firstWhere((d) => d.id == val);
                            final data =
                            doc.data() as Map<String, dynamic>;
                            setState(() {
                              _selectedDoctorId = val;
                              _selectedDoctorName = data['name'];
                            });
                          }
                              : null,
                        ),
                      ),
                    ),
                  const SizedBox(height: 24),

                  // ── STEP 3: Products ──────────────────────────
                  Row(children: [
                    Container(
                      width: 26, height: 26,
                      decoration: const BoxDecoration(
                          color: Color(0xFF1565C0), shape: BoxShape.circle),
                      child: const Center(
                          child: Text('3',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13))),
                    ),
                    const SizedBox(width: 8),
                    const Text('Select Products',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15)),
                  ]),
                  const SizedBox(height: 4),
                  Text(
                    _selectedStockistId == null
                        ? 'Select a stockist above to see products'
                        : 'Stockist stock shown as info — you may order any qty',
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 10),

                  if (_selectedStockistId == null)
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: const Center(
                        child: Text('← Pick a stockist first',
                            style: TextStyle(color: Colors.grey)),
                      ),
                    )
                  else if (_loadingProducts)
                    const Center(
                        child: Padding(
                          padding: EdgeInsets.all(20),
                          child: CircularProgressIndicator(),
                        ))
                  else if (_products.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Center(
                          child: Text('No products found.',
                              style: TextStyle(color: Colors.orange)),
                        ),
                      )
                    else
                      Column(
                        children: _products.map((p) {
                          final data = _productCache[p.id] ??
                              (p.data() as Map<String, dynamic>);
                          final qty = _quantities[p.id] ?? 0;
                          final stockistQty =
                              (data['stockistQty'] as num?)?.toInt() ?? 0;

                          Color stockColor;
                          String stockLabel;
                          if (stockistQty == 0) {
                            stockColor = Colors.red;
                            stockLabel = 'No stock';
                          } else if (stockistQty < 10) {
                            stockColor = Colors.orange;
                            stockLabel = '$stockistQty units';
                          } else {
                            stockColor = Colors.green;
                            stockLabel = '$stockistQty units';
                          }

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
                                      crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                      children: [
                                        Text(data['name'] ?? '',
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold)),
                                        const SizedBox(height: 2),
                                        Text(
                                            '₹${data['price'] ?? 'N/A'} • ${data['packSize'] ?? ''}',
                                            style: TextStyle(
                                                color: Colors.grey.shade600,
                                                fontSize: 12)),
                                        const SizedBox(height: 4),
                                        // Stockist stock badge (info only)
                                        Row(children: [
                                          const Icon(Icons.store,
                                              size: 12, color: Colors.grey),
                                          const SizedBox(width: 4),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: stockColor.withOpacity(0.1),
                                              borderRadius:
                                              BorderRadius.circular(8),
                                              border: Border.all(
                                                  color: stockColor
                                                      .withOpacity(0.4)),
                                            ),
                                            child: Text(
                                              'Stockist: $stockLabel',
                                              style: TextStyle(
                                                  fontSize: 10,
                                                  color: stockColor,
                                                  fontWeight: FontWeight.w600),
                                            ),
                                          ),
                                        ]),
                                      ],
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      IconButton(
                                        onPressed: qty > 0
                                            ? () => setState(() =>
                                        _quantities[p.id] = qty - 1)
                                            : null,
                                        icon: const Icon(
                                            Icons.remove_circle_outline),
                                        color: const Color(0xFF1565C0),
                                        iconSize: 22,
                                      ),
                                      SizedBox(
                                        width: 32,
                                        child: Text('$qty',
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold)),
                                      ),
                                      IconButton(
                                        onPressed: () => setState(
                                                () => _quantities[p.id] = qty + 1),
                                        icon: const Icon(
                                            Icons.add_circle_outline),
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
                  const Text('Remarks (optional)',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15)),
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

          // ── Bottom submit bar ─────────────────────────────────
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
              child: Column(
                children: [
                  if (orderValue > 0) ...[
                    Container(
                      padding: const EdgeInsets.all(8),
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: tier != 'Normal'
                            ? Colors.purple.shade50
                            : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Order Value: ₹$orderValue',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600)),
                          if (tier != 'Normal')
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.purple.shade100,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text('$tier Tier +₹$commission',
                                  style: TextStyle(
                                      color: Colors.purple.shade700,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold)),
                            ),
                        ],
                      ),
                    ),
                  ],
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                            '$totalItems item(s) selected',
                            style: const TextStyle(
                                fontWeight: FontWeight.w600)),
                      ),
                      ElevatedButton(
                        onPressed: _submitting ? null : _submitOrder,
                        style: ElevatedButton.styleFrom(
                            minimumSize: const Size(140, 40)),
                        child: _submitting
                            ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                            : const Text('Send for Approval'),
                      ),
                    ],
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
// MR ORDERS SCREEN
// ─────────────────────────────────────────
class MrOrdersScreen extends StatelessWidget {
  const MrOrdersScreen({super.key});

  Color _statusColor(String status) {
    switch (status) {
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
        stream: db.collection('orders').where('mrId', isEqualTo: uid).snapshots(),
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
              final tier = data['tier'] ?? 'Normal';
              final stockistName = data['stockistName'] ?? '';
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: color.withOpacity(0.15),
                    child: Icon(Icons.receipt_long, color: color),
                  ),
                  title: Text('Order for ${data['doctorName'] ?? 'Unknown Doctor'}',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('$items item(s) • ${data['date'] ?? ''}'),
                      if (stockistName.isNotEmpty)
                        Text('Stockist: $stockistName',
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                      if (tier != 'Normal')
                        Text('Tier: $tier • Commission: +₹${data['commission'] ?? 0}',
                            style: TextStyle(color: Colors.purple.shade700, fontSize: 12)),
                      if (status == 'rejected')
                        Text('⚠ Rejected by stockist',
                            style: TextStyle(color: Colors.red.shade700, fontSize: 12)),
                    ],
                  ),
                  isThreeLine: true,
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(status.toUpperCase(),
                        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => MrOrderDetailScreen(orderId: doc.id, data: data))),
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
// MR ORDER DETAIL SCREEN
// ─────────────────────────────────────────
class MrOrderDetailScreen extends StatelessWidget {
  final String               orderId;
  final Map<String, dynamic> data;
  const MrOrderDetailScreen({super.key, required this.orderId, required this.data});

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
                  style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold)),
              Text(data['date'] ?? '', style: TextStyle(color: Colors.grey.shade600)),
              if (status == 'rejected') ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    data['rejectionReason'] != null && data['rejectionReason'].toString().isNotEmpty
                        ? 'Reason: ${data['rejectionReason']}'
                        : 'Order was rejected by the stockist',
                    style: TextStyle(color: Colors.red.shade700, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ]),
          ),
          const SizedBox(height: 16),
          _detail('Doctor', data['doctorName'] ?? 'N/A'),
          if (data['stockistName'] != null)
            _detail('Stockist', data['stockistName']),
          _detail('Date', data['date'] ?? 'N/A'),
          if (data['orderValue'] != null)
            _detail('Order Value', '₹${data['orderValue']}'),
          if (data['tier'] != null && data['tier'] != 'Normal')
            _detail('Tier', data['tier']),
          if (data['commission'] != null && data['commission'] > 0)
            _detail('Commission', status == 'approved' ? '+₹${data['commission']} ✓' : '₹${data['commission']} (pending approval)'),
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
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            child: ListTile(
              leading: const Icon(Icons.medication, color: Color(0xFF1565C0)),
              title: Text(item['productName'] ?? ''),
              subtitle: Text('₹${item['price'] ?? 'N/A'}'),
              trailing: Text('Qty: ${item['quantity']}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ),
          )),
        ]),
      ),
    );
  }

  Widget _detail(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(width: 100,
          child: Text(label, style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.w500))),
      Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600))),
    ]),
  );
}
// ─────────────────────────────────────────
// MR REPORTS SCREEN
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
// SUBMIT DAILY REPORT
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
      final userDoc = await db.collection('users').doc(uid).get();
      final mrName = userDoc.data()?['name'] ?? 'Unknown MR';

      await db.collection('daily_reports').add({
        'mrId': uid,
        'mrName': mrName,
        'date': today,
        'doctorsVisited': _visitedDoctorNames,
        'notes': _notesCtrl.text.trim(),
        'followUp': _followUpCtrl.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      });
      await db.collection('attendance').doc('${uid}_$today').set({
        'mrId': uid,
        'date': today,
        'status': 'present',
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
// REPORT DETAIL
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
// APPLY LEAVE
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
// LEAVE HISTORY
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
// MR ALLOWANCE SCREEN (with detailed history)
// ─────────────────────────────────────────
class MrAllowanceScreen extends StatelessWidget {
  const MrAllowanceScreen({super.key});

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
    final uid = auth.currentUser?.uid ?? '';
    return Scaffold(
      appBar: AppBar(title: const Text('My Allowance & Commission')),
      body: FutureBuilder<DocumentSnapshot>(
        future: db.collection('users').doc(uid).get(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final userData    = snap.data?.data() as Map<String, dynamic>? ?? {};
          final fixedAllowance = (userData['fixedAllowance'] as num?)?.toDouble() ?? 0;

          return StreamBuilder<QuerySnapshot>(
            stream: db
                .collection('allowances')
                .where('mrId', isEqualTo: uid)
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final docs = snapshot.data?.docs ?? [];

              double totalCommission = 0;
              for (final doc in docs) {
                totalCommission += (doc.data() as Map)['amount'] as num? ?? 0;
              }

              // Group by month for summary
              final Map<String, double> monthTotals = {};
              for (final doc in docs) {
                final d    = doc.data() as Map<String, dynamic>;
                final date = (d['orderDate'] ?? '').toString();
                if (date.length >= 7) {
                  final month = date.substring(0, 7); // "2025-04"
                  monthTotals[month] = (monthTotals[month] ?? 0) +
                      ((d['amount'] as num?)?.toDouble() ?? 0);
                }
              }

              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

                  // ── Summary card ──────────────────────────
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
                          style: TextStyle(color: Colors.white70, fontSize: 13)),
                      const SizedBox(height: 6),
                      Text('₹${fixedAllowance.toStringAsFixed(0)}',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 34,
                              fontWeight: FontWeight.bold)),
                      const Text('per month',
                          style: TextStyle(color: Colors.white70, fontSize: 12)),
                      const Divider(color: Colors.white30, height: 28),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _summaryPill('Total Bonus', '₹${totalCommission.toStringAsFixed(0)}', Colors.white),
                          _summaryPill('Orders', '${docs.length}', Colors.white),
                        ],
                      ),
                    ]),
                  ),
                  const SizedBox(height: 20),

                  // ── Tier legend ───────────────────────────
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Bonus Structure',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 8),
                      Row(children: [
                        _tierLegend('Core',       '₹5k–10k',  '+₹500',  Colors.teal),
                        const SizedBox(width: 8),
                        _tierLegend('Super Core', '₹10k–15k', '+₹1,000', Colors.orange),
                        const SizedBox(width: 8),
                        _tierLegend('Premium',    '₹15k–20k', '+₹1,500', Colors.purple),
                      ]),
                    ]),
                  ),
                  const SizedBox(height: 20),

                  // ── History header ────────────────────────
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    const Text('Commission History',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    if (docs.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.green.shade200),
                        ),
                        child: Text('${docs.length} record(s)',
                            style: TextStyle(color: Colors.green.shade700,
                                fontSize: 12, fontWeight: FontWeight.w600)),
                      ),
                  ]),
                  const SizedBox(height: 12),

                  // ── History list ──────────────────────────
                  if (docs.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        child: Column(children: [
                          Icon(Icons.account_balance_wallet_outlined,
                              size: 64, color: Colors.grey.shade300),
                          const SizedBox(height: 12),
                          Text('No commission records yet',
                              style: TextStyle(color: Colors.grey.shade500, fontSize: 15)),
                          const SizedBox(height: 6),
                          Text('Place orders worth ₹5,000+ to start earning bonuses',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
                        ]),
                      ),
                    )
                  else
                    ...docs.map((doc) {
                      final d         = doc.data() as Map<String, dynamic>;
                      final tier      = d['tier'] as String? ?? 'Normal';
                      final tColor    = _tierColor(tier);
                      final amount    = (d['amount'] as num?)?.toInt() ?? 0;
                      final orderVal  = (d['orderValue'] as num?)?.toInt() ?? 0;
                      final docName   = d['doctorName'] as String? ?? 'N/A';
                      final orderDate = d['orderDate'] as String? ?? '';

                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 1.5,
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(children: [
                            // Tier icon circle
                            Container(
                              width: 44, height: 44,
                              decoration: BoxDecoration(
                                color: tColor.withOpacity(0.12),
                                shape: BoxShape.circle,
                                border: Border.all(color: tColor.withOpacity(0.35)),
                              ),
                              child: Icon(_tierIcon(tier), color: tColor, size: 22),
                            ),
                            const SizedBox(width: 12),

                            // Middle info
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                // Date
                                Text(orderDate,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold, fontSize: 14)),
                                const SizedBox(height: 2),
                                // Doctor name
                                Text(docName,
                                    style: TextStyle(
                                        color: Colors.grey.shade700, fontSize: 13)),
                                const SizedBox(height: 4),
                                // Order value + tier badge
                                Row(children: [
                                  Text('Deal: ₹$orderVal',
                                      style: TextStyle(
                                          color: Colors.grey.shade600, fontSize: 12)),
                                  const SizedBox(width: 8),
                                  if (tier != 'Normal')
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 7, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: tColor.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: tColor.withOpacity(0.4)),
                                      ),
                                      child: Text(tier,
                                          style: TextStyle(
                                              color: tColor,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold)),
                                    ),
                                ]),
                              ]),
                            ),

                            // Bonus amount
                            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                              Text('+₹$amount',
                                  style: TextStyle(
                                      color: tColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18)),
                              Text('bonus', style: TextStyle(
                                  color: Colors.grey.shade500, fontSize: 11)),
                            ]),
                          ]),
                        ),
                      );
                    }),
                  const SizedBox(height: 20),
                ]),
              );
            },
          );
        },
      ),
    );
  }

  Widget _summaryPill(String label, String value, Color color) => Column(children: [
    Text(value, style: TextStyle(
        color: color, fontSize: 20, fontWeight: FontWeight.bold)),
    Text(label, style: TextStyle(color: color.withOpacity(0.75), fontSize: 12)),
  ]);

  Widget _tierLegend(String tier, String range, String bonus, Color color) =>
      Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Column(children: [
            Text(tier, style: TextStyle(
                color: color, fontWeight: FontWeight.bold, fontSize: 11)),
            Text(range, style: TextStyle(color: Colors.grey.shade600, fontSize: 9)),
            Text(bonus, style: TextStyle(
                color: color, fontWeight: FontWeight.w600, fontSize: 11)),
          ]),
        ),
      );
}

// ─────────────────────────────────────────
// ATTENDANCE SCREEN
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
    final end          = '$_selectedYear-${_padded(_selectedMonth)}-${_padded(daysInMonth)}';

    return Scaffold(
      appBar: AppBar(title: const Text('Attendance')),
      body: Column(children: [
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
// NOTIFICATIONS SCREEN
// ─────────────────────────────────────────
class MrNotificationsScreen extends StatelessWidget {
  const MrNotificationsScreen({super.key});

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
                case 'commission':
                  iconColor = Colors.green;
                  iconData  = Icons.attach_money;
                  break;
                case 'order_approved':
                  iconColor = Colors.blue;
                  iconData  = Icons.check_circle;
                  break;
                case 'order_cancelled':
                  iconColor = Colors.red;
                  iconData  = Icons.cancel;
                  break;
                case 'order_billed':
                  iconColor = Colors.purple;
                  iconData  = Icons.receipt;
                  break;
                case 'order_dispatched':
                  iconColor = Colors.teal;
                  iconData  = Icons.local_shipping;
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
                    width: 8, height: 8,
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
// MR PROFILE SCREEN
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
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final mr = snap.data?.data() as Map<String, dynamic>? ?? {};

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(children: [

              // ── Profile card ──────────────────────────
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
                    child: Icon(Icons.person, size: 44, color: Colors.white),
                  ),
                  const SizedBox(height: 12),
                  Text(mr['name'] ?? 'Medical Representative',
                      style: const TextStyle(
                          color: Colors.white, fontSize: 20,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(mr['email'] ?? '',
                      style: const TextStyle(color: Colors.white70, fontSize: 13)),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text('Medical Representative',
                        style: const TextStyle(color: Colors.white, fontSize: 12)),
                  ),
                ]),
              ),
              const SizedBox(height: 20),

              // ── Info tiles ────────────────────────────
              _infoTile(Icons.phone, 'Phone', mr['phone'] ?? 'Not set'),
              _infoTile(Icons.location_on, 'Area', mr['area'] ?? 'Not set'),
              _infoTile(Icons.category, 'Division', mr['division'] ?? 'Not set'),
              _infoTile(Icons.payments, 'Fixed Allowance',
                  '₹${(mr['fixedAllowance'] as num?)?.toInt() ?? 0} / month'),
              const SizedBox(height: 8),

              // ── Menu items ────────────────────────────
              _menuCard(context, Icons.account_balance_wallet,
                  'My Allowance & Commission', Colors.purple, () {
                    Navigator.push(context, MaterialPageRoute(
                        builder: (_) => const MrAllowanceScreen()));
                  }),
              _menuCard(context, Icons.calendar_today,
                  'Attendance', Colors.blue, () {
                    Navigator.push(context, MaterialPageRoute(
                        builder: (_) => const MrAttendanceScreen()));
                  }),
              _menuCard(context, Icons.event_busy,
                  'Leave History', Colors.orange, () {
                    Navigator.push(context, MaterialPageRoute(
                        builder: (_) => const MrLeaveHistoryScreen()));
                  }),
              const SizedBox(height: 16),

              // ── Logout ────────────────────────────────
              Card(
                child: ListTile(
                  leading: const Icon(Icons.logout, color: Colors.red),
                  title: const Text('Logout',
                      style: TextStyle(color: Colors.red,
                          fontWeight: FontWeight.w600)),
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

  Widget _infoTile(IconData icon, String label, String value) => Card(
    margin: const EdgeInsets.only(bottom: 8),
    child: ListTile(
      leading: Icon(icon, color: const Color(0xFF1565C0), size: 22),
      title: Text(label,
          style: const TextStyle(fontSize: 12, color: Colors.grey)),
      subtitle: Text(value,
          style: const TextStyle(
              fontWeight: FontWeight.w600, fontSize: 14, color: Colors.black87)),
    ),
  );

  Widget _menuCard(BuildContext context, IconData icon, String label,
      Color color, VoidCallback onTap) =>
      Card(
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
          trailing: const Icon(Icons.chevron_right, color: Colors.grey),
          onTap: onTap,
        ),
      );
}