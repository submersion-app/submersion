import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:submersion_vision/onnx_runtime.dart';

import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/species_id/data/engines/onnx/onnx_worker_core.dart';

/// Keeps a device that ended the app from doing it again. Opening models on
/// a hardware engine or DirectML can end the process outright, with no error
/// to catch (findings, docs/design/findings/2026-11-20-windows-ml-unpackaged.md),
/// and identification may start by itself when the app opens, so one bad
/// driver could make the app close at every launch.
///
/// The worker notes each device just before it opens a model there and
/// removes the note once the open returns, worked or failed ([OpeningNote],
/// [noteOpens]); that covers a fallback opened after a run failed as well as
/// the first load. A note still there when the next worker starts means the
/// app ended mid-open: the device it names is skipped from then on (never the
/// processor). A newly fetched engine clears the skips. Every failure to read
/// or write here is ignored: the guard only ever removes devices, so losing
/// its notes costs at most one more try.
class DeviceCrashGuard {
  DeviceCrashGuard(this._dir);

  /// The guard's place on this PC: the system temporary folder, which
  /// survives a restart and is the system's to clear.
  factory DeviceCrashGuard.forThisDevice() => DeviceCrashGuard(
    Directory(p.join(Directory.systemTemp.path, 'submersion_species_id')),
  );

  final Directory _dir;
  final _log = LoggerService.forClass(DeviceCrashGuard);

  /// Where the worker notes the device it is opening ([OpeningNote]).
  String get openingNotePath => p.join(_dir.path, 'onnx_opening');

  File get _skipped => File(p.join(_dir.path, 'onnx_devices_skipped'));

  /// [wanted], without the devices the app ended on while opening models;
  /// never empty, since the processor is never skipped.
  Future<List<OrtDevice>> devicesFor(List<OrtDevice> wanted) async {
    final skipped = await _readSkipped();
    final note = File(openingNotePath);
    try {
      if (await note.exists()) {
        final culprit = (await note.readAsString()).trim();
        if (culprit.isNotEmpty &&
            culprit != OrtDevice.cpu.name &&
            skipped.add(culprit)) {
          _log.warning(
            'The app ended while opening models on $culprit; '
            'it is skipped from now on',
          );
          await _writeSkipped(skipped);
        }
        await note.delete();
      }
    } on FileSystemException catch (e) {
      _log.warning('Could not read the device note', error: e);
    }
    final left = [
      for (final device in wanted)
        if (!skipped.contains(device.name)) device,
    ];
    return left.isEmpty ? const [OrtDevice.cpu] : left;
  }

  /// Forgets the skipped devices: a new engine arrived.
  Future<void> reset() async {
    try {
      if (await _skipped.exists()) await _skipped.delete();
    } on FileSystemException catch (e) {
      _log.warning('Could not clear the skipped devices', error: e);
    }
  }

  Future<Set<String>> _readSkipped() async {
    try {
      if (!await _skipped.exists()) return <String>{};
      return {
        for (final line in await _skipped.readAsLines())
          if (line.trim().isNotEmpty) line.trim(),
      };
    } on FileSystemException {
      return <String>{};
    }
  }

  Future<void> _writeSkipped(Set<String> names) async {
    try {
      await _dir.create(recursive: true);
      await _skipped.writeAsString(names.join('\n'), flush: true);
    } on FileSystemException catch (e) {
      _log.warning('Could not note the skipped devices', error: e);
    }
  }
}

/// The worker's side of [DeviceCrashGuard], in the worker isolate: the
/// device being opened, written before the open and removed after it.
/// Synchronous, so the note is on disk before the native call that may end
/// the process.
class OpeningNote {
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

  void opened() {
    try {
      final file = File(_path);
      if (file.existsSync()) file.deleteSync();
    } on FileSystemException {
      // A note left behind skips that device once; it does no other harm.
    }
  }
}

/// [open], with every model open bracketed by [note].
ModelOpener noteOpens(ModelOpener open, OpeningNote note) => (path, device) {
  note.opening(device);
  try {
    return open(path, device);
  } finally {
    note.opened();
  }
};
