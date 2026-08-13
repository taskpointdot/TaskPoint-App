import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../theme/app_theme.dart';
import '../widgets/app_bottom_nav.dart';
import '../main.dart' show AppRoutes;
import '../models/app_notification.dart';
import '../services/job_navigation.dart';
import '../services/notifications_service.dart';
import '../services/session_controller.dart';

IconData _iconFor(String type) => switch (type) {
      'job' => Symbols.work_rounded,
      'bid' => Symbols.local_offer_rounded,
      'message' => Symbols.chat_bubble_rounded,
      'wallet' => Symbols.account_balance_wallet_rounded,
      _ => Symbols.notifications_rounded,
    };

String _timeAgo(DateTime? dt) {
  if (dt == null) return '';
  final diff = DateTime.now().difference(dt);
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes} mins ago';
  if (diff.inHours < 24) return '${diff.inHours} hr ago';
  return '${diff.inDays} d ago';
}

/// Maps to: notifications_inbox/code.html
class NotificationsInboxScreen extends StatefulWidget {
  const NotificationsInboxScreen({super.key});

  @override
  State<NotificationsInboxScreen> createState() => _NotificationsInboxScreenState();
}

class _NotificationsInboxScreenState extends State<NotificationsInboxScreen> {
  int _tab = 0; // 0 all, 1 unread, 2 jobs

  @override
  Widget build(BuildContext context) {
    final uid = SessionController.instance.uid;
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: IconButton(icon: const Icon(Symbols.arrow_back_rounded), onPressed: () => Navigator.of(context).maybePop()),
        title: const Text('Notifications'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.marginMobile, AppSpacing.sm, AppSpacing.marginMobile, 0),
              child: Row(
                children: [
                  for (final entry in const ['All', 'Unread', 'Jobs'].asMap().entries) ...[
                    Expanded(
                      child: ChoiceChip(
                        label: Text(entry.value),
                        selected: _tab == entry.key,
                        onSelected: (_) => setState(() => _tab = entry.key),
                        selectedColor: AppColors.primaryContainer,
                        labelStyle: AppTextStyles.labelSm.copyWith(color: _tab == entry.key ? AppColors.onPrimaryContainer : AppColors.onSurfaceVariant),
                      ),
                    ),
                    if (entry.key != 2) const SizedBox(width: 8),
                  ],
                ],
              ),
            ),
            Expanded(
              child: uid == null
                  ? const SizedBox.shrink()
                  : StreamBuilder<List<AppNotification>>(
                      stream: NotificationsService.instance.watch(uid),
                      builder: (context, snap) {
                        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                        final items = snap.data!.where((n) {
                          if (_tab == 1) return !n.read;
                          if (_tab == 2) return n.type == 'job' || n.type == 'bid';
                          return true;
                        }).toList();
                        if (items.isEmpty) {
                          return Center(child: Text('No notifications', style: AppTextStyles.bodyMd.copyWith(color: AppColors.onSurfaceVariant)));
                        }
                        return ListView.separated(
                          padding: const EdgeInsets.all(AppSpacing.marginMobile),
                          itemCount: items.length,
                          separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
                          itemBuilder: (context, i) => _NotificationCard(
                            item: items[i],
                            // Tapping used to only mark the row read, so a
                            // "Bid accepted" / "New bid received" notification
                            // was a dead end even though it carries the jobId.
                            // Now it also opens whichever screen that job is
                            // actually up to, for this user's role.
                            onTap: () async {
                              final item = items[i];
                              await NotificationsService.instance.markRead(uid, item.id);
                              if (item.jobId == null || !context.mounted) return;
                              await openJobById(context, item.jobId!);
                            },
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: AppBottomNav(
        current: AppTab.messages,
        onTap: (t) {
          if (t == AppTab.home) {
            Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.workerHome, (r) => r.isFirst);
          } else if (t == AppTab.jobs) {
            Navigator.of(context).pushNamed(AppRoutes.jobHistory);
          } else if (t == AppTab.profile) {
            Navigator.of(context).pushNamed(AppRoutes.workerProfileSettings);
          }
        },
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  final AppNotification item;
  final VoidCallback onTap;
  const _NotificationCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: !item.read ? AppColors.primaryContainer.withOpacity(0.06) : Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          boxShadow: AppShadows.soft,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: AppColors.surfaceContainer, shape: BoxShape.circle),
              child: Icon(_iconFor(item.type), size: 20, color: AppColors.primary),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(item.title, style: AppTextStyles.labelLg)),
                      Text(_timeAgo(item.createdAt), style: AppTextStyles.labelSm.copyWith(color: AppColors.onSurfaceVariant)),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(item.body, style: AppTextStyles.bodyMd.copyWith(color: AppColors.onSurfaceVariant)),
                ],
              ),
            ),
            if (!item.read) Container(width: 8, height: 8, margin: const EdgeInsets.only(top: 4), decoration: const BoxDecoration(color: AppColors.error, shape: BoxShape.circle)),
          ],
        ),
      ),
    );
  }
}
