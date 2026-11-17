import 'dart:math' as math;
import 'dart:typed_data';

import 'package:equatable/equatable.dart';

import 'package:submersion/features/species_id/domain/entities/pack_candidate.dart';
import 'package:submersion/features/species_id/domain/entities/species_pack_manifest.dart';
import 'package:submersion/features/species_id/domain/services/region_grid.dart';

/// What one crop was named as.
class NamingResult extends Equatable {
  const NamingResult({
    required this.openScore,
    required this.candidates,
    required this.locationLimited,
    required this.suggestable,
  });

  /// An embedding nothing can be read from: wrong length, zero, or not
  /// finite.
  static const unusable = NamingResult(
    openScore: 0,
    candidates: [],
    locationLimited: false,
    suggestable: false,
  );

  /// The top share over every candidate, before place is considered. It
  /// says whether the crop looks like anything in particular.
  final double openScore;

  /// The best candidates among those allowed, best first.
  final List<NamedCandidate> candidates;

  /// Whether candidates were limited to species recorded near the photo.
  final bool locationLimited;

  /// Whether the crop clears every bar and may be suggested.
  final bool suggestable;

  @override
  List<Object?> get props => [
    openScore,
    candidates,
    locationLimited,
    suggestable,
  ];
}

/// Names a crop from its embedding, against the model pack's candidates.
///
/// Pure arithmetic, so every engine shares it. Limiting the candidates to a
/// place raises every remaining score, so a crop must first look like
/// something specific against the whole list (the open score), and a place
/// with too few recorded species is treated as no place at all.
class SpeciesNamer {
  SpeciesNamer({
    required List<PackCandidate> candidates,
    required Float32List textEmbeddings,
    required int embeddingSize,
    required double logitScale,
    required NamingConfig config,
    required RegionTable regions,
    required int neighbourCells,
  }) : _candidates = candidates,
       _text = textEmbeddings,
       _size = embeddingSize,
       _scale = logitScale,
       _config = config,
       _regions = regions,
       _rings = neighbourCells {
    if (textEmbeddings.length != candidates.length * embeddingSize) {
      throw ArgumentError.value(
        textEmbeddings.length,
        'textEmbeddings',
        'expected ${candidates.length * embeddingSize} values',
      );
    }
    if (regions.candidateCount != candidates.length) {
      throw ArgumentError.value(
        regions.candidateCount,
        'regions',
        'expected ${candidates.length} candidates',
      );
    }
  }

  final List<PackCandidate> _candidates;
  final Float32List _text;
  final int _size;
  final double _scale;
  final NamingConfig _config;
  final RegionTable _regions;
  final int _rings;

  /// [cell] is the photo's grid cell, or null when it has no location.
  /// [boxShorterSide] is the detection's shorter side in the analysed
  /// image's pixels.
  NamingResult name({
    required Float32List embedding,
    required int boxShorterSide,
    int? cell,
  }) {
    final unit = _normalised(embedding);
    if (unit == null || _candidates.isEmpty) return NamingResult.unusable;

    final logits = Float64List(_candidates.length);
    var maxLogit = double.negativeInfinity;
    for (var i = 0; i < _candidates.length; i++) {
      final base = i * _size;
      var dot = 0.0;
      for (var j = 0; j < _size; j++) {
        dot += unit[j] * _text[base + j];
      }
      final logit = dot * _scale;
      logits[i] = logit;
      if (logit > maxLogit) maxLogit = logit;
    }
    if (!maxLogit.isFinite) return NamingResult.unusable;

    var openSum = 0.0;
    for (final logit in logits) {
      openSum += math.exp(logit - maxLogit);
    }
    final openScore = 1 / openSum;

    final allowed = _allowedFor(cell);
    final limited = allowed != null;

    var allowedMax = double.negativeInfinity;
    for (var i = 0; i < logits.length; i++) {
      if ((allowed == null || allowed[i]) && logits[i] > allowedMax) {
        allowedMax = logits[i];
      }
    }
    var sum = 0.0;
    for (var i = 0; i < logits.length; i++) {
      if (allowed == null || allowed[i]) {
        sum += math.exp(logits[i] - allowedMax);
      }
    }

    // The best few in one pass, best first: no need to sort them all.
    final best = <int>[];
    for (var i = 0; i < logits.length; i++) {
      if (allowed != null && !allowed[i]) continue;
      if (best.length == _config.topK && logits[i] <= logits[best.last]) {
        continue;
      }
      var at = best.length;
      while (at > 0 && logits[best[at - 1]] < logits[i]) {
        at--;
      }
      best.insert(at, i);
      if (best.length > _config.topK) best.removeLast();
    }
    final top = [
      for (final index in best)
        NamedCandidate(
          candidate: _candidates[index],
          score: math.exp(logits[index] - allowedMax) / sum,
        ),
    ];

    final bar = limited ? _config.suggestScore : _config.suggestScoreNoLocation;
    final suggestable =
        boxShorterSide >= _config.minCropSide &&
        openScore >= _config.minOpenScore &&
        top.isNotEmpty &&
        top.first.score >= bar;

    return NamingResult(
      openScore: openScore,
      candidates: top,
      locationLimited: limited,
      suggestable: suggestable,
    );
  }

  /// The candidates recorded near [cell], or null when there is no cell or
  /// too few species are recorded there to limit by.
  List<bool>? _allowedFor(int? cell) {
    if (cell == null || cell < 0 || cell >= _regions.grid.cellCount) {
      return null;
    }
    final mask = _regions.allowedMask(
      _regions.grid.neighbourhood(cell, rings: _rings),
    );
    final count = mask.where((allowed) => allowed).length;
    if (count == 0 || count < _config.minAllowedCandidates) return null;
    return mask;
  }

  Float64List? _normalised(Float32List embedding) {
    if (embedding.length != _size) return null;
    var squares = 0.0;
    for (final v in embedding) {
      if (!v.isFinite) return null;
      squares += v * v;
    }
    if (squares <= 0) return null;
    final norm = math.sqrt(squares);
    return Float64List.fromList([for (final v in embedding) v / norm]);
  }
}
