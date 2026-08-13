import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../theme/app_theme.dart';
import '../widgets/app_top_bar.dart';
import '../services/wallet_service.dart';
import '../services/session_controller.dart';

enum _TopUpMethod { jazzCash, easyPaisa }

/// Maps to: digital_wallet_top_up_selection/code.html
/// Manual transfer: the worker sends money to the company account shown
/// below, attaches a screenshot as proof, and it lands in `wallet_topups`
/// as `pending` — nothing auto-approves it yet (no admin dashboard), so the
/// balance updates once someone flips its status by hand.
class DigitalWalletTopUpScreen extends StatefulWidget {
  const DigitalWalletTopUpScreen({super.key});

  @override
  State<DigitalWalletTopUpScreen> createState() => _DigitalWalletTopUpScreenState();
}

class _DigitalWalletTopUpScreenState extends State<DigitalWalletTopUpScreen> {
  final _amountController = TextEditingController();
  final _picker = ImagePicker();
  _TopUpMethod _method = _TopUpMethod.jazzCash;
  Uint8List? _proof;
  bool _submitting = false;

  static const _quickAmounts = [1000, 2000, 5000];

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _pickProof() async {
    final shot = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (shot == null) return;
    final bytes = await shot.readAsBytes();
    setState(() => _proof = bytes);
  }

  Future<void> _submit() async {
    final amt = double.tryParse(_amountController.text.trim());
    final uid = SessionController.instance.uid;
    if (amt == null || amt <= 0 || _proof == null || uid == null || _submitting) return;
    setState(() => _submitting = true);
    try {
      await WalletService.instance.submitTopUp(
        uid: uid,
        amount: amt,
        method: _method == _TopUpMethod.jazzCash ? 'JazzCash' : 'EasyPaisa',
        proofBytes: _proof!,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Rs. ${amt.toStringAsFixed(0)} top-up submitted — pending confirmation')),
      );
      Navigator.of(context).maybePop();
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canSubmit = (double.tryParse(_amountController.text.trim()) ?? 0) > 0 && _proof != null && !_submitting;
    return Scaffold(
      appBar: const AppTopBar(title: 'Top Up Wallet'),
      body: SafeArea(
        child: Stack(
          children: [
            ListView(
              padding: const EdgeInsets.fromLTRB(AppSpacing.marginMobile, AppSpacing.md, AppSpacing.marginMobile, 220),
              children: [
                Text('Enter Amount', style: AppTextStyles.labelLg.copyWith(color: AppColors.onSurfaceVariant)),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: _amountController,
                  keyboardType: TextInputType.number,
                  style: AppTextStyles.headlineLg,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(prefixText: 'PKR  ', hintText: '0'),
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    for (final amt in _quickAmounts) ...[
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => setState(() => _amountController.text = amt.toString()),
                          child: Text('+$amt'),
                        ),
                      ),
                      if (amt != _quickAmounts.last) const SizedBox(width: AppSpacing.sm),
                    ],
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                Text('Payment Method', style: AppTextStyles.labelLg.copyWith(color: AppColors.onSurfaceVariant)),
                const SizedBox(height: AppSpacing.sm),
                _MethodTile(
                  label: 'JC',
                  title: 'JazzCash',
                  subtitle: 'Instant transfer',
                  selected: _method == _TopUpMethod.jazzCash,
                  onTap: () => setState(() => _method = _TopUpMethod.jazzCash),
                ),
                const SizedBox(height: AppSpacing.sm),
                _MethodTile(
                  label: 'EP',
                  title: 'EasyPaisa',
                  subtitle: 'Instant transfer',
                  selected: _method == _TopUpMethod.easyPaisa,
                  onTap: () => setState(() => _method = _TopUpMethod.easyPaisa),
                ),
                const SizedBox(height: AppSpacing.lg),
                _CompanyAccountDetails(method: _method),
                const SizedBox(height: AppSpacing.lg),
                Text('Payment Proof', style: AppTextStyles.labelLg.copyWith(color: AppColors.onSurfaceVariant)),
                const SizedBox(height: AppSpacing.sm),
                InkWell(
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  onTap: _pickProof,
                  child: Container(
                    height: 140,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      border: Border.all(color: _proof != null ? AppColors.primary : AppColors.outlineVariant, width: _proof != null ? 2 : 1),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: _proof == null
                        ? Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Symbols.upload_rounded, color: AppColors.primary, size: 28),
                              const SizedBox(height: 6),
                              Text('Attach transfer screenshot', style: AppTextStyles.bodyMd.copyWith(color: AppColors.onSurfaceVariant)),
                            ],
                          )
                        : Image.memory(_proof!, fit: BoxFit.cover, width: double.infinity),
                  ),
                ),
              ],
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.marginMobile),
                decoration: BoxDecoration(color: AppColors.surface.withOpacity(0.95), border: Border(top: BorderSide(color: AppColors.outlineVariant))),
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: canSubmit ? _submit : null,
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xl))),
                    icon: const Icon(Symbols.lock_rounded, size: 20),
                    label: Text(_submitting ? 'Submitting...' : 'Submit Top-Up', style: AppTextStyles.labelLg.copyWith(color: Colors.white)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompanyAccountDetails extends StatelessWidget {
  final _TopUpMethod method;
  const _CompanyAccountDetails({required this.method});

  @override
  Widget build(BuildContext context) {
    final methodLabel = method == _TopUpMethod.jazzCash ? 'JazzCash' : 'EasyPaisa';
    const accountNumber = '03476801974';
    const accountName = 'Muhammad Bilal';
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.primaryContainer.withOpacity(0.08),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Symbols.account_balance_wallet_rounded, color: AppColors.primary, size: 20),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: Text('Send payment to this $methodLabel account', style: AppTextStyles.labelLg)),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          _DetailRow(label: 'A/C No.', value: accountNumber),
          const SizedBox(height: 4),
          _DetailRow(label: 'A/C Name', value: accountName),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'After sending payment, attach a screenshot below. Your wallet will be topped up once the transaction is confirmed.',
            style: AppTextStyles.bodyMd.copyWith(color: AppColors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(width: 84, child: Text(label, style: AppTextStyles.bodyMd.copyWith(color: AppColors.onSurfaceVariant))),
        Expanded(child: Text(value, style: AppTextStyles.labelLg.copyWith(fontWeight: FontWeight.w700))),
        IconButton(
          icon: const Icon(Symbols.content_copy_rounded, size: 18, color: AppColors.primary),
          tooltip: 'Copy',
          visualDensity: VisualDensity.compact,
          onPressed: () {
            Clipboard.setData(ClipboardData(text: value));
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$label copied')));
          },
        ),
      ],
    );
  }
}

class _MethodTile extends StatelessWidget {
  final String label;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;
  const _MethodTile({required this.label, required this.title, required this.subtitle, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: selected ? AppColors.primary : AppColors.outlineVariant.withOpacity(0.4), width: selected ? 2 : 1),
        ),
        child: Row(
          children: [
            CircleAvatar(radius: 18, backgroundColor: AppColors.surfaceContainer, child: Text(label, style: AppTextStyles.labelSm.copyWith(fontWeight: FontWeight.w700))),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTextStyles.labelLg),
                  Text(subtitle, style: AppTextStyles.bodyMd.copyWith(color: AppColors.onSurfaceVariant)),
                ],
              ),
            ),
            if (selected) const Icon(Symbols.check_circle_rounded, color: AppColors.primary, fill: 1),
          ],
        ),
      ),
    );
  }
}
