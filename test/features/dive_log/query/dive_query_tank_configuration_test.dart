import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/query/compiler/query_compiler.dart';
import 'package:submersion/core/query/compiler/query_validator.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/core/query/syntax/query_parser.dart';
import 'package:submersion/core/query/units/unit_prefs.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';
import 'package:submersion/features/dive_log/query/dive_filter_query.dart';
import 'package:submersion/features/insights/data/tank_configuration_sql.dart';
import 'package:submersion/features/query/app_query_registry.dart';
import 'package:submersion/features/query/presentation/app_query_labels.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../helpers/test_database.dart';

/// Issue #3804: typed search reads the classifier, so `tankConfig:sidemount`
/// finds what the card's Sidemount bar counts.
void main() {
  late AppDatabase db;
  const now = 1700000000000;

  final dives = appQueryRegistry.entityFor(QuerySubject.dives);
  final parser = QueryParser(
    appQueryRegistry,
    dives,
    ParseContext(
      prefs: kMetricPrefs,
      now: DateTime(2026, 10, 30),
      names: const MapNameResolver({}),
    ),
  );

  Future<void> insertDive(String id, {String mode = 'oc', String? siteId}) => db
      .into(db.dives)
      .insert(
        DivesCompanion(
          id: Value(id),
          diveMode: Value(mode),
          siteId: Value(siteId),
          diveDateTime: const Value(now),
          createdAt: const Value(now),
          updatedAt: const Value(now),
        ),
      );

  Future<void> insertTank(
    String diveId,
    int order,
    String role, {
    double o2 = 21,
  }) => db
      .into(db.diveTanks)
      .insert(
        DiveTanksCompanion(
          id: Value('$diveId-$order'),
          diveId: Value(diveId),
          tankRole: Value(role),
          o2Percent: Value(o2),
          volume: const Value(12),
          tankOrder: Value(order),
        ),
      );

  Future<Set<String>> ids(String text) async {
    final parsed = parser.parse(text);
    expect(parsed, isA<ParseOk>(), reason: '$parsed');
    final node = (parsed as ParseOk).node;
    expect(validateQuery(node, dives, appQueryRegistry), isEmpty);
    final q = compileQuery(node, dives, appQueryRegistry, rootAlias: 'd');
    final rows = await db
        .customSelect(
          'SELECT d.id FROM dives d WHERE ${q.where}',
          variables: [for (final p in q.params) Variable(p)],
        )
        .get();
    return {for (final r in rows) r.read<String>('id')};
  }

  setUp(() async {
    db = await setUpTestDatabase();
    await insertDive('single');
    await insertTank('single', 0, 'backGas');
    await insertDive('sidemount');
    await insertTank('sidemount', 0, 'sidemountLeft');
    await insertTank('sidemount', 1, 'stage');
    await insertDive('deco');
    await insertTank('deco', 0, 'backGas');
    await insertTank('deco', 1, 'deco', o2: 50);
    await insertDive('empty');
    await insertDive('loop', mode: 'ccr');
  });
  tearDown(tearDownTestDatabase);

  test('a configuration is found by name', () async {
    expect(await ids('tankConfig:sidemount'), {'sidemount'});
    expect(await ids('tankConfig:singleBackmount'), {'single', 'deco'});
    expect(await ids('tankConfig:rebreather'), {'loop'});
  });

  test('a list of configurations matches any of them', () async {
    final q = compileQuery(
      ConditionNode(
        FieldPath(const ['tankConfig']),
        QueryOp.inList,
        ListValue(const [EnumValue('sidemount'), EnumValue('rebreather')]),
      ),
      dives,
      appQueryRegistry,
      rootAlias: 'd',
    );
    final rows = await db
        .customSelect(
          'SELECT d.id FROM dives d WHERE ${q.where}',
          variables: [for (final p in q.params) Variable(p)],
        )
        .get();
    expect({for (final r in rows) r.read<String>('id')}, {'sidemount', 'loop'});
  });

  test(
    'none is the No tanks logged bar, which leaves rebreathers out',
    () async {
      expect(await ids('tankConfig:none'), {'empty'});
      expect(await ids('gasCount:none'), {'empty', 'loop'});
    },
  );

  test('any is the exact complement of none', () async {
    expect(await ids('tankConfig:any'), {
      'single',
      'sidemount',
      'deco',
      'loop',
    });
  });

  test('an extra is a yes or no field', () async {
    expect(await ids('stages:true'), {'sidemount'});
    expect(await ids('stages:false'), {'single', 'deco', 'empty', 'loop'});
    expect(await ids('decoGas:true'), {'deco'});
    expect(await ids('multiGas:true'), {'deco'});
  });

  test('decoGas is not the decompression field', () async {
    // No recorded deco signal on any dive, while one carried a deco gas.
    expect(await ids('deco:true'), isEmpty);
    expect(await ids('decoGas:true'), {'deco'});
  });

  test('a query reaching dives from a site compiles and matches', () async {
    await db
        .into(db.diveSites)
        .insert(
          const DiveSitesCompanion(
            id: Value('reef'),
            name: Value('Reef'),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
    await insertDive('there', siteId: 'reef');
    await insertTank('there', 0, 'sidemountLeft');

    final sites = appQueryRegistry.entityFor(QuerySubject.sites);
    final q = compileQuery(
      ScopedNode(
        FieldPath(const ['dives']),
        ConditionNode(
          FieldPath(const ['tankConfig']),
          QueryOp.eq,
          const EnumValue('sidemount'),
        ),
      ),
      sites,
      appQueryRegistry,
      rootAlias: 's0',
    );
    final rows = await db
        .customSelect(
          'SELECT s0.id FROM dive_sites s0 WHERE ${q.where}',
          variables: [for (final p in q.params) Variable(p)],
        )
        .get();
    expect(rows.map((r) => r.read<String>('id')), ['reef']);
  });

  test('every field re-ticks on the tables it reads', () {
    final touched = diveFilterTablesTouched(
      DiveFilterState(
        query: ConditionNode(
          FieldPath(const ['tankConfig']),
          QueryOp.eq,
          const EnumValue('sidemount'),
        ),
      ),
    );
    expect(touched, containsAll(kTankConfigurationTables));

    for (final key in ['stages', 'decoGas', 'multiGas']) {
      final touched = diveFilterTablesTouched(
        DiveFilterState(
          query: ConditionNode(
            FieldPath([key]),
            QueryOp.eq,
            const BoolValue(true),
          ),
        ),
      );
      expect(touched, containsAll(kTankConfigurationTables), reason: key);
    }
  });

  testWidgets('a value reads as the card labels it', (tester) async {
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (c) {
            context = c;
            return const SizedBox();
          },
        ),
      ),
    );
    final field = dives.fields.singleWhere((f) => f.key == 'tankConfig');
    expect(
      AppQueryLabels(context).enumValue(field, 'singleBackmount'),
      'Single backmount',
    );
  });
}
