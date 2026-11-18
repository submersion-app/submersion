import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show compute;

import 'package:submersion/features/species_id/data/pack/species_pack_store.dart';
import 'package:submersion/features/species_id/domain/entities/pack_candidate.dart';
import 'package:submersion/features/species_id/domain/entities/species_pack_manifest.dart';
import 'package:submersion/features/species_id/domain/services/region_grid.dart';
import 'package:submersion/features/species_id/domain/services/species_namer.dart';

typedef NamingCrops = List<({Float32List embedding, int shorterSide})>;

/// Names crops off the UI isolate: with thousands of candidates it is
/// millions of multiplications a crop.
Future<List<NamingResult>> nameCrops(
  LoadedPack pack,
  NamingCrops crops,
  int? cell,
) async {
  if (crops.isEmpty) return const [];
  return compute(_nameAll, _jobFor(pack, crops, cell));
}

/// Names a video scan's crops in a worker isolate that keeps the candidate
/// table (issue #4675). The table is tens of megabytes with thousands of
/// candidates: [nameCrops] copies it into a new isolate every call, this
/// copies it once for the whole scan.
class CropNamingWorker {
  CropNamingWorker._(this._isolate, this._requests, this._exit, this._exited) {
    _exited.then((_) {
      _stopped = true;
      for (final waiting in _waiting) {
        if (!waiting.isCompleted) {
          waiting.completeError(StateError('The naming worker stopped'));
        }
      }
    });
  }

  final Isolate _isolate;
  final SendPort _requests;

  /// Tells of the worker exiting or failing.
  final ReceivePort _exit;

  /// Completes when the worker has exited or failed.
  final Future<void> _exited;
  final _waiting = <Completer<List<NamingResult>>>{};
  var _stopped = false;

  /// Throws [StateError] when the worker stops before it is ready, rather
  /// than waiting for it forever.
  static Future<CropNamingWorker> start(LoadedPack pack, int? cell) async {
    final ready = ReceivePort();
    final exit = ReceivePort();
    final exited = Completer<void>();
    exit.listen((_) {
      if (!exited.isCompleted) exited.complete();
    });
    try {
      final isolate = await Isolate.spawn(
        _serve,
        (ready.sendPort, _jobFor(pack, const [], cell)),
        onExit: exit.sendPort,
        onError: exit.sendPort,
      );
      final requests = await Future.any<Object?>([
        ready.first,
        exited.future.then<Object?>(
          (_) => throw StateError('The naming worker stopped before ready'),
        ),
      ]);
      return CropNamingWorker._(
        isolate,
        requests! as SendPort,
        exit,
        exited.future,
      );
    } on Object {
      exit.close();
      rethrow;
    } finally {
      ready.close();
    }
  }

  /// Throws [StateError] once the worker has stopped, rather than waiting
  /// for an answer that will not come.
  Future<List<NamingResult>> name(NamingCrops crops) async {
    if (crops.isEmpty) return const [];
    if (_stopped) throw StateError('The naming worker stopped');
    final reply = ReceivePort();
    final answer = Completer<List<NamingResult>>();
    _waiting.add(answer);
    // The port closes unanswered only after [answer] has failed (the
    // worker stopped): that end of it reports nothing more.
    reply.first.then((message) {
      if (answer.isCompleted) return;
      if (message is List<NamingResult>) {
        answer.complete(message);
      } else {
        answer.completeError(StateError('Naming failed: $message'));
      }
    }).ignore();
    try {
      _requests.send((crops, reply.sendPort));
      return await answer.future;
    } finally {
      _waiting.remove(answer);
      reply.close();
    }
  }

  Future<void> close() async {
    if (!_stopped) _isolate.kill(priority: Isolate.immediate);
    await _exited;
    _exit.close();
  }
}

void _serve((SendPort, _NamingJob) start) {
  final (ready, job) = start;
  final namer = _namerFor(job);
  final requests = ReceivePort();
  ready.send(requests.sendPort);
  requests.listen((message) {
    final (crops, reply) = message as (NamingCrops, SendPort);
    try {
      reply.send([
        for (final crop in crops)
          namer.name(
            embedding: crop.embedding,
            boxShorterSide: crop.shorterSide,
            cell: job.cell,
          ),
      ]);
    } on Object catch (e) {
      reply.send('$e');
    }
  });
}

_NamingJob _jobFor(LoadedPack pack, NamingCrops crops, int? cell) {
  final manifest = pack.pack.manifest;
  return _NamingJob(
    candidates: pack.candidates,
    textEmbeddings: pack.textEmbeddings,
    embeddingSize: manifest.classifier.embeddingSize,
    logitScale: manifest.classifier.logitScale,
    naming: manifest.naming,
    regions: pack.regions,
    neighbourCells: manifest.region.neighbourCells,
    crops: crops,
    cell: cell,
  );
}

class _NamingJob {
  const _NamingJob({
    required this.candidates,
    required this.textEmbeddings,
    required this.embeddingSize,
    required this.logitScale,
    required this.naming,
    required this.regions,
    required this.neighbourCells,
    required this.crops,
    required this.cell,
  });

  final List<PackCandidate> candidates;
  final Float32List textEmbeddings;
  final int embeddingSize;
  final double logitScale;
  final NamingConfig naming;
  final RegionTable regions;
  final int neighbourCells;
  final NamingCrops crops;
  final int? cell;
}

List<NamingResult> _nameAll(_NamingJob job) {
  final namer = _namerFor(job);
  return [
    for (final crop in job.crops)
      namer.name(
        embedding: crop.embedding,
        boxShorterSide: crop.shorterSide,
        cell: job.cell,
      ),
  ];
}

SpeciesNamer _namerFor(_NamingJob job) => SpeciesNamer(
  candidates: job.candidates,
  textEmbeddings: job.textEmbeddings,
  embeddingSize: job.embeddingSize,
  logitScale: job.logitScale,
  config: job.naming,
  regions: job.regions,
  neighbourCells: job.neighbourCells,
);
