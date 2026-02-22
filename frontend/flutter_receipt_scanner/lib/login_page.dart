import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:local_auth/local_auth.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_receipt_scanner/app_state.dart';
import 'package:flutter_receipt_scanner/l10n.dart';
import 'package:flutter_receipt_scanner/main.dart';
import 'package:flutter_receipt_scanner/main_shell.dart';

class LoginPage extends StatefulWidget {
  final bool hasSavedCredentials;

  const LoginPage({Key? key, this.hasSavedCredentials = false})
      : super(key: key);

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String _errorMessage = '';
  bool _obscurePassword = true;
  bool _biometricAvailable = false;

  final String loginUrl = '${ApiConfig.baseUrl}/login';
  final LocalAuthentication _localAuth = LocalAuthentication();

  @override
  void initState() {
    super.initState();
    _checkBiometric();
  }

  Future<void> _checkBiometric() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool('biometricEnabled') ?? true;
    if (!enabled) return;

    // Check device capability
    bool canCheck = false;
    try {
      canCheck = await _localAuth.canCheckBiometrics ||
          await _localAuth.isDeviceSupported();
    } catch (_) {}

    if (!mounted) return;
    setState(() {
      _biometricAvailable = enabled && canCheck;
    });
  }

  static const Color _brandBlue = Color(0xFF1565C0);
  static const Color _brandLight = Color(0xFF1E88E5);

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ── Biometric login ──────────────────────────────────────────────
  Future<void> _biometricLogin() async {
    try {
      final bool canAuth = await _localAuth.canCheckBiometrics ||
          await _localAuth.isDeviceSupported();
      if (!canAuth) return;

      final didAuth = await _localAuth.authenticate(
        localizedReason: L.tr(context, 'biometric_reason'),
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );

      if (!didAuth || !mounted) return;

      // Validate stored token with the server
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null || token.isEmpty) {
        if (!mounted) return;
        setState(() {
          _errorMessage = L.tr(context, 'biometric_login_first');
        });
        return;
      }

      setState(() => _isLoading = true);

      final response = await http.get(
        Uri.parse(ApiConfig.validateTokenUrl),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      if (!mounted) return;

      if (response.statusCode == 200) {
        // Token is valid — update user data if needed
        final data = jsonDecode(response.body);
        if (data['user'] != null) {
          await prefs.setString('user', jsonEncode(data['user']));
        }

        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const MainShell()),
        );
      } else {
        // Token expired or invalid — clear it and ask for password
        await prefs.remove('token');
        await prefs.setBool('isLoggedIn', false);
        setState(() {
          _isLoading = false;
          _errorMessage = L.tr(context, 'session_expired');
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = L.tr(context, 'biometric_failed');
      });
    }
  }

  // ── Email / password login ───────────────────────────────────────
  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final response = await http
          .post(
            Uri.parse(loginUrl),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({
              'email': _emailController.text.trim(),
              'password': _passwordController.text,
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        try {
          final data = jsonDecode(response.body);

          if (data['token'] == null) {
            throw Exception('Token not found in response');
          }

          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('token', data['token']);
          await prefs.setString(
            'user',
            jsonEncode(data['user'] ??
                {
                  'name': 'User',
                  'email': _emailController.text.trim(),
                }),
          );
          await prefs.setBool('isLoggedIn', true);

          if (!mounted) return;

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  '${L.tr(context, 'login_success')} ${data['user']?['name'] ?? ''}'),
              backgroundColor: _brandBlue,
              duration: const Duration(seconds: 2),
            ),
          );

          Future.delayed(const Duration(seconds: 1), () {
            if (!mounted) return;
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const MainShell()),
            );
          });
        } catch (_) {
          setState(() {
            _errorMessage = L.tr(context, 'invalid_server_response');
          });
        }
      } else {
        try {
          final error = jsonDecode(response.body);
          setState(() {
            _errorMessage = error['message'] ??
                'Login failed with status ${response.statusCode}';
          });
        } catch (_) {
          setState(() {
            _errorMessage =
                'Login failed with status ${response.statusCode}';
          });
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = '${L.tr(context, 'network_error')}: $e';
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Build ────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isDark =
        Provider.of<AppState>(context).themeMode == ThemeMode.dark;
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [const Color(0xFF0D47A1), const Color(0xFF1A237E), const Color(0xFF121212)]
                : [const Color(0xFF1565C0), const Color(0xFF1976D2), const Color(0xFFE3F2FD)],
            stops: const [0.0, 0.3, 0.7],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              // ── Top toolbar: language + theme ────────────────────
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    _buildLanguageChip(context),
                    const SizedBox(width: 8),
                    _buildThemeToggle(context, isDark),
                  ],
                ),
              ),

              // ── Scrollable body ─────────────────────────────────
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(height: 8),

                        // Logo with elevated shadow
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.25),
                                blurRadius: 24,
                                spreadRadius: 2,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: CircleAvatar(
                            radius: 52,
                            backgroundColor: Colors.white,
                            child: ClipOval(
                              child: Image.asset(
                                'assets/icon/lemurulogo.png',
                                width: 78,
                                height: 78,
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Title
                        Text(
                          L.tr(context, 'login_title'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          L.tr(context, 'login_subtitle'),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                        ),
                        const SizedBox(height: 32),

                        // ── Form card ─────────────────────────────
                        Container(
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF1E1E1E)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.15),
                                blurRadius: 30,
                                spreadRadius: 0,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(22, 28, 22, 24),
                            child: Form(
                              key: _formKey,
                              child: Column(
                                children: [
                                  // Error message
                                  if (_errorMessage.isNotEmpty)
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(12),
                                      margin:
                                          const EdgeInsets.only(bottom: 18),
                                      decoration: BoxDecoration(
                                        color: Colors.red.shade50,
                                        borderRadius:
                                            BorderRadius.circular(10),
                                        border: Border.all(
                                            color: Colors.red.shade200),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(Icons.error_outline,
                                              size: 18,
                                              color: Colors.red.shade700),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              _errorMessage,
                                              style: TextStyle(
                                                  color: Colors.red.shade800,
                                                  fontSize: 13),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                  // Email field
                                  _buildTextField(
                                    controller: _emailController,
                                    label: L.tr(context, 'email_label'),
                                    hint: L.tr(context, 'email_hint'),
                                    icon: Icons.email_outlined,
                                    keyboardType: TextInputType.emailAddress,
                                    isDark: isDark,
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return L.tr(context, 'email_required');
                                      }
                                      if (!value.contains('@')) {
                                        return L.tr(context, 'email_invalid');
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 16),

                                  // Password field
                                  _buildTextField(
                                    controller: _passwordController,
                                    label: L.tr(context, 'password_label'),
                                    hint: L.tr(context, 'password_hint'),
                                    icon: Icons.lock_outline,
                                    obscure: _obscurePassword,
                                    isDark: isDark,
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _obscurePassword
                                            ? Icons.visibility_off_outlined
                                            : Icons.visibility_outlined,
                                        size: 20,
                                        color: Colors.grey.shade500,
                                      ),
                                      onPressed: () => setState(() =>
                                          _obscurePassword =
                                              !_obscurePassword),
                                    ),
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return L.tr(
                                            context, 'password_required');
                                      }
                                      if (value.length < 6) {
                                        return L.tr(
                                            context, 'password_too_short');
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 28),

                                  // Login button — gradient with shadow
                                  Container(
                                    width: double.infinity,
                                    height: 52,
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [
                                          Color(0xFF1565C0),
                                          Color(0xFF1E88E5),
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: _isLoading
                                          ? []
                                          : [
                                              BoxShadow(
                                                color: _brandBlue
                                                    .withValues(alpha: 0.4),
                                                blurRadius: 12,
                                                offset: const Offset(0, 4),
                                              ),
                                            ],
                                    ),
                                    child: Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        borderRadius:
                                            BorderRadius.circular(12),
                                        onTap: _isLoading ? null : _login,
                                        child: Center(
                                          child: _isLoading
                                              ? const SizedBox(
                                                  height: 22,
                                                  width: 22,
                                                  child:
                                                      CircularProgressIndicator(
                                                    strokeWidth: 2.5,
                                                    valueColor:
                                                        AlwaysStoppedAnimation<
                                                                Color>(
                                                            Colors.white),
                                                  ),
                                                )
                                              : Text(
                                                  L.tr(context,
                                                      'login_button'),
                                                  style: const TextStyle(
                                                    fontSize: 16,
                                                    fontWeight:
                                                        FontWeight.w700,
                                                    color: Colors.white,
                                                    letterSpacing: 0.5,
                                                  ),
                                                ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        // ── Biometric button ─────────────────────
                        if (_biometricAvailable) ...[
                          const SizedBox(height: 24),
                          Column(
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.1)
                                      : _brandBlue.withValues(alpha: 0.1),
                                  border: Border.all(
                                    color: isDark
                                        ? Colors.white.withValues(alpha: 0.3)
                                        : _brandBlue.withValues(alpha: 0.4),
                                    width: 2,
                                  ),
                                ),
                                child: IconButton(
                                  onPressed: _biometricLogin,
                                  icon: const Icon(Icons.fingerprint),
                                  iconSize: 44,
                                  color: isDark ? Colors.white : _brandBlue,
                                  padding: const EdgeInsets.all(14),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                L.tr(context, 'biometric_login'),
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: isDark
                                      ? Colors.white70
                                      : _brandBlue,
                                ),
                              ),
                            ],
                          ),
                        ],

                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
              ),

              // ── Powered by footer — pinned at bottom ──────────
              Padding(
                padding: EdgeInsets.only(bottom: bottomPad + 16, top: 8),
                child: Text(
                  L.tr(context, 'powered_by'),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: isDark
                        ? Colors.white30
                        : _brandBlue.withValues(alpha: 0.6),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Reusable text field builder ─────────────────────────────────
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required bool isDark,
    TextInputType? keyboardType,
    bool obscure = false,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscure,
      style: const TextStyle(fontSize: 15),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, size: 20),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFF5F7FA),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDark ? Colors.white12 : const Color(0xFFE0E0E0),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _brandBlue, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.red.shade300),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.red.shade400, width: 2),
        ),
      ),
      validator: validator,
    );
  }

  // ── Language chip toggle ────────────────────────────────────────
  Widget _buildLanguageChip(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final isEn = appState.locale == 'en';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _langOption('EN', isEn, () => appState.setLocale('en')),
          _langOption('SW', !isEn, () => appState.setLocale('sw')),
        ],
      ),
    );
  }

  Widget _langOption(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: active ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: active ? _brandBlue : Colors.white70,
          ),
        ),
      ),
    );
  }

  // ── Theme toggle ───────────────────────────────────────────────
  Widget _buildThemeToggle(BuildContext context, bool isDark) {
    return GestureDetector(
      onTap: () =>
          Provider.of<AppState>(context, listen: false).toggleTheme(),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
        ),
        child: Icon(
          isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
          color: Colors.white,
          size: 20,
        ),
      ),
    );
  }
}
