class SavingsGroup {
  final String id;
  final String name;
  final String type;
  final String contributionAmount;
  final String frequency;
  final String status;
  final String createdAt;
  final String? description;
  final String? currency;
  final int maxMembers;
  final int currentRound;

  SavingsGroup({
    required this.id,
    required this.name,
    required this.type,
    required this.contributionAmount,
    required this.frequency,
    required this.status,
    required this.createdAt,
    this.description,
    this.currency,
    required this.maxMembers,
    required this.currentRound,
  });

  factory SavingsGroup.fromJson(Map<String, dynamic> json) {
    return SavingsGroup(
      id: json['id'] as String,
      name: json['name'] as String,
      type: json['type'] as String,
      contributionAmount: json['contribution_amount'] as String,
      frequency: json['frequency'] as String,
      status: json['status'] as String,
      createdAt: json['created_at'] as String,
      description: json['description'] as String?,
      currency: json['currency'] as String?,
      maxMembers: json['max_members'] as int,
      currentRound: json['current_round'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'contribution_amount': contributionAmount,
      'frequency': frequency,
      'status': status,
      'created_at': createdAt,
      'description': description,
      'currency': currency,
      'max_members': maxMembers,
      'current_round': currentRound,
    };
  }
}
