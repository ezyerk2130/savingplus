class ContentArticle {
  final String id;
  final String title;
  final String body;
  final String category;
  final String createdAt;
  final int readTimeMin;
  final String? imageUrl;

  ContentArticle({
    required this.id,
    required this.title,
    required this.body,
    required this.category,
    required this.createdAt,
    required this.readTimeMin,
    this.imageUrl,
  });

  factory ContentArticle.fromJson(Map<String, dynamic> json) {
    return ContentArticle(
      id: json['id'] as String,
      title: json['title'] as String,
      body: json['body'] as String,
      category: json['category'] as String,
      createdAt: json['created_at'] as String,
      readTimeMin: json['read_time_min'] as int,
      imageUrl: json['image_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'body': body,
      'category': category,
      'created_at': createdAt,
      'read_time_min': readTimeMin,
      'image_url': imageUrl,
    };
  }
}
