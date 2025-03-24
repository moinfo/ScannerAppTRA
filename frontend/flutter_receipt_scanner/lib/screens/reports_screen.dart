import 'package:flutter/material.dart';
import 'package:flutter_receipt_scanner/services/report_service.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({Key? key}) : super(key: key);

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  bool _isLoading = false;
  bool _isExporting = false;
  final _moneyFormat = NumberFormat.currency(symbol: 'TZS ', decimalDigits: 2);
  DateTime? _startDate;
  DateTime? _endDate;
  String _selectedReportType = 'sales';
  String _selectedPeriod = 'monthly';
  final ReportService _reportService = ReportService();
  
  // Sample data for reports
  final Map<String, List<Map<String, dynamic>>> _reportData = {
    'sales': [],
    'purchases': [],
    'vat': [],
  };

  @override
  void initState() {
    super.initState();
    
    // Set default date range (last 6 months)
    final now = DateTime.now();
    _endDate = now;
    _startDate = DateTime(now.year, now.month - 5, 1);
    
    _loadReportData();
  }

  void _loadReportData() {
    setState(() {
      _isLoading = true;
    });
    
    // Simulate API call
    Future.delayed(const Duration(seconds: 1), () {
      final random = math.Random();
      
      // Generate monthly data for sales, purchases, and VAT
      final now = DateTime.now();
      final months = _generateMonthsBetween(_startDate ?? DateTime(now.year, now.month - 5, 1), _endDate ?? now);
      
      // Sales data
      final salesData = months.map((date) {
        final month = DateFormat('MMM yyyy').format(date);
        final amount = (random.nextDouble() * 5000000) + 1000000;
        
        return {
          'period': month,
          'date': date,
          'amount': amount,
          'formatted_amount': _moneyFormat.format(amount),
          'count': random.nextInt(30) + 10,
        };
      }).toList();
      
      // Purchases data
      final purchasesData = months.map((date) {
        final month = DateFormat('MMM yyyy').format(date);
        final amount = (random.nextDouble() * 3000000) + 500000;
        
        return {
          'period': month,
          'date': date,
          'amount': amount,
          'formatted_amount': _moneyFormat.format(amount),
          'count': random.nextInt(20) + 5,
        };
      }).toList();
      
      // VAT data
      final vatData = months.map((date) {
        final month = DateFormat('MMM yyyy').format(date);
        final salesVat = (salesData.firstWhere((item) => item['period'] == month)['amount'] as num).toDouble() * 0.18;
        final purchasesVat = (purchasesData.firstWhere((item) => item['period'] == month)['amount'] as num).toDouble() * 0.18;
        final vatPayable = salesVat - purchasesVat;
        
        return {
          'period': month,
          'date': date,
          'sales_vat': salesVat,
          'formatted_sales_vat': _moneyFormat.format(salesVat),
          'purchases_vat': purchasesVat,
          'formatted_purchases_vat': _moneyFormat.format(purchasesVat),
          'vat_payable': vatPayable,
          'formatted_vat_payable': _moneyFormat.format(vatPayable),
        };
      }).toList();
      
      setState(() {
        _reportData['sales'] = salesData;
        _reportData['purchases'] = purchasesData;
        _reportData['vat'] = vatData;
        _isLoading = false;
      });
    });
  }
  
  List<DateTime> _generateMonthsBetween(DateTime start, DateTime end) {
    List<DateTime> months = [];
    DateTime current = DateTime(start.year, start.month, 1);
    
    while (current.isBefore(DateTime(end.year, end.month + 1, 1))) {
      months.add(current);
      current = DateTime(current.year, current.month + 1, 1);
    }
    
    return months;
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
      _loadReportData();
    }
  }

  void _changeReportType(String type) {
    setState(() {
      _selectedReportType = type;
    });
  }

  void _changePeriod(String period) {
    setState(() {
      _selectedPeriod = period;
    });
  }

  Future<void> _exportReport() async {
    // Show export options dialog
    final format = await _showExportOptionsDialog();
    if (format == null) return;
    
    try {
      setState(() {
        _isExporting = true;
      });
      
      // Get the report type
      ReportType reportType;
      switch (_selectedReportType) {
        case 'sales':
          reportType = ReportType.sales;
          break;
        case 'purchases':
          reportType = ReportType.purchases;
          break;
        case 'vat':
          reportType = ReportType.vat;
          break;
        default:
          reportType = ReportType.sales;
      }
      
      // Get the report period
      ReportPeriod reportPeriod;
      switch (_selectedPeriod) {
        case 'daily':
          reportPeriod = ReportPeriod.daily;
          break;
        case 'weekly':
          reportPeriod = ReportPeriod.weekly;
          break;
        case 'monthly':
          reportPeriod = ReportPeriod.monthly;
          break;
        case 'quarterly':
          reportPeriod = ReportPeriod.quarterly;
          break;
        case 'yearly':
          reportPeriod = ReportPeriod.yearly;
          break;
        default:
          reportPeriod = ReportPeriod.monthly;
      }
      
      // Generate the report
      final filePath = await _reportService.generateReport(
        data: _reportData[_selectedReportType] ?? [],
        reportType: reportType,
        reportPeriod: reportPeriod,
        format: format,
        startDate: _startDate,
        endDate: _endDate,
      );
      
      // Show success message with option to view the file
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Report exported to: $filePath'),
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'VIEW',
              onPressed: () => _openFile(filePath),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to export report: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isExporting = false;
        });
      }
    }
  }
  
  Future<ReportFormat?> _showExportOptionsDialog() async {
    return showDialog<ReportFormat>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Export Report'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Choose export format:'),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.picture_as_pdf),
                  label: const Text('PDF'),
                  onPressed: () => Navigator.of(context).pop(ReportFormat.pdf),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.table_chart),
                  label: const Text('CSV'),
                  onPressed: () => Navigator.of(context).pop(ReportFormat.csv),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('CANCEL'),
          ),
        ],
      ),
    );
  }
  
  Future<void> _openFile(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        final uri = Uri.file(filePath);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri);
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Could not open file. No app available to handle this file type.'),
              ),
            );
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('File does not exist'),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening file: $e'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadReportData,
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: const Icon(Icons.file_download),
            onPressed: _exportReport,
            tooltip: 'Export Report',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildReportOptions(),
            const SizedBox(height: 24),
            _buildChart(),
            const SizedBox(height: 24),
            const Text(
              'Report Details',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _buildReportDetails(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportOptions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.date_range),
                label: Text(
                  _startDate != null && _endDate != null
                      ? '${DateFormat('dd/MM/yyyy').format(_startDate!)} - ${DateFormat('dd/MM/yyyy').format(_endDate!)}'
                      : 'Select Date Range',
                ),
                onPressed: () => _selectDateRange(context),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              icon: _isExporting 
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.file_download),
              label: Text(_isExporting ? 'Exporting...' : 'Export'),
              onPressed: _isExporting ? null : _exportReport,
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            _buildReportTypeButton('Sales', 'sales', Icons.shopping_cart),
            _buildReportTypeButton('Purchases', 'purchases', Icons.shopping_bag),
            _buildReportTypeButton('VAT', 'vat', Icons.payments),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            _buildPeriodButton('Monthly', 'monthly'),
            _buildPeriodButton('Quarterly', 'quarterly'),
            _buildPeriodButton('Yearly', 'yearly'),
          ],
        ),
      ],
    );
  }

  Widget _buildReportTypeButton(String label, String value, IconData icon) {
    final isSelected = _selectedReportType == value;
    
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4.0),
        child: ElevatedButton.icon(
          icon: Icon(
            icon,
            color: isSelected ? Colors.white : null,
          ),
          label: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : null,
            ),
          ),
          onPressed: () => _changeReportType(value),
          style: ElevatedButton.styleFrom(
            backgroundColor: isSelected ? Theme.of(context).primaryColor : Colors.grey.shade200,
            foregroundColor: isSelected ? Colors.white : Colors.black87,
          ),
        ),
      ),
    );
  }

  Widget _buildPeriodButton(String label, String value) {
    final isSelected = _selectedPeriod == value;
    
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4.0),
        child: OutlinedButton(
          onPressed: () => _changePeriod(value),
          style: OutlinedButton.styleFrom(
            backgroundColor: isSelected ? Colors.blue.shade50 : null,
            side: BorderSide(
              color: isSelected ? Theme.of(context).primaryColor : Colors.grey,
            ),
          ),
          child: Text(label),
        ),
      ),
    );
  }

  Widget _buildChart() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }
    
    final data = _reportData[_selectedReportType] ?? [];
    if (data.isEmpty) {
      return const Center(
        child: Text('No data available for the selected period'),
      );
    }
    
    // Find max value for scaling
    double maxValue = 0;
    if (_selectedReportType == 'vat') {
      for (var item in data) {
        maxValue = math.max(maxValue, item['sales_vat'] as double);
        maxValue = math.max(maxValue, item['purchases_vat'] as double);
      }
    } else {
      for (var item in data) {
        maxValue = math.max(maxValue, item['amount'] as double);
      }
    }
    
    return Container(
      height: 200,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _getReportTitle(),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: data.map((item) {
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: _buildChartBar(item),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: data.map((item) {
              return Expanded(
                child: Text(
                  DateFormat('MMM').format(item['date']),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildChartBar(Map<String, dynamic> item) {
    if (_selectedReportType == 'vat') {
      // For VAT, show both sales and purchases VAT as stacked bars
      final salesVat = item['sales_vat'] as double;
      final purchasesVat = item['purchases_vat'] as double;
      final maxValue = math.max(salesVat, purchasesVat) * 1.2; // Add some padding
      
      return Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Container(
            height: (salesVat / maxValue) * 120,
            width: 20,
            decoration: BoxDecoration(
              color: Colors.blue,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(4),
              ),
            ),
          ),
          Container(
            height: (purchasesVat / maxValue) * 120,
            width: 20,
            decoration: BoxDecoration(
              color: Colors.green,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(4),
                bottomRight: Radius.circular(4),
              ),
            ),
          ),
        ],
      );
    } else {
      // For sales and purchases, show simple bars
      final amount = item['amount'] as double;
      final maxAmount = _reportData[_selectedReportType]!
        .map((item) => item['amount'] as double)
        .reduce((a, b) => math.max(a, b));
      
      final height = (amount / maxAmount) * 140;
      final color = _selectedReportType == 'sales' ? Colors.blue : Colors.green;
      
      return Container(
        height: height,
        width: 20,
        decoration: BoxDecoration(
          color: color,
          borderRadius: const BorderRadius.all(Radius.circular(4)),
        ),
      );
    }
  }

  Widget _buildReportDetails() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }
    
    final data = _reportData[_selectedReportType] ?? [];
    if (data.isEmpty) {
      return const Center(
        child: Text('No data available for the selected period'),
      );
    }
    
    if (_selectedReportType == 'vat') {
      return _buildVatReportDetails(data);
    } else {
      return _buildGenericReportDetails(data);
    }
  }

  Widget _buildGenericReportDetails(List<Map<String, dynamic>> data) {
    return Card(
      elevation: 2,
      child: ListView.separated(
        itemCount: data.length,
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final item = data[index];
          return ListTile(
            title: Text(
              item['period'],
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: Text('${item['count']} transactions'),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  item['formatted_amount'],
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  'Avg: ${_moneyFormat.format(item['amount'] / item['count'])}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildVatReportDetails(List<Map<String, dynamic>> data) {
    return Card(
      elevation: 2,
      child: ListView.separated(
        itemCount: data.length,
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final item = data[index];
          return ExpansionTile(
            title: Text(
              item['period'],
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: Text(
              'VAT Payable: ${item['formatted_vat_payable']}',
              style: TextStyle(
                color: (item['vat_payable'] as double) > 0 ? Colors.green : Colors.red,
              ),
            ),
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    _buildDetailRow('Sales VAT', item['formatted_sales_vat']),
                    _buildDetailRow('Purchases VAT', item['formatted_purchases_vat']),
                    const Divider(),
                    _buildDetailRow(
                      'VAT Payable', 
                      item['formatted_vat_payable'],
                      valueStyle: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: (item['vat_payable'] as double) > 0 ? Colors.green : Colors.red,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {TextStyle? valueStyle}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: valueStyle,
          ),
        ],
      ),
    );
  }

  String _getReportTitle() {
    switch (_selectedReportType) {
      case 'sales':
        return 'Sales Report';
      case 'purchases':
        return 'Purchases Report';
      case 'vat':
        return 'VAT Report';
      default:
        return 'Report';
    }
  }
}