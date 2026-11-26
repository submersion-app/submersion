import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/settings/presentation/widgets/ccr_ppo2_limit_dialog.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/test_app.dart';

typedef _Saved = ({double low, double high, double dil, double depth});

class _RecordingSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _RecordingSettingsNotifier(super.state);

  final calls = <_Saved>[];

  @override
  Future<void> setCcrPpO2Limits({
    required double setpointLow,
    required double setpointHigh,
    required double diluentModPpO2,
    double? setpointSwitchDepth,
  }) async {
    calls.add((
      low: setpointLow,
      high: setpointHigh,
      dil: diluentModPpO2,
      depth: setpointSwitchDepth ?? double.nan,
    ));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget _dialogApp({
  double initialDepth = 10.0,
  UnitFormatter units = const UnitFormatter(AppSettings()),
  required void Function(_Saved) onSave,
}) => MaterialApp(
  locale: const Locale('en'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(
    body: Builder(
      builder: (context) => ElevatedButton(
        onPressed: () => showDialog<void>(
          context: context,
          builder: (_) => CcrPpO2LimitDialog(
            initialSetpointLow: 0.7,
            initialSetpointHigh: 1.3,
            initialDiluentModPpO2: 1.0,
            initialSetpointSwitchDepth: initialDepth,
            units: units,
            onSave: (low, high, dil, depth) =>
                onSave((low: low, high: high, dil: dil, depth: depth)),
          ),
        ),
        child: const Text('Open'),
      ),
    ),
  ),
);

Future<void> _open(WidgetTester tester) async {
  tester.view.physicalSize = const Size(800, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
}

/// The depth row's slider is the fourth, after setpoint low, high and Dil
/// MOD.
Slider _depthSlider(WidgetTester tester) =>
    tester.widget<Slider>(find.byType(Slider).at(3));

Finder get _depthField => find.byType(TextField);

String _fieldText(WidgetTester tester) =>
    tester.widget<TextField>(_depthField).controller!.text;

Future<void> _blur(WidgetTester tester) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
}

Future<void> _save(WidgetTester tester) async {
  await tester.tap(find.text('Save'));
  await tester.pumpAndSettle();
}

void main() {
  group('CcrPpO2LimitDialog switch depth', () {
    testWidgets('shows the label, the hint, the depth and the number field', (
      tester,
    ) async {
      await tester.pumpWidget(_dialogApp(onSave: (_) {}));
      await _open(tester);

      expect(find.text('Setpoint switch depth'), findsOneWidget);
      expect(
        find.text('High setpoint below, low setpoint above'),
        findsOneWidget,
      );
      expect(find.text('10m'), findsOneWidget);
      expect(_fieldText(tester), '10');
      expect(find.byType(Slider), findsNWidgets(4));
      final slider = _depthSlider(tester);
      expect(slider.min, 3.0);
      expect(slider.max, 30.0);
      expect(slider.divisions, 27);
      expect(slider.value, 10.0);
    });

    testWidgets('the slider steps in whole meters, saves meters and moves the '
        'field with it', (tester) async {
      final saved = <_Saved>[];
      await tester.pumpWidget(_dialogApp(onSave: saved.add));
      await _open(tester);

      _depthSlider(tester).onChanged!(15.4);
      await tester.pumpAndSettle();
      expect(_fieldText(tester), '15');
      expect(find.text('15m'), findsOneWidget);

      await _save(tester);
      expect(saved.single.depth, 15.0);
      expect(saved.single.low, 0.7);
      expect(saved.single.high, 1.3);
      expect(saved.single.dil, 1.0);
    });

    testWidgets('the number field takes a depth outside the slider and pins '
        'the thumb at that end', (tester) async {
      final saved = <_Saved>[];
      await tester.pumpWidget(_dialogApp(onSave: saved.add));
      await _open(tester);

      await tester.enterText(_depthField, '40');
      await tester.pumpAndSettle();
      expect(_depthSlider(tester).value, 30.0);
      expect(find.text('40m'), findsOneWidget);
      // The box keeps what was typed, it is not rewritten to the slider end.
      expect(_fieldText(tester), '40');

      await tester.enterText(_depthField, '0');
      await tester.pumpAndSettle();
      expect(_depthSlider(tester).value, 3.0);

      await tester.enterText(_depthField, '40');
      await tester.pumpAndSettle();
      await _save(tester);
      expect(saved.single.depth, 40.0);
    });

    testWidgets('a value above 100 m waits for blur and then settles on 100', (
      tester,
    ) async {
      final saved = <_Saved>[];
      await tester.pumpWidget(_dialogApp(onSave: saved.add));
      await _open(tester);

      await tester.enterText(_depthField, '250');
      await tester.pumpAndSettle();
      // Not applied while typing.
      expect(find.text('10m'), findsOneWidget);

      await _blur(tester);
      expect(_fieldText(tester), '100');
      expect(find.text('100m'), findsOneWidget);

      await _save(tester);
      expect(saved.single.depth, 100.0);
    });

    testWidgets('Save settles a value still in the box, without a blur', (
      tester,
    ) async {
      final saved = <_Saved>[];
      await tester.pumpWidget(_dialogApp(onSave: saved.add));
      await _open(tester);

      // Typed as on a phone: "15" is an in-range prefix of "150", and the
      // box keeps focus when Save is tapped.
      await tester.enterText(_depthField, '15');
      await tester.pumpAndSettle();
      await tester.enterText(_depthField, '150');
      await tester.pumpAndSettle();

      await _save(tester);
      expect(saved.single.depth, 100.0);
    });

    testWidgets('an empty box is ignored and blur restores the held depth', (
      tester,
    ) async {
      final saved = <_Saved>[];
      await tester.pumpWidget(_dialogApp(onSave: saved.add));
      await _open(tester);

      await tester.enterText(_depthField, '');
      await tester.pumpAndSettle();
      expect(find.text('10m'), findsOneWidget);

      await _blur(tester);
      expect(_fieldText(tester), '10');

      await _save(tester);
      expect(saved.single.depth, 10.0);
    });

    testWidgets('a stored depth outside the slider opens with the thumb at the '
        'end and the real value in the box', (tester) async {
      await tester.pumpWidget(_dialogApp(initialDepth: 55.0, onSave: (_) {}));
      await _open(tester);

      expect(_depthSlider(tester).value, 30.0);
      expect(_fieldText(tester), '55');
      expect(find.text('55m'), findsOneWidget);
    });

    testWidgets('in feet the value text and the box show feet and the save '
        'is in meters', (tester) async {
      final saved = <_Saved>[];
      await tester.pumpWidget(
        _dialogApp(
          units: const UnitFormatter(AppSettings(depthUnit: DepthUnit.feet)),
          onSave: saved.add,
        ),
      );
      await _open(tester);

      // 10 m is 32.81 ft.
      expect(find.text('32.8ft'), findsOneWidget);
      expect(_fieldText(tester), '32.8');
      expect(find.text('ft'), findsWidgets);

      await tester.enterText(_depthField, '100');
      await tester.pumpAndSettle();
      await _save(tester);
      // 100 ft is 30.48 m, kept exactly so it shows as 100 ft again.
      expect(saved.single.depth, closeTo(30.48, 1e-9));
    });
  });

  group('CcrPpO2LimitTile', () {
    const settings = AppSettings(
      ccrSetpointLow: 0.6,
      ccrSetpointHigh: 1.2,
      ccrDiluentModPpO2: 1.0,
      ccrSetpointSwitchDepth: 12.0,
    );

    Future<_RecordingSettingsNotifier> pumpTile(
      WidgetTester tester,
      AppSettings value,
    ) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final notifier = _RecordingSettingsNotifier(value);
      await tester.pumpWidget(
        testApp(
          locale: const Locale('en'),
          overrides: [settingsProvider.overrideWith((ref) => notifier)],
          child: const CcrPpO2LimitTile(),
        ),
      );
      await tester.pumpAndSettle();
      return notifier;
    }

    testWidgets('the subtitle names the switch depth', (tester) async {
      await pumpTile(tester, settings);

      expect(
        find.text('Setpoint low 0.6 · high 1.2 · Dil MOD 1.0 bar · switch 12m'),
        findsOneWidget,
      );
    });

    testWidgets('the subtitle shows the switch depth in the diver\'s unit', (
      tester,
    ) async {
      await pumpTile(tester, settings.copyWith(depthUnit: DepthUnit.feet));

      expect(
        find.text(
          'Setpoint low 0.6 · high 1.2 · Dil MOD 1.0 bar · switch 39.4ft',
        ),
        findsOneWidget,
      );
    });

    testWidgets('the dialog starts at the stored depth and saves the new one '
        'with the limits', (tester) async {
      final notifier = await pumpTile(tester, settings);

      await tester.tap(find.byType(ListTile));
      await tester.pumpAndSettle();
      expect(_fieldText(tester), '12');

      await tester.enterText(_depthField, '45');
      await tester.pumpAndSettle();
      await _save(tester);

      expect(notifier.calls, hasLength(1));
      expect(notifier.calls.single.low, 0.6);
      expect(notifier.calls.single.high, 1.2);
      expect(notifier.calls.single.dil, 1.0);
      expect(notifier.calls.single.depth, 45.0);
    });
  });
}
