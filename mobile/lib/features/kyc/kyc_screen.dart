import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/utils/formatters.dart';

class KycScreen extends StatefulWidget {
  const KycScreen({super.key});

  @override
  State<KycScreen> createState() => _KycScreenState();
}

class _KycScreenState extends State<KycScreen> {
  final ApiClient _api = ApiClient();
  final ImagePicker _picker = ImagePicker();

  List<Map<String, dynamic>> _documents = [];
  bool _isLoading = true;
  bool _isUploading = false;
  String _documentType = 'national_id';
  XFile? _selectedFile;

  final _docTypes = [
    {'value': 'national_id', 'label': 'National ID (NIDA)'},
    {'value': 'passport', 'label': 'Passport'},
    {'value': 'driving_license', 'label': 'Driving License'},
    {'value': 'voter_id', 'label': 'Voter ID'},
  ];

  @override
  void initState() {
    super.initState();
    _loadDocuments();
  }

  Future<void> _loadDocuments() async {
    setState(() => _isLoading = true);
    try {
      final res = await _api.get('/kyc/documents');
      final list = (res.data as List<dynamic>?) ?? [];
      if (!mounted) return;
      setState(() {
        _documents = list.cast<Map<String, dynamic>>();
      });
    } catch (_) {} finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickFile() async {
    final file = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (file != null) {
      setState(() => _selectedFile = file);
    }
  }

  Future<void> _uploadDocument() async {
    if (_selectedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a file first')),
      );
      return;
    }

    setState(() => _isUploading = true);
    try {
      final formData = FormData.fromMap({
        'document_type': _documentType,
        'file': await MultipartFile.fromFile(_selectedFile!.path, filename: _selectedFile!.name),
      });

      await ApiClient().post('/kyc/upload', data: formData);

      if (!mounted) return;
      setState(() => _selectedFile = null);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Document uploaded successfully!'), backgroundColor: Colors.green),
      );
      _loadDocuments();
    } on DioException catch (e) {
      if (!mounted) return;
      final msg = e.error is ApiException ? e.error.toString() : 'Upload failed';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('An unexpected error occurred')),
      );
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;

    return Scaffold(
      appBar: AppBar(title: const Text('KYC Verification')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadDocuments,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildStatusCard(user),
                  const SizedBox(height: 20),
                  _buildTierInfo(),
                  const SizedBox(height: 24),
                  _buildUploadSection(),
                  const SizedBox(height: 24),
                  _buildDocumentsList(),
                ],
              ),
            ),
    );
  }

  Widget _buildStatusCard(user) {
    Color statusColor;
    IconData statusIcon;
    switch (user?.kycStatus ?? 'pending') {
      case 'approved':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case 'rejected':
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        break;
      case 'pending':
        statusColor = Colors.orange;
        statusIcon = Icons.hourglass_empty;
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.info;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(statusIcon, color: statusColor, size: 40),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'KYC Status: ${(user?.kycStatus ?? 'pending').toUpperCase()}',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: statusColor),
                ),
                const SizedBox(height: 4),
                Text(
                  'Current Tier: ${user?.kycTier ?? 0}',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTierInfo() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Tier Limits', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            Table(
              border: TableBorder.all(color: Colors.grey[200]!),
              children: [
                TableRow(
                  decoration: BoxDecoration(color: Colors.grey[50]),
                  children: const [
                    Padding(padding: EdgeInsets.all(8), child: Text('Tier', style: TextStyle(fontWeight: FontWeight.w600))),
                    Padding(padding: EdgeInsets.all(8), child: Text('Daily Limit', style: TextStyle(fontWeight: FontWeight.w600))),
                    Padding(padding: EdgeInsets.all(8), child: Text('Balance', style: TextStyle(fontWeight: FontWeight.w600))),
                  ],
                ),
                _tierRow('0', 'TZS 50,000', 'TZS 200,000'),
                _tierRow('1', 'TZS 500,000', 'TZS 2,000,000'),
                _tierRow('2', 'TZS 5,000,000', 'TZS 20,000,000'),
                _tierRow('3', 'Unlimited', 'Unlimited'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  TableRow _tierRow(String tier, String daily, String balance) {
    return TableRow(
      children: [
        Padding(padding: const EdgeInsets.all(8), child: Text(tier)),
        Padding(padding: const EdgeInsets.all(8), child: Text(daily, style: const TextStyle(fontSize: 13))),
        Padding(padding: const EdgeInsets.all(8), child: Text(balance, style: const TextStyle(fontSize: 13))),
      ],
    );
  }

  Widget _buildUploadSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Upload Document', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _documentType,
              decoration: const InputDecoration(labelText: 'Document Type'),
              items: _docTypes
                  .map((d) => DropdownMenuItem(value: d['value'] as String, child: Text(d['label'] as String)))
                  .toList(),
              onChanged: (v) => setState(() => _documentType = v!),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _pickFile,
              icon: const Icon(Icons.image),
              label: Text(_selectedFile != null ? _selectedFile!.name : 'Select Image'),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: _isUploading ? null : _uploadDocument,
                child: _isUploading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Upload'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentsList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Uploaded Documents', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        if (_documents.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text('No documents uploaded yet', style: TextStyle(color: Colors.grey[500])),
            ),
          )
        else
          ...List.generate(_documents.length, (i) {
            final doc = _documents[i];
            final status = doc['status'] as String? ?? 'pending';

            IconData statusIcon;
            Color statusColor;
            switch (status) {
              case 'approved':
                statusIcon = Icons.check_circle;
                statusColor = Colors.green;
                break;
              case 'rejected':
                statusIcon = Icons.cancel;
                statusColor = Colors.red;
                break;
              default:
                statusIcon = Icons.hourglass_empty;
                statusColor = Colors.orange;
            }

            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: Icon(Icons.description, color: Colors.grey[400]),
                title: Text(
                  (doc['document_type'] as String? ?? '').replaceAll('_', ' ').toUpperCase(),
                  style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
                ),
                subtitle: Text(
                  formatDate(doc['created_at'] as String? ?? DateTime.now().toIso8601String()),
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, color: statusColor, size: 20),
                    const SizedBox(width: 4),
                    Text(
                      status.toUpperCase(),
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: statusColor),
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }
}
