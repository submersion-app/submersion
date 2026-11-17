import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/dive_detail_sections.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_data_source.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/data_sources_section.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_controller.dart';

import '../../../../helpers/test_database.dart';
import 'dive_detail_page_unlock_harness.dart';

/// Stands in for the repository's whole-record writes the page makes.
class _Repo extends Fake implements DiveRepository {
  /// Set once the page is pumped: the fake whose dive the page reads.
  FakeSave? save;
  final promoted = <String>[];
  final primaries = <String>[];

  @override
  Future<void> setPrimaryDataSource({
    required String diveId,
    required String computerReadingId,
  }) async => primaries.add(computerReadingId);

  @override
  Future<String> convertPlanToActualDive(
    String planId, {
    DateTime? actualDateTime,
  }) async {
    promoted.add(planId);
    final save = this.save!;
    save.stored = save.stored.copyWith(isPlanned: false, diveNumber: 7);
    return planId;
  }
}

RecordEditController<Dive> _controller(WidgetTester tester) {
  final scope = tester.widget<RecordEditScope<Dive>>(
    find.byWidgetPredicate((w) => w is RecordEditScope<Dive>).first,
  );
  return scope.notifier!;
}

final _now = DateTime(2023, 1, 1, 12);

final _twoSources = [
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

void main() {
  setUp(setUpTestDatabase);
  tearDown(tearDownTestDatabase);

  testWidgets(
    'a planned dive marked as logged from its banner reads the dive again',
    (tester) async {
      final planned = dive.copyWith(isPlanned: true);
      final repo = _Repo();
      final page = await pumpPage(
        tester,
        stored: planned,
        extra: [diveRepositoryProvider.overrideWithValue(repo)],
      );
      repo.save = page.save;
      await unlock(tester);
      final before = _controller(tester).session;

      await tester.tap(find.widgetWithText(TextButton, 'Mark as logged'));
      await settle(tester);
      await settle(tester);

      expect(repo.promoted, [dive.id]);
      final controller = _controller(tester);
      expect(controller.isUnlocked, isTrue);
      expect(controller.isDirty, isFalse);
      expect(controller.session, isNot(same(before)));
      expect(controller.session!.stored.isPlanned, isFalse);
      expect(controller.session!.stored.diveNumber, 7);
      expect(action(tester, 'Save').onPressed, isNull);
    },
  );

  testWidgets('a refused confirmation leaves the sitting as it was', (
    tester,
  ) async {
    await pumpPage(
      tester,
      sources: _twoSources,
      visible: const {
        DiveDetailSectionId.notes,
        DiveDetailSectionId.dataSources,
      },
    );
    await unlock(tester);
    final before = _controller(tester).session;

    final sourceMenu = find
        .descendant(
          of: find.byType(DataSourcesSection),
          matching: find.byIcon(Icons.more_vert),
        )
        .last;
    await tester.ensureVisible(sourceMenu);
    await tester.tap(sourceMenu);
    await settle(tester);
    await tester.tap(find.text('Split into separate dive'));
    await settle(tester);
    await tester.tap(find.text('Cancel').last);
    await settle(tester);

    final controller = _controller(tester);
    expect(controller.session, same(before));
    expect(controller.isOperating, isFalse);
  });
  Future<void> openSourceMenu(WidgetTester tester) async {
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
  }

  testWidgets('locked: the Data sources card writes nothing', (tester) async {
    final repo = _Repo();
    final page = await pumpPage(
      tester,
      sources: _twoSources,
      visible: const {DiveDetailSectionId.dataSources},
      extra: [diveRepositoryProvider.overrideWithValue(repo)],
    );
    repo.save = page.save;

    await openSourceMenu(tester);
    expect(find.text('Unlock to use these'), findsOneWidget);
    await tester.tap(find.text('Set as primary'), warnIfMissed: false);
    await settle(tester);

    expect(repo.primaries, isEmpty);
  });

  testWidgets('unlocked and clean, Set as primary from the card runs and the '
      'sitting starts again', (tester) async {
    final repo = _Repo();
    final page = await pumpPage(
      tester,
      sources: _twoSources,
      visible: const {DiveDetailSectionId.dataSources},
      extra: [diveRepositoryProvider.overrideWithValue(repo)],
    );
    repo.save = page.save;
    await unlock(tester);
    final before = _controller(tester).session;

    await openSourceMenu(tester);
    await tester.tap(find.text('Set as primary'));
    await settle(tester);
    await settle(tester);

    expect(repo.primaries, ['src-b']);
    expect(_controller(tester).session, isNot(same(before)));
  });
}
