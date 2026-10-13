import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/data/visibility/shared_item_policy.dart';
import 'package:submersion/core/services/shared_library/shared_library_models.dart';
import 'package:submersion/core/services/shared_library/shared_library_store.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/data/repositories/profile_hides_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/core/query/names/name_index.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/query/data/name_index_loader.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../helpers/test_database.dart';

Future<void> _diver(String id) => DiverRepository().createDiver(
  Diver(id: id, name: id, createdAt: DateTime(2026), updatedAt: DateTime(2026)),
);

void main() {
  setUp(() async {
    await setUpTestDatabase();
    await _diver('member');
    await _diver('other');
    await SharedLibraryStore().upsertMembership(
      const SharedLibraryMembership(
        id: 'ms',
        diverId: 'member',
        libraryId: 'L',
        memberId: 'm',
        displayName: 'Ann',
        libraryName: 'Reef Survey',
        backendKind: 's3',
      ),
    );
    await SiteRepository().createSite(
      const DiveSite(id: 'lib', name: 'Library site', sharedLibraryId: 'L'),
    );
  });

  tearDown(tearDownTestDatabase);

  Future<Iterable<String>> visibleTo(String diverId) async =>
      (await SiteRepository().getAllSites(diverId: diverId)).map((s) => s.id);

  test('a library site is visible to a member profile only', () async {
    expect(await visibleTo('member'), contains('lib'));
    expect(await visibleTo('other'), isNot(contains('lib')));
  });

  test('search honours the same rule', () async {
    expect(
      await SiteRepository().searchSites('Library', diverId: 'other'),
      isEmpty,
    );
    expect(
      await SiteRepository().searchSites('Library', diverId: 'member'),
      hasLength(1),
    );
  });

  test('the name index honours the same rule', () async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    final loader = NameIndexLoader(DatabaseService.instance.database);
    final forMember = await loader.load(diverId: 'member', l10n: l10n);
    final forOther = await loader.load(diverId: 'other', l10n: l10n);
    bool has(NameIndex index) => index.entries.any(
      (e) => e.subject == QuerySubject.sites && e.label == 'Library site',
    );
    expect(has(forMember), isTrue);
    expect(has(forOther), isFalse);
  });

  test(
    'a hide removes a library site for that profile and survives an edit',
    () async {
      expect(
        await ProfileHidesRepository().hide(
          SharedItemKind.site,
          'lib',
          'member',
        ),
        isTrue,
      );
      expect(await visibleTo('member'), isNot(contains('lib')));
      final site = (await SiteRepository().getSiteById('lib'))!;
      await SiteRepository().updateSite(
        site.copyWith(notes: 'edited remotely'),
      );
      expect(await visibleTo('member'), isNot(contains('lib')));
      await ProfileHidesRepository().unhide(
        SharedItemKind.site,
        'lib',
        'member',
      );
      expect(await visibleTo('member'), contains('lib'));
    },
  );
}
