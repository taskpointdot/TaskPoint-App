import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../theme/app_theme.dart';
import '../widgets/app_top_bar.dart';
import '../models/wallet_transaction.dart';
import '../services/wallet_service.dart';
import '../services/session_controller.dart';
import '../main.dart';

/// Maps to: transaction_details_history/code.html
///
/// The original mockup showed one fixed transaction receipt; every real
/// entry point to this screen (drawer "Transactions", profile settings)
/// links here generically with no specific transaction in hand, so this is
/// the current user's real transaction history rather than a single
/// hardcoded receipt.
class TransactionDetailsScreen extends StatelessWidget {
  const TransactionDetailsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = SessionController.instance.uid;
    return Scaffold(
      appBar: const AppTopBar(title: 'Transactions'),
      body: SafeArea(
        child: uid == null
            ? const SizedBox.shrink()
            : StreamBuilder<List<WalletTransaction>>(
                stream: WalletService.instance.watchTransactions(uid),
                builder: (context, snap) {
                  if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                  final txs = snap.data!;
                  if (txs.isEmpty) {
                    return Center(child: Text('No transactions yet', style: AppTextStyles.bodyMd.copyWith(color: AppColors.onSurfaceVariant)));
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.marginMobile, AppSpacing.sm, AppSpacing.marginMobile, AppSpacing.xl),
                    itemCount: txs.length,
                    separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
                    itemBuilder: (context, i) => _TransactionCard(tx: txs[i]),
                  );
                },
              ),
      ),
    );
  }
}

class _TransactionCard extends StatelessWidget {
  final WalletTransaction tx;
  const _TransactionCard({required this.tx});

  @override
  Widget build(BuildContext context) {
    final (statusColor, statusLabel) = switch (tx.status) {
      TxStatus.confirmed => (AppColors.primary, 'COMPLETED'),
      TxStatus.pending => (AppColors.statusAmberFg, 'PENDING'),
      TxStatus.rejected => (AppColors.error, 'REJECTED'),
    };
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(color: AppColors.surfaceContainerLowest, borderRadius: BorderRadius.circular(AppRadius.lg), boxShadow: AppShadows.soft),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(tx.status == TxStatus.confirmed ? Symbols.check_circle_rounded : Symbols.schedule_rounded, color: statusColor, fill: 1),
                  const SizedBox(width: AppSpacing.sm),
                  Text(statusLabel, style: AppTextStyles.labelLg.copyWith(color: AppColors.onSurfaceVariant, letterSpacing: 1)),
                ],
              ),
              IconButton(
                icon: const Icon(Symbols.report_problem_rounded, size: 20, color: AppColors.onSurfaceVariant),
                onPressed: () => Navigator.of(context).pushNamed(AppRoutes.reportProblem),
                tooltip: 'Report a Problem / Dispute',
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          _row('Type', tx.type == TxType.topup ? 'Wallet Top-Up' : 'Job Earning'),
          if (tx.createdAt != null) _row('Date & Time', '${tx.createdAt}'.split('.').first),
          if (tx.label.isNotEmpty) _row('Details', tx.label),
          const Divider(height: AppSpacing.lg),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Amount', style: AppTextStyles.headlineMd),
              Text('Rs. ${tx.amount.toStringAsFixed(0)}', style: AppTextStyles.headlineMd.copyWith(color: AppColors.primary)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTextStyles.bodyMd.copyWith(color: AppColors.onSurfaceVariant)),
          Flexible(child: Text(value, style: AppTextStyles.labelLg, textAlign: TextAlign.right)),
        ],
      ),
    );
  }
}
