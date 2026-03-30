class Transaction {
  final String id, type, status, amount, fee, currency, reference, createdAt;
  final String? description, completedAt;

  Transaction({required this.id, required this.type, required this.status, required this.amount,
    required this.fee, required this.currency, required this.reference, required this.createdAt,
    this.description, this.completedAt});

  factory Transaction.fromJson(Map<String, dynamic> json) => Transaction(
    id: json['id'] ?? '', type: json['type'] ?? '', status: json['status'] ?? '',
    amount: json['amount']?.toString() ?? '0.00', fee: json['fee']?.toString() ?? '0.00',
    currency: json['currency'] ?? 'TZS', reference: json['reference'] ?? '',
    createdAt: json['created_at'] ?? '', description: json['description'],
    completedAt: json['completed_at'],
  );
}
