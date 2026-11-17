import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/pages/bulk_dive_edit_page.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/bulk_field_gate.dart';
import 'package:submersion/features/tank_presets/presentation/providers/tank_preset_providers.dart';
import 'package:submersion/features/trips/domain/services/trip_draft.dart';
import 'package:submersion/features/trips/presentation/pages/trip_edit_page.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/forms/form_row.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

/// New Trip in the dive editor and bulk edit opens at the dives' dates, not
/// today's (issue #3351), and moves no dive until the edit saves.
void main() {
  late DiveRepository dives;

  setUp(() async {
    await setUpTestDatabase();
    dives = DiveRepository();
  });
  tearDown(tearDownTestDatabase);

  Dive dive(String id, DateTime at) =>
      Dive(id: id, dateTime: at, entryTime: at);

  Future<GoRouter> pumpRouter(
    WidgetTester tester,
    GoRoute editor, {
    List<Override> extra = const [],
  }) async {
    tester.view.physicalSize = const Size(950, 8000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final router = GoRouter(
      initialLocation: '/edit',
      routes: [
        editor,
        GoRoute(
          path: '/trips/new',
          builder: (context, state) =>
              TripEditPage(draft: state.extra as TripDraft?),
        ),
      ],
    );
    addTearDown(router.dispose);
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...overrides.cast<Override>(),
          diveRepositoryProvider.overrideWithValue(dives),
          diveListNotifierProvider.overrideWith(
            (ref) => DiveListNotifier(dives, ref),
          ),
          customTankPresetsProvider.overrideWith((ref) async => []),
          ...extra,
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
    return router;
  }

  Future<void> openNewTrip(WidgetTester tester) async {
    final tripRow = find.ancestor(
      of: find.text('Trip'),
      matching: find.byType(FormRow),
    );
    if (tripRow.evaluate().isEmpty) {
      await tester.ensureVisible(find.text('Trip').first);
      await tester.tap(find.text('Trip').first);
      await tester.pumpAndSettle();
    }
    final row = tripRow.first;
    await tester.ensureVisible(row);
    await tester.pumpAndSettle();
    await tester.tap(row);
    await tester.pumpAndSettle();
    await tester.tap(find.text('New Trip').last);
    await tester.pumpAndSettle();
  }

  TripDraft draftOnScreen(WidgetTester tester) =>
      tester.widget<TripEditPage>(find.byType(TripEditPage)).draft!;
  testWidgets('bulk edit\'s form spans the selected dives', (tester) async {
    await dives.createDive(dive('a', DateTime.utc(2025, 3, 10, 9)));
    await dives.createDive(dive('b', DateTime.utc(2025, 3, 14, 9)));
    await pumpRouter(
      tester,
      GoRoute(
        path: '/edit',
        builder: (context, state) =>
            const BulkDiveEditPage(diveIds: ['a', 'b']),
      ),
    );
    final gate = find.ancestor(
      of: find.text('Trip'),
      matching: find.byType(BulkFieldGate),
    );
    await tester.ensureVisible(gate);
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(of: gate, matching: find.byType(Checkbox)),
    );
    await tester.pumpAndSettle();

    await openNewTrip(tester);

    final draft = draftOnScreen(tester);
    expect(draft.trip.startDate, DateTime(2025, 3, 10));
    expect(draft.trip.endDate, DateTime(2025, 3, 14));
    expect(draft.diveIds, isEmpty);
  });
}
