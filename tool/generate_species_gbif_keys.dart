// Resolves the bundled species catalog to GBIF taxon keys and derives the
// taxon whitelist used by the nearby-species query.
//
// Run manually when assets/data/species.json changes:
//   dart run tool/generate_species_gbif_keys.dart
//
// This hits the network. It is not part of the build or CI.
import 'dart:convert';
import 'dart:io';

const String _matchEndpoint = 'https://api.gbif.org/v1/species/match';
const String _userAgent = 'Submersion/1.0 (https://submersion.app)';

/// Taxa whose catalog members are aquatic re-entrants into an otherwise
/// terrestrial group. Whitelisting one of these admits every land relative,
/// which is how foxes, badgers, martens and polecats reached the
/// nearby-species list at a freshwater site (issue #1036).
///
/// Naming a taxon here pushes its catalog species down to the next rank, so
/// the entries are the coarsest rank that still needs narrowing rather than
/// an exhaustive list of terrestrial groups.
const Set<String> _straddlingTaxa = {
  // Seals, sea lions and the sea otter, alongside every fox, badger and cat.
  'Carnivora',
  // The sea otter's own family, shared with the badger, marten and polecat.
  'Mustelidae',
  // Sea snakes and kraits, alongside cobras, mambas and taipans.
  'Elapidae',
  // The marine iguana, alongside the green iguana and its tree-dwelling kin.
  'Iguanidae',
};

Future<void> main() async {
  final catalog =
      jsonDecode(await File('assets/data/species.json').readAsString())
          as Map<String, dynamic>;
  final species = (catalog['species'] as List).cast<Map<String, dynamic>>();

  final client = HttpClient();
  final speciesKeys = <String, String>{};
  final taxonKeys = <int>{};
  final unmatched = <String>[];
  final unwhitelisted = <String>[];
  final collisions = <String>[];

  for (final entry in species) {
    final scientificName = entry['scientificName'] as String?;
    final localId = entry['id'] as String?;
    if (scientificName == null || localId == null) continue;

    final uri = Uri.parse(
      '$_matchEndpoint?name=${Uri.encodeQueryComponent(scientificName)}',
    );

    try {
      final request = await client.getUrl(uri);
      request.headers.set(HttpHeaders.userAgentHeader, _userAgent);
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();

      if (response.statusCode != 200) {
        unmatched.add(scientificName);
        continue;
      }

      final match = jsonDecode(body) as Map<String, dynamic>;
      final usageKey = match['usageKey'];

      if (usageKey is int) {
        // The catalog contains a handful of duplicate scientific names whose
        // later copy is miscategorised (mantas and a hammerhead filed as
        // generic 'fish'). Keeping the first occurrence is both deterministic
        // and the better-categorised entry; last-write-wins would silently
        // pick the wrong one.
        final key = usageKey.toString();
        final existing = speciesKeys[key];
        if (existing == null) {
          speciesKeys[key] = localId;
        } else {
          collisions.add('$scientificName: kept $existing, dropped $localId');
        }
      } else {
        unmatched.add(scientificName);
      }

      final whitelistKey = _whitelistKey(match);
      if (whitelistKey != null) {
        taxonKeys.add(whitelistKey);
      } else {
        unwhitelisted.add(scientificName);
      }
    } catch (e) {
      unmatched.add(scientificName);
    }

    // Be polite to a free public service.
    await Future<void>.delayed(const Duration(milliseconds: 120));
  }

  client.close();

  final sortedTaxa = taxonKeys.toList()..sort();
  final output = const JsonEncoder.withIndent('  ').convert({
    'generated': DateTime.now().toUtc().toIso8601String().split('T').first,
    'speciesKeys': speciesKeys,
    'taxonKeys': sortedTaxa,
  });
  await File('assets/data/species_gbif_keys.json').writeAsString('$output\n');

  stdout.writeln('Resolved ${speciesKeys.length} of ${species.length} species');
  stdout.writeln('Taxon whitelist: ${sortedTaxa.length} keys');
  if (unmatched.isNotEmpty) {
    stdout.writeln('Unmatched (${unmatched.length}): ${unmatched.join(', ')}');
  }
  if (unwhitelisted.isNotEmpty) {
    stdout.writeln(
      'No whitelist rank (${unwhitelisted.length}): '
      '${unwhitelisted.join(', ')}',
    );
  }
  if (collisions.isNotEmpty) {
    stdout.writeln(
      'Duplicate scientific names in the catalog (${collisions.length}):',
    );
    for (final c in collisions) {
      stdout.writeln('  $c');
    }
  }
}

/// Picks the rank at which a catalog species enters the occurrence-query
/// whitelist: the broadest one that stays aquatic.
///
/// Order is right for almost everything. Fish, corals, echinoderms and algae
/// have no terrestrial relatives, so an order is aquatic wholesale and the
/// whitelist stays generous enough to surface the regional long tail. The
/// walk down to family and then genus covers the two exceptions:
///
///   * A [_straddlingTaxa] entry is skipped as too broad, so seals enter at
///     Phocidae and the sea otter, whose family holds badgers and martens,
///     at Enhydra.
///   * GBIF's backbone ranks reptiles as classes rather than orders, so a
///     sea turtle, sea snake or saltwater crocodile carries no order key at
///     all and starts at family. Collecting order keys alone dropped every
///     one of them from the whitelist.
int? _whitelistKey(Map<String, dynamic> match) {
  const ranks = [
    ('order', 'orderKey'),
    ('family', 'familyKey'),
    ('genus', 'genusKey'),
  ];

  for (final (name, key) in ranks) {
    final value = match[key];
    if (value is! int) continue;
    if (_straddlingTaxa.contains(match[name])) continue;
    return value;
  }
  return null;
}
