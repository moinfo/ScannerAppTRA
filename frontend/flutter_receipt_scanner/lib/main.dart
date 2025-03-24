import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_receipt_scanner/dashboard.dart';
import 'package:flutter_receipt_scanner/login_page.dart';
import 'package:flutter_receipt_scanner/providers/app_state_provider.dart';
import 'package:flutter_receipt_scanner/providers/purchases_provider.dart';
import 'package:flutter_receipt_scanner/providers/receipt_provider.dart';
import 'package:flutter_receipt_scanner/providers/sales_provider.dart';
import 'package:flutter_receipt_scanner/providers/vat_provider.dart';
import 'package:flutter_receipt_scanner/services/receipt_to_sale_service.dart';
import 'package:flutter_receipt_scanner/utils/api_request_status.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:math' show min;

// API URLs - Change these based on your environment
class ApiConfig {
  // Set to false for testing without a running backend server
  static const bool useRealBackend = true;
  
  // Set to true for local development, false for production
  static const bool useLocalServer = false;
  
  // Base URLs
  static const String productionBaseUrl = 'https://lemuru.co.tz/api';
  static const String localBaseUrl = 'http://10.0.2.2:8000/api'; // Use your IP or 10.0.2.2 for Android emulator
  
  // Receipt scraper URL
  static const String scraperUrl = 'http://50.116.44.162:4000';
  
  // Get the appropriate base URL
  static String get baseUrl => useLocalServer ? localBaseUrl : productionBaseUrl;
  
  // API endpoints
  static String get receiptsUrl => '$baseUrl/receipts';
  static String get addReceiptUrl => '$baseUrl/add_receipt';
  static String get loginUrl => '$baseUrl/login';
  
  // New API endpoints
  static String get salesUrl => '$baseUrl/sales';
  static String get purchasesUrl => '$baseUrl/purchases';
  static String get reportsUrl => '$baseUrl/reports';
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Check if user is logged in
  final prefs = await SharedPreferences.getInstance();
  final bool isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
  
  runApp(MyApp(isLoggedIn: isLoggedIn));
}

class MyApp extends StatelessWidget {
  final bool isLoggedIn;
  
  const MyApp({super.key, this.isLoggedIn = false});
  
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => AppStateProvider()),
        ChangeNotifierProvider(create: (context) => ReceiptProvider()),
        ChangeNotifierProvider(create: (context) => SalesProvider()),
        ChangeNotifierProvider(create: (context) => PurchasesProvider()),
        ChangeNotifierProvider(create: (context) => VatProvider()),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Flutter Receipt Scanner',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          useMaterial3: true,
        ),
        home: isLoggedIn ? const MyHomePage() : const LoginPage(),
        routes: {
          'scan': (context) => const ScanPage(),
          'login': (context) => const LoginPage(),
          'home': (context) => const MyHomePage(),
          'dashboard': (context) {
            // Instead of directly accessing providers here, wrap the Dashboard
            // in a Builder widget to ensure context is correct
            return Builder(
              builder: (context) {
                try {
                  // Pre-access providers to ensure they're available
                  Provider.of<AppStateProvider>(context, listen: false);
                  Provider.of<VatProvider>(context, listen: false);
                  Provider.of<ReceiptProvider>(context, listen: false);
                  Provider.of<SalesProvider>(context, listen: false);
                  Provider.of<PurchasesProvider>(context, listen: false);
                  
                  // If everything is OK, return the Dashboard
                  return const Dashboard();
                } catch (e) {
                  // If there's an error accessing providers, show a loading screen
                  debugPrint('Error accessing providers in dashboard route: $e');
                  return Scaffold(
                    body: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const CircularProgressIndicator(),
                          const SizedBox(height: 16),
                          Text('Initializing app...', 
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                  );
                }
              }
            );
          },
        },
      ),
    );
  }
}

class NoItems extends StatelessWidget {
  const NoItems({
    super.key,
    required this.errMsg,
  });

  final String errMsg;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(errMsg),
    );
  }
}

class ReceiptCard extends StatelessWidget {
  const ReceiptCard({
    super.key,
    required this.receipt,
    required this.index,
  });

  final Receipt receipt;
  final int index;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        child: Text('${index + 1}', style: const TextStyle(fontSize: 13)),
      ),
      title: Text(
        receipt.companyName,
        style: const TextStyle(fontSize: 13),
      ),
      subtitle: Text(
        '${receipt.date} ${receipt.time}',
        style: const TextStyle(fontSize: 12),
      ),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (BuildContext context) {
              return ReceiptDetailPage(receipt: receipt);
            },
          ),
        );
      },
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

// This will help us check the login state more easily
class LoginState {
  static Future<Map<String, dynamic>> getUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final bool isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
    final String? token = prefs.getString('token');
    final String? userJson = prefs.getString('user');
    Map<String, dynamic> user = {};
    
    if (userJson != null) {
      try {
        user = jsonDecode(userJson);
      } catch (e) {
        debugPrint('Error decoding user JSON: $e');
      }
    }
    
    final String? email = user['email'];
    final String? name = user['name'];
    final bool isOfflineMode = token != null && token.startsWith('offline_');
    
    return {
      'isLoggedIn': isLoggedIn,
      'token': token,
      'email': email,
      'name': name,
      'isOfflineMode': isOfflineMode,
    };
  }
}

class _MyHomePageState extends State<MyHomePage> {
  final ScrollController _scrollController = ScrollController();
  DateTime? _startDate;
  DateTime? _endDate;
  final TextEditingController _searchController = TextEditingController();
  
  // User info
  String _userName = "";
  String _userEmail = "";
  bool _isOfflineMode = false;
  
  @override
  void initState() {
    super.initState();
    debugPrint('initState called');
    
    // Load user info and initial data
    SchedulerBinding.instance.addPostFrameCallback((_) async {
      debugPrint('Post frame callback triggered');
      
      // Get user info
      final userInfo = await LoginState.getUserInfo();
      setState(() {
        _userName = userInfo['name'] ?? 'Guest User';
        _userEmail = userInfo['email'] ?? 'No email';
        _isOfflineMode = userInfo['isOfflineMode'] ?? false;
      });
      
      // Show login status toast message
      _showLoginStatusToast();
      
      // Load receipts
      Provider.of<ReceiptProvider>(context, listen: false).fetchReceipts();
    });
    
    // Add scroll listener for pagination
    _scrollController.addListener(_scrollListener);
  }
  
  void _showLoginStatusToast() {
    // Show a toast message with login status
    final scaffold = ScaffoldMessenger.of(context);
    scaffold.showSnackBar(
      SnackBar(
        content: _isOfflineMode
            ? Text('Logged in as $_userName (Offline Mode)')
            : Text('Logged in as $_userName ($_userEmail)'),
        backgroundColor: _isOfflineMode ? Colors.orange : Colors.green,
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: 'OK',
          onPressed: scaffold.hideCurrentSnackBar,
          textColor: Colors.white,
        ),
      ),
    );
  }
  
  void _scrollListener() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      // We're approaching the end of the list, load more data
      final provider = Provider.of<ReceiptProvider>(context, listen: false);
      if (!provider.isLoading && provider.hasMoreData) {
        provider.loadMoreReceipts();
      }
    }
  }

  void _applyDateFilter() async {
    final provider = Provider.of<ReceiptProvider>(context, listen: false);
    await provider.fetchReceipts(
      startDate: _startDate,
      endDate: _endDate,
      searchTerm: _searchController.text.trim(),
    );
  }

  Future<void> _selectDateRange(BuildContext context) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
    );
    
    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      _applyDateFilter();
    }
  }

  void _clearFilters() {
    setState(() {
      _startDate = null;
      _endDate = null;
      _searchController.clear();
    });
    Provider.of<ReceiptProvider>(context, listen: false).fetchReceipts();
  }

  void _logout() async {
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
    
    // Navigate back to login page
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => const LoginPage(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Lemuru Scanner App'),
            if (_userEmail.isNotEmpty) 
              Text(
                _isOfflineMode 
                    ? 'Offline Mode - $_userName' 
                    : '$_userName ($_userEmail)',
                style: const TextStyle(fontSize: 12),
              ),
          ],
        ),
        actions: [
          if (_isOfflineMode)
            Container(
              padding: const EdgeInsets.all(8.0),
              child: const Icon(Icons.cloud_off, color: Colors.orange),
            ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
            tooltip: 'Logout',
          ),
        ],
      ),
      body: Column(
        children: [
          // Search and filter section
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              children: [
                // Search bar
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search by company name',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        _applyDateFilter();
                      },
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                  ),
                  onSubmitted: (_) => _applyDateFilter(),
                ),
                const SizedBox(height: 8),
                
                // Date filter row
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.date_range),
                        label: Text(_startDate != null && _endDate != null 
                            ? '${DateFormat('dd/MM/yy').format(_startDate!)} - ${DateFormat('dd/MM/yy').format(_endDate!)}'
                            : 'Select Date Range'),
                        onPressed: () => _selectDateRange(context),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.filter_list),
                      onPressed: _applyDateFilter,
                    ),
                    IconButton(
                      icon: const Icon(Icons.clear_all),
                      onPressed: _clearFilters,
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Receipts list
          Expanded(
            child: Consumer<ReceiptProvider>(
              builder: (context, receipt, _) => buildBody(receipt),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () =>
            Navigator.pushNamed(context, ScanPage.route).then((value) async {
              await Provider.of<ReceiptProvider>(context, listen: false)
                  .fetchReceipts(
                    startDate: _startDate,
                    endDate: _endDate,
                    searchTerm: _searchController.text.trim(),
                  );
            }),
        child: const Icon(Icons.qr_code_scanner_rounded),
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Widget buildBody(ReceiptProvider receiptProvider) {
    debugPrint('Current API status: ${receiptProvider.apiRequestStatus}');

    if (receiptProvider.apiRequestStatus == APIRequestStatus.error ||
        receiptProvider.apiRequestStatus == APIRequestStatus.networkError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Error: ${receiptProvider.lastError}'),
            ElevatedButton(
              onPressed: () => receiptProvider.fetchReceipts(
                startDate: _startDate,
                endDate: _endDate,
                searchTerm: _searchController.text.trim(),
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    return BodyBuilder(
      apiRequestStatus: receiptProvider.apiRequestStatus,
      body: buildBodyList(receiptProvider),
      onRefresh: () async {
        debugPrint('Refresh triggered');
        await receiptProvider.fetchReceipts(
          startDate: _startDate,
          endDate: _endDate,
          searchTerm: _searchController.text.trim(),
        );
      },
    );
  }

  Widget buildBodyList(ReceiptProvider receiptProvider) {
    debugPrint('Receipts length: ${receiptProvider.receipts.length}');
    if (receiptProvider.receipts.isNotEmpty) {
      return Stack(
        children: [
          ListView.builder(
            controller: _scrollController,
            itemCount: receiptProvider.receipts.length + (receiptProvider.hasMoreData ? 1 : 0),
            itemBuilder: (context, index) {
              if (index < receiptProvider.receipts.length) {
                debugPrint('Building item at index: $index');
                return ReceiptCard(
                  receipt: receiptProvider.receipts[index],
                  index: index,
                );
              } else {
                // Show a loading indicator at the bottom while loading more data
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16.0),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
            },
          ),
          
          // Indicator when loading more data
          if (receiptProvider.isLoadingMore)
            const Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(),
            ),
        ],
      );
    }

    debugPrint('No receipts found');
    return const NoItems(errMsg: 'No receipts found.');
  }
}

class ReceiptDetailPage extends StatelessWidget {
  ReceiptDetailPage({
    super.key,
    required this.receipt,
  });

  final Receipt receipt;
  final moneyFormat = NumberFormat.currency(name: '', decimalDigits: 2);
  final TextStyle receiptTextStyle = const TextStyle(
    fontSize: 12.0,
  );

  void _launchUrl(BuildContext context, String path) async {
    bool canLaunch = !await canLaunchUrl(Uri.parse('https://verify.tra.go.tz/$path'));

    if (canLaunch) {
      if (!context.mounted) return;

      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            content: SingleChildScrollView(
              child: SizedBox(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Failed to open browser',
                      style: TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text('Close'),
              ),
            ],
          );
        },
      );
    } else {
      launchUrl(Uri.parse('https://verify.tra.go.tz/$path'));
    }
  }
  
  Future<void> _convertToSale(BuildContext context, Receipt receipt) async {
    // Show confirmation dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Convert to Sale'),
        content: Text('Do you want to convert this receipt from ${receipt.companyName} to a sale record?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('CONVERT'),
          ),
        ],
      ),
    ) ?? false;
    
    if (!confirm || !context.mounted) return;
    
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Text('Converting receipt to sale...'),
          ],
        ),
      ),
    );
    
    try {
      // Get the SalesProvider
      final salesProvider = Provider.of<SalesProvider>(context, listen: false);
      
      // Use the ReceiptToSaleService to convert the receipt
      final receiptToSaleService = ReceiptToSaleService();
      final response = await receiptToSaleService.convertReceiptToSale(receipt);
      
      // Close loading dialog
      if (context.mounted) {
        Navigator.of(context).pop();
      }
      
      if (response.success) {
        // Refresh the sales list
        salesProvider.fetchSales();
        
        // Show success message
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Receipt successfully converted to sale'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        // Show error message
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to convert receipt: ${response.errorMessage}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      // Close loading dialog
      if (context.mounted) {
        Navigator.of(context).pop();
        
        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error converting receipt: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          receipt.companyName,
          style: TextStyle(
            fontSize: MediaQuery.of(context).size.width * 0.042666,
          ),
        ),
        actions: [
          if (receipt.verificationCode != null)
            IconButton(
              onPressed: () => _launchUrl(
                context,
                "${receipt.verificationCode}_${receipt.time?.replaceAll(':', '')}",
              ),
              icon: const Icon(Icons.language),
              tooltip: 'Verify on TRA website',
            ),
          IconButton(
            onPressed: () => _convertToSale(context, receipt),
            icon: const Icon(Icons.shopping_cart),
            tooltip: 'Convert to sale',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCompanyHeader(),
            const SizedBox(height: 20),
            _buildCustomerInfo(),
            const SizedBox(height: 20),
            _buildReceiptInfo(),
            const SizedBox(height: 20),
            _buildItemsTable(),
            if (receipt.adjustments?.isNotEmpty ?? false) ...[
              const SizedBox(height: 20),
              Text('Invoice Adjustments', style: receiptTextStyle),
              _buildAdjustmentsTable(),
            ],
            if (receipt.payments?.isNotEmpty ?? false) ...[
              const SizedBox(height: 20),
              Text('Invoice Payments', style: receiptTextStyle),
              _buildPaymentsTable(),
            ],
            const SizedBox(height: 20),
            _buildTotalsTable(),
          ],
        ),
      ),
    );
  }

  Widget _buildCompanyHeader() {
    return Center(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            receipt.companyName,
            textAlign: TextAlign.center,
            style: receiptTextStyle,
          ),
          const SizedBox(height: 5),
          Text(
            receipt.poBox ?? '',
            textAlign: TextAlign.center,
            style: receiptTextStyle,
          ),
          const SizedBox(height: 5),
          Text(
            'MOBILE: ${receipt.mobile}',
            textAlign: TextAlign.center,
            style: receiptTextStyle,
          ),
          const SizedBox(height: 5),
          Text(
            'TIN: ${receipt.tin}',
            textAlign: TextAlign.center,
            style: receiptTextStyle,
          ),
          const SizedBox(height: 5),
          Text(
            'VRN: ${receipt.vrn}',
            textAlign: TextAlign.center,
            style: receiptTextStyle,
          ),
          const SizedBox(height: 5),
          Text(
            'SERIAL NO: ${receipt.serialNumber}',
            textAlign: TextAlign.center,
            style: receiptTextStyle,
          ),
          const SizedBox(height: 5),
          Text(
            'UIN: ${receipt.uin}',
            textAlign: TextAlign.center,
            style: receiptTextStyle,
          ),
          const SizedBox(height: 5),
          Text(
            'TAX OFFICE: ${receipt.taxOffice}',
            textAlign: TextAlign.center,
            style: receiptTextStyle,
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'CUSTOMER NAME: ${receipt.customer?.name ?? ''}',
          style: receiptTextStyle,
        ),
        const SizedBox(height: 5),
        Text(
          'CUSTOMER ID TYPE: ${receipt.customer?.idType ?? ''}',
          style: receiptTextStyle,
        ),
        const SizedBox(height: 5),
        Text(
          'CUSTOMER ID: ${receipt.customer?.id ?? ''}',
          style: receiptTextStyle,
        ),
        const SizedBox(height: 5),
        Text(
          'CUSTOMER MOBILE: ${receipt.customer?.mobile ?? 'n/a'}',
          style: receiptTextStyle,
        ),
      ],
    );
  }

  Widget _buildReceiptInfo() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('RECEIPT NO:', style: receiptTextStyle),
            Text(receipt.number ?? '', style: receiptTextStyle),
          ],
        ),
        const SizedBox(height: 5),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Z NUMBER:', style: receiptTextStyle),
            Text(receipt.zNumber ?? '', style: receiptTextStyle),
          ],
        ),
        const SizedBox(height: 5),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Text('DATE: ', style: receiptTextStyle),
                Text(receipt.date ?? '', style: receiptTextStyle),
              ],
            ),
            Row(
              children: [
                Text('TIME: ', style: receiptTextStyle),
                Text(receipt.time ?? '', style: receiptTextStyle),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildItemsTable() {
    return Table(
      columnWidths: const {
        0: FlexColumnWidth(3),
        1: FlexColumnWidth(1),
        2: FlexColumnWidth(2),
      },
      children: [
        TableRow(
          children: [
            Text('DESCRIPTION', style: receiptTextStyle),
            Text(
              'QTY',
              style: receiptTextStyle,
              textAlign: TextAlign.right,
            ),
            Text(
              'AMOUNT',
              style: receiptTextStyle,
              textAlign: TextAlign.right,
            ),
          ],
        ),
        if (receipt.items != null && receipt.items!.isNotEmpty)
          ...receipt.items!.map((item) => TableRow(
            children: [
              Text(item.description ?? '', style: receiptTextStyle),
              Text(
                '${item.quantity ?? 1}',
                style: receiptTextStyle,
                textAlign: TextAlign.right,
              ),
              Text(
                moneyFormat.format(item.amount ?? 0),
                style: receiptTextStyle,
                textAlign: TextAlign.right,
              ),
            ],
          )).toList(),
      ],
    );
  }

  Widget _buildTotalsTable() {
    return Table(
      children: [
        _buildTableRow('TOTAL EXCL OF TAX:', receipt.totalExlcOfTax),
        if (receipt.isTanesco) ...[
          if (receipt.kwhCharge != null && receipt.kwhCharge! > 0)
            _buildTableRow('KWH Charge:', receipt.kwhCharge),
          if (receipt.kvaCharge != null && receipt.kvaCharge! > 0)
            _buildTableRow('KVA Charge:', receipt.kvaCharge),
          if (receipt.serviceCharge != null && receipt.serviceCharge! > 0)
            _buildTableRow('Service Charge:', receipt.serviceCharge),
          if (receipt.interestAmount != null && receipt.interestAmount! > 0)
            _buildTableRow('Interest Amount:', receipt.interestAmount),
          if (receipt.taxRate != null)
            _buildTableRow('TAX RATE (${receipt.taxRate}%):', receipt.totalTax),
        ],
        _buildTableRow('TOTAL TAX:', receipt.totalTax),
        if (receipt.isTanesco) ...[
          if (receipt.reaCharge != null && receipt.reaCharge! > 0)
            _buildTableRow('REA:', receipt.reaCharge),
          if (receipt.ewuraCharge != null && receipt.ewuraCharge! > 0)
            _buildTableRow('EWURA:', receipt.ewuraCharge),
          if (receipt.propertyTax != null && receipt.propertyTax! > 0)
            _buildTableRow('Property Tax:', receipt.propertyTax),
        ],
        _buildTableRow('TOTAL INCL OF TAX:', receipt.totalInclOfTax),
      ],
    );
  }

  Widget _buildAdjustmentsTable() {
    return Table(
      columnWidths: const {
        0: FlexColumnWidth(1),
        1: FlexColumnWidth(2),
        2: FlexColumnWidth(1),
      },
      children: [
        TableRow(
          children: [
            Text('Type', style: receiptTextStyle),
            Text('Description', style: receiptTextStyle),
            Text(
              'Amount',
              style: receiptTextStyle,
              textAlign: TextAlign.right,
            ),
          ],
        ),
        ...receipt.adjustments!.map((adjustment) => TableRow(
          children: [
            Text(adjustment.type, style: receiptTextStyle),
            Text(adjustment.description, style: receiptTextStyle),
            Text(
              moneyFormat.format(adjustment.amount),
              style: receiptTextStyle,
              textAlign: TextAlign.right,
            ),
          ],
        )).toList(),
      ],
    );
  }

  Widget _buildPaymentsTable() {
    return Table(
      columnWidths: const {
        0: FlexColumnWidth(1),
        1: FlexColumnWidth(2),
        2: FlexColumnWidth(1),
      },
      children: [
        TableRow(
          children: [
            Text('Type', style: receiptTextStyle),
            Text('Description', style: receiptTextStyle),
            Text(
              'Amount',
              style: receiptTextStyle,
              textAlign: TextAlign.right,
            ),
          ],
        ),
        ...receipt.payments!.map((payment) => TableRow(
          children: [
            Text(payment.type, style: receiptTextStyle),
            Text(payment.description, style: receiptTextStyle),
            Text(
              moneyFormat.format(payment.amount),
              style: receiptTextStyle,
              textAlign: TextAlign.right,
            ),
          ],
        )).toList(),
      ],
    );
  }

  TableRow _buildTableRow(String label, double? value) {
    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 5),
          child: Text(label, style: receiptTextStyle),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 5),
          child: Text(
            value != null ? moneyFormat.format(value) : '-',
            style: receiptTextStyle,
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}

class ScanPage extends StatefulWidget {
  static String route = 'scan';

  const ScanPage({super.key});

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  MobileScannerController controller = MobileScannerController();
  bool frozen = false;

  bool receiptUrlFound = false;

  String errMsg = '';

  String _code = '';
  String _time = '';

  _handleReceiptScrapeFailed() async {
    setState(() {
      errMsg = '';
      receiptUrlFound = true;
    });

    await scrape(
      _code,
      _time,
      Provider.of<ReceiptProvider>(context, listen: false),
    );
  }

  _handleReceiptAlreadyExists() async {
    setState(() {
      errMsg = '';
      receiptUrlFound = false;
    });

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    var media = MediaQuery.of(context).size;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan'),
      ),
      body: SizedBox(
        height: media.height * 1,
        width: media.width * 1,
        child: Stack(
          children: [
            SizedBox(
              height: media.height * 1,
              width: media.width * 1,
              child: Column(
                children: [
                  Expanded(
                    flex: 5,
                    child: _buildQrView(context),
                  ),
                  Expanded(
                    flex: 1,
                    child: FittedBox(
                      fit: BoxFit.contain,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Container(
                                margin: const EdgeInsets.all(8),
                                child: IconButton(
                                  onPressed: () => controller.toggleTorch(),
                                  icon: ValueListenableBuilder(
                                    valueListenable: controller.torchState,
                                    builder: (context, state, child) {
                                      switch (state) {
                                        case TorchState.off:
                                          return const Icon(Icons.flash_off);
                                        case TorchState.on:
                                          return const Icon(Icons.flash_on);
                                      }
                                    },
                                  ),
                                ),
                              ),
                              Container(
                                margin: const EdgeInsets.all(8),
                                child: IconButton(
                                  onPressed: () => controller.switchCamera(),
                                  icon: ValueListenableBuilder(
                                    valueListenable: controller.cameraFacingState,
                                    builder: (context, state, child) {
                                      switch (state) {
                                        case CameraFacing.front:
                                          return const Icon(Icons.camera_front);
                                        case CameraFacing.back:
                                          return const Icon(Icons.camera_rear);
                                      }
                                    },
                                  ),
                                ),
                              ),
                            ],
                          )
                        ],
                      ),
                    ),
                  )
                ],
              ),
            ),
            receiptUrlFound
                ? Container(
              height: media.height * 1,
              width: media.width * 1,
              decoration: const BoxDecoration(
                color: Color.fromARGB(125, 0, 0, 0),
              ),
              child: Center(
                child: Container(
                  padding: EdgeInsets.all(media.width * 0.05),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(media.width * 0.04),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Please wait...'),
                      SizedBox(height: media.width * 0.05),
                      const CircularProgressIndicator(),
                    ],
                  ),
                ),
              ),
            )
                : const SizedBox(),
            errMsg.isNotEmpty
                ? Container(
              height: media.height * 1,
              width: media.width * 1,
              decoration: const BoxDecoration(
                color: Color.fromARGB(125, 0, 0, 0),
              ),
              child: Center(
                child: Container(
                  padding: EdgeInsets.all(media.width * 0.05),
                  width: media.width * 0.8,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(
                      media.width * 0.03,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(errMsg),
                      SizedBox(height: media.width * 0.05),
                      ElevatedButton(
                        onPressed: errMsg == 'Receipt already scanned!'
                            ? _handleReceiptAlreadyExists
                            : _handleReceiptScrapeFailed,
                        child: Text(errMsg == 'Receipt already scanned!'
                            ? 'Close'
                            : 'Try Again'),
                      ),
                    ],
                  ),
                ),
              ),
            )
                : const SizedBox(),
          ],
        ),
      ),
    );
  }

  Widget _buildQrView(BuildContext context) {
    return MobileScanner(
      key: qrKey,
      controller: controller,
      onDetect: (capture) async {
        if (capture.barcodes.isNotEmpty && capture.barcodes.first.rawValue != null) {
          try {
            var url = capture.barcodes.first.rawValue!;

            final splittted = url.split('/');
            final last = splittted.last;
            final lastSplitted = last.split('_');

            if (lastSplitted.length == 2) {
              await scrape(
                lastSplitted.first,
                lastSplitted.last,
                Provider.of<ReceiptProvider>(context, listen: false),
              );
            } else {
              setState(() {
                receiptUrlFound = false;
                errMsg = 'Receipt Incorrect';
              });
            }
          } catch (e) {
            setState(() {
              receiptUrlFound = false;
              errMsg = 'Receipt Incorrect';
            });
          }
        }
      },
    );
  }

  Future<void> scrape(String code, String time, ReceiptProvider receiptProvider) async {
    int retries = 3;

    // Check if receipt already exists
    if (receiptProvider.checkIfReceiptExists(code)) {
      setState(() {
        receiptUrlFound = false;
        errMsg = 'Receipt already scanned!';
      });
      return;
    }

    for (int i = 0; i < retries; i++) {
      try {
        setState(() {
          receiptUrlFound = true;
          _code = code;
          _time = time;
          errMsg = '';
        });

        print('Attempt ${i + 1} of $retries');
        print('Scraping receipt: code=$code, time=$time');

        // First request to scraping server
        http.Response response = await http.get(
          Uri.parse('${ApiConfig.scraperUrl}/receipt/$code/$time'),
          headers: {
            'Accept': 'application/json',
          },
        ).timeout(const Duration(seconds: 30));

        print('Response status: ${response.statusCode}');
        print('Response body: ${response.body}');

        if (response.statusCode == 200 && response.body.isNotEmpty) {
          dynamic responseBody = jsonDecode(response.body);

          // Validate required fields
          if (!validateRequiredFields(responseBody)) {
            print('Missing required fields, retrying...');
            if (i == retries - 1) {
              setState(() {
                receiptUrlFound = false;
                errMsg = 'Failed to get complete receipt data';
              });
              return;
            }
            continue;
          }

          print('Attempting to upload to Lemuru server...');

          // Second request to Lemuru server
          http.Response serverResponse = await http.post(
            Uri.parse(ApiConfig.addReceiptUrl),
            body: jsonEncode(responseBody),
            headers: {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
          ).timeout(const Duration(seconds: 30));

          print('Lemuru server response status: ${serverResponse.statusCode}');
          print('Lemuru server response body: ${serverResponse.body}');

          if (serverResponse.statusCode == 200) {
            setState(() {
              receiptUrlFound = false;
              _code = '';
              _time = '';
              errMsg = '';
            });

            if (mounted) {
              Navigator.of(context).pop();
            }
            return;
          } else {
            throw Exception('Failed to upload data to Lemuru servers: ${serverResponse.statusCode} - ${serverResponse.body}');
          }
        } else {
          throw Exception('TRA scrape failed: Status ${response.statusCode} - ${response.body}');
        }
      } on TimeoutException catch (e) {
        print('Timeout error during attempt ${i + 1}: $e');
        if (i == retries - 1) {
          setState(() {
            receiptUrlFound = false;
            errMsg = 'Request timed out. Please try again.';
          });
          return;
        }
      } on FormatException catch (e) {
        print('Format error during attempt ${i + 1}: $e');
        if (i == retries - 1) {
          setState(() {
            receiptUrlFound = false;
            errMsg = 'Invalid data format received. Please try again.';
          });
          return;
        }
      } catch (e, stackTrace) {
        print('Error during attempt ${i + 1}: $e');
        print('Stack trace: $stackTrace');

        if (i == retries - 1) {
          setState(() {
            receiptUrlFound = false;
            errMsg = e.toString();
          });
          return;
        }

        // Wait before retrying
        await Future.delayed(const Duration(seconds: 2));
      }
    }
  }

  bool validateRequiredFields(Map<String, dynamic> data) {
    final requiredFields = [
      'company_name',
      'tin',
      'vrn',
      'serial_no',
      'uin',
      'tax_office'
    ];

    final missingFields = requiredFields.where((field) =>
    data[field] == null || data[field].toString().isEmpty
    ).toList();

    if (missingFields.isNotEmpty) {
      print('Missing required fields: $missingFields');
      return false;
    }

    return true;
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }
}

class Receipt {
  int id;
  String companyName;
  String? poBox;
  String? mobile;
  String? tin;
  String? vrn;
  String? serialNumber;
  String? uin;
  String? taxOffice;
  String? date;
  String? time;
  String? number;
  String? zNumber;
  String? verificationCode;
  double? totalExlcOfTax;
  double? totalDiscount;
  double? totalTax;
  double? totalInclOfTax;

  // TANESCO specific fields
  double? kwhCharge;
  double? kvaCharge;
  double? serviceCharge;
  double? interestAmount;
  double? reaCharge;
  double? ewuraCharge;
  double? propertyTax;
  double? taxRate;
  List<InvoiceAdjustment>? adjustments;
  List<InvoicePayment>? payments;

  Customer? customer;
  List<Item>? items;

  bool get isTanesco =>
      companyName.toLowerCase().contains('tanzania electric supply') ||
          companyName.toLowerCase().contains('tanesco') ||
          kwhCharge != null;

  Receipt({
    required this.id,
    required this.companyName,
    this.poBox,
    this.mobile,
    this.tin,
    this.vrn,
    this.serialNumber,
    this.uin,
    this.taxOffice,
    this.date,
    this.time,
    this.number,
    this.zNumber,
    this.verificationCode,
    this.totalExlcOfTax,
    this.totalDiscount,
    this.totalTax,
    this.totalInclOfTax,
    this.kwhCharge,
    this.kvaCharge,
    this.serviceCharge,
    this.interestAmount,
    this.reaCharge,
    this.ewuraCharge,
    this.propertyTax,
    this.taxRate,
    this.adjustments,
    this.payments,
    this.customer,
    this.items,
  });

  factory Receipt.fromJson(Map<String, dynamic> json) {
    // Check if we're dealing with a simplified offline format
    if (json.containsKey('companyName') && !json.containsKey('receipt')) {
      // Using the simplified format we created for offline mode
      return Receipt(
        id: json['id'] ?? 0,
        companyName: json['companyName'] ?? 'Unknown Company',
        poBox: null,
        mobile: null,
        tin: null,
        vrn: null,
        serialNumber: null,
        uin: null,
        taxOffice: null,
        date: json['date'],
        time: json['time'],
        number: null,
        zNumber: null,
        verificationCode: json['id']?.toString(),
        totalExlcOfTax: double.tryParse(json['amount']?.toString() ?? '0') ?? 0,
        totalDiscount: 0,
        totalTax: 0,
        totalInclOfTax: double.tryParse(json['amount']?.toString() ?? '0') ?? 0,
        customer: Customer(
          name: '', 
          idType: '', 
          id: '', 
          mobile: ''
        ),
        items: [],
        adjustments: [],
        payments: [],
      );
    }
    
    // Helper function to safely parse double values
    double? parseDouble(dynamic value) {
      if (value == null) return null;
      if (value is num) return value.toDouble();
      if (value is String) {
        try {
          final cleanValue = value.replaceAll(',', '').trim();
          if (cleanValue.isEmpty) return null;
          return double.parse(cleanValue);
        } catch (e) {
          print('Error parsing double value: $value');
          return null;
        }
      }
      return null;
    }

    Customer customer = Customer.fromJson({
      'customer_name': json['customer_name'],
      'customer_id_type': json['customer_id_type'],
      'customer_id': json['customer_id'],
      'customer_mobile': json['customer_mobile'],
    });

    List<Item> items = [];
    if (json['items'] != null && json['items'] is List) {
      items = (json['items'] as List).map((item) {
        try {
          return Item.fromJson(item);
        } catch (e) {
          print('Error parsing item: $e');
          return null;
        }
      }).whereType<Item>().toList();
    }

    List<InvoiceAdjustment>? adjustments;
    if (json['adjustments'] != null && json['adjustments'] is List) {
      adjustments = (json['adjustments'] as List).map((adj) {
        try {
          return InvoiceAdjustment.fromJson(adj);
        } catch (e) {
          print('Error parsing adjustment: $e');
          return null;
        }
      }).whereType<InvoiceAdjustment>().toList();
    }

    List<InvoicePayment>? payments;
    if (json['payments'] != null && json['payments'] is List) {
      payments = (json['payments'] as List).map((payment) {
        try {
          return InvoicePayment.fromJson(payment);
        } catch (e) {
          print('Error parsing payment: $e');
          return null;
        }
      }).whereType<InvoicePayment>().toList();
    }

    return Receipt(
      id: json['id'],
      companyName: json['company_name'] ?? '',
      poBox: json['p_o_box'],
      mobile: json['mobile'],
      tin: json['tin'],
      vrn: json['vrn'],
      serialNumber: json['serial_no'],
      uin: json['uin'],
      taxOffice: json['tax_office'],
      date: json['receipt_date'],
      time: json['receipt_time'],
      number: json['receipt_number'],
      zNumber: json['receipt_z_number'],
      verificationCode: json['receipt_verification_code'],
      totalExlcOfTax: parseDouble(json['receipt_total_excl_of_tax']),
      totalDiscount: parseDouble(json['receipt_total_discount']),
      totalTax: parseDouble(json['receipt_total_tax']),
      totalInclOfTax: parseDouble(json['receipt_total_incl_of_tax']),
      // TANESCO specific fields
      kwhCharge: parseDouble(json['kwh_charge']),
      kvaCharge: parseDouble(json['kva_charge']),
      serviceCharge: parseDouble(json['service_charge']),
      interestAmount: parseDouble(json['interest_amount']),
      reaCharge: parseDouble(json['rea_charge'] ?? json['receipt_rea']),
      ewuraCharge: parseDouble(json['ewura_charge'] ?? json['receipt_ewura']),
      propertyTax: parseDouble(json['property_tax'] ?? json['receipt_property_tax']),
      taxRate: parseDouble(json['tax_rate']),
      adjustments: adjustments,
      payments: payments,
      customer: customer,
      items: items,
    );
  }
}

class InvoiceAdjustment {
  String type;
  String description;
  double amount;

  InvoiceAdjustment({
    required this.type,
    required this.description,
    required this.amount,
  });

  factory InvoiceAdjustment.fromJson(Map<String, dynamic> json) {
    return InvoiceAdjustment(
      type: json['type'] ?? 'ADJUSTMENT',
      description: json['description'] ?? '',
      amount: double.parse(json['amount']?.toString() ?? '0'),
    );
  }
}

class InvoicePayment {
  String type;
  String description;
  double amount;

  InvoicePayment({
    required this.type,
    required this.description,
    required this.amount,
  });

  factory InvoicePayment.fromJson(Map<String, dynamic> json) {
    return InvoicePayment(
      type: json['type'] ?? 'PAYMENT',
      description: json['description'] ?? '',
      amount: double.parse(json['amount']?.toString() ?? '0'),
    );
  }
}

class Customer {
  String? name;
  String? idType;
  String? id;
  String? mobile;

  Customer({
    this.name,
    this.idType,
    this.id,
    this.mobile,
  });

  factory Customer.fromJson(Map<String, dynamic> json) {
    return Customer(
      name: json['customer_name'],
      idType: json['customer_id_type'],
      id: json['customer_id'],
      mobile: json['customer_mobile'],
    );
  }
}

class Item {
  String? description;
  int? quantity;
  double? amount;

  Item({
    this.description,
    this.quantity,
    this.amount,
  });

  factory Item.fromJson(Map<String, dynamic> json) {
    return Item(
      description: json['description'] ?? json['item_description'],
      quantity: json['qty'] ?? json['item_qty'] ?? 1,
      amount: double.tryParse(json['amount']?.toString() ?? json['item_amount']?.toString() ?? '0'),
    );
  }
}

class ReceiptProvider extends ChangeNotifier {
  List<Receipt> _receipts = [];
  APIRequestStatus _apiRequestStatus = APIRequestStatus.loading;
  String _lastError = '';
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMoreData = true;
  int _currentPage = 1;
  
  List<Receipt> get receipts => _receipts;
  APIRequestStatus get apiRequestStatus => _apiRequestStatus;
  String get lastError => _lastError;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore; 
  bool get hasMoreData => _hasMoreData;

  ReceiptProvider() {
    debugPrint('ReceiptProvider initialized');
    // We'll fetch receipts from the MyHomePage instead to avoid duplicate calls
  }

  Future<void> fetchReceipts({DateTime? startDate, DateTime? endDate, String? searchTerm}) async {
    debugPrint('Starting fetchReceipts()');
    _apiRequestStatus = APIRequestStatus.loading;
    _isLoading = true;
    _currentPage = 1;
    _hasMoreData = true;
    notifyListeners();

    try {
      // Check for offline mode first
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      final offlineData = prefs.getString('offline_receipts');
      
      // Check if we're in offline mode (token starts with 'offline_')
      if (token != null && token.startsWith('offline_') && offlineData != null) {
        debugPrint('Using offline data instead of API call');
        
        // Simulate a delay to mimic network call
        await Future.delayed(const Duration(milliseconds: 500));
        
        // Parse the offline data
        final List<dynamic> responseBody = jsonDecode(offlineData);
        
        // Apply filtering if any
        List<dynamic> filteredData = responseBody;
        
        if (searchTerm != null && searchTerm.isNotEmpty) {
          final searchLower = searchTerm.toLowerCase();
          filteredData = filteredData.where((item) => 
            item['companyName'].toString().toLowerCase().contains(searchLower)
          ).toList();
        }
        
        if (startDate != null && endDate != null) {
          filteredData = filteredData.where((item) {
            final itemDate = DateTime.parse(item['date']);
            return itemDate.isAfter(startDate.subtract(const Duration(days: 1))) && 
                   itemDate.isBefore(endDate.add(const Duration(days: 1)));
          }).toList();
        }
        
        List<Receipt> nwReceipts = getReceiptsFromJson(filteredData);
        debugPrint('Successfully parsed ${nwReceipts.length} offline receipts');
        
        _receipts = nwReceipts;
        _apiRequestStatus = APIRequestStatus.loaded;
        _hasMoreData = false; // No more data in offline mode
        _lastError = '';
        
        return;
      }
      
      // If not in offline mode, proceed with regular API call
      String url = '${ApiConfig.receiptsUrl}?page=$_currentPage';
      
      if (startDate != null && endDate != null) {
        final startDateStr = DateFormat('yyyy-MM-dd').format(startDate);
        final endDateStr = DateFormat('yyyy-MM-dd').format(endDate);
        url += '&start_date=$startDateStr&end_date=$endDateStr';
      }
      
      if (searchTerm != null && searchTerm.isNotEmpty) {
        url += '&search=$searchTerm';
      }
      
      debugPrint('Attempting API call to: $url');
      
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Accept': 'application/json',
          'Authorization': token != null ? 'Bearer $token' : '',
        },
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          debugPrint('API call timed out after 30 seconds');
          throw TimeoutException('Request timed out');
        },
      );

      debugPrint('API Response Status Code: ${response.statusCode}');

      if (response.statusCode == 200) {
        Map<String, dynamic> jsonResponse = jsonDecode(response.body);
        List<dynamic> responseBody = jsonResponse['receipts']['data'] as List<dynamic>;
        debugPrint('Successfully decoded JSON. Number of items: ${responseBody.length}');

        // Check if there are more pages
        final meta = jsonResponse['receipts']['meta'];
        _hasMoreData = meta != null && 
            meta['current_page'] < meta['last_page'] && 
            responseBody.isNotEmpty;
        
        List<Receipt> nwReceipts = getReceiptsFromJson(responseBody);
        debugPrint('Successfully parsed ${nwReceipts.length} receipts');

        _receipts = nwReceipts;
        _apiRequestStatus = APIRequestStatus.loaded;
        _lastError = '';
      } else if (response.statusCode == 401) {
        // Handle unauthorized access - redirect to login
        _lastError = 'Unauthorized access. Please login again.';
        _apiRequestStatus = APIRequestStatus.error;
        
        // Clear login info
        await prefs.clear();
      } else {
        _lastError = 'Server returned ${response.statusCode}: ${response.body}';
        debugPrint('API Error: $_lastError');
        _apiRequestStatus = APIRequestStatus.error;
      }
    } on SocketException catch (e) {
      _lastError = 'Network error: ${e.message}';
      debugPrint('SocketException: $_lastError');
      _apiRequestStatus = APIRequestStatus.networkError;
    } on TimeoutException catch (e) {
      _lastError = 'Request timed out: ${e.message}';
      debugPrint('TimeoutException: $_lastError');
      _apiRequestStatus = APIRequestStatus.networkError;
    } on FormatException catch (e) {
      _lastError = 'Data format error: ${e.message}';
      debugPrint('FormatException: $_lastError');
      _apiRequestStatus = APIRequestStatus.error;
    } catch (e, stackTrace) {
      _lastError = 'Unexpected error: $e';
      debugPrint('Unexpected error: $e');
      debugPrint('Stack trace: $stackTrace');
      _apiRequestStatus = APIRequestStatus.error;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  Future<void> loadMoreReceipts({DateTime? startDate, DateTime? endDate, String? searchTerm}) async {
    if (_isLoadingMore || !_hasMoreData) return;
    
    debugPrint('Loading more receipts, page: ${_currentPage + 1}');
    _isLoadingMore = true;
    notifyListeners();
    
    try {
      // Check for offline mode first
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      
      // If in offline mode, we don't have pagination, so just return
      if (token != null && token.startsWith('offline_')) {
        debugPrint('In offline mode - no more data to load');
        _isLoadingMore = false;
        _hasMoreData = false;
        notifyListeners();
        return;
      }
      
      // Build the URL with query parameters for filtering
      String url = '${ApiConfig.receiptsUrl}?page=${_currentPage + 1}';
      
      if (startDate != null && endDate != null) {
        final startDateStr = DateFormat('yyyy-MM-dd').format(startDate);
        final endDateStr = DateFormat('yyyy-MM-dd').format(endDate);
        url += '&start_date=$startDateStr&end_date=$endDateStr';
      }
      
      if (searchTerm != null && searchTerm.isNotEmpty) {
        url += '&search=$searchTerm';
      }
      
      debugPrint('Loading more - API call to: $url');
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Accept': 'application/json',
          'Authorization': token != null ? 'Bearer $token' : '',
        },
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        Map<String, dynamic> jsonResponse = jsonDecode(response.body);
        List<dynamic> responseBody = jsonResponse['receipts']['data'] as List<dynamic>;
        
        // Check if there are more pages
        final meta = jsonResponse['receipts']['meta'];
        _hasMoreData = meta != null && 
            meta['current_page'] < meta['last_page'] && 
            responseBody.isNotEmpty;
            
        // Update current page
        _currentPage++;
        
        if (responseBody.isNotEmpty) {
          List<Receipt> newReceipts = getReceiptsFromJson(responseBody);
          _receipts.addAll(newReceipts);
          debugPrint('Added ${newReceipts.length} more receipts. Total: ${_receipts.length}');
        } else {
          _hasMoreData = false;
          debugPrint('No more receipts to load');
        }
      } else {
        debugPrint('Error loading more: ${response.statusCode}');
        // Don't update _lastError here - we don't want to show an error message
        // for pagination, just stop loading more
        _hasMoreData = false;
      }
    } catch (e) {
      debugPrint('Error loading more: $e');
      _hasMoreData = false;
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  bool checkIfReceiptExists(String code) {
    debugPrint('Checking for receipt with code: $code');
    var receipts = _receipts.where((receipt) => receipt.verificationCode == code);
    bool exists = receipts.isNotEmpty;
    debugPrint('Receipt exists: $exists');
    return exists;
  }

  List<Receipt> getReceiptsFromJson(List<dynamic> json) {
    debugPrint('Starting to parse ${json.length} receipts');
    List<Receipt> parsedReceipts = [];

    for (var i = 0; i < json.length; i++) {
      try {
        var receipt = Receipt.fromJson(json[i]);
        parsedReceipts.add(receipt);
      } catch (e) {
        debugPrint('Error parsing receipt at index $i: $e');
        debugPrint('Problematic JSON: ${json[i]}');
      }
    }

    debugPrint('Successfully parsed ${parsedReceipts.length} out of ${json.length} receipts');
    return parsedReceipts;
  }
}

class BodyBuilder extends StatelessWidget {
  const BodyBuilder({
    Key? key,
    required this.apiRequestStatus,
    required this.body,
    required this.onRefresh,
  }) : super(key: key);

  final APIRequestStatus apiRequestStatus;
  final Widget body;
  final Function onRefresh;

  @override
  Widget build(BuildContext context) {
    Widget child;

    switch (apiRequestStatus) {
      case APIRequestStatus.loading:
        child = const Center(
          child: CircularProgressIndicator(),
        );
        break;
      case APIRequestStatus.loaded:
        child = RefreshIndicator(
          onRefresh: () => onRefresh(),
          child: body,
        );
        break;
      case APIRequestStatus.error:
      case APIRequestStatus.networkError:
        child = ErrorWidget(
          apiRequestStatus: apiRequestStatus,
          onRefresh: onRefresh,
        );
        break;
    }

    return child;
  }
}

class ErrorWidget extends StatelessWidget {
  const ErrorWidget({
    Key? key,
    required this.apiRequestStatus,
    required this.onRefresh,
  }) : super(key: key);

  final APIRequestStatus apiRequestStatus;
  final Function onRefresh;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            getMessage(apiRequestStatus),
            style: Theme.of(context).textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          ElevatedButton(
            onPressed: () => onRefresh(),
            child: const Text('Try again'),
          ),
        ],
      ),
    );
  }

  String getMessage(APIRequestStatus apiRequestStatus) {
    String message = '';

    if (apiRequestStatus == APIRequestStatus.error) {
      message = 'This page cannot be loaded right now\n Try again.';
    } else if (apiRequestStatus == APIRequestStatus.networkError) {
      message = 'Check your internet connection.';
    }

    return message;
  }
}