import 'package:flutter/material.dart';
import 'package:dio/dio.dart';

import '../../core/api/api_client.dart';
import '../../core/models/content.dart';
import '../../core/utils/formatters.dart';

class LearnScreen extends StatefulWidget {
  const LearnScreen({super.key});

  @override
  State<LearnScreen> createState() => _LearnScreenState();
}

class _LearnScreenState extends State<LearnScreen> {
  final ApiClient _api = ApiClient();

  List<ContentArticle> _articles = [];
  bool _isLoading = true;
  String _selectedCategory = 'all';

  final _categories = ['all', 'saving', 'investing', 'budgeting', 'insurance', 'credit'];
  final _categoryLabels = ['All', 'Saving', 'Investing', 'Budgeting', 'Insurance', 'Credit'];

  @override
  void initState() {
    super.initState();
    _loadArticles();
  }

  Future<void> _loadArticles() async {
    setState(() => _isLoading = true);
    try {
      final params = <String, dynamic>{};
      if (_selectedCategory != 'all') params['category'] = _selectedCategory;

      final res = await _api.get('/content/articles', queryParameters: params);
      final list = (res.data as List<dynamic>?) ?? [];
      if (!mounted) return;
      setState(() {
        _articles = list.map((e) => ContentArticle.fromJson(e as Map<String, dynamic>)).toList();
      });
    } on DioException catch (e) {
      if (!mounted) return;
      final msg = e.error is ApiException ? e.error.toString() : 'Failed to load articles';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } catch (_) {} finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _openArticle(ContentArticle article) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _ArticleDetailView(article: article),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Learn')),
      body: Column(
        children: [
          SizedBox(
            height: 52,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: _categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final isSelected = _selectedCategory == _categories[i];
                return FilterChip(
                  label: Text(_categoryLabels[i]),
                  selected: isSelected,
                  selectedColor: const Color(0xFF2563EB).withOpacity(0.15),
                  onSelected: (_) {
                    setState(() => _selectedCategory = _categories[i]);
                    _loadArticles();
                  },
                );
              },
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _articles.isEmpty
                    ? Center(child: Text('No articles found', style: TextStyle(color: Colors.grey[500])))
                    : RefreshIndicator(
                        onRefresh: _loadArticles,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _articles.length,
                          itemBuilder: (context, i) => _articleCard(_articles[i]),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _articleCard(ContentArticle article) {
    final categoryColors = {
      'saving': Colors.green,
      'investing': const Color(0xFF2563EB),
      'budgeting': Colors.orange,
      'insurance': Colors.purple,
      'credit': Colors.red,
    };
    final color = categoryColors[article.category] ?? Colors.grey;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _openArticle(article),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      article.category.toUpperCase(),
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
                    ),
                  ),
                  const Spacer(),
                  Icon(Icons.schedule, size: 14, color: Colors.grey[400]),
                  const SizedBox(width: 4),
                  Text(
                    '${article.readTimeMin} min read',
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                article.title,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              Text(
                article.body.length > 120 ? '${article.body.substring(0, 120)}...' : article.body,
                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ArticleDetailView extends StatelessWidget {
  final ContentArticle article;
  const _ArticleDetailView({required this.article});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Article')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              article.title,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    article.category.toUpperCase(),
                    style: const TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF2563EB)),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '${article.readTimeMin} min read',
                  style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                ),
                const SizedBox(width: 12),
                Text(
                  formatDate(article.createdAt),
                  style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              article.body,
              style: const TextStyle(fontSize: 15, height: 1.7),
            ),
          ],
        ),
      ),
    );
  }
}
