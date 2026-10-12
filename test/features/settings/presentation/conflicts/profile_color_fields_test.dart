import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/presentation/profile_colors/profile_metric.dart';
import 'package:submersion/features/settings/presentation/conflicts/catalogue/diver_settings_fields.dart';
import 'package:submersion/features/settings/presentation/conflicts/catalogue/profile_color_fields.dart';
import 'package:submersion/features/settings/presentation/conflicts/conflict_field.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';

void main() {
  final l10n = AppLocalizationsEn();

  test('every colour column is in the diver settings catalogue', () {
    for (final metric in ProfileMetric.values) {
      final field = diverSettingsFields[metric.settingsKey];
      expect(field, isNotNull, reason: metric.settingsKey);
      expect(field!.kind, FieldKind.enumValue);
    }
  });

  test('labels the field with the metric name', () {
    expect(
      diverSettingsFields['profileColorPpO2']!.label(l10n),
      'Profile color: ppO2',
    );
  });

  test('names a stored colour by word and hex', () {
    expect(profileColorLabeler(l10n, '${0xFF00ACC1}'), 'Cyan (#00ACC1)');
    expect(profileColorLabeler(l10n, 'not a number'), isNull);
    // Off the palette (a newer build's swatch): the dialog prints it raw.
    expect(profileColorLabeler(l10n, '${0xFF123456}'), isNull);
  });
}
