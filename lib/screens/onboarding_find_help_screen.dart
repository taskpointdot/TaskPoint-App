import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../theme/app_theme.dart';
import '../services/session_controller.dart';

/// Maps to: onboarding_find_help/code.html
/// Full 3-slide onboarding carousel. Previously this screen only ever
/// rendered a single static slide (the page dots were decorative and the
/// "Next" button jumped straight to OTP) — it now uses a real PageView so
/// all 3 slides are swipeable/tappable-through, and only calls [onNext]
/// once the user reaches (and taps past) the final slide.
class OnboardingFindHelpScreen extends StatefulWidget {
  final VoidCallback? onNext;
  final VoidCallback? onSkip;
  const OnboardingFindHelpScreen({super.key, this.onNext, this.onSkip});

  @override
  State<OnboardingFindHelpScreen> createState() => _OnboardingFindHelpScreenState();
}

class _OnboardingSlide {
  final IconData icon;
  final String titleLocal;
  final String titleEn;
  final String body;
  const _OnboardingSlide({required this.icon, required this.titleLocal, required this.titleEn, required this.body});
}

const _slides = <_OnboardingSlide>[
  _OnboardingSlide(
    icon: Symbols.plumbing_rounded,
    titleLocal: 'Ghar baithe kaam dhoondain',
    titleEn: 'Find reliable help nearby',
    body: 'Connect with trusted, verified professionals in your local area instantly. Aasani se apne ird gird mahir afrad talash karain.',
  ),
  _OnboardingSlide(
    icon: Symbols.mic_rounded,
    titleLocal: 'Awaaz se kaam post karain',
    titleEn: 'Post a job in seconds',
    body: 'Just describe what you need out loud, or type it, and our AI assistant will match you with the right worker nearby.',
  ),
  _OnboardingSlide(
    icon: Symbols.verified_user_rounded,
    titleLocal: 'Mehfooz adaigi, live tracking',
    titleEn: 'Track work & pay securely',
    body: 'Watch your worker arrive in real time and pay safely through the app once the job is done to your satisfaction.',
  ),
];

class _OnboardingFindHelpScreenState extends State<OnboardingFindHelpScreen> {
  final PageController _controller = PageController();
  int _page = 0;

  bool get _isLastPage => _page == _slides.length - 1;

  @override
  void initState() {
    super.initState();
    // If we landed here because a moderator suspended this account (see
    // SessionController), say so once. Otherwise being thrown back to
    // onboarding mid-session just looks like a random logout or crash.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final reason = SessionController.instance.lastSuspensionReason;
      if (reason == null || !mounted) return;
      SessionController.instance.lastSuspensionReason = null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 8),
          backgroundColor: AppColors.error,
          content: Text(
            reason.isEmpty
                ? 'Your account has been suspended. Please contact TaskPoint support.'
                : 'Your account has been suspended: $reason',
          ),
        ),
      );
    });
  }

  void _goNext() {
    if (_isLastPage) {
      widget.onNext?.call();
    } else {
      _controller.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Column(
          children: [
            // TopAppBar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.marginMobile, vertical: AppSpacing.sm),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Symbols.arrow_back_rounded, color: AppColors.primary),
                    onPressed: _page == 0 ? () => Navigator.of(context).maybePop() : _goToPrevious,
                  ),
                  Expanded(
                    child: Text('TaskPoint', textAlign: TextAlign.center, style: AppTextStyles.headlineMd.copyWith(color: AppColors.primary, fontWeight: FontWeight.w700)),
                  ),
                  TextButton(
                    onPressed: widget.onSkip,
                    child: Text('Skip', style: AppTextStyles.labelLg.copyWith(color: AppColors.primary)),
                  ),
                ],
              ),
            ),
            // Swipeable slides — this is the piece that was missing before:
            // the carousel now actually holds all 3 slides instead of just one.
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _slides.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (context, index) {
                  final slide = _slides[index];
                  return LayoutBuilder(
                    builder: (context, constraints) {
                      return SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(AppSpacing.marginMobile, AppSpacing.lg, AppSpacing.marginMobile, AppSpacing.xl),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(minHeight: constraints.maxHeight),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                height: 220,
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    Opacity(
                                      opacity: 0.2,
                                      child: Container(
                                        width: 220,
                                        height: 220,
                                        decoration: const BoxDecoration(color: AppColors.primaryContainer, shape: BoxShape.circle),
                                      ),
                                    ),
                                    Container(
                                      width: 180,
                                      height: 180,
                                      decoration: BoxDecoration(
                                        color: AppColors.surfaceContainerLow,
                                        borderRadius: BorderRadius.circular(24),
                                        boxShadow: AppShadows.soft,
                                      ),
                                      clipBehavior: Clip.antiAlias,
                                      child: Icon(slide.icon, size: 96, color: AppColors.primary),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: AppSpacing.lg),
                              Text.rich(
                                TextSpan(
                                  children: [
                                    TextSpan(text: '${slide.titleLocal}\n'),
                                    TextSpan(text: slide.titleEn, style: TextStyle(color: AppColors.primary.withOpacity(0.8))),
                                  ],
                                ),
                                textAlign: TextAlign.center,
                                style: AppTextStyles.headlineLgMobile,
                              ),
                              const SizedBox(height: AppSpacing.md),
                              Text(
                                slide.body,
                                textAlign: TextAlign.center,
                                style: AppTextStyles.bodyLg.copyWith(color: AppColors.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            // Footer
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.marginMobile, AppSpacing.sm, AppSpacing.marginMobile, AppSpacing.lg),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: List.generate(_slides.length, (i) {
                      final active = i == _page;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: GestureDetector(
                          onTap: () => _controller.animateToPage(i, duration: const Duration(milliseconds: 300), curve: Curves.easeOut),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: active ? 32 : 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: active ? AppColors.primary : AppColors.surfaceVariant,
                              borderRadius: BorderRadius.circular(AppRadius.full),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                  ElevatedButton.icon(
                    onPressed: _goNext,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      // The app theme's default ElevatedButton style sets
                      // minimumSize: Size.fromHeight(56), i.e. Size(double.infinity, 56),
                      // meant for full-width buttons in a Column. This button
                      // sits inside a Row next to the page dots instead, so it
                      // must override that back to a normal finite size or it
                      // crashes with "BoxConstraints forces an infinite width".
                      minimumSize: const Size(64, 48),
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    ),
                    icon: Icon(_isLastPage ? Symbols.check_rounded : Symbols.arrow_forward_rounded, size: 20),
                    label: Text(_isLastPage ? 'Shuru Karain / Get Started' : 'Aagay Barhain / Next', style: AppTextStyles.labelLg.copyWith(color: Colors.white)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _goToPrevious() {
    _controller.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
  }
}
