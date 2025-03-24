import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_receipt_scanner/services/auth_service.dart';

enum AppConnectionState {
  online,
  offline,
  connecting,
}

class AppStateProvider extends ChangeNotifier {
  AppConnectionState _connectionState = AppConnectionState.connecting;
  bool _isLoggedIn = false;
  bool _isOfflineMode = false;
  String _userName = '';
  String _userEmail = '';
  
  final AuthService _authService = AuthService();
  final Connectivity _connectivity = Connectivity();
  
  AppStateProvider() {
    _initAppState();
    _setupConnectivityListener();
  }

  // Getters
  AppConnectionState get connectionState => _connectionState;
  bool get isLoggedIn => _isLoggedIn;
  bool get isOfflineMode => _isOfflineMode;
  String get userName => _userName;
  String get userEmail => _userEmail;
  bool get isConnecting => _connectionState == AppConnectionState.connecting;
  bool get isOnline => _connectionState == AppConnectionState.online;
  bool get isOffline => _connectionState == AppConnectionState.offline;

  // Initialize app state
  Future<void> _initAppState() async {
    try {
      // Check connectivity
      final connectivityResult = await _connectivity.checkConnectivity();
      _updateConnectionState(connectivityResult);
      
      // Check login status
      await _checkLoginStatus();
    } catch (e) {
      debugPrint('Error initializing app state: $e');
      _connectionState = AppConnectionState.offline;
      notifyListeners();
    }
  }

  // Setup connectivity listener
  void _setupConnectivityListener() {
    _connectivity.onConnectivityChanged.listen((ConnectivityResult result) {
      _updateConnectionState(result);
    });
  }

  // Update connection state based on connectivity result
  void _updateConnectionState(ConnectivityResult result) {
    final wasOffline = _connectionState == AppConnectionState.offline;
    
    if (result == ConnectivityResult.none) {
      _connectionState = AppConnectionState.offline;
    } else {
      _connectionState = AppConnectionState.online;
    }
    
    notifyListeners();
    
    // If we were offline and now we're online, try to sync data
    if (wasOffline && _connectionState == AppConnectionState.online) {
      _syncDataIfNeeded();
    }
  }

  // Check login status
  Future<void> _checkLoginStatus() async {
    final userInfo = await _authService.getUserInfo();
    
    _isLoggedIn = userInfo['isLoggedIn'] ?? false;
    _userName = userInfo['name'] ?? '';
    _userEmail = userInfo['email'] ?? '';
    _isOfflineMode = userInfo['isOfflineMode'] ?? false;
    
    notifyListeners();
  }

  // Login
  Future<bool> login(String email, String password) async {
    try {
      final response = await _authService.login(email, password);
      
      if (response.success) {
        await _checkLoginStatus();
        return true;
      } else {
        return false;
      }
    } catch (e) {
      debugPrint('Error logging in: $e');
      return false;
    }
  }

  // Offline login
  Future<bool> loginOffline(String email) async {
    try {
      final response = await _authService.loginOffline(email);
      
      if (response.success) {
        await _checkLoginStatus();
        return true;
      } else {
        return false;
      }
    } catch (e) {
      debugPrint('Error logging in offline: $e');
      return false;
    }
  }

  // Logout
  Future<bool> logout() async {
    try {
      final success = await _authService.logout();
      
      if (success) {
        _isLoggedIn = false;
        _userName = '';
        _userEmail = '';
        _isOfflineMode = false;
        notifyListeners();
      }
      
      return success;
    } catch (e) {
      debugPrint('Error logging out: $e');
      return false;
    }
  }

  // Sync data if needed
  Future<void> _syncDataIfNeeded() async {
    // This is a placeholder for data synchronization logic
    // We'll implement this in the actual SyncService
    debugPrint('Attempting to sync offline data');
  }

  @override
  void dispose() {
    super.dispose();
  }
}