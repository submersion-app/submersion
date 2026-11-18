import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/buddies/domain/constants/buddy_field.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/buddies/domain/entities/buddy_with_dive_count.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/shared/constants/entity_field.dart';

/// The buddy list's Country field (issue #4457).
void main() {
  const units = UnitFormatter(AppSettings());
  final adapter = BuddyFieldAdapter.instance;

  BuddyWithDiveCount entry({String? country}) => BuddyWithDiveCount(
    buddy: Buddy(
      id: 'b1',
      name: 'Marco',
      country: country,
      countryCode: country == 'Italy' ? 'IT' : null,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    ),
    diveCount: 0,
  );

  test('the field reads the buddy country', () {
    expect(
      adapter.extractValue(BuddyField.country, entry(country: 'Italy')),
      'Italy',
    );
    expect(adapter.formatValue(BuddyField.country, 'Italy', units), 'Italy');
  });

  test('a buddy without a country shows the placeholder', () {
    final value = adapter.extractValue(BuddyField.country, entry());
    expect(value, isNull);
    expect(
      adapter.formatValue(BuddyField.country, value, units),
      kFieldValuePlaceholder,
    );
  });

  test('the field is a sortable contact column', () {
    expect(BuddyField.country.sortable, isTrue);
    expect(BuddyField.country.categoryName, 'contact');
    expect(adapter.fieldsByCategory['contact'], contains(BuddyField.country));
  });

  test('the field has its English labels', () {
    expect(BuddyField.country.displayName, 'Country');
    expect(BuddyField.country.shortLabel, 'Country');
  });
}
