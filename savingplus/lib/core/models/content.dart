class ContentArticle {
  final String id, title, body, category, createdAt;
  final int readTimeMin;
  final String? imageUrl;

  ContentArticle({required this.id, required this.title, required this.body,
    required this.category, required this.createdAt, required this.readTimeMin, this.imageUrl});

  factory ContentArticle.fromJson(Map<String, dynamic> json) => ContentArticle(
    id: json['id'] ?? '', title: json['title'] ?? '', body: json['body'] ?? '',
    category: json['category'] ?? '', createdAt: json['created_at'] ?? '',
    readTimeMin: json['read_time_min'] ?? 3, imageUrl: json['image_url'],
  );
}
