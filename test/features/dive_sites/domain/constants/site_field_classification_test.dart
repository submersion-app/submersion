import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_sites/domain/constants/site_field.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/domain/entities/site_with_dive_count.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/site_types/domain/entities/site_type_entity.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';
import 'package:submersion/shared/constants/entity_field.dart';

/// Site type and tag layout columns (issue #1765).
void main() {
  final adapter = SiteFieldAdapter.instance;
  const units = UnitFormatter(AppSettings());
  final now = DateTime(2026);

  test('the new fields are appended after every existing member', () {
    // Saved layouts store members by name, so these must come last.
    const values = SiteField.values;
    expect(values[values.length - 2], SiteField.siteTypes);
    expect(values.last, SiteField.tags);
    expect(SiteField.siteTypes.categoryName, 'details');
    expect(SiteField.tags.categoryName, 'details');
    expect(SiteField.siteTypes.sortable, isFalse);
    expect(SiteField.tags.sortable, isFalse);
  });

  test('cells render comma lists', () {
    final entry = SiteWithDiveCount(
      site: const DiveSite(id: 's', name: 's'),
      diveCount: 0,
      siteTypes: [
        SiteTypeEntity(
          id: 'lake',
          name: 'Lake',
          isBuiltIn: true,
          createdAt: now,
          updatedAt: now,
        ),
        SiteTypeEntity(
          id: 'wreck',
          name: 'Wreck',
          isBuiltIn: true,
          createdAt: now,
          updatedAt: now,
        ),
      ],
      tags: [Tag(id: 't', name: 'To try', createdAt: now, updatedAt: now)],
    );

    String cell(SiteField field) =>
        adapter.formatValue(field, adapter.extractValue(field, entry), units);

    expect(cell(SiteField.siteTypes), 'Lake, Wreck');
    expect(cell(SiteField.tags), 'To try');
  });

  test('an unclassified site renders the placeholder', () {
    const entry = SiteWithDiveCount(
      site: DiveSite(id: 's', name: 's'),
      diveCount: 0,
    );
    for (final field in [SiteField.siteTypes, SiteField.tags]) {
      expect(
        adapter.formatValue(field, adapter.extractValue(field, entry), units),
        kFieldValuePlaceholder,
      );
    }
  });

  test('fieldFromName round-trips the new names', () {
    expect(adapter.fieldFromName('siteTypes'), SiteField.siteTypes);
    expect(adapter.fieldFromName('tags'), SiteField.tags);
  });
}
