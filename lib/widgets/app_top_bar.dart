import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

/// Simple back-button + centered title bar used on most secondary screens
/// (role_selection, cnic_verification, job_alert_detail, my_jobs, etc.)
class AppTopBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final IconData leadingIcon;
  final VoidCallback? onLeadingTap;
  final Widget? trailing;

  const AppTopBar({
    super.key,
    required this.title,
    this.leadingIcon = Symbols.arrow_back_rounded,
    this.onLeadingTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      leading: IconButton(
        icon: Icon(leadingIcon),
        onPressed: onLeadingTap ?? () => Navigator.of(context).maybePop(),
      ),
      title: Text(title),
      actions: trailing == null ? null : [trailing!, const SizedBox(width: 8)],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(56);
}
