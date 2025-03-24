import 'package:flutter/foundation.dart';
import 'package:flutter_receipt_scanner/main.dart';
import 'package:flutter_receipt_scanner/services/receipt_service.dart';
import 'package:flutter_receipt_scanner/services/api_service.dart';
import 'package:flutter_receipt_scanner/utils/api_request_status.dart';
import 'package:intl/intl.dart';

class ReceiptProvider extends ChangeNotifier {
  final ReceiptService _receiptService = ReceiptService();
  
  List<Receipt> _receipts = [];
  APIRequestStatus _apiRequestStatus = APIRequestStatus.loading;
  String _lastError = '';
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMoreData = true;
  int _currentPage = 1;
  
  List<Receipt> get receipts => _receipts;
  APIRequestStatus get apiRequestStatus => _apiRequestStatus;
  String get lastError => _lastError;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore; 
  bool get hasMoreData => _hasMoreData;

  ReceiptProvider() {
    debugPrint('ReceiptProvider initialized');
  }

  Future<void> fetchReceipts({DateTime? startDate, DateTime? endDate, String? searchTerm}) async {
    debugPrint('Starting fetchReceipts()');
    _apiRequestStatus = APIRequestStatus.loading;
    _isLoading = true;
    _currentPage = 1;
    _hasMoreData = true;
    notifyListeners();

    try {
      final response = await _receiptService.getReceipts(
        page: _currentPage,
        startDate: startDate,
        endDate: endDate,
        searchTerm: searchTerm,
      );
      
      if (response.success) {
        final responseData = response.data!;
        final List<dynamic> receiptData = responseData['receipts']['data'] as List<dynamic>;
        
        // Check if there are more pages
        final meta = responseData['receipts']['meta'];
        _hasMoreData = meta != null && 
            meta['current_page'] < meta['last_page'] && 
            receiptData.isNotEmpty;
        
        // Parse receipts
        List<Receipt> newReceipts = getReceiptsFromJson(receiptData);
        debugPrint('Successfully parsed ${newReceipts.length} receipts');
        
        _receipts = newReceipts;
        _apiRequestStatus = APIRequestStatus.loaded;
        _lastError = '';
      } else {
        _lastError = response.errorMessage ?? 'Unknown error';
        _apiRequestStatus = response.isOffline ? APIRequestStatus.loaded : APIRequestStatus.error;
        
        if (response.statusCode == 401) {
          _apiRequestStatus = APIRequestStatus.error;
          _lastError = 'Unauthorized access. Please login again.';
        }
      }
    } catch (e) {
      debugPrint('Error in fetchReceipts: $e');
      _lastError = 'Unexpected error: $e';
      _apiRequestStatus = APIRequestStatus.error;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  Future<void> loadMoreReceipts({DateTime? startDate, DateTime? endDate, String? searchTerm}) async {
    if (_isLoadingMore || !_hasMoreData) return;
    
    debugPrint('Loading more receipts, page: ${_currentPage + 1}');
    _isLoadingMore = true;
    notifyListeners();
    
    try {
      final response = await _receiptService.getReceipts(
        page: _currentPage + 1,
        startDate: startDate,
        endDate: endDate,
        searchTerm: searchTerm,
      );
      
      if (response.success) {
        final responseData = response.data!;
        final List<dynamic> receiptData = responseData['receipts']['data'] as List<dynamic>;
        
        // Check if there are more pages
        final meta = responseData['receipts']['meta'];
        _hasMoreData = meta != null && 
            meta['current_page'] < meta['last_page'] && 
            receiptData.isNotEmpty;
            
        // Update current page
        _currentPage++;
        
        if (receiptData.isNotEmpty) {
          List<Receipt> newReceipts = getReceiptsFromJson(receiptData);
          _receipts.addAll(newReceipts);
          debugPrint('Added ${newReceipts.length} more receipts. Total: ${_receipts.length}');
        } else {
          _hasMoreData = false;
          debugPrint('No more receipts to load');
        }
      } else {
        // Don't update _lastError here - we don't want to show an error message
        // for pagination, just stop loading more
        _hasMoreData = false;
        debugPrint('Error loading more: ${response.errorMessage}');
      }
    } catch (e) {
      debugPrint('Error loading more: $e');
      _hasMoreData = false;
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  bool checkIfReceiptExists(String code) {
    debugPrint('Checking for receipt with code: $code');
    var receipts = _receipts.where((receipt) => receipt.verificationCode == code);
    bool exists = receipts.isNotEmpty;
    debugPrint('Receipt exists: $exists');
    return exists;
  }

  List<Receipt> getReceiptsFromJson(List<dynamic> json) {
    debugPrint('Starting to parse ${json.length} receipts');
    List<Receipt> parsedReceipts = [];

    for (var i = 0; i < json.length; i++) {
      try {
        var receipt = Receipt.fromJson(json[i]);
        parsedReceipts.add(receipt);
      } catch (e) {
        debugPrint('Error parsing receipt at index $i: $e');
        debugPrint('Problematic JSON: ${json[i]}');
      }
    }

    debugPrint('Successfully parsed ${parsedReceipts.length} out of ${json.length} receipts');
    return parsedReceipts;
  }
  
  // Add a new receipt
  Future<bool> addReceipt(Map<String, dynamic> receipt) async {
    try {
      final response = await _receiptService.addReceipt(receipt);
      if (response.success) {
        await fetchReceipts(); // Refresh the list
        return true;
      } else {
        _lastError = response.errorMessage ?? 'Failed to add receipt';
        notifyListeners();
        return false;
      }
    } catch (e) {
      debugPrint('Error adding receipt: $e');
      _lastError = 'Error adding receipt: $e';
      notifyListeners();
      return false;
    }
  }
  
  // Delete a receipt
  Future<bool> deleteReceipt(int receiptId) async {
    try {
      final response = await _receiptService.deleteReceipt(receiptId);
      if (response.success) {
        // Remove from local list
        _receipts.removeWhere((receipt) => receipt.id == receiptId);
        notifyListeners();
        return true;
      } else {
        _lastError = response.errorMessage ?? 'Failed to delete receipt';
        notifyListeners();
        return false;
      }
    } catch (e) {
      debugPrint('Error deleting receipt: $e');
      _lastError = 'Error deleting receipt: $e';
      notifyListeners();
      return false;
    }
  }
}