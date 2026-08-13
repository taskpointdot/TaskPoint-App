import '../models/ui_models.dart';

/// What a spoken request was understood to mean.
class VoiceIntent {
  final String transcript;

  /// Best-matching service category, or null when nothing scored.
  final ServiceCategory? category;

  /// Runner-up matches, so the UI can offer "did you mean…" instead of a
  /// dead end when confidence is low.
  final List<ServiceCategory> alternatives;

  /// How many distinct keywords matched. 0 means no idea what they asked
  /// for; 1 is a weak guess worth confirming; 2+ is confident.
  final int score;

  /// A rupee amount heard in the request ("do hazaar", "500 rupay"), if any.
  final double? budget;

  const VoiceIntent({
    required this.transcript,
    this.category,
    this.alternatives = const [],
    this.score = 0,
    this.budget,
  });

  bool get isConfident => category != null && score >= 2;
  bool get isUncertain => category != null && score == 1;
  bool get isUnknown => category == null;
}

/// Maps a spoken job request onto one of the Firestore service categories.
///
/// This is keyword matching, not NLP. The thesis scopes an OpenAI-backed
/// Roman Urdu chatbot, which needs an API key this project doesn't have —
/// so rather than leave the mic button doing nothing, this handles the shape
/// requests actually take in practice ("mujhe plumber chahiye", "nal se paani
/// leak ho raha hai", "AC theek karwana hai") by scoring each category
/// against its English name, its Roman Urdu name, and a synonym table.
///
/// Matching is deliberately driven by whatever categories exist in Firestore
/// rather than a hard-coded list, so adding a category in the admin
/// dashboard makes it voice-searchable too.
class VoiceIntentMatcher {
  VoiceIntentMatcher._();

  /// Roman Urdu / colloquial terms people use for each service, keyed by the
  /// category's canonical English name (lowercased). Includes the *problem*
  /// vocabulary, not just the trade name — people say "paani leak ho raha
  /// hai" far more often than they say "plumber".
  static const _synonyms = <String, List<String>>{
    'plumber': [
      'mistri', 'nal', 'toti', 'paani', 'pani', 'leak', 'leakage', 'pipe', 'sink',
      'basin', 'tap', 'drain', 'nali', 'gusalkhana', 'bathroom', 'toilet', 'flush',
      'water', 'motor', 'tanki', 'plumbing',
    ],
    'electrician': [
      'bijli', 'bijlee', 'light', 'lights', 'bulb', 'switch', 'socket', 'wiring',
      'wire', 'fan', 'meter', 'current', 'shock', 'fuse', 'breaker', 'electric',
      'electrical', 'power', 'connection',
    ],
    'carpenter': [
      'tarkhan', 'lakri', 'lakdi', 'wood', 'wooden', 'darwaza', 'door', 'window',
      'khirki', 'furniture', 'almari', 'cupboard', 'cabinet', 'table', 'chair',
      'kursi', 'bed', 'palang', 'shelf', 'carpentry',
    ],
    'painter': [
      'rang', 'rangsaz', 'paint', 'painting', 'safedi', 'whitewash', 'deewar',
      'wall', 'walls', 'colour', 'color', 'distemper', 'polish',
    ],
    'mason': [
      'raj', 'rajmistri', 'cement', 'plaster', 'brick', 'eent', 'taameer',
      'construction', 'concrete', 'masonry', 'chhat', 'roof', 'floor', 'tile',
      'tiles', 'marble',
      // Shared with 'painter' on purpose: "deewar ka kaam" is genuinely
      // ambiguous — a wall might need plastering or painting. Scoring both
      // is what triggers the "which service did you mean?" confirm sheet
      // instead of silently picking one.
      'deewar', 'wall',
    ],
    'cleaner': [
      'safai', 'saaf', 'cleaning', 'clean', 'jhaaru', 'jharu', 'kachra', 'kooda',
      'dusting', 'sweep', 'mopping', 'wash', 'maid', 'housekeeping',
    ],
    'ac repair': [
      'ac', 'a c', 'air conditioner', 'airconditioner', 'cooling', 'cool',
      'split', 'inverter', 'gas', 'chiller', 'thanda',
    ],
    'appliance repair': [
      'fridge', 'refrigerator', 'freezer', 'washing machine', 'machine', 'oven',
      'microwave', 'geyser', 'heater', 'appliance', 'dryer', 'dishwasher',
    ],
    'gardener': [
      'mali', 'garden', 'gardening', 'paudhe', 'poday', 'ghaas', 'grass', 'lawn',
      'plant', 'plants', 'tree', 'darakht', 'trimming', 'hedge',
    ],
    'mover/shifting': [
      'shifting', 'shift', 'mover', 'moving', 'saman', 'samaan', 'luggage',
      'truck', 'transport', 'relocate', 'relocation', 'packers', 'ghar badalna',
    ],
    'pest control': [
      'keeray', 'keeda', 'pest', 'cockroach', 'cockroaches', 'macchar', 'machar',
      'mosquito', 'termite', 'deemak', 'rat', 'rats', 'chuha', 'chuhay', 'ants',
      'cheenti', 'spray', 'fumigation',
    ],
    'car wash': [
      'gari', 'gaari', 'car', 'bike', 'motorcycle', 'vehicle', 'wash', 'dhona',
      'dhulai', 'detailing', 'polish car',
    ],
  };

  /// Words that carry no signal but would otherwise match category names by
  /// accident (e.g. "wash" appearing in both cleaner and car wash).
  static const _stopWords = {
    'mujhe', 'mujhy', 'muje', 'chahiye', 'chahye', 'chaiye', 'karwana', 'karna',
    'hai', 'ha', 'hy', 'ko', 'ka', 'ki', 'ke', 'se', 'me', 'mein', 'main', 'ek',
    'aik', 'need', 'want', 'i', 'a', 'an', 'the', 'please', 'find', 'get',
    'for', 'my', 'is', 'are', 'to', 'and', 'koi', 'koie', 'banda', 'wala',
  };

  /// Scores every category against [transcript] and returns the best match.
  static VoiceIntent parse(String transcript, List<ServiceCategory> categories) {
    final normalised = _normalise(transcript);
    if (normalised.isEmpty || categories.isEmpty) {
      return VoiceIntent(transcript: transcript, budget: _extractBudget(normalised));
    }

    final scored = <ServiceCategory, int>{};
    for (final category in categories) {
      final score = _scoreCategory(normalised, category);
      if (score > 0) scored[category] = score;
    }

    if (scored.isEmpty) {
      return VoiceIntent(transcript: transcript, budget: _extractBudget(normalised));
    }

    final ranked = scored.keys.toList()..sort((a, b) => scored[b]!.compareTo(scored[a]!));
    return VoiceIntent(
      transcript: transcript,
      category: ranked.first,
      alternatives: ranked.skip(1).take(3).toList(),
      score: scored[ranked.first]!,
      budget: _extractBudget(normalised),
    );
  }

  static int _scoreCategory(String normalised, ServiceCategory category) {
    final terms = <String>{
      ..._termsFrom(category.name),
      ..._termsFrom(category.localName),
      ...?_synonyms[category.name.toLowerCase().trim()],
      ...?_synonyms[category.iconKey.toLowerCase().trim()],
    }..removeWhere((t) => t.length < 2 || _stopWords.contains(t));

    var score = 0;
    for (final term in terms) {
      if (_containsWord(normalised, term)) score++;
    }
    return score;
  }

  /// Splits a display name into searchable terms — "Mover/Shifting" has to
  /// match someone who only said "shifting".
  static Iterable<String> _termsFrom(String value) =>
      value.toLowerCase().split(RegExp(r'[^a-z0-9]+')).where((t) => t.isNotEmpty);

  /// Whole-word (or whole-phrase) containment, so "ac" doesn't match inside
  /// "back" and "car" doesn't match inside "carpenter".
  static bool _containsWord(String haystack, String needle) {
    final pattern = RegExp('(^| )${RegExp.escape(needle)}( |\$)');
    return pattern.hasMatch(haystack);
  }

  static String _normalise(String input) => input
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  /// Pulls a budget out of the spoken request. Handles plain digits
  /// ("500 rupay") and the two multipliers people actually say out loud,
  /// "hazaar"/"thousand" and "lakh".
  static double? _extractBudget(String normalised) {
    if (normalised.isEmpty) return null;

    final thousand = RegExp(r'(\d+(?:\.\d+)?)\s*(hazaar|hazar|hazzar|thousand|k)\b').firstMatch(normalised);
    if (thousand != null) {
      final base = double.tryParse(thousand.group(1)!);
      if (base != null) return base * 1000;
    }
    final lakh = RegExp(r'(\d+(?:\.\d+)?)\s*(lakh|lac)\b').firstMatch(normalised);
    if (lakh != null) {
      final base = double.tryParse(lakh.group(1)!);
      if (base != null) return base * 100000;
    }
    // Bare number, ignoring anything implausible for a job budget so a
    // spoken phone number or house number isn't mistaken for a price.
    for (final match in RegExp(r'\b(\d{2,7})\b').allMatches(normalised)) {
      final value = double.tryParse(match.group(1)!);
      if (value != null && value >= 50 && value <= 1000000) return value;
    }
    return null;
  }
}
