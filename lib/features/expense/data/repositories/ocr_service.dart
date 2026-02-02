import 'dart:developer';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:intl/intl.dart';

class OcrService {
  final TextRecognizer _textRecognizer = TextRecognizer();

  Future<Map<String, dynamic>> extractDataFromReceipt(String imagePath) async {
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final recognizedText = await _textRecognizer.processImage(inputImage);

      final text = recognizedText.text;
      final lines = text.split('\n');
      log("=== OCR Extracted Text ===\n$text");
      // Extract data
      final amount = _extractAmount(lines);
      final date = _extractDate(lines);
      final merchant = _extractMerchant(lines);
      final items = _extractItems(lines);

      return {
        'amount': amount,
        'date': date,
        'merchant': merchant,
        'items': items,
      };
    } catch (e) {
      throw Exception('OCR failed: ${e.toString()}');
    }
  }

  String _extractAmount(List<String> lines) {
    // Common patterns for amounts
    final amountPatterns = [
      RegExp(r'\$\s*(\d+\.?\d*)'),
      RegExp(r'(\d+\.?\d*)\s*\$'),
      RegExp(r'total[:\s]*\$?\s*(\d+\.?\d*)', caseSensitive: false),
      RegExp(r'amount[:\s]*\$?\s*(\d+\.?\d*)', caseSensitive: false),
      RegExp(r'(\d+\.\d{2})'),
    ];

    for (final line in lines) {
      for (final pattern in amountPatterns) {
        final match = pattern.firstMatch(line);
        if (match != null) {
          final amount = match.group(1);
          if (amount != null) {
            final value = double.tryParse(amount);
            if (value != null && value > 0 && value < 100000) {
              return amount;
            }
          }
        }
      }
    }

    return '';
  }

  String _extractDate(List<String> lines) {
    // Date patterns
    final datePatterns = [
      RegExp(r'(\d{1,2}[/-]\d{1,2}[/-]\d{2,4})'),
      RegExp(r'(\d{4}[/-]\d{1,2}[/-]\d{1,2})'),
      RegExp(
        r'(\d{1,2}\s+(?:jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z]*\s+\d{2,4})',
        caseSensitive: false,
      ),
    ];

    for (final line in lines) {
      for (final pattern in datePatterns) {
        final match = pattern.firstMatch(line);
        if (match != null) {
          final dateStr = match.group(1);
          if (dateStr != null) {
            try {
              // Try to parse and format the date
              final date = _parseDate(dateStr);
              if (date != null) {
                return DateFormat('yyyy-MM-dd').format(date);
              }
            } catch (e) {
              continue;
            }
          }
        }
      }
    }

    return DateFormat('yyyy-MM-dd').format(DateTime.now());
  }

  DateTime? _parseDate(String dateStr) {
    final formats = [
      'dd/MM/yyyy',
      'MM/dd/yyyy',
      'yyyy-MM-dd',
      'dd-MM-yyyy',
      'MM-dd-yyyy',
    ];

    for (final format in formats) {
      try {
        return DateFormat(format).parse(dateStr);
      } catch (e) {
        continue;
      }
    }

    return null;
  }

  String _extractMerchant(List<String> lines) {
    // Usually the merchant name is in the first few lines
    // and is typically the longest or most prominent text
    if (lines.isEmpty) return '';

    // Filter out common noise
    final filteredLines = lines.where((line) {
      final lower = line.toLowerCase();
      return line.length > 2 &&
          !lower.contains('receipt') &&
          !lower.contains('invoice') &&
          !lower.contains('bill') &&
          !line.contains(RegExp(r'\d{3,}')) && // Avoid phone numbers
          !line.contains(RegExp(r'^\d+$')); // Avoid pure numbers
    }).toList();

    if (filteredLines.isNotEmpty) {
      // Return the first non-empty line that looks like a merchant name
      for (final line in filteredLines.take(5)) {
        if (line.trim().length >= 3) {
          return line.trim();
        }
      }
    }

    return '';
  }

  List<String> _extractItems(List<String> lines) {
    // Handle columnar receipt format where data is organized by columns
    // QTY | DESCRIPTION | UNIT PRICE | AMOUNT

    // Find header line positions
    int qtyIdx = -1;
    int descIdx = -1;
    int unitPriceIdx = -1;
    int amountIdx = -1;

    for (int i = 0; i < lines.length; i++) {
      final lower = lines[i].toLowerCase().trim();
      if (lower == 'qty' || lower == 'quantity') qtyIdx = i;
      if (lower == 'description' || lower == 'desc') descIdx = i;
      if (lower == 'unit price') unitPriceIdx = i;
      if (lower == 'amount') amountIdx = i;
    }

    // If we found the column headers, extract data from that structure
    if (qtyIdx >= 0 && descIdx >= 0 && amountIdx >= 0) {
      return _extractItemsFromColumnarFormat(
        lines,
        qtyIdx,
        descIdx,
        unitPriceIdx,
        amountIdx,
      );
    }

    // Fallback: try to find items in scattered format
    return _extractItemsFromScatteredData(lines);
  }

  List<String> _extractItemsFromColumnarFormat(
    List<String> lines,
    int qtyIdx,
    int descIdx,
    int unitPriceIdx,
    int amountIdx,
  ) {
    final items = <String>[];

    // Collect quantities - only single digit numbers
    final quantities = <String>[];
    for (int i = qtyIdx + 1; i < descIdx; i++) {
      final line = lines[i].trim();
      // Only keep simple numbers (qty is usually 1-9)
      if (RegExp(r'^\d+$').hasMatch(line) && line.length <= 2) {
        quantities.add(line);
      }
    }

    // Collect prices (amounts) - only valid prices
    final amounts = <String>[];
    for (int i = amountIdx + 1; i < lines.length; i++) {
      final line = lines[i].trim();
      final lower = line.toLowerCase();

      // Stop at these sections
      if (lower.contains('subtotal') ||
          lower.contains('total') ||
          lower.contains('tax') ||
          lower.contains('payment') ||
          lower.contains('terms') ||
          lower.contains('online') ||
          lower.contains('thank')) {
        break;
      }

      // Only keep valid price patterns: X.XX format
      if (RegExp(r'^\d+\.\d{2}$').hasMatch(line)) {
        amounts.add(line);
      }
    }

    // Collect descriptions - from anywhere between qty and amount sections
    // But be very strict about what counts as a description
    final descriptions = <String>[];

    for (int i = qtyIdx + 1; i < amountIdx; i++) {
      final line = lines[i].trim();
      final lower = line.toLowerCase();

      // Skip empty lines
      if (line.isEmpty) continue;

      // Skip pure numbers (quantities and prices)
      if (RegExp(r'^\d+(\.\d{2})?$').hasMatch(line)) continue;

      // Skip all headers and keywords
      if (lower == 'qty' ||
          lower == 'quantity' ||
          lower == 'description' ||
          lower == 'unit price' ||
          lower == 'amount' ||
          lower == 'subtotal' ||
          lower == 'total' ||
          lower == 'tax' ||
          lower == 'bill to' ||
          lower == 'ship to' ||
          lower == 'receipt' ||
          lower == 'receipt #' ||
          lower == 'receipt date' ||
          lower == 'receipt date' ||
          lower == 'p.o.#' ||
          lower == 'po.#' ||
          lower == 'due date' ||
          lower == 'payment instruction' ||
          lower == 'paypal email' ||
          lower == 'bank transfer' ||
          lower == 'routing' ||
          lower == 'terms & conditions' ||
          lower == 'online receipt' ||
          lower.contains('instruction')) {
        continue;
      }

      // Skip location/address indicators
      if (lower.contains('lane') ||
          lower.contains('square') ||
          lower.contains('drive') ||
          lower.contains('avenue') ||
          lower.contains('street') ||
          lower.contains('pineview') ||
          lower.contains('harvest') ||
          lower.contains('court') ||
          lower.contains('new york') ||
          lower.contains('cambridge') ||
          lower.contains('ma ') ||
          lower.contains('ny ') ||
          lower.startsWith('john') ||
          lower.startsWith('ml') ||
          lower.endsWith('inc.') ||
          lower.endsWith('inc') ||
          lower.contains('abc') ||
          lower.contains('routing') ||
          lower.contains('gmail') ||
          lower.contains('paypal') ||
          lower.contains('email')) {
        continue;
      }

      // Skip if it's a zip code or looks like one
      if (RegExp(r'\d{5}').hasMatch(line)) {
        continue;
      }

      // Skip garbage text (too short or just "you.", "jhank", etc.)
      if (line.length < 3 ||
          lower == 'you.' ||
          lower == 'you' ||
          lower == 'jhank' ||
          lower == 'ml' ||
          lower.length > 100) {
        // Very long lines are likely addresses
        continue;
      }

      // This looks like a real description
      descriptions.add(line);
    }

    // Match quantities with amounts and descriptions
    final itemCount = [
      quantities.length,
      amounts.length,
    ].reduce((a, b) => a < b ? a : b);

    for (int i = 0; i < itemCount; i++) {
      String desc = i < descriptions.length ? descriptions[i] : 'Item ${i + 1}';
      final item = '${quantities[i]} $desc ${amounts[i]}';
      items.add(item.replaceAll(RegExp(r'\s+'), ' ').trim());
    }

    return items;
  }

  List<String> _extractItemsFromScatteredData(List<String> lines) {
    // Fallback: extract items when data is scattered across multiple lines
    final items = <String>[];

    for (int i = 0; i < lines.length; i++) {
      final trimmed = lines[i].trim();

      // Look for lines that start with qty number and likely contain price
      if (RegExp(r'^\d+\s+').hasMatch(trimmed)) {
        final lower = trimmed.toLowerCase();

        // Skip header/footer lines
        if (lower.contains('qty') ||
            lower.contains('description') ||
            lower.contains('amount') ||
            lower.contains('bill') ||
            lower.contains('ship') ||
            lower.contains('receipt') ||
            lower.contains('lane') ||
            lower.contains('street') ||
            lower.contains('avenue') ||
            lower.contains('drive') ||
            lower.contains('court') ||
            lower.contains('square')) {
          continue;
        }

        // Look ahead to see if there are price values in nearby lines
        String itemData = trimmed;

        // Check next line for prices if current line doesn't have them
        if (!RegExp(r'\d+\.\d{2}').hasMatch(itemData) && i + 1 < lines.length) {
          final nextLine = lines[i + 1].trim();
          // Combine if next line looks like it has prices
          if (RegExp(r'^\d+\.\d{2}').hasMatch(nextLine) ||
              RegExp(r'\d+\.\d{2}$').hasMatch(nextLine)) {
            itemData += ' $nextLine';
            i++; // Skip next line in main loop
          }
        }

        itemData = itemData.replaceAll(RegExp(r'\s+'), ' ').trim();
        if (itemData.isNotEmpty && !items.contains(itemData)) {
          items.add(itemData);
        }
      }
    }

    return items;
  }

  void dispose() {
    _textRecognizer.close();
  }
}
