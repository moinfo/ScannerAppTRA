import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_receipt_scanner/main.dart';
import 'package:flutter_receipt_scanner/services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

class VatPayment {
  final int id;
  final String period;
  final double salesVat;
  final double purchasesVat;
  final double amountPayable;
  final String status;
  final String dueDate;
  final String? paymentDate;
  final String? paymentMethod;
  final String? paymentReference;
  final String? notes;

  VatPayment({
    required this.id,
    required this.period,
    required this.salesVat,
    required this.purchasesVat,
    required this.amountPayable,
    required this.status,
    required this.dueDate,
    this.paymentDate,
    this.paymentMethod,
    this.paymentReference,
    this.notes,
  });

  factory VatPayment.fromJson(Map<String, dynamic> json) {
    return VatPayment(
      id: json['id'] ?? 0,
      period: json['period'] ?? '',
      salesVat: json['sales_vat'] is num ? json['sales_vat'].toDouble() : 0.0,
      purchasesVat: json['purchases_vat'] is num ? json['purchases_vat'].toDouble() : 0.0,
      amountPayable: json['amount_payable'] is num ? json['amount_payable'].toDouble() : 0.0,
      status: json['status'] ?? 'Pending',
      dueDate: json['due_date'] ?? DateFormat('yyyy-MM-dd').format(DateTime.now().add(const Duration(days: 30))),
      paymentDate: json['payment_date'],
      paymentMethod: json['payment_method'],
      paymentReference: json['payment_reference'],
      notes: json['notes'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'period': period,
      'sales_vat': salesVat,
      'purchases_vat': purchasesVat,
      'amount_payable': amountPayable,
      'status': status,
      'due_date': dueDate,
      'payment_date': paymentDate,
      'payment_method': paymentMethod,
      'payment_reference': paymentReference,
      'notes': notes,
    };
  }
}

class VatReport {
  final String period;
  final DateTime periodStartDate;
  final DateTime periodEndDate;
  final double totalSales;
  final double totalPurchases;
  final double salesVat;
  final double purchasesVat;
  final double vatPayable;
  final List<Map<String, dynamic>> salesBreakdown;
  final List<Map<String, dynamic>> purchasesBreakdown;

  VatReport({
    required this.period,
    required this.periodStartDate,
    required this.periodEndDate,
    required this.totalSales,
    required this.totalPurchases,
    required this.salesVat,
    required this.purchasesVat,
    required this.vatPayable,
    required this.salesBreakdown,
    required this.purchasesBreakdown,
  });

  factory VatReport.fromJson(Map<String, dynamic> json) {
    List<Map<String, dynamic>> salesBreakdown = [];
    if (json['sales_breakdown'] != null && json['sales_breakdown'] is List) {
      salesBreakdown = (json['sales_breakdown'] as List)
          .map((item) => item as Map<String, dynamic>)
          .toList();
    }
    
    List<Map<String, dynamic>> purchasesBreakdown = [];
    if (json['purchases_breakdown'] != null && json['purchases_breakdown'] is List) {
      purchasesBreakdown = (json['purchases_breakdown'] as List)
          .map((item) => item as Map<String, dynamic>)
          .toList();
    }

    return VatReport(
      period: json['period'] ?? '',
      periodStartDate: json['period_start_date'] != null 
          ? DateTime.parse(json['period_start_date']) 
          : DateTime.now().subtract(const Duration(days: 30)),
      periodEndDate: json['period_end_date'] != null 
          ? DateTime.parse(json['period_end_date']) 
          : DateTime.now(),
      totalSales: json['total_sales'] is num ? json['total_sales'].toDouble() : 0.0,
      totalPurchases: json['total_purchases'] is num ? json['total_purchases'].toDouble() : 0.0,
      salesVat: json['sales_vat'] is num ? json['sales_vat'].toDouble() : 0.0,
      purchasesVat: json['purchases_vat'] is num ? json['purchases_vat'].toDouble() : 0.0,
      vatPayable: json['vat_payable'] is num ? json['vat_payable'].toDouble() : 0.0,
      salesBreakdown: salesBreakdown,
      purchasesBreakdown: purchasesBreakdown,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'period': period,
      'period_start_date': DateFormat('yyyy-MM-dd').format(periodStartDate),
      'period_end_date': DateFormat('yyyy-MM-dd').format(periodEndDate),
      'total_sales': totalSales,
      'total_purchases': totalPurchases,
      'sales_vat': salesVat,
      'purchases_vat': purchasesVat,
      'vat_payable': vatPayable,
      'sales_breakdown': salesBreakdown,
      'purchases_breakdown': purchasesBreakdown,
    };
  }
}

class VatService {
  final ApiService _apiService = ApiService();
  
  // Singleton pattern
  static final VatService _instance = VatService._internal();
  factory VatService() => _instance;
  VatService._internal();

  // Full updated getVatPayments method (fix for line 206)
  Future<ApiResponse<List<VatPayment>>> getVatPayments({
    int page = 1,
    DateTime? startDate,
    DateTime? endDate,
    String? status,
  }) async {
    try {
      // Check for offline mode
      final isOfflineMode = await _apiService.isOfflineMode();

      if (isOfflineMode) {
        // Get offline VAT payments data
        final offlineData = await _getOfflineVatPayments();

        // Apply filtering if needed
        List<VatPayment> filteredData = offlineData;

        if (status != null && status.isNotEmpty) {
          filteredData = filteredData.where((payment) =>
          payment.status.toLowerCase() == status.toLowerCase()
          ).toList();
        }

        if (startDate != null && endDate != null) {
          filteredData = filteredData.where((payment) {
            try {
              final dueDate = DateTime.parse(payment.dueDate);
              return dueDate.isAfter(startDate.subtract(const Duration(days: 1))) &&
                  dueDate.isBefore(endDate.add(const Duration(days: 1)));
            } catch (e) {
              return false;
            }
          }).toList();
        }

        return ApiResponse.offline(filteredData);
      }

      // Build query parameters
      final Map<String, dynamic> queryParams = {'page': page.toString()};

      if (startDate != null && endDate != null) {
        queryParams['start_date'] = DateFormat('yyyy-MM-dd').format(startDate);
        queryParams['end_date'] = DateFormat('yyyy-MM-dd').format(endDate);
      }

      if (status != null && status.isNotEmpty) {
        queryParams['status'] = status;
      }

      // Pre-fetch the offline data before making the API call
      final offlineVatPaymentsJson = await _getOfflineVatPaymentsAsJson();
      final offlineDataMap = {'data': offlineVatPaymentsJson};

      // Make API call with synchronous offlineFallback
      final response = await _apiService.get<Map<String, dynamic>>(
        '${ApiConfig.reportsUrl}/vat/payments',
        queryParams: queryParams,
        fromJson: (json) => json,
        offlineFallback: () => offlineDataMap,  // Now synchronous
      );

      if (response.success) {
        final List<dynamic> paymentsData = response.data!['data'] as List;
        final payments = paymentsData.map((json) => VatPayment.fromJson(json)).toList();
        return ApiResponse.success(payments);
      } else {
        return ApiResponse.error(response.errorMessage ?? 'Failed to fetch VAT payments');
      }
    } catch (e) {
      debugPrint('Error in getVatPayments: $e');
      return ApiResponse.error('Failed to fetch VAT payments: $e');
    }
  }

// Full updated getVatPaymentDetails method (fix for line 245)
  Future<ApiResponse<VatPayment>> getVatPaymentDetails(int paymentId) async {
    try {
      // Check for offline mode
      final isOfflineMode = await _apiService.isOfflineMode();

      if (isOfflineMode) {
        // In offline mode, get from local storage
        final payment = await _getOfflineVatPaymentById(paymentId);
        if (payment != null) {
          return ApiResponse.offline(payment);
        } else {
          return ApiResponse.error('VAT payment not found in offline storage');
        }
      }

      // Pre-fetch the offline payment before making the API call
      final offlinePayment = await _getOfflineVatPaymentById(paymentId);

      // Make API call with synchronous offlineFallback
      final response = await _apiService.get<Map<String, dynamic>>(
        '${ApiConfig.reportsUrl}/vat/payments/$paymentId',
        fromJson: (json) => json,
        offlineFallback: offlinePayment != null
            ? () => offlinePayment.toJson()  // Synchronous function
            : null,  // No fallback if payment not found
      );

      if (response.success) {
        final payment = VatPayment.fromJson(response.data!);
        return ApiResponse.success(payment);
      } else {
        return ApiResponse.error(response.errorMessage ?? 'Failed to get VAT payment details');
      }
    } catch (e) {
      debugPrint('Error in getVatPaymentDetails: $e');
      return ApiResponse.error('Failed to get VAT payment details: $e');
    }
  }

// Full updated generateVatReport method (fix for line 398)
  Future<ApiResponse<VatReport>> generateVatReport(DateTime startDate, DateTime endDate) async {
    try {
      // Check for offline mode
      final isOfflineMode = await _apiService.isOfflineMode();

      if (isOfflineMode) {
        // In offline mode, generate report from local data
        final report = await _generateOfflineVatReport(startDate, endDate);
        return ApiResponse.offline(report);
      }

      // Format dates for the API
      final startDateStr = DateFormat('yyyy-MM-dd').format(startDate);
      final endDateStr = DateFormat('yyyy-MM-dd').format(endDate);

      // Pre-generate the offline report before making the API call
      final offlineReport = await _generateOfflineVatReport(startDate, endDate);
      final offlineReportJson = offlineReport.toJson();

      // Make API call with synchronous offlineFallback
      final response = await _apiService.get<Map<String, dynamic>>(
        ApiConfig.reportsUrl + '/vat',
        queryParams: {
          'start_date': startDateStr,
          'end_date': endDateStr,
        },
        fromJson: (json) => json,
        offlineFallback: () => offlineReportJson,  // Now synchronous
      );

      if (response.success) {
        final report = VatReport.fromJson(response.data!);
        return ApiResponse.success(report);
      } else {
        return ApiResponse.error(response.errorMessage ?? 'Failed to generate VAT report');
      }
    } catch (e) {
      debugPrint('Error in generateVatReport: $e');
      return ApiResponse.error('Failed to generate VAT report: $e');
    }
  }

  // Create a new VAT payment
  Future<ApiResponse<VatPayment>> createVatPayment(VatPayment payment) async {
    try {
      // Check for offline mode
      final isOfflineMode = await _apiService.isOfflineMode();
      
      if (isOfflineMode) {
        // In offline mode, save to local storage
        final savedPayment = await _addOfflineVatPayment(payment);
        if (savedPayment != null) {
          return ApiResponse.offline(savedPayment);
        } else {
          return ApiResponse.error('Failed to save VAT payment offline');
        }
      }
      
      // Make API call to create payment
      final response = await _apiService.post<Map<String, dynamic>>(
        '${ApiConfig.reportsUrl}/vat/payments',
        body: payment.toJson(),
        fromJson: (json) => json,
      );
      
      if (response.success) {
        final newPayment = VatPayment.fromJson(response.data!);
        return ApiResponse.success(newPayment);
      } else {
        return ApiResponse.error(response.errorMessage ?? 'Failed to create VAT payment');
      }
    } catch (e) {
      debugPrint('Error in createVatPayment: $e');
      return ApiResponse.error('Failed to create VAT payment: $e');
    }
  }

  // Update VAT payment status and details
  Future<ApiResponse<VatPayment>> updateVatPaymentStatus(
    int paymentId, 
    String status, {
    String? paymentMethod,
    String? paymentReference,
    String? paymentDate,
    String? notes,
  }) async {
    try {
      // Check for offline mode
      final isOfflineMode = await _apiService.isOfflineMode();
      
      if (isOfflineMode) {
        // In offline mode, update in local storage
        final payment = await _getOfflineVatPaymentById(paymentId);
        if (payment == null) {
          return ApiResponse.error('VAT payment not found in offline storage');
        }
        
        final updatedPayment = VatPayment(
          id: payment.id,
          period: payment.period,
          salesVat: payment.salesVat,
          purchasesVat: payment.purchasesVat,
          amountPayable: payment.amountPayable,
          status: status,
          dueDate: payment.dueDate,
          paymentMethod: paymentMethod ?? payment.paymentMethod,
          paymentReference: paymentReference ?? payment.paymentReference,
          paymentDate: paymentDate ?? payment.paymentDate,
          notes: notes ?? payment.notes,
        );
        
        final result = await _updateOfflineVatPayment(updatedPayment);
        if (result != null) {
          return ApiResponse.offline(result);
        } else {
          return ApiResponse.error('Failed to update VAT payment status offline');
        }
      }
      
      // Make API call to update status and details
      final body = {
        'status': status,
      };
      
      // Add optional fields if they are provided
      if (paymentMethod != null) body['payment_method'] = paymentMethod;
      if (paymentReference != null) body['payment_reference'] = paymentReference;
      if (paymentDate != null) body['payment_date'] = paymentDate;
      if (notes != null) body['notes'] = notes;
      
      final response = await _apiService.put<Map<String, dynamic>>(
        '${ApiConfig.reportsUrl}/vat/payments/$paymentId/status',
        body: body,
        fromJson: (json) => json,
      );
      
      if (response.success) {
        final updatedPayment = VatPayment.fromJson(response.data!);
        return ApiResponse.success(updatedPayment);
      } else {
        return ApiResponse.error(response.errorMessage ?? 'Failed to update VAT payment status');
      }
    } catch (e) {
      debugPrint('Error in updateVatPaymentStatus: $e');
      return ApiResponse.error('Failed to update VAT payment status: $e');
    }
  }


  // Helper methods for offline data
  Future<List<VatPayment>> _getOfflineVatPayments() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final offlineVatJson = prefs.getString('offline_vat');
      
      if (offlineVatJson != null) {
        final List<dynamic> paymentsData = jsonDecode(offlineVatJson) as List;
        return paymentsData.map((json) => VatPayment.fromJson(json)).toList();
      }
      
      return [];
    } catch (e) {
      debugPrint('Error getting offline VAT payments: $e');
      return [];
    }
  }

  Future<List<dynamic>> _getOfflineVatPaymentsAsJson() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final offlineVatJson = prefs.getString('offline_vat');
      
      if (offlineVatJson != null) {
        return jsonDecode(offlineVatJson) as List;
      }
      
      return [];
    } catch (e) {
      debugPrint('Error getting offline VAT payments as JSON: $e');
      return [];
    }
  }

  Future<VatPayment?> _getOfflineVatPaymentById(int paymentId) async {
    try {
      final payments = await _getOfflineVatPayments();
      for (var payment in payments) {
        if (payment.id == paymentId) {
          return payment;
        }
      }
      return null;
    } catch (e) {
      debugPrint('Error getting offline VAT payment by ID: $e');
      return null;
    }
  }

  Future<VatPayment?> _addOfflineVatPayment(VatPayment payment) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final payments = await _getOfflineVatPayments();
      
      // Generate a new ID (max existing ID + 1)
      int newId = 1;
      if (payments.isNotEmpty) {
        newId = payments.map((p) => p.id).reduce((max, id) => id > max ? id : max) + 1;
      }
      
      // Create new payment with generated ID
      final newPayment = VatPayment(
        id: newId,
        period: payment.period,
        salesVat: payment.salesVat,
        purchasesVat: payment.purchasesVat,
        amountPayable: payment.amountPayable,
        status: payment.status,
        dueDate: payment.dueDate,
      );
      
      // Add to list and save
      payments.add(newPayment);
      await prefs.setString('offline_vat', jsonEncode(payments.map((p) => p.toJson()).toList()));
      
      return newPayment;
    } catch (e) {
      debugPrint('Error adding offline VAT payment: $e');
      return null;
    }
  }

  Future<VatPayment?> _updateOfflineVatPayment(VatPayment updatedPayment) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final payments = await _getOfflineVatPayments();
      
      // Find payment by ID and replace it
      bool found = false;
      final updatedPayments = payments.map((payment) {
        if (payment.id == updatedPayment.id) {
          found = true;
          return updatedPayment;
        }
        return payment;
      }).toList();
      
      if (!found) {
        return null;
      }
      
      // Save updated list
      await prefs.setString('offline_vat', jsonEncode(updatedPayments.map((p) => p.toJson()).toList()));
      
      return updatedPayment;
    } catch (e) {
      debugPrint('Error updating offline VAT payment: $e');
      return null;
    }
  }

  Future<VatReport> _generateOfflineVatReport(DateTime startDate, DateTime endDate) async {
    try {
      // Get relevant offline data
      final prefs = await SharedPreferences.getInstance();
      final salesJson = prefs.getString('offline_sales');
      final purchasesJson = prefs.getString('offline_purchases');
      
      // Extract and filter sales data for the period
      List<Map<String, dynamic>> sales = [];
      if (salesJson != null) {
        final List<dynamic> allSales = jsonDecode(salesJson) as List;
        sales = allSales.where((sale) {
          try {
            final saleDate = DateTime.parse(sale['date']);
            return saleDate.isAfter(startDate.subtract(const Duration(days: 1))) && 
                   saleDate.isBefore(endDate.add(const Duration(days: 1)));
          } catch (e) {
            return false;
          }
        }).map((s) => s as Map<String, dynamic>).toList();
      }
      
      // Extract and filter purchases data for the period
      List<Map<String, dynamic>> purchases = [];
      if (purchasesJson != null) {
        final List<dynamic> allPurchases = jsonDecode(purchasesJson) as List;
        purchases = allPurchases.where((purchase) {
          try {
            final purchaseDate = DateTime.parse(purchase['date']);
            return purchaseDate.isAfter(startDate.subtract(const Duration(days: 1))) && 
                   purchaseDate.isBefore(endDate.add(const Duration(days: 1)));
          } catch (e) {
            return false;
          }
        }).map((p) => p as Map<String, dynamic>).toList();
      }
      
      // Calculate totals
      double totalSales = 0;
      for (var sale in sales) {
        totalSales += (sale['amount'] as num).toDouble();
      }
      
      double totalPurchases = 0;
      for (var purchase in purchases) {
        totalPurchases += (purchase['amount'] as num).toDouble();
      }
      
      // Calculate VAT (assume 18% VAT rate)
      const vatRate = 0.18;
      final salesVat = totalSales * vatRate;
      final purchasesVat = totalPurchases * vatRate;
      final vatPayable = salesVat - purchasesVat;
      
      // Generate period name
      final periodName = '${DateFormat('MMM').format(startDate)} - ${DateFormat('MMM yyyy').format(endDate)}';
      
      // Create report
      return VatReport(
        period: periodName,
        periodStartDate: startDate,
        periodEndDate: endDate,
        totalSales: totalSales,
        totalPurchases: totalPurchases,
        salesVat: salesVat,
        purchasesVat: purchasesVat,
        vatPayable: vatPayable,
        salesBreakdown: sales,
        purchasesBreakdown: purchases,
      );
    } catch (e) {
      debugPrint('Error generating offline VAT report: $e');
      // Return an empty report
      return VatReport(
        period: '${DateFormat('MMM').format(startDate)} - ${DateFormat('MMM yyyy').format(endDate)}',
        periodStartDate: startDate,
        periodEndDate: endDate,
        totalSales: 0,
        totalPurchases: 0,
        salesVat: 0,
        purchasesVat: 0,
        vatPayable: 0,
        salesBreakdown: [],
        purchasesBreakdown: [],
      );
    }
  }
}