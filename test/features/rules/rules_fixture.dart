import 'package:drift/drift.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/query/domain/query_node.dart';

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
