import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../theme/app_theme.dart';
import '../models/ui_models.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/notification_bell.dart';
import '../services/categories_service.dart';
import '../main.dart' show AppRoutes;
import 'my_jobs_tracking_screen.dart';
import 'profile_settings_screen.dart';

/// Maps to: home_voice_job_posting/code.html (and home_updated_tokens/code.html,
/// which is the same screen with refreshed design tokens — merged into one).
class HomeVoiceJobPostingScreen extends StatefulWidget {
  final ValueChanged<ServiceCategory>? onCategoryTap;
  final VoidCallback? onMicTap;
  const HomeVoiceJobPostingScreen({super.key, this.onCategoryTap, this.onMicTap});

  @override
  State<HomeVoiceJobPostingScreen> createState() => _HomeVoiceJobPostingScreenState();
}

class _HomeVoiceJobPostingScreenState extends State<HomeVoiceJobPostingScreen> {
  AppTab _tab = AppTab.home;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(icon: const Icon(Symbols.arrow_back_rounded, color: AppColors.primary), onPressed: () => Navigator.of(context).maybePop()),
        title: Text('TaskPoint', style: AppTextStyles.headlineMd.copyWith(color: AppColors.primary, fontWeight: FontWeight.w700)),
        centerTitle: true,
        actions: [
          NotificationBellButton(iconColor: AppColors.primary),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(AppSpacing.marginMobile, AppSpacing.lg, AppSpacing.marginMobile, 100),
          children: [
            const SizedBox(height: AppSpacing.md),
            Text('Tap to speak your job request', textAlign: TextAlign.center, style: AppTextStyles.headlineMd),
            const SizedBox(height: AppSpacing.xl),
            Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(color: AppColors.brandTeal.withOpacity(0.25), shape: BoxShape.circle),
                  ),
                  InkWell(
                    onTap: widget.onMicTap,
                    customBorder: const CircleBorder(),
                    child: Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(color: AppColors.brandTeal, shape: BoxShape.circle, boxShadow: AppShadows.active),
                      child: const Icon(Symbols.mic_rounded, color: Colors.white, size: 40, fill: 1),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('Or select a category below', textAlign: TextAlign.center, style: AppTextStyles.bodyMd.copyWith(color: AppColors.onSurfaceVariant)),
            const SizedBox(height: AppSpacing.lg),
            StreamBuilder<List<ServiceCategory>>(
              stream: CategoriesService.instance.watchAll(),
              builder: (context, snap) {
                final categories = snap.data ?? const [];
                if (!snap.hasData) return const Padding(padding: EdgeInsets.symmetric(vertical: 24), child: Center(child: CircularProgressIndicator()));
                return GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: AppSpacing.md,
                  crossAxisSpacing: AppSpacing.md,
                  childAspectRatio: 1,
                  children: [
                    for (final cat in categories)
                      InkWell(
                        borderRadius: BorderRadius.circular(24),
                        onTap: () => widget.onCategoryTap?.call(cat),
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.surfaceContainerLowest,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: AppShadows.soft,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 64,
                                height: 64,
                                decoration: BoxDecoration(color: AppColors.surfaceContainerLow, shape: BoxShape.circle),
                                child: Icon(cat.icon, color: AppColors.brandTeal, size: 30),
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              Text(cat.name, style: AppTextStyles.labelLg),
                            ],
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
      bottomNavigationBar: AppBottomNav(
        current: _tab,
        onTap: (t) {
          setState(() => _tab = t);
          if (t == AppTab.jobs) {
            Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MyJobsTrackingScreen()));
          } else if (t == AppTab.profile) {
            Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ProfileSettingsScreen()));
          } else if (t == AppTab.messages) {
            Navigator.of(context).pushNamed(AppRoutes.aiAssistantChat);
          }
        },
      ),
    );
  }
}
