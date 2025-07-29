import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:network_info_plus/network_info_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class ApiConfig {
  // Development settings
  static const bool useRealBackend = true;
  static const bool useLocalServer = true;
  static const bool autoDetectLocalIP = false; // Temporarily disable auto-detection
  
  // Production URLs (fallback)
  static const String productionBaseUrl = 'https://lemuru.co.tz/api';
  
  // Local server ports
  static const int backendPort = 8001;
  static const int scraperPort = 3000;
  static const int expressPort = 8000;
  
  // Fallback IPs for different network scenarios (prioritized by likelihood)
  static const List<String> commonLocalIPs = [
    '192.168.139.133',   // Confirmed working WiFi IP (highest priority)
    '192.168.0.60',   // Confirmed working WiFi IP (highest priority)
    '192.168.0.236',  // Recently detected IP (mobile network?)
    '192.168.1.1',    // Common router IP range
    '192.168.0.1',    // Common router IP range
    '10.0.0.1',       // Another common range
    '172.16.0.1',     // Corporate network range
    '127.0.0.1',      // Localhost fallback
  ];
  
  // Cache for detected IP
  static String? _cachedLocalIP;
  static DateTime? _lastIPCheck;
  static const Duration ipCacheTimeout = Duration(minutes: 5);
  
  // Get local IP address dynamically
  static Future<String> getLocalIP() async {
    // If auto-detection is disabled, use the first working IP from the list
    if (!autoDetectLocalIP) {
      for (String ip in commonLocalIPs) {
        if (await _testConnection(ip, backendPort)) {
          print('🎯 Using confirmed working IP: $ip');
          return ip;
        }
      }
      // If no working IP found, return the first one as fallback
      print('⚠️ No working IP found, using fallback: ${commonLocalIPs.first}');
      return commonLocalIPs.first;
    }
    
    // Return cached IP if still valid
    if (_cachedLocalIP != null && 
        _lastIPCheck != null && 
        DateTime.now().difference(_lastIPCheck!) < ipCacheTimeout) {
      return _cachedLocalIP!;
    }
    
    try {
      // Try to get WiFi IP first
      final info = NetworkInfo();
      String? wifiIP = await info.getWifiIP();
      
      if (wifiIP != null && wifiIP != '127.0.0.1' && wifiIP.isNotEmpty) {
        _cachedLocalIP = wifiIP;
        _lastIPCheck = DateTime.now();
        print('📡 Detected local IP: $wifiIP');
        return wifiIP;
      }
      
      // If WiFi IP fails, try connectivity check
      final connectivity = Connectivity();
      final connectivityResult = await connectivity.checkConnectivity();
      
      if (connectivityResult == ConnectivityResult.wifi) {
        // Try common IP ranges
        for (String ip in commonLocalIPs) {
          if (await _testConnection(ip, backendPort)) {
            _cachedLocalIP = ip;
            _lastIPCheck = DateTime.now();
            print('🔍 Found working IP: $ip');
            return ip;
          }
        }
      }
      
      // Fallback to first common IP if all else fails
      print('⚠️ Using fallback IP: ${commonLocalIPs.first}');
      return commonLocalIPs.first;
      
    } catch (e) {
      print('❌ IP Detection Error: $e');
      return commonLocalIPs.first; // Fallback
    }
  }
  
  // Test if a server is reachable
  static Future<bool> _testConnection(String ip, int port) async {
    try {
      final client = http.Client();
      final response = await client.get(
        Uri.parse('http://$ip:$port'),
        headers: {'Connection': 'close'},
      ).timeout(const Duration(seconds: 2));
      client.close();
      return response.statusCode == 200 || response.statusCode == 302;
    } catch (e) {
      return false;
    }
  }
  
  // Get base URL dynamically
  static Future<String> get baseUrl async {
    if (!useLocalServer) return productionBaseUrl;
    if (!autoDetectLocalIP) return 'http://${commonLocalIPs.first}:$backendPort/api';
    
    final ip = await getLocalIP();
    return 'http://$ip:$backendPort/api';
  }
  
  // Get scraper URL dynamically
  static Future<String> get scraperUrl async {
    if (!autoDetectLocalIP) return 'http://${commonLocalIPs.first}:$scraperPort';
    
    final ip = await getLocalIP();
    return 'http://$ip:$scraperPort';
  }
  
  // Fallback URLs
  static const String alternateScraperUrl = 'https://verify.tra.go.tz';
  static const bool useDirectScraping = false;
  
  // Get effective scraper URL
  static Future<String> get effectiveScraperUrl async {
    if (useDirectScraping) return alternateScraperUrl;
    return await scraperUrl;
  }
  
  // API endpoints (async versions for dynamic URLs)
  static Future<String> get receiptsUrl async => '${await baseUrl}/receipts';
  static Future<String> get addReceiptUrl async => '${await baseUrl}/add_receipt';
  static Future<String> get loginUrl async => '${await baseUrl}/login';
  
  // New API endpoints
  static Future<String> get salesUrl async => '${await baseUrl}/sales';
  static Future<String> get purchasesUrl async => '${await baseUrl}/purchases';
  static Future<String> get reportsUrl async => '${await baseUrl}/reports';
  
  // Utility methods
  static Future<void> refreshIP() async {
    _cachedLocalIP = null;
    _lastIPCheck = null;
    await getLocalIP();
  }
  
  static Future<Map<String, dynamic>> getConnectionStatus() async {
    final ip = await getLocalIP();
    final backendReachable = await _testConnection(ip, backendPort);
    final scraperReachable = await _testConnection(ip, scraperPort);
    
    return {
      'localIP': ip,
      'backendUrl': 'http://$ip:$backendPort',
      'scraperUrl': 'http://$ip:$scraperPort',
      'backendReachable': backendReachable,
      'scraperReachable': scraperReachable,
      'lastChecked': DateTime.now().toIso8601String(),
    };
  }
  
  // Connection timeouts
  static const int connectionTimeout = 15; // in seconds
}