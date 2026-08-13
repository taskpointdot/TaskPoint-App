import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../theme/app_theme.dart';
import '../widgets/app_top_bar.dart';
import '../widgets/buttons.dart';
import '../main.dart' show AppRoutes;
import '../models/app_user.dart';
import '../services/session_controller.dart';
import 'cnic_verification_screen.dart';

/// Maps to: role_selection/code.html
class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  UserRole selected = UserRole.seeker;
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppTopBar(title: 'TaskPoint'),
      // Scrollable content — fixes "RenderFlex overflowed" on smaller
      // screens / larger text scales, since a Column+Spacer can't scroll.
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(AppRadius.xl),
                  boxShadow: AppShadows.soft,
                ),
                child: Text(
                  'Aap TaskPoint ko kis tarah istemal karna chahte hain?',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.headlineLgMobile,
                ),
              ),
              const SizedBox(height: 24),
              _RoleCard(
                title: 'Mujhe Kaam Karwana Hai',
                subtitle: 'Find reliable professionals for home tasks',
                icon: Symbols.home_rounded,
                active: selected == UserRole.seeker,
                onTap: () => setState(() => selected = UserRole.seeker),
              ),
              const SizedBox(height: 16),
              _RoleCard(
                title: 'Mujhe Kaam Karna Hai',
                subtitle: 'Browse available jobs and earn money',
                icon: Symbols.build_rounded,
                active: selected == UserRole.worker,
                onTap: () => setState(() => selected = UserRole.worker),
              ),
            ],
          ),
        ),
      ),
      // Fixed footer button instead of Column+Spacer, so it never fights
      // the scroll view for space.
      bottomSheet: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          decoration: BoxDecoration(
            color: AppColors.background,
            border: Border(top: BorderSide(color: AppColors.outlineVariant.withOpacity(0.2))),
          ),
          child: PrimaryButton(
            label: _saving ? 'Saving...' : 'Confirm Selection',
            // Both seekers and providers must verify their CNIC first —
            // only which home screen they land on afterwards differs.
            onPressed: _saving
                ? null
                : () async {
                    setState(() => _saving = true);
                    try {
                      await SessionController.instance.setRole(selected);
                    } finally {
                      if (mounted) setState(() => _saving = false);
                    }
                    if (!context.mounted) return;
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => CnicVerificationScreen(
                          onVerified: () => Navigator.of(context).pushReplacementNamed(
                            selected == UserRole.seeker ? AppRoutes.home : AppRoutes.workerHome,
                          ),
                        ),
                      ),
                    );
                  },
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  const _RoleCard({required this.title, required this.subtitle, required this.icon, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.xl),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: Border.all(color: active ? AppColors.primary : Colors.transparent, width: 2),
          boxShadow: active ? AppShadows.active : AppShadows.soft,
        ),
        child: Stack(
          children: [
            if (active)
              const Positioned(
                top: 0,
                right: 0,
                child: Icon(Symbols.check_circle_rounded, color: AppColors.primary, fill: 1),
              ),
            Column(
              children: [
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(color: AppColors.surfaceContainer, shape: BoxShape.circle),
                  child: Icon(icon, color: active ? AppColors.primary : AppColors.outline, size: 44),
                ),
                const SizedBox(height: 16),
                Text(title, textAlign: TextAlign.center, style: AppTextStyles.headlineMd),
                const SizedBox(height: 8),
                Text(subtitle, textAlign: TextAlign.center, style: AppTextStyles.bodyMd.copyWith(color: AppColors.onSurfaceVariant)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
