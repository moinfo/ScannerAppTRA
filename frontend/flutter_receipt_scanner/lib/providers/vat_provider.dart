import 'package:flutter/foundation.dart';
import 'package:flutter_receipt_scanner/services/vat_service.dart';
import 'package:flutter_receipt_scanner/utils/api_request_status.dart';

class VatProvider extends ChangeNotifier {
  final VatService _vatService = VatService();
  
  List<VatPayment> _vatPayments = [];
  VatReport? _currentReport;
  APIRequestStatus _apiRequestStatus = APIRequestStatus.loading;
  APIRequestStatus _reportStatus = APIRequestStatus.loading;
  String _lastError = '';
  bool _isLoading = false;
  bool _isReportLoading = false;
  bool _isOperationInProgress = false;
  
  List<VatPayment> get vatPayments => _vatPayments;
  VatReport? get currentReport => _currentReport;
  APIRequestStatus get apiRequestStatus => _apiRequestStatus;
  APIRequestStatus get reportStatus => _reportStatus;
  String get lastError => _lastError;
  bool get isLoading => _isLoading;
  bool get isReportLoading => _isReportLoading;
  bool get isOperationInProgress => _isOperationInProgress;
  
  double get totalVatPayable => _vatPayments.fold(0, (sum, payment) => sum + payment.amountPayable);
  int get pendingPaymentsCount => _vatPayments.where((payment) => payment.status == 'Pending').length;
  int get completedPaymentsCount => _vatPayments.where((payment) => payment.status == 'Completed').length;

  VatProvider() {
    debugPrint('VatProvider initialized');
  }

  Future<void> fetchVatPayments({DateTime? startDate, DateTime? endDate, String? status}) async {
    debugPrint('Starting fetchVatPayments()');
    _apiRequestStatus = APIRequestStatus.loading;
    _isLoading = true;
    notifyListeners();

    try {
      final response = await _vatService.getVatPayments(
        startDate: startDate,
        endDate: endDate,
        status: status,
      );
      
      if (response.success) {
        _vatPayments = response.data!;
        _apiRequestStatus = APIRequestStatus.loaded;
        _lastError = '';
        debugPrint('Successfully loaded ${_vatPayments.length} VAT payments');
      } else {
        _lastError = response.errorMessage ?? 'Unknown error';
        _apiRequestStatus = response.isOffline ? APIRequestStatus.loaded : APIRequestStatus.error;
        
        if (response.statusCode == 401) {
          _apiRequestStatus = APIRequestStatus.error;
          _lastError = 'Unauthorized access. Please login again.';
        }
      }
    } catch (e) {
      debugPrint('Error in fetchVatPayments: $e');
      _lastError = 'Unexpected error: $e';
      _apiRequestStatus = APIRequestStatus.error;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<VatPayment?> getVatPaymentDetails(int paymentId) async {
    try {
      final response = await _vatService.getVatPaymentDetails(paymentId);
      
      if (response.success) {
        return response.data;
      } else {
        _lastError = response.errorMessage ?? 'Failed to get VAT payment details';
        notifyListeners();
        return null;
      }
    } catch (e) {
      debugPrint('Error getting VAT payment details: $e');
      _lastError = 'Error getting VAT payment details: $e';
      notifyListeners();
      return null;
    }
  }

  Future<bool> createVatPayment(VatPayment payment) async {
    _isOperationInProgress = true;
    notifyListeners();
    
    try {
      final response = await _vatService.createVatPayment(payment);
      
      if (response.success) {
        // Add to local list
        _vatPayments.add(response.data!);
        _isOperationInProgress = false;
        notifyListeners();
        return true;
      } else {
        _lastError = response.errorMessage ?? 'Failed to create VAT payment';
        _isOperationInProgress = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      debugPrint('Error creating VAT payment: $e');
      _lastError = 'Error creating VAT payment: $e';
      _isOperationInProgress = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateVatPaymentStatus(int paymentId, String status, {
    String? paymentMethod,
    String? paymentReference,
    String? paymentDate,
    String? notes,
  }) async {
    _isOperationInProgress = true;
    notifyListeners();
    
    try {
      final response = await _vatService.updateVatPaymentStatus(
        paymentId, 
        status,
        paymentMethod: paymentMethod,
        paymentReference: paymentReference,
        paymentDate: paymentDate,
        notes: notes,
      );
      
      if (response.success) {
        // Update in local list
        final index = _vatPayments.indexWhere((p) => p.id == paymentId);
        if (index != -1) {
          _vatPayments[index] = response.data!;
        }
        _isOperationInProgress = false;
        notifyListeners();
        return true;
      } else {
        _lastError = response.errorMessage ?? 'Failed to update VAT payment status';
        _isOperationInProgress = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      debugPrint('Error updating VAT payment status: $e');
      _lastError = 'Error updating VAT payment status: $e';
      _isOperationInProgress = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> generateVatReport(DateTime startDate, DateTime endDate) async {
    debugPrint('Starting generateVatReport()');
    _reportStatus = APIRequestStatus.loading;
    _isReportLoading = true;
    notifyListeners();

    try {
      final response = await _vatService.generateVatReport(startDate, endDate);
      
      if (response.success) {
        _currentReport = response.data;
        _reportStatus = APIRequestStatus.loaded;
        _lastError = '';
        debugPrint('Successfully generated VAT report');
      } else {
        _lastError = response.errorMessage ?? 'Unknown error';
        _reportStatus = response.isOffline ? APIRequestStatus.loaded : APIRequestStatus.error;
      }
    } catch (e) {
      debugPrint('Error in generateVatReport: $e');
      _lastError = 'Unexpected error: $e';
      _reportStatus = APIRequestStatus.error;
    } finally {
      _isReportLoading = false;
      notifyListeners();
    }
  }
}