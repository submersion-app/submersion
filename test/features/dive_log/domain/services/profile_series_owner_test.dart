import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/dive_log/domain/entities/dive_data_source.dart';
import 'package:submersion/features/dive_log/domain/services/profile_series_owner.dart';

DiveDataSource _source(String id, String? computerId, {bool primary = false}) {
  return DiveDataSource(
    id: id,
    diveId: 'dive-1',
    computerId: computerId,
    isPrimary: primary,
    importedAt: DateTime(2026, 1, 1),
    createdAt: DateTime(2026, 1, 1),
  );
}

void main() {
  final sources = [
    _source('src-1', 'comp-1', primary: true),
    _source('src-2', 'comp-2'),
  ];

  test('a series with a source id belongs to that source', () {
    final owner = owningDataSource(
      sourceId: 'src-2',
      computerId: null,
      sources: sources,
    );
    expect(owner?.id, 'src-2');
  });

  test('a series naming a source the list lacks belongs to the source of '
      'its computer', () {
    // A carried row of a combined dive collapses into its strand's chip on
    // read, so the list can lack the exact row the series names.
    final owner = owningDataSource(
      sourceId: 'src-9',
      computerId: 'comp-2',
      sources: sources,
    );
    expect(owner?.id, 'src-2');
  });

  test('a series with no source belongs to the source of its computer', () {
    final owner = owningDataSource(
      sourceId: null,
      computerId: 'comp-2',
      sources: sources,
    );
    expect(owner?.id, 'src-2');
  });

  test('a series with neither source nor computer belongs to a source with '
      'no computer, the primary one first', () {
    final owner = owningDataSource(
      sourceId: null,
      computerId: null,
      sources: [
        _source('file-1', null),
        _source('file-2', null, primary: true),
      ],
    );
    expect(owner?.id, 'file-2');
  });

  test('a series with neither source nor computer has no owner when every '
      'source names a computer', () {
    final owner = owningDataSource(
      sourceId: null,
      computerId: null,
      sources: sources,
    );
    expect(owner, isNull);
  });
}
