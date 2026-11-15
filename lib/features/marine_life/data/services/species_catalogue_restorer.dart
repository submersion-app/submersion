import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/text/blank_text.dart';
import 'package:submersion/features/marine_life/data/repositories/species_repository.dart';
import 'package:submersion/features/marine_life/data/services/imported_species_resolver.dart';

const _log = LoggerService('SpeciesCatalogueRestorer');

/// Restores the species catalogue a UDDF file declares (issue #4578), as
/// `UddfImportParsers.parseSpecies` reads each `<spec>`.
///
/// A sighting creates the species it names on import, but a species no
/// dive sighted came back from nowhere else, so a backup lost every such
/// custom species. Each entry goes through [ImportedSpeciesResolver], which
/// links to a species already here (bundled or custom) rather than minting
/// a twin, so restoring the same backup twice changes nothing.
///
/// An entry with neither a common nor a scientific name is skipped. Best
/// effort per entry: one unreadable species must not fail the import.
Future<void> restoreSpeciesCatalogue(
  List<Map<String, dynamic>> catalogue,
  SpeciesRepository repository,
) async {
  if (catalogue.isEmpty) return;
  final resolver = ImportedSpeciesResolver(repository);
  String? text(Object? value) => value is String ? trimmedOrNull(value) : null;

  for (final entry in catalogue) {
    final scientific = text(entry['scientificName']);
    final name = text(entry['commonName']) ?? scientific;
    if (name == null) continue;
    final category = entry['category'];
    try {
      await resolver.resolve(
        commonName: name,
        scientificName: scientific,
        category: category is SpeciesCategory ? category : null,
        taxonomyClass: text(entry['taxonomyClass']),
        description: text(entry['description']),
      );
    } catch (e) {
      _log.warning('Could not restore the species "$name": $e');
    }
  }
}
