import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../theme/app_theme.dart';
import '../theme/app_settings_controller.dart';
import '../widgets/app_top_bar.dart';
import '../main.dart' show AppRoutes;
import '../services/session_controller.dart';
import 'edit_account_screen.dart';

/// Maps to: profile_settings/code.html
class ProfileSettingsScreen extends StatefulWidget {
  const ProfileSettingsScreen({super.key});

  @override
  State<ProfileSettingsScreen> createState() => _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends State<ProfileSettingsScreen> {
  Future<void> _editAccount() async {
    final me = SessionController.instance.user;
    if (me == null) return;
    final result = await Navigator.of(context).push<Map<String, String>>(
      MaterialPageRoute(builder: (_) => EditAccountScreen(initialName: me.name, initialPhone: me.phone, initialEmail: me.email)),
    );
    if (result == null || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(t(context, en: 'Account details updated', ur: 'Account details update ho gayin'))),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Listens to both AppSettingsController (Dark Mode / language) and
    // SessionController (live profile data) so this screen rebuilds when
    // either changes.
    return ListenableBuilder(
      listenable: Listenable.merge([AppSettingsController.instance, SessionController.instance]),
      builder: (context, _) {
        final settings = AppSettingsController.instance;
        final me = SessionController.instance.user;
        return Scaffold(
          appBar: AppTopBar(title: t(context, en: 'Settings', ur: 'ترتیبات / Settings')),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(color: AppColors.surfaceContainerLowest, borderRadius: BorderRadius.circular(AppRadius.xl), boxShadow: AppShadows.soft),
                  child: Column(
                    children: [
                      const CircleAvatar(radius: 48, backgroundColor: AppColors.surfaceContainer, child: Icon(Symbols.person_rounded, size: 48, color: AppColors.onSurfaceVariant)),
                      const SizedBox(height: 12),
                      Text(me?.name.isNotEmpty == true ? me!.name : 'Add your name', style: AppTextStyles.headlineMd),
                      Text(me?.phone ?? '', style: AppTextStyles.bodyMd.copyWith(color: AppColors.onSurfaceVariant)),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  decoration: BoxDecoration(color: AppColors.surfaceContainerLowest, borderRadius: BorderRadius.circular(AppRadius.xl), boxShadow: AppShadows.soft),
                  child: Column(
                    children: [
                      _SettingsTile(icon: Symbols.person_rounded, label: t(context, en: 'Edit Account', ur: 'Account Edit Karain'), onTap: _editAccount),
                      const Divider(height: 1),
                      _SettingsTile(
                        icon: Symbols.contacts_rounded,
                        label: t(context, en: 'Emergency Contacts List', ur: 'Emergency Contacts List'),
                        onTap: () => Navigator.of(context).pushNamed(AppRoutes.emergencyContacts),
                      ),
                      const Divider(height: 1),
                      _SettingsTile(
                        icon: Symbols.receipt_long_rounded,
                        label: t(context, en: 'Transaction History', ur: 'Transaction History'),
                        onTap: () => Navigator.of(context).pushNamed(AppRoutes.transactionDetails),
                      ),
                      const Divider(height: 1),
                      SwitchListTile(
                        value: settings.isDarkMode,
                        onChanged: settings.setDarkMode,
                        activeThumbColor: AppColors.brandTeal,
                        secondary: const Icon(Symbols.dark_mode_rounded, color: AppColors.outline),
                        title: Text(t(context, en: 'Dark Mode', ur: 'Dark Mode'), style: AppTextStyles.bodyLg),
                      ),
                      const Divider(height: 1),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Symbols.language_rounded, color: AppColors.outline),
                                const SizedBox(width: 12),
                                Text(t(context, en: 'Language', ur: 'Zaban'), style: AppTextStyles.bodyLg),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(color: AppColors.surfaceContainerHigh, borderRadius: BorderRadius.circular(AppRadius.full)),
                              child: Row(
                                children: [
                                  Expanded(child: _LangOption(label: 'English', active: settings.isEnglish, onTap: () => settings.setEnglish(true))),
                                  Expanded(child: _LangOption(label: 'Roman Urdu', active: !settings.isEnglish, onTap: () => settings.setEnglish(false))),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Center(
                  child: TextButton.icon(
                    onPressed: () async {
                      await SessionController.instance.signOut();
                      if (context.mounted) Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.splash, (route) => false);
                    },
                    icon: const Icon(Symbols.logout_rounded, color: AppColors.error),
                    label: Text(t(context, en: 'Logout Account', ur: 'Logout Karain'), style: AppTextStyles.labelLg.copyWith(color: AppColors.error)),
                  ),
                ),
              ],
            ),
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
  const _SettingsTile({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: AppColors.outline),
      title: Text(label, style: AppTextStyles.bodyLg),
      trailing: const Icon(Symbols.chevron_right_rounded, color: AppColors.outlineVariant),
    );
  }
}

class _LangOption extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _LangOption({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(color: active ? AppColors.surfaceContainerLowest : Colors.transparent, borderRadius: BorderRadius.circular(20), boxShadow: active ? AppShadows.soft : null),
        child: Text(label, textAlign: TextAlign.center, style: AppTextStyles.labelLg.copyWith(color: active ? AppColors.primary : AppColors.onSurfaceVariant)),
      ),
    );
  }
}
