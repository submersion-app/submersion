import 'dart:convert';

import 'package:submersion/features/agent_access/data/diver_settings_lookup.dart';
import 'package:submersion/features/agent_access/data/documents/diver_document.dart';
import 'package:submersion/features/agent_access/data/resources/agent_resource.dart';
import 'package:submersion/features/agent_access/domain/agent_tool.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/settings/data/repositories/diver_settings_repository.dart';

/// Every profile's display units, so an agent can convert metric values
/// before presenting them.
class UnitsResource implements AgentResource {
  UnitsResource({
    required DiverRepository divers,
    required DiverSettingsRepository settings,
  }) : _divers = divers,
       _settings = settings;

  final DiverRepository _divers;
  final DiverSettingsRepository _settings;

  @override
  String get uri => 'submersion://units';

  @override
  String get name => 'Display units per diver profile';

  @override
  String get mimeType => 'application/json';

  @override
  Future<String> read(AgentToolContext context) async {
    final rows = <Map<String, Object?>>[];
    for (final (:diver, :settings) in await diversWithSettings(
      _divers,
      _settings,
    )) {
      final doc = diverDocument(
        diver,
        isActive: false,
        diveCount: 0,
        settings: settings,
      );
      rows.add({
        'diver_id': diver.id,
        'units': doc['units'],
        'date_format': doc['date_format'],
        'time_format': doc['time_format'],
      });
    }
    return jsonEncode(rows);
  }
}
