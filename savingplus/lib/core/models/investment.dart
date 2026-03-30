class InvestmentProduct {
  final String id, name, description, type, currency, riskLevel, status;
  final String minAmount, expectedReturn;
  final String? maxAmount;
  final int? durationDays;

  InvestmentProduct({required this.id, required this.name, required this.description,
    required this.type, required this.currency, required this.riskLevel, required this.status,
    required this.minAmount, required this.expectedReturn, this.maxAmount, this.durationDays});

  factory InvestmentProduct.fromJson(Map<String, dynamic> json) => InvestmentProduct(
    id: json['id'] ?? '', name: json['name'] ?? '', description: json['description'] ?? '',
    type: json['type'] ?? '', currency: json['currency'] ?? 'TZS',
    riskLevel: json['risk_level'] ?? 'low', status: json['status'] ?? '',
    minAmount: json['min_amount']?.toString() ?? '0', expectedReturn: json['expected_return']?.toString() ?? '0',
    maxAmount: json['max_amount']?.toString(), durationDays: json['duration_days'],
  );
}

class Investment {
  final String id, amount, currency, status, createdAt;
  final String? productName, productType, actualReturn, maturityDate;
  final double expectedReturn;

  Investment({required this.id, required this.amount, required this.currency, required this.status,
    required this.createdAt, required this.expectedReturn, this.productName, this.productType,
    this.actualReturn, this.maturityDate});

  factory Investment.fromJson(Map<String, dynamic> json) => Investment(
    id: json['id'] ?? '', amount: json['amount']?.toString() ?? '0',
    currency: json['currency'] ?? 'TZS', status: json['status'] ?? '',
    createdAt: json['created_at'] ?? '',
    expectedReturn: (json['expected_return'] is num) ? (json['expected_return'] as num).toDouble() : double.tryParse(json['expected_return']?.toString() ?? '0') ?? 0,
    productName: json['product_name'], productType: json['product_type'],
    actualReturn: json['actual_return']?.toString(), maturityDate: json['maturity_date'],
  );
}
