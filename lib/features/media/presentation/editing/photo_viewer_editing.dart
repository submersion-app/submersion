import 'dart:async';

import 'package:flutter/material.dart';

import 'package:submersion/core/models/log_entry.dart';
import 'package:submersion/core/platform/device_capabilities.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/media/data/services/photo_edit_save_service.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/photo_record.dart';
import 'package:submersion/features/media/presentation/editing/photo_edit_fields.dart';
import 'package:submersion/features/media/presentation/editing/photo_held_writes.dart';
import 'package:submersion/features/media/presentation/providers/media_providers.dart';
import 'package:submersion/features/media/presentation/providers/photo_editing_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/record_editing/edit_field.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_controller.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_leave_guard.dart';

const _log = LoggerService('PhotoViewerEditing', category: LogCategory.media);

/// A photo viewer's own lock (issue #4527): every photo opens locked;
/// unlocking starts a sitting on the photo on screen, whose changes are
/// held until one Save. Both viewers mix this in, so the lock, the bar's
/// Cancel and Save, and the checks on leaving and stepping are written once.
///
/// The lock is the photo's, not its dive's: a viewer pushed over a dive page
/// in a sitting is a route of its own, so its scope is a different one, and
/// nothing here ends that sitting.
mixin PhotoViewerEditing<W extends ConsumerStatefulWidget> on ConsumerState<W> {
  /// Told on every lock, by whatever route, so the page closes the panels and
  /// modes that change the photo.
  void onPhotoLocked();

  RecordEditController<PhotoRecord>? _photoController;
  bool _wasUnlocked = false;

  /// The sitting the viewer listens to. Its controller tells the page only
  /// when the set of changes moves; the viewer redraws the photo, its chips
  /// and boxes on every change (taps and picks, never keystrokes).
  EditSession<PhotoRecord>? _listened;

  /// Whether this viewer offers the lock: on a device that can change media
  /// at all.
  bool get editingOffered => ref.read(deviceCapabilitiesProvider).mediaAttach;

  /// Created on first use, so a viewer that never offers editing has none.
  RecordEditController<PhotoRecord> get photoEditController =>
      _photoController ??= RecordEditController<PhotoRecord>(
        onSave: _savePhotoSitting,
      )..addListener(_onPhotoEditChanged);

  /// The sitting, while the photo on screen is unlocked.
  EditSession<PhotoRecord>? get photoSitting => _photoController?.session;

  bool get photoUnlocked => _photoController?.isUnlocked ?? false;

  /// Whether the viewer only reads: not unlocked. A device that cannot
  /// unlock at all (a browser) is always here, so nothing there falls back
  /// to writing at once.
  bool get photoLocked => !photoUnlocked;

  /// The photo the sitting is over.
  String? get _sittingId => photoSitting?.stored.item.id;

  void _onPhotoEditChanged() {
    if (!mounted) return;
    final session = photoSitting;
    if (!identical(session, _listened)) {
      _listened?.removeListener(_onSittingChanged);
      _listened = session?..addListener(_onSittingChanged);
    }
    final unlocked = photoUnlocked;
    if (_wasUnlocked && !unlocked) {
      _closeRoutesAbove();
      onPhotoLocked();
    }
    _wasUnlocked = unlocked;
    setState(() {});
  }

  /// Closes the sheets and dialogs open over the viewer once its sitting
  /// has ended (the photo deleted elsewhere): they hold into a sitting that
  /// no longer exists. Cancel and Save are tapped on the viewer itself, so
  /// there is nothing above it then. A page the diver opened from the viewer
  /// (a species from its chip) is theirs, and stays.
  void _closeRoutesAbove() {
    final route = ModalRoute.of(context);
    if (route == null || route.isCurrent || !route.isActive) return;
    Navigator.of(
      context,
    ).popUntil((other) => other == route || other is! PopupRoute);
  }

  void _onSittingChanged() {
    if (mounted) setState(() {});
  }

  /// The photo on screen as stored, for unlocking; null while it is being
  /// read, and for a photo with no stored row. Call from `build`: it also
  /// keeps a sitting on top of what is stored, and ends it if its photo is
  /// deleted.
  PhotoRecord? followStoredPhoto(MediaItem onScreen) {
    if (!editingOffered) return null;
    final id = _sittingId ?? onScreen.id;
    ref.listen(photoRecordProvider(id), (_, next) {
      if (next.isLoading || next.hasError) return;
      final controller = _photoController;
      if (controller == null || _sittingId != id) return;
      final stored = next.value;
      if (stored == null) {
        _endForGonePhoto();
        return;
      }
      controller.storedChanged(stored);
      _pruneMootEdits(controller.session);
    });
    final stored = ref.watch(photoRecordProvider(id)).value;
    return stored?.item.id == onScreen.id ? stored : null;
  }

  /// Drops the held tag edits the stored photo has made moot (another device
  /// made the same change), so a sitting with nothing left to save is clean.
  void _pruneMootEdits(EditSession<PhotoRecord>? session) {
    if (session == null || session.isDisposed || session.isFrozen) return;
    final stored = session.stored;
    void prune<V>(EditField<PhotoRecord, V> field, V pruned) {
      if (pruned != session.valueOf(field)) session.set(field, pruned);
    }

    prune(
      photoSpeciesField,
      session.valueOf(photoSpeciesField).prunedTo(stored.species),
    );
    prune(
      photoPeopleField,
      session.valueOf(photoPeopleField).prunedTo(stored.people),
    );
    prune(
      photoTagsField,
      session.valueOf(photoTagsField).prunedTo(stored.tags),
    );
  }

  /// Whether [item] can be unlocked here: the viewer offers editing, the
  /// item has a stored row ([stored] from [followStoredPhoto]) and is not a
  /// document.
  bool canUnlock(MediaItem item, PhotoRecord? stored) =>
      editingOffered && stored != null && !item.isDocument;

  /// The dive the sitting's photo was on when it was unlocked.
  ({String? id})? _diveAtUnlock;

  void unlockPhoto(PhotoRecord stored) {
    _diveAtUnlock = (id: stored.item.diveId);
    photoEditController.unlock(stored);
  }

  /// The sitting's photo is no longer stored: the sitting ends, and the
  /// diver is told nothing was saved.
  void _endForGonePhoto() {
    final controller = _photoController;
    if (controller == null || !controller.isUnlocked) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // A save running now cannot be locked: it fails on the missing row,
      // and its failure ends the sitting with this same message.
      if (!mounted || !controller.isUnlocked || controller.isSaving) return;
      _lockAsGone(controller);
    });
  }

  /// Ends the sitting over a photo that no longer exists, and says so.
  void _lockAsGone(RecordEditController<PhotoRecord> controller) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final l10n = context.l10n;
    final message = controller.session?.stored.item.isVideo ?? false
        ? l10n.media_viewer_videoGoneWhileEditing
        : l10n.media_viewer_photoGoneWhileEditing;
    controller.lock();
    messenger?.showSnackBar(SnackBar(content: Text(message)));
  }

  /// Where the sitting's photo last was in the viewer's list.
  int _sittingSlot = 0;

  /// Whether the last [keepSittingPhoto] had to put the sitting's photo in:
  /// it is in the list only while the sitting lasts.
  bool _keptOnly = false;

  /// [list] with the sitting's photo kept in it, at the place it last had,
  /// while its row exists (Eric, 2026-11-16): another device dropping it from
  /// this list (untagging the species, moving the dive out of the trip) does
  /// not end the sitting. Only the photo's deletion does ([followStoredPhoto]).
  List<MediaItem> keepSittingPhoto(List<MediaItem> list) {
    final session = photoSitting;
    _keptOnly = false;
    if (session == null) return list;
    final photo = session.stored.item;
    final at = list.indexWhere((m) => m.id == photo.id);
    if (at >= 0) {
      _sittingSlot = at;
      return list;
    }
    _keptOnly = true;
    final slot = _sittingSlot.clamp(0, list.length);
    return [...list.sublist(0, slot), photo, ...list.sublist(slot)];
  }

  /// Where the sitting's photo is in [list], a list [keepSittingPhoto]
  /// returned, or null with no sitting.
  int? sittingIndexIn(List<MediaItem> list) {
    final id = _sittingId;
    if (id == null) return null;
    final index = list.indexWhere((m) => m.id == id);
    return index < 0 ? null : index;
  }

  /// [stored] with the sitting's photo drawn as the sitting has it.
  List<MediaItem> shownMediaList(
    List<MediaItem> stored,
    List<DiveProfilePoint> profile,
  ) {
    final session = photoSitting;
    if (session == null) return stored;
    final id = session.stored.item.id;
    return [
      for (final item in stored)
        item.id == id ? photoShownItem(session, profile) : item,
    ];
  }

  /// [item] as the sitting has it when the sitting is over it.
  MediaItem shownItem(MediaItem item, List<DiveProfilePoint> profile) {
    final session = photoSitting;
    if (session == null || session.stored.item.id != item.id) return item;
    return photoShownItem(session, profile);
  }

  /// Steps [delta] photos through the check: with changes it asks first;
  /// either way the photo is locked before [step] runs, so every photo
  /// opens locked.
  ///
  /// A photo kept in the list only by its sitting leaves it as the sitting
  /// ends, and the photo after it slides into its place: a step forward has
  /// then been taken already, so [step] is given one less.
  Future<void> stepGuarded(int delta, void Function(int delta) step) async {
    final controller = _photoController;
    if (controller == null || !controller.isUnlocked) {
      step(delta);
      return;
    }
    final keptOnly = _keptOnly;
    if (await cancelSitting(context, controller) && mounted) {
      step(keptOnly && delta > 0 ? delta - 1 : delta);
    }
  }

  /// Closes the viewer; while unlocked, through the check, as the close
  /// button and the swipe down pop past the leave guard.
  void closeGuarded() {
    if (!editingOffered) return Navigator.of(context).pop();
    unawaited(() async {
      if (await leaveGuarded() && mounted) Navigator.of(context).pop();
    }());
  }

  /// For a way out that `PopScope` does not see (the close button, the
  /// swipe down, Go to dive): true when the viewer may go, the photo locked.
  Future<bool> leaveGuarded() async {
    final controller = _photoController;
    if (controller == null || !controller.isUnlocked) return true;
    return cancelSitting(context, controller);
  }

  /// Escape while unlocked: Cancel, asking first when there are changes.
  Future<void> cancelPhotoSitting() async {
    final controller = _photoController;
    if (controller != null) await cancelSitting(context, controller);
  }

  Future<void> savePhotoAndReport() async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    final controller = photoEditController;
    final saved = await controller.save();
    final error = controller.saveError;
    if (saved || error == null) return;
    // Deleted while the save ran: the sitting is over, as when the photo
    // goes at any other moment.
    if (error is PhotoGoneError) {
      if (mounted) _lockAsGone(controller);
      return;
    }
    // A photo moved to another dive can never be saved, nor a relink to a
    // file that changed since it was located: say so, and how to go on,
    // rather than invite a retry.
    final message = switch (error) {
      PhotoMovedError() => l10n.media_viewer_movedWhileEditing,
      LocatedFileChangedError() => l10n.media_viewer_locatedFileChanged,
      _ => l10n.recordEdit_saveFailed,
    };
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _savePhotoSitting(EditSession<PhotoRecord> session) async {
    // Read now: the write may finish after the viewer has gone.
    final service = ref.read(photoEditSaveServiceProvider);
    final enricher = ref.read(diveMediaEnricherProvider);
    final diverId = ref.read(validatedCurrentDiverIdProvider.future);
    final changed = session.changedCardIds;
    final diveId = session.stored.item.diveId;
    // A held relink's new bookmark is taken back if the write does not
    // commit.
    await undoRelinkOnFailure(
      session,
      () async => service.save(
        mediaId: session.stored.item.id,
        diverId: await diverId,
        apply: session.applyTo,
        changedCardIds: changed,
        alsoWrite: session.hasHeldWrites ? session.runHeldWrites : null,
        alsoWriteIsAChange: session.hasHeldChanges,
        // Moved to another dive meanwhile: its time and its writes to the
        // dive were made for the dive it was on.
        diveAtStart: _diveAtUnlock,
      ),
    );
    // The write is committed. What a relink left for now (the upload of
    // different bytes, the cache's drop) and placing the dive's photos
    // again are each best effort: a failure here is not a failed save.
    for (final step in relinkAfterCommit(session)) {
      try {
        await step();
      } catch (error, stackTrace) {
        _log.error(
          "A relink's work after its committed save failed",
          error: error,
          stackTrace: stackTrace,
        );
      }
    }
    if (diveId == null || !changed.contains(photoTimeCardId)) return;
    try {
      await enricher.enrichMissingForDive(diveId);
    } catch (error, stackTrace) {
      _log.error(
        'Placing the photos of dive $diveId after a save failed',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  /// [child] with the leave check and the scope the viewer's controls read
  /// the sitting from, when the viewer offers editing.
  /// [backsOutFirst] says when Back closes a step of the viewer's own
  /// first (fullscreen), leaving the sitting as it is.
  Widget photoEditScope({
    required Widget child,
    bool Function()? backsOutFirst,
  }) {
    if (!editingOffered) return child;
    final controller = photoEditController;
    return RecordEditLeaveGuard<PhotoRecord>(
      controller: controller,
      backsOutFirst: backsOutFirst,
      child: RecordEditScope<PhotoRecord>(controller: controller, child: child),
    );
  }

  void disposePhotoEditing() {
    _listened?.removeListener(_onSittingChanged);
    _photoController
      ?..removeListener(_onPhotoEditChanged)
      ..dispose();
  }
}
