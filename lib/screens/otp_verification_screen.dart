import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../widgets/app_top_bar.dart';

/// Maps to: otp_verification/code.html
///
/// [onSubmit] confirms the 6-digit code against the real Firebase Phone Auth
/// `verificationId` from the send that led here (main.dart holds that id in
/// closure, not this widget) and throws on failure. [onResend] re-sends a
/// fresh code the same way. [onVerified] fires only after [onSubmit]
/// succeeds — it's what actually navigates onward.
class OtpVerificationScreen extends StatefulWidget {
  final String phoneNumber;
  final Future<void> Function(String smsCode) onSubmit;
  final Future<void> Function() onResend;
  final VoidCallback? onVerified;
  const OtpVerificationScreen({
    super.key,
    this.phoneNumber = '+92 345 1234567',
    required this.onSubmit,
    required this.onResend,
    this.onVerified,
  });

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  static const _length = 6;
  late final List<TextEditingController> _controllers = List.generate(_length, (_) => TextEditingController());
  late final List<FocusNode> _focusNodes = List.generate(_length, (_) => FocusNode());

  Timer? _timer;
  int _secondsLeft = 45;
  bool _verifying = false;
  bool _resending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _secondsLeft = 45;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_secondsLeft == 0) {
        t.cancel();
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  bool get _isComplete => _controllers.every((c) => c.text.isNotEmpty);

  void _onChanged(int index, String value) {
    if (value.isNotEmpty && index < _length - 1) {
      _focusNodes[index + 1].requestFocus();
    }
    if (_error != null) _error = null;
    setState(() {});
  }

  Future<void> _verify() async {
    if (!_isComplete || _verifying) return;
    final code = _controllers.map((c) => c.text).join();
    setState(() {
      _verifying = true;
      _error = null;
    });
    try {
      await widget.onSubmit(code);
      widget.onVerified?.call();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  Future<void> _resend() async {
    if (_secondsLeft != 0 || _resending) return;
    setState(() => _resending = true);
    try {
      await widget.onResend();
      if (mounted) _startTimer();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
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
            children: [
              Text('Phone Number Tasdeeq', style: AppTextStyles.headlineLgMobile, textAlign: TextAlign.center),
              const SizedBox(height: AppSpacing.sm),
              Text(
                "We've sent a 6-digit code to",
                style: AppTextStyles.bodyMd.copyWith(color: AppColors.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(widget.phoneNumber, style: AppTextStyles.labelLg.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: AppSpacing.lg),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(_length, (i) {
                  return SizedBox(
                    width: 44,
                    height: 56,
                    child: TextField(
                      controller: _controllers[i],
                      focusNode: _focusNodes[i],
                      textAlign: TextAlign.center,
                      keyboardType: TextInputType.number,
                      maxLength: 1,
                      style: AppTextStyles.headlineMd,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(
                        counterText: '',
                        filled: true,
                        fillColor: AppColors.surfaceContainerLowest,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: AppColors.outlineVariant)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: AppColors.outlineVariant)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.primary, width: 2)),
                      ),
                      onChanged: (v) => _onChanged(i, v),
                    ),
                  );
                }),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text('0:${_secondsLeft.toString().padLeft(2, '0')} seconds remaining', style: AppTextStyles.bodyMd.copyWith(color: AppColors.outline)),
              const SizedBox(height: AppSpacing.md),
              TextButton(
                onPressed: (_secondsLeft == 0 && !_resending) ? _resend : null,
                child: Text(
                  _resending ? 'Sending...' : 'OTP Dobara Bhejen',
                  style: AppTextStyles.labelLg.copyWith(color: _secondsLeft == 0 ? AppColors.primary : AppColors.outlineVariant),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(_error!, style: AppTextStyles.bodyMd.copyWith(color: AppColors.error), textAlign: TextAlign.center),
              ],
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: (_isComplete && !_verifying) ? _verify : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isComplete ? AppColors.primary : AppColors.surfaceVariant,
                    foregroundColor: _isComplete ? Colors.white : AppColors.onSurfaceVariant,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.full)),
                    elevation: 0,
                  ),
                  child: _verifying
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                      : Text('Verify Code', style: AppTextStyles.labelLg.copyWith(color: _isComplete ? Colors.white : AppColors.onSurfaceVariant)),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
          ),
        ),
      ),
    );
  }
}
