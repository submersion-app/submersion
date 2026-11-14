import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/record_editing/edit_card.dart';
import 'package:submersion/shared/widgets/record_editing/edit_field.dart';
import 'package:submersion/shared/widgets/record_editing/record_card_frame.dart';
import 'package:submersion/shared/widgets/record_editing/record_card_header.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_controller.dart';

@immutable
class _Rec {
  const _Rec({this.notes = ''});

  final String notes;

  @override
  bool operator ==(Object other) => other is _Rec && other.notes == notes;

  @override
  int get hashCode => notes.hashCode;
}

final _notes = EditField<_Rec, String>(
  id: 'notes',
  cardId: 'notes',
  read: (r) => r.notes,
  write: (r, v) => _Rec(notes: v),
);

final _card = EditCard<_Rec>(
  id: 'notes',
  title: (_) => 'Notes',
  isEmpty: (_) => false,
  editorBuilder: (_, session) => const Text('EDITOR', key: ValueKey('editor')),
);

/// Counts how often the card's read widget is created, to show unlocking
/// keeps it mounted.
class _ReadBody extends StatefulWidget {
  const _ReadBody();

  static int created = 0;

  @override
  State<_ReadBody> createState() => _ReadBodyState();
}

class _ReadBodyState extends State<_ReadBody> {
  @override
  void initState() {
    super.initState();
    _ReadBody.created++;
  }

  @override
  Widget build(BuildContext context) => const Text('READ');
}

const _readCard = Card(
  key: ValueKey('readCard'),
  child: Padding(
    padding: EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        RecordCardHeader(title: 'Notes', trailing: Text('3 tags')),
        Divider(),
        _ReadBody(),
      ],
    ),
  ),
);

Widget _host(RecordEditController<_Rec>? controller) {
  final frame = RecordCardFrame<_Rec>(card: _card, child: _readCard);
  return MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: SingleChildScrollView(
        child: controller == null
            ? frame
            : RecordEditScope<_Rec>(controller: controller, child: frame),
      ),
    ),
  );
}

RecordEditController<_Rec> _controller() {
  final controller = RecordEditController<_Rec>(onSave: (_) async {});
  addTearDown(controller.dispose);
  return controller;
}

void main() {
  setUp(() => _ReadBody.created = 0);

  testWidgets('with no controller above it the card reads as before', (
    tester,
  ) async {
    await tester.pumpWidget(_host(null));

    expect(find.text('READ'), findsOneWidget);
    expect(find.text('Notes'), findsOneWidget);
    expect(find.text('3 tags'), findsOneWidget);
    expect(find.byIcon(Icons.edit_outlined), findsNothing);
    expect(find.text('Done'), findsNothing);
  });

  testWidgets('locked: the card reads as before', (tester) async {
    await tester.pumpWidget(_host(_controller()));

    expect(find.text('READ'), findsOneWidget);
    expect(find.text('3 tags'), findsOneWidget);
    expect(find.byIcon(Icons.edit_outlined), findsNothing);
  });

  testWidgets('unlocked: the header gains a pencil and keeps its trailing', (
    tester,
  ) async {
    final controller = _controller();
    await tester.pumpWidget(_host(controller));

    controller.unlock(const _Rec());
    await tester.pump();

    expect(find.byTooltip('Edit Notes'), findsOneWidget);
    expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
    expect(find.text('3 tags'), findsOneWidget);
    expect(find.text('READ'), findsOneWidget);
  });

  testWidgets('unlocking neither resizes nor remounts the card', (
    tester,
  ) async {
    final controller = _controller();
    await tester.pumpWidget(_host(controller));
    final card = find.byKey(const ValueKey('readCard'));
    final before = tester.getSize(card);
    expect(_ReadBody.created, 1);

    controller.unlock(const _Rec());
    await tester.pump();

    expect(tester.getSize(card), before);
    expect(_ReadBody.created, 1);
  });

  testWidgets('tapping the header opens the editor in place', (tester) async {
    final controller = _controller()..unlock(const _Rec());
    await tester.pumpWidget(_host(controller));

    await tester.tap(find.text('Notes'));
    await tester.pump();

    expect(controller.openCardIds, {'notes'});
    expect(find.byKey(const ValueKey('editor')), findsOneWidget);
    expect(find.text('READ'), findsNothing);
    expect(find.text('Notes'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);
    expect(find.byIcon(Icons.edit_outlined), findsNothing);
  });

  testWidgets('Done closes the card back to its read layout', (tester) async {
    final controller = _controller()
      ..unlock(const _Rec())
      ..openCard('notes');
    await tester.pumpWidget(_host(controller));

    await tester.tap(find.text('Done'));
    await tester.pump();

    expect(controller.openCardIds, isEmpty);
    expect(find.text('READ'), findsOneWidget);
    expect(find.byKey(const ValueKey('editor')), findsNothing);
    expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
  });

  // Closed, the header row is one tap target and the dot's label is read
  // as part of it; open, it stands alone. Either way it is announced.
  testWidgets('a changed card shows the dot, closed and open', (tester) async {
    final semantics = tester.ensureSemantics();
    final controller = _controller()..unlock(const _Rec());
    await tester.pumpWidget(_host(controller));
    expect(find.bySemanticsLabel(RegExp('Unsaved changes')), findsNothing);

    controller.session!.set(_notes, 'b');
    await tester.pump();
    expect(find.bySemanticsLabel(RegExp('Unsaved changes')), findsOneWidget);

    controller.openCard('notes');
    await tester.pump();
    expect(find.bySemanticsLabel(RegExp('Unsaved changes')), findsOneWidget);

    semantics.dispose();
  });

  testWidgets('an open card has the accent outline', (tester) async {
    final controller = _controller()
      ..unlock(const _Rec())
      ..openCard('notes');
    await tester.pumpWidget(_host(controller));

    final card = tester.widget<Card>(find.byType(Card));
    final shape = card.shape! as RoundedRectangleBorder;
    final scheme = Theme.of(tester.element(find.byType(Card))).colorScheme;
    expect(shape.side.color, scheme.primary);
    expect(shape.side.width, 2);
  });

  testWidgets('locking an open card puts the read layout back', (tester) async {
    final controller = _controller()
      ..unlock(const _Rec())
      ..openCard('notes');
    await tester.pumpWidget(_host(controller));

    controller.lock();
    await tester.pump();

    expect(find.text('READ'), findsOneWidget);
    expect(find.byKey(const ValueKey('editor')), findsNothing);
    expect(find.byIcon(Icons.edit_outlined), findsNothing);
  });
}
