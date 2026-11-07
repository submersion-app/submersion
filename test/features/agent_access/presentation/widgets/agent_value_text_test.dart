import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/agent_access/presentation/widgets/agent_write_confirm_dialog.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Issue #4294: a paper logbook's times and visibility read in the diver's
/// units in the confirm dialog.
void main() {
  final l = lookupAppLocalizations(const Locale('en'));
  const feet = UnitFormatter(AppSettings(depthUnit: DepthUnit.feet));

  test('a measured visibility reads in the diver\'s depth unit', () {
    expect(agentValueText(l, feet, 'visibility_m', 18.288), contains('60'));
    expect(agentValueText(l, feet, 'visibility_m', 18.288), contains('ft'));
    expect(agentValueText(l, feet, 'visibility_min_m', 24.384), contains('80'));
  });

  test('a runtime and a bottom time read as minutes and seconds', () {
    expect(agentValueText(l, feet, 'runtime_s', 3000), '50:00');
    expect(agentValueText(l, feet, 'bottom_time_s', 2430), '40:30');
  });

  test('a dive number reads as the number', () {
    expect(agentValueText(l, feet, 'dive_number', 20), '20');
  });
}
