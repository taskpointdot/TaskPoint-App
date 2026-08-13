import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../theme/app_theme.dart';
import '../main.dart' show AppRoutes;
import '../services/session_controller.dart';

/// The side menu opened by the hamburger icon on the home dashboards.
/// Previously the hamburger `IconButton`s on both HomeDashboardScreen and
/// WorkerHomeDashboardScreen had empty `onPressed: () {}` callbacks and no
/// `Scaffold.drawer` was ever set, so tapping the icon did nothing. This
/// widget is that missing drawer; [isWorker] switches between the seeker
/// and worker menu items.
class AppDrawer extends StatelessWidget {
  final bool isWorker;
  const AppDrawer({super.key, this.isWorker = false});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: AppColors.surface,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(color: AppColors.primaryContainer, shape: BoxShape.circle),
                    child: const Icon(Symbols.person_rounded, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('TaskPoint', style: AppTextStyles.headlineMd.copyWith(color: AppColors.primary, fontWeight: FontWeight.w700)),
                        Text(isWorker ? 'Worker Account' : 'Seeker Account', style: AppTextStyles.bodyMd.copyWith(color: AppColors.onSurfaceVariant)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: isWorker ? _workerItems(context) : _seekerItems(context),
              ),
            ),
            const Divider(height: 1),
            _DrawerTile(
              icon: Symbols.logout_rounded,
              label: 'Logout',
              danger: true,
              onTap: () async {
                Navigator.of(context).pop();
                await SessionController.instance.signOut();
                if (context.mounted) Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.splash, (route) => false);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  List<Widget> _seekerItems(BuildContext context) {
    return [
      _DrawerTile(
        icon: Symbols.home_rounded,
        label: 'Home',
        onTap: () => Navigator.of(context).pop(),
      ),
      _DrawerTile(
        icon: Symbols.work_rounded,
        label: 'My Jobs',
        onTap: () => _go(context, AppRoutes.myJobsTracking),
      ),
      _DrawerTile(
        icon: Symbols.receipt_long_rounded,
        label: 'Transactions',
        onTap: () => _go(context, AppRoutes.transactionDetails),
      ),
      _DrawerTile(
        icon: Symbols.person_rounded,
        label: 'Profile & Settings',
        onTap: () => _go(context, AppRoutes.profileSettings),
      ),
      _DrawerTile(
        icon: Symbols.emergency_rounded,
        label: 'Emergency Contacts',
        onTap: () => _go(context, AppRoutes.emergencyContacts),
      ),
      _DrawerTile(
        icon: Symbols.support_agent_rounded,
        label: 'Report a Problem',
        onTap: () => _go(context, AppRoutes.reportProblem),
      ),
    ];
  }

  List<Widget> _workerItems(BuildContext context) {
    return [
      _DrawerTile(
        icon: Symbols.home_rounded,
        label: 'Home',
        onTap: () => Navigator.of(context).pop(),
      ),
      // "Job Offers" and "Job History" both pointed at jobHistory, so the
      // drawer had two identical entries under different names. Incoming
      // offers actually live on the worker home dashboard's live feed.
      _DrawerTile(
        icon: Symbols.work_rounded,
        label: 'Job Offers',
        onTap: () => _go(context, AppRoutes.workerHome),
      ),
      _DrawerTile(
        icon: Symbols.history_rounded,
        label: 'Job History',
        onTap: () => _go(context, AppRoutes.jobHistory),
      ),
      _DrawerTile(
        icon: Symbols.account_balance_wallet_rounded,
        label: 'Earnings & Wallet',
        onTap: () => _go(context, AppRoutes.earningsWallet),
      ),
      _DrawerTile(
        icon: Symbols.insights_rounded,
        label: 'Performance Insights',
        onTap: () => _go(context, AppRoutes.performanceInsights),
      ),
      _DrawerTile(
        icon: Symbols.notifications_rounded,
        label: 'Notifications',
        onTap: () => _go(context, AppRoutes.notificationsInbox),
      ),
      _DrawerTile(
        icon: Symbols.person_rounded,
        label: 'Profile & Settings',
        onTap: () => _go(context, AppRoutes.workerProfileSettings),
      ),
      _DrawerTile(
        icon: Symbols.support_agent_rounded,
        label: 'Report a Problem',
        onTap: () => _go(context, AppRoutes.reportProblem),
      ),
    ];
  }

  void _go(BuildContext context, String route) {
    Navigator.of(context).pop();
    Navigator.of(context).pushNamed(route);
  }
}

class _DrawerTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;
  const _DrawerTile({required this.icon, required this.label, required this.onTap, this.danger = false});

  @override
  Widget build(BuildContext context) {
    final color = danger ? AppColors.error : AppColors.onSurface;
    return ListTile(
      leading: Icon(icon, color: danger ? AppColors.error : AppColors.primary),
      title: Text(label, style: AppTextStyles.labelLg.copyWith(color: color)),
      onTap: onTap,
    );
  }
}
