class SavingsPlan {
  final String id;
  final String name;
  final String type;
  final String status;
  final String currentAmount;
  final String interestRate;
  final String createdAt;
  final String? targetAmount;
  final String? maturityDate;
  final String? autoDebitAmount;
  final String? autoDebitFrequency;
  final int? lockDurationDays;
  final bool autoDebit;

  SavingsPlan({
    required this.id,
    required this.name,
    required this.type,
    required this.status,
    required this.currentAmount,
    required this.interestRate,
    required this.createdAt,
    this.targetAmount,
    this.maturityDate,
    this.autoDebitAmount,
    this.autoDebitFrequency,
    this.lockDurationDays,
    required this.autoDebit,
  });

  factory SavingsPlan.fromJson(Map<String, dynamic> json) {
    return SavingsPlan(
      id: json['id'] as String,
      name: json['name'] as String,
      type: json['type'] as String,
      status: json['status'] as String,
      currentAmount: json['current_amount'] as String,
      interestRate: json['interest_rate'] as String,
      createdAt: json['created_at'] as String,
      targetAmount: json['target_amount'] as String?,
      maturityDate: json['maturity_date'] as String?,
      autoDebitAmount: json['auto_debit_amount'] as String?,
      autoDebitFrequency: json['auto_debit_frequency'] as String?,
      lockDurationDays: json['lock_duration_days'] as int?,
      autoDebit: json['auto_debit'] as bool,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'status': status,
      'current_amount': currentAmount,
      'interest_rate': interestRate,
      'created_at': createdAt,
      'target_amount': targetAmount,
      'maturity_date': maturityDate,
      'auto_debit_amount': autoDebitAmount,
      'auto_debit_frequency': autoDebitFrequency,
      'lock_duration_days': lockDurationDays,
      'auto_debit': autoDebit,
    };
  }
}
