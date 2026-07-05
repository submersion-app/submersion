import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/cylinder_sac.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_data_source.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/gas_analysis_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/cylinders_card.dart';
import 'package:submersion/features/dive_log/presentation/widgets/field_attribution_badge.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

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
}) {
  return DiveTank(
    id: id,
    name: name,
    volume: volume,
    startPressure: startPressure,
    endPressure: endPressure,
    gasMix: gasMix,
    computerId: computerId,
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
  UnitFormatter units = _units,
  AppSettings settings = _settings,
  SacUnit sacUnit = SacUnit.pressurePerMin,
}) {
  return testApp(
    overrides: [
      cylinderSacProvider.overrideWith((ref, id) async => cylinderSacs),
      tankPressuresProvider.overrideWith(
        (ref, id) async => <String, List<TankPressurePoint>>{},
      ),
      diveDataSourcesProvider.overrideWith((ref, id) async => dataSources),
    ],
    child: SingleChildScrollView(
      child: CylindersCard(
        dive: dive,
        units: units,
        settings: settings,
        sacUnit: sacUnit,
      ),
    ),
  );
}

void main() {
  group('CylindersCard', () {
    testWidgets('renders title, tank identity, pressures, and MOD/MND', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildCard(dive: _makeDive([_makeTank()]), cylinderSacs: [_makeSac()]),
      );
      await tester.pumpAndSettle();

      expect(find.text('Cylinders'), findsOneWidget);
      expect(find.textContaining('Tank 1 (EAN32)'), findsOneWidget);
      expect(
        find.textContaining('200 bar → 50 bar (150 bar used)'),
        findsOneWidget,
      );
      expect(find.textContaining('MOD:'), findsOneWidget);
      expect(find.textContaining('MND:'), findsOneWidget);
    });

    testWidgets('shows SAC and gas used on a single-tank dive', (tester) async {
      await tester.pumpWidget(
        _buildCard(dive: _makeDive([_makeTank()]), cylinderSacs: [_makeSac()]),
      );
      await tester.pumpAndSettle();

      // sacRate 2.0 bar/min, pressurePerMin mode, metric.
      expect(find.text('2.0 bar/min'), findsOneWidget);
      // gasUsedLiters = (200 - 50) * 11.1 = 1665 L.
      expect(find.text('1665 L used'), findsOneWidget);
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

      expect(find.textContaining('Tank 1'), findsOneWidget);
      expect(find.textContaining('/min'), findsNothing);
      expect(find.textContaining('used'), findsNothing);
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

      expect(find.text('2.0 bar/min'), findsOneWidget);
      expect(find.text('1.2 bar/min'), findsOneWidget);
      expect(find.textContaining('Deco O2'), findsOneWidget);
    });

    testWidgets('formats SAC as L/min when unit is litersPerMin', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildCard(
          dive: _makeDive([_makeTank()]),
          cylinderSacs: [_makeSac()],
          sacUnit: SacUnit.litersPerMin,
        ),
      );
      await tester.pumpAndSettle();

      // sacVolume = 2.0 * 11.1 / 1.01325 = 21.909... -> '21.9 L/min'.
      expect(find.text('21.9 L/min'), findsOneWidget);
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

      // 2.0 bar/min * 14.5038 = 29.0076 -> '29.0 psi/min'.
      expect(find.text('29.0 psi/min'), findsOneWidget);
      // Pressure line rendered in psi.
      expect(find.textContaining('psi →'), findsOneWidget);
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
}
