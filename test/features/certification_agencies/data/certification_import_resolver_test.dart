import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/certification_agencies/data/repositories/custom_certification_repository.dart';
import 'package:submersion/features/certification_agencies/data/services/certification_import_resolver.dart';

import '../../../helpers/test_database.dart';

void main() {
  late CustomCertificationRepository repo;

  setUp(() async {
    final db = await setUpTestDatabase();
    for (final id in ['a', 'b']) {
      await db.customStatement(
        'INSERT INTO divers (id, name, created_at, updated_at) '
        'VALUES (?, ?, 0, 0)',
        [id, id],
      );
    }
    repo = CustomCertificationRepository();
  });
  tearDown(tearDownTestDatabase);

  CertificationImportResolver resolver({String diverId = 'a'}) =>
      CertificationImportResolver(
        repo,
        diverId: diverId,
        shareByDefault: false,
      );

  test('built-ins match by enum name or display name, ignoring case', () async {
    final r = resolver();
    expect(await r.agencyId('PADI'), 'padi');
    expect(await r.agencyId('acuc'), 'acuc');
    expect(await r.levelId('padi', 'Open Water'), 'openWater');
    expect(await r.levelId('padi', 'advancedopenwater'), 'advancedOpenWater');
  });

  test('a blank agency keeps the existing PADI default', () async {
    expect(await resolver().agencyId(''), 'padi');
    expect(await resolver().agencyId(null), 'padi');
    expect(await repo.getAllAgencies(), isEmpty);
  });

  test('an unknown agency becomes a private custom agency', () async {
    final id = await resolver().agencyId('  Club X ');
    final agencies = await repo.getAllAgencies();
    expect(agencies.single.id, id);
    expect(agencies.single.name, 'Club X');
    expect(agencies.single.diverId, 'a');
    expect(agencies.single.isShared, isFalse);
  });

  test('second import reuses the custom agency', () async {
    final first = await resolver().agencyId('Club X');
    final second = await resolver().agencyId('club x');
    expect(second, first);
    expect(await repo.getAllAgencies(), hasLength(1));
  });

  test(
    "another diver's shared agency is reused, a private one is not",
    () async {
      final shared = await repo.createAgency(
        diverId: 'b',
        name: 'Shared Club',
        isShared: true,
      );
      await repo.createAgency(
        diverId: 'b',
        name: 'Private Club',
        isShared: false,
      );
      final r = resolver();
      expect(await r.agencyId('shared club'), shared.id);
      final created = await r.agencyId('Private Club');
      expect(created, isNot(shared.id));
      expect(await repo.getAllAgencies(), hasLength(3));
    },
  );

  test(
    'unknown level text is not auto-created; a known custom level matches',
    () async {
      final r = resolver();
      expect(await r.levelId('padi', 'Underwater Basket Weaving'), isNull);
      expect(await repo.getAllLevels(), isEmpty);
      final l = await repo.createLevel(
        diverId: 'a',
        agencyId: 'padi',
        name: 'Ice Diver',
        isProgression: true,
        isShared: false,
      );
      expect(await r.levelId('padi', 'ice diver'), l.id);
    },
  );

  test(
    "a level name shared by two agencies resolves to the agency's own",
    () async {
      final r = resolver();
      expect(await r.levelId('acuc', 'Advanced Diver'), 'acucAdvancedDiver');
      expect(await r.levelId('bsac', 'Advanced Diver'), 'bsacAdvancedDiver');
    },
  );

  // Copilot review on PR #3011: a custom level named after another agency's
  // built-in must survive export and re-import as itself.
  test('a custom level wins over a built-in from another agency', () async {
    final padiCustom = await repo.createLevel(
      diverId: 'a',
      agencyId: 'padi',
      name: 'Advanced Diver',
      isProgression: true,
      isShared: false,
    );
    final club = await repo.createAgency(
      diverId: 'a',
      name: 'Club X',
      isShared: false,
    );
    final clubOpenWater = await repo.createLevel(
      diverId: 'a',
      agencyId: club.id,
      name: 'Open Water',
      isProgression: true,
      isShared: false,
    );
    final r = resolver();
    expect(await r.levelId('padi', 'Advanced Diver'), padiCustom.id);
    expect(await r.levelId(club.id, 'open water'), clubOpenWater.id);
    // With no custom match, the global built-ins still apply.
    expect(await r.levelId(club.id, 'Rescue Diver'), 'rescue');
  });

  test('a shared import falls back to private when another diver holds the '
      'name privately', () async {
    await repo.createAgency(diverId: 'b', name: 'Club X', isShared: false);
    final r = CertificationImportResolver(
      repo,
      diverId: 'a',
      shareByDefault: true,
    );
    final id = await r.agencyId('Club X');
    final created = (await repo.getAllAgencies()).firstWhere((a) => a.id == id);
    expect(created.diverId, 'a');
    expect(created.isShared, isFalse);
  });
}
