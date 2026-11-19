import 'dart:async';
import 'dart:collection';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/services/media_location.dart';
import 'package:submersion/features/species_id/data/services/media_identification_service.dart';
import 'package:submersion/features/species_id/domain/entities/dive_species_run_state.dart';

/// Where a dive is, for naming its media, and whether it still exists.
typedef DiveLocation = ({bool exists, GeoPoint? site, GeoPoint? entry});

/// Find species: looks at every photo and video linked to a dive, on the
/// diver's request (issue #4727). One dive at a time; another waits its
/// turn. Photos go first, so the quick results arrive first.
///
/// It pauses before the next item when the app goes to the background or
/// the device is too warm, and stops after the item in progress when
/// cancelled, another logbook is opened, or the dive is deleted. What it
/// found is applied (confident matches tagged, when the setting is on) all
/// together when it ends, as one History entry.
class DiveSpeciesRun extends StateNotifier<Map<String, DiveSpeciesRunState>> {
  DiveSpeciesRun({
    required Future<List<MediaItem>> Function(String diveId) mediaForDive,
    required Future<DiveLocation> Function(String diveId) diveLocation,
    required Future<RunItemOutcome> Function(MediaItem, GeoPoint?) request,
    required void Function(String mediaId) cancel,
    required Future<int> Function(List<RunAppliedItem> items) applyAll,
    required int Function() databaseGeneration,
  }) : _mediaForDive = mediaForDive,
       _diveLocation = diveLocation,
       _request = request,
       _cancelItem = cancel,
       _applyAll = applyAll,
       _generation = databaseGeneration,
       super(const {});

  final Future<List<MediaItem>> Function(String) _mediaForDive;
  final Future<DiveLocation> Function(String) _diveLocation;
  final Future<RunItemOutcome> Function(MediaItem, GeoPoint?) _request;
  final void Function(String) _cancelItem;
  final Future<int> Function(List<RunAppliedItem>) _applyAll;
  final int Function() _generation;

  final _queue = Queue<String>();
  final _finished = <String, Completer<void>>{};
  String? _current;
  String? _currentItem;
  bool _cancelRequested = false;
  bool _inBackground = false;
  bool _tooHot = false;
  Completer<void>? _resumed;
  bool _disposed = false;

  /// [diveId]'s run, or null when it has none.
  DiveSpeciesRunState? stateOf(String diveId) => state[diveId];

  /// Starts a run for [diveId], or queues it behind the one running.
  /// Completes when that dive's run ends.
  Future<void> start(String diveId) {
    final existing = _finished[diveId];
    if (existing != null && !existing.isCompleted) return existing.future;
    final done = Completer<void>();
    _finished[diveId] = done;
    _queue.add(diveId);
    _set(DiveSpeciesRunState(diveId: diveId));
    if (_current == null) unawaited(_drain());
    return done.future;
  }

  /// Stops [diveId]'s run after the item in progress, or drops it if it
  /// has not started.
  void cancel(String diveId) {
    if (_queue.remove(diveId)) {
      _set(state[diveId]!.copyWith(phase: DiveRunPhase.cancelled));
      _finished[diveId]?.complete();
      return;
    }
    if (_current != diveId) return;
    _cancelRequested = true;
    final item = _currentItem;
    if (item != null) _cancelItem(item);
    _wake();
  }

  /// Carries on after the device cooled down.
  void resume(String diveId) {
    if (_current != diveId) return;
    _tooHot = false;
    _wake();
  }

  void appPaused() => _inBackground = true;

  void appResumed() {
    _inBackground = false;
    _wake();
  }

  @override
  void dispose() {
    _disposed = true;
    _cancelRequested = true;
    _wake();
    super.dispose();
  }

  Future<void> _drain() async {
    while (_queue.isNotEmpty && !_disposed) {
      final diveId = _queue.removeFirst();
      _current = diveId;
      _cancelRequested = false;
      _tooHot = false;
      try {
        await _run(diveId);
      } finally {
        _current = null;
        _currentItem = null;
        _finished[diveId]?.complete();
      }
    }
  }

  Future<void> _run(String diveId) async {
    final generation = _generation();
    var where = await _diveLocation(diveId);
    final items = [
      for (final m in await _mediaForDive(diveId))
        if (m.mediaType == MediaType.photo) m,
      for (final m in await _mediaForDive(diveId))
        if (m.mediaType == MediaType.video) m,
    ];
    var s = (state[diveId] ?? DiveSpeciesRunState(diveId: diveId)).copyWith(
      phase: DiveRunPhase.running,
      total: items.length,
      done: 0,
      summary: const DiveRunSummary(),
    );
    _set(s);
    final looked = <RunAppliedItem>[];
    var stoppedFor = _Stop.none;
    var index = 0;
    while (index < items.length) {
      stoppedFor = await _waitToGo(diveId, generation);
      if (stoppedFor != _Stop.none) break;
      final item = items[index];
      _currentItem = item.id;
      final outcome = await _request(
        item,
        mediaLocation(
          item,
          siteLocation: where.site,
          entryLocation: where.entry,
        ),
      );
      _currentItem = null;
      if (_disposed) return;
      if (_generation() != generation) {
        stoppedFor = _Stop.logbook;
        break;
      }
      where = await _diveLocation(diveId);
      if (!where.exists) {
        stoppedFor = _Stop.diveGone;
        break;
      }
      if (outcome == RunItemOutcome.tooHot && !_cancelRequested) {
        _tooHot = true;
        continue;
      }
      if (outcome == RunItemOutcome.notForeground && !_cancelRequested) {
        _inBackground = true;
        continue;
      }
      final video = item.mediaType == MediaType.video;
      if (outcome == RunItemOutcome.done) {
        looked.add((mediaId: item.id, isVideo: video));
      }
      s = s.copyWith(
        done: index + 1,
        summary: s.summary.copyWith(
          photos: s.summary.photos + (video ? 0 : 1),
          videos: s.summary.videos + (video ? 1 : 0),
          unreadable:
              s.summary.unreadable +
              (outcome == RunItemOutcome.unreadable ? 1 : 0),
        ),
      );
      _set(s);
      index++;
      if (_cancelRequested) {
        stoppedFor = _Stop.cancelled;
        break;
      }
    }
    if (stoppedFor == _Stop.none && _cancelRequested) {
      stoppedFor = _Stop.cancelled;
    }
    var tagged = 0;
    // Another logbook, or a dive that is gone, has nothing left to tag.
    if (looked.isNotEmpty &&
        stoppedFor != _Stop.logbook &&
        stoppedFor != _Stop.diveGone &&
        !_disposed) {
      tagged = await _applyAll(looked);
    }
    if (_disposed) return;
    _set(
      s.copyWith(
        phase: stoppedFor == _Stop.none
            ? DiveRunPhase.finished
            : DiveRunPhase.cancelled,
        pauseReason: () => null,
        summary: s.summary.copyWith(speciesTagged: tagged),
      ),
    );
  }

  /// Waits while paused; says why the run must stop instead, if it must.
  Future<_Stop> _waitToGo(String diveId, int generation) async {
    while (true) {
      if (_disposed || _cancelRequested) return _Stop.cancelled;
      if (_generation() != generation) return _Stop.logbook;
      final reason = _tooHot
          ? DiveRunPause.tooHot
          : _inBackground
          ? DiveRunPause.background
          : null;
      if (reason == null) {
        final current = state[diveId];
        if (current != null && current.phase == DiveRunPhase.paused) {
          _set(
            current.copyWith(
              phase: DiveRunPhase.running,
              pauseReason: () => null,
            ),
          );
        }
        return _Stop.none;
      }
      _set(
        state[diveId]!.copyWith(
          phase: DiveRunPhase.paused,
          pauseReason: () => reason,
        ),
      );
      final resumed = _resumed = Completer<void>();
      await resumed.future;
    }
  }

  void _wake() {
    final resumed = _resumed;
    _resumed = null;
    if (resumed != null && !resumed.isCompleted) resumed.complete();
  }

  void _set(DiveSpeciesRunState s) {
    if (_disposed) return;
    state = {...state, s.diveId: s};
  }
}

enum _Stop { none, cancelled, logbook, diveGone }
