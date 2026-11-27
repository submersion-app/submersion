import 'dart:async';

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
import 'package:submersion/shared/widgets/record_editing/record_open_unlocked.dart';

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
  // 'bad' stands for input the card refuses at Save.
  isValid: (session) => session.valueOf(_textField) != 'bad',
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

  /// How often the page's beforeSave was asked, and, while set, the answer
  /// it is still waiting for.
  int beforeSaveAsked = 0;
  Completer<bool>? holdBeforeSave;

  /// While set and not completed, the page's save is still being written.
  Completer<void>? holdSave;
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
    this.stripEntry = false,
    this.openUnlocked = false,
    this.onSittingEnded,
    this.saveLabel,
    this.allowSave = true,
  });

  final String noteId;
  final String? saveLabel;
  final bool allowSave;
  final bool embedded;
  final bool offersEditing;
  final bool stripEntry;
  final bool openUnlocked;
  final VoidCallback? onSittingEnded;

  @override
  ConsumerState<_NotePage> createState() => _NotePageState();
}

class _NotePageState extends ConsumerState<_NotePage>
    with
        RecordEditHost<_NotePage, _Note>,
        RecordOpenUnlocked<_NotePage, _Note> {
  @override
  bool openUnlockedOf(_NotePage widget) => widget.openUnlocked;

  @override
  VoidCallback? get onOpenedSittingEnded => widget.onSittingEnded;

  @override
  void onEditChanged() {
    noteOpenedSittingEnded();
    super.onEditChanged();
  }

  @override
  String get hostRecordId => widget.noteId;

  @override
  String recordIdOf(_Note record) => record.id;

  @override
  bool get offersEditing => widget.offersEditing;

  @override
  Iterable<EditCard<_Note>> get hostEditCards => [_textCard];

  @override
  _Note? get storedForUnlock => ref.read(_noteProvider(widget.noteId)).value;

  @override
  Future<void> saveSitting(EditSession<_Note> session) async {
    final probe = ref.read(_probeProvider);
    probe.saves.add(session.changedCardIds);
    await probe.holdSave?.future;
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
  String? get saveLabel => widget.saveLabel;

  @override
  Future<bool> beforeSave() async {
    final probe = ref.read(_probeProvider);
    probe.beforeSaveAsked++;
    final hold = probe.holdBeforeSave;
    if (hold != null) return hold.future;
    return widget.allowSave;
  }

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
    openUnlockedOnce(stored);
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

  // A sitting that ends otherwise (a reader's Send, issue #4527, phase 2)
  // names its Save, and may stop before it.
  group('save label and the check before Save', () {
    testWidgets('the host\'s save label reaches the bar', (tester) async {
      await pump(tester, const _NotePage(noteId: 'n1', saveLabel: 'Send'));
      await unlock(tester);

      expect(find.text('Send'), findsOneWidget);
      expect(find.text(l.forms_save), findsNothing);
    });

    testWidgets('a beforeSave that answers false saves nothing and keeps the '
        'sitting', (tester) async {
      await pump(tester, const _NotePage(noteId: 'n1', allowSave: false));
      await unlock(tester);
      await editText(tester, 'Choppy');

      await tester.tap(find.text(l.forms_save));
      await tester.pumpAndSettle();

      expect(probe.saves, isEmpty);
      expect(find.byType(RecordEditBar), findsOneWidget);
    });

    testWidgets('a beforeSave that answers true saves', (tester) async {
      await pump(tester, const _NotePage(noteId: 'n1'));
      await unlock(tester);
      await editText(tester, 'Choppy');

      await tester.tap(find.text(l.forms_save));
      await tester.pumpAndSettle();

      expect(probe.saves, hasLength(1));
    });

    // A double tap, or the Save key pressed twice, while the check is still
    // reading what it needs.
    testWidgets('a second Save while beforeSave is asked asks once', (
      tester,
    ) async {
      await pump(tester, const _NotePage(noteId: 'n1'));
      await unlock(tester);
      await editText(tester, 'Choppy');
      final hold = probe.holdBeforeSave = Completer<bool>();

      await tester.tap(find.text(l.forms_save));
      await tester.pump();
      await tester.tap(find.text(l.forms_save));
      await tester.pump();
      hold.complete(true);
      await tester.pumpAndSettle();

      expect(probe.beforeSaveAsked, 1);
      expect(probe.saves, hasLength(1));
    });

    testWidgets('input to fix is refused before beforeSave is asked', (
      tester,
    ) async {
      await pump(tester, const _NotePage(noteId: 'n1'));
      await unlock(tester);
      await editText(tester, 'bad');

      await tester.tap(find.text(l.forms_save));
      await tester.pumpAndSettle();

      expect(probe.beforeSaveAsked, 0);
      expect(probe.saves, isEmpty);
      expect(find.text(l.recordEdit_fixInvalid), findsOneWidget);
    });

    testWidgets('a Save while the sitting is being written asks nothing', (
      tester,
    ) async {
      await pump(tester, const _NotePage(noteId: 'n1'));
      await unlock(tester);
      await editText(tester, 'Choppy');
      final writing = probe.holdSave = Completer<void>();
      await tester.tap(find.text(l.forms_save));
      await tester.pump();

      unawaited(
        tester.state<_NotePageState>(find.byType(_NotePage)).saveAndReport(),
      );
      await tester.pump();
      writing.complete();
      await tester.pumpAndSettle();

      expect(probe.beforeSaveAsked, 1);
      expect(probe.saves, hasLength(1));
    });

    testWidgets('a sitting with nothing changed ends without beforeSave', (
      tester,
    ) async {
      await pump(tester, const _NotePage(noteId: 'n1'));
      await unlock(tester);

      await tester
          .state<_NotePageState>(find.byType(_NotePage))
          .saveAndReport();
      await tester.pumpAndSettle();

      expect(probe.beforeSaveAsked, 0);
      expect(find.byType(RecordEditBar), findsNothing);
    });
  });

  // A page asked to open unlocked (an old edit address, a pane's
  // `&mode=edit`) does so once, and tells its owner when that sitting ends.
  group('opened unlocked', () {
    testWidgets('the page unlocks once', (tester) async {
      await pump(tester, const _NotePage(noteId: 'n1', openUnlocked: true));
      expect(find.byType(RecordEditBar), findsOneWidget);

      await tester.tap(find.text(l.forms_cancel));
      await tester.pumpAndSettle();
      expect(find.byType(RecordEditBar), findsNothing);

      // A rebuild with the same request does not unlock again.
      tester
          .state<_HostState>(find.byType(_Host))
          .show(const _NotePage(noteId: 'n1', openUnlocked: true));
      await tester.pumpAndSettle();
      expect(find.byType(RecordEditBar), findsNothing);
    });

    testWidgets('the end of the sitting it opened is told once', (
      tester,
    ) async {
      var ended = 0;
      await pump(
        tester,
        _NotePage(
          noteId: 'n1',
          openUnlocked: true,
          onSittingEnded: () => ended++,
        ),
      );

      await tester.tap(find.text(l.forms_cancel));
      await tester.pumpAndSettle();
      expect(ended, 1);

      await unlock(tester);
      await tester.tap(find.text(l.forms_cancel));
      await tester.pumpAndSettle();
      expect(ended, 1);
    });

    testWidgets('turned off with nothing changed, it locks', (tester) async {
      await pump(tester, const _NotePage(noteId: 'n1', openUnlocked: true));
      expect(find.byType(RecordEditBar), findsOneWidget);

      tester
          .state<_HostState>(find.byType(_Host))
          .show(const _NotePage(noteId: 'n1'));
      await tester.pumpAndSettle();
      expect(find.byType(RecordEditBar), findsNothing);
    });

    // Android's Back strips `mode=edit` from the same page: typing the
    // diver has done keeps the sitting open.
    testWidgets('turned off with changes, it stays unlocked', (tester) async {
      await pump(tester, const _NotePage(noteId: 'n1', openUnlocked: true));
      await editText(tester, 'Choppy');

      tester
          .state<_HostState>(find.byType(_Host))
          .show(const _NotePage(noteId: 'n1'));
      await tester.pumpAndSettle();
      expect(find.byType(RecordEditBar), findsOneWidget);
      expect(find.text('Choppy'), findsOneWidget);
    });

    testWidgets('turned on again, it opens unlocked again', (tester) async {
      await pump(tester, const _NotePage(noteId: 'n1', openUnlocked: true));
      await tester.tap(find.text(l.forms_cancel));
      await tester.pumpAndSettle();
      final host = tester.state<_HostState>(find.byType(_Host));
      host.show(const _NotePage(noteId: 'n1'));
      await tester.pumpAndSettle();
      expect(find.byType(RecordEditBar), findsNothing);

      host.show(const _NotePage(noteId: 'n1', openUnlocked: true));
      await tester.pumpAndSettle();
      expect(find.byType(RecordEditBar), findsOneWidget);
    });

    // The unlock comes after the frame: a record that is not the page's
    // own by then (a stale read, another record handed to the page) is not
    // opened, and the page's own opens once it has it.
    testWidgets('a record not the page\'s own is not opened', (tester) async {
      probe = _Probe();
      probe.notes['n2'] = const _Note('n1', 'First', 'Calm');
      await tester.pumpWidget(
        ProviderScope(
          overrides: [_probeProvider.overrideWithValue(probe)],
          child: const MaterialApp(
            locale: Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: _Host(page: _NotePage(noteId: 'n2', openUnlocked: true)),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(RecordEditBar), findsNothing);

      probe.notes['n2'] = const _Note('n2', 'Second', 'Flat');
      ProviderScope.containerOf(
        tester.element(find.byType(_Host)),
      ).invalidate(_noteProvider('n2'));
      await tester.pumpAndSettle();
      expect(find.text('Editing Second'), findsOneWidget);
    });

    testWidgets('a leave the app asked about is not told', (tester) async {
      var ended = 0;
      await pump(
        tester,
        _NotePage(
          noteId: 'n1',
          openUnlocked: true,
          onSittingEnded: () => ended++,
        ),
      );
      await editText(tester, 'Choppy');

      final leaving = container.read(appExitGuardProvider).mayLeave();
      await tester.pumpAndSettle();
      await tester.tap(find.text(l.forms_discard_discard));
      await tester.pumpAndSettle();

      expect(await leaving, isTrue);
      expect(ended, 0);
    });
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

  testWidgets('a page that offers no editing takes no keys', (tester) async {
    await pump(tester, const _NotePage(noteId: 'n1', offersEditing: false));

    final targets = container.read(recordEditShortcutTargetsProvider);
    expect(targets.current, isNull);
    expect(find.byIcon(Icons.lock_outline), findsNothing);
  });
}
