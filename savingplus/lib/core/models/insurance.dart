class InsuranceProduct {
  final String id, name, description, type, provider, status;
  final String premiumAmount, premiumFrequency, coverageAmount;

  InsuranceProduct({required this.id, required this.name, required this.description,
    required this.type, required this.provider, required this.status,
    required this.premiumAmount, required this.premiumFrequency, required this.coverageAmount});

  factory InsuranceProduct.fromJson(Map<String, dynamic> json) => InsuranceProduct(
    id: json['id'] ?? '', name: json['name'] ?? '', description: json['description'] ?? '',
    type: json['type'] ?? '', provider: json['provider'] ?? '', status: json['status'] ?? '',
    premiumAmount: json['premium_amount']?.toString() ?? '0',
    premiumFrequency: json['premium_frequency'] ?? '',
    coverageAmount: json['coverage_amount']?.toString() ?? '0',
  );
}

class InsurancePolicy {
  final String id, policyNumber, status, coverageStart, coverageEnd, createdAt;
  final String? productName, productType, premiumPaid, beneficiary;
  final bool autoRenew;

  InsurancePolicy({required this.id, required this.policyNumber, required this.status,
    required this.coverageStart, required this.coverageEnd, required this.createdAt,
    this.productName, this.productType, this.premiumPaid, this.beneficiary, this.autoRenew = true});

  factory InsurancePolicy.fromJson(Map<String, dynamic> json) => InsurancePolicy(
    id: json['id'] ?? '', policyNumber: json['policy_number'] ?? '',
    status: json['status'] ?? '', coverageStart: json['coverage_start'] ?? '',
    coverageEnd: json['coverage_end'] ?? '', createdAt: json['created_at'] ?? '',
    productName: json['product_name'], productType: json['product_type'],
    premiumPaid: json['premium_paid']?.toString(), beneficiary: json['beneficiary'],
    autoRenew: json['auto_renew'] ?? true,
  );
}
