import 'package:flutter/material.dart';
import 'package:flutter_receipt_scanner/main.dart';
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
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Receipt'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: ValueListenableBuilder(
              valueListenable: controller.torchState,
              builder: (context, state, child) {
                switch (state as TorchState) {
                  case TorchState.off:
                    return const Icon(Icons.flash_off, color: Colors.grey);
                  case TorchState.on:
                    return const Icon(Icons.flash_on, color: Colors.yellow);
                }
              },
            ),
            onPressed: () => controller.toggleTorch(),
          ),
          IconButton(
            icon: ValueListenableBuilder(
              valueListenable: controller.cameraFacingState,
              builder: (context, state, child) {
                switch (state as CameraFacing) {
                  case CameraFacing.front:
                    return const Icon(Icons.camera_front);
                  case CameraFacing.back:
                    return const Icon(Icons.camera_rear);
                }
              },
            ),
            onPressed: () => controller.switchCamera(),
          ),
        ],
      ),
      body: Stack(
        children: [
          // QR scanner
          _buildQrView(context),
          
          // Overlay instructions
          Positioned(
            top: 20,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              margin: const EdgeInsets.symmetric(horizontal: 24),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Column(
                children: [
                  Text(
                    'Scan TRA Receipt QR Code',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Position the QR code within the frame to scan',
                    style: TextStyle(color: Colors.white70),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
          
          // Frame indicator
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(
                  color: Colors.white,
                  width: 2.0,
                ),
                borderRadius: BorderRadius.circular(12),
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
      ),
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