import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/features/query/app_query_registry.dart';
import 'package:submersion/features/query/presentation/app_query_labels.dart';
import 'package:submersion/features/query/presentation/query_label_lookup.dart';
import 'package:submersion/l10n/l10n_extension.dart';

import '../../../helpers/test_app.dart';

/// The registry names labels by ARB key; these pin that every key resolves
/// to a real string and that enum values show their localized names.
void main() {
  final en = l10nForLocaleTag('en');

  test('every plain query_ key in app_en.arb resolves through the lookup', () {
    final arb =
        jsonDecode(File('lib/l10n/arb/app_en.arb').readAsStringSync())
            as Map<String, dynamic>;
    // Keys with placeholders generate methods, not getters, and are not in
    // the lookup.
    final keys = arb.entries
        .where(
          (e) =>
              e.key.startsWith('query_') &&
              e.value is String &&
              !(e.value as String).contains('{'),
        )
        .map((e) => e.key);
    expect(keys, isNotEmpty);
    for (final key in keys) {
      expect(
        queryLabelForKey(en, key),
        isNot(key),
        reason:
            '$key is missing from query_label_lookup.dart; '
            'run python3 scripts/gen_query_label_lookup.py',
      );
    }
  });

  test('every registry label key resolves, an unknown key returns itself', () {
    for (final entity in appQueryRegistry.entities) {
      for (final f in entity.fields) {
        expect(queryLabelForKey(en, f.labelKey), isNot(f.labelKey));
      }
      for (final r in entity.relations) {
        expect(queryLabelForKey(en, r.labelKey), isNot(r.labelKey));
      }
      final entityKey = 'query_entity_${entity.subject.name}';
      expect(queryLabelForKey(en, entityKey), isNot(entityKey));
    }
    expect(queryLabelForKey(en, 'query_no_such_key'), 'query_no_such_key');
  });

  testWidgets('AppQueryLabels localises fields, entities, ops and enums', (
    tester,
  ) async {
    late AppQueryLabels labels;
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        child: Builder(
          builder: (context) {
            labels = AppQueryLabels(context);
            return const SizedBox();
          },
        ),
      ),
    );
    final dives = appQueryRegistry.entityFor(QuerySubject.dives);
    expect(labels.field(dives.field('depth')!), 'Max depth');
    expect(labels.relation(dives.relation('site')!), 'Site');
    expect(labels.entity(QuerySubject.sites), 'Dive sites');
    expect(labels.op(QueryOp.gte), 'at least');
    expect(labels.op(QueryOp.isEmpty), 'is not set');
    expect(labels.enumValue(dives.field('waterType')!, 'salt'), 'Salt Water');
    expect(labels.enumValue(dives.field('weekday')!, 'monday'), 'Mon');
    // An unknown enum value falls back to its stored name.
    expect(labels.enumValue(dives.field('waterType')!, 'brine'), 'brine');
  });
}
