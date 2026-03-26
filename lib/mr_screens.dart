import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'auth.dart';
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
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people),
            label: 'Doctors',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.medication),
            label: 'Products',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.shopping_cart),
            label: 'Orders',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────
// MR DASHBOARD
// ─────────────────────────────────────────
class MrDashboardScreen extends StatelessWidget {
  const MrDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MR Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1565C0), Color(0xFF1E88E5)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Good Morning! 👋',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Medical Representative',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Today: Monday, 25 March 2026',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Stats row
            const Text(
              'Today\'s Summary',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _statCard('Doctors\nVisited', '0', Icons.people, Colors.blue),
                const SizedBox(width: 12),
                _statCard('Orders\nPlaced', '0', Icons.shopping_cart, Colors.green),
                const SizedBox(width: 12),
                _statCard('Reports\nDone', '0', Icons.assignment, Colors.orange),
              ],
            ),
            const SizedBox(height: 20),

            // Quick actions
            const Text(
              'Quick Actions',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.5,
              children: [
                _quickAction(context, 'Visit Doctor', Icons.add_location, Colors.blue, () {}),
                _quickAction(context, 'Place Order', Icons.add_shopping_cart, Colors.green, () {}),
                _quickAction(context, 'Daily Report', Icons.edit_note, Colors.orange, () {}),
                _quickAction(context, 'Apply Leave', Icons.event_busy, Colors.red, () {}),
              ],
            ),
            const SizedBox(height: 20),

            // Attendance this month
            const Text(
              'This Month',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _monthStat('Present', '0', Colors.green),
                  _monthStat('Absent', '0', Colors.red),
                  _monthStat('Leave', '0', Colors.orange),
                  _monthStat('Working\nDays', '25', Colors.blue),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _quickAction(BuildContext context, String label, IconData icon,
      Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _monthStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 11, color: Colors.grey),
        ),
      ],
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
  String _searchQuery = '';
  final List<String> _divisions = ['All', 'Ortho', 'Gynec', 'General'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Products & Stock')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              onChanged: (val) =>
                  setState(() => _searchQuery = val.toLowerCase()),
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
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
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
                        Text('No products available',
                            style: TextStyle(
                                color: Colors.grey.shade500,
                                fontSize: 16)),
                      ],
                    ),
                  );
                }
                var products = snapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final name =
                  (data['name'] ?? '').toString().toLowerCase();
                  final division = (data['division'] ?? '').toString();
                  final matchesSearch = _searchQuery.isEmpty ||
                      name.contains(_searchQuery);
                  final matchesDivision = _filterDivision == 'All' ||
                      division == _filterDivision;
                  return matchesSearch && matchesDivision;
                }).toList();

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: products.length,
                  itemBuilder: (context, index) {
                    final data =
                    products[index].data() as Map<String, dynamic>;
                    final stock = data['stock'] ?? 0;
                    final minStock = data['minStock'] ?? 10;
                    final isOutOfStock = stock == 0;
                    final isLowStock = stock > 0 && stock <= minStock;
                    final division = data['division'] ?? 'General';

                    Color color;
                    switch (division) {
                      case 'Ortho':
                        color = Colors.blue;
                        break;
                      case 'Gynec':
                        color = Colors.pink;
                        break;
                      default:
                        color = Colors.green;
                    }

                    Color stockColor = Colors.green;
                    String stockLabel = 'Available';
                    if (isOutOfStock) {
                      stockColor = Colors.red;
                      stockLabel = 'Out of Stock';
                    } else if (isLowStock) {
                      stockColor = Colors.orange;
                      stockLabel = 'Low Stock';
                    }

                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        leading: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.medication, color: color),
                        ),
                        title: Text(data['name'] ?? 'Unknown',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold)),
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
                                      fontSize: 10,
                                      color: stockColor,
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
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────
// MR DOCTORS SCREEN
// ─────────────────────────────────────────
class MrDoctorsScreen extends StatelessWidget {
  const MrDoctorsScreen({super.key});

  // Temporary doctor data - will come from Firebase later
  static const List<Map<String, String>> _doctors = [
    {
      'name': 'Dr. Ramesh Kumar',
      'specialization': 'Orthopedic',
      'hospital': 'City Hospital',
      'area': 'Nellore Main',
      'division': 'Ortho',
    },
    {
      'name': 'Dr. Priya Sharma',
      'specialization': 'Gynecologist',
      'hospital': 'Apollo Clinic',
      'area': 'Nellore North',
      'division': 'Gynec',
    },
    {
      'name': 'Dr. Suresh Babu',
      'specialization': 'General Physician',
      'hospital': 'Suresh Hospital',
      'area': 'Nellore South',
      'division': 'General',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Doctor List'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          // Info banner
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(12),
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
                    'You must be near the doctor\'s location to check in.',
                    style: TextStyle(fontSize: 12, color: Colors.blue),
                  ),
                ),
              ],
            ),
          ),

          // Doctor list
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: _doctors.length,
              itemBuilder: (context, index) {
                final doctor = _doctors[index];
                return _DoctorCard(doctor: doctor);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _DoctorCard extends StatelessWidget {
  final Map<String, String> doctor;
  const _DoctorCard({required this.doctor});

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
    final color = _divisionColor(doctor['division']!);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
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
                    doctor['name']!,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  Text(
                    doctor['specialization']!,
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  ),
                  Text(
                    doctor['hospital']!,
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      doctor['division']!,
                      style: TextStyle(
                          color: color,
                          fontSize: 11,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Location verification coming soon!'),
                    backgroundColor: Colors.orange,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(70, 36),
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              child: const Text('Check In', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────
// MR ORDERS SCREEN
// ─────────────────────────────────────────
class MrOrdersScreen extends StatelessWidget {
  const MrOrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Orders')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {},
        icon: const Icon(Icons.add),
        label: const Text('New Order'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.shopping_cart_outlined,
                size: 80, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              'No orders yet',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap + New Order to place your first order',
              style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────
// MR REPORTS SCREEN
// ─────────────────────────────────────────
class MrReportsScreen extends StatelessWidget {
  const MrReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Daily Reports')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {},
        icon: const Icon(Icons.add),
        label: const Text('Submit Report'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.assignment_outlined,
                size: 80, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              'No reports submitted yet',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              'Submit your daily report every evening',
              style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
            ),
          ],
        ),
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
    return Scaffold(
      appBar: AppBar(title: const Text('My Profile')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Profile header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1565C0), Color(0xFF1E88E5)],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Column(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: Colors.white,
                    child: Icon(Icons.person,
                        size: 50, color: Color(0xFF1565C0)),
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Medical Representative',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'mr@arka.com',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Menu items
            _profileMenuItem(Icons.calendar_today, 'Attendance', () {}),
            _profileMenuItem(Icons.event_busy, 'Leave History', () {}),
            _profileMenuItem(Icons.account_balance_wallet, 'My Allowance', () {}),
            _profileMenuItem(Icons.history, 'Order History', () {}),
            _profileMenuItem(Icons.lock_outline, 'Change Password', () {}),
            const SizedBox(height: 10),
            // Logout
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text(
                'Logout',
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
              ),
              onTap: () async {
                isLoggingOut = true;
                await auth.signOut();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _profileMenuItem(IconData icon, String label, VoidCallback onTap) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFF1565C0)),
        title: Text(label),
        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
        onTap: onTap,
      ),
    );
  }
}