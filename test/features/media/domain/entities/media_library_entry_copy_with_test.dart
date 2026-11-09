import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_library_filter.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';

final _item = MediaItem(
  id: 'm1',
  mediaType: MediaType.photo,
  sourceType: MediaSourceType.platformGallery,
  takenAt: DateTime(2026, 3, 12),
  createdAt: DateTime(2026, 3, 12),
  updatedAt: DateTime(2026, 3, 12),
);

void main() {
  final entry = MediaLibraryEntry(
    item: _item,
    diveNumber: 7,
    siteName: 'Reef',
    hasPeople: true,
  );

  test('copyWith with no arguments is equal', () {
    expect(entry.copyWith(), entry);
  });

  test('copyWith replaces only the fields it is given', () {
    final copy = entry.copyWith(hasSpecies: true, hasTimeInDive: true);
    expect(copy.hasPeople, isTrue);
    expect(copy.hasSpecies, isTrue);
    expect(copy.hasTimeInDive, isTrue);
    expect(copy.diveNumber, 7);
    expect(copy.siteName, 'Reef');
  });

  test('copyWith can clear a nullable field', () {
    final copy = entry.copyWith(diveNumber: null, siteName: null);
    expect(copy.diveNumber, isNull);
    expect(copy.siteName, isNull);
    expect(copy.hasPeople, isTrue);
  });
}
