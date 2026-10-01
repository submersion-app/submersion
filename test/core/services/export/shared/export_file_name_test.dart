import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:submersion/core/services/export/shared/export_file_name.dart';

void main() {
  group('fileNameSegment', () {
    test('keeps letters of every script and their digits', () {
      expect(fileNameSegment('Curaçao'), 'Curaçao');
      expect(fileNameSegment('台湾 2026'), '台湾_2026');
      expect(fileNameSegment('אילת'), 'אילת');
      expect(fileNameSegment('Ţărmul Mării'), 'Ţărmul_Mării');
    });

    test('keeps combining marks, so a decomposed accent stays whole', () {
      // "e" followed by U+0301, the form macOS file names arrive in.
      expect(fileNameSegment('Café Reef'), 'Café_Reef');
      expect(fileNameSegment('हिन्दी'), 'हिन्दी');
    });

    test('collapses any run of other characters to one underscore', () {
      expect(fileNameSegment('Bonaire 2026!'), 'Bonaire_2026');
      expect(fileNameSegment('Red  Sea / Egypt'), 'Red_Sea_Egypt');
      expect(fileNameSegment('a__b'), 'a_b');
    });

    test('trims separators at either end', () {
      expect(fileNameSegment('  -Cozumel- '), 'Cozumel');
      expect(fileNameSegment('_x_'), 'x');
    });

    test('stays within the byte budget, so a long name still saves', () {
      // 3 bytes each in UTF-8: uncapped, 120 of them overrun the 255-byte
      // limit every file system puts on one name.
      final long = fileNameSegment('潜' * 120);
      expect(
        utf8.encode(long).length,
        lessThanOrEqualTo(fileNameSegmentMaxBytes),
      );
      expect(long, '潜' * (fileNameSegmentMaxBytes ~/ 3));
      // A cut never leaves a separator at the end.
      final words = fileNameSegment('${'a' * (fileNameSegmentMaxBytes - 1)} b');
      expect(words, 'a' * (fileNameSegmentMaxBytes - 1));
      // Nor half of a character outside the Basic Multilingual Plane.
      final astral = fileNameSegment(
        '${'a' * (fileNameSegmentMaxBytes - 2)}𝐀𝐀',
      );
      expect(astral, 'a' * (fileNameSegmentMaxBytes - 2));
      // Nor a letter without the accent that follows it: "e" fits, its
      // U+0301 does not, so the cut falls before the "e".
      final accent = fileNameSegment(
        '${'a' * (fileNameSegmentMaxBytes - 1)}e\u0301',
      );
      expect(accent, 'a' * (fileNameSegmentMaxBytes - 1));
      // Several marks on one letter go with it as a group: "e", U+0301 fit,
      // U+0323 does not, so all three are dropped.
      final stacked = fileNameSegment(
        '${'a' * (fileNameSegmentMaxBytes - 3)}e\u0301\u0323',
      );
      expect(stacked, 'a' * (fileNameSegmentMaxBytes - 3));
    });

    test('is empty when nothing usable is left', () {
      expect(fileNameSegment(''), '');
      expect(fileNameSegment('!!! ?'), '');
    });
  });

  test('fileNameDate is ISO, whatever the diver reads elsewhere', () {
    expect(fileNameDate(DateTime(2026, 3, 5, 23, 59)), '2026-03-05');
  });

  test('fileNameDate keeps ASCII digits under a native-digit locale', () async {
    await initializeDateFormatting('fa');
    final previousLocale = Intl.defaultLocale;
    addTearDown(() => Intl.defaultLocale = previousLocale);
    Intl.defaultLocale = 'fa';
    expect(fileNameDate(DateTime(2026, 3, 5)), '2026-03-05');
  });

  group('exportFileName', () {
    test('joins the parts with underscores and adds the extension', () {
      expect(
        exportFileName(['gas_record', 'Curaçao', '2026-03-15'], 'csv'),
        'gas_record_Curaçao_2026-03-15.csv',
      );
    });

    test('steers clear of the names Windows reserves for devices', () {
      expect(exportFileName(['AUX'], 'subplan'), 'AUX_.subplan');
      expect(exportFileName(['con'], 'subplan'), 'con_.subplan');
      expect(exportFileName(['Com1'], 'pdf'), 'Com1_.pdf');
      expect(exportFileName(['LPT¹'], 'pdf'), 'LPT¹_.pdf');
      // Only the whole name is reserved, not a name that contains one.
      expect(exportFileName(['Auxiliary'], 'pdf'), 'Auxiliary.pdf');
      expect(exportFileName(['trip', 'Con'], 'pdf'), 'trip_Con.pdf');
    });

    test('drops empty parts, so a missing name never leaves "__"', () {
      expect(
        exportFileName(['gas_record', '', '2026-03-15'], 'csv'),
        'gas_record_2026-03-15.csv',
      );
      expect(exportFileName(['trip', ''], 'pdf'), 'trip.pdf');
    });
  });
}
