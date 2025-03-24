import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_receipt_scanner/main.dart';
import 'package:flutter_receipt_scanner/services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

class Sale {
  final int id;
  final String customer;
  final String date;
  final double amount;
  final String status;
  final List<SaleItem> items;

  Sale({
    required this.id,
    required this.customer,
    required this.date,
    required this.amount,
    required this.status,
    required this.items,
  });

  factory Sale.fromJson(Map<String, dynamic> json) {
    List<SaleItem> saleItems = [];
    if (json['items'] != null && json['items'] is List) {
      saleItems = (json['items'] as List)
          .map((item) => SaleItem.fromJson(item))
          .toList();
    }

    return Sale(
      id: json['id'] ?? 0,
      customer: json['customer'] ?? 'Unknown Customer',
      date: json['date'] ?? DateFormat('yyyy-MM-dd').format(DateTime.now()),
      amount: json['amount'] is num ? json['amount'].toDouble() : 0.0,
      status: json['status'] ?? 'Pending',
      items: saleItems,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'customer': customer,
      'date': date,
      'amount': amount,
      'status': status,
      'items': items.map((item) => item.toJson()).toList(),
    };
  }
}

class SaleItem {
  final String name;
  final int quantity;
  final double price;

  SaleItem({
    required this.name,
    required this.quantity,
    required this.price,
  });

  factory SaleItem.fromJson(Map<String, dynamic> json) {
    return SaleItem(
      name: json['name'] ?? 'Unknown Item',
      quantity: json['quantity'] ?? 1,
      price: json['price'] is num ? json['price'].toDouble() : 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'quantity': quantity,
      'price': price,
    };
  }
}

class SalesService {
  final ApiService _apiService = ApiService();
  
  // Singleton pattern
  static final SalesService _instance = SalesService._internal();
  factory SalesService() => _instance;
  SalesService._internal();

  // Get all sales with pagination and filtering
  // Get all sales with pagination and filtering
  Future<ApiResponse<List<Sale>>> getSales({
    int page = 1,
    DateTime? startDate,
    DateTime? endDate,
    String? searchTerm,
  }) async {
    try {
      // Check for offline mode
      final isOfflineMode = await _apiService.isOfflineMode();

      if (isOfflineMode) {
        // Get offline sales data
        final offlineData = await _getOfflineSales();

        // Apply filtering if needed
        List<Sale> filteredData = offlineData;

        if (searchTerm != null && searchTerm.isNotEmpty) {
          final searchLower = searchTerm.toLowerCase();
          filteredData = filteredData.where((sale) =>
              sale.customer.toLowerCase().contains(searchLower)
          ).toList();
        }

        if (startDate != null && endDate != null) {
          filteredData = filteredData.where((sale) {
            try {
              final saleDate = DateTime.parse(sale.date);
              return saleDate.isAfter(startDate.subtract(const Duration(days: 1))) &&
                  saleDate.isBefore(endDate.add(const Duration(days: 1)));
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

      if (searchTerm != null && searchTerm.isNotEmpty) {
        queryParams['search'] = searchTerm;
      }

      // Pre-fetch the offline data before making the API call
      final offlineSalesJson = await _getOfflineSalesAsJson();
      final offlineDataMap = {'data': offlineSalesJson};

      // Make API call with synchronous offlineFallback
      final response = await _apiService.get<Map<String, dynamic>>(
        ApiConfig.salesUrl,
        queryParams: queryParams,
        fromJson: (json) => json,
        offlineFallback: () => offlineDataMap,  // Now synchronous
      );

      if (response.success) {
        // Check if the data is under 'data' or 'receipts' key (API might return either)
        final List<dynamic> salesData;
        if (response.data!.containsKey('data')) {
          salesData = response.data!['data'] as List;
        } else if (response.data!.containsKey('receipts')) {
          salesData = response.data!['receipts']['data'] as List;
        } else {
          return ApiResponse.error('Unexpected API response format');
        }
        
        final sales = salesData.map((json) => Sale.fromJson(json)).toList();
        return ApiResponse.success(sales);
      } else {
        return ApiResponse.error(response.errorMessage ?? 'Failed to fetch sales');
      }
    } catch (e) {
      debugPrint('Error in getSales: $e');
      return ApiResponse.error('Failed to fetch sales: $e');
    }
  }

// Get sale details by ID
  Future<ApiResponse<Sale>> getSaleDetails(int saleId) async {
    try {
      // Check for offline mode
      final isOfflineMode = await _apiService.isOfflineMode();

      if (isOfflineMode) {
        // In offline mode, get from local storage
        final sale = await _getOfflineSaleById(saleId);
        if (sale != null) {
          return ApiResponse.offline(sale);
        } else {
          return ApiResponse.error('Sale not found in offline storage');
        }
      }

      // Pre-fetch the offline sale before making the API call
      final offlineSale = await _getOfflineSaleById(saleId);

      // Make API call with synchronous offlineFallback
      final response = await _apiService.get<Map<String, dynamic>>(
        '${ApiConfig.salesUrl}/$saleId',
        fromJson: (json) => json,
        offlineFallback: offlineSale != null
            ? () => offlineSale.toJson()  // Synchronous function
            : null,  // No fallback if sale not found
      );

      if (response.success) {
        final sale = Sale.fromJson(response.data!);
        return ApiResponse.success(sale);
      } else {
        return ApiResponse.error(response.errorMessage ?? 'Failed to get sale details');
      }
    } catch (e) {
      debugPrint('Error in getSaleDetails: $e');
      return ApiResponse.error('Failed to get sale details: $e');
    }
  }

  // Create a new sale
  Future<ApiResponse<Sale>> createSale(Sale sale) async {
    try {
      // Check for offline mode
      final isOfflineMode = await _apiService.isOfflineMode();
      
      if (isOfflineMode) {
        // In offline mode, save to local storage
        final savedSale = await _addOfflineSale(sale);
        if (savedSale != null) {
          return ApiResponse.offline(savedSale);
        } else {
          return ApiResponse.error('Failed to save sale offline');
        }
      }
      
      // Make API call to create sale
      final response = await _apiService.post<Map<String, dynamic>>(
        ApiConfig.salesUrl,
        body: sale.toJson(),
        fromJson: (json) => json,
      );
      
      if (response.success) {
        final newSale = Sale.fromJson(response.data!);
        return ApiResponse.success(newSale);
      } else {
        return ApiResponse.error(response.errorMessage ?? 'Failed to create sale');
      }
    } catch (e) {
      debugPrint('Error in createSale: $e');
      return ApiResponse.error('Failed to create sale: $e');
    }
  }

  // Update an existing sale
  Future<ApiResponse<Sale>> updateSale(Sale sale) async {
    try {
      // Check for offline mode
      final isOfflineMode = await _apiService.isOfflineMode();
      
      if (isOfflineMode) {
        // In offline mode, update in local storage
        final updatedSale = await _updateOfflineSale(sale);
        if (updatedSale != null) {
          return ApiResponse.offline(updatedSale);
        } else {
          return ApiResponse.error('Failed to update sale offline');
        }
      }
      
      // Make API call to update sale
      final response = await _apiService.put<Map<String, dynamic>>(
        '${ApiConfig.salesUrl}/${sale.id}',
        body: sale.toJson(),
        fromJson: (json) => json,
      );
      
      if (response.success) {
        final updatedSale = Sale.fromJson(response.data!);
        return ApiResponse.success(updatedSale);
      } else {
        return ApiResponse.error(response.errorMessage ?? 'Failed to update sale');
      }
    } catch (e) {
      debugPrint('Error in updateSale: $e');
      return ApiResponse.error('Failed to update sale: $e');
    }
  }

  // Delete a sale
  Future<ApiResponse<bool>> deleteSale(int saleId) async {
    try {
      // Check for offline mode
      final isOfflineMode = await _apiService.isOfflineMode();
      
      if (isOfflineMode) {
        // In offline mode, delete from local storage
        final success = await _deleteOfflineSale(saleId);
        if (success) {
          return ApiResponse.offline(true);
        } else {
          return ApiResponse.error('Failed to delete sale from offline storage');
        }
      }
      
      // Make API call to delete sale
      return await _apiService.delete(
        '${ApiConfig.salesUrl}/$saleId',
      );
    } catch (e) {
      debugPrint('Error in deleteSale: $e');
      return ApiResponse.error('Failed to delete sale: $e');
    }
  }

  // Helper methods for offline data
  Future<List<Sale>> _getOfflineSales() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final offlineSalesJson = prefs.getString('offline_sales');
      
      if (offlineSalesJson != null) {
        final List<dynamic> salesData = jsonDecode(offlineSalesJson) as List;
        return salesData.map((json) => Sale.fromJson(json)).toList();
      }
      
      return [];
    } catch (e) {
      debugPrint('Error getting offline sales: $e');
      return [];
    }
  }

  Future<List<dynamic>> _getOfflineSalesAsJson() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final offlineSalesJson = prefs.getString('offline_sales');
      
      if (offlineSalesJson != null) {
        return jsonDecode(offlineSalesJson) as List;
      }
      
      return [];
    } catch (e) {
      debugPrint('Error getting offline sales as JSON: $e');
      return [];
    }
  }

  Future<Sale?> _getOfflineSaleById(int saleId) async {
    try {
      final sales = await _getOfflineSales();
      for (var sale in sales) {
        if (sale.id == saleId) {
          return sale;
        }
      }
      return null;
    } catch (e) {
      debugPrint('Error getting offline sale by ID: $e');
      return null;
    }
  }

  Future<Sale?> _addOfflineSale(Sale sale) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final sales = await _getOfflineSales();
      
      // Generate a new ID (max existing ID + 1)
      int newId = 1;
      if (sales.isNotEmpty) {
        newId = sales.map((s) => s.id).reduce((max, id) => id > max ? id : max) + 1;
      }
      
      // Create new sale with generated ID
      final newSale = Sale(
        id: newId,
        customer: sale.customer,
        date: sale.date,
        amount: sale.amount,
        status: sale.status,
        items: sale.items,
      );
      
      // Add to list and save
      sales.add(newSale);
      await prefs.setString('offline_sales', jsonEncode(sales.map((s) => s.toJson()).toList()));
      
      return newSale;
    } catch (e) {
      debugPrint('Error adding offline sale: $e');
      return null;
    }
  }

  Future<Sale?> _updateOfflineSale(Sale updatedSale) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final sales = await _getOfflineSales();
      
      // Find sale by ID and replace it
      bool found = false;
      final updatedSales = sales.map((sale) {
        if (sale.id == updatedSale.id) {
          found = true;
          return updatedSale;
        }
        return sale;
      }).toList();
      
      if (!found) {
        return null;
      }
      
      // Save updated list
      await prefs.setString('offline_sales', jsonEncode(updatedSales.map((s) => s.toJson()).toList()));
      
      return updatedSale;
    } catch (e) {
      debugPrint('Error updating offline sale: $e');
      return null;
    }
  }

  Future<bool> _deleteOfflineSale(int saleId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final sales = await _getOfflineSales();
      
      // Filter out the sale to delete
      final newList = sales.where((s) => s.id != saleId).toList();
      
      // Save updated list
      await prefs.setString('offline_sales', jsonEncode(newList.map((s) => s.toJson()).toList()));
      
      return true;
    } catch (e) {
      debugPrint('Error deleting offline sale: $e');
      return false;
    }
  }
}