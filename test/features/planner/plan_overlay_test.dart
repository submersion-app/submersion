import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/map_style.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_repository_provider.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/features/planner/presentation/providers/plan_overlay_provider.dart';
import 'package:submersion/features/planner/presentation/providers/plan_repository_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../helpers/test_database.dart';

class _TestSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _TestSettingsNotifier() : super(const AppSettings());

  @override
  Future<void> setMapStyle(MapStyle style) async =>
      state = state.copyWith(mapStyle: style);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late ProviderContainer container;

  setUp(() async {
    await setUpTestDatabase();
    container = ProviderContainer(
      overrides: [
        settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
      ],
    );
    addTearDown(container.dispose);
  });

  tearDown(() {
    DatabaseService.instance.resetForTesting();
  });

  test(
    'overlay resolves for a converted dive and maps the full profile',
    () async {
      final notifier = container.read(divePlanNotifierProvider.notifier);
      notifier.addSimplePlan(maxDepth: 45.0, bottomTimeMinutes: 25);
      notifier.updateName('Deco plan');

      final created = await container
          .read(diveRepositoryProvider)
          .createDive(notifier.toDive());
      notifier.setLinkedDive(created.id);
      await notifier.save();

      final overlay = await container.read(
        plannedProfileOverlayProvider(created.id).future,
      );
      expect(overlay, isNotNull);
      expect(overlay!.name, 'Deco plan');
      expect(overlay.sourceId, startsWith('plan:'));
      // The overlay carries the full computed schedule: it descends to the
      // planned bottom and ends back at the surface.
      final depths = overlay.points.map((p) => p.depth);
      expect(depths.reduce((a, b) => a > b ? a : b), closeTo(45.0, 0.01));
      expect(overlay.points.last.depth, 0.0);
      // A 45 m / 25 min air plan carries deco, so the profile runs longer
      // than the bottom segments alone.
      expect(overlay.points.last.timestamp, greaterThan(25 * 60));
    },
  );

  test('overlay is null for a dive with no linked plan', () async {
    final repository = container.read(divePlanRepositoryProvider);
    expect(await repository.getPlanByLinkedDiveId('no-such-dive'), isNull);

    final overlay = await container.read(
      plannedProfileOverlayProvider('no-such-dive').future,
    );
    expect(overlay, isNull);
  });
}
