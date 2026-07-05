import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/dive_log/domain/entities/dive_data_source.dart';
import 'package:submersion/features/dive_log/domain/services/source_name_resolver.dart';

DiveDataSource _source({
  String? computerName,
  String? computerModel,
  String? computerSerial,
  String? computerId,
  String? sourceFormat,
  String? sourceFileName,
}) {
  return DiveDataSource(
    id: 'src-1',
    diveId: 'dive-1',
    computerId: computerId,
    isPrimary: true,
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
}
