import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';

import '../../core/api/api_client.dart';
import '../../core/api/token_storage.dart';
import '../../core/utils/theme.dart';

class KycScreen extends StatefulWidget {
  const KycScreen({super.key});

  @override
  State<KycScreen> createState() => _KycScreenState();
}

class _KycScreenState extends State<KycScreen> {
  final _api = ApiClient.instance;
  final _nidaController = TextEditingController();
  int _currentStep = 1; // 0=info(done), 1=id card(current), 2=selfie
  bool _isLoading = true;
  bool _isUploading = false;
  bool _showNidaManual = false;
  String? _error;
  XFile? _frontFile;
  XFile? _backFile;

  @override
  void initState() {
    super.initState();
    _loadKycStatus();
  }

  @override
  void dispose() {
    _nidaController.dispose();
    super.dispose();
  }

  Future<void> _loadKycStatus() async {
    setState(() => _isLoading = true);
    try {
      await _api.get('/kyc/status');
      if (!mounted) return;
      setState(() => _isLoading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() { _isLoading = false; _error = ApiClient.getErrorMessage(e); });
    }
  }

  Future<void> _pickImage(bool isFront) async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.camera, imageQuality: 80);
    if (file != null) {
      setState(() {
        if (isFront) _frontFile = file;
        else _backFile = file;
      });
    }
  }

  Future<void> _handleUpload() async {
    if (_frontFile == null && _nidaController.text.trim().isEmpty) {
      setState(() => _error = 'Please capture your ID card or enter NIDA number');
      return;
    }

    setState(() { _isUploading = true; _error = null; });
    try {
      final token = await TokenStorage().getAccessToken();
      final formData = FormData.fromMap({
        'document_type': 'national_id',
        if (_frontFile != null)
          'file': await MultipartFile.fromFile(_frontFile!.path, filename: _frontFile!.name),
        if (_nidaController.text.trim().isNotEmpty)
          'nida_number': _nidaController.text.trim(),
      });
      await Dio(BaseOptions(
        baseUrl: ApiConfig.baseUrl,
        headers: {'Authorization': 'Bearer $token'},
      )).post('/kyc/upload', data: formData);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Document uploaded successfully!')),
      );
      setState(() { _currentStep = 2; });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = ApiClient.getErrorMessage(e));
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.of(context).pop()),
        title: Text('Identity Verification',
            style: GoogleFonts.plusJakartaSans(fontSize: 20, fontWeight: FontWeight.w600)),
        actions: [IconButton(icon: const Icon(Icons.translate), onPressed: () {})],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),

                  // Green banner
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: AppGradients.primaryGradient,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 32, height: 32,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.verified_user, color: Colors.white, size: 18),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Required by the Bank of Tanzania to protect your account and enable full features.',
                            style: GoogleFonts.inter(fontSize: 12, color: Colors.white, height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Step indicator
                  Row(
                    children: [
                      _buildStepCircle(0, 'INFO', true, Icons.check),
                      Expanded(child: Container(height: 2, color: AppColors.primary)),
                      _buildStepCircle(1, 'ID CARD', _currentStep >= 1, Icons.lock_outline),
                      Expanded(child: Container(height: 2, color: _currentStep >= 2 ? AppColors.primary : AppColors.surfaceContainerHigh)),
                      _buildStepCircle(2, 'SELFIE', _currentStep >= 2, null),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // Upload heading
                  Text('Upload your NIDA ID',
                      style: GoogleFonts.plusJakartaSans(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.onBackground)),
                  const SizedBox(height: 4),
                  Text('Tanzania National ID (NIDA)',
                      style: GoogleFonts.inter(fontSize: 14, color: AppColors.onSurfaceVariant)),
                  const SizedBox(height: 20),

                  // ID placeholder card
                  Container(
                    width: double.infinity,
                    height: 180,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.credit_card, size: 64, color: AppColors.primary.withValues(alpha: 0.4)),
                        const SizedBox(height: 8),
                        Text('NIDA National ID',
                            style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.primary.withValues(alpha: 0.6))),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Instructions card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.cardWhite,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.ghostBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.info_outline, size: 18, color: AppColors.primary),
                            const SizedBox(width: 8),
                            Text('Instructions',
                                style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.onBackground)),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text('Place your NIDA card on a flat surface with good lighting. Ensure all corners are visible and text is readable.',
                            style: GoogleFonts.inter(fontSize: 13, color: AppColors.onSurfaceVariant, height: 1.4)),
                        const SizedBox(height: 16),

                        // Two capture boxes
                        Row(
                          children: [
                            Expanded(child: _buildCaptureBox('FRONT OF CARD', _frontFile != null, () => _pickImage(true))),
                            const SizedBox(width: 12),
                            Expanded(child: _buildCaptureBox('BACK OF CARD', _backFile != null, () => _pickImage(false))),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Manual NIDA entry
                  GestureDetector(
                    onTap: () => setState(() => _showNidaManual = !_showNidaManual),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Or enter your NIDA number manually',
                            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.primary)),
                        const SizedBox(width: 4),
                        Icon(_showNidaManual ? Icons.expand_less : Icons.expand_more,
                            size: 18, color: AppColors.primary),
                      ],
                    ),
                  ),

                  if (_showNidaManual) ...[
                    const SizedBox(height: 16),
                    Text('NIDA number',
                        style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.onBackground)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _nidaController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        hintText: 'XXXX-XXXXX-XXXXX-XX',
                        prefixIcon: Container(
                          width: 48,
                          alignment: Alignment.center,
                          child: Text('123', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.onSurfaceVariant)),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),

                  if (_error != null) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: AppColors.error.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12)),
                      child: Text(_error!, style: GoogleFonts.inter(color: AppColors.error, fontSize: 13)),
                    ),
                    const SizedBox(height: 16),
                  ],

                  GradientButton(
                    onPressed: _isUploading ? null : _handleUpload,
                    child: _isUploading
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text('Continue to selfie'),
                              const SizedBox(width: 6),
                              const Icon(Icons.arrow_forward, size: 18, color: Colors.white),
                            ],
                          ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  Widget _buildStepCircle(int step, String label, bool completed, IconData? icon) {
    final isActive = _currentStep == step;
    final color = completed ? AppColors.primary : AppColors.surfaceContainerHigh;
    return Column(
      children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: completed ? AppColors.primary : AppColors.surfaceContainerLow,
            border: Border.all(color: color, width: 2),
          ),
          child: Center(
            child: completed && icon != null
                ? Icon(icon, size: 16, color: Colors.white)
                : Text('${step + 1}',
                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600,
                        color: completed ? Colors.white : AppColors.onSurfaceVariant)),
          ),
        ),
        const SizedBox(height: 4),
        Text(label,
            style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w600,
                color: isActive ? AppColors.primary : AppColors.onSurfaceVariant, letterSpacing: 0.5)),
      ],
    );
  }

  Widget _buildCaptureBox(String label, bool captured, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 100,
        decoration: BoxDecoration(
          color: captured ? AppColors.primary.withValues(alpha: 0.06) : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: captured ? AppColors.primary : AppColors.onSurfaceVariant.withValues(alpha: 0.3),
            width: 1,
            strokeAlign: BorderSide.strokeAlignInside,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(captured ? Icons.check_circle : Icons.camera_alt_outlined,
                size: 28, color: captured ? AppColors.primary : AppColors.onSurfaceVariant),
            const SizedBox(height: 6),
            Text(label,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600,
                    color: AppColors.onSurfaceVariant, letterSpacing: 0.3)),
            if (!captured)
              Text('Capture', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.primary)),
          ],
        ),
      ),
    );
  }
}
