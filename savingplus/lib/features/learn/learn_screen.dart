import 'package:flutter/material.dart';
import '../../core/api/api_client.dart';
import '../../core/models/content.dart';
import '../../core/utils/formatters.dart';

class LearnScreen extends StatefulWidget {
  const LearnScreen({super.key});

  @override
  State<LearnScreen> createState() => _LearnScreenState();
}

class _LearnScreenState extends State<LearnScreen> {
  final _api = ApiClient.instance;
  List<ContentArticle> _articles = [];
  bool _isLoading = true;
  String _selectedCategory = 'all';

  final _categories = ['all', 'saving', 'investing', 'budgeting', 'insurance', 'credit'];

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
      if (!mounted) return;
      final data = res.data;
      final list = data is List ? data : (data is Map ? (data['articles'] ?? []) : []);
      setState(() {
        _articles = (list as List).map((e) => ContentArticle.fromJson(e)).toList();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ApiClient.getErrorMessage(e))),
      );
    }
  }

  Color _categoryColor(String category) {
    switch (category) {
      case 'saving': return Colors.green;
      case 'investing': return Colors.purple;
      case 'budgeting': return Colors.blue;
      case 'insurance': return Colors.orange;
      case 'credit': return Colors.red;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Learn')),
      body: Column(
        children: [
          // Category chips
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: _categories.map((c) {
                final selected = _selectedCategory == c;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: FilterChip(
                    selected: selected,
                    label: Text(c[0].toUpperCase() + c.substring(1)),
                    onSelected: (_) {
                      setState(() => _selectedCategory = c);
                      _loadArticles();
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _articles.isEmpty
                    ? Center(
                        child: Text('No articles found', style: TextStyle(color: Colors.grey[500])),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadArticles,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _articles.length,
                          itemBuilder: (context, index) {
                            final article = _articles[index];
                            final catColor = _categoryColor(article.category);
                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: ExpansionTile(
                                tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                                title: Text(article.title,
                                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                                subtitle: Row(
                                  children: [
                                    Container(
                                      margin: const EdgeInsets.only(top: 6),
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: catColor.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(article.category,
                                          style: TextStyle(fontSize: 11, color: catColor, fontWeight: FontWeight.w600)),
                                    ),
                                    const SizedBox(width: 8),
                                    Padding(
                                      padding: const EdgeInsets.only(top: 6),
                                      child: Text('${article.readTimeMin} min read',
                                          style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                                    ),
                                  ],
                                ),
                                children: [
                                  Text(article.body,
                                      style: TextStyle(fontSize: 14, height: 1.6, color: Colors.grey[800])),
                                  const SizedBox(height: 8),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: Text(formatDate(article.createdAt),
                                        style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}
