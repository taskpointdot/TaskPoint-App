import 'package:speech_to_text/speech_to_text.dart';

/// Live speech-to-text behind the mic button.
///
/// The mic used to be a navigation shortcut — it pushed the AI chat screen
/// and nothing was ever recorded. This wraps `speech_to_text` so the button
/// actually listens, streaming partial results while the user is still
/// talking rather than only handing back a final transcript.
///
/// Recognition is on-device (Android's platform recogniser / the browser's
/// SpeechRecognition API), so there's no API key and no audio leaves the
/// phone.
class VoiceInputService {
  VoiceInputService._();
  static final VoiceInputService instance = VoiceInputService._();

  final SpeechToText _speech = SpeechToText();
  bool _initialised = false;

  bool get isListening => _speech.isListening;

  /// Locale preference order. Pakistani English first: users describe jobs
  /// in Roman Urdu ("mujhe plumber chahiye"), and en-PK/en-IN acoustic
  /// models handle that code-switching far better than en-US, which tends
  /// to mangle Urdu words into unrelated English ones.
  static const _preferredLocales = ['en_PK', 'ur_PK', 'en_IN', 'en_GB', 'en_US'];

  /// Whether speech recognition is usable at all. Returns false when the
  /// user denies the mic permission, or on a device/browser with no
  /// recogniser — callers should fall back to the text field rather than
  /// leaving a mic button that silently does nothing.
  Future<bool> initialize({void Function(String message)? onError}) async {
    if (_initialised) return true;
    _initialised = await _speech.initialize(
      onError: (e) => onError?.call(_friendlyError(e.errorMsg)),
      onStatus: (_) {},
      debugLogging: false,
    );
    return _initialised;
  }

  /// Picks the best available locale from [_preferredLocales], falling back
  /// to whatever the system default is.
  Future<String?> _bestLocaleId() async {
    final locales = await _speech.locales();
    if (locales.isEmpty) return null;
    final available = {for (final l in locales) l.localeId.replaceAll('-', '_'): l.localeId};
    for (final preferred in _preferredLocales) {
      final match = available[preferred];
      if (match != null) return match;
    }
    final system = await _speech.systemLocale();
    return system?.localeId;
  }

  /// Starts listening.
  ///
  /// [onResult] fires repeatedly: once per partial result as the user
  /// speaks, then a final time with `isFinal: true`. [onDone] fires when
  /// the recogniser stops for any reason — including the silence timeout,
  /// which is why callers can't assume stop() is the only way listening ends.
  Future<bool> start({
    required void Function(String transcript, bool isFinal) onResult,
    required VoidCallback onDone,
    void Function(String message)? onError,
  }) async {
    if (!await initialize(onError: onError)) return false;
    await _speech.listen(
      localeId: await _bestLocaleId(),
      onResult: (result) => onResult(result.recognizedWords, result.finalResult),
      listenOptions: SpeechListenOptions(
        partialResults: true,
        cancelOnError: true,
        // Job descriptions are dictated, not conversational, so don't let
        // the recogniser cut in with its own turn-taking heuristics.
        listenMode: ListenMode.dictation,
      ),
      // Generous windows: someone describing a job in Roman Urdu often
      // pauses mid-sentence to think, and the defaults cut them off.
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 4),
    );
    _watchForStop(onDone);
    return true;
  }

  /// `speech_to_text` has no "stopped" callback, so poll the flag and tell
  /// the caller once listening has actually ended — otherwise a session that
  /// ends on the silence timeout leaves the UI stuck showing a live mic.
  Future<void> _watchForStop(VoidCallback onDone) async {
    while (_speech.isListening) {
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
    onDone();
  }

  /// Stops and keeps whatever was transcribed so far.
  Future<void> stop() => _speech.stop();

  /// Stops and discards the result.
  Future<void> cancel() => _speech.cancel();

  String _friendlyError(String code) => switch (code) {
        'error_no_match' => "Didn't catch that — please try again.",
        'error_speech_timeout' || 'error_no_speech' => "Didn't hear anything. Tap the mic and speak.",
        'error_permission' => 'Microphone permission is needed to use voice search.',
        'error_network' || 'error_network_timeout' => 'Speech recognition needs a network connection.',
        'error_busy' => 'The microphone is busy. Close other apps using it and try again.',
        _ => 'Voice input failed ($code). You can type your request instead.',
      };
}

typedef VoidCallback = void Function();
