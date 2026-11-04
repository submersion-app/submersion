import 'dart:convert';

import 'package:submersion/core/query/names/name_index.dart';
import 'package:submersion/features/agent_access/data/records/record_repositories.dart';
import 'package:submersion/features/agent_access/data/writes/writable_entity.dart';
import 'package:submersion/features/query/app_query_registry.dart';
import 'package:submersion/features/query/data/name_index_loader.dart';
import 'package:submersion/features/query/domain/entities/saved_query.dart';
import 'package:submersion/features/query/domain/saved_query_load.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The names [diverId]'s queries resolve their references by.
Future<NameIndex> queryNames(RecordRepositories r, String? diverId) =>
    NameIndexLoader(r.db).load(diverId: diverId, l10n: l10nForLocaleTag('en'));

/// [query], stored JSON for [subject], read as the app reads a saved query,
/// with why it cannot be used under [key], or null: a newer or unreadable
/// shape, an unknown subject, a field that does not validate, or a
/// reference to a record that is gone.
Future<({SavedQueryLoad load, PlanBlock? problem})> checkedQuery(
  RecordRepositories r, {
  required String key,
  required String subject,
  required Map<String, Object?> query,
  required String? diverId,
}) async {
  final now = DateTime.now();
  final load = loadSavedQuery(
    SavedQuery(
      id: '',
      diverId: diverId,
      subject: subject,
      name: '',
      queryJson: jsonEncode(query),
      createdAt: now,
      updatedAt: now,
    ),
    appQueryRegistry,
    await queryNames(r, diverId),
  );
  final problem = switch (load.problem) {
    null => null,
    SavedQueryProblem.unknownSubject => 'it names no subject this app has',
    SavedQueryProblem.unresolvedRef => 'it names a record that is gone',
    SavedQueryProblem.unreadable => 'it is not a query this app reads',
    SavedQueryProblem.invalid => 'it does not validate for $subject',
  };
  return (
    load: load,
    problem: problem == null
        ? null
        : PlanBlock(BlockReason.invalidValue, '$key: $problem.'),
  );
}
