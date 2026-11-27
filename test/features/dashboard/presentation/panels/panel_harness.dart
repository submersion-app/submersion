import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

/// Where the last tap in a pumped panel navigated.
class PanelNav {
  String? location;
}

/// Pumps [panel] alone in a [width] by [height] box with [overrides], on a
/// router whose every other path records itself in the returned [PanelNav].
Future<PanelNav> pumpPanel(
  WidgetTester tester,
  Widget panel, {
  List<Object> overrides = const [],
  double width = 400,
  double height = 180,
  AppSettings settings = const AppSettings(),
  double textScale = 1,
  Locale? locale,
  ThemeData? theme,
}) async {
  tester.view.physicalSize = Size(width, height + 200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final nav = PanelNav();
  final base = await getBaseOverrides(
    settingsNotifier: MockSettingsNotifier(settings),
  );
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(width: width, height: height, child: panel),
          ),
        ),
      ),
      GoRoute(
        path: '/:a/:b/:c',
        builder: (_, s) => _Recorded(nav, s.uri.toString()),
      ),
      GoRoute(
        path: '/:a/:b',
        builder: (_, s) => _Recorded(nav, s.uri.toString()),
      ),
      GoRoute(path: '/:a', builder: (_, s) => _Recorded(nav, s.uri.toString())),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [...base, ...overrides].cast(),
      child: MaterialApp.router(
        locale: locale,
        theme: theme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
  return nav;
}

class _Recorded extends StatelessWidget {
  final PanelNav nav;
  final String location;

  const _Recorded(this.nav, this.location);

  @override
  Widget build(BuildContext context) {
    nav.location = location;
    return const Scaffold();
  }
}
