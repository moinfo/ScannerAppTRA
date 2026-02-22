import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_receipt_scanner/app_state.dart';
import 'package:flutter_receipt_scanner/l10n.dart';
import 'package:flutter_receipt_scanner/login_page.dart';
import 'package:flutter_receipt_scanner/main_shell.dart';
import 'package:flutter_receipt_scanner/utils/api_request_status.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

// API URLs - Change these based on your environment
class ApiConfig {
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
  static String get dashboardUrl => '$baseUrl/dashboard';
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load persisted state
  final prefs = await SharedPreferences.getInstance();
  final bool isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
  final bool hasSavedCredentials = prefs.getString('token') != null && isLoggedIn;
  final appState = await AppState.load();

  runApp(MyApp(
    isLoggedIn: isLoggedIn,
    hasSavedCredentials: hasSavedCredentials,
    appState: appState,
  ));
}

class MyApp extends StatelessWidget {
  final bool isLoggedIn;
  final bool hasSavedCredentials;
  final AppState appState;

  const MyApp({
    super.key,
    this.isLoggedIn = false,
    this.hasSavedCredentials = false,
    required this.appState,
  });

  static const Color _primaryBlue = Color(0xFF1565C0);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: appState),
        ChangeNotifierProvider(create: (_) => ReceiptProvider()),
      ],
      child: Consumer<AppState>(
        builder: (context, state, _) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'Flutter Receipt Scanner',
            theme: ThemeData(
              useMaterial3: true,
              colorSchemeSeed: _primaryBlue,
              brightness: Brightness.light,
            ),
            darkTheme: ThemeData(
              useMaterial3: true,
              colorSchemeSeed: _primaryBlue,
              brightness: Brightness.dark,
            ),
            themeMode: state.themeMode,
            home: isLoggedIn
                ? const MainShell()
                : LoginPage(hasSavedCredentials: hasSavedCredentials),
            routes: {
              'scan': (context) => const ScanPage(),
              'login': (context) => const LoginPage(),
              'home': (context) => const MainShell(),
            },
          );
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
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: 64,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            errMsg,
            style: TextStyle(
              fontSize: 15,
              color: Colors.grey.shade500,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            L.tr(context, 'scan_to_start'),
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade400,
            ),
          ),
        ],
      ),
    );
  }
}

class ReceiptCard extends StatelessWidget {
  ReceiptCard({
    super.key,
    required this.receipt,
    required this.index,
  });

  final Receipt receipt;
  final int index;
  final _moneyFormat = NumberFormat.currency(name: '', decimalDigits: 2);

  static const Color _primaryColor = Color(0xFF1565C0);
  static const Color _subtleGray = Color(0xFF757575);

  String _timeAgo(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('dd MMM').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? Colors.white : const Color(0xFF212121);
    final metaColor = isDark ? Colors.grey.shade400 : _subtleGray;

    final initials = receipt.companyName
        .split(' ')
        .where((w) => w.isNotEmpty)
        .take(2)
        .map((w) => w[0].toUpperCase())
        .join();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Card(
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (BuildContext context) {
                  return ReceiptDetailPage(receipt: receipt);
                },
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Company initial avatar
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _primaryColor.withValues(alpha: isDark ? 0.2 : 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    initials,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: _primaryColor,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Company name + metadata
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        receipt.companyName,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: titleColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.calendar_today, size: 12, color: metaColor),
                          const SizedBox(width: 3),
                          Flexible(
                            child: Text(
                              receipt.date ?? '',
                              style: TextStyle(fontSize: 11, color: metaColor),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Icon(Icons.access_time, size: 12, color: metaColor),
                          const SizedBox(width: 3),
                          Flexible(
                            child: Text(
                              receipt.time ?? '',
                              style: TextStyle(fontSize: 11, color: metaColor),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      if (receipt.number != null && receipt.number!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(Icons.tag, size: 12, color: metaColor),
                            const SizedBox(width: 3),
                            Flexible(
                              child: Text(
                                receipt.number!,
                                style: TextStyle(fontSize: 11, color: metaColor),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Total amount + time ago
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (receipt.totalInclOfTax != null) ...[
                      Text(
                        _moneyFormat.format(receipt.totalInclOfTax),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: _primaryColor,
                        ),
                      ),
                      Text(
                        'TZS',
                        style: TextStyle(fontSize: 10, color: metaColor),
                      ),
                    ],
                    if (receipt.createdAt != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          _timeAgo(receipt.createdAt!),
                          style: TextStyle(fontSize: 10, color: metaColor),
                        ),
                      ),
                  ],
                  ),
                const SizedBox(width: 4),
                Icon(Icons.chevron_right, size: 20, color: metaColor),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ReceiptListPage extends StatefulWidget {
  const ReceiptListPage({
    super.key,
    this.userName = '',
    this.userEmail = '',
    this.isOfflineMode = false,
  });

  final String userName;
  final String userEmail;
  final bool isOfflineMode;

  @override
  State<ReceiptListPage> createState() => _ReceiptListPageState();
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

class _ReceiptListPageState extends State<ReceiptListPage> {
  final ScrollController _scrollController = ScrollController();
  DateTime? _startDate;
  DateTime? _endDate;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_scrollListener);
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

  static const Color _primaryColor = Color(0xFF1565C0);

  @override
  Widget build(BuildContext context) {
    final bool hasActiveFilters = _startDate != null || _searchController.text.trim().isNotEmpty;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final headerBg = isDark ? const Color(0xFF1A1A2E) : _primaryColor;
    final searchFill = isDark ? Colors.white.withValues(alpha: 0.08) : Colors.white;
    final searchHint = isDark ? Colors.grey.shade500 : Colors.grey.shade400;
    final dateBg = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.white.withValues(alpha: 0.15);
    final dateBorder = isDark
        ? Colors.white.withValues(alpha: 0.1)
        : Colors.white24;

    return Column(
        children: [
          // Search and filter section
          Container(
            decoration: BoxDecoration(
              color: headerBg,
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
            ),
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: Column(
              children: [
                // Search bar
                TextField(
                  controller: _searchController,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  decoration: InputDecoration(
                    hintText: L.tr(context, 'search_hint'),
                    hintStyle: TextStyle(color: searchHint, fontSize: 13),
                    prefixIcon: Icon(Icons.search, size: 20,
                        color: isDark ? Colors.grey.shade400 : null),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.clear, size: 18,
                                color: isDark ? Colors.grey.shade400 : null),
                            onPressed: () {
                              _searchController.clear();
                              _applyDateFilter();
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: searchFill,
                    contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: isDark
                          ? BorderSide(color: Colors.white.withValues(alpha: 0.1))
                          : BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: isDark
                          ? BorderSide(color: Colors.white.withValues(alpha: 0.1))
                          : BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        color: isDark ? Colors.white24 : _primaryColor,
                        width: 1.5,
                      ),
                    ),
                  ),
                  onSubmitted: (_) => _applyDateFilter(),
                  onChanged: (_) => setState(() {}), // refresh suffix icon
                ),
                const SizedBox(height: 8),
                // Date filter row
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () => _selectDateRange(context),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: dateBg,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: dateBorder),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.date_range, size: 18, color: Colors.white70),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _startDate != null && _endDate != null
                                      ? '${DateFormat('dd MMM yy').format(_startDate!)} - ${DateFormat('dd MMM yy').format(_endDate!)}'
                                      : L.tr(context, 'date_range'),
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: _startDate != null ? Colors.white : Colors.white60,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (hasActiveFilters) ...[
                      const SizedBox(width: 8),
                      InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: _clearFilters,
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: dateBg,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.filter_alt_off, size: 18, color: Colors.white70),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          // Receipt count indicator
          Consumer<ReceiptProvider>(
            builder: (context, provider, _) {
              final countColor = isDark ? Colors.grey.shade500 : const Color(0xFF757575);
              if (provider.apiRequestStatus == APIRequestStatus.loaded &&
                  provider.receipts.isNotEmpty) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Row(
                    children: [
                      Text(
                        '${provider.receipts.length} ${provider.receipts.length == 1 ? L.tr(context, 'receipt_count') : L.tr(context, 'receipts_count')}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: countColor,
                        ),
                      ),
                      if (provider.hasMoreData)
                        Text(
                          ' +',
                          style: TextStyle(fontSize: 12, color: countColor),
                        ),
                    ],
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),

          // Receipts list
          Expanded(
            child: Consumer<ReceiptProvider>(
              builder: (context, receipt, _) => buildBody(receipt),
            ),
          ),
        ],
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
      final isNetwork = receiptProvider.apiRequestStatus == APIRequestStatus.networkError;
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isNetwork ? Icons.wifi_off_rounded : Icons.error_outline_rounded,
                size: 56,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: 16),
              Text(
                isNetwork ? L.tr(context, 'no_connection') : L.tr(context, 'something_wrong'),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF424242),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                receiptProvider.lastError,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () => receiptProvider.fetchReceipts(
                  startDate: _startDate,
                  endDate: _endDate,
                  searchTerm: _searchController.text.trim(),
                ),
                icon: const Icon(Icons.refresh, size: 18),
                label: Text(L.tr(context, 'retry')),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
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
    return NoItems(errMsg: L.tr(context, 'no_receipts'));
  }
}

class ReceiptDetailPage extends StatelessWidget {
  ReceiptDetailPage({
    super.key,
    required this.receipt,
  });

  final Receipt receipt;
  final moneyFormat = NumberFormat.currency(name: '', decimalDigits: 2);

  // ── Color palette (theme-aware) ────────────────────────────────────
  static const Color _primaryColor = Color(0xFF1565C0);

  static bool _isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color _subtleGray(BuildContext context) =>
      _isDark(context) ? const Color(0xFFB0B0B0) : const Color(0xFF757575);

  static Color _lightBg(BuildContext context) =>
      _isDark(context) ? const Color(0xFF2A2A2A) : const Color(0xFFF5F5F5);

  static Color _dividerColor(BuildContext context) =>
      _isDark(context) ? const Color(0xFF555555) : const Color(0xFFBDBDBD);

  static Color _zebraStripe(BuildContext context) =>
      _isDark(context) ? const Color(0xFF252525) : const Color(0xFFF9F9F9);

  static Color _rowBg(BuildContext context) =>
      _isDark(context) ? const Color(0xFF1E1E1E) : Colors.white;

  // ── Text styles (theme-aware) ─────────────────────────────────────
  static const TextStyle _companyNameStyle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.bold,
    color: _primaryColor,
  );
  static const TextStyle _sectionTitleStyle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: _primaryColor,
  );
  static TextStyle _labelStyle(BuildContext context) => TextStyle(
    fontSize: 12,
    color: _subtleGray(context),
  );
  static TextStyle _valueStyle(BuildContext context) => TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: _isDark(context) ? const Color(0xFFE0E0E0) : const Color(0xFF212121),
  );
  static const TextStyle _tableHeaderStyle = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    color: Colors.white,
  );
  static TextStyle _totalLabelStyle(BuildContext context) => TextStyle(
    fontSize: 13,
    color: _isDark(context) ? const Color(0xFFB0B0B0) : const Color(0xFF424242),
  );
  static TextStyle _totalValueStyle(BuildContext context) => TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: _isDark(context) ? const Color(0xFFE0E0E0) : const Color(0xFF212121),
  );
  static const TextStyle _grandTotalStyle = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.bold,
    color: Colors.white,
  );
  static const TextStyle _grandTotalLabelStyle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: Colors.white70,
  );
  static TextStyle _metaStyle(BuildContext context) => TextStyle(
    fontSize: 11,
    color: _subtleGray(context),
  );

  void _launchUrl(BuildContext context, String path) async {
    bool canLaunch = !await canLaunchUrl(Uri.parse('https://verify.tra.go.tz/$path'));

    if (canLaunch) {
      if (!context.mounted) return;

      showDialog(
        context: context,
        builder: (ctx) {
          return AlertDialog(
            content: SingleChildScrollView(
              child: SizedBox(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      L.tr(context, 'failed_open_browser'),
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                },
                child: Text(L.tr(context, 'close')),
              ),
            ],
          );
        },
      );
    } else {
      launchUrl(Uri.parse('https://verify.tra.go.tz/$path'));
    }
  }

  // ── Helper widgets ─────────────────────────────────────────────────

  Widget _buildDashedDivider(BuildContext context) {
    final color = _dividerColor(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: LayoutBuilder(
        builder: (_, constraints) {
          const dashWidth = 5.0;
          const dashGap = 3.0;
          final dashCount =
              (constraints.maxWidth / (dashWidth + dashGap)).floor();
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(dashCount, (_) {
              return SizedBox(
                width: dashWidth,
                height: 1,
                child: DecoratedBox(
                  decoration: BoxDecoration(color: color),
                ),
              );
            }),
          );
        },
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 18, color: _primaryColor),
          const SizedBox(width: 8),
          Text(title, style: _sectionTitleStyle),
        ],
      ),
    );
  }

  Widget _buildIconLabel(BuildContext context, IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(right: 16, bottom: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: _subtleGray(context)),
          const SizedBox(width: 4),
          Flexible(child: Text(text, style: _metaStyle(context))),
        ],
      ),
    );
  }

  Widget _buildLabelValueRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: _labelStyle(context)),
          Flexible(child: Text(value, style: _valueStyle(context), textAlign: TextAlign.right)),
        ],
      ),
    );
  }

  Widget _buildTotalRow(BuildContext context, String label, double? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: _totalLabelStyle(context)),
          Text(
            value != null ? moneyFormat.format(value) : '-',
            style: _totalValueStyle(context),
          ),
        ],
      ),
    );
  }

  Widget _buildStyledThreeColumnTable(
    BuildContext context, {
    required List<String> headers,
    required List<List<String>> rows,
  }) {
    final rowColor = _rowBg(context);
    final stripe = _zebraStripe(context);
    final borderColor = _isDark(context) ? const Color(0xFF444444) : Colors.grey.shade200;
    return Column(
      children: [
        // Header row
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: _primaryColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
          ),
          child: Row(
            children: [
              Expanded(flex: 2, child: Text(headers[0], style: _tableHeaderStyle)),
              Expanded(flex: 3, child: Text(headers[1], style: _tableHeaderStyle)),
              Expanded(
                flex: 2,
                child: Text(headers[2], style: _tableHeaderStyle, textAlign: TextAlign.right),
              ),
            ],
          ),
        ),
        // Data rows
        ...rows.asMap().entries.map((entry) {
          final i = entry.key;
          final row = entry.value;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: i.isEven ? rowColor : stripe,
              border: i == rows.length - 1
                  ? Border.all(color: borderColor, width: 0)
                  : null,
            ),
            child: Row(
              children: [
                Expanded(flex: 2, child: Text(row[0], style: _labelStyle(context))),
                Expanded(flex: 3, child: Text(row[1], style: _valueStyle(context))),
                Expanded(
                  flex: 2,
                  child: Text(row[2], style: _valueStyle(context), textAlign: TextAlign.right),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  // ── Main build ─────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Card(
          elevation: 2,
          color: _isDark(context) ? const Color(0xFF1E1E1E) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildCompanyHeader(context),
                _buildDashedDivider(context),
                _buildCustomerInfo(context),
                _buildDashedDivider(context),
                _buildReceiptInfo(context),
                _buildDashedDivider(context),
                _buildItemsTable(context),
                if (receipt.adjustments?.isNotEmpty ?? false) ...[
                  _buildDashedDivider(context),
                  _buildAdjustmentsTable(context),
                ],
                if (receipt.payments?.isNotEmpty ?? false) ...[
                  _buildDashedDivider(context),
                  _buildPaymentsTable(context),
                ],
                _buildDashedDivider(context),
                _buildTotalsSection(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Company header ─────────────────────────────────────────────────

  Widget _buildCompanyHeader(BuildContext context) {
    return Center(
      child: Column(
        children: [
          Text(
            receipt.companyName,
            textAlign: TextAlign.center,
            style: _companyNameStyle,
          ),
          if (receipt.poBox != null && receipt.poBox!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.location_on_outlined, size: 14, color: _subtleGray(context)),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    receipt.poBox!,
                    textAlign: TextAlign.center,
                    style: _metaStyle(context),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 10),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 6,
            runSpacing: 4,
            children: [
              if (receipt.mobile != null)
                _buildIconLabel(context, Icons.phone_outlined, receipt.mobile!),
              if (receipt.tin != null)
                _buildIconLabel(context, Icons.badge_outlined, 'TIN: ${receipt.tin}'),
              if (receipt.vrn != null)
                _buildIconLabel(context, Icons.tag, 'VRN: ${receipt.vrn}'),
              if (receipt.serialNumber != null)
                _buildIconLabel(context, Icons.qr_code, 'S/N: ${receipt.serialNumber}'),
              if (receipt.uin != null)
                _buildIconLabel(context, Icons.fingerprint, 'UIN: ${receipt.uin}'),
              if (receipt.taxOffice != null)
                _buildIconLabel(context, Icons.account_balance_outlined, receipt.taxOffice!),
            ],
          ),
        ],
      ),
    );
  }

  // ── Customer info ──────────────────────────────────────────────────

  Widget _buildCustomerInfo(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(L.tr(context, 'section_customer'), Icons.person_outline),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _lightBg(context),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              _buildLabelValueRow(context, L.tr(context, 'label_name'), receipt.customer?.name ?? '-'),
              _buildLabelValueRow(context, L.tr(context, 'label_id_type'), receipt.customer?.idType ?? '-'),
              _buildLabelValueRow(context, L.tr(context, 'label_id'), receipt.customer?.id ?? '-'),
              _buildLabelValueRow(context, L.tr(context, 'label_mobile'), receipt.customer?.mobile ?? 'n/a'),
            ],
          ),
        ),
      ],
    );
  }

  // ── Receipt info ───────────────────────────────────────────────────

  Widget _buildReceiptInfo(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(L.tr(context, 'section_receipt_details'), Icons.receipt_long_outlined),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _lightBg(context),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              _buildLabelValueRow(context, L.tr(context, 'label_receipt_no'), receipt.number ?? '-'),
              _buildLabelValueRow(context, L.tr(context, 'label_z_number'), receipt.zNumber ?? '-'),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Icon(Icons.calendar_today, size: 13, color: _subtleGray(context)),
                        const SizedBox(width: 4),
                        Text(receipt.date ?? '-', style: _valueStyle(context)),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      Icon(Icons.access_time, size: 13, color: _subtleGray(context)),
                      const SizedBox(width: 4),
                      Text(receipt.time ?? '-', style: _valueStyle(context)),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Items table ────────────────────────────────────────────────────

  Widget _buildItemsTable(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(L.tr(context, 'section_items'), Icons.shopping_cart_outlined),
        // Header row
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: _primaryColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
          ),
          child: Row(
            children: [
              Expanded(flex: 3, child: Text(L.tr(context, 'table_description'), style: _tableHeaderStyle)),
              Expanded(
                flex: 1,
                child: Text(L.tr(context, 'table_qty'), style: _tableHeaderStyle, textAlign: TextAlign.right),
              ),
              Expanded(
                flex: 2,
                child: Text(L.tr(context, 'table_amount'), style: _tableHeaderStyle, textAlign: TextAlign.right),
              ),
            ],
          ),
        ),
        // Item rows
        if (receipt.items != null && receipt.items!.isNotEmpty)
          ...receipt.items!.asMap().entries.map((entry) {
            final i = entry.key;
            final item = entry.value;
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              color: i.isEven ? _rowBg(context) : _zebraStripe(context),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Text(item.description ?? '', style: _valueStyle(context)),
                  ),
                  Expanded(
                    flex: 1,
                    child: Text(
                      '${item.quantity ?? 1}',
                      style: _labelStyle(context),
                      textAlign: TextAlign.right,
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      moneyFormat.format(item.amount ?? 0),
                      style: _valueStyle(context),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }

  // ── Adjustments table ──────────────────────────────────────────────

  Widget _buildAdjustmentsTable(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(L.tr(context, 'section_adjustments'), Icons.tune),
        _buildStyledThreeColumnTable(
          context,
          headers: [L.tr(context, 'table_type'), L.tr(context, 'table_description_lower'), L.tr(context, 'table_amount_lower')],
          rows: receipt.adjustments!
              .map((adj) => [
                    adj.type,
                    adj.description,
                    moneyFormat.format(adj.amount),
                  ])
              .toList(),
        ),
      ],
    );
  }

  // ── Payments table ─────────────────────────────────────────────────

  Widget _buildPaymentsTable(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(L.tr(context, 'section_payments'), Icons.payment),
        _buildStyledThreeColumnTable(
          context,
          headers: [L.tr(context, 'table_type'), L.tr(context, 'table_description_lower'), L.tr(context, 'table_amount_lower')],
          rows: receipt.payments!
              .map((pmt) => [
                    pmt.type,
                    pmt.description,
                    moneyFormat.format(pmt.amount),
                  ])
              .toList(),
        ),
      ],
    );
  }

  // ── Totals section ─────────────────────────────────────────────────

  Widget _buildTotalsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(L.tr(context, 'section_totals'), Icons.summarize_outlined),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _lightBg(context),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              _buildTotalRow(context, L.tr(context, 'total_excl_tax'), receipt.totalExlcOfTax),
              if (receipt.isTanesco) ...[
                if (receipt.kwhCharge != null && receipt.kwhCharge! > 0)
                  _buildTotalRow(context, L.tr(context, 'kwh_charge'), receipt.kwhCharge),
                if (receipt.kvaCharge != null && receipt.kvaCharge! > 0)
                  _buildTotalRow(context, L.tr(context, 'kva_charge'), receipt.kvaCharge),
                if (receipt.serviceCharge != null && receipt.serviceCharge! > 0)
                  _buildTotalRow(context, L.tr(context, 'service_charge'), receipt.serviceCharge),
                if (receipt.interestAmount != null && receipt.interestAmount! > 0)
                  _buildTotalRow(context, L.tr(context, 'interest_amount'), receipt.interestAmount),
                if (receipt.taxRate != null)
                  _buildTotalRow(context, '${L.tr(context, 'total_tax')} (${receipt.taxRate}%)', receipt.totalTax),
              ],
              _buildTotalRow(context, L.tr(context, 'total_tax'), receipt.totalTax),
              if (receipt.isTanesco) ...[
                if (receipt.reaCharge != null && receipt.reaCharge! > 0)
                  _buildTotalRow(context, L.tr(context, 'rea_label'), receipt.reaCharge),
                if (receipt.ewuraCharge != null && receipt.ewuraCharge! > 0)
                  _buildTotalRow(context, L.tr(context, 'ewura_label'), receipt.ewuraCharge),
                if (receipt.propertyTax != null && receipt.propertyTax! > 0)
                  _buildTotalRow(context, L.tr(context, 'property_tax'), receipt.propertyTax),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1565C0), Color(0xFF1E88E5)],
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(L.tr(context, 'total_label'), style: _grandTotalLabelStyle),
              Text(
                receipt.totalInclOfTax != null
                    ? moneyFormat.format(receipt.totalInclOfTax)
                    : '-',
                style: _grandTotalStyle,
              ),
            ],
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
  bool _isProcessing = false;
  final Set<String> _scannedCodes = {};

  bool receiptUrlFound = false;

  String errMsg = '';
  bool _errIsDuplicate = false;

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
        title: Text(L.tr(context, 'scan_title')),
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
                      Text(L.tr(context, 'please_wait')),
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
                        onPressed: _errIsDuplicate
                            ? _handleReceiptAlreadyExists
                            : _handleReceiptScrapeFailed,
                        child: Text(_errIsDuplicate
                            ? L.tr(context, 'close')
                            : L.tr(context, 'try_again')),
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
        if (_isProcessing) return;
        if (capture.barcodes.isNotEmpty && capture.barcodes.first.rawValue != null) {
          _isProcessing = true;
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
                errMsg = L.tr(context, 'receipt_incorrect');
              _errIsDuplicate = false;
              });
            }
          } catch (e) {
            setState(() {
              receiptUrlFound = false;
              errMsg = L.tr(context, 'receipt_incorrect');
              _errIsDuplicate = false;
            });
          } finally {
            _isProcessing = false;
          }
        }
      },
    );
  }

  Future<void> scrape(String code, String time, ReceiptProvider receiptProvider) async {
    int retries = 2;

    // Check if receipt already exists (in provider list or scanned this session)
    if (receiptProvider.checkIfReceiptExists(code) || _scannedCodes.contains(code)) {
      setState(() {
        receiptUrlFound = false;
        errMsg = L.tr(context, 'receipt_already_scanned');
        _errIsDuplicate = true;
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

        // First request to scraping server (Puppeteer can be slow)
        http.Response response = await http.get(
          Uri.parse('${ApiConfig.scraperUrl}/receipt/$code/$time'),
          headers: {
            'Accept': 'application/json',
          },
        ).timeout(const Duration(seconds: 60));

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
                errMsg = L.tr(context, 'scan_failed_complete');
                _errIsDuplicate = false;
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
            // Track this code to prevent duplicate scans
            _scannedCodes.add(code);

            setState(() {
              receiptUrlFound = false;
              _code = '';
              _time = '';
              errMsg = '';
            });

            // Refresh the receipt list
            await receiptProvider.fetchReceipts();

            if (mounted) {
              final serverData = jsonDecode(serverResponse.body);
              final isDuplicate = serverData['duplicate'] == true;

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(isDuplicate
                      ? L.tr(context, 'receipt_exists')
                      : L.tr(context, 'scan_success')),
                  backgroundColor: isDuplicate ? Colors.orange : Colors.green,
                  duration: const Duration(seconds: 3),
                ),
              );

              // Build receipt from scraped data and open detail page
              try {
                final receiptData = responseBody is List ? Map<String, dynamic>.from(responseBody[0]) : Map<String, dynamic>.from(responseBody);
                receiptData['id'] = serverData['receipt_id'] ?? 0;
                final receipt = Receipt.fromJson(receiptData);
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (context) => ReceiptDetailPage(receipt: receipt),
                  ),
                );
              } catch (e) {
                // If parsing fails, just go back to the list
                print('Could not parse receipt for detail view: $e');
                Navigator.of(context).pop();
              }
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
            errMsg = L.tr(context, 'request_timeout');
            _errIsDuplicate = false;
          });
          return;
        }
      } on FormatException catch (e) {
        print('Format error during attempt ${i + 1}: $e');
        if (i == retries - 1) {
          setState(() {
            receiptUrlFound = false;
            errMsg = L.tr(context, 'invalid_format');
            _errIsDuplicate = false;
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
  DateTime? createdAt;

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
    this.createdAt,
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
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at']) : null,
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

class DashboardData {
  final int totalReceipts;
  final double totalAmount;
  final int todayScans;
  final double avgValue;
  final double totalTax;
  final List<Receipt> recentReceipts;

  const DashboardData({
    this.totalReceipts = 0,
    this.totalAmount = 0,
    this.todayScans = 0,
    this.avgValue = 0,
    this.totalTax = 0,
    this.recentReceipts = const [],
  });

  factory DashboardData.fromJson(Map<String, dynamic> json) {
    final stats = json['stats'] ?? {};
    final recentList = json['recent_receipts'] as List<dynamic>? ?? [];
    return DashboardData(
      totalReceipts: stats['total_receipts'] ?? 0,
      totalAmount: (stats['total_amount'] ?? 0).toDouble(),
      todayScans: stats['today_scans'] ?? 0,
      avgValue: (stats['avg_value'] ?? 0).toDouble(),
      totalTax: (stats['total_tax'] ?? 0).toDouble(),
      recentReceipts: recentList
          .map((r) {
            try { return Receipt.fromJson(r); } catch (_) { return null; }
          })
          .whereType<Receipt>()
          .toList(),
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

  // Dashboard state
  DashboardData _dashboardData = const DashboardData();
  APIRequestStatus _dashboardStatus = APIRequestStatus.loading;

  List<Receipt> get receipts => _receipts;
  APIRequestStatus get apiRequestStatus => _apiRequestStatus;
  String get lastError => _lastError;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMoreData => _hasMoreData;
  DashboardData get dashboardData => _dashboardData;
  APIRequestStatus get dashboardStatus => _dashboardStatus;

  ReceiptProvider() {
    debugPrint('ReceiptProvider initialized');
    // We'll fetch receipts from MainShell instead to avoid duplicate calls
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

  Future<void> fetchDashboard({DateTime? startDate, DateTime? endDate}) async {
    debugPrint('Starting fetchDashboard()');
    _dashboardStatus = APIRequestStatus.loading;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      // Offline mode: compute from local data
      if (token != null && token.startsWith('offline_')) {
        _dashboardData = DashboardData(
          totalReceipts: _receipts.length,
          totalAmount: _receipts.fold(0, (s, r) => s + (r.totalInclOfTax ?? 0)),
          todayScans: _receipts.where((r) => r.date == DateFormat('dd/MM/yyyy').format(DateTime.now())).length,
          avgValue: _receipts.isEmpty ? 0 : _receipts.fold<double>(0, (s, r) => s + (r.totalInclOfTax ?? 0)) / _receipts.length,
          totalTax: _receipts.fold(0, (s, r) => s + (r.totalTax ?? 0)),
          recentReceipts: _receipts.take(3).toList(),
        );
        _dashboardStatus = APIRequestStatus.loaded;
        notifyListeners();
        return;
      }

      // Build URL with date range
      final start = startDate ?? DateTime(DateTime.now().year, DateTime.now().month, 1);
      final end = endDate ?? DateTime.now();
      final startStr = DateFormat('yyyy-MM-dd').format(start);
      final endStr = DateFormat('yyyy-MM-dd').format(end);
      final url = '${ApiConfig.dashboardUrl}?start_date=$startStr&end_date=$endStr';

      debugPrint('Dashboard API call to: $url');
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Accept': 'application/json',
          'Authorization': token != null ? 'Bearer $token' : '',
        },
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        _dashboardData = DashboardData.fromJson(json);
        _dashboardStatus = APIRequestStatus.loaded;
        debugPrint('Dashboard loaded: ${_dashboardData.totalReceipts} receipts');
      } else {
        _dashboardStatus = APIRequestStatus.error;
        debugPrint('Dashboard API error: ${response.statusCode}');
      }
    } on SocketException {
      _dashboardStatus = APIRequestStatus.networkError;
    } on TimeoutException {
      _dashboardStatus = APIRequestStatus.networkError;
    } catch (e) {
      debugPrint('Dashboard error: $e');
      _dashboardStatus = APIRequestStatus.error;
    } finally {
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
            getMessage(context, apiRequestStatus),
            style: Theme.of(context).textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          ElevatedButton(
            onPressed: () => onRefresh(),
            child: Text(L.tr(context, 'try_again')),
          ),
        ],
      ),
    );
  }

  String getMessage(BuildContext context, APIRequestStatus apiRequestStatus) {
    if (apiRequestStatus == APIRequestStatus.error) {
      return L.tr(context, 'page_load_error');
    } else if (apiRequestStatus == APIRequestStatus.networkError) {
      return L.tr(context, 'check_internet');
    }
    return '';
  }
}