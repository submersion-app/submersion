import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart' show Intl;
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/reef/domain/entities/reef_data_status.dart';
import 'package:submersion/features/reef/domain/entities/reef_habitat.dart';
import 'package:submersion/features/reef/domain/entities/reef_health.dart';
import 'package:submersion/features/reef/domain/services/bleaching_alert_level.dart';
import 'package:submersion/features/reef/presentation/widgets/water_conditions_card.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/l10n_test_helpers.dart';

ReefHealth _health({double? anomaly}) => ReefHealth(
  sst: 30.1,
  sstAnomaly: anomaly,
  degreeHeatingWeeks: 15.64,
  hotspot: 0.91,
  alertLevel: BleachingAlertLevel.watch,
  observedAt: DateTime.utc(2023, 9, 1, 12),
);

Widget _harness({
  required ReefPart<ReefHealth> health,
  ReefPart<ReefHabitat>? habitat,
  WaterType? waterType,
  TemperatureUnit unit = TemperatureUnit.celsius,
}) {
  return ProviderScope(
    overrides: [temperatureUnitProvider.overrideWithValue(unit)],
    child: localizedMaterialApp(
      locale: const Locale('en'),
      home: Scaffold(
        body: WaterConditionsCard(
          health: health,
          habitat: habitat,
          waterType: waterType,
        ),
      ),
    ),
  );
}

void main() {
  String? previousDefaultLocale;

  setUp(() {
    previousDefaultLocale = Intl.defaultLocale;
    Intl.defaultLocale = 'en_US';
  });

  tearDown(() {
    Intl.defaultLocale = previousDefaultLocale;
  });

  group('bleaching gate', () {
    testWidgets('shows stress lines when habitat confirms a reef', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(
          health: ReefPart.ok(_health()),
          habitat: const ReefPart.ok(ReefHabitat(onReef: true)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Bleaching watch'), findsOneWidget);
      expect(find.textContaining('15.6'), findsOneWidget);
    });

    testWidgets('hides stress lines when habitat rules a reef out', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(
          health: ReefPart.ok(_health()),
          habitat: const ReefPart.empty(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Bleaching'), findsNothing);
      expect(find.textContaining('Degree Heating'), findsNothing);
      expect(find.textContaining('30.1'), findsOneWidget);
    });

    testWidgets('shows stress lines when habitat is unavailable', (
      tester,
    ) async {
      // An offline habitat provider must never hide an active alert.
      await tester.pumpWidget(
        _harness(
          health: ReefPart.ok(_health()),
          habitat: const ReefPart.unavailable(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Bleaching watch'), findsOneWidget);
    });

    testWidgets('shows stress lines when habitat is unknown (null)', (
      tester,
    ) async {
      await tester.pumpWidget(_harness(health: ReefPart.ok(_health())));
      await tester.pumpAndSettle();

      expect(find.textContaining('Bleaching watch'), findsOneWidget);
    });
  });

  group('anomaly line', () {
    testWidgets('renders signed anomaly in celsius', (tester) async {
      await tester.pumpWidget(
        _harness(
          health: ReefPart.ok(_health(anomaly: 0.42)),
          habitat: const ReefPart.empty(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('+0.4C'), findsOneWidget);
    });

    testWidgets('converts anomaly as a delta, not an absolute', (tester) async {
      await tester.pumpWidget(
        _harness(
          health: ReefPart.ok(_health(anomaly: 0.5)),
          habitat: const ReefPart.empty(),
          unit: TemperatureUnit.fahrenheit,
        ),
      );
      await tester.pumpAndSettle();

      // 0.5 C delta is +0.9 F. An absolute conversion would say +32.9 F.
      expect(find.textContaining('+0.9F'), findsOneWidget);
      expect(find.textContaining('32.9'), findsNothing);
    });

    testWidgets('renders negative anomaly with its own sign', (tester) async {
      await tester.pumpWidget(
        _harness(
          health: ReefPart.ok(_health(anomaly: -1.0)),
          habitat: const ReefPart.empty(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('-1.0C'), findsOneWidget);
    });
  });

  group('alert level labels', () {
    const expectedLabels = {
      BleachingAlertLevel.noStress: 'No thermal stress',
      BleachingAlertLevel.watch: 'Bleaching watch',
      BleachingAlertLevel.warning: 'Bleaching warning',
      BleachingAlertLevel.alertLevel1: 'Bleaching alert level 1',
      BleachingAlertLevel.alertLevel2: 'Bleaching alert level 2',
      BleachingAlertLevel.alertLevel3: 'Bleaching alert level 3',
      BleachingAlertLevel.alertLevel4: 'Bleaching alert level 4',
      BleachingAlertLevel.alertLevel5: 'Bleaching alert level 5',
    };

    for (final entry in expectedLabels.entries) {
      testWidgets('renders ${entry.key.name} as "${entry.value}"', (
        tester,
      ) async {
        await tester.pumpWidget(
          _harness(
            health: ReefPart.ok(
              ReefHealth(
                sst: 28.0,
                degreeHeatingWeeks: 5.0,
                hotspot: 1.2,
                alertLevel: entry.key,
                observedAt: DateTime.utc(2026, 8, 1, 12),
              ),
            ),
            habitat: const ReefPart.ok(ReefHabitat(onReef: true)),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.textContaining(entry.value), findsOneWidget);
      });
    }
  });

  group('non-ok states', () {
    testWidgets('freshwater message wins over fetched data', (tester) async {
      await tester.pumpWidget(
        _harness(
          health: const ReefPart.unavailable(),
          waterType: WaterType.fresh,
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Satellite water temperature covers oceans only'),
        findsOneWidget,
      );
      expect(find.textContaining('Could not check'), findsNothing);
    });

    testWidgets('distinguishes unavailable from empty', (tester) async {
      await tester.pumpWidget(_harness(health: const ReefPart.unavailable()));
      await tester.pumpAndSettle();
      expect(find.textContaining('Could not check'), findsOneWidget);

      await tester.pumpWidget(_harness(health: const ReefPart.empty()));
      await tester.pumpAndSettle();
      expect(find.textContaining('No satellite water data'), findsOneWidget);
    });
  });
}
