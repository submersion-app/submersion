import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/dive_field.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';
import 'package:submersion/features/dive_log/query/dive_column_filter_edits.dart';

ConditionNode c(String key, QueryOp op, QueryValue? v) =>
    ConditionNode(FieldPath([key]), op, v);

/// How the dive table's menus edit the active filter (#2984).
void main() {
  final site = c('site', QueryOp.eq, const RefValue('s1', 'Salt Pier'));
  final deep = c('depth', QueryOp.gte, const NumberValue(30, null));

  group('addDiveTableRule', () {
    test('an empty query becomes the rule', () {
      expect(addDiveTableRule(const DiveFilterState(), site).query, site);
    });

    test('a single node and the rule are ANDed', () {
      final f = const DiveFilterState().copyWith(query: deep);
      expect(addDiveTableRule(f, site).query, AndNode([deep, site]));
    });

    test('an OR query is kept whole and ANDed, never extended', () {
      final or = OrNode([deep, site]);
      final f = const DiveFilterState().copyWith(query: or);
      final rule = c('rating', QueryOp.gte, const NumberValue(4, null));
      expect(addDiveTableRule(f, rule).query, AndNode([or, rule]));
    });

    test('an equal top-level rule is not added twice', () {
      final f = addDiveTableRule(const DiveFilterState(), site);
      expect(addDiveTableRule(f, site), f);
    });

    test('axes stay as they are, suspended or not', () {
      final f = const DiveFilterState(
        siteId: 'x',
      ).copyWith(axesSuspended: true);
      final next = addDiveTableRule(f, deep);
      expect(next.siteId, 'x');
      expect(next.axesSuspended, isTrue);
    });
  });

  group('resetDiveColumnFilter and isDiveColumnFiltered', () {
    test('removes plain and negated top-level rules on the column only', () {
      final f = const DiveFilterState().copyWith(
        query: AndNode([
          site,
          NotNode(c('site', QueryOp.eq, const RefValue('s2', 'Reef'))),
          deep,
        ]),
      );
      expect(isDiveColumnFiltered(f, DiveField.siteName), isTrue);
      final next = resetDiveColumnFilter(f, DiveField.siteName);
      expect(next.query, deep);
      expect(isDiveColumnFiltered(next, DiveField.siteName), isFalse);
      expect(isDiveColumnFiltered(next, DiveField.maxDepth), isTrue);
    });

    test('the last rule going clears the query', () {
      final f = const DiveFilterState().copyWith(query: site);
      expect(resetDiveColumnFilter(f, DiveField.siteName).query, isNull);
    });

    test('leaves rules nested in groups alone', () {
      final f = const DiveFilterState().copyWith(query: OrNode([site, deep]));
      expect(isDiveColumnFiltered(f, DiveField.siteName), isFalse);
      expect(resetDiveColumnFilter(f, DiveField.siteName), f);
    });

    test('clears the column axis too', () {
      const f = DiveFilterState(siteId: 's1', minDepth: 10, maxDepth: 30);
      expect(isDiveColumnFiltered(f, DiveField.siteName), isTrue);
      expect(resetDiveColumnFilter(f, DiveField.siteName).siteId, isNull);
      final depth = resetDiveColumnFilter(f, DiveField.maxDepth);
      expect((depth.minDepth, depth.maxDepth), (null, null));
      expect(depth.siteId, 's1');
    });

    test(
      'a suspended axis does not mark the column, Reset still clears it',
      () {
        final f = const DiveFilterState(
          siteId: 's1',
        ).copyWith(axesSuspended: true);
        expect(isDiveColumnFiltered(f, DiveField.siteName), isFalse);
        expect(resetDiveColumnFilter(f, DiveField.siteName).siteId, isNull);
      },
    );

    test('an unfilterable column is never filtered', () {
      expect(
        isDiveColumnFiltered(const DiveFilterState(), DiveField.altitude),
        isFalse,
      );
    });
  });
}
