import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/gas_consumption_display.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/icons/submersion_icons.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/cylinder_sac.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_data_source.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/gas_analysis_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/cylinders_card.dart';
import 'package:submersion/features/dive_log/presentation/widgets/field_attribution_badge.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_observation_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/widgets/observation_status_chip.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/transmitters/domain/entities/transmitter.dart';
import 'package:submersion/features/transmitters/presentation/providers/transmitter_providers.dart';
import 'package:submersion/features/trips/presentation/providers/trip_cylinder_providers.dart';

import '../../../../helpers/test_app.dart';

const _settings = AppSettings();
const _units = UnitFormatter(_settings);

DiveTank _makeTank({
  String id = 'tank-1',
  String? name,
  double? volume = 11.1,
  double? startPressure = 200,
  double? endPressure = 50,
  GasMix gasMix = const GasMix(o2: 32),
  String? computerId,
  String? transmitterSerial,
  String? equipmentId,
  TankRole role = TankRole.backGas,
  TankRoleSource? roleSource,
}) {
  return DiveTank(
    id: id,
    name: name,
    volume: volume,
    startPressure: startPressure,
    endPressure: endPressure,
    gasMix: gasMix,
    computerId: computerId,
    transmitterSerial: transmitterSerial,
    equipmentId: equipmentId,
    role: role,
    roleSource: roleSource,
  );
}

Dive _makeDive(List<DiveTank> tanks) {
  return Dive(
    id: 'dive-1',
    diveNumber: 1,
    dateTime: DateTime(2026, 6, 1, 10, 0),
    maxDepth: 30.0,
    avgDepth: 18.0,
    bottomTime: const Duration(minutes: 45),
    tanks: tanks,
  );
}

CylinderSac _makeSac({
  String tankId = 'tank-1',
  double? sacRate = 2.0,
  double? tankVolume = 11.1,
  double? startPressure = 200,
  double? endPressure = 50,
}) {
  return CylinderSac(
    tankId: tankId,
    gasMix: const GasMix(o2: 32),
    role: TankRole.backGas,
    tankVolume: tankVolume,
    sacRate: sacRate,
    startPressure: startPressure,
    endPressure: endPressure,
  );
}

DiveDataSource _makeSource({
  required String id,
  String? computerId,
  bool isPrimary = false,
  String? computerModel,
}) {
  final now = DateTime(2026, 6, 1, 10, 0);
  return DiveDataSource(
    id: id,
    diveId: 'dive-1',
    computerId: computerId,
    isPrimary: isPrimary,
    computerModel: computerModel,
    entryTime: now,
    exitTime: now.add(const Duration(minutes: 45)),
    importedAt: now,
    createdAt: now,
  );
}

Widget _buildCard({
  required Dive dive,
  List<CylinderSac> cylinderSacs = const [],
  List<DiveDataSource> dataSources = const [],
  Map<String, List<TankPressurePoint>> tankPressures = const {},
  UnitFormatter units = _units,
  AppSettings settings = _settings,
  GasConsumptionDisplay display = GasConsumptionDisplay.sac,
  VisualDensity? visualDensity,
  List<Transmitter> registry = const [],
  List<dynamic> extraOverrides = const [],
  Locale? locale,
}) {
  final card = CylindersCard(
    dive: dive,
    units: units,
    settings: settings,
    display: display,
  );
  final body = SingleChildScrollView(
    child: visualDensity == null
        ? card
        : Theme(
            data: ThemeData(visualDensity: visualDensity),
            child: card,
          ),
  );
  // A router host: the Assign chip pushes the transmitter editor.
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => Scaffold(body: body),
      ),
      GoRoute(
        path: '/transmitters/new',
        builder: (context, state) => const Scaffold(body: Text('NEW_PAGE')),
      ),
    ],
  );
  return testAppRouter(
    router: router,
    locale: locale,
    overrides: [
      cylinderSacProvider.overrideWith((ref, id) async => cylinderSacs),
      tankPressuresProvider.overrideWith((ref, id) async => tankPressures),
      diveDataSourcesProvider.overrideWith((ref, id) async => dataSources),
      transmittersProvider.overrideWith((ref) async => registry),
      ...extraOverrides,
    ],
  );
}

void main() {
  group('CylindersCard', () {
    testWidgets('renders a table row: size, gas, pressures, then details', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildCard(dive: _makeDive([_makeTank()]), cylinderSacs: [_makeSac()]),
      );
      await tester.pumpAndSettle();

      expect(find.text('Cylinders'), findsOneWidget);
      for (final header in ['Tank', 'Gas', 'Start', 'End', 'Used']) {
        expect(find.text(header), findsOneWidget);
      }
      // The unit sits once under each pressure header; the cells are bare.
      expect(find.text('bar'), findsNWidgets(3));
      // An unnamed tank without a preset leads with its volume.
      expect(find.text('11.1 L'), findsOneWidget);
      expect(find.text('EAN32'), findsOneWidget);
      expect(find.text('200'), findsOneWidget);
      expect(find.text('50'), findsOneWidget);
      expect(find.text('150'), findsOneWidget);
      expect(find.text('MOD 33m'), findsOneWidget);
      expect(find.textContaining('MND '), findsOneWidget);
    });

    testWidgets('the working ppO2 behind MOD is said once, under the table', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildCard(
          dive: _makeDive([
            _makeTank(),
            _makeTank(id: 'tank-2', gasMix: const GasMix(o2: 50)),
          ]),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('MOD at ppO₂ 1.4'), findsOneWidget);
      expect(find.textContaining('(ppO₂'), findsNothing);
    });

    testWidgets('MOD and its note follow the working ppO2 setting', (
      tester,
    ) async {
      // EAN32 at ppO2 1.4 is 33.75 m; at 1.6 it is 40 m. The label used to
      // say "ppO₂ 1.4" no matter the setting.
      const settings = AppSettings(ppO2MaxWorking: 1.6);
      await tester.pumpWidget(
        _buildCard(
          dive: _makeDive([_makeTank()]),
          cylinderSacs: [_makeSac()],
          settings: settings,
          units: const UnitFormatter(settings),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('MOD 40m'), findsOneWidget);
      expect(find.text('MOD at ppO₂ 1.6'), findsOneWidget);
      expect(find.textContaining('ppO₂ 1.4'), findsNothing);
    });

    testWidgets('MOD is rounded down, never up (issue #2342)', (tester) async {
      // EAN32 at ppO2 1.4 is 33.75 m. Rounded to nearest it showed as 34 m,
      // deeper than the gas may be taken.
      await tester.pumpWidget(
        _buildCard(dive: _makeDive([_makeTank()]), cylinderSacs: [_makeSac()]),
      );
      await tester.pumpAndSettle();

      expect(find.text('MOD 33m'), findsOneWidget);
      expect(find.text('MOD 34m'), findsNothing);
    });

    testWidgets('shows the SAC rate and the gas used on a single-tank dive', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildCard(dive: _makeDive([_makeTank()]), cylinderSacs: [_makeSac()]),
      );
      await tester.pumpAndSettle();

      // sacRate 2.0 bar/min, SAC lane, metric.
      expect(find.text('SAC 2.0 bar/min'), findsOneWidget);
      // gasUsedLiters = (200 - 50) * 11.1 = 1665 L, the volume behind the
      // Used column's pressure drop.
      expect(find.text('Gas used 1665 L'), findsOneWidget);
    });

    testWidgets('a named tank keeps its size and role under the name', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildCard(
          dive: _makeDive([
            _makeTank(),
            const DiveTank(
              id: 'tank-2',
              name: 'Left stage',
              presetName: 'al40',
              volume: 5.7,
              gasMix: GasMix(o2: 50),
              role: TankRole.deco,
            ),
          ]),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Left stage'), findsOneWidget);
      expect(find.text('AL40'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('tank-role-tank-2')),
          matching: find.text('Deco'),
        ),
        findsOneWidget,
      );
      // Above the size and role, not beside them.
      expect(
        tester.getTopLeft(find.text('AL40')).dy,
        greaterThan(tester.getBottomLeft(find.text('Left stage')).dy - 1),
      );
    });

    testWidgets('a tank with neither a name nor a size is numbered', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildCard(dive: _makeDive([_makeTank(volume: null)])),
      );
      await tester.pumpAndSettle();

      expect(find.text('Tank 1'), findsOneWidget);
    });

    testWidgets('pressure columns line up from tank to tank', (tester) async {
      await tester.pumpWidget(
        _buildCard(
          dive: _makeDive([
            _makeTank(),
            _makeTank(
              id: 'tank-2',
              name: 'A much longer stage bottle name',
              startPressure: 210,
              endPressure: 120,
              gasMix: const GasMix(o2: 21, he: 35),
            ),
          ]),
        ),
      );
      await tester.pumpAndSettle();

      final used1 = tester.getTopRight(find.text('150'));
      final used2 = tester.getTopRight(find.text('90'));
      expect(used1.dx, moreOrLessEquals(used2.dx, epsilon: 0.5));
      final start1 = tester.getTopRight(find.text('200'));
      final start2 = tester.getTopRight(find.text('210'));
      expect(start1.dx, moreOrLessEquals(start2.dx, epsilon: 0.5));
      final gas1 = tester.getTopLeft(find.text('EAN32'));
      final gas2 = tester.getTopLeft(find.text('Tx 21/35'));
      expect(gas1.dx, moreOrLessEquals(gas2.dx, epsilon: 0.5));
    });

    testWidgets('a missing pressure shows a placeholder in every column', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildCard(
          dive: _makeDive([_makeTank(startPressure: null, endPressure: null)]),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('--'), findsNWidgets(3));
    });

    testWidgets('a tank carried but not breathed used 0, not unknown', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildCard(
          dive: _makeDive([_makeTank(startPressure: 200, endPressure: 200)]),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('0'), findsOneWidget);
      expect(find.text('--'), findsNothing);
    });

    testWidgets('each pressure cell reads out its column and unit', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(_buildCard(dive: _makeDive([_makeTank()])));
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('Start 200 bar'), findsOneWidget);
      expect(find.bySemanticsLabel('End 50 bar'), findsOneWidget);
      expect(find.bySemanticsLabel('Used 150 bar'), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('the tank and gas cells read out their column', (tester) async {
      // The visual header is hidden from screen readers, so each cell must
      // say which column it is in.
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(_buildCard(dive: _makeDive([_makeTank()])));
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('Gas EAN32'), findsOneWidget);
      expect(
        find.bySemanticsLabel(RegExp(r'^Tank\s+11\.1 L$')),
        findsOneWidget,
      );
      semantics.dispose();
    });

    testWidgets('the dots between detail items are not read out', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        _buildCard(dive: _makeDive([_makeTank()]), cylinderSacs: [_makeSac()]),
      );
      await tester.pumpAndSettle();

      // The dots are drawn between the items...
      expect(find.text(' · '), findsWidgets);
      // ...but no semantics node carries one.
      expect(find.bySemanticsLabel(RegExp('·')), findsNothing);
      // The items themselves are still read.
      expect(find.bySemanticsLabel(RegExp('Gas used 1665 L')), findsWidgets);
      semantics.dispose();
    });

    testWidgets('a missing pressure is read out without a unit', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        _buildCard(
          dive: _makeDive([_makeTank(startPressure: null, endPressure: null)]),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('Start --'), findsOneWidget);
      expect(find.bySemanticsLabel('Used --'), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp(r'-- bar')), findsNothing);
      semantics.dispose();
    });

    testWidgets('a linked cylinder whose item does not resolve keeps its SAC '
        'block', (tester) async {
      // Only the check-in chip depends on the linked item; while it loads,
      // or for a link to an item this device no longer has, the SAC block
      // must still show.
      await tester.pumpWidget(
        _buildCard(
          dive: _makeDive([_makeTank(equipmentId: 'gone')]),
          cylinderSacs: [_makeSac()],
          extraOverrides: [
            equipmentItemProvider('gone').overrideWith((ref) async => null),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('SAC 2.0 bar/min'), findsOneWidget);
    });

    testWidgets('omits the SAC block when SAC is not computable', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildCard(
          dive: _makeDive([_makeTank(startPressure: null, endPressure: null)]),
          cylinderSacs: [
            _makeSac(sacRate: null, startPressure: null, endPressure: null),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('11.1 L'), findsOneWidget);
      expect(find.textContaining('/min'), findsNothing);
      expect(find.textContaining('Gas used'), findsNothing);
    });

    testWidgets('shows one row with distinct SAC per tank on multi-tank dive', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildCard(
          dive: _makeDive([
            _makeTank(),
            _makeTank(
              id: 'tank-2',
              name: 'Deco O2',
              volume: 5.7,
              startPressure: 200,
              endPressure: 140,
              gasMix: const GasMix(o2: 100),
            ),
          ]),
          cylinderSacs: [
            _makeSac(),
            _makeSac(
              tankId: 'tank-2',
              sacRate: 1.2,
              tankVolume: 5.7,
              startPressure: 200,
              endPressure: 140,
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('SAC 2.0 bar/min'), findsOneWidget);
      expect(find.text('SAC 1.2 bar/min'), findsOneWidget);
      expect(find.textContaining('Deco O2'), findsOneWidget);
    });

    testWidgets('formats RMV when the display is rmv', (tester) async {
      await tester.pumpWidget(
        _buildCard(
          dive: _makeDive([_makeTank()]),
          cylinderSacs: [_makeSac()],
          display: GasConsumptionDisplay.rmv,
        ),
      );
      await tester.pumpAndSettle();

      // sacVolume = 2.0 * 11.1 = 22.2 -> '22.2 L/min'. The standard-atmosphere
      // divisor is gone now that both sides share a 1 bar reference (#828).
      expect(find.text('RMV 22.2 L/min'), findsOneWidget);
      expect(find.textContaining('bar/min'), findsNothing);
    });

    testWidgets('both shows a SAC line and an RMV line', (tester) async {
      await tester.pumpWidget(
        _buildCard(
          dive: _makeDive([_makeTank()]),
          cylinderSacs: [_makeSac()],
          display: GasConsumptionDisplay.both,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('SAC 2.0 bar/min'), findsOneWidget);
      expect(find.text('RMV 22.2 L/min'), findsOneWidget);
    });

    testWidgets('the tank icon stays level with the name on a row with rates', (
      tester,
    ) async {
      // The rates add a detail line under the row, so the row is tall; the
      // icon must stay beside the name rather than centre on the block.
      await tester.pumpWidget(
        _buildCard(
          dive: _makeDive([_makeTank()]),
          cylinderSacs: [_makeSac()],
          display: GasConsumptionDisplay.both,
        ),
      );
      await tester.pumpAndSettle();

      final iconTop = tester.getTopLeft(
        find.byIcon(SubmersionIcons.tankBackGas),
      );
      final nameTop = tester.getTopLeft(find.text('11.1 L'));
      expect((iconTop.dy - nameTop.dy).abs(), lessThan(8));
    });

    testWidgets('both fits everything at desktop density', (tester) async {
      // Desktop defaults to compact density, which the default widget-test
      // harness never sees. This row carries all of it at once (source
      // badge, both lanes, gas used, check-in button); an overflow anywhere
      // would fail the test through FlutterError.
      final item = EquipmentItem(
        id: 'al80',
        name: 'AL80 #4',
        type: EquipmentType.tank,
        createdAt: DateTime(2026),
      );
      await tester.pumpWidget(
        _buildCard(
          dive: _makeDive([
            _makeTank(computerId: 'comp-1', equipmentId: 'al80'),
          ]),
          cylinderSacs: [_makeSac()],
          dataSources: [
            _makeSource(
              id: 'src-1',
              computerId: 'comp-1',
              isPrimary: true,
              computerModel: 'Perdix 2',
            ),
            _makeSource(id: 'src-2', computerId: 'comp-2'),
          ],
          display: GasConsumptionDisplay.both,
          visualDensity: VisualDensity.compact,
          extraOverrides: [
            equipmentItemProvider('al80').overrideWith((ref) async => item),
            observationsForDiveProvider(
              'dive-1',
            ).overrideWith((ref) async => const []),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Perdix 2'), findsOneWidget);
      expect(find.text('SAC 2.0 bar/min'), findsOneWidget);
      expect(find.text('RMV 22.2 L/min'), findsOneWidget);
      expect(find.text('Gas used 1665 L'), findsOneWidget);
      expect(find.byType(ObservationStatusChip), findsOneWidget);
    });

    group('on a narrow card', () {
      // A phone, or half of a paired row on a wide pane. The test font sets
      // every glyph a full em wide, so this width exaggerates the squeeze;
      // an overflow anywhere fails the test through FlutterError.
      Future<void> pumpNarrow(
        WidgetTester tester, {
        DiveTank? tank,
        Locale? locale,
        List<DiveDataSource> dataSources = const [],
        List<dynamic> extraOverrides = const [],
      }) async {
        await tester.binding.setSurfaceSize(const Size(340, 800));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(
          _buildCard(
            dive: _makeDive([tank ?? _makeTank()]),
            cylinderSacs: [_makeSac()],
            dataSources: dataSources,
            display: GasConsumptionDisplay.both,
            // Pinned, so the English finders do not depend on the host.
            locale: locale ?? const Locale('en'),
            extraOverrides: extraOverrides,
          ),
        );
        await tester.pumpAndSettle();
      }

      testWidgets('every column and both rates fit', (tester) async {
        await pumpNarrow(tester);

        expect(tester.takeException(), isNull);
        expect(find.text('11.1 L'), findsOneWidget);
        expect(find.text('150'), findsOneWidget);
        expect(find.text('SAC 2.0 bar/min'), findsOneWidget);
        expect(find.text('RMV 22.2 L/min'), findsOneWidget);
      });

      testWidgets('the longer German labels fit', (tester) async {
        // "Druckverbrauch" is the #935 shape: a translated lane label far
        // wider than the English "SAC".
        await pumpNarrow(tester, locale: const Locale('de'));

        expect(tester.takeException(), isNull);
        expect(find.text('Verbraucht'), findsOneWidget);
        expect(find.textContaining('Druckverbrauch '), findsOneWidget);
        expect(find.textContaining('AMV '), findsOneWidget);
      });

      testWidgets('a transmitter, source badge and check-in fit together', (
        tester,
      ) async {
        // The old row overflowed by 20px here: the serial and its Assign
        // chip sat in a Row beside the check-in button.
        final item = EquipmentItem(
          id: 'al80',
          name: 'AL80 #4',
          type: EquipmentType.tank,
          createdAt: DateTime(2026),
        );
        await pumpNarrow(
          tester,
          tank: _makeTank(
            equipmentId: 'al80',
            transmitterSerial: '812345',
            computerId: 'comp-1',
          ),
          dataSources: [
            _makeSource(
              id: 'src-1',
              computerId: 'comp-1',
              isPrimary: true,
              computerModel: 'Perdix 2',
            ),
            _makeSource(id: 'src-2', computerId: 'comp-2'),
          ],
          extraOverrides: [
            equipmentItemProvider('al80').overrideWith((ref) async => item),
            observationsForDiveProvider(
              'dive-1',
            ).overrideWith((ref) async => const []),
          ],
        );

        expect(tester.takeException(), isNull);
        expect(find.byType(ObservationStatusChip), findsOneWidget);
        expect(find.text('Perdix 2'), findsOneWidget);
        expect(find.text('Transmitter 812345'), findsOneWidget);
        expect(find.text('Assign transmitter'), findsOneWidget);
      });
    });

    testWidgets('both omits the RMV line for a cylinder without a volume', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildCard(
          dive: _makeDive([_makeTank(volume: null)]),
          cylinderSacs: [_makeSac(tankVolume: null)],
          display: GasConsumptionDisplay.both,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('SAC 2.0 bar/min'), findsOneWidget);
      expect(find.textContaining('RMV'), findsNothing);
    });

    testWidgets('formats pressures and SAC in imperial units', (tester) async {
      const imperialSettings = AppSettings(
        pressureUnit: PressureUnit.psi,
        volumeUnit: VolumeUnit.cubicFeet,
        depthUnit: DepthUnit.feet,
      );
      await tester.pumpWidget(
        _buildCard(
          dive: _makeDive([_makeTank()]),
          cylinderSacs: [_makeSac()],
          units: const UnitFormatter(imperialSettings),
          settings: imperialSettings,
        ),
      );
      await tester.pumpAndSettle();

      // 2.0 bar/min * 14.5038 = 29.0076 -> '29 psi/min' (no decimal for psi).
      expect(find.text('SAC 29 psi/min'), findsOneWidget);
      // The unit under each pressure header follows the setting.
      expect(find.text('psi'), findsNWidgets(3));
      expect(find.text('bar'), findsNothing);
    });

    testWidgets('an unnamed tank leads with its preset name', (tester) async {
      await tester.pumpWidget(
        _buildCard(
          dive: _makeDive([
            const DiveTank(
              id: 'tank-1',
              presetName: 'al80',
              startPressure: 200,
              endPressure: 50,
              gasMix: GasMix(o2: 32),
            ),
          ]),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('AL80'), findsOneWidget);
    });

    testWidgets('falls back to time-series pressures when metadata is null', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildCard(
          dive: _makeDive([_makeTank(startPressure: null, endPressure: null)]),
          tankPressures: const {
            'tank-1': [
              TankPressurePoint(tankId: 'tank-1', timestamp: 0, pressure: 200),
              TankPressurePoint(
                tankId: 'tank-1',
                timestamp: 2700,
                pressure: 60,
              ),
            ],
          },
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('200'), findsOneWidget);
      expect(find.text('60'), findsOneWidget);
      expect(find.text('140'), findsOneWidget);
    });

    testWidgets('hides source badge with a single data source', (tester) async {
      // Riverpod ignores override changes on an in-place ProviderScope
      // rebuild, so the single-source and multi-source cases live in
      // separate tests with fresh scopes.
      await tester.pumpWidget(
        _buildCard(
          dive: _makeDive([_makeTank(computerId: 'comp-1')]),
          cylinderSacs: [_makeSac()],
          dataSources: [
            _makeSource(
              id: 'src-1',
              computerId: 'comp-1',
              isPrimary: true,
              computerModel: 'Perdix 2',
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(FieldAttributionBadge), findsNothing);
    });

    testWidgets('shows source badge with two or more data sources', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildCard(
          dive: _makeDive([_makeTank(computerId: 'comp-1')]),
          cylinderSacs: [_makeSac()],
          dataSources: [
            _makeSource(
              id: 'src-1',
              computerId: 'comp-1',
              isPrimary: true,
              computerModel: 'Perdix 2',
            ),
            _makeSource(
              id: 'src-2',
              computerId: 'comp-2',
              computerModel: 'Teric',
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Perdix 2'), findsOneWidget);
    });
  });

  group('transmitter caption', () {
    Dive diveWithSerial(String? serial) =>
        _makeDive([_makeTank(transmitterSerial: serial)]);

    testWidgets('shows the serial under a downloaded tank', (tester) async {
      await tester.pumpWidget(_buildCard(dive: diveWithSerial('180777')));
      await tester.pumpAndSettle();

      expect(find.text('Transmitter 180777'), findsOneWidget);
      expect(find.text('Assign transmitter'), findsOneWidget);
    });

    testWidgets('no chip once the serial has a registry entry', (tester) async {
      await tester.pumpWidget(
        _buildCard(
          dive: diveWithSerial('180777'),
          registry: [
            Transmitter(
              id: 'e1',
              transmitterSerial: '180777',
              label: 'O2',
              createdAt: DateTime.utc(2026, 9, 1),
              updatedAt: DateTime.utc(2026, 9, 1),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Transmitter 180777'), findsOneWidget);
      expect(find.text('Assign transmitter'), findsNothing);
    });

    testWidgets('a registry serial with padding still counts as known', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildCard(
          dive: diveWithSerial('180777'),
          registry: [
            Transmitter(
              id: 'e1',
              transmitterSerial: ' 180777 ',
              label: 'O2',
              createdAt: DateTime.utc(2026, 9, 1),
              updatedAt: DateTime.utc(2026, 9, 1),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Assign transmitter'), findsNothing);
    });

    testWidgets('no caption without a serial', (tester) async {
      await tester.pumpWidget(_buildCard(dive: diveWithSerial(null)));
      await tester.pumpAndSettle();

      expect(find.textContaining('Transmitter '), findsNothing);
    });

    testWidgets('a role read off the transmitter name says so (#2595)', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildCard(
          dive: _makeDive([
            _makeTank(
              gasMix: const GasMix(o2: 100),
              transmitterSerial: '180777',
              role: TankRole.oxygenSupply,
              roleSource: TankRoleSource.transmitterName,
            ),
          ]),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text("O₂ Supply, read from the transmitter's name"),
        findsOneWidget,
      );
      expect(find.text('Assign transmitter'), findsOneWidget);
    });

    testWidgets('a role with no source shows no such line', (tester) async {
      await tester.pumpWidget(
        _buildCard(
          dive: _makeDive([
            _makeTank(transmitterSerial: '180777', role: TankRole.oxygenSupply),
          ]),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining("transmitter's name"), findsNothing);
    });

    testWidgets('the chip opens the editor with the serial', (tester) async {
      await tester.pumpWidget(_buildCard(dive: diveWithSerial('180777')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Assign transmitter'));
      await tester.pumpAndSettle();

      expect(find.text('NEW_PAGE'), findsOneWidget);
    });
  });

  group('reassign pressure series entry point', () {
    testWidgets('shown when two tanks carry a series', (tester) async {
      await tester.pumpWidget(
        _buildCard(
          dive: _makeDive([_makeTank(id: 'a'), _makeTank(id: 'b')]),
          tankPressures: {
            'a': [
              const TankPressurePoint(tankId: 'a', timestamp: 0, pressure: 200),
            ],
            'b': [
              const TankPressurePoint(tankId: 'b', timestamp: 0, pressure: 210),
            ],
          },
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Reassign pressure series'), findsOneWidget);
    });

    testWidgets('hidden with a single series', (tester) async {
      await tester.pumpWidget(
        _buildCard(
          dive: _makeDive([_makeTank(id: 'a'), _makeTank(id: 'b')]),
          tankPressures: {
            'a': [
              const TankPressurePoint(tankId: 'a', timestamp: 0, pressure: 200),
            ],
          },
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Reassign pressure series'), findsNothing);
    });

    testWidgets('a linked tank names its trip cylinder and bottle', (
      tester,
    ) async {
      final dive = _makeDive([
        _makeTank().copyWith(tripCylinderId: 'a'),
      ]).copyWith(tripId: 't1');
      await tester.pumpWidget(
        _buildCard(
          dive: dive,
          extraOverrides: [
            tripCylinderLabelsAtProvider((
              tripId: 't1',
              atMillis: dive.effectiveEntryTime.millisecondsSinceEpoch,
            )).overrideWith(
              (ref) async => {'a': (label: 'Truck 2', bottle: '14')},
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Truck 2 · Bottle 14'), findsOneWidget);
    });

    testWidgets('an unlinked tank shows no trip cylinder line', (tester) async {
      await tester.pumpWidget(
        _buildCard(dive: _makeDive([_makeTank()]).copyWith(tripId: 't1')),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('tank-trip-cylinder-tank-1')), findsNothing);
      expect(find.textContaining('Bottle'), findsNothing);
    });
  });
}
