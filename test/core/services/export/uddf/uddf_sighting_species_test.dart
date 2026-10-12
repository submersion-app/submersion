import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/services/export/uddf/uddf_export_builders.dart';
import 'package:submersion/core/services/export/uddf/uddf_full_import_service.dart';
import 'package:submersion/core/services/export/uddf/uddf_import_parsers.dart';
import 'package:submersion/features/marine_life/domain/entities/species.dart';
import 'package:xml/xml.dart';

/// A sighting names its species only by `speciesref`; the name, scientific
/// name and category live in `<applicationdata><submersion><species>`
/// (issue #3033). The parser resolves the ref so the importer can create or
/// match the species from the file's own data.
void main() {
  String docWith({required String sightings, String species = ''}) =>
      '''<uddf version="3.2.1">
  <profiledata>
    <repetitiongroup id="rg">
      <dive id="d1">
        <informationbeforedive>
          <divenumber>1</divenumber>
          <datetime>2026-01-15T09:00:00</datetime>
        </informationbeforedive>
        <samples>
          <waypoint><depth>5</depth><divetime>0</divetime></waypoint>
          <waypoint><depth>5</depth><divetime>60</divetime></waypoint>
        </samples>
        <informationafterdive>
          <sightings>$sightings</sightings>
        </informationafterdive>
      </dive>
    </repetitiongroup>
  </profiledata>
  <applicationdata>
    <submersion version="1.0">
      <species>$species</species>
    </submersion>
  </applicationdata>
</uddf>''';

  Future<List<Map<String, dynamic>>> sightingsOf(String doc) async {
    final result = await UddfFullImportService().importAllDataFromUddf(doc);
    return (result.dives.single['sightings'] as List)
        .cast<Map<String, dynamic>>();
  }

  test('a resolved ref carries the species section fields', () async {
    final sightings = await sightingsOf(
      docWith(
        sightings:
            '<sighting speciesref="species_grande_crevette_rose" count="3"/>',
        species: '''
          <spec id="species_grande_crevette_rose">
            <commonname>Grande crevette rose</commonname>
            <scientificname>Palaemon serratus</scientificname>
            <category>invertebrate</category>
            <taxonomyclass>Malacostraca</taxonomyclass>
            <description>Rock pools and seagrass</description>
          </spec>''',
      ),
    );

    final sighting = sightings.single;
    expect(sighting['speciesRef'], 'species_grande_crevette_rose');
    expect(sighting['speciesName'], 'Grande crevette rose');
    expect(sighting['speciesScientificName'], 'Palaemon serratus');
    expect(sighting['speciesCategory'], SpeciesCategory.invertebrate);
    expect(sighting['speciesTaxonomyClass'], 'Malacostraca');
    expect(sighting['speciesDescription'], 'Rock pools and seagrass');
    expect(sighting['count'], 3);
  });

  test('an unresolved ref is left for the name-from-ref fallback', () async {
    final sightings = await sightingsOf(
      docWith(sightings: '<sighting speciesref="species_mystery_fish"/>'),
    );

    final sighting = sightings.single;
    expect(sighting['speciesRef'], 'species_mystery_fish');
    expect(sighting.containsKey('speciesName'), isFalse);
    expect(sighting.containsKey('speciesCategory'), isFalse);
  });

  test('a spec without optional fields stamps only what it has', () async {
    final sightings = await sightingsOf(
      docWith(
        sightings: '<sighting speciesref="species_a"/>',
        species: '<spec id="species_a"><commonname>Wrasse</commonname></spec>',
      ),
    );

    final sighting = sightings.single;
    expect(sighting['speciesName'], 'Wrasse');
    expect(sighting.containsKey('speciesScientificName'), isFalse);
    expect(sighting.containsKey('speciesCategory'), isFalse);
    expect(sighting.containsKey('speciesTaxonomyClass'), isFalse);
  });

  test('the taxonomy class survives an export and a re-parse', () {
    final builder = XmlBuilder();
    builder.element(
      'uddf',
      nest: () => UddfExportBuilders.buildApplicationData(
        builder,
        species: const [
          Species(
            id: 'abc',
            commonName: 'Grande crevette rose',
            scientificName: 'Palaemon serratus',
            category: SpeciesCategory.invertebrate,
            taxonomyClass: 'Malacostraca',
          ),
        ],
      ),
    );
    final spec = builder.buildDocument().findAllElements('spec').single;

    expect(spec.getAttribute('id'), 'species_abc');
    final parsed = UddfImportParsers.parseSpecies(spec);
    expect(parsed['taxonomyClass'], 'Malacostraca');
    expect(parsed['scientificName'], 'Palaemon serratus');
  });

  test('a species without a taxonomy class writes no element', () {
    final builder = XmlBuilder();
    builder.element(
      'uddf',
      nest: () => UddfExportBuilders.buildApplicationData(
        builder,
        species: const [
          Species(
            id: 'x',
            commonName: 'Wrasse',
            category: SpeciesCategory.fish,
          ),
        ],
      ),
    );

    final spec = builder.buildDocument().findAllElements('spec').single;
    expect(spec.findElements('taxonomyclass'), isEmpty);
  });
}
