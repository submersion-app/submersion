import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_color_sheet.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_color_names.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Opens the sheet, runs [act] against it, and returns what it completed
/// with.
Future<EquipmentColorChoice?> _open(
  WidgetTester tester, {
  String? selected,
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

  testWidgets('a colour from outside the palette selects nothing', (
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
        for (final key in ['color-swatch-none', 'color-swatch-#EF4444']) {
          final size = tester.getSize(find.byKey(ValueKey(key)));
          expect(size.width, greaterThanOrEqualTo(48), reason: key);
          expect(size.height, greaterThanOrEqualTo(48), reason: key);
        }
        await _dismiss(tester);
      },
    );
  });
}
