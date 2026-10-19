import 'package:submersion/features/settings/presentation/pages/data_settings_pane.dart';
import 'package:submersion/features/settings/presentation/pages/safety_hub_page.dart';
import 'package:submersion/features/settings/presentation/pages/settings_page.dart';
import 'package:submersion/features/settings/presentation/widgets/settings_pane_navigator.dart';

/// Where a `/settings?selected=<id>` link should really go, or null when the
/// settings page already renders it correctly.
///
/// Two kinds of link need moving:
///
/// - Decompression is no longer a root section (#3395). On desktop it opens
///   under Safety in the detail pane; on phone, on its own page.
/// - On phone, Safety (the hub, or one of its sub-pages) is a full page with
///   its own app bar, so rendering it inside the generic section wrapper
///   would show two. That also catches a desktop URL left behind when the
///   window narrows below the master-detail breakpoint.
/// - On phone, a page opened inside the desktop Data pane (#3467) goes to
///   its own route, the top page of the pane's stack.
String? resolveLegacySettingsLocation(Uri uri, {required bool masterDetail}) {
  final selected = uri.queryParameters['selected'];
  if (selected == null) return null;
  final subPage = SafetySubPage.fromId(
    uri.queryParameters[SafetySettingsPane.queryParam],
  );

  if (masterDetail) {
    if (selected != 'decompression') return null;
    return '${uri.path}?selected=safety'
        '&${SafetySettingsPane.queryParam}=${SafetySubPage.decompression.id}';
  }

  return switch (selected) {
    'decompression' => SafetySubPage.decompression.phoneRoute,
    'safety' => subPage?.phoneRoute ?? '/settings/safety',
    'data' => _topDataPage(uri),
    _ => null,
  };
}

/// The innermost page a Data pane URL opens, or null when it opens none.
String? _topDataPage(Uri uri) {
  final pages = SettingsPaneNavigator.stackIn(
    uri,
    DataSettingsPane.queryParam,
    dataPanePage,
  );
  return pages.isEmpty ? null : pages.last.$1;
}

/// Where a `/settings/section/<id>` link should go instead of the generic
/// section wrapper, or null when the wrapper is right for it.
///
/// Sections with a page of their own go to that page. Decompression, which
/// no longer has a root section, opens under Safety: in the detail pane on a
/// master-detail window (as the `?selected=` link does), on its own page on a
/// phone.
String? resolveSettingsSectionRedirect(
  String? sectionId, {
  required bool masterDetail,
}) {
  if (sectionId == 'decompression' && masterDetail) {
    return '/settings?selected=safety'
        '&${SafetySettingsPane.queryParam}=${SafetySubPage.decompression.id}';
  }
  return settingsSectionDedicatedRoutes[sectionId];
}
