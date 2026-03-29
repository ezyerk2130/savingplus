class InsuranceProduct {
  final String id;
  final String name;
  final String type;
  final String provider;
  final String premiumAmount;
  final String premiumFrequency;
  final String coverageAmount;
  final String status;
  final String createdAt;
  final String? description;

  InsuranceProduct({
    required this.id,
    required this.name,
    required this.type,
    required this.provider,
    required this.premiumAmount,
    required this.premiumFrequency,
    required this.coverageAmount,
    required this.status,
    required this.createdAt,
    this.description,
  });

  factory InsuranceProduct.fromJson(Map<String, dynamic> json) {
    return InsuranceProduct(
      id: json['id'] as String,
      name: json['name'] as String,
      type: json['type'] as String,
      provider: json['provider'] as String,
      premiumAmount: json['premium_amount'] as String,
      premiumFrequency: json['premium_frequency'] as String,
      coverageAmount: json['coverage_amount'] as String,
      status: json['status'] as String,
      createdAt: json['created_at'] as String,
      description: json['description'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'provider': provider,
      'premium_amount': premiumAmount,
      'premium_frequency': premiumFrequency,
      'coverage_amount': coverageAmount,
      'status': status,
      'created_at': createdAt,
      'description': description,
    };
  }
}

class InsurancePolicy {
  final String id;
  final String productName;
  final String productType;
  final String policyNumber;
  final String status;
  final String coverageStart;
  final String coverageEnd;
  final String premiumPaid;
  final String createdAt;

  InsurancePolicy({
    required this.id,
    required this.productName,
    required this.productType,
    required this.policyNumber,
    required this.status,
    required this.coverageStart,
    required this.coverageEnd,
    required this.premiumPaid,
    required this.createdAt,
  });

  factory InsurancePolicy.fromJson(Map<String, dynamic> json) {
    return InsurancePolicy(
      id: json['id'] as String,
      productName: json['product_name'] as String,
      productType: json['product_type'] as String,
      policyNumber: json['policy_number'] as String,
      status: json['status'] as String,
      coverageStart: json['coverage_start'] as String,
      coverageEnd: json['coverage_end'] as String,
      premiumPaid: json['premium_paid'] as String,
      createdAt: json['created_at'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'product_name': productName,
      'product_type': productType,
      'policy_number': policyNumber,
      'status': status,
      'coverage_start': coverageStart,
      'coverage_end': coverageEnd,
      'premium_paid': premiumPaid,
      'created_at': createdAt,
    };
  }
}
