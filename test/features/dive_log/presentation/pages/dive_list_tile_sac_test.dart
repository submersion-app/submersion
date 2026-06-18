import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/dive_field.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/list_view_mode.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_list_page.dart';
import 'package:submersion/features/dive_log/presentation/providers/view_config_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/test_app.dart';

class _TestSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _TestSettingsNotifier(super.initial);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _TestCardConfigNotifier extends CardViewConfigNotifier {
  _TestCardConfigNotifier(CardViewConfig config)
    : super.withMode(ListViewMode.detailed) {
    state = config;
  }
}

void main() {
  // One back-gas tank chosen for clean SAC values:
  // minutes = 50, avgPressureAtm = 10/10 + 1 = 2.0
  // sac         = (10L * 100bar) / 50 / 2.0 = 10.0 L/min
  // sacPressure = 100bar / 50 / 2.0         = 1.0 bar/min
  Dive sacDive() => Dive(
    id: 'lt-sac',
    diveNumber: 7,
    dateTime: DateTime(2024, 6, 1),
    runtime: const Duration(minutes: 50),
    avgDepth: 10.0,
    tanks: const [
      DiveTank(
        id: 't',
        volume: 10.0,
        startPressure: 200.0,
        endPressure: 100.0,
        role: TankRole.backGas,
      ),
    ],
  );

  Widget buildTile(AppSettings settings) {
    final config = CardViewConfig.defaultDetailed().copyWith(
      extraFields: [DiveField.sacRate],
    );
    return testApp(
      overrides: [
        settingsProvider.overrideWith((ref) => _TestSettingsNotifier(settings)),
        detailedCardConfigProvider.overrideWith(
          (ref) => _TestCardConfigNotifier(config),
        ),
      ],
      child: DiveListTile(
        diveId: 'lt-sac',
        diveNumber: 7,
        dateTime: DateTime(2024, 6, 1),
        fullDive: sacDive(),
      ),
    );
  }

  group('DiveListTile SAC extra field', () {
    testWidgets('honors pressure preference (bar/min)', (tester) async {
      await tester.pumpWidget(
        buildTile(
          const AppSettings(
            sacUnit: SacUnit.pressurePerMin,
            pressureUnit: PressureUnit.bar,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('1.0 bar/min'), findsOneWidget);
    });

    testWidgets('honors volume preference (L/min)', (tester) async {
      await tester.pumpWidget(
        buildTile(
          const AppSettings(
            sacUnit: SacUnit.litersPerMin,
            volumeUnit: VolumeUnit.liters,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('10.0 L/min'), findsOneWidget);
    });
  });
}
