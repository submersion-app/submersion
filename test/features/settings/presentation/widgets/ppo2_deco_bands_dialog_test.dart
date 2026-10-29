import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/settings/presentation/widgets/ppo2_deco_bands_dialog.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

typedef _SavedCall = ({
  bool bandsEnabled,
  double band1,
  double band2,
  double band3,
  bool maxO2DepthEnabled,
  double maxO2DepthMeters,
});

Widget _app({
  bool initialBandsEnabled = true,
  double initialBand1 = 1.3,
  double initialBand2 = 1.4,
  double initialBand3 = 1.5,
  bool initialMaxO2DepthEnabled = false,
  double initialMaxO2DepthMeters = 6.0,
  double initialFlatPpO2 = 1.6,
  UnitFormatter units = const UnitFormatter(AppSettings()),
  required void Function(_SavedCall) onSave,
}) => MaterialApp(
  locale: const Locale('en'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(
    body: Builder(
      builder: (context) => ElevatedButton(
        onPressed: () => showDialog<void>(
          context: context,
          builder: (dialogContext) => PpO2DecoBandsDialog(
            initialBandsEnabled: initialBandsEnabled,
            initialBand1: initialBand1,
            initialBand2: initialBand2,
            initialBand3: initialBand3,
            initialMaxO2DepthEnabled: initialMaxO2DepthEnabled,
            initialMaxO2DepthMeters: initialMaxO2DepthMeters,
            initialFlatPpO2: initialFlatPpO2,
            units: units,
            onSave:
                (
                  bandsEnabled,
                  band1,
                  band2,
                  band3,
                  maxO2DepthEnabled,
                  maxO2DepthMeters,
                ) => onSave((
                  bandsEnabled: bandsEnabled,
                  band1: band1,
                  band2: band2,
                  band3: band3,
                  maxO2DepthEnabled: maxO2DepthEnabled,
                  maxO2DepthMeters: maxO2DepthMeters,
                )),
          ),
        ),
        child: const Text('Open'),
      ),
    ),
  ),
);

Slider _slider(WidgetTester tester, int index) =>
    tester.widgetList<Slider>(find.byType(Slider)).elementAt(index);

Future<void> _openDialog(WidgetTester tester) async {
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
}

void main() {
  group('PpO2DecoBandsDialog', () {
    testWidgets('shows the initial band and depth values', (tester) async {
      await tester.pumpWidget(_app(onSave: (_) {}));
      await _openDialog(tester);

      expect(find.text('Deco ppO2: per O2 band'), findsOneWidget);
      expect(find.text('1.3 bar'), findsOneWidget);
      expect(find.text('1.4 bar'), findsOneWidget);
      expect(find.text('1.5 bar'), findsOneWidget);
      expect(find.text('6.0m'), findsOneWidget);
      // 4 sliders: 3 bands + 1 explicit depth.
      expect(find.byType(Slider), findsNWidgets(4));
    });

    testWidgets('untouched layers start from the flat deco ppO2, so turning '
        'them on keeps the ceiling in force', (tester) async {
      final saved = <_SavedCall>[];
      await tester.pumpWidget(
        _app(
          initialBandsEnabled: false,
          initialBand1: 1.6,
          initialBand2: 1.6,
          initialBand3: 1.6,
          initialFlatPpO2: 1.4,
          onSave: saved.add,
        ),
      );
      await _openDialog(tester);

      expect(find.text('1.4 bar'), findsNWidgets(3));
      // Pure O2 reaches 1.4 bar at 4 m on the flat model.
      expect(find.text('4.0m'), findsOneWidget);

      await tester.tap(find.byType(SwitchListTile).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(saved.single.bandsEnabled, isTrue);
      expect(saved.single.band1, closeTo(1.4, 1e-9));
      expect(saved.single.band3, closeTo(1.4, 1e-9));
      // The depth layer was left off, so it keeps its stored value rather
      // than the 4 m it was shown seeded at.
      expect(saved.single.maxO2DepthMeters, 6.0);
    });

    testWidgets('saving for the other layer leaves a seeded layer that is '
        'still off as stored, not pinned to today\'s flat limit', (
      tester,
    ) async {
      final saved = <_SavedCall>[];
      await tester.pumpWidget(
        _app(
          initialBandsEnabled: false,
          initialBand1: 1.6,
          initialBand2: 1.6,
          initialBand3: 1.6,
          initialFlatPpO2: 1.4,
          onSave: saved.add,
        ),
      );
      await _openDialog(tester);

      // Only the explicit O2 depth switch is turned on.
      await tester.tap(find.byType(SwitchListTile).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(saved.single.bandsEnabled, isFalse);
      expect(saved.single.band1, 1.6);
      expect(saved.single.band2, 1.6);
      expect(saved.single.band3, 1.6);
      expect(saved.single.maxO2DepthEnabled, isTrue);
      expect(saved.single.maxO2DepthMeters, closeTo(4.0, 1e-9));
    });

    testWidgets('bands the diver already edited are kept even while off', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(initialBandsEnabled: false, initialFlatPpO2: 1.6, onSave: (_) {}),
      );
      await _openDialog(tester);

      expect(find.text('1.3 bar'), findsOneWidget);
      expect(find.text('1.4 bar'), findsOneWidget);
      expect(find.text('1.5 bar'), findsOneWidget);
    });

    testWidgets('the band sliders start disabled when bands are off', (
      tester,
    ) async {
      await tester.pumpWidget(_app(initialBandsEnabled: false, onSave: (_) {}));
      await _openDialog(tester);

      expect(_slider(tester, 0).onChanged, isNull);
      expect(_slider(tester, 1).onChanged, isNull);
      expect(_slider(tester, 2).onChanged, isNull);
    });

    testWidgets('toggling the bands switch on enables the band sliders', (
      tester,
    ) async {
      await tester.pumpWidget(_app(initialBandsEnabled: false, onSave: (_) {}));
      await _openDialog(tester);

      final switches = find.byType(SwitchListTile);
      await tester.tap(switches.first);
      await tester.pumpAndSettle();

      expect(_slider(tester, 0).onChanged, isNotNull);
    });

    testWidgets(
      'the explicit-depth slider starts disabled until its own switch is on',
      (tester) async {
        await tester.pumpWidget(
          _app(initialMaxO2DepthEnabled: false, onSave: (_) {}),
        );
        await _openDialog(tester);

        expect(_slider(tester, 3).onChanged, isNull);

        final switches = find.byType(SwitchListTile);
        await tester.tap(switches.last);
        await tester.pumpAndSettle();

        expect(_slider(tester, 3).onChanged, isNotNull);
      },
    );

    testWidgets('displays the explicit depth in the diver\'s unit setting', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          initialMaxO2DepthMeters: 6.0,
          units: const UnitFormatter(AppSettings(depthUnit: DepthUnit.feet)),
          onSave: (_) {},
        ),
      );
      await _openDialog(tester);

      // 6.0 m == 19.68 ft, rounded to one decimal; the slider's own grid
      // stays in meters regardless (issue #3580 follow-up).
      expect(find.text('19.7ft'), findsOneWidget);
      expect(_slider(tester, 3).value, 6.0);
    });

    testWidgets('Save reports every edited value through onSave', (
      tester,
    ) async {
      _SavedCall? saved;
      await tester.pumpWidget(
        _app(
          initialBandsEnabled: true,
          initialBand1: 1.3,
          initialBand2: 1.4,
          initialBand3: 1.5,
          initialMaxO2DepthEnabled: false,
          initialMaxO2DepthMeters: 6.0,
          onSave: (call) => saved = call,
        ),
      );
      await _openDialog(tester);

      _slider(tester, 0).onChanged!(1.4);
      await tester.pump();
      final switches = find.byType(SwitchListTile);
      await tester.tap(switches.last);
      await tester.pump();
      _slider(tester, 3).onChanged!(7.5);
      await tester.pump();

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(saved, isNotNull);
      expect(saved!.bandsEnabled, isTrue);
      expect(saved!.band1, closeTo(1.4, 1e-9));
      expect(saved!.band2, closeTo(1.4, 1e-9));
      expect(saved!.band3, closeTo(1.5, 1e-9));
      expect(saved!.maxO2DepthEnabled, isTrue);
      expect(saved!.maxO2DepthMeters, closeTo(7.5, 1e-9));
    });

    testWidgets('Cancel closes the dialog without calling onSave', (
      tester,
    ) async {
      var saveCalled = false;
      await tester.pumpWidget(_app(onSave: (_) => saveCalled = true));
      await _openDialog(tester);

      _slider(tester, 0).onChanged!(1.4);
      await tester.pump();

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(saveCalled, isFalse);
      expect(find.byType(PpO2DecoBandsDialog), findsNothing);
    });
  });
}
