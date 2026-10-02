import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';

void main() {
  test('explore strings exist and contain no dashes used as punctuation', () {
    final l10n = AppLocalizationsEn();
    final samples = [
      l10n.explore_title,
      l10n.explore_hint,
      l10n.explore_count(0),
      l10n.explore_count(1),
      l10n.explore_count(12),
      l10n.explore_chip_numeric('Depth', 'over', '20 m'),
      l10n.explore_chart_entityCounts('site'),
      l10n.diveLog_filter_sectionWaterTempUnit('C'),
      l10n.explore_error_schemaMismatch,
    ];
    for (final s in samples) {
      expect(s, isNotEmpty);
      expect(s, isNot(contains(String.fromCharCode(0x2014))));
      expect(s, isNot(contains(' - ')));
    }
    expect(l10n.explore_count(0), 'No dives');
    expect(l10n.explore_count(12), '12 dives');
  });
}
