import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:submersion/core/services/sync/conflict_reference.dart';
import 'package:submersion/core/services/sync/sync_service.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/settings/presentation/conflicts/conflict_comparison.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  late AppLocalizations l10n;
  String? savedLocale;
  const units = UnitFormatter(AppSettings());

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await initializeDateFormatting('en');
    savedLocale = Intl.defaultLocale;
    Intl.defaultLocale = 'en';
  });
  tearDownAll(() => Intl.defaultLocale = savedLocale);

  SyncConflict conflict(
    Map<String, dynamic> local,
    Map<String, dynamic> remote, {
    String entityType = 'dives',
    List<ConflictReference> localRefs = const [],
    List<ConflictReference> remoteRefs = const [],
  }) => SyncConflict(
    entityType: entityType,
    recordId: 'r1',
    localData: local,
    remoteData: remote,
    localModified: DateTime(2026),
    remoteModified: DateTime(2026),
    localReferences: localRefs,
    remoteReferences: remoteRefs,
  );

  ConflictComparison compare(SyncConflict c) =>
      buildConflictComparison(l10n: l10n, units: units, conflict: c);

  test('lists every differing field, no cap', () {
    final local = {for (var i = 0; i < 12; i++) 'field$i': i};
    final remote = {for (var i = 0; i < 12; i++) 'field$i': i + 100};
    final result = compare(conflict(local, remote));
    expect(result.state, ConflictComparisonState.differing);
    expect(result.differences, hasLength(12));
  });

  test('bookkeeping never counts as a difference', () {
    final result = compare(
      conflict(
        {'id': 'r1', 'name': 'A', 'hlc': '1:0:a', 'updatedAt': 1},
        {'id': 'r1', 'name': 'A', 'hlc': '2:0:b', 'updatedAt': 2},
      ),
    );
    expect(result.state, ConflictComparisonState.sameContent);
    expect(result.unchanged.map((f) => f.key), ['name']);
  });

  test('a key the remote omits is not a difference', () {
    final result = compare(
      conflict({'name': 'A', 'notes': 'kept locally'}, {'name': 'B'}),
    );
    expect(result.differences.map((d) => d.key), ['name']);
    expect(result.unchanged.map((f) => f.key), ['notes']);
  });

  test('an explicit null is a difference shown as Not set', () {
    final result = compare(conflict({'notes': 'x'}, {'notes': null}));
    expect(result.differences.single.remoteDisplay, 'Not set');
  });

  test('a key only the remote has is ignored', () {
    final result = compare(conflict({'name': 'A'}, {'name': 'A', 'future': 1}));
    expect(result.state, ConflictComparisonState.sameContent);
    expect(result.unchanged.map((f) => f.key), ['name']);
  });

  test('int and double of the same value are equal', () {
    final result = compare(conflict({'waterTemp': 26.0}, {'waterTemp': 26}));
    expect(result.state, ConflictComparisonState.sameContent);
  });

  test('a remote deletion shows the local values that would go', () {
    final result = compare(
      conflict(
        {'name': 'Blue Hole', 'maxDepth': 30.0},
        {'id': 'r1', '_deleted': true, 'deletedAt': 5},
      ),
    );
    expect(result.state, ConflictComparisonState.remoteDeleted);
    expect(result.differences, isEmpty);
    expect(result.survivingValues.map((f) => f.key), ['name', 'maxDepth']);
  });

  test('a local deletion shows the remote values', () {
    final result = compare(conflict({}, {'name': 'Blue Hole'}));
    expect(result.state, ConflictComparisonState.localDeleted);
    expect(result.survivingValues.single.display, 'Blue Hole');
  });

  test('preferred fields lead, the rest follow by label', () {
    final result = compare(
      conflict(
        {'zeta': 1, 'notes': 'a', 'alpha': 1, 'name': 'A'},
        {'zeta': 2, 'notes': 'b', 'alpha': 2, 'name': 'B'},
      ),
    );
    expect(result.differences.map((d) => d.key), [
      'name',
      'notes',
      'alpha',
      'zeta',
    ]);
  });

  test('an unchanged opaque payload reads Same, not Changed', () {
    final result = compare(
      conflict(
        {'name': 'A', 'computerTissueJson': '{"t":1}'},
        {'name': 'B', 'computerTissueJson': '{"t":1}'},
      ),
    );
    final tissue = result.unchanged.singleWhere(
      (f) => f.key == 'computerTissueJson',
    );
    expect(tissue.display, 'Same');
  });

  test("a deleted record's values leave out opaque payloads", () {
    final result = compare(
      conflict(
        {'name': 'Blue Hole', 'computerTissueJson': '{"t":1}'},
        {'id': 'r1', '_deleted': true},
      ),
    );
    expect(result.survivingValues.map((f) => f.key), ['name']);
  });

  test('a foreign key is compared by id and shown by name', () {
    const localSite = ConflictReference(
      field: 'siteId',
      targetType: 'diveSites',
      recordId: 's1',
      name: 'Blue Hole',
    );
    const remoteSite = ConflictReference(
      field: 'siteId',
      targetType: 'diveSites',
      recordId: 's2',
      name: 'Shark Point',
    );
    final result = compare(
      conflict(
        {'siteId': 's1'},
        {'siteId': 's2'},
        localRefs: [localSite],
        remoteRefs: [remoteSite],
      ),
    );
    final diff = result.differences.single;
    expect(diff.label, l10n.settings_conflict_ref_diveSite);
    expect(diff.localDisplay, 'Blue Hole');
    expect(diff.remoteDisplay, 'Shark Point');
  });

  test('a foreign key set on one side only reads Not set on the other', () {
    const site = ConflictReference(
      field: 'siteId',
      targetType: 'diveSites',
      recordId: 's1',
      name: 'Blue Hole',
    );
    final result = compare(
      conflict({'siteId': 's1'}, {'siteId': null}, localRefs: [site]),
    );
    expect(result.differences.single.remoteDisplay, 'Not set');
  });

  test('a missing referenced record says so', () {
    const gone = ConflictReference(
      field: 'tagId',
      targetType: 'tags',
      recordId: 't1',
      exists: false,
    );
    const other = ConflictReference(
      field: 'tagId',
      targetType: 'tags',
      recordId: 't2',
      name: 'Night dive',
    );
    final result = compare(
      conflict(
        {'tagId': 't1'},
        {'tagId': 't2'},
        entityType: 'diveTags',
        localRefs: [gone],
        remoteRefs: [other],
      ),
    );
    expect(
      result.differences.single.localDisplay,
      l10n.settings_conflict_ref_missing,
    );
  });

  group('quality findings', () {
    Map<String, dynamic> finding({
      String severity = 'warning',
      String category = 'profile',
      String params = '{"depth":42.0,"atSeconds":185}',
      bool withCategory = true,
    }) => {
      'id': 'qf-1',
      'detectorId': 'depth_spike',
      'detectorVersion': 1,
      if (withCategory) 'category': category,
      'severity': severity,
      'status': 'open',
      'params': params,
    };

    ConflictComparison compareFinding(
      Map<String, dynamic> local,
      Map<String, dynamic> remote,
    ) => compare(conflict(local, remote, entityType: 'qualityFindings'));

    test(
      'a readable finding leads with its sentence and hides raw columns',
      () {
        final result = compareFinding(finding(), finding(severity: 'critical'));
        final keys = [
          ...result.differences.map((d) => d.key),
          ...result.unchanged.map((f) => f.key),
        ];
        expect(result.unchanged.first.key, '_finding');
        expect(
          result.unchanged.first.label,
          l10n.settings_conflict_ref_finding,
        );
        expect(keys, isNot(contains('detectorId')));
        expect(keys, isNot(contains('params')));
        expect(result.differences.map((d) => d.key), ['severity']);
      },
    );

    test('differing sentences are a difference', () {
      final result = compareFinding(
        finding(),
        finding(params: '{"depth":50.0,"atSeconds":185}'),
      );
      expect(result.differences.first.key, '_finding');
      expect(
        result.differences.first.localDisplay,
        isNot(result.differences.first.remoteDisplay),
      );
    });

    for (final (name, local, remote) in [
      (
        'params that are not JSON',
        finding(params: 'not json at all'),
        finding(params: 'not json at all', severity: 'critical'),
      ),
      (
        'a category from a newer schema',
        finding(category: 'somethingNewer'),
        finding(category: 'somethingNewer', severity: 'critical'),
      ),
      (
        'a missing category',
        finding(withCategory: false),
        finding(withCategory: false, severity: 'critical'),
      ),
    ]) {
      test('falls back to raw columns for $name', () {
        final result = compareFinding(local, remote);
        final keys = [
          ...result.differences.map((d) => d.key),
          ...result.unchanged.map((f) => f.key),
        ];
        expect(keys, isNot(contains('_finding')));
        expect(keys, contains('detectorId'));
      });
    }
  });
}
