import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VAT Screen Test',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const VatPaymentScreen(),
    );
  }
}

// Here we've included the entire VatPaymentScreen implementation directly
class VatPaymentScreen extends StatefulWidget {
  const VatPaymentScreen({Key? key}) : super(key: key);

  @override
  State<VatPaymentScreen> createState() => _VatPaymentScreenState();
}

class _VatPaymentScreenState extends State<VatPaymentScreen> {
  final _searchController = TextEditingController();
  bool _isLoading = false;
  DateTime? _startDate;
  DateTime? _endDate;
  final _moneyFormat = NumberFormat.currency(symbol: 'TZS ', decimalDigits: 2);
  
  // List of VAT payment data
  final List<Map<String, dynamic>> _vatPaymentData = [];
  
  // Columns for the data table
  final List<String> _columns = ['id', 'period', 'payment_date', 'sales_vat', 'purchases_vat', 'vat_payable', 'status'];
  final List<String> _columnNames = ['ID', 'Period', 'Payment Date', 'Sales VAT', 'Purchases VAT', 'VAT Payable', 'Status'];

  // Summary data
  Map<String, dynamic> _summary = {
    'total_sales_vat': 0.0,
    'total_purchases_vat': 0.0,
    'total_vat_payable': 0.0,
    'paid_vat': 0.0,
    'pending_vat': 0.0,
  };

  @override
  void initState() {
    super.initState();
    _loadVatPaymentData();
  }

  void _loadVatPaymentData() {
    setState(() {
      _isLoading = true;
    });
    
    // Simulate API call
    Future.delayed(const Duration(seconds: 1), () {
      // Generate random VAT payment data
      final random = math.Random();
      final now = DateTime.now();
      final currentYear = now.year;
      final currentMonth = now.month;
      final statuses = ['Paid', 'Pending', 'Processing', 'Late'];
      
      final vatPayments = <Map<String, dynamic>>[];
      double totalSalesVat = 0.0;
      double totalPurchasesVat = 0.0;
      double totalVatPayable = 0.0;
      double paidVat = 0.0;
      double pendingVat = 0.0;
      
      // Generate data for the past 12 months
      for (int i = 0; i < 12; i++) {
        final month = (currentMonth - i) > 0 ? (currentMonth - i) : (currentMonth - i + 12);
        final year = (currentMonth - i) > 0 ? currentYear : currentYear - 1;
        final periodMonth = DateFormat('MMMM').format(DateTime(2022, month));
        
        final salesVat = (random.nextDouble() * 300000) + 50000;
        final purchasesVat = (random.nextDouble() * 200000) + 20000;
        final vatPayable = salesVat - purchasesVat;
        
        final status = i < 3 ? 'Pending' : statuses[random.nextInt(statuses.length)];
        final paymentDate = status == 'Paid' || status == 'Late' 
            ? DateFormat('yyyy-MM-dd').format(DateTime(year, month + 1, random.nextInt(20) + 1))
            : '';
            
        // Update summary data
        totalSalesVat += salesVat;
        totalPurchasesVat += purchasesVat;
        totalVatPayable += vatPayable;
        if (status == 'Paid') {
          paidVat += vatPayable;
        } else {
          pendingVat += vatPayable;
        }
        
        vatPayments.add({
          'id': 'VAT-$year-${month.toString().padLeft(2, '0')}',
          'period': '$periodMonth $year',
          'period_month': month,
          'period_year': year,
          'payment_date': paymentDate,
          'sales_vat': _moneyFormat.format(salesVat),
          'purchases_vat': _moneyFormat.format(purchasesVat),
          'vat_payable': _moneyFormat.format(vatPayable),
          'status': status,
          // Additional fields for details
          'raw_sales_vat': salesVat,
          'raw_purchases_vat': purchasesVat,
          'raw_vat_payable': vatPayable,
          'due_date': DateFormat('yyyy-MM-dd').format(DateTime(year, month + 1, 20)),
          'payment_method': status == 'Paid' ? (random.nextBool() ? 'Bank Transfer' : 'TRA Portal') : '',
          'payment_reference': status == 'Paid' ? 'REF-${random.nextInt(10000) + 10000}' : '',
          'notes': random.nextBool() ? 'Filed on time' : '',
        });
      }
      
      // Sort by period year and month (newest first)
      vatPayments.sort((a, b) {
        final yearCompare = b['period_year'].compareTo(a['period_year']);
        if (yearCompare != 0) return yearCompare;
        return b['period_month'].compareTo(a['period_month']);
      });
      
      setState(() {
        _vatPaymentData.clear();
        _vatPaymentData.addAll(vatPayments);
        
        _summary = {
          'total_sales_vat': totalSalesVat,
          'total_purchases_vat': totalPurchasesVat,
          'total_vat_payable': totalVatPayable,
          'paid_vat': paidVat,
          'pending_vat': pendingVat,
        };
        
        _isLoading = false;
      });
    });
  }

  void _handleSearch(String query) {
    // In a real implementation, this would filter the data
    _loadVatPaymentData();
  }

  void _handleDateRangeChanged(DateTime? start, DateTime? end) {
    setState(() {
      _startDate = start;
      _endDate = end;
    });
    // In a real implementation, this would filter by date
    _loadVatPaymentData();
  }

  void _showVatPaymentDetails(Map<String, dynamic> payment) {
    final isPaid = payment['status'] == 'Paid';
    final isLate = payment['status'] == 'Late';
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('VAT Payment: ${payment['period']}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow('Period', payment['period']),
              _buildDetailRow('Status', payment['status']),
              _buildDetailRow('Due Date', payment['due_date']),
              if (isPaid || isLate) _buildDetailRow('Payment Date', payment['payment_date']),
              if (isPaid) _buildDetailRow('Payment Method', payment['payment_method']),
              if (isPaid) _buildDetailRow('Payment Reference', payment['payment_reference']),
              if (payment['notes'].isNotEmpty) _buildDetailRow('Notes', payment['notes']),
              
              const SizedBox(height: 16),
              const Text(
                'VAT Summary',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8.0),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8.0),
                ),
                child: Column(
                  children: [
                    _buildSummaryRow('Sales VAT', payment['sales_vat']),
                    _buildSummaryRow('Purchases VAT', payment['purchases_vat']),
                    const Divider(),
                    _buildSummaryRow('VAT Payable', payment['vat_payable'], isBold: true),
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
          if (!isPaid && !isLate)
            ElevatedButton.icon(
              icon: const Icon(Icons.payments),
              label: const Text('Pay VAT'),
              onPressed: () {
                Navigator.of(context).pop();
                _showPayVatDialog(payment);
              },
            ),
          if (isPaid || isLate)
            ElevatedButton.icon(
              icon: const Icon(Icons.print),
              label: const Text('Print Receipt'),
              onPressed: () {
                Navigator.of(context).pop();
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

  void _showPayVatDialog(Map<String, dynamic> payment) {
    final TextEditingController _referenceController = TextEditingController();
    String _selectedPaymentMethod = 'TRA Portal';
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Pay VAT for ${payment['period']}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8.0),
                ),
                child: Row(
                  children: [
                    Icon(Icons.payments, color: Colors.blue.shade700),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Amount Due:',
                            style: TextStyle(
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            payment['vat_payable'],
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Payment Method',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              StatefulBuilder(
                builder: (context, setState) => Column(
                  children: [
                    RadioListTile<String>(
                      title: const Text('TRA Portal'),
                      value: 'TRA Portal',
                      groupValue: _selectedPaymentMethod,
                      onChanged: (value) {
                        setState(() {
                          _selectedPaymentMethod = value!;
                        });
                      },
                    ),
                    RadioListTile<String>(
                      title: const Text('Bank Transfer'),
                      value: 'Bank Transfer',
                      groupValue: _selectedPaymentMethod,
                      onChanged: (value) {
                        setState(() {
                          _selectedPaymentMethod = value!;
                        });
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _referenceController,
                decoration: const InputDecoration(
                  labelText: 'Payment Reference',
                  hintText: 'Enter payment reference number',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Process payment
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('VAT payment for ${payment['period']} processed successfully'),
                  backgroundColor: Colors.green,
                ),
              );
              _loadVatPaymentData(); // Refresh data
            },
            child: const Text('Process Payment'),
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

  Widget _buildSummaryCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16.0),
      child: Card(
        elevation: 4,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'VAT Payment Summary',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildSummaryItem(
                      'Total Sales VAT',
                      _moneyFormat.format(_summary['total_sales_vat']),
                      Colors.blue,
                    ),
                  ),
                  Expanded(
                    child: _buildSummaryItem(
                      'Total Purchases VAT',
                      _moneyFormat.format(_summary['total_purchases_vat']),
                      Colors.green,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildSummaryItem(
                      'Total VAT Payable',
                      _moneyFormat.format(_summary['total_vat_payable']),
                      Colors.orange,
                    ),
                  ),
                  Expanded(
                    child: _buildSummaryItem(
                      'Paid VAT',
                      _moneyFormat.format(_summary['paid_vat']),
                      Colors.green.shade700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildSummaryItem(
                'Pending VAT',
                _moneyFormat.format(_summary['pending_vat']),
                Colors.red,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[600],
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('VAT Payments'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadVatPaymentData,
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: const Icon(Icons.file_download),
            onPressed: () {
              // Export data functionality
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Export functionality not implemented'),
                ),
              );
            },
            tooltip: 'Export Data',
          ),
          // Add a button for generating reports
          IconButton(
            icon: const Icon(Icons.summarize),
            onPressed: () {
              _showReportDialog();
            },
            tooltip: 'Generate Report',
          ),
        ],
      ),
      body: Column(
        children: [
          if (!_isLoading) _buildSummaryCard(),
          // Search and filter bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        _handleSearch('');
                      },
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10.0),
                    ),
                  ),
                  onSubmitted: _handleSearch,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.date_range),
                        label: Text(
                          _startDate != null && _endDate != null
                              ? '${DateFormat('MM/dd/yyyy').format(_startDate!)} - ${DateFormat('MM/dd/yyyy').format(_endDate!)}'
                              : 'Select Date Range',
                        ),
                        onPressed: () async {
                          final DateTimeRange? picked = await showDateRangePicker(
                            context: context,
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now(),
                            initialDateRange: _startDate != null && _endDate != null
                                ? DateTimeRange(start: _startDate!, end: _endDate!)
                                : null,
                          );
                          
                          if (picked != null) {
                            _handleDateRangeChanged(picked.start, picked.end);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      icon: const Icon(Icons.clear_all),
                      label: const Text('Clear Filters'),
                      onPressed: () {
                        _searchController.clear();
                        _handleDateRangeChanged(null, null);
                        _handleSearch('');
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          // VAT payments data table
          Expanded(
            child: _isLoading 
                ? const Center(child: CircularProgressIndicator())
                : _vatPaymentData.isEmpty
                    ? const Center(child: Text('No VAT payment data available'))
                    : _buildDataTable(),
          ),
        ],
      ),
    );
  }

  void _showReportDialog() {
    DateTime? startDate;
    DateTime? endDate;
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Generate VAT Report'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Select period for VAT report'),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.calendar_today),
                      label: Text(startDate != null 
                          ? DateFormat('MM/dd/yyyy').format(startDate!)
                          : 'Start Date'),
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now().subtract(const Duration(days: 30)),
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null) {
                          setState(() {
                            startDate = picked;
                          });
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.calendar_today),
                      label: Text(endDate != null 
                          ? DateFormat('MM/dd/yyyy').format(endDate!)
                          : 'End Date'),
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null) {
                          setState(() {
                            endDate = picked;
                          });
                        }
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: startDate == null || endDate == null
                  ? null  // Disable if dates not selected
                  : () {
                      Navigator.of(context).pop();
                      
                      // Show success message
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('VAT Report generated successfully'),
                          backgroundColor: Colors.green,
                        ),
                      );
                      
                      // In the real implementation, this would call vatProvider.generateVatReport(startDate!, endDate!)
                      _showReportResultDialog(startDate!, endDate!);
                    },
              child: const Text('Generate Report'),
            ),
          ],
        ),
      ),
    );
  }
  
  void _showReportResultDialog(DateTime startDate, DateTime endDate) {
    // Generate simple mock report based on the selected period
    final period = '${DateFormat('MMM yyyy').format(startDate)} - ${DateFormat('MMM yyyy').format(endDate)}';
    final random = math.Random();
    
    final totalSales = 5000000.0 + random.nextDouble() * 5000000.0;
    final totalPurchases = 3000000.0 + random.nextDouble() * 3000000.0;
    final salesVat = totalSales * 0.18;
    final purchasesVat = totalPurchases * 0.18;
    final vatPayable = salesVat - purchasesVat;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('VAT Report: $period'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetailRow('Period', period),
                _buildDetailRow('From', DateFormat('MM/dd/yyyy').format(startDate)),
                _buildDetailRow('To', DateFormat('MM/dd/yyyy').format(endDate)),
                
                const SizedBox(height: 16),
                const Text(
                  'VAT Summary',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8.0),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  child: Column(
                    children: [
                      _buildSummaryRow('Total Sales', _moneyFormat.format(totalSales)),
                      _buildSummaryRow('Total Purchases', _moneyFormat.format(totalPurchases)),
                      const Divider(),
                      _buildSummaryRow('Sales VAT', _moneyFormat.format(salesVat)),
                      _buildSummaryRow('Purchases VAT', _moneyFormat.format(purchasesVat)),
                      const Divider(),
                      _buildSummaryRow('VAT Payable', _moneyFormat.format(vatPayable), isBold: true),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.print),
            label: const Text('Print Report'),
            onPressed: () {
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Print functionality not implemented'),
                ),
              );
            },
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.file_download),
            label: const Text('Export Report'),
            onPressed: () {
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Export functionality not implemented'),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
  
  Widget _buildDataTable() {
    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: _columnNames.map((name) => DataColumn(
            label: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
          )).toList(),
          rows: _vatPaymentData.map((payment) => DataRow(
            cells: _columns.map((column) => DataCell(
              Text(payment[column]?.toString() ?? ''),
            )).toList(),
            onSelectChanged: (_) => _showVatPaymentDetails(payment),
          )).toList(),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}