import 'package:flutter/material.dart';
import 'package:dio/dio.dart';

import '../../core/api/api_client.dart';
import '../../core/models/group.dart';
import '../../core/utils/formatters.dart';

class GroupsScreen extends StatefulWidget {
  const GroupsScreen({super.key});

  @override
  State<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends State<GroupsScreen> {
  final ApiClient _api = ApiClient();

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
      final list = (res.data as List<dynamic>?) ?? [];
      if (!mounted) return;
      setState(() {
        _groups = list.map((e) => SavingsGroup.fromJson(e as Map<String, dynamic>)).toList();
      });
    } on DioException catch (e) {
      if (!mounted) return;
      final msg = e.error is ApiException ? e.error.toString() : 'Failed to load groups';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } catch (_) {} finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showCreateGroupSheet() {
    final nameController = TextEditingController();
    final descController = TextEditingController();
    final amountController = TextEditingController();
    final maxMembersController = TextEditingController(text: '10');
    String type = 'rotating';
    String frequency = 'monthly';

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
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Create Group', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                const SizedBox(height: 16),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Group Name'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descController,
                  decoration: const InputDecoration(labelText: 'Description'),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: type,
                  decoration: const InputDecoration(labelText: 'Type'),
                  items: const [
                    DropdownMenuItem(value: 'rotating', child: Text('Rotating (Upatu)')),
                    DropdownMenuItem(value: 'pooled', child: Text('Pooled Savings')),
                  ],
                  onChanged: (v) => setSheetState(() => type = v!),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(prefixText: 'TZS ', labelText: 'Contribution Amount'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: frequency,
                  decoration: const InputDecoration(labelText: 'Frequency'),
                  items: const [
                    DropdownMenuItem(value: 'weekly', child: Text('Weekly')),
                    DropdownMenuItem(value: 'biweekly', child: Text('Bi-weekly')),
                    DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
                  ],
                  onChanged: (v) => setSheetState(() => frequency = v!),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: maxMembersController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Max Members'),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () async {
                    if (nameController.text.trim().isEmpty || amountController.text.trim().isEmpty) return;
                    try {
                      await _api.post('/groups', data: {
                        'name': nameController.text.trim(),
                        'description': descController.text.trim(),
                        'type': type,
                        'contribution_amount': amountController.text.trim(),
                        'frequency': frequency,
                        'max_members': int.tryParse(maxMembersController.text.trim()) ?? 10,
                      });
                      if (!mounted) return;
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Group created!'), backgroundColor: Colors.green),
                      );
                      _loadGroups();
                    } on DioException catch (e) {
                      final msg = e.error is ApiException ? e.error.toString() : 'Failed to create group';
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
                    }
                  },
                  child: const Text('Create Group'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _joinGroup(SavingsGroup group) async {
    try {
      await _api.post('/groups/${group.id}/join');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Joined group!'), backgroundColor: Colors.green),
      );
      _loadGroups();
    } on DioException catch (e) {
      final msg = e.error is ApiException ? e.error.toString() : 'Failed to join';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  Future<void> _leaveGroup(SavingsGroup group) async {
    try {
      await _api.post('/groups/${group.id}/leave');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Left group'), backgroundColor: Colors.green),
      );
      _loadGroups();
    } on DioException catch (e) {
      final msg = e.error is ApiException ? e.error.toString() : 'Failed to leave';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  void _showContributeSheet(SavingsGroup group) {
    final controller = TextEditingController(text: group.contributionAmount);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Contribute to ${group.name}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(prefixText: 'TZS ', labelText: 'Amount'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                if (controller.text.trim().isEmpty) return;
                try {
                  await _api.post('/groups/${group.id}/contribute', data: {
                    'amount': controller.text.trim(),
                  });
                  if (!mounted) return;
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Contribution successful!'), backgroundColor: Colors.green),
                  );
                  _loadGroups();
                } on DioException catch (e) {
                  final msg = e.error is ApiException ? e.error.toString() : 'Contribution failed';
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
                }
              },
              child: const Text('Contribute'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _startRound(SavingsGroup group) async {
    try {
      await _api.post('/groups/${group.id}/start-round');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('New round started!'), backgroundColor: Colors.green),
      );
      _loadGroups();
    } on DioException catch (e) {
      final msg = e.error is ApiException ? e.error.toString() : 'Failed to start round';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Groups')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateGroupSheet,
        icon: const Icon(Icons.add),
        label: const Text('New Group'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadGroups,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _groups.isEmpty
                ? ListView(
                    children: [
                      const SizedBox(height: 100),
                      Center(
                        child: Column(
                          children: [
                            Icon(Icons.group_outlined, size: 64, color: Colors.grey[300]),
                            const SizedBox(height: 16),
                            Text('No groups yet', style: TextStyle(color: Colors.grey[500], fontSize: 16)),
                          ],
                        ),
                      ),
                    ],
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _groups.length,
                    itemBuilder: (context, i) => _groupCard(_groups[i]),
                  ),
      ),
    );
  }

  Widget _groupCard(SavingsGroup group) {
    Color statusColor;
    switch (group.status) {
      case 'active':
        statusColor = Colors.green;
        break;
      case 'completed':
        statusColor = const Color(0xFF2563EB);
        break;
      default:
        statusColor = Colors.orange;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(group.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    group.status.toUpperCase(),
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: statusColor),
                  ),
                ),
              ],
            ),
            if (group.description != null && group.description!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(group.description!, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                _infoItem('Type', group.type.toUpperCase()),
                _infoItem('Contribution', formatMoney(group.contributionAmount)),
                _infoItem('Frequency', group.frequency),
                _infoItem('Max Members', '${group.maxMembers}'),
                _infoItem('Round', '${group.currentRound}'),
              ],
            ),
            const Divider(height: 24),
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton(onPressed: () => _joinGroup(group), child: const Text('Join')),
                OutlinedButton(
                  onPressed: () => _leaveGroup(group),
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                  child: const Text('Leave'),
                ),
                ElevatedButton(onPressed: () => _showContributeSheet(group), child: const Text('Contribute')),
                OutlinedButton(onPressed: () => _startRound(group), child: const Text('Start Round')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
      ],
    );
  }
}
