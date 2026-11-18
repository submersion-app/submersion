import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/dive_detail_sections.dart';
import 'package:submersion/features/dive_import/presentation/providers/dive_resync_providers.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_data_source.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/data_sources_section.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';
import 'package:submersion/features/pre_dive/data/repositories/pre_dive_session_repository.dart';
import 'package:submersion/features/pre_dive/domain/entities/pre_dive_session.dart';
import 'package:submersion/features/pre_dive/presentation/providers/pre_dive_providers.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_controller.dart';

import '../../../../helpers/test_database.dart';
import 'dive_detail_page_unlock_harness.dart';

/// Whole-record operations on the dive page end to end (issue #4527, plan
/// 7): nothing writes while locked, and after one the sitting starts again
/// from the dive as stored, clean.
class _Repo extends Fake implements DiveRepository {
  FakeSave? save;
  final calls = <String>[];

  @override
  Future<String> convertPlanToActualDive(
    String planId, {
    DateTime? actualDateTime,
  }) async {
    calls.add('promote');
    return planId;
  }

  @override
  Future<void> setPrimaryDataSource({
    required String diveId,
    required String computerReadingId,
  }) async => calls.add('primary');
}

class _PreDiveRepo extends Fake implements PreDiveSessionRepository {
  _PreDiveRepo(this.onUnlink);

  final void Function() onUnlink;
  final unlinked = <String>[];

  @override
  Future<void> unlinkFromDive(String sessionId) async {
    unlinked.add(sessionId);
    onUnlink();
  }
}

class _SpyList extends PaginatedDiveListNotifier {
  _SpyList(super.repository, super.ref);

  final deleted = <String>[];

  @override
  Future<void> deleteDive(String id) async => deleted.add(id);
}

final _now = DateTime(2023, 1, 1, 12);

final _sources = [
  DiveDataSource(
    id: 'src-a',
    diveId: dive.id,
    computerId: 'dc-a',
    isPrimary: true,
    computerName: 'Perdix',
    importedAt: _now,
    createdAt: _now,
  ),
  DiveDataSource(
    id: 'src-b',
    diveId: dive.id,
    computerId: 'dc-b',
    isPrimary: false,
    computerName: 'Teric',
    importedAt: _now,
    createdAt: _now,
  ),
];

final _linked = PreDiveSession(
  id: 'pre-1',
  templateName: 'Boat',
  diveId: dive.id,
  startedAt: DateTime(2023, 1, 1, 8),
  createdAt: DateTime(2023, 1, 1, 8),
  updatedAt: DateTime(2023, 1, 1, 8),
);

RecordEditController<Dive> _controller(WidgetTester tester) => tester
    .widget<RecordEditScope<Dive>>(
      find.byWidgetPredicate((w) => w is RecordEditScope<Dive>).first,
    )
    .notifier!;

Future<void> _openPageMenu(WidgetTester tester) async {
  final menus = find.byWidgetPredicate((w) => w is PopupMenuButton<String>);
  await tester.tap(menus.last);
  await settle(tester);
}

void main() {
  setUp(setUpTestDatabase);
  tearDown(tearDownTestDatabase);

  late _Repo repo;
  late _PreDiveRepo preDive;
  _SpyList? list;

  Future<FakeSave> pump(
    WidgetTester tester, {
    Dive? stored,
    Dive Function(Dive stored)? afterUnlink,
    Set<DiveDetailSectionId> visible = const {
      DiveDetailSectionId.notes,
      DiveDetailSectionId.dataSources,
    },
  }) async {
    repo = _Repo();
    list = null;
    late FakeSave save;
    preDive = _PreDiveRepo(
      // The unlink lands as a change to the stored dive, so the fresh
      // sitting can be seen reading it.
      () => save.stored =
          afterUnlink?.call(save.stored) ??
          save.stored.copyWith(notes: 'After the operation'),
    );
    final page = await pumpPage(
      tester,
      stored: stored,
      sources: _sources,
      visible: visible,
      size: const Size(700, 1600),
      extra: [
        diveRepositoryProvider.overrideWithValue(repo),
        preDiveSessionRepositoryProvider.overrideWithValue(preDive),
        preDiveSessionForDiveProvider(
          dive.id,
        ).overrideWith((ref) async => _linked),
        diveHasImportedFileProvider(dive.id).overrideWith((ref) async => true),
        paginatedDiveListProvider.overrideWith(
          (ref) => list = _SpyList(ref.watch(diveRepositoryProvider), ref),
        ),
      ],
    );
    save = page.save;
    repo.save = save;
    return save;
  }

  testWidgets('locked: no tap on any operation writes', (tester) async {
    await pump(tester, stored: dive.copyWith(isPlanned: true));

    // The banner.
    await tester.tap(
      find.widgetWithText(TextButton, 'Mark as logged'),
      warnIfMissed: false,
    );
    await settle(tester);

    // Every operation in the page's menu.
    for (final label in [
      'Mark as logged',
      'Unlink pre-dive checklist',
      'Resync from original file',
      'Delete',
    ]) {
      await _openPageMenu(tester);
      await tester.tap(find.text(label).last, warnIfMissed: false);
      await settle(tester);
      // A disabled item leaves the menu open: close it.
      if (find.text('Unlock to use these').evaluate().isNotEmpty) {
        await tester.tapAt(const Offset(5, 500));
        await settle(tester);
      }
    }

    // The Data sources card's own menu.
    final sourceMenu = find
        .descendant(
          of: find.byType(DataSourcesSection),
          matching: find.byIcon(Icons.more_vert),
        )
        .last;
    await tester.ensureVisible(sourceMenu);
    await settle(tester);
    await tester.tap(sourceMenu);
    await settle(tester);
    await tester.tap(find.text('Set as primary'), warnIfMissed: false);
    await settle(tester);

    expect(repo.calls, isEmpty);
    expect(preDive.unlinked, isEmpty);
    // Never even read: nothing reached the delete.
    expect(list?.deleted ?? const <String>[], isEmpty);
    expect(find.text('Discard changes?'), findsNothing);
  });

  testWidgets('an operation under an open, unchanged Notes editor: the '
      'editor closes and nothing jumps', (tester) async {
    await pump(tester);
    await unlock(tester);
    await openNotes(tester);
    final notesCard = find.byKey(const ValueKey('diveSection_notes'));
    final top = tester.getTopLeft(notesCard).dy;
    expect(_controller(tester).openCardIds, contains('notes'));

    await _openPageMenu(tester);
    await tester.tap(find.text('Unlink pre-dive checklist'));
    await settle(tester);
    await settle(tester);

    expect(preDive.unlinked, ['pre-1']);
    final controller = _controller(tester);
    expect(controller.isUnlocked, isTrue);
    expect(controller.openCardIds, isEmpty);
    expect(controller.isDirty, isFalse);
    expect(tester.getTopLeft(notesCard).dy, top);
  });

  testWidgets('after an operation the cards show the dive as stored now, and '
      'Cancel writes nothing', (tester) async {
    final save = await pump(tester);
    await unlock(tester);

    await _openPageMenu(tester);
    await tester.tap(find.text('Unlink pre-dive checklist'));
    await settle(tester);
    await settle(tester);

    expect(find.text('After the operation'), findsOneWidget);
    expect(action(tester, 'Save').onPressed, isNull);
    await tester.tap(find.text('Cancel'));
    await settle(tester);
    expect(save.calls, isEmpty);
    expect(find.byTooltip('Unlock to edit'), findsOneWidget);
  });

  // Review Focus 2: the fresh sitting offers again what the operation
  // emptied, as the strip is worked out from the dive as stored now.
  testWidgets('a card an operation emptied is offered on the strip again', (
    tester,
  ) async {
    final night = Tag(
      id: 'night',
      name: 'Night',
      createdAt: DateTime(2024),
      updatedAt: DateTime(2024),
    );
    await pump(
      tester,
      stored: dive.copyWith(tags: [night]),
      afterUnlink: (stored) => stored.copyWith(tags: const []),
      visible: const {
        DiveDetailSectionId.tags,
        DiveDetailSectionId.notes,
        DiveDetailSectionId.dataSources,
      },
    );
    await unlock(tester);
    final tagsChip = find.byKey(
      ValueKey('addStrip_${DiveDetailSectionId.tags.name}'),
    );
    expect(tagsChip, findsNothing);

    await _openPageMenu(tester);
    await tester.tap(find.text('Unlink pre-dive checklist'));
    await settle(tester);
    await settle(tester);

    expect(_controller(tester).isUnlocked, isTrue);
    expect(tagsChip, findsOneWidget);
  });
}
