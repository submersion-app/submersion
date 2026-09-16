import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/site_types/domain/entities/site_type_entity.dart';

void main() {
  final created = DateTime(2026, 1, 1);
  final type = SiteTypeEntity(
    id: 'mine',
    diverId: 'diver-1',
    name: 'Mine',
    sortOrder: 100,
    createdAt: created,
    updatedAt: created,
  );

  test('create makes a custom type stamped now', () {
    final before = DateTime.now();
    final made = SiteTypeEntity.create(
      id: 'mine',
      name: 'Mine',
      diverId: 'diver-1',
      sortOrder: 7,
    );
    expect(made.isBuiltIn, isFalse);
    expect(made.diverId, 'diver-1');
    expect(made.sortOrder, 7);
    expect(made.createdAt.isBefore(before), isFalse);
    expect(made.updatedAt, made.createdAt);
  });

  test('generateSlug lowercases, drops punctuation, joins words', () {
    expect(SiteTypeEntity.generateSlug('  Old Mine Shaft! '), 'old_mine_shaft');
    expect(SiteTypeEntity.generateSlug('Ice-diving hole'), 'ice-diving_hole');
  });

  test('copyWith replaces only the fields given', () {
    final later = DateTime(2026, 2, 1);
    final copy = type.copyWith(name: 'Old mine', updatedAt: later);
    expect(copy.name, 'Old mine');
    expect(copy.updatedAt, later);
    expect(copy.id, type.id);
    expect(copy.diverId, type.diverId);
    expect(copy.isBuiltIn, type.isBuiltIn);
    expect(copy.sortOrder, type.sortOrder);
    expect(copy.createdAt, type.createdAt);
  });

  test('copyWith with no arguments is an equal value', () {
    expect(type.copyWith(), type);
    expect(
      type.copyWith(
        id: 'lake',
        diverId: 'diver-2',
        isBuiltIn: true,
        sortOrder: 1,
        createdAt: DateTime(2020),
      ),
      isNot(type),
    );
  });
}
