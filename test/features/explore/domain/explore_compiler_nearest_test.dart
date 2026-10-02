import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/query/units/unit_prefs.dart';
import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/query/names/name_index.dart';
import 'package:submersion/features/explore/domain/explore_compiler.dart';
import 'package:submersion/features/explore/domain/query_model.dart';

/// "Did you mean" searches the kinds the resolver searches: a misspelt place
/// can be a site, and a misspelt site can be a place.
void main() {
  const units = UnitPrefs(
    depth: DepthUnit.meters,
    temperature: TemperatureUnit.celsius,
    pressure: PressureUnit.bar,
    weight: WeightUnit.kilograms,
    volume: VolumeUnit.liters,
  );
  final names = NameIndex(const [
    NameEntry(
      subject: QuerySubject.sites,
      label: 'Salt Pier',
      ids: ['s-salt'],
      target: NameTarget.siteId,
    ),
    NameEntry(
      subject: QuerySubject.sites,
      label: 'Bonaire',
      ids: ['s-salt'],
      target: NameTarget.sitePlace,
    ),
  ]);

  List<String> suggestions(String kind, String text) {
    final q = ExploreCompiler.compile(
      ParsedQuery.fromJson({
        'schemaVersion': kQuerySchemaVersion,
        'subject': 'dives',
        'mentions': [
          {'kind': kind, 'text': text},
        ],
      }),
      ExploreCompilerContext(
        units: units,
        names: names,
        now: DateTime(2026, 9, 28),
      ),
    );
    return q.unresolved.single.candidates.map((e) => e.label).toList();
  }

  test('a misspelt place suggests the site it resembles', () {
    expect(suggestions('place', 'Salt Peir'), contains('Salt Pier'));
  });

  test('a misspelt site suggests the place it resembles', () {
    expect(suggestions('site', 'Bonare'), contains('Bonaire'));
  });
}
