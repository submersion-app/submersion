import 'dart:typed_data';

/// Reads field values straight off a FIT file's byte stream.
///
/// fit_tool decodes each message it knows through a fixed field list taken
/// from an old FIT SDK profile, and discards the bytes of any field that list
/// lacks. Some fields Garmin watches write were added to the profile later,
/// such as `session.end_position_lat/long` (fields 38/39), so fit_tool never
/// surfaces them. This walks the records itself, following each definition
/// message's layout, to recover those fields.
///
/// It does not validate the CRC; fit_tool has already accepted the file by the
/// time this runs, and a malformed stream yields null rather than an error.
class FitRawFieldReader {
  const FitRawFieldReader._(); // coverage:ignore-line

  /// FIT `sint32` invalid value: the field is present but holds no data.
  static const int _sint32Invalid = 0x7FFFFFFF;

  /// The `sint32` values of [fieldIds] on the first data message whose global
  /// message number is [globalId], keyed by field number.
  ///
  /// A field that message does not define, that is not four bytes wide, or
  /// that holds the invalid sentinel is left out of the map. Returns null when
  /// no such message exists or the bytes cannot be walked.
  static Map<int, int>? firstSint32Fields(
    Uint8List bytes, {
    required int globalId,
    required Set<int> fieldIds,
  }) {
    try {
      return _scan(ByteData.sublistView(bytes), globalId, fieldIds);
    } on RangeError {
      return null;
    } on FormatException {
      return null;
    }
  }

  static Map<int, int>? _scan(ByteData data, int globalId, Set<int> fieldIds) {
    var fileStart = 0;
    // A FIT file may be several FIT files chained end to end.
    while (fileStart + 12 <= data.lengthInBytes) {
      final headerSize = data.getUint8(fileStart);
      final dataSize = data.getUint32(fileStart + 4, Endian.little);
      if (headerSize < 12 || !_hasFitSignature(data, fileStart)) {
        throw const FormatException('Not a FIT header');
      }
      final recordsEnd = fileStart + headerSize + dataSize;
      if (recordsEnd > data.lengthInBytes) {
        throw const FormatException('Truncated FIT file');
      }

      final found = _scanRecords(
        data,
        fileStart + headerSize,
        recordsEnd,
        globalId,
        fieldIds,
      );
      if (found != null) return found;

      fileStart = recordsEnd + 2; // skip the file CRC
    }
    return null;
  }

  static bool _hasFitSignature(ByteData data, int fileStart) =>
      data.getUint8(fileStart + 8) == 0x2E && // .
      data.getUint8(fileStart + 9) == 0x46 && // F
      data.getUint8(fileStart + 10) == 0x49 && // I
      data.getUint8(fileStart + 11) == 0x54; // T

  static Map<int, int>? _scanRecords(
    ByteData data,
    int start,
    int end,
    int globalId,
    Set<int> fieldIds,
  ) {
    final definitions = <int, _Definition>{};
    var pos = start;

    while (pos < end) {
      final header = data.getUint8(pos++);
      final isCompressedTimestamp = (header & 0x80) != 0;
      final isDefinition = !isCompressedTimestamp && (header & 0x40) != 0;
      final localId = isCompressedTimestamp
          ? (header >> 5) & 0x03
          : header & 0x0F;

      if (isDefinition) {
        final hasDeveloperFields = (header & 0x20) != 0;
        final (definition, next) = _readDefinition(
          data,
          pos,
          hasDeveloperFields,
        );
        definitions[localId] = definition;
        pos = next;
        continue;
      }

      final definition = definitions[localId];
      if (definition == null) {
        throw const FormatException('Data message before its definition');
      }
      if (pos + definition.dataSize > end) {
        throw const FormatException('Data message overran the file');
      }
      if (definition.globalId == globalId) {
        return _readFields(data, pos, definition, fieldIds);
      }
      pos += definition.dataSize;
    }
    if (pos > end) throw const FormatException('Record overran the file');
    return null;
  }

  static (_Definition, int) _readDefinition(
    ByteData data,
    int pos,
    bool hasDeveloperFields,
  ) {
    // Byte 0 is reserved; byte 1 is the architecture (0 little, 1 big).
    final endian = data.getUint8(pos + 1) == 0 ? Endian.little : Endian.big;
    final globalId = data.getUint16(pos + 2, endian);
    final fieldCount = data.getUint8(pos + 4);
    pos += 5;

    final fields = <({int id, int size})>[];
    var dataSize = 0;
    for (var i = 0; i < fieldCount; i++) {
      final size = data.getUint8(pos + 1);
      fields.add((id: data.getUint8(pos), size: size));
      dataSize += size;
      pos += 3;
    }

    if (hasDeveloperFields) {
      final developerCount = data.getUint8(pos++);
      for (var i = 0; i < developerCount; i++) {
        dataSize += data.getUint8(pos + 1);
        pos += 3;
      }
    }

    return (
      _Definition(
        globalId: globalId,
        endian: endian,
        fields: fields,
        dataSize: dataSize,
      ),
      pos,
    );
  }

  static Map<int, int> _readFields(
    ByteData data,
    int pos,
    _Definition definition,
    Set<int> fieldIds,
  ) {
    final values = <int, int>{};
    for (final field in definition.fields) {
      if (field.size == 4 && fieldIds.contains(field.id)) {
        final value = data.getInt32(pos, definition.endian);
        if (value != _sint32Invalid) values[field.id] = value;
      }
      pos += field.size;
    }
    return values;
  }
}

class _Definition {
  const _Definition({
    required this.globalId,
    required this.endian,
    required this.fields,
    required this.dataSize,
  });

  final int globalId;
  final Endian endian;
  final List<({int id, int size})> fields;

  /// Bytes one data message for this definition occupies, developer fields
  /// included.
  final int dataSize;
}
