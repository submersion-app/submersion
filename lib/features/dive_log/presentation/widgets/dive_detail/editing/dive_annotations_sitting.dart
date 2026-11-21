import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/constants/dive_detail_sections.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/text/markdown/notes_markdown.dart';
import 'package:submersion/features/dive_log/data/repositories/annotation_repository.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/profile_event.dart';
import 'package:submersion/features/dive_log/domain/services/annotation_links.dart';
import 'package:submersion/features/dive_log/presentation/providers/annotation_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_edit_cards.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_gas_switch_sitting.dart';
import 'package:submersion/features/equipment/presentation/helpers/gear_expansion.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

const _log = LoggerService('DiveAnnotationsSitting');
const _uuid = Uuid();

/// The change of the Profile card the annotations make, while any is
/// placed, moved or removed.
const String annotationsKey = 'annotations';

/// The write that settles the annotations with the notes at Save, held as
/// they load: it runs whenever the notes or the annotations changed.
const String annotationsWriteKey = 'annotationsWrite';

final String _profileCardId = DiveDetailSectionId.profile.name;

/// What a sitting holds for the dive's annotations.
///
/// An annotation is a row of the dive's profile events and a
/// `[words](annotation:id)` link in its notes (#4109), so the notes carry
/// half of every change: placing one appends its linked line, removing one
/// unlinks its words. The rows are settled with the notes at Save.
@immutable
class SittingAnnotations {
  const SittingAnnotations({
    required this.loaded,
    this.placed = const [],
    this.moved = const {},
    this.removed = const {},
    this.appended = const {},
  });

  /// The annotations as stored when the sitting read them.
  final List<ProfileEvent> loaded;

  /// Placed in this sitting, not yet written.
  final List<PendingAnnotation> placed;

  /// Stored ones moved in this sitting, by id.
  final Map<String, ({int timestamp, double? depth})> moved;

  /// Stored ones removed in this sitting.
  final Set<String> removed;

  /// The line each annotation placed from the profile added to the notes,
  /// by id, so removing it in the same sitting takes the line away again.
  final Map<String, String> appended;

  bool get isTouched =>
      placed.isNotEmpty || moved.isNotEmpty || removed.isNotEmpty;

  /// Whether the Profile card holds a change while the notes read [notes]:
  /// a pin placed counts only while the notes still link it, as one whose
  /// line was cut will not be written.
  bool isChangeIn(String notes) {
    if (moved.isNotEmpty || removed.isNotEmpty) return true;
    final linked = annotationIdsInNotes(notes);
    return placed.any((pin) => linked.contains(pin.id));
  }

  SittingAnnotations copyWith({
    List<PendingAnnotation>? placed,
    Map<String, ({int timestamp, double? depth})>? moved,
    Set<String>? removed,
    Map<String, String>? appended,
  }) => SittingAnnotations(
    loaded: loaded,
    placed: placed ?? this.placed,
    moved: moved ?? this.moved,
    removed: removed ?? this.removed,
    appended: appended ?? this.appended,
  );
}

const String _noteKey = 'annotations.held';

SittingAnnotations? sittingAnnotations(EditSession<Dive> session) =>
    session.isDisposed ? null : session.recall<SittingAnnotations>(_noteKey);

const String _repoKey = 'annotations.repo';
const String _failedKey = 'annotations.failed';
const String _readingKey = 'annotations.reading';

/// Whether the sitting's read of the annotations failed, so the Profile
/// card can say so and offer [retryDiveAnnotations] rather than take pins
/// it cannot hold.
bool annotationsLoadFailed(EditSession<Dive> session) =>
    !session.isDisposed && session.recall<bool>(_failedKey) == true;

/// The sitting's latest read of the annotations, for an editor opened
/// before it answered: keeping them does not notify the sitting's
/// listeners, so the editor redraws when this completes.
Future<void> annotationsRead(EditSession<Dive> session) =>
    (session.isDisposed ? null : session.recall<Future<void>>(_readingKey)) ??
    Future<void>.value();

/// Reads the dive's annotations once per sitting, and holds the write that
/// settles them with the notes at Save. Tracked.
///
/// The write is held before the read answers: notes changed in a sitting
/// whose read failed are still settled with the rows at Save.
void loadDiveAnnotations(EditSession<Dive> session, ProviderRead read) {
  if (!session.firstTime(_noteKey)) return;
  final repository = read(annotationRepositoryProvider);
  session
    ..remember(_repoKey, repository)
    ..holdWrite(annotationsWriteKey, () => _write(session, repository));
  _readAnnotations(session);
}

/// Reads the annotations again after a read that failed. Tracked.
Future<void> retryDiveAnnotations(EditSession<Dive> session) {
  if (!annotationsLoadFailed(session) || !_canChange(session)) {
    return Future<void>.value();
  }
  return _readAnnotations(session);
}

Future<void> _readAnnotations(EditSession<Dive> session) {
  final repository = session.recall<AnnotationRepository>(_repoKey)!;
  session.remember(_failedKey, null);
  final diveId = session.stored.id;
  final work = () async {
    final List<ProfileEvent> loaded;
    try {
      loaded = await repository.annotationsForDive(diveId);
    } catch (error, stackTrace) {
      _log.warning(
        'Reading the annotations for a sitting failed',
        error: error,
        stackTrace: stackTrace,
      );
      if (!session.isDisposed) session.remember(_failedKey, true);
      return;
    }
    if (!_canChange(session)) return;
    session
      ..remember(_noteKey, SittingAnnotations(loaded: loaded))
      // A line cut from the notes takes its pin's change with it.
      ..addListener(() => _followNotes(session));
  }();
  session
    ..remember(_readingKey, work)
    ..track(work);
  return work;
}

Future<void> _write(
  EditSession<Dive> session,
  AnnotationRepository repository,
) async {
  final held = sittingAnnotations(session);
  final notes = session.working.notes;
  final touched = held != null && held.isTouched;
  if (!touched && notes == session.stored.notes) return;
  final linked = annotationIdsInNotes(notes);
  final diveId = session.stored.id;
  // With no annotations held (their read failed), the notes alone settle
  // the rows: the ones whose links were cut go, the rest take their words.
  await repository.reconcile(
    diveId: diveId,
    notes: notes,
    create: [
      for (final pin in held?.placed ?? const <PendingAnnotation>[])
        if (linked.contains(pin.id)) pin,
    ],
  );
  if (held == null) return;
  for (final MapEntry(key: id, value: at) in held.moved.entries) {
    if (!linked.contains(id)) continue;
    await repository.moveAnnotation(
      id: id,
      timestamp: at.timestamp,
      depth: at.depth,
    );
  }
}

/// Holds or releases the Profile card's change when the notes no longer
/// agree with it. Only on a difference, as holding notifies again.
void _followNotes(EditSession<Dive> session) {
  if (!_canChange(session)) return;
  final held = sittingAnnotations(session);
  if (held == null) return;
  final changed = held.isChangeIn(session.working.notes);
  if (changed != session.isHeld(annotationsKey)) _hold(session, held);
}

/// Replaces what is held, and holds or releases the Profile card's change.
void _hold(EditSession<Dive> session, SittingAnnotations next) {
  session.remember(_noteKey, next);
  if (next.isChangeIn(session.working.notes)) {
    session.holdChange(
      annotationsKey,
      cardId: _profileCardId,
      // The rows are written by the held write; this is the card's change.
      write: () async {},
    );
  } else {
    session.releaseWrite(annotationsKey);
  }
}

bool _canChange(EditSession<Dive> session) =>
    !session.isDisposed && !session.isFrozen;

/// The annotations as the sitting has them: the stored ones not removed,
/// where moved, then the placed ones, keeping only those the sitting's
/// notes still link, each with the words its link shows.
List<ProfileEvent> sittingAnnotationEvents(EditSession<Dive> session) {
  final held = sittingAnnotations(session);
  if (held == null) return const [];
  final notes = session.working.notes;
  final words = annotationWordsInNotes(notes);
  final diveId = session.stored.id;
  return [
    for (final event in held.loaded)
      if (!held.removed.contains(event.id) && words.containsKey(event.id))
        switch (held.moved[event.id]) {
          final at? => ProfileEvent.annotation(
            id: event.id,
            diveId: diveId,
            timestamp: at.timestamp,
            depth: at.depth,
            words: words[event.id]!,
            createdAt: event.createdAt,
          ),
          null => event.copyWith(description: words[event.id]),
        },
    for (final pin in held.placed)
      if (words.containsKey(pin.id))
        ProfileEvent.annotation(
          id: pin.id,
          diveId: diveId,
          timestamp: pin.timestamp,
          depth: pin.depth,
          words: words[pin.id]!,
          createdAt: DateTime.now(),
        ),
  ];
}

/// Places one: its linked line joins the notes, as `addAnnotation` writes
/// it, and it is held as placed. Returns its id, or null before the
/// annotations load.
String? placeAnnotation(
  EditSession<Dive> session, {
  required int seconds,
  double? depth,
  required String words,
}) {
  final held = sittingAnnotations(session);
  if (held == null || !_canChange(session)) return null;
  final id = _uuid.v4();
  final notes = session.valueOf(diveNotesField);
  final link = annotationLinkMarkdown(words, id);
  final next = appendMarkdownParagraph(notes, link);
  session.set(diveNotesField, next);
  _hold(
    session,
    held.copyWith(
      placed: [
        ...held.placed,
        PendingAnnotation(id: id, timestamp: seconds, depth: depth),
      ],
      appended: {...held.appended, id: next.substring(notes.length)},
    ),
  );
  return id;
}

/// For a pin the Notes editor placed, which writes its link itself.
void holdNotesPin(EditSession<Dive> session, PendingAnnotation pin) {
  final held = sittingAnnotations(session);
  if (held == null || !_canChange(session)) return;
  _hold(session, held.copyWith(placed: [...held.placed, pin]));
}

/// Moves one. A stored one moved back to where it was is no change.
void moveSittingAnnotation(
  EditSession<Dive> session,
  String id, {
  required int seconds,
  double? depth,
}) {
  final held = sittingAnnotations(session);
  if (held == null || !_canChange(session)) return;
  final placedIndex = held.placed.indexWhere((p) => p.id == id);
  if (placedIndex >= 0) {
    _hold(
      session,
      held.copyWith(
        placed: [...held.placed]
          ..[placedIndex] = PendingAnnotation(
            id: id,
            timestamp: seconds,
            depth: depth,
          ),
      ),
    );
    return;
  }
  final stored = held.loaded.where((e) => e.id == id).firstOrNull;
  if (stored == null) return;
  final moved = {...held.moved};
  if (stored.timestamp == seconds && stored.depth == depth) {
    moved.remove(id);
  } else {
    moved[id] = (timestamp: seconds, depth: depth);
  }
  _hold(session, held.copyWith(moved: moved));
}

/// Removes one: its words stay in the notes as plain text, as removing an
/// annotation always has. One placed from the profile in this sitting takes
/// the line it added with it, while that line is still in the notes as it
/// added it. A placed one is dropped; a stored one goes at Save.
void removeSittingAnnotation(EditSession<Dive> session, String id) {
  final held = sittingAnnotations(session);
  if (held == null || !_canChange(session)) return;
  final notes = session.valueOf(diveNotesField);
  final line = held.appended[id];
  session.set(
    diveNotesField,
    line != null && notes.contains(line)
        ? notes.replaceFirst(line, '')
        : unlinkAnnotation(notes, id),
  );
  final isPlaced = held.placed.any((p) => p.id == id);
  _hold(
    session,
    held.copyWith(
      placed: [
        for (final p in held.placed)
          if (p.id != id) p,
      ],
      moved: {...held.moved}..remove(id),
      removed: isPlaced ? held.removed : {...held.removed, id},
      appended: {...held.appended}..remove(id),
    ),
  );
}

/// Whether Save can settle the annotations with the sitting's notes without
/// losing one the diver did not remove (#4815). Save reads every annotation
/// whose link no longer reads as one as removed, so a link edited by hand
/// (a bracket, a parenthesis or part of its id deleted, or its id changed)
/// would take its annotation with it. The Notes card holds Save until the
/// link is mended, or deleted whole, address and all, which removes the
/// annotation as it always has.
///
/// Checked only when Save would settle the annotations: the notes changed,
/// or an annotation was placed, moved or removed. What counts as damage is
/// [AnnotationLinkBaseline.damagedBy]'s, against the stored notes, for the
/// annotations the sitting holds. Notes stored already broken hold nothing
/// while they are left as they are.
bool annotationLinksIntact(EditSession<Dive> session) {
  final notes = session.valueOf(diveNotesField);
  final held = sittingAnnotations(session);
  if (notes == session.stored.notes && !(held?.isTouched ?? false)) {
    return true;
  }
  final stored = _baseline(session);
  final placed = {
    for (final pin in held?.placed ?? const <PendingAnnotation>[]) pin.id,
  };
  final holding = {
    // Before the read answers, or after it failed, the stored notes' links,
    // whole or broken, stand for the rows.
    if (held == null) ...{...stored.linked, ...stored.strayIds},
    if (held != null)
      for (final event in held.loaded)
        if (!held.removed.contains(event.id)) event.id,
    ...placed,
  };
  return stored.damagedBy(notes, holding, placed: placed).isEmpty;
}

const String _baselineKey = 'annotations.baseline';

/// The stored notes' links and stray addresses, read again only when the
/// stored notes change: the check runs on every keystroke.
AnnotationLinkBaseline _baseline(EditSession<Dive> session) {
  final notes = session.stored.notes;
  final kept = session.recall<AnnotationLinkBaseline>(_baselineKey);
  if (kept != null && kept.notes == notes) return kept;
  final baseline = AnnotationLinkBaseline.of(notes);
  session.remember(_baselineKey, baseline);
  return baseline;
}

/// The earliest and latest second an annotation may fall on: from the
/// start, to the stored profile's end, else the sitting's runtime, bottom
/// time or exit, capped as the time sheet caps it today.
({int min, int max}) annotationTimeLimits(EditSession<Dive> session) =>
    (min: 0, max: annotationTimeCap(gasSwitchTimeLimits(session).max));
