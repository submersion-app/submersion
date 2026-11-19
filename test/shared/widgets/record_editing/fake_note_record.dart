import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/record_editing/add_strip.dart';
import 'package:submersion/shared/widgets/record_editing/edit_card.dart';
import 'package:submersion/shared/widgets/record_editing/edit_field.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';
import 'package:submersion/shared/widgets/record_editing/record_card_frame.dart';
import 'package:submersion/shared/widgets/record_editing/record_card_header.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_controller.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_host.dart';
import 'package:submersion/shared/widgets/record_editing/record_satellite.dart';

/// A record small enough to show what the shared editing pieces do for any
/// record page (issue #4527, phase 3): a parent page with two cards, and a
/// satellite page holding one of them.
@immutable
class FakeNote {
  const FakeNote(this.id, this.title, this.text, this.extra);

  final String id;
  final String title;
  final String text;
  final String extra;

  @override
  bool operator ==(Object other) =>
      other is FakeNote &&
      other.id == id &&
      other.title == title &&
      other.text == text &&
      other.extra == extra;

  @override
  int get hashCode => Object.hash(id, title, text, extra);
}

final fakeTextField = EditField<FakeNote, String>(
  id: 'text',
  cardId: 'text',
  read: (note) => note.text,
  write: (note, text) => FakeNote(note.id, note.title, text, note.extra),
);

final fakeExtraField = EditField<FakeNote, String>(
  id: 'extra',
  cardId: 'extra',
  read: (note) => note.extra,
  write: (note, extra) => FakeNote(note.id, note.title, note.text, extra),
);

final fakeTextCard = EditCard<FakeNote>(
  id: 'text',
  title: (_) => 'Text',
  isEmpty: (note) => note.text.isEmpty,
  editorBuilder: (context, session) => TextFormField(
    key: const ValueKey('textEditor'),
    initialValue: session.valueOf(fakeTextField),
    onChanged: (text) => session.set(fakeTextField, text),
  ),
);

/// Its check fails on the value `bad`, as a card's own check would.
final fakeExtraCard = EditCard<FakeNote>(
  id: 'extra',
  title: (_) => 'Extra',
  isEmpty: (note) => note.extra.isEmpty,
  isValid: (session) => session.valueOf(fakeExtraField) != 'bad',
  editorBuilder: (context, session) => TextFormField(
    key: const ValueKey('extraEditor'),
    initialValue: session.valueOf(fakeExtraField),
    onChanged: (extra) => session.set(fakeExtraField, extra),
  ),
);

/// The stored notes, by id, and the sittings saved, as their card ids.
class FakeNoteProbe {
  final notes = <String, FakeNote>{
    'n1': const FakeNote('n1', 'First', 'Calm', 'Full'),
  };
  final saves = <Set<String>>[];
}

final fakeNoteProbeProvider = Provider<FakeNoteProbe>(
  (ref) => throw UnimplementedError(),
);

final fakeNoteProvider = FutureProvider.family<FakeNote?, String>(
  (ref, id) async => ref.watch(fakeNoteProbeProvider).notes[id],
);

/// What every fake page shares: its record, its save and its reread.
mixin _FakeNoteHost<W extends ConsumerStatefulWidget>
    on ConsumerState<W>, RecordEditHost<W, FakeNote> {
  String get noteId;

  @override
  String get hostRecordId => noteId;

  @override
  String recordIdOf(FakeNote record) => record.id;

  @override
  FakeNote? get storedForUnlock => ref.read(fakeNoteProvider(noteId)).value;

  /// Stores the working copy, as a record's save service would.
  @override
  Future<void> saveSitting(EditSession<FakeNote> session) async {
    final probe = ref.read(fakeNoteProbeProvider);
    probe.saves.add(session.changedCardIds);
    final saved = session.working;
    probe.notes[saved.id] = saved;
    justSavedRecord = saved;
    ref.invalidate(fakeNoteProvider(saved.id));
  }

  @override
  Future<FakeNote?> rereadStored(
    ProviderContainer container,
    FakeNote stored,
  ) => container.read(fakeNoteProvider(stored.id).future);

  @override
  void dispose() {
    disposeEditing();
    super.dispose();
  }
}

/// The record's own page: both cards, and a button that opens the
/// satellite, handing it the sitting in progress.
class FakeNotePage extends ConsumerStatefulWidget {
  const FakeNotePage({super.key, this.noteId = 'n1'});

  final String noteId;

  @override
  ConsumerState<FakeNotePage> createState() => FakeNotePageState();
}

class FakeNotePageState extends ConsumerState<FakeNotePage>
    with RecordEditHost<FakeNotePage, FakeNote>, _FakeNoteHost<FakeNotePage> {
  @override
  String get noteId => widget.noteId;

  @override
  Iterable<EditCard<FakeNote>> get hostEditCards => [
    fakeTextCard,
    fakeExtraCard,
  ];

  @override
  String editingTitle(FakeNote record) => 'Editing ${record.title}';

  @override
  List<AddStripEntry> addStripEntries(FakeNote working) => const [];

  @override
  Widget build(BuildContext context) {
    followStored(fakeNoteProvider(widget.noteId));
    final stored = ref.watch(fakeNoteProvider(widget.noteId)).value;
    if (stored == null) return const SizedBox.shrink();
    final shown = shownRecord(stored);
    return editScaffold(
      record: stored,
      shown: shown,
      lockedBar: AppBar(title: Text(shown.title), actions: [lockButton(shown)]),
      content: ListView(
        children: [
          RecordCardFrame<FakeNote>(
            card: fakeTextCard,
            child: Column(
              children: [
                const RecordCardHeader(title: 'Text'),
                Text(shown.text, key: const ValueKey('text')),
              ],
            ),
          ),
          Text(shown.extra, key: const ValueKey('parentExtra')),
          // Below the page's scope, so the push finds the sitting.
          Builder(
            builder: (context) => TextButton(
              key: const ValueKey('openSatellite'),
              onPressed: () => pushRecordSatellite<FakeNote, void>(
                context,
                builder: (joined) =>
                    FakeSatellitePage(noteId: widget.noteId, joined: joined),
              ),
              child: const Text('Open satellite'),
            ),
          ),
        ],
      ),
    );
  }
}

/// A page of the same record holding only its `extra` card, as a passport
/// is a page of a gear item.
class FakeSatellitePage extends ConsumerStatefulWidget {
  const FakeSatellitePage({super.key, this.noteId = 'n1', this.joined});

  final String noteId;
  final RecordEditController<FakeNote>? joined;

  @override
  ConsumerState<FakeSatellitePage> createState() => FakeSatellitePageState();
}

class FakeSatellitePageState extends ConsumerState<FakeSatellitePage>
    with
        RecordEditHost<FakeSatellitePage, FakeNote>,
        _FakeNoteHost<FakeSatellitePage> {
  @override
  String get noteId => widget.noteId;

  @override
  RecordEditController<FakeNote>? get joinedSitting => widget.joined;

  @override
  Iterable<EditCard<FakeNote>> get hostEditCards => [fakeExtraCard];

  @override
  String editingTitle(FakeNote record) => 'Satellite of ${record.title}';

  @override
  List<AddStripEntry> addStripEntries(FakeNote working) => const [];

  @override
  Widget build(BuildContext context) {
    followStored(fakeNoteProvider(widget.noteId));
    final stored = ref.watch(fakeNoteProvider(widget.noteId)).value;
    if (stored == null) return const SizedBox.shrink();
    final shown = shownRecord(stored);
    return editScaffold(
      record: stored,
      shown: shown,
      lockedBar: AppBar(
        title: const Text('Satellite'),
        actions: [lockButton(shown)],
      ),
      content: ListView(
        children: [
          RecordCardFrame<FakeNote>(
            card: fakeExtraCard,
            child: Column(
              children: [
                const RecordCardHeader(title: 'Extra'),
                Text(shown.extra, key: const ValueKey('satelliteExtra')),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Pumps [home] over a fresh probe, and returns the probe.
Future<FakeNoteProbe> pumpFakeNotes(WidgetTester tester, Widget home) async {
  final probe = FakeNoteProbe();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [fakeNoteProbeProvider.overrideWithValue(probe)],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: home,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return probe;
}
