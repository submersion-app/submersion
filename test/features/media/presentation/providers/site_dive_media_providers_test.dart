import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/media/presentation/providers/site_media_providers.dart';

import '../../../../helpers/test_database.dart';

/// The site's dive-photo providers read the media table directly (issue
/// #4252), so they must still refresh when a photo is linked and when a dive
/// joins the site without the media table being written (issue #974).
void main() {
  late AppDatabase db;
  late ProviderContainer container;

  Future<void> site(String id) => db.customStatement(
    'INSERT INTO dive_sites (id, name, created_at, updated_at) '
    'VALUES (?, ?, 0, 0)',
    [id, id],
  );

  Future<void> dive(String id, String? siteId) => db.customStatement(
    'INSERT INTO dives (id, dive_date_time, site_id, created_at, updated_at) '
    'VALUES (?, 0, ?, 0, 0)',
    [id, siteId],
  );

  /// Written through customUpdate so drift sees the write, as the
  /// repositories' own writes are.
  Future<void> media(String id, String diveId) => db.customUpdate(
    'INSERT INTO media (id, dive_id, file_path, file_type, taken_at, '
    'created_at, updated_at) VALUES (?, ?, ?, ?, 1000, 0, 0)',
    variables: [
      Variable.withString(id),
      Variable.withString(diveId),
      Variable.withString('/photos/$id.jpg'),
      Variable.withString('photo'),
    ],
    updates: {db.media},
    updateKind: UpdateKind.insert,
  );

  Future<void> moveDive(String id, String siteId) => db.customUpdate(
    'UPDATE dives SET site_id = ? WHERE id = ?',
    variables: [Variable.withString(siteId), Variable.withString(id)],
    updates: {db.dives},
    // An update, not a delete: without the kind drift treats the write as
    // any kind, and its dives-delete rule would tick the media table too.
    updateKind: UpdateKind.update,
  );

  /// Polls [read] until it returns [expected]; the change ticks are
  /// debounced, so a refresh lands a few hundred milliseconds after a write.
  Future<void> eventually<T>(Future<T> Function() read, T expected) async {
    for (var attempt = 0; attempt < 100; attempt++) {
      // By rendering, so a list compares by its elements.
      if ('${await read()}' == '$expected') return;
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    expect(await read(), expected);
  }

  setUp(() async {
    db = await setUpTestDatabase();
    container = ProviderContainer(retry: (_, _) => null);
    await site('S');
    await site('other');
    await dive('here', 'S');
    await dive('there', 'other');
  });

  tearDown(() async {
    container.dispose();
    await tearDownTestDatabase();
  });

  test('the count refreshes when a dive photo is linked', () async {
    container.listen(mediaCountFromDivesAtSiteProvider('S'), (_, _) {});
    expect(
      await container.read(mediaCountFromDivesAtSiteProvider('S').future),
      0,
    );

    await media('m1', 'here');
    await eventually(
      () => container.read(mediaCountFromDivesAtSiteProvider('S').future),
      1,
    );
  });

  test('the count refreshes when a dive with photos joins the site', () async {
    await media('m1', 'there');
    container.listen(mediaCountFromDivesAtSiteProvider('S'), (_, _) {});
    expect(
      await container.read(mediaCountFromDivesAtSiteProvider('S').future),
      0,
    );

    await moveDive('there', 'S');
    await eventually(
      () => container.read(mediaCountFromDivesAtSiteProvider('S').future),
      1,
    );
  });

  test('the open list refreshes on a link and on a site move', () async {
    await media('m-there', 'there');
    final provider = flatMediaFromDivesAtSiteProvider('S');
    container.listen(provider, (_, _) {});
    Future<List<String>> ids() async =>
        (await container.read(provider.future)).map((m) => m.id).toList();
    expect(await ids(), isEmpty);

    await media('m-here', 'here');
    await eventually(ids, ['m-here']);

    await moveDive('there', 'S');
    await eventually(ids, ['m-here', 'm-there']);
  });
}
