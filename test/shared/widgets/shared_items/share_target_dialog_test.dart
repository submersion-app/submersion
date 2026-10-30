import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/data/visibility/item_sharing.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';
import 'package:submersion/shared/widgets/shared_items/share_target_dialog.dart';

/// The dialog that picks who a trip or site is shared with (issue #2151).
void main() {
  final profiles = [
    for (final (id, name) in [('son', 'Sam'), ('daughter', 'Dana')])
      Diver(
        id: id,
        name: name,
        createdAt: DateTime(2024),
        updatedAt: DateTime(2024),
      ),
  ];

  /// Opens the dialog and returns a future of its result.
  Future<Future<ItemSharing?>> open(
    WidgetTester tester, {
    ItemSharing initial = ItemSharing.none,
    bool allowEmpty = true,
  }) async {
    late Future<ItemSharing?> result;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => result = showShareTargetDialog(
              context,
              title: 'Share with',
              body: 'Body',
              profiles: profiles,
              initial: initial,
              confirmLabel: 'Save',
              allowEmpty: allowEmpty,
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return result;
  }

  bool checked(WidgetTester tester, String label) => tester
      .widget<CheckboxListTile>(
        find.ancestor(
          of: find.text(label),
          matching: find.byType(CheckboxListTile),
        ),
      )
      .value!;

  testWidgets('ticking Everyone clears the profiles', (tester) async {
    final result = await open(
      tester,
      initial: const ItemSharing(profileIds: {'son'}),
    );
    expect(checked(tester, 'Sam'), isTrue);
    await tester.tap(find.text('Everyone'));
    await tester.pump();
    expect(checked(tester, 'Sam'), isFalse);
    expect(checked(tester, 'Everyone'), isTrue);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(await result, ItemSharing.all);
  });

  testWidgets('ticking a profile clears Everyone', (tester) async {
    final result = await open(tester, initial: ItemSharing.all);
    await tester.tap(find.text('Dana'));
    await tester.pump();
    expect(checked(tester, 'Everyone'), isFalse);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(await result, const ItemSharing(profileIds: {'daughter'}));
  });

  testWidgets('cancel returns null', (tester) async {
    final result = await open(tester);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(await result, isNull);
  });

  testWidgets('without allowEmpty, nothing chosen cannot be confirmed', (
    tester,
  ) async {
    await open(tester, allowEmpty: false);
    final save = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Save'),
    );
    expect(save.onPressed, isNull);
  });

  group('sharingSummary', () {
    final l10n = AppLocalizationsEn();
    const names = {'son': 'Sam', 'daughter': 'Dana'};

    test('says Not shared, Everyone, or the names in order', () {
      expect(sharingSummary(ItemSharing.none, names, l10n), 'Not shared');
      expect(sharingSummary(ItemSharing.all, names, l10n), 'Everyone');
      expect(
        sharingSummary(
          const ItemSharing(profileIds: {'son', 'daughter'}),
          names,
          l10n,
        ),
        'Dana, Sam',
      );
    });

    test('leaves out a profile it cannot name', () {
      expect(
        sharingSummary(const ItemSharing(profileIds: {'gone'}), names, l10n),
        'Not shared',
      );
    });
  });
}
