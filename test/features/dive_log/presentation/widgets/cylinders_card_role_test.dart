import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/gas_consumption_display.dart';
import 'package:submersion/core/icons/submersion_icons.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/cylinder_sac.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_data_source.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/gas_analysis_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/cylinders_card.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/transmitters/domain/entities/transmitter.dart';
import 'package:submersion/features/transmitters/presentation/providers/transmitter_providers.dart';

import '../../../../helpers/test_app.dart';

/// The Tanks card names each cylinder's role and draws the glyph for how it
/// is carried (issue #2901).
const _settings = AppSettings();

DiveTank _tank(String id, TankRole role) => DiveTank(
  id: id,
  volume: 10,
  startPressure: 200,
  endPressure: 50,
  gasMix: const GasMix(o2: 21),
  role: role,
);

Widget _card(List<DiveTank> tanks, {Locale locale = const Locale('en')}) {
  return testApp(
    locale: locale,
    overrides: [
      cylinderSacProvider.overrideWith(
        (ref, id) async => const <CylinderSac>[],
      ),
      tankPressuresProvider.overrideWith(
        (ref, id) async => const <String, List<TankPressurePoint>>{},
      ),
      diveDataSourcesProvider.overrideWith(
        (ref, id) async => const <DiveDataSource>[],
      ),
      transmittersProvider.overrideWith((ref) async => const <Transmitter>[]),
    ],
    child: SingleChildScrollView(
      child: CylindersCard(
        dive: Dive(
          id: 'dive-1',
          diveNumber: 1,
          dateTime: DateTime(2026, 6, 1, 10),
          maxDepth: 30,
          bottomTime: const Duration(minutes: 45),
          tanks: tanks,
        ),
        units: const UnitFormatter(_settings),
        settings: _settings,
        display: GasConsumptionDisplay.sac,
      ),
    ),
  );
}

void main() {
  group('CylindersCard tank roles', () {
    testWidgets('a sidemount pair shows each side by icon and label', (
      tester,
    ) async {
      await tester.pumpWidget(
        _card([
          _tank('l', TankRole.sidemountLeft),
          _tank('r', TankRole.sidemountRight),
        ]),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(SubmersionIcons.tankSidemountLeft), findsOneWidget);
      expect(find.byIcon(SubmersionIcons.tankSidemountRight), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('tank-role-l')),
          matching: find.text('Sidemount Left'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('tank-role-r')),
          matching: find.text('Sidemount Right'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('a lone back gas tank keeps its icon but drops the label', (
      tester,
    ) async {
      await tester.pumpWidget(_card([_tank('b', TankRole.backGas)]));
      await tester.pumpAndSettle();

      expect(find.byIcon(SubmersionIcons.tankBackGas), findsOneWidget);
      expect(find.byKey(const Key('tank-role-b')), findsNothing);
      expect(find.text('Back Gas'), findsNothing);
    });

    testWidgets('back gas is labelled once a second tank joins it', (
      tester,
    ) async {
      await tester.pumpWidget(
        _card([_tank('b', TankRole.backGas), _tank('s', TankRole.stage)]),
      );
      await tester.pumpAndSettle();

      expect(find.text('Back Gas'), findsOneWidget);
      expect(find.text('Stage'), findsOneWidget);
      expect(find.byIcon(SubmersionIcons.tankBackGas), findsOneWidget);
      expect(find.byIcon(SubmersionIcons.tankSlung), findsOneWidget);
    });

    testWidgets('a lone tank in any other role is labelled', (tester) async {
      await tester.pumpWidget(_card([_tank('s', TankRole.stage)]));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('tank-role-s')), findsOneWidget);
      expect(find.text('Stage'), findsOneWidget);
    });

    testWidgets('the label follows the app language', (tester) async {
      await tester.pumpWidget(
        _card([
          _tank('l', TankRole.sidemountLeft),
          _tank('r', TankRole.sidemountRight),
        ], locale: const Locale('de')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Sidemount Left'), findsNothing);
      expect(
        find.descendant(
          of: find.byKey(const Key('tank-role-l')),
          matching: find.text('Sidemount Links'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('role and volume chips wrap on a narrow card', (tester) async {
      tester.view.physicalSize = const Size(260, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _card([
          _tank('l', TankRole.sidemountLeft),
          _tank('r', TankRole.sidemountRight),
        ], locale: const Locale('de')),
      );
      await tester.pumpAndSettle();

      // A RenderFlex overflow would fail the test through FlutterError.
      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('tank-role-r')), findsOneWidget);
    });
  });
}
