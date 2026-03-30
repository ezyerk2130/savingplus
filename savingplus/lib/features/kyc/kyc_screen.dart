import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';
import '../../core/api/api_client.dart';
import '../../core/utils/formatters.dart';
import '../../core/api/token_storage.dart';

class KycScreen extends StatefulWidget {
  const KycScreen({super.key});

  @override
  State<KycScreen> createState() => _KycScreenState();
}

class _KycScreenState extends State<KycScreen> {
  final _api = ApiClient.instance;
  bool _isLoading = true;
  bool _isUploading = false;
  Map<String, dynamic>? _kycStatus;
  List<dynamic> _documents = [];
  String _selectedDocType = 'national_id';
  XFile? _selectedFile;

  final _docTypes = [
    {'value': 'national_id', 'label': 'National ID (NIDA)'},
    {'value': 'passport', 'label': 'Passport'},
    {'value': 'driving_license', 'label': 'Driving License'},
    {'value': 'voter_id', 'label': 'Voter ID'},
  ];

  final _tierInfo = [
    {'tier': 0, 'limit': 'TZS 50,000/day', 'desc': 'Unverified'},
    {'tier': 1, 'limit': 'TZS 500,000/day', 'desc': 'Basic KYC'},
    {'tier': 2, 'limit': 'TZS 5,000,000/day', 'desc': 'Full KYC'},
    {'tier': 3, 'limit': 'Unlimited', 'desc': 'Premium KYC'},
  ];

  @override
  void initState() {
    super.initState();
    _loadKycStatus();
  }

  Future<void> _loadKycStatus() async {
    setState(() => _isLoading = true);
    try {
      final res = await _api.get('/kyc/status');
      if (!mounted) return;
      final data = res.data;
      setState(() {
        _kycStatus = data is Map<String, dynamic> ? data : {};
        _documents = data['documents'] ?? [];
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

  Future<void> _pickFile() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (file != null) {
      setState(() => _selectedFile = file);
    }
  }

  Future<void> _handleUpload() async {
    if (_selectedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a file first')),
      );
      return;
    }

    setState(() => _isUploading = true);
    try {
      final token = await TokenStorage().getAccessToken();
      final formData = FormData.fromMap({
        'document_type': _selectedDocType,
        'file': await MultipartFile.fromFile(_selectedFile!.path, filename: _selectedFile!.name),
      });
      await Dio(BaseOptions(
        baseUrl: 'http://10.0.2.2:8080/api/v1',
        headers: {'Authorization': 'Bearer $token'},
      )).post('/kyc/upload', data: formData);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Document uploaded successfully!')),
      );
      setState(() => _selectedFile = null);
      _loadKycStatus();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ApiClient.getErrorMessage(e))),
      );
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Color _docStatusColor(String status) {
    switch (status) {
      case 'approved': return Colors.green;
      case 'pending': return Colors.orange;
      case 'rejected': return Colors.red;
      default: return Colors.grey;
    }
  }

  IconData _docStatusIcon(String status) {
    switch (status) {
      case 'approved': return Icons.check_circle;
      case 'pending': return Icons.schedule;
      case 'rejected': return Icons.cancel;
      default: return Icons.help_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final kycStatusStr = _kycStatus?['kyc_status'] ?? 'pending';
    final kycTier = _kycStatus?['kyc_tier'] ?? 0;

    return Scaffold(
      appBar: AppBar(title: const Text('KYC Verification')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadKycStatus,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Status card
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF102A43),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          kycStatusStr == 'approved' ? Icons.verified : Icons.pending,
                          color: kycStatusStr == 'approved' ? Colors.green[300] : Colors.orange[300],
                          size: 48,
                        ),
                        const SizedBox(height: 8),
                        Text('KYC Status: ${kycStatusStr.toUpperCase()}',
                            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        Text('Current Tier: $kycTier',
                            style: const TextStyle(color: Colors.white60, fontSize: 14)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Tier info
                  const Text('Tier Limits', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Table(
                        columnWidths: const {
                          0: FlexColumnWidth(0.8),
                          1: FlexColumnWidth(1.5),
                          2: FlexColumnWidth(1.5),
                        },
                        children: [
                          TableRow(
                            decoration: BoxDecoration(color: Colors.grey[100]),
                            children: const [
                              Padding(padding: EdgeInsets.all(10), child: Text('Tier', style: TextStyle(fontWeight: FontWeight.w600))),
                              Padding(padding: EdgeInsets.all(10), child: Text('Limit', style: TextStyle(fontWeight: FontWeight.w600))),
                              Padding(padding: EdgeInsets.all(10), child: Text('Level', style: TextStyle(fontWeight: FontWeight.w600))),
                            ],
                          ),
                          ..._tierInfo.map((t) => TableRow(
                            decoration: BoxDecoration(
                              color: t['tier'] == kycTier ? primary.withOpacity(0.08) : null,
                            ),
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(10),
                                child: Text('${t['tier']}',
                                    style: TextStyle(
                                        fontWeight: t['tier'] == kycTier ? FontWeight.w700 : FontWeight.normal,
                                        color: t['tier'] == kycTier ? primary : null)),
                              ),
                              Padding(padding: const EdgeInsets.all(10), child: Text('${t['limit']}')),
                              Padding(padding: const EdgeInsets.all(10), child: Text('${t['desc']}')),
                            ],
                          )),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Upload section
                  const Text('Upload Document', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _selectedDocType,
                    decoration: const InputDecoration(labelText: 'Document Type', border: OutlineInputBorder()),
                    items: _docTypes.map((d) =>
                        DropdownMenuItem(value: d['value'], child: Text(d['label']!))).toList(),
                    onChanged: (v) => setState(() => _selectedDocType = v!),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _pickFile,
                    icon: const Icon(Icons.attach_file),
                    label: Text(_selectedFile != null ? _selectedFile!.name : 'Choose File'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton(
                      onPressed: _isUploading ? null : _handleUpload,
                      child: _isUploading
                          ? const SizedBox(
                              height: 20, width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('Upload'),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Uploaded documents
                  if (_documents.isNotEmpty) ...[
                    const Text('Uploaded Documents', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    ...List.generate(_documents.length, (i) {
                      final doc = _documents[i];
                      final status = doc['status'] ?? 'pending';
                      return ListTile(
                        leading: Icon(_docStatusIcon(status), color: _docStatusColor(status)),
                        title: Text((doc['document_type'] ?? '').toString().replaceAll('_', ' ').toUpperCase(),
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                        subtitle: Text('Uploaded ${formatDate(doc['created_at'])}',
                            style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: _docStatusColor(status).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(status,
                              style: TextStyle(fontSize: 11, color: _docStatusColor(status), fontWeight: FontWeight.w600)),
                        ),
                      );
                    }),
                  ],
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }
}
