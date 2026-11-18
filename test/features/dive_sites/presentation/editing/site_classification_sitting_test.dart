import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_classification_repository.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/editing/site_classification_sitting.dart';
import 'package:submersion/features/dive_sites/presentation/editing/site_plain_fields.dart';
import 'package:submersion/features/dive_sites/presentation/editing/site_sitting_start.dart';
import 'package:submersion/features/site_types/domain/entities/site_type_entity.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

import '../../../../helpers/test_database.dart';

/// A site's types and tags are held in the sitting and written at Save as
/// the difference from what the sitting loaded (issue #4527, phase 2).
void main() {
  late SiteClassificationRepository repository;
  const site = DiveSite(id: 's1', name: 'A');

  setUp(() async {
    await setUpTestDatabase();
    repository = SiteClassificationRepository();
    final db = DatabaseService.instance.database;
    await db.customStatement(
      "INSERT INTO dive_sites (id, name, created_at, updated_at) "
      "VALUES ('s1', 'A', 0, 0)",
    );
    await db.customStatement(
      "INSERT INTO tags (id, name, created_at, updated_at, "
      "applies_to_dives, applies_to_sites) "
      "VALUES ('t1', 'To try', 0, 0, 0, 1), ('t2', 'Avoid', 0, 0, 0, 1), "
      "('t3', 'Busy', 0, 0, 0, 1), ('t4', 'Calm', 0, 0, 0, 1)",
    );
  });

  tearDown(tearDownTestDatabase);

  final at = DateTime.utc(2026);
  // Only the ids are written; the rest is what a picker would hand over.
  SiteTypeEntity type(String id) =>
      SiteTypeEntity(id: id, name: id, createdAt: at, updatedAt: at);
  Tag tag(String id) => Tag(id: id, name: id, createdAt: at, updatedAt: at);

  Future<EditSession<DiveSite>> loaded() async {
    final session = EditSession<DiveSite>(site);
    addTearDown(session.dispose);
    await siteTypesList.load(session);
    await siteTagsList.load(session);
    return session;
  }

  test('types write only the difference', () async {
    await repository.replaceTypes('s1', ['wreck', 'lake']);
    final session = await loaded();
    siteTypesList.set(session, [type('lake'), type('reef')]);
    // Stored underneath meanwhile: a sync adds a type.
    await repository.replaceTypes('s1', ['wreck', 'lake', 'cave']);

    await session.runHeldWrites();

    final after = await repository.getTypesForSite('s1');
    expect(after.map((t) => t.id).toSet(), {'lake', 'cave', 'reef'});
  });

  test('tags write only the difference', () async {
    await repository.replaceTags('s1', ['t1', 't2']);
    final session = await loaded();
    siteTagsList.set(session, [tag('t2'), tag('t3')]);
    // Stored underneath meanwhile: a sync puts a tag on.
    await repository.replaceTags('s1', ['t1', 't2', 't4']);

    await session.runHeldWrites();

    final after = await repository.getTagsForSite('s1');
    expect(after.map((t) => t.id).toSet(), {'t2', 't3', 't4'});
  });

  test('a change dots its card', () async {
    final session = await loaded();
    siteTypesList.set(session, [type('reef')]);

    expect(session.changedCardIds, {siteHeaderCardId});
  });

  test('writing notes the library field', () async {
    final session = await loaded();
    siteTypesList.set(session, [type('reef')]);

    await session.runHeldWrites();

    expect(siteLibraryFields(session), {'siteTypes'});
  });

  test('a write that changes nothing names no library field', () async {
    await repository.replaceTags('s1', ['t1']);
    final session = await loaded();
    siteTagsList.set(session, [tag('t1'), tag('t2')]);
    // Stored underneath meanwhile: the same tag, by another member.
    await repository.replaceTags('s1', ['t1', 't2']);

    await session.runHeldWrites();

    // A fresh clock on an unchanged list would beat that member's edit.
    expect(siteLibraryFields(session), isEmpty);
  });
}
