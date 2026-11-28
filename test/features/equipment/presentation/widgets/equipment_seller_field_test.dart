import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_providers.dart';
import 'package:submersion/features/dive_centers/domain/entities/dive_center.dart';
import 'package:submersion/features/dive_centers/presentation/providers/dive_center_providers.dart';
import 'package:submersion/features/equipment/presentation/editing/gear_item_edit_fields.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_seller_field.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// The Seller field (issue #5140): type a name, or pick a buddy or dive
/// centre from the suggestions.
void main() {
  final t = DateTime(2025);
  final anna = Buddy(id: 'b1', name: 'Anna Berg', createdAt: t, updatedAt: t);
  final lars = Buddy(id: 'b2', name: 'Lars Holm', createdAt: t, updatedAt: t);
  final anchor = DiveCenter(
    id: 'c1',
    name: 'Anchor Dive',
    createdAt: t,
    updatedAt: t,
  );

  final field = find.byKey(const ValueKey('gear-edit-seller'));
  final chip = find.byKey(const ValueKey('gear-edit-seller-chip'));

  Future<List<GearSeller>> pump(
    WidgetTester tester, {
    GearSeller value = (buddyId: null, centerId: null, name: ''),
  }) async {
    final emitted = <GearSeller>[];
    var current = value;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          allBuddiesProvider.overrideWith((ref) async => [anna, lars]),
          allDiveCentersProvider.overrideWith((ref) async => [anchor]),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => EquipmentSellerField(
                value: current,
                onChanged: (v) {
                  emitted.add(v);
                  setState(() => current = v);
                },
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return emitted;
  }

  testWidgets('typing lists matching buddies and dive centres', (tester) async {
    await pump(tester);

    await tester.enterText(field, 'An');
    await tester.pumpAndSettle();

    expect(find.text('Anna Berg'), findsOneWidget);
    expect(find.text('Buddy'), findsOneWidget);
    expect(find.text('Anchor Dive'), findsOneWidget);
    expect(find.text('Dive center'), findsOneWidget);
    expect(find.text('Lars Holm'), findsNothing);
    expect(find.text('Keep "An" as typed'), findsOneWidget);
  });

  testWidgets('picking a buddy links it and shows a chip', (tester) async {
    final emitted = await pump(tester);

    await tester.enterText(field, 'ann');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Anna Berg'));
    await tester.pumpAndSettle();

    expect(emitted.last, (buddyId: 'b1', centerId: null, name: 'Anna Berg'));
    expect(chip, findsOneWidget);
    expect(field, findsNothing);
  });

  testWidgets('picking a dive centre links it', (tester) async {
    final emitted = await pump(tester);

    await tester.enterText(field, 'anch');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Anchor Dive'));
    await tester.pumpAndSettle();

    expect(emitted.last, (buddyId: null, centerId: 'c1', name: 'Anchor Dive'));
  });

  testWidgets('a name typed in full stays typed', (tester) async {
    final emitted = await pump(tester);

    await tester.enterText(field, 'Anna Berg');
    await tester.pumpAndSettle();

    expect(emitted.last, (buddyId: null, centerId: null, name: 'Anna Berg'));
    expect(chip, findsNothing);
  });

  testWidgets('Enter keeps the typed name, linking nothing', (tester) async {
    final emitted = await pump(tester);

    await tester.enterText(field, 'Ann');
    await tester.pumpAndSettle();
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(emitted.last, (buddyId: null, centerId: null, name: 'Ann'));
    expect(chip, findsNothing);
  });

  testWidgets('a value set from outside shows in the field', (tester) async {
    // A clone's prefill can land after the field is built.
    final emitted = <GearSeller>[];
    final value = ValueNotifier<GearSeller>((
      buddyId: null,
      centerId: null,
      name: '',
    ));
    addTearDown(value.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          allBuddiesProvider.overrideWith((ref) async => [anna, lars]),
          allDiveCentersProvider.overrideWith((ref) async => [anchor]),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ValueListenableBuilder<GearSeller>(
              valueListenable: value,
              builder: (context, v, _) =>
                  EquipmentSellerField(value: v, onChanged: emitted.add),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    value.value = (buddyId: null, centerId: null, name: 'Dive Shop Ltd');
    await tester.pumpAndSettle();

    expect(find.text('Dive Shop Ltd'), findsOneWidget);
  });

  testWidgets('clearing the chip leaves an empty typed seller', (tester) async {
    final emitted = await pump(
      tester,
      value: (buddyId: 'b1', centerId: null, name: 'Anna Berg'),
    );
    expect(chip, findsOneWidget);

    await tester.tap(find.byTooltip('Clear seller'));
    await tester.pumpAndSettle();

    expect(emitted.last, (buddyId: null, centerId: null, name: ''));
    expect(field, findsOneWidget);
  });

  testWidgets('a linked buddy shows its current name', (tester) async {
    await pump(tester, value: (buddyId: 'b2', centerId: null, name: 'Lars'));
    expect(find.text('Lars Holm'), findsOneWidget);
  });

  testWidgets('a link this profile cannot open shows the stored name', (
    tester,
  ) async {
    await pump(
      tester,
      value: (buddyId: 'b9', centerId: null, name: 'Someone Else'),
    );
    expect(chip, findsOneWidget);
    expect(find.text('Someone Else'), findsOneWidget);
  });
}
