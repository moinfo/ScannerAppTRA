import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_receipt_scanner/config/api_config.dart';
import 'package:flutter_receipt_scanner/services/api_service.dart';
import 'package:flutter_receipt_scanner/services/sales_service.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:csv/csv.dart';

enum ReportType { sales, purchases, vat }
enum ReportPeriod { daily, weekly, monthly, quarterly, yearly }
enum ReportFormat { pdf, csv }

class ReportService {
  // Singleton pattern
  static final ReportService _instance = ReportService._internal();
  factory ReportService() => _instance;
  ReportService._internal();

  final ApiService _apiService = ApiService();
  final _moneyFormat = NumberFormat.currency(symbol: 'TZS ', decimalDigits: 2);
  
  // Get report data from API
  Future<ApiResponse<List<Map<String, dynamic>>>> getReportData({
    required ReportType reportType,
    required ReportPeriod period,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      // Check for offline mode
      final isOfflineMode = await _apiService.isOfflineMode();
      
      if (isOfflineMode) {
        return ApiResponse.error('Reports are not available in offline mode');
      }
      
      // Build endpoint based on report type
      String endpoint;
      switch (reportType) {
        case ReportType.sales:
          endpoint = '${ApiConfig.reportsUrl}/sales';
          break;
        case ReportType.purchases:
          endpoint = '${ApiConfig.reportsUrl}/purchases';
          break;
        case ReportType.vat:
          endpoint = '${ApiConfig.reportsUrl}/vat';
          break;
      }
      
      // Build query parameters
      final Map<String, dynamic> queryParams = {
        'period': _getPeriodString(period),
      };
      
      if (startDate != null && endDate != null) {
        queryParams['start_date'] = DateFormat('yyyy-MM-dd').format(startDate);
        queryParams['end_date'] = DateFormat('yyyy-MM-dd').format(endDate);
      }
      
      // Make API call
      final response = await _apiService.get<Map<String, dynamic>>(
        endpoint,
        queryParams: queryParams,
        fromJson: (json) => json,
      );
      
      if (response.success) {
        final List<dynamic> data = response.data!['data'] as List;
        final reportData = data.map((item) => item as Map<String, dynamic>).toList();
        return ApiResponse.success(reportData);
      } else {
        return ApiResponse.error(response.errorMessage ?? 'Failed to fetch report data');
      }
    } catch (e) {
      debugPrint('Error in getReportData: $e');
      return ApiResponse.error('Failed to fetch report data: $e');
    }
  }
  
  // Helper method to convert period enum to string
  String _getPeriodString(ReportPeriod period) {
    switch (period) {
      case ReportPeriod.daily:
        return 'daily';
      case ReportPeriod.weekly:
        return 'weekly';
      case ReportPeriod.monthly:
        return 'monthly';
      case ReportPeriod.quarterly:
        return 'quarterly';
      case ReportPeriod.yearly:
        return 'yearly';
    }
  }

  // Generate and save a report as PDF or CSV
  Future<String> generateReport({
    required List<Map<String, dynamic>> data,
    required ReportType reportType,
    required ReportPeriod reportPeriod,
    required ReportFormat format,
    required DateTime? startDate,
    required DateTime? endDate,
  }) async {
    try {
      final fileName = _generateFileName(reportType, format);
      
      // Generate the appropriate file format
      if (format == ReportFormat.pdf) {
        return await _generatePdfReport(data, reportType, reportPeriod, startDate, endDate, fileName);
      } else {
        return await _generateCsvReport(data, reportType, reportPeriod, startDate, endDate, fileName);
      }
    } catch (e) {
      debugPrint('Error generating report: $e');
      throw Exception('Failed to generate report: $e');
    }
  }

  // Generate a PDF report
  Future<String> _generatePdfReport(
    List<Map<String, dynamic>> data, 
    ReportType reportType,
    ReportPeriod reportPeriod,
    DateTime? startDate,
    DateTime? endDate,
    String fileName,
  ) async {
    // Create a PDF document
    final pdf = pw.Document();
    
    // Add title and metadata
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        header: (context) => _buildPdfHeader(reportType, reportPeriod, startDate, endDate),
        build: (context) => [
          _buildPdfTitle(reportType),
          pw.SizedBox(height: 20),
          _buildPdfSummary(data, reportType),
          pw.SizedBox(height: 20),
          _buildPdfTable(data, reportType),
        ],
        footer: (context) => _buildPdfFooter(context.pageNumber, context.pagesCount),
      ),
    );
    
    // Save the PDF to a file
    final directory = await getApplicationDocumentsDirectory();
    final filePath = '${directory.path}/$fileName';
    final file = File(filePath);
    await file.writeAsBytes(await pdf.save());
    
    return filePath;
  }

  // Generate a CSV report
  Future<String> _generateCsvReport(
    List<Map<String, dynamic>> data, 
    ReportType reportType,
    ReportPeriod reportPeriod,
    DateTime? startDate,
    DateTime? endDate,
    String fileName,
  ) async {
    // Create CSV data
    List<List<dynamic>> csvData = [];
    
    // Add headers based on report type
    if (reportType == ReportType.sales || reportType == ReportType.purchases) {
      csvData.add(['Period', 'Date', 'Count', 'Amount']);
      
      // Add rows
      for (var item in data) {
        csvData.add([
          item['period'],
          DateFormat('yyyy-MM-dd').format(item['date']),
          item['count'],
          item['amount'],
        ]);
      }
    } else if (reportType == ReportType.vat) {
      csvData.add(['Period', 'Date', 'Sales VAT', 'Purchases VAT', 'VAT Payable']);
      
      // Add rows
      for (var item in data) {
        csvData.add([
          item['period'],
          DateFormat('yyyy-MM-dd').format(item['date']),
          item['sales_vat'],
          item['purchases_vat'],
          item['vat_payable'],
        ]);
      }
    }
    
    // Convert to CSV string
    String csv = const ListToCsvConverter().convert(csvData);
    
    // Save to file
    final directory = await getApplicationDocumentsDirectory();
    final filePath = '${directory.path}/$fileName';
    final file = File(filePath);
    await file.writeAsString(csv);
    
    return filePath;
  }

  // Build the PDF header
  pw.Widget _buildPdfHeader(
    ReportType reportType,
    ReportPeriod reportPeriod,
    DateTime? startDate,
    DateTime? endDate,
  ) {
    String dateRange = 'All periods';
    if (startDate != null && endDate != null) {
      dateRange = '${DateFormat('dd MMM yyyy').format(startDate)} - ${DateFormat('dd MMM yyyy').format(endDate)}';
    }
    
    return pw.Container(
      alignment: pw.Alignment.center,
      margin: const pw.EdgeInsets.only(bottom: 20),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Text(
            'LEMURU BUSINESS',
            style: pw.TextStyle(
              fontSize: 18,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 5),
          pw.Text(
            'Financial Management Report',
            style: const pw.TextStyle(
              fontSize: 14,
            ),
          ),
          pw.SizedBox(height: 5),
          pw.Text(
            dateRange,
            style: pw.TextStyle(
              fontSize: 12,
              fontStyle: pw.FontStyle.italic,
            ),
          ),
          pw.SizedBox(height: 5),
          pw.Divider(),
        ],
      ),
    );
  }

  // Build the PDF title
  pw.Widget _buildPdfTitle(ReportType reportType) {
    String title;
    switch (reportType) {
      case ReportType.sales:
        title = 'SALES REPORT';
        break;
      case ReportType.purchases:
        title = 'PURCHASES REPORT';
        break;
      case ReportType.vat:
        title = 'VAT REPORT';
        break;
    }
    
    return pw.Container(
      alignment: pw.Alignment.center,
      child: pw.Text(
        title,
        style: pw.TextStyle(
          fontSize: 16,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
    );
  }

  // Build the PDF summary
  pw.Widget _buildPdfSummary(List<Map<String, dynamic>> data, ReportType reportType) {
    if (data.isEmpty) {
      return pw.Container();
    }
    
    if (reportType == ReportType.sales || reportType == ReportType.purchases) {
      // Calculate total amount and count
      double totalAmount = 0;
      int totalCount = 0;
      
      for (var item in data) {
        totalAmount += item['amount'] as double;
        totalCount += item['count'] as int;
      }
      
      return pw.Container(
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(width: 1, color: PdfColors.grey300),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'Summary',
              style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 10),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Total Amount:'),
                pw.Text(
                  _moneyFormat.format(totalAmount),
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 5),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Total Transactions:'),
                pw.Text(
                  totalCount.toString(),
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 5),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Average per Transaction:'),
                pw.Text(
                  _moneyFormat.format(totalAmount / totalCount),
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    } else if (reportType == ReportType.vat) {
      // Calculate total VAT
      double totalSalesVat = 0;
      double totalPurchasesVat = 0;
      double totalVatPayable = 0;
      
      for (var item in data) {
        totalSalesVat += item['sales_vat'] as double;
        totalPurchasesVat += item['purchases_vat'] as double;
        totalVatPayable += item['vat_payable'] as double;
      }
      
      return pw.Container(
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(width: 1, color: PdfColors.grey300),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'Summary',
              style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 10),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Total Sales VAT:'),
                pw.Text(
                  _moneyFormat.format(totalSalesVat),
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 5),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Total Purchases VAT:'),
                pw.Text(
                  _moneyFormat.format(totalPurchasesVat),
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 5),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Total VAT Payable:'),
                pw.Text(
                  _moneyFormat.format(totalVatPayable),
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    color: totalVatPayable > 0 ? PdfColors.green : PdfColors.red,
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }
    
    return pw.Container();
  }

  // Build the PDF table
  pw.Widget _buildPdfTable(List<Map<String, dynamic>> data, ReportType reportType) {
    if (data.isEmpty) {
      return pw.Container(
        alignment: pw.Alignment.center,
        child: pw.Text('No data available for the selected period'),
      );
    }
    
    if (reportType == ReportType.sales || reportType == ReportType.purchases) {
      return pw.Table(
        border: pw.TableBorder.all(width: 1, color: PdfColors.grey300),
        children: [
          // Header row
          pw.TableRow(
            decoration: const pw.BoxDecoration(color: PdfColors.grey200),
            children: [
              _buildTableCell('Period', isHeader: true),
              _buildTableCell('Transactions', isHeader: true),
              _buildTableCell('Amount', isHeader: true),
              _buildTableCell('Average', isHeader: true),
            ],
          ),
          // Data rows
          ...data.map((item) {
            return pw.TableRow(
              children: [
                _buildTableCell(item['period']),
                _buildTableCell(item['count'].toString()),
                _buildTableCell(_moneyFormat.format(item['amount'])),
                _buildTableCell(_moneyFormat.format(item['amount'] / item['count'])),
              ],
            );
          }).toList(),
        ],
      );
    } else if (reportType == ReportType.vat) {
      return pw.Table(
        border: pw.TableBorder.all(width: 1, color: PdfColors.grey300),
        children: [
          // Header row
          pw.TableRow(
            decoration: const pw.BoxDecoration(color: PdfColors.grey200),
            children: [
              _buildTableCell('Period', isHeader: true),
              _buildTableCell('Sales VAT', isHeader: true),
              _buildTableCell('Purchases VAT', isHeader: true),
              _buildTableCell('VAT Payable', isHeader: true),
            ],
          ),
          // Data rows
          ...data.map((item) {
            return pw.TableRow(
              children: [
                _buildTableCell(item['period']),
                _buildTableCell(_moneyFormat.format(item['sales_vat'])),
                _buildTableCell(_moneyFormat.format(item['purchases_vat'])),
                _buildTableCell(_moneyFormat.format(item['vat_payable'])),
              ],
            );
          }).toList(),
        ],
      );
    }
    
    return pw.Container();
  }

  // Helper method to build table cells
  pw.Widget _buildTableCell(String text, {bool isHeader = false}) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      alignment: pw.Alignment.center,
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontWeight: isHeader ? pw.FontWeight.bold : null,
        ),
      ),
    );
  }

  // Build the PDF footer
  pw.Widget _buildPdfFooter(int pageNumber, int pageCount) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 20),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'Generated on ${DateFormat('dd MMM yyyy HH:mm').format(DateTime.now())}',
            style: const pw.TextStyle(
              fontSize: 10,
              color: PdfColors.grey,
            ),
          ),
          pw.Text(
            'Page $pageNumber of $pageCount',
            style: const pw.TextStyle(
              fontSize: 10,
              color: PdfColors.grey,
            ),
          ),
        ],
      ),
    );
  }

  // Generate a file name based on report type and format
  String _generateFileName(ReportType reportType, ReportFormat format) {
    final now = DateTime.now();
    final dateStr = DateFormat('yyyyMMdd_HHmmss').format(now);
    String reportName;
    
    switch (reportType) {
      case ReportType.sales:
        reportName = 'sales';
        break;
      case ReportType.purchases:
        reportName = 'purchases';
        break;
      case ReportType.vat:
        reportName = 'vat';
        break;
    }
    
    String extension = format == ReportFormat.pdf ? 'pdf' : 'csv';
    return 'lemuru_${reportName}_report_$dateStr.$extension';
  }
}