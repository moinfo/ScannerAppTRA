import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_receipt_scanner/utils/api_request_status.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:math' show min;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => ReceiptProvider(),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Flutter Receipt Scanner',
        theme: ThemeData(
          primarySwatch: Colors.blue,
        ),
        home: const MyHomePage(),
        routes: {'scan': (context) => const ScanPage()},
      ),
    );
  }
}

class NoItems extends StatelessWidget {
  const NoItems({
    super.key,
    required this.errMsg,
  });

  final String errMsg;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(errMsg),
    );
  }
}

class ReceiptCard extends StatelessWidget {
  const ReceiptCard({
    super.key,
    required this.receipt,
    required this.index,
  });

  final Receipt receipt;
  final int index;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        child: Text('${index + 1}', style: const TextStyle(fontSize: 13)),
      ),
      title: Text(
        receipt.companyName,
        style: const TextStyle(fontSize: 13),
      ),
      subtitle: Text(
        '${receipt.date} ${receipt.time}',
        style: const TextStyle(fontSize: 12),
      ),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (BuildContext context) {
              return ReceiptDetailPage(receipt: receipt);
            },
          ),
        );
      },
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {

  @override
  initState() {
    super.initState();
    debugPrint('initState called');
    SchedulerBinding.instance.addPostFrameCallback((_) {
      debugPrint('Post frame callback triggered');
      Provider.of<ReceiptProvider>(context, listen: false).fetchReceipts();
    });
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Wajenzi Pro Scanner App'),
      ),
      body: Consumer<ReceiptProvider>(
        builder: (context, receipt, _) => buildBody(receipt),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () =>
            Navigator.pushNamed(context, ScanPage.route).then((value) async {
          await Provider.of<ReceiptProvider>(context, listen: false)
              .fetchReceipts();
        }),
        child: const Icon(Icons.qr_code_scanner_rounded),
      ),
    );
  }

  Widget buildBody(ReceiptProvider receiptProvider) {

    debugPrint('Current API status: ${receiptProvider.apiRequestStatus}');

    if (receiptProvider.apiRequestStatus == APIRequestStatus.error ||
        receiptProvider.apiRequestStatus == APIRequestStatus.networkError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Error: ${receiptProvider.lastError}'),
            ElevatedButton(
              onPressed: () => receiptProvider.fetchReceipts(),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    return BodyBuilder(
      apiRequestStatus: receiptProvider.apiRequestStatus,
      body: buildBodyList(receiptProvider),
      onRefresh: () async {
        debugPrint('Refresh triggered');
        await receiptProvider.fetchReceipts();
      },
    );
  }

  Widget buildBodyList(ReceiptProvider receiptProvider) {
    debugPrint('Receipts length: ${receiptProvider.receipts.length}');
    if (receiptProvider.receipts.isNotEmpty) {
      return ListView.builder(
        itemCount: receiptProvider.receipts.length,
        itemBuilder: (context, int index) {
          debugPrint('Building item at index: $index');
          return ReceiptCard(
            receipt: receiptProvider.receipts[index],
            index: index,
          );
        },
      );
    }

    debugPrint('No receipts found');
    return const NoItems(errMsg: 'No receipts found.');
  }
}

class ReceiptDetailPage extends StatelessWidget {
  ReceiptDetailPage({
    super.key,
    required this.receipt,
  });

  final Receipt receipt;
  final moneyFormat = NumberFormat.currency(name: '');
  final TextStyle receiptTextStyle = const TextStyle(
    fontSize: 12.0,
  );

  void _launchUrl(BuildContext context, String path) async {
    bool canLaunch = !await canLaunchUrl(Uri.parse('https://verify.tra.go.tz/$path'));

    if (canLaunch) {
      if (!context.mounted) return;

      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            content: SingleChildScrollView(
              child: SizedBox(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Failed to open browser',
                      style: TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text('Close'),
              ),
            ],
          );
        },
      );
    } else {
      launchUrl(Uri.parse('https://verify.tra.go.tz/$path'));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          receipt.companyName,
          style: TextStyle(
            fontSize: MediaQuery.of(context).size.width * 0.042666,
          ),
        ),
        actions: [
          if (receipt.verificationCode != null)
            IconButton(
              onPressed: () => _launchUrl(
                context,
                "${receipt.verificationCode}_${receipt.time?.replaceAll(':', '')}",
              ),
              icon: const Icon(Icons.language),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCompanyHeader(),
            const SizedBox(height: 20),
            _buildCustomerInfo(),
            const SizedBox(height: 20),
            _buildReceiptInfo(),
            const SizedBox(height: 20),
            _buildItemsTable(),
            if (receipt.adjustments?.isNotEmpty ?? false) ...[
              const SizedBox(height: 20),
              Text('Invoice Adjustments', style: receiptTextStyle),
              _buildAdjustmentsTable(),
            ],
            if (receipt.payments?.isNotEmpty ?? false) ...[
              const SizedBox(height: 20),
              Text('Invoice Payments', style: receiptTextStyle),
              _buildPaymentsTable(),
            ],
            const SizedBox(height: 20),
            _buildTotalsTable(),
          ],
        ),
      ),
    );
  }

  Widget _buildCompanyHeader() {
    return Center(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            receipt.companyName,
            textAlign: TextAlign.center,
            style: receiptTextStyle,
          ),
          const SizedBox(height: 5),
          Text(
            receipt.poBox ?? '',
            textAlign: TextAlign.center,
            style: receiptTextStyle,
          ),
          const SizedBox(height: 5),
          Text(
            'MOBILE: ${receipt.mobile}',
            textAlign: TextAlign.center,
            style: receiptTextStyle,
          ),
          const SizedBox(height: 5),
          Text(
            'TIN: ${receipt.tin}',
            textAlign: TextAlign.center,
            style: receiptTextStyle,
          ),
          const SizedBox(height: 5),
          Text(
            'VRN: ${receipt.vrn}',
            textAlign: TextAlign.center,
            style: receiptTextStyle,
          ),
          const SizedBox(height: 5),
          Text(
            'SERIAL NO: ${receipt.serialNumber}',
            textAlign: TextAlign.center,
            style: receiptTextStyle,
          ),
          const SizedBox(height: 5),
          Text(
            'UIN: ${receipt.uin}',
            textAlign: TextAlign.center,
            style: receiptTextStyle,
          ),
          const SizedBox(height: 5),
          Text(
            'TAX OFFICE: ${receipt.taxOffice}',
            textAlign: TextAlign.center,
            style: receiptTextStyle,
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'CUSTOMER NAME: ${receipt.customer?.name}',
          style: receiptTextStyle,
        ),
        const SizedBox(height: 5),
        Text(
          'CUSTOMER ID TYPE: ${receipt.customer?.idType}',
          style: receiptTextStyle,
        ),
        const SizedBox(height: 5),
        Text(
          'CUSTOMER ID: ${receipt.customer?.id}',
          style: receiptTextStyle,
        ),
        const SizedBox(height: 5),
        Text(
          'CUSTOMER MOBILE: ${receipt.customer?.mobile}',
          style: receiptTextStyle,
        ),
      ],
    );
  }

  Widget _buildReceiptInfo() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('RECEIPT NO:', style: receiptTextStyle),
            Text(receipt.number ?? '', style: receiptTextStyle),
          ],
        ),
        const SizedBox(height: 5),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Z NUMBER:', style: receiptTextStyle),
            Text(receipt.zNumber ?? '', style: receiptTextStyle),
          ],
        ),
        const SizedBox(height: 5),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Text('DATE: ', style: receiptTextStyle),
                Text(receipt.date ?? '', style: receiptTextStyle),
              ],
            ),
            Row(
              children: [
                Text('TIME: ', style: receiptTextStyle),
                Text(receipt.time ?? '', style: receiptTextStyle),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildItemsTable() {
    return Table(
      columnWidths: const {
        0: FlexColumnWidth(3),
        1: FlexColumnWidth(1),
        2: FlexColumnWidth(2),
      },
      children: [
        TableRow(
          children: [
            Text('DESCRIPTION', style: receiptTextStyle),
            Text(
              'QTY',
              style: receiptTextStyle,
              textAlign: TextAlign.right,
            ),
            Text(
              'AMOUNT',
              style: receiptTextStyle,
              textAlign: TextAlign.right,
            ),
          ],
        ),
        if (receipt.items != null && receipt.items!.isNotEmpty)
          ...receipt.items!.map((item) => TableRow(
            children: [
              Text(item.description ?? '', style: receiptTextStyle),
              Text(
                '${item.quantity}',
                style: receiptTextStyle,
                textAlign: TextAlign.right,
              ),
              Text(
                moneyFormat.format(item.amount),
                style: receiptTextStyle,
                textAlign: TextAlign.right,
              ),
            ],
          )).toList(),
      ],
    );
  }

  Widget _buildTotalsTable() {
    return Table(
      children: [
        _buildTableRow('TOTAL EXCL OF TAX:', receipt.totalExlcOfTax),
        if (receipt.kwhCharge != null)
          _buildTableRow('KWH Charge:', receipt.kwhCharge),
        if (receipt.kvaCharge != null)
          _buildTableRow('KVA Charge:', receipt.kvaCharge),
        if (receipt.serviceCharge != null)
          _buildTableRow('Service Charge:', receipt.serviceCharge),
        if (receipt.interestAmount != null)
          _buildTableRow('Interest Amount:', receipt.interestAmount),
        if (receipt.taxRate != null)
          _buildTableRow('TAX RATE (${receipt.taxRate}%):', receipt.totalTax),
        _buildTableRow('TOTAL TAX:', receipt.totalTax),
        if (receipt.reaCharge != null)
          _buildTableRow('REA:', receipt.reaCharge),
        if (receipt.ewuraCharge != null)
          _buildTableRow('EWURA:', receipt.ewuraCharge),
        if (receipt.propertyTax != null)
          _buildTableRow('Property Tax:', receipt.propertyTax),
        _buildTableRow('TOTAL INCL OF TAX:', receipt.totalInclOfTax),
      ],
    );
  }

  Widget _buildAdjustmentsTable() {
    return Table(
      columnWidths: const {
        0: FlexColumnWidth(1),
        1: FlexColumnWidth(2),
        2: FlexColumnWidth(1),
      },
      children: [
        TableRow(
          children: [
            Text('Type', style: receiptTextStyle),
            Text('Description', style: receiptTextStyle),
            Text(
              'Amount',
              style: receiptTextStyle,
              textAlign: TextAlign.right,
            ),
          ],
        ),
        ...receipt.adjustments!.map((adjustment) => TableRow(
          children: [
            Text(adjustment.type, style: receiptTextStyle),
            Text(adjustment.description, style: receiptTextStyle),
            Text(
              moneyFormat.format(adjustment.amount),
              style: receiptTextStyle,
              textAlign: TextAlign.right,
            ),
          ],
        )).toList(),
      ],
    );
  }

  Widget _buildPaymentsTable() {
    return Table(
      columnWidths: const {
        0: FlexColumnWidth(1),
        1: FlexColumnWidth(2),
        2: FlexColumnWidth(1),
      },
      children: [
        TableRow(
          children: [
            Text('Type', style: receiptTextStyle),
            Text('Description', style: receiptTextStyle),
            Text(
              'Amount',
              style: receiptTextStyle,
              textAlign: TextAlign.right,
            ),
          ],
        ),
        ...receipt.payments!.map((payment) => TableRow(
          children: [
            Text(payment.type, style: receiptTextStyle),
            Text(payment.description, style: receiptTextStyle),
            Text(
              moneyFormat.format(payment.amount),
              style: receiptTextStyle,
              textAlign: TextAlign.right,
            ),
          ],
        )).toList(),
      ],
    );
  }

  TableRow _buildTableRow(String label, double? value) {
    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 5),
          child: Text(label, style: receiptTextStyle),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 5),
          child: Text(
            value != null ? moneyFormat.format(value) : '-',
            style: receiptTextStyle,
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}

class ScanPage extends StatefulWidget {
  static String route = 'scan';

  const ScanPage({super.key});

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  MobileScannerController controller = MobileScannerController();
  bool frozen = false;

  bool receiptUrlFound = false;

  String errMsg = '';

  String _code = '';
  String _time = '';

  _handleReceiptScrapeFailed() async {
    setState(() {
      errMsg = '';
      receiptUrlFound = true;
    });

    await scrape(
      _code,
      _time,
      Provider.of<ReceiptProvider>(context, listen: false),
    );
  }

  _handleReceiptAlreadyExists() async {
    setState(() {
      errMsg = '';
      receiptUrlFound = false;
    });

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    var media = MediaQuery.of(context).size;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan'),
      ),
      body: SizedBox(
        height: media.height * 1,
        width: media.width * 1,
        child: Stack(
          children: [
            SizedBox(
              height: media.height * 1,
              width: media.width * 1,
              child: Column(
                children: [
                  Expanded(
                    flex: 5,
                    child: _buildQrView(context),
                  ),
                  Expanded(
                    flex: 1,
                    child: FittedBox(
                      fit: BoxFit.contain,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Container(
                                margin: const EdgeInsets.all(8),
                                child: IconButton(
                                  onPressed: () => controller.toggleTorch(),
                                  icon: ValueListenableBuilder(
                                    valueListenable: controller.torchState,
                                    builder: (context, state, child) {
                                      switch (state) {
                                        case TorchState.off:
                                          return const Icon(Icons.flash_off);
                                        case TorchState.on:
                                          return const Icon(Icons.flash_on);
                                      }
                                    },
                                  ),
                                ),
                              ),
                              Container(
                                margin: const EdgeInsets.all(8),
                                child: IconButton(
                                  onPressed: () => controller.switchCamera(),
                                  icon: ValueListenableBuilder(
                                    valueListenable:
                                        controller.cameraFacingState,
                                    builder: (context, state, child) {
                                      switch (state) {
                                        case CameraFacing.front:
                                          return const Icon(Icons.camera_front);
                                        case CameraFacing.back:
                                          return const Icon(Icons.camera_rear);
                                      }
                                    },
                                  ),
                                ),
                              ),
                            ],
                          )
                        ],
                      ),
                    ),
                  )
                ],
              ),
            ),
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
                          borderRadius:
                              BorderRadius.circular(media.width * 0.04),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('Please wait...'),
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
      ),
    );
  }

  Widget _buildQrView(BuildContext context) {
    return MobileScanner(
      key: qrKey,
      controller: controller,
      onDetect: (barcode, args) async {
        if (barcode.rawValue != null) {
          try {
            var url = barcode.rawValue!;

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
                errMsg = 'Receipt Incorrect';
              });
            }
          } catch (e) {
            setState(() {
              receiptUrlFound = false;
              errMsg = 'Receipt Incorrect';
            });
          }
        }
      },
    );
  }

  Future scrape(String code, String time, ReceiptProvider receiptProvider) async {
    setState(() {
      receiptUrlFound = true;
      _code = code;
      _time = time;
    });

    if (receiptProvider.checkIfReceiptExists(code)) {
      setState(() {
        receiptUrlFound = false;
        errMsg = 'Receipt already scanned!';
      });
      return;
    }

    try {
      print('Attempting to fetch receipt from: http://50.116.44.162:4000/receipt/$code/$time');

      http.Response response = await http.get(
        Uri.parse('http://50.116.44.162:4000/receipt/$code/$time'),
        headers: {
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 30));

      print('Response status code: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200 && response.body.isNotEmpty) {
        dynamic responseBody = jsonDecode(response.body);

        // Map the items to match the expected format
        if (responseBody['items'] != null) {
          responseBody['items'] = responseBody['items'].map((item) => {
            'item_description': item['description'],
            'item_qty': item['qty'],
            'item_amount': item['amount'],
          }).toList();
        }

        print('Attempting to upload to Wajenzi server...');

        http.Response serverResponse = await http.post(
          Uri.parse('https://wajenziprosystem.co.tz/api/add_receipt'),
          body: jsonEncode(responseBody),
          headers: {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
          },
        );

        print('Wajenzi server response status: ${serverResponse.statusCode}');
        print('Wajenzi server response body: ${serverResponse.body}');

        if (serverResponse.statusCode == 200) {
          setState(() {
            receiptUrlFound = false;
            _code = '';
            _time = '';
          });

          if (mounted) {
            Navigator.of(context).pop();
          }
        } else {
          setState(() {
            receiptUrlFound = false;
            errMsg = 'Failed to upload data to wajenzi servers: ${serverResponse.statusCode} - ${serverResponse.body}';
          });
        }
      } else {
        setState(() {
          receiptUrlFound = false;
          errMsg = 'TRA scrape failed: Status ${response.statusCode} - ${response.body}';
        });
      }
    } catch (e, stackTrace) {
      print('Error during scraping: $e');
      print('Stack trace: $stackTrace');

      setState(() {
        receiptUrlFound = false;
        errMsg = 'TRA scrape failed: ${e.toString()}';
      });
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }
}

List<Receipt> getReceiptsFromJson(List<dynamic> receipts) => List.generate(
    receipts.length, (index) => Receipt.fromJson(receipts[index]));

class Receipt {
  int id;
  String companyName;
  String? poBox;
  String? mobile;
  String? tin;
  String? vrn;
  String? serialNumber;
  String? uin;
  String? taxOffice;
  String? date;
  String? time;
  String? number;
  String? zNumber;
  String? verificationCode;
  double? totalExlcOfTax;
  double? totalDiscount;
  double? totalTax;
  double? totalInclOfTax;

  // New fields for TANESCO receipts
  double? kwhCharge;
  double? kvaCharge;
  double? serviceCharge;
  double? interestAmount;
  double? reaCharge;
  double? ewuraCharge;
  double? propertyTax;
  double? taxRate;
  List<InvoiceAdjustment>? adjustments;
  List<InvoicePayment>? payments;

  Customer? customer;
  List<Item>? items;

  Receipt({
    required this.id,
    required this.companyName,
    this.poBox,
    this.mobile,
    this.tin,
    this.vrn,
    this.serialNumber,
    this.uin,
    this.taxOffice,
    this.date,
    this.time,
    this.number,
    this.zNumber,
    this.verificationCode,
    this.totalExlcOfTax,
    this.totalDiscount,
    this.totalTax,
    this.totalInclOfTax,
    this.kwhCharge,
    this.kvaCharge,
    this.serviceCharge,
    this.interestAmount,
    this.reaCharge,
    this.ewuraCharge,
    this.propertyTax,
    this.taxRate,
    this.adjustments,
    this.payments,
    this.customer,
    this.items,
  });

  factory Receipt.fromJson(Map<String, dynamic> json) {
    Customer customer = Customer.fromJson({
      'customer_name': json['customer_name'],
      'customer_id_type': json['customer_id_type'],
      'customer_id': json['customer_id'],
      'customer_mobile': json['customer_mobile'],
    });

    List<Item> items = [];
    if (json['items'] != null && json['items'].isNotEmpty) {
      items = List.generate(
        json['items'].length,
            (index) => Item.fromJson(json['items'][index]),
      );
    }

    List<InvoiceAdjustment>? adjustments;
    if (json['adjustments'] != null) {
      adjustments = List.generate(
        json['adjustments'].length,
            (index) => InvoiceAdjustment.fromJson(json['adjustments'][index]),
      );
    }

    List<InvoicePayment>? payments;
    if (json['payments'] != null) {
      payments = List.generate(
        json['payments'].length,
            (index) => InvoicePayment.fromJson(json['payments'][index]),
      );
    }

    return Receipt(
      id: json['id'],
      companyName: json['company_name'],
      poBox: json['p_o_box'],
      mobile: json['mobile'],
      tin: json['tin'],
      vrn: json['vrn'],
      serialNumber: json['serial_no'],
      uin: json['uin'],
      taxOffice: json['tax_office'],
      date: json['receipt_date'],
      time: json['receipt_time'],
      number: json['receipt_number'],
      zNumber: json['receipt_z_number'],
      verificationCode: json['receipt_verification_code'],
      totalExlcOfTax: json['receipt_total_excl_of_tax'] != null
          ? double.parse(json['receipt_total_excl_of_tax'])
          : null,
      totalDiscount: json['receipt_total_discount'] != null
          ? double.parse(json['receipt_total_discount'])
          : null,
      totalTax: json['receipt_total_tax'] != null
          ? double.parse(json['receipt_total_tax'])
          : null,
      totalInclOfTax: json['receipt_total_incl_of_tax'] != null
          ? double.parse(json['receipt_total_incl_of_tax'])
          : null,
      kwhCharge: json['kwh_charge'] != null
          ? double.parse(json['kwh_charge'])
          : null,
      kvaCharge: json['kva_charge'] != null
          ? double.parse(json['kva_charge'])
          : null,
      serviceCharge: json['service_charge'] != null
          ? double.parse(json['service_charge'])
          : null,
      interestAmount: json['interest_amount'] != null
          ? double.parse(json['interest_amount'])
          : null,
      reaCharge: json['rea_charge'] != null
          ? double.parse(json['rea_charge'])
          : null,
      ewuraCharge: json['ewura_charge'] != null
          ? double.parse(json['ewura_charge'])
          : null,
      propertyTax: json['property_tax'] != null
          ? double.parse(json['property_tax'])
          : null,
      taxRate: json['tax_rate'] != null
          ? double.parse(json['tax_rate'])
          : null,
      adjustments: adjustments,
      payments: payments,
      customer: customer,
      items: items,
    );
  }
}

class InvoiceAdjustment {
  String type;
  String description;
  double amount;

  InvoiceAdjustment({
    required this.type,
    required this.description,
    required this.amount,
  });

  factory InvoiceAdjustment.fromJson(Map<String, dynamic> json) {
    return InvoiceAdjustment(
      type: json['type'],
      description: json['description'],
      amount: double.parse(json['amount']),
    );
  }
}

class InvoicePayment {
  String type;
  String description;
  double amount;

  InvoicePayment({
    required this.type,
    required this.description,
    required this.amount,
  });

  factory InvoicePayment.fromJson(Map<String, dynamic> json) {
    return InvoicePayment(
      type: json['type'],
      description: json['description'],
      amount: double.parse(json['amount']),
    );
  }
}

class Customer {
  String? name;
  String? idType;
  String? id;
  String? mobile;

  Customer({
    this.name,
    this.idType,
    this.id,
    this.mobile,
  });

  factory Customer.fromJson(Map<String, dynamic> json) {
    return Customer(
      name: json['customer_name'],
      idType: json['customer_id_type'],
      id: json['customer_id'],
      mobile: json['customer_mobile'],
    );
  }
}

class Item {
  String? description;
  int? quantity;
  double? amount;

  Item({
    this.description,
    this.quantity,
    this.amount,
  });

  factory Item.fromJson(Map<String, dynamic> json) {
    return Item(
      description: json['description'],
      quantity: json['qty'],
      amount: double.parse(json['amount']),
    );
  }
}

class ReceiptProvider extends ChangeNotifier {
  List<Receipt> _receipts = [];
  APIRequestStatus _apiRequestStatus = APIRequestStatus.loading;
  String _lastError = ''; // Add error message storage

  List<Receipt> get receipts => _receipts;
  APIRequestStatus get apiRequestStatus => _apiRequestStatus;
  String get lastError => _lastError;

  ReceiptProvider() {
    debugPrint('ReceiptProvider initialized');
    fetchReceipts();
  }

  Future<void> fetchReceipts() async {
    debugPrint('Starting fetchReceipts()');
    _apiRequestStatus = APIRequestStatus.loading;
    notifyListeners();

    try {
      debugPrint('Attempting API call to: https://wajenziprosystem.co.tz/api/receipts');
      final response = await http.get(
        Uri.parse('https://wajenziprosystem.co.tz/api/receipts'),
        headers: {
          'Accept': 'application/json',
        },
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          debugPrint('API call timed out after 30 seconds');
          throw TimeoutException('Request timed out');
        },
      );

      debugPrint('API Response Status Code: ${response.statusCode}');
      debugPrint('API Response Headers: ${response.headers}');

      if (response.statusCode == 200) {
        debugPrint('Response body length: ${response.body.length}');
        debugPrint('First 100 characters of response: ${response.body.substring(0, min(100, response.body.length))}');

        // Fix: Parse the nested structure correctly
        Map<String, dynamic> jsonResponse = jsonDecode(response.body);
        List<dynamic> responseBody = jsonResponse['receipts']['data'] as List<dynamic>;
        debugPrint('Successfully decoded JSON. Number of items: ${responseBody.length}');

        List<Receipt> nwReceipts = getReceiptsFromJson(responseBody);
        debugPrint('Successfully parsed ${nwReceipts.length} receipts');

        _receipts = nwReceipts;
        _apiRequestStatus = APIRequestStatus.loaded;
        _lastError = '';
        notifyListeners();
        debugPrint('Successfully updated state with new receipts');
      } else {
        _lastError = 'Server returned ${response.statusCode}: ${response.body}';
        debugPrint('API Error: $_lastError');
        _apiRequestStatus = APIRequestStatus.error;
        notifyListeners();
      }
    } on SocketException catch (e) {
      _lastError = 'Network error: ${e.message}';
      debugPrint('SocketException: $_lastError');
      _apiRequestStatus = APIRequestStatus.networkError;
      notifyListeners();
    } on TimeoutException catch (e) {
      _lastError = 'Request timed out: ${e.message}';
      debugPrint('TimeoutException: $_lastError');
      _apiRequestStatus = APIRequestStatus.networkError;
      notifyListeners();
    } on FormatException catch (e) {
      _lastError = 'Data format error: ${e.message}';
      debugPrint('FormatException: $_lastError');
      debugPrint('Response that caused error: ${e.source}');
      _apiRequestStatus = APIRequestStatus.error;
      notifyListeners();
    } catch (e, stackTrace) {
      _lastError = 'Unexpected error: $e';
      debugPrint('Unexpected error: $e');
      debugPrint('Stack trace: $stackTrace');
      _apiRequestStatus = APIRequestStatus.error;
      notifyListeners();
    }
  }

  bool checkIfReceiptExists(String code) {
    debugPrint('Checking for receipt with code: $code');
    var receipts = _receipts.where((receipt) => receipt.verificationCode == code);
    bool exists = receipts.isNotEmpty;
    debugPrint('Receipt exists: $exists');
    return exists;
  }

  // Helper method to safely parse response
  List<Receipt> getReceiptsFromJson(List<dynamic> json) {
    debugPrint('Starting to parse ${json.length} receipts');
    List<Receipt> parsedReceipts = [];

    for (var i = 0; i < json.length; i++) {
      try {
        var receipt = Receipt.fromJson(json[i]);
        parsedReceipts.add(receipt);
      } catch (e) {
        debugPrint('Error parsing receipt at index $i: $e');
        debugPrint('Problematic JSON: ${json[i]}');
      }
    }

    debugPrint('Successfully parsed ${parsedReceipts.length} out of ${json.length} receipts');
    return parsedReceipts;
  }
}

class BodyBuilder extends StatelessWidget {
  const BodyBuilder({
    Key? key,
    required this.apiRequestStatus,
    required this.body,
    required this.onRefresh,
  }) : super(key: key);

  final APIRequestStatus apiRequestStatus;
  final Widget body;
  final Function onRefresh;

  @override
  Widget build(BuildContext context) {
    Widget child;

    switch (apiRequestStatus) {
      case APIRequestStatus.loading:
        child = const Center(
          child: CircularProgressIndicator(),
        );
        break;
      case APIRequestStatus.loaded:
        child = RefreshIndicator(
          onRefresh: () => onRefresh(),
          child: body,
        );
        break;
      case APIRequestStatus.error:
      case APIRequestStatus.networkError:
        child = ErrorWidget(
          apiRequestStatus: apiRequestStatus,
          onRefresh: onRefresh,
        );
        break;
    }

    return child;
  }
}

class ErrorWidget extends StatelessWidget {
  const ErrorWidget({
    Key? key,
    required this.apiRequestStatus,
    required this.onRefresh,
  }) : super(key: key);

  final APIRequestStatus apiRequestStatus;
  final Function onRefresh;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            getMessage(apiRequestStatus),
            style: Theme.of(context).textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          ElevatedButton(
            onPressed: () => onRefresh(),
            child: const Text('Try again'),
          ),
        ],
      ),
    );
  }

  String getMessage(APIRequestStatus apiRequestStatus) {
    String message = '';

    if (apiRequestStatus == APIRequestStatus.error) {
      message = 'This page cannot be loaded right now\n Try again.';
    } else if (apiRequestStatus == APIRequestStatus.networkError) {
      message = 'Check your internet connection.';
    }

    return message;
  }
}
