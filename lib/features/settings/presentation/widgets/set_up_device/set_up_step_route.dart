import 'package:submersion/features/settings/domain/data_health/feature_health.dart';
import 'package:submersion/features/settings/domain/setup/set_up_progress.dart';
import 'package:submersion/features/settings/presentation/pages/data_settings_pane.dart';
import 'package:submersion/features/settings/presentation/widgets/data_health/health_text.dart';
import 'package:submersion/features/settings/presentation/widgets/settings_pane_navigator.dart';

/// The settings page that resolves [step]. Until the setup flow's own step
/// pages exist, each step opens the page that does that job today: the same
/// page the feature's strip item and row open.
String setUpStepRoute(SetUpStep step) => switch (step) {
  SetUpStep.account => '/settings/connected-accounts',
  SetUpStep.sync => dataFeatureRoute(DataFeature.sync),
  SetUpStep.backups => dataFeatureRoute(DataFeature.backup),
  SetUpStep.photos => dataFeatureRoute(DataFeature.media),
};

/// [route], a page reached from Settings > Data, as a location that opens it
/// in the desktop Data pane, over the Data hub. For the desktop settings list
/// beside the pane, which is outside it. Null when the pane does not show
/// that page (it is then pushed).
String? dataPaneLocation(String route) {
  if (SettingsPaneNavigator.pageAt(route, dataPanePage) == null) return null;
  return Uri(
    path: '/settings',
    queryParameters: {
      'selected': 'data',
      DataSettingsPane.queryParam: route.substring('/settings/'.length),
    },
  ).toString();
}
