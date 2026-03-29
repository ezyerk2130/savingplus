class Loan {
  final String id;
  final String loanNumber;
  final String type;
  final String principal;
  final String totalDue;
  final String amountPaid;
  final String status;
  final String dueDate;
  final String createdAt;
  final String interestRate;
  final String currency;
  final int termDays;

  Loan({
    required this.id,
    required this.loanNumber,
    required this.type,
    required this.principal,
    required this.totalDue,
    required this.amountPaid,
    required this.status,
    required this.dueDate,
    required this.createdAt,
    required this.interestRate,
    required this.currency,
    required this.termDays,
  });

  factory Loan.fromJson(Map<String, dynamic> json) {
    return Loan(
      id: json['id'] as String,
      loanNumber: json['loan_number'] as String,
      type: json['type'] as String,
      principal: json['principal'] as String,
      totalDue: json['total_due'] as String,
      amountPaid: json['amount_paid'] as String,
      status: json['status'] as String,
      dueDate: json['due_date'] as String,
      createdAt: json['created_at'] as String,
      interestRate: json['interest_rate'] as String,
      currency: json['currency'] as String,
      termDays: json['term_days'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'loan_number': loanNumber,
      'type': type,
      'principal': principal,
      'total_due': totalDue,
      'amount_paid': amountPaid,
      'status': status,
      'due_date': dueDate,
      'created_at': createdAt,
      'interest_rate': interestRate,
      'currency': currency,
      'term_days': termDays,
    };
  }
}

class LoanEligibility {
  final String maxLoanAmount;
  final String interestRate;
  final String savingsBalance;
  final int kycTier;
  final bool eligible;
  final int activeLoans;

  LoanEligibility({
    required this.maxLoanAmount,
    required this.interestRate,
    required this.savingsBalance,
    required this.kycTier,
    required this.eligible,
    required this.activeLoans,
  });

  factory LoanEligibility.fromJson(Map<String, dynamic> json) {
    return LoanEligibility(
      maxLoanAmount: json['max_loan_amount'] as String,
      interestRate: json['interest_rate'] as String,
      savingsBalance: json['savings_balance'] as String,
      kycTier: json['kyc_tier'] as int,
      eligible: json['eligible'] as bool,
      activeLoans: json['active_loans'] as int,
    );
  }
}
