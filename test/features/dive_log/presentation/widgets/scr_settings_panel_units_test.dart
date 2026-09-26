import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/widgets/scr_settings_panel.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

/// The SCR panel's two gas-flow rates (CMF injection rate and assumed VO2)
/// follow the diver's volume unit on screen and are stored in L/min (#1935).
void main() {
  late String? previousLocale;

  setUp(() {
    previousLocale = Intl.defaultLocale;
    Intl.defaultLocale = 'en';
  });

  tearDown(() {
    Intl.defaultLocale = previousLocale;
  });

  group('cubic feet', () {
    testWidgets('shows both rates in cuft/min', (tester) async {
      await _pumpPanel(
        tester,
        VolumeUnit.cubicFeet,
        const ScrSettingsPanel(
          scrType: ScrType.cmf,
          injectionRate: 8.0,
          assumedVo2: 1.30,
          onChanged: _ignore,
        ),
      );

      expect(find.text('cuft/min'), findsNWidgets(2));
      expect(find.text('L/min'), findsNothing);
      // 8.0 L/min is 0.2825 cuft/min; 1.30 L/min is 0.0459 cuft/min.
      expect(_textOf(tester, 'Injection Rate'), '0.28');
      expect(_textOf(tester, 'Assumed VO₂'), '0.046');
    });

    testWidgets('stores typed cuft/min rates as L/min', (tester) async {
      final captured = _Captured();
      await _pumpPanel(
        tester,
        VolumeUnit.cubicFeet,
        ScrSettingsPanel(
          scrType: ScrType.cmf,
          injectionRate: 8.0,
          assumedVo2: 1.30,
          onChanged: captured.call,
        ),
      );

      await tester.enterText(_fieldWithLabel('Injection Rate'), '0.3');
      await tester.pump();
      expect(captured.injectionRate, closeTo(0.3 / 0.0353147, 0.0001));

      await tester.enterText(_fieldWithLabel('Assumed VO₂'), '0.05');
      await tester.pump();
      expect(captured.assumedVo2, closeTo(0.05 / 0.0353147, 0.0001));
      // The untouched injection rate is still reported from the typed value.
      expect(captured.injectionRate, closeTo(0.3 / 0.0353147, 0.0001));
    });

    testWidgets('an untouched rate keeps its stored L/min value exactly', (
      tester,
    ) async {
      // Seeding rounds to 0.28 cuft/min, which reads back as 7.93 L/min. A
      // save that never touched the field must not drift the stored rate.
      final captured = _Captured();
      await _pumpPanel(
        tester,
        VolumeUnit.cubicFeet,
        ScrSettingsPanel(
          scrType: ScrType.cmf,
          injectionRate: 8.0,
          assumedVo2: 1.30,
          onChanged: captured.call,
        ),
      );

      await tester.enterText(_fieldWithLabel('Type'), 'Sofnolime');
      await tester.pump();

      expect(captured.injectionRate, 8.0);
      expect(captured.assumedVo2, 1.30);
    });

    testWidgets('hints follow the volume unit', (tester) async {
      await _pumpPanel(
        tester,
        VolumeUnit.cubicFeet,
        const ScrSettingsPanel(scrType: ScrType.cmf, onChanged: _ignore),
      );

      // The VO2 field is seeded with its default, so only the injection
      // rate's hint is visible; clear VO2 to reveal its hint too.
      await tester.enterText(_fieldWithLabel('Assumed VO₂'), '');
      await tester.pump();

      expect(_hintOf(tester, 'Injection Rate'), '0.28');
      expect(_hintOf(tester, 'Assumed VO₂'), '0.046');
    });

    for (final type in [ScrType.pascr, ScrType.escr]) {
      testWidgets('${type.name} shows and stores VO2 in cuft/min', (
        tester,
      ) async {
        final captured = _Captured();
        await _pumpPanel(
          tester,
          VolumeUnit.cubicFeet,
          ScrSettingsPanel(
            scrType: type,
            assumedVo2: 1.30,
            onChanged: captured.call,
          ),
        );

        expect(find.text('cuft/min'), findsOneWidget);
        expect(_textOf(tester, 'Assumed VO₂'), '0.046');
        expect(_hintOf(tester, 'Assumed VO₂'), '0.046');

        await tester.enterText(_fieldWithLabel('Assumed VO₂'), '0.05');
        await tester.pump();
        expect(captured.assumedVo2, closeTo(0.05 / 0.0353147, 0.0001));
      });
    }

    testWidgets('the calculated loop FO2 matches the metric result', (
      tester,
    ) async {
      // 8 L/min of EAN40 with 1.3 L/min VO2 gives (3.2 - 1.3) / 6.7 = 28.4 %.
      await _pumpPanel(
        tester,
        VolumeUnit.cubicFeet,
        const ScrSettingsPanel(
          scrType: ScrType.cmf,
          injectionRate: 8.0,
          assumedVo2: 1.30,
          supplyGas: GasMix(o2: 40.0, he: 0.0),
          onChanged: _ignore,
        ),
      );

      expect(find.text('Calculated loop FO₂: 28.4%'), findsOneWidget);
    });
  });

  group('fed back through the parent, as on the dive edit page', () {
    testWidgets('clearing a rate that started empty reports null', (
      tester,
    ) async {
      final host = await _pumpHost(tester, VolumeUnit.cubicFeet, null);

      await tester.enterText(_fieldWithLabel('Injection Rate'), '0.3');
      await tester.pump();
      expect(host.injectionRate, closeTo(0.3 / 0.0353147, 0.0001));

      await tester.enterText(_fieldWithLabel('Injection Rate'), '');
      await tester.pump();
      expect(host.injectionRate, isNull);
    });

    testWidgets('typing the seed back restores the original stored rate', (
      tester,
    ) async {
      final host = await _pumpHost(tester, VolumeUnit.cubicFeet, 8.0);

      await tester.enterText(_fieldWithLabel('Injection Rate'), '0.3');
      await tester.pump();
      await tester.enterText(_fieldWithLabel('Injection Rate'), '0.28');
      await tester.pump();

      // "0.28" is what 8.0 L/min was shown as, not the 8.495 L/min the
      // parent was handed for "0.3".
      expect(host.injectionRate, 8.0);
    });

    testWidgets('a unit change while open re-renders the rates', (
      tester,
    ) async {
      // Settings start at the metric defaults and are replaced once the
      // diver's row loads, which can happen after the panel is built.
      final host = await _pumpHost(tester, VolumeUnit.liters, 8.0);
      expect(_textOf(tester, 'Injection Rate'), '8');

      await host.settings.setVolumeUnit(VolumeUnit.cubicFeet);
      await tester.pump();

      expect(find.text('cuft/min'), findsNWidgets(2));
      expect(_textOf(tester, 'Injection Rate'), '0.28');
      expect(_textOf(tester, 'Assumed VO₂'), '0.046');

      // Re-rendering must not drift the stored values.
      await tester.enterText(_fieldWithLabel('Type'), 'Sofnolime');
      await tester.pump();
      expect(host.injectionRate, 8.0);
      expect(host.assumedVo2, 1.30);

      // And new entries are read in the new unit.
      await tester.enterText(_fieldWithLabel('Injection Rate'), '0.3');
      await tester.pump();
      expect(host.injectionRate, closeTo(0.3 / 0.0353147, 0.0001));
    });
  });

  group('liters', () {
    testWidgets('shows and stores rates in L/min unchanged', (tester) async {
      final captured = _Captured();
      await _pumpPanel(
        tester,
        VolumeUnit.liters,
        ScrSettingsPanel(
          scrType: ScrType.cmf,
          injectionRate: 8.25,
          assumedVo2: 1.30,
          onChanged: captured.call,
        ),
      );

      expect(find.text('L/min'), findsNWidgets(2));
      // Metric seeds keep their full precision, as before.
      expect(_textOf(tester, 'Injection Rate'), '8.25');
      expect(_textOf(tester, 'Assumed VO₂'), '1.3');

      await tester.enterText(_fieldWithLabel('Injection Rate'), '9.5');
      await tester.pump();

      expect(captured.injectionRate, closeTo(9.5, 0.0001));
      expect(captured.assumedVo2, closeTo(1.30, 0.0001));
    });

    testWidgets('hints keep their metric values', (tester) async {
      await _pumpPanel(
        tester,
        VolumeUnit.liters,
        const ScrSettingsPanel(scrType: ScrType.cmf, onChanged: _ignore),
      );
      await tester.enterText(_fieldWithLabel('Assumed VO₂'), '');
      await tester.pump();

      expect(_hintOf(tester, 'Injection Rate'), '8.0');
      expect(_hintOf(tester, 'Assumed VO₂'), '1.30');
    });

    testWidgets('hints use the locale decimal separator', (tester) async {
      Intl.defaultLocale = 'de';
      await _pumpPanel(
        tester,
        VolumeUnit.liters,
        const ScrSettingsPanel(scrType: ScrType.cmf, onChanged: _ignore),
      );
      await tester.enterText(_fieldWithLabel('Assumed VO₂'), '');
      await tester.pump();

      expect(_hintOf(tester, 'Injection Rate'), '8,0');
      expect(_hintOf(tester, 'Assumed VO₂'), '1,30');
    });
  });
}

void _ignore({
  ScrType? scrType,
  double? injectionRate,
  double? additionRatio,
  String? orificeSize,
  GasMix? supplyGas,
  double? assumedVo2,
  double? loopO2Min,
  double? loopO2Max,
  double? loopO2Avg,
  String? scrubberType,
  int? scrubberDurationMinutes,
  int? scrubberRemainingMinutes,
}) {}

class _Captured {
  double? injectionRate;
  double? assumedVo2;

  void call({
    ScrType? scrType,
    double? injectionRate,
    double? additionRatio,
    String? orificeSize,
    GasMix? supplyGas,
    double? assumedVo2,
    double? loopO2Min,
    double? loopO2Max,
    double? loopO2Avg,
    String? scrubberType,
    int? scrubberDurationMinutes,
    int? scrubberRemainingMinutes,
  }) {
    this.injectionRate = injectionRate;
    this.assumedVo2 = assumedVo2;
  }
}

Finder _fieldWithLabel(String label) =>
    find.ancestor(of: find.text(label), matching: find.byType(TextFormField));

TextField _textFieldOf(WidgetTester tester, String label) =>
    tester.widget<TextField>(
      find.descendant(
        of: _fieldWithLabel(label),
        matching: find.byType(TextField),
      ),
    );

/// The field's own value. A finder on its text would also match the hidden
/// hint, which can read the same.
String _textOf(WidgetTester tester, String label) =>
    _textFieldOf(tester, label).controller!.text;

String? _hintOf(WidgetTester tester, String label) =>
    _textFieldOf(tester, label).decoration?.hintText;

/// Hosts the panel the way the dive edit page does: each reported value is
/// stored and passed back in on the next build.
class _Host {
  _Host(this.settings, this.injectionRate);

  final MockSettingsNotifier settings;
  double? injectionRate;
  double? assumedVo2 = 1.30;
}

Future<_Host> _pumpHost(
  WidgetTester tester,
  VolumeUnit volumeUnit,
  double? injectionRate,
) async {
  final host = _Host(
    MockSettingsNotifier(AppSettings(volumeUnit: volumeUnit)),
    injectionRate,
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [settingsProvider.overrideWith((ref) => host.settings)],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: StatefulBuilder(
              builder: (context, setState) => ScrSettingsPanel(
                scrType: ScrType.cmf,
                injectionRate: host.injectionRate,
                assumedVo2: host.assumedVo2,
                onChanged:
                    ({
                      scrType,
                      injectionRate,
                      additionRatio,
                      orificeSize,
                      supplyGas,
                      assumedVo2,
                      loopO2Min,
                      loopO2Max,
                      loopO2Avg,
                      scrubberType,
                      scrubberDurationMinutes,
                      scrubberRemainingMinutes,
                    }) => setState(() {
                      host.injectionRate = injectionRate;
                      host.assumedVo2 = assumedVo2;
                    }),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return host;
}

Future<void> _pumpPanel(
  WidgetTester tester,
  VolumeUnit volumeUnit,
  Widget panel,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        settingsProvider.overrideWith(
          (ref) => MockSettingsNotifier(AppSettings(volumeUnit: volumeUnit)),
        ),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: SingleChildScrollView(child: panel)),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
