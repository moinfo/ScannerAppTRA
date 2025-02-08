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
    SchedulerBinding.instance.addPostFrameCallback((_) {
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
    return BodyBuilder(
      apiRequestStatus: receiptProvider.apiRequestStatus,
      body: buildBodyList(receiptProvider),
      onRefresh: () async {
        await receiptProvider.fetchReceipts();
      },
    );
  }

  Widget buildBodyList(ReceiptProvider receiptProvider) {
    if (receiptProvider.receipts.isNotEmpty) {
      return ListView.builder(
        itemCount: receiptProvider.receipts.length,
        itemBuilder: (context, int index) => ReceiptCard(
          receipt: receiptProvider.receipts[index],
          index: index,
        ),
      );
    }

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

  void _launchUrl(BuildContext context, String path) async {
    bool canLaunch =
        !await canLaunchUrl(Uri.parse('https://verify.tra.go.tz/$path'));

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

  final TextStyle receiptTextStyle = const TextStyle(
    fontSize: 12.0,
    // fontFamily: 'Merchant',
  );
  @override
  Widget build(BuildContext context) {
    var media = MediaQuery.of(context).size;
    return Scaffold(
      // backgroundColor: const Color.fromARGB(255, 96, 140, 147),
      appBar: AppBar(
        title: Text(
          receipt.companyName,
          style: TextStyle(
            fontSize: media.width * 0.042666,
          ),
        ),
        actions: [
          receipt.verificationCode != null
              ? IconButton(
                  onPressed: () async {
                    if (receipt.time != null) {
                      String path =
                          "${receipt.verificationCode}_${receipt.time!.replaceAll(':', '')}";
                      _launchUrl(context, path);
                    }
                  },
                  icon: const Icon(Icons.language),
                )
              : const SizedBox(),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
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
            ),
            const SizedBox(height: 20),
            Text(
              'CUSTOMER NAME: ${receipt.customer?.name}',
              textAlign: TextAlign.start,
              style: receiptTextStyle,
            ),
            const SizedBox(height: 5),
            Text(
              'CUSTOMER ID TYPE: ${receipt.customer?.idType}',
              textAlign: TextAlign.start,
              style: receiptTextStyle,
            ),
            const SizedBox(height: 5),
            Text(
              'CUSTOMER ID: ${receipt.customer?.id}',
              textAlign: TextAlign.start,
              style: receiptTextStyle,
            ),
            const SizedBox(height: 5),
            Text(
              'CUSTOMER MOBILE: ${receipt.customer?.mobile}',
              textAlign: TextAlign.start,
              style: receiptTextStyle,
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'RECEIPT NO:',
                  style: receiptTextStyle,
                ),
                Text(
                  receipt.number ?? '',
                  style: receiptTextStyle,
                ),
              ],
            ),
            const SizedBox(height: 5),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Z NUMBER: ',
                  style: receiptTextStyle,
                ),
                Text(
                  receipt.zNumber ?? '',
                  style: receiptTextStyle,
                ),
              ],
            ),
            const SizedBox(height: 5),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'DATE: ',
                      style: receiptTextStyle,
                    ),
                    Text(
                      receipt.date ?? '',
                      style: receiptTextStyle,
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'TIME: ',
                      style: receiptTextStyle,
                    ),
                    Text(
                      receipt.time ?? '',
                      style: receiptTextStyle,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),
            const SizedBox(height: 10),
            Table(
              columnWidths: const {
                0: FlexColumnWidth(3),
                1: FlexColumnWidth(1),
                2: FlexColumnWidth(2),
              },
              children: [
                TableRow(
                  children: [
                    Text(
                      'DESCRIPTION',
                      style: receiptTextStyle,
                    ),
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
                  ...buildItemsRows(receipt.items)
              ],
            ),
            const SizedBox(height: 20),
            Table(
              children: [
                TableRow(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 5),
                      child:
                          Text('TOTAL EXCL OF TAX:', style: receiptTextStyle),
                    ),
                    Text(
                      moneyFormat.format(receipt.totalExlcOfTax),
                      style: receiptTextStyle,
                      textAlign: TextAlign.right,
                    ),
                  ],
                ),
                TableRow(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 5),
                      child: Text('TOTAL DISCOUNT:', style: receiptTextStyle),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 5),
                      child: Text(
                        moneyFormat.format(receipt.totalDiscount),
                        style: receiptTextStyle,
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ],
                ),
                TableRow(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 5),
                      child: Text('TOTAL TAX:', style: receiptTextStyle),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 5.0),
                      child: Text(
                        moneyFormat.format(receipt.totalTax),
                        style: receiptTextStyle,
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ],
                ),
                TableRow(
                  children: [
                    Text('TOTAL INCL OF TAX:', style: receiptTextStyle),
                    Text(
                      moneyFormat.format(receipt.totalInclOfTax),
                      style: receiptTextStyle,
                      textAlign: TextAlign.right,
                    ),
                  ],
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  List<TableRow> buildItemsRows(List<Item>? items) {
    return receipt.items!
        .map(
          (item) => TableRow(
            children: [
              Text(
                item.description ?? '',
                style: receiptTextStyle,
              ),
              Text(
                '${item.quantity}',
                style: receiptTextStyle,
                textAlign: TextAlign.right,
              ),
              Text(
                '${item.amount}',
                style: receiptTextStyle,
                textAlign: TextAlign.right,
              ),
            ],
          ),
        )
        .toList();
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

  Future scrape(
      String code, String time, ReceiptProvider receiptProvider) async {
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
      http.Response response = await http.get(
        Uri.parse('http://50.116.44.162:4000/receipt/$code/$time'),
        headers: {
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 30));

      dynamic responseBody = jsonDecode(response.body);

      if (response.statusCode == 200 && responseBody.isNotEmpty) {
        http.Response serverResponse = await http.post(
          Uri.parse('https://wajenziprosystem.co.tz/api/add_receipt'),
          body: jsonEncode(responseBody),
          headers: {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
          },
        );

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
            errMsg = 'Failed to upload data to lemuru servers';
          });
        }
      } else {
        setState(() {
          receiptUrlFound = false;
          errMsg = 'TRA scrape failed';
        });
      }
    } catch (e) {
      setState(() {
        receiptUrlFound = false;
        errMsg = 'TRA scrape failed';
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

    List<Item> items = json['items'].isNotEmpty
        ? List.generate(json['items'].length,
            (index) => Item.fromJson(json['items'][index]))
        : [];

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
      totalExlcOfTax: double.parse(json['receipt_total_excl_of_tax']),
      totalDiscount: double.parse(json['receipt_total_discount']),
      totalTax: double.parse(json['receipt_total_tax']),
      totalInclOfTax: double.parse(json['receipt_total_incl_of_tax']),
      customer: customer,
      items: items,
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

  List<Receipt> get receipts => _receipts;
  APIRequestStatus get apiRequestStatus => _apiRequestStatus;

  ReceiptProvider() {
    fetchReceipts();
  }

  Future<void> fetchReceipts() async {
    _apiRequestStatus = APIRequestStatus.loading;
    notifyListeners();

    try {
      http.Response response = await http.get(
        Uri.parse('https://wajenziprosystem.co.tz/api/receipts'),
        headers: {
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        List<dynamic> responseBody = jsonDecode(response.body);
        List<Receipt> nwReceipts = getReceiptsFromJson(responseBody);
        _receipts = nwReceipts;
        _apiRequestStatus = APIRequestStatus.loaded;
        notifyListeners();
      } else {
        _apiRequestStatus = APIRequestStatus.error;
        notifyListeners();
      }
    } catch (e) {
      if (e is SocketException || e is TimeoutException) {
        _apiRequestStatus = APIRequestStatus.networkError;
        notifyListeners();
      } else {
        _apiRequestStatus = APIRequestStatus.error;
        notifyListeners();
      }
    }
  }

  bool checkIfReceiptExists(String code) {
    var receipts =
        _receipts.where((receipt) => receipt.verificationCode == code);

    if (receipts.isNotEmpty) return true;

    return false;
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
