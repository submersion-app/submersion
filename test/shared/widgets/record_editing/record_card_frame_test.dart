import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/record_editing/edit_card.dart';
import 'package:submersion/shared/widgets/record_editing/edit_field.dart';
import 'package:submersion/shared/widgets/record_editing/record_card_frame.dart';
import 'package:submersion/shared/widgets/record_editing/record_card_header.dart';
import 'package:submersion/shared/widgets/record_editing/record_card_pencil.dart';
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

Widget _host(RecordEditController<_Rec>? controller, {TextScaler? textScaler}) {
  final frame = RecordCardFrame<_Rec>(card: _card, child: _readCard);
  return MaterialApp(
    builder: textScaler == null
        ? null
        : (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: textScaler),
            child: child!,
          ),
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

/// The frame 600 px down a page seen through a 300 px high window, so it
/// starts out of sight. [showFrame] leaves the frame out, to mount it later.
Widget _tallHost(
  RecordEditController<_Rec> controller, {
  bool showFrame = true,
}) {
  return MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: Align(
        alignment: Alignment.topCenter,
        child: SizedBox(
          height: 300,
          child: RecordEditScope<_Rec>(
            controller: controller,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 600),
                  if (showFrame)
                    RecordCardFrame<_Rec>(card: _card, child: _readCard),
                  const SizedBox(height: 600),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

/// A page seen through a 300 px high window, with the card 600 px down it
/// so it starts out of sight. Like the dive page, it builds the card only
/// once it has been added from the strip.
Widget _addedHost(RecordEditController<_Rec> controller) {
  return MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: Align(
        alignment: Alignment.topCenter,
        child: SizedBox(
          height: 300,
          child: RecordEditScope<_Rec>(
            controller: controller,
            child: Builder(
              builder: (context) {
                final edit = RecordEditScope.maybeOf<_Rec>(context)!;
                return SingleChildScrollView(
                  child: Column(
                    children: [
                      const SizedBox(height: 600),
                      if (edit.addedCardIds.contains(_card.id))
                        RecordCardFrame<_Rec>(
                          card: _card,
                          child: const SizedBox.shrink(),
                        ),
                      const SizedBox(height: 600),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    ),
  );
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
    expect(find.byType(RecordPencilDisc), findsNothing);
    expect(find.text('Done'), findsNothing);
  });

  testWidgets(
    'an open card keeps the gap a self-spacing read card places above itself',
    (tester) async {
      final controller = _controller()..unlock(const _Rec());
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: RecordEditScope<_Rec>(
              controller: controller,
              child: Column(
                children: [
                  RecordCardFrame<_Rec>(
                    key: const ValueKey('frame'),
                    card: _card,
                    topGap: 24,
                    child: const SizedBox(height: 40),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      controller.openCard(_card.id);
      await tester.pumpAndSettle();

      final frameTop = tester.getTopLeft(find.byKey(const ValueKey('frame')));
      final cardTop = tester.getTopLeft(
        find.descendant(
          of: find.byKey(const ValueKey('frame')),
          matching: find.byType(Card),
        ),
      );
      expect(cardTop.dy - frameTop.dy, 24);
    },
  );

  testWidgets('locked: the card reads as before', (tester) async {
    await tester.pumpWidget(_host(_controller()));

    expect(find.text('READ'), findsOneWidget);
    expect(find.text('3 tags'), findsOneWidget);
    expect(find.byType(RecordPencilDisc), findsNothing);
  });

  testWidgets('unlocked: the header gains a pencil and keeps its trailing', (
    tester,
  ) async {
    final controller = _controller();
    await tester.pumpWidget(_host(controller));

    controller.unlock(const _Rec());
    await tester.pump();

    expect(find.byTooltip('Edit Notes'), findsOneWidget);
    expect(find.byType(RecordPencilDisc), findsOneWidget);
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

  // The header's own right edge is where the pencil and Done belong, with
  // whatever the card shows while reading just before the pencil.
  // The pencil is no taller than the title's line at any system text size
  // up to 100%, so a smaller one does not make unlocking grow the row.
  testWidgets('at a small text size, unlocking keeps the header\'s height', (
    tester,
  ) async {
    final controller = _controller();
    await tester.pumpWidget(
      _host(controller, textScaler: const TextScaler.linear(0.85)),
    );
    final header = find.byType(RecordCardHeader);
    final before = tester.getSize(header);

    controller.unlock(const _Rec());
    await tester.pump();

    expect(find.byType(RecordPencilDisc), findsOneWidget);
    expect(tester.getSize(header), before);
  });

  testWidgets('the pencil sits at the right edge, after the trailing', (
    tester,
  ) async {
    final controller = _controller()..unlock(const _Rec());
    await tester.pumpWidget(_host(controller));

    final header = tester.getRect(find.byType(RecordCardHeader));
    final pencil = tester.getRect(find.byType(RecordPencilDisc));
    final trailing = tester.getRect(find.text('3 tags'));
    expect(pencil.right, header.right);
    expect(trailing.right, lessThan(pencil.left));
    expect(pencil.left - trailing.right, lessThan(16));
    expect(tester.getRect(find.text('Notes')).left, header.left);
  });

  testWidgets('Done sits at the right edge of an open card', (tester) async {
    final controller = _controller()
      ..unlock(const _Rec())
      ..openCard('notes');
    await tester.pumpWidget(_host(controller));

    final header = tester.getRect(find.byType(RecordCardHeader));
    final done = tester.getRect(find.widgetWithText(TextButton, 'Done'));
    expect(done.right, header.right);
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
    expect(find.byType(RecordPencilDisc), findsNothing);
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
    expect(find.byType(RecordPencilDisc), findsOneWidget);
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
    expect(find.byType(RecordPencilDisc), findsNothing);
  });

  // Some cards carry an icon before their title (Altitude). It stays put in
  // every state of the header.
  group('a header with a leading widget', () {
    Widget host(RecordCardFrameData? data) => MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: RecordCardFrameScope(
          data: data,
          child: const RecordCardHeader(
            leading: Icon(Icons.terrain),
            title: 'Altitude',
            trailing: Text('info'),
          ),
        ),
      ),
    );

    RecordCardFrameData frame({required bool isOpen}) => RecordCardFrameData(
      isOpen: isOpen,
      isChanged: true,
      onOpen: () {},
      onDone: () {},
    );

    void expectLeadingBeforeTitle(WidgetTester tester) {
      final leading = tester.getRect(find.byIcon(Icons.terrain));
      final title = tester.getRect(find.text('Altitude'));
      expect(leading.left, 0);
      expect(leading.right, lessThanOrEqualTo(title.left));
    }

    testWidgets('locked: it sits before the title, trailing at the right', (
      tester,
    ) async {
      await tester.pumpWidget(host(null));

      expectLeadingBeforeTitle(tester);
      expect(tester.getRect(find.text('info')).right, 800);
    });

    testWidgets('unlocked: it sits before the title, the pencil at the right', (
      tester,
    ) async {
      await tester.pumpWidget(host(frame(isOpen: false)));

      expectLeadingBeforeTitle(tester);
      expect(tester.getRect(find.byType(RecordPencilDisc)).right, 800);
      expect(find.text('info'), findsOneWidget);
    });

    testWidgets('open: it sits before the title, Done at the right', (
      tester,
    ) async {
      await tester.pumpWidget(host(frame(isOpen: true)));

      expectLeadingBeforeTitle(tester);
      expect(find.text('Done'), findsOneWidget);
    });

    // The first keystroke in an open card marks it changed. If the dot then
    // took room from the title, a title that only just fitted would wrap,
    // and everything in the card would jump down a line under the diver.
    testWidgets('the dot arriving does not reflow the title', (tester) async {
      Widget at(RecordCardFrameData data) => MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            // Wide enough for the title beside Done, with nothing to spare.
            child: SizedBox(
              width: 300,
              child: RecordCardFrameScope(
                data: data,
                child: const RecordCardHeader(title: 'Altitude Dive'),
              ),
            ),
          ),
        ),
      );
      RecordCardFrameData open({required bool isChanged}) =>
          RecordCardFrameData(
            isOpen: true,
            isChanged: isChanged,
            onOpen: () {},
            onDone: () {},
          );

      await tester.pumpWidget(at(open(isChanged: false)));
      final clean = tester.getRect(find.text('Altitude Dive'));
      final height = tester.getSize(find.byType(RecordCardHeader)).height;

      await tester.pumpWidget(at(open(isChanged: true)));

      expect(find.byType(RecordChangedDot), findsOneWidget);
      expect(tester.getRect(find.text('Altitude Dive')), clean);
      expect(tester.getSize(find.byType(RecordCardHeader)).height, height);
    });

    testWidgets('a header with none keeps its title at the left edge', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: RecordCardHeader(title: 'Notes')),
        ),
      );

      expect(tester.getRect(find.text('Notes')).left, 0);
    });
  });

  group('a card asked to show itself', () {
    const editor = ValueKey('editor');

    // A refusal for unreadable input names the field. Its own row scrolls
    // itself into view, which may be far below the top of a tall card.
    testWidgets('a request that names a field is left to that field', (
      tester,
    ) async {
      final controller = _controller()
        ..unlock(const _Rec())
        ..openCard('notes');
      await tester.pumpWidget(_tallHost(controller));
      expect(tester.getRect(find.byKey(editor)).top, greaterThan(300));

      controller
        ..setFieldInvalid('notes', 'notes', invalid: true)
        ..closeCard('notes');
      await tester.pumpAndSettle();

      expect(tester.getRect(find.byKey(editor)).top, greaterThan(300));
      expect(controller.revealRequest, isNotNull, reason: 'not answered');
    });

    testWidgets('a card added from the strip scrolls into view', (
      tester,
    ) async {
      final controller = _controller()..unlock(const _Rec());
      await tester.pumpWidget(_addedHost(controller));
      expect(find.byKey(editor), findsNothing);

      controller.addCard('notes');
      await tester.pumpAndSettle();

      final rect = tester.getRect(find.byKey(editor));
      expect(rect.top, greaterThanOrEqualTo(0));
      expect(rect.bottom, lessThanOrEqualTo(300));
      expect(controller.revealRequest, isNull, reason: 'answered');
    });

    testWidgets('it is shown once: scrolling away afterwards is left alone', (
      tester,
    ) async {
      final controller = _controller()..unlock(const _Rec());
      await tester.pumpWidget(_addedHost(controller));
      controller.addCard('notes');
      await tester.pumpAndSettle();

      tester.state<ScrollableState>(find.byType(Scrollable)).position.jumpTo(0);
      // Anything that rebuilds the page: the old request must not replay.
      controller.session!.set(_notes, 'b');
      await tester.pumpAndSettle();

      expect(tester.getRect(find.byKey(editor)).top, greaterThan(300));
    });

    testWidgets('a card with no scrollable above it does nothing', (
      tester,
    ) async {
      final controller = _controller()..unlock(const _Rec());
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: RecordEditScope<_Rec>(
              controller: controller,
              child: RecordCardFrame<_Rec>(card: _card, child: _readCard),
            ),
          ),
        ),
      );

      controller.addCard('notes');
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byKey(editor), findsOneWidget);
    });
  });

  group('the header', () {
    Widget at(double width, Widget header) => MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(width: width, child: header),
        ),
      ),
    );

    // The first keystroke in an open card marks it changed. If the dot then
    // took room from the title, a title that only just fitted would wrap,
    // and everything in the card would jump down a line under the diver.
    testWidgets('the dot arriving does not reflow the title', (tester) async {
      // Wide enough for the title beside Done, with nothing to spare.
      Widget open({required bool isChanged}) => at(
        300,
        RecordCardFrameScope(
          data: RecordCardFrameData(
            isOpen: true,
            isChanged: isChanged,
            onOpen: () {},
            onDone: () {},
          ),
          child: const RecordCardHeader(title: 'Altitude Dive'),
        ),
      );

      await tester.pumpWidget(open(isChanged: false));
      final clean = tester.getRect(find.text('Altitude Dive'));
      final height = tester.getSize(find.byType(RecordCardHeader)).height;

      await tester.pumpWidget(open(isChanged: true));

      expect(find.byType(RecordChangedDot), findsOneWidget);
      expect(tester.getRect(find.text('Altitude Dive')), clean);
      expect(tester.getSize(find.byType(RecordCardHeader)).height, height);
    });

    // Locked is how every card reads in a released build.
    testWidgets('locked: a title too long for the card wraps', (tester) async {
      const title = 'A card title that is too long';
      await tester.pumpWidget(
        at(200, const RecordCardHeader(title: title, trailing: Text('3'))),
      );

      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.text(title)).width, lessThanOrEqualTo(200));
      expect(tester.getRect(find.text('3')).right, 200);
    });

    testWidgets('unlocked and closed, the row is announced as a button', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      final controller = _controller()..unlock(const _Rec());
      await tester.pumpWidget(_host(controller));

      final row = tester.getSemantics(find.text('Notes'));
      expect(row.flagsCollection.isButton, isTrue);

      semantics.dispose();
    });

    // The header is a button of its own: in the Card it would otherwise
    // merge into the card's node, and the whole card would be one button
    // named for everything it says (issue #4527).
    testWidgets('unlocked, the header button leaves the card body its own', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      final controller = _controller()..unlock(const _Rec());
      await tester.pumpWidget(_host(controller));

      final row = tester.getSemantics(find.text('Notes'));
      expect(row.label, isNot(contains('READ')));
      expect(
        tester.getSemantics(find.text('READ')).flagsCollection.isButton,
        isFalse,
      );

      semantics.dispose();
    });
  });
}
