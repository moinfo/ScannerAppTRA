import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_receipt_scanner/main.dart';
import 'package:flutter_receipt_scanner/providers/app_state_provider.dart';
import 'package:flutter_receipt_scanner/providers/vat_provider.dart';
import 'package:flutter_receipt_scanner/screens/auto_purchases_screen.dart';
import 'package:flutter_receipt_scanner/screens/home_screen.dart';
import 'package:flutter_receipt_scanner/screens/purchases_screen.dart';
import 'package:flutter_receipt_scanner/screens/reports_screen.dart';
import 'package:flutter_receipt_scanner/screens/sales_screen.dart';
import 'package:flutter_receipt_scanner/screens/scan_screen.dart';
import 'package:flutter_receipt_scanner/screens/vat_payment_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Dashboard extends StatefulWidget {
  const Dashboard({Key? key}) : super(key: key);

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  int _selectedIndex = 0;
  String _userName = "";
  String _userEmail = "";
  bool _isOfflineMode = false;

  // We'll use a getter for screens to ensure providers are available each time
  List<Widget>? _screensCache;
  
  List<Widget> get _screens {
    if (_screensCache == null) {
      _initializeScreens();
    }
    return _screensCache!;
  }
  
  void _initializeScreens() {
    _screensCache = [
      const HomeScreen(),
      const AutoPurchasesScreen(),
      const SalesScreen(),
      const PurchasesScreen(),
      const VatPaymentScreen(),
      const ScanScreen(),
      const ReportsScreen(),
    ];
  }

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
    
    // Initialize screens after the first frame when providers are ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // This ensures providers are accessible
      if (mounted) {
        try {
          // Access providers to ensure they're initialized
          Provider.of<VatProvider>(context, listen: false);
          Provider.of<AppStateProvider>(context, listen: false);
          
          // Now initialize the screens
          _initializeScreens();
        } catch (e) {
          debugPrint('Error initializing screens: $e');
        }
      }
    });
  }

  Future<void> _loadUserInfo() async {
    final userInfo = await LoginState.getUserInfo();
    setState(() {
      _userName = userInfo['name'] ?? 'Guest User';
      _userEmail = userInfo['email'] ?? 'No email';
      _isOfflineMode = userInfo['isOfflineMode'] ?? false;
    });
  }

  void _onItemTapped(int index) {
    if (_selectedIndex != index) {
      // Add haptic feedback for better user experience
      try {
        HapticFeedback.lightImpact();
      } catch (e) {
        // Haptic feedback not available, continue without it
      }
      
      setState(() {
        _selectedIndex = index;
      });
    }
  }

  void _showProfileOptions(BuildContext context) {
    // Get the profile URL (same as in build method)
    String? profileUrl;
    try {
      // We could add profileUrl to AppStateProvider later if needed
      // For now, just leave it as null
    } catch (e) {
      // Ignore if we can't get the profile URL
    }
    
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Profile header
            Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.blue.shade100,
                  backgroundImage: profileUrl != null && profileUrl.isNotEmpty
                      ? NetworkImage(profileUrl!)
                      : null,
                  child: profileUrl == null || profileUrl.isEmpty
                      ? Text(
                          _userName.isNotEmpty ? _userName[0].toUpperCase() : 'U',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade700,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _userName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        _userEmail,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      if (_isOfflineMode)
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Offline Mode',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.orange.shade800,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            
            // Quick actions
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildQuickAction(
                  icon: Icons.person,
                  label: 'Profile',
                  onTap: () {
                    Navigator.pop(context);
                    // Navigate to profile
                  },
                ),
                _buildQuickAction(
                  icon: Icons.settings,
                  label: 'Settings',
                  onTap: () {
                    Navigator.pop(context);
                    // Navigate to settings
                  },
                ),
                _buildQuickAction(
                  icon: Icons.help,
                  label: 'Help',
                  onTap: () {
                    Navigator.pop(context);
                    // Navigate to help
                  },
                ),
                _buildQuickAction(
                  icon: Icons.logout,
                  label: 'Logout',
                  color: Colors.red,
                  onTap: () {
                    Navigator.pop(context);
                    _logout();
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
  }) {
    final actionColor = color ?? Colors.blue.shade700;
    
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: actionColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: actionColor,
              size: 24,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: actionColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _logout() async {
    // Show confirmation dialog
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Logout'),
        content: Text(_isOfflineMode 
          ? 'Are you sure you want to exit offline mode? You will need to login again.'
          : 'Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Logout'),
          ),
        ],
      ),
    ) ?? false;
    
    if (!shouldLogout || !mounted) return;
    
    // Perform logout
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    
    if (!mounted) return;
    
    // Show logout message
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Logged out successfully'),
        backgroundColor: Colors.blue,
        duration: Duration(seconds: 2),
      ),
    );
    
    // Navigate back to login page using named route
    Navigator.of(context).pushReplacementNamed('login');
  }

  @override
  Widget build(BuildContext context) {
    // Get the profile URL (not using profileUrl since it's not defined in AppStateProvider)
    String? profileUrl;
    // Just leaving it as null since profileUrl doesn't exist in AppStateProvider
    try {
      // We could add profileUrl to AppStateProvider later if needed
      // For now, just leave it as null
    } catch (e) {
      // Ignore if we can't get the profile URL
    }
    
    // Make sure screens are initialized (will use the getter)
    
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(80.0),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue.shade800, Colors.blue.shade600],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.blue.shade300.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: AppBar(
            elevation: 0,
            backgroundColor: Colors.transparent,
            leading: Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Builder(
                builder: (context) => IconButton(
                  icon: const Icon(Icons.menu, color: Colors.white),
                  onPressed: () => Scaffold.of(context).openDrawer(),
                ),
              ),
            ),
            flexibleSpace: SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(left: 72.0, right: 16.0, top: 8.0, bottom: 8.0), // Left padding for menu button
                child: Row(
                  children: [
                    // App title and user info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.qr_code_scanner, 
                                color: Colors.white, 
                                size: 20
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Lemuru Scanner', 
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold, 
                                  letterSpacing: 0.5
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          if (_userName.isNotEmpty) 
                            Row(
                              children: [
                                Icon(
                                  _isOfflineMode ? Icons.cloud_off : Icons.person,
                                  color: _isOfflineMode ? Colors.orange.shade200 : Colors.white70,
                                  size: 14,
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    _isOfflineMode 
                                        ? 'Offline Mode • $_userName' 
                                        : 'Welcome, $_userName',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: _isOfflineMode ? Colors.orange.shade200 : Colors.white70,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                    
                    // Status indicators and profile
                    Row(
                      children: [
                        // Online/Offline status indicator
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _isOfflineMode 
                                ? Colors.orange.withOpacity(0.9)
                                : Colors.green.withOpacity(0.9),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _isOfflineMode ? Icons.cloud_off : Icons.wifi,
                                color: Colors.white,
                                size: 12,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _isOfflineMode ? 'Offline' : 'Online',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        
                        // Profile avatar with enhanced styling
                        GestureDetector(
                          onTap: () {
                            // Show profile options
                            _showProfileOptions(context);
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white,
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: CircleAvatar(
                              radius: 20,
                              backgroundColor: Colors.white,
                              backgroundImage: profileUrl != null && profileUrl.isNotEmpty
                                  ? NetworkImage(profileUrl!)
                                  : null,
                              child: profileUrl == null || profileUrl.isEmpty
                                  ? Text(
                                      _userName.isNotEmpty ? _userName[0].toUpperCase() : 'U',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blue.shade700,
                                      ),
                                    )
                                  : null,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.grey.shade50,
                Colors.white,
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: _screens[_selectedIndex],
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, -5),
              spreadRadius: 0,
            ),
            BoxShadow(
              color: Colors.blue.withOpacity(0.05),
              blurRadius: 40,
              offset: const Offset(0, -10),
              spreadRadius: 0,
            ),
          ],
        ),
        child: SafeArea(
          child: Container(
            height: 90,
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildNavItem(
                  icon: Icons.dashboard_outlined,
                  selectedIcon: Icons.dashboard,
                  label: 'Home',
                  index: 0,
                ),
                _buildNavItem(
                  icon: Icons.receipt_long_outlined,
                  selectedIcon: Icons.receipt_long,
                  label: 'Auto',
                  index: 1,
                ),
                _buildNavItem(
                  icon: Icons.shopping_cart_outlined,
                  selectedIcon: Icons.shopping_cart,
                  label: 'Sales',
                  index: 2,
                ),
                _buildNavItem(
                  icon: Icons.shopping_bag_outlined,
                  selectedIcon: Icons.shopping_bag,
                  label: 'Purchases',
                  index: 3,
                ),
                _buildNavItem(
                  icon: Icons.payments_outlined,
                  selectedIcon: Icons.payments,
                  label: 'VAT',
                  index: 4,
                ),
                _buildNavItem(
                  icon: Icons.qr_code_scanner_outlined,
                  selectedIcon: Icons.qr_code_scanner,
                  label: 'Scan',
                  index: 5,
                  isSpecial: true,
                ),
                _buildNavItem(
                  icon: Icons.bar_chart_outlined,
                  selectedIcon: Icons.bar_chart,
                  label: 'Reports',
                  index: 6,
                ),
              ],
            ),
          ),
        ),
      ),
      drawer: Drawer(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue.shade800, Colors.blue.shade600],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.shade300.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: SafeArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Profile picture with improved styling
                    CircleAvatar(
                      radius: 36,
                      backgroundColor: Colors.white,
                      backgroundImage: profileUrl != null && profileUrl.isNotEmpty
                          ? NetworkImage(profileUrl!)
                          : null,
                      child: profileUrl == null || profileUrl.isEmpty
                          ? Text(
                              _userName.isNotEmpty ? _userName[0].toUpperCase() : 'U',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade700,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _userName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _userEmail,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                    if (_isOfflineMode)
                      Container(
                        margin: const EdgeInsets.only(top: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.orange,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'Offline Mode',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  const SizedBox(height: 8),
                  // Section header
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text(
                      'MAIN MENU',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ),
                  // Main menu items with improved styling
                  _buildDrawerItem(
                    icon: Icons.dashboard,
                    title: 'Dashboard',
                    isSelected: _selectedIndex == 0,
                    onTap: () {
                      _onItemTapped(0);
                      Navigator.pop(context);
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.receipt_long,
                    title: 'Auto Purchases',
                    isSelected: _selectedIndex == 1,
                    onTap: () {
                      _onItemTapped(1);
                      Navigator.pop(context);
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.shopping_cart,
                    title: 'Sales',
                    isSelected: _selectedIndex == 2,
                    onTap: () {
                      _onItemTapped(2);
                      Navigator.pop(context);
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.shopping_bag,
                    title: 'Purchases',
                    isSelected: _selectedIndex == 3,
                    onTap: () {
                      _onItemTapped(3);
                      Navigator.pop(context);
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.payments,
                    title: 'VAT Payments',
                    isSelected: _selectedIndex == 4,
                    onTap: () {
                      _onItemTapped(4);
                      Navigator.pop(context);
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.qr_code_scanner,
                    title: 'Scan Receipt',
                    isSelected: _selectedIndex == 5,
                    onTap: () {
                      _onItemTapped(5);
                      Navigator.pop(context);
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.bar_chart,
                    title: 'Reports',
                    isSelected: _selectedIndex == 6,
                    onTap: () {
                      _onItemTapped(6);
                      Navigator.pop(context);
                    },
                  ),
                  const Divider(height: 32),
                  // Section header
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text(
                      'SETTINGS',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ),
                  // Removed profile navigation
                  _buildDrawerItem(
                    icon: Icons.person,
                    title: 'My Profile',
                    onTap: () {
                      Navigator.pop(context);
                      // Profile route removed
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.settings,
                    title: 'Settings',
                    onTap: () {
                      Navigator.pop(context);
                      // Add settings navigation logic here
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.help_outline,
                    title: 'Help & Support',
                    onTap: () {
                      Navigator.pop(context);
                      // Add help navigation logic here
                    },
                  ),
                ],
              ),
            ),
            // Bottom logout button
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 5,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _logout();
                },
                icon: const Icon(Icons.logout),
                label: const Text('Logout'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade50,
                  foregroundColor: Colors.red,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  // Helper method for bottom navigation items
  Widget _buildNavItem({
    required IconData icon,
    required IconData selectedIcon,
    required String label,
    required int index,
    bool isSpecial = false,
  }) {
    final isSelected = _selectedIndex == index;
    final primaryColor = Colors.blue.shade700;
    final unselectedColor = Colors.grey.shade500;
    
    return GestureDetector(
      onTap: () => _onItemTapped(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: EdgeInsets.symmetric(
          horizontal: isSpecial ? 4 : 2, 
          vertical: 0
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon container with enhanced styling
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              padding: EdgeInsets.all(isSpecial ? 6 : 3),
              decoration: BoxDecoration(
                color: isSelected 
                    ? (isSpecial 
                        ? primaryColor 
                        : primaryColor.withOpacity(0.15))
                    : (isSpecial 
                        ? Colors.grey.shade50 
                        : Colors.transparent),
                borderRadius: BorderRadius.circular(isSpecial ? 16 : 12),
                boxShadow: isSelected ? [
                  if (isSpecial) ...[
                    BoxShadow(
                      color: primaryColor.withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                      spreadRadius: 0,
                    ),
                    BoxShadow(
                      color: primaryColor.withOpacity(0.1),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                      spreadRadius: 0,
                    ),
                  ] else ...[
                    BoxShadow(
                      color: primaryColor.withOpacity(0.15),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                      spreadRadius: 0,
                    ),
                  ],
                ] : null,
                border: isSpecial && !isSelected 
                    ? Border.all(
                        color: Colors.grey.shade200, 
                        width: 1.5
                      ) 
                    : null,
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                transitionBuilder: (Widget child, Animation<double> animation) {
                  return ScaleTransition(
                    scale: animation,
                    child: child,
                  );
                },
                child: Icon(
                  isSelected ? selectedIcon : icon,
                  key: ValueKey(isSelected),
                  color: isSelected 
                      ? (isSpecial ? Colors.white : primaryColor)
                      : unselectedColor,
                  size: isSpecial ? 22 : 18,
                ),
              ),
            ),
            
            // Animated spacing
            SizedBox(height: isSelected ? 1 : 0),
            
            // Label with enhanced styling
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                fontSize: 8,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? primaryColor : unselectedColor,
                height: 1.0,
              ),
              child: Text(label),
            ),
            
          ],
        ),
      ),
    );
  }

  // Helper method to build drawer items with consistent styling
  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    bool isSelected = false,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: isSelected ? Colors.blue.shade50 : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        leading: Icon(
          icon,
          color: isSelected ? Colors.blue.shade700 : Colors.grey.shade700,
        ),
        title: Text(
          title,
          style: TextStyle(
            color: isSelected ? Colors.blue.shade700 : Colors.black87,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        onTap: onTap,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
      ),
    );
  }
}