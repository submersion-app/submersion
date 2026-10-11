import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/cylinder_passports/data/repositories/cylinder_passport_repository.dart';
import 'package:submersion/features/cylinder_passports/presentation/widgets/passport_scan_sheet.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_edit_page.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/gear_link.dart';
import 'package:submersion/features/equipment/domain/entities/gear_provenance.dart';
import 'package:submersion/features/equipment/domain/models/equipment_arrangement.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_arrangement_provider.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_set_providers.dart';
import 'package:submersion/features/tank_presets/presentation/providers/tank_preset_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

/// The dive editor's Equipment section takes a scanned tag (issue #2652).
void main() {
  const pid = '8f3a5c1e-1b2c-4d5e-8f90-1234567890ab';
  const fins = EquipmentItem(
    id: 'fins',
    name: 'Jets',
    type: EquipmentType.fins,
  );
  late DiveRepository repository;

  setUp(() async {
    final db = await setUpTestDatabase();
    await db.customStatement('PRAGMA foreign_keys = OFF');
    repository = DiveRepository();
  });
  tearDown(tearDownTestDatabase);

  Future<AppLocalizations> open(
    WidgetTester tester, {
    double width = 1200,
    Locale locale = const Locale('en'),
  }) async {
    tester.view.physicalSize = Size(width, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final dive = await tester.runAsync(() async {
      final repo = EquipmentRepository();
      await repo.createEquipment(fins);
      final reg = await repo.createEquipment(
        const EquipmentItem(
          id: 'reg',
          name: 'Primary',
          type: EquipmentType.regulator,
        ),
      );
      await CylinderPassportRepository().assignPassportId(
        equipmentId: reg.id,
        passportId: pid,
      );
      return repository.createDive(
        Dive(
          id: 'dive-1',
          diveNumber: 1,
          dateTime: DateTime(2026, 3, 28, 10),
          notes: '',
          gear: gearLinksFor(
            const [fins],
            const [GearProvenance(equipmentId: 'fins')],
          ),
        ),
      );
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...await getBaseOverrides(),
          diveRepositoryProvider.overrideWithValue(repository),
          diveListNotifierProvider.overrideWith(
            (ref) => DiveListNotifier(repository, ref),
          ),
          customTankPresetsProvider.overrideWith((ref) async => []),
          equipmentArrangementProvider.overrideWithValue(
            EquipmentArrangement.defaults.copyWith(groupByType: false),
          ),
          equipmentSetsProvider.overrideWith((ref) async => []),
          passportScanLauncherProvider.overrideWithValue(
            (context) async =>
                'https://submersion.app/g#f=1&p=$pid&t=regulator',
          ),
        ].cast(),
        child: MaterialApp(
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: DiveEditPage(diveId: dive!.id, embedded: true)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final summary = find.textContaining('1 ');
    final gasGear = find.textContaining('Air');
    final target = gasGear.evaluate().isNotEmpty ? gasGear : summary;
    await tester.ensureVisible(target.first);
    await tester.pumpAndSettle();
    await tester.tap(target.first);
    await tester.pumpAndSettle();
    return AppLocalizations.of(tester.element(find.byType(DiveEditPage)));
  }

  Future<void> tapScan(WidgetTester tester, AppLocalizations l10n) async {
    final scan = find.text(l10n.gearPassport_scan_action);
    await tester.ensureVisible(scan);
    await tester.pumpAndSettle();
    await tester.tap(scan);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a scanned tag adds its item to the dive, once', (tester) async {
    final l10n = await open(tester);
    expect(find.text('Primary'), findsNothing);
    await tapScan(tester, l10n);
    expect(find.text('Primary'), findsOneWidget);
    expect(find.text(l10n.gearPassport_scan_added('Primary')), findsOneWidget);
    // Let the first snack bar go before the second scan.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await tapScan(tester, l10n);
    expect(find.text('Primary'), findsOneWidget);
    expect(
      find.text(l10n.gearPassport_scan_alreadyOnDive('Primary')),
      findsOneWidget,
    );
  });

  for (final locale in const [Locale('en'), Locale('de')]) {
    testWidgets('every header action fits a 360 px phone ($locale)', (
      tester,
    ) async {
      final l10n = await open(tester, width: 360, locale: locale);
      // Other parts of the editor already overflow at this width in German;
      // this test is about the Equipment header only, which it measures
      // below, so drain whatever the rest of the page reported.
      while (tester.takeException() != null) {}
      for (final label in [
        l10n.diveLog_edit_useSet,
        l10n.diveLog_edit_add,
        l10n.gearPassport_scan_action,
        l10n.equipment_list_sortTooltip,
      ]) {
        // Crowded, the actions show as icons named by their tooltips.
        final action = find.byTooltip(label);
        expect(action, findsOneWidget, reason: label);
        expect(
          tester.getRect(action).right,
          lessThanOrEqualTo(360),
          reason: label,
        );
      }
    });
  }
}
