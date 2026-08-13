import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../theme/app_theme.dart';
import 'emergency_contacts_screen.dart';

/// Maps to: no_emergency_contacts_found/code.html
class NoEmergencyContactsScreen extends StatelessWidget {
  const NoEmergencyContactsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(icon: const Icon(Symbols.close_rounded, color: AppColors.primary), onPressed: () => Navigator.of(context).maybePop()),
        title: Text('Emergency SOS', style: AppTextStyles.headlineMd.copyWith(color: AppColors.primary, fontWeight: FontWeight.w700)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.marginMobile),
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(24),
                boxShadow: AppShadows.soft,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(color: AppColors.errorContainer, shape: BoxShape.circle),
                    child: Icon(Symbols.warning_rounded, color: AppColors.onErrorContainer, fill: 1, size: 32),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text('No Emergency Contacts Found', style: AppTextStyles.headlineLgMobile, textAlign: TextAlign.center),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'You currently have no emergency contacts saved in TaskPoint. For your safety, please add a contact so we can reach them if needed.',
                    style: AppTextStyles.bodyLg.copyWith(color: AppColors.onSurfaceVariant),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const EmergencyContactsScreen())),
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md))),
                      icon: const Icon(Symbols.person_add_rounded, size: 20),
                      label: Text('Add Contact Immediately', style: AppTextStyles.labelLg.copyWith(color: Colors.white)),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md))),
                      child: Text('Remind Me Later', style: AppTextStyles.labelLg.copyWith(color: AppColors.onSurfaceVariant)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
