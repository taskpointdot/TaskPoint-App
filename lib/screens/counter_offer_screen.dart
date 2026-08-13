import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../theme/app_theme.dart';
import '../widgets/app_top_bar.dart';
import '../services/jobs_service.dart';
import '../services/session_controller.dart';

/// Maps to: counter_offer_screen/code.html
/// The worker's side of negotiating a job's price — submits a bid on
/// [jobId] via [JobsService.placeBid].
class CounterOfferScreen extends StatefulWidget {
  final String jobId;
  final String jobTitle;
  final double currentPrice;
  const CounterOfferScreen({super.key, required this.jobId, required this.jobTitle, required this.currentPrice});

  @override
  State<CounterOfferScreen> createState() => _CounterOfferScreenState();
}

class _CounterOfferScreenState extends State<CounterOfferScreen> {
  static const _amounts = [500, 800, 1000, 1200, 1500, 2000];
  int? _selected;
  bool _isCustom = false;
  bool _sending = false;

  Future<void> _openCustomAmountDialog() async {
    final controller = TextEditingController(text: _isCustom && _selected != null ? '$_selected' : '');
    final entered = await showDialog<int>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Enter Custom Amount'),
          content: TextField(
            controller: controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(prefixText: 'Rs. ', hintText: 'e.g. 900'),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Cancel')),
            TextButton(
              onPressed: () {
                final value = int.tryParse(controller.text.trim());
                Navigator.of(dialogContext).pop(value);
              },
              child: const Text('Confirm'),
            ),
          ],
        );
      },
    );
    if (entered == null || entered <= 0) return;
    setState(() {
      _selected = entered;
      _isCustom = true;
    });
  }

  Future<void> _sendOffer() async {
    final amount = _selected;
    final me = SessionController.instance.user;
    if (amount == null || me == null || _sending) return;
    setState(() => _sending = true);
    try {
      await JobsService.instance.placeBid(jobId: widget.jobId, workerId: me.uid, workerName: me.name, price: amount.toDouble());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Offer of Rs. $amount sent')));
      Navigator.of(context).maybePop();
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppTopBar(title: 'Make an Offer'),
      body: SafeArea(
        child: Stack(
          children: [
            ListView(
              padding: const EdgeInsets.fromLTRB(AppSpacing.marginMobile, AppSpacing.md, AppSpacing.marginMobile, 140),
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(color: AppColors.surfaceContainerLowest, borderRadius: BorderRadius.circular(AppRadius.lg), boxShadow: AppShadows.soft),
                  child: Column(
                    children: [
                      CircleAvatar(radius: 32, backgroundColor: AppColors.surfaceVariant, child: const Icon(Symbols.person_rounded, color: AppColors.onSurfaceVariant, size: 32)),
                      const SizedBox(height: AppSpacing.sm),
                      Text(widget.jobTitle, style: AppTextStyles.headlineMd, textAlign: TextAlign.center),
                      const SizedBox(height: 4),
                      Text('Select an amount to propose as a counter-offer.', style: AppTextStyles.bodyMd.copyWith(color: AppColors.onSurfaceVariant), textAlign: TextAlign.center),
                      const SizedBox(height: AppSpacing.md),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                        decoration: BoxDecoration(
                          color: AppColors.primaryContainer.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('CURRENT ', style: AppTextStyles.labelSm.copyWith(color: AppColors.primary, letterSpacing: 1)),
                            Text('Rs. ${widget.currentPrice.toStringAsFixed(0)}', style: AppTextStyles.headlineLgMobile.copyWith(color: AppColors.primary, fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text('Select Counter-Offer', style: AppTextStyles.labelLg.copyWith(color: AppColors.onSurfaceVariant)),
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
                      _PriceChip(
                        amount: amount,
                        selected: !_isCustom && _selected == amount,
                        onTap: () => setState(() {
                          _selected = amount;
                          _isCustom = false;
                        }),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: OutlinedButton.icon(
                    onPressed: _openCustomAmountDialog,
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: _isCustom ? AppColors.primary : AppColors.outlineVariant, width: _isCustom ? 1.5 : 1, style: BorderStyle.solid),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
                    ),
                    icon: Icon(_isCustom ? Symbols.check_circle_rounded : Symbols.edit_rounded, size: 20),
                    label: Text(
                      _isCustom ? 'Custom: Rs. $_selected' : 'Enter Custom Amount',
                      style: AppTextStyles.labelLg.copyWith(color: AppColors.primary),
                    ),
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
                decoration: BoxDecoration(
                  color: AppColors.surface.withOpacity(0.95),
                  border: Border(top: BorderSide(color: AppColors.outlineVariant)),
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: (_selected == null || _sending) ? null : _sendOffer,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: AppColors.surfaceVariant,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
                    ),
                    icon: const Icon(Symbols.send_rounded, size: 20),
                    label: Text(_sending ? 'Sending...' : (_selected == null ? 'Send Offer' : 'Send Rs. $_selected'), style: AppTextStyles.labelLg.copyWith(color: Colors.white)),
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

class _PriceChip extends StatelessWidget {
  final int amount;
  final bool selected;
  final VoidCallback onTap;
  const _PriceChip({required this.amount, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: selected ? AppColors.primary : AppColors.outlineVariant),
          boxShadow: selected ? AppShadows.active : null,
        ),
        alignment: Alignment.center,
        child: Text(
          'Rs. $amount',
          style: AppTextStyles.headlineMd.copyWith(color: selected ? Colors.white : AppColors.onSurface),
        ),
      ),
    );
  }
}
