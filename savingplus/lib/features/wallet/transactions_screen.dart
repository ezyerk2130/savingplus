import 'package:flutter/material.dart';
import '../../core/api/api_client.dart';
import '../../core/models/transaction.dart';
import '../../core/utils/formatters.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  final _api = ApiClient.instance;
  List<Transaction> _transactions = [];
  bool _isLoading = true;
  bool _hasMore = true;
  int _page = 1;
  String _typeFilter = 'all';
  String _statusFilter = 'all';

  final _types = ['all', 'deposit', 'withdrawal', 'savings_deposit', 'savings_withdrawal'];
  final _typeLabels = {'all': 'All', 'deposit': 'Deposit', 'withdrawal': 'Withdrawal',
    'savings_deposit': 'Savings In', 'savings_withdrawal': 'Savings Out'};
  final _statuses = ['all', 'completed', 'pending', 'failed'];

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  Future<void> _loadTransactions({bool loadMore = false}) async {
    if (!loadMore) {
      setState(() {
        _isLoading = true;
        _page = 1;
        _transactions = [];
      });
    }
    try {
      final params = <String, dynamic>{'page': _page, 'page_size': 20};
      if (_typeFilter != 'all') params['type'] = _typeFilter;
      if (_statusFilter != 'all') params['status'] = _statusFilter;
      final res = await _api.get('/transactions', queryParameters: params);
      if (!mounted) return;
      final data = res.data;
      final txList = data is Map ? (data['transactions'] ?? []) : (data is List ? data : []);
      final newTx = (txList as List).map((e) => Transaction.fromJson(e)).toList();
      setState(() {
        if (loadMore) {
          _transactions.addAll(newTx);
        } else {
          _transactions = newTx;
        }
        _hasMore = newTx.length >= 20;
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

  IconData _txIcon(String type) {
    switch (type) {
      case 'deposit': return Icons.arrow_downward;
      case 'withdrawal': return Icons.arrow_upward;
      case 'savings_deposit':
      case 'savings_withdrawal': return Icons.savings;
      default: return Icons.swap_horiz;
    }
  }

  Color _txColor(String type) {
    if (type.contains('deposit')) return Colors.green;
    return Colors.red;
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'completed': return Colors.green;
      case 'pending': return Colors.orange;
      case 'failed': return Colors.red;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Wallet')),
      body: Column(
        children: [
          // Type filter
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: _types.map((t) {
                final selected = _typeFilter == t;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: FilterChip(
                    selected: selected,
                    label: Text(_typeLabels[t] ?? t),
                    onSelected: (_) {
                      setState(() => _typeFilter = t);
                      _loadTransactions();
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          // Status filter
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: _statuses.map((s) {
                final selected = _statusFilter == s;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: FilterChip(
                    selected: selected,
                    label: Text(s[0].toUpperCase() + s.substring(1)),
                    onSelected: (_) {
                      setState(() => _statusFilter = s);
                      _loadTransactions();
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
                : _transactions.isEmpty
                    ? Center(child: Text('No transactions found', style: TextStyle(color: Colors.grey[500])))
                    : RefreshIndicator(
                        onRefresh: () => _loadTransactions(),
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          itemCount: _transactions.length + (_hasMore ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index == _transactions.length) {
                              return Padding(
                                padding: const EdgeInsets.all(16),
                                child: Center(
                                  child: TextButton(
                                    onPressed: () {
                                      _page++;
                                      _loadTransactions(loadMore: true);
                                    },
                                    child: const Text('Load More'),
                                  ),
                                ),
                              );
                            }
                            final tx = _transactions[index];
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: _txColor(tx.type).withOpacity(0.1),
                                child: Icon(_txIcon(tx.type), color: _txColor(tx.type), size: 20),
                              ),
                              title: Text(tx.type.replaceAll('_', ' ').toUpperCase(),
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                              subtitle: Text(formatDate(tx.createdAt),
                                  style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '${tx.type.contains('deposit') ? '+' : '-'}${formatMoney(tx.amount)}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                      color: _txColor(tx.type),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: _statusColor(tx.status).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(tx.status,
                                        style: TextStyle(
                                            color: _statusColor(tx.status),
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600)),
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
