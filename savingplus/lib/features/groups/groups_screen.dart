import 'package:flutter/material.dart';
import '../../core/api/api_client.dart';
import '../../core/models/group.dart';
import '../../core/utils/formatters.dart';

class GroupsScreen extends StatefulWidget {
  const GroupsScreen({super.key});

  @override
  State<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends State<GroupsScreen> {
  final _api = ApiClient.instance;
  List<SavingsGroup> _groups = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadGroups();
  }

  Future<void> _loadGroups() async {
    setState(() => _isLoading = true);
    try {
      final res = await _api.get('/groups');
      if (!mounted) return;
      final data = res.data;
      final list = data is List ? data : (data is Map ? (data['groups'] ?? []) : []);
      setState(() {
        _groups = (list as List).map((e) => SavingsGroup.fromJson(e)).toList();
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

  Color _typeColor(String type) {
    switch (type) {
      case 'merry_go_round': return Colors.purple;
      case 'fixed_pool': return Colors.blue;
      case 'saving_circle': return Colors.teal;
      default: return Colors.grey;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'active': return Colors.green;
      case 'forming': return Colors.orange;
      case 'completed': return Colors.blue;
      default: return Colors.grey;
    }
  }

  Future<void> _groupAction(SavingsGroup group, String action) async {
    try {
      switch (action) {
        case 'join':
          await _api.post('/groups/${group.id}/join');
          break;
        case 'contribute':
          await _api.post('/groups/${group.id}/contribute');
          break;
        case 'leave':
          await _api.post('/groups/${group.id}/leave');
          break;
        case 'start':
          await _api.post('/groups/${group.id}/start');
          break;
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${action[0].toUpperCase()}${action.substring(1)} successful!')),
      );
      _loadGroups();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ApiClient.getErrorMessage(e))),
      );
    }
  }

  void _showCreateSheet() {
    final nameCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    final maxMembersCtrl = TextEditingController(text: '10');
    String type = 'merry_go_round';
    String frequency = 'weekly';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Create Group',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                const SizedBox(height: 16),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Group Name', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: type,
                  decoration: const InputDecoration(labelText: 'Type', border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'merry_go_round', child: Text('Merry-go-round')),
                    DropdownMenuItem(value: 'fixed_pool', child: Text('Fixed Pool')),
                    DropdownMenuItem(value: 'saving_circle', child: Text('Saving Circle')),
                  ],
                  onChanged: (v) => setSheetState(() => type = v!),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amountCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Contribution Amount',
                    prefixText: 'TZS  ',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: frequency,
                  decoration: const InputDecoration(labelText: 'Frequency', border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'daily', child: Text('Daily')),
                    DropdownMenuItem(value: 'weekly', child: Text('Weekly')),
                    DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
                  ],
                  onChanged: (v) => setSheetState(() => frequency = v!),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: maxMembersCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Max Members',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      try {
                        await _api.post('/groups', data: {
                          'name': nameCtrl.text.trim(),
                          'type': type,
                          'contribution_amount': double.tryParse(amountCtrl.text) ?? 0,
                          'frequency': frequency,
                          'max_members': int.tryParse(maxMembersCtrl.text) ?? 10,
                        });
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Group created!')),
                        );
                        _loadGroups();
                      } catch (e) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(ApiClient.getErrorMessage(e))),
                        );
                      }
                    },
                    child: const Text('Create Group'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Savings Groups')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateSheet,
        icon: const Icon(Icons.add),
        label: const Text('New Group'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _groups.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.group_outlined, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 12),
                      Text('No groups yet', style: TextStyle(color: Colors.grey[500], fontSize: 16)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadGroups,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _groups.length,
                    itemBuilder: (context, index) {
                      final g = _groups[index];
                      final typeColor = _typeColor(g.type);
                      final statusColor = _statusColor(g.status);
                      return Card(
                        margin: const EdgeInsets.only(bottom: 14),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(g.name,
                                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: typeColor.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(g.type.replaceAll('_', ' '),
                                        style: TextStyle(fontSize: 11, color: typeColor, fontWeight: FontWeight.w600)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Icon(Icons.payments_outlined, size: 16, color: Colors.grey[600]),
                                  const SizedBox(width: 4),
                                  Text(formatMoney(g.contributionAmount),
                                      style: TextStyle(fontSize: 13, color: Colors.grey[700])),
                                  const SizedBox(width: 12),
                                  Icon(Icons.schedule, size: 16, color: Colors.grey[600]),
                                  const SizedBox(width: 4),
                                  Text(g.frequency,
                                      style: TextStyle(fontSize: 13, color: Colors.grey[700])),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Icon(Icons.people_outline, size: 16, color: Colors.grey[600]),
                                  const SizedBox(width: 4),
                                  Text('${g.maxMembers} members',
                                      style: TextStyle(fontSize: 13, color: Colors.grey[700])),
                                  const SizedBox(width: 12),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: statusColor.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(g.status,
                                        style: TextStyle(fontSize: 11, color: statusColor, fontWeight: FontWeight.w600)),
                                  ),
                                  if (g.currentRound > 0) ...[
                                    const SizedBox(width: 8),
                                    Text('Round ${g.currentRound}',
                                        style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 14),
                              Row(
                                children: [
                                  if (g.status == 'forming') ...[
                                    Expanded(
                                      child: OutlinedButton(
                                        onPressed: () => _groupAction(g, 'join'),
                                        child: const Text('Join'),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: FilledButton(
                                        onPressed: () => _groupAction(g, 'start'),
                                        child: const Text('Start'),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      onPressed: () => _groupAction(g, 'leave'),
                                      icon: const Icon(Icons.exit_to_app, color: Colors.red),
                                      tooltip: 'Leave',
                                    ),
                                  ],
                                  if (g.status == 'active')
                                    Expanded(
                                      child: FilledButton(
                                        onPressed: () => _groupAction(g, 'contribute'),
                                        child: const Text('Contribute'),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
