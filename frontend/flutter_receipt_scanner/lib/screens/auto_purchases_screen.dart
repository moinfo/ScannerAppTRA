import 'package:flutter/material.dart';
import 'package:flutter_receipt_scanner/main.dart';
import 'package:flutter_receipt_scanner/providers/receipt_provider.dart';
import 'package:flutter_receipt_scanner/utils/api_request_status.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class AutoPurchasesScreen extends StatefulWidget {
  const AutoPurchasesScreen({Key? key}) : super(key: key);

  @override
  State<AutoPurchasesScreen> createState() => _AutoPurchasesScreenState();
}

class _AutoPurchasesScreenState extends State<AutoPurchasesScreen> {
  @override
  Widget build(BuildContext context) {
    return const MyHomePage();
  }
}