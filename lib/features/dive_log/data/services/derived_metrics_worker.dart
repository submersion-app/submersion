import 'dart:typed_data';

import 'package:collection/collection.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_sample.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_series_codec.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_series_codec_exception.dart';
import 'package:submersion/features/dive_log/domain/codecs/tank_pressure_series_codec.dart';
import 'package:submersion/features/dive_log/domain/entities/derived_metrics.dart';
import 'package:submersion/features/dive_log/domain/services/derived_metrics_service.dart';

/// One tank's undecoded pressure series plus the volume the engine needs,
/// mirroring `TankSeriesBlob` in the sensor-summary worker.
class TankPressureBlob {
  final String tankId;
  final double? volumeLiters;
  final Uint8List samples;

  const TankPressureBlob({
    required this.tankId,
    this.volumeLiters,
    required this.samples,
  });
}

/// Everything the worker needs, read on the main isolate WITHOUT decoding
/// anything: blobs and scalars only, so nothing heavy crosses the boundary.
/// No DateTime crosses either; [computedAtMs] is an int.
class DerivedMetricsWorkInput {
  final String diveId;
  final List<Uint8List> primaryBlobs;
  final List<TankPressureBlob> tankBlobs;
  final DiveMode diveMode;
  final int sourceUpdatedAt;
  final int computedAtMs;

  const DerivedMetricsWorkInput({
    required this.diveId,
    required this.primaryBlobs,
    required this.tankBlobs,
    required this.diveMode,
    required this.sourceUpdatedAt,
    required this.computedAtMs,
  });
}

/// Top-level so `compute` can send it to a worker isolate.
DiveDerivedMetrics computeDerivedMetricsFromBlobs(
  DerivedMetricsWorkInput input,
) {
  const profileCodec = ProfileSeriesCodec();
  const tankCodec = TankPressureSeriesCodec();

  final samples = <ProfileSample>[];
  for (final blob in input.primaryBlobs) {
    final decoded = _decodeOrNull(() => profileCodec.decode(blob));
    if (decoded != null) samples.addAll(decoded);
  }
  if (input.primaryBlobs.isNotEmpty && samples.isEmpty) {
    // Blobs existed but none of them read. Record the reason so the sweep
    // does not revisit the dive on every pass.
    return DiveDerivedMetrics(
      diveId: input.diveId,
      engineVersion: DerivedMetricsService.version,
      sourceUpdatedAt: input.sourceUpdatedAt,
      computedAt: input.computedAtMs,
      unsupportedReason: UnsupportedReason.noProfile,
    );
  }
  if (input.primaryBlobs.length > 1) {
    mergeSort<ProfileSample>(
      samples,
      compare: (a, b) => a.timestamp.compareTo(b.timestamp),
    );
  }

  final tanks = <TankPressureSeries>[];
  for (final blob in input.tankBlobs) {
    final decoded = _decodeOrNull(() => tankCodec.decode(blob.samples));
    if (decoded == null) continue;
    tanks.add(
      TankPressureSeries(
        tankId: blob.tankId,
        volumeLiters: blob.volumeLiters,
        points: [
          for (final p in decoded) (timestamp: p.timestamp, bar: p.pressure),
        ],
      ),
    );
  }

  return DerivedMetricsService.compute(
    diveId: input.diveId,
    samples: samples,
    tanks: tanks,
    diveMode: input.diveMode,
    sourceUpdatedAt: input.sourceUpdatedAt,
    computedAtMs: input.computedAtMs,
  );
}

/// Swallows a corrupt blob so the sweep does not revisit the dive forever,
/// but rethrows a FORWARD version: a dive written by a newer build must stay
/// stale rather than cache an answer this build cannot produce correctly,
/// because upgrading back would never recompute it.
List<T>? _decodeOrNull<T>(List<T> Function() decode) {
  try {
    return decode();
  } on UnknownSeriesVersionException catch (e) {
    if (e.isForwardVersion) rethrow;
    return null;
  } on ProfileSeriesCodecException {
    return null;
  }
}
