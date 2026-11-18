import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/dive_detail_sections.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_data_source.dart';
import 'package:submersion/features/dive_log/domain/entities/source_profile.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/dive_detail_profile_section.dart';
import 'package:submersion/features/dive_log/presentation/widgets/source_bar.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_controller.dart';

import '../../../../helpers/test_database.dart';
import 'dive_detail_page_unlock_harness.dart';

/// The profile card's pinned copy during a sitting (issue #4527, plan 7):
/// it is the card the diver sees once the card has scrolled away, so its
/// source bar's Set as primary is the same whole-record operation, and it
/// has no room for Edit profile.
void main() {
  final profile = List.generate(41, (i) {
    final t = i * 30;
    final depth = t < 180
        ? 30.0 * t / 180
        : t < 900
        ? 30.0
        : 30.0 * (1200 - t) / 300;
    return DiveProfilePoint(timestamp: t, depth: depth);
  });
  final now = DateTime(2023, 1, 1, 12);
  final sources = [
    DiveDataSource(
      id: 'src-a',
      diveId: dive.id,
      computerId: 'dc-a',
      isPrimary: true,
      computerName: 'Perdix',
      importedAt: now,
      createdAt: now,
    ),
    DiveDataSource(
      id: 'src-b',
      diveId: dive.id,
      computerId: 'dc-b',
      isPrimary: false,
      computerName: 'Teric',
      importedAt: now,
      createdAt: now,
    ),
  ];
  late Dive profiled;
  late _Repo repo;

  setUp(() async {
    await setUpTestDatabase();
    profiled = dive.copyWith(
      profile: profile,
      runtime: const Duration(seconds: 1200),
      maxDepth: 30,
    );
    repo = _Repo();
  });
  tearDown(tearDownTestDatabase);

  Future<void> settleLong(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 150));
    }
  }

  Future<void> pump(WidgetTester tester) async {
    await pumpPage(
      tester,
      stored: profiled,
      sources: sources,
      size: const Size(900, 700),
      visible: const {
        DiveDetailSectionId.profile,
        DiveDetailSectionId.notes,
        DiveDetailSectionId.dataSources,
      },
      extra: [
        diveRepositoryProvider.overrideWithValue(repo),
        // Both computers recorded the same minutes, so the bar offers each.
        sourceProfilesProvider(dive.id).overrideWith(
          (ref) async => {
            for (final source in sources)
              source.id: SourceProfile(
                sourceId: source.id,
                computerId: source.computerId,
                isEdited: false,
                points: profile,
              ),
          },
        ),
      ],
    );
    await settleLong(tester);
  }

  RecordEditController<Dive> controllerOf(WidgetTester tester) => tester
      .widget<RecordEditScope<Dive>>(
        find.byWidgetPredicate((w) => w is RecordEditScope<Dive>).first,
      )
      .notifier!;

  /// Scrolls the card's top past the page's, so its copy pins. The page's
  /// own scroll view: the Add strip above it scrolls sideways.
  Future<void> pinTheCopy(WidgetTester tester) async {
    final scrollable = find
        .byWidgetPredicate(
          (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
        )
        .first;
    final cardTop = tester
        .getTopLeft(find.byKey(const ValueKey('diveSection_profile')))
        .dy;
    final viewportTop = tester.getTopLeft(scrollable).dy;
    final position = tester.state<ScrollableState>(scrollable).position;
    position.jumpTo(position.pixels + cardTop - viewportTop + 80);
    for (var i = 0; i < 3; i++) {
      await tester.pump();
    }
  }

  Finder copy() => find.byWidgetPredicate(
    (w) => w is DiveDetailProfileSection && w.fillHeight,
  );

  Future<void> openCopysChipMenu(WidgetTester tester) async {
    await tester.tap(
      find.descendant(
        of: find.descendant(of: copy(), matching: find.byType(SourceBar)),
        matching: find.byWidgetPredicate((w) => w is PopupMenuButton<void>),
      ),
    );
    await settleLong(tester);
  }

  PopupMenuItem<void> setPrimaryItem(WidgetTester tester) =>
      tester.widget<PopupMenuItem<void>>(
        find.ancestor(
          of: find.text('Set as primary'),
          matching: find.byWidgetPredicate((w) => w is PopupMenuItem<void>),
        ),
      );

  // With the semantics tree on: Set as primary from the pinned copy used to
  // trip the framework's debug check `node.built` in flushSemantics as the
  // page read the dive again; the pinned box is now a semantics container
  // of its own.
  testWidgets('unlocked and clean: the copy has no Edit profile, and Set as '
      'primary from it runs and the sitting starts again', (tester) async {
    await pump(tester);
    await unlock(tester);
    await settleLong(tester);
    final before = controllerOf(tester).session;

    await pinTheCopy(tester);
    expect(copy(), findsOneWidget);
    expect(
      find.descendant(of: copy(), matching: find.byTooltip('Edit profile')),
      findsNothing,
    );
    expect(
      find.descendant(of: copy(), matching: find.byTooltip('Add annotation')),
      findsNothing,
    );

    await openCopysChipMenu(tester);
    expect(setPrimaryItem(tester).enabled, isTrue);
    await tester.tap(find.text('Set as primary'));
    await settleLong(tester);

    expect(repo.primaries, ['src-b']);
    final controller = controllerOf(tester);
    expect(controller.isUnlocked, isTrue);
    expect(controller.session, isNot(same(before)));
    expect(controller.isDirty, isFalse);
  });

  testWidgets('with unsaved changes Set as primary on the copy is disabled '
      'under the reason, and writes nothing', (tester) async {
    await pump(tester);
    await unlock(tester);
    await openNotes(tester);
    await tester.enterText(find.byType(TextField).first, 'Choppy');
    await settleLong(tester);
    await tester.tap(find.text('Done'));
    await settleLong(tester);
    final before = controllerOf(tester).session;

    await pinTheCopy(tester);
    expect(copy(), findsOneWidget);
    await openCopysChipMenu(tester);

    expect(find.text('Save or cancel your changes first'), findsOneWidget);
    expect(setPrimaryItem(tester).enabled, isFalse);
    await tester.tap(find.text('Set as primary'), warnIfMissed: false);
    await settleLong(tester);

    expect(repo.primaries, isEmpty);
    expect(controllerOf(tester).session, same(before));
    expect(controllerOf(tester).session!.working.notes, 'Choppy');
  });
}

/// Stands in for the repository's Set as primary, recording it.
class _Repo extends Fake implements DiveRepository {
  final primaries = <String>[];

  @override
  Future<void> setPrimaryDataSource({
    required String diveId,
    required String computerReadingId,
  }) async => primaries.add(computerReadingId);
}
