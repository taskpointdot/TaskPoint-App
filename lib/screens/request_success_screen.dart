import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../theme/app_theme.dart';
import '../widgets/buttons.dart';
import 'worker_offers_inbox_screen.dart';

/// Maps to: request_success_radar_broadcasting/code.html
/// The original uses a WebGL shader for the radar pulse; here we recreate
/// the same "expanding rings" effect with a simple CustomPainter + AnimationController.
class RequestSuccessScreen extends StatefulWidget {
  final String jobId;
  const RequestSuccessScreen({super.key, required this.jobId});

  @override
  State<RequestSuccessScreen> createState() => _RequestSuccessScreenState();
}

class _RequestSuccessScreenState extends State<RequestSuccessScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Symbols.arrow_back_rounded, color: AppColors.onSurface),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppRadius.xl),
                boxShadow: AppShadows.soft,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: const BoxDecoration(color: AppColors.primaryContainer, shape: BoxShape.circle),
                    child: const Icon(Symbols.check_circle_rounded, color: Colors.white, size: 48, fill: 1),
                  ),
                  const SizedBox(height: 16),
                  Text('Aap ki request live ho gayi hai!', textAlign: TextAlign.center, style: AppTextStyles.headlineLgMobile.copyWith(color: AppColors.primary)),
                  const SizedBox(height: 8),
                  Text('Broadcasting to nearby verified workers...', textAlign: TextAlign.center, style: AppTextStyles.bodyLg.copyWith(color: AppColors.onSurfaceVariant)),
                  const SizedBox(height: 32),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.dflt),
                    child: Container(
                      height: 180,
                      width: double.infinity,
                      color: AppColors.surfaceContainerLowest,
                      child: AnimatedBuilder(
                        animation: _controller,
                        builder: (context, _) => CustomPaint(painter: _RadarPainter(_controller.value)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  PrimaryButton(
                    label: 'Offers Dekhain',
                    onPressed: () => Navigator.of(context)
                        .push(MaterialPageRoute(builder: (_) => WorkerOffersInboxScreen(jobId: widget.jobId))),
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

class _RadarPainter extends CustomPainter {
  final double t;
  _RadarPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.shortestSide / 2;
    final teal = AppColors.brandTeal;

    canvas.drawCircle(center, 6, Paint()..color = teal);

    for (final offset in [0.0, 0.5]) {
      final progress = (t + offset) % 1.0;
      final radius = progress * maxRadius;
      final opacity = (1 - progress).clamp(0.0, 1.0) * 0.6;
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = teal.withOpacity(opacity)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RadarPainter oldDelegate) => oldDelegate.t != t;
}
