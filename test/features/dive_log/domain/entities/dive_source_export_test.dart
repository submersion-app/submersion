import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_source_export.dart';

/// A fully populated row, so every field participates in the comparisons.
DiveSourceExport build({
  String id = 'src-a',
  String diveId = 'dive-1',
  int ordinal = 0,
  bool isPrimary = true,
  Uint8List? rawData,
  String? computerModel = 'Perdix AI',
  int? descriptorModel = 5,
  double? maxDepth = 31.5,
  int? mergeSourceSlot = 0,
  DateTime? importedAt,
}) {
  return DiveSourceExport(
    id: id,
    diveId: diveId,
    ordinal: ordinal,
    isPrimary: isPrimary,
    importedAt: importedAt ?? DateTime(2019, 6, 2, 18, 41, 7),
    createdAt: DateTime(2019, 6, 2, 18, 41, 7),
    rawData: rawData ?? Uint8List.fromList([1, 2, 3]),
    rawFingerprint: Uint8List.fromList([0xA1, 0x7F]),
    computerId: 'computer-1',
    computerModel: computerModel,
    computerSerial: 'SN-A',
    sourceFormat: 'libdc',
    sourceFileName: 'backup.uddf',
    sourceFileFormat: 'uddf',
    sourceUuid: 'uuid-1',
    descriptorVendor: 'Shearwater',
    descriptorProduct: 'Perdix',
    descriptorModel: descriptorModel,
    libdivecomputerVersion: '0.9.0',
    mergeSourceSlot: mergeSourceSlot,
    timeOffsetSeconds: 0,
    maxDepth: maxDepth,
    avgDepth: 18.0,
    duration: 2400,
    waterTemp: 22.0,
    entryLatitude: 1.0,
    entryLongitude: 2.0,
    exitLatitude: 3.0,
    exitLongitude: 4.0,
    entryTime: DateTime(2019, 6, 2, 10),
    exitTime: DateTime(2019, 6, 2, 10, 40),
    maxAscentRate: 9.0,
    maxDescentRate: 18.0,
    surfaceInterval: 3600,
    cns: 12.5,
    otu: 30.0,
    decoAlgorithm: 'ZHL16C',
    gradientFactorLow: 30,
    gradientFactorHigh: 85,
    lastParsedAt: DateTime(2026, 3, 11),
  );
}

void main() {
  group('DiveSourceExport', () {
    test('two rows with the same values are equal', () {
      expect(build(), equals(build()));
      expect(build().hashCode, equals(build().hashCode));
    });

    test('rows differing in any exported field are not equal', () {
      // A field missing from props would make one of these compare equal,
      // which is how a column silently stops round-tripping.
      final reference = build();

      expect(build(id: 'src-b'), isNot(equals(reference)));
      expect(build(diveId: 'dive-2'), isNot(equals(reference)));
      expect(build(ordinal: 1), isNot(equals(reference)));
      expect(build(isPrimary: false), isNot(equals(reference)));
      expect(build(computerModel: 'Teric'), isNot(equals(reference)));
      expect(build(descriptorModel: 9), isNot(equals(reference)));
      expect(build(maxDepth: 30.9), isNot(equals(reference)));
      expect(build(mergeSourceSlot: 1), isNot(equals(reference)));
      expect(build(importedAt: DateTime(2020)), isNot(equals(reference)));
      expect(
        build(rawData: Uint8List.fromList([9, 9, 9])),
        isNot(equals(reference)),
        reason: 'raw bytes are compared by content, not identity',
      );
    });

    test('hasDump follows the bytes, treating empty as absent', () {
      expect(build().hasDump, isTrue);
      expect(build(rawData: Uint8List(0)).hasDump, isFalse);

      final noBytes = DiveSourceExport(
        id: 'src-a',
        diveId: 'dive-1',
        ordinal: 0,
        isPrimary: true,
        importedAt: DateTime(2019),
        createdAt: DateTime(2019),
      );
      expect(noBytes.hasDump, isFalse);
    });
  });
}
