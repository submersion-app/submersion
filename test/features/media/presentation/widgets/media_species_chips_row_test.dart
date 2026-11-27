import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/media/domain/entities/species_tag_chip.dart';
import 'package:submersion/features/media/presentation/providers/species_media_providers.dart';
import 'package:submersion/features/media/presentation/widgets/media_species_chips_row.dart';
import 'package:submersion/features/media/domain/entities/photo_record.dart';
import 'package:submersion/features/media/domain/value_objects/photo_tag_edits.dart';
import 'package:submersion/features/media/presentation/editing/photo_edit_fields.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';
import '../support/media_widget_harness.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';

void main() {
  testWidgets('renders one chip per tag with the localized name', (
    tester,
  ) async {
    final overrides = await getBaseOverrides();
    final router = GoRouter(
      initialLocation: '/viewer',
      routes: [
        GoRoute(
          path: '/viewer',
          builder: (_, _) =>
              const Scaffold(body: MediaSpeciesChipsRow(mediaId: 'p1')),
        ),
        GoRoute(
          path: '/species/:id',
          builder: (_, state) =>
              Scaffold(body: Text('DETAIL ${state.pathParameters['id']}')),
        ),
      ],
    );
    await tester.pumpWidget(
      testAppRouter(
        router: router,
        locale: const Locale('de'),
        overrides: [
          ...overrides,
          mediaTagChipsProvider('p1').overrideWith(
            (ref) async => const [
              SpeciesTagChip(
                speciesId: 'sp_whale_shark',
                storedName: 'Whale Shark',
                category: SpeciesCategory.shark,
                isBuiltIn: true,
              ),
              SpeciesTagChip(
                speciesId: 'c1',
                storedName: 'My Nudibranch',
                category: SpeciesCategory.invertebrate,
                isBuiltIn: false,
              ),
            ],
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Walhai'), findsOneWidget);
    expect(find.text('My Nudibranch'), findsOneWidget);

    await tester.tap(find.text('Walhai'));
    await tester.pumpAndSettle();
    expect(find.text('DETAIL sp_whale_shark'), findsOneWidget);
  });

  testWidgets('renders nothing without tags', (tester) async {
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        overrides: [
          ...overrides,
          mediaTagChipsProvider('p1').overrideWith((ref) async => const []),
        ],
        child: const MediaSpeciesChipsRow(mediaId: 'p1'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ActionChip), findsNothing);
  });
  testWidgets('in a sitting: the sitting\'s tags, redrawn as they change', (
    tester,
  ) async {
    final overrides = await getBaseOverrides();
    final sitting = EditSession<PhotoRecord>(
      PhotoRecord(
        item: testMediaItem(id: 'p1', diveId: 'd1'),
        species: const [],
        people: const [],
      ),
    );
    addTearDown(sitting.dispose);
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        overrides: [
          ...overrides,
          mediaTagChipsProvider('p1').overrideWith((ref) async => const []),
        ],
        child: MediaSpeciesChipsRow(mediaId: 'p1', sitting: sitting),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(ActionChip), findsNothing);

    sitting.set(
      photoSpeciesField,
      SpeciesTagEdits.none.toggled(
        const SpeciesTagChip(
          speciesId: 'c1',
          storedName: 'My Nudibranch',
          category: SpeciesCategory.invertebrate,
          isBuiltIn: false,
        ),
        tagged: true,
        stored: const [],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('My Nudibranch'), findsOneWidget);
  });

  group('one line, then a count (issue #4825)', () {
    final many = [
      for (var i = 0; i < 16; i++)
        SpeciesTagChip(
          speciesId: 'sp_$i',
          storedName: 'Striped species $i',
          category: SpeciesCategory.fish,
          isBuiltIn: false,
        ),
    ];
    final more = find.byKey(const ValueKey('media_species_more'));

    Future<void> pumpMany(
      WidgetTester tester, {
      VoidCallback? onMoreTap,
    }) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final overrides = await getBaseOverrides();
      await tester.pumpWidget(
        testApp(
          locale: const Locale('en'),
          overrides: [
            ...overrides,
            mediaTagChipsProvider('p1').overrideWith((ref) async => many),
          ],
          child: Align(
            alignment: Alignment.topLeft,
            child: MediaSpeciesChipsRow(mediaId: 'p1', onMoreTap: onMoreTap),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('sixteen tags stay on one line with a count chip', (
      tester,
    ) async {
      await pumpMany(tester);
      expect(more, findsOneWidget);
      // A plain chip when there is nothing to open (issue #4921), so read
      // the RawChip both kinds build on.
      final chip = tester.widget<RawChip>(
        find.descendant(of: more, matching: find.byType(RawChip)),
      );
      expect((chip.label as Text).data, startsWith('+'));
      final row = tester.getSize(find.byType(MediaSpeciesChipsRow));
      final oneChip = tester.getSize(find.byType(ActionChip).first);
      // One chip's height and the row's gap under it.
      expect(row.height, lessThanOrEqualTo(oneChip.height + 8));
      expect(tester.takeException(), isNull);
    });

    testWidgets('the count says how many species it stands for', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await pumpMany(tester);
      // A plain chip when there is nothing to open (issue #4921), so read
      // the RawChip both kinds build on.
      final chip = tester.widget<RawChip>(
        find.descendant(of: more, matching: find.byType(RawChip)),
      );
      final hidden = int.parse((chip.label as Text).data!.substring(1));
      expect(find.bySemanticsLabel('$hidden more species'), findsOneWidget);
      // The ones shown and the ones counted are all of them.
      expect(
        find.textContaining('Striped species').evaluate().length + hidden,
        16,
      );
      semantics.dispose();
    });

    testWidgets('with nothing to open, the count is not announced as a '
        'button', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpMany(tester);
      final node = tester.getSemantics(more);
      expect(node.flagsCollection.isButton, isFalse);
      expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isFalse);
      semantics.dispose();
    });

    testWidgets('the count chip calls onMoreTap', (tester) async {
      var taps = 0;
      await pumpMany(tester, onMoreTap: () => taps++);
      await tester.tap(more);
      expect(taps, 1);
    });

    testWidgets('a few tags show without a count', (tester) async {
      final overrides = await getBaseOverrides();
      await tester.pumpWidget(
        testApp(
          locale: const Locale('en'),
          overrides: [
            ...overrides,
            mediaTagChipsProvider(
              'p1',
            ).overrideWith((ref) async => many.take(2).toList()),
          ],
          child: const MediaSpeciesChipsRow(mediaId: 'p1'),
        ),
      );
      await tester.pumpAndSettle();
      expect(more, findsNothing);
      expect(find.textContaining('Striped species'), findsNWidgets(2));
    });
  });
}
