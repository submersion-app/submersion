import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/insights/domain/tank_configuration/tank_configuration.dart';
import 'package:submersion/features/insights/presentation/formatters/tank_configuration_labels.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';

/// Issue #3421: every configuration and extra has its own label.
void main() {
  final l10n = AppLocalizationsEn();

  test('base configuration labels', () {
    expect(
      {
        for (final c in TankBaseConfiguration.values)
          c: tankBaseConfigurationLabel(l10n, c),
      },
      {
        TankBaseConfiguration.rebreather: 'Rebreather',
        TankBaseConfiguration.sidemount: 'Sidemount',
        TankBaseConfiguration.twinBackmount: 'Twin backmount',
        TankBaseConfiguration.singleBackmount: 'Single backmount',
        TankBaseConfiguration.other: 'Other',
        TankBaseConfiguration.noTanks: 'No tanks logged',
      },
    );
  });

  test('extra labels', () {
    expect(
      {
        for (final e in TankConfigurationExtra.values)
          e: tankConfigurationExtraLabel(l10n, e),
      },
      {
        TankConfigurationExtra.stages: 'Stage(s)',
        TankConfigurationExtra.decoGas: 'Deco gas',
        TankConfigurationExtra.multiGas: 'Multi-gas',
      },
    );
  });
}
