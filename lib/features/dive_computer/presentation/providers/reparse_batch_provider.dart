import 'package:libdivecomputer_plugin/libdivecomputer_plugin.dart' as pigeon;

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/dive_computer/data/services/reparse_batch_service.dart';
import 'package:submersion/features/dive_computer/presentation/providers/reparse_providers.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_repository_provider.dart';

final _log = LoggerService.forClass(ReparseBatchNotifier);

/// Progress of a batch re-parse (issue #224).
sealed class ReparseBatchState {
  const ReparseBatchState();
}

class ReparseBatchIdle extends ReparseBatchState {
  const ReparseBatchIdle();
}

class ReparseBatchRunning extends ReparseBatchState {
  const ReparseBatchRunning({
    required this.done,
    required this.total,
    this.cancelling = false,
  });

  final int done;
  final int total;

  /// Cancel was pressed; the run stops once the current dive is finished.
  final bool cancelling;
}

class ReparseBatchFinished extends ReparseBatchState {
  const ReparseBatchFinished({
    required this.result,
    required this.failedDives,
    this.runError,
  });

  final ReparseBatchResult result;

  /// [ReparseBatchResult.failures] with what the results list shows of each.
  final List<ReparseFailedDive> failedDives;

  /// Set when the run itself failed before or between dives (the database
  /// could not be read, say), rather than any one dive.
  final String? runError;
}

/// A dive the run could not re-parse, as the results list shows it. The
/// dive's own fields are null when it could not be read back (deleted while
/// the run was going, say).
class ReparseFailedDive {
  const ReparseFailedDive({
    required this.diveId,
    required this.error,
    this.diveNumber,
    this.date,
    this.siteName,
  });

  final String diveId;
  final String error;
  final int? diveNumber;
  final DateTime? date;
  final String? siteName;
}

/// The native parse call. Overridden in tests.
final reparseParseFnProvider = Provider<RawDiveParseFn>(
  (ref) => pigeon.DiveComputerHostApi().parseRawDiveData,
);

/// Reads the failed dives back for the results list. Overridden in tests.
final reparseDiveLookupProvider =
    Provider<Future<List<Dive>> Function(List<String> diveIds)>((ref) {
      final repository = ref.watch(diveRepositoryProvider);
      return repository.getDivesByIdsWithoutSamples;
    });

/// Owns one batch re-parse at a time, so its dialog can be rebuilt without
/// losing the run.
class ReparseBatchNotifier extends StateNotifier<ReparseBatchState> {
  ReparseBatchNotifier(this._ref) : super(const ReparseBatchIdle());

  final Ref _ref;
  bool _cancelRequested = false;

  /// Re-parses [diveIds], only [computerId]'s sources when given. Does
  /// nothing while a run is already going.
  Future<void> start(List<String> diveIds, {String? computerId}) async {
    if (state is ReparseBatchRunning) return;
    _cancelRequested = false;
    state = ReparseBatchRunning(done: 0, total: diveIds.length);
    final ReparseBatchResult result;
    try {
      result = await _ref
          .read(reparseBatchServiceProvider)
          .run(
            diveIds,
            parseFn: _ref.read(reparseParseFnProvider),
            computerId: computerId,
            onProgress: (done, total) {
              if (mounted) {
                state = ReparseBatchRunning(
                  done: done,
                  total: total,
                  cancelling: _cancelRequested,
                );
              }
            },
            isCancelled: () => _cancelRequested,
          );
    } catch (e, stackTrace) {
      // Each dive's failure is caught inside the run; this is the run itself
      // failing, which must still end the dialog's progress state.
      _log.error('Batch re-parse failed', error: e, stackTrace: stackTrace);
      if (!mounted) return;
      final done = switch (state) {
        ReparseBatchRunning(:final done) => done,
        _ => 0,
      };
      state = ReparseBatchFinished(
        // How many of the [done] dives succeeded is lost with the run, so
        // none is claimed; the dialog shows the error and the rest.
        result: ReparseBatchResult(
          total: diveIds.length,
          succeeded: 0,
          skipped: 0,
          notProcessed: diveIds.length - done,
          profilesPreserved: 0,
          failures: const [],
        ),
        failedDives: const [],
        runError: e.toString(),
      );
      return;
    }
    final failedDives = await _describe(result.failures);
    if (!mounted) return;
    state = ReparseBatchFinished(result: result, failedDives: failedDives);
  }

  Future<List<ReparseFailedDive>> _describe(
    List<ReparseDiveFailure> failures,
  ) async {
    if (failures.isEmpty) return const [];
    var dives = const <String, Dive>{};
    try {
      final found = await _ref.read(reparseDiveLookupProvider)([
        for (final f in failures) f.diveId,
      ]);
      dives = {for (final d in found) d.id: d};
    } catch (e, stackTrace) {
      // The list still shows each failure and its error, without the dive's
      // number, date and site.
      _log.error(
        'Could not read back failed re-parse dives',
        error: e,
        stackTrace: stackTrace,
      );
    }
    return [
      for (final f in failures)
        ReparseFailedDive(
          diveId: f.diveId,
          error: f.error,
          diveNumber: dives[f.diveId]?.diveNumber,
          date: dives[f.diveId]?.effectiveEntryTime,
          siteName: dives[f.diveId]?.site?.name,
        ),
    ];
  }

  void cancel() {
    _cancelRequested = true;
    final current = state;
    if (current is ReparseBatchRunning) {
      state = ReparseBatchRunning(
        done: current.done,
        total: current.total,
        cancelling: true,
      );
    }
  }

  void reset() {
    if (state is! ReparseBatchRunning) state = const ReparseBatchIdle();
  }
}

final reparseBatchProvider =
    StateNotifierProvider<ReparseBatchNotifier, ReparseBatchState>(
      (ref) => ReparseBatchNotifier(ref),
    );
