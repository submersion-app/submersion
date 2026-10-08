import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_import/data/services/fit/fit_raw_field_reader.dart';

/// One field of a hand-built FIT definition: its number, byte size, base type
/// byte and the raw bytes a data message carries for it.
typedef _Field = ({int id, int size, int baseType, List<int> bytes});

const int _sint32 = 0x85;
const int _uint8 = 0x02;

List<int> _sint32Bytes(int value, Endian endian) {
  final data = ByteData(4)..setInt32(0, value, endian);
  return data.buffer.asUint8List();
}

_Field _s32(int id, int value, [Endian endian = Endian.little]) =>
    (id: id, size: 4, baseType: _sint32, bytes: _sint32Bytes(value, endian));

_Field _u8(int id, int value) =>
    (id: id, size: 1, baseType: _uint8, bytes: [value]);

/// Builds FIT record bytes by hand, so the reader can be exercised against
/// layouts fit_tool's builder never emits (big-endian, developer fields,
/// compressed-timestamp headers, chained files).
class _FitBytes {
  final _records = BytesBuilder();

  void define(
    int localId,
    int globalId,
    List<_Field> fields, {
    Endian endian = Endian.little,
    List<int> developerFieldSizes = const [],
  }) {
    final hasDev = developerFieldSizes.isNotEmpty;
    _records.addByte(0x40 | (hasDev ? 0x20 : 0) | localId);
    _records.addByte(0); // reserved
    _records.addByte(endian == Endian.little ? 0 : 1);
    final global = ByteData(2)..setUint16(0, globalId, endian);
    _records.add(global.buffer.asUint8List());
    _records.addByte(fields.length);
    for (final f in fields) {
      _records.add([f.id, f.size, f.baseType]);
    }
    if (hasDev) {
      _records.addByte(developerFieldSizes.length);
      for (var i = 0; i < developerFieldSizes.length; i++) {
        _records.add([i, developerFieldSizes[i], 0]);
      }
    }
  }

  void data(
    int localId,
    List<_Field> fields, {
    List<int> developerBytes = const [],
    bool compressedTimestamp = false,
  }) {
    _records.addByte(
      compressedTimestamp ? 0x80 | ((localId & 0x03) << 5) : localId,
    );
    for (final f in fields) {
      _records.add(f.bytes);
    }
    _records.add(developerBytes);
  }

  /// A complete FIT file: 12-byte header, the records, a (dummy) CRC.
  Uint8List file() {
    final records = _records.toBytes();
    final header = ByteData(12)
      ..setUint8(0, 12)
      ..setUint8(1, 0x20)
      ..setUint16(2, 2132, Endian.little)
      ..setUint32(4, records.length, Endian.little);
    final headerBytes = header.buffer.asUint8List()
      ..setRange(8, 12, '.FIT'.codeUnits);
    return (BytesBuilder()
          ..add(headerBytes)
          ..add(records)
          ..add(const [0, 0]))
        .toBytes();
  }
}

void main() {
  const session = 18;

  group('FitRawFieldReader.firstSint32Fields', () {
    test('reads fields fit_tool has no profile entry for', () {
      final fields = [_u8(5, 53), _s32(38, 417566400), _s32(39, 214748364)];
      final fit = _FitBytes()
        ..define(0, session, fields)
        ..data(0, fields);

      final values = FitRawFieldReader.firstSint32Fields(
        fit.file(),
        globalId: session,
        fieldIds: const {38, 39},
      );

      expect(values, {38: 417566400, 39: 214748364});
    });

    test('honours a big-endian definition', () {
      final fields = [
        _s32(38, -123456789, Endian.big),
        _s32(39, 987654321, Endian.big),
      ];
      final fit = _FitBytes()
        ..define(0, session, fields, endian: Endian.big)
        ..data(0, fields);

      final values = FitRawFieldReader.firstSint32Fields(
        fit.file(),
        globalId: session,
        fieldIds: const {38, 39},
      );

      expect(values, {38: -123456789, 39: 987654321});
    });

    test('omits a field holding the sint32 invalid sentinel', () {
      final fields = [_s32(38, 0x7FFFFFFF), _s32(39, 1000)];
      final fit = _FitBytes()
        ..define(0, session, fields)
        ..data(0, fields);

      final values = FitRawFieldReader.firstSint32Fields(
        fit.file(),
        globalId: session,
        fieldIds: const {38, 39},
      );

      expect(values, {39: 1000});
    });

    test('skips other messages, developer fields and compressed headers', () {
      final record = [_s32(0, 1), _s32(1, 2)];
      final sessionFields = [_s32(38, 111), _s32(39, 222)];
      final fit = _FitBytes()
        ..define(1, 20, record, developerFieldSizes: const [3])
        ..data(1, record, developerBytes: const [9, 9, 9])
        ..data(1, record, developerBytes: const [9, 9, 9])
        ..define(2, session, sessionFields)
        ..data(2, sessionFields, compressedTimestamp: true);

      final values = FitRawFieldReader.firstSint32Fields(
        fit.file(),
        globalId: session,
        fieldIds: const {38, 39},
      );

      expect(values, {38: 111, 39: 222});
    });

    test('returns the first matching message only', () {
      final first = [_s32(38, 1), _s32(39, 2)];
      final second = [_s32(38, 3), _s32(39, 4)];
      final fit = _FitBytes()
        ..define(0, session, first)
        ..data(0, first)
        ..data(0, second);

      final values = FitRawFieldReader.firstSint32Fields(
        fit.file(),
        globalId: session,
        fieldIds: const {38, 39},
      );

      expect(values, {38: 1, 39: 2});
    });

    test('finds the message in a later file of a chained FIT file', () {
      final lap = [_s32(38, 5)];
      final sessionFields = [_s32(38, 111), _s32(39, 222)];
      final first =
          (_FitBytes()
                ..define(0, 19, lap)
                ..data(0, lap))
              .file();
      final second =
          (_FitBytes()
                ..define(0, session, sessionFields)
                ..data(0, sessionFields))
              .file();

      final values = FitRawFieldReader.firstSint32Fields(
        (BytesBuilder()
              ..add(first)
              ..add(second))
            .toBytes(),
        globalId: session,
        fieldIds: const {38, 39},
      );

      expect(values, {38: 111, 39: 222});
    });

    test('ignores a field whose declared size is not four bytes', () {
      final fields = [
        (id: 38, size: 1, baseType: _uint8, bytes: const [7]),
      ];
      final fit = _FitBytes()
        ..define(0, session, fields)
        ..data(0, fields);

      final values = FitRawFieldReader.firstSint32Fields(
        fit.file(),
        globalId: session,
        fieldIds: const {38},
      );

      expect(values, isEmpty);
    });

    test('returns null when no message has the global id', () {
      final fields = [_s32(38, 1)];
      final fit = _FitBytes()
        ..define(0, 19, fields)
        ..data(0, fields);

      final values = FitRawFieldReader.firstSint32Fields(
        fit.file(),
        globalId: session,
        fieldIds: const {38},
      );

      expect(values, isNull);
    });

    test('returns null instead of throwing on truncated or junk bytes', () {
      final fields = [_s32(38, 1), _s32(39, 2)];
      final full =
          (_FitBytes()
                ..define(0, session, fields)
                ..data(0, fields))
              .file();

      for (final bytes in [
        Uint8List(0),
        Uint8List.fromList([1, 2, 3]),
        Uint8List.sublistView(full, 0, full.length - 6),
      ]) {
        expect(
          FitRawFieldReader.firstSint32Fields(
            bytes,
            globalId: session,
            fieldIds: const {38, 39},
          ),
          isNull,
        );
      }
    });

    test('a data message for an undefined local id yields null', () {
      final fields = [_s32(38, 1)];
      final fit = _FitBytes()..data(3, fields);

      expect(
        FitRawFieldReader.firstSint32Fields(
          fit.file(),
          globalId: session,
          fieldIds: const {38},
        ),
        isNull,
      );
    });
  });
}
