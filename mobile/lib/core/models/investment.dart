class InvestmentProduct {
  final String id;
  final String name;
  final String type;
  final String currency;
  final String minAmount;
  final String expectedReturn;
  final String riskLevel;
  final String status;
  final String createdAt;
  final String? description;
  final String? maxAmount;
  final String? availablePool;
  final int? durationDays;

  InvestmentProduct({
    required this.id,
    required this.name,
    required this.type,
    required this.currency,
    required this.minAmount,
    required this.expectedReturn,
    required this.riskLevel,
    required this.status,
    required this.createdAt,
    this.description,
    this.maxAmount,
    this.availablePool,
    this.durationDays,
  });

  factory InvestmentProduct.fromJson(Map<String, dynamic> json) {
    return InvestmentProduct(
      id: json['id'] as String,
      name: json['name'] as String,
      type: json['type'] as String,
      currency: json['currency'] as String,
      minAmount: json['min_amount'] as String,
      expectedReturn: json['expected_return'] as String,
      riskLevel: json['risk_level'] as String,
      status: json['status'] as String,
      createdAt: json['created_at'] as String,
      description: json['description'] as String?,
      maxAmount: json['max_amount'] as String?,
      availablePool: json['available_pool'] as String?,
      durationDays: json['duration_days'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'currency': currency,
      'min_amount': minAmount,
      'expected_return': expectedReturn,
      'risk_level': riskLevel,
      'status': status,
      'created_at': createdAt,
      'description': description,
      'max_amount': maxAmount,
      'available_pool': availablePool,
      'duration_days': durationDays,
    };
  }
}

class Investment {
  final String id;
  final String productName;
  final String productType;
  final String amount;
  final String currency;
  final String status;
  final String createdAt;
  final String expectedReturn;
  final String? actualReturn;
  final String? maturityDate;

  Investment({
    required this.id,
    required this.productName,
    required this.productType,
    required this.amount,
    required this.currency,
    required this.status,
    required this.createdAt,
    required this.expectedReturn,
    this.actualReturn,
    this.maturityDate,
  });

  factory Investment.fromJson(Map<String, dynamic> json) {
    return Investment(
      id: json['id'] as String,
      productName: json['product_name'] as String,
      productType: json['product_type'] as String,
      amount: json['amount'] as String,
      currency: json['currency'] as String,
      status: json['status'] as String,
      createdAt: json['created_at'] as String,
      expectedReturn: json['expected_return'] as String,
      actualReturn: json['actual_return'] as String?,
      maturityDate: json['maturity_date'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'product_name': productName,
      'product_type': productType,
      'amount': amount,
      'currency': currency,
      'status': status,
      'created_at': createdAt,
      'expected_return': expectedReturn,
      'actual_return': actualReturn,
      'maturity_date': maturityDate,
    };
  }
}
