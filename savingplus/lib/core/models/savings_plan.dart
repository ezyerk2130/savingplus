class SavingsPlan {
  final String id, name, type, status, currentAmount, interestRate, createdAt;
  final String? targetAmount, maturityDate, autoDebitAmount, autoDebitFrequency, currency;
  final int? lockDurationDays;
  final bool autoDebit;

  SavingsPlan({required this.id, required this.name, required this.type, required this.status,
    required this.currentAmount, required this.interestRate, required this.createdAt,
    this.targetAmount, this.maturityDate, this.autoDebitAmount, this.autoDebitFrequency,
    this.currency, this.lockDurationDays, this.autoDebit = false});

  factory SavingsPlan.fromJson(Map<String, dynamic> json) => SavingsPlan(
    id: json['id'] ?? '', name: json['name'] ?? '', type: json['type'] ?? '',
    status: json['status'] ?? '', currentAmount: json['current_amount']?.toString() ?? '0.00',
    interestRate: json['interest_rate']?.toString() ?? '0', createdAt: json['created_at'] ?? '',
    targetAmount: json['target_amount']?.toString(), maturityDate: json['maturity_date'],
    autoDebitAmount: json['auto_debit_amount']?.toString(), autoDebitFrequency: json['auto_debit_frequency'],
    currency: json['currency'], lockDurationDays: json['lock_duration_days'],
    autoDebit: json['auto_debit'] ?? false,
  );
}
