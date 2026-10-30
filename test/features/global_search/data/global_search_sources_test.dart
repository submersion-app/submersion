import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/features/global_search/data/global_search_sources.dart';
import 'package:submersion/features/global_search/domain/global_search_models.dart';

void main() {
  test('every kind has exactly one source, in display order', () {
    expect(
      kGlobalSearchSources.map((s) => s.kind).toList(),
      GlobalSearchKind.values,
    );
  });

  test('every source can read a plain word', () {
    for (final source in kGlobalSearchSources) {
      expect(
        source.entity.textSearchSql,
        isNotEmpty,
        reason: '${source.kind} has nothing for a word to match',
      );
    }
  });

  test('every list a query can root at is searched', () {
    // The nine list subjects of #2365. A new one belongs in global search.
    const lists = {
      QuerySubject.dives,
      QuerySubject.sites,
      QuerySubject.equipment,
      QuerySubject.trips,
      QuerySubject.buddies,
      QuerySubject.centers,
      QuerySubject.certifications,
      QuerySubject.courses,
      QuerySubject.species,
    };
    final searched = kGlobalSearchSources.map((s) => s.entity.subject).toSet();
    expect(searched.containsAll(lists), isTrue);
  });

  test('a source with a list previews, and one without reads everything', () {
    for (final source in kGlobalSearchSources) {
      expect(source.hasList, source.previewLimit != null);
    }
    final inPlace = kGlobalSearchSources
        .where((s) => !s.hasList)
        .map((s) => s.kind)
        .toSet();
    expect(inPlace, {
      GlobalSearchKind.equipmentSets,
      GlobalSearchKind.documents,
      GlobalSearchKind.divePlans,
      GlobalSearchKind.gpsTracks,
      GlobalSearchKind.underwaterRoutes,
    });
  });
}
