import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../theme/app_theme.dart';
import '../widgets/app_top_bar.dart';
import '../widgets/app_bottom_nav.dart';
import '../main.dart' show AppRoutes;
import '../models/app_user.dart';
import '../services/session_controller.dart';
import 'privacy_security_screen.dart';

/// Maps to: profile_settings_worker/code.html
/// Worker-facing profile & settings screen: skills, service radius,
/// verification badge, and account actions. Distinct from the generic
/// (seeker) ProfileSettingsScreen.
class ProfileSettingsWorkerScreen extends StatefulWidget {
  const ProfileSettingsWorkerScreen({super.key});

  @override
  State<ProfileSettingsWorkerScreen> createState() => _ProfileSettingsWorkerScreenState();
}

class _ProfileSettingsWorkerScreenState extends State<ProfileSettingsWorkerScreen> {
  Future<void> _addSkill() async {
    final controller = TextEditingController();
    final skill = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add Skill'),
        content: TextField(controller: controller, autofocus: true, decoration: const InputDecoration(hintText: 'e.g. Welder')),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(controller.text.trim()), child: const Text('Add')),
        ],
      ),
    );
    if (skill == null || skill.isEmpty) return;
    await SessionController.instance.addSkill(skill);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: SessionController.instance,
      builder: (context, _) {
        final me = SessionController.instance.user;
        return Scaffold(
      appBar: const AppTopBar(title: 'Profile Settings'),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(AppSpacing.marginMobile, AppSpacing.md, AppSpacing.marginMobile, AppSpacing.xl),
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: AppShadows.soft),
              child: Row(
                children: [
                  Stack(
                    children: [
                      const CircleAvatar(radius: 34, backgroundColor: AppColors.surfaceVariant, child: Icon(Symbols.person_rounded, size: 34, color: AppColors.onSurfaceVariant)),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                          child: const Icon(Symbols.edit_rounded, size: 12, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(me?.name.isNotEmpty == true ? me!.name : 'Add your name', style: AppTextStyles.headlineMd),
                        const SizedBox(height: 4),
                        if (me?.cnicStatus == CnicStatus.verified)
                          Row(
                            children: [
                              const Icon(Symbols.verified_rounded, size: 16, color: AppColors.primary, fill: 1),
                              const SizedBox(width: 4),
                              Text('CNIC Verified', style: AppTextStyles.labelSm.copyWith(color: AppColors.primary)),
                            ],
                          )
                        else
                          Text(
                            me?.cnicStatus == CnicStatus.pending ? 'CNIC Pending Review' : 'CNIC Not Verified',
                            style: AppTextStyles.labelSm.copyWith(color: AppColors.onSurfaceVariant),
                          ),
                        if (me?.createdAt != null) ...[
                          const SizedBox(height: 2),
                          Text('Joined ${me!.createdAt}'.split(' ').first, style: AppTextStyles.labelSm.copyWith(color: AppColors.onSurfaceVariant)),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('My Skills', style: AppTextStyles.headlineMd),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final skill in me?.skills ?? const [])
                  Chip(
                    avatar: const Icon(Symbols.build_rounded, size: 16, color: AppColors.primary),
                    label: Text(skill),
                    onDeleted: () => SessionController.instance.removeSkill(skill),
                    backgroundColor: AppColors.surfaceContainerLowest,
                    side: BorderSide(color: AppColors.outlineVariant.withOpacity(0.4)),
                  ),
                ActionChip(
                  avatar: const Icon(Symbols.add_rounded, size: 16, color: AppColors.primary),
                  label: const Text('Add Skill'),
                  onPressed: _addSkill,
                  backgroundColor: AppColors.primaryContainer.withOpacity(0.1),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppRadius.lg), boxShadow: AppShadows.soft),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Symbols.my_location_rounded, color: AppColors.primary),
                      const SizedBox(width: AppSpacing.sm),
                      Text('Service Radius', style: AppTextStyles.labelLg),
                      const Spacer(),
                      Text('${(me?.serviceRadiusKm ?? 5).toStringAsFixed(0)} km', style: AppTextStyles.labelLg.copyWith(color: AppColors.primary)),
                    ],
                  ),
                  Text('Adjust how far you are willing to travel for jobs.', style: AppTextStyles.bodyMd.copyWith(color: AppColors.onSurfaceVariant)),
                  Slider(
                    value: me?.serviceRadiusKm ?? 5,
                    min: 1,
                    max: 25,
                    divisions: 24,
                    activeColor: AppColors.primary,
                    onChanged: (v) => SessionController.instance.updateServiceRadius(v),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('1 km', style: AppTextStyles.labelSm.copyWith(color: AppColors.onSurfaceVariant)),
                      Text('12 km', style: AppTextStyles.labelSm.copyWith(color: AppColors.onSurfaceVariant)),
                      Text('25 km', style: AppTextStyles.labelSm.copyWith(color: AppColors.onSurfaceVariant)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            _SettingsTile(icon: Symbols.notifications_rounded, label: 'Notifications', onTap: () => Navigator.of(context).pushNamed(AppRoutes.notificationsInbox)),
            _SettingsTile(icon: Symbols.lock_rounded, label: 'Privacy & Security', onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PrivacySecurityScreen()))),
            _SettingsTile(icon: Symbols.help_rounded, label: 'Help & Support', onTap: () => Navigator.of(context).pushNamed(AppRoutes.reportProblem)),
            _SettingsTile(
              icon: Symbols.logout_rounded,
              label: 'Logout',
              danger: true,
              onTap: () async {
                await SessionController.instance.signOut();
                if (context.mounted) Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.splash, (r) => false);
              },
            ),
          ],
        ),
      ),
      bottomNavigationBar: AppBottomNav(
        current: AppTab.profile,
        onTap: (t) {
          if (t == AppTab.home) {
            Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.workerHome, (r) => r.isFirst);
          } else if (t == AppTab.jobs) {
            Navigator.of(context).pushNamed(AppRoutes.jobHistory);
          } else if (t == AppTab.messages) {
            Navigator.of(context).pushNamed(AppRoutes.notificationsInbox);
          }
        },
      ),
        );
      },
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;
  const _SettingsTile({required this.icon, required this.label, required this.onTap, this.danger = false});

  @override
  Widget build(BuildContext context) {
    final color = danger ? AppColors.error : AppColors.onSurface;
    return Container(
      margin: const EdgeInsets.only(top: AppSpacing.sm),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppRadius.md), boxShadow: AppShadows.soft),
      child: ListTile(
        leading: Icon(icon, color: danger ? AppColors.error : AppColors.primary),
        title: Text(label, style: AppTextStyles.bodyLg.copyWith(color: color)),
        trailing: danger ? null : const Icon(Symbols.chevron_right_rounded, color: AppColors.onSurfaceVariant),
        onTap: onTap,
      ),
    );
  }
}
