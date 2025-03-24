import 'package:flutter/foundation.dart';
import 'package:flutter_receipt_scanner/services/sales_service.dart';
import 'package:flutter_receipt_scanner/utils/api_request_status.dart';
import 'package:intl/intl.dart';

class SalesProvider extends ChangeNotifier {
  final SalesService _salesService = SalesService();
  
  List<Sale> _sales = [];
  APIRequestStatus _apiRequestStatus = APIRequestStatus.loading;
  String _lastError = '';
  bool _isLoading = false;
  bool _isOperationInProgress = false;
  
  List<Sale> get sales => _sales;
  APIRequestStatus get apiRequestStatus => _apiRequestStatus;
  String get lastError => _lastError;
  bool get isLoading => _isLoading;
  bool get isOperationInProgress => _isOperationInProgress;
  
  double get totalSales => _sales.fold(0, (sum, sale) => sum + sale.amount);
  int get completedSalesCount => _sales.where((sale) => sale.status == 'Completed').length;
  int get pendingSalesCount => _sales.where((sale) => sale.status == 'Pending').length;

  SalesProvider() {
    debugPrint('SalesProvider initialized');
  }

  Future<void> fetchSales({DateTime? startDate, DateTime? endDate, String? searchTerm}) async {
    debugPrint('Starting fetchSales()');
    _apiRequestStatus = APIRequestStatus.loading;
    _isLoading = true;
    notifyListeners();

    try {
      final response = await _salesService.getSales(
        startDate: startDate,
        endDate: endDate,
        searchTerm: searchTerm,
      );
      
      if (response.success) {
        _sales = response.data!;
        _apiRequestStatus = APIRequestStatus.loaded;
        _lastError = '';
        debugPrint('Successfully loaded ${_sales.length} sales');
      } else {
        _lastError = response.errorMessage ?? 'Unknown error';
        _apiRequestStatus = response.isOffline ? APIRequestStatus.loaded : APIRequestStatus.error;
        
        if (response.statusCode == 401) {
          _apiRequestStatus = APIRequestStatus.error;
          _lastError = 'Unauthorized access. Please login again.';
        }
      }
    } catch (e) {
      debugPrint('Error in fetchSales: $e');
      _lastError = 'Unexpected error: $e';
      _apiRequestStatus = APIRequestStatus.error;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Sale?> getSaleDetails(int saleId) async {
    try {
      final response = await _salesService.getSaleDetails(saleId);
      
      if (response.success) {
        return response.data;
      } else {
        _lastError = response.errorMessage ?? 'Failed to get sale details';
        notifyListeners();
        return null;
      }
    } catch (e) {
      debugPrint('Error getting sale details: $e');
      _lastError = 'Error getting sale details: $e';
      notifyListeners();
      return null;
    }
  }

  Future<bool> createSale(Sale sale) async {
    _isOperationInProgress = true;
    notifyListeners();
    
    try {
      final response = await _salesService.createSale(sale);
      
      if (response.success) {
        // Add to local list
        _sales.add(response.data!);
        _isOperationInProgress = false;
        notifyListeners();
        return true;
      } else {
        _lastError = response.errorMessage ?? 'Failed to create sale';
        _isOperationInProgress = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      debugPrint('Error creating sale: $e');
      _lastError = 'Error creating sale: $e';
      _isOperationInProgress = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateSale(Sale sale) async {
    _isOperationInProgress = true;
    notifyListeners();
    
    try {
      final response = await _salesService.updateSale(sale);
      
      if (response.success) {
        // Update in local list
        final index = _sales.indexWhere((s) => s.id == sale.id);
        if (index != -1) {
          _sales[index] = response.data!;
        }
        _isOperationInProgress = false;
        notifyListeners();
        return true;
      } else {
        _lastError = response.errorMessage ?? 'Failed to update sale';
        _isOperationInProgress = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      debugPrint('Error updating sale: $e');
      _lastError = 'Error updating sale: $e';
      _isOperationInProgress = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteSale(int saleId) async {
    _isOperationInProgress = true;
    notifyListeners();
    
    try {
      final response = await _salesService.deleteSale(saleId);
      
      if (response.success) {
        // Remove from local list
        _sales.removeWhere((sale) => sale.id == saleId);
        _isOperationInProgress = false;
        notifyListeners();
        return true;
      } else {
        _lastError = response.errorMessage ?? 'Failed to delete sale';
        _isOperationInProgress = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      debugPrint('Error deleting sale: $e');
      _lastError = 'Error deleting sale: $e';
      _isOperationInProgress = false;
      notifyListeners();
      return false;
    }
  }
}