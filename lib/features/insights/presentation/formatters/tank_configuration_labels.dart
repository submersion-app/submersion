import 'package:submersion/features/insights/domain/tank_configuration/tank_configuration.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// The label of a base configuration on the Gas page's tank configuration
/// card (issue #3421).
String tankBaseConfigurationLabel(
  AppLocalizations l10n,
  TankBaseConfiguration configuration,
) => switch (configuration) {
  TankBaseConfiguration.rebreather => l10n.insights_gas_tankConfig_rebreather,
  TankBaseConfiguration.sidemount => l10n.insights_gas_tankConfig_sidemount,
  TankBaseConfiguration.twinBackmount =>
    l10n.insights_gas_tankConfig_twinBackmount,
  TankBaseConfiguration.singleBackmount =>
    l10n.insights_gas_tankConfig_singleBackmount,
  TankBaseConfiguration.other => l10n.insights_gas_tankConfig_other,
  TankBaseConfiguration.noTanks => l10n.insights_gas_tankConfig_noTanks,
};

/// The label of an extra on the tank configuration card.
String tankConfigurationExtraLabel(
  AppLocalizations l10n,
  TankConfigurationExtra extra,
) => switch (extra) {
  TankConfigurationExtra.stages => l10n.insights_gas_tankConfig_stages,
  TankConfigurationExtra.decoGas => l10n.insights_gas_tankConfig_decoGas,
  TankConfigurationExtra.multiGas => l10n.insights_gas_tankConfig_multiGas,
};
