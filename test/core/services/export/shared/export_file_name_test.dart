import 'package:flutter_test/flutter_test.dart';
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

    test('is empty when nothing usable is left', () {
      expect(fileNameSegment(''), '');
      expect(fileNameSegment('!!! ?'), '');
    });
  });

  group('exportFileName', () {
    test('joins the parts with underscores and adds the extension', () {
      expect(
        exportFileName(['gas_record', 'Curaçao', '2026-03-15'], 'csv'),
        'gas_record_Curaçao_2026-03-15.csv',
      );
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
