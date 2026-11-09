import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_sites/presentation/info/site_altitude_info.dart';
import 'package:submersion/features/equipment/domain/entities/condition_trend.dart';
import 'package:submersion/features/equipment/presentation/info/equipment_info.dart';
import 'package:submersion/features/settings/presentation/info/settings_info.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/trips/presentation/info/scrubber_margin_info.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/info_sheet/dive_terms.dart';
import 'package:submersion/shared/widgets/info_sheet/info_content.dart';

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));
  const units = UnitFormatter(AppSettings());

  String label(DiveTerm term) => diveTermEntry(l10n, units, term).term;
  List<String> labels(InfoContent content) =>
      content.terms.map((e) => e.term).toList();

  test('every settings section has a summary', () {
    for (final section in SettingsInfoSection.values) {
      final content = settingsSectionInfo(l10n, units, section);
      expect(content.summary, isNotEmpty, reason: '$section');
    }
  });

  test('the gradient factors section explains GF and cites its source', () {
    final content = settingsSectionInfo(
      l10n,
      units,
      SettingsInfoSection.gradientFactors,
    );
    expect(labels(content), contains(label(DiveTerm.gradientFactors)));
    expect(content.background, contains('Erik Baker'));
  });

  test('the cell output trend explains mV per bar', () {
    final content = equipmentTrendInfo(
      l10n,
      units,
      ConditionTrendKind.cellGain,
      title: 'Cell output per dive',
    );
    expect(labels(content), [label(DiveTerm.cellGain)]);
    expect(content.terms.single.term, contains('mV per bar'));
  });

  test('the site altitude sheet explains altitude groups', () {
    final content = siteAltitudeInfo(l10n, units);
    expect(labels(content), contains(label(DiveTerm.altitudeGroup)));
  });

  test('the scrubber margin sheet explains the scrubber', () {
    expect(
      labels(scrubberMarginInfo(l10n, units)),
      contains(label(DiveTerm.scrubber)),
    );
  });
}
