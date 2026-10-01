import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    show GasMix;
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder_event.dart';
import 'package:submersion/features/trips/domain/entities/trip_gas_record.dart';
import 'package:submersion/features/trips/presentation/providers/trip_gas_record_providers.dart';
import 'package:submersion/features/trips/presentation/widgets/cylinders/trip_cylinder_record_view.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../../helpers/mock_providers.dart';

void main() {
  final at = DateTime.utc(2026, 3, 9, 9, 5);
  final slot = TripCylinder(
    id: 'a',
    tripId: 't1',
    label: 'Truck 1',
    workingPressure: 207,
    createdAt: at,
    updatedAt: at,
  );
  final fill = TripCylinderEvent(
    id: 'f1',
    tripCylinderId: 'a',
    kind: TripCylinderEventKind.fill,
    occurredAt: at,
    bottleLabel: '14',
    pressure: 200,
    o2Percent: 32,
    analyzedO2: 31.8,
    diveCenterId: 'c1',
    createdAt: at,
    updatedAt: at,
  );

  TripGasRecordRow row(String tankId, {String? diver, double? litres}) =>
      TripGasRecordRow(
        tank: TripGasRecordTank(
          tankId: tankId,
          diveId: 'd-$tankId',
          entryTime: at,
          diverId: diver,
          diverName: diver == null ? null : 'Diver $diver',
          siteName: 'Salt Pier',
          startPressure: 200,
          endPressure: 60,
          volume: 11.1,
          gasMix: const GasMix(o2: 32),
          tripCylinderId: 'a',
        ),
        cylinder: slot,
        bottleLabel: '14',
        fill: fill,
        fillPressure: 200,
        litres: litres,
      );

  TripGasRecord recordOf({
    List<TripGasRecordRow>? rows,
    List<TripGasRecordSlotTotal>? slots,
    List<TripUnlinkedTank> unlinked = const [],
    bool multipleDivers = false,
  }) => TripGasRecord(
    rows: rows ?? [row('t1', litres: 1554)],
    slots:
        slots ??
        [
          TripGasRecordSlotTotal(
            cylinder: slot,
            dives: 2,
            litres: 1554,
            leftOut: 1,
          ),
        ],
    fillsLogged: 3,
    costs: const [MapEntry('USD', 22.0)],
    packageFills: 1,
    unlinked: unlinked,
    multipleDivers: multipleDivers,
  );

  Future<void> pump(WidgetTester tester, TripGasRecord record) async {
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(
            body: TripCylinderRecordView(
              tripId: 't1',
              centerNames: {'c1': 'Dive Friends'},
            ),
          ),
        ),
        GoRoute(
          path: '/dives/:diveId/edit',
          builder: (_, _) => const Scaffold(body: Text('EDIT DIVE')),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
          tripGasRecordProvider('t1').overrideWith((ref) async => record),
        ],
        child: MaterialApp.router(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('totals: fills, per slot litres and left out, cost', (
    tester,
  ) async {
    await pump(tester, recordOf());
    final totals = find.byKey(const Key('record-totals'));
    expect(
      find.descendant(of: totals, matching: find.text('3 fills logged')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: totals,
        matching: find.textContaining('1 dive left out'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: totals, matching: find.textContaining(r'$22.00')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: totals,
        matching: find.textContaining('1 package fill'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('a slot with no figure reads "--", one with no dives no volume', (
    tester,
  ) async {
    final empty = TripCylinder(
      id: 'b',
      tripId: 't1',
      label: 'Truck 2',
      createdAt: at,
      updatedAt: at,
    );
    await pump(
      tester,
      recordOf(
        rows: [row('t1'), row('t2')],
        slots: [
          TripGasRecordSlotTotal(cylinder: slot, dives: 2, leftOut: 2),
          TripGasRecordSlotTotal(cylinder: empty, dives: 0, leftOut: 0),
        ],
      ),
    );
    final totals = find.byKey(const Key('record-totals'));
    expect(
      find.descendant(
        of: totals,
        matching: find.text('Truck 1 · 2 dives · -- · 2 dives left out'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: totals, matching: find.text('Truck 2 · 0 dives')),
      findsOneWidget,
    );
  });

  testWidgets('a row names its bottle, analysis, fill and station', (
    tester,
  ) async {
    await pump(tester, recordOf());
    final r = find.byKey(const Key('record-row-t1'));
    expect(
      find.descendant(
        of: r,
        matching: find.textContaining('Truck 1 · Bottle 14'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: r, matching: find.textContaining('Analyzed')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: r, matching: find.textContaining('Dive Friends')),
      findsOneWidget,
    );
  });

  testWidgets('a single-diver trip names no diver', (tester) async {
    await pump(tester, recordOf(rows: [row('t1', diver: 'x', litres: 1)]));
    expect(find.textContaining('Diver x'), findsNothing);
  });

  testWidgets('names show only with more than one diver', (tester) async {
    await pump(
      tester,
      recordOf(rows: [row('t1', diver: 'x', litres: 1)], multipleDivers: true),
    );
    expect(find.textContaining('Diver x'), findsOneWidget);
  });

  testWidgets('a row with no figure shows "--" for litres', (tester) async {
    await pump(tester, recordOf(rows: [row('t1')]));
    expect(
      find.descendant(
        of: find.byKey(const Key('record-row-t1')),
        matching: find.textContaining('--'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('the gaps line lists unlinked tanks and opens the editor', (
    tester,
  ) async {
    await pump(
      tester,
      recordOf(
        unlinked: [
          TripUnlinkedTank(
            tankId: 'n1',
            diveId: 'd7',
            entryTime: at,
            siteName: 'Klein Bonaire',
            tankOrder: 1,
          ),
        ],
      ),
    );
    await tester.tap(find.byKey(const Key('record-gaps')));
    await tester.pumpAndSettle();
    expect(find.text('Not linked to a cylinder'), findsOneWidget);
    await tester.tap(find.textContaining('Klein Bonaire'));
    await tester.pumpAndSettle();
    expect(find.text('EDIT DIVE'), findsOneWidget);
  });

  testWidgets('no gaps, no gaps line; no rows, the empty text', (tester) async {
    await pump(tester, recordOf(rows: const []));
    expect(find.byKey(const Key('record-gaps')), findsNothing);
    expect(find.byKey(const Key('record-empty')), findsOneWidget);
  });
}
