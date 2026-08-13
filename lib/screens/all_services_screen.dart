import 'package:flutter/material.dart';
import '../models/ui_models.dart';
import '../theme/app_theme.dart';
import '../widgets/app_top_bar.dart';
import '../widgets/post_job_sheet.dart';
import '../services/categories_service.dart';
import '../services/jobs_service.dart';
import '../services/session_controller.dart';
import '../services/geo_utils.dart';
import 'request_success_screen.dart';

/// Reached by tapping "See All" next to "Services" on HomeDashboardScreen.
/// Shows every category from Firestore, not just the handful that fit in
/// the home screen's preview grid. Tapping one quick-posts a job in it,
/// same as the home dashboard's category grid.
class AllServicesScreen extends StatefulWidget {
  const AllServicesScreen({super.key});

  @override
  State<AllServicesScreen> createState() => _AllServicesScreenState();
}

class _AllServicesScreenState extends State<AllServicesScreen> {
  bool _posting = false;

  Future<void> _quickPost(ServiceCategory category) async {
    if (_posting) return;
    final details = await showPostJobSheet(context, categoryName: category.name, categoryIcon: category.icon);
    if (details == null || !mounted) return;
    setState(() => _posting = true);
    try {
      final uid = SessionController.instance.uid;
      if (uid == null) return;
      final position = await currentDevicePosition();
      final jobId = await JobsService.instance.postJob(
        seekerId: uid,
        categoryId: category.id.isEmpty ? null : category.id,
        categoryName: category.name,
        description: details.description,
        budget: details.budget,
        location: position,
      );
      if (!mounted) return;
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => RequestSuccessScreen(jobId: jobId)));
    } finally {
      if (mounted) setState(() => _posting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppTopBar(title: 'All Services'),
      body: SafeArea(
        child: StreamBuilder<List<ServiceCategory>>(
          stream: CategoriesService.instance.watchAll(),
          builder: (context, snap) {
            final categories = snap.data ?? const [];
            if (!snap.hasData) return const Center(child: CircularProgressIndicator());
            return GridView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              itemCount: categories.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 1,
              ),
              itemBuilder: (context, i) {
                final c = categories[i];
                return InkWell(
                  borderRadius: BorderRadius.circular(AppRadius.xl),
                  onTap: _posting ? null : () => _quickPost(c),
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(AppRadius.xl),
                      boxShadow: AppShadows.soft,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: const BoxDecoration(color: AppColors.secondaryContainer, shape: BoxShape.circle),
                          child: Icon(c.icon, color: AppColors.onSecondaryContainer, size: 28),
                        ),
                        const SizedBox(height: 8),
                        Text(c.name, style: AppTextStyles.labelLg),
                        Text(c.localName, style: AppTextStyles.labelSm.copyWith(color: AppColors.onSurfaceVariant.withOpacity(0.7))),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
