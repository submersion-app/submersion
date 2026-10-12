import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/dive_sites/query/site_filter_query.dart';

void main() {
  test('libraryId compiles to shared_library_id, personal to IS NULL', () {
    final lib = compileSiteFilter(const SiteFilterState(libraryId: 'L'));
    expect(lib.where, contains('shared_library_id'));
    expect(lib.params, contains('L'));
    final personal = compileSiteFilter(
      const SiteFilterState(libraryId: SiteFilterState.personalLibrary),
    );
    expect(personal.where.toUpperCase(), contains('SHARED_LIBRARY_ID IS NULL'));
  });

  test('libraryId counts as an active filter and clears', () {
    const filter = SiteFilterState(libraryId: 'L');
    expect(filter.hasActiveFilters, isTrue);
    expect(filter.copyWith(clearLibraryId: true).hasActiveFilters, isFalse);
    expect(filter.copyWith(libraryId: 'M').libraryId, 'M');
    expect(filter == const SiteFilterState(libraryId: 'L'), isTrue);
  });
}
