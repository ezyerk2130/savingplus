class WalletBalance {
  final String walletId;
  final String currency;
  final String availableBalance;
  final String lockedBalance;
  final String totalBalance;

  WalletBalance({required this.walletId, required this.currency,
    required this.availableBalance, required this.lockedBalance, required this.totalBalance});

  factory WalletBalance.fromJson(Map<String, dynamic> json) => WalletBalance(
    walletId: json['wallet_id'] ?? '',
    currency: json['currency'] ?? 'TZS',
    availableBalance: json['available_balance'] ?? '0.00',
    lockedBalance: json['locked_balance'] ?? '0.00',
    totalBalance: json['total_balance'] ?? '0.00',
  );
}
