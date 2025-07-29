import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_receipt_scanner/config/api_config.dart';
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
import 'package:network_info_plus/network_info_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:math' show min;

// Moved ApiConfig to separate file: lib/config/api_config.dart

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
        // Prevent scanning if we're already processing a receipt
        if (_isScanning) {
          return;
        }
        
        if (capture.barcodes.isNotEmpty && capture.barcodes.first.rawValue != null) {
          try {
            var url = capture.barcodes.first.rawValue!;
            debugPrint('Scanned QR code: $url');

            // Pause scanning while processing
            controller.stop();

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
                errMsg = 'Receipt format incorrect. Please scan a valid TRA receipt.';
              });
            }
            
            // Resume scanning after processing is complete
            if (mounted) {
              controller.start();
            }
          } catch (e) {
            debugPrint('Error processing QR code: $e');
            setState(() {
              receiptUrlFound = false;
              errMsg = 'Receipt format incorrect. Please scan a valid TRA receipt.';
            });
            
            // Resume scanning after error
            if (mounted) {
              controller.start();
            }
          }
        }
      },
    );
  }

  // Flag to prevent multiple concurrent scans of the same QR code
  bool _isScanning = false;
  
  Future<void> scrape(String code, String time, ReceiptProvider receiptProvider) async {
    // Prevent multiple concurrent scanning attempts for the same code
    if (_isScanning) {
      debugPrint('Already scanning a receipt. Ignoring this scan.');
      return;
    }
    
    _isScanning = true;
    int retries = 3;

    try {
      // Check if receipt already exists
      if (receiptProvider.checkIfReceiptExists(code)) {
        setState(() {
          receiptUrlFound = false;
          errMsg = 'Receipt already scanned!';
        });
        return;
      }

      print('🚀 [SCAN] Starting receipt scanning process');
      print('🚀 [SCAN] QR Code: $code, Time: $time');
      print('🚀 [SCAN] Max retries: $retries');

      final scanStartTime = DateTime.now();

      for (int i = 0; i < retries; i++) {
        _logProcessingStatus('started', attempt: i + 1, totalAttempts: retries);
        try {
          setState(() {
            receiptUrlFound = true;
            _code = code;
            _time = time;
            errMsg = '';
          });

          print('🔄 [SCAN] === ATTEMPT ${i + 1}/$retries ===');
          print('🔄 [SCAN] Scraping receipt: code=$code, time=$time');
          
          final requestStartTime = DateTime.now();

          // Use direct TRA verification website instead of custom scraper
          // This should be more reliable since it goes directly to the source
          http.Response response;
          
          if (ApiConfig.useDirectScraping) {
            // Use the TRA direct verification page
            final directUrl = '${await ApiConfig.effectiveScraperUrl}/${code}_${time}';
            debugPrint('Using direct TRA verification URL: $directUrl');
            
            response = await http.get(
              Uri.parse(directUrl),
              headers: {
                'Accept': '*/*',
                'User-Agent': 'Mozilla/5.0 Lemuru Receipt Scanner App',
              },
            ).timeout(Duration(seconds: ApiConfig.connectionTimeout));
            
            // For direct TRA site, we need to parse the HTML response
            if (response.statusCode == 200) {
              // Create simple JSON with basic receipt info extracted from HTML
              final html = response.body;
              final responseBody = _extractReceiptDataFromHtml(html, code, time);
              
              // Continue with this parsed data
              response = http.Response(
                jsonEncode(responseBody),
                200,
                headers: {'content-type': 'application/json'},
              );
            }
          } else {
            // Try the local scraper service
            final scraperUrl = await ApiConfig.scraperUrl;
            debugPrint('Using local scraper: $scraperUrl/receipt/$code/$time');
            response = await http.get(
              Uri.parse('$scraperUrl/receipt/$code/$time'),
              headers: {
                'Accept': 'application/json',
              },
            ).timeout(Duration(seconds: ApiConfig.connectionTimeout));
          }

          final requestDuration = DateTime.now().difference(requestStartTime);
          print('📡 [SCAN] Response received in ${requestDuration.inMilliseconds}ms');
          print('📡 [SCAN] Response status: ${response.statusCode}');
          print('📡 [SCAN] Response body length: ${response.body.length} characters');

          if (response.statusCode == 200 && response.body.isNotEmpty) {
            print('✅ [SCAN] Valid response received, parsing JSON...');
            
            dynamic responseBody;
            try {
              responseBody = jsonDecode(response.body);
              print('✅ [SCAN] JSON parsed successfully');
              print('📋 [SCAN] Response data type: ${responseBody.runtimeType}');
            } catch (e) {
              print('❌ [SCAN] JSON parsing error: $e');
              final truncatedRaw = response.body.length > 200 
                  ? '${response.body.substring(0, 200)}...' 
                  : response.body;
              print('📄 [SCAN] Raw response: $truncatedRaw');
              continue;
            }

            // Log response data summary
            if (responseBody is Map<String, dynamic>) {
              print('📋 [SCAN] Response contains ${responseBody.keys.length} fields');
              print('📋 [SCAN] Company: ${responseBody['company_name'] ?? 'N/A'}');
              print('📋 [SCAN] Receipt: ${responseBody['receipt_number'] ?? 'N/A'}');
              print('📋 [SCAN] Amount: ${responseBody['receipt_total_incl_of_tax'] ?? 'N/A'}');
            }

            // Validate required fields
            print('🔍 [SCAN] Starting field validation...');
            _logProcessingStatus('validating', attempt: i + 1, totalAttempts: retries);
            if (!validateRequiredFields(responseBody)) {
              print('❌ [SCAN] Validation failed - retrying attempt ${i + 1}/$retries');
              if (i == retries - 1) {
                print('💀 [SCAN] Max retries reached - giving up');
                _logProcessingStatus('failed', details: 'Field validation failed after $retries attempts', attempt: i + 1, totalAttempts: retries);
                setState(() {
                  receiptUrlFound = false;
                  errMsg = 'Failed to get complete receipt data after $retries attempts';
                });
                return;
              }
              _logProcessingStatus('retrying', details: 'Field validation failed', attempt: i + 1, totalAttempts: retries);
              continue;
            }

            print('✅ [SCAN] Field validation passed!');

            // Upload to server section
            print('🚀 [SCAN] Starting server upload process...');
            _logProcessingStatus('uploading', attempt: i + 1, totalAttempts: retries);
            final uploadStartTime = DateTime.now();
            final serverUrl = await ApiConfig.addReceiptUrl;
            print('📡 [SCAN] Target server URL: $serverUrl');
            print('📦 [SCAN] Payload size: ${jsonEncode(responseBody).length} bytes');

            // Second request to Lemuru server with shorter timeout
            http.Response serverResponse;
            try {
              print('⏳ [SCAN] Sending POST request to server...');
              serverResponse = await http.post(
                Uri.parse(serverUrl),
                body: jsonEncode(responseBody),
                headers: {
                  'Accept': 'application/json',
                  'Content-Type': 'application/json',
                },
              ).timeout(Duration(seconds: ApiConfig.connectionTimeout));
              
              final uploadDuration = DateTime.now().difference(uploadStartTime);
              print('📡 [SCAN] Server response received in ${uploadDuration.inMilliseconds}ms');
              
            } catch (e) {
              // If the server request fails, create a fallback local response
              // This allows the app to continue working even if the server is down
              final uploadDuration = DateTime.now().difference(uploadStartTime);
              print('❌ [SCAN] Server request failed after ${uploadDuration.inMilliseconds}ms: $e');
              print('💾 [SCAN] Attempting local storage fallback...');
              
              // Add receipt to local storage instead
              final success = await _addReceiptToLocalStorage(responseBody);
              
              if (success) {
                print('✅ [SCAN] Receipt saved to local storage successfully');
                serverResponse = http.Response(
                  jsonEncode({'success': true, 'message': 'Receipt saved locally'}),
                  200,
                  headers: {'content-type': 'application/json'},
                );
              } else {
                print('❌ [SCAN] Local storage save failed');
                throw Exception('Failed to save receipt locally');
              }
            }

          print('📊 [SCAN] Server response status: ${serverResponse.statusCode}');
          print('📊 [SCAN] Server response body length: ${serverResponse.body.length} characters');
          if (serverResponse.body.length < 500) {
            print('📄 [SCAN] Server response: ${serverResponse.body}');
          } else {
            final truncatedServerResponse = serverResponse.body.length > 200 
                ? '${serverResponse.body.substring(0, 200)}...' 
                : serverResponse.body;
            print('📄 [SCAN] Server response (truncated): $truncatedServerResponse');
          }

          if (serverResponse.statusCode == 200) {
            print('🎉 [SCAN] Receipt processing completed successfully!');
            print('🎉 [SCAN] Scan attempt ${i + 1} succeeded');
            _logProcessingStatus('success', attempt: i + 1, totalAttempts: retries);
            
            setState(() {
              receiptUrlFound = false;
              _code = '';
              _time = '';
              errMsg = '';
            });

            if (mounted) {
              print('🏠 [SCAN] Navigating back to previous screen');
              Navigator.of(context).pop();
            }
            
            final totalProcessingTime = DateTime.now().difference(scanStartTime);
            print('⏱️ [SCAN] Total processing time: ${totalProcessingTime.inMilliseconds}ms');
            print('✅ [SCAN] Receipt scan workflow completed successfully!');
            
            // Log performance metrics
            _logPerformanceMetrics(scanStartTime, i + 1, true);
            return;
          } else {
            print('❌ [SCAN] Server upload failed with status ${serverResponse.statusCode}');
            print('❌ [SCAN] Server error response: ${serverResponse.body}');
            throw Exception('Failed to upload data to Lemuru servers: ${serverResponse.statusCode} - ${serverResponse.body}');
          }
        } else {
          print('❌ [SCAN] TRA scrape failed with status ${response.statusCode}');
          final truncatedBody = response.body.length > 200 
              ? '${response.body.substring(0, 200)}...' 
              : response.body;
          print('❌ [SCAN] TRA error response: $truncatedBody');
          throw Exception('TRA scrape failed: Status ${response.statusCode} - ${response.body}');
        }
      } on TimeoutException catch (e) {
        print('⏰ [SCAN] Timeout error on attempt ${i + 1}/$retries: $e');
        if (i == retries - 1) {
          print('💀 [SCAN] Max retries reached - timeout failure');
          _logPerformanceMetrics(scanStartTime, i + 1, false, failureReason: 'Timeout after $retries attempts');
          setState(() {
            receiptUrlFound = false;
            errMsg = 'Request timed out. Please try again.';
          });
          return;
        }
        print('🔄 [SCAN] Waiting 1 second before retry...');
        // Wait before retrying
        await Future.delayed(const Duration(seconds: 1));
      } on FormatException catch (e) {
        print('🔧 [SCAN] Format error on attempt ${i + 1}/$retries: $e');
        if (i == retries - 1) {
          print('💀 [SCAN] Max retries reached - format error');
          _logPerformanceMetrics(scanStartTime, i + 1, false, failureReason: 'Format error after $retries attempts');
          setState(() {
            receiptUrlFound = false;
            errMsg = 'Invalid data format received. Please try again.';
          });
          return;
        }
        print('🔄 [SCAN] Waiting 1 second before retry...');
        // Wait before retrying
        await Future.delayed(const Duration(seconds: 1));
      } catch (e, stackTrace) {
        print('💥 [SCAN] Unexpected error on attempt ${i + 1}/$retries: $e');
        debugPrint('Stack trace: $stackTrace');

        if (i == retries - 1) {
          print('💀 [SCAN] Max retries reached - unexpected error');
          final totalTime = DateTime.now().difference(scanStartTime);
          print('⏱️ [SCAN] Total failed processing time: ${totalTime.inMilliseconds}ms');
          _logPerformanceMetrics(scanStartTime, i + 1, false, failureReason: 'Unexpected error: $e');
          setState(() {
            receiptUrlFound = false;
            errMsg = 'Error processing receipt. Please try again.';
          });
          return;
        }

        print('🔄 [SCAN] Waiting 1 second before retry...');
        // Wait before retrying
        await Future.delayed(const Duration(seconds: 1));
      }
    }
    } finally {
      // Reset scanning flag to allow future scans
      _isScanning = false;
      print('🏁 [SCAN] Scanning process finalized, flag reset');
    }
  }

  // Parse HTML from TRA website to extract receipt data
  Map<String, dynamic> _extractReceiptDataFromHtml(String html, String code, String time) {
    // Create a basic receipt data structure
    final Map<String, dynamic> receiptData = {
      'company_name': 'Unknown Merchant',
      'tin': 'Unknown',
      'vrn': 'Unknown',
      'serial_no': 'Unknown',
      'uin': code,
      'tax_office': 'Tanzania',
      'receipt_date': DateTime.now().toString().split(' ')[0],
      'receipt_time': time.substring(0, 2) + ":" + time.substring(2, 4) + ":" + time.substring(4, 6),
      'receipt_verification_code': code,
      'receipt_total_excl_of_tax': 0.0,
      'receipt_total_tax': 0.0,
      'receipt_total_incl_of_tax': 0.0,
    };
    
    try {
      // Extract basic information from the HTML response
      // This is a simplified extraction - in real implementation we would use a proper HTML parser
      if (html.contains('<div class="receipt">')) {
        // Extract company name
        final companyNameRegex = RegExp(r'<h3[^>]*>(.*?)</h3>', dotAll: true);
        final companyNameMatch = companyNameRegex.firstMatch(html);
        if (companyNameMatch != null && companyNameMatch.groupCount >= 1) {
          receiptData['company_name'] = companyNameMatch.group(1)?.trim() ?? 'Unknown Merchant';
        }
        
        // Extract TIN
        final tinRegex = RegExp(r'TIN\s*:\s*(\d+)', caseSensitive: false);
        final tinMatch = tinRegex.firstMatch(html);
        if (tinMatch != null && tinMatch.groupCount >= 1) {
          receiptData['tin'] = tinMatch.group(1) ?? 'Unknown';
        }
        
        // Extract VRN
        final vrnRegex = RegExp(r'VRN\s*:\s*(\d+)', caseSensitive: false);
        final vrnMatch = vrnRegex.firstMatch(html);
        if (vrnMatch != null && vrnMatch.groupCount >= 1) {
          receiptData['vrn'] = vrnMatch.group(1) ?? 'Unknown';
        }
        
        // Extract amount (total)
        final amountRegex = RegExp(r'TOTAL\s*:\s*TZS\s*([\d,\.]+)', caseSensitive: false);
        final amountMatch = amountRegex.firstMatch(html);
        if (amountMatch != null && amountMatch.groupCount >= 1) {
          final amountStr = amountMatch.group(1)?.replaceAll(',', '') ?? '0';
          final amount = double.tryParse(amountStr) ?? 0.0;
          
          // Set total amounts
          receiptData['receipt_total_incl_of_tax'] = amount;
          // Assume 18% VAT for simplicity
          final taxAmount = amount * 0.18 / 1.18;
          final exclAmount = amount - taxAmount;
          
          receiptData['receipt_total_tax'] = taxAmount;
          receiptData['receipt_total_excl_of_tax'] = exclAmount;
        }
        
        // Extract serial number
        final serialRegex = RegExp(r'SERIAL\s*NO\s*:\s*([A-Za-z0-9-]+)', caseSensitive: false);
        final serialMatch = serialRegex.firstMatch(html);
        if (serialMatch != null && serialMatch.groupCount >= 1) {
          receiptData['serial_no'] = serialMatch.group(1) ?? 'Unknown';
        }
      }
    } catch (e) {
      debugPrint('Error parsing HTML: $e');
    }
    
    debugPrint('Extracted receipt data: $receiptData');
    return receiptData;
  }
  
  // Add receipt to local storage when server is unreachable
  Future<bool> _addReceiptToLocalStorage(Map<String, dynamic> receiptData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final offlineReceiptsJson = prefs.getString('offline_receipts') ?? '[]';
      
      List<dynamic> offlineReceipts = jsonDecode(offlineReceiptsJson);
      
      // Generate a new ID
      int newId = 1;
      if (offlineReceipts.isNotEmpty) {
        final maxId = offlineReceipts.map<int>((r) => r['id'] as int? ?? 0).reduce(
          (max, id) => id > max ? id : max
        );
        newId = maxId + 1;
      }
      
      // Add ID to receipt data
      receiptData['id'] = newId;
      
      // Add timestamp if not present
      if (!receiptData.containsKey('date')) {
        receiptData['date'] = DateFormat('yyyy-MM-dd').format(DateTime.now());
      }
      if (!receiptData.containsKey('time')) {
        receiptData['time'] = DateFormat('HH:mm').format(DateTime.now());
      }
      
      // Add to list and save
      offlineReceipts.add(receiptData);
      await prefs.setString('offline_receipts', jsonEncode(offlineReceipts));
      
      debugPrint('Receipt saved to local storage with ID: $newId');
      return true;
    } catch (e) {
      debugPrint('Error adding receipt to local storage: $e');
      return false;
    }
  }
  
  bool validateRequiredFields(Map<String, dynamic> data) {
    print('🔍 [SCAN] Starting receipt validation...');
    print('🔍 [SCAN] useDirectScraping: ${ApiConfig.useDirectScraping}');
    print('🔍 [SCAN] Received data keys: ${data.keys.toList()}');
    
    // More permissive validation for TRA direct scraping
    if (ApiConfig.useDirectScraping) {
      print('🔍 [SCAN] Using DIRECT TRA scraping validation');
      
      // For direct TRA scraping, we have a simplified data structure
      // with fewer required fields
      final basicRequiredFields = [
        'company_name',
        'uin',
        'receipt_total_incl_of_tax'
      ];
      
      print('🔍 [SCAN] Checking basic required fields: $basicRequiredFields');
      
      final missingFields = basicRequiredFields.where((field) =>
        data[field] == null || data[field].toString().isEmpty
      ).toList();
      
      final presentFields = basicRequiredFields.where((field) =>
        data[field] != null && data[field].toString().isNotEmpty
      ).toList();
      
      print('🔍 [SCAN] Present fields: $presentFields');
      
      if (missingFields.isNotEmpty) {
        print('❌ [SCAN] Missing basic required fields: $missingFields');
        _logFieldValues(data, basicRequiredFields);
        return false;
      }
      
      print('✅ [SCAN] All basic required fields present');
      return true;
    }
    
    print('🔍 [SCAN] Using CUSTOM scraper validation');
    
    // Original, more strict validation for the custom scraper
    final requiredFields = [
      'company_name',
      'tin',
      'vrn',
      'serial_no',
      'uin',
      'tax_office'
    ];

    print('🔍 [SCAN] Checking required fields: $requiredFields');

    final missingFields = requiredFields.where((field) =>
      data[field] == null || data[field].toString().isEmpty
    ).toList();

    final presentFields = requiredFields.where((field) =>
      data[field] != null && data[field].toString().isNotEmpty
    ).toList();
    
    print('🔍 [SCAN] Present fields: $presentFields');

    if (missingFields.isNotEmpty) {
      print('❌ [SCAN] Missing required fields: $missingFields');
      _logFieldValues(data, requiredFields);
      return false;
    }

    print('✅ [SCAN] All required fields present');
    return true;
  }

  void _logPerformanceMetrics(DateTime startTime, int attempts, bool success, {String? failureReason}) {
    final totalDuration = DateTime.now().difference(startTime);
    final avgTimePerAttempt = attempts > 0 ? totalDuration.inMilliseconds / attempts : 0;
    
    print('📊 [SCAN] ========== PERFORMANCE METRICS ==========');
    print('📊 [SCAN] Total processing time: ${totalDuration.inMilliseconds}ms (${totalDuration.inSeconds}s)');
    print('📊 [SCAN] Number of attempts: $attempts');
    print('📊 [SCAN] Average time per attempt: ${avgTimePerAttempt.toStringAsFixed(0)}ms');
    print('📊 [SCAN] Success rate: ${success ? '100%' : '0%'} (${success ? 'SUCCESS' : 'FAILED'})');
    
    if (!success && failureReason != null) {
      print('📊 [SCAN] Failure reason: $failureReason');
    }
    
    // Performance analysis
    if (totalDuration.inSeconds > 30) {
      print('⚠️ [SCAN] SLOW: Processing took over 30 seconds');
    } else if (totalDuration.inSeconds > 10) {
      print('⚠️ [SCAN] MODERATE: Processing took over 10 seconds');
    } else {
      print('✅ [SCAN] FAST: Processing completed in under 10 seconds');
    }
    
    if (attempts > 1) {
      print('🔄 [SCAN] Multiple attempts required (${attempts} total)');
    } else {
      print('🎯 [SCAN] Single attempt success');
    }
    
    print('📊 [SCAN] =========================================');
  }

  void _logProcessingStatus(String status, {String? details, int? attempt, int? totalAttempts}) {
    final timestamp = DateTime.now().toIso8601String().split('T')[1].split('.')[0];
    final attemptInfo = (attempt != null && totalAttempts != null) 
        ? ' (Attempt $attempt/$totalAttempts)' 
        : '';
    
    switch (status.toLowerCase()) {
      case 'started':
        print('🚀 [SCAN] [$timestamp] Processing STARTED$attemptInfo');
        break;
      case 'extracting':
        print('🔍 [SCAN] [$timestamp] EXTRACTING data from TRA$attemptInfo');
        break;
      case 'validating':
        print('✅ [SCAN] [$timestamp] VALIDATING receipt fields$attemptInfo');
        break;
      case 'uploading':
        print('📤 [SCAN] [$timestamp] UPLOADING to server$attemptInfo');
        break;
      case 'success':
        print('🎉 [SCAN] [$timestamp] Processing COMPLETED successfully$attemptInfo');
        break;
      case 'failed':
        print('❌ [SCAN] [$timestamp] Processing FAILED$attemptInfo');
        break;
      case 'retrying':
        print('🔄 [SCAN] [$timestamp] RETRYING after error$attemptInfo');
        break;
      default:
        print('📋 [SCAN] [$timestamp] Status: ${status.toUpperCase()}$attemptInfo');
    }
    
    if (details != null && details.isNotEmpty) {
      print('📋 [SCAN] [$timestamp] Details: $details');
    }
  }

  void _logFieldValues(Map<String, dynamic> data, List<String> fields) {
    print('📊 [SCAN] Field values analysis:');
    print('📊 [SCAN] Total data keys: ${data.keys.length}');
    print('📊 [SCAN] Required fields: ${fields.length}');
    
    // Group fields by status
    final presentFields = <String>[];
    final emptyFields = <String>[];
    final missingFields = <String>[];
    
    for (String field in fields) {
      final value = data[field];
      final valueType = value.runtimeType;
      final isEmpty = value == null || value.toString().isEmpty;
      final displayValue = value?.toString() ?? 'null';
      final truncatedValue = displayValue.length > 50 
          ? '${displayValue.substring(0, 50)}...' 
          : displayValue;
      
      // Categorize field status
      if (value == null) {
        missingFields.add(field);
        print('❌ [SCAN]   $field: NULL (missing from response)');
      } else if (isEmpty) {
        emptyFields.add(field);
        print('⚠️ [SCAN]   $field: EMPTY (Type: $valueType, Value: "$truncatedValue")');
      } else {
        presentFields.add(field);
        print('✅ [SCAN]   $field: "$truncatedValue" (Type: $valueType, Length: ${displayValue.length})');
      }
    }
    
    // Summary
    print('📊 [SCAN] Field Summary:');
    print('📊 [SCAN]   ✅ Present: ${presentFields.length} fields - $presentFields');
    print('📊 [SCAN]   ⚠️ Empty: ${emptyFields.length} fields - $emptyFields');
    print('📊 [SCAN]   ❌ Missing: ${missingFields.length} fields - $missingFields');
    
    // Additional analysis
    if (data.isNotEmpty) {
      print('📊 [SCAN] Available data keys: ${data.keys.toList()}');
      
      // Look for similar field names
      for (String missingField in missingFields) {
        final similarFields = data.keys.where((key) => 
          key.toLowerCase().contains(missingField.toLowerCase()) ||
          missingField.toLowerCase().contains(key.toLowerCase())
        ).toList();
        
        if (similarFields.isNotEmpty) {
          print('💡 [SCAN] Possible alternatives for "$missingField": $similarFields');
        }
      }
    }
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