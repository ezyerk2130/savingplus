import 'package:flutter/material.dart';
import 'package:dio/dio.dart';

import '../../core/api/api_client.dart';
import '../../core/models/transaction.dart';
import '../../core/utils/formatters.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  final ApiClient _api = ApiClient();
  final ScrollController _scrollController = ScrollController();

  List<Transaction> _transactions = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  int _page = 1;
  int _totalPages = 1;

  String _typeFilter = 'all';
  String _statusFilter = 'all';

  final _typeOptions = ['all', 'deposit', 'withdrawal', 'savings_deposit', 'interest'];
  final _typeLabels = ['All', 'Deposit', 'Withdrawal', 'Savings', 'Interest'];
  final _statusOptions = ['all', 'completed', 'pending', 'failed'];
  final _statusLabels = ['All', 'Completed', 'Pending', 'Failed'];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadTransactions();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  Future<void> _loadTransactions() async {
    setState(() {
      _isLoading = true;
      _page = 1;
    });
    try {
      final params = <String, dynamic>{'page': 1, 'page_size': 20};
      if (_typeFilter != 'all') params['type'] = _typeFilter;
      if (_statusFilter != 'all') params['status'] = _statusFilter;

      final res = await _api.get('/transactions', queryParameters: params);
      final data = TransactionList.fromJson(res.data as Map<String, dynamic>);

      if (!mounted) return;
      setState(() {
        _transactions = data.transactions;
        _totalPages = data.totalPages;
      });
    } on DioException catch (e) {
      if (!mounted) return;
      final msg = e.error is ApiException ? e.error.toString() : 'Failed to load transactions';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } catch (_) {} finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || _page >= _totalPages) return;
    setState(() => _isLoadingMore = true);
    _page++;
    try {
      final params = <String, dynamic>{'page': _page, 'page_size': 20};
      if (_typeFilter != 'all') params['type'] = _typeFilter;
      if (_statusFilter != 'all') params['status'] = _statusFilter;

      final res = await _api.get('/transactions', queryParameters: params);
      final data = TransactionList.fromJson(res.data as Map<String, dynamic>);

      if (!mounted) return;
      setState(() => _transactions.addAll(data.transactions));
    } catch (_) {
      _page--;
    } finally {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Transactions')),
      body: Column(
        children: [
          // Type filter
          SizedBox(
            height: 48,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _typeOptions.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final isSelected = _typeFilter == _typeOptions[i];
                return FilterChip(
                  label: Text(_typeLabels[i]),
                  selected: isSelected,
                  selectedColor: const Color(0xFF2563EB).withOpacity(0.15),
                  onSelected: (_) {
                    setState(() => _typeFilter = _typeOptions[i]);
                    _loadTransactions();
                  },
                );
              },
            ),
          ),
          // Status filter
          SizedBox(
            height: 48,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _statusOptions.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final isSelected = _statusFilter == _statusOptions[i];
                return FilterChip(
                  label: Text(_statusLabels[i]),
                  selected: isSelected,
                  selectedColor: const Color(0xFF2563EB).withOpacity(0.15),
                  onSelected: (_) {
                    setState(() => _statusFilter = _statusOptions[i]);
                    _loadTransactions();
                  },
                );
              },
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _transactions.isEmpty
                    ? Center(
                        child: Text(
                          'No transactions found',
                          style: TextStyle(color: Colors.grey[500]),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadTransactions,
                        child: ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.all(16),
                          itemCount: _transactions.length + (_isLoadingMore ? 1 : 0),
                          itemBuilder: (context, i) {
                            if (i == _transactions.length) {
                              return const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(16),
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              );
                            }
                            return _transactionTile(_transactions[i]);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _transactionTile(Transaction tx) {
    IconData icon;
    Color iconColor;
    switch (tx.type) {
      case 'deposit':
        icon = Icons.arrow_downward;
        iconColor = Colors.green;
        break;
      case 'withdrawal':
        icon = Icons.arrow_upward;
        iconColor = Colors.red;
        break;
      case 'savings_deposit':
      case 'savings_withdrawal':
        icon = Icons.savings;
        iconColor = const Color(0xFF2563EB);
        break;
      case 'interest':
        icon = Icons.percent;
        iconColor = Colors.orange;
        break;
      default:
        icon = Icons.swap_horiz;
        iconColor = Colors.grey;
    }

    Color statusColor;
    switch (tx.status) {
      case 'completed':
        statusColor = Colors.green;
        break;
      case 'pending':
        statusColor = Colors.orange;
        break;
      case 'failed':
        statusColor = Colors.red;
        break;
      default:
        statusColor = Colors.grey;
    }

    final isCredit = tx.type == 'deposit' || tx.type == 'interest' || tx.type == 'savings_withdrawal';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                tx.type.replaceAll('_', ' ').toUpperCase(),
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                tx.status.toUpperCase(),
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: statusColor),
              ),
            ),
          ],
        ),
        subtitle: Text(
          formatDateTime(tx.createdAt),
          style: TextStyle(fontSize: 12, color: Colors.grey[500]),
        ),
        trailing: Text(
          '${isCredit ? '+' : '-'}${formatMoney(tx.amount)}',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: isCredit ? Colors.green : Colors.red,
          ),
        ),
      ),
    );
  }
}
