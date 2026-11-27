import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/marine_life/domain/entities/species.dart';
import 'package:submersion/features/marine_life/domain/services/species_suggestion_url.dart';

const _species = Species(
  id: 'c1',
  commonName: 'Stove-pipe Sponge',
  scientificName: 'Aplysina archeri',
  category: SpeciesCategory.invertebrate,
  taxonomyClass: 'Demospongiae',
  description: 'Tall purple tubes on the wall.',
);

Map<String, String> _fields(Uri uri) => uri.queryParameters;

void main() {
  test('targets the species issue form with every field filled', () {
    final uri = buildSpeciesSuggestionUrl(
      species: _species,
      locale: 'de',
      appVersion: '1.7.6.7001',
    );

    expect(uri.scheme, 'https');
    expect(uri.host, 'github.com');
    expect(uri.path, '/submersion-app/submersion/issues/new');
    expect(
      uri.queryParameters['title'],
      'Species suggestion: Stove-pipe Sponge',
    );
    expect(uri.queryParameters['template'], 'species-suggestion.yml');
    // The form applies the label for every reporter; a labels= parameter
    // is dropped for anyone who cannot triage the repository.
    expect(uri.queryParameters.containsKey('labels'), isFalse);
    expect(uri.queryParameters.containsKey('body'), isFalse);

    final fields = _fields(uri);
    expect(fields['common_name'], 'Stove-pipe Sponge');
    expect(fields['scientific_name'], 'Aplysina archeri');
    expect(fields['category'], 'invertebrate');
    expect(fields['taxonomy_class'], 'Demospongiae');
    expect(fields['description'], 'Tall purple tubes on the wall.');
    expect(fields['locale'], 'de');
    expect(fields['app_version'], '1.7.6.7001');
  });

  test('keeps the whole URL under the cap by truncating the description', () {
    final long = _species.copyWith(description: 'x' * 20000);

    final uri = buildSpeciesSuggestionUrl(
      species: long,
      locale: 'en',
      appVersion: '1.0.0.1',
    );

    expect(uri.toString().length, lessThanOrEqualTo(8000));
    expect(_fields(uri)['scientific_name'], 'Aplysina archeri');
  });

  test('keeps the URL under the cap when the name is the oversized field', () {
    final long = _species.copyWith(commonName: 'x' * 20000, description: '');

    final uri = buildSpeciesSuggestionUrl(
      species: long,
      locale: 'en',
      appVersion: '1.0.0.1',
    );

    expect(uri.toString().length, lessThanOrEqualTo(8000));
    // The scientific name is what identifies the species, so it survives.
    expect(_fields(uri)['scientific_name'], 'Aplysina archeri');
    expect(uri.queryParameters['title'], startsWith('Species suggestion: xxx'));
  });

  test('truncates the description before the name', () {
    final long = _species.copyWith(
      commonName: 'Stove-pipe Sponge',
      description: 'y' * 20000,
    );

    final uri = buildSpeciesSuggestionUrl(
      species: long,
      locale: 'en',
      appVersion: '1.0.0.1',
    );

    expect(uri.toString().length, lessThanOrEqualTo(8000));
    expect(_fields(uri)['common_name'], 'Stove-pipe Sponge');
  });

  test('holds the cap when every free-text field is oversized', () {
    final long = _species.copyWith(
      commonName: 'x' * 20000,
      scientificName: 'y' * 20000,
      taxonomyClass: 'z' * 20000,
      description: 'w' * 20000,
    );

    final uri = buildSpeciesSuggestionUrl(
      species: long,
      locale: 'en',
      appVersion: '1.0.0.1',
    );

    expect(uri.toString().length, lessThanOrEqualTo(8000));
  });

  test('cuts the description, class and name before the scientific name', () {
    final long = _species.copyWith(
      taxonomyClass: 'z' * 9000,
      description: 'w' * 9000,
    );

    final fields = _fields(
      buildSpeciesSuggestionUrl(
        species: long,
        locale: 'en',
        appVersion: '1.0.0.1',
      ),
    );

    // What identifies the species survives while the others give way.
    expect(fields['scientific_name'], 'Aplysina archeri');
    expect(fields['common_name'], 'Stove-pipe Sponge');
    expect(fields['description']!.length, lessThan(9000));
  });

  test('a species with no scientific name or class leaves them out', () {
    const bare = Species(
      id: 'c2',
      commonName: 'Unknown blenny',
      category: SpeciesCategory.fish,
    );

    final fields = _fields(
      buildSpeciesSuggestionUrl(
        species: bare,
        locale: 'en',
        appVersion: '1.0.0.1',
      ),
    );

    expect(fields.containsKey('scientific_name'), isFalse);
    expect(fields.containsKey('taxonomy_class'), isFalse);
  });

  test('encodes non-ASCII names', () {
    final uri = buildSpeciesSuggestionUrl(
      species: _species.copyWith(commonName: 'Süßwasser Grundel'),
      locale: 'de',
      appVersion: '1.0.0.1',
    );

    expect(
      uri.queryParameters['title'],
      'Species suggestion: Süßwasser Grundel',
    );
    expect(uri.toString(), isNot(contains('ü')));
  });

  test('every field the builder sends is an id in the issue form', () {
    final form = File(
      p.join('.github', 'ISSUE_TEMPLATE', 'species-suggestion.yml'),
    ).readAsStringSync();
    final ids = RegExp(
      r'^\s+id:\s*(\S+)',
      multiLine: true,
    ).allMatches(form).map((m) => m.group(1)).toSet();

    final sent = buildSpeciesSuggestionUrl(
      species: _species,
      locale: 'en',
      appVersion: '1.0.0.1',
    ).queryParameters.keys.toSet()..removeAll(['template', 'title']);
    expect(ids, containsAll(sent));
    expect(form, contains('labels: ["species-suggestion"]'));
  });
}
