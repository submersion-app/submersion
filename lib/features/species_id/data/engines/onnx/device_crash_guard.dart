import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:submersion_vision/onnx_runtime.dart';

import 'package:submersion/core/services/logger_service.dart';

/// Keeps a device that ended the app from doing it again. Opening models on
/// a hardware engine or DirectML can end the process outright, with no error
/// to catch (findings, docs/design/findings/2026-11-20-windows-ml-unpackaged.md),
/// and identification may start by itself when the app opens, so one bad
/// driver could make the app close at every launch.
///
/// Before a load the devices about to be tried are written down, and the note
/// is removed once the load returns, worked or failed. A note still there at
/// the next start means the app ended during that load: the first of its
/// devices not yet skipped is skipped from then on (the hardware engine, then
/// DirectML; never the processor). A newly fetched engine clears the skips.
/// Every failure to read or write here is ignored: the guard only ever
/// removes devices, so losing its notes costs at most one more try.
class DeviceCrashGuard {
  DeviceCrashGuard(this._dir);

  /// The guard's place on this PC: the system temporary folder, which
  /// survives a restart and is the system's to clear.
  factory DeviceCrashGuard.forThisDevice() => DeviceCrashGuard(
    Directory(p.join(Directory.systemTemp.path, 'submersion_species_id')),
  );

  final Directory _dir;
  final _log = LoggerService.forClass(DeviceCrashGuard);

  File get _loading => File(p.join(_dir.path, 'onnx_load_in_progress'));
  File get _skipped => File(p.join(_dir.path, 'onnx_devices_skipped'));

  /// [wanted], without the devices an earlier load ended the app on; never
  /// empty, since the processor is never skipped.
  Future<List<OrtDevice>> devicesFor(List<OrtDevice> wanted) async {
    final skipped = await _read(_skipped);
    final interrupted = await _read(_loading);
    if (interrupted.isNotEmpty) {
      final culprit = interrupted
          .where((d) => d != OrtDevice.cpu.name && !skipped.contains(d))
          .firstOrNull;
      if (culprit != null) {
        skipped.add(culprit);
        _log.warning(
          'The app ended while opening models on $culprit; '
          'it is skipped from now on',
        );
        await _write(_skipped, skipped);
      }
      await _delete(_loading);
    }
    final left = [
      for (final device in wanted)
        if (!skipped.contains(device.name)) device,
    ];
    return left.isEmpty ? const [OrtDevice.cpu] : left;
  }

  /// Notes that a load on [devices] is starting.
  Future<void> loading(List<OrtDevice> devices) =>
      _write(_loading, {for (final d in devices) d.name});

  /// Notes that the load returned.
  Future<void> loaded() => _delete(_loading);

  /// Forgets the skipped devices: a new engine arrived.
  Future<void> reset() => _delete(_skipped);

  Future<Set<String>> _read(File file) async {
    try {
      if (!await file.exists()) return <String>{};
      return {
        for (final line in await file.readAsLines())
          if (line.trim().isNotEmpty) line.trim(),
      };
    } on FileSystemException {
      return <String>{};
    }
  }

  /// Keeps the order the devices were tried in, one per line.
  Future<void> _write(File file, Set<String> names) async {
    try {
      await _dir.create(recursive: true);
      await file.writeAsString(names.join('\n'), flush: true);
    } on FileSystemException catch (e) {
      _log.warning('Could not note the devices being tried', error: e);
    }
  }

  Future<void> _delete(File file) async {
    try {
      if (await file.exists()) await file.delete();
    } on FileSystemException catch (e) {
      _log.warning('Could not clear a device note', error: e);
    }
  }
}
