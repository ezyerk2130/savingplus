class User {
  final String id;
  final String phone;
  final String? email;
  final String fullName;
  final String kycStatus;
  final int kycTier;
  final String status;
  final String createdAt;

  User({required this.id, required this.phone, this.email, required this.fullName,
    required this.kycStatus, required this.kycTier, required this.status, required this.createdAt});

  factory User.fromJson(Map<String, dynamic> json) => User(
    id: json['id'] ?? '',
    phone: json['phone'] ?? '',
    email: json['email'],
    fullName: json['full_name'] ?? '',
    kycStatus: json['kyc_status'] ?? 'pending',
    kycTier: json['kyc_tier'] ?? 0,
    status: json['status'] ?? 'active',
    createdAt: json['created_at'] ?? '',
  );
}
