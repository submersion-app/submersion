import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_edit_page.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/edit_sections/gas_switches_editor.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/tank_presets/presentation/providers/tank_preset_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

/// A suit inflation bottle is not a cylinder to switch to (issue #4243): a
/// dive with one breathing cylinder and the bottle has no gas switch list,
/// where the bottle would otherwise count as the second cylinder.
void main() {
  late DiveRepository repository;
  late String? previousLocale;

  const back = DiveTank(id: 'tank-back', volume: 12, order: 0);
  const deco = DiveTank(
    id: 'tank-deco',
    volume: 7,
    role: TankRole.deco,
    gasMix: GasMix(o2: 50),
    order: 1,
  );
  const suit = DiveTank(
    id: 'tank-suit',
    volume: 0.85,
    role: TankRole.suitInflation,
    order: 2,
  );

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

  Future<void> pumpEditor(WidgetTester tester, List<DiveTank> tanks) async {
    final dive = await repository.createDive(
      Dive(
        id: 'dive-4243',
        dateTime: DateTime.utc(2026, 5, 3, 10),
        runtime: const Duration(seconds: 1800),
        tanks: tanks,
        profile: const [
          DiveProfilePoint(timestamp: 0, depth: 0),
          DiveProfilePoint(timestamp: 900, depth: 30),
          DiveProfilePoint(timestamp: 1800, depth: 0),
        ],
      ),
    );
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
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: DiveEditPage(diveId: dive.id, embedded: true)),
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

  testWidgets('one cylinder and a suit bottle show no gas switch list', (
    tester,
  ) async {
    await pumpEditor(tester, const [back, suit]);

    expect(find.text('Add Tank'), findsOneWidget);
    expect(find.byType(GasSwitchesEditor), findsNothing);
  });

  testWidgets('two cylinders and a suit bottle keep the list', (tester) async {
    await pumpEditor(tester, const [back, deco, suit]);

    expect(find.byType(GasSwitchesEditor), findsOneWidget);
  });
}
