import 'dart:math';

import 'package:submersion/core/database/database.dart';

import '../shape/reshaper.dart';
import '../shape/shape_library.dart';
import '../story/story_plan.dart';

/// What every seeder shares while the demo logbook is written (issue #3708).
///
/// Ids are deterministic (`demo-...`), so the same seed builds the same file
/// and seeders can refer to each other's rows without a lookup.
class DemoSeedContext {
  DemoSeedContext({
    required this.db,
    required this.plan,
    required this.library,
    required this.random,
    required this.photosDir,
    required this.photoFiles,
  }) : reshaper = Reshaper(random);

  final AppDatabase db;
  final StoryPlan plan;
  final ShapeLibrary library;
  final Random random;
  final Reshaper reshaper;

  /// Where the demo photos are while building; the preparer relinks them on
  /// the device.
  final String photosDir;

  /// The photo files in [photosDir], with their credit lines.
  final List<DemoPhoto> photoFiles;

  static const diverId = 'demo-diver';
  static const partnerId = 'demo-partner';

  DateTime get anchor => plan.anchor;

  String diveId(int number) => 'demo-dive-${number.toString().padLeft(4, '0')}';

  String siteId(String catalogId) => 'demo-site-$catalogId';

  String centerId(String catalogId) => 'demo-center-$catalogId';

  String buddyId(String personId) => 'demo-buddy-$personId';

  /// Equipment rows by role, filled by the gear seeder.
  final equipment = <String, String>{};

  /// Equipment sets by key, filled by the gear seeder.
  final equipmentSets = <String, String>{};

  /// Dive computers by key, filled by the gear seeder.
  final computers = <String, String>{};

  /// Each course's dive requirement, filled by the training seeder.
  final courseDiveRequirements = <String, String>{};

  /// Tag ids by name.
  final tags = <String, String>{};

  /// Species ids by common name, after the built-in species are seeded.
  final species = <String, String>{};

  /// Planned dive number to the shape and tank ids it was written with.
  final diveTankIds = <int, List<String>>{};

  double between(double lo, double hi) => lo + random.nextDouble() * (hi - lo);

  T pickOne<T>(List<T> items) => items[random.nextInt(items.length)];
}

class DemoPhoto {
  const DemoPhoto({
    required this.fileName,
    required this.credit,
    required this.subject,
  });

  final String fileName;

  /// Author and licence, shown as the photo's caption credit.
  final String credit;

  /// What the photo shows (a species name, `reef`, `wreck`...), used to put it
  /// on a dive where it belongs.
  final String subject;
}

/// One step of building the demo logbook.
abstract class DemoSeeder {
  String get name;

  Future<void> seed(DemoSeedContext ctx);
}
