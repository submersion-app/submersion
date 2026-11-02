import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/query/names/name_index.dart';
import 'package:submersion/core/query/units/unit_prefs.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/agent_access/domain/agent_tool_error.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/query/data/name_index_loader.dart';
import 'package:submersion/features/settings/data/repositories/diver_settings_repository.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Everything a tool needs to act as one diver profile: the id, that
/// profile's settings, the query parser's unit preferences, and the name
/// index that resolves typed site and buddy names.
class DiverContext {
  const DiverContext({
    required this.diverId,
    required this.settings,
    required this.prefs,
    required this.names,
  });

  final String diverId;
  final AppSettings settings;
  final UnitPrefs prefs;
  final NameIndex names;

  UnitFormatter get formatter => UnitFormatter(settings);
}

/// Builds a [DiverContext] for the named profile, or for the active one.
///
/// The app's own providers follow the active diver only; an agent may name
/// any profile on the device, so this loader reads settings and names for
/// the given id directly. The database is a getter, resolved per call, so a
/// loader built eagerly (once per MCP session) never pins a swapped handle
/// and never touches the database until a tool runs.
class DiverContextLoader {
  DiverContextLoader({
    required AppDatabase Function() db,
    required DiverRepository divers,
    required DiverSettingsRepository settings,
    required String localeTag,
    required Future<String?> Function() activeDiverId,
  }) : _db = db,
       _divers = divers,
       _settings = settings,
       _localeTag = localeTag,
       _activeDiverId = activeDiverId;

  final AppDatabase Function() _db;
  final DiverRepository _divers;
  final DiverSettingsRepository _settings;
  final String _localeTag;
  final Future<String?> Function() _activeDiverId;

  /// The profile a call acts as: [requested] when it names an existing
  /// diver, else the active diver, else the default diver.
  Future<String> resolveDiverId(String? requested) async {
    if (requested != null) {
      final diver = await _divers.getDiverById(requested);
      if (diver == null) {
        throw AgentToolException(
          AgentToolErrorCode.unknownDiver,
          'No diver profile has id "$requested". Call list_divers for the '
          'profiles on this device.',
          details: {'diver_id': requested},
        );
      }
      return diver.id;
    }
    final active = await _activeDiverId();
    if (active != null && await _divers.getDiverById(active) != null) {
      return active;
    }
    final fallback = await _divers.getDefaultDiver();
    if (fallback == null) {
      throw const AgentToolException(
        AgentToolErrorCode.unknownDiver,
        'This device has no diver profile.',
      );
    }
    return fallback.id;
  }

  Future<DiverContext> load({String? diverId}) async {
    final id = await resolveDiverId(diverId);
    final settings =
        await _settings.getSettingsForDiver(id) ?? const AppSettings();
    final names = await NameIndexLoader(
      _db(),
    ).load(diverId: id, l10n: l10nForLocaleTag(_localeTag));
    return DiverContext(
      diverId: id,
      settings: settings,
      prefs: UnitPrefs(
        depth: settings.depthUnit,
        temperature: settings.temperatureUnit,
        pressure: settings.pressureUnit,
        weight: settings.weightUnit,
        volume: settings.volumeUnit,
      ),
      names: names,
    );
  }
}
