import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/domain/visibility/visibility_scale.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/settings/presentation/widgets/visibility_scale_picker.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Stands in for SettingsNotifier so the picker's saves can be inspected
/// without a database. Only setVisibilityScale is exercised here.
class _RecordingSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  final List<AppSettings> saved;

  _RecordingSettingsNotifier(super.initial, this.saved);

  @override
  Future<void> setVisibilityScale({
    required VisibilityScalePreset preset,
    double? excellentM,
    double? goodM,
    double? moderateM,
  }) async {
    state = state.copyWith(
      visibilityScalePreset: preset,
      visibilityScaleExcellentM: excellentM,
      visibilityScaleGoodM: goodM,
      visibilityScaleModerateM: moderateM,
    );
    saved.add(state);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  const metric = UnitFormatter(AppSettings(depthUnit: DepthUnit.meters));
  const imperial = UnitFormatter(AppSettings(depthUnit: DepthUnit.feet));

  Widget host(Widget child) => MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: SingleChildScrollView(child: child)),
  );

  group('visibilityScaleBoundsLabel', () {
    test('renders the three thresholds in metric', () {
      expect(
        visibilityScaleBoundsLabel(VisibilityScale.coldWater, metric),
        '12 / 6 / 2m',
      );
    });

    test('converts to the diver depth unit', () {
      final label = visibilityScaleBoundsLabel(
        VisibilityScale.coldWater,
        imperial,
      );
      expect(label, endsWith('ft'));
      expect(label, contains('39'));
    });
  });

  group('VisibilityScalePresetList', () {
    testWidgets('lists every preset with its thresholds', (tester) async {
      await tester.pumpWidget(
        host(
          VisibilityScalePresetList(
            selected: VisibilityScalePreset.tropical,
            units: metric,
            onSelected: (_) {},
          ),
        ),
      );

      expect(find.text('Tropical'), findsOneWidget);
      expect(find.text('Temperate'), findsOneWidget);
      expect(find.text('Cold water / Inland'), findsOneWidget);
      expect(find.text('Custom'), findsOneWidget);
      // Named presets advertise their bounds; Custom has none to show yet.
      expect(find.text('30 / 15 / 5m'), findsOneWidget);
      expect(find.text('12 / 6 / 2m'), findsOneWidget);
    });

    testWidgets('marks the active preset', (tester) async {
      await tester.pumpWidget(
        host(
          VisibilityScalePresetList(
            selected: VisibilityScalePreset.coldWater,
            units: metric,
            onSelected: (_) {},
          ),
        ),
      );
      expect(find.byIcon(Icons.check), findsOneWidget);
    });

    testWidgets('reports the tapped preset', (tester) async {
      VisibilityScalePreset? picked;
      await tester.pumpWidget(
        host(
          VisibilityScalePresetList(
            selected: VisibilityScalePreset.tropical,
            units: metric,
            onSelected: (p) => picked = p,
          ),
        ),
      );

      await tester.tap(find.text('Cold water / Inland'));
      await tester.pump();
      expect(picked, VisibilityScalePreset.coldWater);
    });

    testWidgets('reports Custom so the caller can open the form', (
      tester,
    ) async {
      VisibilityScalePreset? picked;
      await tester.pumpWidget(
        host(
          VisibilityScalePresetList(
            selected: VisibilityScalePreset.tropical,
            units: metric,
            onSelected: (p) => picked = p,
          ),
        ),
      );

      await tester.tap(find.text('Custom'));
      await tester.pump();
      expect(picked, VisibilityScalePreset.custom);
    });
  });

  group('CustomVisibilityScaleForm', () {
    testWidgets('seeds the fields from the supplied scale', (tester) async {
      await tester.pumpWidget(
        host(
          CustomVisibilityScaleForm(
            initial: VisibilityScale.coldWater,
            units: metric,
            onSubmit: (_) {},
            onCancel: () {},
          ),
        ),
      );

      expect(find.widgetWithText(TextField, '12'), findsOneWidget);
      expect(find.widgetWithText(TextField, '6'), findsOneWidget);
      expect(find.widgetWithText(TextField, '2'), findsOneWidget);
    });

    testWidgets('seeds in the diver depth unit', (tester) async {
      await tester.pumpWidget(
        host(
          CustomVisibilityScaleForm(
            initial: VisibilityScale.coldWater,
            units: imperial,
            onSubmit: (_) {},
            onCancel: () {},
          ),
        ),
      );
      // 12 m is about 39 ft.
      expect(find.widgetWithText(TextField, '39'), findsOneWidget);
    });

    testWidgets('submits metric thresholds from a metric entry', (
      tester,
    ) async {
      VisibilityScale? submitted;
      await tester.pumpWidget(
        host(
          CustomVisibilityScaleForm(
            initial: VisibilityScale.tropical,
            units: metric,
            onSubmit: (s) => submitted = s,
            onCancel: () {},
          ),
        ),
      );

      await tester.enterText(find.byType(TextField).at(0), '18');
      await tester.enterText(find.byType(TextField).at(1), '9');
      await tester.enterText(find.byType(TextField).at(2), '3');
      await tester.tap(find.text('Save'));
      await tester.pump();

      expect(submitted, isNotNull);
      expect(submitted!.excellentAtOrAboveM, 18);
      expect(submitted!.goodAtOrAboveM, 9);
      expect(submitted!.moderateAtOrAboveM, 3);
    });

    testWidgets('converts an imperial entry to metric on submit', (
      tester,
    ) async {
      VisibilityScale? submitted;
      await tester.pumpWidget(
        host(
          CustomVisibilityScaleForm(
            initial: VisibilityScale.tropical,
            units: imperial,
            onSubmit: (s) => submitted = s,
            onCancel: () {},
          ),
        ),
      );

      await tester.enterText(find.byType(TextField).at(0), '40');
      await tester.enterText(find.byType(TextField).at(1), '20');
      await tester.enterText(find.byType(TextField).at(2), '6');
      await tester.tap(find.text('Save'));
      await tester.pump();

      expect(submitted!.excellentAtOrAboveM, closeTo(12.19, 0.01));
      expect(submitted!.goodAtOrAboveM, closeTo(6.1, 0.01));
    });

    testWidgets('blocks a non-descending set with an inline error', (
      tester,
    ) async {
      VisibilityScale? submitted;
      await tester.pumpWidget(
        host(
          CustomVisibilityScaleForm(
            initial: VisibilityScale.tropical,
            units: metric,
            onSubmit: (s) => submitted = s,
            onCancel: () {},
          ),
        ),
      );

      // Ascending instead of descending: one band would be unreachable.
      await tester.enterText(find.byType(TextField).at(0), '5');
      await tester.enterText(find.byType(TextField).at(1), '10');
      await tester.enterText(find.byType(TextField).at(2), '20');
      await tester.tap(find.text('Save'));
      await tester.pump();

      expect(submitted, isNull);
      expect(find.textContaining('smaller than the one above'), findsOneWidget);
    });

    testWidgets('blocks a zero lowest threshold', (tester) async {
      VisibilityScale? submitted;
      await tester.pumpWidget(
        host(
          CustomVisibilityScaleForm(
            initial: VisibilityScale.tropical,
            units: metric,
            onSubmit: (s) => submitted = s,
            onCancel: () {},
          ),
        ),
      );

      await tester.enterText(find.byType(TextField).at(2), '0');
      await tester.tap(find.text('Save'));
      await tester.pump();

      expect(submitted, isNull);
    });

    testWidgets('blocks unparseable input', (tester) async {
      VisibilityScale? submitted;
      await tester.pumpWidget(
        host(
          CustomVisibilityScaleForm(
            initial: VisibilityScale.tropical,
            units: metric,
            onSubmit: (s) => submitted = s,
            onCancel: () {},
          ),
        ),
      );

      await tester.enterText(find.byType(TextField).at(0), 'abc');
      await tester.tap(find.text('Save'));
      await tester.pump();

      expect(submitted, isNull);
    });

    testWidgets('cancel reports without submitting', (tester) async {
      var cancelled = false;
      VisibilityScale? submitted;
      await tester.pumpWidget(
        host(
          CustomVisibilityScaleForm(
            initial: VisibilityScale.tropical,
            units: metric,
            onSubmit: (s) => submitted = s,
            onCancel: () => cancelled = true,
          ),
        ),
      );

      await tester.tap(find.text('Cancel'));
      await tester.pump();

      expect(cancelled, isTrue);
      expect(submitted, isNull);
    });
  });

  group('showVisibilityScalePicker', () {
    /// Pumps a button that opens the picker for [settings], recording every
    /// calibration the notifier is asked to save.
    Future<List<AppSettings>> pumpPicker(
      WidgetTester tester,
      AppSettings settings,
    ) async {
      final saved = <AppSettings>[];
      final notifier = _RecordingSettingsNotifier(settings, saved);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [settingsProvider.overrideWith((ref) => notifier)],
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Consumer(
              builder: (context, ref, _) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () =>
                        showVisibilityScalePicker(context, ref, settings),
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      return saved;
    }

    testWidgets('opens with the presets listed', (tester) async {
      await pumpPicker(tester, const AppSettings());
      expect(find.text('Visibility scale'), findsOneWidget);
      expect(find.text('Cold water / Inland'), findsOneWidget);
    });

    testWidgets('choosing a named preset saves it and closes', (tester) async {
      final saved = await pumpPicker(tester, const AppSettings());

      await tester.tap(find.text('Cold water / Inland'));
      await tester.pumpAndSettle();

      expect(saved, hasLength(1));
      expect(
        saved.single.visibilityScalePreset,
        VisibilityScalePreset.coldWater,
      );
      expect(find.text('Visibility scale'), findsNothing);
    });

    testWidgets('choosing Custom opens the threshold form', (tester) async {
      final saved = await pumpPicker(tester, const AppSettings());

      await tester.tap(find.text('Custom'));
      await tester.pumpAndSettle();

      // Nothing saved yet: the form has to be submitted first.
      expect(saved, isEmpty);
      expect(find.byType(TextField), findsNWidgets(3));
    });

    testWidgets('the custom form seeds from retained thresholds, not the '
        'active preset', (tester) async {
      // The diver set 18/9/3, then switched to Cold water. Reopening Custom
      // must show 18/9/3, not the cold-water 12/6/2.
      await pumpPicker(
        tester,
        const AppSettings(
          visibilityScalePreset: VisibilityScalePreset.coldWater,
          visibilityScaleExcellentM: 18,
          visibilityScaleGoodM: 9,
          visibilityScaleModerateM: 3,
        ),
      );

      await tester.tap(find.text('Custom'));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(TextField, '18'), findsOneWidget);
      expect(find.widgetWithText(TextField, '9'), findsOneWidget);
      expect(find.widgetWithText(TextField, '3'), findsOneWidget);
      expect(find.widgetWithText(TextField, '12'), findsNothing);
    });

    testWidgets('submitting the custom form saves metric thresholds', (
      tester,
    ) async {
      final saved = await pumpPicker(tester, const AppSettings());

      await tester.tap(find.text('Custom'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).at(0), '18');
      await tester.enterText(find.byType(TextField).at(1), '9');
      await tester.enterText(find.byType(TextField).at(2), '3');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(saved, hasLength(1));
      expect(saved.single.visibilityScalePreset, VisibilityScalePreset.custom);
      expect(saved.single.visibilityScaleExcellentM, 18);
      expect(saved.single.visibilityScale.bandFor(9), VisibilityBand.good);
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('cancelling the custom form saves nothing', (tester) async {
      final saved = await pumpPicker(tester, const AppSettings());

      await tester.tap(find.text('Custom'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(saved, isEmpty);
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('an invalid custom set keeps the form open', (tester) async {
      final saved = await pumpPicker(tester, const AppSettings());

      await tester.tap(find.text('Custom'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).at(0), '5');
      await tester.enterText(find.byType(TextField).at(1), '10');
      await tester.enterText(find.byType(TextField).at(2), '20');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(saved, isEmpty);
      expect(find.byType(TextField), findsNWidgets(3));
    });
  });

  group('visibilityPresetLabel', () {
    testWidgets('localizes every preset', (tester) async {
      late AppLocalizations l10n;
      await tester.pumpWidget(
        host(
          Builder(
            builder: (context) {
              l10n = AppLocalizations.of(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(
        visibilityPresetLabel(l10n, VisibilityScalePreset.tropical),
        'Tropical',
      );
      expect(
        visibilityPresetLabel(l10n, VisibilityScalePreset.temperate),
        'Temperate',
      );
      expect(
        visibilityPresetLabel(l10n, VisibilityScalePreset.coldWater),
        'Cold water / Inland',
      );
      expect(
        visibilityPresetLabel(l10n, VisibilityScalePreset.custom),
        'Custom',
      );
    });
  });
}
