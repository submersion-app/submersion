import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_data_source.dart';
import 'package:submersion/features/dive_log/domain/services/field_attribution_service.dart';

DiveDataSource _src(String id, {required bool primary, double? lat}) =>
    DiveDataSource(
      id: id,
      diveId: 'd1',
      isPrimary: primary,
      computerModel: 'Perdix $id',
      entryLatitude: lat,
      entryLongitude: lat,
      importedAt: DateTime(2026),
      createdAt: DateTime(2026),
    );

/// Legacy-name adapter: preserves the pre-nameOf displayName semantics the
/// expectations in this file were written against.
Map<String, String> _compute(
  List<DiveDataSource> sources, {
  String? viewedSourceId,
}) {
  return FieldAttributionService.computeAttribution(
    sources,
    viewedSourceId: viewedSourceId,
    nameOf: (s) => s.computerName ?? s.computerModel ?? 'Unknown Source',
  );
}

void main() {
  test('gps attributed to active source only when it has coordinates', () {
    final withGps = _compute([
      _src('A', primary: true, lat: 12.3),
      _src('B', primary: false),
    ]);
    expect(withGps['gps'], 'Perdix A');

    final noGps = _compute([
      _src('A', primary: true),
      _src('B', primary: false),
    ]);
    expect(noGps.containsKey('gps'), false);
  });
}
