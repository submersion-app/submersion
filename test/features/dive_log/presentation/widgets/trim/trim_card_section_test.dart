import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/buoyancy/buoyancy_twin.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_tracking_provider.dart';
import 'package:submersion/features/dive_log/presentation/widgets/trim/trim_card_section.dart';
import 'package:submersion/features/dive_log/presentation/widgets/trim/trim_figure.dart';
import 'package:submersion/features/dive_log/presentation/widgets/trim/trim_gauges.dart';
import 'package:submersion/features/dive_log/presentation/widgets/trim/trim_tryout_sheet.dart';
import 'package:submersion/features/divers/presentation/providers/diver_weight_entry_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../../helpers/test_app.dart';
import '../buoyancy_outcome_fixture.dart';

/// The trim figure's part of the Weights and buoyancy card (issue #5028).
void main() {
  const units = UnitFormatter(AppSettings());

  // An aluminium cylinder that empties over the dive, so its lift swings
  // the trim from the first sample to the last.
  const tank = TwinTankInput(
    id: 't1',
    label: 'AL80',
    volumeL: 11.1,
    workingPressureBar: 207,
    material: TankMaterial.aluminum,
    startPressureBar: 230,
    endPressureBar: 10,
  );
  final dive = Dive(
    id: 'd1',
    dateTime: DateTime.utc(2026, 3, 15, 10),
    tanks: const [DiveTank(id: 't1', volume: 11.1, role: TankRole.stage)],
    profile: const [
      DiveProfilePoint(timestamp: 0, depth: 0),
      DiveProfilePoint(timestamp: 60, depth: 5),
    ],
  );

  Future<void> pump(WidgetTester tester, {int? cursor}) async {
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        overrides: [
          latestDiverWeightProvider.overrideWith((ref) async => null),
          latestDiverHeightProvider.overrideWith((ref) async => null),
          profileTrackingIndexProvider('d1').overrideWith((ref) => cursor),
        ],
        child: SingleChildScrollView(
          child: TrimCardSection(
            stored: dive,
            outcome: buoyancyOutcome(tanks: const [tank]),
            units: units,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  TrimGauges gauges(WidgetTester tester) =>
      tester.widget<TrimGauges>(find.byType(TrimGauges));

  testWidgets('shows the figure and its gauges', (tester) async {
    await pump(tester);
    expect(find.byType(TrimFigure), findsOneWidget);
    expect(find.byType(TrimGauges), findsOneWidget);
  });

  testWidgets('moving the profile cursor changes the trim', (tester) async {
    await pump(tester, cursor: 0);
    final start = gauges(tester).result.rollKgM;
    ProviderScope.containerOf(
      tester.element(find.byType(TrimCardSection)),
    ).read(profileTrackingIndexProvider('d1').notifier).state = 1;
    await tester.pumpAndSettle();
    final end = gauges(tester).result.rollKgM;
    // A stage on the left floats more as it empties.
    expect(end, isNot(closeTo(start, 1e-6)));
  });

  testWidgets('with no cursor it shows the rest anchor', (tester) async {
    await pump(tester);
    expect(find.byType(TrimFigure), findsOneWidget);
  });

  testWidgets('Try placements opens the sheet; closing it changes nothing', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 4000);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await pump(tester);
    final before = gauges(tester).result.pitchKgM;
    await tester.tap(find.text('Try placements'));
    await tester.pumpAndSettle();
    expect(find.byType(TrimTryoutView), findsOneWidget);
    final sheet = tester.state<State>(find.byType(TrimTryoutView));
    expect(sheet.mounted, isTrue);
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(find.byType(TrimTryoutView), findsNothing);
    expect(gauges(tester).result.pitchKgM, before);
  });
}
