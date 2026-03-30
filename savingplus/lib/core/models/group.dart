class SavingsGroup {
  final String id, name, type, frequency, status, createdAt;
  final String contributionAmount;
  final String? description, currency;
  final int maxMembers, currentRound;

  SavingsGroup({required this.id, required this.name, required this.type,
    required this.contributionAmount, required this.frequency, required this.status,
    required this.createdAt, required this.maxMembers, required this.currentRound,
    this.description, this.currency});

  factory SavingsGroup.fromJson(Map<String, dynamic> json) => SavingsGroup(
    id: json['id'] ?? '', name: json['name'] ?? '', type: json['type'] ?? '',
    contributionAmount: json['contribution_amount']?.toString() ?? '0',
    frequency: json['frequency'] ?? '', status: json['status'] ?? '',
    createdAt: json['created_at'] ?? '', maxMembers: json['max_members'] ?? 0,
    currentRound: json['current_round'] ?? 0, description: json['description'],
    currency: json['currency'],
  );
}
