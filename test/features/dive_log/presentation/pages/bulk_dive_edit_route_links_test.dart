import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/pages/bulk_dive_edit_page.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/tank_presets/presentation/providers/tank_preset_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

/// Bulk edit has no underwater route row: a route is linked on one dive's
/// Nav track card, never on several dives at once.
void main() {
  late DiveRepository dives;

  setUp(() async {
    await setUpTestDatabase();
    dives = DiveRepository();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  final routeRow = find.byKey(const ValueKey('dive-edit-route-row'));

  Future<Dive> insertDive() => dives.createDive(
    Dive(
      id: 'dive-route',
      dateTime: DateTime.utc(2025, 8, 22, 10),
      maxDepth: 20.0,
    ),
  );

  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<void> pumpEditor(
    WidgetTester tester, {
    required List<String> bulkDiveIds,
    List<Override> extraOverrides = const [],
  }) async {
    tester.platformDispatcher.localesTestValue = const [
      Locale('fr'),
      Locale('en'),
    ];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    tester.view.physicalSize = const Size(950, 8000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
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
          ...extraOverrides,
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: BulkDiveEditPage(diveIds: bulkDiveIds, embedded: true),
          ),
        ),
      ),
    );
    await settle(tester);
  }

  testWidgets('bulk edit has no route row', (tester) async {
    final first = await insertDive();
    final second = await dives.createDive(
      Dive(id: 'dive-route-2', dateTime: DateTime.utc(2025, 8, 23, 10)),
    );
    await pumpEditor(tester, bulkDiveIds: [first.id, second.id]);

    expect(routeRow, findsNothing);
  });
}
