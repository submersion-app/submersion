import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/features/media/data/services/media_file_types.dart';
import 'package:submersion/features/media/domain/value_objects/matched_selection.dart';
import 'package:submersion/features/media/domain/value_objects/media_attach_target.dart';
import 'package:submersion/features/media/presentation/providers/files_tab_providers.dart';
import 'package:submersion/features/media/presentation/widgets/file_review_pane.dart';
import 'package:submersion/features/media/presentation/helpers/files_tab_staging.dart';
import 'package:submersion/features/media/presentation/helpers/offer_site_review_after_import.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Files tab in the photo picker.
///
/// Phase 2 / Task 9: minimal skeleton with a "Pick files…" action that
/// runs EXIF extraction and stashes results in [filesTabNotifierProvider].
///
/// Phase 2 / Task 10: adds a "Pick a folder…" action that enumerates
/// eligible media files in a background isolate (via [compute]), an
/// auto-match-by-date checkbox, and routes extracted files through
/// [DivePhotoMatcher] before stashing the result.
///
/// Phase 2 / Task 11: review pane wired in via [FileReviewPane].
///
/// Commit flow (Task 13) layers on top.
///
/// Photos and videos: the picker uses `FileType.media`, the folder enumerator
/// admits `.mp4/.mov/.m4v`, and the commit loop persists each with its
/// [MediaType]. A picked file's capture time comes from its own metadata
/// (JPEG EXIF or the MP4/MOV `mvhd`) via the `ExifExtractor`, so both match
/// dives on every platform.
///
/// Playback caveat: `PhotoViewerPage` resolves a local-file video by
/// `localPath`, which is populated on macOS/Windows/Linux but null on iOS
/// (where only a security-scoped bookmark is stored). Local-file video
/// playback on iOS therefore still needs bookmark->path resolution; until
/// then an iOS-imported video matches and stores but shows the viewer's
/// video-unavailable state rather than playing.
class FilesTab extends ConsumerWidget {
  const FilesTab({super.key, this.target});

  /// What this picker session attaches its files to, when it has an owner.
  ///
  /// A [DiveAttachTarget] backs the review pane's "add all to this dive"
  /// action and makes turning auto-match off produce a usable selection
  /// instead of an inert one: [FilesTabNotifier.commit] only persists files
  /// sitting in [MatchedSelection.matched], so without a manual target a
  /// photo the date matcher rejected had no route into the database.
  ///
  /// A [SiteAttachTarget] switches the tab out of dive mode entirely; see
  /// [_isSiteSession]. Null when the picker was opened with no owning entity
  /// (the library importer), where the matcher is the only thing that can
  /// assign one.
  final MediaAttachTarget? target;

  /// A site session drops every dive affordance: the auto-match checkbox,
  /// the matcher itself, the dive-grouped review pane, and the per-file
  /// assign actions.
  ///
  /// Dive matching against a site is not merely useless, it is wrong. A site
  /// has no time window, so the matcher compares the photo against every
  /// dive in the log and either finds nothing (the issue #1098 symptom: no
  /// group, therefore no commit button, therefore no way to save) or routes
  /// the photo to some dive the user never mentioned.
  bool get _isSiteSession => target is SiteAttachTarget;

  /// The dive files may be manually assigned to, or null when there isn't
  /// one to offer.
  String? get _assignableDiveId => switch (target) {
    DiveAttachTarget(:final diveId) => diveId,
    SiteAttachTarget() || null => null,
  };

  // coverage:ignore-start
  // FilePicker.pickFiles is a static method on package:file_picker; not
  // unit-testable from flutter_test without a custom DI seam. What happens to
  // the picked paths is [stageFilesForReview], covered by
  // files_tab_staging_test; the build() branches it drives (extraction
  // progress, empty/non-empty file lists) are covered by files_tab_test.
  Future<void> _pickFiles(BuildContext context) async {
    final container = ProviderScope.containerOf(context, listen: false);
    // FileType.media admits both images and videos at the OS picker layer.
    // Their capture time is recovered by ExifExtractor (JPEG EXIF or the
    // MP4/MOV mvhd) so both match dives; see class doc.
    final result = await FilePicker.pickFiles(type: FileType.media);
    if (result.isEmpty) return;

    final paths = [for (final pf in result) ?pf.path];
    await stageFilesForReview(container, paths, target: target);
  }

  Future<void> _pickFolder(BuildContext context) async {
    final container = ProviderScope.containerOf(context, listen: false);
    final dirPath = await FilePicker.getDirectoryPath();
    if (dirPath == null) return;

    // Enumerate eligible files in a background isolate so the main
    // isolate stays responsive on large folder trees.
    final paths = await compute(scanFolderForMediaFiles, dirPath);
    if (paths.isEmpty) return;

    await stageFilesForReview(container, paths, target: target);
  }
  // coverage:ignore-end

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(filesTabNotifierProvider);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  icon: const Icon(Icons.upload_file),
                  label: Text(
                    context.l10n.media_photoPicker_files_pickFilesButton,
                  ),
                  // coverage:ignore-start
                  onPressed: () => _pickFiles(context),
                  // coverage:ignore-end
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: FilledButton.icon(
                  icon: const Icon(Icons.folder_open),
                  label: Text(
                    context.l10n.media_photoPicker_files_pickFolderButton,
                  ),
                  // coverage:ignore-start
                  onPressed: () => _pickFolder(context),
                  // coverage:ignore-end
                ),
              ),
            ],
          ),
          // Dives are not this session's business when a site is the target,
          // so the option is hidden rather than shown-and-ignored.
          if (!_isSiteSession)
            Row(
              children: [
                Checkbox(
                  value: state.autoMatchByDate,
                  onChanged: (_) => ref
                      .read(filesTabNotifierProvider.notifier)
                      .toggleAutoMatch(),
                ),
                Expanded(
                  child: Text(
                    context.l10n.media_photoPicker_files_autoMatchLabel,
                  ),
                ),
              ],
            ),
          if (state.isExtracting) ...[
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: state.totalToExtract == 0
                  ? null
                  : state.extractedCount / state.totalToExtract,
            ),
          ],
          const SizedBox(height: 24),
          Expanded(
            child: state.files.isEmpty
                ? Center(
                    child: Text(
                      context.l10n.media_photoPicker_files_emptyHint,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  )
                : FileReviewPane(
                    state: state,
                    assignableDiveId: _assignableDiveId,
                    flat: _isSiteSession,
                  ),
          ),
          // Rendered for anything staged, disabled when nothing is
          // committable, rather than hidden. Hiding it (issue #1098) left a
          // user who had picked files staring at a screen with no way to
          // accept them and no explanation; the URL tab's always-present
          // "Add" is the convention being matched here.
          if (state.files.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _committableCount(state) == 0
                      ? null
                      // coverage:ignore-start
                      : () => _commit(context, ref),
                  // coverage:ignore-end
                  child: Text(_commitLabel(context, state)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// How many staged files [FilesTabNotifier.commit] would actually persist.
  int _committableCount(FilesTabState state) => _isSiteSession
      ? state.files.length
      : state.match.totalFiles - state.match.unmatched.length;

  String _commitLabel(BuildContext context, FilesTabState state) {
    final count = _committableCount(state);
    return _isSiteSession
        ? context.l10n.media_photoPicker_files_attachToSiteButton(count)
        : context.l10n.media_photoPicker_files_linkButton(count);
  }

  // coverage:ignore-start
  // _commit drives `commit()` (covered separately in
  // files_tab_providers_test) and a SnackBar with an Undo action; both rely
  // on framework-driven async-with-context-mounted timing that flutter_test
  // can't deterministically pump without a real Navigator. Behaviour is
  // exercised by manual desktop smoke tests + by the notifier unit tests.
  Future<void> _commit(BuildContext context, WidgetRef ref) async {
    final notifier = ref.read(filesTabNotifierProvider.notifier);
    // Captured with the messenger and navigator: all three read from context,
    // which must not be touched after the await below.
    final l10n = context.l10n;
    // The picker uses a bare Scaffold, so this resolves to the root
    // ScaffoldMessenger, which outlives the pop below and shows the snackbar
    // on the dive-detail view we return to.
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    // commit() clears the staged state, so snapshot the dives first.
    final diveIds = ref
        .read(filesTabNotifierProvider)
        .match
        .matched
        .keys
        .toList();
    final created = await notifier.commit(target: target);
    if (!context.mounted) return;
    // Both snackbars go to the root messenger and so are enqueued before the
    // pop, which is what keeps `ref` and `context` alive for the site-review
    // offer below; the messenger outlives the pop either way.
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          _isSiteSession
              ? l10n.media_photoPicker_files_attachedToSiteCount(created.length)
              : l10n.media_photoPicker_files_linkedCount(created.length),
        ),
        action: SnackBarAction(
          label: l10n.media_photoPicker_files_undo,
          onPressed: () => notifier.undoCommit(created),
        ),
      ),
    );
    if (!_isSiteSession) {
      await offerSiteReviewAfterImport(
        context,
        ref,
        diveIds,
        messenger: messenger,
      );
    }
    if (!context.mounted) return;
    // Return to the detail view now that the files are linked; the grid
    // refreshes reactively via mediaForDiveProvider's watchDiveDetailChanges,
    // and mediaForSiteProvider's invalidateSelfWhen(watchMediaChanges) does
    // the same for a site.
    navigator.pop();
  }

  // coverage:ignore-end
}
