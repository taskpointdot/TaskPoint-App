import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../theme/app_theme.dart';
import '../widgets/app_bottom_nav.dart';
import '../main.dart' show AppRoutes;
import '../models/wallet_transaction.dart';
import '../services/wallet_service.dart';
import '../services/session_controller.dart';

/// Maps to: earnings_wallet_dashboard/code.html
/// Worker's wallet screen. Shows a blocked-account warning when the
/// balance drops below the platform's commission threshold, with a way
/// to top up via JazzCash / EasyPaisa.
class EarningsWalletDashboardScreen extends StatelessWidget {
  const EarningsWalletDashboardScreen({super.key});

  static const _blockedThreshold = -500;

  @override
  Widget build(BuildContext context) {
    final uid = SessionController.instance.uid;
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: IconButton(icon: const Icon(Symbols.arrow_back_rounded), onPressed: () => Navigator.of(context).maybePop()),
        title: const Text('Earnings & Wallet'),
      ),
      body: SafeArea(
        child: uid == null
            ? const SizedBox.shrink()
            : StreamBuilder<double>(
                stream: WalletService.instance.watchBalance(uid),
                builder: (context, balSnap) {
                  final balance = balSnap.data ?? 0;
                  final blocked = balance <= _blockedThreshold;
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.marginMobile, AppSpacing.md, AppSpacing.marginMobile, AppSpacing.xl),
                    children: [
                      if (blocked)
                        Container(
                          margin: const EdgeInsets.only(bottom: AppSpacing.md),
                          padding: const EdgeInsets.all(AppSpacing.md),
                          decoration: BoxDecoration(
                            color: AppColors.errorContainer,
                            borderRadius: BorderRadius.circular(AppRadius.lg),
                            border: Border.all(color: AppColors.error.withOpacity(0.3)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Symbols.error_rounded, color: AppColors.error),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Account Blocked', style: AppTextStyles.labelLg.copyWith(color: AppColors.onErrorContainer)),
                                    const SizedBox(height: 2),
                                    Text('Please clear your debt to continue working.', style: AppTextStyles.bodyMd.copyWith(color: AppColors.onErrorContainer)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: AppShadows.soft),
                        child: Column(
                          children: [
                            Text('Current Balance', style: AppTextStyles.labelLg.copyWith(color: AppColors.onSurfaceVariant)),
                            const SizedBox(height: 4),
                            Text(
                              'Rs. ${balance.toStringAsFixed(0)}',
                              style: AppTextStyles.headlineLg.copyWith(color: blocked ? AppColors.error : AppColors.primary, fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(AppRadius.full),
                              child: LinearProgressIndicator(
                                value: (balance.abs() / _blockedThreshold.abs()).clamp(0, 1).toDouble(),
                                minHeight: 6,
                                backgroundColor: AppColors.surfaceVariant,
                                color: blocked ? AppColors.error : AppColors.statusAmberFg,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Limit: Rs. -1000', style: AppTextStyles.labelSm.copyWith(color: AppColors.onSurfaceVariant)),
                                Text('Blocked Threshold: $_blockedThreshold', style: AppTextStyles.labelSm.copyWith(color: AppColors.onSurfaceVariant)),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Text('Add Funds to Unblock', style: AppTextStyles.headlineMd),
                      const SizedBox(height: AppSpacing.sm),
                      _TopUpOption(
                        icon: Symbols.account_balance_rounded,
                        title: 'JazzCash',
                        subtitle: 'Fast & Secure',
                        onTap: () => Navigator.of(context).pushNamed(AppRoutes.walletTopUp),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      _TopUpOption(
                        icon: Symbols.payments_rounded,
                        title: 'EasyPaisa',
                        subtitle: 'Instant Top-up',
                        onTap: () => Navigator.of(context).pushNamed(AppRoutes.walletTopUp),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Text('Recent Transactions', style: AppTextStyles.headlineMd),
                      const SizedBox(height: AppSpacing.sm),
                      StreamBuilder<List<WalletTransaction>>(
                        stream: WalletService.instance.watchTransactions(uid),
                        builder: (context, txSnap) {
                          final txs = txSnap.data ?? const [];
                          if (!txSnap.hasData) return const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Center(child: CircularProgressIndicator()));
                          if (txs.isEmpty) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              child: Text('No transactions yet', style: AppTextStyles.bodyMd.copyWith(color: AppColors.onSurfaceVariant)),
                            );
                          }
                          return Column(
                            children: [
                              for (final tx in txs.take(10)) ...[
                                _TransactionTile(tx: tx),
                                const Divider(height: 1),
                              ],
                            ],
                          );
                        },
                      ),
                    ],
                  );
                },
              ),
      ),
      bottomNavigationBar: AppBottomNav(
        current: AppTab.jobs,
        onTap: (t) {
          if (t == AppTab.home) {
            Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.workerHome, (r) => r.isFirst);
          } else if (t == AppTab.messages) {
            Navigator.of(context).pushNamed(AppRoutes.notificationsInbox);
          } else if (t == AppTab.profile) {
            Navigator.of(context).pushNamed(AppRoutes.workerProfileSettings);
          }
        },
      ),
    );
  }
}

class _TopUpOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _TopUpOption({required this.icon, required this.title, required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppRadius.lg), boxShadow: AppShadows.soft),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: AppColors.primaryContainer.withOpacity(0.12), borderRadius: BorderRadius.circular(AppRadius.md)),
              child: Icon(icon, color: AppColors.primary),
            ),
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
            const Icon(Symbols.chevron_right_rounded, color: AppColors.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  final WalletTransaction tx;
  const _TransactionTile({required this.tx});

  @override
  Widget build(BuildContext context) {
    final positive = tx.type == TxType.earning;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: AppColors.surfaceContainer, shape: BoxShape.circle),
            child: Icon(positive ? Symbols.arrow_downward_rounded : Symbols.arrow_outward_rounded, size: 18, color: AppColors.onSurfaceVariant),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tx.label.isEmpty ? (positive ? 'Job Payout' : 'Wallet Top-Up') : tx.label, style: AppTextStyles.bodyLg),
                if (tx.createdAt != null) Text('${tx.createdAt}'.split('.').first, style: AppTextStyles.labelSm.copyWith(color: AppColors.onSurfaceVariant)),
              ],
            ),
          ),
          Text(
            '${positive ? '+' : '-'} Rs. ${tx.amount.abs().toStringAsFixed(0)}',
            style: AppTextStyles.labelLg.copyWith(color: positive ? AppColors.statusGreenFg : AppColors.error),
          ),
        ],
      ),
    );
  }
}
