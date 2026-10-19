import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/theme/display_zoom.dart';
import 'package:submersion/features/settings/presentation/providers/display_zoom_provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/settings/presentation/widgets/display_zoom_settings_tile.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

// The test font draws every glyph a full em wide, so text here is wider
// than in a real font; these widths are chosen against that font.

/// Narrow enough for the stacked layout in English.
const double _narrow = 400;

/// Wide enough for the one-row layout in English at the default text size.
const double _wide = 800;

/// Wide enough for one row even with a long title or large text.
const double _extraWide = 1600;

/// Whether [finder]'s text laid out on a single line.
bool _isOneLine(WidgetTester tester, Finder finder) {
  final paragraph = tester.renderObject<RenderParagraph>(finder);
  final lineHeight = paragraph.getFullHeightForCaret(
    const TextPosition(offset: 0),
  );
  return paragraph.size.height < lineHeight * 1.5;
}

/// Whether the slider shares a row with the title rather than sitting below.
bool _isOneRow(WidgetTester tester, String title) =>
    tester.getRect(find.byType(Slider)).left >
    tester.getRect(find.text(title)).right;

void _useWideView(WidgetTester tester) {
  tester.view.physicalSize = const Size(_extraWide, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<ProviderContainer> _pumpTile(
  WidgetTester tester,
  Map<String, Object> initial, {
  double width = _narrow,
  double textScale = 1,
  ValueListenable<double>? widthListenable,
  Locale locale = const Locale('en'),
}) async {
  SharedPreferences.setMockInitialValues(initial);
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: locale,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: widthListenable == null
                ? SizedBox(width: width, child: const DisplayZoomSettingsTile())
                : ValueListenableBuilder<double>(
                    valueListenable: widthListenable,
                    builder: (context, width, child) =>
                        SizedBox(width: width, child: child),
                    child: const DisplayZoomSettingsTile(),
                  ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();

  return container;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('shows the current zoom as a percentage', (tester) async {
    await _pumpTile(tester, {'display_zoom': 0.85});

    expect(find.text('Display size'), findsOneWidget);
    expect(find.text('85%'), findsOneWidget);
  });

  for (final (name, width) in [('stacked', _narrow), ('one row', _wide)]) {
    group('$name layout', () {
      testWidgets('hides the reset action at 100%', (tester) async {
        await _pumpTile(tester, {}, width: width);

        expect(find.text('100%'), findsOneWidget);
        expect(find.byTooltip('Reset'), findsNothing);
        expect(find.byIcon(Icons.restart_alt), findsNothing);
      });

      testWidgets('reset returns the zoom to 100%', (tester) async {
        final container = await _pumpTile(tester, {
          'display_zoom': 0.75,
        }, width: width);

        expect(find.byTooltip('Reset'), findsOneWidget);
        await tester.tap(find.byTooltip('Reset'));
        await tester.pumpAndSettle();

        expect(
          container.read(displayZoomNotifierProvider),
          DisplayZoom.defaultValue,
        );
      });
    });
  }

  testWidgets('drags rescale live but only persist on release', (tester) async {
    final container = await _pumpTile(tester, {});
    final prefs = await SharedPreferences.getInstance();
    final slider = tester.widget<Slider>(find.byType(Slider));

    // Mid-drag: state moves so the app rescales, storage stays untouched.
    slider.onChanged!(0.8);
    await tester.pump();
    expect(container.read(displayZoomNotifierProvider), 0.8);
    expect(prefs.getDouble('display_zoom'), isNull);

    slider.onChanged!(0.75);
    await tester.pump();
    expect(container.read(displayZoomNotifierProvider), 0.75);
    expect(prefs.getDouble('display_zoom'), isNull);

    // Release commits once.
    slider.onChangeEnd!(0.75);
    await tester.pumpAndSettle();
    expect(prefs.getDouble('display_zoom'), 0.75);
  });

  testWidgets('the slider is configured for the supported range', (
    tester,
  ) async {
    await _pumpTile(tester, {});

    final slider = tester.widget<Slider>(find.byType(Slider));
    expect(slider.min, DisplayZoom.min);
    expect(slider.max, DisplayZoom.max);
    expect(slider.divisions, DisplayZoom.divisions);
  });

  group('layout', () {
    testWidgets('stacks the slider under the title when narrow', (
      tester,
    ) async {
      await _pumpTile(tester, {'display_zoom': 0.85});

      final slider = tester.getRect(find.byType(Slider));
      final percent = tester.getRect(find.text('85%'));
      expect(slider.top, greaterThanOrEqualTo(percent.bottom));
    });

    testWidgets('puts the slider beside the title when wide enough', (
      tester,
    ) async {
      await _pumpTile(tester, {'display_zoom': 0.85}, width: _wide);

      final slider = tester.getRect(find.byType(Slider));
      final title = tester.getRect(find.text('Display size'));
      final percent = tester.getRect(find.text('85%'));
      expect(slider.left, greaterThan(title.right));
      expect(_isOneLine(tester, find.text('Display size')), isTrue);
      expect(slider.center.dy, greaterThan(title.top));
      expect(slider.center.dy, lessThan(percent.bottom));

      final smaller = tester.getRect(find.text('Smaller'));
      final larger = tester.getRect(find.text('Larger'));
      final reset = tester.getRect(find.byTooltip('Reset'));
      expect(smaller.right, lessThanOrEqualTo(slider.left));
      expect(larger.left, greaterThanOrEqualTo(slider.right));
      expect(reset.left, greaterThanOrEqualTo(larger.right));
    });

    testWidgets('one row is shorter than the stacked layout', (tester) async {
      await _pumpTile(tester, {});
      final stacked = tester.getSize(find.byType(DisplayZoomSettingsTile));

      await _pumpTile(tester, {}, width: _wide);
      final oneRow = tester.getSize(find.byType(DisplayZoomSettingsTile));

      expect(oneRow.height, lessThan(stacked.height));
    });

    testWidgets('the slider keeps its width when the reset action appears', (
      tester,
    ) async {
      await _pumpTile(tester, {}, width: _wide);
      final before = tester.getRect(find.byType(Slider));

      // Dragging off 100% reveals reset mid-drag; the track must not move
      // under the pointer.
      tester.widget<Slider>(find.byType(Slider)).onChanged!(0.8);
      await tester.pump();

      expect(find.byTooltip('Reset'), findsOneWidget);
      expect(tester.getRect(find.byType(Slider)), before);
    });

    testWidgets('large text keeps the stacked layout until it fits', (
      tester,
    ) async {
      await _pumpTile(
        tester,
        {'display_zoom': 0.75},
        width: _wide,
        textScale: 2,
      );

      expect(tester.takeException(), isNull);
      expect(_isOneRow(tester, 'Display size'), isFalse);
    });

    testWidgets('large text gets one row once there is room for it', (
      tester,
    ) async {
      _useWideView(tester);
      await _pumpTile(
        tester,
        {'display_zoom': 0.75},
        width: _extraWide,
        textScale: 2,
      );

      expect(tester.takeException(), isNull);
      expect(_isOneRow(tester, 'Display size'), isTrue);
      expect(_isOneLine(tester, find.text('Display size')), isTrue);
      expect(find.byTooltip('Reset'), findsOneWidget);
    });

    testWidgets('a long translated title keeps the stacked layout '
        'where it would wrap on one row', (tester) async {
      // Italian: "Dimensione di visualizzazione".
      await _pumpTile(tester, {}, width: _wide, locale: const Locale('it'));

      expect(tester.takeException(), isNull);
      expect(_isOneRow(tester, 'Dimensione di visualizzazione'), isFalse);
    });

    testWidgets('a long translated title gets one row, unwrapped, '
        'once there is room for it', (tester) async {
      _useWideView(tester);
      await _pumpTile(
        tester,
        {},
        width: _extraWide,
        locale: const Locale('it'),
      );

      expect(tester.takeException(), isNull);
      final title = find.text('Dimensione di visualizzazione');
      expect(_isOneRow(tester, 'Dimensione di visualizzazione'), isTrue);
      expect(_isOneLine(tester, title), isTrue);
    });

    testWidgets('a drag survives the layout changing under it', (tester) async {
      // Dragging rescales the app live, which changes the tile's logical
      // width; near the threshold that flips the layout mid-drag.
      final width = ValueNotifier<double>(_wide);
      addTearDown(width.dispose);
      await _pumpTile(tester, {}, widthListenable: width);
      final prefs = await SharedPreferences.getInstance();

      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(Slider)),
      );
      await gesture.moveBy(const Offset(-40, 0));
      await tester.pump();

      width.value = _narrow;
      await tester.pump();
      expect(
        tester.getRect(find.byType(Slider)).top,
        greaterThanOrEqualTo(tester.getRect(find.text('Display size')).bottom),
      );

      await gesture.moveBy(const Offset(-40, 0));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      expect(prefs.getDouble('display_zoom'), isNotNull);
      expect(
        prefs.getDouble('display_zoom'),
        lessThan(DisplayZoom.defaultValue),
      );
    });

    testWidgets('no locale wraps its title on one row', (tester) async {
      _useWideView(tester);
      for (final locale in AppLocalizations.supportedLocales) {
        for (final width in [_wide, _extraWide]) {
          await _pumpTile(tester, {}, width: width, locale: locale);
          expect(tester.takeException(), isNull, reason: '$locale @ $width');

          final l10n = lookupAppLocalizations(locale);
          final title = l10n.settings_appearance_displaySize;
          if (_isOneRow(tester, title)) {
            expect(
              _isOneLine(tester, find.text(title)),
              isTrue,
              reason: '$locale @ $width',
            );
          }
        }
      }
    });
  });
}
