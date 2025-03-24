import 'package:flutter/material.dart';
import 'package:flutter_receipt_scanner/providers/app_state_provider.dart';
import 'package:flutter_receipt_scanner/providers/purchases_provider.dart';
import 'package:flutter_receipt_scanner/providers/receipt_provider.dart';
import 'package:flutter_receipt_scanner/services/purchase_service.dart';
import 'package:flutter_receipt_scanner/utils/api_request_status.dart';
import 'package:flutter_receipt_scanner/widgets/data_table_widget.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class PurchasesScreen extends StatefulWidget {
  const PurchasesScreen({Key? key}) : super(key: key);

  @override
  State<PurchasesScreen> createState() => _PurchasesScreenState();
}

class _PurchasesScreenState extends State<PurchasesScreen> {
  final _searchController = TextEditingController();
  DateTime? _startDate;
  DateTime? _endDate;
  final _moneyFormat = NumberFormat.currency(symbol: 'TZS ', decimalDigits: 2);
  final _vatRate = 0.18; // 18% VAT
  
  // Columns for the data table
  final List<String> _columns = ['id', 'date', 'supplier', 'amount', 'status'];
  final List<String> _columnNames = ['ID', 'Date', 'Supplier', 'Amount', 'Status'];

  // List to store formatted purchases data for the data table
  List<Map<String, dynamic>> _formattedPurchasesData = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadPurchasesData();
    });
  }

  Future<void> _loadPurchasesData() async {
    final purchasesProvider = Provider.of<PurchasesProvider>(context, listen: false);
    
    // Fetch purchases data
    await purchasesProvider.fetchPurchases(
      startDate: _startDate,
      endDate: _endDate,
      searchTerm: _searchController.text.isNotEmpty ? _searchController.text : null,
    );

    // Format the data for the DataTableWidget
    _updateFormattedData();
  }

  void _updateFormattedData() {
    final purchasesProvider = Provider.of<PurchasesProvider>(context, listen: false);
    
    setState(() {
      _formattedPurchasesData = purchasesProvider.purchases.map((purchase) {
        final vat = purchase.amount * _vatRate;
        final total = purchase.amount + vat;
        
        // Map Purchase objects to the format expected by DataTableWidget
        return {
          'id': purchase.id.toString(),
          'date': purchase.date,
          'supplier': purchase.supplier,
          'amount': _moneyFormat.format(purchase.amount),
          'status': purchase.status,
          // Additional fields for details display
          'raw_amount': purchase.amount,
          'raw_vat': vat,
          'raw_total': total,
          'original_purchase': purchase, // Store the original Purchase object
          'receipt_scanned': purchase.receiptId != null,
        };
      }).toList();
    });
  }

  void _handleSearch(String query) {
    _loadPurchasesData();
  }

  void _handleDateRangeChanged(DateTime? start, DateTime? end) {
    setState(() {
      _startDate = start;
      _endDate = end;
    });
    _loadPurchasesData();
  }

  Future<void> _showPurchaseDetails(Map<String, dynamic> purchaseData) async {
    // Get the original Purchase object
    final Purchase purchase = purchaseData['original_purchase'];
    final vat = purchase.amount * _vatRate;
    final total = purchase.amount + vat;
    
    // Fetch detailed purchase info if needed
    final purchasesProvider = Provider.of<PurchasesProvider>(context, listen: false);
    Purchase? detailedPurchase = purchase;
    
    // If we need more detailed info than what's in the list
    if (purchase.items == null || purchase.items!.isEmpty) {
      final response = await purchasesProvider.getPurchaseDetails(purchase.id);
      if (response != null) {
        detailedPurchase = response;
      }
    }

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Purchase Order: ${purchase.id}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow('Date', purchase.date),
              _buildDetailRow('Supplier', purchase.supplier),
              _buildDetailRow('Status', purchase.status),
              _buildDetailRow('Receipt Linked', purchaseData['receipt_scanned'] ? 'Yes' : 'No'),
              
              const SizedBox(height: 16),
              const Text(
                'Items',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              
              // Show items table if items are available
              if (detailedPurchase?.items != null && detailedPurchase!.items!.isNotEmpty)
                Table(
                  border: TableBorder.all(color: Colors.grey.shade300),
                  children: [
                    const TableRow(
                      decoration: BoxDecoration(color: Colors.green),
                      children: [
                        TableCell(
                          child: Padding(
                            padding: EdgeInsets.all(8.0),
                            child: Text(
                              'Item',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        TableCell(
                          child: Padding(
                            padding: EdgeInsets.all(8.0),
                            child: Text(
                              'Qty',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        TableCell(
                          child: Padding(
                            padding: EdgeInsets.all(8.0),
                            child: Text(
                              'Price',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        TableCell(
                          child: Padding(
                            padding: EdgeInsets.all(8.0),
                            child: Text(
                              'Total',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    ...detailedPurchase!.items!.map<TableRow>((item) {
                      final quantity = item.quantity;
                      final price = item.price;
                      final total = quantity * price;
                      
                      return TableRow(
                        children: [
                          TableCell(
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Text(item.name),
                            ),
                          ),
                          TableCell(
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Text(quantity.toString()),
                            ),
                          ),
                          TableCell(
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Text(_moneyFormat.format(price)),
                            ),
                          ),
                          TableCell(
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Text(_moneyFormat.format(total)),
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ],
                )
              else
                const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Text('No items available for this purchase.'),
                ),
              
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(8.0),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8.0),
                ),
                child: Column(
                  children: [
                    _buildSummaryRow('Subtotal', _moneyFormat.format(purchase.amount)),
                    _buildSummaryRow('VAT (18%)', _moneyFormat.format(vat)),
                    const Divider(),
                    _buildSummaryRow('Total', _moneyFormat.format(total), isBold: true),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.edit),
            label: const Text('Edit'),
            onPressed: () {
              Navigator.of(context).pop();
              _showEditPurchaseDialog(purchase);
            },
          ),
          if (!purchaseData['receipt_scanned'])
            ElevatedButton.icon(
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Link Receipt'),
              onPressed: () {
                Navigator.of(context).pop();
                _showLinkReceiptDialog(purchase);
              },
            ),
          ElevatedButton.icon(
            icon: const Icon(Icons.print),
            label: const Text('Print'),
            onPressed: () {
              Navigator.of(context).pop();
              // Implement print functionality
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Print functionality not implemented'),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showEditPurchaseDialog(Purchase purchase) {
    // TODO: Implement edit purchase functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Edit purchase functionality not implemented yet'),
      ),
    );
  }

  void _showAddPurchaseDialog() {
    // TODO: Implement add purchase functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Add new purchase functionality not implemented yet'),
      ),
    );
  }

  void _showLinkReceiptDialog(Purchase purchase) {
    final receiptProvider = Provider.of<ReceiptProvider>(context, listen: false);

    // Basic placeholder - in a real implementation, this would show a list of receipts to link or go to the scanner
    if (receiptProvider.receipts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No receipts available. Please scan a receipt first.'),
        ),
      );
      Navigator.pushNamed(context, 'scan');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Receipt linking functionality not fully implemented yet'),
        ),
      );
    }
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final purchasesProvider = Provider.of<PurchasesProvider>(context);
    final appStateProvider = Provider.of<AppStateProvider>(context);
    
    final bool isLoading = purchasesProvider.isLoading;
    final bool isOffline = appStateProvider.isOffline;
    
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text('Purchases'),
            if (isOffline)
              Container(
                margin: const EdgeInsets.only(left: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.cloud_off, size: 14, color: Colors.orange),
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
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadPurchasesData,
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showAddPurchaseDialog,
            tooltip: 'Add New Purchase',
          ),
        ],
      ),
      body: Column(
        children: [
          if (purchasesProvider.apiRequestStatus == APIRequestStatus.error)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              color: Colors.red.shade100,
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.red),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Error: ${purchasesProvider.lastError}',
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                  TextButton(
                    onPressed: _loadPurchasesData,
                    child: const Text('RETRY'),
                  ),
                ],
              ),
            ),
            
          Expanded(
            child: DataTableWidget(
              data: _formattedPurchasesData,
              columns: _columns,
              columnNames: _columnNames,
              isLoading: isLoading,
              emptyMessage: isLoading 
                  ? 'Loading purchases data...' 
                  : (isOffline ? 'No purchases data available in offline mode' : 'No purchases data available'),
              onRowTap: _showPurchaseDetails,
              searchController: _searchController,
              onSearch: _handleSearch,
              startDate: _startDate,
              endDate: _endDate,
              onDateRangeChanged: _handleDateRangeChanged,
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddPurchaseDialog,
        child: const Icon(Icons.add),
        tooltip: 'Add New Purchase',
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}