import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_color_sheet.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_colors.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Opens the sheet, runs [act] against it, and returns what it completed
/// with.
Future<EquipmentColorChoice?> _open(
  WidgetTester tester, {
  String? selected,
  List<String> recent = const [],
  ValueChanged<String>? onRemember,
  required Future<void> Function() act,
}) async {
  EquipmentColorChoice? result;
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async {
              result = await showEquipmentColorSheet(
                context,
                selected: selected,
                recent: recent,
                onRemember: onRemember,
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  await act();
  await tester.pumpAndSettle();
  return result;
}

Future<void> _dismiss(WidgetTester tester) => tester.tapAt(const Offset(5, 5));

void main() {
  testWidgets('offers None and every palette colour, by name', (tester) async {
    await _open(
      tester,
      act: () async {
        expect(find.text('Choose a color'), findsOneWidget);
        expect(find.bySemanticsLabel('None'), findsOneWidget);
        expect(find.bySemanticsLabel('Red'), findsOneWidget);
        expect(find.bySemanticsLabel('Slate'), findsOneWidget);
        expect(find.bySemanticsLabel('Black'), findsOneWidget);
        expect(find.bySemanticsLabel('White'), findsOneWidget);
        for (final hex in equipmentColorPalette) {
          expect(find.byKey(ValueKey('color-swatch-$hex')), findsOneWidget);
        }
        await _dismiss(tester);
      },
    );
  });

  testWidgets('a tap returns that colour', (tester) async {
    final result = await _open(
      tester,
      act: () => tester.tap(find.byKey(const ValueKey('color-swatch-#3B82F6'))),
    );
    expect(result, (hex: '#3B82F6'));
  });

  testWidgets('Black can be picked (#2627)', (tester) async {
    final result = await _open(
      tester,
      act: () => tester.tap(find.bySemanticsLabel('Black')),
    );
    expect(result, (hex: equipmentColorBlack));
  });

  testWidgets('None returns a choice with no colour', (tester) async {
    final result = await _open(
      tester,
      selected: '#3B82F6',
      act: () => tester.tap(find.byKey(const ValueKey('color-swatch-none'))),
    );
    expect(result, (hex: null));
  });

  testWidgets('dismissing returns nothing', (tester) async {
    final result = await _open(tester, act: () => _dismiss(tester));
    expect(result, isNull);
  });

  testWidgets('the stored colour is the one marked selected', (tester) async {
    await _open(
      tester,
      selected: '#ef4444',
      act: () async {
        bool selected(String key) =>
            tester
                .getSemantics(find.byKey(ValueKey(key)))
                .flagsCollection
                .isSelected ==
            Tristate.isTrue;
        expect(selected('color-swatch-#EF4444'), isTrue);
        expect(selected('color-swatch-#3B82F6'), isFalse);
        expect(selected('color-swatch-none'), isFalse);
        await _dismiss(tester);
      },
    );
  });

  testWidgets('a colour from outside the palette selects no preset', (
    tester,
  ) async {
    await _open(
      tester,
      selected: '#123456',
      act: () async {
        for (final key in [
          'color-swatch-none',
          for (final hex in equipmentColorPalette) 'color-swatch-$hex',
        ]) {
          expect(
            tester
                    .getSemantics(find.byKey(ValueKey(key)))
                    .flagsCollection
                    .isSelected ==
                Tristate.isTrue,
            isFalse,
            reason: key,
          );
        }
        await _dismiss(tester);
      },
    );
  });

  testWidgets('every swatch is at least 48 by 48', (tester) async {
    await _open(
      tester,
      act: () async {
        for (final key in [
          'color-swatch-none',
          'color-swatch-#EF4444',
          'color-swatch-custom',
        ]) {
          final size = tester.getSize(find.byKey(ValueKey(key)));
          expect(size.width, greaterThanOrEqualTo(48), reason: key);
          expect(size.height, greaterThanOrEqualTo(48), reason: key);
        }
        await _dismiss(tester);
      },
    );
  });

  group('recent and custom colours (#4537)', () {
    bool isSelected(WidgetTester tester, String key) =>
        tester
            .getSemantics(find.byKey(ValueKey(key)))
            .flagsCollection
            .isSelected ==
        Tristate.isTrue;

    testWidgets('Custom is an action, not a choice with a selected state', (
      tester,
    ) async {
      await _open(
        tester,
        act: () async {
          final flags = tester
              .getSemantics(find.byKey(const ValueKey('color-swatch-custom')))
              .flagsCollection;
          expect(flags.isSelected, Tristate.none);
          expect(find.bySemanticsLabel('Custom color'), findsOneWidget);
          await _dismiss(tester);
        },
      );
    });

    testWidgets('with nothing recent, Custom follows the presets', (
      tester,
    ) async {
      await _open(
        tester,
        act: () async {
          expect(find.text('Recent'), findsNothing);
          final custom = tester.getCenter(
            find.byKey(const ValueKey('color-swatch-custom')),
          );
          final white = tester.getCenter(
            find.byKey(const ValueKey('color-swatch-$equipmentColorWhite')),
          );
          expect(custom.dy, greaterThanOrEqualTo(white.dy));
          await _dismiss(tester);
        },
      );
    });

    testWidgets('recent colours show by name under Recent, Custom last', (
      tester,
    ) async {
      await _open(
        tester,
        recent: const ['#FF6A00', '#0A3D91'],
        act: () async {
          expect(find.text('Recent'), findsOneWidget);
          expect(find.bySemanticsLabel('Orange (#FF6A00)'), findsOneWidget);
          expect(find.bySemanticsLabel('Blue (#0A3D91)'), findsOneWidget);
          final last = tester.getCenter(
            find.byKey(const ValueKey('color-swatch-recent-#0A3D91')),
          );
          final custom = tester.getCenter(
            find.byKey(const ValueKey('color-swatch-custom')),
          );
          expect(custom.dy, last.dy);
          expect(custom.dx, greaterThan(last.dx));
          await _dismiss(tester);
        },
      );
    });

    testWidgets('an off-palette stored colour leads Recent, selected', (
      tester,
    ) async {
      await _open(
        tester,
        selected: '#123456',
        recent: const ['#FF6A00'],
        act: () async {
          expect(isSelected(tester, 'color-swatch-recent-#123456'), isTrue);
          expect(isSelected(tester, 'color-swatch-recent-#FF6A00'), isFalse);
          final first = tester.getCenter(
            find.byKey(const ValueKey('color-swatch-recent-#123456')),
          );
          final second = tester.getCenter(
            find.byKey(const ValueKey('color-swatch-recent-#FF6A00')),
          );
          expect(first.dx, lessThan(second.dx));
          await _dismiss(tester);
        },
      );
    });

    testWidgets('a recent colour is picked without remembering it', (
      tester,
    ) async {
      final remembered = <String>[];
      final result = await _open(
        tester,
        recent: const ['#FF6A00'],
        onRemember: remembered.add,
        act: () => tester.tap(
          find.byKey(const ValueKey('color-swatch-recent-#FF6A00')),
        ),
      );
      expect(result, (hex: '#FF6A00'));
      expect(remembered, isEmpty);
    });

    testWidgets('Custom: Use picks the typed code and remembers it once', (
      tester,
    ) async {
      final remembered = <String>[];
      final result = await _open(
        tester,
        onRemember: remembered.add,
        act: () async {
          await tester.tap(find.byKey(const ValueKey('color-swatch-custom')));
          await tester.pumpAndSettle();
          await tester.enterText(
            find.byKey(const ValueKey('custom-color-hex')),
            'ff6a00',
          );
          await tester.pump();
          await tester.tap(find.byKey(const ValueKey('custom-color-use')));
        },
      );
      expect(result, (hex: '#FF6A00'));
      expect(remembered, ['#FF6A00']);
    });

    testWidgets('Custom: Cancel goes back to the sheet', (tester) async {
      final remembered = <String>[];
      await _open(
        tester,
        onRemember: remembered.add,
        act: () async {
          await tester.tap(find.byKey(const ValueKey('color-swatch-custom')));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Cancel'));
          await tester.pumpAndSettle();
          expect(find.text('Choose a color'), findsOneWidget);
          await _dismiss(tester);
        },
      );
      expect(remembered, isEmpty);
    });

    testWidgets('on a short window the sheet scrolls to the custom swatch', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(700, 420);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await _open(
        tester,
        recent: const ['#FF6A00', '#0A3D91'],
        act: () async {
          expect(tester.takeException(), isNull);
          final custom = find.byKey(const ValueKey('color-swatch-custom'));
          await tester.ensureVisible(custom);
          await tester.pumpAndSettle();
          await tester.tap(custom);
          await tester.pumpAndSettle();
          expect(find.text('Custom color'), findsWidgets);
          await tester.tap(find.text('Cancel'));
          await tester.pumpAndSettle();
          await _dismiss(tester);
        },
      );
    });

    testWidgets('the title and Recent are headings', (tester) async {
      await _open(
        tester,
        recent: const ['#FF6A00'],
        act: () async {
          for (final text in ['Choose a color', 'Recent']) {
            expect(
              tester.getSemantics(find.text(text)).flagsCollection.isHeader,
              isTrue,
              reason: text,
            );
          }
          await _dismiss(tester);
        },
      );
    });

    testWidgets('a lowercase stored colour built directly is selected', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: EquipmentColorSheet(selected: '#ff6a00')),
        ),
      );
      expect(isSelected(tester, 'color-swatch-recent-#FF6A00'), isTrue);
    });
  });
}
