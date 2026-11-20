import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';
import 'package:submersion/shared/widgets/record_editing/add_strip.dart';
import 'package:submersion/shared/widgets/record_editing/edit_card.dart';
import 'package:submersion/shared/widgets/record_editing/edit_field.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';
import 'package:submersion/shared/widgets/record_editing/record_card_frame.dart';
import 'package:submersion/shared/widgets/record_editing/record_card_header.dart';
import 'package:submersion/shared/widgets/record_editing/record_creating.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_bar.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_host.dart';

/// A record small enough to show what a new record's page does for any
/// record type.
@immutable
class _Note {
  const _Note(this.id, this.text);

  final String id;
  final String text;

  @override
  bool operator ==(Object other) =>
      other is _Note && other.id == id && other.text == text;

  @override
  int get hashCode => Object.hash(id, text);
}

final _textField = EditField<_Note, String>(
  id: 'text',
  cardId: 'text',
  read: (note) => note.text,
  write: (note, text) => _Note(note.id, text),
);

final _textCard = EditCard<_Note>(
  id: 'text',
  title: (_) => 'Text',
  isEmpty: (note) => note.text.isEmpty,
  editorBuilder: (context, session) => TextFormField(
    key: const ValueKey('textEditor'),
    initialValue: session.valueOf(_textField),
    onChanged: (text) => session.set(_textField, text),
  ),
);

/// A card a note lays out only once its text is 'more'.
final _extraCard = EditCard<_Note>(
  id: 'extra',
  title: (_) => 'Extra',
  isEmpty: (note) => true,
  editorBuilder: (context, session) =>
      const Text('extra editor', key: ValueKey('extraEditor')),
);

/// What the page under test was asked to do, and how it answers.
class _Probe {
  final creates = <_Note>[];
  bool failCreate = false;
  bool seedGone = false;
  bool seedFails = false;

  /// Whether the seed reads the page's context, as a clone's name does.
  bool seedReadsContext = false;

  /// A prefill that sets 'A', then waits on [prefillGate], then sets 'AB'.
  bool prefill = false;
  final prefillGate = Completer<void>();

  bool afterThrows = false;
  Completer<void>? afterGate;
  final afterRan = <String>[];

  /// While set and not completed, the create is still being written.
  Completer<void>? createGate;
  final createdIds = <String>[];
  int cancelled = 0;

  /// What the question before a create answers, and what it was asked on.
  bool beforeCreateAnswer = true;
  final askedOn = <String>[];

  /// How many questions had been asked when what follows was captured.
  final askedWhenCaptured = <int>[];
}

final _probeProvider = Provider<_Probe>((ref) => throw UnimplementedError());

class _NewNotePage extends ConsumerStatefulWidget {
  const _NewNotePage({this.embedded = false});

  final bool embedded;

  @override
  ConsumerState<_NewNotePage> createState() => _NewNotePageState();
}

/// What the page has of its own for a stored note: never reached here.
mixin _NoteEditing on RecordEditHost<_NewNotePage, _Note> {
  @override
  String get hostRecordId => 'stored';

  @override
  _Note? get storedForUnlock => null;

  @override
  String editingTitle(_Note record) => 'Editing note';

  @override
  Future<void> saveSitting(EditSession<_Note> session) =>
      throw StateError('a stored note is never saved here');
}

class _NewNotePageState extends ConsumerState<_NewNotePage>
    with
        RecordEditHost<_NewNotePage, _Note>,
        _NoteEditing,
        RecordCreating<_NewNotePage, _Note> {
  _Probe get _probe => ref.read(_probeProvider);

  @override
  bool get isCreating => true;

  @override
  String recordIdOf(_Note record) => record.id;

  @override
  Iterable<EditCard<_Note>> get hostEditCards => [_textCard, _extraCard];

  @override
  Future<_Note?> rereadStored(
    ProviderContainer container,
    _Note stored,
  ) async => null;

  @override
  List<AddStripEntry> addStripEntries(_Note working) => const [];

  @override
  Future<_Note?> makeNewRecordSeed(RecordSeedRead read, String id) async {
    final probe = read(_probeProvider);
    if (probe.seedReadsContext) Localizations.localeOf(context);
    if (probe.seedFails) throw StateError('could not read');
    if (probe.seedGone) return null;
    return _Note(id, '');
  }

  @override
  List<String> newRecordLaidOut(_Note record) =>
      record.text == 'more' ? const ['text', 'extra'] : const ['text'];

  @override
  Future<void> applyNewRecordPrefill(EditSession<_Note> session) async {
    final probe = _probe;
    if (!probe.prefill) return;
    session.set(_textField, 'A');
    await probe.prefillGate.future;
    if (!session.isDisposed) session.set(_textField, 'AB');
  }

  @override
  Future<_Note> createRecord(EditSession<_Note> session) async {
    final probe = _probe;
    final note = session.applyTo(session.stored);
    probe.creates.add(note);
    await probe.createGate?.future;
    if (probe.failCreate) throw StateError('the create failed');
    return note;
  }

  @override
  Future<bool> beforeCreate(EditSession<_Note> session) async {
    final probe = _probe;
    probe.askedOn.add(session.working.text);
    return probe.beforeCreateAnswer;
  }

  @override
  Future<void> Function(_Note created) captureAfterRecordCreated() {
    // Read now: by the time the create commits the page may have gone.
    final probe = _probe;
    probe.askedWhenCaptured.add(probe.askedOn.length);
    return (created) async {
      await probe.afterGate?.future;
      if (probe.afterThrows) throw StateError('after failed');
      probe.afterRan.add(created.id);
    };
  }

  @override
  String newRecordTitle(BuildContext context) => 'New note';

  @override
  String get newRecordLeaveLocation => '/notes';

  @override
  bool get newRecordEmbedded => widget.embedded;

  @override
  void Function(String id)? get onNewRecordCreated => _probe.createdIds.add;

  @override
  VoidCallback? get onNewRecordCancelled =>
      () => _probe.cancelled++;

  @override
  ({String title, String body}) newRecordUnavailable(
    BuildContext context, {
    Object? error,
  }) => error != null
      ? (title: 'Note', body: 'Could not read: $error')
      : (title: 'Note', body: 'Not found');

  @override
  void dispose() {
    disposeEditing();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final waiting = newRecordWaiting(context);
    if (waiting != null) return waiting;
    final stored = shownStored(null)!;
    final shown = shownRecord(stored);
    final content = ListView(
      children: [
        RecordCardFrame<_Note>(
          card: _textCard,
          child: Column(
            children: [
              const RecordCardHeader(title: 'Text'),
              Text(shown.text, key: const ValueKey('text')),
            ],
          ),
        ),
        RecordCardFrame<_Note>(
          card: _extraCard,
          child: const RecordCardHeader(title: 'Extra'),
        ),
      ],
    );
    if (widget.embedded) {
      return editPane(
        header: editingPaneRow(shown, menu: const SizedBox.shrink()),
        shown: shown,
        content: content,
      );
    }
    return editScaffold(
      record: stored,
      shown: shown,
      lockedBar: AppBar(title: const Text('Note')),
      content: content,
    );
  }
}

/// A new record on its own page (issue #4527, phase 3, plan 11): the
/// shared part every record type's new-record page uses, tested on a
/// record of its own.
void main() {
  final l = AppLocalizationsEn();
  late _Probe probe;
  Object? popped;
  var poppedAtAll = false;

  Future<void> pump(
    WidgetTester tester, {
    bool embedded = false,
    void Function(_Probe probe)? setUp,
  }) async {
    probe = _Probe();
    setUp?.call(probe);
    popped = null;
    poppedAtAll = false;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [_probeProvider.overrideWithValue(probe)],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: embedded
              ? const Scaffold(body: _NewNotePage(embedded: true))
              : Builder(
                  builder: (context) => Scaffold(
                    body: TextButton(
                      onPressed: () async {
                        final result = await Navigator.of(context).push(
                          MaterialPageRoute<Object?>(
                            builder: (_) => const _NewNotePage(),
                          ),
                        );
                        poppedAtAll = true;
                        popped = result;
                      },
                      child: const Text('open'),
                    ),
                  ),
                ),
        ),
      ),
    );
    if (!embedded) {
      await tester.tap(find.text('open'));
    }
    await tester.pumpAndSettle();
  }

  Future<void> type(WidgetTester tester, String text) async {
    await tester.enterText(find.byKey(const ValueKey('textEditor')), text);
    await tester.pumpAndSettle();
  }

  Future<void> tapSave(WidgetTester tester) async {
    await tester.tap(find.text(l.forms_save));
    await tester.pumpAndSettle();
  }

  Future<void> tapCancel(WidgetTester tester) async {
    await tester.tap(find.text(l.forms_cancel));
    await tester.pumpAndSettle();
  }

  _NewNotePageState state(WidgetTester tester) =>
      tester.state<_NewNotePageState>(find.byType(_NewNotePage));

  testWidgets('a new record opens unlocked with its laid-out cards open', (
    tester,
  ) async {
    await pump(tester);

    expect(find.byType(RecordEditBar), findsOneWidget);
    expect(find.text('New note'), findsOneWidget);
    expect(find.byKey(const ValueKey('textEditor')), findsOneWidget);
  });

  testWidgets('Save waits for the first entry', (tester) async {
    await pump(tester);

    await tapSave(tester);
    expect(probe.creates, isEmpty);
    expect(find.byType(RecordEditBar), findsOneWidget);

    await type(tester, 'Calm');
    await tapSave(tester);
    expect(probe.creates.single.text, 'Calm');
  });

  testWidgets('a prefill is a change and Save waits for it', (tester) async {
    await pump(tester, setUp: (probe) => probe.prefill = true);

    // The first value is in: Save is enabled before the prefill has ended.
    await tester.tap(find.text(l.forms_save));
    await tester.pump();
    expect(probe.creates, isEmpty);

    probe.prefillGate.complete();
    await tester.pumpAndSettle();

    expect(probe.creates.single.text, 'AB');
  });

  testWidgets('an untouched new record leaves without asking', (tester) async {
    await pump(tester);

    await tapCancel(tester);

    expect(find.text(l.forms_discard_title), findsNothing);
    expect(find.byType(_NewNotePage), findsNothing);
    expect(poppedAtAll, isTrue);
    expect(popped, isNull);
    expect(probe.creates, isEmpty);
  });

  testWidgets('an entry asks before leaving', (tester) async {
    await pump(tester);
    await type(tester, 'Calm');

    await tapCancel(tester);
    expect(find.text(l.forms_discard_title), findsOneWidget);
    await tester.tap(find.text(l.forms_discard_keepEditing));
    await tester.pumpAndSettle();
    expect(find.byType(RecordEditBar), findsOneWidget);

    await tapCancel(tester);
    await tester.tap(find.text(l.forms_discard_discard));
    await tester.pumpAndSettle();
    expect(find.byType(_NewNotePage), findsNothing);
    expect(probe.creates, isEmpty);
  });

  testWidgets('Save creates the record and pops with its id', (tester) async {
    await pump(tester);
    await type(tester, 'Calm');

    await tapSave(tester);

    final created = probe.creates.single;
    expect(created.text, 'Calm');
    expect(created.id, isNotEmpty);
    expect(popped, created.id);
  });

  testWidgets('a question before the create is asked on what was entered, '
      'before what follows is captured', (tester) async {
    await pump(tester);
    await type(tester, 'Calm');

    await tapSave(tester);

    expect(probe.askedOn, ['Calm']);
    expect(probe.askedWhenCaptured, [1]);
    expect(probe.creates.single.text, 'Calm');
  });

  testWidgets('a create declined before it is written creates nothing and '
      'keeps the page', (tester) async {
    await pump(tester, setUp: (probe) => probe.beforeCreateAnswer = false);
    await type(tester, 'Calm');

    await tapSave(tester);

    expect(probe.askedOn, ['Calm']);
    expect(probe.creates, isEmpty);
    expect(find.byType(RecordEditBar), findsOneWidget);
    expect(popped, isNull);
  });

  testWidgets('a change that lays out another card opens it', (tester) async {
    await pump(tester);
    expect(find.byKey(const ValueKey('extraEditor')), findsNothing);

    await type(tester, 'more');

    expect(find.byKey(const ValueKey('extraEditor')), findsOneWidget);
  });

  testWidgets('a pane create calls onCreated and never pops', (tester) async {
    await pump(tester, embedded: true);
    await type(tester, 'Calm');

    await tester.tap(find.text(l.forms_save));
    // The pane moves on in the app; here the page waits, spinning.
    await tester.pump(const Duration(milliseconds: 500));

    expect(probe.createdIds, [probe.creates.single.id]);
    expect(find.byType(_NewNotePage), findsOneWidget);
  });

  testWidgets('a pane Cancel tells the pane', (tester) async {
    await pump(tester, embedded: true);

    await tester.tap(find.text(l.forms_cancel));
    await tester.pump(const Duration(milliseconds: 500));

    expect(probe.cancelled, 1);
  });

  testWidgets('a Save that fails keeps everything, and a retry creates once', (
    tester,
  ) async {
    await pump(tester, setUp: (probe) => probe.failCreate = true);
    await type(tester, 'Calm');

    await tapSave(tester);
    expect(find.text(l.recordEdit_saveFailed), findsOneWidget);
    expect(find.byType(RecordEditBar), findsOneWidget);
    expect(find.text('Calm'), findsWidgets);

    probe.failCreate = false;
    await tapSave(tester);

    expect(probe.creates, hasLength(2));
    expect(probe.creates.last.id, probe.creates.first.id);
    expect(popped, probe.creates.first.id);
  });

  testWidgets('a seed that is gone says so, with no bar', (tester) async {
    await pump(tester, setUp: (probe) => probe.seedGone = true);

    expect(find.text('Not found'), findsOneWidget);
    expect(find.byType(RecordEditBar), findsNothing);
  });

  testWidgets('a seed whose read fails says so', (tester) async {
    await pump(tester, setUp: (probe) => probe.seedFails = true);

    expect(
      find.text('Could not read: Bad state: could not read'),
      findsOneWidget,
    );
    expect(find.byType(RecordEditBar), findsNothing);
  });

  testWidgets('a sitting ended by locking leaves', (tester) async {
    await pump(tester);

    state(tester).editController.lock();
    await tester.pumpAndSettle();

    expect(find.byType(_NewNotePage), findsNothing);
    expect(probe.creates, isEmpty);
  });

  testWidgets('a sitting ended by the leave check does not leave again', (
    tester,
  ) async {
    await pump(tester);

    state(tester)
      ..sittingEndedByLeave = true
      ..editController.lock();
    await tester.pumpAndSettle();

    expect(find.byType(_NewNotePage), findsOneWidget);
    expect(poppedAtAll, isFalse);
  });

  testWidgets('a throw after the create still leaves with the record', (
    tester,
  ) async {
    await pump(tester, setUp: (probe) => probe.afterThrows = true);
    await type(tester, 'Calm');

    await tapSave(tester);

    expect(popped, probe.creates.single.id);
  });

  testWidgets('Back is held while the created record is handed on', (
    tester,
  ) async {
    await pump(tester, setUp: (probe) => probe.afterGate = Completer());
    await type(tester, 'Calm');

    await tester.tap(find.text(l.forms_save));
    // Handing on shows a spinner, which never settles.
    await tester.pump(const Duration(milliseconds: 500));
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    await navigator.maybePop();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(_NewNotePage), findsOneWidget);
    expect(poppedAtAll, isFalse);

    probe.afterGate!.complete();
    await tester.pumpAndSettle();
    expect(popped, probe.creates.single.id);
  });
  testWidgets('pushed without the router inside a routed app, it pops its id', (
    tester,
  ) async {
    probe = _Probe();
    Object? result;
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, _) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await Navigator.of(context).push<Object?>(
                  MaterialPageRoute<Object?>(
                    builder: (_) => const _NewNotePage(),
                  ),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [_probeProvider.overrideWithValue(probe)],
        child: MaterialApp.router(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await type(tester, 'Calm');

    await tapSave(tester);

    expect(result, probe.creates.single.id);
  });
  testWidgets('what follows a create runs even once the page has gone', (
    tester,
  ) async {
    await pump(tester, setUp: (probe) => probe.createGate = Completer());
    await type(tester, 'Calm');
    await tester.tap(find.text(l.forms_save));
    await tester.pump();

    // The app moves elsewhere while the create is being written.
    await tester.pumpWidget(const SizedBox.shrink());
    probe.createGate!.complete();
    await tester.pumpAndSettle();

    expect(probe.afterRan, [probe.creates.single.id]);
  });

  testWidgets('system Back on an untouched new record leaves once', (
    tester,
  ) async {
    await pump(tester);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.byType(_NewNotePage), findsNothing);
    expect(find.text('open'), findsOneWidget);
    expect(probe.creates, isEmpty);
  });

  testWidgets('system Back with an entry asks, then leaves once', (
    tester,
  ) async {
    await pump(tester);
    await type(tester, 'Calm');

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text(l.forms_discard_title), findsOneWidget);
    await tester.tap(find.text(l.forms_discard_discard));
    await tester.pumpAndSettle();

    expect(find.byType(_NewNotePage), findsNothing);
    expect(find.text('open'), findsOneWidget);
    expect(probe.creates, isEmpty);
  });

  testWidgets('pushed without the router inside a shell, it pops its id', (
    tester,
  ) async {
    probe = _Probe();
    Object? result;
    final router = GoRouter(
      routes: [
        ShellRoute(
          builder: (context, state, child) => Scaffold(body: child),
          routes: [
            GoRoute(
              path: '/',
              builder: (context, _) => TextButton(
                onPressed: () async {
                  result = await Navigator.of(context).push<Object?>(
                    MaterialPageRoute<Object?>(
                      builder: (_) => const _NewNotePage(),
                    ),
                  );
                },
                child: const Text('open'),
              ),
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [_probeProvider.overrideWithValue(probe)],
        child: MaterialApp.router(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await type(tester, 'Calm');

    await tapSave(tester);

    expect(result, probe.creates.single.id);
    expect(find.text('open'), findsOneWidget);
  });

  group('heldWritesForCreate', () {
    test('runs the writes held before the record, then the rest', () async {
      final session = EditSession(const _Note('n1', ''), isNew: true);
      addTearDown(session.dispose);
      final order = <String>[];
      session
        ..holdChange('after', cardId: 'text', write: () async => order.add('b'))
        ..holdChange(
          'before',
          cardId: 'text',
          beforeRecord: true,
          write: () async => order.add('a'),
        );

      await heldWritesForCreate(session)!();

      expect(order, ['a', 'b']);
    });

    test('is null with nothing held', () {
      final session = EditSession(const _Note('n1', ''), isNew: true);
      addTearDown(session.dispose);

      expect(heldWritesForCreate(session), isNull);
    });
  });
  testWidgets('a seed may read the page context', (tester) async {
    await pump(tester, setUp: (probe) => probe.seedReadsContext = true);

    expect(find.byType(RecordEditBar), findsOneWidget);
    expect(find.text('Could not read'), findsNothing);
  });
}
