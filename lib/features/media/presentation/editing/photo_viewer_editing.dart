import 'package:flutter/material.dart';

import 'package:submersion/core/models/log_entry.dart';
import 'package:submersion/core/platform/device_capabilities.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/photo_record.dart';
import 'package:submersion/features/media/presentation/editing/photo_edit_fields.dart';
import 'package:submersion/features/media/presentation/providers/media_providers.dart';
import 'package:submersion/features/media/presentation/providers/photo_editing_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';
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
  /// Whether the page was built with editing on (the build switch).
  bool get unlockEditingRequested;

  /// Told on every lock, by whatever route, so the page closes the panels and
  /// modes that change the photo.
  void onPhotoLocked();

  RecordEditController<PhotoRecord>? _photoController;
  bool _wasUnlocked = false;

  /// The sitting the viewer listens to. Its controller tells the page only
  /// when the set of changes moves; the viewer redraws the photo, its chips
  /// and boxes on every change (taps and picks, never keystrokes).
  EditSession<PhotoRecord>? _listened;

  /// Whether this viewer offers the lock: built with editing on, on a device
  /// that can change media at all.
  bool get editingOffered =>
      unlockEditingRequested &&
      ref.read(deviceCapabilitiesProvider).mediaAttach;

  /// Created on first use, so a viewer that never offers editing has none.
  RecordEditController<PhotoRecord> get photoEditController =>
      _photoController ??= RecordEditController<PhotoRecord>(
        onSave: _savePhotoSitting,
      )..addListener(_onPhotoEditChanged);

  /// The sitting, while the photo on screen is unlocked.
  EditSession<PhotoRecord>? get photoSitting => _photoController?.session;

  bool get photoUnlocked => _photoController?.isUnlocked ?? false;

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
    if (_wasUnlocked && !unlocked) onPhotoLocked();
    _wasUnlocked = unlocked;
    setState(() {});
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
    });
    final stored = ref.watch(photoRecordProvider(id)).value;
    return stored?.item.id == onScreen.id ? stored : null;
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

  /// The sitting's photo is no longer stored, or no longer in the list: the
  /// sitting ends, and the diver is told nothing was saved.
  void _endForGonePhoto() {
    final controller = _photoController;
    if (controller == null || !controller.isUnlocked) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !controller.isUnlocked) return;
      final messenger = ScaffoldMessenger.maybeOf(context);
      final message = context.l10n.media_viewer_photoGoneWhileEditing;
      controller.lock();
      messenger?.showSnackBar(SnackBar(content: Text(message)));
    });
  }

  /// Where the sitting's photo is in [list], or null when it is not there.
  /// A photo gone from the list ends the sitting.
  int? sittingIndexIn(List<MediaItem> list) {
    final id = _sittingId;
    if (id == null) return null;
    final index = list.indexWhere((m) => m.id == id);
    if (index < 0) {
      _endForGonePhoto();
      return null;
    }
    return index;
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

  /// Steps to another photo through the check: with changes it asks first;
  /// either way the photo is locked before [step], so every photo opens
  /// locked.
  Future<void> stepGuarded(VoidCallback step) async {
    final controller = _photoController;
    if (controller == null || !controller.isUnlocked) {
      step();
      return;
    }
    if (await cancelSitting(context, controller) && mounted) step();
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
    if (saved || controller.saveError == null) return;
    messenger.showSnackBar(SnackBar(content: Text(l10n.recordEdit_saveFailed)));
  }

  Future<void> _savePhotoSitting(EditSession<PhotoRecord> session) async {
    // Read now: the write may finish after the viewer has gone.
    final service = ref.read(photoEditSaveServiceProvider);
    final enricher = ref.read(diveMediaEnricherProvider);
    final diverId = ref.read(validatedCurrentDiverIdProvider.future);
    final changed = session.changedCardIds;
    final diveId = session.stored.item.diveId;
    await service.save(
      mediaId: session.stored.item.id,
      diverId: await diverId,
      apply: session.applyTo,
      changedCardIds: changed,
      alsoWrite: session.hasHeldWrites ? session.runHeldWrites : null,
      alsoWriteIsAChange: session.hasHeldChanges,
      // Moved to another dive meanwhile: its time and its writes to the dive
      // were made for the dive it was on.
      diveAtStart: _diveAtUnlock,
    );
    // The write is committed. Placing the dive's photos again is derived,
    // and best effort: a failure here is not a failed save.
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
  Widget photoEditScope({required Widget child}) {
    if (!editingOffered) return child;
    final controller = photoEditController;
    return RecordEditLeaveGuard<PhotoRecord>(
      controller: controller,
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
