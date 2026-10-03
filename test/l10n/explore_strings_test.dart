import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/l10n/arb/app_localizations_de.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';

void main() {
  test('ask and explore strings exist and contain no dashes used as '
      'punctuation', () {
    final l10n = AppLocalizationsEn();
    final samples = [
      l10n.diveLog_ask_row('turtles below 20 m'),
      l10n.diveLog_ask_running,
      l10n.diveLog_ask_couldNotUse,
      l10n.diveLog_ask_asked('turtles below 20 m'),
      l10n.accessibility_shortcut_askQuestion,
      l10n.explore_chip_numeric('Depth', 'over', '20 m'),
      l10n.diveLog_filter_sectionWaterTempUnit('C'),
      l10n.explore_error_schemaMismatch,
    ];
    for (final s in samples) {
      expect(s, isNotEmpty);
      expect(s, isNot(contains(String.fromCharCode(0x2014))));
      expect(s, isNot(contains(' - ')));
    }
    expect(l10n.diveLog_ask_row('manta'), 'Ask: manta');
  });

  // Code review: the German file addresses the diver formally.
  test('the German Ask label addresses the diver formally', () {
    expect(
      AppLocalizationsDe().accessibility_shortcut_askQuestion,
      'Fragen zu Ihren Tauchgängen',
    );
  });
}
