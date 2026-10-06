import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/certification_levels.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/certification_agencies/domain/certification_catalog.dart';
import 'package:submersion/features/certification_agencies/domain/entities/custom_certification_agency.dart';
import 'package:submersion/features/certification_agencies/domain/entities/custom_certification_level.dart';

final _t = DateTime(2026);

CustomCertificationAgency agency(
  String id,
  String owner, {
  String name = 'Club X',
  bool shared = false,
}) => CustomCertificationAgency(
  id: id,
  diverId: owner,
  name: name,
  colorArgb: 0xFF3B82F6,
  isShared: shared,
  createdAt: _t,
  updatedAt: _t,
);

CustomCertificationLevel level(
  String id,
  String owner,
  String agencyId, {
  String name = 'Lvl',
  bool progression = true,
  int order = 0,
  bool shared = false,
}) => CustomCertificationLevel(
  id: id,
  diverId: owner,
  agencyId: agencyId,
  name: name,
  isProgression: progression,
  sortOrder: order,
  isShared: shared,
  createdAt: _t,
  updatedAt: _t,
);

const _uuid = '2b1f7c3e-9d8a-4c55-8e21-0f6a1b2c3d4e';

void main() {
  test('built-ins resolve to their enum with brand colours', () {
    final e = CertificationCatalog.builtInOnly.agency('acuc');
    expect(e.builtIn, CertificationAgency.acuc);
    expect(e.primaryColor, CertificationAgency.acuc.primaryColor);
    expect(e.secondaryColor, CertificationAgency.acuc.secondaryColor);
    expect(e.isFallback, isFalse);
    expect(e.interchangeName, 'ACUC');
  });

  test('null agency behaves like Other', () {
    expect(
      CertificationCatalog.builtInOnly.agency(null).builtIn,
      CertificationAgency.other,
    );
  });

  test('a custom agency resolves with its stored and derived colours', () {
    final c = CertificationCatalog(
      agencies: [agency('u1', 'a')],
      viewerDiverId: 'a',
    );
    final e = c.agency('u1');
    expect(e.name, 'Club X');
    expect(e.primaryColor.toARGB32(), 0xFF3B82F6);
    expect(e.secondaryColor, isNot(e.primaryColor));
    expect(e.isBuiltIn, isFalse);
    expect(e.interchangeName, 'Club X');
  });

  test('resolves an invisible custom agency by name', () {
    final c = CertificationCatalog(
      agencies: [agency('u1', 'b', shared: false)],
      viewerDiverId: 'a',
    );
    expect(c.agency('u1').name, 'Club X');
    expect(c.agencies.map((e) => e.id), isNot(contains('u1')));
  });

  test('pickers show own and shared agencies between built-ins and Other', () {
    final c = CertificationCatalog(
      agencies: [
        agency('own', 'a', name: 'Zeta'),
        agency('shared', 'b', name: 'Alpha', shared: true),
        agency('private', 'b', name: 'Hidden'),
      ],
      viewerDiverId: 'a',
    );
    final ids = c.agencies.map((e) => e.id).toList();
    expect(ids.first, 'padi');
    expect(ids.last, 'other');
    expect(ids.sublist(ids.length - 3, ids.length - 1), ['shared', 'own']);
    expect(ids, isNot(contains('private')));
  });

  test('unknown slug ids display as themselves; UUIDs are flagged unknown', () {
    final slug = CertificationCatalog.builtInOnly.agency('newAgency');
    expect(slug.isFallback, isTrue);
    expect(slug.isSlugFallback, isTrue);
    expect(slug.name, 'newAgency');
    expect(slug.primaryColor, CertificationAgency.other.primaryColor);
    final uuid = CertificationCatalog.builtInOnly.agency(_uuid);
    expect(uuid.isFallback, isTrue);
    expect(uuid.isSlugFallback, isFalse);
    expect(uuid.interchangeName, 'Unknown agency');
    final lvl = CertificationCatalog.builtInOnly.level(_uuid);
    expect(lvl.isFallback, isTrue);
    expect(lvl.interchangeName, 'Unknown certification');
  });

  test('ladder is built-ins then visible custom rungs in sort order', () {
    final c = CertificationCatalog(
      levels: [
        level('r2', 'a', 'padi', name: 'Ice Instructor', order: 1),
        level('r1', 'a', 'padi', name: 'Ice Diver', order: 0),
        level('s1', 'a', 'padi', name: 'Altitude', progression: false),
        level('hidden', 'b', 'padi', name: 'Private'),
      ],
      viewerDiverId: 'a',
    );
    final builtIn = CertificationLevelCatalog.ladderFor(
      CertificationAgency.padi,
    );
    final ladder = c.ladderFor('padi').map((e) => e.id).toList();
    expect(ladder.sublist(0, builtIn.length), builtIn.map((l) => l.name));
    expect(ladder.sublist(builtIn.length), ['r1', 'r2']);
    expect(c.specialtiesFor('padi').map((e) => e.id), contains('s1'));
    expect(ladder, isNot(contains('hidden')));
  });

  test('levels of a custom agency follow the agency visibility', () {
    final c = CertificationCatalog(
      agencies: [agency('ag', 'b', shared: true)],
      levels: [level('l1', 'b', 'ag', shared: false)],
      viewerDiverId: 'a',
    );
    expect(c.ladderFor('ag').map((e) => e.id), ['l1']);
  });

  test('a custom agency has no built-in ladder of its own', () {
    final c = CertificationCatalog(
      agencies: [agency('ag', 'a')],
      levels: [level('l1', 'a', 'ag')],
      viewerDiverId: 'a',
    );
    expect(c.ladderFor('ag').map((e) => e.id), ['l1']);
    expect(c.specialtiesFor('ag'), isEmpty);
  });

  test('levelsFor keeps a stored foreign value before Other', () {
    final ids = CertificationCatalog.builtInOnly
        .levelsFor('dan', ensure: 'openWater')
        .map((e) => e.id)
        .toList();
    expect(ids.last, 'other');
    expect(ids[ids.length - 2], 'openWater');
  });

  test('custom rung outranks built-ins of the same agency', () {
    final c = CertificationCatalog(
      levels: [level('r1', 'a', 'padi')],
      viewerDiverId: 'b',
    );
    expect(
      c.rankOf('padi', 'r1'),
      greaterThan(c.rankOf('padi', 'courseDirector')),
    );
    expect(c.rankOf('padi', null), -1);
    expect(c.rankOf('padi', 'nitrox'), -1);
    expect(c.rankOf('padi', _uuid), -1);
  });

  test('ownership drives canEdit', () {
    final c = CertificationCatalog(
      agencies: [agency('u1', 'a', shared: true)],
      levels: [level('l1', 'b', 'padi')],
      viewerDiverId: 'b',
    );
    expect(c.canEditAgency('u1'), isFalse);
    expect(c.canEditAgency('padi'), isFalse);
    expect(c.canEditLevel('l1'), isTrue);
  });
}
