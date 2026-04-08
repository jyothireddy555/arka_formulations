import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'mr_screens.dart';
import 'admin_screens.dart';
import 'stockist_screens.dart';
import 'notification_service.dart';

final FirebaseAuth auth = FirebaseAuth.instance;
final FirebaseFirestore db = FirebaseFirestore.instance;

// ─────────────────────────────────────────
// AUTH WRAPPER — listens to login state
// Uses idTokenChanges() and caches last known
// user so token refreshes don't cause a flash
// ─────────────────────────────────────────
// Global flag — set true before signing out
bool isLoggingOut = false;

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  User? _lastKnownUser;
  bool _initialised = false;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: auth.idTokenChanges(),
      builder: (context, snapshot) {
        if (!_initialised &&
            snapshot.connectionState == ConnectionState.waiting) {
          return const _LoadingScreen(message: 'Connecting...');
        }

        if (snapshot.connectionState != ConnectionState.waiting) {
          _initialised = true;
        }

        if (snapshot.hasData && snapshot.data != null) {
          isLoggingOut = false;
          _lastKnownUser = snapshot.data;
        }

        // Only show "Refreshing" if it's a token refresh, NOT a real logout
        if (snapshot.data == null && _lastKnownUser != null && !isLoggingOut) {
          return const _LoadingScreen(message: 'Refreshing session...');
        }

        if (_lastKnownUser != null && !isLoggingOut) {
          return const RoleRedirector();
        }

        _lastKnownUser = null;
        return const LoginScreen();
      },
    );
  }
}
// ─────────────────────────────────────────
// ROLE REDIRECTOR
// ─────────────────────────────────────────
class RoleRedirector extends StatefulWidget {
  const RoleRedirector({super.key});

  @override
  State<RoleRedirector> createState() => _RoleRedirectorState();
}

class _RoleRedirectorState extends State<RoleRedirector> {
  // FIX: Track whether onUserLogin() has already been called this session.
  // Without this, auto-login (app restart) never calls onUserLogin(),
  // so the FCM token is never saved and Firestore listeners never start —
  // meaning ALL notifications silently fail for auto-logged-in users.
  bool _notificationInitDone = false;

  void _ensureNotificationsInitialised() {
    if (_notificationInitDone) return;
    _notificationInitDone = true;
    // Run after build so context is ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationService.instance.onUserLogin();
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: db
          .collection('users')
          .doc(auth.currentUser!.uid)
          .snapshots(), // ← real-time stream, stays alive
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _LoadingScreen(message: 'Loading profile...');
        }

        // Only sign out on definitive "document doesn't exist" — not on errors
        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>;
          final role = data['role'] ?? 'mr';
          final isActive = data['isActive'] ?? true;

          if (!isActive && role == 'mr') {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              auth.signOut();
            });
            return const _DeactivatedScreen();
          }

          // Ensure FCM token is saved & listeners started — works for both
          // fresh login and auto-login on app restart.
          _ensureNotificationsInitialised();

          if (role == 'admin') {
            return const AdminMainScreen();
          } else if (role == 'stockist') {
            return const StockistMainScreen();
          } else {
            return const MrMainScreen();
          }
        }

        // Transient error — don't sign out, just keep loading
        if (snapshot.hasError) {
          return const _LoadingScreen(message: 'Retrying...');
        }

        // Document truly doesn't exist — then sign out
        if (snapshot.hasData && !snapshot.data!.exists) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            auth.signOut();
          });
          return const LoginScreen();
        }

        return const _LoadingScreen(message: 'Loading profile...');
      },
    );
  }
}

// ─────────────────────────────────────────
// LOADING SCREEN
// ─────────────────────────────────────────
class _LoadingScreen extends StatelessWidget {
  final String message;
  const _LoadingScreen({required this.message});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1565C0),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.medical_services,
                size: 50,
                color: Color(0xFF1565C0),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Arka Formulations',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            const CircularProgressIndicator(color: Colors.white),
            const SizedBox(height: 16),
            Text(
              message,
              style: const TextStyle(color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────
// DEACTIVATED SCREEN
// ─────────────────────────────────────────
class _DeactivatedScreen extends StatelessWidget {
  const _DeactivatedScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1565C0),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.block, color: Colors.white, size: 80),
              const SizedBox(height: 24),
              const Text(
                'Account Deactivated',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Your account has been deactivated.\nPlease contact your administrator.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () => auth.signOut(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF1565C0),
                ),
                child: const Text('Back to Login'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────
// LOGIN SCREEN
// ─────────────────────────────────────────
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  String _errorMessage = '';

  Future<void> _login() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = 'Please enter email and password.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      await auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      // RoleRedirector._ensureNotificationsInitialised() handles onUserLogin()
      // for both fresh login and auto-login on app restart — do NOT call it here.
    } on FirebaseAuthException catch (e) {
      setState(() {
        _isLoading = false;
        switch (e.code) {
          case 'user-not-found':
          case 'wrong-password':
          case 'invalid-credential':
            _errorMessage = 'Invalid email or password.';
            break;
          case 'invalid-email':
            _errorMessage = 'Please enter a valid email address.';
            break;
          case 'user-disabled':
            _errorMessage = 'This account has been disabled.';
            break;
          case 'too-many-requests':
            _errorMessage =
            'Too many attempts. Please try again later.';
            break;
          default:
            _errorMessage = 'Login failed. Please try again.';
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
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1565C0),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    Icons.medical_services,
                    size: 60,
                    color: Color(0xFF1565C0),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Arka Formulations',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Field Force Management',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 40),

                // Login card
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Sign In',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1565C0),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Email
                      TextField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Email Address',
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Password
                      TextField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        onSubmitted: (_) => _login(),
                        decoration: InputDecoration(
                          labelText: 'Password',
                          prefixIcon:
                          const Icon(Icons.lock_outlined),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                            ),
                            onPressed: () => setState(() =>
                            _obscurePassword = !_obscurePassword),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Error message
                      if (_errorMessage.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.all(10),
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border:
                            Border.all(color: Colors.red.shade200),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline,
                                  color: Colors.red, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _errorMessage,
                                  style: const TextStyle(
                                      color: Colors.red,
                                      fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                        ),

                      // Login button
                      _isLoading
                          ? const Center(
                          child: CircularProgressIndicator())
                          : ElevatedButton(
                        onPressed: _login,
                        child: const Text(
                          'Login',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}