import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/dive_log/domain/entities/dive_data_source.dart';
import 'package:submersion/features/dive_log/domain/services/source_name_resolver.dart';

DiveDataSource _source({
  String id = 'src-1',
  String? computerName,
  String? computerModel,
  String? computerSerial,
  String? computerId,
  String? sourceFormat,
  String? sourceFileName,
  bool isPrimary = true,
}) {
  return DiveDataSource(
    id: id,
    diveId: 'dive-1',
    computerId: computerId,
    isPrimary: isPrimary,
    computerName: computerName,
    computerModel: computerModel,
    computerSerial: computerSerial,
    sourceFormat: sourceFormat,
    sourceFileName: sourceFileName,
    importedAt: DateTime(2026, 1, 1),
    createdAt: DateTime(2026, 1, 1),
  );
}

const labels = SourceNameLabels(
  unknownComputer: 'Unknown Computer',
  manualEntry: 'Manual Entry',
  importedFile: 'Imported File',
  editedSuffix: ' (edited)',
);

void main() {
  test('prefers friendly name over model and serial', () {
    final source = _source(
      computerName: 'Kiyans Teric',
      computerModel: 'Teric',
      computerSerial: '1234',
      computerId: 'dc-1',
    );
    expect(resolveSourceName(source, labels), 'Kiyans Teric');
  });

  test('falls back name -> model -> serial', () {
    expect(
      resolveSourceName(
        _source(
          computerModel: 'Teric',
          computerSerial: '1234',
          computerId: 'dc-1',
        ),
        labels,
      ),
      'Teric',
    );
    expect(
      resolveSourceName(
        _source(computerSerial: '1234', computerId: 'dc-1'),
        labels,
      ),
      '1234',
    );
  });

  test('computer-less manual source resolves to Manual Entry', () {
    expect(
      resolveSourceName(_source(sourceFormat: 'manual'), labels),
      'Manual Entry',
    );
  });

  test('computer-less file import resolves to Imported File', () {
    expect(
      resolveSourceName(_source(sourceFileName: 'log.uddf'), labels),
      'Imported File',
    );
  });

  test('download with no identifying data resolves to Unknown Computer', () {
    expect(
      resolveSourceName(_source(computerId: 'dc-1'), labels),
      'Unknown Computer',
    );
  });

  test('edited variant appends suffix', () {
    final source = _source(computerName: 'Kiyans Teric', computerId: 'dc-1');
    expect(
      resolveSourceName(source, labels, edited: true),
      'Kiyans Teric (edited)',
    );
  });

  group('tankSourceName', () {
    final teric = _source(computerName: 'Teric', computerId: 'dc-1');
    final perdix = _source(
      computerName: 'Perdix',
      computerId: 'dc-2',
      isPrimary: false,
    );

    test('names the computer a tank was attributed to', () {
      expect(
        tankSourceName(
          sourceId: null,
          computerId: 'dc-2',
          sources: [teric, perdix],
          labels: labels,
        ),
        'Perdix',
      );
    });

    test('a tank with no computer belongs to the primary source', () {
      expect(
        tankSourceName(
          sourceId: null,
          computerId: null,
          sources: [perdix, teric],
          labels: labels,
        ),
        'Teric',
      );
    });

    test('a single-source dive has nothing to tell apart', () {
      expect(
        tankSourceName(
          sourceId: null,
          computerId: 'dc-1',
          sources: [teric],
          labels: labels,
        ),
        isNull,
      );
    });

    test('a computer none of the sources carries is not named', () {
      expect(
        tankSourceName(
          sourceId: null,
          computerId: 'dc-9',
          sources: [teric, perdix],
          labels: labels,
        ),
        isNull,
      );
    });
  });

  group('tankSourceName for sources that name no computer (#2716)', () {
    final fileA = _source(id: 'src-a', sourceFileName: 'a.csv');
    final fileB = _source(
      id: 'src-b',
      sourceFileName: 'b.csv',
      isPrimary: false,
    );

    test('names the tank\'s own source by its file', () {
      // Both would read "Imported File"; the file tells them apart.
      expect(
        tankSourceName(
          sourceId: 'src-b',
          computerId: null,
          sources: [fileA, fileB],
          labels: labels,
        ),
        'b.csv',
      );
    });

    test('a tank with no source is the primary source\'s', () {
      expect(
        tankSourceName(
          sourceId: null,
          computerId: null,
          sources: [fileA, fileB],
          labels: labels,
        ),
        'a.csv',
      );
    });

    test('a computer still wins over the source', () {
      final teric = _source(
        id: 'src-t',
        computerName: 'Teric',
        computerId: 'dc-1',
      );
      expect(
        tankSourceName(
          sourceId: 'src-b',
          computerId: 'dc-1',
          sources: [teric, fileB],
          labels: labels,
        ),
        'Teric',
      );
    });

    test('a source none of the sources is, is not named', () {
      expect(
        tankSourceName(
          sourceId: 'src-gone',
          computerId: null,
          sources: [fileA, fileB],
          labels: labels,
        ),
        isNull,
      );
    });
  });
}
