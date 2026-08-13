import 'package:flutter_test/flutter_test.dart';
import 'package:taskpoint/models/ui_models.dart';
import 'package:taskpoint/services/voice_intent_matcher.dart';

/// The same taxonomy CategoriesService seeds into Firestore, so these tests
/// exercise the matcher against the categories it will really see.
const _categories = seedCategories;

VoiceIntent parse(String said) => VoiceIntentMatcher.parse(said, _categories);

void main() {
  group('names the trade directly', () {
    test('English', () {
      expect(parse('I need an electrician').category?.name, 'Electrician');
    });

    test('Roman Urdu sentence', () {
      expect(parse('mujhe plumber chahiye').category?.name, 'Plumber');
    });

    test('local name instead of English name', () {
      // "Tarkhan" is the localName for Carpenter — a user who only knows the
      // Urdu word must still get there.
      expect(parse('koi tarkhan bhej dain').category?.name, 'Carpenter');
    });
  });

  group('describes the problem rather than the trade', () {
    test('leaking tap maps to plumber', () {
      final intent = parse('nal se paani leak ho raha hai');
      expect(intent.category?.name, 'Plumber');
      expect(intent.isConfident, isTrue, reason: 'nal + paani + leak should all hit');
    });

    test('no electricity maps to electrician', () {
      expect(parse('kamray ki light aur switch kaam nahi kar rahe').category?.name, 'Electrician');
    });

    test('termites map to pest control', () {
      expect(parse('ghar mein deemak hai').category?.name, 'Pest Control');
    });

    test('house move maps to mover', () {
      expect(parse('saman shift karna hai').category?.name, 'Mover/Shifting');
    });
  });

  group('word-boundary matching', () {
    test('"car" does not match Carpenter', () {
      // Substring matching would score Carpenter here because "car" is a
      // prefix of "carpenter"; whole-word matching must not.
      expect(parse('car wash karwani hai').category?.name, 'Car Wash');
    });

    test('"ac" does not match inside another word', () {
      // "back" contains "ac". Without word boundaries this scored AC Repair.
      expect(parse('back door tootha hua hai').category?.name, isNot('AC Repair'));
    });

    test('AC as a standalone word does match', () {
      expect(parse('AC ki cooling kam hai').category?.name, 'AC Repair');
    });
  });

  group('confidence', () {
    test('gibberish is unknown, not a wrong guess', () {
      final intent = parse('kuch samajh nahi aa raha');
      expect(intent.isUnknown, isTrue);
      expect(intent.category, isNull);
    });

    test('empty transcript is unknown', () {
      expect(parse('').isUnknown, isTrue);
    });

    test('a single weak hit is flagged uncertain for confirmation', () {
      final intent = parse('mali');
      expect(intent.category?.name, 'Gardener');
      expect(intent.isUncertain, isTrue);
      expect(intent.isConfident, isFalse);
    });

    test('alternatives are offered for the confirm sheet', () {
      final intent = parse('deewar ka kaam hai');
      expect(intent.category, isNotNull);
      expect(intent.alternatives, isNotEmpty);
    });
  });

  group('budget extraction', () {
    test('plain rupee amount', () {
      expect(parse('plumber chahiye 500 rupay').budget, 500);
    });

    test('hazaar multiplier', () {
      expect(parse('painter ka kaam hai 2 hazaar').budget, 2000);
    });

    test('thousand multiplier', () {
      expect(parse('carpenter 3 thousand').budget, 3000);
    });

    test('lakh multiplier', () {
      expect(parse('mason ka kaam 2 lakh').budget, 200000);
    });

    test('no amount spoken', () {
      expect(parse('mujhe plumber chahiye').budget, isNull);
    });

    test('implausibly small numbers are not treated as a budget', () {
      // "2 kamray" — a room count, not a price.
      expect(parse('2 kamray paint karne hain').budget, isNull);
    });
  });

  test('handles an empty category list without throwing', () {
    final intent = VoiceIntentMatcher.parse('mujhe plumber chahiye', const []);
    expect(intent.isUnknown, isTrue);
  });
}
