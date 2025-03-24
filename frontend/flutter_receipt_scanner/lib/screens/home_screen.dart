import 'package:flutter/material.dart';
import 'package:flutter_receipt_scanner/providers/app_state_provider.dart';
import 'package:flutter_receipt_scanner/providers/purchases_provider.dart';
import 'package:flutter_receipt_scanner/providers/receipt_provider.dart';
import 'package:flutter_receipt_scanner/providers/sales_provider.dart';
import 'package:flutter_receipt_scanner/providers/vat_provider.dart';
import 'package:flutter_receipt_scanner/utils/api_request_status.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _moneyFormat = NumberFormat.currency(symbol: 'TZS ', decimalDigits: 2);
  
  // List to store all recent transactions combined from different sources
  final List<Map<String, dynamic>> _recentTransactions = [];
  bool _isLoadingTransactions = false;

  @override
  void initState() {
    super.initState();
    // Use post-frame callback to ensure context is ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadData();
      }
    });
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoadingTransactions = true;
    });

    try {
      // Load data from all providers with safe access
      final salesProvider = Provider.of<SalesProvider>(context, listen: false);
      final purchasesProvider = Provider.of<PurchasesProvider>(context, listen: false);
      final vatProvider = Provider.of<VatProvider>(context, listen: false);
      
      // Access ReceiptProvider safely
      ReceiptProvider? receiptProvider;
      try {
        receiptProvider = Provider.of<ReceiptProvider>(context, listen: false);
      } catch (e) {
        debugPrint('ReceiptProvider not available yet: $e');
        // Continue without receipt provider
      }

      // Fetch data from all sources in parallel
      List<Future> futures = [
        salesProvider.fetchSales(),
        purchasesProvider.fetchPurchases(),
        vatProvider.fetchVatPayments(),
      ];
      
      // Only add receipt fetch if provider is available
      if (receiptProvider != null) {
        futures.add(receiptProvider.fetchReceipts());
      }
      
      await Future.wait(futures);

      // Combine recent transactions from different sources
      _combineRecentTransactions();
    } catch (e) {
      debugPrint('Error loading data: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingTransactions = false;
        });
      }
    }
  }

  void _combineRecentTransactions() {
    try {
      final salesProvider = Provider.of<SalesProvider>(context, listen: false);
      final purchasesProvider = Provider.of<PurchasesProvider>(context, listen: false);
      final vatProvider = Provider.of<VatProvider>(context, listen: false);
      
      // Safely access ReceiptProvider
      ReceiptProvider? receiptProvider;
      try {
        receiptProvider = Provider.of<ReceiptProvider>(context, listen: false);
      } catch (e) {
        debugPrint('ReceiptProvider not available for combining transactions: $e');
      }
      
      _recentTransactions.clear();

      // Add sales transactions
      for (var sale in salesProvider.sales) {
        _recentTransactions.add({
          'id': sale.id,
          'date': sale.date,
          'type': 'Sale',
          'description': '${sale.customer} - sale transaction',
          'amount': sale.amount,
          'formatted_amount': _moneyFormat.format(sale.amount),
          'status': sale.status,
          'originalObject': sale,
        });
      }

      // Add purchase transactions
      for (var purchase in purchasesProvider.purchases) {
        _recentTransactions.add({
          'id': purchase.id,
          'date': purchase.date,
          'type': 'Purchase',
          'description': '${purchase.supplier} - purchase transaction',
          'amount': purchase.amount,
          'formatted_amount': _moneyFormat.format(purchase.amount),
          'status': purchase.status,
          'originalObject': purchase,
        });
      }

      // Add VAT payment transactions
      for (var vatPayment in vatProvider.vatPayments) {
        _recentTransactions.add({
          'id': vatPayment.id,
          'date': vatPayment.dueDate,
          'type': 'VAT Payment',
          'description': 'VAT Payment for ${vatPayment.period}',
          'amount': vatPayment.amountPayable,
          'formatted_amount': _moneyFormat.format(vatPayment.amountPayable),
          'status': vatPayment.status,
          'originalObject': vatPayment,
        });
      }

      // Add receipts only if provider is available
      if (receiptProvider != null) {
        for (var receipt in receiptProvider.receipts) {
          _recentTransactions.add({
            'id': receipt.id,
            'date': receipt.date ?? DateTime.now().toString(),
            'type': 'Receipt',
            'description': '${receipt.companyName} - receipt scanned',
            'amount': receipt.totalInclOfTax ?? 0.0,
            'formatted_amount': _moneyFormat.format(receipt.totalInclOfTax ?? 0.0),
            'status': 'Recorded',
            'originalObject': receipt,
          });
        }
      }

      // Sort all transactions by date, most recent first
      _recentTransactions.sort((a, b) {
        final dateA = DateTime.parse(a['date']);
        final dateB = DateTime.parse(b['date']);
        return dateB.compareTo(dateA);
      });

      // Take only the 10 most recent transactions
      if (_recentTransactions.length > 10) {
        _recentTransactions.removeRange(10, _recentTransactions.length);
      }

      if (mounted) {
        setState(() {
          _isLoadingTransactions = false;
        });
      }
    } catch (e) {
      debugPrint('Error combining transactions: $e');
      if (mounted) {
        setState(() {
          _isLoadingTransactions = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    try {
      // Access the providers to read data
      final appStateProvider = Provider.of<AppStateProvider>(context);
      final salesProvider = Provider.of<SalesProvider>(context);
      final purchasesProvider = Provider.of<PurchasesProvider>(context);
      final vatProvider = Provider.of<VatProvider>(context);
      
      // Safely try to access ReceiptProvider, but don't require it
      ReceiptProvider? receiptProvider;
      try {
        receiptProvider = Provider.of<ReceiptProvider>(context);
      } catch (e) {
        // ReceiptProvider not available, but we can continue without it
        debugPrint('ReceiptProvider not available in build: $e');
      }

      // Check the connectivity status
      final bool isOffline = appStateProvider.isOffline;
    
      return RefreshIndicator(
        onRefresh: () async {
          await _loadData();
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome message with connectivity indicator
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Dashboard Overview',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (isOffline)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.cloud_off, size: 16, color: Colors.orange),
                          SizedBox(width: 4),
                          Text(
                            'Offline',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.orange,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Welcome back! Here\'s your business overview for ${DateFormat('MMMM yyyy').format(DateTime.now())}',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 24),
              
              // Summary cards
              Expanded(
                flex: 2,
                child: GridView.count(
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1.5,
                  children: [
                    _buildSummaryCard(
                      title: 'Total Sales',
                      value: salesProvider.totalSales,
                      icon: Icons.shopping_cart,
                      color: Colors.blue,
                      isLoading: salesProvider.isLoading,
                    ),
                    _buildSummaryCard(
                      title: 'Total Purchases',
                      value: purchasesProvider.totalPurchases,
                      icon: Icons.shopping_bag,
                      color: Colors.green,
                      isLoading: purchasesProvider.isLoading,
                    ),
                    _buildSummaryCard(
                      title: 'VAT Payable',
                      value: vatProvider.totalVatPayable,
                      icon: Icons.payments,
                      color: Colors.orange,
                      isLoading: vatProvider.isLoading,
                    ),
                    _buildSummaryCard(
                      title: 'Receipts Scanned',
                      value: receiptProvider?.receipts.length.toDouble() ?? 0,
                      icon: Icons.receipt,
                      color: Colors.purple,
                      isCount: true,
                      isLoading: receiptProvider?.isLoading ?? false,
                    ),
                  ],
                ),
              ),
              
              // Recent transactions section
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Recent Transactions',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      // Navigate to transactions list
                    },
                    child: const Text('See All'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              
              // Recent transactions list
              Expanded(
                flex: 3,
                child: _isLoadingTransactions
                    ? const Center(child: CircularProgressIndicator())
                    : _recentTransactions.isEmpty
                        ? Center(
                            child: Text(
                              'No recent transactions',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          )
                        : ListView.builder(
                            itemCount: _recentTransactions.length,
                            itemBuilder: (context, index) {
                              final transaction = _recentTransactions[index];
                              final type = transaction['type'];
                              
                              return Card(
                                margin: const EdgeInsets.only(bottom: 8.0),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: _getColorForTransactionType(type),
                                    child: Icon(
                                      _getIconForTransactionType(type),
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                  ),
                                  title: Text(
                                    transaction['description'],
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle: Text(
                                    'Date: ${transaction['date']}',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  trailing: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        transaction['formatted_amount'],
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        transaction['status'],
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: transaction['status'] == 'Completed' || transaction['status'] == 'Paid'
                                              ? Colors.green
                                              : transaction['status'] == 'Pending'
                                                  ? Colors.orange
                                                  : Colors.blue,
                                        ),
                                      ),
                                    ],
                                  ),
                                  onTap: () => _showTransactionDetails(transaction),
                                ),
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      // Fallback UI if any providers fail to load
      debugPrint('Error in HomeScreen build: $e');
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text('Loading dashboard data...', 
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      );
    }
  }

  Widget _buildSummaryCard({
    required String title,
    required double value,
    required IconData icon,
    required Color color,
    bool isCount = false,
    bool isLoading = false,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  color: color,
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Spacer(),
            if (isLoading)
              SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              )
            else
              Text(
                isCount ? value.toInt().toString() : _moneyFormat.format(value),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Color _getColorForTransactionType(String type) {
    switch (type) {
      case 'Sale':
        return Colors.blue;
      case 'Purchase':
        return Colors.green;
      case 'VAT Payment':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  IconData _getIconForTransactionType(String type) {
    switch (type) {
      case 'Sale':
        return Icons.shopping_cart;
      case 'Purchase':
        return Icons.shopping_bag;
      case 'VAT Payment':
        return Icons.payments;
      default:
        return Icons.receipt;
    }
  }

  void _showTransactionDetails(Map<String, dynamic> transaction) {
    final type = transaction['type'];
    
    // Get appropriate detail rows based on transaction type
    List<Widget> detailRows = _getDetailRowsForType(transaction, type);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: _getColorForTransactionType(type),
              child: Icon(
                _getIconForTransactionType(type),
                color: Colors.white,
                size: 16,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '$type #${transaction['id']}',
                style: const TextStyle(fontSize: 18),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: detailRows,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          if (type == 'Sale' || type == 'Purchase')
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                // TODO: Navigate to edit screen for this transaction
              },
              child: const Text('View Details'),
            ),
        ],
      ),
    );
  }

  List<Widget> _getDetailRowsForType(Map<String, dynamic> transaction, String type) {
    final basicDetails = [
      _buildDetailRow('Date', transaction['date']),
      _buildDetailRow('Amount', transaction['formatted_amount']),
      _buildDetailRow('Status', transaction['status']),
    ];
    
    switch (type) {
      case 'Sale':
        final sale = transaction['originalObject'];
        return [
          _buildDetailRow('Customer', sale.customer),
          ...basicDetails,
          _buildDetailRow('Items', '${sale.items.length} items'),
        ];
      case 'Purchase':
        final purchase = transaction['originalObject'];
        return [
          _buildDetailRow('Supplier', purchase.supplier),
          ...basicDetails,
          _buildDetailRow('Receipt Linked', purchase.receiptId != null ? 'Yes' : 'No'),
          if (purchase.items != null) 
            _buildDetailRow('Items', '${purchase.items!.length} items'),
        ];
      case 'VAT Payment':
        final vatPayment = transaction['originalObject'];
        return [
          _buildDetailRow('Period', vatPayment.period),
          _buildDetailRow('Due Date', vatPayment.dueDate),
          _buildDetailRow('Sales VAT', _moneyFormat.format(vatPayment.salesVat)),
          _buildDetailRow('Purchases VAT', _moneyFormat.format(vatPayment.purchasesVat)),
          _buildDetailRow('Amount Payable', _moneyFormat.format(vatPayment.amountPayable)),
          _buildDetailRow('Status', vatPayment.status),
        ];
      default:
        return basicDetails;
    }
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label: ',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }
}