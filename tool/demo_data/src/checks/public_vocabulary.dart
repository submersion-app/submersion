import 'package:drift/native.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/tank_presets.dart';
import 'package:submersion/core/database/app_sql_functions.dart';
import 'package:submersion/core/database/database.dart'
    hide FieldPreset, TankPresets;
import 'package:submersion/features/dive_log/domain/entities/view_field_config.dart';
import 'package:submersion/features/documents/domain/entities/document_page.dart';

import '../seeders/gear_catalog.dart';
import '../seeders/places_seeder.dart';
import '../story/story_plan.dart';
import 'privacy_check.dart';

/// Fixed words the demo logbook takes from the app's own vocabulary, for the
/// privacy check's allow list (issue #3708).
///
/// Real logs use the same words ("al80", "Stage", "Belt"), so a hash match on
/// one identifies nobody. Only fixed vocabulary belongs here: names, notes and
/// other free text the seeders write stay under the check.
Set<String> get demoPublicVocabulary => {
  for (final preset in TankPresets.all) preset.name,
  for (final role in TankRole.values) role.displayName,
  for (final g in demoGear) g.name,
  ...demoGearProductNames,
  for (final level in CertLevel.values) level.title,
  ...PlacesSeeder.tagNames,
  for (final preset in FieldPreset.builtInTablePresets()) preset.name,
  // DocumentRepository names a card's pages after their side.
  for (final side in DocumentPageSide.values) '${side.name}.jpg',
  // The seeders' fixed tank and weight labels.
  'Back gas',
  'Belt',
  'Trim',
};

/// Text in the personal columns of a brand-new, empty logbook: the rows the
/// app seeds itself (dive types, roles, site types and the like), which every
/// real logbook carries too.
Future<Set<String>> appSeededStrings() async {
  final db = AppDatabase(NativeDatabase.memory(setup: registerAppSqlFunctions));
  try {
    final strings = <String>{};
    for (final t in db.allTables) {
      for (final c in t.$columns) {
        if (!PrivacyCheck.isPersonalText(c)) continue;
        final rows = await db
            .customSelect(
              'SELECT DISTINCT "${c.name}" AS v FROM "${t.actualTableName}" '
              'WHERE "${c.name}" IS NOT NULL',
            )
            .get();
        strings.addAll(rows.map((r) => r.read<String>('v')));
      }
    }
    return strings;
  } finally {
    await db.close();
  }
}
