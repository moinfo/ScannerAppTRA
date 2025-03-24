import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_receipt_scanner/dashboard.dart';
import 'package:flutter_receipt_scanner/main.dart';
import 'package:flutter_receipt_scanner/providers/app_state_provider.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({Key? key}) : super(key: key);

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String _errorMessage = '';
  bool _shouldBypassLogin = false;

  // Use ApiConfig for URL management
  final String loginUrl = '${ApiConfig.baseUrl}/login';

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // Helper method to bypass login for testing in case the server is down
  Future<void> _bypassLogin() async {
    debugPrint('Bypassing login for offline mode');
    
    // Get app state provider
    final appStateProvider = Provider.of<AppStateProvider>(context, listen: false);
    
    // Perform offline login
    final success = await appStateProvider.loginOffline(
      _emailController.text.isEmpty ? 'offline@example.com' : _emailController.text
    );
    
    if (!success) {
      setState(() {
        _errorMessage = 'Failed to enter offline mode. Please try again.';
      });
      return;
    }
    
    if (!mounted) return;
    
    // Show offline mode message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Entering app in OFFLINE MODE as ${_emailController.text.isEmpty ? "Guest User" : _emailController.text}'),
        backgroundColor: Colors.orange,
        duration: const Duration(seconds: 2),
      ),
    );
    
    // Navigate with a delay to allow the message to be seen
    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => const Dashboard(),
        ),
      );
    });
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    
    // If bypass flag is set, skip normal login and use the test login
    if (_shouldBypassLogin) {
      await _bypassLogin();
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      // Get app state provider
      final appStateProvider = Provider.of<AppStateProvider>(context, listen: false);
      final success = await appStateProvider.login(
        _emailController.text.trim(),
        _passwordController.text,
      );
      
      if (success) {
        if (!mounted) return;

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Login successful! Welcome ${appStateProvider.userName}'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
        
        // Navigate to dashboard and remove login page from stack
        // Delayed to allow the user to see the success message
        Future.delayed(const Duration(seconds: 1), () {
          if (!mounted) return;
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => const Dashboard(),
            ),
          );
        });
      } else {
        setState(() {
          _errorMessage = appStateProvider.connectionState == AppConnectionState.offline 
              ? 'Network error: No internet connection. Please use offline mode.' 
              : 'Login failed. Please check your credentials.';
        });
      }
    } catch (e) {
      debugPrint('Login exception: $e');
      
      // If we're in local development mode and there's a network error,
      // it might be because the backend server is not running.
      // In this case, we can offer to bypass login for testing
      if (ApiConfig.useLocalServer && (e.toString().contains('SocketException') || 
          e.toString().contains('Connection refused') || 
          e.toString().contains('Network is unreachable'))) {
        
        setState(() {
          _errorMessage = 'Network error: $e\n\nBypass login for testing? (Tap "Login" again)';
          _isLoading = false;
        });
        
        // Add a flag to bypass login next time
        _shouldBypassLogin = true;
        return;
      }
      
      setState(() {
        _errorMessage = 'Network error: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Center(
            child: SingleChildScrollView(
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Logo
                    Padding(
                      padding: const EdgeInsets.only(bottom: 40.0),
                      child: Image.asset(
                        'assets/icon/lemurulogo.png',
                        height: 120,
                      ),
                    ),
                    
                    // Server status message
                    Container(
                      padding: const EdgeInsets.all(10),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: const Text(
                        'Backend server is currently unavailable. Please use the "Enter App" button below to access the app in offline mode.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.deepOrange),
                      ),
                    ),
                    
                    // Title
                    const Text(
                      'Lemuru Receipt Scanner',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Please login to continue',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 30),
                    
                    // Error message
                    if (_errorMessage.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.all(10),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Text(
                          _errorMessage,
                          style: TextStyle(color: Colors.red.shade800),
                        ),
                      ),
                    
                    // Email field
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: 'Email',
                        hintText: 'Enter your email',
                        prefixIcon: const Icon(Icons.email),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your email';
                        }
                        if (!value.contains('@')) {
                          return 'Please enter a valid email';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    
                    // Password field
                    TextFormField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        hintText: 'Enter your password',
                        prefixIcon: const Icon(Icons.lock),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your password';
                        }
                        if (value.length < 6) {
                          return 'Password must be at least 6 characters';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    
                    // Login button
                    ElevatedButton(
                      onPressed: _isLoading ? null : _login,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Text(
                              'Login',
                              style: TextStyle(fontSize: 16),
                            ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Test login bypass button (always visible now due to server issues)
                    TextButton(
                      onPressed: _isLoading ? null : _bypassLogin,
                      child: const Text('Enter App (Server Unavailable)'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}