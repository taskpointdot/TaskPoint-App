import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../services/privacy_security_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_top_bar.dart';

/// Reached from PrivacySecurityScreen's "Manage Logged-in Devices" row,
/// which previously just showed a "coming soon" snackbar.
class ManageDevicesScreen extends StatefulWidget {
  const ManageDevicesScreen({super.key});

  @override
  State<ManageDevicesScreen> createState() => _ManageDevicesScreenState();
}

class _ManageDevicesScreenState extends State<ManageDevicesScreen> {
  final _service = PrivacySecurityService();
  late Future<List<LoggedInDevice>> _future;
  String? _revokingId;
  bool _revokingAll = false;

  @override
  void initState() {
    super.initState();
    _future = _service.fetchLoggedInDevices();
  }

  Future<void> _refresh() async {
    setState(() => _future = _service.fetchLoggedInDevices());
    await _future;
  }

  Future<void> _revoke(LoggedInDevice device) async {
    setState(() => _revokingId = device.id);
    try {
      await _service.revokeDevice(device.id);
      await _refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Logged out of ${device.name}')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not log out that device. Please try again.'), backgroundColor: AppColors.error));
    } finally {
      if (mounted) setState(() => _revokingId = null);
    }
  }

  Future<void> _revokeAllOthers() async {
    setState(() => _revokingAll = true);
    try {
      await _service.revokeAllOtherDevices();
      await _refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Logged out of all other devices')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not log out other devices. Please try again.'), backgroundColor: AppColors.error));
    } finally {
      if (mounted) setState(() => _revokingAll = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppTopBar(title: 'Logged-in Devices'),
      body: SafeArea(
        child: FutureBuilder<List<LoggedInDevice>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            final devices = snapshot.data ?? const [];
            final others = devices.where((d) => !d.isCurrentDevice).toList();
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                Text(
                  'These are the devices currently signed in to your account.',
                  style: AppTextStyles.bodyMd.copyWith(color: AppColors.onSurfaceVariant),
                ),
                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(color: AppColors.surfaceContainerLowest, borderRadius: BorderRadius.circular(AppRadius.lg), boxShadow: AppShadows.soft),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      for (int i = 0; i < devices.length; i++) ...[
                        if (i > 0) const Divider(height: 1),
                        _DeviceRow(
                          device: devices[i],
                          revoking: _revokingId == devices[i].id,
                          onLogOut: () => _revoke(devices[i]),
                        ),
                      ],
                    ],
                  ),
                ),
                if (others.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  OutlinedButton.icon(
                    onPressed: _revokingAll ? null : _revokeAllOthers,
                    icon: _revokingAll
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Symbols.logout_rounded, size: 18),
                    label: Text(_revokingAll ? 'Logging out...' : 'Log Out of All Other Devices'),
                    style: OutlinedButton.styleFrom(foregroundColor: AppColors.error, side: const BorderSide(color: AppColors.error)),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _DeviceRow extends StatelessWidget {
  final LoggedInDevice device;
  final bool revoking;
  final VoidCallback onLogOut;
  const _DeviceRow({required this.device, required this.revoking, required this.onLogOut});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(
        device.name.toLowerCase().contains('iphone') || device.name.toLowerCase().contains('galaxy') ? Symbols.smartphone_rounded : Symbols.laptop_mac_rounded,
        color: AppColors.primary,
      ),
      title: Row(
        children: [
          Flexible(child: Text(device.name, style: AppTextStyles.labelLg, overflow: TextOverflow.ellipsis)),
          if (device.isCurrentDevice) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: AppColors.statusGreenBg, borderRadius: BorderRadius.circular(AppRadius.full)),
              child: Text('This device', style: AppTextStyles.labelSm.copyWith(color: AppColors.statusGreenFg)),
            ),
          ],
        ],
      ),
      subtitle: Text(device.lastActive, style: AppTextStyles.bodyMd.copyWith(color: AppColors.onSurfaceVariant)),
      trailing: device.isCurrentDevice
          ? null
          : (revoking
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : TextButton(onPressed: onLogOut, child: const Text('Log Out', style: TextStyle(color: AppColors.error)))),
    );
  }
}
