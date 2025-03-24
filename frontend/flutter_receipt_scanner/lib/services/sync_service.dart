import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_receipt_scanner/services/database_service.dart';
import 'package:flutter_receipt_scanner/services/api_service.dart';
import 'package:flutter_receipt_scanner/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum SyncStatus {
  idle,
  syncing,
  success,
  error,
  offline,
}

class SyncResult {
  final SyncStatus status;
  final String message;
  final Map<String, dynamic>? data;
  
  SyncResult({
    required this.status,
    required this.message,
    this.data,
  });
}

class SyncService {
  final ApiService _apiService = ApiService();
  final DatabaseService _databaseService = DatabaseService();
  final Connectivity _connectivity = Connectivity();
  
  SyncStatus _currentStatus = SyncStatus.idle;
  Timer? _autoSyncTimer;
  bool _isSyncInProgress = false;
  DateTime _lastSyncAttempt = DateTime.now().subtract(const Duration(hours: 1));
  
  // Singleton pattern
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;
  SyncService._internal() {
    _initSyncService();
  }

  // Getters
  SyncStatus get status => _currentStatus;
  bool get isSyncing => _isSyncInProgress;
  DateTime get lastSyncAttempt => _lastSyncAttempt;

  // Initialize sync service
  Future<void> _initSyncService() async {
    debugPrint('Initializing sync service');
    
    // Check if sync is scheduled
    final prefs = await SharedPreferences.getInstance();
    final isAutoSyncEnabled = prefs.getBool('auto_sync_enabled') ?? true;
    
    if (isAutoSyncEnabled) {
      _scheduleAutoSync();
    }
    
    // Setup connectivity listener
    _connectivity.onConnectivityChanged.listen((ConnectivityResult result) {
      _handleConnectivityChange(result);
    });
  }

  // Handle connectivity change
  void _handleConnectivityChange(ConnectivityResult result) async {
    if (result != ConnectivityResult.none) {
      debugPrint('Connection restored, checking for pending syncs');
      
      // If we just came back online and it's been more than 15 minutes since last sync attempt
      final timeSinceLastSync = DateTime.now().difference(_lastSyncAttempt);
      if (timeSinceLastSync.inMinutes >= 15) {
        await syncAllPendingData();
      }
    }
  }

  // Schedule auto sync
  void _scheduleAutoSync() {
    // Cancel existing timer if any
    _autoSyncTimer?.cancel();
    
    // Schedule sync every 30 minutes
    _autoSyncTimer = Timer.periodic(const Duration(minutes: 30), (timer) async {
      final connectivityResult = await _connectivity.checkConnectivity();
      if (connectivityResult != ConnectivityResult.none) {
        await syncAllPendingData();
      }
    });
    
    debugPrint('Auto sync scheduled');
  }

  // Cancel auto sync
  void cancelAutoSync() {
    _autoSyncTimer?.cancel();
    _autoSyncTimer = null;
    debugPrint('Auto sync canceled');
  }

  // Enable/disable auto sync
  Future<void> setAutoSync(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('auto_sync_enabled', enabled);
    
    if (enabled) {
      _scheduleAutoSync();
    } else {
      cancelAutoSync();
    }
  }

  // Sync all pending data
  Future<SyncResult> syncAllPendingData() async {
    // Avoid multiple syncs running concurrently
    if (_isSyncInProgress) {
      return SyncResult(
        status: SyncStatus.syncing,
        message: 'Sync already in progress',
      );
    }
    
    debugPrint('Starting sync of all pending data');
    _isSyncInProgress = true;
    _currentStatus = SyncStatus.syncing;
    _lastSyncAttempt = DateTime.now();
    
    try {
      // Check connectivity
      final connectivityResult = await _connectivity.checkConnectivity();
      if (connectivityResult == ConnectivityResult.none) {
        _isSyncInProgress = false;
        _currentStatus = SyncStatus.offline;
        return SyncResult(
          status: SyncStatus.offline,
          message: 'No internet connection available',
        );
      }
      
      // Check if in offline mode
      final isOfflineMode = await _apiService.isOfflineMode();
      if (isOfflineMode) {
        _isSyncInProgress = false;
        _currentStatus = SyncStatus.offline;
        return SyncResult(
          status: SyncStatus.offline,
          message: 'App is in offline mode, sync not possible',
        );
      }
      
      // Get unsynced entities
      final unsyncedReceipts = await _databaseService.getUnsyncedEntities('receipt');
      final unsyncedSales = await _databaseService.getUnsyncedEntities('sale');
      final unsyncedPurchases = await _databaseService.getUnsyncedEntities('purchase');
      final unsyncedVatPayments = await _databaseService.getUnsyncedEntities('vat_payment');
      
      debugPrint('Found ${unsyncedReceipts.length} unsynced receipts');
      debugPrint('Found ${unsyncedSales.length} unsynced sales');
      debugPrint('Found ${unsyncedPurchases.length} unsynced purchases');
      debugPrint('Found ${unsyncedVatPayments.length} unsynced VAT payments');
      
      // Sync each type of entity
      final receiptResults = await _syncEntities(
        unsyncedReceipts,
        '${ApiConfig.receiptsUrl}/sync',
        'receipt',
      );
      
      final salesResults = await _syncEntities(
        unsyncedSales,
        '${ApiConfig.salesUrl}/sync',
        'sale',
      );
      
      final purchasesResults = await _syncEntities(
        unsyncedPurchases,
        '${ApiConfig.purchasesUrl}/sync',
        'purchase',
      );
      
      final vatPaymentsResults = await _syncEntities(
        unsyncedVatPayments,
        '${ApiConfig.reportsUrl}/vat/payments/sync',
        'vat_payment',
      );
      
      // Calculate total results
      final totalEntities = unsyncedReceipts.length + unsyncedSales.length +
          unsyncedPurchases.length + unsyncedVatPayments.length;
      
      final totalSuccess = receiptResults.successCount + salesResults.successCount +
          purchasesResults.successCount + vatPaymentsResults.successCount;
      
      final totalFailed = receiptResults.failedCount + salesResults.failedCount +
          purchasesResults.failedCount + vatPaymentsResults.failedCount;
      
      // Update status
      _isSyncInProgress = false;
      if (totalEntities == 0) {
        _currentStatus = SyncStatus.success;
        return SyncResult(
          status: SyncStatus.success,
          message: 'No data to sync',
          data: {
            'synced': 0,
            'failed': 0,
            'total': 0,
          },
        );
      } else if (totalSuccess == totalEntities) {
        _currentStatus = SyncStatus.success;
        return SyncResult(
          status: SyncStatus.success,
          message: 'All data synced successfully',
          data: {
            'synced': totalSuccess,
            'failed': 0,
            'total': totalEntities,
          },
        );
      } else if (totalFailed == totalEntities) {
        _currentStatus = SyncStatus.error;
        return SyncResult(
          status: SyncStatus.error,
          message: 'Failed to sync any data',
          data: {
            'synced': 0,
            'failed': totalFailed,
            'total': totalEntities,
          },
        );
      } else {
        _currentStatus = SyncStatus.success;
        return SyncResult(
          status: SyncStatus.success,
          message: 'Synced $totalSuccess out of $totalEntities items',
          data: {
            'synced': totalSuccess,
            'failed': totalFailed,
            'total': totalEntities,
          },
        );
      }
    } catch (e) {
      debugPrint('Error during sync: $e');
      _isSyncInProgress = false;
      _currentStatus = SyncStatus.error;
      return SyncResult(
        status: SyncStatus.error,
        message: 'Error during sync: $e',
      );
    }
  }

  // Sync a specific type of entity
  Future<_SyncEntityResult> _syncEntities(
    List<Map<String, dynamic>> entities,
    String endpoint,
    String entityType,
  ) async {
    if (entities.isEmpty) {
      return _SyncEntityResult(0, 0);
    }
    
    debugPrint('Syncing $entityType data to $endpoint');
    
    int successCount = 0;
    int failedCount = 0;
    
    for (var entity in entities) {
      try {
        final response = await _apiService.post<Map<String, dynamic>>(
          endpoint,
          body: entity,
          fromJson: (json) => json,
        );
        
        if (response.success) {
          // Mark as synced in database
          await _databaseService.markAsSynced(entityType, entity['id']);
          successCount++;
        } else {
          failedCount++;
          debugPrint('Failed to sync $entityType ${entity['id']}: ${response.errorMessage}');
        }
      } catch (e) {
        failedCount++;
        debugPrint('Error syncing $entityType ${entity['id']}: $e');
      }
    }
    
    debugPrint('Synced $successCount/$failedCount $entityType entries');
    return _SyncEntityResult(successCount, failedCount);
  }

  // Dispose
  void dispose() {
    cancelAutoSync();
  }
}

class _SyncEntityResult {
  final int successCount;
  final int failedCount;
  
  _SyncEntityResult(this.successCount, this.failedCount);
}