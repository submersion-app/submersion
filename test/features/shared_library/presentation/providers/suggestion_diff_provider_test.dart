import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart' show DiveSitesCompanion;
import 'package:submersion/core/services/shared_library/shared_library_store.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/shared_library/presentation/providers/shared_library_providers.dart';

import '../../../../helpers/test_database.dart';

void main() {
  setUp(setUpTestDatabase);
  tearDown(tearDownTestDatabase);

  test(
    'reopening a suggestion compares against the site as it is now',
    () async {
      await SiteRepository().createSite(
        const DiveSite(
          id: 's',
          name: 'S',
          hazards: 'old',
          sharedLibraryId: 'L',
        ),
      );
      await SharedLibraryStore().putSuggestion(
        SharedSiteSuggestion(
          id: 'g',
          libraryId: 'L',
          siteId: 's',
          memberId: 'r',
          memberName: 'Ray',
          fields: const {'hazards': 'new'},
          createdAt: DateTime.utc(2026),
          direction: SharedSiteSuggestion.incoming,
        ),
      );
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // The sheet opens, then closes.
      final first = container.listen(suggestionDiffProvider('g'), (_, _) {});
      expect(
        (await container.read(suggestionDiffProvider('g').future))['hazards'],
        ('old', 'new'),
      );
      first.close();
      await Future<void>.delayed(Duration.zero);

      // A sync changes the site before the owner looks again.
      await SiteRepository().applyImportedMetadata(
        's',
        const DiveSitesCompanion(hazards: Value('newer')),
      );

      final second = container.listen(suggestionDiffProvider('g'), (_, _) {});
      addTearDown(second.close);
      expect(
        (await container.read(suggestionDiffProvider('g').future))['hazards'],
        ('newer', 'new'),
      );
    },
  );
}
