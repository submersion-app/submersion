import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_sitting_follow_up.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_annotations_provider.dart';
import 'package:submersion/features/marine_life/presentation/providers/species_providers.dart';
import 'package:submersion/features/media/presentation/providers/media_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/l10n_test_helpers.dart';

/// What a saved sitting owes once its write has committed, for the cards
/// plan 6 brought in (issue #4527).
void main() {
  final before = Dive(id: 'dive-1', dateTime: DateTime.utc(2026));
  final after = before.copyWith(notes: 'saved');

  late ProviderContainer container;
  late List<(String, String?)> adopted;
  late Map<String, int> builds;

  setUp(() {
    adopted = [];
    builds = {};
    int count(String name) => builds[name] = (builds[name] ?? 0) + 1;
    container = ProviderContainer(
      overrides: [
        unitFormatterProvider.overrideWithValue(
          const UnitFormatter(AppSettings()),
        ),
        diveGearRefreshProvider.overrideWithValue((_) {}),
        divePlanLinkAdoptProvider.overrideWithValue(
          (planId, diveId) => adopted.add((planId, diveId)),
        ),
        diveAnnotationsProvider.overrideWith((ref, id) async {
          count('annotations');
          return const [];
        }),
        diveSightingsProvider.overrideWith((ref, id) async {
          count('sightings');
          return const [];
        }),
        mediaForDiveProvider.overrideWith((ref, id) async {
          count('media');
          return const [];
        }),
      ],
    );
    addTearDown(container.dispose);
    for (final p in [
      diveAnnotationsProvider(before.id),
      diveSightingsProvider(before.id),
      mediaForDiveProvider(before.id),
    ]) {
      container.listen(p, (_, _) {}, fireImmediately: true);
    }
  });

  Future<DiveSittingFollowUp> followUp(WidgetTester tester) async {
    late DiveSittingFollowUp made;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: localizedMaterialApp(
          locale: const Locale('en'),
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) {
                made = DiveSittingFollowUp.read(context, ref);
                return const SizedBox();
              },
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    return made;
  }

  Future<void> run(
    WidgetTester tester,
    DiveSittingFollowUp f, {
    required Set<String> changed,
    List<Future<void> Function()> mediaAfterCommit = const [],
    List<(String, String?)> planLinksAdopted = const [],
  }) async {
    await f.run(
      before: before,
      after: after,
      tripDateStretches: const [],
      changedCardIds: changed,
      mediaAfterCommit: mediaAfterCommit,
      planLinksAdopted: planLinksAdopted,
    );
    await tester.pump();
  }

  testWidgets('a media upload queue that throws after the write is not a '
      'failed save; the rest still run', (tester) async {
    final f = await followUp(tester);
    final ran = <int>[];
    await run(
      tester,
      f,
      changed: {'media'},
      mediaAfterCommit: [
        () async => throw StateError('queue closed'),
        () async => ran.add(2),
      ],
    );
    expect(ran, [2]);
    expect(builds['media'], 2);
  });

  testWidgets("each card's providers are invalidated only when it changed", (
    tester,
  ) async {
    final f = await followUp(tester);
    await run(tester, f, changed: {'sightings'});
    expect(builds['sightings'], 2);
    expect(builds['annotations'], 1);
    expect(builds['media'], 1);

    await run(tester, f, changed: {'notes'});
    expect(builds['annotations'], 2);
    expect(builds['sightings'], 2);
  });

  testWidgets('the plan link is adopted after a Compare change', (
    tester,
  ) async {
    final f = await followUp(tester);
    await run(
      tester,
      f,
      changed: {'diveLab'},
      planLinksAdopted: const [('plan-1', 'dive-1'), ('plan-0', null)],
    );
    expect(adopted, [('plan-1', 'dive-1'), ('plan-0', null)]);

    adopted.clear();
    await run(
      tester,
      f,
      changed: {'notes'},
      planLinksAdopted: const [('plan-1', 'dive-1')],
    );
    expect(adopted, isEmpty);
  });
}
