import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:submersion_vision/onnx_runtime.dart';

import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/species_id/data/engines/onnx/onnx_worker_core.dart';

/// Keeps a device that ends the app from doing it again. Opening models on
/// a hardware engine or DirectML, or their first run there, can end the
/// process outright with no error to catch (findings,
/// docs/design/findings/2026-11-20-windows-ml-unpackaged.md), and
/// identification may start by itself when the app opens, so one bad driver
/// could make the app close at every launch.
///
/// The worker notes the device just before it opens a model there or runs
/// one for the first time, and removes the note once that returns, worked or
/// failed ([OpeningNote], [noteOpens], [FirstRunWatcher]). A note still there
/// when the next worker starts means the app ended meanwhile, and the device
/// it names takes a strike. Closing the app or a power cut during a load
/// does the same, so one strike is forgiven: a device is skipped from its
/// second strike in a row on, and a run that returns on a device clears that
/// device's single strike (a completed load does not, since a first run comes
/// after it). The processor is never skipped. A newly fetched engine clears the
/// hardware engine's strikes. Every failure to read or write here is
/// ignored: the guard only ever removes devices, so losing its notes costs
/// at most another try.
class DeviceCrashGuard {
  DeviceCrashGuard(this._dir);

  /// The guard's place on this PC: the system temporary folder, which
  /// survives a restart and is the system's to clear.
  factory DeviceCrashGuard.forThisDevice() => DeviceCrashGuard(
    Directory(p.join(Directory.systemTemp.path, 'submersion_species_id')),
  );

  /// Strikes from which a device is skipped.
  static const skipAt = 2;

  final Directory _dir;
  final _log = LoggerService.forClass(DeviceCrashGuard);

  /// Where the worker notes the device it is opening or first running on.
  String get openingNotePath => p.join(_dir.path, 'onnx_opening');

  File get _strikesFile => File(p.join(_dir.path, 'onnx_device_strikes'));

  /// [wanted], without the devices the app ended on twice in a row; never
  /// empty, since the processor is never skipped.
  Future<List<OrtDevice>> devicesFor(List<OrtDevice> wanted) async {
    final strikes = await _readStrikes();
    final note = File(openingNotePath);
    try {
      if (await note.exists()) {
        final culprit = (await note.readAsString()).trim();
        var recorded = true;
        if (culprit.isNotEmpty && culprit != OrtDevice.cpu.name) {
          strikes[culprit] = (strikes[culprit] ?? 0) + 1;
          _log.warning(
            'The app ended while using $culprit '
            '(strike ${strikes[culprit]} of $skipAt)',
          );
          recorded = await _writeStrikes(strikes);
        }
        // Kept until its strike is saved, so the next start counts it.
        if (recorded) await note.delete();
      }
    } on FileSystemException catch (e) {
      _log.warning('Could not read the device note', error: e);
    }
    final left = [
      for (final device in wanted)
        if (device == OrtDevice.cpu || (strikes[device.name] ?? 0) < skipAt)
          device,
    ];
    return left.isEmpty ? const [OrtDevice.cpu] : left;
  }

  /// A run returned on [device]: the app got past its open and first run,
  /// so a single strike against it is cleared. Only that device's: another
  /// device's strike stands until that device has run. A completed load is
  /// not enough, since a first run comes after it.
  Future<void> ranSafely(OrtDevice device) async {
    final strikes = await _readStrikes();
    final count = strikes[device.name];
    if (count == null || count >= skipAt) return;
    strikes.remove(device.name);
    await _writeStrikes(strikes);
  }

  /// Forgets [device]'s strikes: a new engine arrived for it.
  Future<void> forgive(OrtDevice device) async {
    final strikes = await _readStrikes();
    if (strikes.remove(device.name) != null) await _writeStrikes(strikes);
  }

  Future<Map<String, int>> _readStrikes() async {
    try {
      if (!await _strikesFile.exists()) return <String, int>{};
      return {
        for (final line in await _strikesFile.readAsLines())
          if (line.split(' ') case [
            final name,
            final count,
          ] when int.tryParse(count) != null)
            name: int.parse(count),
      };
    } on FileSystemException {
      return <String, int>{};
    }
  }

  /// Saves [strikes]; false when they could not be saved.
  Future<bool> _writeStrikes(Map<String, int> strikes) async {
    try {
      await _dir.create(recursive: true);
      if (strikes.isEmpty) {
        if (await _strikesFile.exists()) await _strikesFile.delete();
        return true;
      }
      await _strikesFile.writeAsString(
        [for (final e in strikes.entries) '${e.key} ${e.value}'].join('\n'),
        flush: true,
      );
      return true;
    } on FileSystemException catch (e) {
      _log.warning('Could not save the device strikes', error: e);
      return false;
    }
  }
}

/// The worker's side of [DeviceCrashGuard], in the worker isolate: the
/// device being opened or first run on, written before and removed after.
/// Synchronous, so the note is on disk before the native call that may end
/// the process.
class OpeningNote implements FirstRunWatcher {
  OpeningNote(this._path);

  final String _path;

  void opening(OrtDevice device) {
    try {
      final file = File(_path);
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(device.name, flush: true);
    } on FileSystemException {
      // The guard only ever removes devices; without a note it removes none.
    }
  }

  @override
  void starting(OrtDevice device) => opening(device);

  @override
  void finished() {
    try {
      final file = File(_path);
      if (file.existsSync()) file.deleteSync();
    } on FileSystemException {
      // A note left behind is one strike; it does no other harm.
    }
  }
}

/// [open], with every model open bracketed by [note].
ModelOpener noteOpens(ModelOpener open, OpeningNote note) => (path, device) {
  note.opening(device);
  try {
    return open(path, device);
  } finally {
    note.finished();
  }
};
