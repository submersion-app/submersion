import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/features/courses/domain/models/course_filter_state.dart';
import 'package:submersion/features/courses/presentation/providers/course_query_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late ProviderContainer container;
  const now = 1735689600000;

  setUp(() async {
    db = await setUpTestDatabase();
    Future<void> sql(String s) => db.customStatement(s);
    await sql(
      'INSERT INTO divers (id, name, created_at, updated_at) '
      "VALUES ('me', 'Me', $now, $now)",
    );
    await sql(
      'INSERT INTO courses (id, diver_id, name, agency, start_date, '
      'completion_date, created_at, updated_at) VALUES '
      "('ow', 'me', 'OW', 'padi', $now, $now, $now, $now), "
      "('aow', 'me', 'AOW', 'padi', $now, NULL, $now, $now), "
      "('tec', 'me', 'Tec', 'tdi', $now, $now, $now, $now)",
    );
    SharedPreferences.setMockInitialValues({currentDiverIdKey: 'me'});
    final prefs = await SharedPreferences.getInstance();
    container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
  });
  tearDown(() async {
    container.dispose();
    await tearDownTestDatabase();
  });

  Future<Set<String>> visible() async {
    final sub = container.listen(filteredCoursesProvider, (_, _) {});
    addTearDown(sub.close);
    for (var i = 0; i < 200; i++) {
      final v = container.read(filteredCoursesProvider);
      if (v.hasError) throw v.error!;
      if (v.hasValue && !v.isLoading) return {for (final c in v.value!) c.id};
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    fail('the course list never settled');
  }

  test('status and query compose', () async {
    expect(await visible(), {'ow', 'aow', 'tec'});
    final state = container.read(courseFilterProvider.notifier);
    state.state = const CourseFilterState(
      status: CourseStatusFilter.inProgress,
    );
    expect(await visible(), {'aow'});
    state.state = CourseFilterState(
      status: CourseStatusFilter.completed,
      query: ConditionNode(
        FieldPath(['agency']),
        QueryOp.eq,
        const EnumValue('padi'),
      ),
    );
    expect(await visible(), {'ow'});
  });
}
