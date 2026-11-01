import 'package:submersion/features/agent_access/data/diver_context.dart';
import 'package:submersion/features/agent_access/data/resources/agent_resource.dart';
import 'package:submersion/features/agent_access/data/resources/query_language_resource.dart';
import 'package:submersion/features/agent_access/data/resources/units_resource.dart';
import 'package:submersion/features/agent_access/data/tools/get_records_tool.dart';
import 'package:submersion/features/agent_access/data/tools/list_divers_tool.dart';
import 'package:submersion/features/agent_access/data/tools/query_tool.dart';
import 'package:submersion/features/agent_access/domain/agent_tool.dart';
import 'package:submersion/features/agent_access/domain/agent_tool_error.dart';
import 'package:submersion/features/buddies/data/repositories/buddy_repository.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_types/data/repositories/dive_type_repository.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/marine_life/data/repositories/species_repository.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
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

  /// The read surface of this version: profiles, query, dive documents.
  static AgentToolRegistry standard({
    required DiverContextLoader loader,
    required DiverRepository divers,
    required DiverSettingsRepository settings,
    required DiveRepository dives,
    required BuddyRepository buddies,
    required SpeciesRepository species,
    required MediaRepository media,
    required DiveTypeRepository diveTypes,
  }) {
    return AgentToolRegistry(
      tools: [
        ListDiversTool(loader: loader, divers: divers, settings: settings),
        QueryTool(loader: loader, dives: dives),
        GetRecordsTool(
          loader: loader,
          dives: dives,
          buddies: buddies,
          species: species,
          media: media,
          diveTypes: diveTypes,
        ),
      ],
      resources: [
        QueryLanguageResource(),
        UnitsResource(divers: divers, settings: settings),
      ],
    );
  }
}
