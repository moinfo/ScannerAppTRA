import 'package:flutter/material.dart';
import 'package:flutter_receipt_scanner/config/api_config.dart';
import 'package:flutter_receipt_scanner/providers/receipt_provider.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ScanScreen extends StatefulWidget {
  const ScanScreen({Key? key}) : super(key: key);

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final MobileScannerController controller = MobileScannerController();
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  bool receiptUrlFound = false;
  String errMsg = '';
  String _code = '';
  String _time = '';

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void _handleReceiptAlreadyExists() {
    setState(() {
      receiptUrlFound = false;
      errMsg = '';
    });
  }

  void _handleReceiptScrapeFailed() {
    setState(() {
      receiptUrlFound = false;
      errMsg = '';
    });
  }

  bool validateRequiredFields(dynamic responseBody) {
    final requiredFields = [
      'companyName',
      'date',
      'time',
      'items',
    ];

    for (var field in requiredFields) {
      if (responseBody[field] == null) {
        return false;
      }
    }

    return true;
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context).size;
    
    return Stack(
        children: [
          // QR scanner
          _buildQrView(context),
          
          // Camera controls positioned at top right
          Positioned(
            top: 20,
            right: 20,
            child: Column(
              children: [
                // Torch control
                Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(50),
                  ),
                  child: IconButton(
                    icon: ValueListenableBuilder(
                      valueListenable: controller.torchState,
                      builder: (context, state, child) {
                        switch (state as TorchState) {
                          case TorchState.off:
                            return const Icon(Icons.flash_off, color: Colors.white);
                          case TorchState.on:
                            return const Icon(Icons.flash_on, color: Colors.yellow);
                        }
                      },
                    ),
                    onPressed: () => controller.toggleTorch(),
                  ),
                ),
                const SizedBox(height: 12),
                // Camera switch control
                Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(50),
                  ),
                  child: IconButton(
                    icon: ValueListenableBuilder(
                      valueListenable: controller.cameraFacingState,
                      builder: (context, state, child) {
                        switch (state as CameraFacing) {
                          case CameraFacing.front:
                            return const Icon(Icons.camera_front, color: Colors.white);
                          case CameraFacing.back:
                            return const Icon(Icons.camera_rear, color: Colors.white);
                        }
                      },
                    ),
                    onPressed: () => controller.switchCamera(),
                  ),
                ),
              ],
            ),
          ),

          // Overlay instructions with enhanced styling
          Positioned(
            top: 20,
            left: 20,
            right: 100, // Leave space for camera controls
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.black.withOpacity(0.8),
                    Colors.black.withOpacity(0.6),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.qr_code_scanner,
                        color: Colors.blue.shade300,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'QR Code Scanner',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Position the TRA receipt QR code within the frame',
                    style: TextStyle(
                      color: Colors.white70, 
                      fontSize: 13,
                      height: 1.3,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
          
          // Enhanced frame indicator with corners
          Center(
            child: SizedBox(
              width: 280,
              height: 280,
              child: Stack(
                children: [
                  // Corner indicators (top-left)
                  Positioned(
                    top: 0,
                    left: 0,
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        border: const Border(
                          top: BorderSide(color: Colors.white, width: 4),
                          left: BorderSide(color: Colors.white, width: 4),
                        ),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(12),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 4,
                            offset: const Offset(1, 1),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Corner indicators (top-right)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        border: const Border(
                          top: BorderSide(color: Colors.white, width: 4),
                          right: BorderSide(color: Colors.white, width: 4),
                        ),
                        borderRadius: const BorderRadius.only(
                          topRight: Radius.circular(12),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 4,
                            offset: const Offset(-1, 1),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Corner indicators (bottom-left)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        border: const Border(
                          bottom: BorderSide(color: Colors.white, width: 4),
                          left: BorderSide(color: Colors.white, width: 4),
                        ),
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(12),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 4,
                            offset: const Offset(1, -1),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Corner indicators (bottom-right)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        border: const Border(
                          bottom: BorderSide(color: Colors.white, width: 4),
                          right: BorderSide(color: Colors.white, width: 4),
                        ),
                        borderRadius: const BorderRadius.only(
                          bottomRight: Radius.circular(12),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 4,
                            offset: const Offset(-1, -1),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Loading and error overlays
          receiptUrlFound
            ? Container(
              height: media.height * 1,
              width: media.width * 1,
              decoration: const BoxDecoration(
                color: Color.fromARGB(125, 0, 0, 0),
              ),
              child: Center(
                child: Container(
                  padding: EdgeInsets.all(media.width * 0.05),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(media.width * 0.04),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Processing receipt...'),
                      SizedBox(height: media.width * 0.05),
                      const CircularProgressIndicator(),
                    ],
                  ),
                ),
              ),
            )
            : const SizedBox(),
          errMsg.isNotEmpty
            ? Container(
              height: media.height * 1,
              width: media.width * 1,
              decoration: const BoxDecoration(
                color: Color.fromARGB(125, 0, 0, 0),
              ),
              child: Center(
                child: Container(
                  padding: EdgeInsets.all(media.width * 0.05),
                  width: media.width * 0.8,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(
                      media.width * 0.03,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(errMsg),
                      SizedBox(height: media.width * 0.05),
                      ElevatedButton(
                        onPressed: errMsg == 'Receipt already scanned!'
                            ? _handleReceiptAlreadyExists
                            : _handleReceiptScrapeFailed,
                        child: Text(errMsg == 'Receipt already scanned!'
                            ? 'Close'
                            : 'Try Again'),
                      ),
                    ],
                  ),
                ),
              ),
            )
            : const SizedBox(),
        ],
      );
  }

  Widget _buildQrView(BuildContext context) {
    return MobileScanner(
      key: qrKey,
      controller: controller,
      onDetect: (capture) async {
        if (capture.barcodes.isNotEmpty && capture.barcodes.first.rawValue != null) {
          try {
            var url = capture.barcodes.first.rawValue!;

            final splittted = url.split('/');
            final last = splittted.last;
            final lastSplitted = last.split('_');

            if (lastSplitted.length == 2) {
              await scrape(
                lastSplitted.first,
                lastSplitted.last,
                Provider.of<ReceiptProvider>(context, listen: false),
              );
            } else {
              setState(() {
                receiptUrlFound = false;
                errMsg = 'Invalid Receipt Format';
              });
            }
          } catch (e) {
            setState(() {
              receiptUrlFound = false;
              errMsg = 'Invalid Receipt Format';
            });
          }
        }
      },
    );
  }

  Future<void> scrape(String code, String time, ReceiptProvider receiptProvider) async {
    int retries = 3;

    // Check if receipt already exists
    if (receiptProvider.checkIfReceiptExists(code)) {
      setState(() {
        receiptUrlFound = false;
        errMsg = 'Receipt already scanned!';
      });
      return;
    }

    for (int i = 0; i < retries; i++) {
      try {
        setState(() {
          receiptUrlFound = true;
          _code = code;
          _time = time;
          errMsg = '';
        });

        debugPrint('Attempt ${i + 1} of $retries');
        debugPrint('Scraping receipt: code=$code, time=$time');

        // First request to scraping server
        http.Response response = await http.get(
          Uri.parse('${await ApiConfig.scraperUrl}/receipt/$code/$time'),
          headers: {
            'Accept': 'application/json',
          },
        ).timeout(const Duration(seconds: 30));

        debugPrint('Response status: ${response.statusCode}');
        debugPrint('Response body: ${response.body}');

        if (response.statusCode == 200 && response.body.isNotEmpty) {
          dynamic responseBody = jsonDecode(response.body);

          // Validate required fields
          if (!validateRequiredFields(responseBody)) {
            debugPrint('Missing required fields, retrying...');
            if (i == retries - 1) {
              setState(() {
                receiptUrlFound = false;
                errMsg = 'Failed to get complete receipt data';
              });
              return;
            }
            continue;
          }

          debugPrint('Attempting to upload to Lemuru server...');

          // Second request to Lemuru server
          http.Response serverResponse = await http.post(
            Uri.parse(await ApiConfig.addReceiptUrl),
            body: jsonEncode(responseBody),
            headers: {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
          ).timeout(const Duration(seconds: 30));

          debugPrint('Lemuru server response status: ${serverResponse.statusCode}');
          debugPrint('Lemuru server response body: ${serverResponse.body}');

          if (serverResponse.statusCode == 200) {
            setState(() {
              receiptUrlFound = false;
              _code = '';
              _time = '';
              errMsg = '';
            });

            // Show success message
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Receipt processed successfully!'),
                backgroundColor: Colors.green,
              ),
            );
            
            // Refresh data
            await receiptProvider.fetchReceipts();
            return;
          } else {
            throw Exception('Failed to upload data to Lemuru servers: ${serverResponse.statusCode} - ${serverResponse.body}');
          }
        } else {
          throw Exception('TRA scrape failed: Status ${response.statusCode} - ${response.body}');
        }
      } catch (e) {
        debugPrint('Error during scanning: $e');
        if (i == retries - 1) {
          setState(() {
            receiptUrlFound = false;
            errMsg = 'Error processing receipt. Please try again.';
          });
          return;
        }
      }
    }
  }
}