import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/domain/entities/photo_record.dart';
import 'package:submersion/features/media/presentation/providers/media_gear_providers.dart';
import 'package:submersion/features/media/presentation/widgets/media_gear_sheet.dart';
import 'package:submersion/features/media/presentation/widgets/media_info_gear_section.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

/// The info panel's Gear card (issue #5046): the gear linked to a photo as
/// chips, each opening its item, and Edit gear while the photo is unlocked.
void main() {
  final photo = MediaItem(
    id: 'm1',
    diveId: 'd1',
    mediaType: MediaType.photo,
    sourceType: MediaSourceType.platformGallery,
    takenAt: DateTime(2026),
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  const drysuit = EquipmentItem(
    id: 'e1',
    name: 'Zeagle drysuit',
    type: EquipmentType.drysuit,
  );
  const bcd = EquipmentItem(
    id: 'e2',
    name: 'Apeks wing',
    type: EquipmentType.bcd,
  );
  const torch = EquipmentItem(
    id: 'e3',
    name: 'Canister torch',
    type: EquipmentType.light,
  );

  EditSession<PhotoRecord> sittingWith(List<String> gearIds) =>
      EditSession<PhotoRecord>(
        PhotoRecord(
          item: photo,
          species: const [],
          people: const [],
          gearIds: gearIds,
        ),
      );

  Future<void> pump(
    WidgetTester tester, {
    List<String> linked = const [],
    List<EquipmentItem> visible = const [drysuit, bcd, torch],
    Set<String> onDive = const {},
    EditSession<PhotoRecord>? sitting,
    double width = 500,
  }) async {
    tester.view.physicalSize = Size(width, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => Scaffold(
            body: SingleChildScrollView(
              child: MediaInfoGearSection(item: photo, sitting: sitting),
            ),
          ),
        ),
        GoRoute(
          path: '/equipment/:id',
          builder: (_, state) =>
              Scaffold(body: Text('GEAR ${state.pathParameters['id']}')),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          allEquipmentProvider.overrideWith((ref) async => visible),
          gearIdsForMediaProvider.overrideWith((ref, id) async => linked),
          gearOnDiveProvider.overrideWith((ref, id) async => onDive),
        ],
        child: MaterialApp.router(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows No gear linked and no Edit gear while locked', (
    tester,
  ) async {
    await pump(tester);
    expect(find.text('No gear linked'), findsOneWidget);
    expect(find.byKey(const ValueKey('media_info_editGear')), findsNothing);
  });

  testWidgets('shows linked gear chips in name order', (tester) async {
    await pump(tester, linked: ['e1', 'e2']);
    final wing = tester.getTopLeft(find.text('Apeks wing'));
    final suit = tester.getTopLeft(find.text('Zeagle drysuit'));
    expect(wing.dx < suit.dx || wing.dy < suit.dy, isTrue);
  });

  testWidgets('hides a chip for gear the diver cannot see', (tester) async {
    await pump(tester, linked: ['e1', 'hidden'], visible: [drysuit]);
    expect(find.text('Zeagle drysuit'), findsOneWidget);
    expect(find.byType(ActionChip), findsOneWidget);
  });

  testWidgets('tapping a chip navigates to the item page', (tester) async {
    await pump(tester, linked: ['e1']);
    await tester.tap(find.text('Zeagle drysuit'));
    await tester.pumpAndSettle();
    expect(find.text('GEAR e1'), findsOneWidget);
  });

  testWidgets('Edit gear shows while the sitting is over the photo', (
    tester,
  ) async {
    final sitting = sittingWith(['e1']);
    addTearDown(sitting.dispose);
    await pump(tester, sitting: sitting);
    expect(find.byKey(const ValueKey('media_info_editGear')), findsOneWidget);
    expect(find.text('Zeagle drysuit'), findsOneWidget);
  });

  testWidgets('ten linked items wrap without overflow at 360 px wide', (
    tester,
  ) async {
    final many = [
      for (var i = 0; i < 10; i++)
        EquipmentItem(
          id: 'g$i',
          name: 'Very long gear item name number $i',
          type: EquipmentType.other,
        ),
    ];
    await pump(
      tester,
      linked: [for (final g in many) g.id],
      visible: many,
      width: 360,
    );
    expect(find.byType(ActionChip), findsNWidgets(10));
    expect(tester.takeException(), isNull);
  });

  group('gear sheet', () {
    testWidgets("lists the dive's gear under On this dive first", (
      tester,
    ) async {
      final sitting = sittingWith(const []);
      addTearDown(sitting.dispose);
      await pump(tester, sitting: sitting, onDive: {'e3'});
      await tester.tap(find.byKey(const ValueKey('media_info_editGear')));
      await tester.pumpAndSettle();

      expect(find.byType(MediaGearSheet), findsOneWidget);
      final onDive = tester.getTopLeft(find.text('On this dive')).dy;
      final yours = tester.getTopLeft(find.text('Your gear')).dy;
      final torchRow = tester.getTopLeft(find.text('Canister torch')).dy;
      expect(onDive < torchRow && torchRow < yours, isTrue);
    });

    testWidgets('checking an item holds an add, unchecking it a remove', (
      tester,
    ) async {
      final sitting = sittingWith(['e1']);
      addTearDown(sitting.dispose);
      await pump(tester, sitting: sitting, linked: ['e1']);
      await tester.tap(find.byKey(const ValueKey('media_info_editGear')));
      await tester.pumpAndSettle();
      final sheet = find.byType(MediaGearSheet);

      await tester.tap(
        find.descendant(of: sheet, matching: find.text('Apeks wing')),
      );
      await tester.pumpAndSettle();
      expect(sitting.working.gearIds.toSet(), {'e1', 'e2'});

      await tester.tap(
        find.descendant(of: sheet, matching: find.text('Zeagle drysuit')),
      );
      await tester.pumpAndSettle();
      expect(sitting.working.gearIds, ['e2']);
    });

    testWidgets('search narrows both sections', (tester) async {
      final sitting = sittingWith(const []);
      addTearDown(sitting.dispose);
      await pump(tester, sitting: sitting, onDive: {'e3'});
      await tester.tap(find.byKey(const ValueKey('media_info_editGear')));
      await tester.pumpAndSettle();
      final sheet = find.byType(MediaGearSheet);

      await tester.enterText(
        find.descendant(of: sheet, matching: find.byType(TextField)),
        'wing',
      );
      await tester.pumpAndSettle();

      expect(
        find.descendant(of: sheet, matching: find.text('Apeks wing')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: sheet, matching: find.text('Canister torch')),
        findsNothing,
      );
      expect(
        find.descendant(of: sheet, matching: find.text('Zeagle drysuit')),
        findsNothing,
      );
    });
  });
}
