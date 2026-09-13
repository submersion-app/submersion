import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/domain/entities/site_with_dive_count.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/site_types/domain/entities/site_type_entity.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';

/// Site type and tag filters (issue #1765).
void main() {
  final now = DateTime(2026);
  SiteTypeEntity type(String id) => SiteTypeEntity(
    id: id,
    name: id,
    isBuiltIn: true,
    createdAt: now,
    updatedAt: now,
  );
  Tag tag(String id) => Tag(
    id: id,
    name: id,
    createdAt: now,
    updatedAt: now,
    appliesToSites: true,
  );
  SiteWithDiveCount site(
    String id, {
    List<String> types = const [],
    List<String> tags = const [],
  }) => SiteWithDiveCount(
    site: DiveSite(id: id, name: id),
    diveCount: 0,
    siteTypes: [for (final t in types) type(t)],
    tags: [for (final t in tags) tag(t)],
  );

  final sites = [
    site('lakeWreck', types: ['lake', 'wreck'], tags: ['try']),
    site('reef', types: ['reef'], tags: ['avoid']),
    site('bare'),
  ];

  List<String> ids(SiteFilterState f) =>
      f.apply(sites).map((s) => s.site.id).toList();

  test('no type or tag filter keeps every site', () {
    expect(ids(const SiteFilterState()), ['lakeWreck', 'reef', 'bare']);
  });

  test('type filter matches any of the chosen types', () {
    expect(ids(const SiteFilterState(siteTypeIds: {'wreck', 'reef'})), [
      'lakeWreck',
      'reef',
    ]);
  });

  test('tag filter matches any of the chosen tags', () {
    expect(ids(const SiteFilterState(tagIds: {'try'})), ['lakeWreck']);
  });

  test('type and tag filters combine with AND', () {
    expect(
      ids(const SiteFilterState(siteTypeIds: {'reef'}, tagIds: {'try'})),
      isEmpty,
    );
    expect(ids(const SiteFilterState(siteTypeIds: {'lake'}, tagIds: {'try'})), [
      'lakeWreck',
    ]);
  });

  test('empty sets are inactive and copyWith can clear them', () {
    expect(const SiteFilterState().hasActiveFilters, isFalse);
    const f = SiteFilterState(siteTypeIds: {'lake'}, tagIds: {'try'});
    expect(f.hasActiveFilters, isTrue);
    final cleared = f.copyWith(siteTypeIds: const {}, tagIds: const {});
    expect(cleared.hasActiveFilters, isFalse);
    expect(f.copyWith(country: 'Mexico').siteTypeIds, {'lake'});
  });
}
