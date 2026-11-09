// Regenerates the two id-keyed lookup switches, the id list and the
// scientific name map from assets/data/species.json.
//
//   dart run tool/generate_species_lookups.dart
//
// No network. Run after any change to the asset.
import 'dart:convert';
import 'dart:io';

import 'src/species_tool_support.dart';

Future<void> main() async {
  final catalog =
      jsonDecode(await File('assets/data/species.json').readAsString())
          as Map<String, dynamic>;
  final rows = (catalog['species'] as List).cast<Map<String, dynamic>>();

  const dir = 'lib/features/marine_life/presentation';
  await File(
    '$dir/species_name_lookup.dart',
  ).writeAsString(renderNameLookup(rows));
  await File(
    '$dir/species_description_lookup.dart',
  ).writeAsString(renderDescriptionLookup(rows));
  await File('$dir/species_ids.dart').writeAsString(renderIdList(rows));
  await File(
    '$dir/species_scientific_names.dart',
  ).writeAsString(renderScientificNames(rows));
  final format = await Process.run('dart', [
    'format',
    '$dir/species_name_lookup.dart',
    '$dir/species_description_lookup.dart',
    '$dir/species_ids.dart',
    '$dir/species_scientific_names.dart',
  ]);
  stdout.write(format.stdout);
  stderr.write(format.stderr);
  stdout.writeln(
    'Wrote ${rows.length} cases into both lookups, the id list and '
    'the scientific name map',
  );
}
