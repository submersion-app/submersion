import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_person_tag.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/presentation/helpers/face_box_geometry.dart';
import 'package:submersion/features/media/presentation/providers/media_people_providers.dart';
import 'package:submersion/features/media/presentation/widgets/people_tags/add_to_dive_offer.dart';
import 'package:submersion/features/media/presentation/widgets/people_tags/people_tag_hint.dart';
import 'package:submersion/features/media/presentation/widgets/people_tags/person_picker_sheet.dart';
import 'package:submersion/l10n/l10n_extension.dart';

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
  final onLinux = linux ?? (!kIsWeb && Platform.isLinux);
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

  static const _log = LoggerService('PeopleTagViewerMixin');

  /// Runs a tag write; a failure is logged and told to the diver rather
  /// than left as an unhandled async error.
  Future<bool> _save(String what, Future<void> Function() write) async {
    try {
      await write();
      return true;
    } catch (e, stackTrace) {
      _log.error('Failed to $what', error: e, stackTrace: stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.media_people_saveFailed)),
        );
      }
      return false;
    }
  }

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
        chips: ref.watch(mediaPeopleChipsProvider(item.id)).value ?? const [],
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
    final chips = ref.read(mediaPeopleChipsProvider(mediaId)).value;
    for (final chip in chips ?? const <MediaPersonChip>[]) {
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
    if (choice == null || !mounted) return;
    final saved = await _save(
      'tag a person',
      () => ref
          .read(mediaPeopleRepositoryProvider)
          .addTag(
            mediaId: item.id,
            buddyId: choice is BuddyChoice ? choice.buddy.id : null,
            diverId: choice is MeChoice ? choice.diverId : null,
            box: box,
            // A moment belongs to a box: a tag without a spot has neither.
            videoPosition: box == null ? null : at,
          ),
    );
    if (!saved || !mounted) return;
    await offerAddToDive(context, ref, diveId: item.diveId, choice: choice);
  }

  void selectPeopleTag(MediaPersonTag tag) =>
      setState(() => selectedPeopleTagId = tag.id);

  void clearPeopleSelection() => setState(() => selectedPeopleTagId = null);

  /// Asks who the selected box really is and saves the change.
  Future<void> changeTaggedPerson(MediaItem item, MediaPersonTag tag) async {
    final choice = await showPersonPickerSheet(context, diveId: item.diveId);
    if (choice == null || !mounted) return;
    final saved = await _save(
      'change a tagged person',
      () => ref
          .read(mediaPeopleRepositoryProvider)
          .updateTag(
            tag.copyWith(
              buddyId: choice is BuddyChoice ? choice.buddy.id : null,
              diverId: choice is MeChoice ? choice.diverId : null,
              updatedAt: DateTime.now(),
            ),
          ),
    );
    if (!saved || !mounted) return;
    await offerAddToDive(context, ref, diveId: item.diveId, choice: choice);
  }

  Future<void> removePeopleTag(String tagId) async {
    final saved = await _save(
      'remove a tag',
      () => ref.read(mediaPeopleRepositoryProvider).removeTag(tagId),
    );
    if (saved && mounted) setState(() => selectedPeopleTagId = null);
  }

  Future<void> movePeopleTag(MediaPersonTag tag, FaceBox box) => _save(
    'move a face box',
    () => ref
        .read(mediaPeopleRepositoryProvider)
        .updateTag(tag.copyWith(box: box, updatedAt: DateTime.now())),
  );
}
