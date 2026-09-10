import 'dart:typed_data';

import 'package:collection/collection.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_sample.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_series_codec.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_series_codec_exception.dart';
import 'package:submersion/features/dive_log/domain/codecs/tank_pressure_series_codec.dart';
import 'package:submersion/features/equipment/domain/entities/dive_sensor_summary.dart';
import 'package:submersion/features/equipment/domain/services/dive_sensor_summary_service.dart';

/// One tank's pressure series as it crosses the isolate boundary: identity
/// plus the undecoded blob, like `SeriesBlob` in the statistics aggregates.
class TankSeriesBlob {
  final String tankId;
  final String? transmitterSerial;
  final String? computerId;
  final Uint8List samples;

  const TankSeriesBlob({
    required this.tankId,
    this.transmitterSerial,
    this.computerId,
    required this.samples,
  });
}

/// Everything [computeSensorSummaryFromBlobs] needs, read on the main
/// isolate without decoding anything.
class SensorSummaryWorkInput {
  final String diveId;
  final List<Uint8List> primaryBlobs;
  final List<TankSeriesBlob> tankBlobs;
  final DiveMode diveMode;
  final int? runtimeSeconds;
  final int? scrubberDurationMinutes;
  final int? scrubberRemainingMinutes;
  final int sourceUpdatedAt;
  final int computedAtMs;

  const SensorSummaryWorkInput({
    required this.diveId,
    required this.primaryBlobs,
    required this.tankBlobs,
    required this.diveMode,
    required this.runtimeSeconds,
    required this.scrubberDurationMinutes,
    required this.scrubberRemainingMinutes,
    required this.sourceUpdatedAt,
    required this.computedAtMs,
  });
}

/// Top-level so `compute` can send it to a worker. Decodes every blob,
/// merges the primary segments by timestamp (stable, so two segments with
/// the same second keep their order), and runs the pure service.
///
/// A blob that fails to decode is skipped: one corrupt segment must not
/// leave the dive without a row, or the sweep would revisit it forever.
DiveSensorSummary computeSensorSummaryFromBlobs(SensorSummaryWorkInput input) {
  const profileCodec = ProfileSeriesCodec();
  const tankCodec = TankPressureSeriesCodec();

  final samples = <ProfileSample>[];
  for (final blob in input.primaryBlobs) {
    final decoded = _decodeOrNull(() => profileCodec.decode(blob));
    if (decoded != null) samples.addAll(decoded);
  }
  if (input.primaryBlobs.length > 1) {
    mergeSort<ProfileSample>(
      samples,
      compare: (a, b) => a.timestamp.compareTo(b.timestamp),
    );
  }

  final tanks = <TankSensorSeries>[];
  for (final blob in input.tankBlobs) {
    final decoded = _decodeOrNull(() => tankCodec.decode(blob.samples));
    if (decoded == null) continue;
    tanks.add(
      TankSensorSeries(
        tankId: blob.tankId,
        transmitterSerial: blob.transmitterSerial,
        computerId: blob.computerId,
        samples: decoded,
      ),
    );
  }

  return const DiveSensorSummaryService().summarize(
    diveId: input.diveId,
    samples: samples,
    tanks: tanks,
    diveMode: input.diveMode,
    runtimeSeconds: input.runtimeSeconds,
    scrubberDurationMinutes: input.scrubberDurationMinutes,
    scrubberRemainingMinutes: input.scrubberRemainingMinutes,
    sourceUpdatedAt: input.sourceUpdatedAt,
    computedAt: DateTime.fromMillisecondsSinceEpoch(
      input.computedAtMs,
      isUtc: true,
    ),
  );
}

/// Both codecs (and the bounded inflate under them) throw
/// [ProfileSeriesCodecException] on anything unreadable, which is the one
/// failure the worker tolerates: the blob is dropped and the rest of the
/// dive is still summarised.
List<T>? _decodeOrNull<T>(List<T> Function() decode) {
  try {
    return decode();
  } on UnknownSeriesVersionException catch (e) {
    // A version NEWER than anything this build knows is not corruption:
    // the samples are fine and a later build reads them. Swallowing it
    // would persist a summary with none of them as current for the dive's
    // updated_at, and upgrading back would never recompute it. Let it
    // escape so the dive stays stale until it can be read.
    if (e.isForwardVersion) rethrow;
    return null;
  } on ProfileSeriesCodecException {
    return null;
  }
}
