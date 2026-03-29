class User {
  final String id;
  final String phone;
  final String fullName;
  final String kycStatus;
  final String status;
  final String createdAt;
  final String? email;
  final int kycTier;

  User({
    required this.id,
    required this.phone,
    required this.fullName,
    required this.kycStatus,
    required this.status,
    required this.createdAt,
    this.email,
    required this.kycTier,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      phone: json['phone'] as String,
      fullName: json['full_name'] as String,
      kycStatus: json['kyc_status'] as String,
      status: json['status'] as String,
      createdAt: json['created_at'] as String,
      email: json['email'] as String?,
      kycTier: json['kyc_tier'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'phone': phone,
      'full_name': fullName,
      'kyc_status': kycStatus,
      'status': status,
      'created_at': createdAt,
      'email': email,
      'kyc_tier': kycTier,
    };
  }
}
