import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/number_input.dart';
import 'package:submersion/features/cylinder_passports/data/repositories/cylinder_fill_repository.dart';
import 'package:submersion/features/cylinder_passports/data/repositories/cylinder_passport_repository.dart';
import 'package:submersion/features/cylinder_passports/domain/entities/cylinder_fill.dart';
import 'package:submersion/features/cylinder_passports/presentation/providers/cylinder_passport_providers.dart';
import 'package:submersion/features/cylinder_passports/presentation/widgets/passport_scan_sheet.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    show GasMix;
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_attribute.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/gas_calculators/presentation/providers/gas_blender_providers.dart';
import 'package:submersion/features/gas_calculators/presentation/widgets/blender/blender_cylinder_card.dart';
import 'package:submersion/features/gas_calculators/presentation/widgets/blender/blender_volume_conversion.dart';
import 'package:submersion/features/gas_calculators/presentation/widgets/gas_blender_calculator.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../helpers/mock_providers.dart';
import '../../helpers/test_database.dart';
import '../../support/fake_app_settings_repository.dart';

void main() {
  const own = '8f3a5c1e-1b2c-4d5e-8f90-1234567890ab';
  late EquipmentItem filled;
  late EquipmentItem empty;
  late FakeAppSettingsRepository prefs;

  Future<EquipmentItem> tank(String name) =>
      EquipmentRepository().createEquipment(
        EquipmentItem(
          id: '',
          name: name,
          type: EquipmentType.tank,
          attributes: const [
            EquipmentAttribute(
              id: '',
              equipmentId: '',
              key: EquipmentAttrKeys.volumeL,
              valueNum: 12,
            ),
          ],
        ),
      );

  setUp(() async {
    await setUpTestDatabase();
    prefs = FakeAppSettingsRepository();
    filled = await tank('Faber 12');
    empty = await tank('Spare 12');
    await CylinderPassportRepository().assignPassportId(
      equipmentId: filled.id,
      passportId: own,
    );
    final t = DateTime(2026, 9, 27);
    await CylinderFillRepository().create(
      CylinderFill(
        id: '',
        passportId: own,
        equipmentId: filled.id,
        filledAt: t,
        o2Percent: 21,
        hePercent: 35,
        createdAt: t,
        updatedAt: t,
      ),
    );
  });
  tearDown(tearDownTestDatabase);

  Future<(AppLocalizations, WidgetRef)> pump(
    WidgetTester tester, {
    AppSettings settings = const AppSettings(),
    String? scanned,
    Future<List<EquipmentItem>> Function()? gear,
  }) async {
    final overrides = await getBaseOverrides(
      settingsNotifier: MockSettingsNotifier(settings),
    );
    late WidgetRef captured;
    await tester.pumpWidget(
      ProviderScope(
        // A new key per pump, so a second pump is a fresh scope.
        key: UniqueKey(),
        overrides: [
          ...overrides,
          appSettingsRepositoryProvider.overrideWithValue(prefs),
          activeEquipmentProvider.overrideWith(
            (ref) => (gear ?? () async => [filled, empty])(),
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
            body: Consumer(
              builder: (context, ref, _) {
                captured = ref;
                return const GasBlenderCalculator();
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final l10n = AppLocalizations.of(
      tester.element(find.byType(GasBlenderCalculator)),
    );
    return (l10n, captured);
  }

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

  Future<void> choose(WidgetTester tester, String name) async {
    await tapAndWait(tester, find.byKey(const Key('blender-choose-cylinder')));
    await tapAndWait(tester, find.text(name));
  }

  /// The start row's pressure, O2 and He, in that order.
  List<String> startFields(WidgetTester tester) => [
    for (final field in tester.widgetList<TextField>(
      find.descendant(
        of: find.byType(BlenderCylinderCard),
        matching: find.byType(TextField),
      ),
    ))
      field.controller!.text,
  ].sublist(0, 3);

  String cylinderField(WidgetTester tester, AppLocalizations l10n) => tester
      .widget<TextField>(
        find.byWidgetPredicate(
          (w) =>
              w is TextField &&
              (w.decoration?.labelText ?? '').startsWith(
                l10n.gasCalculators_blender_cylinderVolume,
              ),
        ),
      )
      .controller!
      .text;

  testWidgets('a cylinder fills in its size and its last mix', (tester) async {
    final (l10n, ref) = await pump(tester);
    await choose(tester, 'Faber 12');
    expect(ref.read(blenderCylinderLitersProvider), 12);
    expect(ref.read(blenderStartMixProvider), const GasMix(o2: 21, he: 35));
    expect(startFields(tester).sublist(1), ['21', '35']);
    expect(cylinderField(tester, l10n), '12');
    expect(
      find.text(l10n.gasCalculators_blender_filledFrom('Faber 12', 'Tx 21/35')),
      findsOne,
    );
  });

  testWidgets('the size reads in imperial units', (tester) async {
    const imperial = AppSettings(volumeUnit: VolumeUnit.cubicFeet);
    final (l10n, _) = await pump(tester, settings: imperial);
    await choose(tester, 'Faber 12');
    expect(
      cylinderField(tester, l10n),
      formatRoundedForInput(litersToDisplayVolume(12, imperial), 2),
    );
  });

  testWidgets('the choice outlives the blender', (tester) async {
    await pump(tester);
    await choose(tester, 'Faber 12');
    final (l10n, _) = await pump(tester);
    expect(startFields(tester).sublist(1), ['21', '35']);
    expect(cylinderField(tester, l10n), '12');
  });

  testWidgets('a cylinder with no fills sets only its size', (tester) async {
    final (_, ref) = await pump(tester);
    final before = ref.read(blenderStartMixProvider);
    await choose(tester, 'Spare 12');
    expect(ref.read(blenderCylinderLitersProvider), 12);
    expect(ref.read(blenderStartMixProvider), before);
  });

  testWidgets('scanning a tag with a newer fill takes that fill', (
    tester,
  ) async {
    // Written by the diver's other phone, not yet synced here.
    final (_, ref) = await pump(
      tester,
      scanned:
          'https://submersion.app/c#f=1&p=$own'
          '&fi=3f0c2b8e-6a1d-4c47-9e2a-5b7d8c9e0f11'
          '&ft=2026-09-28T09%3A30%3A00Z&fo=32&fp=232',
    );
    await tapAndWait(tester, find.byKey(const Key('blender-choose-cylinder')));
    await tapAndWait(tester, find.byKey(const Key('blender-scan-tag')));
    expect(ref.read(blenderStartMixProvider), const GasMix(o2: 32));
  });

  testWidgets('closing the blender mid-choice leaves quietly', (tester) async {
    final gate = Completer<CylinderFill?>();
    final showBlender = ValueNotifier(true);
    addTearDown(showBlender.dispose);
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...overrides,
          appSettingsRepositoryProvider.overrideWithValue(prefs),
          activeEquipmentProvider.overrideWith((ref) async => [filled]),
          newestFillProvider(filled.id).overrideWith((ref) => gate.future),
        ].cast(),
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ValueListenableBuilder<bool>(
              valueListenable: showBlender,
              builder: (context, show, _) =>
                  show ? const GasBlenderCalculator() : const Text('gone'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await choose(tester, 'Faber 12');
    // The newest fill is still being read when the diver leaves.
    showBlender.value = false;
    await tester.pumpAndSettle();
    gate.complete(null);
    await tester.pumpAndSettle();
    expect(find.text('gone'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a gear list that fails to load says so', (tester) async {
    final (l10n, ref) = await pump(
      tester,
      gear: () async => throw StateError('database is locked'),
    );
    final before = ref.read(blenderStartMixProvider);
    await tapAndWait(tester, find.byKey(const Key('blender-choose-cylinder')));
    expect(find.text(l10n.gasCalculators_blender_cylinderFailed), findsOne);
    expect(ref.read(blenderStartMixProvider), before);
  });

  testWidgets('a scan that is not a cylinder tag says so', (tester) async {
    final (l10n, ref) = await pump(tester, scanned: 'hello');
    final before = ref.read(blenderStartMixProvider);
    await tapAndWait(tester, find.byKey(const Key('blender-choose-cylinder')));
    await tapAndWait(tester, find.byKey(const Key('blender-scan-tag')));
    expect(find.text(l10n.passport_tag_linkInvalid), findsOne);
    expect(ref.read(blenderStartMixProvider), before);
  });

  testWidgets('a scan after a pick still takes the tag\'s newer fill', (
    tester,
  ) async {
    final (_, ref) = await pump(
      tester,
      scanned:
          'https://submersion.app/c#f=1&p=$own'
          '&fi=3f0c2b8e-6a1d-4c47-9e2a-5b7d8c9e0f11'
          '&ft=2026-09-28T09%3A30%3A00Z&fo=32&fp=232',
    );
    // Picking the tank first caches its newest fill (Tx 21/35).
    await choose(tester, 'Faber 12');
    expect(ref.read(blenderStartMixProvider), const GasMix(o2: 21, he: 35));
    await tapAndWait(tester, find.byKey(const Key('blender-choose-cylinder')));
    await tapAndWait(tester, find.byKey(const Key('blender-scan-tag')));
    expect(ref.read(blenderStartMixProvider), const GasMix(o2: 32));
  });
}
