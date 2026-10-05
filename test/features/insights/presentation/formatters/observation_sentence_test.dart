import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/insights/domain/observations/observation.dart';
import 'package:submersion/features/insights/domain/observations/observation_facts.dart';
import 'package:submersion/features/insights/domain/observations/observation_rule_id.dart';
import 'package:submersion/features/insights/domain/observations/observation_target.dart';
import 'package:submersion/features/insights/presentation/formatters/observation_sentence.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

Observation _o(ObservationRuleId rule, ObservationFacts facts) => Observation(
  ruleId: rule,
  fingerprint: 'f',
  score: 1,
  facts: facts,
  target: const DiveLogTarget(),
);

void main() {
  // The app loads date symbols at startup; a bare unit test must do it.
  setUpAll(initializeDateFormatting);

  final en = lookupAppLocalizations(const Locale('en'));
  const metric = UnitFormatter(AppSettings());
  const imperial = UnitFormatter(
    AppSettings(
      depthUnit: DepthUnit.feet,
      weightUnit: WeightUnit.pounds,
      volumeUnit: VolumeUnit.cubicFeet,
    ),
  );
  const rmvDown = TrendFacts(
    recent: 15,
    previous: 20,
    recentDives: 9,
    previousDives: 9,
  );

  test('RMV improved, in litres and in cubic feet', () {
    final o = _o(ObservationRuleId.rmvTrend, rmvDown);
    final m = observationSentence(o, en, metric);
    expect(m, contains('improved'));
    expect(m, contains('25%'));
    expect(m, contains('15.0 L/min'));
    expect(m, contains('20.0 L/min'));
    final i = observationSentence(o, en, imperial);
    expect(i, contains('cuft/min'));
    expect(i, isNot(contains('L/min')));
  });

  test('max depth deeper follows the depth unit', () {
    const up = TrendFacts(
      recent: 24,
      previous: 20,
      recentDives: 9,
      previousDives: 9,
    );
    final o = _o(ObservationRuleId.maxDepthTrend, up);
    expect(observationSentence(o, en, metric), contains('24.0m'));
    expect(observationSentence(o, en, metric), contains('deeper'));
    expect(observationSentence(o, en, imperial), contains('ft'));
  });

  test('weight carried in kilograms or pounds', () {
    const less = TrendFacts(
      recent: 6,
      previous: 8,
      recentDives: 9,
      previousDives: 9,
    );
    final o = _o(ObservationRuleId.weightTrend, less);
    expect(observationSentence(o, en, metric), contains('2.0 kg less'));
    expect(observationSentence(o, en, imperial), contains('lb'));
  });

  test('ascent rate states the rate and the guidance in the depth unit', () {
    final o = _o(
      ObservationRuleId.ascentRate,
      const RateFacts(metersPerMin: 11.4, dives: 6),
    );
    final m = observationSentence(o, en, metric);
    expect(m, contains('11.4m/min'));
    expect(m, contains('9m/min to 10m/min'));
    expect(m, contains('6 dives'));
    final i = observationSentence(o, en, imperial);
    expect(i, contains('ft/min'));
    expect(i, isNot(contains('m/min to')));
  });

  test('dive gap and busiest month', () {
    expect(
      observationSentence(
        _o(
          ObservationRuleId.diveGap,
          DiveGapFacts(
            days: 120,
            lastDiveId: 'd',
            lastDiveDate: DateTime.utc(2026),
          ),
        ),
        en,
        metric,
      ),
      'Your last dive was 120 days ago',
    );
    expect(
      observationSentence(
        _o(
          ObservationRuleId.busiestMonth,
          const MonthFacts(month: 8, years: 2),
        ),
        en,
        metric,
      ),
      'August has been your busiest month in 2 different years',
    );
  });

  test('career milestones say "logged" without prior experience', () {
    final facts = MilestoneFacts(
      milestone: 100,
      includesPrior: false,
      diveId: 'd',
      date: DateTime.utc(2026, 9, 20),
    );
    final logged = observationSentence(
      _o(ObservationRuleId.diveCountMilestone, facts),
      en,
      metric,
    );
    expect(logged, startsWith('You reached 100 logged dives on'));
    final career = observationSentence(
      _o(
        ObservationRuleId.diveCountMilestone,
        MilestoneFacts(
          milestone: 100,
          includesPrior: true,
          diveId: 'd',
          date: DateTime.utc(2026, 9, 20),
        ),
      ),
      en,
      metric,
    );
    expect(career, startsWith('You reached 100 dives on'));
  });

  test('a facts type that does not match its rule falls back to the label', () {
    final o = _o(
      ObservationRuleId.rmvTrend,
      const MonthFacts(month: 1, years: 2),
    );
    expect(observationSentence(o, en, metric), 'RMV trend');
  });

  test('every rule has a label in every locale', () {
    for (final locale in AppLocalizations.supportedLocales) {
      final l10n = lookupAppLocalizations(locale);
      for (final rule in ObservationRuleId.values) {
        expect(observationRuleLabel(rule, l10n), isNotEmpty);
      }
    }
  });

  test('German renders with no English left in it', () {
    final de = lookupAppLocalizations(const Locale('de'));
    final s = observationSentence(
      _o(ObservationRuleId.rmvTrend, rmvDown),
      de,
      metric,
    );
    expect(s, contains('25 %'));
    expect(s, isNot(contains('improved')));
  });
}
