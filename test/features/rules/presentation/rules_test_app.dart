import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/core/query/domain/query_value.dart';
import 'package:submersion/core/query/names/name_index.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/query/presentation/providers/query_name_index_provider.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../helpers/mock_providers.dart';

/// Names the rules widget tests resolve ids against.
final kRuleTestNames = NameIndex.fromRefs({
  QuerySubject.diveTypes: const [
    RefValue('deep', 'Deep'),
    RefValue('boat', 'Boat'),
    RefValue('recreational', 'Recreational'),
  ],
  QuerySubject.tags: const [RefValue('cold', 'Cold')],
  QuerySubject.sites: const [],
  QuerySubject.buddies: const [],
  QuerySubject.equipment: const [],
});

/// Pumps [home] at [path] inside a router whose other routes record where
/// the page navigated.
Future<List<String>> pumpRulesApp(
  WidgetTester tester, {
  required Widget Function(GoRouterState state) home,
  String path = '/rules',
  List<dynamic> extra = const [],
  Size size = const Size(800, 1000),
  MockSettingsNotifier? settings,
  Future<NameIndex> Function(Ref ref)? names,
}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
  final pushed = <String>[];
  final router = GoRouter(
    initialLocation: path,
    routes: [
      GoRoute(path: path, builder: (context, state) => home(state)),
      GoRoute(
        path: '/:rest(.*)',
        builder: (context, state) {
          pushed.add(state.uri.toString());
          return const Scaffold(body: SizedBox());
        },
      ),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...await getBaseOverrides(settingsNotifier: settings),
        validatedCurrentDiverIdProvider.overrideWith((ref) async => 'me'),
        queryNameIndexProvider.overrideWith(
          names ?? (ref) async => kRuleTestNames,
        ),
        ...extra,
      ].cast(),
      child: MaterialApp.router(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return pushed;
}
