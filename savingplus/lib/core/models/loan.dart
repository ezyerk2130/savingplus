class Loan {
  final String id, loanNumber, type, principal, totalDue, amountPaid, status, dueDate, createdAt;
  final double interestRate;
  final int termDays;

  Loan({required this.id, required this.loanNumber, required this.type, required this.principal,
    required this.totalDue, required this.amountPaid, required this.status,
    required this.dueDate, required this.createdAt, required this.interestRate, required this.termDays});

  factory Loan.fromJson(Map<String, dynamic> json) => Loan(
    id: json['id'] ?? '', loanNumber: json['loan_number'] ?? '', type: json['type'] ?? '',
    principal: json['principal']?.toString() ?? '0', totalDue: json['total_due']?.toString() ?? '0',
    amountPaid: json['amount_paid']?.toString() ?? '0', status: json['status'] ?? '',
    dueDate: json['due_date'] ?? '', createdAt: json['created_at'] ?? '',
    interestRate: (json['interest_rate'] is num) ? (json['interest_rate'] as num).toDouble() : double.tryParse(json['interest_rate']?.toString() ?? '0') ?? 0,
    termDays: json['term_days'] ?? 0,
  );
}

class LoanEligibility {
  final bool eligible;
  final String maxLoanAmount, savingsBalance;
  final double interestRate;
  final int kycTier;

  LoanEligibility({required this.eligible, required this.maxLoanAmount,
    required this.savingsBalance, required this.interestRate, required this.kycTier});

  factory LoanEligibility.fromJson(Map<String, dynamic> json) => LoanEligibility(
    eligible: json['eligible'] ?? false,
    maxLoanAmount: json['max_loan_amount']?.toString() ?? '0',
    savingsBalance: json['savings_balance']?.toString() ?? '0',
    interestRate: (json['interest_rate'] is num) ? (json['interest_rate'] as num).toDouble() : double.tryParse(json['interest_rate']?.toString() ?? '0') ?? 0,
    kycTier: json['kyc_tier'] ?? 0,
  );
}
