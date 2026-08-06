// Resolves the bundled species catalog to GBIF taxon keys and derives the
// order whitelist used by the nearby-species query.
//
// Run manually when assets/data/species.json changes:
//   dart run tool/generate_species_gbif_keys.dart
//
// This hits the network. It is not part of the build or CI.
import 'dart:convert';
import 'dart:io';

const String _matchEndpoint = 'https://api.gbif.org/v1/species/match';
const String _userAgent = 'Submersion/1.0 (https://submersion.app)';

Future<void> main() async {
  final catalog =
      jsonDecode(await File('assets/data/species.json').readAsString())
          as Map<String, dynamic>;
  final species = (catalog['species'] as List).cast<Map<String, dynamic>>();

  final client = HttpClient();
  final speciesKeys = <String, String>{};
  final orderKeys = <int>{};
  final unmatched = <String>[];
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
      final orderKey = match['orderKey'];

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
      if (orderKey is int) orderKeys.add(orderKey);
    } catch (e) {
      unmatched.add(scientificName);
    }

    // Be polite to a free public service.
    await Future<void>.delayed(const Duration(milliseconds: 120));
  }

  client.close();

  final sortedOrders = orderKeys.toList()..sort();
  final output = const JsonEncoder.withIndent('  ').convert({
    'generated': DateTime.now().toUtc().toIso8601String().split('T').first,
    'speciesKeys': speciesKeys,
    'orderKeys': sortedOrders,
  });
  await File('assets/data/species_gbif_keys.json').writeAsString('$output\n');

  stdout.writeln('Resolved ${speciesKeys.length} of ${species.length} species');
  stdout.writeln('Order whitelist: ${sortedOrders.length} keys');
  if (unmatched.isNotEmpty) {
    stdout.writeln('Unmatched (${unmatched.length}): ${unmatched.join(', ')}');
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
