import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/features/rules/domain/entities/rule.dart';
import 'package:submersion/features/rules/domain/entities/rule_action.dart';
import 'package:submersion/features/rules/domain/rule_subject.dart';

/// Shared seeding for the logbook rules tests (#3513).
const kRuleTs = 1790000000000;

Future<void> seedRuleDivers(AppDatabase db, List<String> ids) async {
  for (final id in ids) {
    await db
        .into(db.divers)
        .insert(
          DiversCompanion.insert(
            id: id,
            name: id,
            createdAt: kRuleTs,
            updatedAt: kRuleTs,
          ),
        );
  }
}

Future<void> seedRuleDive(
  AppDatabase db,
  String id, {
  String diver = 'me',
  double? maxDepth,
  bool planned = false,
  String? entryMethod,
  String? waterType,
  String notes = '',
  String? siteId,
  int? number,
}) => db
    .into(db.dives)
    .insert(
      DivesCompanion.insert(
        id: id,
        diverId: Value(diver),
        diveNumber: Value(number),
        diveDateTime: kRuleTs,
        maxDepth: Value(maxDepth),
        isPlanned: Value(planned),
        entryMethod: Value(entryMethod),
        waterType: Value(waterType),
        notes: Value(notes),
        siteId: Value(siteId),
        createdAt: kRuleTs,
        updatedAt: kRuleTs,
      ),
    );

Future<void> seedRuleSite(
  AppDatabase db,
  String id, {
  String? owner = 'me',
  String? name,
  String? country,
  String description = '',
  bool shared = false,
  String? libraryId,
}) => db
    .into(db.diveSites)
    .insert(
      DiveSitesCompanion.insert(
        id: id,
        name: name ?? 'Site $id',
        diverId: Value(owner),
        country: Value(country),
        description: Value(description),
        isShared: Value(shared),
        sharedLibraryId: Value(libraryId),
        createdAt: kRuleTs,
        updatedAt: kRuleTs,
      ),
    );

ConditionNode depthOver(double metres) =>
    ConditionNode(FieldPath(['depth']), QueryOp.gt, NumberValue(metres, null));

/// The action most rules tests run: add the Deep dive type.
const kAddDeepType = DiveMembershipAction(
  DiveCollection.diveTypes,
  MembershipMode.add,
  ['deep'],
);

/// A [subject] rule holding just [action], for the appliers.
Rule ruleOf(
  RuleSubject subject,
  RuleAction action, {
  String name = 'Rule one',
}) => Rule(
  id: 'r1',
  diverId: 'me',
  subject: subject,
  name: name,
  enabled: true,
  triggers: const {RuleTrigger.afterImport},
  condition: null,
  conditionJson: '',
  actions: [action],
  actionsJson: '',
  sortOrder: 0,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

/// [diveId]'s dive types, sorted.
Future<List<String>> ruleDiveTypes(AppDatabase db, String diveId) async => [
  for (final r
      in await db
          .customSelect(
            'SELECT dive_type_id FROM dive_dive_types WHERE dive_id = ? '
            'ORDER BY dive_type_id',
            variables: [Variable.withString(diveId)],
          )
          .get())
    r.read<String>('dive_type_id'),
];

/// Lets the database's real I/O run between frames, [rounds] times, then
/// settles (unless [andSettle] is false: a page whose animations run on).
Future<void> settleRuleWork(
  WidgetTester tester, {
  int rounds = 6,
  Duration step = Duration.zero,
  bool andSettle = true,
}) async {
  for (var i = 0; i < rounds; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 60)),
    );
    await tester.pump(step);
  }
  if (andSettle) await tester.pumpAndSettle();
}
