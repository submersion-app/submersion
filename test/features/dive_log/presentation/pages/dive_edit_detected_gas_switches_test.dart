import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart'
    show GasSwitche, GasSwitchesCompanion;
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_edit_page.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/tank_presets/presentation/providers/tank_preset_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/forms/minutes_seconds_field.dart';
import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

/// Issue #4335: on a sidemount dive with two cylinders of Air, the computer
/// logged its starting gas against the wrong cylinder and none of the
/// turns. The switch editor offers what the cylinder pressures show in one
/// tap, and keeps a switch logged before the primary computer started.
void main() {
  late DiveRepository repository;
  late String? previousLocale;

  const left = DiveTank(
    id: 'tank-left',
    volume: 12,
    role: TankRole.sidemountLeft,
    order: 0,
  );
  const right = DiveTank(
    id: 'tank-right',
    volume: 12,
    role: TankRole.sidemountRight,
    order: 1,
  );
  final profile = [
    const DiveProfilePoint(timestamp: 0, depth: 0),
    for (var t = 60; t <= 2400; t += 60)
      DiveProfilePoint(timestamp: t, depth: 18),
  ];

  /// Left breathed to 10:00 and from 20:00 to 30:00, right in between and
  /// from 30:00 to the end, every reading every 2 s.
  Map<String, List<TankPressurePoint>> rotation() {
    bool onLeft(int t) => t <= 600 || (t > 1200 && t <= 1800);
    List<TankPressurePoint> series(String id, bool Function(int t) on) {
      var bar = 200.0;
      return [
        for (var t = 0; t <= 2400; t += 2)
          TankPressurePoint(
            tankId: id,
            timestamp: t,
            pressure: (t > 0 && on(t) ? bar -= 3.4 / 30 : bar).roundToDouble(),
          ),
      ];
    }

    return {
      'tank-left': series('tank-left', onLeft),
      'tank-right': series('tank-right', (t) => t > 0 && !onLeft(t)),
    };
  }

  setUp(() async {
    previousLocale = Intl.defaultLocale;
    Intl.defaultLocale = 'en_US';
    await setUpTestDatabase();
    repository = DiveRepository();
  });

  tearDown(() async {
    Intl.defaultLocale = previousLocale;
    await tearDownTestDatabase();
  });

  Future<Dive> seedDive({
    List<({String id, int t, String tankId})>? rows,
  }) async {
    final dive = await repository.createDive(
      Dive(
        id: 'dive-4335',
        dateTime: DateTime.utc(2026, 11, 1, 10),
        runtime: const Duration(seconds: 2400),
        tanks: const [left, right],
        profile: profile,
      ),
    );
    final db = DatabaseService.instance.database;
    for (final row in rows ?? const <({String id, int t, String tankId})>[]) {
      await db
          .into(db.gasSwitches)
          .insert(
            GasSwitchesCompanion.insert(
              id: row.id,
              diveId: dive.id,
              tankId: row.tankId,
              timestamp: row.t,
              createdAt: 0,
              depth: const Value(0),
            ),
          );
    }
    return dive;
  }

  Future<void> pumpEditor(
    WidgetTester tester,
    String diveId, {
    void Function(String)? onSaved,
    Map<String, List<TankPressurePoint>> pressures = const {},
  }) async {
    tester.view.physicalSize = const Size(950, 8000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final overrides = await getBaseOverrides(
      settingsNotifier: MockSettingsNotifier(const AppSettings()),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...overrides.cast<Override>(),
          diveRepositoryProvider.overrideWithValue(repository),
          diveListNotifierProvider.overrideWith(
            (ref) => DiveListNotifier(repository, ref),
          ),
          customTankPresetsProvider.overrideWith((ref) async => []),
          tankPressuresProvider(diveId).overrideWith((ref) async => pressures),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: DiveEditPage(
              diveId: diveId,
              embedded: true,
              onSaved: onSaved,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final gasGear = find.textContaining('Gas & Gear');
    await tester.ensureVisible(gasGear.first);
    await tester.pumpAndSettle();
    await tester.tap(gasGear.first, warnIfMissed: false);
    await tester.pumpAndSettle();
  }

  Future<List<GasSwitche>> storedSwitches() {
    final db = DatabaseService.instance.database;
    return (db.select(db.gasSwitches)
          ..where((t) => t.diveId.equals('dive-4335'))
          ..orderBy([(t) => OrderingTerm.asc(t.timestamp)]))
        .get();
  }

  Future<void> save(WidgetTester tester) async {
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
  }

  final fill = find.text('Fill in 4 switches from the cylinder pressures');

  testWidgets('re-points the logged start and adds every turn', (tester) async {
    final dive = await seedDive(
      rows: [(id: 'logged-start', t: 0, tankId: 'tank-right')],
    );
    String? savedId;
    await pumpEditor(
      tester,
      dive.id,
      pressures: rotation(),
      onSaved: (id) => savedId = id,
    );

    await tester.ensureVisible(fill);
    await tester.pumpAndSettle();
    await tester.tap(fill);
    await tester.pumpAndSettle();

    // Nothing is left to fill in, and the picker shows the new cylinder.
    expect(find.textContaining('from the cylinder pressures'), findsNothing);
    expect(find.byType(MinutesSecondsField), findsNWidgets(4));
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('gas-switch-tank-logged-start')),
        matching: find.textContaining('Tank 1'),
      ),
      findsOneWidget,
    );

    await save(tester);
    expect(savedId, isNotNull, reason: 'save should complete');
    final rows = await storedSwitches();
    expect(
      [for (final r in rows) r.tankId],
      ['tank-left', 'tank-right', 'tank-left', 'tank-right'],
    );
    expect(rows.first.id, 'logged-start');
    expect(rows[1].timestamp, closeTo(600, 30));
    expect(rows[2].timestamp, closeTo(1200, 30));
    expect(rows[3].timestamp, closeTo(1800, 30));
    expect(rows[1].depth, 18.0);
  });

  testWidgets('no pressures offer nothing to fill in', (tester) async {
    final dive = await seedDive(
      rows: [(id: 'logged-start', t: 0, tankId: 'tank-right')],
    );
    await pumpEditor(tester, dive.id);

    expect(find.textContaining('from the cylinder pressures'), findsNothing);
  });

  testWidgets('a switch logged before the dive start does not block Save', (
    tester,
  ) async {
    final dive = await seedDive(
      rows: [
        (id: 'early', t: -103, tankId: 'tank-left'),
        (id: 'start', t: 0, tankId: 'tank-left'),
      ],
    );
    String? savedId;
    await pumpEditor(tester, dive.id, onSaved: (id) => savedId = id);

    expect(find.text('-1:43'), findsOneWidget);
    // Another field, so the dive is dirty and Save writes it.
    await tester.enterText(
      find.descendant(
        of: find.byKey(const ValueKey('gas-switch-time-start')),
        matching: find.byType(TextFormField),
      ),
      '0:30',
    );
    await tester.pumpAndSettle();
    await save(tester);

    expect(savedId, isNotNull, reason: 'save should complete');
    final rows = await storedSwitches();
    expect([for (final r in rows) r.timestamp], [-103, 30]);
  });
}
