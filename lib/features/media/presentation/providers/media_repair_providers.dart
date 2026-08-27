import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/media/data/repositories/media_repair_log_repository.dart';
import 'package:submersion/features/media/data/services/repair/folder_candidate_source.dart';
import 'package:submersion/features/media/data/services/repair/media_repair_service.dart';
import 'package:submersion/features/media/data/services/repair/photo_library_candidate_source.dart';
import 'package:submersion/features/media/data/services/repair/store_candidate_source.dart';
import 'package:submersion/features/media/data/services/volume_status.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_library_filter.dart';
import 'package:submersion/features/media/domain/services/media_repair_matcher.dart';
import 'package:submersion/features/media/domain/services/media_repair_types.dart';
import 'package:submersion/features/media/presentation/providers/media_library_providers.dart';
import 'package:submersion/features/media/presentation/providers/media_providers.dart';
import 'package:submersion/features/media/presentation/providers/media_resolver_providers.dart';
import 'package:submersion/features/media/presentation/providers/photo_picker_providers.dart';
import 'package:submersion/features/media_store/presentation/providers/media_store_providers.dart';

/// Which places the wizard searches.
class RepairWizardConfig {
  const RepairWizardConfig({
    this.folderRoots = const [],
    this.usePhotoLibrary = false,
    this.useStore = true,
  });

  final List<String> folderRoots;
  final bool usePhotoLibrary;
  final bool useStore;
}

sealed class RepairWizardState {
  const RepairWizardState();
}

class RepairWizardIdle extends RepairWizardState {
  const RepairWizardIdle();
}

class RepairWizardHarvesting extends RepairWizardState {
  const RepairWizardHarvesting();
}

class RepairWizardReview extends RepairWizardState {
  const RepairWizardReview({required this.proposals, this.prefixMove});

  final List<RepairProposal> proposals;
  final PrefixMove? prefixMove;
}

class RepairWizardApplying extends RepairWizardState {
  const RepairWizardApplying();
}

class RepairWizardDone extends RepairWizardState {
  const RepairWizardDone({required this.report});

  final RepairApplyReport report;
}

class RepairWizardError extends RepairWizardState {
  const RepairWizardError(this.error);

  final Object error;
}

/// The wizard's engine hooks, injectable for tests.
class RepairWizardNotifier extends StateNotifier<RepairWizardState> {
  RepairWizardNotifier({
    required this.loadMissingRows,
    required this.buildSources,
    required this.newVolumeProbe,
    required this.applyProposals,
  }) : super(const RepairWizardIdle());

  final Future<List<MediaItem>> Function() loadMissingRows;
  final List<CandidateSource> Function(RepairWizardConfig config) buildSources;

  /// Builds the volume probe for ONE harvest pass. A factory rather than a
  /// bare probe so each scan re-reads mount state (the user may plug the
  /// missing drive in between scans) while a single scan still probes each
  /// mount root once, however many rows live on it.
  final Future<bool> Function(String path) Function() newVolumeProbe;
  final Future<RepairApplyReport> Function(List<RepairProposal> proposals)
  applyProposals;

  static const _log = LoggerService('RepairWizardNotifier');

  final Set<String> _checked = {};
  List<RepairProposal> _proposals = const [];

  bool isChecked(String mediaId) => _checked.contains(mediaId);

  void toggleProposal(String mediaId) {
    if (!_checked.remove(mediaId)) _checked.add(mediaId);
    // Re-emit review so checkbox consumers rebuild.
    final current = state;
    if (current is RepairWizardReview) {
      state = RepairWizardReview(
        proposals: current.proposals,
        prefixMove: current.prefixMove,
      );
    }
  }

  Future<void> harvest(RepairWizardConfig config) async {
    state = const RepairWizardHarvesting();
    try {
      final rows = await loadMissingRows();

      // An unmounted volume is not broken: exclude those rows entirely so
      // the wizard never proposes replacing files that still exist.
      final isVolumeOnline = newVolumeProbe();
      final targets = <MediaItem>[];
      for (final row in rows) {
        final path = row.localPath ?? row.filePath;
        if (path != null && path.isNotEmpty && !await isVolumeOnline(path)) {
          continue;
        }
        targets.add(row);
      }

      final byFilename = <String, List<RepairCandidate>>{};
      final foundPaths = <String>{};
      for (final source in buildSources(config)) {
        final harvest = await source.harvest(targets);
        harvest.byFilename.forEach(
          (name, candidates) =>
              byFilename.putIfAbsent(name, () => []).addAll(candidates),
        );
        foundPaths.addAll(harvest.foundPaths);
      }

      final prefixMove = detectPrefixMove(
        brokenPaths: [
          for (final row in targets)
            if ((row.localPath ?? row.filePath) != null)
              (row.localPath ?? row.filePath)!,
        ],
        foundPaths: foundPaths,
      );

      _proposals = buildRepairProposals(
        brokenRows: targets,
        candidatesByFilename: byFilename,
        prefixMove: prefixMove,
        foundPaths: foundPaths,
      );

      _checked
        ..clear()
        ..addAll([
          for (final p in _proposals)
            if (p.confidence == RepairConfidence.exact ||
                p.confidence == RepairConfidence.probable)
              p.item.id,
        ]);

      state = RepairWizardReview(proposals: _proposals, prefixMove: prefixMove);
    } catch (e) {
      // Logged here because the pane shows a generic localized message: the
      // raw exception is untranslated and can name internal paths.
      _log.warning('Repair harvest failed: $e');
      state = RepairWizardError(e);
    }
  }

  Future<void> applyChecked() async {
    state = const RepairWizardApplying();
    try {
      final accepted = [
        for (final p in _proposals)
          if (_checked.contains(p.item.id) && p.candidate != null) p,
      ];
      final report = await applyProposals(accepted);
      state = RepairWizardDone(report: report);
    } catch (e) {
      _log.warning('Repair apply failed: $e');
      state = RepairWizardError(e);
    }
  }
}

final mediaRepairServiceProvider = Provider<MediaRepairService>((ref) {
  final platform = ref.watch(localMediaPlatformProvider);
  final storage = ref.watch(localBookmarkStorageProvider);
  return MediaRepairService(
    repository: ref.watch(mediaRepositoryProvider),
    queue: ref.watch(mediaTransferQueueRepositoryProvider),
    createBookmark: platform.createBookmark,
    writeBookmark: storage.write,
    log: ref.watch(mediaRepairLogRepositoryProvider),
  );
});

/// Per-device repair history (Media section Phase 5).
final mediaRepairLogRepositoryProvider = Provider<MediaRepairLogRepository>(
  (ref) => MediaRepairLogRepository(),
);

/// Newest repair history entries for the history view.
final repairHistoryProvider = FutureProvider<List<RepairLogEntry>>((ref) {
  final repo = ref.watch(mediaRepairLogRepositoryProvider);
  ref.invalidateSelfWhen(repo.watchRepairLogChanges());
  return repo.recent();
});

// no-tick: autoDispose, and the repository reads live inside callbacks the
// notifier invokes at action time rather than in this body -- there is no
// cached row here that could go stale. The wizard is opened, run, and
// disposed; re-running its scan on an unrelated media write is the bug, not
// the fix, since the scan is what writes media in the first place.
final repairWizardProvider =
    StateNotifierProvider.autoDispose<RepairWizardNotifier, RepairWizardState>((
      ref,
    ) {
      return RepairWizardNotifier(
        loadMissingRows: () async {
          final repo = ref.read(mediaLibraryRepositoryProvider);
          final diverId = ref.read(currentDiverIdProvider);
          final rows = <MediaItem>[];
          MediaLibraryCursor? cursor;
          // Page through every missing row: repairs operate on the full set,
          // not the first screenful.
          do {
            final page = await repo.getPage(
              diverId: diverId,
              filter: const MediaLibraryFilter(
                health: MediaHealthFilter.missing,
              ),
              after: cursor,
              limit: 200,
            );
            rows.addAll(page.entries.map((e) => e.item));
            cursor = page.nextCursor;
          } while (cursor != null);
          return rows;
        },
        buildSources: (config) => [
          if (config.folderRoots.isNotEmpty)
            FolderCandidateSource(roots: config.folderRoots),
          if (config.usePhotoLibrary)
            PhotoLibraryCandidateSource(
              picker: ref.read(photoPickerServiceProvider),
            ),
          if (config.useStore)
            StoreCandidateSource(
              // Lazy per-key HEAD: resolves the runtime when first needed so an
              // unconfigured store degrades to unverified candidates, never an
              // error.
              head: (key) async {
                final runtime = await ref.read(
                  mediaStoreRuntimeProvider.future,
                );
                final store = runtime?.store;
                if (store == null) return null;
                return store.head(key);
              },
            ),
        ],
        newVolumeProbe: () => VolumeStatus().newPassProbe(),
        applyProposals: (proposals) =>
            ref.read(mediaRepairServiceProvider).apply(proposals),
      );
    });
