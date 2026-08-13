import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/session_controller.dart';

/// Maps to: taskpoint_launch_screen/code.html
///
/// Waits for [SessionController] to resolve the real Firebase Auth state
/// (signed out / signed in but mid-onboarding / fully onboarded) and routes
/// to wherever that user actually belongs, instead of always going to
/// onboarding. A short minimum display time keeps the splash from flashing
/// by instantly on a fast auth check.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    SessionController.instance.addListener(_onSessionChanged);
    Future.delayed(const Duration(milliseconds: 1200), _tryNavigate);
  }

  bool _minTimeElapsed = false;

  void _tryNavigate() {
    _minTimeElapsed = true;
    _maybeGo();
  }

  void _onSessionChanged() => _maybeGo();

  void _maybeGo() {
    if (!mounted) return;
    if (!_minTimeElapsed) return;
    if (SessionController.instance.status == SessionStatus.loading) return;
    SessionController.instance.removeListener(_onSessionChanged);
    Navigator.of(context).pushReplacementNamed(SessionController.instance.startRoute);
  }

  @override
  void dispose() {
    SessionController.instance.removeListener(_onSessionChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Replace with Image.asset('assets/images/taskpoint_logo.png')
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Center(
                child: Text('TP', style: TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 12),
            Text('TaskPoint', style: AppTextStyles.headlineLg.copyWith(color: AppColors.primary)),
            const SizedBox(height: 8),
            Text(
              'AI-Assisted Labour Marketplace',
              style: AppTextStyles.bodyMd.copyWith(color: AppColors.onSurfaceVariant.withOpacity(0.8)),
            ),
            const SizedBox(height: 48),
            SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(strokeWidth: 3, color: AppColors.primary, backgroundColor: AppColors.surfaceContainerHighest),
            ),
          ],
        ),
      ),
    );
  }
}
