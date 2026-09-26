import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/cylinder_passports/domain/entities/cylinder_fill.dart';
import 'package:submersion/features/cylinder_passports/domain/entities/cylinder_passport_payload.dart';
import 'package:submersion/features/cylinder_passports/presentation/pages/passport_page.dart';
import 'package:submersion/features/cylinder_passports/presentation/providers/cylinder_passport_providers.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/data/repositories/service_schedule_repository.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_attribute.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/service_clock_status.dart';
import 'package:submersion/features/equipment/domain/entities/service_kind.dart';
import 'package:submersion/features/equipment/domain/entities/service_record.dart';
import 'package:submersion/features/equipment/domain/entities/service_schedule.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_component_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

void main() {
  late String? savedIntlLocale;
  setUp(() async {
    savedIntlLocale = Intl.defaultLocale;
    Intl.defaultLocale = 'en_US';
    await setUpTestDatabase();
  });
  tearDown(() async {
    Intl.defaultLocale = savedIntlLocale;
    await tearDownTestDatabase();
  });

  const id = 'eq-1';
  const pid = '8f3a5c1e-1b2c-4d5e-8f90-1234567890ab';
  final now = DateTime(2026, 9, 25);
  const tank = EquipmentItem(
    id: id,
    name: 'Faber 12',
    type: EquipmentType.tank,
    brand: 'Faber',
    serialNumber: 'F123',
    attributes: [
      EquipmentAttribute(
        id: 'a2',
        equipmentId: id,
        key: EquipmentAttrKeys.volumeL,
        valueNum: 12,
      ),
      EquipmentAttribute(
        id: 'a3',
        equipmentId: id,
        key: EquipmentAttrKeys.workingPressureBar,
        valueNum: 232,
      ),
      EquipmentAttribute(
        id: 'a4',
        equipmentId: id,
        key: EquipmentAttrKeys.tankMaterial,
        valueText: 'steel',
      ),
    ],
  );

  ServiceClockStatus clock(String kindId, ServiceClockSeverity severity) =>
      ServiceClockStatus(
        schedule: ServiceSchedule(
          id: 's-$kindId',
          equipmentId: id,
          serviceKindId: kindId,
          createdAt: now,
          updatedAt: now,
        ),
        kind: ServiceKind(
          id: kindId,
          name: kindId,
          createdAt: now,
          updatedAt: now,
        ),
        anchor: DateTime(2025, 1, 1),
        dueDate: DateTime(2027, 1, 1),
        severity: severity,
        now: now,
      );

  ServiceRecord record(String kindId, DateTime date) => ServiceRecord(
    id: 'r-$kindId-${date.millisecondsSinceEpoch}',
    equipmentId: id,
    serviceCategory: ServiceCategory.inspection,
    serviceKindId: kindId,
    serviceDate: date,
    createdAt: date,
    updatedAt: date,
  );

  CylinderFill fill(double o2) => CylinderFill(
    id: 'f-$o2',
    passportId: pid,
    equipmentId: id,
    filledAt: DateTime(2026, 9, 20),
    o2Percent: o2,
    pressureBar: 220,
    temperatureC: 21.5,
    stationName: 'Blue Water Fills',
    createdAt: now,
    updatedAt: now,
  );

  Future<AppLocalizations> pump(
    WidgetTester tester, {
    List<CylinderFill> fills = const [],
    List<ServiceClockStatus> clocks = const [],
    List<ServiceRecord> records = const [],
    List<dynamic> extraOverrides = const [],
    AppSettings? settings,
  }) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(600, 2800);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final overrides = await getBaseOverrides(
      settingsNotifier: settings == null
          ? null
          : MockSettingsNotifier(settings),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...overrides,
          equipmentItemProvider(id).overrideWith((ref) async => tank),
          passportIdProvider(id).overrideWith((ref) async => pid),
          fillsForEquipmentProvider(id).overrideWith((ref) async => fills),
          newestFillProvider(
            id,
          ).overrideWith((ref) async => fills.isEmpty ? null : fills.first),
          serviceClockStatusesProvider(id).overrideWith((ref) async => clocks),
          serviceRecordsForEquipmentProvider(
            id,
          ).overrideWith((ref) async => records),
          equipmentRollupClockProvider.overrideWith((ref) async => {}),
          serviceKindsProvider.overrideWith(
            (ref) async => [
              ServiceKind(
                id: 'o2-clean',
                name: 'O2 clean',
                createdAt: now,
                updatedAt: now,
              ),
            ],
          ),
          ...extraOverrides,
        ].cast(),
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: PassportPage(equipmentId: id),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return AppLocalizations.of(tester.element(find.byType(PassportPage)));
  }

  testWidgets('shows the spec and derived figures', (tester) async {
    final l10n = await pump(tester);
    expect(find.text('Faber 12'), findsWidgets);
    expect(find.text(l10n.passport_spec_title), findsOneWidget);
    expect(find.text('12 L'), findsOneWidget);
    expect(find.text('232 bar'), findsOneWidget);
    expect(find.text(l10n.passport_spec_buoyancyEmpty), findsOneWidget);
    expect(find.text(l10n.passport_spec_buoyancyFull), findsOneWidget);
    expect(
      find.textContaining(l10n.passport_spec_freeGas('232 bar')),
      findsOneWidget,
    );
  });

  testWidgets('with no fill shows the empty state and the log button', (
    tester,
  ) async {
    final l10n = await pump(tester);
    expect(find.text(l10n.passport_fill_none), findsOneWidget);
    expect(find.text(l10n.passport_fill_log), findsOneWidget);
    // No hydro was ever recorded, so there is nothing to count from.
    expect(find.text(l10n.passport_history_sinceHydro(0)), findsNothing);
  });

  testWidgets('shows the current fill with MOD at both limits', (tester) async {
    final l10n = await pump(tester, fills: [fill(32)]);
    expect(find.text('EAN32'), findsWidgets);
    expect(
      find.text(l10n.passport_fill_station('Blue Water Fills')),
      findsOneWidget,
    );
    expect(find.text(l10n.passport_fill_unsigned), findsWidgets);
    // The gas temperature at the analysis is shown in the diver's units.
    expect(find.textContaining('21.5°C'), findsOneWidget);
    // EAN32: 33.75 m at 1.4, 40.0 m at 1.6.
    expect(find.text(l10n.passport_fill_mod('33.8m', '1.4')), findsOneWidget);
    expect(find.text(l10n.passport_fill_mod('40.0m', '1.6')), findsOneWidget);
  });

  testWidgets('warns when a rich fill meets an untracked O2 clean clock', (
    tester,
  ) async {
    final l10n = await pump(
      tester,
      fills: [fill(50)],
      clocks: [clock('hydro', ServiceClockSeverity.ok)],
    );
    expect(find.text(l10n.passport_o2Warning_untracked('50%')), findsOneWidget);
    expect(find.text(l10n.passport_service_trackO2Clean), findsOneWidget);
  });

  testWidgets('an untracked O2 clean row shows the kind name', (tester) async {
    final l10n = await pump(tester);
    expect(find.text('O2 clean'), findsOneWidget);
    expect(find.text('o2-clean'), findsNothing);
    expect(find.text(l10n.passport_service_notTracked), findsOneWidget);
  });

  testWidgets('no warning when the O2 clean clock is current', (tester) async {
    final l10n = await pump(
      tester,
      fills: [fill(50)],
      clocks: [clock('o2-clean', ServiceClockSeverity.ok)],
      records: [record('o2-clean', DateTime(2026, 3, 1))],
    );
    expect(find.text(l10n.passport_o2Warning_untracked('50%')), findsNothing);
    expect(find.text(l10n.passport_service_trackO2Clean), findsNothing);
  });

  testWidgets('lists service clocks with their last date', (tester) async {
    final l10n = await pump(
      tester,
      clocks: [clock('hydro', ServiceClockSeverity.overdue)],
      records: [record('hydro', DateTime(2021, 1, 1))],
    );
    expect(find.text('hydro'), findsWidgets);
    expect(
      find.textContaining(l10n.passport_service_lastDone('')),
      findsWidgets,
    );
  });

  testWidgets('a clock with nothing recorded says so instead of a date', (
    tester,
  ) async {
    final l10n = await pump(
      tester,
      clocks: [clock('hydro', ServiceClockSeverity.ok)],
    );
    expect(find.text(l10n.passport_service_neverRecorded), findsOneWidget);
    expect(
      find.textContaining(l10n.passport_service_lastDone('')),
      findsNothing,
    );
  });

  testWidgets('an O2 clean clock with no cleaning on record still warns', (
    tester,
  ) async {
    final l10n = await pump(
      tester,
      fills: [fill(50)],
      clocks: [clock('o2-clean', ServiceClockSeverity.ok)],
    );
    expect(find.text(l10n.passport_o2Warning_untracked('50%')), findsOneWidget);
  });

  testWidgets('fills are counted from the recorded hydro', (tester) async {
    final l10n = await pump(
      tester,
      fills: [fill(32)],
      clocks: [clock('hydro', ServiceClockSeverity.ok)],
      records: [record('hydro', DateTime(2026, 1, 1))],
    );
    expect(find.text(l10n.passport_history_sinceHydro(1)), findsOneWidget);
  });

  testWidgets('the O2 warning quotes the analysis, not a rounded figure', (
    tester,
  ) async {
    final l10n = await pump(tester, fills: [fill(40.4)]);
    expect(
      find.text(l10n.passport_o2Warning_untracked('40.4%')),
      findsOneWidget,
    );
  });

  testWidgets('ppO2 limits use the locale decimal separator', (tester) async {
    Intl.defaultLocale = 'de_DE';
    await pump(tester, fills: [fill(32)]);
    expect(find.textContaining('ppO2 1,4'), findsOneWidget);
    expect(find.textContaining('ppO2 1,6'), findsOneWidget);
  });

  testWidgets('a failed label print says so', (tester) async {
    final l10n = await pump(
      tester,
      extraOverrides: [
        equipmentRepositoryProvider.overrideWithValue(
          _BrokenEquipmentRepository(),
        ),
      ],
    );
    await tester.ensureVisible(find.text(l10n.passport_tag_printLabel));
    await tester.tap(find.text(l10n.passport_tag_printLabel));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text(l10n.passport_tag_printFailed), findsOneWidget);
  });

  test('route extras that are not a tag are ignored, not cast', () {
    const tag = CylinderPassportPayload(passportId: pid);
    expect(scannedTagFrom(tag), tag);
    expect(scannedTagFrom(null), isNull);
    expect(scannedTagFrom('https://submersion.app/c#p=x'), isNull);
    expect(scannedTagFrom(42), isNull);
  });

  testWidgets('the current fill shows the analysed O2 and He', (tester) async {
    final l10n = await pump(tester, fills: [fill(32)]);
    expect(find.text(l10n.passport_fill_analysis('32%', '0%')), findsOneWidget);
  });

  testWidgets('the header names the cylinder material', (tester) async {
    await pump(tester);
    expect(find.widgetWithText(Chip, 'Steel'), findsOneWidget);
  });

  testWidgets('every value follows imperial units', (tester) async {
    await pump(
      tester,
      fills: [
        CylinderFill(
          id: 'f1',
          passportId: pid,
          equipmentId: id,
          filledAt: DateTime(2026, 9, 20),
          o2Percent: 32,
          pressureBar: 220,
          temperatureC: 20,
          createdAt: now,
          updatedAt: now,
        ),
      ],
      settings: const AppSettings(
        depthUnit: DepthUnit.feet,
        pressureUnit: PressureUnit.psi,
        volumeUnit: VolumeUnit.cubicFeet,
        weightUnit: WeightUnit.pounds,
        temperatureUnit: TemperatureUnit.fahrenheit,
      ),
    );
    final texts = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data ?? '')
        .join('\n');
    // Working and fill pressure, buoyancy, MOD, gas temperature, free gas.
    expect(texts, contains('psi'));
    expect(texts, contains('lbs'));
    expect(texts, contains('ft'));
    expect(texts, contains('°F'));
    expect(texts, contains('cuft'));
    // Nothing leaks through in metric.
    expect(texts, isNot(contains(' bar')));
    expect(texts, isNot(contains(' kg')));
    expect(texts, isNot(contains('°C')));
    expect(RegExp(r'\d m\b|\dm\b').hasMatch(texts), isFalse);
  });

  testWidgets('a failure to track O2 cleaning says so', (tester) async {
    final l10n = await pump(
      tester,
      extraOverrides: [
        serviceScheduleRepositoryProvider.overrideWithValue(
          _BrokenScheduleRepository(),
        ),
      ],
    );
    final track = find.text(l10n.passport_service_trackO2Clean);
    await tester.ensureVisible(track);
    await tester.tap(track);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text(l10n.passport_service_trackFailed), findsOneWidget);
  });
}

class _BrokenEquipmentRepository extends EquipmentRepository {
  @override
  Future<List<EquipmentItem>> getEquipmentByIds(List<String> ids) async =>
      throw StateError('database is locked');
}

class _BrokenScheduleRepository extends ServiceScheduleRepository {
  @override
  Future<List<ServiceSchedule>> getSchedulesForEquipment(
    String equipmentId,
  ) async => throw StateError('database is locked');
}
