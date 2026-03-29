class WalletBalance {
  final String walletId;
  final String currency;
  final String availableBalance;
  final String lockedBalance;
  final String totalBalance;

  WalletBalance({
    required this.walletId,
    required this.currency,
    required this.availableBalance,
    required this.lockedBalance,
    required this.totalBalance,
  });

  factory WalletBalance.fromJson(Map<String, dynamic> json) {
    return WalletBalance(
      walletId: json['wallet_id'] as String,
      currency: json['currency'] as String,
      availableBalance: json['available_balance'] as String,
      lockedBalance: json['locked_balance'] as String,
      totalBalance: json['total_balance'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'wallet_id': walletId,
      'currency': currency,
      'available_balance': availableBalance,
      'locked_balance': lockedBalance,
      'total_balance': totalBalance,
    };
  }
}
