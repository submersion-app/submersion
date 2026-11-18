import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/data/repositories/annotation_repository.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/annotation_placement_provider.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/annotation_edits.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/dive_detail_annotation_actions.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_annotations_sitting.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

import '../../../../../helpers/mock_providers.dart';
import '../../../../../helpers/test_database.dart';

/// Where the profile's annotation actions write: at once, into a sitting,
/// or nowhere (issue #4527, plan 6).
void main() {
  const diveId = 'd1';
  late AnnotationRepository repo;
  late String storedId;
  late Dive dive;

  setUp(() async {
    await setUpTestDatabase();
    repo = AnnotationRepository();
    await DiveRepository().createDive(
      createTestDiveWithBottomTime(id: diveId, diveNumber: 1),
    );
    storedId = await repo.addAnnotation(
      diveId: diveId,
      timestamp: 300,
      words: 'turtle',
    );
    dive = (await DiveRepository().getDiveById(diveId))!;
  });
  tearDown(tearDownTestDatabase);

  /// Pumps a button that runs [act] with the actions for [dive], and
  /// returns the provider container.
  Future<ProviderContainer> pump(
    WidgetTester tester,
    Future<void> Function(DiveDetailAnnotationActions actions) act, {
    AnnotationEdits? edits,
    bool readOnly = false,
  }) async {
    late ProviderContainer container;
    await tester.pumpWidget(
      ProviderScope(
        overrides: await getBaseOverrides(),
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) {
                container = ProviderScope.containerOf(context);
                final actions = DiveDetailAnnotationActions(
                  ref: ref,
                  context: context,
                  dive: dive,
                  edits: edits,
                  readOnly: readOnly,
                );
                return Center(
                  child: ElevatedButton(
                    onPressed: () => act(actions),
                    child: const Text('go'),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
    return container;
  }

  testWidgets('read only: the pin does not start placing, and a placement '
      'writes nothing', (tester) async {
    final container = await pump(tester, (actions) async {
      await actions.onPinPressed();
      await actions.place(600, null);
    }, readOnly: true);
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();

    expect(container.read(annotationPlacementProvider(diveId)), isNull);
    expect(find.text('What happened'), findsNothing);
    final stored = await tester.runAsync(() => repo.annotationsForDive(diveId));
    expect(stored!.single.timestamp, 300);
  });

  testWidgets('sitting edits: a move reaches the sitting, not the '
      'repository', (tester) async {
    final session = EditSession<Dive>(dive);
    addTearDown(session.dispose);
    final container = await pump(
      tester,
      (actions) => actions.place(900, 18),
      edits: SittingAnnotationEdits(session),
    );
    loadDiveAnnotations(session, container.read);
    await tester.runAsync(session.settled);
    // Placement disposes itself when nothing watches it.
    final placement = container.listen(
      annotationPlacementProvider(diveId),
      (_, _) {},
    );
    addTearDown(placement.close);
    container
        .read(annotationPlacementProvider(diveId).notifier)
        .startMove(storedId);

    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();

    expect(sittingAnnotations(session)!.moved[storedId], (
      timestamp: 900,
      depth: 18.0,
    ));
    final stored = await tester.runAsync(() => repo.annotationsForDive(diveId));
    expect(stored!.single.timestamp, 300);
  });

  test(
    'SittingAnnotationEdits add, move and remove go to the sitting',
    () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final session = EditSession<Dive>(dive);
      addTearDown(session.dispose);
      loadDiveAnnotations(session, container.read);
      await session.settled();
      final edits = SittingAnnotationEdits(session);

      await edits.add(seconds: 600, words: 'manta');
      expect(sittingAnnotations(session)!.placed, hasLength(1));
      await edits.move(storedId, seconds: 700);
      expect(sittingAnnotations(session)!.moved.keys, [storedId]);
      await edits.remove(storedId);
      expect(sittingAnnotations(session)!.removed, {storedId});
      expect(edits.maxSeconds(99), annotationTimeLimits(session).max);
    },
  );
}
