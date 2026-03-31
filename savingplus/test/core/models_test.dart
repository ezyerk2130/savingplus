import 'package:flutter_test/flutter_test.dart';
import 'package:savingplus/core/models/user.dart';
import 'package:savingplus/core/models/wallet.dart';
import 'package:savingplus/core/models/transaction.dart';
import 'package:savingplus/core/models/savings_plan.dart';
import 'package:savingplus/core/models/investment.dart';
import 'package:savingplus/core/models/group.dart';
import 'package:savingplus/core/models/insurance.dart';
import 'package:savingplus/core/models/loan.dart';
import 'package:savingplus/core/models/content.dart';

void main() {
  group('User', () {
    test('fromJson parses correctly', () {
      final user = User.fromJson({
        'id': '123',
        'phone': '+255700000001',
        'full_name': 'John Doe',
        'email': 'john@example.com',
        'kyc_status': 'approved',
        'kyc_tier': 2,
        'status': 'active',
        'created_at': '2026-01-01T00:00:00Z',
      });
      expect(user.id, '123');
      expect(user.phone, '+255700000001');
      expect(user.fullName, 'John Doe');
      expect(user.email, 'john@example.com');
      expect(user.kycStatus, 'approved');
      expect(user.kycTier, 2);
      expect(user.status, 'active');
    });

    test('fromJson handles missing fields with defaults', () {
      final user = User.fromJson({});
      expect(user.id, '');
      expect(user.phone, '');
      expect(user.fullName, '');
      expect(user.kycStatus, 'pending');
      expect(user.kycTier, 0);
      expect(user.status, 'active');
      expect(user.email, isNull);
    });

    test('fromJson handles null email', () {
      final user = User.fromJson({
        'id': 'u1',
        'phone': '+255700000001',
        'full_name': 'Test',
        'email': null,
        'kyc_status': 'pending',
        'kyc_tier': 0,
        'status': 'active',
        'created_at': '',
      });
      expect(user.email, isNull);
    });
  });

  group('WalletBalance', () {
    test('fromJson parses correctly', () {
      final w = WalletBalance.fromJson({
        'wallet_id': 'w1',
        'currency': 'TZS',
        'available_balance': '50000.00',
        'locked_balance': '10000.00',
        'total_balance': '60000.00',
      });
      expect(w.walletId, 'w1');
      expect(w.currency, 'TZS');
      expect(w.availableBalance, '50000.00');
      expect(w.lockedBalance, '10000.00');
      expect(w.totalBalance, '60000.00');
    });

    test('fromJson handles missing fields', () {
      final w = WalletBalance.fromJson({});
      expect(w.walletId, '');
      expect(w.currency, 'TZS');
      expect(w.availableBalance, '0.00');
      expect(w.lockedBalance, '0.00');
      expect(w.totalBalance, '0.00');
    });
  });

  group('Transaction', () {
    test('fromJson parses amount as string', () {
      final t = Transaction.fromJson({
        'id': 't1',
        'type': 'deposit',
        'status': 'completed',
        'amount': 5000.00,
        'fee': 0,
        'currency': 'TZS',
        'reference': 'REF-001',
        'created_at': '2026-01-01',
      });
      expect(t.id, 't1');
      expect(t.amount, '5000.0');
      expect(t.fee, '0');
      expect(t.type, 'deposit');
      expect(t.status, 'completed');
      expect(t.currency, 'TZS');
      expect(t.reference, 'REF-001');
    });

    test('fromJson handles string amount', () {
      final t = Transaction.fromJson({
        'id': 't2',
        'type': 'withdrawal',
        'status': 'pending',
        'amount': '10000.00',
        'fee': '500.00',
        'currency': 'TZS',
        'reference': 'REF-002',
        'created_at': '2026-02-01',
        'description': 'Test withdrawal',
        'completed_at': '2026-02-02',
      });
      expect(t.amount, '10000.00');
      expect(t.fee, '500.00');
      expect(t.description, 'Test withdrawal');
      expect(t.completedAt, '2026-02-02');
    });

    test('fromJson handles missing optional fields', () {
      final t = Transaction.fromJson({
        'id': 't3',
        'type': 'deposit',
        'status': 'completed',
        'amount': '100',
        'fee': '0',
        'currency': 'TZS',
        'reference': 'REF-003',
        'created_at': '2026-01-01',
      });
      expect(t.description, isNull);
      expect(t.completedAt, isNull);
    });
  });

  group('SavingsPlan', () {
    test('fromJson parses auto_debit fields', () {
      final p = SavingsPlan.fromJson({
        'id': 'p1',
        'name': 'Emergency',
        'type': 'flexible',
        'status': 'active',
        'current_amount': '10000',
        'interest_rate': '0.04',
        'created_at': '2026-01-01',
        'auto_debit': true,
        'auto_debit_amount': '500',
        'auto_debit_frequency': 'daily',
      });
      expect(p.id, 'p1');
      expect(p.name, 'Emergency');
      expect(p.type, 'flexible');
      expect(p.autoDebit, true);
      expect(p.autoDebitAmount, '500');
      expect(p.autoDebitFrequency, 'daily');
    });

    test('fromJson handles missing optional fields', () {
      final p = SavingsPlan.fromJson({
        'id': 'p2',
        'name': 'Basic',
        'type': 'locked',
        'status': 'active',
        'current_amount': '0',
        'interest_rate': '0.06',
        'created_at': '2026-01-01',
      });
      expect(p.autoDebit, false);
      expect(p.autoDebitAmount, isNull);
      expect(p.autoDebitFrequency, isNull);
      expect(p.targetAmount, isNull);
      expect(p.lockDurationDays, isNull);
    });

    test('fromJson parses target plan fields', () {
      final p = SavingsPlan.fromJson({
        'id': 'p3',
        'name': 'Car Fund',
        'type': 'target',
        'status': 'active',
        'current_amount': '500000',
        'interest_rate': '0.05',
        'created_at': '2026-01-01',
        'target_amount': '5000000',
        'lock_duration_days': 365,
      });
      expect(p.targetAmount, '5000000');
      expect(p.lockDurationDays, 365);
    });
  });

  group('InvestmentProduct', () {
    test('fromJson parses all fields', () {
      final p = InvestmentProduct.fromJson({
        'id': 'ip1',
        'name': 'T-Bill',
        'description': 'Treasury bill investment',
        'type': 'treasury_bill',
        'currency': 'TZS',
        'risk_level': 'low',
        'status': 'active',
        'min_amount': 100000,
        'expected_return': 10.5,
        'max_amount': 50000000,
        'duration_days': 91,
      });
      expect(p.id, 'ip1');
      expect(p.name, 'T-Bill');
      expect(p.riskLevel, 'low');
      expect(p.minAmount, '100000');
      expect(p.expectedReturn, '10.5');
      expect(p.maxAmount, '50000000');
      expect(p.durationDays, 91);
    });

    test('fromJson handles optional fields as null', () {
      final p = InvestmentProduct.fromJson({
        'id': 'ip2',
        'name': 'Fund',
        'description': 'desc',
        'type': 'mutual_fund',
        'currency': 'TZS',
        'risk_level': 'medium',
        'status': 'active',
        'min_amount': 50000,
        'expected_return': 8.0,
      });
      expect(p.maxAmount, isNull);
      expect(p.durationDays, isNull);
    });
  });

  group('Investment', () {
    test('fromJson parses correctly', () {
      final inv = Investment.fromJson({
        'id': 'inv1',
        'amount': 500000,
        'currency': 'TZS',
        'status': 'active',
        'created_at': '2026-01-01',
        'expected_return': 10.5,
        'product_name': 'T-Bill Q1',
        'product_type': 'treasury_bill',
      });
      expect(inv.id, 'inv1');
      expect(inv.amount, '500000');
      expect(inv.expectedReturn, 10.5);
      expect(inv.productName, 'T-Bill Q1');
    });
  });

  group('SavingsGroup', () {
    test('fromJson parses contribution fields', () {
      final g = SavingsGroup.fromJson({
        'id': 'g1',
        'name': 'Mama Savings',
        'type': 'upatu',
        'contribution_amount': 5000,
        'frequency': 'weekly',
        'status': 'active',
        'created_at': '2026-01-01',
        'max_members': 8,
        'current_round': 3,
      });
      expect(g.id, 'g1');
      expect(g.name, 'Mama Savings');
      expect(g.type, 'upatu');
      expect(g.contributionAmount, '5000');
      expect(g.frequency, 'weekly');
      expect(g.maxMembers, 8);
      expect(g.currentRound, 3);
    });

    test('fromJson handles missing optional fields', () {
      final g = SavingsGroup.fromJson({
        'id': 'g2',
        'name': 'Group',
        'type': 'goal',
        'contribution_amount': '1000',
        'frequency': 'monthly',
        'status': 'active',
        'created_at': '2026-01-01',
        'max_members': 5,
        'current_round': 0,
      });
      expect(g.description, isNull);
      expect(g.currency, isNull);
    });
  });

  group('InsuranceProduct', () {
    test('fromJson parses correctly', () {
      final ip = InsuranceProduct.fromJson({
        'id': 'ins1',
        'name': 'Health Cover',
        'description': 'Basic health insurance',
        'type': 'health',
        'provider': 'NIC Insurance',
        'status': 'active',
        'premium_amount': 25000,
        'premium_frequency': 'monthly',
        'coverage_amount': 5000000,
      });
      expect(ip.id, 'ins1');
      expect(ip.name, 'Health Cover');
      expect(ip.premiumAmount, '25000');
      expect(ip.premiumFrequency, 'monthly');
      expect(ip.coverageAmount, '5000000');
    });
  });

  group('InsurancePolicy', () {
    test('fromJson parses correctly', () {
      final pol = InsurancePolicy.fromJson({
        'id': 'pol1',
        'policy_number': 'POL-001',
        'status': 'active',
        'coverage_start': '2026-01-01',
        'coverage_end': '2027-01-01',
        'created_at': '2026-01-01',
        'product_name': 'Health Cover',
        'product_type': 'health',
        'premium_paid': '25000',
        'beneficiary': 'Jane Doe',
        'auto_renew': false,
      });
      expect(pol.policyNumber, 'POL-001');
      expect(pol.autoRenew, false);
      expect(pol.beneficiary, 'Jane Doe');
    });

    test('fromJson defaults auto_renew to true', () {
      final pol = InsurancePolicy.fromJson({
        'id': 'pol2',
        'policy_number': 'POL-002',
        'status': 'active',
        'coverage_start': '2026-01-01',
        'coverage_end': '2027-01-01',
        'created_at': '2026-01-01',
      });
      expect(pol.autoRenew, true);
    });
  });

  group('Loan', () {
    test('fromJson parses interest rate and term', () {
      final l = Loan.fromJson({
        'id': 'l1',
        'loan_number': 'LN-001',
        'type': 'savings_backed',
        'principal': '50000',
        'total_due': '52000',
        'amount_paid': '0',
        'status': 'pending',
        'due_date': '2026-04-01',
        'created_at': '2026-01-01',
        'interest_rate': 9.0,
        'term_days': 30,
      });
      expect(l.id, 'l1');
      expect(l.loanNumber, 'LN-001');
      expect(l.interestRate, 9.0);
      expect(l.termDays, 30);
      expect(l.principal, '50000');
      expect(l.totalDue, '52000');
      expect(l.amountPaid, '0');
    });

    test('fromJson handles string interest rate', () {
      final l = Loan.fromJson({
        'id': 'l2',
        'loan_number': 'LN-002',
        'type': 'personal',
        'principal': '100000',
        'total_due': '110000',
        'amount_paid': '50000',
        'status': 'active',
        'due_date': '2026-06-01',
        'created_at': '2026-03-01',
        'interest_rate': '12.5',
        'term_days': 90,
      });
      expect(l.interestRate, 12.5);
    });

    test('fromJson handles missing fields', () {
      final l = Loan.fromJson({});
      expect(l.id, '');
      expect(l.interestRate, 0);
      expect(l.termDays, 0);
    });
  });

  group('LoanEligibility', () {
    test('fromJson parses correctly', () {
      final e = LoanEligibility.fromJson({
        'eligible': true,
        'max_loan_amount': 500000,
        'savings_balance': 1000000,
        'interest_rate': 9.0,
        'kyc_tier': 2,
      });
      expect(e.eligible, true);
      expect(e.maxLoanAmount, '500000');
      expect(e.interestRate, 9.0);
      expect(e.kycTier, 2);
    });
  });

  group('ContentArticle', () {
    test('fromJson parses read_time_min', () {
      final a = ContentArticle.fromJson({
        'id': 'a1',
        'title': 'Saving Tips',
        'body': 'content here',
        'category': 'saving',
        'created_at': '2026-01-01',
        'read_time_min': 5,
      });
      expect(a.id, 'a1');
      expect(a.title, 'Saving Tips');
      expect(a.readTimeMin, 5);
      expect(a.imageUrl, isNull);
    });

    test('fromJson defaults read_time_min to 3', () {
      final a = ContentArticle.fromJson({
        'id': 'a2',
        'title': 'Test',
        'body': 'body',
        'category': 'investing',
        'created_at': '2026-01-01',
      });
      expect(a.readTimeMin, 3);
    });

    test('fromJson parses imageUrl', () {
      final a = ContentArticle.fromJson({
        'id': 'a3',
        'title': 'With Image',
        'body': 'body',
        'category': 'tips',
        'created_at': '2026-01-01',
        'read_time_min': 2,
        'image_url': 'https://example.com/img.jpg',
      });
      expect(a.imageUrl, 'https://example.com/img.jpg');
    });
  });
}
