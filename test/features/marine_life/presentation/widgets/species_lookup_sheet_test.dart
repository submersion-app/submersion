import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/marine_life/data/services/species_lookup_service.dart';
import 'package:submersion/features/marine_life/domain/entities/species_lookup.dart';
import 'package:submersion/features/marine_life/presentation/providers/species_lookup_providers.dart';
import 'package:submersion/features/marine_life/presentation/widgets/species_lookup_sheet.dart';

import '../../../../helpers/test_app.dart';

const _whale = SpeciesLookupHit(
  taxonId: 52188,
  scientificName: 'Rhincodon typus',
  rank: 'species',
  rankLevel: 10,
  commonName: 'Whale Shark',
  observationCount: 2662,
);

const _genus = SpeciesLookupHit(
  taxonId: 1,
  scientificName: 'Rhincodon',
  rank: 'genus',
  rankLevel: 20,
  observationCount: 3000,
);

const _resolved = SpeciesLookupResult(
  taxonId: 52188,
  commonName: 'Whale Shark',
  scientificName: 'Rhincodon typus',
  category: SpeciesCategory.shark,
  taxonomyClass: 'Chondrichthyes',
);

class _FakeLookup implements SpeciesLookupService {
  _FakeLookup({this.hits = const [], this.failWith});

  final List<SpeciesLookupHit> hits;
  final SpeciesLookupException? failWith;
  final List<String> queries = [];
  final List<int> resolved = [];

  @override
  Future<List<SpeciesLookupHit>> search(
    String query, {
    required String locale,
  }) async {
    queries.add('$query@$locale');
    if (failWith != null) throw failWith!;
    return hits;
  }

  @override
  Future<SpeciesLookupResult> resolve(
    int taxonId, {
    required String locale,
  }) async {
    resolved.add(taxonId);
    return _resolved;
  }
}

/// Opens the sheet from a button so the popped value can be captured.
Future<SpeciesLookupOutcome? Function()> _open(
  WidgetTester tester,
  _FakeLookup service, {
  String initialQuery = '',
  bool allowCreateWithout = true,
}) async {
  SpeciesLookupOutcome? popped;
  var closed = false;
  await tester.pumpWidget(
    testApp(
      locale: const Locale('en'),
      overrides: [
        speciesLookupServiceProvider.overrideWithValue(service),
        speciesLookupLocaleProvider.overrideWithValue('en'),
      ],
      child: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () async {
            popped = await showSpeciesLookupSheet(
              context,
              initialQuery: initialQuery,
              allowCreateWithout: allowCreateWithout,
            );
            closed = true;
          },
          child: const Text('OPEN'),
        ),
      ),
    ),
  );
  await tester.tap(find.text('OPEN'));
  await tester.pumpAndSettle();
  return () => closed ? popped : throw StateError('sheet still open');
}

void main() {
  testWidgets('starts idle and searches only when asked', (tester) async {
    final service = _FakeLookup(hits: const [_whale, _genus]);
    await _open(tester, service, initialQuery: 'whale');

    expect(find.text('Type a name and tap Look up.'), findsOneWidget);
    expect(service.queries, isEmpty);

    await tester.tap(find.text('Look up'));
    await tester.pumpAndSettle();

    expect(service.queries, ['whale@en']);
    expect(find.text('Whale Shark'), findsOneWidget);
    expect(find.text('Rhincodon typus'), findsOneWidget);
    expect(find.text('2662 observations'), findsOneWidget);
    expect(
      find.text('Species data and photos from iNaturalist'),
      findsOneWidget,
    );
  });

  testWidgets('a coarser rank is listed but cannot be chosen', (tester) async {
    final service = _FakeLookup(hits: const [_genus]);
    await _open(tester, service, initialQuery: 'rhincodon');
    await tester.tap(find.text('Look up'));
    await tester.pumpAndSettle();

    expect(find.text('genus: choose a species'), findsOneWidget);
    final tile = tester.widget<ListTile>(
      find.widgetWithText(ListTile, 'Rhincodon'),
    );
    expect(tile.enabled, isFalse);
  });

  testWidgets('choosing a hit resolves it and pops with the result', (
    tester,
  ) async {
    final service = _FakeLookup(hits: const [_whale]);
    final read = await _open(tester, service, initialQuery: 'whale');
    await tester.tap(find.text('Look up'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Whale Shark'));
    await tester.pumpAndSettle();

    expect(service.resolved, [52188]);
    expect(
      read(),
      isA<SpeciesLookupChosen>().having((o) => o.result, 'result', _resolved),
    );
  });

  testWidgets('shows the empty state for a query with no hits', (tester) async {
    final service = _FakeLookup();
    await _open(tester, service, initialQuery: 'zzz');
    await tester.tap(find.text('Look up'));
    await tester.pumpAndSettle();

    expect(find.text('No species found for "zzz"'), findsOneWidget);
  });

  testWidgets('shows one message per failure kind with a retry', (
    tester,
  ) async {
    final service = _FakeLookup(
      failWith: const SpeciesLookupException(SpeciesLookupErrorKind.offline),
    );
    await _open(tester, service, initialQuery: 'whale');
    await tester.tap(find.text('Look up'));
    await tester.pumpAndSettle();

    expect(find.text('You appear to be offline.'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(service.queries, hasLength(2));
  });

  testWidgets('Create without lookup pops its own outcome, distinct from a '
      'dismissal', (tester) async {
    final service = _FakeLookup();
    final read = await _open(tester, service, initialQuery: 'whale');

    await tester.tap(find.text('Create without lookup'));
    await tester.pumpAndSettle();

    expect(read(), isA<SpeciesLookupCreateWithout>());
  });

  testWidgets('dismissing the sheet pops null', (tester) async {
    final service = _FakeLookup();
    final read = await _open(tester, service, initialQuery: 'whale');

    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();

    expect(read(), isNull);
  });

  testWidgets('the create-without escape is withheld when the caller has no '
      'name to fall back on', (tester) async {
    final service = _FakeLookup();
    await _open(tester, service, allowCreateWithout: false);

    expect(find.text('Create without lookup'), findsNothing);
    expect(find.byKey(const ValueKey('lookup_create_without')), findsNothing);
  });
}
