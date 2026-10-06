import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/insights/data/repositories/observation_dismissals_repository.dart';
import 'package:submersion/features/insights/domain/observations/observation.dart';
import 'package:submersion/features/insights/domain/observations/observation_facts.dart';
import 'package:submersion/features/insights/domain/observations/observation_rule_id.dart';
import 'package:submersion/features/insights/domain/observations/observation_target.dart';
import 'package:submersion/features/insights/presentation/providers/observations_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';

const phone = Size(400, 860);
const desktop = Size(1400, 900);

final testDiver = Diver(
  id: 'diver-1',
  name: 'A',
  createdAt: DateTime.utc(2020),
  updatedAt: DateTime.utc(2020),
);

Observation gapObservation({
  String lastDiveId = 'dive-9',
  ObservationTarget target = const DiveLogTarget(),
}) => Observation(
  ruleId: ObservationRuleId.diveGap,
  fingerprint: lastDiveId,
  score: 0.3,
  facts: DiveGapFacts(
    days: 120,
    lastDiveId: lastDiveId,
    lastDiveDate: DateTime.utc(2026, 6, 7),
  ),
  target: target,
);

Observation categoryObservation(String categoryId) => Observation(
  ruleId: ObservationRuleId.busiestMonth,
  fingerprint: '8',
  score: 1,
  facts: const MonthFacts(month: 8, years: 2),
  target: InsightsCategoryTarget(categoryId),
);

/// Records dismissals instead of writing them.
class FakeDismissals implements ObservationDismissalsRepository {
  FakeDismissals({this.fail = false});
  final bool fail;
  final calls = <String>[];

  @override
  Future<void> dismiss({
    required String diverId,
    required ObservationRuleId rule,
    required String fingerprint,
  }) async {
    if (fail) throw StateError('disk full');
    calls.add('dismiss $diverId ${rule.dbValue} $fingerprint');
  }

  @override
  Future<void> undismiss({
    required String diverId,
    required ObservationRuleId rule,
    required String fingerprint,
  }) async {
    calls.add('undismiss $diverId ${rule.dbValue} $fingerprint');
  }

  @override
  Stream<Set<String>> watchDismissedKeys(String diverId) =>
      Stream.value(const {});

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Pumps [child] at `/insights` inside a router whose other destinations
/// render their own location, so a test can read where a tap went.
Future<GoRouter> pumpObservationApp(
  WidgetTester tester, {
  required Widget child,
  Size size = phone,
  List<Override> overrides = const [],
  Diver? diver,
  MockSettingsNotifier? settings,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final base = await getBaseOverrides(settingsNotifier: settings);
  Widget echo(BuildContext _, GoRouterState s) =>
      Scaffold(body: Text('at ${s.uri}'));
  final router = GoRouter(
    initialLocation: '/insights',
    routes: [
      GoRoute(
        path: '/insights',
        builder: (_, _) => Scaffold(body: child),
        routes: [GoRoute(path: ':id', builder: echo)],
      ),
      GoRoute(
        path: '/dives',
        builder: echo,
        routes: [GoRoute(path: ':diveId', builder: echo)],
      ),
      GoRoute(path: '/sites/:siteId', builder: echo),
      GoRoute(path: '/buddies/:buddyId', builder: echo),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    testAppRouter(
      router: router,
      locale: const Locale('en'),
      overrides: [
        ...base,
        currentDiverProvider.overrideWith((ref) async => diver),
        ...overrides,
      ],
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

/// The router's base location, query included. A push does not change
/// it; assert a push through the destination's `at <location>` text.
String locationOf(GoRouter router) =>
    router.routerDelegate.currentConfiguration.uri.toString();

/// Settings with nothing muted, for tests that mute.
MockSettingsNotifier mutableSettings() =>
    MockSettingsNotifier(const AppSettings());

/// Overrides that hand the strip and page a fixed list.
List<Override> observationsOverride(List<Observation> list) => [
  observationsProvider.overrideWith((ref) async => list),
];
