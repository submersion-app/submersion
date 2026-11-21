import 'dart:async';

import 'package:submersion_vision/windows_ml.dart';

import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/species_id/data/engines/onnx/onnx_worker.dart';

/// The hardware engines a PC offers beyond DirectML and the processor: a
/// GPU or NPU vendor's engine, through Windows ML on Windows 11 24H2 and
/// later (design section 2a). Any engine offered is used, checked or not.
abstract interface class HardwareEngines {
  /// Whether an engine is offered that is not ready yet, so the pack's
  /// download would fetch it too.
  Future<bool> offersEngineToFetch();

  /// Prepares every offered engine that is not ready, downloading it from
  /// Microsoft where needed; true when one became ready. Never throws: an
  /// engine that fails to arrive leaves DirectML and the processor.
  Future<bool> fetchEngine();

  /// The ready engines' libraries, registered with ONNX Runtime before the
  /// models load.
  Future<List<ProviderLibrary>> readyProviderLibraries();
}

/// No engines beyond DirectML and the processor (every platform but
/// Windows).
class NoHardwareEngines implements HardwareEngines {
  const NoHardwareEngines();

  @override
  Future<bool> offersEngineToFetch() async => false;

  @override
  Future<bool> fetchEngine() async => false;

  @override
  Future<List<ProviderLibrary>> readyProviderLibraries() async => const [];
}

/// The engines Windows ML's catalogue offers. A catalogue that cannot be
/// read (an older Windows, a missing library) offers and registers
/// nothing, so the models still run on DirectML or the processor.
///
/// Windows ML adds an installed engine to the app's process anew each time
/// (it reads as not ready after every launch), so the engines are prepared
/// whenever a worker starts; that downloads nothing. Only an engine that is
/// not on the PC is fetched, during the pack's download.
class WindowsMlEngines implements HardwareEngines {
  WindowsMlEngines(
    this._catalogue, {
    this.fetchTimeout = const Duration(minutes: 20),
    this.prepareTimeout = const Duration(minutes: 2),
  });

  final WinMlCatalogue _catalogue;

  /// How long the engines' downloads may take, together, before the
  /// install goes on without them (about 200 MB each on a slow line).
  final Duration fetchTimeout;

  /// How long preparing an installed engine may take.
  final Duration prepareTimeout;

  final _log = LoggerService.forClass(WindowsMlEngines);

  @override
  Future<bool> offersEngineToFetch() async =>
      (await _engines()).any((e) => e.state == WinMlReadyState.notPresent);

  @override
  Future<bool> fetchEngine() async {
    // One timer keeps the deadline for every engine: a clock change cannot
    // move it, and whether time is left is read from the same timer that
    // ends a download, so the two can never disagree.
    final passed = Completer<void>();
    final timer = Timer(fetchTimeout, passed.complete);
    var anyReady = false;
    try {
      for (final engine in await _engines()) {
        if (engine.state != WinMlReadyState.notPresent) continue;
        if (passed.isCompleted) {
          _log.warning(
            'No time left to fetch Windows ML engine ${engine.name}',
          );
          break;
        }
        anyReady = await _fetch(engine.name, passed.future) || anyReady;
      }
    } finally {
      timer.cancel();
    }
    return anyReady;
  }

  /// Fetches [name] until [deadline]; never throws. A download the deadline
  /// cuts short goes on in its own isolate and does no harm.
  Future<bool> _fetch(String name, Future<void> deadline) async {
    try {
      final ready = await Future.any([
        _catalogue.ensureReady(name),
        deadline.then<bool>((_) => throw TimeoutException(null, fetchTimeout)),
      ]);
      _log.info('Windows ML engine $name: ready $ready');
      return ready;
    } on TimeoutException {
      _log.warning('Windows ML engine $name not fetched within $fetchTimeout');
    } on Object catch (e) {
      _log.warning('Windows ML engine $name did not arrive', error: e);
    }
    return false;
  }

  @override
  Future<List<ProviderLibrary>> readyProviderLibraries() async {
    var engines = await _engines();
    final installed = [
      for (final e in engines)
        if (e.state == WinMlReadyState.notReady) e.name,
    ];
    if (installed.isNotEmpty) {
      for (final name in installed) {
        await _prepare(name, prepareTimeout);
      }
      // A read that fails keeps the engines already known to be ready.
      engines = await _engines(orElse: engines);
    }
    return [
      for (final engine in engines)
        if (engine.state == WinMlReadyState.ready &&
            engine.libraryPath.isNotEmpty)
          (name: engine.name, path: engine.libraryPath),
    ];
  }

  /// Prepares [name], giving up after [limit]; never throws. A call that
  /// times out goes on in its own isolate and does no harm.
  Future<bool> _prepare(String name, Duration limit) async {
    try {
      final ready = await _catalogue.ensureReady(name).timeout(limit);
      _log.info('Windows ML engine $name: ready $ready');
      return ready;
    } on TimeoutException {
      _log.warning('Windows ML engine $name not ready after $limit');
    } on Object catch (e) {
      _log.warning('Windows ML engine $name did not arrive', error: e);
    }
    return false;
  }

  Future<List<WinMlEngine>> _engines({
    List<WinMlEngine> orElse = const [],
  }) async {
    try {
      return await _catalogue.engines();
    } on Object catch (e) {
      _log.warning('Windows ML catalogue unreadable', error: e);
      return orElse;
    }
  }
}
