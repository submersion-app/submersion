import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/constants/map_style.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/gas_switch.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/gas_switch_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/what_if_sheet.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/test_app.dart';

class _TestSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _TestSettingsNotifier() : super(const AppSettings());

  @override
  Future<void> setMapStyle(MapStyle style) async =>
      state = state.copyWith(mapStyle: style);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

List<DiveProfilePoint> _squareProfile() {
  final points = <DiveProfilePoint>[];
  for (var t = 0; t <= 1620; t += 10) {
    final double depth;
    if (t <= 120) {
      depth = 30 * t / 120;
    } else if (t <= 1320) {
      depth = 30;
    } else {
      depth = 30 * (1 - (t - 1320) / 300);
    }
    points.add(DiveProfilePoint(timestamp: t, depth: depth));
  }
  return points;
}

void main() {
  final profile = _squareProfile();
  final dive = Dive(
    id: 'dive-7',
    name: 'Wreck',
    dateTime: DateTime(2026, 7, 1, 9),
    entryTime: DateTime(2026, 7, 1, 9),
    exitTime: DateTime(2026, 7, 1, 9, 27),
    maxDepth: 30,
    profile: profile,
    tanks: const [
      DiveTank(id: 'back', name: 'Primary', volume: 11.1, startPressure: 200),
    ],
  );

  testWidgets(
    'Open in planner loads a what-if plan and navigates to the planner',
    (tester) async {
      final router = GoRouter(
        initialLocation: '/dives/dive-7',
        routes: [
          GoRoute(
            path: '/dives/:id',
            builder: (_, _) => Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => showWhatIfSheet(context, dive),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
          GoRoute(
            path: '/planning/dive-planner',
            builder: (_, _) => const Scaffold(body: Text('planner page')),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        testAppRouter(
          router: router,
          locale: const Locale('en'),
          overrides: [
            settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
            diveProvider.overrideWith((ref, id) async => dive),
            divesProvider.overrideWith((ref) async => <Dive>[]),
            diveProfileProvider.overrideWith((ref, id) async => profile),
            gasSwitchesProvider.overrideWith(
              (ref, id) async => <GasSwitchWithTank>[],
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.text('open')),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.byType(WhatIfSheet), findsOneWidget);
      expect(find.text('Detail'), findsOneWidget);
      // No dive within 24h -> no tissue-seeding switch.
      expect(find.text('Seed tissues from previous dive'), findsNothing);

      await tester.tap(find.text('Open in planner'));
      await tester.pumpAndSettle();

      final state = container.read(divePlanNotifierProvider);
      expect(state.sourceDiveId, 'dive-7');
      expect(state.name, 'Replan: Wreck');
      // No preceding dive: start clean. Seeding from this dive's end
      // tissues would plan a repetitive after it and inflate TTS.
      expect(state.initialTissueState, isNull);
      expect(state.surfaceInterval, isNull);
      // Descent plus bottom from the log, authored as editable segments. Deco
      // stops are NOT baked in as segments: the engine computes them fresh
      // from the authored bottom portion, same as any other plan.
      expect(state.segments.length, greaterThanOrEqualTo(2));
      expect(
        state.segments.map((s) => s.id).toSet().length,
        state.segments.length,
      );
      expect(state.tanks.single.id, 'back');

      expect(find.text('planner page'), findsOneWidget);
      // push (not go) keeps the dive page underneath; the planner is the
      // topmost matched route.
      expect(
        router.routerDelegate.currentConfiguration.last.matchedLocation,
        '/planning/dive-planner',
      );
    },
  );
}
