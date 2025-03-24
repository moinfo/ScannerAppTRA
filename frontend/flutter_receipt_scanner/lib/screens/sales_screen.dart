import 'package:flutter/material.dart';
import 'package:flutter_receipt_scanner/providers/app_state_provider.dart';
import 'package:flutter_receipt_scanner/providers/sales_provider.dart';
import 'package:flutter_receipt_scanner/screens/add_edit_sale_screen.dart';
import 'package:flutter_receipt_scanner/services/sales_service.dart';
import 'package:flutter_receipt_scanner/utils/api_request_status.dart';
import 'package:flutter_receipt_scanner/widgets/data_table_widget.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class SalesScreen extends StatefulWidget {
  const SalesScreen({Key? key}) : super(key: key);

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  final _searchController = TextEditingController();
  DateTime? _startDate;
  DateTime? _endDate;
  final _moneyFormat = NumberFormat.currency(symbol: 'TZS ', decimalDigits: 2);
  
  // Columns for the data table
  final List<String> _columns = ['id', 'date', 'customer', 'amount', 'status'];
  final List<String> _columnNames = ['ID', 'Date', 'Customer', 'Amount', 'Status'];

  // List to store formatted sales data for the data table
  List<Map<String, dynamic>> _formattedSalesData = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSalesData();
    });
  }

  Future<void> _loadSalesData() async {
    final salesProvider = Provider.of<SalesProvider>(context, listen: false);
    
    // Fetch sales data
    await salesProvider.fetchSales(
      startDate: _startDate,
      endDate: _endDate,
      searchTerm: _searchController.text.isNotEmpty ? _searchController.text : null,
    );

    // Format the data for the DataTableWidget
    _updateFormattedData();
  }

  void _updateFormattedData() {
    final salesProvider = Provider.of<SalesProvider>(context, listen: false);
    final vatRate = 0.18; // 18% VAT
    
    setState(() {
      _formattedSalesData = salesProvider.sales.map((sale) {
        final vat = sale.amount * vatRate;
        final total = sale.amount + vat;
        
        // Map Sale objects to the format expected by DataTableWidget
        return {
          'id': sale.id.toString(),
          'date': sale.date,
          'customer': sale.customer,
          'amount': _moneyFormat.format(sale.amount),
          'status': sale.status,
          // Additional fields for details display
          'raw_amount': sale.amount,
          'raw_vat': vat,
          'raw_total': total,
          'original_sale': sale, // Store the original Sale object for access to items
        };
      }).toList();
    });
  }

  void _handleSearch(String query) {
    _loadSalesData();
  }

  void _handleDateRangeChanged(DateTime? start, DateTime? end) {
    setState(() {
      _startDate = start;
      _endDate = end;
    });
    _loadSalesData();
  }

  Future<void> _showSaleDetails(Map<String, dynamic> saleData) async {
    // Get the original Sale object
    final Sale sale = saleData['original_sale'];
    final vatRate = 0.18; // 18% VAT
    final vat = sale.amount * vatRate;
    final total = sale.amount + vat;
    
    // Fetch detailed sale info if needed
    final salesProvider = Provider.of<SalesProvider>(context, listen: false);
    Sale? detailedSale = sale;
    
    // If we need more detailed info than what's in the list
    if (sale.items.isEmpty) {
      final response = await salesProvider.getSaleDetails(sale.id);
      if (response != null) {
        detailedSale = response;
      }
    }

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Sale Invoice: ${sale.id}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow('Date', sale.date),
              _buildDetailRow('Customer', sale.customer),
              _buildDetailRow('Status', sale.status),
              
              const SizedBox(height: 16),
              const Text(
                'Items',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              Table(
                border: TableBorder.all(color: Colors.grey.shade300),
                children: [
                  const TableRow(
                    decoration: BoxDecoration(color: Colors.blue),
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
                  ...detailedSale!.items!.map<TableRow>((item) {
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
                    _buildSummaryRow('Subtotal', _moneyFormat.format(sale.amount)),
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
              _showEditSaleDialog(sale);
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

  void _showEditSaleDialog(Sale sale) {
    // Navigate to the AddEditSaleScreen to edit the sale
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AddEditSaleScreen(sale: sale),
      ),
    ).then((result) {
      if (result == true) {
        // If sale was updated, refresh the list
        _loadSalesData();
      }
    });
  }

  void _showAddSaleDialog() {
    // Navigate to the AddEditSaleScreen to create a new sale
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const AddEditSaleScreen(),
      ),
    ).then((result) {
      if (result == true) {
        // If sale was created, refresh the list
        _loadSalesData();
      }
    });
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
    final salesProvider = Provider.of<SalesProvider>(context);
    final appStateProvider = Provider.of<AppStateProvider>(context);
    
    final bool isLoading = salesProvider.isLoading;
    final bool isOffline = appStateProvider.isOffline;
    
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text('Sales'),
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
            onPressed: _loadSalesData,
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showAddSaleDialog,
            tooltip: 'Add New Sale',
          ),
        ],
      ),
      body: Column(
        children: [
          if (salesProvider.apiRequestStatus == APIRequestStatus.error)
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
                      'Error: ${salesProvider.lastError}',
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                  TextButton(
                    onPressed: _loadSalesData,
                    child: const Text('RETRY'),
                  ),
                ],
              ),
            ),
            
          Expanded(
            child: DataTableWidget(
              data: _formattedSalesData,
              columns: _columns,
              columnNames: _columnNames,
              isLoading: isLoading,
              emptyMessage: isLoading 
                  ? 'Loading sales data...' 
                  : (isOffline ? 'No sales data available in offline mode' : 'No sales data available'),
              onRowTap: _showSaleDetails,
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
        onPressed: _showAddSaleDialog,
        child: const Icon(Icons.add),
        tooltip: 'Add New Sale',
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}