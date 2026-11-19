import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';

import 'package:submersion/features/media/domain/entities/media_person_tag.dart';
import 'package:submersion/features/media/domain/entities/species_tag_chip.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';

/// The species a photo's sitting tagged and untagged (issue #4527).
///
/// Held as edits rather than as the whole list, so they apply to the tags
/// as stored at Save: a tag added on another device during the sitting,
/// which the edits never name, is kept.
@immutable
class SpeciesTagEdits extends Equatable {
  const SpeciesTagEdits({
    this.added = const {},
    this.removed = const {},
    this.confirmed = const {},
  });

  static const none = SpeciesTagEdits();

  /// Species tagged in the sitting, by species id.
  final Map<String, SpeciesTagChip> added;

  /// Stored species untagged in the sitting.
  final Set<String> removed;

  /// Stored tags the app applied that the diver confirmed in the sitting
  /// (issue #4727), by species id.
  final Set<String> confirmed;

  bool get isEmpty => added.isEmpty && removed.isEmpty && confirmed.isEmpty;

  /// These edits with the app's tag of [speciesId] confirmed.
  SpeciesTagEdits confirming(String speciesId) => SpeciesTagEdits(
    added: added,
    removed: {...removed}..remove(speciesId),
    confirmed: {...confirmed, speciesId},
  );

  /// These edits with [chip] tagged or untagged, against [stored] as it is
  /// now. Untagging one the sitting added, or tagging back one it removed,
  /// leaves no edit behind; one the store has meanwhile tagged or untagged
  /// itself is still left the way the diver asked.
  SpeciesTagEdits toggled(
    SpeciesTagChip chip, {
    required bool tagged,
    required List<SpeciesTagChip> stored,
  }) {
    final id = chip.speciesId;
    final storedChip = stored.where((s) => s.speciesId == id).firstOrNull;
    final isStored = storedChip != null;
    final nextAdded = {...added}..remove(id);
    final nextRemoved = {...removed}..remove(id);
    if (tagged && !isStored) nextAdded[id] = chip;
    if (!tagged && isStored) nextRemoved.add(id);
    return SpeciesTagEdits(
      added: nextAdded,
      removed: nextRemoved,
      // Named by hand over the app's own tag of it (a fish named from a
      // video frame, the picker): the diver's now (issue #4727).
      confirmed: !tagged
          ? ({...confirmed}..remove(id))
          : storedChip?.unconfirmed ?? false
          ? {...confirmed, id}
          : confirmed,
    );
  }

  /// [stored] without the untagged species, then the tagged ones it does not
  /// have already.
  List<SpeciesTagChip> applyTo(List<SpeciesTagChip> stored) {
    final kept = [
      for (final chip in stored)
        if (!removed.contains(chip.speciesId))
          // Confirmed in the sitting, or tagged by hand while the app's own
          // tag of it landed underneath: the diver's either way.
          confirmed.contains(chip.speciesId) ||
                  added.containsKey(chip.speciesId)
              ? chip.copyWith(unconfirmed: false)
              : chip,
    ];
    final have = {for (final chip in kept) chip.speciesId};
    return [
      ...kept,
      for (final chip in added.values)
        if (!have.contains(chip.speciesId)) chip,
    ];
  }

  /// These edits less the ones [stored] has made moot: a species tagged
  /// that is stored already, or untagged that is no longer stored.
  SpeciesTagEdits prunedTo(List<SpeciesTagChip> stored) {
    final ids = {for (final chip in stored) chip.speciesId};
    return SpeciesTagEdits(
      added: {
        for (final entry in added.entries)
          if (!ids.contains(entry.key)) entry.key: entry.value,
      },
      removed: removed.intersection(ids),
      // A species tagged by hand that the app tagged underneath meanwhile
      // is now stored: the add becomes a confirm of the app's tag.
      confirmed: {
        for (final chip in stored)
          if (chip.unconfirmed &&
              (confirmed.contains(chip.speciesId) ||
                  added.containsKey(chip.speciesId)))
            chip.speciesId,
      },
    );
  }

  @override
  List<Object?> get props => [added, removed, confirmed];
}

/// The people a photo's sitting tagged, moved, re-assigned and removed
/// (issue #4527). Held as edits for the reason [SpeciesTagEdits] is.
@immutable
class PersonTagEdits extends Equatable {
  const PersonTagEdits({
    this.added = const [],
    this.changed = const {},
    this.removed = const {},
  });

  static const none = PersonTagEdits();

  /// Tags made in the sitting, each with a local id until Save stores it.
  final List<MediaPersonChip> added;

  /// Stored tags as the sitting changed them, by tag id.
  final Map<String, MediaPersonChip> changed;

  /// Stored tags the sitting removed.
  final Set<String> removed;

  bool get isEmpty => added.isEmpty && changed.isEmpty && removed.isEmpty;

  /// These edits with [chip] tagged. A tag of the same person that
  /// [isDuplicatePersonTag] counts as the same tag is moved to the new spot
  /// instead, and a tag without a spot adds nothing to one already there, as
  /// `MediaPeopleRepository.addTag` does.
  PersonTagEdits add(
    MediaPersonChip chip, {
    required List<MediaPersonChip> stored,
    required bool isVideo,
  }) {
    final tag = chip.tag;
    for (final shown in applyTo(stored)) {
      final other = shown.tag;
      if (other.buddyId != tag.buddyId || other.diverId != tag.diverId) {
        continue;
      }
      final same = isDuplicatePersonTag(
        isVideo: isVideo,
        aPositionMs: other.videoPosition?.inMilliseconds,
        aHasBox: other.box != null,
        bPositionMs: tag.videoPosition?.inMilliseconds,
        bHasBox: tag.box != null,
      );
      if (!same) continue;
      if (tag.box == null) return this;
      return change(
        shown.copyWith(
          tag: other.copyWith(
            box: tag.box,
            videoPosition: isVideo ? tag.videoPosition : null,
          ),
        ),
        stored: stored,
      );
    }
    return PersonTagEdits(
      added: [...added, chip],
      changed: changed,
      removed: removed,
    );
  }

  /// These edits with the tag of [chip]'s id changed to [chip]. A stored tag
  /// changed back to how it is stored leaves no edit.
  PersonTagEdits change(
    MediaPersonChip chip, {
    required List<MediaPersonChip> stored,
  }) {
    final id = chip.tag.id;
    final at = added.indexWhere((a) => a.tag.id == id);
    if (at >= 0) {
      return PersonTagEdits(
        added: [...added]..[at] = chip,
        changed: changed,
        removed: removed,
      );
    }
    final original = stored.where((s) => s.tag.id == id).firstOrNull;
    final nextChanged = {...changed};
    if (original != null && samePersonTag(original.tag, chip.tag)) {
      nextChanged.remove(id);
    } else {
      nextChanged[id] = chip;
    }
    return PersonTagEdits(added: added, changed: nextChanged, removed: removed);
  }

  /// These edits with the tag [tagId] removed. Removing a tag the sitting
  /// added leaves no edit.
  PersonTagEdits remove(String tagId, {required List<MediaPersonChip> stored}) {
    if (added.any((a) => a.tag.id == tagId)) {
      return PersonTagEdits(
        added: [
          for (final a in added)
            if (a.tag.id != tagId) a,
        ],
        changed: changed,
        removed: removed,
      );
    }
    return PersonTagEdits(
      added: added,
      changed: {...changed}..remove(tagId),
      removed: {...removed, tagId},
    );
  }

  /// [stored] with these edits: removed tags gone, changed ones as changed
  /// (a change to a tag no longer stored is dropped), then the added ones.
  List<MediaPersonChip> applyTo(List<MediaPersonChip> stored) => [
    for (final chip in stored)
      if (!removed.contains(chip.tag.id)) changed[chip.tag.id] ?? chip,
    ...added,
  ];

  /// These edits less the ones [stored] has made moot: a removal or change
  /// of a tag no longer stored, or a change the stored tag now matches.
  PersonTagEdits prunedTo(List<MediaPersonChip> stored) {
    final byId = {for (final chip in stored) chip.tag.id: chip.tag};
    return PersonTagEdits(
      added: added,
      changed: {
        for (final entry in changed.entries)
          if (byId[entry.key] case final tag?
              when !samePersonTag(tag, entry.value.tag))
            entry.key: entry.value,
      },
      removed: removed.intersection(byId.keys.toSet()),
    );
  }

  @override
  List<Object?> get props => [added, changed, removed];
}

/// The photo's own tags (#1970) a sitting added and removed (issue #4527),
/// held as edits for the reason [SpeciesTagEdits] is.
@immutable
class MediaTagEdits extends Equatable {
  const MediaTagEdits({this.added = const {}, this.removed = const {}});

  static const none = MediaTagEdits();

  /// Tags added in the sitting, by tag id.
  final Map<String, Tag> added;

  /// Stored tags removed in the sitting.
  final Set<String> removed;

  bool get isEmpty => added.isEmpty && removed.isEmpty;

  /// The edits that turn [stored] into [chosen], as the tag sheet hands back
  /// the whole set.
  factory MediaTagEdits.between(List<Tag> stored, List<Tag> chosen) {
    final had = {for (final tag in stored) tag.id};
    final has = {for (final tag in chosen) tag.id};
    return MediaTagEdits(
      added: {
        for (final tag in chosen)
          if (!had.contains(tag.id)) tag.id: tag,
      },
      removed: had.difference(has),
    );
  }

  /// [stored] without the removed tags, then the added ones it does not
  /// have already.
  List<Tag> applyTo(List<Tag> stored) {
    final kept = [
      for (final tag in stored)
        if (!removed.contains(tag.id)) tag,
    ];
    final have = {for (final tag in kept) tag.id};
    return [
      ...kept,
      for (final tag in added.values)
        if (!have.contains(tag.id)) tag,
    ];
  }

  /// These edits less the ones [stored] has made moot, as
  /// [SpeciesTagEdits.prunedTo] does.
  MediaTagEdits prunedTo(List<Tag> stored) {
    final ids = {for (final tag in stored) tag.id};
    return MediaTagEdits(
      added: {
        for (final entry in added.entries)
          if (!ids.contains(entry.key)) entry.key: entry.value,
      },
      removed: removed.intersection(ids),
    );
  }

  @override
  List<Object?> get props => [added, removed];
}

/// Whether [a] and [b] name the same person at the same spot and moment;
/// their ids and timestamps aside.
bool samePersonTag(MediaPersonTag a, MediaPersonTag b) =>
    a.buddyId == b.buddyId &&
    a.diverId == b.diverId &&
    a.box == b.box &&
    a.videoPosition == b.videoPosition;
