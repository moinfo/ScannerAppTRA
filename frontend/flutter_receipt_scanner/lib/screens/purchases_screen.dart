import 'package:flutter/material.dart';
import 'package:flutter_receipt_scanner/providers/purchases_provider.dart';
// import 'package:flutter_receipt_scanner/models/purchase.dart';
import 'package:flutter_receipt_scanner/utils/api_request_status.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../services/purchase_service.dart';

class PurchasesScreen extends StatefulWidget {
  const PurchasesScreen({Key? key}) : super(key: key);

  @override
  State<PurchasesScreen> createState() => _PurchasesScreenState();
}

class _PurchasesScreenState extends State<PurchasesScreen> {
  final _searchController = TextEditingController();
  final _dateFormat = DateFormat('dd MMM yyyy');
  final _moneyFormat = NumberFormat.currency(symbol: 'TZS ', decimalDigits: 2);
  bool _isFiltering = false;
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    // Fetch purchases on init
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Provider.of<PurchasesProvider>(context, listen: false).fetchPurchases();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Select date range
  Future<void> _selectDateRange(BuildContext context) async {
    final initialDateRange = DateTimeRange(
      start: _startDate ?? DateTime.now().subtract(const Duration(days: 7)),
      end: _endDate ?? DateTime.now(),
    );

    final newDateRange = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2025),
      initialDateRange: initialDateRange,
    );

    if (newDateRange != null) {
      setState(() {
        _startDate = newDateRange.start;
        _endDate = newDateRange.end;
      });

      // Apply date filter
      _applyFilters();
    }
  }

  // Apply filters (search term and date range)
  void _applyFilters() {
    final purchasesProvider = Provider.of<PurchasesProvider>(context, listen: false);
    purchasesProvider.fetchPurchases(
      startDate: _startDate,
      endDate: _endDate,
      searchTerm: _searchController.text.isNotEmpty ? _searchController.text : null,
    );
  }

  // Show purchase details dialog
  void _showPurchaseDetails(Purchase purchase) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: Colors.green,
              child: const Icon(Icons.shopping_bag, color: Colors.white, size: 16),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Purchase #${purchase.id}',
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
            children: [
              _buildDetailRow('Supplier', purchase.supplier),
              _buildDetailRow('Date', _dateFormat.format(DateTime.parse(purchase.date))),
              _buildDetailRow('Amount', _moneyFormat.format(purchase.amount)),
              _buildDetailRow('Status', purchase.status),

              if (purchase.items != null && purchase.items!.isNotEmpty)
                _buildDetailRow('Items', '${purchase.items!.length} items'),

              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),

              // Items list
              if (purchase.items != null && purchase.items!.isNotEmpty) ...[
                const Text(
                  'Items:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: purchase.items!.length,
                  itemBuilder: (context, index) {
                    final item = purchase.items![index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8.0),
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.description,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Qty: ${item.quantity}'),
                                Text(_moneyFormat.format(item.price)),
                              ],
                            ),
                            if (item.vatAmount != null)
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Text(
                                    'VAT: ${_moneyFormat.format(item.vatAmount)}',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                )
              ] else
                const Text('No item details available'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _showEditPurchaseDialog(purchase);
            },
            child: const Text('Edit'),
          ),
        ],
      ),
    );
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

  // Add new purchase dialog
  void _showAddPurchaseDialog() {
    // Implementation will be added later
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Add purchase functionality coming soon'),
      ),
    );
  }

  // Edit purchase dialog
  void _showEditPurchaseDialog(Purchase purchase) {
    // Implementation will be added later
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Edit purchase functionality coming soon'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Purchases'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () {
              setState(() {
                _isFiltering = !_isFiltering;
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              final purchasesProvider = Provider.of<PurchasesProvider>(context, listen: false);
              purchasesProvider.fetchPurchases();
            },
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter section
          if (_isFiltering)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      labelText: 'Search by supplier',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _applyFilters();
                        },
                      ),
                    ),
                    onSubmitted: (_) => _applyFilters(),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.date_range),
                          label: Text(_startDate != null && _endDate != null
                              ? '${_dateFormat.format(_startDate!)} - ${_dateFormat.format(_endDate!)}'
                              : 'Select Date Range'),
                          onPressed: () => _selectDateRange(context),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.filter_list),
                        onPressed: _applyFilters,
                      ),
                      IconButton(
                        icon: const Icon(Icons.clear_all),
                        onPressed: () {
                          setState(() {
                            _startDate = null;
                            _endDate = null;
                            _searchController.clear();
                          });
                          _applyFilters();
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),

          // Purchases List
          Expanded(
            child: Consumer<PurchasesProvider>(
              builder: (context, purchasesProvider, child) {
                final isLoading = purchasesProvider.isLoading;

                if (isLoading) {
                  return const Center(child: CircularProgressIndicator());
                } else if (purchasesProvider.apiRequestStatus == APIRequestStatus.error) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 60, color: Colors.red),
                        const SizedBox(height: 16),
                        Text('Error: ${purchasesProvider.lastError}'),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => purchasesProvider.fetchPurchases(),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  );
                } else if (purchasesProvider.purchases.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.shopping_bag, size: 60, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        const Text(
                          'No purchases recorded yet',
                          style: TextStyle(fontSize: 18),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Add purchases manually',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: _showAddPurchaseDialog,
                          icon: const Icon(Icons.add),
                          label: const Text('Add Purchase Manually'),
                        ),
                      ],
                    ),
                  );
                } else {
                  // Show purchases list
                  return RefreshIndicator(
                    onRefresh: () => purchasesProvider.fetchPurchases(),
                    child: ListView.builder(
                      itemCount: purchasesProvider.purchases.length,
                      itemBuilder: (context, index) {
                        final purchase = purchasesProvider.purchases[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.green,
                              child: const Icon(Icons.shopping_bag, color: Colors.white, size: 16),
                            ),
                            title: Text(
                              purchase.supplier,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              'Date: ${_dateFormat.format(DateTime.parse(purchase.date))}',
                            ),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  _moneyFormat.format(purchase.amount),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                Text(
                                  purchase.status,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: purchase.status == 'Paid'
                                        ? Colors.green
                                        : Colors.orange,
                                  ),
                                ),
                              ],
                            ),
                            onTap: () => _showPurchaseDetails(purchase),
                          ),
                        );
                      },
                    ),
                  );
                }
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddPurchaseDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}