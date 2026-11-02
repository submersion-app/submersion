import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart' hide Dive;
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/presentation/providers/annotation_placement_provider.dart';
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
}
