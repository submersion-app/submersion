import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart' hide Dive;
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/annotation_placement_provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_legend_provider.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/dive_detail_annotation_actions.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/forms/minutes_seconds_field.dart';

import '../../../../../helpers/mock_providers.dart';
import '../../../../../helpers/test_database.dart';

/// The actions outlive the widget that made them: a sheet can stay open
/// after the section behind it is rebuilt away (#4109).
void main() {
  const diveId = 'd1';
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
    await DiveRepository().createDive(
      createTestDiveWithBottomTime(id: diveId, diveNumber: 1),
    );
  });
  tearDown(() => tearDownTestDatabase());

  testWidgets('the words typed in an open sheet survive the section behind '
      'it going away', (tester) async {
    final show = ValueNotifier(true);
    addTearDown(show.dispose);
    final dive = createTestDiveWithBottomTime(id: diveId, diveNumber: 1);
    late ProviderContainer container;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ValueListenableBuilder<bool>(
              valueListenable: show,
              builder: (context, visible, _) => visible
                  ? Consumer(
                      builder: (context, ref, _) {
                        container = ProviderScope.containerOf(context);
                        final actions = DiveDetailAnnotationActions(
                          ref: ref,
                          context: context,
                          dive: dive,
                        );
                        return ElevatedButton(
                          onPressed: () => actions.place(60, null),
                          child: const Text('place'),
                        );
                      },
                    )
                  : const SizedBox.shrink(),
            ),
          ),
        ),
      ),
    );
    container.read(annotationPlacementProvider(diveId).notifier).toggleNew();
    await tester.tap(find.text('place'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'What happened'),
      'felt sick',
    );
    show.value = false;
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });

    expect(tester.takeException(), isNull);
    final rows = await tester.runAsync(
      () => (db.select(db.diveProfileEvents)).get(),
    );
    expect(rows!.single.description, 'felt sick');
    expect(container.read(annotationPlacementProvider(diveId)), isNull);
    expect(find.byType(MinutesSecondsField), findsNothing);
  });

  group('the profile on screen', () {
    Future<DiveDetailAnnotationActions> actionsFor(
      WidgetTester tester,
      Dive dive,
    ) async {
      late DiveDetailAnnotationActions actions;
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Consumer(
              builder: (context, ref, _) {
                actions = DiveDetailAnnotationActions(
                  ref: ref,
                  context: context,
                  dive: dive,
                );
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );
      return actions;
    }

    testWidgets('sets the cap when a longer computer is showing', (
      tester,
    ) async {
      final dive = createTestDiveWithBottomTime(id: diveId, diveNumber: 1)
          .copyWith(
            profile: const [
              DiveProfilePoint(timestamp: 0, depth: 0),
              DiveProfilePoint(timestamp: 600, depth: 10),
            ],
          );
      final actions = await actionsFor(tester, dive);

      expect(actions.maxSeconds, 600);
      expect(
        actions.onProfile(const [
          DiveProfilePoint(timestamp: 0, depth: 0),
          DiveProfilePoint(timestamp: 900, depth: 12),
        ]).maxSeconds,
        900,
      );
    });

    testWidgets('leaves the dive\'s own profile when nothing else is drawn', (
      tester,
    ) async {
      final dive = createTestDiveWithBottomTime(id: diveId, diveNumber: 1)
          .copyWith(
            profile: const [
              DiveProfilePoint(timestamp: 0, depth: 0),
              DiveProfilePoint(timestamp: 600, depth: 10),
            ],
          );
      final actions = await actionsFor(tester, dive);

      expect(actions.onProfile(const []).maxSeconds, 600);
    });
  });

  testWidgets('adding one with annotations hidden turns them back on', (
    tester,
  ) async {
    final dive = createTestDiveWithBottomTime(id: diveId, diveNumber: 1);
    late ProviderContainer container;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) {
                container = ProviderScope.containerOf(context);
                ref.watch(profileLegendProvider);
                final actions = DiveDetailAnnotationActions(
                  ref: ref,
                  context: context,
                  dive: dive,
                );
                return ElevatedButton(
                  onPressed: () => actions.addAt(60, null),
                  child: const Text('add'),
                );
              },
            ),
          ),
        ),
      ),
    );
    container.read(profileLegendProvider.notifier).toggleAnnotations();
    await tester.pump();
    expect(container.read(profileLegendProvider).showAnnotations, isFalse);

    await tester.tap(find.text('add'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'What happened'),
      'felt sick',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await tester.pumpAndSettle();

    expect(container.read(profileLegendProvider).showAnnotations, isTrue);
  });
}
