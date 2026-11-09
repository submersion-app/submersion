import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';

/// A tag's scopes are a set drawn from the registry (issue #1942).
void main() {
  final now = DateTime(2026);

  Tag tag({Set<TagScope>? scopes}) => scopes == null
      ? Tag(id: 't', name: 'T', createdAt: now, updatedAt: now)
      : Tag(id: 't', name: 'T', createdAt: now, updatedAt: now, scopes: scopes);

  test('a tag is a dive tag unless told otherwise', () {
    expect(tag().scopes, {TagScope.dives});
    expect(tag().appliesTo(TagScope.dives), isTrue);
    expect(tag().appliesTo(TagScope.sites), isFalse);
  });

  test('create offers the tag in exactly its one scope', () {
    for (final scope in TagScope.values) {
      expect(Tag.create(id: 't', name: 'T', scope: scope).scopes, {scope});
    }
  });

  test('copyWith replaces the scopes, and keeps them when not given', () {
    final both = tag().copyWith(scopes: const {TagScope.dives, TagScope.sites});
    expect(both.appliesTo(TagScope.sites), isTrue);
    expect(both.copyWith(name: 'U').scopes, both.scopes);
  });

  group('color (issue #4384)', () {
    Tag coloured(String? hex) =>
        Tag(id: 't', name: 'T', colorHex: hex, createdAt: now, updatedAt: now);

    test('a tag with no usable colour draws as the palette Blue', () {
      for (final hex in [null, '', 'nothex']) {
        expect(coloured(hex).color, const Color(0xFF3B82F6), reason: '$hex');
      }
    });

    test('an imported code without a hash keeps drawing as itself', () {
      expect(coloured('FF0000').color, const Color(0xFFFF0000));
    });
  });

  test('equality ignores the order the scopes were added in', () {
    final a = tag(scopes: {TagScope.dives, TagScope.sites});
    final b = tag(scopes: {TagScope.sites, TagScope.dives});
    expect(a, b);
    expect(a.hashCode, b.hashCode);
  });
}
