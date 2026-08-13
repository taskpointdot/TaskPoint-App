import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../theme/app_theme.dart';
import '../widgets/app_top_bar.dart';
import '../widgets/buttons.dart';

/// The onboarding carousel goes straight here to collect the phone number.
/// [onContinue] (wired in main.dart) sends the real Firebase Phone Auth SMS
/// and only returns once that's kicked off (or throws on failure), so this
/// screen shows a loading state and surfaces any error inline.
class PhoneNumberScreen extends StatefulWidget {
  final Future<void> Function(String phone) onContinue;
  const PhoneNumberScreen({super.key, required this.onContinue});

  @override
  State<PhoneNumberScreen> createState() => _PhoneNumberScreenState();
}

class _PhoneNumberScreenState extends State<PhoneNumberScreen> {
  final _controller = TextEditingController();
  String? _error;
  bool _sending = false;

  String _digitsOnly(String s) => s.replaceAll(RegExp(r'[^0-9]'), '');

  Future<void> _submit() async {
    if (_sending) return;
    final digits = _digitsOnly(_controller.text);
    if (digits.length != 10) {
      setState(() => _error = 'Enter a valid 10-digit mobile number (e.g. 3451234567)');
      return;
    }
    setState(() {
      _error = null;
      _sending = true;
    });
    try {
      await widget.onContinue('+92 $digits');
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppTopBar(title: 'TaskPoint'),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.marginMobile, AppSpacing.xl, AppSpacing.marginMobile, AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 72,
                height: 72,
                alignment: Alignment.center,
                decoration: const BoxDecoration(color: AppColors.primaryContainer, shape: BoxShape.circle),
                child: const Icon(Symbols.smartphone_rounded, color: Colors.white, size: 32),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text('Apna Number Darj Karain', style: AppTextStyles.headlineLgMobile, textAlign: TextAlign.center),
              const SizedBox(height: AppSpacing.sm),
              Text(
                "We'll send a verification code to this number",
                style: AppTextStyles.bodyMd.copyWith(color: AppColors.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xl),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 56,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.outlineVariant),
                    ),
                    child: Text('+92', style: AppTextStyles.labelLg.copyWith(fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      autofocus: true,
                      keyboardType: TextInputType.phone,
                      style: AppTextStyles.labelLg,
                      maxLength: 10,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      onChanged: (_) {
                        if (_error != null) setState(() => _error = null);
                      },
                      onSubmitted: (_) => _submit(),
                      decoration: InputDecoration(
                        counterText: '',
                        hintText: '3451234567',
                        filled: true,
                        fillColor: AppColors.surfaceContainerLowest,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: AppColors.outlineVariant)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: AppColors.outlineVariant)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.primary, width: 2)),
                      ),
                    ),
                  ),
                ],
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: AppTextStyles.bodyMd.copyWith(color: AppColors.error)),
              ],
              const Spacer(),
              PrimaryButton(label: _sending ? 'Sending...' : 'Send OTP', onPressed: _sending ? null : _submit),
              const SizedBox(height: AppSpacing.md),
            ],
          ),
        ),
      ),
    );
  }
}
