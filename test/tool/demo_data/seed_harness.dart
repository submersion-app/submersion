import 'dart:io';
import 'dart:math';

import 'package:path/path.dart' as p;

import '../../helpers/test_database.dart';
import '../../../tool/demo_data/src/seeders/seed_context.dart';
import '../../../tool/demo_data/src/shape/shape_library.dart';
import '../../../tool/demo_data/src/story/catalog.dart';
import '../../../tool/demo_data/src/story/story_planner.dart';
import 'synthetic_shapes.dart';

final _catalog = Catalog.load('assets/data');

final testPhotos = [
  const DemoPhoto(
    fileName: 'reef.jpg',
    credit: 'Test Author, CC0',
    subject: 'reef',
  ),
  const DemoPhoto(
    fileName: 'turtle.jpg',
    credit: 'Test Author, CC0',
    subject: 'Green Sea Turtle',
  ),
  const DemoPhoto(
    fileName: 'wreck.jpg',
    credit: 'Test Author, CC0',
    subject: 'wreck',
  ),
  // Enough of one subject that they must spread over several dives.
  for (var i = 2; i <= 8; i++)
    DemoPhoto(
      fileName: 'turtle-$i.jpg',
      credit: 'Test Author, CC0',
      subject: 'Green Sea Turtle',
    ),
  for (var i = 2; i <= 5; i++)
    DemoPhoto(
      fileName: 'reef-$i.jpg',
      credit: 'Test Author, CC0',
      subject: 'reef',
    ),
];

/// A seed context over a fresh in-memory database (set as the app's open
/// database), the real story plan from the bundled catalogues, synthetic
/// shapes and placeholder photo files. Pair with tearDownTestDatabase().
Future<DemoSeedContext> seedContext({int seed = 42}) async {
  final db = await setUpTestDatabase();
  final dir = Directory.systemTemp.createTempSync('demo_photos');
  for (final photo in testPhotos) {
    File(p.join(dir.path, photo.fileName)).writeAsBytesSync([0xFF, 0xD8, 0xFF]);
  }
  return DemoSeedContext(
    db: db,
    plan: StoryPlanner(
      Random(seed),
      _catalog,
    ).plan(anchor: DateTime(2026, 10, 1)),
    library: ShapeLibrary(syntheticShapes(), Random(seed)),
    random: Random(seed),
    photosDir: dir.path,
    photoFiles: testPhotos,
  );
}

Future<int> countRows(DemoSeedContext ctx, String table) async =>
    (await ctx.db
            .customSelect('SELECT COUNT(*) AS n FROM "$table"')
            .getSingle())
        .read<int>('n');
