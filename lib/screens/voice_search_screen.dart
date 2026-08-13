import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../models/ui_models.dart';
import '../theme/app_theme.dart';
import '../services/categories_service.dart';
import '../services/geo_utils.dart';
import '../services/voice_input_service.dart';
import '../services/voice_intent_matcher.dart';
import '../widgets/app_top_bar.dart';
import 'voice_search_results_screen.dart';

/// The listening screen behind the mic button.
///
/// The mic used to be pure navigation — it pushed the AI chat and nothing
/// was ever recorded. This actually listens: the transcript updates live as
/// the user speaks, and when they stop, the request is matched to a service
/// category and turned into a list of real provider profiles.
class VoiceSearchScreen extends StatefulWidget {
  const VoiceSearchScreen({super.key});

  @override
  State<VoiceSearchScreen> createState() => _VoiceSearchScreenState();
}

class _VoiceSearchScreenState extends State<VoiceSearchScreen> with SingleTickerProviderStateMixin {
  final _voice = VoiceInputService.instance;

  late final AnimationController _pulse =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat();

  String _transcript = '';
  bool _listening = false;
  bool _available = true;
  String? _error;

  /// Categories are streamed rather than fetched once so the matcher always
  /// scores against the live taxonomy — a category added in the admin
  /// dashboard becomes voice-searchable without an app update.
  List<ServiceCategory> _categories = const [];

  @override
  void initState() {
    super.initState();
    CategoriesService.instance.watchAll().listen((cats) {
      if (mounted) setState(() => _categories = cats);
    });
    _checkAvailability();
  }

  Future<void> _checkAvailability() async {
    final ok = await _voice.initialize(onError: _showError);
    if (mounted) setState(() => _available = ok);
  }

  void _showError(String message) {
    if (!mounted) return;
    setState(() {
      _error = message;
      _listening = false;
    });
  }

  @override
  void dispose() {
    _pulse.dispose();
    // Don't leave the recogniser holding the mic if the user backs out
    // mid-sentence.
    _voice.cancel();
    super.dispose();
  }

  Future<void> _toggleListening() async {
    if (_listening) {
      await _voice.stop();
      return;
    }
    setState(() {
      _error = null;
      _transcript = '';
      _listening = true;
    });
    final started = await _voice.start(
      onResult: (text, isFinal) {
        if (!mounted) return;
        setState(() => _transcript = text);
      },
      onDone: () {
        if (!mounted) return;
        setState(() => _listening = false);
        // The recogniser also stops on its own silence timeout, so resolve
        // here rather than only in the stop button's handler.
        _resolve();
      },
      onError: _showError,
    );
    if (!started && mounted) {
      setState(() {
        _listening = false;
        _available = false;
      });
    }
  }

  /// Turns whatever was heard into a category and shows matching providers.
  Future<void> _resolve() async {
    final said = _transcript.trim();
    if (said.isEmpty) return;

    final intent = VoiceIntentMatcher.parse(said, _categories);
    if (intent.isUnknown) {
      setState(() => _error =
          "Couldn't tell which service you need. Try naming the trade — e.g. \"mujhe plumber chahiye\".");
      return;
    }
    // A single weak keyword hit is worth confirming rather than silently
    // sending them to the wrong trade.
    final category = intent.isUncertain ? await _confirmCategory(intent) : intent.category;
    if (category == null || !mounted) return;

    final position = await currentDevicePosition();
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => VoiceSearchResultsScreen(
          category: category,
          transcript: said,
          spokenBudget: intent.budget,
          origin: position,
        ),
      ),
    );
  }

  Future<ServiceCategory?> _confirmCategory(VoiceIntent intent) {
    final options = [intent.category!, ...intent.alternatives];
    return showModalBottomSheet<ServiceCategory>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.outlineVariant,
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
            ),
            const SizedBox(height: 16),
            Text('Which service did you mean?', style: AppTextStyles.headlineMd),
            const SizedBox(height: 8),
            for (final option in options)
              ListTile(
                leading: Icon(option.icon, color: AppColors.primary),
                title: Text(option.name, style: AppTextStyles.labelLg),
                subtitle: Text(option.localName, style: AppTextStyles.labelSm),
                onTap: () => Navigator.of(sheetContext).pop(option),
              ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppTopBar(title: 'Voice Search'),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Text(
                _listening ? 'Listening…' : 'Tap the mic and say what you need',
                style: AppTextStyles.headlineMd,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                'Roman Urdu ya English — jaise "mujhe plumber chahiye" ya '
                '"my kitchen tap is leaking".',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyMd.copyWith(color: AppColors.onSurfaceVariant),
              ),
              const SizedBox(height: 32),
              _MicButton(
                listening: _listening,
                enabled: _available,
                pulse: _pulse,
                onTap: _available ? _toggleListening : null,
              ),
              const SizedBox(height: 28),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      if (_transcript.isNotEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceContainerLowest,
                            borderRadius: BorderRadius.circular(AppRadius.lg),
                            boxShadow: AppShadows.soft,
                          ),
                          child: Text(_transcript, style: AppTextStyles.bodyLg),
                        ),
                      if (!_available)
                        _Notice(
                          icon: Symbols.mic_off_rounded,
                          text: 'Voice input is unavailable on this device or the microphone '
                              'permission was denied. Pick a category on the previous screen instead.',
                        ),
                      if (_error != null) ...[
                        const SizedBox(height: 16),
                        _Notice(icon: Symbols.error_rounded, text: _error!),
                      ],
                    ],
                  ),
                ),
              ),
              if (_transcript.isNotEmpty && !_listening)
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _resolve,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.full)),
                    ),
                    icon: const Icon(Symbols.search_rounded),
                    label: const Text('Find providers'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MicButton extends StatelessWidget {
  final bool listening;
  final bool enabled;
  final AnimationController pulse;
  final VoidCallback? onTap;

  const _MicButton({
    required this.listening,
    required this.enabled,
    required this.pulse,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colour = !enabled
        ? AppColors.outlineVariant
        : listening
            ? AppColors.error
            : AppColors.brandTeal;
    return SizedBox(
      width: 180,
      height: 180,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Expanding ring, shown only while actually recording — the old
          // screen had a static halo that looked identical whether the mic
          // was live or not.
          if (listening)
            AnimatedBuilder(
              animation: pulse,
              builder: (context, _) => Container(
                width: 110 + pulse.value * 70,
                height: 110 + pulse.value * 70,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colour.withValues(alpha: (1 - pulse.value) * 0.28),
                ),
              ),
            ),
          Material(
            color: colour,
            shape: const CircleBorder(),
            elevation: enabled ? 6 : 0,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onTap,
              child: SizedBox(
                width: 108,
                height: 108,
                child: Icon(
                  listening ? Symbols.stop_rounded : Symbols.mic_rounded,
                  color: Colors.white,
                  size: 44,
                  fill: 1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Notice({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.statusAmberBg,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppColors.statusAmberFg),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: AppTextStyles.bodyMd.copyWith(color: AppColors.statusAmberFg)),
          ),
        ],
      ),
    );
  }
}
