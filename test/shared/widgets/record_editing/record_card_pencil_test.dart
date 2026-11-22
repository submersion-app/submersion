import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/theme/record_pencil_colors.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/record_editing/edit_card.dart';
import 'package:submersion/shared/widgets/record_editing/edit_field.dart';
import 'package:submersion/shared/widgets/record_editing/record_card_frame.dart';
import 'package:submersion/shared/widgets/record_editing/record_card_header.dart';
import 'package:submersion/shared/widgets/record_editing/record_card_pencil.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_controller.dart';

final _name = EditField<String, String>(
  id: 'name',
  cardId: 'header',
  read: (r) => r,
  write: (_, v) => v,
);

final _card = EditCard<String>(
  id: 'header',
  title: (_) => 'Dive',
  isEmpty: (_) => false,
  editorBuilder: (_, _) => const Text('editor'),
);

/// A card that draws its own title row, with the pencil at its end, the way
/// the dive page's header block does (issue #4527, plan 4).
Widget _host(
  RecordEditController<String>? controller, {
  bool inCard = false,
  ThemeData? theme,
}) {
  const titleRow = Row(
    children: [
      Expanded(child: Text('Blue Corner')),
      RecordCardPencil(cardTitle: 'Dive'),
    ],
  );
  // The dive page's header block draws its title row inside a Card, which
  // gathers its texts into one node for a screen reader.
  final Widget row = inCard ? const Card(child: titleRow) : titleRow;
  return MaterialApp(
    theme: theme,
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: controller == null
          ? row
          : RecordEditScope<String>(
              controller: controller,
              child: RecordCardFrame<String>(card: _card, child: row),
            ),
    ),
  );
}

RecordEditController<String> _controller() {
  final controller = RecordEditController<String>(onSave: (_) async {});
  addTearDown(controller.dispose);
  return controller;
}

void main() {
  testWidgets('with no frame it draws nothing and takes no room', (
    tester,
  ) async {
    await tester.pumpWidget(_host(null));

    expect(find.byType(RecordPencilDisc), findsNothing);
    expect(tester.getSize(find.byType(RecordCardPencil)), Size.zero);
  });

  testWidgets('locked it draws nothing and takes no room', (tester) async {
    await tester.pumpWidget(_host(_controller()));

    expect(find.byType(RecordPencilDisc), findsNothing);
    expect(tester.getSize(find.byType(RecordCardPencil)), Size.zero);
  });

  testWidgets('unlocked and closed, a pencil that opens the card', (
    tester,
  ) async {
    final controller = _controller()..unlock('Blue Corner');
    await tester.pumpWidget(_host(controller));

    await tester.tap(find.byType(RecordPencilDisc));
    await tester.pump();

    expect(controller.openCardIds, {'header'});
    expect(find.text('editor'), findsOneWidget);
  });

  // A shade of the theme's blue blended into every card, so the pencil is
  // the theme's pencil colours instead: a filled disc, ringed (issue #4527).
  testWidgets('the pencil is a disc in the theme\'s pencil colours', (
    tester,
  ) async {
    const custom = RecordPencilColors(
      fill: Color(0xFF123456),
      onFill: Color(0xFFABCDEF),
      outline: Color(0xFF654321),
    );
    final controller = _controller()..unlock('Blue Corner');
    await tester.pumpWidget(
      _host(controller, theme: ThemeData(extensions: const [custom])),
    );

    final disc = find.byType(RecordPencilDisc);
    expect(tester.getSize(disc), const Size.square(RecordPencilDisc.size));
    final material = tester.widget<Material>(
      find.descendant(of: disc, matching: find.byType(Material)),
    );
    expect(material.color, custom.fill);
    expect(
      material.shape,
      CircleBorder(side: BorderSide(color: custom.outline)),
    );
    // The InkWell's border clips its ink; the disc needs no clip layer.
    expect(material.clipBehavior, Clip.none);
    final glyph = tester.widget<Icon>(
      find.descendant(of: disc, matching: find.byType(Icon)),
    );
    expect(glyph.icon, Icons.edit);
    expect(glyph.color, custom.onFill);
  });

  // An ink splash or focus highlight painted under an opaque disc would show
  // only as a hairline round it, so the disc is the surface the ink paints
  // on: pressed, hovered or focused from the keyboard, the disc itself
  // shows it.
  testWidgets('the pencil\'s ink paints on the disc, not under it', (
    tester,
  ) async {
    final controller = _controller()..unlock('Blue Corner');
    await tester.pumpWidget(_host(controller));

    final ink = find.descendant(
      of: find.byType(RecordPencilDisc),
      matching: find.byType(InkWell),
    );
    expect(ink, findsOneWidget);
    final surface = tester.widget<Material>(
      find.ancestor(of: ink, matching: find.byType(Material)).first,
    );
    expect(surface.color, RecordPencilColors.light.fill);
  });

  testWidgets('at a small text size the disc shrinks with the text', (
    tester,
  ) async {
    final controller = _controller()..unlock('Blue Corner');
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(0.85)),
        child: _host(controller),
      ),
    );

    expect(
      tester.getSize(find.byType(RecordPencilDisc)).height,
      (RecordPencilDisc.size * 0.85).floorToDouble(),
    );
  });

  testWidgets('at a large text size the disc keeps its size', (tester) async {
    final controller = _controller()..unlock('Blue Corner');
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(2)),
        child: _host(controller),
      ),
    );

    expect(
      tester.getSize(find.byType(RecordPencilDisc)),
      const Size.square(RecordPencilDisc.size),
    );
  });

  // A card's own title row (an icon and a titleMedium title) is one 24
  // point line, and the pencil arriving on unlock must not make it taller.
  testWidgets('unlocking keeps a title row\'s height', (tester) async {
    final controller = _controller();
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: RecordEditScope<String>(
            controller: controller,
            child: RecordCardFrame<String>(
              card: _card,
              child: Builder(
                builder: (context) => Row(
                  key: const ValueKey('titleRow'),
                  children: [
                    const Icon(Icons.layers),
                    Expanded(
                      child: Text(
                        'Twin set',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    const RecordCardPencil(cardTitle: 'Twin set'),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    final row = find.byKey(const ValueKey('titleRow'));
    final before = tester.getSize(row);

    controller.unlock('Blue Corner');
    await tester.pump();

    expect(find.byType(RecordPencilDisc), findsOneWidget);
    expect(tester.getSize(row), before);
  });

  testWidgets('with changes, the dot', (tester) async {
    final controller = _controller()..unlock('Blue Corner');
    await tester.pumpWidget(_host(controller));
    final l10n = AppLocalizations.of(
      tester.element(find.byType(RecordCardPencil)),
    );
    expect(find.bySemanticsLabel(l10n.recordEdit_unsavedChanges), findsNothing);

    controller.session!.set(_name, 'Elphinstone');
    await tester.pump();

    expect(
      find.bySemanticsLabel(l10n.recordEdit_unsavedChanges),
      findsOneWidget,
    );
  });

  // The dot that marks unsaved changes is the pencil's colour, ring and
  // all, wherever it is drawn (issue #4527).
  testWidgets('the unsaved dot wears the theme\'s pencil colours', (
    tester,
  ) async {
    const custom = RecordPencilColors(
      fill: Color(0xFF123456),
      onFill: Color(0xFFABCDEF),
      outline: Color(0xFF654321),
    );
    final controller = _controller()..unlock('Blue Corner');
    await tester.pumpWidget(
      _host(controller, theme: ThemeData(extensions: const [custom])),
    );
    controller.session!.set(_name, 'Elphinstone');
    await tester.pump();

    final box = tester.widget<Container>(
      find.descendant(
        of: find.byType(RecordChangedDot),
        matching: find.byType(Container),
      ),
    );
    final decoration = box.decoration! as BoxDecoration;
    expect(decoration.shape, BoxShape.circle);
    expect(decoration.color, custom.fill);
    expect(decoration.border, Border.all(color: custom.outline));
  });

  // Inside a Card the pencil keeps a node of its own: merged into the
  // card's, it would be one button named for everything the card says, and
  // a screen reader could not reach the card's way in (issue #4527).
  testWidgets('inside a card it is still a button of its own', (tester) async {
    final handle = tester.ensureSemantics();
    final controller = _controller()..unlock('Blue Corner');
    await tester.pumpWidget(_host(controller, inCard: true));

    final pencil = find.bySemanticsLabel('Edit Dive');
    expect(pencil, findsOneWidget);
    expect(
      tester.getSemantics(pencil),
      matchesSemantics(label: 'Edit Dive', isButton: true, hasTapAction: true),
    );
    // The card's own text stays its own, not part of a button.
    expect(
      tester.getSemantics(find.text('Blue Corner')),
      isNot(matchesSemantics(isButton: true)),
    );
    handle.dispose();
  });

  testWidgets('it is announced as a button named for the card', (tester) async {
    final handle = tester.ensureSemantics();
    final controller = _controller()..unlock('Blue Corner');
    await tester.pumpWidget(_host(controller));
    final l10n = AppLocalizations.of(
      tester.element(find.byType(RecordCardPencil)),
    );

    expect(
      tester.getSemantics(
        find.bySemanticsLabel(l10n.recordEdit_editCardTooltip('Dive')),
      ),
      matchesSemantics(
        isButton: true,
        hasTapAction: true,
        label: l10n.recordEdit_editCardTooltip('Dive'),
      ),
    );
    handle.dispose();
  });
}
