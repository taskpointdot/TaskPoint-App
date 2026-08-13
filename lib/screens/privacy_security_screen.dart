import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../main.dart' show AppRoutes;
import '../services/privacy_security_service.dart';
import '../services/session_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/app_top_bar.dart';
import 'change_password_screen.dart';
import 'manage_devices_screen.dart';

/// New screen — previously missing. The "Privacy & Security" tile on
/// ProfileSettingsWorkerScreen had an empty `onTap: () {}` and went
/// nowhere. This is that screen: account-security toggles plus data
/// actions, styled to match the rest of the worker profile section.
class PrivacySecurityScreen extends StatefulWidget {
  const PrivacySecurityScreen({super.key});

  @override
  State<PrivacySecurityScreen> createState() => _PrivacySecurityScreenState();
}

class _PrivacySecurityScreenState extends State<PrivacySecurityScreen> {
  final PrivacySecurityService _service = PrivacySecurityService();

  late bool _profileVisible = SessionController.instance.user?.profileVisible ?? true;
  late bool _shareLiveLocation = SessionController.instance.user?.shareLiveLocation ?? true;
  late bool _twoFactorAuth = SessionController.instance.user?.twoFactorEnabled ?? false;

  // Per-row "saving" flags so a toggle can show a spinner and be disabled
  // while its request is in flight, without blocking the rest of the page.
  bool _savingProfileVisible = false;
  bool _savingShareLocation = false;
  bool _savingTwoFactor = false;
  bool _downloadingData = false;
  bool _deletingAccount = false;

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.error),
    );
  }

  Future<void> _toggleProfileVisible(bool value) async {
    final previous = _profileVisible;
    setState(() {
      _profileVisible = value;
      _savingProfileVisible = true;
    });
    try {
      await _service.updateShowProfileToCustomers(value);
    } catch (e) {
      if (!mounted) return;
      setState(() => _profileVisible = previous); // revert on failure
      _showError('Could not update profile visibility. Please try again.');
    } finally {
      if (mounted) setState(() => _savingProfileVisible = false);
    }
  }

  Future<void> _toggleShareLiveLocation(bool value) async {
    final previous = _shareLiveLocation;
    setState(() {
      _shareLiveLocation = value;
      _savingShareLocation = true;
    });
    try {
      await _service.updateShareLiveLocation(value);
    } catch (e) {
      if (!mounted) return;
      setState(() => _shareLiveLocation = previous);
      _showError('Could not update location sharing. Please try again.');
    } finally {
      if (mounted) setState(() => _savingShareLocation = false);
    }
  }

  Future<void> _toggleTwoFactorAuth(bool value) async {
    final previous = _twoFactorAuth;
    setState(() {
      _twoFactorAuth = value;
      _savingTwoFactor = true;
    });
    try {
      await _service.updateTwoFactorAuth(value);
    } catch (e) {
      if (!mounted) return;
      setState(() => _twoFactorAuth = previous);
      _showError('Could not update two-factor authentication. Please try again.');
    } finally {
      if (mounted) setState(() => _savingTwoFactor = false);
    }
  }

  Future<void> _downloadMyData() async {
    if (_downloadingData) return;
    setState(() => _downloadingData = true);
    try {
      await _service.requestDataExport();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('We will email you a copy of your data')),
      );
    } catch (e) {
      _showError('Could not request your data export. Please try again.');
    } finally {
      if (mounted) setState(() => _downloadingData = false);
    }
  }

  Future<void> _confirmDeleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Account?'),
        content: const Text('This permanently removes your TaskPoint account and all associated data. This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _deletingAccount = true);
    try {
      await _service.deleteAccount();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Your account has been deleted')),
      );
      // deleteAccount() removes the Firebase Auth user, but the app was
      // left sitting on the Privacy screen still rendering the deleted
      // profile until something happened to force a rebuild. Tear the
      // session down and go back to the start of the flow.
      await SessionController.instance.signOut();
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.splash, (route) => false);
      return;
    } catch (e) {
      _showError('Could not delete your account. Please try again.');
    } finally {
      if (mounted) setState(() => _deletingAccount = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppTopBar(title: 'Privacy & Security'),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(AppSpacing.marginMobile, AppSpacing.md, AppSpacing.marginMobile, AppSpacing.xl),
          children: [
            Text('Privacy', style: AppTextStyles.labelLg.copyWith(color: AppColors.onSurfaceVariant)),
            const SizedBox(height: AppSpacing.sm),
            _SettingsCard(
              children: [
                _SwitchRow(
                  icon: Symbols.visibility_rounded,
                  title: 'Show Profile to Customers',
                  subtitle: 'Your name, rating and skills are visible to seekers nearby.',
                  value: _profileVisible,
                  saving: _savingProfileVisible,
                  onChanged: _toggleProfileVisible,
                ),
                const Divider(height: 1),
                _SwitchRow(
                  icon: Symbols.location_on_rounded,
                  title: 'Share Live Location',
                  subtitle: 'Let customers track you in real time during an active job.',
                  value: _shareLiveLocation,
                  saving: _savingShareLocation,
                  onChanged: _toggleShareLiveLocation,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('Security', style: AppTextStyles.labelLg.copyWith(color: AppColors.onSurfaceVariant)),
            const SizedBox(height: AppSpacing.sm),
            _SettingsCard(
              children: [
                _SwitchRow(
                  icon: Symbols.shield_lock_rounded,
                  title: 'Two-Factor Authentication',
                  subtitle: 'Require an OTP on top of your password when signing in.',
                  value: _twoFactorAuth,
                  saving: _savingTwoFactor,
                  onChanged: _toggleTwoFactorAuth,
                ),
                const Divider(height: 1),
                _ActionRow(
                  icon: Symbols.password_rounded,
                  title: 'Change Password',
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ChangePasswordScreen())),
                ),
                const Divider(height: 1),
                _ActionRow(
                  icon: Symbols.devices_rounded,
                  title: 'Manage Logged-in Devices',
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ManageDevicesScreen())),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('Your Data', style: AppTextStyles.labelLg.copyWith(color: AppColors.onSurfaceVariant)),
            const SizedBox(height: AppSpacing.sm),
            _SettingsCard(
              children: [
                _ActionRow(
                  icon: Symbols.download_rounded,
                  title: 'Download My Data',
                  loading: _downloadingData,
                  onTap: _downloadingData ? null : _downloadMyData,
                ),
                const Divider(height: 1),
                _ActionRow(
                  icon: Symbols.delete_forever_rounded,
                  title: 'Delete Account',
                  danger: true,
                  loading: _deletingAccount,
                  onTap: _deletingAccount ? null : _confirmDeleteAccount,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;
  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppRadius.lg), boxShadow: AppShadows.soft),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final bool saving;
  final ValueChanged<bool> onChanged;
  const _SwitchRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    this.saving = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.sm, AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.labelLg),
                const SizedBox(height: 2),
                Text(subtitle, style: AppTextStyles.bodyMd.copyWith(color: AppColors.onSurfaceVariant)),
              ],
            ),
          ),
          if (saving)
            const SizedBox(
              width: 24,
              height: 24,
              child: Padding(
                padding: EdgeInsets.all(2),
                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
              ),
            )
          else
            Switch(value: value, onChanged: onChanged, activeThumbColor: AppColors.primary),
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback? onTap;
  final bool danger;
  final bool loading;
  const _ActionRow({required this.icon, required this.title, required this.onTap, this.danger = false, this.loading = false});

  @override
  Widget build(BuildContext context) {
    final color = danger ? AppColors.error : AppColors.onSurface;
    return ListTile(
      leading: Icon(icon, color: danger ? AppColors.error : AppColors.primary),
      title: Text(title, style: AppTextStyles.bodyLg.copyWith(color: color)),
      trailing: loading
          ? SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: danger ? AppColors.error : AppColors.primary),
            )
          : (danger ? null : const Icon(Symbols.chevron_right_rounded, color: AppColors.onSurfaceVariant)),
      onTap: onTap,
    );
  }
}
