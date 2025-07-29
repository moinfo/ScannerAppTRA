import 'dart:convert';
import 'dart:io';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_receipt_scanner/config/api_config.dart';

class ApiResponse<T> {
  final T? data;
  final bool success;
  final String? errorMessage;
  final int? statusCode;
  final bool isOffline;

  ApiResponse({
    this.data,
    required this.success,
    this.errorMessage,
    this.statusCode,
    this.isOffline = false,
  });

  factory ApiResponse.success(T data) {
    return ApiResponse(
      data: data,
      success: true,
      statusCode: 200,
    );
  }

  factory ApiResponse.offline(T data) {
    return ApiResponse(
      data: data,
      success: true, 
      isOffline: true,
      statusCode: 200,
    );
  }

  factory ApiResponse.error(String message, {int? statusCode}) {
    return ApiResponse(
      success: false,
      errorMessage: message,
      statusCode: statusCode,
    );
  }
}

class ApiService {
  // Singleton pattern
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  // Default timeout duration
  final Duration _timeout = const Duration(seconds: 30);

  // Retry configuration
  final int _maxRetries = 3;
  final Duration _retryDelay = const Duration(seconds: 2);

  // Get auth token
  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  // Check if in offline mode
  Future<bool> isOfflineMode() async {
    // Force online mode for backend testing
    return false;
    // Original code:
    // final token = await _getToken();
    // return token != null && token.startsWith('offline_');
  }

  // Helper method to build headers
  Future<Map<String, String>> _getHeaders({bool requiresAuth = true}) async {
    final headers = {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };

    if (requiresAuth) {
      final token = await _getToken();
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }
    }

    return headers;
  }

  // Generic GET request with retry logic
  Future<ApiResponse<T>> get<T>(
    String endpoint, {
    required T Function(dynamic) fromJson,
    Map<String, dynamic>? queryParams,
    bool requiresAuth = true,
    T Function()? offlineFallback,
  }) async {
    // Check if backend should be used
    if (!ApiConfig.useRealBackend) {
      if (offlineFallback != null) {
        debugPrint('🔄 Using offline fallback because useRealBackend=false for GET $endpoint');
        return ApiResponse.offline(offlineFallback());
      } else {
        return ApiResponse.error('No offline data available and useRealBackend=false');
      }
    }
    
    // Check if in offline mode 
    if (await isOfflineMode()) {
      if (offlineFallback != null) {
        debugPrint('🔄 Using offline fallback for GET $endpoint');
        return ApiResponse.offline(offlineFallback());
      } else {
        return ApiResponse.error('No offline data available for this endpoint');
      }
    }

    final headers = await _getHeaders(requiresAuth: requiresAuth);
    String url = endpoint;

    // Add query parameters if provided
    if (queryParams != null && queryParams.isNotEmpty) {
      final queryString = Uri(queryParameters: queryParams).query;
      url = '$url?$queryString';
    }

    debugPrint('🌐 GET Request to: $url');

    for (int attempt = 0; attempt < _maxRetries; attempt++) {
      try {
        final response = await http
            .get(Uri.parse(url), headers: headers)
            .timeout(_timeout);

        debugPrint('📥 Response status: ${response.statusCode}');

        if (response.statusCode >= 200 && response.statusCode < 300) {
          // Success
          return ApiResponse.success(fromJson(jsonDecode(response.body)));
        } else if (response.statusCode == 401) {
          // Unauthorized - handle token expiration
          return ApiResponse.error('Unauthorized. Please login again.',
              statusCode: response.statusCode);
        } else {
          // Other errors
          String errorMessage;
          try {
            final errorJson = jsonDecode(response.body);
            errorMessage = errorJson['message'] ?? 'Unknown error occurred';
          } catch (e) {
            errorMessage = 'Error: ${response.statusCode}';
          }
          
          // If not last attempt, retry
          if (attempt < _maxRetries - 1) {
            debugPrint('⚠️ Attempt ${attempt + 1} failed. Retrying...');
            await Future.delayed(_retryDelay * (attempt + 1));
            continue;
          }
          
          return ApiResponse.error(errorMessage, statusCode: response.statusCode);
        }
      } on SocketException catch (e) {
        // Network error
        if (attempt < _maxRetries - 1) {
          debugPrint('⚠️ Network error. Retrying...');
          await Future.delayed(_retryDelay * (attempt + 1));
          continue;
        }
        return ApiResponse.error('Network error: ${e.message}');
      } on TimeoutException catch (e) {
        // Timeout
        if (attempt < _maxRetries - 1) {
          debugPrint('⚠️ Request timed out. Retrying...');
          await Future.delayed(_retryDelay * (attempt + 1));
          continue;
        }
        return ApiResponse.error('Request timed out: ${e.message}');
      } catch (e) {
        // Other exceptions
        if (attempt < _maxRetries - 1) {
          debugPrint('⚠️ Error: $e. Retrying...');
          await Future.delayed(_retryDelay * (attempt + 1));
          continue;
        }
        return ApiResponse.error('Unexpected error: $e');
      }
    }

    // This should never be reached, but just in case
    return ApiResponse.error('Request failed after multiple attempts');
  }

  // Generic POST request with retry logic
  Future<ApiResponse<T>> post<T>(
    String endpoint, {
    required Object body,
    required T Function(dynamic) fromJson,
    bool requiresAuth = true,
    T Function()? offlineFallback,
  }) async {
    // Check if backend should be used
    if (!ApiConfig.useRealBackend) {
      if (offlineFallback != null) {
        debugPrint('🔄 Using offline fallback because useRealBackend=false for POST $endpoint');
        return ApiResponse.offline(offlineFallback());
      } else {
        return ApiResponse.error('No offline data available and useRealBackend=false');
      }
    }
    
    // Check if in offline mode
    if (await isOfflineMode()) {
      return ApiResponse.error('Cannot perform POST request in offline mode');
    }

    final headers = await _getHeaders(requiresAuth: requiresAuth);
    
    debugPrint('🌐 POST Request to: $endpoint');
    debugPrint('📤 Request body: $body');

    for (int attempt = 0; attempt < _maxRetries; attempt++) {
      try {
        final response = await http
            .post(
              Uri.parse(endpoint),
              headers: headers,
              body: jsonEncode(body),
            )
            .timeout(_timeout);

        debugPrint('📥 Response status: ${response.statusCode}');

        if (response.statusCode >= 200 && response.statusCode < 300) {
          // Success
          return ApiResponse.success(fromJson(jsonDecode(response.body)));
        } else if (response.statusCode == 401) {
          // Unauthorized - handle token expiration
          return ApiResponse.error('Unauthorized. Please login again.',
              statusCode: response.statusCode);
        } else {
          // Other errors
          String errorMessage;
          try {
            final errorJson = jsonDecode(response.body);
            errorMessage = errorJson['message'] ?? 'Unknown error occurred';
          } catch (e) {
            errorMessage = 'Error: ${response.statusCode}';
          }
          
          // If not last attempt, retry
          if (attempt < _maxRetries - 1) {
            debugPrint('⚠️ Attempt ${attempt + 1} failed. Retrying...');
            await Future.delayed(_retryDelay * (attempt + 1));
            continue;
          }
          
          return ApiResponse.error(errorMessage, statusCode: response.statusCode);
        }
      } on SocketException catch (e) {
        // Network error
        if (attempt < _maxRetries - 1) {
          debugPrint('⚠️ Network error. Retrying...');
          await Future.delayed(_retryDelay * (attempt + 1));
          continue;
        }
        return ApiResponse.error('Network error: ${e.message}');
      } on TimeoutException catch (e) {
        // Timeout
        if (attempt < _maxRetries - 1) {
          debugPrint('⚠️ Request timed out. Retrying...');
          await Future.delayed(_retryDelay * (attempt + 1));
          continue;
        }
        return ApiResponse.error('Request timed out: ${e.message}');
      } catch (e) {
        // Other exceptions
        if (attempt < _maxRetries - 1) {
          debugPrint('⚠️ Error: $e. Retrying...');
          await Future.delayed(_retryDelay * (attempt + 1));
          continue;
        }
        return ApiResponse.error('Unexpected error: $e');
      }
    }

    // This should never be reached, but just in case
    return ApiResponse.error('Request failed after multiple attempts');
  }

  // Generic PUT request with retry logic
  Future<ApiResponse<T>> put<T>(
    String endpoint, {
    required Object body,
    required T Function(dynamic) fromJson,
    bool requiresAuth = true,
    T Function()? offlineFallback,
  }) async {
    // Check if backend should be used
    if (!ApiConfig.useRealBackend) {
      if (offlineFallback != null) {
        debugPrint('🔄 Using offline fallback because useRealBackend=false for PUT $endpoint');
        return ApiResponse.offline(offlineFallback());
      } else {
        return ApiResponse.error('No offline data available and useRealBackend=false');
      }
    }
    
    // Check if in offline mode
    if (await isOfflineMode()) {
      return ApiResponse.error('Cannot perform PUT request in offline mode');
    }

    final headers = await _getHeaders(requiresAuth: requiresAuth);
    
    debugPrint('🌐 PUT Request to: $endpoint');
    debugPrint('📤 Request body: $body');

    for (int attempt = 0; attempt < _maxRetries; attempt++) {
      try {
        final response = await http
            .put(
              Uri.parse(endpoint),
              headers: headers,
              body: jsonEncode(body),
            )
            .timeout(_timeout);

        debugPrint('📥 Response status: ${response.statusCode}');

        if (response.statusCode >= 200 && response.statusCode < 300) {
          // Success
          return ApiResponse.success(fromJson(jsonDecode(response.body)));
        } else if (response.statusCode == 401) {
          // Unauthorized - handle token expiration
          return ApiResponse.error('Unauthorized. Please login again.',
              statusCode: response.statusCode);
        } else {
          // Other errors
          String errorMessage;
          try {
            final errorJson = jsonDecode(response.body);
            errorMessage = errorJson['message'] ?? 'Unknown error occurred';
          } catch (e) {
            errorMessage = 'Error: ${response.statusCode}';
          }
          
          // If not last attempt, retry
          if (attempt < _maxRetries - 1) {
            debugPrint('⚠️ Attempt ${attempt + 1} failed. Retrying...');
            await Future.delayed(_retryDelay * (attempt + 1));
            continue;
          }
          
          return ApiResponse.error(errorMessage, statusCode: response.statusCode);
        }
      } on SocketException catch (e) {
        // Network error
        if (attempt < _maxRetries - 1) {
          debugPrint('⚠️ Network error. Retrying...');
          await Future.delayed(_retryDelay * (attempt + 1));
          continue;
        }
        return ApiResponse.error('Network error: ${e.message}');
      } on TimeoutException catch (e) {
        // Timeout
        if (attempt < _maxRetries - 1) {
          debugPrint('⚠️ Request timed out. Retrying...');
          await Future.delayed(_retryDelay * (attempt + 1));
          continue;
        }
        return ApiResponse.error('Request timed out: ${e.message}');
      } catch (e) {
        // Other exceptions
        if (attempt < _maxRetries - 1) {
          debugPrint('⚠️ Error: $e. Retrying...');
          await Future.delayed(_retryDelay * (attempt + 1));
          continue;
        }
        return ApiResponse.error('Unexpected error: $e');
      }
    }

    // This should never be reached, but just in case
    return ApiResponse.error('Request failed after multiple attempts');
  }

  // Generic DELETE request with retry logic
  Future<ApiResponse<bool>> delete(
    String endpoint, {
    bool requiresAuth = true,
    bool Function()? offlineFallback,
  }) async {
    // Check if backend should be used
    if (!ApiConfig.useRealBackend) {
      if (offlineFallback != null) {
        debugPrint('🔄 Using offline fallback because useRealBackend=false for DELETE $endpoint');
        return ApiResponse.offline(offlineFallback());
      } else {
        return ApiResponse.error('No offline data available and useRealBackend=false');
      }
    }
    
    // Check if in offline mode
    if (await isOfflineMode()) {
      return ApiResponse.error('Cannot perform DELETE request in offline mode');
    }

    final headers = await _getHeaders(requiresAuth: requiresAuth);
    
    debugPrint('🌐 DELETE Request to: $endpoint');

    for (int attempt = 0; attempt < _maxRetries; attempt++) {
      try {
        final response = await http
            .delete(
              Uri.parse(endpoint),
              headers: headers,
            )
            .timeout(_timeout);

        debugPrint('📥 Response status: ${response.statusCode}');

        if (response.statusCode >= 200 && response.statusCode < 300) {
          // Success
          return ApiResponse.success(true);
        } else if (response.statusCode == 401) {
          // Unauthorized - handle token expiration
          return ApiResponse.error('Unauthorized. Please login again.',
              statusCode: response.statusCode);
        } else {
          // Other errors
          String errorMessage;
          try {
            final errorJson = jsonDecode(response.body);
            errorMessage = errorJson['message'] ?? 'Unknown error occurred';
          } catch (e) {
            errorMessage = 'Error: ${response.statusCode}';
          }
          
          // If not last attempt, retry
          if (attempt < _maxRetries - 1) {
            debugPrint('⚠️ Attempt ${attempt + 1} failed. Retrying...');
            await Future.delayed(_retryDelay * (attempt + 1));
            continue;
          }
          
          return ApiResponse.error(errorMessage, statusCode: response.statusCode);
        }
      } on SocketException catch (e) {
        // Network error
        if (attempt < _maxRetries - 1) {
          debugPrint('⚠️ Network error. Retrying...');
          await Future.delayed(_retryDelay * (attempt + 1));
          continue;
        }
        return ApiResponse.error('Network error: ${e.message}');
      } on TimeoutException catch (e) {
        // Timeout
        if (attempt < _maxRetries - 1) {
          debugPrint('⚠️ Request timed out. Retrying...');
          await Future.delayed(_retryDelay * (attempt + 1));
          continue;
        }
        return ApiResponse.error('Request timed out: ${e.message}');
      } catch (e) {
        // Other exceptions
        if (attempt < _maxRetries - 1) {
          debugPrint('⚠️ Error: $e. Retrying...');
          await Future.delayed(_retryDelay * (attempt + 1));
          continue;
        }
        return ApiResponse.error('Unexpected error: $e');
      }
    }

    // This should never be reached, but just in case
    return ApiResponse.error('Request failed after multiple attempts');
  }
}