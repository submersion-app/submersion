import 'package:submersion/features/settings/domain/setup/set_up_progress.dart';
import 'package:submersion/features/settings/presentation/pages/data_settings_pane.dart';
import 'package:submersion/features/settings/presentation/widgets/settings_pane_navigator.dart';

/// [step] of the Set up this device flow.
String setUpStepRoute(SetUpStep step) => '/settings/setup?step=${step.name}';

/// The flow from its first step with every step shown, showing a hidden
/// card again.
const setUpAgainRoute = '/settings/setup?again=true';

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
