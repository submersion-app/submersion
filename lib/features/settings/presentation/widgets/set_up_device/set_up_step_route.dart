import 'package:submersion/features/settings/domain/setup/set_up_progress.dart';
import 'package:submersion/features/settings/presentation/pages/data_settings_pane.dart';

/// The settings path that resolves [step]. Until the setup flow's own step
/// pages exist, each step opens the page that does that job today.
String _setUpStepPath(SetUpStep step) => switch (step) {
  SetUpStep.account => 'connected-accounts',
  SetUpStep.sync => 'cloud-sync',
  SetUpStep.backups => 'backup',
  SetUpStep.photos => 'photos-media',
};

/// [step]'s page, for opening from inside Settings > Data.
String setUpStepRoute(SetUpStep step) => '/settings/${_setUpStepPath(step)}';

/// [step]'s page as a Data pane location, for opening from outside Settings
/// > Data (the Settings root): in the desktop pane it opens over the Data
/// hub, and on a phone the router sends it to the page itself.
String setUpStepDataLocation(SetUpStep step) =>
    '/settings?selected=data&${DataSettingsPane.queryParam}='
    '${_setUpStepPath(step)}';
