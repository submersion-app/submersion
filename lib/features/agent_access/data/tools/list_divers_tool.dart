import 'package:submersion/features/agent_access/data/diver_context.dart';
import 'package:submersion/features/agent_access/data/documents/diver_document.dart';
import 'package:submersion/features/agent_access/domain/agent_tool.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/settings/data/repositories/diver_settings_repository.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

/// Lists every diver profile on the device with its unit preferences.
class ListDiversTool implements AgentTool {
  ListDiversTool({
    required DiverContextLoader loader,
    required DiverRepository divers,
    required DiverSettingsRepository settings,
  }) : _loader = loader,
       _divers = divers,
       _settings = settings;

  final DiverContextLoader _loader;
  final DiverRepository _divers;
  final DiverSettingsRepository _settings;

  @override
  String get name => 'list_divers';

  @override
  String get description =>
      'List every diver profile on this device: id, name, whether it is the '
      'active profile, dive count, and the display units it prefers. Other '
      'tools take an optional diver_id from this list; omitted means the '
      'active profile.';

  @override
  Map<String, Object?> get inputSchema => const {
    'type': 'object',
    'properties': <String, Object?>{},
    'additionalProperties': false,
  };

  @override
  Future<Map<String, Object?>> call(
    Map<String, Object?> args,
    AgentToolContext context,
  ) async {
    final activeId = await _loader.resolveDiverId(null);
    final divers = await _divers.getAllDivers();
    final counts = await _divers.getDiveCountsByDiver();
    final docs = <Map<String, Object?>>[];
    for (final diver in divers) {
      final settings =
          await _settings.getSettingsForDiver(diver.id) ?? const AppSettings();
      docs.add(
        diverDocument(
          diver,
          isActive: diver.id == activeId,
          diveCount: counts[diver.id] ?? 0,
          settings: settings,
        ),
      );
    }
    return {'divers': docs};
  }
}
