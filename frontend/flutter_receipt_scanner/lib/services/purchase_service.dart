import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_receipt_scanner/main.dart';
import 'package:flutter_receipt_scanner/services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

class Purchase {
  final int id;
  final String supplier;
  final String date;
  final double amount;
  final String status;
  final int? receiptId;
  final List<PurchaseItem>? items;
  
  // Detailed receipt fields
  final String? companyName;
  final String? poBox;
  final String? mobile;
  final String? tin;
  final String? vrn;
  final String? serialNo;
  final String? uin;
  final String? taxOffice;
  final String? customerName;
  final String? customerIdType;
  final String? customerId;
  final String? customerMobile;
  final String? receiptNumber;
  final String? receiptZNumber;
  final String? receiptTime;
  final String? receiptVerificationCode;
  final double? receiptTotalExclOfTax;
  final double? receiptTotalTax;
  final double? receiptTotalDiscount;
  final String? taxRateA;
  final double? rea;
  final double? ewura;
  final double? propertyTax;

  Purchase({
    required this.id,
    required this.supplier,
    required this.date,
    required this.amount,
    required this.status,
    this.receiptId,
    this.items,
    this.companyName,
    this.poBox,
    this.mobile,
    this.tin,
    this.vrn,
    this.serialNo,
    this.uin,
    this.taxOffice,
    this.customerName,
    this.customerIdType,
    this.customerId,
    this.customerMobile,
    this.receiptNumber,
    this.receiptZNumber,
    this.receiptTime,
    this.receiptVerificationCode,
    this.receiptTotalExclOfTax,
    this.receiptTotalTax,
    this.receiptTotalDiscount,
    this.taxRateA,
    this.rea,
    this.ewura,
    this.propertyTax,
  });

  factory Purchase.fromJson(Map<String, dynamic> json) {
    List<PurchaseItem>? purchaseItems;
    if (json['items'] != null && json['items'] is List) {
      purchaseItems = (json['items'] as List)
          .map((item) => PurchaseItem.fromJson(item))
          .toList();
    }

    return Purchase(
      id: json['id'] ?? 0,
      supplier: json['supplier'] ?? json['company_name'] ?? 'Unknown Supplier',
      date: json['date'] ?? json['receipt_date'] ?? DateFormat('yyyy-MM-dd').format(DateTime.now()),
      amount: json['amount'] is num ? json['amount'].toDouble() : 
              (json['receipt_total_incl_of_tax'] is num ? json['receipt_total_incl_of_tax'].toDouble() : 0.0),
      status: json['status'] ?? 'Pending',
      receiptId: json['receipt_id'],
      items: purchaseItems,
      
      // Detailed receipt fields
      companyName: json['company_name'],
      poBox: json['p_o_box'],
      mobile: json['mobile'],
      tin: json['tin'],
      vrn: json['vrn'],
      serialNo: json['serial_no'],
      uin: json['uin'],
      taxOffice: json['tax_office'],
      customerName: json['customer_name'],
      customerIdType: json['customer_id_type'],
      customerId: json['customer_id'],
      customerMobile: json['customer_mobile'],
      receiptNumber: json['receipt_number'],
      receiptZNumber: json['receipt_z_number'],
      receiptTime: json['receipt_time'],
      receiptVerificationCode: json['receipt_verification_code'],
      receiptTotalExclOfTax: json['receipt_total_excl_of_tax'] is num ? json['receipt_total_excl_of_tax'].toDouble() : null,
      receiptTotalTax: json['receipt_total_tax'] is num ? json['receipt_total_tax'].toDouble() : null,
      receiptTotalDiscount: json['receipt_total_discount'] is num ? json['receipt_total_discount'].toDouble() : null,
      taxRateA: json['tax_rate_a'],
      rea: json['rea'] is num ? json['rea'].toDouble() : 
           (json['receipt_rea'] is num ? json['receipt_rea'].toDouble() : null),
      ewura: json['ewura'] is num ? json['ewura'].toDouble() : 
             (json['receipt_ewura'] is num ? json['receipt_ewura'].toDouble() : null),
      propertyTax: json['property_tax'] is num ? json['property_tax'].toDouble() : 
                   (json['receipt_property_tax'] is num ? json['receipt_property_tax'].toDouble() : null),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'supplier': supplier,
      'date': date,
      'amount': amount,
      'status': status,
      'receipt_id': receiptId,
      'items': items?.map((item) => item.toJson()).toList(),
      
      // Detailed receipt fields
      'company_name': companyName,
      'p_o_box': poBox,
      'mobile': mobile,
      'tin': tin,
      'vrn': vrn,
      'serial_no': serialNo,
      'uin': uin,
      'tax_office': taxOffice,
      'customer_name': customerName,
      'customer_id_type': customerIdType,
      'customer_id': customerId,
      'customer_mobile': customerMobile,
      'receipt_number': receiptNumber,
      'receipt_z_number': receiptZNumber,
      'receipt_time': receiptTime,
      'receipt_verification_code': receiptVerificationCode,
      'receipt_total_excl_of_tax': receiptTotalExclOfTax,
      'receipt_total_tax': receiptTotalTax,
      'receipt_total_discount': receiptTotalDiscount,
      'tax_rate_a': taxRateA,
      'rea': rea,
      'ewura': ewura,
      'property_tax': propertyTax,
      // Laravel backend expects these field names
      'receipt_rea': rea,
      'receipt_ewura': ewura,
      'receipt_property_tax': propertyTax,
    };
  }
}

class PurchaseItem {
  final String name;
  final int quantity;
  final double price;
  final double? vatAmount;

  PurchaseItem({
    required this.name,
    required this.quantity,
    required this.price,
    this.vatAmount,
  });

  factory PurchaseItem.fromJson(Map<String, dynamic> json) {
    return PurchaseItem(
      name: json['name'] ?? json['description'] ?? json['item_description'] ?? 'Unknown Item',
      quantity: json['quantity'] ?? json['qty'] ?? json['item_qty'] ?? 1,
      price: json['price'] is num ? json['price'].toDouble() : 
             (json['amount'] is num ? json['amount'].toDouble() : 
             (json['item_amount'] is num ? json['item_amount'].toDouble() : 0.0)),
      vatAmount: json['vat_amount'] is num ? json['vat_amount'].toDouble() : null,
    );
  }

  String get description => name;

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'quantity': quantity,
      'price': price,
      'vat_amount': vatAmount,
    };
  }
}

class PurchaseService {
  final ApiService _apiService = ApiService();
  
  // Singleton pattern
  static final PurchaseService _instance = PurchaseService._internal();
  factory PurchaseService() => _instance;
  PurchaseService._internal();

  // Get all purchases with pagination and filtering
  Future<ApiResponse<List<Purchase>>> getPurchases({
    int page = 1,
    DateTime? startDate,
    DateTime? endDate,
    String? searchTerm,
  }) async {
    try {
      // Check for offline mode
      final isOfflineMode = await _apiService.isOfflineMode();

      if (isOfflineMode) {
        // Get offline purchases data
        final offlineData = await _getOfflinePurchases();

        // Apply filtering if needed
        List<Purchase> filteredData = offlineData;

        if (searchTerm != null && searchTerm.isNotEmpty) {
          final searchLower = searchTerm.toLowerCase();
          filteredData = filteredData.where((purchase) =>
              purchase.supplier.toLowerCase().contains(searchLower)
          ).toList();
        }

        if (startDate != null && endDate != null) {
          filteredData = filteredData.where((purchase) {
            try {
              final purchaseDate = DateTime.parse(purchase.date);
              return purchaseDate.isAfter(startDate.subtract(const Duration(days: 1))) &&
                  purchaseDate.isBefore(endDate.add(const Duration(days: 1)));
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
      final offlinePurchasesJson = await _getOfflinePurchasesAsJson();

      // Make API call
      final response = await _apiService.get<Map<String, dynamic>>(
        await ApiConfig.purchasesUrl,
        queryParams: queryParams,
        fromJson: (json) => json,
        offlineFallback: () => {'data': offlinePurchasesJson},
      );

      if (response.success) {
        // Check if the data is in the expected format
        final List<dynamic> purchasesData;
        if (response.data!.containsKey('data')) {
          purchasesData = response.data!['data'] as List;
        } else if (response.data!.containsKey('receipts')) {
          purchasesData = response.data!['receipts']['data'] as List;
        } else if (response.data!.containsKey('purchases') && response.data!['purchases'].containsKey('data')) {
          // New API format
          purchasesData = response.data!['purchases']['data'] as List;
          debugPrint('Found purchases.data format with ${purchasesData.length} items');
        } else {
          debugPrint('Unexpected API response format: ${response.data}');
          return ApiResponse.error('Unexpected API response format');
        }
        
        final purchases = purchasesData.map((json) => Purchase.fromJson(json)).toList();
        return ApiResponse.success(purchases);
      } else {
        return ApiResponse.error(response.errorMessage ?? 'Failed to fetch purchases');
      }
    } catch (e) {
      debugPrint('Error in getPurchases: $e');
      return ApiResponse.error('Failed to fetch purchases: $e');
    }
  }

// Fix for the getPurchaseDetails method
  Future<ApiResponse<Purchase>> getPurchaseDetails(int purchaseId) async {
    try {
      // Check for offline mode
      final isOfflineMode = await _apiService.isOfflineMode();

      if (isOfflineMode) {
        // In offline mode, get from local storage
        final purchase = await _getOfflinePurchaseById(purchaseId);
        if (purchase != null) {
          return ApiResponse.offline(purchase);
        } else {
          return ApiResponse.error('Purchase not found in offline storage');
        }
      }

      // Pre-fetch the offline purchase data
      final purchase = await _getOfflinePurchaseById(purchaseId);
      final purchaseJson = purchase?.toJson();

      // Make API call to get purchase details
      final response = await _apiService.get<Map<String, dynamic>>(
        '${ApiConfig.purchasesUrl}/$purchaseId',
        fromJson: (json) => json,
        offlineFallback: purchaseJson != null
            ? () => purchaseJson
            : null,
      );

      if (response.success) {
        final purchase = Purchase.fromJson(response.data!);
        return ApiResponse.success(purchase);
      } else {
        return ApiResponse.error(response.errorMessage ?? 'Failed to get purchase details');
      }
    } catch (e) {
      debugPrint('Error in getPurchaseDetails: $e');
      return ApiResponse.error('Failed to get purchase details: $e');
    }
  }



  // Create a new purchase
  Future<ApiResponse<Purchase>> createPurchase(Purchase purchase) async {
    try {
      // Check for offline mode
      final isOfflineMode = await _apiService.isOfflineMode();
      
      if (isOfflineMode) {
        // In offline mode, save to local storage
        final savedPurchase = await _addOfflinePurchase(purchase);
        if (savedPurchase != null) {
          return ApiResponse.offline(savedPurchase);
        } else {
          return ApiResponse.error('Failed to save purchase offline');
        }
      }
      
      // Make API call to create purchase
      final response = await _apiService.post<Map<String, dynamic>>(
        await ApiConfig.purchasesUrl,
        body: purchase.toJson(),
        fromJson: (json) => json,
      );
      
      if (response.success) {
        final newPurchase = Purchase.fromJson(response.data!);
        return ApiResponse.success(newPurchase);
      } else {
        return ApiResponse.error(response.errorMessage ?? 'Failed to create purchase');
      }
    } catch (e) {
      debugPrint('Error in createPurchase: $e');
      return ApiResponse.error('Failed to create purchase: $e');
    }
  }

  // Update an existing purchase
  Future<ApiResponse<Purchase>> updatePurchase(Purchase purchase) async {
    try {
      // Check for offline mode
      final isOfflineMode = await _apiService.isOfflineMode();
      
      if (isOfflineMode) {
        // In offline mode, update in local storage
        final updatedPurchase = await _updateOfflinePurchase(purchase);
        if (updatedPurchase != null) {
          return ApiResponse.offline(updatedPurchase);
        } else {
          return ApiResponse.error('Failed to update purchase offline');
        }
      }
      
      // Make API call to update purchase
      final response = await _apiService.put<Map<String, dynamic>>(
        '${ApiConfig.purchasesUrl}/${purchase.id}',
        body: purchase.toJson(),
        fromJson: (json) => json,
      );
      
      if (response.success) {
        final updatedPurchase = Purchase.fromJson(response.data!);
        return ApiResponse.success(updatedPurchase);
      } else {
        return ApiResponse.error(response.errorMessage ?? 'Failed to update purchase');
      }
    } catch (e) {
      debugPrint('Error in updatePurchase: $e');
      return ApiResponse.error('Failed to update purchase: $e');
    }
  }

  // Delete a purchase
  Future<ApiResponse<bool>> deletePurchase(int purchaseId) async {
    try {
      // Check for offline mode
      final isOfflineMode = await _apiService.isOfflineMode();
      
      if (isOfflineMode) {
        // In offline mode, delete from local storage
        final success = await _deleteOfflinePurchase(purchaseId);
        if (success) {
          return ApiResponse.offline(true);
        } else {
          return ApiResponse.error('Failed to delete purchase from offline storage');
        }
      }
      
      // Make API call to delete purchase
      return await _apiService.delete(
        '${ApiConfig.purchasesUrl}/$purchaseId',
      );
    } catch (e) {
      debugPrint('Error in deletePurchase: $e');
      return ApiResponse.error('Failed to delete purchase: $e');
    }
  }

  // Link a purchase to a receipt
  Future<ApiResponse<Purchase>> linkToReceipt(int purchaseId, int receiptId) async {
    try {
      // Check for offline mode
      final isOfflineMode = await _apiService.isOfflineMode();
      
      if (isOfflineMode) {
        // In offline mode, update in local storage
        final purchase = await _getOfflinePurchaseById(purchaseId);
        if (purchase == null) {
          return ApiResponse.error('Purchase not found in offline storage');
        }
        
        final updatedPurchase = Purchase(
          id: purchase.id,
          supplier: purchase.supplier,
          date: purchase.date,
          amount: purchase.amount,
          status: purchase.status,
          receiptId: receiptId,
          items: purchase.items,
        );
        
        final result = await _updateOfflinePurchase(updatedPurchase);
        if (result != null) {
          return ApiResponse.offline(result);
        } else {
          return ApiResponse.error('Failed to link purchase to receipt offline');
        }
      }
      
      // Make API call to link
      final response = await _apiService.put<Map<String, dynamic>>(
        '${ApiConfig.purchasesUrl}/$purchaseId/link/$receiptId',
        body: {},
        fromJson: (json) => json,
      );
      
      if (response.success) {
        final updatedPurchase = Purchase.fromJson(response.data!);
        return ApiResponse.success(updatedPurchase);
      } else {
        return ApiResponse.error(response.errorMessage ?? 'Failed to link purchase to receipt');
      }
    } catch (e) {
      debugPrint('Error in linkToReceipt: $e');
      return ApiResponse.error('Failed to link purchase to receipt: $e');
    }
  }

  // Helper methods for offline data
  Future<List<Purchase>> _getOfflinePurchases() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final offlinePurchasesJson = prefs.getString('offline_purchases');
      
      if (offlinePurchasesJson != null) {
        final List<dynamic> purchasesData = jsonDecode(offlinePurchasesJson) as List;
        return purchasesData.map((json) => Purchase.fromJson(json)).toList();
      }
      
      return [];
    } catch (e) {
      debugPrint('Error getting offline purchases: $e');
      return [];
    }
  }

  Future<List<dynamic>> _getOfflinePurchasesAsJson() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final offlinePurchasesJson = prefs.getString('offline_purchases');
      
      if (offlinePurchasesJson != null) {
        return jsonDecode(offlinePurchasesJson) as List;
      }
      
      // Generate mock purchases if none exist
      final mockPurchases = _generateMockPurchases();
      
      // Save them for future use
      await prefs.setString('offline_purchases', jsonEncode(mockPurchases));
      
      return mockPurchases;
    } catch (e) {
      debugPrint('Error getting offline purchases as JSON: $e');
      return _generateMockPurchases(); // Return mock data as fallback
    }
  }
  
  List<Map<String, dynamic>> _generateMockPurchases() {
    // Mock suppliers
    final suppliers = [
      'Tanzania Breweries Ltd',
      'Tanesco',
      'Twiga Cement',
      'Azam Industries',
      'Serengeti Breweries',
      'Coca-Cola Kwanza',
      'Tigo Tanzania',
      'Vodacom Tanzania',
    ];
    
    // Generate purchases for the past 6 months
    final now = DateTime.now();
    final formatter = DateFormat('yyyy-MM-dd');
    
    List<Map<String, dynamic>> mockPurchases = [];
    
    // Generate 20 purchases with different dates
    for (int i = 0; i < 20; i++) {
      // Random date within last 6 months
      final daysAgo = (i * 9) % 180; // Spread out over 6 months
      final date = now.subtract(Duration(days: daysAgo));
      final dateStr = formatter.format(date);
      
      // Random amount between 100,000 and 1,000,000
      final amount = 100000 + (900000 * (i / 20));
      
      // Random supplier
      final supplier = suppliers[i % suppliers.length];
      
      // Random status
      final status = daysAgo < 30 ? 'Pending' : 'Received';
      
      // Create mock items
      List<Map<String, dynamic>> items = [];
      final itemCount = 1 + (i % 5); // 1-5 items
      
      for (int j = 0; j < itemCount; j++) {
        items.add({
          'name': 'Item ${j+1}',
          'quantity': j + 1,
          'price': amount / itemCount,
          'vat_amount': (amount / itemCount) * 0.18,
        });
      }
      
      mockPurchases.add({
        'id': i + 1,
        'supplier': supplier,
        'date': dateStr,
        'amount': amount,
        'status': status,
        'receipt_id': null,
        'items': items,
      });
    }
    
    return mockPurchases;
  }

  Future<Purchase?> _getOfflinePurchaseById(int purchaseId) async {
    try {
      final purchases = await _getOfflinePurchases();
      for (var purchase in purchases) {
        if (purchase.id == purchaseId) {
          return purchase;
        }
      }
      return null;
    } catch (e) {
      debugPrint('Error getting offline purchase by ID: $e');
      return null;
    }
  }

  Future<Purchase?> _addOfflinePurchase(Purchase purchase) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final purchases = await _getOfflinePurchases();
      
      // Generate a new ID (max existing ID + 1)
      int newId = 1;
      if (purchases.isNotEmpty) {
        newId = purchases.map((p) => p.id).reduce((max, id) => id > max ? id : max) + 1;
      }
      
      // Create new purchase with generated ID
      final newPurchase = Purchase(
        id: newId,
        supplier: purchase.supplier,
        date: purchase.date,
        amount: purchase.amount,
        status: purchase.status,
        receiptId: purchase.receiptId,
        items: purchase.items,
      );
      
      // Add to list and save
      purchases.add(newPurchase);
      await prefs.setString('offline_purchases', jsonEncode(purchases.map((p) => p.toJson()).toList()));
      
      return newPurchase;
    } catch (e) {
      debugPrint('Error adding offline purchase: $e');
      return null;
    }
  }

  Future<Purchase?> _updateOfflinePurchase(Purchase updatedPurchase) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final purchases = await _getOfflinePurchases();
      
      // Find purchase by ID and replace it
      bool found = false;
      final updatedPurchases = purchases.map((purchase) {
        if (purchase.id == updatedPurchase.id) {
          found = true;
          return updatedPurchase;
        }
        return purchase;
      }).toList();
      
      if (!found) {
        return null;
      }
      
      // Save updated list
      await prefs.setString('offline_purchases', jsonEncode(updatedPurchases.map((p) => p.toJson()).toList()));
      
      return updatedPurchase;
    } catch (e) {
      debugPrint('Error updating offline purchase: $e');
      return null;
    }
  }

  Future<bool> _deleteOfflinePurchase(int purchaseId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final purchases = await _getOfflinePurchases();
      
      // Filter out the purchase to delete
      final newList = purchases.where((p) => p.id != purchaseId).toList();
      
      // Save updated list
      await prefs.setString('offline_purchases', jsonEncode(newList.map((p) => p.toJson()).toList()));
      
      return true;
    } catch (e) {
      debugPrint('Error deleting offline purchase: $e');
      return false;
    }
  }
}