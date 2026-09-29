import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';
import 'package:submersion/features/dive_log/presentation/widgets/active_filter_chip_labels.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations_de.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';

/// Chip text is translated, never assembled from English fragments. German
/// is the probe: an English literal cannot pass for it by accident.
void main() {
  List<String> labels(DiveFilterState f, {bool german = false}) => [
    for (final c in activeFilterChipLabels(
      f,
      german ? AppLocalizationsDe() : AppLocalizationsEn(),
      const AppSettings(),
      siteName: (_) => null,
      speciesName: (_) => null,
      computerName: (_) => null,
    ))
      c.label,
  ];

  test('a weekday count is a translated plural', () {
    expect(labels(const DiveFilterState(weekdays: [6, 7])), ['2 weekdays']);
    expect(labels(const DiveFilterState(weekdays: [1])), ['1 weekday']);
    expect(labels(const DiveFilterState(weekdays: [6, 7]), german: true), [
      '2 Wochentage',
    ]);
  });

  test('bottom time uses the translated minutes unit', () {
    final de = labels(
      const DiveFilterState(minBottomTimeMinutes: 45),
      german: true,
    );
    expect(de.single, contains('45 Min.'));
    expect(de.single, isNot(contains('45 min')));
    final range = labels(
      const DiveFilterState(minBottomTimeMinutes: 30, maxBottomTimeMinutes: 60),
      german: true,
    );
    expect(range.single, contains('60 Min.'));
  });
}
