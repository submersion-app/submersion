import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/safety_finding.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_finding.dart';
import 'package:submersion/features/safety/domain/services/no_fly_service.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/settings/presentation/widgets/safety_hub_summaries.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));
  final reviewTotal = SafetyRuleId.values.length;
  final conditionTotal = ConditionRuleId.values.length;

  group('safetyReviewSummary', () {
    test('default settings read on with every rule and standard no-fly', () {
      expect(
        safetyReviewSummary(l10n, const AppSettings()),
        'On, $reviewTotal of $reviewTotal rules, no-fly Standard',
      );
    });

    test('review off still names the no-fly preset', () {
      expect(
        safetyReviewSummary(
          l10n,
          const AppSettings(
            safetyReviewEnabled: false,
            noFlyPreset: NoFlyPreset.strict,
          ),
        ),
        'Off, no-fly Strict',
      );
    });

    test('every rule disabled while on reads zero, not off', () {
      expect(
        safetyReviewSummary(
          l10n,
          AppSettings(
            safetyReviewDisabledRules: {
              for (final r in SafetyRuleId.values) r.dbValue,
            },
          ),
        ),
        'On, 0 of $reviewTotal rules, no-fly Standard',
      );
    });

    test('a stored id that is no longer a rule does not lower the count', () {
      expect(
        safetyReviewSummary(
          l10n,
          AppSettings(
            safetyReviewDisabledRules: {
              SafetyRuleId.rapidAscent.dbValue,
              'retiredRule',
            },
          ),
        ),
        'On, ${reviewTotal - 1} of $reviewTotal rules, no-fly Standard',
      );
    });
  });

  group('decompressionSummary', () {
    test('shows the gradient factors', () {
      expect(
        decompressionSummary(l10n, const AppSettings(gfLow: 30, gfHigh: 70)),
        'GF 30/70',
      );
    });
  });

  group('equipmentConditionSummary', () {
    test('default settings read on with every rule', () {
      expect(
        equipmentConditionSummary(l10n, const AppSettings()),
        'On, $conditionTotal of $conditionTotal rules',
      );
    });

    test('engine off reads off', () {
      expect(
        equipmentConditionSummary(
          l10n,
          const AppSettings(conditionEngineEnabled: false),
        ),
        'Off',
      );
    });

    test('disabled rules lower the count', () {
      expect(
        equipmentConditionSummary(
          l10n,
          AppSettings(
            conditionDisabledRules: {
              ConditionRuleId.cellOutputLow.dbValue,
              ConditionRuleId.issueRecurring.dbValue,
            },
          ),
        ),
        'On, ${conditionTotal - 2} of $conditionTotal rules',
      );
    });
  });
}
