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

  File _sidecar(String peerId) =>
      File(p.join(dir.path, 'nearby-out-$peerId.json'));

  File incoming(String peerId, String id) =>
      File(p.join(dir.path, 'nearby-in-$peerId-$id.gz'));

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
    final out = File(p.join(dir.path, 'nearby-out-$peerId-$id.gz'));
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
    final out = File(p.join(dir.path, 'nearby-delta-$peerId-$id.gz'));
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

  /// Gunzips a received transfer to a JSON file beside it.
  Future<File> gunzip(File gz) async {
    final out = File('${gz.path}.json');
    await gz.openRead().transform(gzip.decoder).pipe(out.openWrite());
    return out;
  }
}
