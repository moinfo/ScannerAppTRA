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
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoadingTransactions = true;
    });

    // Load data from all providers
    final salesProvider = Provider.of<SalesProvider>(context, listen: false);
    final purchasesProvider = Provider.of<PurchasesProvider>(context, listen: false);
    final vatProvider = Provider.of<VatProvider>(context, listen: false);
    final receiptProvider = Provider.of<ReceiptProvider>(context, listen: false);

    // Fetch data from all sources in parallel
    await Future.wait([
      salesProvider.fetchSales(),
      purchasesProvider.fetchPurchases(),
      vatProvider.fetchVatPayments(),
      receiptProvider.fetchReceipts()
    ]);

    // Combine recent transactions from different sources
    _combineRecentTransactions();
  }

  void _combineRecentTransactions() {
    final salesProvider = Provider.of<SalesProvider>(context, listen: false);
    final purchasesProvider = Provider.of<PurchasesProvider>(context, listen: false);
    final vatProvider = Provider.of<VatProvider>(context, listen: false);
    
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

    setState(() {
      _isLoadingTransactions = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Access the providers to read data
    final appStateProvider = Provider.of<AppStateProvider>(context);
    final salesProvider = Provider.of<SalesProvider>(context);
    final purchasesProvider = Provider.of<PurchasesProvider>(context);
    final vatProvider = Provider.of<VatProvider>(context);
    final receiptProvider = Provider.of<ReceiptProvider>(context);

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
                    value: receiptProvider.receipts.length.toDouble(),
                    icon: Icons.qr_code_scanner,
                    color: Colors.purple,
                    isCount: true,
                    isLoading: receiptProvider.isLoading,
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Recent transactions
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
                if (_recentTransactions.isNotEmpty)
                  TextButton(
                    onPressed: () {
                      // Navigate to a full transactions list page
                      // TODO: Implement navigation to a dedicated transactions screen
                    },
                    child: const Text('View All'),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            
            Expanded(
              flex: 3,
              child: _isLoadingTransactions || 
                     salesProvider.isLoading || 
                     purchasesProvider.isLoading || 
                     vatProvider.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _recentTransactions.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.receipt_long_outlined,
                                size: 48,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No recent transactions found',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 8),
                              if (!isOffline)
                                ElevatedButton(
                                  onPressed: _loadData,
                                  child: const Text('Refresh'),
                                ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: _recentTransactions.length,
                          itemBuilder: (context, index) {
                            final transaction = _recentTransactions[index];
                            return Card(
                              elevation: 2,
                              margin: const EdgeInsets.only(bottom: 12),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: _getColorForTransactionType(transaction['type']),
                                  child: Icon(
                                    _getIconForTransactionType(transaction['type']),
                                    color: Colors.white,
                                  ),
                                ),
                                title: Text(
                                  transaction['description'],
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Text(
                                  '${transaction['date']} • ${transaction['status']}',
                                ),
                                trailing: Text(
                                  transaction['formatted_amount'],
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: _getColorForTransactionType(transaction['type']),
                                  ),
                                ),
                                onTap: () {
                                  // Show transaction details
                                  _showTransactionDetails(transaction);
                                },
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
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