import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_receipt_scanner/config/api_config.dart';
import 'package:flutter_receipt_scanner/services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

class ReceiptService {
  final ApiService _apiService = ApiService();
  
  // Singleton pattern
  static final ReceiptService _instance = ReceiptService._internal();
  factory ReceiptService() => _instance;
  ReceiptService._internal();

  // Fixed getReceipts method on line 86
  Future<ApiResponse<Map<String, dynamic>>> getReceipts({
    int page = 1,
    DateTime? startDate,
    DateTime? endDate,
    String? searchTerm,
  }) async {
    try {
      // Check for offline mode
      final isOfflineMode = await _apiService.isOfflineMode();

      if (isOfflineMode) {
        // Get offline receipts data and create formatted result
        final offlineData = await _getOfflineReceipts();

        // Apply filtering if needed
        List<dynamic> filteredData = offlineData;

        if (searchTerm != null && searchTerm.isNotEmpty) {
          final searchLower = searchTerm.toLowerCase();
          filteredData = filteredData.where((item) =>
              item['companyName'].toString().toLowerCase().contains(searchLower)
          ).toList();
        }

        if (startDate != null && endDate != null) {
          filteredData = filteredData.where((item) {
            try {
              final itemDate = DateTime.parse(item['date']);
              return itemDate.isAfter(startDate.subtract(const Duration(days: 1))) &&
                  itemDate.isBefore(endDate.add(const Duration(days: 1)));
            } catch (e) {
              return false;
            }
          }).toList();
        }

        // Create a mock pagination result
        final Map<String, dynamic> result = {
          'receipts': {
            'data': filteredData,
            'meta': {
              'current_page': page,
              'last_page': page,
              'total': filteredData.length,
              'per_page': 20,
            }
          }
        };

        return ApiResponse.offline(result);
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

      // Pre-fetch offline data before the API call
      final offlineData = await _getOfflineReceipts();
      final offlinePaginationResult = {
        'receipts': {
          'data': offlineData,
          'meta': {
            'current_page': page,
            'last_page': page,
            'total': offlineData.length,
            'per_page': 20,
          }
        }
      };

      // Make API call with synchronous offlineFallback
      return await _apiService.get<Map<String, dynamic>>(
        await ApiConfig.receiptsUrl,
        queryParams: queryParams,
        fromJson: (json) => json,
        offlineFallback: () => offlinePaginationResult,  // Now synchronous
      );
    } catch (e) {
      debugPrint('Error in getReceipts: $e');
      return ApiResponse.error('Failed to fetch receipts: $e');
    }
  }

// Fixed getReceiptDetails method on line 156
  Future<ApiResponse<Map<String, dynamic>>> getReceiptDetails(int receiptId) async {
    try {
      // Check for offline mode
      final isOfflineMode = await _apiService.isOfflineMode();

      if (isOfflineMode) {
        // In offline mode, get from local storage
        final receipt = await _getOfflineReceiptById(receiptId);
        if (receipt != null) {
          return ApiResponse.offline(receipt);
        } else {
          return ApiResponse.error('Receipt not found in offline storage');
        }
      }

      // Pre-fetch the offline receipt before the API call
      final offlineReceipt = await _getOfflineReceiptById(receiptId);

      // Make API call with synchronous offlineFallback
      return await _apiService.get<Map<String, dynamic>>(
        '${await ApiConfig.receiptsUrl}/$receiptId',
        fromJson: (json) => json,
        offlineFallback: offlineReceipt != null
            ? () => offlineReceipt  // Synchronous function
            : null,  // No fallback if receipt not found
      );
    } catch (e) {
      debugPrint('Error in getReceiptDetails: $e');
      return ApiResponse.error('Failed to get receipt details: $e');
    }
  }
  // Add a new receipt
  Future<ApiResponse<Map<String, dynamic>>> addReceipt(Map<String, dynamic> receiptData) async {
    try {
      // Check for offline mode
      final isOfflineMode = await _apiService.isOfflineMode();
      
      if (isOfflineMode) {
        // In offline mode, save to local storage
        final success = await _addOfflineReceipt(receiptData);
        if (success) {
          return ApiResponse.offline({'success': true, 'message': 'Receipt saved offline'});
        } else {
          return ApiResponse.error('Failed to save receipt offline');
        }
      }
      
      // Make API call to add receipt
      return await _apiService.post<Map<String, dynamic>>(
        await ApiConfig.addReceiptUrl,
        body: receiptData,
        fromJson: (json) => json,
      );
    } catch (e) {
      debugPrint('Error in addReceipt: $e');
      return ApiResponse.error('Failed to add receipt: $e');
    }
  }


  // Delete a receipt
  Future<ApiResponse<bool>> deleteReceipt(int receiptId) async {
    try {
      // Check for offline mode
      final isOfflineMode = await _apiService.isOfflineMode();
      
      if (isOfflineMode) {
        // In offline mode, delete from local storage
        final success = await _deleteOfflineReceipt(receiptId);
        if (success) {
          return ApiResponse.offline(true);
        } else {
          return ApiResponse.error('Failed to delete receipt from offline storage');
        }
      }
      
      // Make API call to delete receipt
      return await _apiService.delete(
        '${await ApiConfig.receiptsUrl}/$receiptId',
      );
    } catch (e) {
      debugPrint('Error in deleteReceipt: $e');
      return ApiResponse.error('Failed to delete receipt: $e');
    }
  }

  // Verify if a receipt exists by verification code
  Future<bool> checkIfReceiptExists(String verificationCode) async {
    try {
      // Check offline storage first
      final prefs = await SharedPreferences.getInstance();
      final offlineReceiptsJson = prefs.getString('offline_receipts');
      
      if (offlineReceiptsJson != null) {
        final offlineReceipts = jsonDecode(offlineReceiptsJson) as List;
        return offlineReceipts.any((receipt) => 
          receipt['verificationCode'] == verificationCode
        );
      }
      
      return false;
    } catch (e) {
      debugPrint('Error checking if receipt exists: $e');
      return false;
    }
  }

  // Helper methods for offline data
  Future<List<dynamic>> _getOfflineReceipts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final offlineReceiptsJson = prefs.getString('offline_receipts');
      
      if (offlineReceiptsJson != null) {
        return jsonDecode(offlineReceiptsJson) as List;
      }
      
      return [];
    } catch (e) {
      debugPrint('Error getting offline receipts: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>?> _getOfflineReceiptById(int receiptId) async {
    try {
      final offlineReceipts = await _getOfflineReceipts();
      final receipt = offlineReceipts.firstWhere(
        (r) => r['id'] == receiptId,
        orElse: () => null,
      );
      
      return receipt;
    } catch (e) {
      debugPrint('Error getting offline receipt by ID: $e');
      return null;
    }
  }

  Future<bool> _addOfflineReceipt(Map<String, dynamic> receiptData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final offlineReceipts = await _getOfflineReceipts();
      
      // Generate a new ID (max existing ID + 1)
      int newId = 1;
      if (offlineReceipts.isNotEmpty) {
        newId = offlineReceipts.map<int>((r) => r['id'] as int).reduce(
          (max, id) => id > max ? id : max
        ) + 1;
      }
      
      // Add ID to receipt data
      receiptData['id'] = newId;
      
      // Add timestamp if not present
      if (!receiptData.containsKey('date')) {
        receiptData['date'] = DateFormat('yyyy-MM-dd').format(DateTime.now());
      }
      if (!receiptData.containsKey('time')) {
        receiptData['time'] = DateFormat('HH:mm').format(DateTime.now());
      }
      
      // Add to list and save
      offlineReceipts.add(receiptData);
      await prefs.setString('offline_receipts', jsonEncode(offlineReceipts));
      
      return true;
    } catch (e) {
      debugPrint('Error adding offline receipt: $e');
      return false;
    }
  }

  Future<bool> _deleteOfflineReceipt(int receiptId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final offlineReceipts = await _getOfflineReceipts();
      
      // Filter out the receipt to delete
      final newList = offlineReceipts.where((r) => r['id'] != receiptId).toList();
      
      // Save updated list
      await prefs.setString('offline_receipts', jsonEncode(newList));
      
      return true;
    } catch (e) {
      debugPrint('Error deleting offline receipt: $e');
      return false;
    }
  }
}