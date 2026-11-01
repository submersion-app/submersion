import 'package:submersion/features/agent_access/data/diver_context.dart';
import 'package:submersion/features/agent_access/data/records/record_catalog.dart';
import 'package:submersion/features/agent_access/data/records/record_repositories.dart';
import 'package:submersion/features/agent_access/data/resources/agent_resource.dart';
import 'package:submersion/features/agent_access/data/resources/query_language_resource.dart';
import 'package:submersion/features/agent_access/data/resources/units_resource.dart';
import 'package:submersion/features/agent_access/data/tools/get_records_tool.dart';
import 'package:submersion/features/agent_access/data/tools/list_divers_tool.dart';
import 'package:submersion/features/agent_access/data/tools/list_records_tool.dart';
import 'package:submersion/features/agent_access/data/tools/query_tool.dart';
import 'package:submersion/features/agent_access/domain/agent_tool.dart';
import 'package:submersion/features/agent_access/domain/agent_tool_error.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/settings/data/repositories/diver_settings_repository.dart';

/// The tools and resources one MCP session exposes.
class AgentToolRegistry {
  AgentToolRegistry({
    required List<AgentTool> tools,
    required List<AgentResource> resources,
  }) : _tools = List.unmodifiable(tools),
       _resources = List.unmodifiable(resources);

  final List<AgentTool> _tools;
  final List<AgentResource> _resources;

  List<AgentTool> get tools => _tools;
  List<AgentResource> get resources => _resources;

  AgentTool toolNamed(String name) {
    for (final tool in _tools) {
      if (tool.name == name) return tool;
    }
    throw AgentToolException(
      AgentToolErrorCode.notFound,
      'No tool named "$name".',
      details: {'tool': name},
    );
  }

  /// The read surface of this version: profiles, query, and every record.
  static AgentToolRegistry standard({
    required DiverContextLoader loader,
    required DiverRepository divers,
    required DiverSettingsRepository settings,
    required RecordRepositories records,
  }) {
    final catalog = RecordCatalog(records);
    return AgentToolRegistry(
      tools: [
        ListDiversTool(loader: loader, divers: divers, settings: settings),
        QueryTool(loader: loader, dives: records.dives),
        GetRecordsTool(loader: loader, catalog: catalog),
        ListRecordsTool(loader: loader, catalog: catalog),
      ],
      resources: [
        QueryLanguageResource(),
        UnitsResource(divers: divers, settings: settings),
      ],
    );
  }
}
