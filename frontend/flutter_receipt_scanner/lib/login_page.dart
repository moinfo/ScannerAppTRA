import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_receipt_scanner/main.dart';

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
    final prefs = await SharedPreferences.getInstance();
    
    // Store dummy authentication data
    await prefs.setString('token', 'offline_token_${DateTime.now().millisecondsSinceEpoch}');
    await prefs.setString('user', jsonEncode({
      'name': _emailController.text.isEmpty ? 'Offline User' : _emailController.text.split('@')[0],
      'email': _emailController.text.isEmpty ? 'offline@example.com' : _emailController.text,
    }));
    await prefs.setBool('isLoggedIn', true);
    
    // Store some dummy receipt data for offline testing
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
          builder: (context) => const MyHomePage(),
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
      // Print debug information
      debugPrint('Attempting login with URL: $loginUrl');
      debugPrint('Email: ${_emailController.text.trim()}');
      
      final response = await http.post(
        Uri.parse(loginUrl),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'email': _emailController.text.trim(),
          'password': _passwordController.text,
        }),
      ).timeout(const Duration(seconds: 15));

      debugPrint('Login response status: ${response.statusCode}');
      debugPrint('Login response body: ${response.body}');
      
      if (response.statusCode == 200) {
        try {
          final data = jsonDecode(response.body);
          
          if (data['token'] == null) {
            throw Exception('Token not found in response');
          }
          
          // Save token and user info to SharedPreferences
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('token', data['token']);
          await prefs.setString('user', jsonEncode(data['user'] ?? {'name': 'User', 'email': _emailController.text.trim()}));
          await prefs.setBool('isLoggedIn', true);
          
          if (!mounted) return;

          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Login successful! Welcome ${data['user']['name'] ?? 'User'}'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
          
          // Navigate to main app and remove login page from stack
          // Delayed to allow the user to see the success message
          Future.delayed(const Duration(seconds: 1), () {
            if (!mounted) return;
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) => const MyHomePage(),
              ),
            );
          });
        } catch (jsonError) {
          debugPrint('Error parsing response: $jsonError');
          setState(() {
            _errorMessage = 'Invalid server response. Please try again.';
          });
        }
      } else if (response.statusCode == 404) {
        // Handle 404 Not Found - Backend server issue
        setState(() {
          _errorMessage = 'Server Error: The login endpoint is not available (404). Please use the "Enter App" button below to access the app.';
        });
      } else {
        // Handle other errors
        try {
          final error = jsonDecode(response.body);
          setState(() {
            _errorMessage = error['message'] ?? 'Login failed with status ${response.statusCode}';
          });
        } catch (jsonError) {
          setState(() {
            _errorMessage = 'Login failed with status ${response.statusCode}';
          });
        }
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
                    
                    // Offline mode button
                    TextButton(
                      onPressed: _isLoading ? null : _bypassLogin,
                      child: const Text('Enter App (Offline Mode)'),
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