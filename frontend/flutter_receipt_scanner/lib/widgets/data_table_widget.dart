import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class DataTableWidget extends StatefulWidget {
  final List<Map<String, dynamic>> data;
  final List<String> columns;
  final List<String> columnNames;
  final bool isLoading;
  final String emptyMessage;
  final Function(Map<String, dynamic>)? onRowTap;
  final TextEditingController searchController;
  final Function(String) onSearch;
  final DateTime? startDate;
  final DateTime? endDate;
  final Function(DateTime?, DateTime?) onDateRangeChanged;
  final Widget Function(Map<String, dynamic>)? actionBuilder;

  const DataTableWidget({
    Key? key,
    required this.data,
    required this.columns,
    required this.columnNames,
    this.isLoading = false,
    this.emptyMessage = 'No data available',
    this.onRowTap,
    required this.searchController,
    required this.onSearch,
    this.startDate,
    this.endDate,
    required this.onDateRangeChanged,
    this.actionBuilder,
  }) : super(key: key);

  @override
  State<DataTableWidget> createState() => _DataTableWidgetState();
}

class _DataTableWidgetState extends State<DataTableWidget> {
  int _sortColumnIndex = 0;
  bool _sortAscending = true;
  List<Map<String, dynamic>> _filteredData = [];
  bool _showFilterOptions = false;

  @override
  void initState() {
    super.initState();
    _filteredData = List.from(widget.data);
  }

  @override
  void didUpdateWidget(DataTableWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.data != oldWidget.data) {
      _filteredData = List.from(widget.data);
      _applyFilters();
    }
  }

  void _applyFilters() {
    final searchTerm = widget.searchController.text.toLowerCase();
    setState(() {
      _filteredData = widget.data.where((item) {
        // Apply search filter
        bool matchesSearch = searchTerm.isEmpty || 
            widget.columns.any((column) => 
                item[column].toString().toLowerCase().contains(searchTerm));
                
        // Apply date range filter
        bool matchesDateRange = true;
        if (widget.startDate != null && widget.endDate != null) {
          if (item['date'] != null) {
            try {
              final itemDate = DateTime.parse(item['date']);
              matchesDateRange = itemDate.isAfter(widget.startDate!.subtract(const Duration(days: 1))) && 
                  itemDate.isBefore(widget.endDate!.add(const Duration(days: 1)));
            } catch (e) {
              // If date parsing fails, keep the item in the list
              matchesDateRange = true;
            }
          }
        }
        
        return matchesSearch && matchesDateRange;
      }).toList();
      
      // Apply sorting
      if (_sortColumnIndex < widget.columns.length) {
        final column = widget.columns[_sortColumnIndex];
        _filteredData.sort((a, b) {
          var aValue = a[column];
          var bValue = b[column];
          
          // Handle different data types
          if (aValue is num && bValue is num) {
            return _sortAscending ? aValue.compareTo(bValue) : bValue.compareTo(aValue);
          } else if (aValue is DateTime && bValue is DateTime) {
            return _sortAscending ? aValue.compareTo(bValue) : bValue.compareTo(aValue);
          } else {
            return _sortAscending 
                ? aValue.toString().compareTo(bValue.toString()) 
                : bValue.toString().compareTo(aValue.toString());
          }
        });
      }
    });
  }

  void _onSort(int columnIndex, bool ascending) {
    setState(() {
      _sortColumnIndex = columnIndex;
      _sortAscending = ascending;
      _applyFilters();
    });
  }

  Future<void> _selectDateRange(BuildContext context) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: widget.startDate != null && widget.endDate != null
          ? DateTimeRange(start: widget.startDate!, end: widget.endDate!)
          : null,
    );
    
    if (picked != null) {
      widget.onDateRangeChanged(picked.start, picked.end);
      _applyFilters();
    }
  }

  void _clearFilters() {
    widget.searchController.clear();
    widget.onDateRangeChanged(null, null);
    widget.onSearch('');
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Search and filter bar
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: widget.searchController,
                      decoration: InputDecoration(
                        hintText: 'Search...',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10.0),
                        ),
                        contentPadding: const EdgeInsets.symmetric(vertical: 0.0),
                      ),
                      onChanged: (value) {
                        widget.onSearch(value);
                        _applyFilters();
                      },
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      _showFilterOptions ? Icons.expand_less : Icons.filter_list,
                      color: Colors.blue,
                    ),
                    onPressed: () {
                      setState(() {
                        _showFilterOptions = !_showFilterOptions;
                      });
                    },
                  ),
                ],
              ),
              if (_showFilterOptions)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.only(top: 8.0),
                  padding: const EdgeInsets.all(8.0),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(10.0),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Filter Options',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16.0,
                        ),
                      ),
                      const SizedBox(height: 8.0),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.date_range),
                              label: Text(
                                widget.startDate != null && widget.endDate != null
                                    ? '${DateFormat('dd/MM/yyyy').format(widget.startDate!)} - ${DateFormat('dd/MM/yyyy').format(widget.endDate!)}'
                                    : 'Select Date Range',
                              ),
                              onPressed: () => _selectDateRange(context),
                            ),
                          ),
                          const SizedBox(width: 8.0),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.clear),
                            label: const Text('Clear'),
                            onPressed: _clearFilters,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red.shade400,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        
        // Status bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            children: [
              Text(
                'Showing ${_filteredData.length} entries',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              if (widget.isLoading)
                const SizedBox(
                  width: 20, 
                  height: 20, 
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
        ),
        
        // Data table
        Expanded(
          child: widget.isLoading 
              ? const Center(child: CircularProgressIndicator())
              : _filteredData.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.warning_amber_rounded, size: 64, color: Colors.grey),
                          const SizedBox(height: 16),
                          Text(
                            widget.emptyMessage,
                            style: const TextStyle(color: Colors.grey, fontSize: 16),
                          ),
                        ],
                      ),
                    )
                  : SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          sortColumnIndex: _sortColumnIndex,
                          sortAscending: _sortAscending,
                          columns: List.generate(
                            widget.columns.length,
                            (index) => DataColumn(
                              label: Text(
                                widget.columnNames[index],
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              onSort: (columnIndex, ascending) {
                                _onSort(columnIndex, ascending);
                              },
                            ),
                          ),
                          rows: _filteredData.map((item) {
                            return DataRow(
                              cells: widget.columns.map((column) {
                                if (column == 'actions' && widget.actionBuilder != null) {
                                  return DataCell(widget.actionBuilder!(item));
                                } else {
                                  return DataCell(
                                    Text(item[column]?.toString() ?? ''),
                                  );
                                }
                              }).toList(),
                              onSelectChanged: widget.onRowTap != null
                                  ? (_) => widget.onRowTap!(item)
                                  : null,
                            );
                          }).toList(),
                        ),
                      ),
                    ),
        ),
      ],
    );
  }
}