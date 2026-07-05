import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/map_style.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_repository_provider.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
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

  test('converting a plan persists a planned dive and links it back', () async {
    final notifier = container.read(divePlanNotifierProvider.notifier);
    notifier.addSimplePlan(maxDepth: 30.0, bottomTimeMinutes: 20);
    notifier.updateName('Convert me');
    final planId = container.read(divePlanNotifierProvider).id;

    // What the page's convert action does: persist toDive(), link, save.
    final dive = notifier.toDive();
    expect(dive.id, isNot(planId));
    expect(dive.isPlanned, isTrue);
    expect(dive.name, 'Convert me');

    final created = await container
        .read(diveRepositoryProvider)
        .createDive(dive);
    notifier.setLinkedDive(created.id);
    await notifier.save();

    // The dive round-trips from the repository as a planned dive.
    final fetched = await container
        .read(diveRepositoryProvider)
        .getDiveById(created.id);
    expect(fetched, isNotNull);
    expect(fetched!.isPlanned, isTrue);
    expect(fetched.tanks, isNotEmpty);

    // The plan aggregate carries the link.
    final savedPlan = await container
        .read(divePlanRepositoryProvider)
        .getPlan(planId);
    expect(savedPlan, isNotNull);
    expect(savedPlan!.linkedDiveId, created.id);
  });

  test('converting twice yields two distinct dives', () async {
    final notifier = container.read(divePlanNotifierProvider.notifier);
    notifier.addSimplePlan(maxDepth: 20.0, bottomTimeMinutes: 15);

    final repository = container.read(diveRepositoryProvider);
    final first = await repository.createDive(notifier.toDive());
    final second = await repository.createDive(notifier.toDive());
    expect(first.id, isNot(second.id));
  });
}
