import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_person_tag.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/presentation/helpers/face_box_geometry.dart';
import 'package:submersion/features/media/presentation/providers/media_people_providers.dart';
import 'package:submersion/features/media/presentation/widgets/people_tags/add_to_dive_offer.dart';
import 'package:submersion/features/media/presentation/widgets/people_tags/person_picker_sheet.dart';

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

  /// Decoded image sizes, which win over a row's unrotated dimensions.
  final Map<String, Size> _decodedSizes = {};

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
    await ref
        .read(mediaPeopleRepositoryProvider)
        .addTag(
          mediaId: item.id,
          buddyId: choice is BuddyChoice ? choice.buddy.id : null,
          diverId: choice is MeChoice ? choice.diverId : null,
          box: box,
          // A moment belongs to a box: a tag without a spot has neither.
          videoPosition: box == null ? null : at,
        );
    if (!mounted) return;
    await offerAddToDive(context, ref, diveId: item.diveId, choice: choice);
  }

  void selectPeopleTag(MediaPersonTag tag) =>
      setState(() => selectedPeopleTagId = tag.id);

  void clearPeopleSelection() => setState(() => selectedPeopleTagId = null);

  /// Asks who the selected box really is and saves the change.
  Future<void> changeTaggedPerson(MediaItem item, MediaPersonTag tag) async {
    final choice = await showPersonPickerSheet(context, diveId: item.diveId);
    if (choice == null || !mounted) return;
    await ref
        .read(mediaPeopleRepositoryProvider)
        .updateTag(
          tag.copyWith(
            buddyId: choice is BuddyChoice ? choice.buddy.id : null,
            diverId: choice is MeChoice ? choice.diverId : null,
            updatedAt: DateTime.now(),
          ),
        );
    if (!mounted) return;
    await offerAddToDive(context, ref, diveId: item.diveId, choice: choice);
  }

  Future<void> removePeopleTag(String tagId) async {
    await ref.read(mediaPeopleRepositoryProvider).removeTag(tagId);
    if (mounted) setState(() => selectedPeopleTagId = null);
  }

  Future<void> movePeopleTag(MediaPersonTag tag, FaceBox box) => ref
      .read(mediaPeopleRepositoryProvider)
      .updateTag(tag.copyWith(box: box, updatedAt: DateTime.now()));
}
