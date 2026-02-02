import 'package:flutter/material.dart';
import 'package:invesq_practical/features/expense/data/repositories/ocr_service.dart';

enum OcrState { initial, processing, success, error }

class ExpenseProvider with ChangeNotifier {
  final OcrService _ocrService = OcrService();

  OcrState _state = OcrState.initial;
  String? _errorMessage;
  double _ocrProgress = 0.0;

  OcrState get state => _state;
  String? get errorMessage => _errorMessage;
  double get ocrProgress => _ocrProgress;

  Future<Map<String, dynamic>> processReceipt(String imagePath) async {
    try {
      _state = OcrState.processing;
      _ocrProgress = 0.0;
      _errorMessage = null;
      notifyListeners();

      // Simulate progress
      _updateProgress(0.3);
      await Future.delayed(const Duration(milliseconds: 500));

      final result = await _ocrService.extractDataFromReceipt(imagePath);

      _updateProgress(0.9);
      await Future.delayed(const Duration(milliseconds: 300));

      _updateProgress(1.0);
      _state = OcrState.success;
      notifyListeners();

      return result;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _state = OcrState.error;
      notifyListeners();
      return {};
    }
  }

  void _updateProgress(double progress) {
    _ocrProgress = progress;
    notifyListeners();
  }

  void reset() {
    _state = OcrState.initial;
    _ocrProgress = 0.0;
    _errorMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _ocrService.dispose();
    super.dispose();
  }
}
