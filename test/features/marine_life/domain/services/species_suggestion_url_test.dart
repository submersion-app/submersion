import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
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

Map<String, dynamic> _bodyJson(Uri uri) {
  final body = uri.queryParameters['body']!;
  final start = body.indexOf('```json') + '```json'.length;
  final end = body.lastIndexOf('```');
  return jsonDecode(body.substring(start, end).trim()) as Map<String, dynamic>;
}

void main() {
  test('targets a new issue with the title, label and a JSON body', () {
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
    expect(uri.queryParameters['labels'], 'species-suggestion');

    final json = _bodyJson(uri);
    expect(json['commonName'], 'Stove-pipe Sponge');
    expect(json['scientificName'], 'Aplysina archeri');
    expect(json['category'], 'invertebrate');
    expect(json['taxonomyClass'], 'Demospongiae');
    expect(json['description'], 'Tall purple tubes on the wall.');
    expect(json['locale'], 'de');
    expect(json['appVersion'], '1.7.6.7001');
  });

  test('keeps the whole URL under the cap by truncating the description', () {
    final long = _species.copyWith(description: 'x' * 20000);

    final uri = buildSpeciesSuggestionUrl(
      species: long,
      locale: 'en',
      appVersion: '1.0.0.1',
    );

    expect(uri.toString().length, lessThanOrEqualTo(8000));
    expect(_bodyJson(uri)['scientificName'], 'Aplysina archeri');
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
    expect(_bodyJson(uri)['scientificName'], 'Aplysina archeri');
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
    expect(_bodyJson(uri)['commonName'], 'Stove-pipe Sponge');
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

    final json = _bodyJson(
      buildSpeciesSuggestionUrl(
        species: long,
        locale: 'en',
        appVersion: '1.0.0.1',
      ),
    );

    // What identifies the species survives while the others give way.
    expect(json['scientificName'], 'Aplysina archeri');
    expect(json['commonName'], 'Stove-pipe Sponge');
    expect((json['description'] as String).length, lessThan(9000));
  });

  test('a species with no scientific name or class keeps them null', () {
    const bare = Species(
      id: 'c2',
      commonName: 'Unknown blenny',
      category: SpeciesCategory.fish,
    );

    final json = _bodyJson(
      buildSpeciesSuggestionUrl(
        species: bare,
        locale: 'en',
        appVersion: '1.0.0.1',
      ),
    );

    expect(json['scientificName'], isNull);
    expect(json['taxonomyClass'], isNull);
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
}
