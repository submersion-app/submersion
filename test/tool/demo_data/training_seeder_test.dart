import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_database.dart';
import '../../../tool/demo_data/src/seeders/diver_seeder.dart';
import '../../../tool/demo_data/src/seeders/places_seeder.dart';
import '../../../tool/demo_data/src/seeders/seed_context.dart';
import '../../../tool/demo_data/src/seeders/training_seeder.dart';
import 'seed_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DemoSeedContext ctx;

  setUpAll(() async {
    ctx = await seedContext();
    await DiverSeeder().seed(ctx);
    await PlacesSeeder().seed(ctx);
    await TrainingSeeder().seed(ctx);
  });

  tearDownAll(tearDownTestDatabase);

  test(
    'every certification has an agency, an issue date and card images',
    () async {
      final rows = await ctx.db
          .customSelect('SELECT agency, issue_date FROM certifications')
          .get();
      expect(rows, hasLength(ctx.plan.certs.length + 1));
      for (final r in rows) {
        expect(r.read<String>('agency'), isNotEmpty);
        expect(r.read<int?>('issue_date'), isNotNull);
      }
      final cards = await ctx.db
          .customSelect(
            "SELECT COUNT(*) AS n FROM documents WHERE type = 'certificationCard'",
          )
          .getSingle();
      expect(cards.read<int>('n'), ctx.plan.certs.length);
      expect(
        await countRows(ctx, 'document_pages'),
        greaterThanOrEqualTo(ctx.plan.certs.length * 2),
      );
    },
  );

  test(
    'each course has its certification and a requirement per kind',
    () async {
      expect(await countRows(ctx, 'courses'), ctx.plan.courses.length);
      expect(
        await countRows(ctx, 'course_requirements'),
        ctx.plan.courses.length * 2,
      );
      expect(ctx.courseDiveRequirements, hasLength(ctx.plan.courses.length));
    },
  );

  test('a custom agency, its level and currency are recorded', () async {
    for (final t in [
      'custom_certification_agencies',
      'custom_certification_levels',
      'certification_currency_events',
      'certification_currency_prefs',
    ]) {
      expect(await countRows(ctx, t), greaterThan(0), reason: t);
    }
  });
}
