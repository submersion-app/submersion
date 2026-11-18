import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/app/app_exit_guard.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';
import 'package:submersion/shared/widgets/record_editing/add_strip.dart';
import 'package:submersion/shared/widgets/record_editing/edit_card.dart';
import 'package:submersion/shared/widgets/record_editing/edit_field.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';
import 'package:submersion/shared/widgets/record_editing/record_card_frame.dart';
import 'package:submersion/shared/widgets/record_editing/record_card_header.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_bar.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_host.dart';
import 'package:submersion/shared/widgets/record_editing/record_sitting_refusal.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_pane_header.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_shortcuts.dart';

/// A record small enough to show what the host does for any record page.
@immutable
class _Note {
  const _Note(this.id, this.title, this.text);

  final String id;
  final String title;
  final String text;

  @override
  bool operator ==(Object other) =>
      other is _Note &&
      other.id == id &&
      other.title == title &&
      other.text == text;

  @override
  int get hashCode => Object.hash(id, title, text);
}

final _textField = EditField<_Note, String>(
  id: 'text',
  cardId: 'text',
  read: (note) => note.text,
  write: (note, text) => _Note(note.id, note.title, text),
);

final _textCard = EditCard<_Note>(
  id: 'text',
  title: (_) => 'Text',
  isEmpty: (_) => false,
  editorBuilder: (context, session) => TextFormField(
    key: const ValueKey('textEditor'),
    initialValue: session.valueOf(_textField),
    onChanged: (text) => session.set(_textField, text),
  ),
);

/// The stored notes, by id, and what the page under test was asked to do.
class _Probe {
  final notes = <String, _Note>{
    'n1': const _Note('n1', 'First', 'Calm'),
    'n2': const _Note('n2', 'Second', 'Flat'),
  };
  final saves = <Set<String>>[];
  bool failSave = false;
  Object? refuseWith;
}

final _probeProvider = Provider<_Probe>((ref) => throw UnimplementedError());

final _noteProvider = FutureProvider.family<_Note?, String>(
  (ref, id) async => ref.watch(_probeProvider).notes[id],
);

class _NotePage extends ConsumerStatefulWidget {
  const _NotePage({
    required this.noteId,
    this.embedded = false,
    this.offersEditing = true,
    this.hostsEditing = true,
    this.stripEntry = false,
  });

  final String noteId;
  final bool embedded;
  final bool offersEditing;
  final bool hostsEditing;
  final bool stripEntry;

  @override
  ConsumerState<_NotePage> createState() => _NotePageState();
}

class _NotePageState extends ConsumerState<_NotePage>
    with RecordEditHost<_NotePage, _Note> {
  @override
  String get hostRecordId => widget.noteId;

  @override
  String recordIdOf(_Note record) => record.id;

  @override
  bool get offersEditing => widget.offersEditing;

  @override
  bool get hostsEditing => widget.hostsEditing;

  @override
  Iterable<EditCard<_Note>> get hostEditCards => [_textCard];

  @override
  _Note? get storedForUnlock => ref.read(_noteProvider(widget.noteId)).value;

  @override
  Future<void> saveSitting(EditSession<_Note> session) async {
    final probe = ref.read(_probeProvider);
    probe.saves.add(session.changedCardIds);
    if (probe.failSave) throw StateError('the save failed');
    if (probe.refuseWith case final refusal?) throw refusal;
    justSavedRecord = session.working;
  }

  @override
  Future<_Note?> rereadStored(ProviderContainer container, _Note stored) =>
      container.read(_noteProvider(stored.id).future);

  @override
  String editingTitle(_Note record) => 'Editing ${record.title}';

  @override
  List<AddStripEntry> addStripEntries(_Note working) => [
    if (widget.stripEntry) const AddStripEntry(cardId: 'extra', label: 'Extra'),
  ];

  @override
  void dispose() {
    disposeEditing();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    followStored(_noteProvider(widget.noteId));
    final stored = ref.watch(_noteProvider(widget.noteId)).value;
    if (stored == null) return const SizedBox.shrink();
    final shown = shownRecord(stored);
    final content = ListView(
      children: [
        Text(shown.title, key: const ValueKey('title')),
        RecordCardFrame<_Note>(
          card: _textCard,
          child: Column(
            children: [
              const RecordCardHeader(title: 'Text'),
              Text(shown.text, key: const ValueKey('text')),
            ],
          ),
        ),
      ],
    );
    if (!hostsEditing) {
      return Scaffold(
        appBar: AppBar(title: Text(shown.title)),
        body: content,
      );
    }
    if (widget.embedded) {
      final header = isSittingOpen
          ? editingPaneRow(shown, menu: const SizedBox.shrink())
          : Row(children: [Text(shown.title), lockButton(shown)]);
      return editPane(header: header, shown: shown, content: content);
    }
    return editScaffold(
      record: stored,
      shown: shown,
      lockedBar: AppBar(
        title: Text(shown.title),
        actions: [if (offersEditing) lockButton(shown)],
      ),
      content: content,
    );
  }
}

/// The page, with a way to hand it another note.
class _Host extends StatefulWidget {
  const _Host({required this.page});

  final _NotePage page;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  late _NotePage page = widget.page;

  void show(_NotePage next) => setState(() => page = next);

  @override
  Widget build(BuildContext context) =>
      widget.page.embedded ? Scaffold(body: page) : page;
}

/// The page shared by every record type that edits in place (issue #4527):
/// the lock, the bar, the strip, the leave check, the keys and following
/// the stored record, tested on a record of its own.
void main() {
  final l = AppLocalizationsEn();
  late _Probe probe;
  late ProviderContainer container;

  Future<void> pump(WidgetTester tester, _NotePage page) async {
    probe = _Probe();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [_probeProvider.overrideWithValue(probe)],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: _Host(page: page),
        ),
      ),
    );
    await tester.pumpAndSettle();
    container = ProviderScope.containerOf(tester.element(find.byType(_Host)));
  }

  Future<void> unlock(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.lock_outline));
    await tester.pumpAndSettle();
  }

  Future<void> editText(WidgetTester tester, String text) async {
    await tester.tap(find.text('Text'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('textEditor')), text);
    await tester.pumpAndSettle();
  }

  Future<void> storeNote(_Note note) async {
    probe.notes[note.id] = note;
    container.invalidate(_noteProvider(note.id));
  }

  testWidgets('locked shows the lock and no edit bar', (tester) async {
    await pump(tester, const _NotePage(noteId: 'n1'));

    expect(find.byIcon(Icons.lock_outline), findsOneWidget);
    expect(find.byType(RecordEditBar), findsNothing);
  });

  testWidgets('unlocking swaps the bar and titles it', (tester) async {
    await pump(tester, const _NotePage(noteId: 'n1'));
    await unlock(tester);

    expect(find.byType(RecordEditBar), findsOneWidget);
    expect(find.text('Editing First'), findsOneWidget);
  });

  testWidgets('a change enables Save, and Save writes the sitting and locks', (
    tester,
  ) async {
    await pump(tester, const _NotePage(noteId: 'n1'));
    await unlock(tester);
    await editText(tester, 'Choppy');

    await tester.tap(find.text(l.forms_save));
    await tester.pumpAndSettle();

    expect(probe.saves, [
      {'text'},
    ]);
    expect(find.byType(RecordEditBar), findsNothing);
    // Shown as saved before the stored note is read back.
    expect(find.text('Choppy'), findsOneWidget);
  });

  testWidgets('a failed save stays unlocked and says so', (tester) async {
    await pump(tester, const _NotePage(noteId: 'n1'));
    await unlock(tester);
    await editText(tester, 'Choppy');
    probe.failSave = true;

    await tester.tap(find.text(l.forms_save));
    await tester.pumpAndSettle();

    expect(find.text(l.recordEdit_saveFailed), findsOneWidget);
    expect(find.byType(RecordEditBar), findsOneWidget);
    expect(find.text('Choppy'), findsOneWidget);
  });

  testWidgets('a refused held write shows its own message', (tester) async {
    await pump(tester, const _NotePage(noteId: 'n1'));
    await unlock(tester);
    await editText(tester, 'Choppy');
    probe.refuseWith = RecordSittingRefusal((_) => 'Refused here');

    await tester.tap(find.text(l.forms_save));
    await tester.pumpAndSettle();

    expect(find.text('Refused here'), findsOneWidget);
    expect(find.text(l.recordEdit_saveFailed), findsNothing);
    expect(find.byType(RecordEditBar), findsOneWidget);
  });

  testWidgets('Back with changes asks, and discarding locks', (tester) async {
    await pump(tester, const _NotePage(noteId: 'n1'));
    await unlock(tester);
    await editText(tester, 'Choppy');

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text(l.forms_discard_title), findsOneWidget);

    await tester.tap(find.text(l.forms_discard_discard));
    await tester.pumpAndSettle();
    expect(find.byType(RecordEditBar), findsNothing);
    expect(find.text('Calm'), findsOneWidget);
  });

  testWidgets('a stored change follows into an untouched card', (tester) async {
    await pump(tester, const _NotePage(noteId: 'n1'));
    await unlock(tester);
    await editText(tester, 'Choppy');

    await storeNote(const _Note('n1', 'Renamed', 'Calm'));
    await tester.pumpAndSettle();

    expect(find.text('Renamed'), findsOneWidget);
    expect(find.byType(RecordEditBar), findsOneWidget);
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.text('Choppy'), findsOneWidget);
  });

  testWidgets('another record locks the sitting', (tester) async {
    await pump(tester, const _NotePage(noteId: 'n1'));
    await unlock(tester);

    tester
        .state<_HostState>(find.byType(_Host))
        .show(const _NotePage(noteId: 'n2'));
    await tester.pumpAndSettle();

    expect(find.byType(RecordEditBar), findsNothing);
    expect(find.text('Second'), findsWidgets);
  });

  testWidgets('while unlocked the app asks before leaving', (tester) async {
    await pump(tester, const _NotePage(noteId: 'n1'));
    final guard = container.read(appExitGuardProvider);
    await unlock(tester);

    // Clean: nothing to lose, nothing to ask.
    expect(await guard.mayLeave(), isTrue);

    await editText(tester, 'Choppy');
    final leaving = guard.mayLeave();
    await tester.pumpAndSettle();
    expect(find.text(l.forms_discard_title), findsOneWidget);

    await tester.tap(find.text(l.forms_discard_discard));
    await tester.pumpAndSettle();
    expect(await leaving, isTrue);
    expect(find.byType(RecordEditBar), findsNothing);
  });

  testWidgets('the pane uses the pane header', (tester) async {
    await pump(tester, const _NotePage(noteId: 'n1', embedded: true));
    await unlock(tester);

    expect(find.byType(RecordEditPaneHeader), findsOneWidget);
    expect(find.byType(RecordEditBar), findsNothing);
  });

  testWidgets('the strip lists what the page offers', (tester) async {
    await pump(tester, const _NotePage(noteId: 'n1', stripEntry: true));
    expect(find.text('Extra'), findsNothing);

    await unlock(tester);
    expect(find.text('Extra'), findsOneWidget);
  });

  testWidgets('the save key saves the page in view', (tester) async {
    await pump(tester, const _NotePage(noteId: 'n1'));

    final target = container.read(recordEditShortcutTargetsProvider).current;
    expect(target, isNotNull);
    target!.unlock();
    await tester.pumpAndSettle();
    expect(find.byType(RecordEditBar), findsOneWidget);
  });

  testWidgets('a page that never hosts editing builds no sitting', (
    tester,
  ) async {
    await pump(tester, const _NotePage(noteId: 'n1', hostsEditing: false));

    final state = tester.state<_NotePageState>(find.byType(_NotePage));
    expect(state.maybeEditController, isNull);
    expect(container.read(recordEditShortcutTargetsProvider).current, isNull);
  });

  testWidgets('a page that offers no editing takes no keys', (tester) async {
    await pump(tester, const _NotePage(noteId: 'n1', offersEditing: false));

    final targets = container.read(recordEditShortcutTargetsProvider);
    expect(targets.current, isNull);
    expect(find.byIcon(Icons.lock_outline), findsNothing);
  });
}
