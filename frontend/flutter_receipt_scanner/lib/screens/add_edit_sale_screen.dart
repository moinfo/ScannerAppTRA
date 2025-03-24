import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_receipt_scanner/providers/sales_provider.dart';
import 'package:flutter_receipt_scanner/services/sales_service.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class AddEditSaleScreen extends StatefulWidget {
  final Sale? sale;
  
  const AddEditSaleScreen({Key? key, this.sale}) : super(key: key);

  @override
  State<AddEditSaleScreen> createState() => _AddEditSaleScreenState();
}

class _AddEditSaleScreenState extends State<AddEditSaleScreen> {
  final _formKey = GlobalKey<FormState>();
  
  final _customerController = TextEditingController();
  final _dateController = TextEditingController();
  final _amountController = TextEditingController();
  
  String _status = 'Pending';
  final List<String> _statusOptions = ['Pending', 'Completed', 'Cancelled'];
  
  DateTime _selectedDate = DateTime.now();
  List<SaleItemForm> _items = [];
  
  bool _isLoading = false;
  String _errorMessage = '';
  bool _isEditMode = false;
  
  @override
  void initState() {
    super.initState();
    
    if (widget.sale != null) {
      // Edit mode
      _isEditMode = true;
      _customerController.text = widget.sale!.customer;
      _dateController.text = DateFormat('yyyy-MM-dd').format(DateTime.parse(widget.sale!.date));
      _selectedDate = DateTime.parse(widget.sale!.date);
      _amountController.text = widget.sale!.amount.toString();
      _status = widget.sale!.status;
      
      // Initialize items
      _items = widget.sale!.items.map((item) => 
        SaleItemForm(
          nameController: TextEditingController(text: item.name),
          quantityController: TextEditingController(text: item.quantity.toString()),
          priceController: TextEditingController(text: item.price.toString()),
        )
      ).toList();
    } else {
      // Add mode
      _dateController.text = DateFormat('yyyy-MM-dd').format(_selectedDate);
      _addItem(); // Add one empty item row by default
    }
  }
  
  @override
  void dispose() {
    _customerController.dispose();
    _dateController.dispose();
    _amountController.dispose();
    
    // Dispose item controllers
    for (var item in _items) {
      item.dispose();
    }
    
    super.dispose();
  }
  
  void _addItem() {
    setState(() {
      _items.add(SaleItemForm(
        nameController: TextEditingController(),
        quantityController: TextEditingController(text: '1'),
        priceController: TextEditingController(text: '0'),
      ));
    });
  }
  
  void _removeItem(int index) {
    setState(() {
      _items[index].dispose();
      _items.removeAt(index);
      _updateTotalAmount();
    });
  }
  
  void _updateTotalAmount() {
    double total = 0;
    
    for (var item in _items) {
      final quantity = int.tryParse(item.quantityController.text) ?? 0;
      final price = double.tryParse(item.priceController.text) ?? 0;
      total += quantity * price;
    }
    
    _amountController.text = total.toString();
  }
  
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _dateController.text = DateFormat('yyyy-MM-dd').format(_selectedDate);
      });
    }
  }
  
  Future<void> _saveSale() async {
    if (_formKey.currentState!.validate()) {
      if (_items.isEmpty) {
        setState(() {
          _errorMessage = 'Please add at least one item';
        });
        return;
      }
      
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });
      
      try {
        final salesProvider = Provider.of<SalesProvider>(context, listen: false);
        
        // Collect sale items
        final items = _items.map((item) => 
          SaleItem(
            name: item.nameController.text,
            quantity: int.parse(item.quantityController.text),
            price: double.parse(item.priceController.text),
          )
        ).toList();
        
        // Create or update sale object
        final sale = Sale(
          id: _isEditMode ? widget.sale!.id : 0, // For new sales, API will assign ID
          customer: _customerController.text,
          date: _dateController.text,
          amount: double.parse(_amountController.text),
          status: _status,
          items: items,
        );
        
        bool success;
        if (_isEditMode) {
          success = await salesProvider.updateSale(sale);
        } else {
          success = await salesProvider.createSale(sale);
        }
        
        if (success && mounted) {
          Navigator.of(context).pop(true); // Return success
        } else {
          setState(() {
            _errorMessage = salesProvider.lastError;
            _isLoading = false;
          });
        }
      } catch (e) {
        setState(() {
          _errorMessage = 'Error saving sale: $e';
          _isLoading = false;
        });
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? 'Edit Sale' : 'Add New Sale'),
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              ),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_errorMessage.isNotEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.red.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                ),
              
              // Customer field
              TextFormField(
                controller: _customerController,
                decoration: const InputDecoration(
                  labelText: 'Customer',
                  hintText: 'Enter customer name',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a customer name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              // Date field
              GestureDetector(
                onTap: () => _selectDate(context),
                child: AbsorbPointer(
                  child: TextFormField(
                    controller: _dateController,
                    decoration: const InputDecoration(
                      labelText: 'Date',
                      hintText: 'YYYY-MM-DD',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.calendar_today),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please select a date';
                      }
                      return null;
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),
              
              // Status dropdown
              DropdownButtonFormField<String>(
                value: _status,
                decoration: const InputDecoration(
                  labelText: 'Status',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.fact_check),
                ),
                items: _statusOptions.map((status) {
                  return DropdownMenuItem<String>(
                    value: status,
                    child: Text(status),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _status = value;
                    });
                  }
                },
              ),
              const SizedBox(height: 24),
              
              // Items section
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Items',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.add),
                          label: const Text('Add Item'),
                          onPressed: _addItem,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    // Item headers
                    const Row(
                      children: [
                        Expanded(
                          flex: 5,
                          child: Text(
                            'Item',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          flex: 2,
                          child: Text(
                            'Qty',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          flex: 3,
                          child: Text(
                            'Price',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          flex: 3,
                          child: Text(
                            'Total',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        SizedBox(width: 40), // Space for delete button
                      ],
                    ),
                    const Divider(),
                    
                    // Item rows
                    ..._items.asMap().entries.map((entry) {
                      final index = entry.key;
                      final item = entry.value;
                      final quantity = int.tryParse(item.quantityController.text) ?? 0;
                      final price = double.tryParse(item.priceController.text) ?? 0;
                      final total = quantity * price;
                      
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 5,
                              child: TextFormField(
                                controller: item.nameController,
                                decoration: const InputDecoration(
                                  hintText: 'Item name',
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                                  border: OutlineInputBorder(),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Required';
                                  }
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 2,
                              child: TextFormField(
                                controller: item.quantityController,
                                decoration: const InputDecoration(
                                  hintText: 'Qty',
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                                  border: OutlineInputBorder(),
                                ),
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Required';
                                  }
                                  return null;
                                },
                                onChanged: (_) => _updateTotalAmount(),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 3,
                              child: TextFormField(
                                controller: item.priceController,
                                decoration: const InputDecoration(
                                  hintText: 'Price',
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                                  border: OutlineInputBorder(),
                                ),
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                                ],
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Required';
                                  }
                                  return null;
                                },
                                onChanged: (_) => _updateTotalAmount(),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 3,
                              child: Container(
                                alignment: Alignment.centerLeft,
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: Colors.grey.shade400),
                                ),
                                child: Text(
                                  'TZS ${NumberFormat('#,##0.00').format(total)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 32,
                              child: IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => _removeItem(index),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                splashRadius: 20,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                    
                    if (_items.isEmpty)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Text(
                            'No items added yet. Click "Add Item" to add an item.',
                            style: TextStyle(
                              color: Colors.grey,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ),
                    
                    const Divider(),
                    
                    // Total amount
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        const Text(
                          'Total Amount:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'TZS ${NumberFormat('#,##0.00').format(double.tryParse(_amountController.text) ?? 0)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              
              // Submit button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveSale,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(
                    _isLoading
                        ? 'Saving...'
                        : (_isEditMode ? 'Update Sale' : 'Create Sale'),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SaleItemForm {
  final TextEditingController nameController;
  final TextEditingController quantityController;
  final TextEditingController priceController;
  
  SaleItemForm({
    required this.nameController,
    required this.quantityController,
    required this.priceController,
  });
  
  void dispose() {
    nameController.dispose();
    quantityController.dispose();
    priceController.dispose();
  }
}