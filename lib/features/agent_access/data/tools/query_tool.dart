import 'package:submersion/core/query/compiler/query_compiler.dart';
import 'package:submersion/core/query/compiler/query_validator.dart';
import 'package:submersion/core/query/domain/query_errors.dart';
import 'package:submersion/core/query/registry/query_entity.dart';
import 'package:submersion/core/query/syntax/query_parser.dart';
import 'package:submersion/features/agent_access/data/diver_context.dart';
import 'package:submersion/features/agent_access/data/documents/document_dates.dart';
import 'package:submersion/features/agent_access/data/query_roots.dart';
import 'package:submersion/features/agent_access/data/records/record_catalog.dart';
import 'package:submersion/features/agent_access/data/records/record_entity.dart';
import 'package:submersion/features/agent_access/data/records/record_repositories.dart';
import 'package:submersion/features/agent_access/data/root_scope.dart';
import 'package:submersion/features/agent_access/data/service_status_overlay.dart';
import 'package:submersion/features/agent_access/domain/agent_tool.dart';
import 'package:submersion/features/agent_access/data/tools/tool_args.dart';
import 'package:submersion/features/agent_access/domain/agent_tool_error.dart';
import 'package:submersion/features/equipment/query/equipment_query_entity.dart'
    show serviceStatusTable;
import 'package:submersion/features/query/app_query_registry.dart';
import 'package:submersion/features/query/data/query_id_set_runner.dart';

const kQueryDefaultLimit = 500;
const kQueryMaxLimit = 5000;

/// Finds records with the entity query language, scoped to one diver.
class QueryTool implements AgentTool {
  QueryTool({
    required DiverContextLoader loader,
    required RecordRepositories records,
    required RecordCatalog catalog,
  }) : _loader = loader,
       _records = records,
       _catalog = catalog;

  final DiverContextLoader _loader;
  final RecordRepositories _records;
  final RecordCatalog _catalog;

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
      'everything. include_summaries adds a compact row per record. '
      'serviceDue and nextServiceDue are evaluated for the named diver when '
      'the query runs. $kDocumentDateRule';

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
        'description': 'Return a compact summary per matching record.',
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
    final limit = intArg(
      args,
      'limit',
      fallback: kQueryDefaultLimit,
      min: 1,
      max: kQueryMaxLimit,
    );
    final offset = intArg(args, 'offset', fallback: 0, min: 0);
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
    // The cache `serviceDue` reads holds the active diver's verdicts only,
    // so the named diver's come from the engine and shadow it here.
    final cte = compiled.tablesTouched.contains(serviceStatusTable)
        ? await serviceStatusOverlay(
            diverId: ctx.diverId,
            settings: ctx.settings,
            repositories: _records,
            now: DateTime.now(),
          )
        : null;
    final runner = QueryIdSetRunner(context.db);
    final all = (await runner.ids(
      compiled,
      scope: rootScopeFor(root, ctx.diverId, alias: compiled.rootAlias),
      cte: cte,
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
    if (includeSummaries) {
      result['summaries'] = await _catalog
          .named(root.subject.name)
          .summaries(page, RecordLoad(include: const {}, diverId: ctx.diverId));
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
