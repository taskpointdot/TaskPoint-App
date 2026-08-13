import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../theme/app_theme.dart';

enum AppTab { home, jobs, messages, profile }

/// The persistent bottom nav bar seen on Home, My Jobs, Worker Offers, etc.
/// (see role_selection / home_dashboard_discovery / my_jobs_tracking code.html)
class AppBottomNav extends StatelessWidget {
  final AppTab current;
  final ValueChanged<AppTab> onTap;

  const AppBottomNav({super.key, required this.current, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        height: 64,
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: AppColors.surface.withOpacity(0.95),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.outlineVariant.withOpacity(0.4)),
          boxShadow: AppShadows.soft,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _NavItem(icon: Symbols.home_rounded, label: 'Home', tab: AppTab.home, current: current, onTap: onTap),
            _NavItem(icon: Symbols.work_rounded, label: 'My Jobs', tab: AppTab.jobs, current: current, onTap: onTap, showDot: false),
            _NavItem(icon: Symbols.chat_rounded, label: 'Messages', tab: AppTab.messages, current: current, onTap: onTap, showDot: true),
            _NavItem(icon: Symbols.person_rounded, label: 'Profile', tab: AppTab.profile, current: current, onTap: onTap),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final AppTab tab;
  final AppTab current;
  final ValueChanged<AppTab> onTap;
  final bool showDot;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.tab,
    required this.current,
    required this.onTap,
    this.showDot = false,
  });

  @override
  Widget build(BuildContext context) {
    final active = tab == current;
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.full),
      onTap: () => onTap(tab),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: active ? AppColors.secondaryContainer : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.full),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(icon, color: active ? AppColors.onSecondaryContainer : AppColors.onSurfaceVariant, size: 22),
                if (showDot)
                  Positioned(
                    top: -2,
                    right: -2,
                    child: Container(width: 7, height: 7, decoration: const BoxDecoration(color: AppColors.error, shape: BoxShape.circle)),
                  ),
              ],
            ),
            const SizedBox(height: 2),
            Text(label, style: AppTextStyles.labelSm.copyWith(color: active ? AppColors.onSecondaryContainer : AppColors.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}
