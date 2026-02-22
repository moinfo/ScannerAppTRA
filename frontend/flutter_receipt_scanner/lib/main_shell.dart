import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:local_auth/local_auth.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_receipt_scanner/app_state.dart';
import 'package:flutter_receipt_scanner/dashboard_page.dart';
import 'package:flutter_receipt_scanner/l10n.dart';
import 'package:flutter_receipt_scanner/login_page.dart';
import 'package:flutter_receipt_scanner/main.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  String _userName = '';
  String _userEmail = '';
  bool _isOfflineMode = false;

  // Dashboard date range (default: current month)
  late DateTime _dashStartDate;
  late DateTime _dashEndDate;

  static const Color _primaryColor = Color(0xFF1565C0);

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _dashStartDate = DateTime(now.year, now.month, 1);
    _dashEndDate = now;
    _loadUserInfo();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<ReceiptProvider>(context, listen: false);
      provider.fetchReceipts();
      provider.fetchDashboard(startDate: _dashStartDate, endDate: _dashEndDate);
    });
  }

  Future<void> _loadUserInfo() async {
    final info = await LoginState.getUserInfo();
    if (!mounted) return;
    setState(() {
      _userName = info['name'] ?? 'Guest User';
      _userEmail = info['email'] ?? 'No email';
      _isOfflineMode = info['isOfflineMode'] ?? false;
    });
  }

  void _onTabTapped(int index) {
    if (index == 2) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ScanPage()),
      ).then((_) {
        final provider = Provider.of<ReceiptProvider>(context, listen: false);
        provider.fetchReceipts();
        provider.fetchDashboard(startDate: _dashStartDate, endDate: _dashEndDate);
      });
      return;
    }
    setState(() => _currentIndex = index);
  }

  Future<void> _pickDashboardDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _dashStartDate, end: _dashEndDate),
    );

    if (picked != null) {
      setState(() {
        _dashStartDate = picked.start;
        _dashEndDate = picked.end;
      });
      Provider.of<ReceiptProvider>(context, listen: false)
          .fetchDashboard(startDate: _dashStartDate, endDate: _dashEndDate);
    }
  }

  String _appBarTitle(BuildContext context) {
    switch (_currentIndex) {
      case 0:
        return L.tr(context, 'nav_dashboard');
      case 1:
        return L.tr(context, 'app_title');
      case 3:
        return L.tr(context, 'profile_title');
      default:
        return L.tr(context, 'app_title');
    }
  }

  String? _appBarSubtitle() {
    if (_currentIndex == 0) {
      // Show date range on dashboard tab
      final fmt = DateFormat('dd MMM');
      return '${fmt.format(_dashStartDate)} - ${fmt.format(_dashEndDate)}';
    }
    if (_currentIndex == 1) {
      if (_isOfflineMode) {
        return '${L.tr(context, 'offline_mode')} - $_userName';
      }
      return _userEmail.isNotEmpty ? _userEmail : null;
    }
    return null;
  }

  Widget _buildDateRangeButton(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(right: 2),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: isDark ? 0.1 : 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: _pickDashboardDateRange,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.date_range_rounded,
                size: 16,
                color: isDark ? Colors.white70 : Colors.white,
              ),
              const SizedBox(width: 4),
              Text(
                _formatDateRangeShort(),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white70 : Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDateRangeShort() {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    // If it's the default "this month" range, show a label
    if (_dashStartDate.year == monthStart.year &&
        _dashStartDate.month == monthStart.month &&
        _dashStartDate.day == monthStart.day &&
        _dashEndDate.year == now.year &&
        _dashEndDate.month == now.month &&
        _dashEndDate.day == now.day) {
      return L.tr(context, 'this_month');
    }
    final fmt = DateFormat('dd/MM');
    return '${fmt.format(_dashStartDate)}-${fmt.format(_dashEndDate)}';
  }

  Widget _buildLanguageToggle(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final isDark = appState.themeMode == ThemeMode.dark;
    final isEn = appState.locale == 'en';

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.1)
            : Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(alpha: isDark ? 0.15 : 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _langChip('EN', isEn, () => appState.setLocale('en')),
          _langChip('SW', !isEn, () => appState.setLocale('sw')),
        ],
      ),
    );
  }

  Widget _langChip(String label, bool active, VoidCallback onTap) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: active
              ? (isDark ? Colors.white.withValues(alpha: 0.2) : Colors.white)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: active
                ? (isDark ? Colors.white : _primaryColor)
                : Colors.white54,
          ),
        ),
      ),
    );
  }

  Widget _buildThemeToggle(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final isDark = appState.themeMode == ThemeMode.dark;

    return Container(
      margin: const EdgeInsets.only(right: 2),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: isDark ? 0.1 : 0.15),
        shape: BoxShape.circle,
      ),
      child: IconButton(
        icon: Icon(
          isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
          size: 19,
          color: isDark ? Colors.amber.shade300 : Colors.white,
        ),
        onPressed: () => appState.toggleTheme(),
        tooltip: L.tr(context, 'profile_theme'),
        visualDensity: VisualDensity.compact,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final subtitle = _appBarSubtitle();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final appBarBg = isDark ? const Color(0xFF1A1A2E) : _primaryColor;
    final subtitleColor =
        isDark ? Colors.white38 : Colors.white70;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: appBarBg,
        foregroundColor: Colors.white,
        elevation: isDark ? 0 : 2,
        surfaceTintColor: Colors.transparent,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _appBarTitle(context),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            if (subtitle != null)
              Text(
                subtitle,
                style: TextStyle(fontSize: 11, color: subtitleColor),
              ),
          ],
        ),
        actions: [
          if (_isOfflineMode)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child:
                  Icon(Icons.cloud_off, color: Colors.orangeAccent, size: 20),
            ),
          // Date range picker (only on Dashboard tab)
          if (_currentIndex == 0)
            _buildDateRangeButton(context),
          // Language toggle
          _buildLanguageToggle(context),
          // Dark mode toggle
          _buildThemeToggle(context),
          const SizedBox(width: 4),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex > 2 ? _currentIndex - 1 : _currentIndex,
        children: [
          const DashboardPage(),
          ReceiptListPage(
            userName: _userName,
            userEmail: _userEmail,
            isOfflineMode: _isOfflineMode,
          ),
          ProfilePage(
            userName: _userName,
            userEmail: _userEmail,
            isOfflineMode: _isOfflineMode,
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: _onTabTapped,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.dashboard_outlined),
            selectedIcon: const Icon(Icons.dashboard),
            label: L.tr(context, 'nav_dashboard'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.receipt_long_outlined),
            selectedIcon: const Icon(Icons.receipt_long),
            label: L.tr(context, 'nav_receipts'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.qr_code_scanner_outlined),
            selectedIcon: const Icon(Icons.qr_code_scanner),
            label: L.tr(context, 'nav_scan'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.person_outline),
            selectedIcon: const Icon(Icons.person),
            label: L.tr(context, 'nav_profile'),
          ),
        ],
      ),
    );
  }
}

// ─── Profile Page ────────────────────────────────────────────────────────────

class ProfilePage extends StatefulWidget {
  const ProfilePage({
    super.key,
    required this.userName,
    required this.userEmail,
    required this.isOfflineMode,
  });

  final String userName;
  final String userEmail;
  final bool isOfflineMode;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  static const Color _primaryColor = Color(0xFF1565C0);
  final LocalAuthentication _localAuth = LocalAuthentication();
  bool _biometricEnabled = true;
  bool _deviceSupportsBiometric = false;

  @override
  void initState() {
    super.initState();
    _loadBiometricInfo();
  }

  Future<void> _loadBiometricInfo() async {
    final prefs = await SharedPreferences.getInstance();

    // Check device capability
    bool canCheck = false;
    try {
      canCheck = await _localAuth.canCheckBiometrics ||
          await _localAuth.isDeviceSupported();
    } catch (_) {}

    if (!mounted) return;
    setState(() {
      _biometricEnabled = prefs.getBool('biometricEnabled') ?? true;
      _deviceSupportsBiometric = canCheck;
    });
  }

  Future<void> _toggleBiometric(bool value) async {
    // Require fingerprint verification before changing
    try {
      final didAuth = await _localAuth.authenticate(
        localizedReason: L.tr(context, 'biometric_reason'),
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );
      if (!didAuth || !mounted) return;
    } catch (_) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('biometricEnabled', value);
    if (!mounted) return;
    setState(() => _biometricEnabled = value);
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final isDark = appState.themeMode == ThemeMode.dark;
    final initial = widget.userName.isNotEmpty ? widget.userName[0].toUpperCase() : '?';

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      children: [
        // Avatar + user card
        Card(
          elevation: 2,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 38,
                  backgroundColor: _primaryColor,
                  child: Text(
                    initial,
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  widget.userName,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.isOfflineMode
                      ? L.tr(context, 'offline_mode')
                      : widget.userEmail,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 20),

        // Dark mode toggle
        Card(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: SwitchListTile(
            secondary: Icon(
              isDark ? Icons.dark_mode : Icons.light_mode_outlined,
              color: _primaryColor,
            ),
            title: Text(L.tr(context, 'profile_theme')),
            value: isDark,
            onChanged: (_) => appState.toggleTheme(),
          ),
        ),

        const SizedBox(height: 8),

        // Biometric login toggle (only if device supports it)
        if (_deviceSupportsBiometric) ...[
          Card(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: SwitchListTile(
              secondary: const Icon(Icons.fingerprint, color: _primaryColor),
              title: Text(L.tr(context, 'profile_biometric')),
              value: _biometricEnabled,
              onChanged: _toggleBiometric,
            ),
          ),
          const SizedBox(height: 8),
        ],

        // Language selector
        Card(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            leading: const Icon(Icons.language, color: _primaryColor),
            title: Text(L.tr(context, 'profile_language')),
            trailing: ToggleButtons(
              borderRadius: BorderRadius.circular(8),
              isSelected: [
                appState.locale == 'en',
                appState.locale == 'sw',
              ],
              onPressed: (index) {
                appState.setLocale(index == 0 ? 'en' : 'sw');
              },
              constraints:
                  const BoxConstraints(minWidth: 48, minHeight: 36),
              children: const [
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text('EN', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text('SW', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 24),

        // Logout button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => _doLogout(context),
            icon: const Icon(Icons.logout),
            label: Text(L.tr(context, 'logout')),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),

        const SizedBox(height: 32),

        // Footer
        Center(
          child: Column(
            children: [
              Text(
                '${L.tr(context, 'profile_app_version')}: 1.0.0',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              ),
              const SizedBox(height: 4),
              Text(
                L.tr(context, 'powered_by'),
                style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _doLogout(BuildContext context) async {
    final shouldLogout = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(L.tr(context, 'confirm_logout')),
            content: Text(L.tr(context, 'logout_confirm_msg')),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text(L.tr(context, 'cancel')),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: Text(
                  L.tr(context, 'logout'),
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
        ) ??
        false;

    if (!shouldLogout || !context.mounted) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(L.tr(context, 'logged_out')),
        backgroundColor: Colors.blue,
        duration: const Duration(seconds: 2),
      ),
    );

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }
}
