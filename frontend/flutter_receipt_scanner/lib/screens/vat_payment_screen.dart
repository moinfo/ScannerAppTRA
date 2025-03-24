import 'package:flutter/material.dart';
import 'package:flutter_receipt_scanner/providers/app_state_provider.dart';
import 'package:flutter_receipt_scanner/providers/vat_provider.dart';
import 'package:flutter_receipt_scanner/services/vat_service.dart';
import 'package:flutter_receipt_scanner/utils/api_request_status.dart';
import 'package:flutter_receipt_scanner/widgets/data_table_widget.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class VatPaymentScreen extends StatefulWidget {
  const VatPaymentScreen({Key? key}) : super(key: key);

  @override
  State<VatPaymentScreen> createState() => _VatPaymentScreenState();
}

class _VatPaymentScreenState extends State<VatPaymentScreen> {
  final _searchController = TextEditingController();
  DateTime? _startDate;
  DateTime? _endDate;
  final _moneyFormat = NumberFormat.currency(symbol: 'TZS ', decimalDigits: 2);
  
  // Columns for the data table - these should match the keys in the map used by the DataTableWidget
  final List<String> _columns = ['id', 'period', 'dueDate', 'salesVat', 'purchasesVat', 'amountPayable', 'status', 'actions'];
  final List<String> _columnNames = ['ID', 'Period', 'Due Date', 'Sales VAT', 'Purchases VAT', 'VAT Payable', 'Status', 'Actions'];

  @override
  void initState() {
    super.initState();
    // Fetch VAT payment data when the screen initializes
    // Using post-frame callback to ensure context is ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadVatPaymentData();
      }
    });
  }

  void _loadVatPaymentData() {
    // Using try-catch to handle potential provider access issues
    try {
      final vatProvider = Provider.of<VatProvider>(context, listen: false);
      vatProvider.fetchVatPayments(startDate: _startDate, endDate: _endDate);
    } catch (e) {
      debugPrint('Error accessing VatProvider: $e');
      // Retry after a short delay if provider wasn't ready
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          _loadVatPaymentData();
        }
      });
    }
  }

  void _handleSearch(String query) {
    // Real implementation would filter by query
    _loadVatPaymentData();
  }

  void _handleDateRangeChanged(DateTime? start, DateTime? end) {
    setState(() {
      _startDate = start;
      _endDate = end;
    });
    
    // Reload data with date filters
    _loadVatPaymentData();
  }

  Future<void> _showVatPaymentDetails(dynamic paymentData) async {
    // Cast to Map if it's not a VatPayment object
    Map<String, dynamic> payment;
    int paymentId = 0;
    
    if (paymentData is VatPayment) {
      paymentId = paymentData.id;
      payment = {
        'id': paymentData.id.toString(),
        'period': paymentData.period,
        'dueDate': paymentData.dueDate,
        'salesVat': _moneyFormat.format(paymentData.salesVat),
        'purchasesVat': _moneyFormat.format(paymentData.purchasesVat),
        'vatPayable': _moneyFormat.format(paymentData.amountPayable),
        'status': paymentData.status,
        'paymentDate': paymentData.paymentDate,
        'paymentMethod': paymentData.paymentMethod,
        'paymentReference': paymentData.paymentReference,
        'notes': paymentData.notes,
        'raw_sales_vat': paymentData.salesVat,
        'raw_purchases_vat': paymentData.purchasesVat,
        'raw_vat_payable': paymentData.amountPayable,
      };
    } else {
      payment = paymentData as Map<String, dynamic>;
      paymentId = int.tryParse(payment['id'].toString()) ?? 0;
    }

    final isPaid = payment['status'] == 'Paid' || payment['status'] == 'Completed';
    final isLate = payment['status'] == 'Late';
    
    // Get more details if available and if we don't already have details
    final vatProvider = Provider.of<VatProvider>(context, listen: false);
    if (paymentId > 0 && 
        (payment['paymentMethod'] == null || 
         payment['paymentReference'] == null)) {
      final details = await vatProvider.getVatPaymentDetails(paymentId);
      if (details != null) {
        // Update with additional details if available
        payment['paymentMethod'] = details.paymentMethod ?? '';
        payment['paymentReference'] = details.paymentReference ?? '';
        payment['notes'] = details.notes ?? '';
        payment['paymentDate'] = details.paymentDate ?? '';
      }
    }
    
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
              _buildDetailRow('Due Date', payment['dueDate']),
              if (isPaid || isLate) _buildDetailRow('Payment Date', payment['paymentDate'] ?? 'Not available'),
              if (isPaid && payment['paymentMethod'] != null) _buildDetailRow('Payment Method', payment['paymentMethod']),
              if (isPaid && payment['paymentReference'] != null) _buildDetailRow('Payment Reference', payment['paymentReference']),
              if (payment['notes'] != null && payment['notes'].isNotEmpty) _buildDetailRow('Notes', payment['notes']),
              
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
                    _buildSummaryRow('Sales VAT', payment['salesVat']),
                    _buildSummaryRow('Purchases VAT', payment['purchasesVat']),
                    const Divider(),
                    _buildSummaryRow('VAT Payable', payment['vatPayable'] ?? payment['amountPayable'], isBold: true),
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
                _showPayVatDialog(payment, paymentId);
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

  void _showPayVatDialog(Map<String, dynamic> payment, int paymentId) {
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
                            payment['vatPayable'] ?? payment['amountPayable'],
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
            onPressed: () async {
              final reference = _referenceController.text.trim();
              if (reference.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter a payment reference'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              
              Navigator.of(context).pop();
              
              // Create an updated payment with payment details
              final updatedPayment = VatPayment(
                id: paymentId,
                period: payment['period'],
                salesVat: payment['raw_sales_vat'] ?? 0,
                purchasesVat: payment['raw_purchases_vat'] ?? 0,
                amountPayable: payment['raw_vat_payable'] ?? 0,
                status: 'Completed',
                dueDate: payment['dueDate'],
                paymentDate: DateFormat('yyyy-MM-dd').format(DateTime.now()),
                paymentMethod: _selectedPaymentMethod,
                paymentReference: reference,
                notes: 'Paid via app',
              );
              
              // Process payment through provider
              final vatProvider = Provider.of<VatProvider>(context, listen: false);
              final todayFormatted = DateFormat('yyyy-MM-dd').format(DateTime.now());
              
              final success = await vatProvider.updateVatPaymentStatus(
                paymentId,
                'Completed',
                paymentMethod: _selectedPaymentMethod,
                paymentReference: reference,
                paymentDate: todayFormatted,
                notes: 'Paid via app on ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}',
              );
              
              if (success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('VAT payment for ${payment['period']} processed successfully'),
                    backgroundColor: Colors.green,
                  ),
                );
                _loadVatPaymentData(); // Refresh data
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error processing payment: ${vatProvider.lastError}'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('Process Payment'),
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
            Consumer<VatProvider>(
              builder: (context, vatProvider, _) => ElevatedButton(
                onPressed: (startDate == null || endDate == null || vatProvider.isReportLoading)
                    ? null  // Disable if dates not selected or loading
                    : () async {
                        Navigator.of(context).pop();
                        
                        // Generate report
                        await vatProvider.generateVatReport(startDate!, endDate!);
                        
                        // Show report 
                        if (vatProvider.reportStatus == APIRequestStatus.loaded && vatProvider.currentReport != null) {
                          _showReportResultDialog(vatProvider.currentReport!);
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Failed to generate report: ${vatProvider.lastError}'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      },
                child: vatProvider.isReportLoading 
                  ? const SizedBox(
                      width: 16, 
                      height: 16, 
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)
                    ) 
                  : const Text('Generate Report'),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  void _showReportResultDialog(VatReport report) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('VAT Report: ${report.period}'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetailRow('Period', report.period),
                _buildDetailRow('From', DateFormat('MM/dd/yyyy').format(report.periodStartDate)),
                _buildDetailRow('To', DateFormat('MM/dd/yyyy').format(report.periodEndDate)),
                
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
                      _buildSummaryRow('Total Sales', _moneyFormat.format(report.totalSales)),
                      _buildSummaryRow('Total Purchases', _moneyFormat.format(report.totalPurchases)),
                      const Divider(),
                      _buildSummaryRow('Sales VAT', _moneyFormat.format(report.salesVat)),
                      _buildSummaryRow('Purchases VAT', _moneyFormat.format(report.purchasesVat)),
                      const Divider(),
                      _buildSummaryRow('VAT Payable', _moneyFormat.format(report.vatPayable), isBold: true),
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

  Widget _buildSummaryCard(VatProvider vatProvider) {
    // Calculate summary data
    double totalSalesVat = 0.0;
    double totalPurchasesVat = 0.0;
    double totalVatPayable = 0.0;
    double paidVat = 0.0;
    double pendingVat = 0.0;
    
    for (var payment in vatProvider.vatPayments) {
      totalSalesVat += payment.salesVat;
      totalPurchasesVat += payment.purchasesVat;
      totalVatPayable += payment.amountPayable;
      
      if (payment.status == 'Paid' || payment.status == 'Completed') {
        paidVat += payment.amountPayable;
      } else {
        pendingVat += payment.amountPayable;
      }
    }
    
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
                      _moneyFormat.format(totalSalesVat),
                      Colors.blue,
                    ),
                  ),
                  Expanded(
                    child: _buildSummaryItem(
                      'Total Purchases VAT',
                      _moneyFormat.format(totalPurchasesVat),
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
                      _moneyFormat.format(totalVatPayable),
                      Colors.orange,
                    ),
                  ),
                  Expanded(
                    child: _buildSummaryItem(
                      'Paid VAT',
                      _moneyFormat.format(paidVat),
                      Colors.green.shade700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildSummaryItem(
                'Pending VAT',
                _moneyFormat.format(pendingVat),
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
    // Catch any provider not found errors
    try {
      return Consumer2<VatProvider, AppStateProvider>(
        builder: (context, vatProvider, appStateProvider, _) {
        final isLoading = vatProvider.isLoading;
        final isError = vatProvider.apiRequestStatus == APIRequestStatus.error;
        final isOffline = appStateProvider.isOffline;
        final vatPayments = vatProvider.vatPayments;
        
        // Transform VatPayment objects to map for DataTableWidget
        final List<Map<String, dynamic>> tableData = vatPayments.map((payment) => {
          'id': payment.id.toString(),
          'period': payment.period,
          'dueDate': payment.dueDate,
          'salesVat': _moneyFormat.format(payment.salesVat),
          'purchasesVat': _moneyFormat.format(payment.purchasesVat),
          'amountPayable': _moneyFormat.format(payment.amountPayable),
          'status': payment.status,
        }).toList();
        
        return Scaffold(
          appBar: AppBar(
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('VAT Payments'),
                if (isOffline) 
                  Padding(
                    padding: const EdgeInsets.only(left: 8.0),
                    child: Chip(
                      label: const Text('Offline', style: TextStyle(fontSize: 10, color: Colors.white)),
                      backgroundColor: Colors.deepOrange,
                      padding: const EdgeInsets.all(0),
                    ),
                  ),
              ],
            ),
            automaticallyImplyLeading: false,
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: isLoading ? null : _loadVatPaymentData,
                tooltip: 'Refresh',
              ),
              IconButton(
                icon: const Icon(Icons.add_circle),
                onPressed: isLoading ? null : () {
                  _showCreateVatPaymentDialog();
                },
                tooltip: 'Create VAT Payment',
              ),
              IconButton(
                icon: const Icon(Icons.file_download),
                onPressed: isLoading ? null : () {
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
                onPressed: isLoading ? null : () {
                  _showReportDialog();
                },
                tooltip: 'Generate Report',
              ),
            ],
          ),
          body: Column(
            children: [
              // Show error message if there's an error
              if (isError && !isLoading)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16.0),
                  color: Colors.red.shade100,
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Error: ${vatProvider.lastError}',
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                      TextButton(
                        onPressed: _loadVatPaymentData,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
                
              // Show summary card if data is loaded
              if (!isLoading && vatPayments.isNotEmpty) 
                _buildSummaryCard(vatProvider),
                
              // VAT payments data table
              Expanded(
                child: isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : vatPayments.isEmpty
                        ? const Center(child: Text('No VAT payment data available'))
                        : DataTableWidget(
                            data: tableData,
                            columns: _columns,
                            columnNames: _columnNames,
                            isLoading: false,
                            emptyMessage: 'No VAT payment data available',
                            onRowTap: _showVatPaymentDetails,
                            searchController: _searchController,
                            onSearch: _handleSearch,
                            startDate: _startDate,
                            endDate: _endDate,
                            onDateRangeChanged: _handleDateRangeChanged,
                            actionBuilder: (payment) {
                              final isPaid = payment['status'] == 'Paid' || payment['status'] == 'Completed';
                              return Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (!isPaid)
                                    IconButton(
                                      icon: const Icon(Icons.payment, color: Colors.green),
                                      tooltip: 'Pay VAT',
                                      onPressed: () {
                                        final paymentId = int.tryParse(payment['id'].toString()) ?? 0;
                                        _showPayVatDialog(payment, paymentId);
                                      },
                                    ),
                                  IconButton(
                                    icon: const Icon(Icons.visibility, color: Colors.blue),
                                    tooltip: 'View Details',
                                    onPressed: () => _showVatPaymentDetails(payment),
                                  ),
                                  if (isPaid)
                                    IconButton(
                                      icon: const Icon(Icons.print, color: Colors.purple),
                                      tooltip: 'Print Receipt',
                                      onPressed: () {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('Print functionality not implemented'),
                                          ),
                                        );
                                      },
                                    ),
                                ],
                              );
                            },
                          ),
              ),
            ],
          ),
        );
      },
    );
    } catch (e) {
      debugPrint('Error accessing providers in VatPaymentScreen build: $e');
      // Fallback UI when providers aren't available
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text('Initializing VAT payments...', 
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      );
    }
  }

  void _showCreateVatPaymentDialog() {
    // Current date and time for reference
    final now = DateTime.now();
    final periodFormatter = DateFormat('MMM yyyy');
    final currentPeriod = periodFormatter.format(now);
    
    // Controllers for the form fields
    final periodController = TextEditingController(text: currentPeriod);
    final amountController = TextEditingController();
    final dueDateController = TextEditingController(
      text: DateFormat('yyyy-MM-dd').format(now.add(const Duration(days: 30)))
    );
    
    // Values for VAT calculation
    double salesAmount = 0;
    double purchasesAmount = 0;
    double salesVat = 0;
    double purchasesVat = 0;
    double vatPayable = 0;
    final vatRate = 0.18; // 18% VAT rate
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          // Function to calculate VAT values
          void calculateVat() {
            setState(() {
              salesVat = salesAmount * vatRate;
              purchasesVat = purchasesAmount * vatRate;
              vatPayable = salesVat - purchasesVat;
              if (vatPayable > 0) {
                amountController.text = vatPayable.toStringAsFixed(2);
              } else {
                amountController.text = '0';
              }
            });
          }
          
          return AlertDialog(
            title: const Text('Create VAT Payment'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: periodController,
                    decoration: const InputDecoration(
                      labelText: 'Period',
                      hintText: 'e.g. Jan 2025',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Sales amount with VAT calculation
                  TextField(
                    decoration: const InputDecoration(
                      labelText: 'Sales Amount',
                      hintText: 'Enter total sales amount',
                      border: OutlineInputBorder(),
                      prefixText: 'TZS ',
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (value) {
                      salesAmount = double.tryParse(value) ?? 0;
                      calculateVat();
                    },
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Sales VAT (18%): ${_moneyFormat.format(salesVat)}',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 16),
                  
                  // Purchases amount with VAT calculation
                  TextField(
                    decoration: const InputDecoration(
                      labelText: 'Purchases Amount',
                      hintText: 'Enter total purchases amount',
                      border: OutlineInputBorder(),
                      prefixText: 'TZS ',
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (value) {
                      purchasesAmount = double.tryParse(value) ?? 0;
                      calculateVat();
                    },
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Purchases VAT (18%): ${_moneyFormat.format(purchasesVat)}',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 16),
                  
                  // VAT Payable (calculated)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Text(
                          'VAT Payable: ',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          _moneyFormat.format(vatPayable),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: vatPayable > 0 ? Colors.blue.shade800 : Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Due date
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now().add(const Duration(days: 30)),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked != null) {
                        setState(() {
                          dueDateController.text = DateFormat('yyyy-MM-dd').format(picked);
                        });
                      }
                    },
                    child: AbsorbPointer(
                      child: TextField(
                        controller: dueDateController,
                        decoration: const InputDecoration(
                          labelText: 'Due Date',
                          hintText: 'Select due date',
                          border: OutlineInputBorder(),
                          suffixIcon: Icon(Icons.calendar_today),
                        ),
                      ),
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
                onPressed: vatPayable <= 0
                    ? null
                    : () async {
                        // Create VAT payment
                        final period = periodController.text.trim();
                        if (period.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Please enter a valid period'),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }
                        
                        // Close dialog
                        Navigator.of(context).pop();
                        
                        // Show loading indicator
                        showDialog(
                          context: context,
                          barrierDismissible: false,
                          builder: (context) => const AlertDialog(
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CircularProgressIndicator(),
                                SizedBox(height: 16),
                                Text('Creating VAT payment...'),
                              ],
                            ),
                          ),
                        );
                        
                        try {
                          // Create VAT payment object
                          final payment = VatPayment(
                            id: 0, // Will be assigned by the server or offline storage
                            period: period,
                            salesVat: salesVat,
                            purchasesVat: purchasesVat,
                            amountPayable: vatPayable,
                            status: 'Pending',
                            dueDate: dueDateController.text,
                          );
                          
                          // Create payment via provider
                          final vatProvider = Provider.of<VatProvider>(context, listen: false);
                          final success = await vatProvider.createVatPayment(payment);
                          
                          // Close loading dialog
                          if (context.mounted) {
                            Navigator.of(context).pop();
                          }
                          
                          // Show success or error message
                          if (success && context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('VAT payment for $period created successfully'),
                                backgroundColor: Colors.green,
                              ),
                            );
                            
                            // Refresh data
                            _loadVatPaymentData();
                          } else if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error creating VAT payment: ${vatProvider.lastError}'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        } catch (e) {
                          // Close loading dialog
                          if (context.mounted) {
                            Navigator.of(context).pop();
                          }
                          
                          // Show error message
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error creating VAT payment: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      },
                child: const Text('Create VAT Payment'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}