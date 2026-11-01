import 'package:submersion/features/agent_access/data/query_roots.dart';
import 'package:submersion/features/agent_access/data/records/families/dive_records.dart';
import 'package:submersion/features/agent_access/data/records/record_entity.dart';
import 'package:submersion/features/agent_access/data/records/record_repositories.dart';
import 'package:submersion/features/agent_access/domain/agent_tool_error.dart';

/// Every entity an agent can read.
class RecordCatalog {
  RecordCatalog(RecordRepositories r)
    : all = List.unmodifiable([...diveEntries(r)]);

  final List<RecordEntry> all;

  /// The entities `query` does not root at, which `list_records` serves.
  List<RecordEntry> get nonRoots {
    final roots = {for (final r in kQueryRoots) r.name};
    return [
      for (final entry in all)
        if (!roots.contains(entry.name)) entry,
    ];
  }

  /// The entity named [name], refusing anything else with the valid names.
  RecordEntry named(Object? name) {
    for (final entry in all) {
      if (entry.name == name) return entry;
    }
    throw AgentToolException(
      AgentToolErrorCode.invalidArgument,
      'entity must be one of ${[for (final e in all) e.name]}.',
      details: {'entity': name},
    );
  }
}
