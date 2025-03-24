import 'package:flutter/foundation.dart';
import 'package:flutter_receipt_scanner/services/purchase_service.dart';
import 'package:flutter_receipt_scanner/utils/api_request_status.dart';

class PurchasesProvider extends ChangeNotifier {
  final PurchaseService _purchaseService = PurchaseService();
  
  List<Purchase> _purchases = [];
  APIRequestStatus _apiRequestStatus = APIRequestStatus.loading;
  String _lastError = '';
  bool _isLoading = false;
  bool _isOperationInProgress = false;
  
  List<Purchase> get purchases => _purchases;
  APIRequestStatus get apiRequestStatus => _apiRequestStatus;
  String get lastError => _lastError;
  bool get isLoading => _isLoading;
  bool get isOperationInProgress => _isOperationInProgress;
  
  double get totalPurchases => _purchases.fold(0, (sum, purchase) => sum + purchase.amount);
  int get receivedPurchasesCount => _purchases.where((purchase) => purchase.status == 'Received').length;
  int get orderedPurchasesCount => _purchases.where((purchase) => purchase.status == 'Ordered').length;

  PurchasesProvider() {
    debugPrint('PurchasesProvider initialized');
  }

  Future<void> fetchPurchases({DateTime? startDate, DateTime? endDate, String? searchTerm}) async {
    debugPrint('Starting fetchPurchases()');
    _apiRequestStatus = APIRequestStatus.loading;
    _isLoading = true;
    notifyListeners();

    try {
      final response = await _purchaseService.getPurchases(
        startDate: startDate,
        endDate: endDate,
        searchTerm: searchTerm,
      );
      
      if (response.success) {
        _purchases = response.data!;
        _apiRequestStatus = APIRequestStatus.loaded;
        _lastError = '';
        debugPrint('Successfully loaded ${_purchases.length} purchases');
      } else {
        _lastError = response.errorMessage ?? 'Unknown error';
        _apiRequestStatus = response.isOffline ? APIRequestStatus.loaded : APIRequestStatus.error;
        
        if (response.statusCode == 401) {
          _apiRequestStatus = APIRequestStatus.error;
          _lastError = 'Unauthorized access. Please login again.';
        }
      }
    } catch (e) {
      debugPrint('Error in fetchPurchases: $e');
      _lastError = 'Unexpected error: $e';
      _apiRequestStatus = APIRequestStatus.error;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Purchase?> getPurchaseDetails(int purchaseId) async {
    try {
      final response = await _purchaseService.getPurchaseDetails(purchaseId);
      
      if (response.success) {
        return response.data;
      } else {
        _lastError = response.errorMessage ?? 'Failed to get purchase details';
        notifyListeners();
        return null;
      }
    } catch (e) {
      debugPrint('Error getting purchase details: $e');
      _lastError = 'Error getting purchase details: $e';
      notifyListeners();
      return null;
    }
  }

  Future<bool> createPurchase(Purchase purchase) async {
    _isOperationInProgress = true;
    notifyListeners();
    
    try {
      final response = await _purchaseService.createPurchase(purchase);
      
      if (response.success) {
        // Add to local list
        _purchases.add(response.data!);
        _isOperationInProgress = false;
        notifyListeners();
        return true;
      } else {
        _lastError = response.errorMessage ?? 'Failed to create purchase';
        _isOperationInProgress = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      debugPrint('Error creating purchase: $e');
      _lastError = 'Error creating purchase: $e';
      _isOperationInProgress = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> updatePurchase(Purchase purchase) async {
    _isOperationInProgress = true;
    notifyListeners();
    
    try {
      final response = await _purchaseService.updatePurchase(purchase);
      
      if (response.success) {
        // Update in local list
        final index = _purchases.indexWhere((p) => p.id == purchase.id);
        if (index != -1) {
          _purchases[index] = response.data!;
        }
        _isOperationInProgress = false;
        notifyListeners();
        return true;
      } else {
        _lastError = response.errorMessage ?? 'Failed to update purchase';
        _isOperationInProgress = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      debugPrint('Error updating purchase: $e');
      _lastError = 'Error updating purchase: $e';
      _isOperationInProgress = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> deletePurchase(int purchaseId) async {
    _isOperationInProgress = true;
    notifyListeners();
    
    try {
      final response = await _purchaseService.deletePurchase(purchaseId);
      
      if (response.success) {
        // Remove from local list
        _purchases.removeWhere((purchase) => purchase.id == purchaseId);
        _isOperationInProgress = false;
        notifyListeners();
        return true;
      } else {
        _lastError = response.errorMessage ?? 'Failed to delete purchase';
        _isOperationInProgress = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      debugPrint('Error deleting purchase: $e');
      _lastError = 'Error deleting purchase: $e';
      _isOperationInProgress = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> linkToReceipt(int purchaseId, int receiptId) async {
    _isOperationInProgress = true;
    notifyListeners();
    
    try {
      final response = await _purchaseService.linkToReceipt(purchaseId, receiptId);
      
      if (response.success) {
        // Update in local list
        final index = _purchases.indexWhere((p) => p.id == purchaseId);
        if (index != -1) {
          _purchases[index] = response.data!;
        }
        _isOperationInProgress = false;
        notifyListeners();
        return true;
      } else {
        _lastError = response.errorMessage ?? 'Failed to link purchase to receipt';
        _isOperationInProgress = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      debugPrint('Error linking purchase to receipt: $e');
      _lastError = 'Error linking purchase to receipt: $e';
      _isOperationInProgress = false;
      notifyListeners();
      return false;
    }
  }
}