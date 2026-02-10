import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/services/format_detector.dart';

void main() {
  const detector = FormatDetector();

  group('Empty / invalid input', () {
    test('returns unknown for empty bytes', () {
      final result = detector.detect(Uint8List(0));
      expect(result.format, ImportFormat.unknown);
      expect(result.confidence, 0.0);
      expect(result.warnings, isNotEmpty);
    });
  });

  group('Binary detection - FIT files', () {
    test('detects valid FIT file header', () {
      // FIT header: byte[0] = header size (14), bytes[8..11] = ".FIT"
      final bytes = Uint8List(64);
      bytes[0] = 14; // header size
      bytes[8] = 0x2E; // .
      bytes[9] = 0x46; // F
      bytes[10] = 0x49; // I
      bytes[11] = 0x54; // T
      final result = detector.detect(bytes);
      expect(result.format, ImportFormat.fit);
      expect(result.sourceApp, SourceApp.garminConnect);
      expect(result.confidence, 1.0);
    });

    test('rejects too-short bytes for FIT', () {
      final bytes = Uint8List(8); // too short
      bytes[0] = 14;
      final result = detector.detect(bytes);
      expect(result.format, isNot(ImportFormat.fit));
    });

    test('rejects bytes with wrong FIT magic', () {
      final bytes = Uint8List(64);
      bytes[0] = 14;
      bytes[8] = 0x00; // not '.'
      final result = detector.detect(bytes);
      expect(result.format, isNot(ImportFormat.fit));
    });
  });

  group('Binary detection - SQLite files', () {
    test('detects SQLite file header', () {
      final magic = utf8.encode('SQLite format 3\x00');
      final bytes = Uint8List(64);
      bytes.setRange(0, magic.length, magic);
      final result = detector.detect(bytes);
      expect(result.format, ImportFormat.sqlite);
      expect(result.confidence, 0.5);
    });
  });

  group('XML detection', () {
    test('detects UDDF root element', () {
      const xml = '<?xml version="1.0"?><uddf version="3.2.0"></uddf>';
      final result = detector.detect(_toBytes(xml));
      expect(result.format, ImportFormat.uddf);
      expect(result.confidence, 0.95);
    });

    test('detects Submersion UDDF export', () {
      const xml =
          '<?xml version="1.0"?>'
          '<uddf version="3.2.0">'
          '<!-- Submersion export -->'
          '</uddf>';
      final result = detector.detect(_toBytes(xml));
      expect(result.format, ImportFormat.uddf);
      expect(result.sourceApp, SourceApp.submersion);
    });

    test('detects Subsurface XML', () {
      const xml =
          '<?xml version="1.0"?>'
          '<divelog program=\'subsurface\' version=\'5.0\'></divelog>';
      final result = detector.detect(_toBytes(xml));
      expect(result.format, ImportFormat.subsurfaceXml);
      expect(result.sourceApp, SourceApp.subsurface);
      expect(result.confidence, 0.98);
    });

    test('detects Diving Log XML', () {
      const xml = '<?xml version="1.0"?><DivingLog version="6.0"></DivingLog>';
      final result = detector.detect(_toBytes(xml));
      expect(result.format, ImportFormat.divingLogXml);
      expect(result.sourceApp, SourceApp.divingLog);
    });

    test('detects Suunto SML', () {
      const xml = '<?xml version="1.0"?><sml>...</sml>';
      final result = detector.detect(_toBytes(xml));
      expect(result.format, ImportFormat.suuntoSml);
      expect(result.sourceApp, SourceApp.suunto);
    });

    test('detects generic dive XML as UDDF fallback', () {
      const xml =
          '<?xml version="1.0"?>'
          '<data>'
          '<dive depth="25" duration="45" profile="true" waypoint="yes"/>'
          '</data>';
      final result = detector.detect(_toBytes(xml));
      expect(result.format, ImportFormat.uddf);
      expect(result.confidence, 0.5);
      expect(result.warnings, isNotEmpty);
    });

    test('does not detect non-dive XML as dive format', () {
      const xml =
          '<?xml version="1.0"?><catalog><book title="Flutter"/></catalog>';
      final result = detector.detect(_toBytes(xml));
      // Should fall through to CSV or unknown
      expect(result.format, isNot(ImportFormat.uddf));
    });
  });

  group('CSV detection', () {
    test('detects MacDive CSV by header signatures', () {
      const csv =
          'Dive No,Date,Time,Location,Max. Depth,Bottom Time,Dive Type\n'
          '1,2024-01-15,10:00,Blue Hole,25,45,Recreational\n';
      final result = detector.detect(_toBytes(csv));
      expect(result.format, ImportFormat.csv);
      expect(result.sourceApp, SourceApp.macdive);
      expect(result.confidence, greaterThan(0.6));
      expect(result.csvHeaders, isNotNull);
    });

    test('detects Subsurface CSV', () {
      // Subsurface scoring needs signatures: divesiteid, cylindertype,
      // diveguide, divemaster, sac -- need 4+ to score > 0.6
      const csv =
          'divesiteid,date,time,duration,maxdepth,avgdepth,cylindertype,divemaster,sac\n'
          '1,2024-01-15,10:00,0:45:00,25,18,AL80,John,15\n';
      final result = detector.detect(_toBytes(csv));
      expect(result.format, ImportFormat.csv);
      expect(result.sourceApp, SourceApp.subsurface);
    });

    test('detects Shearwater CSV by GF headers', () {
      const csv =
          'Dive Number,Date,Max Depth,Avg Depth,Duration,GF Low,GF High,ppO2\n'
          '1,2024-01-15,25,18,0:45:00,30,70,1.2\n';
      final result = detector.detect(_toBytes(csv));
      expect(result.format, ImportFormat.csv);
      expect(result.sourceApp, SourceApp.shearwater);
    });

    test('detects generic dive CSV', () {
      const csv =
          'date,depth,duration,location,temperature\n'
          '2024-01-15,25,45,Reef,28\n';
      final result = detector.detect(_toBytes(csv));
      expect(result.format, ImportFormat.csv);
      expect(result.sourceApp, SourceApp.generic);
    });

    test('detects Submersion CSV', () {
      const csv =
          'Dive Number,Date,Time,Site,Max Depth,Bottom Time,Water Temp,Start Pressure\n'
          '1,2024-01-15,10:00,Blue Hole,25,45,28,200\n';
      final result = detector.detect(_toBytes(csv));
      expect(result.format, ImportFormat.csv);
      expect(result.sourceApp, SourceApp.submersion);
    });

    test('returns headers in csvHeaders field', () {
      const csv =
          'Date,Depth,Duration\n'
          '2024-01-15,25,45\n';
      final result = detector.detect(_toBytes(csv));
      if (result.format == ImportFormat.csv) {
        expect(result.csvHeaders, ['Date', 'Depth', 'Duration']);
      }
    });

    test('does not detect non-dive CSV', () {
      const csv =
          'Name,Email,Phone\n'
          'Alice,alice@test.com,555-1234\n';
      final result = detector.detect(_toBytes(csv));
      // Not enough dive keywords
      expect(result.format, ImportFormat.unknown);
    });
  });

  group('Detection priority', () {
    test('FIT binary takes priority over text detection', () {
      // Build a FIT header followed by CSV-like text
      final fitHeader = Uint8List(14);
      fitHeader[0] = 14;
      fitHeader[8] = 0x2E;
      fitHeader[9] = 0x46;
      fitHeader[10] = 0x49;
      fitHeader[11] = 0x54;

      final csvText = utf8.encode('Date,Depth,Duration\n2024-01-15,25,45\n');
      final combined = Uint8List(fitHeader.length + csvText.length);
      combined.setAll(0, fitHeader);
      combined.setAll(fitHeader.length, csvText);

      final result = detector.detect(combined);
      expect(result.format, ImportFormat.fit);
    });
  });
}

Uint8List _toBytes(String text) => Uint8List.fromList(utf8.encode(text));
