import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../theme/app_theme.dart';
import '../main.dart' show AppRoutes;
import '../models/app_notification.dart';
import '../services/job_navigation.dart';
import '../services/notifications_service.dart';
import '../services/session_controller.dart';

/// Bell icon used on the seeker and worker home app bars.
///
/// Opens a small dropdown panel anchored right below the bell itself,
/// showing the current user's most recent real notifications; a "View all"
/// link at the bottom reaches the full notifications screen.
class NotificationBellButton extends StatefulWidget {
  final Color? iconColor;
  const NotificationBellButton({super.key, this.iconColor});

  @override
  State<NotificationBellButton> createState() => _NotificationBellButtonState();
}

class _NotificationBellButtonState extends State<NotificationBellButton> {
  final LayerLink _link = LayerLink();
  OverlayEntry? _entry;

  void _toggle() {
    if (_entry != null) {
      _close();
    } else {
      _open();
    }
  }

  void _open() {
    final overlay = Overlay.of(context);
    _entry = OverlayEntry(
      builder: (context) => Stack(
        children: [
          Positioned.fill(child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: _close)),
          CompositedTransformFollower(
            link: _link,
            showWhenUnlinked: false,
            targetAnchor: Alignment.bottomRight,
            followerAnchor: Alignment.topRight,
            offset: const Offset(0, 8),
            child: _NotificationDropdownPanel(
              onViewAll: () {
                _close();
                Navigator.of(context).pushNamed(AppRoutes.notificationsInbox);
              },
              onItemTap: _openNotification,
            ),
          ),
        ],
      ),
    );
    overlay.insert(_entry!);
  }

  void _close() {
    _entry?.remove();
    _entry = null;
  }

  /// Dismiss the overlay first, then mark read and jump to the job the
  /// notification is about. Uses this State's own `context`, not the
  /// overlay builder's, since the overlay entry is gone by then.
  Future<void> _openNotification(AppNotification item) async {
    _close();
    final uid = SessionController.instance.uid;
    if (uid != null) await NotificationsService.instance.markRead(uid, item.id);
    if (item.jobId == null || !mounted) return;
    await openJobById(context, item.jobId!);
  }

  @override
  void dispose() {
    _close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final uid = SessionController.instance.uid;
    return CompositedTransformTarget(
      link: _link,
      child: Stack(
        children: [
          IconButton(
            icon: Icon(Symbols.notifications_rounded, color: widget.iconColor),
            onPressed: _toggle,
          ),
          if (uid != null)
            StreamBuilder<int>(
              stream: NotificationsService.instance.watchUnreadCount(uid),
              builder: (context, snap) {
                if ((snap.data ?? 0) == 0) return const SizedBox.shrink();
                return Positioned(
                  top: 12,
                  right: 12,
                  child: Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppColors.error, shape: BoxShape.circle)),
                );
              },
            ),
        ],
      ),
    );
  }
}

class _NotificationDropdownPanel extends StatelessWidget {
  final VoidCallback onViewAll;

  /// Called when a row is tapped, so the owning bell can dismiss its overlay
  /// before the tapped notification's screen is pushed — otherwise the panel
  /// would hang around floating above the new route.
  final ValueChanged<AppNotification> onItemTap;

  const _NotificationDropdownPanel({required this.onViewAll, required this.onItemTap});

  @override
  Widget build(BuildContext context) {
    final uid = SessionController.instance.uid;
    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      color: AppColors.surface,
      child: Container(
        width: 320,
        constraints: const BoxConstraints(maxHeight: 360),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.outlineVariant.withOpacity(0.4)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Text('Notifications', style: AppTextStyles.labelLg.copyWith(fontWeight: FontWeight.w700)),
            ),
            const Divider(height: 1),
            Flexible(
              child: uid == null
                  ? const SizedBox.shrink()
                  : StreamBuilder<List<AppNotification>>(
                      stream: NotificationsService.instance.watch(uid),
                      builder: (context, snap) {
                        final items = (snap.data ?? const []).take(5).toList();
                        if (items.isEmpty) {
                          return Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text('No notifications yet', style: AppTextStyles.bodyMd.copyWith(color: AppColors.onSurfaceVariant)),
                          );
                        }
                        return ListView.separated(
                          shrinkWrap: true,
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          itemCount: items.length,
                          separatorBuilder: (_, _) => const Divider(height: 1),
                          itemBuilder: (context, i) {
                            final item = items[i];
                            return ListTile(
                              dense: true,
                              // These rows had no onTap at all — the dropdown
                              // was purely decorative and the only way out of
                              // it was "View all".
                              onTap: () => onItemTap(item),
                              leading: Icon(
                                Symbols.notifications_rounded,
                                size: 20,
                                color: item.read ? AppColors.onSurfaceVariant : AppColors.primary,
                              ),
                              title: Text(
                                item.title,
                                style: AppTextStyles.labelSm.copyWith(
                                  fontWeight: item.read ? FontWeight.w500 : FontWeight.w700,
                                ),
                              ),
                              subtitle: Text(item.body, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppTextStyles.bodyMd.copyWith(color: AppColors.onSurfaceVariant)),
                            );
                          },
                        );
                      },
                    ),
            ),
            const Divider(height: 1),
            TextButton(
              onPressed: onViewAll,
              child: const Text('View all'),
            ),
          ],
        ),
      ),
    );
  }
}
