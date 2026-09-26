import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
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

  // The form seeds and parses through Intl.defaultLocale, a process global
  // that MaterialApp's locale does not set. Pin it so "2.5" is not riding on
  // intl's implicit fallback, and restore it for the next file.
  late String? previousLocale;

  setUp(() {
    previousLocale = Intl.defaultLocale;
    Intl.defaultLocale = 'en_US';
  });

  tearDown(() {
    Intl.defaultLocale = previousLocale;
  });

  Widget host(Widget child) => MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: SingleChildScrollView(child: child)),
  );

  group('visibilityScaleBandLabels', () {
    final l10n = lookupAppLocalizations(const Locale('en'));

    test('names every band with its range in metric', () {
      expect(
        visibilityScaleBandLabels(VisibilityScale.tropical, l10n, metric),
        [
          'Excellent 30 m+',
          'Good 15-30 m',
          'Moderate 5-15 m',
          'Poor under 5 m',
        ],
      );
    });

    test('converts to the diver depth unit', () {
      // 12 m, 6 m and 2 m are about 39, 20 and 7 ft.
      expect(
        visibilityScaleBandLabels(
          VisibilityScale.coldWater,
          l10n,
          imperial,
          wholeUnits: true,
        ),
        [
          'Excellent 39 ft+',
          'Good 20-39 ft',
          'Moderate 7-20 ft',
          'Poor under 7 ft',
        ],
      );
    });

    test('keeps a fractional threshold instead of rounding it away', () {
      // Rounded to whole metres, 2.5 would read "Poor under 3 m" although
      // 2.7 m is Moderate.
      expect(
        visibilityScaleBandLabels(
          const VisibilityScale(
            excellentAtOrAboveM: 18,
            goodAtOrAboveM: 9,
            moderateAtOrAboveM: 2.5,
          ),
          l10n,
          metric,
        ),
        [
          'Excellent 18 m+',
          'Good 9-18 m',
          'Moderate 2.5-9 m',
          'Poor under 2.5 m',
        ],
      );
    });

    test('drops the decimal from a whole value entered in feet', () {
      // Entered as 40/20/6 ft and stored in metres, the values convert back
      // with a floating-point tail that must not show.
      expect(
        visibilityScaleBandLabels(
          VisibilityScale(
            excellentAtOrAboveM: imperial.depthToMeters(40),
            goodAtOrAboveM: imperial.depthToMeters(20),
            moderateAtOrAboveM: imperial.depthToMeters(6),
          ),
          l10n,
          imperial,
        ),
        [
          'Excellent 40 ft+',
          'Good 20-40 ft',
          'Moderate 6-20 ft',
          'Poor under 6 ft',
        ],
      );
    });
  });

  group('retainedCustomVisibilityScale', () {
    test('is null until the diver has saved custom thresholds', () {
      expect(retainedCustomVisibilityScale(const AppSettings()), isNull);
    });

    test(
      'returns the saved thresholds even while a named preset is active',
      () {
        final scale = retainedCustomVisibilityScale(
          const AppSettings(
            visibilityScalePreset: VisibilityScalePreset.coldWater,
            visibilityScaleExcellentM: 18,
            visibilityScaleGoodM: 9,
            visibilityScaleModerateM: 3,
          ),
        );
        expect(
          scale,
          const VisibilityScale(
            excellentAtOrAboveM: 18,
            goodAtOrAboveM: 9,
            moderateAtOrAboveM: 3,
          ),
        );
      },
    );

    test('is null for an invalid saved set', () {
      expect(
        retainedCustomVisibilityScale(
          const AppSettings(
            visibilityScaleExcellentM: 3,
            visibilityScaleGoodM: 9,
            visibilityScaleModerateM: 18,
          ),
        ),
        isNull,
      );
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
      // Named presets spell out every band's range, Poor included.
      expect(find.text('Excellent 30 m+ ·'), findsOneWidget);
      expect(find.text('Good 15-30 m'), findsOneWidget);
      expect(find.text('Moderate 5-15 m ·'), findsOneWidget);
      expect(find.text('Poor under 5 m'), findsOneWidget);
      expect(find.text('Excellent 12 m+ ·'), findsOneWidget);
      expect(find.text('Good 6-12 m'), findsOneWidget);
      expect(find.text('Moderate 2-6 m ·'), findsOneWidget);
      expect(find.text('Poor under 2 m'), findsOneWidget);
    });

    testWidgets('never splits a band across lines in a narrow dialog', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          SizedBox(
            // Wide enough for one band per line in the test font, too narrow
            // for two, so every line has to break between bands.
            width: 300,
            child: VisibilityScalePresetList(
              selected: VisibilityScalePreset.tropical,
              units: metric,
              onSelected: (_) {},
            ),
          ),
        ),
      );

      // The narrow width really did push Good below Excellent.
      expect(
        tester.getTopLeft(find.text('Good 15-30 m')).dy,
        greaterThan(tester.getTopLeft(find.text('Excellent 30 m+ ·')).dy),
      );

      // A band may move to the next line as a whole, but its label and range
      // must stay together: every glyph box shares one line.
      for (final band in [
        'Excellent 30 m+ ·',
        'Good 15-30 m',
        'Moderate 5-15 m ·',
        'Poor under 5 m',
      ]) {
        final paragraph = tester.renderObject<RenderParagraph>(find.text(band));
        final tops = paragraph
            .getBoxesForSelection(
              TextSelection(baseOffset: 0, extentOffset: band.length),
            )
            .map((box) => box.top)
            .toSet();
        expect(tops, hasLength(1), reason: '"$band" wrapped');
      }
    });

    testWidgets('explains what the scale is for and that dives are kept', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          VisibilityScalePresetList(
            selected: VisibilityScalePreset.tropical,
            units: metric,
            onSelected: (_) {},
          ),
        ),
      );

      expect(
        find.textContaining('in dive details and statistics'),
        findsOneWidget,
      );
      expect(
        find.textContaining('never changes the distances you logged'),
        findsOneWidget,
      );
    });

    testWidgets('Custom invites the diver to set distances when none are '
        'saved', (tester) async {
      await tester.pumpWidget(
        host(
          VisibilityScalePresetList(
            selected: VisibilityScalePreset.tropical,
            units: metric,
            onSelected: (_) {},
          ),
        ),
      );

      expect(find.text('Set your own distances'), findsOneWidget);
    });

    testWidgets('Custom shows the saved ranges once they exist', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          VisibilityScalePresetList(
            selected: VisibilityScalePreset.tropical,
            units: metric,
            custom: const VisibilityScale(
              excellentAtOrAboveM: 18,
              goodAtOrAboveM: 9,
              moderateAtOrAboveM: 3,
            ),
            onSelected: (_) {},
          ),
        ),
      );

      expect(find.text('Set your own distances'), findsNothing);
      expect(find.text('Excellent 18 m+ ·'), findsOneWidget);
      expect(find.text('Good 9-18 m'), findsOneWidget);
      expect(find.text('Moderate 3-9 m ·'), findsOneWidget);
      expect(find.text('Poor under 3 m'), findsOneWidget);
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

    testWidgets('explains what each field means', (tester) async {
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

      expect(
        find.text(
          'Enter the shortest distance that still counts for each label.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('shows where Poor begins, following the Moderate field', (
      tester,
    ) async {
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
      expect(find.text('Poor under 2 m'), findsOneWidget);

      await tester.enterText(find.byType(TextField).at(2), '3');
      await tester.pump();
      expect(find.text('Poor under 3 m'), findsOneWidget);
      expect(find.text('Poor under 2 m'), findsNothing);
    });

    testWidgets('keeps a fractional Moderate value in the Poor line', (
      tester,
    ) async {
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

      await tester.enterText(find.byType(TextField).at(2), '2.5');
      await tester.pump();
      expect(find.text('Poor under 2.5 m'), findsOneWidget);
    });

    testWidgets('the Poor line matches a whole-unit Moderate seed', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          CustomVisibilityScaleForm(
            initial: VisibilityScale.coldWater,
            units: imperial,
            wholeUnits: true,
            onSubmit: (_) {},
            onCancel: () {},
          ),
        ),
      );

      // Moderate is 2 m, seeded as "7" ft; the line must not read 6.6 ft
      // beside a field that says 7.
      expect(find.widgetWithText(TextField, '7'), findsOneWidget);
      expect(find.text('Poor under 7 ft'), findsOneWidget);
    });

    testWidgets('hides the Poor line while Moderate is unusable', (
      tester,
    ) async {
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

      await tester.enterText(find.byType(TextField).at(2), 'abc');
      await tester.pump();
      expect(find.textContaining('Poor'), findsNothing);

      await tester.enterText(find.byType(TextField).at(2), '0');
      await tester.pump();
      expect(find.textContaining('Poor'), findsNothing);
    });

    testWidgets('seeds a named preset in whole diver depth units', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          CustomVisibilityScaleForm(
            initial: VisibilityScale.coldWater,
            units: imperial,
            wholeUnits: true,
            onSubmit: (_) {},
            onCancel: () {},
          ),
        ),
      );
      // 12 m is 39.37 ft. A preset's bounds are nominal, so the decimal is
      // noise and the field matches the "39" the preset list advertises.
      expect(find.widgetWithText(TextField, '39'), findsOneWidget);
    });

    testWidgets('seeds a fractional threshold with its decimal', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          CustomVisibilityScaleForm(
            initial: const VisibilityScale(
              excellentAtOrAboveM: 18,
              goodAtOrAboveM: 9,
              moderateAtOrAboveM: 2.5,
            ),
            units: metric,
            onSubmit: (_) {},
            onCancel: () {},
          ),
        ),
      );

      // Rounding to "3" would move the threshold on the next Save.
      expect(find.widgetWithText(TextField, '2.5'), findsOneWidget);
      expect(find.widgetWithText(TextField, '3'), findsNothing);
      expect(find.widgetWithText(TextField, '18'), findsOneWidget);
    });

    testWidgets('saves an untouched field at its stored precision', (
      tester,
    ) async {
      VisibilityScale? submitted;
      await tester.pumpWidget(
        host(
          CustomVisibilityScaleForm(
            initial: const VisibilityScale(
              excellentAtOrAboveM: 18,
              goodAtOrAboveM: 9,
              moderateAtOrAboveM: 2.56,
            ),
            units: metric,
            onSubmit: (s) => submitted = s,
            onCancel: () {},
          ),
        ),
      );
      // Shown at one decimal, but Save must not store the rounded 2.6.
      expect(find.widgetWithText(TextField, '2.6'), findsOneWidget);

      await tester.tap(find.text('Save'));
      await tester.pump();

      expect(submitted!.moderateAtOrAboveM, 2.56);
    });

    testWidgets('saves an untouched field exactly through a feet round trip', (
      tester,
    ) async {
      VisibilityScale? submitted;
      await tester.pumpWidget(
        host(
          CustomVisibilityScaleForm(
            initial: const VisibilityScale(
              excellentAtOrAboveM: 18,
              goodAtOrAboveM: 9,
              moderateAtOrAboveM: 2.5,
            ),
            units: imperial,
            onSubmit: (s) => submitted = s,
            onCancel: () {},
          ),
        ),
      );

      // 2.5 m shows as 8.2 ft, which reads back as 2.499 m.
      await tester.tap(find.text('Save'));
      await tester.pump();

      expect(submitted!.excellentAtOrAboveM, 18);
      expect(submitted!.goodAtOrAboveM, 9);
      expect(submitted!.moderateAtOrAboveM, 2.5);
    });

    testWidgets('an edited field saves what was typed, not the stored value', (
      tester,
    ) async {
      VisibilityScale? submitted;
      await tester.pumpWidget(
        host(
          CustomVisibilityScaleForm(
            initial: const VisibilityScale(
              excellentAtOrAboveM: 18,
              goodAtOrAboveM: 9,
              moderateAtOrAboveM: 2.56,
            ),
            units: metric,
            onSubmit: (s) => submitted = s,
            onCancel: () {},
          ),
        ),
      );

      await tester.enterText(find.byType(TextField).at(2), '2.7');
      await tester.tap(find.text('Save'));
      await tester.pump();

      expect(submitted!.moderateAtOrAboveM, 2.7);
    });

    testWidgets('seeds and saves with a comma decimal separator', (
      tester,
    ) async {
      Intl.defaultLocale = 'de';
      VisibilityScale? submitted;
      await tester.pumpWidget(
        host(
          CustomVisibilityScaleForm(
            initial: const VisibilityScale(
              excellentAtOrAboveM: 18,
              goodAtOrAboveM: 9,
              moderateAtOrAboveM: 2.5,
            ),
            units: metric,
            onSubmit: (s) => submitted = s,
            onCancel: () {},
          ),
        ),
      );
      expect(find.widgetWithText(TextField, '2,5'), findsOneWidget);

      // Under de '.' groups thousands, so an edit must be read with ','.
      await tester.enterText(find.byType(TextField).at(1), '9,5');
      await tester.tap(find.text('Save'));
      await tester.pump();

      expect(submitted!.goodAtOrAboveM, 9.5);
      expect(submitted!.moderateAtOrAboveM, 2.5);
    });

    testWidgets('seeds a feet entry back as the whole number typed', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          CustomVisibilityScaleForm(
            // 40 ft, 20 ft and 8.2 ft, as stored after an imperial entry.
            initial: const VisibilityScale(
              excellentAtOrAboveM: 12.192,
              goodAtOrAboveM: 6.096,
              moderateAtOrAboveM: 2.49936,
            ),
            units: imperial,
            onSubmit: (_) {},
            onCancel: () {},
          ),
        ),
      );

      expect(find.widgetWithText(TextField, '40'), findsOneWidget);
      expect(find.widgetWithText(TextField, '20'), findsOneWidget);
      expect(find.widgetWithText(TextField, '8.2'), findsOneWidget);
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

    testWidgets('scrolls instead of overflowing on a short screen', (
      tester,
    ) async {
      // A phone in landscape: the explained preset list is taller than this.
      await tester.binding.setSurfaceSize(const Size(800, 360));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await pumpPicker(
        tester,
        const AppSettings(
          visibilityScaleExcellentM: 18,
          visibilityScaleGoodM: 9,
          visibilityScaleModerateM: 3,
        ),
      );
      expect(tester.takeException(), isNull);

      await tester.scrollUntilVisible(
        find.text('Custom'),
        100,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.text('Custom'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(TextField), findsNWidgets(3));
    });

    testWidgets('opens with the presets listed', (tester) async {
      await pumpPicker(tester, const AppSettings());
      expect(find.text('Visibility scale'), findsOneWidget);
      expect(find.text('Cold water / Inland'), findsOneWidget);
    });

    testWidgets('the Custom row shows retained thresholds', (tester) async {
      await pumpPicker(
        tester,
        const AppSettings(
          visibilityScalePreset: VisibilityScalePreset.coldWater,
          visibilityScaleExcellentM: 18,
          visibilityScaleGoodM: 9,
          visibilityScaleModerateM: 3,
        ),
      );

      expect(find.text('Excellent 18 m+ ·'), findsOneWidget);
      expect(find.text('Good 9-18 m'), findsOneWidget);
      expect(find.text('Moderate 3-9 m ·'), findsOneWidget);
      expect(find.text('Poor under 3 m'), findsOneWidget);
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

    testWidgets('reopening a fractional custom threshold and saving keeps it', (
      tester,
    ) async {
      final saved = await pumpPicker(
        tester,
        const AppSettings(
          visibilityScalePreset: VisibilityScalePreset.custom,
          visibilityScaleExcellentM: 18,
          visibilityScaleGoodM: 9,
          visibilityScaleModerateM: 2.5,
        ),
      );

      await tester.tap(find.text('Custom'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextField, '2.5'), findsOneWidget);

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(saved.single.visibilityScaleModerateM, 2.5);
    });

    testWidgets('reopening a feet custom threshold shows the number typed', (
      tester,
    ) async {
      await pumpPicker(
        tester,
        const AppSettings(
          depthUnit: DepthUnit.feet,
          visibilityScalePreset: VisibilityScalePreset.custom,
          visibilityScaleExcellentM: 12.192,
          visibilityScaleGoodM: 6.096,
          visibilityScaleModerateM: 1.8288,
        ),
      );

      await tester.tap(find.text('Custom'));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(TextField, '40'), findsOneWidget);
      expect(find.widgetWithText(TextField, '20'), findsOneWidget);
      expect(find.widgetWithText(TextField, '6'), findsOneWidget);
    });

    testWidgets('with no custom thresholds saved, the form seeds the active '
        'preset in whole feet', (tester) async {
      await pumpPicker(
        tester,
        const AppSettings(
          depthUnit: DepthUnit.feet,
          visibilityScalePreset: VisibilityScalePreset.coldWater,
        ),
      );

      await tester.tap(find.text('Custom'));
      await tester.pumpAndSettle();

      // Cold water is 12 / 6 / 2 m: 39.37, 19.69 and 6.56 ft.
      expect(find.widgetWithText(TextField, '39'), findsOneWidget);
      expect(find.widgetWithText(TextField, '20'), findsOneWidget);
      expect(find.widgetWithText(TextField, '7'), findsOneWidget);
      expect(find.widgetWithText(TextField, '39.4'), findsNothing);
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
