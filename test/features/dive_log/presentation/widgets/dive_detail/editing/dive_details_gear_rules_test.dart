import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_centers/domain/entities/dive_center.dart';
import 'package:submersion/features/dive_centers/domain/services/rental_memory_resolver.dart';
import 'package:submersion/features/dive_centers/presentation/providers/dive_center_gear_note_providers.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_weight.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_details_trip_rows.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_controller.dart';

import '../../../../../../helpers/mock_providers.dart';
import '../../../../../../helpers/test_database.dart';

/// The Details card starts two rules that reach the Cylinders and Weight
/// cards: a trip change relinks slots, and the dive center's last dive
/// replaces weights and cylinders (issue #4527, plan 5).
void main() {
  final l = AppLocalizationsEn();
  final t0 = DateTime.utc(2026, 3, 9, 9);
  final trip = Trip(
    id: 'trip',
    name: 'Red Sea',
    startDate: t0,
    endDate: t0.add(const Duration(days: 6)),
    createdAt: t0,
    updatedAt: t0,
  );
  final center = DiveCenter(
    id: 'center',
    name: 'Blue Hole Divers',
    createdAt: t0,
    updatedAt: t0,
  );
  const belt = DiveWeight(
    id: 'w',
    diveId: 'dive',
    weightType: WeightType.belt,
    amountKg: 6,
  );
  final last = LastDiveAtCenter(
    diveId: 'old',
    dateTime: t0.subtract(const Duration(days: 30)),
    weights: const [
      DiveWeight(
        id: 'x',
        diveId: 'old',
        weightType: WeightType.integrated,
        amountKg: 4,
      ),
    ],
    weightingFeedback: null,
    weightingFeedbackKg: null,
    tanks: const [DiveTank(id: 'y', volume: 11.1)],
  );

  setUp(setUpTestDatabase);
  tearDown(tearDownTestDatabase);

  Future<RecordEditController<Dive>> pump(
    WidgetTester tester,
    Dive dive,
    Widget Function(RecordEditController<Dive> c) row,
  ) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final controller = RecordEditController<Dive>(onSave: (_) async {})
      ..unlock(dive)
      ..openCard('details');
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...await getBaseOverrides(),
          lastDiveAtCenterProvider((
            centerId: center.id,
            excludingDiveId: dive.id,
          )).overrideWith((ref) async => last),
          diveCenterGearNotesProvider(
            center.id,
          ).overrideWith((ref) async => const []),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(
              child: RecordEditScope<Dive>(
                controller: controller,
                child: row(controller),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return controller;
  }

  testWidgets('a trip cleared on Details clears slot links: Cylinders gets '
      'its dot', (tester) async {
    final linked = Dive(
      id: 'dive',
      dateTime: t0,
      trip: trip,
      tripId: trip.id,
      tanks: const [DiveTank(id: 't', volume: 12, tripCylinderId: 's1')],
    );
    final c = await pump(
      tester,
      linked,
      (c) => DiveTripRow(session: c.session!),
    );

    await tester.tap(find.byTooltip(l.common_action_remove));
    await tester.runAsync(() => c.session!.settled());
    await tester.pumpAndSettle();

    expect(c.session!.working.tanks.single.tripCylinderId, isNull);
    expect(c.session!.changedCardIds, {'details', 'tanks'});
  });

  testWidgets('the last dive at the center applied: Weight and Cylinders get '
      'their dots', (tester) async {
    final c = await pump(
      tester,
      Dive(id: 'dive', dateTime: t0, diveCenter: center),
      (c) => DiveCenterRow(session: c.session!),
    );

    await tester.tap(find.text(l.diveCenters_rental_applyLastDive));
    await tester.pumpAndSettle();

    final w = c.session!.working;
    expect(w.weights.single.amountKg, 4);
    expect(w.tanks.single.volume, 11.1);
    expect(c.session!.changedCardIds, {'weights', 'tanks'});
  });

  testWidgets('applying over weights asks; declining changes nothing', (
    tester,
  ) async {
    final c = await pump(
      tester,
      Dive(id: 'dive', dateTime: t0, diveCenter: center, weights: const [belt]),
      (c) => DiveCenterRow(session: c.session!),
    );

    await tester.tap(find.text(l.diveCenters_rental_applyLastDive));
    await tester.pumpAndSettle();
    expect(find.text(l.diveCenters_rental_applyConfirmTitle), findsOneWidget);
    await tester.tap(find.text(l.common_action_cancel));
    await tester.pumpAndSettle();

    expect(c.session!.isDirty, isFalse);
  });

  testWidgets('no center, no card', (tester) async {
    await pump(
      tester,
      Dive(id: 'dive', dateTime: t0),
      (c) => DiveCenterRow(session: c.session!),
    );
    expect(find.text(l.diveCenters_rental_applyLastDive), findsNothing);
  });
}
