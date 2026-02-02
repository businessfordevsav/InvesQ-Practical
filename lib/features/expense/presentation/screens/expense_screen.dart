import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:invesq_practical/core/constants/app_constants.dart';
import 'package:invesq_practical/core/widgets/custom_text_field.dart';
import 'package:invesq_practical/features/expense/presentation/providers/expense_provider.dart';

class ExpenseScreen extends StatefulWidget {
  const ExpenseScreen({super.key});

  @override
  State<ExpenseScreen> createState() => _ExpenseScreenState();
}

class _ExpenseScreenState extends State<ExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _dateController = TextEditingController();
  final _notesController = TextEditingController();
  final _itemDescController = TextEditingController();
  final _itemPriceController = TextEditingController();

  String _selectedCategory = AppConstants.expenseCategories[0];
  File? _receiptImage;
  DateTime _selectedDate = DateTime.now();
  bool _isOcrProcessed = false;
  List<String> _ocrItems = [];
  List<Map<String, String>> _savedItems = [];
  bool _showAddItemForm = false;
  Map<String, String> _extractedData = {};

  @override
  void initState() {
    super.initState();
    _dateController.text = DateFormat('MMM dd, yyyy').format(_selectedDate);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _dateController.dispose();
    _notesController.dispose();
    _itemDescController.dispose();
    _itemPriceController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        setState(() {
          _receiptImage = File(pickedFile.path);
          _isOcrProcessed = false;
        });

        // Show OCR option
        if (mounted) {
          _showOcrDialog();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to pick image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showOcrDialog() async {
    final shouldProcess = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Process Receipt'),
        content: const Text(
          'Would you like to automatically extract data from this receipt using OCR?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Yes'),
          ),
        ],
      ),
    );

    if (shouldProcess == true && mounted) {
      await _processOcr();
    }
  }

  Future<void> _processOcr() async {
    if (_receiptImage == null) return;

    final expenseProvider = Provider.of<ExpenseProvider>(
      context,
      listen: false,
    );

    // Show processing dialog
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => _OcrProcessingDialog(),
      );
    }

    final result = await expenseProvider.processReceipt(_receiptImage!.path);

    if (mounted) {
      Navigator.pop(context); // Close processing dialog

      if (expenseProvider.state == OcrState.success) {
        // Only store extracted data for display in receipt section
        // Don't auto-fill title and amount - let user enter these manually
        if (result['date']?.isNotEmpty == true) {
          try {
            _selectedDate = DateTime.parse(result['date']!);
            _dateController.text = DateFormat(
              'MMM dd, yyyy',
            ).format(_selectedDate);
          } catch (e) {
            // Keep current date if parsing fails
          }
        }

        setState(() {
          _isOcrProcessed = true;
          _extractedData = {
            'merchant': result['merchant'] ?? '',
            'amount': result['amount'] ?? '',
            'date': result['date'] ?? '',
          };
          _ocrItems = (result['items'] as List<dynamic>?)?.cast<String>() ?? [];

          // Auto-populate saved items from OCR items
          _savedItems = _ocrItems.map((item) {
            // Parse item to extract description and price
            // Formats: "qty description unit_price amount" or "qty description price"
            try {
              final trimmed = item.trim();

              // Find all prices (numbers with .xx format)
              final prices = RegExp(r'\d+\.\d{2}').allMatches(trimmed);

              if (prices.isEmpty) {
                // No price found, use item as description
                return {'description': trimmed, 'price': '0.00'};
              }

              // Get the last price (usually the amount)
              final lastPrice = prices.last.group(0) ?? '0.00';

              // Extract description: everything before the first price
              final firstPriceStart = trimmed.indexOf(RegExp(r'\d+\.\d{2}'));
              String description = trimmed.substring(0, firstPriceStart).trim();

              // Clean up description: remove qty number at start if present
              description = description
                  .replaceFirst(RegExp(r'^\d+\s+'), '')
                  .trim();

              // If description is empty, use the whole item text
              if (description.isEmpty) {
                description = trimmed;
              }

              return {
                'description': description.isNotEmpty ? description : 'Item',
                'price': lastPrice,
              };
            } catch (e) {
              return {'description': item, 'price': '0.00'};
            }
          }).toList();
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _ocrItems.isEmpty
                  ? 'Receipt processed successfully!'
                  : 'Receipt processed! Found ${_ocrItems.length} items.',
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              expenseProvider.errorMessage ?? 'Failed to process receipt',
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _addItem() {
    if (_itemDescController.text.isEmpty || _itemPriceController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter item description and price'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _savedItems.add({
        'description': _itemDescController.text,
        'price': _itemPriceController.text,
      });
      _itemDescController.clear();
      _itemPriceController.clear();
      _showAddItemForm = false;
    });
  }

  void _removeItem(int index) {
    setState(() {
      _savedItems.removeAt(index);
    });
  }

  double _calculateTotal() {
    double total = 0;
    for (final item in _savedItems) {
      total += double.tryParse(item['price'] ?? '0') ?? 0;
    }
    return total;
  }

  List<Widget> _buildItemRows() {
    return List.generate(_savedItems.length, (index) {
      final item = _savedItems[index];
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                // Qty - typically just "1" for expenses
                SizedBox(
                  width: 40,
                  child: Text('1', style: const TextStyle(fontSize: 14)),
                ),
                // Description
                Expanded(
                  child: Text(
                    item['description'] ?? '',
                    style: const TextStyle(fontSize: 14),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // Amount
                SizedBox(
                  width: 75,
                  child: Text(
                    '\$${item['price'] ?? '0.00'}',
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                // Delete button
                SizedBox(
                  width: 32,
                  child: IconButton(
                    icon: const Icon(Icons.close, size: 16),
                    onPressed: () => _removeItem(index),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    tooltip: 'Remove item',
                  ),
                ),
              ],
            ),
          ),
          if (index < _savedItems.length - 1)
            Divider(height: 1, color: Colors.grey[300]),
        ],
      );
    });
  }

  void _saveExpense() {
    if (_formKey.currentState!.validate()) {
      // Calculate total amount from items
      final totalAmount = _calculateTotal();

      // Create expense data
      final expenseData = {
        'title': _titleController.text,
        'amount': totalAmount,
        'date': _selectedDate,
        'items': _savedItems,
        'merchant': _extractedData['merchant'],
        'notes': _notesController.text,
        'category': _selectedCategory,
      };

      // Navigate to confirmation/saved screen
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ExpenseSavedScreen(expenseData: expenseData),
        ),
      ).then((_) {
        _resetForm();
      });
    }
  }

  void _resetForm() {
    _formKey.currentState?.reset();
    _titleController.clear();
    _amountController.clear();
    _dateController.text = DateFormat('MMM dd, yyyy').format(DateTime.now());
    _notesController.clear();
    _itemDescController.clear();
    _itemPriceController.clear();
    setState(() {
      _receiptImage = null;
      _selectedDate = DateTime.now();
      _selectedCategory = AppConstants.expenseCategories[0];
      _isOcrProcessed = false;
      _ocrItems = [];
      _savedItems = [];
      _showAddItemForm = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Expense'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _resetForm,
            tooltip: 'Reset Form',
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            // Title Field (Only field before receipt)
            CustomTextField(
              controller: _titleController,
              labelText: 'Expense Title',
              hintText: 'e.g., Repair Service, Equipment',
              prefixIcon: Icons.title,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a title';
                }
                return null;
              },
            ),

            const SizedBox(height: 24),
            // Receipt Image Upload
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Title with OCR badge on separate row
                    Row(
                      children: [
                        const Icon(Icons.receipt_long),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Receipt Image',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    // OCR Processed badge on its own row for full width
                    if (_isOcrProcessed) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green[100],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.check_circle,
                              size: 18,
                              color: Colors.green[700],
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'OCR Processed',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.green[700],
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    if (_receiptImage != null) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(
                          _receiptImage!,
                          height: 200,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Action Buttons - Vertical Layout
                      Column(
                        children: [
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () => _pickImage(ImageSource.camera),
                              icon: const Icon(Icons.camera_alt),
                              label: const Text(
                                'Retake Photo',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () => _pickImage(ImageSource.gallery),
                              icon: const Icon(Icons.photo_library),
                              label: const Text(
                                'Choose from Gallery',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                              ),
                            ),
                          ),
                          if (!_isOcrProcessed) ...[
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: _processOcr,
                                icon: const Icon(Icons.document_scanner),
                                label: const Text(
                                  'Scan Receipt',
                                  style: TextStyle(fontWeight: FontWeight.w600),
                                ),
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  backgroundColor: Colors.green,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ] else ...[
                      Column(
                        children: [
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () => _pickImage(ImageSource.camera),
                              icon: const Icon(Icons.camera_alt),
                              label: const Text(
                                'Take Photo',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 16,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () => _pickImage(ImageSource.gallery),
                              icon: const Icon(Icons.photo_library),
                              label: const Text(
                                'Choose from Gallery',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 16,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Professional Receipt Design
            if (_ocrItems.isNotEmpty) ...[
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.receipt_long, color: Colors.blue),
                          const SizedBox(width: 8),
                          Text(
                            'Extracted Items (${_ocrItems.length})',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue[700],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Divider(),
                      const SizedBox(height: 12),
                      ..._ocrItems.asMap().entries.map((e) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: Colors.blue[100],
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    '${e.key + 1}',
                                    style: TextStyle(
                                      color: Colors.blue[700],
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  e.value,
                                  style: const TextStyle(fontSize: 14),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Professional Receipt Design
            if (_extractedData.isNotEmpty || _savedItems.isNotEmpty) ...[
              const SizedBox(height: 24),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    // Receipt Header
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(8),
                          topRight: Radius.circular(8),
                        ),
                        border: Border(
                          bottom: BorderSide(color: Colors.grey[300]!),
                        ),
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            (_extractedData['merchant'] ?? '').isNotEmpty
                                ? _extractedData['merchant']!
                                : (_titleController.text.isNotEmpty
                                      ? _titleController.text
                                      : 'Receipt'),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (_extractedData['date'] != null)
                            Text(
                              'Date: ${_extractedData['date']}',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[700],
                              ),
                            ),
                        ],
                      ),
                    ),

                    // Items Table Header
                    if (_savedItems.isNotEmpty)
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          border: Border(
                            bottom: BorderSide(color: Colors.grey[300]!),
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 40,
                              child: Text(
                                'QTY',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: Colors.grey[700],
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                'DESCRIPTION',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: Colors.grey[700],
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 90,
                              child: Text(
                                'AMOUNT',
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: Colors.grey[700],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Items List
                    if (_savedItems.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'No items extracted. Add items manually below.',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                      )
                    else
                      ..._buildItemRows(),

                    // Divider before totals
                    if (_savedItems.isNotEmpty)
                      Container(height: 1, color: Colors.grey[300]),

                    // Totals Section
                    if (_savedItems.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Subtotal',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[700],
                                  ),
                                ),
                                Text(
                                  '\$${_calculateTotal().toStringAsFixed(2)}',
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Total',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  '\$${_calculateTotal().toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
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
            ],

            // Manual Item Addition Section
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Add Items Manually',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            _showAddItemForm
                                ? Icons.expand_less
                                : Icons.expand_more,
                          ),
                          onPressed: () {
                            setState(() {
                              _showAddItemForm = !_showAddItemForm;
                            });
                          },
                        ),
                      ],
                    ),
                    if (_showAddItemForm) ...[
                      const SizedBox(height: 16),
                      CustomTextField(
                        controller: _itemDescController,
                        labelText: 'Item Description',
                        hintText: 'e.g., Service Charge',
                        prefixIcon: Icons.label_outline,
                      ),
                      const SizedBox(height: 12),
                      CustomTextField(
                        controller: _itemPriceController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        labelText: 'Price',
                        hintText: 'e.g., 50.00',
                        prefixIcon: Icons.attach_money,
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _addItem,
                          icon: const Icon(Icons.add),
                          label: const Text('Add Item'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Notes
            CustomTextField(
              controller: _notesController,
              labelText: 'Notes (Optional)',
              hintText: 'Add any additional notes',
              prefixIcon: Icons.note,
              maxLines: 3,
            ),

            const SizedBox(height: 24),

            // Save Button
            SizedBox(
              height: 56,
              child: ElevatedButton.icon(
                onPressed: _saveExpense,
                icon: const Icon(Icons.save),
                label: const Text(
                  'Save Expense',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _OcrProcessingDialog extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<ExpenseProvider>(
      builder: (context, provider, child) {
        return AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 16),
              const CircularProgressIndicator(),
              const SizedBox(height: 24),
              const Text(
                'Processing Receipt...',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              LinearProgressIndicator(
                value: provider.ocrProgress,
                backgroundColor: Colors.grey[300],
              ),
              const SizedBox(height: 8),
              Text(
                '${(provider.ocrProgress * 100).toInt()}%',
                style: TextStyle(color: Colors.grey[600]),
              ),
              const SizedBox(height: 16),
              Text(
                'Extracting amount, date, and merchant...',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600], fontSize: 14),
              ),
            ],
          ),
        );
      },
    );
  }
}

class ExpenseSavedScreen extends StatelessWidget {
  final Map<String, dynamic> expenseData;

  const ExpenseSavedScreen({super.key, required this.expenseData});

  @override
  Widget build(BuildContext context) {
    final items = expenseData['items'] as List<Map<String, String>>?;
    final totalAmount = expenseData['amount'] as double?;
    final savedDate = DateTime.now();

    return Scaffold(
      appBar: AppBar(title: const Text('Expense Saved'), elevation: 0),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Success Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.green[700]!, Colors.green[500]!],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                children: [
                  Icon(Icons.check_circle, size: 64, color: Colors.green[100]),
                  const SizedBox(height: 16),
                  const Text(
                    'Expense Saved Successfully!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),

            // Expense Details Card
            Padding(
              padding: const EdgeInsets.all(16),
              child: Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title
                      Row(
                        children: [
                          const Icon(Icons.receipt_long, color: Colors.blue),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Title',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  expenseData['title'] ?? 'N/A',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),
                      const Divider(),
                      const SizedBox(height: 20),

                      // Amount
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Total Amount',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[700],
                            ),
                          ),
                          Text(
                            '\$${(totalAmount ?? 0).toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Date Saved
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Saved Date',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[700],
                            ),
                          ),
                          Text(
                            DateFormat(
                              'MMM dd, yyyy - hh:mm a',
                            ).format(savedDate),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),

                      if (expenseData['merchant'] != null &&
                          expenseData['merchant'].isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Merchant',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[700],
                              ),
                            ),
                            Text(
                              expenseData['merchant'] ?? 'N/A',
                              style: const TextStyle(fontSize: 14),
                            ),
                          ],
                        ),
                      ],

                      if (expenseData['notes'] != null &&
                          expenseData['notes'].isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Text(
                          'Notes',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[700],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          expenseData['notes'],
                          style: const TextStyle(fontSize: 14),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),

            // Items Section
            if (items != null && items.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Items',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ...items.asMap().entries.map((e) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              children: [
                                Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: Colors.blue[100],
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Text(
                                      '${e.key + 1}',
                                      style: TextStyle(
                                        color: Colors.blue[700],
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    e.value['description'] ?? '',
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                ),
                                Text(
                                  '\$${e.value['price'] ?? '0.00'}',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ),
              ),

            // Buttons
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.add),
                      label: const Text('Add Another Expense'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.pop(context);
                      },
                      icon: const Icon(Icons.home),
                      label: const Text('Back to Home'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
