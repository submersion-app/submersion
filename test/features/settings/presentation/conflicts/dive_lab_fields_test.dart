import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/settings/presentation/conflicts/catalogue/conflict_field_catalogue.dart';
import 'package:submersion/features/settings/presentation/conflicts/conflict_field.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  late AppLocalizations en;

  setUpAll(() async {
    en = await AppLocalizations.delegate.load(const Locale('en'));
  });

  test("a scenario's mode reads as the Dive Lab names it", () {
    final field = conflictFieldFor('diveScenarios', 'mode');
    expect(field.label(en), 'Scenario mode');
    expect(field.enumLabel!(en, 'replay'), 'Replay');
    expect(field.enumLabel!(en, 'replan'), 'Re-plan');
  });

  test("a dive plan's mode keeps its own labels", () {
    final field = conflictFieldFor('divePlans', 'mode');
    expect(field.label(en), isNot('Scenario mode'));
    expect(field.enumLabel!(en, 'replay'), isNull);
  });

  test('the branch point reads as a duration', () {
    final field = conflictFieldFor('diveScenarios', 'branchSeconds');
    expect(field.label(en), 'Branch');
    expect(field.kind, FieldKind.durationSeconds);
  });

  test('interventions stay opaque: their JSON is not for reading', () {
    final field = conflictFieldFor('diveScenarios', 'interventionsJson');
    expect(field.label(en), 'Interventions');
    expect(field.kind, FieldKind.opaque);
  });
}
