class Transaction {
  final String id;
  final String type;
  final String status;
  final String amount;
  final String fee;
  final String currency;
  final String reference;
  final String createdAt;
  final String? description;
  final String? completedAt;

  Transaction({
    required this.id,
    required this.type,
    required this.status,
    required this.amount,
    required this.fee,
    required this.currency,
    required this.reference,
    required this.createdAt,
    this.description,
    this.completedAt,
  });

  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      id: json['id'] as String,
      type: json['type'] as String,
      status: json['status'] as String,
      amount: json['amount'] as String,
      fee: json['fee'] as String,
      currency: json['currency'] as String,
      reference: json['reference'] as String,
      createdAt: json['created_at'] as String,
      description: json['description'] as String?,
      completedAt: json['completed_at'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'status': status,
      'amount': amount,
      'fee': fee,
      'currency': currency,
      'reference': reference,
      'created_at': createdAt,
      'description': description,
      'completed_at': completedAt,
    };
  }
}

class TransactionList {
  final List<Transaction> transactions;
  final int total;
  final int page;
  final int pageSize;
  final int totalPages;

  TransactionList({
    required this.transactions,
    required this.total,
    required this.page,
    required this.pageSize,
    required this.totalPages,
  });

  factory TransactionList.fromJson(Map<String, dynamic> json) {
    return TransactionList(
      transactions: (json['transactions'] as List<dynamic>)
          .map((e) => Transaction.fromJson(e as Map<String, dynamic>))
          .toList(),
      total: json['total'] as int,
      page: json['page'] as int,
      pageSize: json['page_size'] as int,
      totalPages: json['total_pages'] as int,
    );
  }
}
