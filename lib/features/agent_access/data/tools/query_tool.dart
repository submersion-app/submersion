import 'package:submersion/core/query/compiler/query_compiler.dart';
import 'package:submersion/core/query/compiler/query_validator.dart';
import 'package:submersion/core/query/domain/query_errors.dart';
import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/core/query/registry/query_entity.dart';
import 'package:submersion/core/query/syntax/query_parser.dart';
import 'package:submersion/features/agent_access/data/diver_context.dart';
import 'package:submersion/features/agent_access/data/documents/dive_summary_document.dart';
import 'package:submersion/features/agent_access/data/root_scope.dart';
import 'package:submersion/features/agent_access/domain/agent_tool.dart';
import 'package:submersion/features/agent_access/domain/agent_tool_error.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/repositories/series_id_chunks.dart';
import 'package:submersion/features/equipment/query/equipment_query_entity.dart'
    show serviceStatusTable;
import 'package:submersion/features/query/app_query_registry.dart';
import 'package:submersion/features/query/data/query_id_set_runner.dart';

/// The nine subjects a query may root at, in the registry's order.
final List<QuerySubject> kQueryRoots = QuerySubject.values.take(9).toList();

const kQueryDefaultLimit = 500;
const kQueryMaxLimit = 5000;

/// Finds records with the entity query language, scoped to one diver.
class QueryTool implements AgentTool {
  QueryTool({required DiverContextLoader loader, required DiveRepository dives})
    : _loader = loader,
      _dives = dives;

  final DiverContextLoader _loader;
  final DiveRepository _dives;

  @override
  String get name => 'query';

  @override
  String get description =>
      'Find records with the Submersion query language (read the '
      'submersion://query-language resource for the grammar and fields). '
      'Returns matching ids sorted ascending, paged by limit and offset. Bare '
      'numbers take the named (or active) diver\'s display units, so "depth > '
      '100" means feet for a diver who logs in feet; add a unit suffix (m, ft, '
      'c, f, bar, psi, kg, lb, min) to be explicit. An empty query matches '
      'everything. include_summaries adds a compact row per dive (dives root '
      'only in this version).';

  @override
  Map<String, Object?> get inputSchema => {
    'type': 'object',
    'properties': {
      'root': {
        'type': 'string',
        'enum': [for (final r in kQueryRoots) r.name],
        'description': 'Which records to search.',
      },
      'query': {
        'type': 'string',
        'description': 'Query language text. Empty matches every record.',
        'default': '',
      },
      'diver_id': {
        'type': 'string',
        'description':
            'Profile to search as (from list_divers). Omitted means the '
            'active profile.',
      },
      'include_summaries': {
        'type': 'boolean',
        'default': false,
        'description': 'Return a compact summary per matching dive.',
      },
      'limit': {
        'type': 'integer',
        'minimum': 1,
        'maximum': kQueryMaxLimit,
        'default': kQueryDefaultLimit,
      },
      'offset': {'type': 'integer', 'minimum': 0, 'default': 0},
    },
    'required': ['root'],
    'additionalProperties': false,
  };

  @override
  Future<Map<String, Object?>> call(
    Map<String, Object?> args,
    AgentToolContext context,
  ) async {
    final root = _rootFor(args['root']);
    final text = (args['query'] as String?) ?? '';
    final limit = _intArg(args, 'limit', kQueryDefaultLimit, 1, kQueryMaxLimit);
    final offset = _intArg(args, 'offset', 0, 0, null);
    final includeSummaries = args['include_summaries'] == true;

    final ctx = await _loader.load(diverId: args['diver_id'] as String?);
    final parser = QueryParser(
      appQueryRegistry,
      root,
      ParseContext(prefs: ctx.prefs, now: DateTime.now(), names: ctx.names),
    );
    final node = switch (parser.parse(text)) {
      ParseOk(:final node) => node,
      ParseFailure(:final error) => throw _parseError(error),
    };
    final problems = validateQuery(node, root, appQueryRegistry);
    if (problems.isNotEmpty) {
      throw AgentToolException(
        AgentToolErrorCode.parseError,
        problems.first.message,
        details: {
          'errors': [for (final p in problems) _errorJson(p)],
        },
      );
    }
    final compiled = compileQuery(
      node,
      root,
      appQueryRegistry,
      diverId: ctx.diverId,
    );
    if (compiled.tablesTouched.contains(serviceStatusTable)) {
      throw const AgentToolException(
        AgentToolErrorCode.invalidArgument,
        'The serviceDue field is not available to agents in this version.',
      );
    }
    final runner = QueryIdSetRunner(context.db);
    final all = (await runner.ids(
      compiled,
      scope: rootScopeFor(root, ctx.diverId, alias: compiled.rootAlias),
    )).toList()..sort();
    final page = all.skip(offset).take(limit).toList();
    final result = <String, Object?>{
      'root': root.subject.name,
      'diver_id': ctx.diverId,
      'total': all.length,
      'ids': page,
      'offset': offset,
      'limit': limit,
      'has_more': offset + page.length < all.length,
    };
    if (includeSummaries && root.subject == QuerySubject.dives) {
      final summaries = <Map<String, Object?>>[];
      for (final chunk in seriesIdChunks(page)) {
        for (final s in await _dives.getSummariesByIds(chunk)) {
          summaries.add(diveSummaryDocument(s));
        }
      }
      result['summaries'] = summaries;
    }
    return result;
  }

  QueryEntity _rootFor(Object? raw) {
    final subject = kQueryRoots.where((r) => r.name == raw).firstOrNull;
    if (subject == null) {
      throw AgentToolException(
        AgentToolErrorCode.invalidArgument,
        'root must be one of ${[for (final r in kQueryRoots) r.name]}.',
        details: {'root': raw},
      );
    }
    return appQueryRegistry.entityFor(subject);
  }

  int _intArg(
    Map<String, Object?> args,
    String key,
    int fallback,
    int min,
    int? max,
  ) {
    final raw = args[key];
    if (raw == null) return fallback;
    if (raw is! int || raw < min || (max != null && raw > max)) {
      throw AgentToolException(
        AgentToolErrorCode.invalidArgument,
        '$key must be an integer from $min${max == null ? '' : ' to $max'}.',
        details: {key: raw},
      );
    }
    return raw;
  }

  AgentToolException _parseError(QueryError error) => AgentToolException(
    AgentToolErrorCode.parseError,
    error.message,
    details: _errorJson(error),
  );

  Map<String, Object?> _errorJson(QueryError error) => {
    'code': error.code.name,
    'offset': error.offset,
    'length': error.length,
    'suggestions': error.suggestions,
  };
}
