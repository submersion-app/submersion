import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Every editable record must be writable by an agent before release (spec,
/// "Coverage and release gate"), so every repository method whose name says
/// it writes ([isWriteName]: create, update and delete, and rename, assign,
/// link, reorder and the rest) is accounted for: reached by a write entity,
/// or listed in the baseline as not reached yet. The baseline only shrinks. A new method
/// that a write entity does not reach fails here, which is what keeps "any
/// record" true.
///
/// After covering a method, move it to [covered] and regenerate the baseline:
/// `UPDATE_AGENT_WRITE_BASELINE=1 flutter test
/// test/architecture/agent_write_coverage_test.dart`
void main() {
  const baselinePath = 'test/architecture/agent_write_coverage_baseline.txt';

  /// `repository file:method`, and the write entity that reaches it.
  const covered = <String, String>{
    'lib/features/dive_log/data/repositories/dive_repository_impl.dart:createDive':
        'dives',
    'lib/features/dive_log/data/repositories/dive_repository_impl.dart:bulkUpdateFields':
        'dives',
    'lib/features/dive_log/data/repositories/dive_repository_impl.dart:bulkShiftDiveTimes':
        'dives',
    'lib/features/dive_log/data/repositories/dive_repository_impl.dart:bulkDeleteDives':
        'dives',
    'lib/features/dive_log/data/repositories/dive_repository_impl.dart:bulkSetSite':
        'dives',
    'lib/features/dive_log/data/repositories/dive_repository_impl.dart:bulkAddTags':
        'dives',
    'lib/features/dive_log/data/repositories/dive_repository_impl.dart:bulkRemoveTags':
        'dives',
    'lib/features/dive_log/data/repositories/dive_repository_impl.dart:bulkAddDiveTypes':
        'dives',
    'lib/features/dive_log/data/repositories/dive_repository_impl.dart:bulkRemoveDiveTypes':
        'dives',
    'lib/features/buddies/data/repositories/buddy_repository.dart:createBuddy':
        'buddies',
    'lib/features/buddies/data/repositories/buddy_repository.dart:updateFields':
        'buddies',
    'lib/features/buddies/data/repositories/buddy_repository.dart:deleteBuddy':
        'buddies',
    'lib/features/buddies/data/repositories/buddy_repository.dart:bulkAddBuddies':
        'dives',
    'lib/features/buddies/data/repositories/buddy_repository.dart:bulkRemoveBuddies':
        'dives',
    'lib/features/dive_sites/data/repositories/site_repository_impl.dart:createSite':
        'sites',
    'lib/features/dive_sites/data/repositories/site_repository_impl.dart:updateSite':
        'sites',
    'lib/features/dive_sites/data/repositories/site_repository_impl.dart:deleteSite':
        'sites',
    'lib/features/dive_log/data/repositories/dive_repository_impl.dart:bulkAddEquipment':
        'dives',
    'lib/features/dive_log/data/repositories/dive_repository_impl.dart:bulkRemoveEquipment':
        'dives',
    'lib/features/dive_log/data/repositories/dive_repository_impl.dart:bulkAddCourses':
        'dives',
    'lib/features/dive_log/data/repositories/dive_repository_impl.dart:bulkRemoveCourses':
        'dives',
    'lib/features/dive_log/data/repositories/dive_child_row_repository.dart:addTank':
        'dive_tanks',
    'lib/features/dive_log/data/repositories/dive_child_row_repository.dart:updateTank':
        'dive_tanks',
    'lib/features/dive_log/data/repositories/dive_child_row_repository.dart:deleteTank':
        'dive_tanks',
    'lib/features/dive_log/data/repositories/dive_child_row_repository.dart:addWeight':
        'dive_weights',
    'lib/features/dive_log/data/repositories/dive_child_row_repository.dart:updateWeight':
        'dive_weights',
    'lib/features/dive_log/data/repositories/dive_child_row_repository.dart:deleteWeight':
        'dive_weights',
    'lib/features/marine_life/data/repositories/species_repository.dart:addSighting':
        'sightings',
    'lib/features/marine_life/data/repositories/species_repository.dart:updateSighting':
        'sightings',
    'lib/features/marine_life/data/repositories/species_repository.dart:deleteSighting':
        'sightings',
    'lib/features/dive_log/data/repositories/dive_child_row_repository.dart:addCustomField':
        'dive_custom_fields',
    'lib/features/dive_log/data/repositories/dive_child_row_repository.dart:updateCustomField':
        'dive_custom_fields',
    'lib/features/dive_log/data/repositories/dive_child_row_repository.dart:deleteCustomField':
        'dive_custom_fields',
    'lib/features/dive_roles/data/repositories/dive_role_link_repository.dart:writeDiverRoles':
        'dives',
    'lib/features/dive_log/data/repositories/annotation_repository.dart:addAnnotation':
        'dive_events',
    'lib/features/dive_log/data/repositories/annotation_repository.dart:moveAnnotation':
        'dive_events',
    'lib/features/dive_log/data/repositories/annotation_repository.dart:removeAnnotation':
        'dive_events',
    'lib/features/dive_lab/data/repositories/dive_scenario_repository.dart:saveScenario':
        'dive_scenarios',
    'lib/features/dive_lab/data/repositories/dive_scenario_repository.dart:deleteScenario':
        'dive_scenarios',
    'lib/features/tags/data/repositories/tag_repository.dart:createTag': 'tags',
    'lib/features/tags/data/repositories/tag_repository.dart:updateTag': 'tags',
    'lib/features/tags/data/repositories/tag_repository.dart:deleteTag': 'tags',
    'lib/features/tags/data/repositories/tag_repository.dart:mergeTags': 'tags',
    'lib/features/dive_types/data/repositories/dive_type_repository.dart:createDiveType':
        'dive_types',
    'lib/features/dive_types/data/repositories/dive_type_repository.dart:updateDiveType':
        'dive_types',
    'lib/features/dive_types/data/repositories/dive_type_repository.dart:setDiveTypeVisibility':
        'dive_types',
    'lib/features/dive_types/data/repositories/dive_type_repository.dart:deleteDiveType':
        'dive_types',
    'lib/features/dive_roles/data/repositories/dive_role_repository.dart:createDiveRole':
        'dive_roles',
    'lib/features/dive_roles/data/repositories/dive_role_repository.dart:renameDiveRole':
        'dive_roles',
    'lib/features/dive_roles/data/repositories/dive_role_repository.dart:deleteDiveRole':
        'dive_roles',
    'lib/features/site_types/data/repositories/site_type_repository.dart:createSiteType':
        'site_types',
    'lib/features/site_types/data/repositories/site_type_repository.dart:updateSiteType':
        'site_types',
    'lib/features/site_types/data/repositories/site_type_repository.dart:deleteSiteType':
        'site_types',
    'lib/features/site_types/data/repositories/site_type_repository.dart:deleteSiteTypesWithLinks':
        'site_types',
    'lib/features/marine_life/data/repositories/species_repository.dart:createSpecies':
        'species',
    'lib/features/marine_life/data/repositories/species_repository.dart:updateSpecies':
        'species',
    'lib/features/marine_life/data/repositories/species_repository.dart:deleteSpecies':
        'species',
    'lib/features/marine_life/data/repositories/species_repository.dart:addExpectedSpecies':
        'sites',
    'lib/features/marine_life/data/repositories/species_repository.dart:removeExpectedSpecies':
        'sites',
    'lib/features/dive_sites/data/repositories/site_classification_repository.dart:replaceTags':
        'sites',
    'lib/features/dive_sites/data/repositories/site_classification_repository.dart:addTagsToSites':
        'sites',
    'lib/features/dive_centers/data/repositories/dive_center_repository.dart:createDiveCenter':
        'centers',
    'lib/features/dive_centers/data/repositories/dive_center_repository.dart:updateDiveCenter':
        'centers',
    'lib/features/dive_centers/data/repositories/dive_center_repository.dart:deleteDiveCenter':
        'centers',
    'lib/features/dive_centers/data/repositories/dive_center_gear_note_repository.dart:create':
        'center_gear_notes',
    'lib/features/dive_centers/data/repositories/dive_center_gear_note_repository.dart:update':
        'center_gear_notes',
    'lib/features/dive_centers/data/repositories/dive_center_gear_note_repository.dart:delete':
        'center_gear_notes',
    'lib/features/certification_agencies/data/repositories/custom_certification_repository.dart:createAgency':
        'custom_agencies',
    'lib/features/certification_agencies/data/repositories/custom_certification_repository.dart:updateAgency':
        'custom_agencies',
    'lib/features/certification_agencies/data/repositories/custom_certification_repository.dart:deleteAgency':
        'custom_agencies',
    'lib/features/certification_agencies/data/repositories/custom_certification_repository.dart:createLevel':
        'custom_levels',
    'lib/features/certification_agencies/data/repositories/custom_certification_repository.dart:updateLevel':
        'custom_levels',
    'lib/features/certification_agencies/data/repositories/custom_certification_repository.dart:deleteLevel':
        'custom_levels',
    'lib/features/certification_agencies/data/repositories/custom_certification_repository.dart:reorderProgression':
        'custom_levels',
    'lib/features/tank_presets/data/repositories/tank_preset_repository.dart:createPreset':
        'tank_presets',
    'lib/features/tank_presets/data/repositories/tank_preset_repository.dart:updatePreset':
        'tank_presets',
    'lib/features/tank_presets/data/repositories/tank_preset_repository.dart:deletePreset':
        'tank_presets',
    'lib/features/weight_presets/data/repositories/weight_preset_repository.dart:createPreset':
        'weight_presets',
    'lib/features/weight_presets/data/repositories/weight_preset_repository.dart:updatePreset':
        'weight_presets',
    'lib/features/weight_presets/data/repositories/weight_preset_repository.dart:renamePreset':
        'weight_presets',
    'lib/features/weight_presets/data/repositories/weight_preset_repository.dart:deletePreset':
        'weight_presets',
    'lib/features/cylinder_configs/data/repositories/cylinder_config_repository.dart:createConfig':
        'cylinder_configs',
    'lib/features/cylinder_configs/data/repositories/cylinder_config_repository.dart:updateConfig':
        'cylinder_configs',
    'lib/features/cylinder_configs/data/repositories/cylinder_config_repository.dart:deleteConfig':
        'cylinder_configs',
    'lib/features/cylinder_configs/data/repositories/cylinder_config_repository.dart:saveItems':
        'cylinder_configs',
  };

  /// Writes that change no record a diver keeps, so no change set entity
  /// covers them, each with the reason. `path:*` exempts a whole repository
  /// file. Anything a diver edits as a record of their diving stays out of
  /// here, however small.
  const exempt = <String, String>{
    'lib/features/settings/data/repositories/app_settings_repository.dart:*':
        'app preferences, not logbook records',
    'lib/features/settings/data/repositories/diver_settings_repository.dart:*':
        'a diver\'s preferences, not logbook records',
    'lib/features/auto_update/data/repositories/update_preferences.dart:*':
        'app preferences',
    'lib/features/backup/data/repositories/backup_preferences.dart:*':
        'app preferences and backup bookkeeping',
    'lib/features/change_log/data/repositories/change_log_preferences.dart:*':
        'app preferences',
    'lib/features/change_log/data/repositories/change_log_repository.dart:*':
        'the log of changes itself, written by every write',
    'lib/features/notifications/data/repositories/scheduled_notification_repository.dart:*':
        'reminders scheduled from records, rewritten when they change',
    'lib/features/maps/data/repositories/offline_map_repository.dart:*':
        'map downloads kept on this device',
    'lib/features/reef/data/repositories/reef_cache_dao.dart:*': 'a cache',
    'lib/features/tides/data/repositories/noaa_station_cache_repository.dart:*':
        'a cache',
    'lib/features/gps_log/data/repositories/track_geometry_cache_repository.dart:*':
        'a cache',
    'lib/features/insights/data/repositories/deco_classification_cache.dart:*':
        'a cache',
    'lib/features/insights/data/repositories/observation_dismissals_repository.dart:*':
        'the state of derived findings, recomputed from records',
    'lib/features/data_quality/data/repositories/quality_findings_repository.dart:*':
        'the state of derived findings, recomputed from records',
    'lib/features/dive_computer/data/repositories/dive_computer_connection_repository.dart:*':
        'this device\'s pairing with a dive computer',
    'lib/features/marine_life/data/repositories/species_repository.dart:resetBuiltInSpecies':
        'restores the bundled catalogue; the edits it undoes are species '
        'updates',
    'lib/features/weight_presets/data/repositories/weight_preset_repository.dart:createFromWeights':
        'a shortcut for a create with entries, which weight_presets covers',
  };

  /// A public `Future` method on a repository. The return type may sit on the
  /// line above the name. The type stops at `=` and at the end of its line, or
  /// on a line ending in `=>` it would run to that arrow and take the method
  /// the body calls on the next line for this one.
  final futureMethod = RegExp(
    r'^\s*Future<[^=;\n]*>\s+(?:\n\s*)?([a-z]\w*)\s*[(<]',
    multiLine: true,
  );

  Set<String> scanRepositories() {
    final found = <String>{};
    for (final entity in Directory('lib/features').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final path = entity.path.replaceAll(r'\', '/');
      if (!path.contains('/data/repositories/')) continue;
      for (final match in futureMethod.allMatches(entity.readAsStringSync())) {
        final name = match.group(1)!;
        if (isWriteName(name)) found.add('$path:$name');
      }
    }
    return found;
  }

  test('a write is known by every verb repositories use for one', () {
    for (final name in [
      'createDive',
      'renameDiveRole',
      'assignDivesToTrip',
      'linkDiveToCourse',
      'unlinkDive',
      'reorderCylinders',
      'markAsServiced',
      'clearDefault',
      'replaceBuddyCertifications',
      'retireEquipment',
      'shareWith',
      'shiftDiveTimes',
      'fillNotesIfEmpty',
      'recordConnection',
    ]) {
      expect(isWriteName(name), isTrue, reason: name);
    }
    for (final name in [
      'getDiveById',
      'recordExists',
      'countDives',
      'watchAll',
      'partitionMediaForDiveDeletion',
    ]) {
      expect(isWriteName(name), isFalse, reason: name);
    }
  });

  Set<String> readBaseline() => File(baselinePath)
      .readAsLinesSync()
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toSet();

  /// Whether [method] is exempt, by name or with its whole repository file.
  bool isExempt(String method) =>
      exempt.containsKey(method) ||
      exempt.containsKey('${method.substring(0, method.lastIndexOf(':'))}:*');

  test('every exempt entry names an existing write and a reason', () {
    final found = scanRepositories();
    for (final MapEntry(:key, :value) in exempt.entries) {
      expect(value.trim(), isNotEmpty, reason: key);
      if (key.endsWith(':*')) {
        final file = key.substring(0, key.length - 1);
        expect(found.any((m) => m.startsWith(file)), isTrue, reason: key);
      } else {
        expect(found, contains(key));
      }
    }
  });

  test('no method is both covered and exempt', () {
    expect(covered.keys.where(isExempt), isEmpty);
  });

  test('every repository write is covered or in the baseline', () {
    final found = scanRepositories().where((m) => !isExempt(m)).toSet();
    if (Platform.environment['UPDATE_AGENT_WRITE_BASELINE'] == '1') {
      final lines = found.difference(covered.keys.toSet()).toList()..sort();
      File(baselinePath).writeAsStringSync('${lines.join('\n')}\n');
    }

    final unaccounted = found
        .difference(covered.keys.toSet())
        .difference(readBaseline());

    expect(
      unaccounted,
      isEmpty,
      reason:
          'A repository gained a write no agent can reach. Add a change set '
          'entity for it and list it in covered.',
    );
  });

  test('the baseline names no method that has gone or been covered', () {
    final found = scanRepositories();

    expect(readBaseline().difference(found), isEmpty);
    expect(readBaseline().intersection(covered.keys.toSet()), isEmpty);
    expect(readBaseline().where(isExempt), isEmpty);
  });

  test('every covered method exists', () {
    expect(covered.keys.toSet().difference(scanRepositories()), isEmpty);
  });
}

/// Whether a repository method's name says it writes. The verbs are the ones
/// repositories here use for a write, so a new method under any of them is
/// either reached by a write entity or listed in the baseline.
bool isWriteName(String name) =>
    !_readsNamedLikeWrites.contains(name) &&
    RegExp('^(?:${_writeVerbs.join('|')})(?:[A-Z]\\w*)?\$').hasMatch(name);

const _writeVerbs = [
  'create',
  'add',
  'insert',
  'update',
  'set',
  'save',
  'delete',
  'remove',
  'upsert',
  'bulk',
  'merge',
  'clear',
  'restore',
  'link',
  'unlink',
  'relink',
  'repoint',
  'apply',
  'replace',
  'rename',
  'reorder',
  'undo',
  'mark',
  'write',
  'assign',
  'reassign',
  'unassign',
  'fill',
  'shift',
  'retire',
  'share',
  'unshare',
  'record',
  'stamp',
  'promote',
  'archive',
  'unarchive',
  'toggle',
  'hide',
  'unhide',
  'move',
  'attach',
  'detach',
  'swap',
  'duplicate',
  'reset',
  'dismiss',
  'pin',
  'unpin',
  'purge',
  'prune',
  'wipe',
];

/// Methods whose name starts with a write verb but which only read.
const _readsNamedLikeWrites = {'recordExists'};
