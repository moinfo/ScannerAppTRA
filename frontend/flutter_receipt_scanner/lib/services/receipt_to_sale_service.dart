import 'package:flutter/material.dart';
import 'package:flutter_receipt_scanner/config/api_config.dart';
import 'package:flutter_receipt_scanner/main.dart';
import 'package:flutter_receipt_scanner/services/api_service.dart';
import 'package:flutter_receipt_scanner/services/sales_service.dart';
import 'package:intl/intl.dart';

class ReceiptToSaleService {
  final ApiService _apiService = ApiService();
  
  // Singleton pattern
  static final ReceiptToSaleService _instance = ReceiptToSaleService._internal();
  factory ReceiptToSaleService() => _instance;
  ReceiptToSaleService._internal();

  // Convert a receipt to a sale
  Future<ApiResponse<Sale>> convertReceiptToSale(Receipt receipt) async {
    try {
      // Check for offline mode
      final isOfflineMode = await _apiService.isOfflineMode();
      
      if (isOfflineMode) {
        // Create a sale from the receipt in offline mode
        final sale = _createSaleFromReceipt(receipt);
        
        // Use SalesService to save the sale
        final salesService = SalesService();
        final response = await salesService.createSale(sale);
        return response;
      }
      
      // Create a sale from the receipt for offline fallback
      final fallbackSale = _createSaleFromReceipt(receipt);
      
      // Make API call to convert receipt to sale
      final response = await _apiService.post<Map<String, dynamic>>(
        '${ApiConfig.salesUrl}/from-receipt/${receipt.id}',
        body: {},
        fromJson: (json) => json,
        offlineFallback: () => fallbackSale.toJson(),
      );
      
      if (response.success) {
        final sale = Sale.fromJson(response.data!);
        return ApiResponse.success(sale);
      } else {
        return ApiResponse.error(response.errorMessage ?? 'Failed to convert receipt to sale');
      }
    } catch (e) {
      debugPrint('Error converting receipt to sale: $e');
      return ApiResponse.error('Failed to convert receipt to sale: $e');
    }
  }
  
  // Create a Sale object from a Receipt
  Sale _createSaleFromReceipt(Receipt receipt) {
    // Extract items from receipt
    final items = receipt.items?.map((item) => 
      SaleItem(
        name: item.description ?? 'Unknown Item',
        quantity: item.quantity ?? 1,
        price: (item.amount ?? 0) / (item.quantity ?? 1),
      )
    ).toList() ?? [];
    
    // If no items in receipt, create a generic one
    if (items.isEmpty) {
      items.add(
        SaleItem(
          name: 'Purchase from ${receipt.companyName}',
          quantity: 1,
          price: receipt.totalInclOfTax ?? 0,
        ),
      );
    }
    
    // Calculate total amount (excluding tax)
    double totalAmount = receipt.totalExlcOfTax ?? 0;
    
    // If no total excluding tax is available, use total including tax / 1.18 (assuming 18% VAT)
    if (totalAmount == 0 && receipt.totalInclOfTax != null && receipt.totalInclOfTax! > 0) {
      totalAmount = receipt.totalInclOfTax! / 1.18;
    }
    
    // Create a sale object
    return Sale(
      id: 0, // Will be assigned by the service
      customer: receipt.companyName,
      date: receipt.date ?? DateFormat('yyyy-MM-dd').format(DateTime.now()),
      amount: totalAmount,
      status: 'Completed',
      items: items,
    );
  }
}