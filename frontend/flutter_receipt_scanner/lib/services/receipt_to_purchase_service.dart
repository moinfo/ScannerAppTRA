import 'package:flutter/material.dart';
import 'package:flutter_receipt_scanner/config/api_config.dart';
import 'package:flutter_receipt_scanner/main.dart';
import 'package:flutter_receipt_scanner/services/api_service.dart';
import 'package:flutter_receipt_scanner/services/purchase_service.dart';
import 'package:intl/intl.dart';

class ReceiptToPurchaseService {
  final ApiService _apiService = ApiService();
  
  // Singleton pattern
  static final ReceiptToPurchaseService _instance = ReceiptToPurchaseService._internal();
  factory ReceiptToPurchaseService() => _instance;
  ReceiptToPurchaseService._internal();

  // Convert a receipt to a purchase
  Future<ApiResponse<Purchase>> convertReceiptToPurchase(Receipt receipt) async {
    try {
      // Check for offline mode
      final isOfflineMode = await _apiService.isOfflineMode();
      
      if (isOfflineMode) {
        // Create a purchase from the receipt in offline mode
        final purchase = _createPurchaseFromReceipt(receipt);
        
        // Use PurchaseService to save the purchase
        final purchaseService = PurchaseService();
        final response = await purchaseService.createPurchase(purchase);
        return response;
      }
      
      // Create a purchase from the receipt for offline fallback
      final fallbackPurchase = _createPurchaseFromReceipt(receipt);
      
      // Make API call to convert receipt to purchase
      final response = await _apiService.post<Map<String, dynamic>>(
        '${ApiConfig.purchasesUrl}/from-receipt/${receipt.id}',
        body: {},
        fromJson: (json) => json,
        offlineFallback: () => fallbackPurchase.toJson(),
      );
      
      if (response.success) {
        final purchase = Purchase.fromJson(response.data!);
        return ApiResponse.success(purchase);
      } else {
        return ApiResponse.error(response.errorMessage ?? 'Failed to convert receipt to purchase');
      }
    } catch (e) {
      debugPrint('Error converting receipt to purchase: $e');
      return ApiResponse.error('Failed to convert receipt to purchase: $e');
    }
  }
  
  // Create a Purchase object from a Receipt
  Purchase _createPurchaseFromReceipt(Receipt receipt) {
    // Extract items from receipt
    final items = receipt.items?.map((item) => 
      PurchaseItem(
        name: item.description ?? 'Unknown Item',
        quantity: item.quantity ?? 1,
        price: (item.amount ?? 0) / (item.quantity ?? 1),
        vatAmount: item.quantity != null && item.quantity! > 0 
            ? ((item.amount ?? 0) * 0.18) / item.quantity! 
            : 0,
      )
    ).toList() ?? [];
    
    // If no items in receipt, create a generic one
    if (items.isEmpty) {
      items.add(
        PurchaseItem(
          name: 'Purchase from ${receipt.companyName}',
          quantity: 1,
          price: receipt.totalInclOfTax ?? 0,
          vatAmount: (receipt.totalInclOfTax ?? 0) * 0.18,
        ),
      );
    }
    
    // Calculate total amount (excluding tax)
    double totalAmount = receipt.totalExlcOfTax ?? 0;
    
    // If no total excluding tax is available, use total including tax / 1.18 (assuming 18% VAT)
    if (totalAmount == 0 && receipt.totalInclOfTax != null && receipt.totalInclOfTax! > 0) {
      totalAmount = receipt.totalInclOfTax! / 1.18;
    }
    
    // Create a purchase object
    return Purchase(
      id: 0, // Will be assigned by the service
      supplier: receipt.companyName,
      date: receipt.date ?? DateFormat('yyyy-MM-dd').format(DateTime.now()),
      amount: totalAmount,
      status: 'Completed',
      receiptId: receipt.id,
      items: items,
    );
  }
}