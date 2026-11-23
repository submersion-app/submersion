import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/theme/full_themes/submersion_theme.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/widgets/edit_sections/tank_row.dart';
import 'package:submersion/features/dive_log/presentation/widgets/tank_editor.dart';
import 'package:submersion/features/dive_log/presentation/widgets/tank_editor_header.dart';
import 'package:submersion/features/dive_log/presentation/widgets/tank_field_grid.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';

import '../../../../helpers/mock_providers.dart';

/// The cylinder editor of the Cylinders card on a phone (issue #4962): the
/// card editor nests it in the page, the open card and the cylinder's
/// outline, which left O2 "5(%", working pressure no room at all and the
/// title wrapping letter by letter.
void main() {
  final l = AppLocalizationsEn();
  const ean50 = DiveTank(
    id: 't',
    volume: 7,
    workingPressure: 200,
    startPressure: 200,
    endPressure: 100,
    gasMix: GasMix(o2: 50),
  );

  /// [child] at [width] wide, framed as the dive page frames an open card:
  /// page padding, the open card and its padding.
  Future<void> pumpAt(
    WidgetTester tester,
    Widget child, {
    double width = 400,
    double textScale = 1,
  }) async {
    tester.view.physicalSize = Size(width, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [...await getBaseOverrides()],
        child: MaterialApp(
          theme: submersionLight,
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(textScale)),
              child: Scaffold(
                body: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: child,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Widget openRow({int tankNumber = 3, VoidCallback? onRemove}) => TankRow(
    tank: ean50,
    tankNumber: tankNumber,
    units: const UnitFormatter(AppSettings()),
    onChanged: (_) {},
    onRemove: onRemove ?? () {},
    initiallyExpanded: true,
  );

  /// The text field labelled [label].
  RenderEditable editableOf(WidgetTester tester, String label) {
    final field = find.ancestor(
      of: find.text(label),
      matching: find.byType(TextField),
    );
    return tester
        .state<EditableTextState>(
          find.descendant(of: field.first, matching: find.byType(EditableText)),
        )
        .renderEditable;
  }

  /// [box] is laid out at least as wide as its text needs: nothing clipped.
  void expectFits(RenderBox box, String what) {
    expect(
      box.size.width,
      greaterThanOrEqualTo(box.getMaxIntrinsicWidth(double.infinity) - 0.01),
      reason: '$what is clipped',
    );
  }

  // The test font draws every glyph a full em wide, about twice what Roboto
  // gives digits and units, so "200 bar" would read as clipped in a field
  // that holds it with room to spare. The values checked for fit are the
  // short ones the issue saw clipped (O2 "5(%"); the minimum width check
  // covers every field.
  for (final width in [360.0, 400.0]) {
    for (final scale in [1.0, 1.3]) {
      testWidgets('an open cylinder on a ${width.toInt()} dp phone at text '
          'scale $scale keeps every field wide enough and its mix, pressures '
          'and title whole', (tester) async {
        await pumpAt(tester, openRow(), width: width, textScale: scale);

        final minWidth = TextScaler.linear(
          scale,
        ).scale(TankFieldGrid.defaultMinFieldWidth);
        for (final label in [
          l.diveLog_tank_label_o2,
          l.diveLog_tank_label_he,
          l.diveLog_tank_label_n2,
          l.diveLog_tank_label_volume,
          l.diveLog_tank_label_material,
          l.diveLog_tank_label_workingPressure,
          l.diveLog_tank_label_startPressure,
          l.diveLog_tank_label_endPressure,
        ]) {
          final field = tester.getRect(
            find
                .ancestor(
                  of: find.text(label),
                  matching: find.byType(InputDecorator),
                )
                .first,
          );
          expect(
            field.width,
            greaterThanOrEqualTo(minWidth),
            reason: '$label field',
          );
        }
        for (final label in [
          l.diveLog_tank_label_o2,
          l.diveLog_tank_label_he,
          l.diveLog_tank_label_volume,
        ]) {
          expectFits(editableOf(tester, label), '$label value');
        }

        // The computed N2 shows on one line.
        final n2 = find.descendant(
          of: find.ancestor(
            of: find.text(l.diveLog_tank_label_n2),
            matching: find.byType(InputDecorator),
          ),
          matching: find.text('50'),
        );
        expectFits(tester.renderObject<RenderParagraph>(n2), 'N2 value');

        // The title and mix name stay whole, on one line each.
        for (final text in [l.diveLog_tank_title(3), 'EAN50']) {
          final paragraph = tester.renderObject<RenderParagraph>(
            find.descendant(
              of: find.byType(TankEditorHeader),
              matching: find.text(text),
            ),
          );
          expectFits(paragraph, text);
          expect(paragraph.didExceedMaxLines, isFalse, reason: text);
        }
      });
    }
  }

  testWidgets('on a phone O2 and He share a line and N2 sits below O2 at the '
      'same width', (tester) async {
    await pumpAt(tester, openRow());

    Rect fieldOf(String label) => tester.getRect(
      find
          .ancestor(of: find.text(label), matching: find.byType(InputDecorator))
          .first,
    );
    final o2 = fieldOf(l.diveLog_tank_label_o2);
    final he = fieldOf(l.diveLog_tank_label_he);
    final n2 = fieldOf(l.diveLog_tank_label_n2);
    expect(he.top, o2.top);
    expect(he.left, greaterThan(o2.right));
    expect(n2.top, greaterThan(o2.bottom));
    expect(n2.left, o2.left);
    expect(n2.width, moreOrLessEquals(o2.width));
  });

  testWidgets('on a wide screen O2, He and N2 keep one line', (tester) async {
    await pumpAt(tester, openRow(), width: 900);

    double topOf(String label) => tester
        .getRect(
          find
              .ancestor(
                of: find.text(label),
                matching: find.byType(InputDecorator),
              )
              .first,
        )
        .top;
    expect(topOf(l.diveLog_tank_label_he), topOf(l.diveLog_tank_label_o2));
    expect(topOf(l.diveLog_tank_label_n2), topOf(l.diveLog_tank_label_o2));
  });

  testWidgets('on a narrow phone the header actions fold into a menu that '
      'still scans and removes', (tester) async {
    var removed = 0;
    await pumpAt(tester, openRow(onRemove: () => removed++), width: 320);

    expect(
      find.descendant(
        of: find.byType(IconButton),
        matching: find.byIcon(Icons.qr_code_scanner),
      ),
      findsNothing,
    );
    await tester.tap(find.byKey(const Key('tank-actions-menu')));
    await tester.pumpAndSettle();
    expect(find.text(l.passport_scan_title), findsOneWidget);

    await tester.tap(find.text(l.diveLog_tank_tooltip_remove));
    await tester.pumpAndSettle();
    expect(removed, 1);
  });

  testWidgets('on a wide screen the header keeps its buttons', (tester) async {
    var removed = 0;
    await pumpAt(tester, openRow(onRemove: () => removed++), width: 900);

    expect(find.byKey(const Key('tank-actions-menu')), findsNothing);
    expect(find.byKey(const Key('tank-scan-tag')), findsOneWidget);
    await tester.tap(find.byTooltip(l.diveLog_tank_tooltip_remove));
    expect(removed, 1);
  });

  testWidgets('inside the outlined cylinder row the editor draws no card of '
      'its own; on its own it keeps one', (tester) async {
    await pumpAt(tester, openRow());
    expect(
      find.descendant(of: find.byType(TankEditor), matching: find.byType(Card)),
      findsNothing,
    );

    await pumpAt(
      tester,
      TankEditor(tank: ean50, tankNumber: 1, onChanged: (_) {}),
    );
    expect(
      find.descendant(of: find.byType(TankEditor), matching: find.byType(Card)),
      findsOneWidget,
    );
  });
}
