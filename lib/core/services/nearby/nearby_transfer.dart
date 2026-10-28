import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

/// How long a sender keeps a full copy, and a receiver keeps its partial
/// one, for a resume after a dropped link.
const nearbyResumeWindow = Duration(hours: 24);

/// One gzipped payload going out in numbered parts.
class NearbyOutgoing {
  const NearbyOutgoing({
    required this.id,
    required this.kind,
    required this.file,
    required this.byteLength,
  });

  final String id;

  /// `delta` (a JSON payload) or `full` (a streamed base).
  final String kind;
  final File file;
  final int byteLength;

  int partCount(int partSize) =>
      byteLength == 0 ? 0 : (byteLength + partSize - 1) ~/ partSize;

  Future<Uint8List> readPart(int index, int partSize) async {
    final raf = await file.open();
    try {
      final start = index * partSize;
      await raf.setPosition(start);
      final end = start + partSize > byteLength ? byteLength : start + partSize;
      return await raf.read(end - start);
    } finally {
      await raf.close();
    }
  }
}

/// Temp files for nearby transfers, one directory per device.
class NearbyTransferFiles {
  NearbyTransferFiles(this.dir, {required DateTime Function() now})
    : _now = now;

  final Directory dir;
  final DateTime Function() _now;

  /// Whether [value] (a transfer id or device id, both sent by the peer)
  /// is safe inside a file name: letters, digits, `-` and `_` only, so it
  /// can never name a path outside [dir].
  static bool isSafeName(String value) => _safeName.hasMatch(value);

  static final _safeName = RegExp(r'^[A-Za-z0-9_-]{1,64}$');

  File _file(String prefix, List<String> parts, String suffix) {
    for (final part in parts) {
      if (!isSafeName(part)) {
        throw ArgumentError.value(part, 'name', 'not a safe transfer name');
      }
    }
    return File(p.join(dir.path, '$prefix-${parts.join('-')}$suffix'));
  }

  File _sidecar(String peerId) => _file('nearby-out', [peerId], '.json');

  File incoming(String peerId, String id) =>
      _file('nearby-in', [peerId, id], '.gz');

  /// The full copy last offered to [peerId], when still inside the resume
  /// window and on disk.
  Future<NearbyOutgoing?> reusableFull(String peerId) async {
    final sidecar = _sidecar(peerId);
    if (!await sidecar.exists()) return null;
    try {
      final json = jsonDecode(await sidecar.readAsString()) as Map;
      final createdAt = DateTime.fromMillisecondsSinceEpoch(
        json['createdAt'] as int,
      );
      final file = File(json['path'] as String);
      if (_now().difference(createdAt) > nearbyResumeWindow ||
          !await file.exists()) {
        await discardOutgoing(peerId);
        return null;
      }
      return NearbyOutgoing(
        id: json['id'] as String,
        kind: 'full',
        file: file,
        byteLength: await file.length(),
      );
    } on Object {
      await discardOutgoing(peerId);
      return null;
    }
  }

  /// Gzips [jsonFile] into an outgoing full copy for [peerId], remembered
  /// for resumes, and deletes [jsonFile].
  Future<NearbyOutgoing> prepareFull(
    String peerId,
    String id,
    File jsonFile,
  ) async {
    await discardOutgoing(peerId);
    final out = _file('nearby-out', [peerId, id], '.gz');
    await jsonFile.openRead().transform(gzip.encoder).pipe(out.openWrite());
    await jsonFile.delete();
    await _sidecar(peerId).writeAsString(
      jsonEncode({
        'id': id,
        'path': out.path,
        'createdAt': _now().millisecondsSinceEpoch,
      }),
    );
    return NearbyOutgoing(
      id: id,
      kind: 'full',
      file: out,
      byteLength: await out.length(),
    );
  }

  Future<NearbyOutgoing> prepareDelta(
    String peerId,
    String id,
    String json,
  ) async {
    final out = _file('nearby-delta', [peerId, id], '.gz');
    await out.writeAsBytes(gzip.encode(utf8.encode(json)));
    return NearbyOutgoing(
      id: id,
      kind: 'delta',
      file: out,
      byteLength: await out.length(),
    );
  }

  /// Removes the remembered full copy for [peerId], if any.
  Future<void> discardOutgoing(String peerId) async {
    final sidecar = _sidecar(peerId);
    if (!await sidecar.exists()) return;
    try {
      final json = jsonDecode(await sidecar.readAsString()) as Map;
      final file = File(json['path'] as String);
      if (await file.exists()) await file.delete();
    } on Object {
      // A sidecar this code cannot read names nothing worth keeping.
    }
    await sidecar.delete();
  }

  /// Drops everything kept for [peerId] (an unpairing): the full copy
  /// offered to it, and every copy from it or to it still on disk.
  Future<void> discardPeer(String peerId) async {
    if (!isSafeName(peerId)) return;
    await discardOutgoing(peerId);
    await _deleteWhere(
      (name) => [
        'nearby-out-$peerId-',
        'nearby-in-$peerId-',
        'nearby-delta-$peerId-',
      ].any(name.startsWith),
    );
  }

  /// Drops [peerId]'s partial copies of any offer other than [keep]: a
  /// new offer replaces an old one for good.
  Future<void> discardOtherIncoming(String peerId, {required String keep}) =>
      _deleteWhere((name) {
        final prefix = 'nearby-in-$peerId-';
        return name.startsWith(prefix) && !name.startsWith('$prefix$keep.');
      });

  /// Drops every transfer file past the resume window, whoever it was for:
  /// copies for peers that never came back, and leftovers of a crash.
  Future<void> sweepStale() async {
    final cutoff = _now().subtract(nearbyResumeWindow);
    await _deleteWhere((name) => name.startsWith('nearby-'), olderThan: cutoff);
  }

  Future<void> _deleteWhere(
    bool Function(String name) matches, {
    DateTime? olderThan,
  }) async {
    if (!await dir.exists()) return;
    await for (final entity in dir.list()) {
      if (entity is! File || !matches(p.basename(entity.path))) continue;
      try {
        if (olderThan != null &&
            (await entity.lastModified()).isAfter(olderThan)) {
          continue;
        }
        await entity.delete();
      } on FileSystemException {
        // Gone already, or in use; the next sweep tries again.
      }
    }
  }

  /// Gunzips a received transfer to a JSON file beside it. A transfer that
  /// is not valid gzip throws and leaves no output behind.
  Future<File> gunzip(File gz) async {
    final out = File('${gz.path}.json');
    final sink = out.openWrite();
    try {
      await sink.addStream(gz.openRead().transform(gzip.decoder));
      await sink.close();
    } on Object {
      // Closed before the delete: Windows cannot remove an open file.
      await sink.close().catchError((Object _) {});
      if (await out.exists()) await out.delete();
      rethrow;
    }
    return out;
  }
}
