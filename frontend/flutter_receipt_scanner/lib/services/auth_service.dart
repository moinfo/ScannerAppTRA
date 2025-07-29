import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_receipt_scanner/main.dart';
import 'package:flutter_receipt_scanner/services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  final ApiService _apiService = ApiService();
  
  // Singleton pattern
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  // Login method that uses the API service
  Future<ApiResponse<Map<String, dynamic>>> login(String email, String password) async {
    try {
      // If backend is disabled, use offline login for any credentials
      if (!ApiConfig.useRealBackend) {
        debugPrint('🔑 Using offline login because useRealBackend=false');
        return await loginOffline(email);
      }
      
      final response = await _apiService.post<Map<String, dynamic>>(
        await ApiConfig.loginUrl,
        body: {
          'email': email,
          'password': password,
        },
        fromJson: (json) => json,
        requiresAuth: false,
      );

      if (response.success) {
        // Save authentication data
        await _saveAuthData(
          response.data!['token'],
          response.data!['user'],
        );
        return response;
      } else {
        return response;
      }
    } catch (e) {
      debugPrint('Error in login: $e');
      return ApiResponse.error('Login failed: $e');
    }
  }

  // Offline login mode for testing and demo
  Future<ApiResponse<Map<String, dynamic>>> loginOffline(String email) async {
    try {
      // Generate offline user data
      final String displayName = email.isEmpty 
          ? 'Offline User' 
          : email.contains('@') 
              ? email.split('@')[0] 
              : email;
              
      final userData = {
        'name': displayName,
        'email': email.isEmpty ? 'offline@example.com' : email,
      };
      
      // Store dummy authentication data
      final String offlineToken = 'offline_token_${DateTime.now().millisecondsSinceEpoch}';
      await _saveAuthData(offlineToken, userData);
      
      // Create sample offline data for testing
      await _setupOfflineData();
      
      return ApiResponse.offline({
        'token': offlineToken,
        'user': userData,
      });
    } catch (e) {
      debugPrint('Error in offline login: $e');
      return ApiResponse.error('Offline login failed: $e');
    }
  }

  // Save authentication data to SharedPreferences
  Future<void> _saveAuthData(String token, dynamic userData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', token);
      await prefs.setString('user', jsonEncode(userData));
      await prefs.setBool('isLoggedIn', true);
      debugPrint('Auth data saved');
    } catch (e) {
      debugPrint('Error saving auth data: $e');
      throw Exception('Failed to save auth data: $e');
    }
  }

  // Setup offline data for testing
  Future<void> _setupOfflineData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Offline receipts
      await prefs.setString('offline_receipts', jsonEncode([
        {
          'id': 1,
          'companyName': 'Grocery Store TZ',
          'date': '2025-03-24',
          'time': '10:30 AM',
          'amount': '12500',
          'items': '5 items'
        },
        {
          'id': 2,
          'companyName': 'Electronics Shop',
          'date': '2025-03-23',
          'time': '02:15 PM',
          'amount': '250000',
          'items': '2 items'
        },
        {
          'id': 3,
          'companyName': 'Pharmacy',
          'date': '2025-03-22',
          'time': '09:45 AM',
          'amount': '35000',
          'items': '3 items'
        }
      ]));
      
      // Offline sales data
      await prefs.setString('offline_sales', jsonEncode([
        {
          'id': 1,
          'customer': 'John Doe',
          'date': '2025-03-24',
          'amount': 75000,
          'status': 'Completed',
          'items': [
            {'name': 'Product A', 'quantity': 2, 'price': 25000},
            {'name': 'Product B', 'quantity': 1, 'price': 25000}
          ]
        },
        {
          'id': 2,
          'customer': 'Jane Smith',
          'date': '2025-03-23',
          'amount': 120000,
          'status': 'Pending',
          'items': [
            {'name': 'Product C', 'quantity': 3, 'price': 40000}
          ]
        }
      ]));
      
      // Offline purchases data
      await prefs.setString('offline_purchases', jsonEncode([
        {
          'id': 1,
          'supplier': 'ABC Suppliers',
          'date': '2025-03-22',
          'amount': 150000,
          'status': 'Received',
          'receipt_id': 2
        },
        {
          'id': 2,
          'supplier': 'XYZ Trading',
          'date': '2025-03-20',
          'amount': 75000,
          'status': 'Ordered',
          'receipt_id': null
        }
      ]));
      
      // Offline VAT data
      await prefs.setString('offline_vat', jsonEncode([
        {
          'id': 1,
          'period': 'March 2025',
          'sales_vat': 35000,
          'purchases_vat': 20000,
          'amount_payable': 15000,
          'status': 'Pending',
          'due_date': '2025-04-15'
        }
      ]));
      
      debugPrint('Offline data setup complete');
    } catch (e) {
      debugPrint('Error setting up offline data: $e');
    }
  }

  // Logout method
  Future<bool> logout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      return true;
    } catch (e) {
      debugPrint('Error in logout: $e');
      return false;
    }
  }

  // Check if user is logged in
  Future<bool> isLoggedIn() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool('isLoggedIn') ?? false;
    } catch (e) {
      debugPrint('Error checking login status: $e');
      return false;
    }
  }

  // Get user info
  Future<Map<String, dynamic>> getUserInfo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final bool isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
      final String? token = prefs.getString('token');
      final String? userJson = prefs.getString('user');
      
      Map<String, dynamic> user = {};
      if (userJson != null) {
        try {
          user = jsonDecode(userJson);
        } catch (e) {
          debugPrint('Error decoding user JSON: $e');
        }
      }
      
      final String? email = user['email'];
      final String? name = user['name'];
      final bool isOfflineMode = token != null && token.startsWith('offline_');
      
      return {
        'isLoggedIn': isLoggedIn,
        'token': token,
        'email': email,
        'name': name,
        'isOfflineMode': isOfflineMode,
      };
    } catch (e) {
      debugPrint('Error getting user info: $e');
      return {
        'isLoggedIn': false,
        'isOfflineMode': false,
      };
    }
  }
}