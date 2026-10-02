import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/cylinder_passports/data/repositories/cylinder_passport_repository.dart';
import 'package:submersion/features/cylinder_passports/presentation/widgets/log_fill_sheet.dart';
import 'package:submersion/features/cylinder_passports/presentation/widgets/passport_scan_sheet.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    show GasMix;
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/gas_calculators/presentation/providers/gas_blender_providers.dart';
import 'package:submersion/features/gas_calculators/presentation/widgets/blender/blender_procedure_card.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../helpers/mock_providers.dart';
import '../../helpers/test_database.dart';

void main() {
  const own = '8f3a5c1e-1b2c-4d5e-8f90-1234567890ab';
  const stranger = '11111111-2222-4333-8444-555555555555';
  late AppDatabase db;
  late EquipmentItem tank;

  setUp(() async {
    db = await setUpTestDatabase();
    tank = await EquipmentRepository().createEquipment(
      const EquipmentItem(id: '', name: 'Faber 12', type: EquipmentType.tank),
    );
    await CylinderPassportRepository().assignPassportId(
      equipmentId: tank.id,
      passportId: own,
    );
  });
  tearDown(tearDownTestDatabase);

  /// The procedure card for a 21/35 trimix at 232 bar settling at 30 C.
  Future<(AppLocalizations, WidgetRef)> pump(
    WidgetTester tester, {
    String? scanned,
    Future<List<EquipmentItem>> Function()? gear,
  }) async {
    final overrides = await getBaseOverrides();
    late WidgetRef captured;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...overrides,
          activeEquipmentProvider.overrideWith(
            (ref) => (gear ?? () async => [tank])(),
          ),
          passportScanLauncherProvider.overrideWithValue(
            (context) async => scanned,
          ),
        ].cast(),
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(
              child: Consumer(
                builder: (context, ref, _) {
                  captured = ref;
                  return const BlenderProcedureCard();
                },
              ),
            ),
          ),
        ),
      ),
    );
    captured.read(blenderTargetMixProvider.notifier).state = const GasMix(
      o2: 21,
      he: 35,
    );
    captured.read(blenderTargetPressureProvider.notifier).state = 232;
    captured.read(blenderSettledTempProvider.notifier).state = 30;
    await tester.pumpAndSettle();
    final l10n = AppLocalizations.of(
      tester.element(find.byType(BlenderProcedureCard)),
    );
    return (l10n, captured);
  }

  /// Taps, then lets the database work behind the tap finish.
  Future<void> tapAndWait(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    for (var i = 0; i < 3; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pumpAndSettle();
    }
  }

  String fieldText(WidgetTester tester, String key) =>
      tester.widget<TextField>(find.byKey(Key(key))).controller!.text;

  testWidgets('a valid blend offers Log this fill', (tester) async {
    final (l10n, _) = await pump(tester);
    expect(find.text(l10n.gasCalculators_blender_logFill), findsOneWidget);
  });

  testWidgets('a blend that cannot be made offers nothing to log', (
    tester,
  ) async {
    final (l10n, ref) = await pump(tester);
    ref.read(blenderStartPressureProvider.notifier).state = 250;
    await tester.pumpAndSettle();
    expect(find.text(l10n.gasCalculators_blender_logFill), findsNothing);
  });

  testWidgets('choosing the tank opens the sheet with the planned fill', (
    tester,
  ) async {
    final (l10n, _) = await pump(tester);
    await tapAndWait(tester, find.byKey(const Key('blender-log-fill')));
    expect(find.text(l10n.gasCalculators_blender_chooseCylinder), findsOne);
    await tapAndWait(tester, find.text('Faber 12'));
    expect(find.byType(LogFillSheet), findsOneWidget);
    expect(fieldText(tester, 'logFill_o2'), '21');
    expect(fieldText(tester, 'logFill_he'), '35');
    expect(fieldText(tester, 'logFill_pressure'), '232');
    expect(fieldText(tester, 'logFill_temperature'), '30');
    expect(find.text(l10n.passport_logFill_analysedHint), findsOneWidget);
  });

  testWidgets('scanning the tank tag picks the same tank', (tester) async {
    await pump(tester, scanned: 'https://submersion.app/c#f=1&p=$own');
    await tapAndWait(tester, find.byKey(const Key('blender-log-fill')));
    await tapAndWait(tester, find.byKey(const Key('blender-scan-tag')));
    expect(find.byType(LogFillSheet), findsOneWidget);
    final sheet = tester.widget<LogFillSheet>(find.byType(LogFillSheet));
    expect(sheet.equipmentId, tank.id);
    expect(sheet.passportId, own);
  });

  testWidgets("someone else's tag says so and opens nothing", (tester) async {
    final (l10n, _) = await pump(
      tester,
      scanned: 'https://submersion.app/c#f=1&p=$stranger',
    );
    await tapAndWait(tester, find.byKey(const Key('blender-log-fill')));
    await tapAndWait(tester, find.byKey(const Key('blender-scan-tag')));
    expect(find.text(l10n.gasCalculators_blender_notYourCylinder), findsOne);
    expect(find.byType(LogFillSheet), findsNothing);
  });

  testWidgets('saving stores the analysed values under the passport', (
    tester,
  ) async {
    final (l10n, _) = await pump(tester);
    await tapAndWait(tester, find.byKey(const Key('blender-log-fill')));
    await tapAndWait(tester, find.text('Faber 12'));
    await tester.enterText(find.byKey(const Key('logFill_o2')), '20.6');
    await tapAndWait(tester, find.text(l10n.forms_save));
    expect(find.byType(LogFillSheet), findsNothing);
    final fills = await tester.runAsync(
      () => db.select(db.cylinderFills).get(),
    );
    final fill = fills!.single;
    expect(fill.passportId, own);
    expect(fill.equipmentId, tank.id);
    expect(fill.o2Percent, 20.6);
    expect(fill.hePercent, 35);
    expect(fill.pressureBar, 232);
    expect(fill.temperatureC, 30);
  });

  testWidgets('a gear list that fails to load says so', (tester) async {
    final (l10n, _) = await pump(
      tester,
      gear: () async => throw StateError('database is locked'),
    );
    await tapAndWait(tester, find.byKey(const Key('blender-log-fill')));
    expect(find.text(l10n.gasCalculators_blender_cylinderFailed), findsOne);
    expect(find.byType(LogFillSheet), findsNothing);
  });
}
