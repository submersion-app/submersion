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
class WindowsMlEngines implements HardwareEngines {
  WindowsMlEngines([this._catalogue = const WinMlCatalog()]);

  final WinMlCatalogue _catalogue;
  final _log = LoggerService.forClass(WindowsMlEngines);

  @override
  Future<bool> offersEngineToFetch() async =>
      (await _engines()).any((e) => e.state != WinMlReadyState.ready);

  @override
  Future<bool> fetchEngine() async {
    var anyReady = false;
    for (final engine in await _engines()) {
      if (engine.state == WinMlReadyState.ready) continue;
      try {
        final ready = await _catalogue.ensureReady(engine.name);
        _log.info('Windows ML engine ${engine.name}: ready $ready');
        anyReady = anyReady || ready;
      } on Object catch (e) {
        _log.warning(
          'Windows ML engine ${engine.name} did not arrive',
          error: e,
        );
      }
    }
    return anyReady;
  }

  @override
  Future<List<ProviderLibrary>> readyProviderLibraries() async => [
    for (final engine in await _engines())
      if (engine.state == WinMlReadyState.ready &&
          engine.libraryPath.isNotEmpty)
        (name: engine.name, path: engine.libraryPath),
  ];

  Future<List<WinMlEngine>> _engines() async {
    try {
      return await _catalogue.engines();
    } on Object catch (e) {
      _log.warning('Windows ML catalogue unreadable', error: e);
      return const [];
    }
  }
}
