import 'package:flutter/material.dart';
import 'package:flutter_receipt_scanner/login_page.dart';
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
import 'dart:convert';

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
    setState(() {
      _selectedIndex = index;
    });
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
    // Access providers to ensure they're properly initialized
    final vatProvider = Provider.of<VatProvider>(context, listen: false);
    final appStateProvider = Provider.of<AppStateProvider>(context, listen: false);
    
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
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.blue.shade700,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Lemuru Scanner', 
              style: TextStyle(
                fontWeight: FontWeight.bold, 
                letterSpacing: 0.5
              ),
            ),
            if (_userEmail.isNotEmpty) 
              Text(
                _isOfflineMode 
                    ? 'Offline Mode - $_userName' 
                    : '$_userName',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.normal,
                  color: Colors.white70
                ),
              ),
          ],
        ),
        actions: [
          if (_isOfflineMode)
            Container(
              padding: const EdgeInsets.all(8.0),
              margin: const EdgeInsets.only(right: 8.0),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Icon(Icons.cloud_off, color: Colors.orange, size: 20),
            ),
          // Profile picture in app bar  
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: CircleAvatar(
              radius: 18,
              backgroundColor: Colors.white,
              backgroundImage: profileUrl != null && profileUrl.isNotEmpty
                  ? NetworkImage(profileUrl)
                  : null,
              child: profileUrl == null || profileUrl.isEmpty
                  ? Text(
                      _userName.isNotEmpty ? _userName[0].toUpperCase() : 'U',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade700,
                      ),
                    )
                  : null,
            ),
          ),
        ],
      ),
      body: _screens[_selectedIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          type: BottomNavigationBarType.fixed, // Needed for more than 3 items
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          selectedItemColor: Colors.blue.shade700,
          unselectedItemColor: Colors.grey.shade600,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
          unselectedLabelStyle: const TextStyle(fontSize: 11),
          elevation: 16,
          backgroundColor: Colors.white,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.dashboard),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.receipt_long),
              label: 'Auto',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.shopping_cart),
              label: 'Sales',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.shopping_bag),
              label: 'Purchases',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.payments),
              label: 'VAT',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.qr_code_scanner),
              label: 'Scan',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.bar_chart),
              label: 'Reports',
            ),
          ],
        ),
      ),
      drawer: Drawer(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue.shade800, Colors.blue.shade600],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
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
                          ? NetworkImage(profileUrl)
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