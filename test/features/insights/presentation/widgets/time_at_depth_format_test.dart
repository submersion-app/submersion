import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/insights/presentation/widgets/time_at_depth_format.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));

  group('timeAtDepthUsesHours', () {
    test('switches to hours at ten hours', () {
      expect(timeAtDepthUsesHours(599), isFalse);
      expect(timeAtDepthUsesHours(600), isTrue);
    });
  });

  group('formatTimeAtDepth', () {
    test('minutes mode keeps the minute string', () {
      expect(formatTimeAtDepth(l10n, 66240, hours: false), '66240 min');
    });

    test('a small bar in an hours chart still reads in minutes', () {
      expect(formatTimeAtDepth(l10n, 5, hours: true), '5 min');
    });

    test('under 100 hours reads hours and minutes', () {
      expect(formatTimeAtDepth(l10n, 1100, hours: true), '18h 20m');
      expect(formatTimeAtDepth(l10n, 5999, hours: true), '99h 59m');
    });

    test('100 hours or more reads whole grouped hours', () {
      expect(formatTimeAtDepth(l10n, 6000, hours: true), '100 h');
      expect(formatTimeAtDepth(l10n, 66240, hours: true), '1,104 h');
      expect(formatTimeAtDepth(l10n, 66270, hours: true), '1,105 h');
    });
  });
}
