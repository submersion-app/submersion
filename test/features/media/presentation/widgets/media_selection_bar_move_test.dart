import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/dive_search.dart';
import 'package:submersion/core/models/log_entry.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_picker_row.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_summary.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_repository_provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/open_dive_sitting_provider.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/presentation/providers/media_providers.dart';
import 'package:submersion/features/media/presentation/widgets/media_selection_bar.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/selection/selection_controller.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

class _RecordingMediaRepo implements MediaRepository {
  (List<String>, String)? reassigned;

  /// When set, the move throws instead of recording.
  Object? reassignError;

  @override
  Future<void> reassignMediaToDive(
    List<String> mediaIds,
    String newDiveId,
  ) async {
    final error = reassignError;
    if (error != null) throw error;
    reassigned = (mediaIds, newDiveId);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeDiveRepo implements DiveRepository {
  @override
  Future<List<DivePickerRow>> getDivePickerRows({
    String? diverId,
    String query = '',
    DiveSummaryCursor? cursor,
    int limit = kDivePickerPageSize,
  }) async => [
    DivePickerRow(
      id: 'dive-2',
      diveNumber: 2,
      siteName: 'Blue Hole',
      dateTime: DateTime.utc(2026, 6, 12),
      sortTimestamp: DateTime.utc(2026, 6, 12).millisecondsSinceEpoch,
    ),
  ];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

MediaItem _item(String id, {String? diveId}) => MediaItem(
  id: id,
  diveId: diveId,
  mediaType: MediaType.photo,
  sourceType: MediaSourceType.platformGallery,
  takenAt: DateTime(2026),
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

/// The library's Move to dive asks first, naming the count and the dive, and
/// refuses a dive that is open for editing (issue #4527, media library
/// plan 1).
void main() {
  setUp(setUpTestDatabase);
  tearDown(tearDownTestDatabase);

  late _RecordingMediaRepo repo;
  late SelectionController controller;

  /// [openDive] names the dive whose page is unlocked, if any.
  Future<void> pump(
    WidgetTester tester, {
    String? openDive,
    List<MediaItem>? items,
    Locale locale = const Locale('en'),
  }) async {
    final selected =
        items ??
        [_item('a', diveId: 'd1'), _item('b', diveId: 'd1'), _item('c')];
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    repo = _RecordingMediaRepo();
    controller = SelectionController()..enterExplicit();
    for (final item in selected) {
      controller.toggle(item.id);
    }
    addTearDown(controller.dispose);
    final session = EditSession<Dive>(
      Dive(id: openDive ?? 'none', dateTime: DateTime.utc(2026)),
    );
    addTearDown(session.dispose);
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...overrides.cast<Override>(),
          mediaRepositoryProvider.overrideWithValue(repo),
          diveRepositoryProvider.overrideWithValue(_FakeDiveRepo()),
          validatedCurrentDiverIdProvider.overrideWith((ref) async => 'me'),
          if (openDive != null)
            openDiveSittingProvider.overrideWith(
              (ref) => OpenDiveSitting(
                diveId: openDive,
                session: session,
                showMediaCard: () {},
              ),
            ),
        ],
        child: MaterialApp(
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            appBar: PreferredSize(
              preferredSize: const Size.fromHeight(56),
              child: MediaSelectionBar(
                controller: controller,
                selectableIds: [for (final item in selected) item.id],
                selectedItems: selected,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> pickDive(WidgetTester tester) async {
    await tester.tap(
      find.byKey(const ValueKey('selection_action_move_to_dive')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('#2'));
    await tester.pumpAndSettle();
  }

  final confirm = find.byKey(const ValueKey('move_to_dive_confirm'));
  Finder dialogButton(String label) => find.descendant(
    of: confirm,
    matching: find.widgetWithText(TextButton, label),
  );
  const hint =
      'A dive in this move is open for editing. Save, cancel or lock it, '
      'then try again.';

  testWidgets('picking a dive asks, naming the count and the dive', (
    tester,
  ) async {
    await pump(tester);
    await pickDive(tester);

    expect(confirm, findsOneWidget);
    expect(find.text('Move 3 items?'), findsOneWidget);
    expect(
      find.descendant(of: confirm, matching: find.textContaining('#2')),
      findsOneWidget,
    );
    expect(repo.reassigned, isNull);
  });

  testWidgets('one item is spoken of as one, on no dive or on one', (
    tester,
  ) async {
    await pump(tester, items: [_item('c')]);
    await pickDive(tester);

    expect(find.text('Move 1 item?'), findsOneWidget);
    expect(
      find.descendant(
        of: confirm,
        matching: find.textContaining('The item moves to #2 Blue Hole'),
      ),
      findsOneWidget,
    );
    expect(find.textContaining('They move'), findsNothing);
  });

  // Code review on PR #4948: items already on the picked dive do not move.
  testWidgets('items already on the picked dive are left out of the move', (
    tester,
  ) async {
    await pump(
      tester,
      items: [
        _item('a', diveId: 'dive-2'),
        _item('b', diveId: 'd1'),
      ],
    );
    await pickDive(tester);

    expect(find.text('Move 1 item?'), findsOneWidget);
    await tester.tap(dialogButton('Move'));
    await tester.pumpAndSettle();

    expect(repo.reassigned?.$1, ['b']);
  });

  testWidgets('a move with every item already there writes nothing', (
    tester,
  ) async {
    await pump(tester, items: [_item('a', diveId: 'dive-2')]);
    await pickDive(tester);

    expect(confirm, findsNothing);
    expect(repo.reassigned, isNull);
    expect(controller.value.isActive, isFalse);
  });

  testWidgets('the dive is named with the language\'s own separator', (
    tester,
  ) async {
    await pump(tester, locale: const Locale('ja'));
    await tester.tap(
      find.byKey(const ValueKey('selection_action_move_to_dive')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('#2'));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: confirm,
        matching: find.textContaining('#2 Blue Hole\u3001'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('Cancel writes nothing and keeps the selection', (tester) async {
    await pump(tester);
    await pickDive(tester);
    await tester.tap(dialogButton('Cancel'));
    await tester.pumpAndSettle();

    expect(repo.reassigned, isNull);
    expect(controller.value.checkedIds, {'a', 'b', 'c'});
  });

  testWidgets('Move writes and ends the mode', (tester) async {
    await pump(tester);
    await pickDive(tester);
    await tester.tap(dialogButton('Move'));
    await tester.pumpAndSettle();

    expect(repo.reassigned?.$1, ['a', 'b', 'c']);
    expect(repo.reassigned?.$2, 'dive-2');
    expect(controller.value.isActive, isFalse);
  });

  testWidgets('a dive open for editing with no changes is refused', (
    tester,
  ) async {
    await pump(tester, openDive: 'dive-2');
    await pickDive(tester);

    expect(find.text(hint), findsOneWidget);
    expect(confirm, findsNothing);
    expect(repo.reassigned, isNull);
    expect(controller.value.checkedIds, {'a', 'b', 'c'});
  });

  testWidgets('the dive the items are on, open, is refused', (tester) async {
    await pump(tester, openDive: 'd1');
    await pickDive(tester);

    expect(find.text(hint), findsOneWidget);
    expect(repo.reassigned, isNull);
  });

  testWidgets('a locked dive is moved to', (tester) async {
    await pump(tester, openDive: 'd9');
    await pickDive(tester);
    await tester.tap(dialogButton('Move'));
    await tester.pumpAndSettle();

    expect(repo.reassigned?.$1, ['a', 'b', 'c']);
    expect(repo.reassigned?.$2, 'dive-2');
  });

  testWidgets('a dive opened while the confirmation is up is refused', (
    tester,
  ) async {
    await pump(tester);
    await pickDive(tester);
    final session = EditSession<Dive>(
      Dive(id: 'dive-2', dateTime: DateTime.utc(2026)),
    );
    addTearDown(session.dispose);
    ProviderScope.containerOf(
      tester.element(find.byType(MediaSelectionBar)),
    ).read(openDiveSittingProvider.notifier).state = OpenDiveSitting(
      diveId: 'dive-2',
      session: session,
      showMediaCard: () {},
    );
    await tester.tap(dialogButton('Move'));
    await tester.pumpAndSettle();

    expect(find.text(hint), findsOneWidget);
    expect(repo.reassigned, isNull);
    expect(controller.value.checkedIds, {'a', 'b', 'c'});
  });

  testWidgets('a move that fails says so and keeps the selection', (
    tester,
  ) async {
    await pump(tester);
    repo.reassignError = StateError('disk full');
    await pickDive(tester);
    await tester.tap(dialogButton('Move'));
    await tester.pumpAndSettle();

    expect(find.text('Could not move the items'), findsOneWidget);
    expect(controller.value.checkedIds, {'a', 'b', 'c'});
  });

  testWidgets('a move that fails is logged with its cause', (tester) async {
    final logged = <LogEntry>[];
    final subscription = LoggerService.logStream.listen(logged.add);
    addTearDown(subscription.cancel);
    await pump(tester);
    repo.reassignError = StateError('disk full');
    await pickDive(tester);
    await tester.tap(dialogButton('Move'));
    await tester.pumpAndSettle();

    expect(
      logged.where(
        (e) => e.level == LogLevel.error && e.message.contains('Move to dive'),
      ),
      isNotEmpty,
    );
  });
}
