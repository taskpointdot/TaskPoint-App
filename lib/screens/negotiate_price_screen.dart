import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../theme/app_theme.dart';
import '../widgets/app_top_bar.dart';
import '../services/jobs_service.dart';
import '../services/session_controller.dart';

/// Maps to: negotiate_price_chips_layout/code.html
/// Worker-side counter-offer screen, reached from the incoming job
/// notification popup when the worker taps "Counter-Offer" instead of
/// accepting the listed price outright.
class NegotiatePriceScreen extends StatefulWidget {
  final String jobId;
  final String jobTitle;
  final IconData categoryIcon;
  final String estimatedRange;
  const NegotiatePriceScreen({
    super.key,
    required this.jobId,
    required this.jobTitle,
    required this.categoryIcon,
    required this.estimatedRange,
  });

  @override
  State<NegotiatePriceScreen> createState() => _NegotiatePriceScreenState();
}

class _NegotiatePriceScreenState extends State<NegotiatePriceScreen> {
  static const _amounts = [500, 1000, 1500, 2000];
  int? _selected;
  bool _sending = false;

  Future<void> _submit() async {
    final amount = _selected;
    final me = SessionController.instance.user;
    if (amount == null || me == null || _sending) return;
    setState(() => _sending = true);
    try {
      await JobsService.instance.placeBid(jobId: widget.jobId, workerId: me.uid, workerName: me.name, price: amount.toDouble());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Counter-offer of Rs. $amount sent')));
      Navigator.of(context).maybePop();
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppTopBar(title: 'Negotiate Price'),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.marginMobile, AppSpacing.md, AppSpacing.marginMobile, AppSpacing.marginMobile),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppRadius.lg), boxShadow: AppShadows.soft),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(color: AppColors.primaryContainer.withOpacity(0.12), borderRadius: BorderRadius.circular(AppRadius.md)),
                      child: Icon(widget.categoryIcon, color: AppColors.primary),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(child: Text(widget.jobTitle, style: AppTextStyles.headlineMd)),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                decoration: BoxDecoration(color: AppColors.statusAmberBg, borderRadius: BorderRadius.circular(AppRadius.md)),
                child: Row(
                  children: [
                    const Icon(Symbols.info_rounded, size: 18, color: AppColors.statusAmberFg),
                    const SizedBox(width: 6),
                    Expanded(child: Text('Estimated: ${widget.estimatedRange}', style: AppTextStyles.bodyMd.copyWith(color: AppColors.statusAmberFg))),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text('Tap a price to make your offer', style: AppTextStyles.labelLg.copyWith(color: AppColors.onSurfaceVariant)),
              const SizedBox(height: AppSpacing.sm),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: AppSpacing.md,
                crossAxisSpacing: AppSpacing.md,
                childAspectRatio: 2.4,
                children: [
                  for (final amount in _amounts)
                    InkWell(
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      onTap: () => setState(() => _selected = amount),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        decoration: BoxDecoration(
                          color: _selected == amount ? AppColors.primary : Colors.white,
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                          border: Border.all(color: _selected == amount ? AppColors.primary : AppColors.outlineVariant),
                          boxShadow: _selected == amount ? AppShadows.active : AppShadows.soft,
                        ),
                        alignment: Alignment.center,
                        child: Text('Rs. $amount', style: AppTextStyles.headlineMd.copyWith(color: _selected == amount ? Colors.white : AppColors.onSurface)),
                      ),
                    ),
                ],
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: (_selected == null || _sending) ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    disabledBackgroundColor: AppColors.surfaceVariant,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xl)),
                  ),
                  child: Text(_sending ? 'Sending...' : 'Submit Counter-Offer', style: AppTextStyles.labelLg.copyWith(color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
