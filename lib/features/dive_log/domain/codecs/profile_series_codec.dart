import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:submersion/features/dive_log/domain/codecs/bounded_inflate.dart';
import 'package:submersion/features/dive_log/domain/codecs/byte_io.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_field_table.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_sample.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_series_codec_exception.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_series_summary.dart';

/// The bytes and scalars a `dive_profile_series` row stores.
class EncodedProfileSeries {
  const EncodedProfileSeries({
    required this.bytes,
    required this.codecVersion,
    required this.summary,
  });

  final Uint8List bytes;
  final int codecVersion;
  final ProfileSeriesSummary summary;
}

/// Packs a series of [ProfileSample]s into one zlib-compressed columnar blob
/// and back. Lossless.
///
/// Layout of the uncompressed body: a version byte, the sample count as a
/// varint, then one column block per entry of that version's field table in
/// table order. See `byte_io.dart` for the block format.
///
/// Versioning: a later codec appends fields under a new version byte. The
/// decoder selects the field table by the blob's version byte, so an older
/// blob decodes under a newer codec with its missing fields null. A version
/// this codec does not know is refused.
class ProfileSeriesCodec {
  const ProfileSeriesCodec({this.fieldTables = const {version: fieldTableV1}});

  /// The version new blobs are written with.
  static const int version = 1;

  /// Codec v1 field table. See [kProfileFieldTableV1].
  static const List<ProfileField> fieldTableV1 = kProfileFieldTableV1;

  /// Field table per version byte this codec can read.
  final Map<int, List<ProfileField>> fieldTables;

  static final ZLibCodec _zlib = ZLibCodec(level: 6);

  /// Encodes a non-empty, timestamp-ordered series.
  ///
  /// Throws [ArgumentError] on an empty list, on more than
  /// [kMaxSeriesSampleCount] samples, on decreasing timestamps, on an
  /// unregistered [version], or on a field table without `timestamp` and
  /// `depth`.
  ///
  /// Most of those are caller bugs, but not all: a deltaInt field whose
  /// difference from the previous sample leaves the zigzag varint range
  /// (`minVarInt` .. `maxVarInt`) also throws [ArgumentError], and that is
  /// data. A caller packing rows it did not produce, the part 2 migration
  /// among them, has to handle the throw per series rather than treat it as
  /// a bug that cannot happen.
  EncodedProfileSeries encode(
    List<ProfileSample> samples, {
    int version = ProfileSeriesCodec.version,
  }) {
    final table = fieldTables[version];
    if (table == null) {
      throw ArgumentError.value(version, 'version', 'no field table');
    }
    _validateTable(table);
    // Refuse to write what decode would refuse to read. Part 2 drops the
    // source rows once a series is packed, so a blob over the cap would be
    // unrecoverable while its summary scalars kept the dive looking whole.
    if (samples.length > kMaxSeriesSampleCount) {
      throw ArgumentError.value(
        samples.length,
        'samples',
        'more than the maximum $kMaxSeriesSampleCount samples',
      );
    }
    final summary = ProfileSeriesSummary.of(samples);
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
    for (final field in table) {
      final column = [
        for (final sample in samples) _fieldOf(sample, field.name),
      ];
      _writeColumn(writer, field.kind, column);
    }
    return EncodedProfileSeries(
      bytes: Uint8List.fromList(_zlib.encode(writer.takeBytes())),
      codecVersion: version,
      summary: summary,
    );
  }

  /// Decodes a blob written by [encode] under any registered version.
  ///
  /// Throws [ProfileSeriesCodecException] on anything malformed: not a zlib
  /// stream, a body or sample count over the codec limits, an unknown
  /// version, a truncated block, trailing bytes, or a sample without
  /// timestamp or depth.
  List<ProfileSample> decode(Uint8List bytes) {
    final body = inflateBounded(bytes);
    if (body.isEmpty) {
      throw const ProfileSeriesCodecException('empty body');
    }
    final reader = ByteReader(body);
    final blobVersion = reader.readByte();
    final table = fieldTables[blobVersion];
    if (table == null) {
      throw UnknownSeriesVersionException(
        blobVersion,
        fieldTables.keys.toSet(),
      );
    }
    _validateTable(table);
    final count = reader.readVarUint();
    if (count == 0) {
      throw const ProfileSeriesCodecException('empty series');
    }
    // The count sizes one list per field, so it needs a hard cap of its
    // own: the payload guard below bounds it only by the body, and a body
    // at the inflate cap admits a count near 67 million, which for 28
    // columns is about 15 GB of references before any value is read.
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
    final columns = <String, List<Object?>>{};
    for (final field in table) {
      columns[field.name] = _readColumn(reader, field.kind, count);
    }
    if (!reader.isAtEnd) {
      throw ProfileSeriesCodecException(
        '${reader.remaining} trailing byte(s) after the last block',
      );
    }
    return _samplesFrom(columns, count);
  }

  static void _validateTable(List<ProfileField> table) {
    final names = <String>{};
    for (final field in table) {
      if (!names.add(field.name)) {
        throw ArgumentError.value(
          table,
          'fieldTables',
          'duplicate field ${field.name}',
        );
      }
    }
    if (!names.contains('timestamp') || !names.contains('depth')) {
      throw ArgumentError.value(
        table,
        'fieldTables',
        'every field table must carry timestamp and depth',
      );
    }
    // A field's kind is frozen with its name: the column readers and
    // _samplesFrom both cast on it, and cast() is lazy, so a mismatch would
    // otherwise escape as a TypeError from inside a presence loop or from a
    // ProfileSample argument, far from the table that caused it.
    for (final field in table) {
      final frozen = _frozenKinds[field.name];
      if (frozen != null && frozen != field.kind) {
        throw ArgumentError.value(
          table,
          'fieldTables',
          '${field.name} is ${frozen.name} in v1, not ${field.kind.name}',
        );
      }
    }
  }

  static final Map<String, ProfileFieldKind> _frozenKinds = {
    for (final field in kProfileFieldTableV1) field.name: field.kind,
  };

  static Object? _fieldOf(ProfileSample s, String name) => switch (name) {
    'timestamp' => s.timestamp,
    'depth' => s.depth,
    'pressure' => s.pressure,
    'temperature' => s.temperature,
    'heart_rate' => s.heartRate,
    'ascent_rate' => s.ascentRate,
    'ceiling' => s.ceiling,
    'ndl' => s.ndl,
    'setpoint' => s.setpoint,
    'pp_o2' => s.ppO2,
    'o2_sensor1' => s.o2Sensor1,
    'o2_sensor2' => s.o2Sensor2,
    'o2_sensor3' => s.o2Sensor3,
    'o2_sensor4' => s.o2Sensor4,
    'o2_sensor5' => s.o2Sensor5,
    'o2_sensor6' => s.o2Sensor6,
    'cns' => s.cns,
    'tts' => s.tts,
    'rbt' => s.rbt,
    'deco_type' => s.decoType,
    'heart_rate_source' => s.heartRateSource,
    'heading' => s.heading,
    'o2_sensor_mv1' => s.o2SensorMv1,
    'o2_sensor_mv2' => s.o2SensorMv2,
    'o2_sensor_mv3' => s.o2SensorMv3,
    'o2_sensor_mv4' => s.o2SensorMv4,
    'o2_sensor_mv5' => s.o2SensorMv5,
    'o2_sensor_mv6' => s.o2SensorMv6,
    _ => throw ArgumentError.value(name, 'name', 'not a profile sample field'),
  };

  static void _writeColumn(
    ByteWriter writer,
    ProfileFieldKind kind,
    List<Object?> column,
  ) {
    switch (kind) {
      case ProfileFieldKind.deltaInt:
        var previous = 0;
        writer.writeColumn<int>(column.cast<int?>(), (value) {
          writer.writeVarInt(value - previous);
          previous = value;
        });
      case ProfileFieldKind.float64:
        writer.writeColumn<double>(column.cast<double?>(), writer.writeFloat64);
      case ProfileFieldKind.runLengthString:
        _writeStringColumn(writer, column.cast<String?>());
    }
  }

  static List<Object?> _readColumn(
    ByteReader reader,
    ProfileFieldKind kind,
    int count,
  ) {
    switch (kind) {
      case ProfileFieldKind.deltaInt:
        var previous = 0;
        return reader.readColumn<int>(count, () {
          previous += reader.readVarInt();
          return previous;
        });
      case ProfileFieldKind.float64:
        return reader.readColumn<double>(count, reader.readFloat64);
      case ProfileFieldKind.runLengthString:
        return _readStringColumn(reader, count);
    }
  }

  static void _writeStringColumn(ByteWriter writer, List<String?> values) {
    if (!writer.writePresence(values)) return;
    final runs = <(String, int)>[];
    for (final value in values) {
      if (value == null) continue;
      if (runs.isNotEmpty && runs.last.$1 == value) {
        runs[runs.length - 1] = (value, runs.last.$2 + 1);
      } else {
        runs.add((value, 1));
      }
    }
    writer.writeVarUint(runs.length);
    for (final (value, length) in runs) {
      final encoded = utf8.encode(value);
      writer
        ..writeVarUint(length)
        ..writeVarUint(encoded.length)
        ..writeBytes(encoded);
    }
  }

  static List<String?> _readStringColumn(ByteReader reader, int count) {
    final present = reader.readPresence(count);
    var presentCount = 0;
    for (final isPresent in present) {
      if (isPresent) presentCount++;
    }
    if (presentCount == 0) return List<String?>.filled(count, null);
    final runCount = reader.readVarUint();
    if (runCount > presentCount) {
      throw ProfileSeriesCodecException(
        '$runCount string runs for $presentCount present values',
      );
    }
    final values = <String>[];
    for (var run = 0; run < runCount; run++) {
      final length = reader.readVarUint();
      // The encoder never emits an empty run, and accepting one would make
      // the format non-canonical: padding runs would decode to the same
      // samples from different bytes, so any hash of the blob would
      // disagree with the decoder about identity.
      if (length == 0) {
        throw ProfileSeriesCodecException('string run $run is empty');
      }
      // Subtract rather than add: `values.length + length` overflows into a
      // negative for a length near 2^63, which one varint can declare, and
      // the append loop below would then run unbounded.
      if (length > presentCount - values.length) {
        throw ProfileSeriesCodecException(
          'string run $run of length $length overruns the $presentCount '
          'present values',
        );
      }
      final byteLength = reader.readVarUint();
      final String value;
      try {
        value = utf8.decode(reader.readBytes(byteLength));
      } on FormatException catch (e) {
        throw ProfileSeriesCodecException(
          'invalid UTF-8 in string run $run: ${e.message}',
        );
      }
      for (var i = 0; i < length; i++) {
        values.add(value);
      }
    }
    if (values.length != presentCount) {
      throw ProfileSeriesCodecException(
        'string runs cover ${values.length} of $presentCount present values',
      );
    }
    var next = 0;
    return [for (final isPresent in present) isPresent ? values[next++] : null];
  }

  static List<ProfileSample> _samplesFrom(
    Map<String, List<Object?>> columns,
    int count,
  ) {
    List<T?> column<T>(String name) {
      final values = columns[name];
      if (values == null) return List<T?>.filled(count, null);
      return values.cast<T?>();
    }

    final timestamps = column<int>('timestamp');
    // The invariant encode enforces, re-checked here. Every retired reader
    // got it from `ORDER BY timestamp`, and every consumer still assumes
    // it: the merge interleaves on it, the aggregates difference
    // consecutive samples, and the summary takes first and last rather than
    // min and max. A crafted or bit-rotted blob can carry a decreasing
    // delta, and the samples would then be silently out of order rather
    // than refused.
    for (var i = 1; i < timestamps.length; i++) {
      final previous = timestamps[i - 1];
      final current = timestamps[i];
      if (previous != null && current != null && current < previous) {
        throw ProfileSeriesCodecException(
          'sample $i decreases from $previous to $current',
        );
      }
    }
    final depths = column<double>('depth');
    final pressures = column<double>('pressure');
    final temperatures = column<double>('temperature');
    final heartRates = column<int>('heart_rate');
    final ascentRates = column<double>('ascent_rate');
    final ceilings = column<double>('ceiling');
    final ndls = column<int>('ndl');
    final setpoints = column<double>('setpoint');
    final ppO2s = column<double>('pp_o2');
    final o2Sensor1s = column<double>('o2_sensor1');
    final o2Sensor2s = column<double>('o2_sensor2');
    final o2Sensor3s = column<double>('o2_sensor3');
    final o2Sensor4s = column<double>('o2_sensor4');
    final o2Sensor5s = column<double>('o2_sensor5');
    final o2Sensor6s = column<double>('o2_sensor6');
    final cnss = column<double>('cns');
    final ttss = column<int>('tts');
    final rbts = column<int>('rbt');
    final decoTypes = column<int>('deco_type');
    final heartRateSources = column<String>('heart_rate_source');
    final headings = column<double>('heading');
    final mv1s = column<int>('o2_sensor_mv1');
    final mv2s = column<int>('o2_sensor_mv2');
    final mv3s = column<int>('o2_sensor_mv3');
    final mv4s = column<int>('o2_sensor_mv4');
    final mv5s = column<int>('o2_sensor_mv5');
    final mv6s = column<int>('o2_sensor_mv6');

    return [
      for (var i = 0; i < count; i++)
        ProfileSample(
          timestamp:
              timestamps[i] ??
              (throw ProfileSeriesCodecException('sample $i has no timestamp')),
          depth:
              depths[i] ??
              (throw ProfileSeriesCodecException('sample $i has no depth')),
          pressure: pressures[i],
          temperature: temperatures[i],
          heartRate: heartRates[i],
          ascentRate: ascentRates[i],
          ceiling: ceilings[i],
          ndl: ndls[i],
          setpoint: setpoints[i],
          ppO2: ppO2s[i],
          o2Sensor1: o2Sensor1s[i],
          o2Sensor2: o2Sensor2s[i],
          o2Sensor3: o2Sensor3s[i],
          o2Sensor4: o2Sensor4s[i],
          o2Sensor5: o2Sensor5s[i],
          o2Sensor6: o2Sensor6s[i],
          cns: cnss[i],
          tts: ttss[i],
          rbt: rbts[i],
          decoType: decoTypes[i],
          heartRateSource: heartRateSources[i],
          heading: headings[i],
          o2SensorMv1: mv1s[i],
          o2SensorMv2: mv2s[i],
          o2SensorMv3: mv3s[i],
          o2SensorMv4: mv4s[i],
          o2SensorMv5: mv5s[i],
          o2SensorMv6: mv6s[i],
        ),
    ];
  }
}
