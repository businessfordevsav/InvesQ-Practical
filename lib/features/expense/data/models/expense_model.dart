class ExpenseModel {
  final String title;
  final double amount;
  final DateTime date;
  final String category;
  final String? receiptImagePath;
  final String? notes;

  ExpenseModel({
    required this.title,
    required this.amount,
    required this.date,
    required this.category,
    this.receiptImagePath,
    this.notes,
  });

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'amount': amount,
      'date': date.toIso8601String(),
      'category': category,
      'receiptImagePath': receiptImagePath,
      'notes': notes,
    };
  }
}
