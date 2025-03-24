import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final databasePath = await getDatabasesPath();
    final path = join(databasePath, 'tra_scanner.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDatabase,
      onUpgrade: _upgradeDatabase,
    );
  }

  Future<void> _createDatabase(Database db, int version) async {
    debugPrint('Creating database at version $version');
    
    // Create receipts table
    await db.execute('''
      CREATE TABLE receipts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        company_name TEXT NOT NULL,
        po_box TEXT,
        mobile TEXT,
        tin TEXT,
        vrn TEXT,
        serial_number TEXT,
        uin TEXT,
        tax_office TEXT,
        date TEXT,
        time TEXT,
        number TEXT,
        z_number TEXT,
        verification_code TEXT,
        total_excl_of_tax REAL,
        total_discount REAL,
        total_tax REAL,
        total_incl_of_tax REAL,
        kwh_charge REAL,
        kva_charge REAL,
        service_charge REAL,
        interest_amount REAL,
        rea_charge REAL,
        ewura_charge REAL,
        property_tax REAL,
        tax_rate REAL,
        customer_name TEXT,
        customer_id_type TEXT,
        customer_id TEXT,
        customer_mobile TEXT,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        synced INTEGER DEFAULT 0
      )
    ''');
    
    // Create receipt items table
    await db.execute('''
      CREATE TABLE receipt_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        receipt_id INTEGER NOT NULL,
        description TEXT,
        quantity INTEGER,
        amount REAL,
        FOREIGN KEY (receipt_id) REFERENCES receipts (id) ON DELETE CASCADE
      )
    ''');
    
    // Create receipt adjustments table
    await db.execute('''
      CREATE TABLE receipt_adjustments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        receipt_id INTEGER NOT NULL,
        type TEXT,
        description TEXT,
        amount REAL,
        FOREIGN KEY (receipt_id) REFERENCES receipts (id) ON DELETE CASCADE
      )
    ''');
    
    // Create receipt payments table
    await db.execute('''
      CREATE TABLE receipt_payments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        receipt_id INTEGER NOT NULL,
        type TEXT,
        description TEXT,
        amount REAL,
        FOREIGN KEY (receipt_id) REFERENCES receipts (id) ON DELETE CASCADE
      )
    ''');
    
    // Create sales table
    await db.execute('''
      CREATE TABLE sales (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        customer TEXT NOT NULL,
        date TEXT NOT NULL,
        amount REAL NOT NULL,
        status TEXT NOT NULL,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        synced INTEGER DEFAULT 0
      )
    ''');
    
    // Create sale items table
    await db.execute('''
      CREATE TABLE sale_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sale_id INTEGER NOT NULL,
        name TEXT NOT NULL,
        quantity INTEGER NOT NULL,
        price REAL NOT NULL,
        FOREIGN KEY (sale_id) REFERENCES sales (id) ON DELETE CASCADE
      )
    ''');
    
    // Create purchases table
    await db.execute('''
      CREATE TABLE purchases (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        supplier TEXT NOT NULL,
        date TEXT NOT NULL,
        amount REAL NOT NULL,
        status TEXT NOT NULL,
        receipt_id INTEGER,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        synced INTEGER DEFAULT 0,
        FOREIGN KEY (receipt_id) REFERENCES receipts (id) ON DELETE SET NULL
      )
    ''');
    
    // Create purchase items table
    await db.execute('''
      CREATE TABLE purchase_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        purchase_id INTEGER NOT NULL,
        name TEXT NOT NULL,
        quantity INTEGER NOT NULL,
        price REAL NOT NULL,
        FOREIGN KEY (purchase_id) REFERENCES purchases (id) ON DELETE CASCADE
      )
    ''');
    
    // Create VAT payments table
    await db.execute('''
      CREATE TABLE vat_payments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        period TEXT NOT NULL,
        sales_vat REAL NOT NULL,
        purchases_vat REAL NOT NULL,
        amount_payable REAL NOT NULL,
        status TEXT NOT NULL,
        due_date TEXT NOT NULL,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        synced INTEGER DEFAULT 0
      )
    ''');
    
    // Create sync log table
    await db.execute('''
      CREATE TABLE sync_log (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        entity_type TEXT NOT NULL,
        entity_id INTEGER NOT NULL,
        operation TEXT NOT NULL,
        status TEXT NOT NULL,
        error_message TEXT,
        timestamp TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');
    
    // Migrate data from SharedPreferences if available
    await _migrateFromSharedPreferences();
  }

  Future<void> _upgradeDatabase(Database db, int oldVersion, int newVersion) async {
    debugPrint('Upgrading database from version $oldVersion to $newVersion');
    // Add upgrade logic here in future versions
  }

  Future<void> _migrateFromSharedPreferences() async {
    try {
      debugPrint('Starting migration from SharedPreferences to SQLite');
      final prefs = await SharedPreferences.getInstance();
      
      // Migrate receipts
      final receiptsJson = prefs.getString('offline_receipts');
      if (receiptsJson != null) {
        final receipts = jsonDecode(receiptsJson) as List;
        for (var receipt in receipts) {
          await insertReceipt(receipt);
        }
        debugPrint('Migrated ${receipts.length} receipts from SharedPreferences');
      }
      
      // Migrate sales
      final salesJson = prefs.getString('offline_sales');
      if (salesJson != null) {
        final sales = jsonDecode(salesJson) as List;
        for (var sale in sales) {
          await insertSale(sale);
        }
        debugPrint('Migrated ${sales.length} sales from SharedPreferences');
      }
      
      // Migrate purchases
      final purchasesJson = prefs.getString('offline_purchases');
      if (purchasesJson != null) {
        final purchases = jsonDecode(purchasesJson) as List;
        for (var purchase in purchases) {
          await insertPurchase(purchase);
        }
        debugPrint('Migrated ${purchases.length} purchases from SharedPreferences');
      }
      
      // Migrate VAT payments
      final vatJson = prefs.getString('offline_vat');
      if (vatJson != null) {
        final vatPayments = jsonDecode(vatJson) as List;
        for (var payment in vatPayments) {
          await insertVatPayment(payment);
        }
        debugPrint('Migrated ${vatPayments.length} VAT payments from SharedPreferences');
      }
      
      debugPrint('Migration from SharedPreferences to SQLite completed');
    } catch (e) {
      debugPrint('Error migrating from SharedPreferences: $e');
    }
  }

  // Receipt operations
  Future<int> insertReceipt(Map<String, dynamic> receipt) async {
    final db = await database;
    
    // Extract nested objects
    final items = receipt['items'] as List?;
    final adjustments = receipt['adjustments'] as List?;
    final payments = receipt['payments'] as List?;
    final customer = receipt['customer'] as Map<String, dynamic>?;
    
    // Remove nested objects from receipt data
    receipt.remove('items');
    receipt.remove('adjustments');
    receipt.remove('payments');
    receipt.remove('customer');
    
    // Add customer data to receipt
    if (customer != null) {
      receipt['customer_name'] = customer['name'];
      receipt['customer_id_type'] = customer['idType'];
      receipt['customer_id'] = customer['id'];
      receipt['customer_mobile'] = customer['mobile'];
    }
    
    // Make sure all receipt keys match the column names
    final receiptData = _convertKeysToSnakeCase(receipt);
    
    // Insert receipt and get its ID
    final receiptId = await db.insert('receipts', receiptData);
    
    // Insert items
    if (items != null) {
      for (final item in items) {
        final itemData = _convertKeysToSnakeCase(item);
        itemData['receipt_id'] = receiptId;
        await db.insert('receipt_items', itemData);
      }
    }
    
    // Insert adjustments
    if (adjustments != null) {
      for (final adjustment in adjustments) {
        final adjustmentData = _convertKeysToSnakeCase(adjustment);
        adjustmentData['receipt_id'] = receiptId;
        await db.insert('receipt_adjustments', adjustmentData);
      }
    }
    
    // Insert payments
    if (payments != null) {
      for (final payment in payments) {
        final paymentData = _convertKeysToSnakeCase(payment);
        paymentData['receipt_id'] = receiptId;
        await db.insert('receipt_payments', paymentData);
      }
    }
    
    return receiptId;
  }

  Future<Map<String, dynamic>?> getReceiptById(int id) async {
    final db = await database;
    
    // Get receipt
    final List<Map<String, dynamic>> maps = await db.query(
      'receipts',
      where: 'id = ?',
      whereArgs: [id],
    );
    
    if (maps.isEmpty) return null;
    
    final receipt = _convertKeysToCamelCase(maps.first);
    
    // Get items
    final List<Map<String, dynamic>> itemMaps = await db.query(
      'receipt_items',
      where: 'receipt_id = ?',
      whereArgs: [id],
    );
    
    receipt['items'] = itemMaps.map((item) => _convertKeysToCamelCase(item)).toList();
    
    // Get adjustments
    final List<Map<String, dynamic>> adjustmentMaps = await db.query(
      'receipt_adjustments',
      where: 'receipt_id = ?',
      whereArgs: [id],
    );
    
    receipt['adjustments'] = adjustmentMaps.map((adjustment) => _convertKeysToCamelCase(adjustment)).toList();
    
    // Get payments
    final List<Map<String, dynamic>> paymentMaps = await db.query(
      'receipt_payments',
      where: 'receipt_id = ?',
      whereArgs: [id],
    );
    
    receipt['payments'] = paymentMaps.map((payment) => _convertKeysToCamelCase(payment)).toList();
    
    // Create customer object
    receipt['customer'] = {
      'name': receipt['customerName'],
      'idType': receipt['customerIdType'],
      'id': receipt['customerId'],
      'mobile': receipt['customerMobile'],
    };
    
    // Remove customer fields
    receipt.remove('customerName');
    receipt.remove('customerIdType');
    receipt.remove('customerId');
    receipt.remove('customerMobile');
    
    return receipt;
  }

  Future<List<Map<String, dynamic>>> getReceipts({
    int? limit,
    int? offset,
    String? searchTerm,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final db = await database;
    
    String whereClause = '';
    List<dynamic> whereArgs = [];
    
    if (searchTerm != null && searchTerm.isNotEmpty) {
      whereClause += 'company_name LIKE ?';
      whereArgs.add('%$searchTerm%');
    }
    
    if (startDate != null && endDate != null) {
      if (whereClause.isNotEmpty) {
        whereClause += ' AND ';
      }
      whereClause += 'date BETWEEN ? AND ?';
      whereArgs.add(startDate.toIso8601String().substring(0, 10));
      whereArgs.add(endDate.toIso8601String().substring(0, 10));
    }
    
    final List<Map<String, dynamic>> maps = await db.query(
      'receipts',
      where: whereClause.isEmpty ? null : whereClause,
      whereArgs: whereArgs.isEmpty ? null : whereArgs,
      limit: limit,
      offset: offset,
      orderBy: 'date DESC, time DESC',
    );
    
    final List<Map<String, dynamic>> receipts = [];
    
    for (final map in maps) {
      final receipt = _convertKeysToCamelCase(map);
      
      // Get items
      final List<Map<String, dynamic>> itemMaps = await db.query(
        'receipt_items',
        where: 'receipt_id = ?',
        whereArgs: [map['id']],
      );
      
      receipt['items'] = itemMaps.map((item) => _convertKeysToCamelCase(item)).toList();
      
      // Create customer object
      receipt['customer'] = {
        'name': receipt['customerName'],
        'idType': receipt['customerIdType'],
        'id': receipt['customerId'],
        'mobile': receipt['customerMobile'],
      };
      
      // Remove customer fields
      receipt.remove('customerName');
      receipt.remove('customerIdType');
      receipt.remove('customerId');
      receipt.remove('customerMobile');
      
      receipts.add(receipt);
    }
    
    return receipts;
  }

  Future<int> updateReceipt(Map<String, dynamic> receipt) async {
    final db = await database;
    
    final receiptId = receipt['id'];
    if (receiptId == null) {
      throw Exception('Receipt ID is required for update');
    }
    
    // Extract nested objects
    final items = receipt['items'] as List?;
    final adjustments = receipt['adjustments'] as List?;
    final payments = receipt['payments'] as List?;
    final customer = receipt['customer'] as Map<String, dynamic>?;
    
    // Remove nested objects and ID from receipt data
    receipt.remove('items');
    receipt.remove('adjustments');
    receipt.remove('payments');
    receipt.remove('customer');
    receipt.remove('id');
    
    // Add customer data to receipt
    if (customer != null) {
      receipt['customer_name'] = customer['name'];
      receipt['customer_id_type'] = customer['idType'];
      receipt['customer_id'] = customer['id'];
      receipt['customer_mobile'] = customer['mobile'];
    }
    
    // Make sure all receipt keys match the column names
    final receiptData = _convertKeysToSnakeCase(receipt);
    receiptData['synced'] = 0; // Mark as not synced
    
    // Update receipt
    await db.update(
      'receipts',
      receiptData,
      where: 'id = ?',
      whereArgs: [receiptId],
    );
    
    // Delete existing related records
    await db.delete('receipt_items', where: 'receipt_id = ?', whereArgs: [receiptId]);
    await db.delete('receipt_adjustments', where: 'receipt_id = ?', whereArgs: [receiptId]);
    await db.delete('receipt_payments', where: 'receipt_id = ?', whereArgs: [receiptId]);
    
    // Insert new items
    if (items != null) {
      for (final item in items) {
        final itemData = _convertKeysToSnakeCase(item);
        itemData['receipt_id'] = receiptId;
        itemData.remove('id'); // Remove item ID to let SQLite generate a new one
        await db.insert('receipt_items', itemData);
      }
    }
    
    // Insert new adjustments
    if (adjustments != null) {
      for (final adjustment in adjustments) {
        final adjustmentData = _convertKeysToSnakeCase(adjustment);
        adjustmentData['receipt_id'] = receiptId;
        adjustmentData.remove('id');
        await db.insert('receipt_adjustments', adjustmentData);
      }
    }
    
    // Insert new payments
    if (payments != null) {
      for (final payment in payments) {
        final paymentData = _convertKeysToSnakeCase(payment);
        paymentData['receipt_id'] = receiptId;
        paymentData.remove('id');
        await db.insert('receipt_payments', paymentData);
      }
    }
    
    return receiptId;
  }

  Future<int> deleteReceipt(int id) async {
    final db = await database;
    return await db.delete(
      'receipts',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Sale operations
  Future<int> insertSale(Map<String, dynamic> sale) async {
    final db = await database;
    
    // Extract items
    final items = sale['items'] as List?;
    
    // Remove items from sale data
    sale.remove('items');
    
    // Make sure all sale keys match the column names
    final saleData = _convertKeysToSnakeCase(sale);
    
    // Insert sale and get its ID
    final saleId = await db.insert('sales', saleData);
    
    // Insert items
    if (items != null) {
      for (final item in items) {
        final itemData = _convertKeysToSnakeCase(item);
        itemData['sale_id'] = saleId;
        await db.insert('sale_items', itemData);
      }
    }
    
    return saleId;
  }

  Future<Map<String, dynamic>?> getSaleById(int id) async {
    final db = await database;
    
    // Get sale
    final List<Map<String, dynamic>> maps = await db.query(
      'sales',
      where: 'id = ?',
      whereArgs: [id],
    );
    
    if (maps.isEmpty) return null;
    
    final sale = _convertKeysToCamelCase(maps.first);
    
    // Get items
    final List<Map<String, dynamic>> itemMaps = await db.query(
      'sale_items',
      where: 'sale_id = ?',
      whereArgs: [id],
    );
    
    sale['items'] = itemMaps.map((item) => _convertKeysToCamelCase(item)).toList();
    
    return sale;
  }

  Future<List<Map<String, dynamic>>> getSales({
    int? limit,
    int? offset,
    String? searchTerm,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final db = await database;
    
    String whereClause = '';
    List<dynamic> whereArgs = [];
    
    if (searchTerm != null && searchTerm.isNotEmpty) {
      whereClause += 'customer LIKE ?';
      whereArgs.add('%$searchTerm%');
    }
    
    if (startDate != null && endDate != null) {
      if (whereClause.isNotEmpty) {
        whereClause += ' AND ';
      }
      whereClause += 'date BETWEEN ? AND ?';
      whereArgs.add(startDate.toIso8601String().substring(0, 10));
      whereArgs.add(endDate.toIso8601String().substring(0, 10));
    }
    
    final List<Map<String, dynamic>> maps = await db.query(
      'sales',
      where: whereClause.isEmpty ? null : whereClause,
      whereArgs: whereArgs.isEmpty ? null : whereArgs,
      limit: limit,
      offset: offset,
      orderBy: 'date DESC',
    );
    
    final List<Map<String, dynamic>> sales = [];
    
    for (final map in maps) {
      final sale = _convertKeysToCamelCase(map);
      
      // Get items
      final List<Map<String, dynamic>> itemMaps = await db.query(
        'sale_items',
        where: 'sale_id = ?',
        whereArgs: [map['id']],
      );
      
      sale['items'] = itemMaps.map((item) => _convertKeysToCamelCase(item)).toList();
      
      sales.add(sale);
    }
    
    return sales;
  }

  Future<int> updateSale(Map<String, dynamic> sale) async {
    final db = await database;
    
    final saleId = sale['id'];
    if (saleId == null) {
      throw Exception('Sale ID is required for update');
    }
    
    // Extract items
    final items = sale['items'] as List?;
    
    // Remove items and ID from sale data
    sale.remove('items');
    sale.remove('id');
    
    // Make sure all sale keys match the column names
    final saleData = _convertKeysToSnakeCase(sale);
    saleData['synced'] = 0; // Mark as not synced
    
    // Update sale
    await db.update(
      'sales',
      saleData,
      where: 'id = ?',
      whereArgs: [saleId],
    );
    
    // Delete existing items
    await db.delete('sale_items', where: 'sale_id = ?', whereArgs: [saleId]);
    
    // Insert new items
    if (items != null) {
      for (final item in items) {
        final itemData = _convertKeysToSnakeCase(item);
        itemData['sale_id'] = saleId;
        itemData.remove('id'); // Remove item ID to let SQLite generate a new one
        await db.insert('sale_items', itemData);
      }
    }
    
    return saleId;
  }

  Future<int> deleteSale(int id) async {
    final db = await database;
    return await db.delete(
      'sales',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Purchase operations
  Future<int> insertPurchase(Map<String, dynamic> purchase) async {
    final db = await database;
    
    // Extract items
    final items = purchase['items'] as List?;
    
    // Remove items from purchase data
    purchase.remove('items');
    
    // Make sure all purchase keys match the column names
    final purchaseData = _convertKeysToSnakeCase(purchase);
    
    // Insert purchase and get its ID
    final purchaseId = await db.insert('purchases', purchaseData);
    
    // Insert items
    if (items != null) {
      for (final item in items) {
        final itemData = _convertKeysToSnakeCase(item);
        itemData['purchase_id'] = purchaseId;
        await db.insert('purchase_items', itemData);
      }
    }
    
    return purchaseId;
  }

  Future<Map<String, dynamic>?> getPurchaseById(int id) async {
    final db = await database;
    
    // Get purchase
    final List<Map<String, dynamic>> maps = await db.query(
      'purchases',
      where: 'id = ?',
      whereArgs: [id],
    );
    
    if (maps.isEmpty) return null;
    
    final purchase = _convertKeysToCamelCase(maps.first);
    
    // Get items
    final List<Map<String, dynamic>> itemMaps = await db.query(
      'purchase_items',
      where: 'purchase_id = ?',
      whereArgs: [id],
    );
    
    purchase['items'] = itemMaps.map((item) => _convertKeysToCamelCase(item)).toList();
    
    return purchase;
  }

  Future<List<Map<String, dynamic>>> getPurchases({
    int? limit,
    int? offset,
    String? searchTerm,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final db = await database;
    
    String whereClause = '';
    List<dynamic> whereArgs = [];
    
    if (searchTerm != null && searchTerm.isNotEmpty) {
      whereClause += 'supplier LIKE ?';
      whereArgs.add('%$searchTerm%');
    }
    
    if (startDate != null && endDate != null) {
      if (whereClause.isNotEmpty) {
        whereClause += ' AND ';
      }
      whereClause += 'date BETWEEN ? AND ?';
      whereArgs.add(startDate.toIso8601String().substring(0, 10));
      whereArgs.add(endDate.toIso8601String().substring(0, 10));
    }
    
    final List<Map<String, dynamic>> maps = await db.query(
      'purchases',
      where: whereClause.isEmpty ? null : whereClause,
      whereArgs: whereArgs.isEmpty ? null : whereArgs,
      limit: limit,
      offset: offset,
      orderBy: 'date DESC',
    );
    
    final List<Map<String, dynamic>> purchases = [];
    
    for (final map in maps) {
      final purchase = _convertKeysToCamelCase(map);
      
      // Get items
      final List<Map<String, dynamic>> itemMaps = await db.query(
        'purchase_items',
        where: 'purchase_id = ?',
        whereArgs: [map['id']],
      );
      
      purchase['items'] = itemMaps.map((item) => _convertKeysToCamelCase(item)).toList();
      
      purchases.add(purchase);
    }
    
    return purchases;
  }

  Future<int> updatePurchase(Map<String, dynamic> purchase) async {
    final db = await database;
    
    final purchaseId = purchase['id'];
    if (purchaseId == null) {
      throw Exception('Purchase ID is required for update');
    }
    
    // Extract items
    final items = purchase['items'] as List?;
    
    // Remove items and ID from purchase data
    purchase.remove('items');
    purchase.remove('id');
    
    // Make sure all purchase keys match the column names
    final purchaseData = _convertKeysToSnakeCase(purchase);
    purchaseData['synced'] = 0; // Mark as not synced
    
    // Update purchase
    await db.update(
      'purchases',
      purchaseData,
      where: 'id = ?',
      whereArgs: [purchaseId],
    );
    
    // Delete existing items
    await db.delete('purchase_items', where: 'purchase_id = ?', whereArgs: [purchaseId]);
    
    // Insert new items
    if (items != null) {
      for (final item in items) {
        final itemData = _convertKeysToSnakeCase(item);
        itemData['purchase_id'] = purchaseId;
        itemData.remove('id'); // Remove item ID to let SQLite generate a new one
        await db.insert('purchase_items', itemData);
      }
    }
    
    return purchaseId;
  }

  Future<int> deletePurchase(int id) async {
    final db = await database;
    return await db.delete(
      'purchases',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // VAT Payment operations
  Future<int> insertVatPayment(Map<String, dynamic> vatPayment) async {
    final db = await database;
    
    // Make sure all VAT payment keys match the column names
    final vatPaymentData = _convertKeysToSnakeCase(vatPayment);
    
    // Insert VAT payment and get its ID
    return await db.insert('vat_payments', vatPaymentData);
  }

  Future<Map<String, dynamic>?> getVatPaymentById(int id) async {
    final db = await database;
    
    final List<Map<String, dynamic>> maps = await db.query(
      'vat_payments',
      where: 'id = ?',
      whereArgs: [id],
    );
    
    if (maps.isEmpty) return null;
    
    return _convertKeysToCamelCase(maps.first);
  }

  Future<List<Map<String, dynamic>>> getVatPayments({
    int? limit,
    int? offset,
    String? status,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final db = await database;
    
    String whereClause = '';
    List<dynamic> whereArgs = [];
    
    if (status != null && status.isNotEmpty) {
      whereClause += 'status = ?';
      whereArgs.add(status);
    }
    
    if (startDate != null && endDate != null) {
      if (whereClause.isNotEmpty) {
        whereClause += ' AND ';
      }
      whereClause += 'due_date BETWEEN ? AND ?';
      whereArgs.add(startDate.toIso8601String().substring(0, 10));
      whereArgs.add(endDate.toIso8601String().substring(0, 10));
    }
    
    final List<Map<String, dynamic>> maps = await db.query(
      'vat_payments',
      where: whereClause.isEmpty ? null : whereClause,
      whereArgs: whereArgs.isEmpty ? null : whereArgs,
      limit: limit,
      offset: offset,
      orderBy: 'due_date DESC',
    );
    
    return maps.map((map) => _convertKeysToCamelCase(map)).toList();
  }

  Future<int> updateVatPayment(Map<String, dynamic> vatPayment) async {
    final db = await database;
    
    final vatPaymentId = vatPayment['id'];
    if (vatPaymentId == null) {
      throw Exception('VAT Payment ID is required for update');
    }
    
    // Remove ID from VAT payment data
    vatPayment.remove('id');
    
    // Make sure all VAT payment keys match the column names
    final vatPaymentData = _convertKeysToSnakeCase(vatPayment);
    vatPaymentData['synced'] = 0; // Mark as not synced
    
    // Update VAT payment
    return await db.update(
      'vat_payments',
      vatPaymentData,
      where: 'id = ?',
      whereArgs: [vatPaymentId],
    );
  }

  Future<int> deleteVatPayment(int id) async {
    final db = await database;
    return await db.delete(
      'vat_payments',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Sync operations
  Future<void> markAsSynced(String entityType, int entityId) async {
    final db = await database;
    
    String tableName;
    switch (entityType) {
      case 'receipt':
        tableName = 'receipts';
        break;
      case 'sale':
        tableName = 'sales';
        break;
      case 'purchase':
        tableName = 'purchases';
        break;
      case 'vat_payment':
        tableName = 'vat_payments';
        break;
      default:
        throw Exception('Unknown entity type: $entityType');
    }
    
    await db.update(
      tableName,
      {'synced': 1},
      where: 'id = ?',
      whereArgs: [entityId],
    );
    
    // Add to sync log
    await db.insert('sync_log', {
      'entity_type': entityType,
      'entity_id': entityId,
      'operation': 'sync',
      'status': 'success',
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  Future<List<Map<String, dynamic>>> getUnsyncedEntities(String entityType) async {
    final db = await database;
    
    String tableName;
    switch (entityType) {
      case 'receipt':
        tableName = 'receipts';
        break;
      case 'sale':
        tableName = 'sales';
        break;
      case 'purchase':
        tableName = 'purchases';
        break;
      case 'vat_payment':
        tableName = 'vat_payments';
        break;
      default:
        throw Exception('Unknown entity type: $entityType');
    }
    
    final List<Map<String, dynamic>> maps = await db.query(
      tableName,
      where: 'synced = 0',
      orderBy: 'id ASC',
    );
    
    // For receipts, we need to include related data
    if (entityType == 'receipt') {
      final List<Map<String, dynamic>> receipts = [];
      
      for (final map in maps) {
        final receipt = _convertKeysToCamelCase(map);
        final receiptId = map['id'];
        
        // Get items
        final List<Map<String, dynamic>> itemMaps = await db.query(
          'receipt_items',
          where: 'receipt_id = ?',
          whereArgs: [receiptId],
        );
        
        receipt['items'] = itemMaps.map((item) => _convertKeysToCamelCase(item)).toList();
        
        // Get adjustments
        final List<Map<String, dynamic>> adjustmentMaps = await db.query(
          'receipt_adjustments',
          where: 'receipt_id = ?',
          whereArgs: [receiptId],
        );
        
        receipt['adjustments'] = adjustmentMaps.map((adjustment) => _convertKeysToCamelCase(adjustment)).toList();
        
        // Get payments
        final List<Map<String, dynamic>> paymentMaps = await db.query(
          'receipt_payments',
          where: 'receipt_id = ?',
          whereArgs: [receiptId],
        );
        
        receipt['payments'] = paymentMaps.map((payment) => _convertKeysToCamelCase(payment)).toList();
        
        // Create customer object
        receipt['customer'] = {
          'name': receipt['customerName'],
          'idType': receipt['customerIdType'],
          'id': receipt['customerId'],
          'mobile': receipt['customerMobile'],
        };
        
        // Remove customer fields
        receipt.remove('customerName');
        receipt.remove('customerIdType');
        receipt.remove('customerId');
        receipt.remove('customerMobile');
        
        receipts.add(receipt);
      }
      
      return receipts;
    } else if (entityType == 'sale' || entityType == 'purchase') {
      // For sales and purchases, we need to include items
      final List<Map<String, dynamic>> entities = [];
      
      for (final map in maps) {
        final entity = _convertKeysToCamelCase(map);
        final entityId = map['id'];
        
        // Get items
        final List<Map<String, dynamic>> itemMaps = await db.query(
          entityType == 'sale' ? 'sale_items' : 'purchase_items',
          where: entityType == 'sale' ? 'sale_id = ?' : 'purchase_id = ?',
          whereArgs: [entityId],
        );
        
        entity['items'] = itemMaps.map((item) => _convertKeysToCamelCase(item)).toList();
        
        entities.add(entity);
      }
      
      return entities;
    }
    
    return maps.map((map) => _convertKeysToCamelCase(map)).toList();
  }

  // Helper methods
  Map<String, dynamic> _convertKeysToSnakeCase(Map<String, dynamic> data) {
    final result = <String, dynamic>{};
    data.forEach((key, value) {
      // Skip null values
      if (value == null) return;
      
      // Convert camelCase to snake_case
      final snakeKey = key.replaceAllMapped(
        RegExp(r'([A-Z])'),
        (match) => '_${match.group(1)!.toLowerCase()}',
      );
      
      result[snakeKey] = value;
    });
    return result;
  }

  Map<String, dynamic> _convertKeysToCamelCase(Map<String, dynamic> data) {
    final result = <String, dynamic>{};
    data.forEach((key, value) {
      // Convert snake_case to camelCase
      final camelKey = key.replaceAllMapped(
        RegExp(r'_([a-z])'),
        (match) => match.group(1)!.toUpperCase(),
      );
      
      result[camelKey] = value;
    });
    return result;
  }
}