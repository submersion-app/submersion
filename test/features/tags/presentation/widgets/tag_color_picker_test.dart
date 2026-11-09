import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/tags/domain/tag_palette.dart';
import 'package:submersion/features/tags/presentation/widgets/tag_chip.dart';
import 'package:submersion/features/tags/presentation/widgets/tag_color_picker.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// The tag colour picker: a preview chip over a grid of 60 palette dots, a
/// dot for a colour off the palette, and a "+" for a custom one (issue
/// #4384).
void main() {
  final current = find.byKey(const ValueKey('tag-color-current'));
  final custom = find.byKey(const ValueKey('tag-color-custom'));
  Finder dot(String hex) => find.byKey(ValueKey('tag-color-$hex'));

  /// Pumps the picker under a parent that, like the dialogs, stores what the
  /// picker reports and hands it back as [TagColorPicker.selectedColor].
  Future<(ValueNotifier<String?>, List<String>)> pumpPicker(
    WidgetTester tester, {
    String? selectedColor,
    TextEditingController? nameController,
    TargetPlatform? platform,
    double width = 400,
  }) async {
    final selection = ValueNotifier<String?>(selectedColor);
    addTearDown(selection.dispose);
    final reported = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: platform),
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: Center(
              child: SizedBox(
                width: width,
                child: ValueListenableBuilder<String?>(
                  valueListenable: selection,
                  builder: (context, value, _) => TagColorPicker(
                    selectedColor: value,
                    nameController: nameController,
                    onColorSelected: (hex) {
                      reported.add(hex);
                      selection.value = hex;
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    return (selection, reported);
  }

  bool isSelected(WidgetTester tester, Finder finder) =>
      tester.getSemantics(finder).flagsCollection.isSelected == Tristate.isTrue;

  testWidgets('previews the tag by name in the chosen colour', (tester) async {
    final name = TextEditingController(text: 'Night dive');
    addTearDown(name.dispose);
    await pumpPicker(tester, selectedColor: '#14B8A6', nameController: name);

    final chip = tester.widget<TagChip>(find.byType(TagChip));
    expect(chip.color, const Color(0xFF14B8A6));
    expect(find.text('Night dive'), findsOne);

    name.text = 'Wreck';
    await tester.pump();
    expect(find.text('Wreck'), findsOne);
  });

  testWidgets('offers every palette colour and a custom one', (tester) async {
    await pumpPicker(tester, selectedColor: '#EF4444');
    for (final entry in tagPalette) {
      expect(dot(entry.hex), findsOne, reason: entry.hex);
    }
    expect(custom, findsOne);
    expect(current, findsNothing);
  });

  testWidgets('a tag with no colour has Blue chosen and no extra dot', (
    tester,
  ) async {
    await pumpPicker(tester);
    expect(current, findsNothing);
    expect(isSelected(tester, dot('#3B82F6')), isTrue);
    expect(isSelected(tester, dot('#EF4444')), isFalse);
  });

  testWidgets('a palette code in another casing selects its dot', (
    tester,
  ) async {
    await pumpPicker(tester, selectedColor: '#3b82f6');
    expect(current, findsNothing);
    expect(isSelected(tester, dot('#3B82F6')), isTrue);
  });

  testWidgets('an unreadable code is drawn and chosen as Blue', (tester) async {
    await pumpPicker(tester, selectedColor: 'red');
    expect(current, findsNothing);
    expect(isSelected(tester, dot('#3B82F6')), isTrue);
  });

  testWidgets('a colour off the palette keeps a dot of its own', (
    tester,
  ) async {
    final (_, reported) = await pumpPicker(tester, selectedColor: 'FF0000');
    expect(current, findsOne);
    expect(isSelected(tester, current), isTrue);
    expect(find.bySemanticsLabel('Current color, FF0000'), findsOne);

    await tester.tap(dot('#EF4444'));
    await tester.pump();
    expect(reported, ['#EF4444']);
    expect(isSelected(tester, dot('#EF4444')), isTrue);

    // Still there, so the diver can go back to it.
    await tester.tap(current);
    await tester.pump();
    expect(reported.last, 'FF0000');
    expect(isSelected(tester, current), isTrue);
  });

  testWidgets('a translucent import keeps its own dot, not the opaque one', (
    tester,
  ) async {
    await pumpPicker(tester, selectedColor: '80EF4444');
    expect(current, findsOne);
    expect(isSelected(tester, current), isTrue);
    expect(isSelected(tester, dot('#EF4444')), isFalse);
  });

  testWidgets('a newer colour off the palette replaces the extra dot', (
    tester,
  ) async {
    final (selection, _) = await pumpPicker(tester, selectedColor: 'FF0000');
    selection.value = '#123456';
    await tester.pump();
    expect(find.bySemanticsLabel('Current color, #123456'), findsOne);
    expect(find.bySemanticsLabel('Current color, FF0000'), findsNothing);
  });

  testWidgets('names every dot for a screen reader', (tester) async {
    await pumpPicker(tester, selectedColor: '#EF4444');
    expect(find.bySemanticsLabel('Teal'), findsOne);
    expect(find.bySemanticsLabel('Teal, light'), findsOne);
    expect(find.bySemanticsLabel('Teal, dark'), findsOne);
    expect(find.bySemanticsLabel('Custom color'), findsOne);
  });

  group('the + dot', () {
    testWidgets('opens on the colour the tag is drawn in', (tester) async {
      await pumpPicker(tester, selectedColor: 'FF0000');
      await tester.tap(custom);
      await tester.pumpAndSettle();
      final field = tester.widget<TextField>(
        find.byKey(const ValueKey('tag-color-hex')),
      );
      expect(field.controller!.text, '#FF0000');
    });

    testWidgets('reports the colour chosen there', (tester) async {
      final (_, reported) = await pumpPicker(tester, selectedColor: '#EF4444');
      await tester.tap(custom);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('tag-color-hex')),
        '#2E8B57',
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('tag-color-use')));
      await tester.pumpAndSettle();
      expect(reported, ['#2E8B57']);
      expect(isSelected(tester, current), isTrue);
    });

    testWidgets('reports nothing when cancelled', (tester) async {
      final (_, reported) = await pumpPicker(tester, selectedColor: '#EF4444');
      await tester.tap(custom);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(reported, isEmpty);
    });
  });

  group('a dot is a reachable tap target', () {
    for (final (platform, floor) in [
      (TargetPlatform.android, 48.0),
      (TargetPlatform.iOS, 48.0),
      (TargetPlatform.macOS, 32.0),
      (TargetPlatform.windows, 32.0),
      (TargetPlatform.linux, 32.0),
    ]) {
      testWidgets('$platform reaches $floor', (tester) async {
        await pumpPicker(tester, platform: platform, selectedColor: 'FF0000');
        for (final finder in [dot('#EF4444'), current, custom]) {
          final size = tester.getSize(finder);
          expect(size.height, greaterThanOrEqualTo(floor));
          expect(size.width, greaterThanOrEqualTo(floor));
        }
      });
    }
  });

  testWidgets('lays out inside an AlertDialog, which asks its width first', (
    tester,
  ) async {
    // AlertDialog sizes itself with IntrinsicWidth, so the picker must
    // answer an intrinsic width without laying out its bands.
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.macOS),
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: AlertDialog(
            content: SingleChildScrollView(
              child: TagColorPicker(
                selectedColor: 'FF0000',
                onColorSelected: (_) {},
              ),
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    final first = tester.getRect(dot(tagPalette.first.hex));
    final tenth = tester.getRect(dot(tagPalette[9 * 3].hex));
    final eleventh = tester.getRect(dot(tagPalette[10 * 3].hex));
    expect(tenth.top, first.top);
    expect(eleventh.top, greaterThan(first.top));
  });

  group('hues wrap in even bands', () {
    // Column per hue, light shade on top: its dot gives the column's left
    // edge and its band's top edge.
    double left(WidgetTester tester, int hue) =>
        tester.getRect(dot(tagPalette[hue * 3].hex)).left;
    double top(WidgetTester tester, int hue) =>
        tester.getRect(dot(tagPalette[hue * 3].hex)).top;

    testWidgets('ten hues to a band on a wide desktop dialog', (tester) async {
      await pumpPicker(
        tester,
        platform: TargetPlatform.macOS,
        width: 870,
        selectedColor: '#EF4444',
      );
      expect(top(tester, 9), top(tester, 0));
      expect(top(tester, 10), greaterThan(top(tester, 9)));
      expect(left(tester, 10), left(tester, 0));
      expect(top(tester, 19), top(tester, 10));
    });

    testWidgets('a current colour leads the first band, columns aligned', (
      tester,
    ) async {
      await pumpPicker(
        tester,
        platform: TargetPlatform.macOS,
        width: 870,
        selectedColor: 'FF0000',
      );
      final currentRect = tester.getRect(current);
      expect(currentRect.top, top(tester, 0));
      expect(left(tester, 0), greaterThan(currentRect.left));
      expect(left(tester, 10), left(tester, 0));
    });

    testWidgets('the + dot ends the last band', (tester) async {
      await pumpPicker(
        tester,
        platform: TargetPlatform.macOS,
        width: 870,
        selectedColor: '#EF4444',
      );
      final plus = tester.getRect(custom);
      expect(plus.top, top(tester, 19));
      expect(plus.left, greaterThan(left(tester, 19)));
    });
  });

  group('in a real dialog (review of #4384)', () {
    Future<ValueNotifier<String?>> pumpDialog(
      WidgetTester tester, {
      required Size view,
      required TargetPlatform platform,
      String? selectedColor,
    }) async {
      tester.view.physicalSize = view;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final selection = ValueNotifier<String?>(selectedColor);
      addTearDown(selection.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: platform),
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: AlertDialog(
              content: SingleChildScrollView(
                child: ValueListenableBuilder<String?>(
                  valueListenable: selection,
                  builder: (context, value, _) => TagColorPicker(
                    selectedColor: value,
                    onColorSelected: (hex) => selection.value = hex,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      return selection;
    }

    for (final stored in <String?>[null, 'FF0000']) {
      testWidgets('a 360 dp phone gets four hues a band, not two ($stored)', (
        tester,
      ) async {
        await pumpDialog(
          tester,
          view: const Size(360, 2000),
          platform: TargetPlatform.android,
          selectedColor: stored,
        );
        expect(tester.takeException(), isNull);
        final first = tester.getRect(dot(tagPalette.first.hex));
        final fourth = tester.getRect(dot(tagPalette[3 * 3].hex));
        final last = tester.getRect(dot(tagPalette.last.hex));
        expect(fourth.top, first.top);
        // Five bands of three 48 dp dots and the gaps between them.
        expect(last.bottom - first.top, lessThanOrEqualTo(5 * 144 + 4 * 4));
      });
    }

    testWidgets('the dialog keeps its width when a current dot appears', (
      tester,
    ) async {
      final selection = await pumpDialog(
        tester,
        view: const Size(1200, 900),
        platform: TargetPlatform.macOS,
        selectedColor: '#EF4444',
      );
      final before = tester.getSize(find.byType(AlertDialog)).width;
      selection.value = '#123456';
      await tester.pump();
      expect(current, findsOne);
      expect(tester.getSize(find.byType(AlertDialog)).width, before);
    });
  });

  testWidgets('the + dot is an action, not a choice with a selected state', (
    tester,
  ) async {
    await pumpPicker(tester, selectedColor: '#EF4444');
    expect(
      tester.getSemantics(custom).flagsCollection.isSelected,
      Tristate.none,
    );
  });

  testWidgets('wraps to a narrow phone dialog without overflowing', (
    tester,
  ) async {
    await pumpPicker(
      tester,
      platform: TargetPlatform.android,
      width: 280,
      selectedColor: '#EF4444',
    );
    expect(tester.takeException(), isNull);
    final first = tester.getRect(dot(tagPalette.first.hex));
    final last = tester.getRect(dot(tagPalette.last.hex));
    expect(last.top, greaterThan(first.bottom));
  });
}
