import 'package:flutter/material.dart';
import 'package:flutter_receipt_scanner/providers/app_state_provider.dart';
import 'package:flutter_receipt_scanner/providers/vat_provider.dart';
import 'package:flutter_receipt_scanner/screens/vat_payment_screen.dart';
import 'package:provider/provider.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppStateProvider()),
        ChangeNotifierProvider(create: (_) => VatProvider()),
      ],
      child: MaterialApp(
        title: 'VAT Screen Test',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          useMaterial3: true,
        ),
        home: const VatPaymentScreen(),
      ),
    );
  }
}