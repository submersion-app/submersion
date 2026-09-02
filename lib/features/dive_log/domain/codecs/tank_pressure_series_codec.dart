import 'dart:io';
import 'dart:typed_data';

import 'package:equatable/equatable.dart';
import 'package:submersion/features/dive_log/domain/codecs/bounded_inflate.dart';
import 'package:submersion/features/dive_log/domain/codecs/byte_io.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_series_codec_exception.dart';

/// One tank pressure reading as the v181 `tank_pressure_profiles` table
/// stored it (the codec's column order), minus the identity columns (`id`,
/// `dive_id`, `tank_id`, `computer_id`) that live on the series row.
class TankPressureSample extends Equatable {
  const TankPressureSample({required this.timestamp, required this.pressure});

  /// Seconds from dive start.
  final int timestamp;

  /// Bar.
  final double pressure;

  /// The same reading [seconds] later (negative moves it earlier). Merge and
  /// consolidation re-base a segment's samples onto the combined timeline.
  TankPressureSample shiftedBy(int seconds) =>
      TankPressureSample(timestamp: timestamp + seconds, pressure: pressure);

  @override
  List<Object?> get props => [timestamp, pressure];
}

/// The scalars a `tank_pressure_series` row stores next to its blob.
class TankPressureSeriesSummary extends Equatable {
  const TankPressureSeriesSummary({
    required this.sampleCount,
    required this.startTimestamp,
    required this.endTimestamp,
  });

  /// Computes the summary of a non-empty, timestamp-ordered series.
  factory TankPressureSeriesSummary.of(List<TankPressureSample> samples) {
    if (samples.isEmpty) {
      throw ArgumentError.value(
        samples,
        'samples',
        'a series needs at least one sample',
      );
    }
    return TankPressureSeriesSummary(
      sampleCount: samples.length,
      startTimestamp: samples.first.timestamp,
      endTimestamp: samples.last.timestamp,
    );
  }

  final int sampleCount;
  final int startTimestamp;
  final int endTimestamp;

  @override
  List<Object?> get props => [sampleCount, startTimestamp, endTimestamp];
}

/// The bytes and scalars a `tank_pressure_series` row stores.
class EncodedTankPressureSeries {
  const EncodedTankPressureSeries({
    required this.bytes,
    required this.codecVersion,
    required this.summary,
  });

  final Uint8List bytes;
  final int codecVersion;
  final TankPressureSeriesSummary summary;
}

/// Packs a tank's pressure readings into one zlib-compressed columnar blob
/// and back. Lossless.
///
/// Body: version byte, sample count varint, a delta-zigzag-varint timestamp
/// column, a float64 pressure column. Both columns are always fully present
/// (the fields are non-nullable), so each costs one presence byte.
class TankPressureSeriesCodec {
  const TankPressureSeriesCodec();

  static const int version = 1;

  // ZLibCodec has no const constructor, so this is `final`, not `const`.
  static final ZLibCodec _zlib = ZLibCodec(level: 6);

  /// Encodes a non-empty, timestamp-ordered series. Throws [ArgumentError]
  /// on an empty list, on more than [kMaxSeriesSampleCount] samples, or on
  /// decreasing timestamps.
  EncodedTankPressureSeries encode(List<TankPressureSample> samples) {
    // Refuse to write what decode would refuse to read; see the profile
    // codec for why an unreadable blob is worse than a refused encode.
    if (samples.length > kMaxSeriesSampleCount) {
      throw ArgumentError.value(
        samples.length,
        'samples',
        'more than the maximum $kMaxSeriesSampleCount samples',
      );
    }
    final summary = TankPressureSeriesSummary.of(samples);
    for (var i = 1; i < samples.length; i++) {
      if (samples[i].timestamp < samples[i - 1].timestamp) {
        throw ArgumentError.value(
          samples,
          'samples',
          'timestamps must be non-decreasing (sample $i)',
        );
      }
    }
    final writer = ByteWriter()
      ..writeByte(version)
      ..writeVarUint(samples.length);
    var previous = 0;
    writer.writeColumn<int>([for (final s in samples) s.timestamp], (value) {
      writer.writeVarInt(value - previous);
      previous = value;
    });
    writer.writeColumn<double>([
      for (final s in samples) s.pressure,
    ], writer.writeFloat64);
    return EncodedTankPressureSeries(
      bytes: Uint8List.fromList(_zlib.encode(writer.takeBytes())),
      codecVersion: version,
      summary: summary,
    );
  }

  /// Decodes a blob written by [encode]. Throws
  /// [ProfileSeriesCodecException] on anything malformed.
  List<TankPressureSample> decode(Uint8List bytes) {
    final body = inflateBounded(bytes);
    if (body.isEmpty) {
      throw const ProfileSeriesCodecException('empty body');
    }
    final reader = ByteReader(body);
    final blobVersion = reader.readByte();
    if (blobVersion != version) {
      throw UnknownSeriesVersionException(blobVersion, const {version});
    }
    final count = reader.readVarUint();
    if (count == 0) {
      throw const ProfileSeriesCodecException('empty series');
    }
    // The count sizes both column lists, so cap it before the payload guard
    // below, which a body at the inflate cap would leave far too generous.
    if (count > kMaxSeriesSampleCount) {
      throw ProfileSeriesCodecException(
        'sample count $count exceeds the maximum $kMaxSeriesSampleCount',
      );
    }
    // Every sample carries at least a one-byte timestamp delta, so a count
    // the remaining payload cannot hold is corruption, not a large series.
    if (count > reader.remaining) {
      throw ProfileSeriesCodecException(
        'sample count $count exceeds the ${reader.remaining} remaining '
        'byte(s)',
      );
    }
    var previous = 0;
    final timestamps = reader.readColumn<int>(count, () {
      previous += reader.readVarInt();
      return previous;
    });
    final pressures = reader.readColumn<double>(count, reader.readFloat64);
    if (!reader.isAtEnd) {
      throw ProfileSeriesCodecException(
        '${reader.remaining} trailing byte(s) after the last block',
      );
    }
    // The invariant encode enforces; see the profile codec for why every
    // consumer still depends on it.
    for (var i = 1; i < timestamps.length; i++) {
      final previous = timestamps[i - 1];
      final current = timestamps[i];
      if (previous != null && current != null && current < previous) {
        throw ProfileSeriesCodecException(
          'sample $i decreases from $previous to $current',
        );
      }
    }
    return [
      for (var i = 0; i < count; i++)
        TankPressureSample(
          timestamp:
              timestamps[i] ??
              (throw ProfileSeriesCodecException('sample $i has no timestamp')),
          pressure:
              pressures[i] ??
              (throw ProfileSeriesCodecException('sample $i has no pressure')),
        ),
    ];
  }
}
