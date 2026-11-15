import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/record_editing/edit_card.dart';
import 'package:submersion/shared/widgets/record_editing/edit_field.dart';
import 'package:submersion/shared/widgets/record_editing/record_card_frame.dart';
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
Widget _host(RecordEditController<String>? controller) {
  const row = Row(
    children: [
      Expanded(child: Text('Blue Corner')),
      RecordCardPencil(cardTitle: 'Dive'),
    ],
  );
  return MaterialApp(
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

    expect(find.byIcon(Icons.edit_outlined), findsNothing);
    expect(tester.getSize(find.byType(RecordCardPencil)), Size.zero);
  });

  testWidgets('locked it draws nothing and takes no room', (tester) async {
    await tester.pumpWidget(_host(_controller()));

    expect(find.byIcon(Icons.edit_outlined), findsNothing);
    expect(tester.getSize(find.byType(RecordCardPencil)), Size.zero);
  });

  testWidgets('unlocked and closed, a pencil that opens the card', (
    tester,
  ) async {
    final controller = _controller()..unlock('Blue Corner');
    await tester.pumpWidget(_host(controller));

    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pump();

    expect(controller.openCardIds, {'header'});
    expect(find.text('editor'), findsOneWidget);
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
