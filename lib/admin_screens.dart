import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'auth.dart';

final FirebaseAuth _auth = FirebaseAuth.instance;
final FirebaseFirestore _db = FirebaseFirestore.instance;

// ─────────────────────────────────────────
// ADMIN MAIN SCREEN WITH BOTTOM NAVIGATION
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
    const AdminOrdersScreen(),
    const AdminMrManagementScreen(),
    const AdminStockScreen(),
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
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.shopping_bag),
            label: 'Orders',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.badge),
            label: 'MRs',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.inventory),
            label: 'Stock',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.manage_accounts),
            label: 'Manage',
          ),
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
                  Text('Welcome, Admin 👋',
                      style: TextStyle(color: Colors.white70, fontSize: 14)),
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

            // Live stats from Firestore
            StreamBuilder<QuerySnapshot>(
              stream: _db
                  .collection('users')
                  .where('role', isEqualTo: 'mr')
                  .snapshots(),
              builder: (context, mrSnapshot) {
                final mrCount =
                mrSnapshot.hasData ? mrSnapshot.data!.docs.length : 0;
                return StreamBuilder<QuerySnapshot>(
                  stream: _db
                      .collection('orders')
                      .where('status', isEqualTo: 'pending')
                      .snapshots(),
                  builder: (context, orderSnapshot) {
                    final pendingOrders = orderSnapshot.hasData
                        ? orderSnapshot.data!.docs.length
                        : 0;
                    return StreamBuilder<QuerySnapshot>(
                      stream: _db
                          .collection('leave_requests')
                          .where('status', isEqualTo: 'pending')
                          .snapshots(),
                      builder: (context, leaveSnapshot) {
                        final pendingLeaves = leaveSnapshot.hasData
                            ? leaveSnapshot.data!.docs.length
                            : 0;
                        return GridView.count(
                          crossAxisCount: 2,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 1.6,
                          children: [
                            _adminStatCard('Total MRs',
                                '$mrCount', Icons.badge, Colors.blue),
                            _adminStatCard(
                                'Pending Orders',
                                '$pendingOrders',
                                Icons.pending_actions,
                                Colors.orange),
                            _adminStatCard(
                                'Leave Requests',
                                '$pendingLeaves',
                                Icons.event_busy,
                                Colors.red),
                            _adminStatCard('Total Doctors', '0',
                                Icons.people, Colors.purple),
                          ],
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

  Widget _adminStatCard(
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
                  style:
                  const TextStyle(fontSize: 11, color: Colors.grey)),
            ],
          ),
        ],
      ),
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
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const AddMrScreen()),
              );
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddMrScreen()),
          );
        },
        icon: const Icon(Icons.person_add),
        label: const Text('Add MR'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _db
            .collection('users')
            .where('role', isEqualTo: 'mr')
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
                  Icon(Icons.badge_outlined,
                      size: 80, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  Text('No MRs added yet',
                      style: TextStyle(
                          color: Colors.grey.shade500, fontSize: 16)),
                  const SizedBox(height: 8),
                  Text('Tap + Add MR to create a new MR account',
                      style: TextStyle(
                          color: Colors.grey.shade400, fontSize: 13)),
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
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: isActive
                            ? Colors.blue.shade50
                            : Colors.grey.shade100,
                        child: Icon(Icons.person,
                            color: isActive
                                ? Colors.blue
                                : Colors.grey),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  mr['name'] ?? 'Unknown',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isActive
                                        ? Colors.green.shade50
                                        : Colors.red.shade50,
                                    borderRadius:
                                    BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    isActive ? 'Active' : 'Inactive',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: isActive
                                          ? Colors.green
                                          : Colors.red,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            Text(mr['email'] ?? '',
                                style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 13)),
                            Text(
                                '📱 ${mr['phone'] ?? 'N/A'}  📍 ${mr['area'] ?? 'N/A'}',
                                style: TextStyle(
                                    color: Colors.grey.shade500,
                                    fontSize: 12)),
                          ],
                        ),
                      ),
                      PopupMenuButton(
                        icon: const Icon(Icons.more_vert),
                        itemBuilder: (_) => [
                          PopupMenuItem(
                            value: 'toggle',
                            child: Text(isActive
                                ? 'Deactivate'
                                : 'Activate'),
                          ),
                          const PopupMenuItem(
                            value: 'view',
                            child: Text('View Details'),
                          ),
                        ],
                        onSelected: (value) async {
                          if (value == 'toggle') {
                            await _db
                                .collection('users')
                                .doc(docId)
                                .update({'isActive': !isActive});
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(isActive
                                    ? 'MR deactivated'
                                    : 'MR activated'),
                                backgroundColor: isActive
                                    ? Colors.red
                                    : Colors.green,
                              ),
                            );
                          } else if (value == 'view') {
                            _showMrDetails(context, mr);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showMrDetails(BuildContext context, Map<String, dynamic> mr) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: CircleAvatar(
                radius: 35,
                backgroundColor: Colors.blue.shade50,
                child: const Icon(Icons.person,
                    size: 40, color: Colors.blue),
              ),
            ),
            const SizedBox(height: 16),
            _detailRow(Icons.person, 'Name', mr['name'] ?? 'N/A'),
            _detailRow(Icons.email, 'Email', mr['email'] ?? 'N/A'),
            _detailRow(Icons.phone, 'Phone', mr['phone'] ?? 'N/A'),
            _detailRow(Icons.location_on, 'Area', mr['area'] ?? 'N/A'),
            _detailRow(Icons.work, 'Division',
                mr['division'] ?? 'N/A'),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFF1565C0)),
          const SizedBox(width: 10),
          Text('$label: ',
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 14)),
          Expanded(
              child: Text(value,
                  style: const TextStyle(fontSize: 14))),
        ],
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

    // Validation
    if (name.isEmpty ||
        email.isEmpty ||
        phone.isEmpty ||
        area.isEmpty ||
        password.isEmpty) {
      setState(() => _errorMessage = 'Please fill in all fields.');
      return;
    }

    if (password.length < 6) {
      setState(
              () => _errorMessage = 'Password must be at least 6 characters.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      // Save current admin user
      final currentAdmin = _auth.currentUser!;

      // Create MR account in Firebase Auth
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final newUid = userCredential.user!.uid;

      // Save MR details in Firestore
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

      // Sign back in as admin
      // Note: Creating a user signs you in as them automatically
      // We need to sign back in as admin
      await _auth.signOut();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ MR account created successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }

      // Re-login admin - this will trigger AuthWrapper to redirect
    } on FirebaseAuthException catch (e) {
      setState(() {
        _isLoading = false;
        switch (e.code) {
          case 'email-already-in-use':
            _errorMessage = 'This email is already registered.';
            break;
          case 'invalid-email':
            _errorMessage = 'Please enter a valid email address.';
            break;
          case 'weak-password':
            _errorMessage = 'Password is too weak.';
            break;
          default:
            _errorMessage = 'Failed to create account: ${e.message}';
        }
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
            // Header info
            Container(
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
                      'Creating an MR account will allow them to login to the app immediately.',
                      style: TextStyle(fontSize: 12, color: Colors.blue),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Name
            const Text('Full Name',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                hintText: 'Enter MR full name',
                prefixIcon: Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: 14),

            // Email
            const Text('Email Address',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                hintText: 'Enter email address',
                prefixIcon: Icon(Icons.email_outlined),
              ),
            ),
            const SizedBox(height: 14),

            // Phone
            const Text('Phone Number',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                hintText: 'Enter phone number',
                prefixIcon: Icon(Icons.phone_outlined),
              ),
            ),
            const SizedBox(height: 14),

            // Area
            const Text('Area / Territory',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            TextField(
              controller: _areaController,
              decoration: const InputDecoration(
                hintText: 'e.g. Nellore North, Nellore South',
                prefixIcon: Icon(Icons.location_on_outlined),
              ),
            ),
            const SizedBox(height: 14),

            // Division
            const Text('Division',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
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
            const SizedBox(height: 14),

            // Password
            const Text('Login Password',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            TextField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              decoration: InputDecoration(
                hintText: 'Set a password for MR login',
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

            // Submit button
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton.icon(
              onPressed: _createMr,
              icon: const Icon(Icons.person_add),
              label: const Text(
                'Create MR Account',
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
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
              style:
              TextStyle(color: Colors.grey.shade500, fontSize: 16)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────
// ADMIN STOCK SCREEN
// ─────────────────────────────────────────
class AdminStockScreen extends StatelessWidget {
  const AdminStockScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Stock Management')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {},
        icon: const Icon(Icons.add),
        label: const Text('Add Product'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined,
                size: 80, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text('No products added yet',
                style:
                TextStyle(color: Colors.grey.shade500, fontSize: 16)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────
// ADMIN PROFILE / MANAGE SCREEN
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
                  colors: [Color(0xFF1565C0), Color(0xFF1E88E5)],
                ),
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
                      style:
                      TextStyle(color: Colors.white70, fontSize: 13)),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _sectionTitle('Field Management'),
            _menuItem(Icons.badge, 'MR Management', Colors.blue, () {
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) =>
                      const AdminMrManagementScreen()));
            }),
            _menuItem(Icons.people, 'Doctor Management', Colors.green,
                    () {}),
            const SizedBox(height: 10),
            _sectionTitle('HR Management'),
            _menuItem(Icons.calendar_today, 'Attendance Records',
                Colors.orange, () {}),
            _menuItem(Icons.event_busy, 'Leave Approvals', Colors.red,
                    () {}),
            _menuItem(Icons.account_balance_wallet,
                'Allowance Management', Colors.purple, () {}),
            const SizedBox(height: 10),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Logout',
                  style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.w600)),
              onTap: () async {
                await _auth.signOut();
                if (context.mounted) {
                  Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const LoginScreen()));
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(title,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
                letterSpacing: 0.5)),
      ),
    );
  }

  Widget _menuItem(
      IconData icon, String label, Color color, VoidCallback onTap) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
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