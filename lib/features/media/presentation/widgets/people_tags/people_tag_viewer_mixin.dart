import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:video_player/video_player.dart';

import 'package:submersion/core/platform/host_platform.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/buddies/data/repositories/buddy_repository.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_providers.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/photo_record.dart';
import 'package:submersion/features/media/domain/value_objects/photo_tag_edits.dart';
import 'package:submersion/features/media/presentation/editing/photo_edit_fields.dart';
import 'package:submersion/features/media/presentation/editing/photo_held_writes.dart';
import 'package:submersion/features/media/presentation/editing/photo_sitting_shown.dart';
import 'package:submersion/features/media/domain/entities/media_person_tag.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/presentation/helpers/face_box_geometry.dart';
import 'package:submersion/features/media/presentation/providers/media_people_providers.dart';
import 'package:submersion/features/media/presentation/widgets/people_tags/add_to_dive_offer.dart';
import 'package:submersion/features/media/presentation/widgets/people_tags/people_tag_hint.dart';
import 'package:submersion/features/media/presentation/widgets/people_tags/person_picker_sheet.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

/// Whether a face box can be placed on [item] here (issue #1745). A photo
/// needs its size known, to map a tap onto it. A video also needs a player
/// that is ready on this device: Linux has no video player, a connector
/// video only ever shows its poster, and a missing file never loads. Where
/// it cannot, tag mode offers only "Tag without a spot".
///
/// [linux] overrides the platform check, for tests.
bool canPlaceSpot(
  MediaItem item, {
  required bool videoReady,
  required Size? imageSize,
  bool? linux,
}) {
  if (imageSize == null || imageSize.isEmpty) return false;
  if (!item.isVideo) return true;
  final onLinux = linux ?? (!kIsWeb && HostPlatform.isLinux);
  return videoReady &&
      !onLinux &&
      item.sourceType != MediaSourceType.serviceConnector;
}

/// What the gallery's pages need from the viewer's tag mode: whether it is
/// on, the box being edited, and where taps and drags report.
class PeopleTagSession {
  final bool active;
  final String? selectedTagId;

  /// The box just dropped on a media item, shown while the picker asks who
  /// it is; null for any other item.
  final FaceBox? Function(String mediaId) pendingBoxFor;
  final Size? Function(MediaItem item, {Size? videoSize}) imageSizeOf;
  final void Function(String mediaId, Size size) onImageSize;
  final bool Function(MediaItem item, {Size? videoSize, bool videoReady})
  canPlace;
  final void Function(MediaItem item, FaceBox box, Duration? at) onPlace;
  final void Function(MediaPersonTag tag) onSelect;
  final void Function(MediaPersonTag tag, FaceBox box) onMove;

  /// The photo's sitting (issue #4527): the boxes and chips show its held
  /// tags. Null while the photo is locked.
  final EditSession<PhotoRecord>? sitting;

  const PeopleTagSession({
    required this.active,
    required this.selectedTagId,
    required this.pendingBoxFor,
    required this.imageSizeOf,
    required this.onImageSize,
    required this.canPlace,
    required this.onPlace,
    required this.onSelect,
    required this.onMove,
    this.sitting,
  });
}

/// The people-tag mode a media viewer shares (issue #1745): on and off,
/// the box being edited, and the flows behind a tap (place, pick, save,
/// offer to add the buddy to the dive). Modelled on
/// `ColorAdjustViewerMixin`'s "Pick white".
mixin PeopleTagViewerMixin<T extends ConsumerStatefulWidget>
    on ConsumerState<T> {
  /// Whether tag mode is waiting for taps.
  bool taggingPeople = false;

  /// The tag whose box is selected for editing, if any.
  String? selectedPeopleTagId;

  /// The box dropped on [_pendingMediaId] while the picker is open.
  FaceBox? _pendingBox;
  String? _pendingMediaId;

  FaceBox? pendingPeopleBox(String mediaId) =>
      _pendingMediaId == mediaId ? _pendingBox : null;

  /// The photo's sitting, where tag mode holds its changes until Save
  /// (issue #4527). Null while the photo is locked, when tag mode is off and
  /// a change has nowhere to go.
  EditSession<PhotoRecord>? get peopleSitting;

  /// The tags [mediaId] shows: the sitting's when it is over that photo.
  List<MediaPersonChip> _shownChips(String mediaId) {
    final sitting = peopleSitting;
    if (sittingIsOver(sitting, mediaId)) return sitting!.working.people;
    return ref.read(mediaPeopleChipsProvider(mediaId)).value ?? const [];
  }

  /// Whether [session], captured before an await, can still take a change
  /// for [mediaId].
  bool _stillOpen(EditSession<PhotoRecord> session, String mediaId) =>
      mounted &&
      !session.isDisposed &&
      !session.isFrozen &&
      session.stored.item.id == mediaId;

  void _holdPeople(
    EditSession<PhotoRecord> session,
    PersonTagEdits Function(PersonTagEdits edits) change,
  ) => session.set(photoPeopleField, change(session.valueOf(photoPeopleField)));

  /// Decoded image sizes, which win over a row's unrotated dimensions.
  final Map<String, Size> _decodedSizes = {};

  /// The session the gallery's pages share. [pauseVideo] pauses a video by
  /// id: placing a box pauses it again, so a box never lands on a frame that
  /// has already moved on.
  PeopleTagSession buildPeopleSession({
    required void Function(String mediaId) pauseVideo,
  }) => PeopleTagSession(
    active: taggingPeople,
    selectedTagId: selectedPeopleTagId,
    pendingBoxFor: pendingPeopleBox,
    imageSizeOf: peopleImageSize,
    onImageSize: rememberImageSize,
    canPlace: (item, {videoSize, videoReady = false}) => canPlaceSpot(
      item,
      videoReady: videoReady,
      imageSize: peopleImageSize(item, videoSize: videoSize),
    ),
    onPlace: (item, box, at) {
      if (item.isVideo) pauseVideo(item.id);
      unawaited(placePeopleTag(item, box, at: at));
    },
    onSelect: selectPeopleTag,
    onMove: (tag, box) => unawaited(movePeopleTag(tag, box)),
    sitting: peopleSitting,
  );

  /// Tag mode's hint and bar over the viewer for [item]; [video] is its
  /// player's state, and [onShowMoment] shows a video tag's frame.
  Widget peopleTagHint(
    MediaItem item, {
    required VideoPlayerValue? video,
    required ValueChanged<MediaPersonTag> onShowMoment,
  }) {
    final selected = selectedPeopleTag(item.id);
    return Positioned.fill(
      child: PeopleTagHint(
        canPlaceSpot: canPlaceSpot(
          item,
          videoReady: video != null && video.isInitialized && !video.hasError,
          imageSize: peopleImageSize(item, videoSize: video?.size),
        ),
        hasSelection: selected != null,
        selectionHasBox: selected?.box != null,
        chips: peopleChipsShown(ref, item.id, peopleSitting),
        selectedTagId: selectedPeopleTagId,
        onSelectTag: (tag) {
          selectPeopleTag(tag);
          // A moment off screen: show its frame where the video can play.
          if (tag.videoPosition != null) onShowMoment(tag);
        },
        onWithoutSpot: () => unawaited(tagWithoutSpot(item)),
        onDone: togglePeopleTagging,
        onChangePerson: () {
          if (selected != null) unawaited(changeTaggedPerson(item, selected));
        },
        onRemove: () {
          if (selected != null) unawaited(removePeopleTag(selected.id));
        },
      ),
    );
  }

  /// Enters or leaves tag mode. A video is paused first, so a box is drawn
  /// on the frame on screen.
  void togglePeopleTagging({Future<void> Function()? pauseVideo}) {
    if (!taggingPeople) unawaited(pauseVideo?.call());
    setState(() {
      taggingPeople = !taggingPeople;
      selectedPeopleTagId = null;
    });
  }

  /// The size a box on [item] is placed against: a video player's
  /// [videoSize], or for a photo [faceImageSize] of the row and the decoded
  /// image.
  Size? peopleImageSize(MediaItem item, {Size? videoSize}) {
    if (item.isVideo) return videoSize;
    return faceImageSize(
      width: item.width,
      height: item.height,
      decoded: _decodedSizes[item.id],
    );
  }

  void rememberImageSize(String mediaId, Size size) {
    if (_decodedSizes[mediaId] == size) return;
    setState(() => _decodedSizes[mediaId] = size);
  }

  /// The selected tag on [mediaId], read from the chips already loaded.
  MediaPersonTag? selectedPeopleTag(String mediaId) {
    final id = selectedPeopleTagId;
    if (id == null) return null;
    for (final chip in _shownChips(mediaId)) {
      if (chip.tag.id == id) return chip.tag;
    }
    return null;
  }

  /// A tap placed [box] on [item] (at [at] on a video): asks who it is,
  /// saves the tag and offers to add the buddy to the dive.
  Future<void> placePeopleTag(MediaItem item, FaceBox box, {Duration? at}) =>
      _tagWith(item, box: box, at: at);

  /// Tags someone on [item] without a spot.
  Future<void> tagWithoutSpot(MediaItem item) => _tagWith(item);

  Future<void> _tagWith(MediaItem item, {FaceBox? box, Duration? at}) async {
    // Captured first: a sitting that ends while the picker is open takes
    // nothing.
    final session = peopleSitting;
    if (session == null) return;
    final buddies = ref.read(buddyRepositoryProvider);
    if (box != null) {
      setState(() {
        _pendingBox = box;
        _pendingMediaId = item.id;
      });
    }
    final PersonChoice? choice;
    try {
      choice = await showPersonPickerSheet(context, diveId: item.diveId);
    } finally {
      if (mounted && box != null) {
        setState(() {
          _pendingBox = null;
          _pendingMediaId = null;
        });
      }
    }
    if (choice == null || !_stillOpen(session, item.id)) return;
    final now = DateTime.now();
    final chip = MediaPersonChip(
      tag: MediaPersonTag(
        id: const Uuid().v4(),
        mediaId: item.id,
        buddyId: choice is BuddyChoice ? choice.buddy.id : null,
        diverId: choice is MeChoice ? choice.diverId : null,
        box: box,
        // A moment belongs to a box: a tag without a spot has neither.
        videoPosition: box == null ? null : at,
        createdAt: now,
        updatedAt: now,
      ),
      buddyName: choice is BuddyChoice ? choice.buddy.name : null,
    );
    _holdPeople(
      session,
      (edits) =>
          edits.add(chip, stored: session.stored.people, isVideo: item.isVideo),
    );
    await _offerHeldAdd(session, item, choice, buddies);
  }

  void selectPeopleTag(MediaPersonTag tag) =>
      setState(() => selectedPeopleTagId = tag.id);

  void clearPeopleSelection() => setState(() => selectedPeopleTagId = null);

  /// Puts back a selection the pager cleared while staying on the same
  /// photo (issue #4527).
  void restorePeopleSelection(String? tagId) {
    if (selectedPeopleTagId != tagId) {
      setState(() => selectedPeopleTagId = tagId);
    }
  }

  /// Asks who the selected box really is and holds the change.
  Future<void> changeTaggedPerson(MediaItem item, MediaPersonTag tag) async {
    final session = peopleSitting;
    if (session == null) return;
    final buddies = ref.read(buddyRepositoryProvider);
    final choice = await showPersonPickerSheet(context, diveId: item.diveId);
    if (choice == null || !_stillOpen(session, item.id)) return;
    final changed = MediaPersonChip(
      tag: tag.copyWith(
        buddyId: choice is BuddyChoice ? choice.buddy.id : null,
        diverId: choice is MeChoice ? choice.diverId : null,
        updatedAt: DateTime.now(),
      ),
      buddyName: choice is BuddyChoice ? choice.buddy.name : null,
    );
    _holdPeople(
      session,
      (edits) => edits.change(changed, stored: session.stored.people),
    );
    await _offerHeldAdd(session, item, choice, buddies);
  }

  Future<void> removePeopleTag(String tagId) async {
    final session = peopleSitting;
    if (session == null || session.isDisposed || session.isFrozen) return;
    _holdPeople(
      session,
      (edits) => edits.remove(tagId, stored: session.stored.people),
    );
    setState(() => selectedPeopleTagId = null);
  }

  Future<void> movePeopleTag(MediaPersonTag tag, FaceBox box) async {
    final session = peopleSitting;
    if (session == null || session.isDisposed || session.isFrozen) return;
    final shown = _shownChips(tag.mediaId).where((c) => c.tag.id == tag.id);
    final buddyName = shown.isEmpty ? null : shown.first.buddyName;
    _holdPeople(
      session,
      (edits) => edits.change(
        MediaPersonChip(
          tag: tag.copyWith(box: box),
          buddyName: buddyName,
        ),
        stored: session.stored.people,
      ),
    );
  }

  /// The add-to-dive offer made in a sitting, while it is shown.
  ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? _heldOffer;

  /// Closes the add-to-dive offer made in a sitting: once the sitting has
  /// ended its Add would land nowhere, and would be lost unsaid.
  void dismissHeldOffer() {
    _heldOffer?.close();
    _heldOffer = null;
  }

  /// Offers to add a tagged buddy to the dive, held in [session] when taken.
  Future<void> _offerHeldAdd(
    EditSession<PhotoRecord> session,
    MediaItem item,
    PersonChoice choice,
    BuddyRepository buddies,
  ) async {
    final diveId = item.diveId;
    if (diveId == null || choice is! BuddyChoice) return;
    if (isBuddyToDiveHeld(session, choice.buddy.id)) return;
    final offer = await offerAddToDive(
      context,
      ref,
      diveId: diveId,
      choice: choice,
      onAdd: (buddy) {
        if (session.isDisposed || session.isFrozen) return;
        holdAddBuddyToDive(
          session,
          diveId: diveId,
          buddyId: buddy.id,
          repository: buddies,
        );
      },
    );
    // The sitting ended while the offer was being made (the dive's buddies
    // are read first): dismissHeldOffer has run already, so close it here.
    if (!_stillOpen(session, item.id)) {
      offer?.close();
      return;
    }
    _heldOffer = offer;
    // Gone by itself (its Add, its timeout): nothing is left to close.
    unawaited(
      offer?.closed.then((_) {
        if (identical(_heldOffer, offer)) _heldOffer = null;
      }),
    );
  }
}
