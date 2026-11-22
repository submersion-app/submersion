import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_header_status.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

EquipmentItem _item(EquipmentStatus status, {bool isActive = true}) =>
    EquipmentItem(
      id: 'x',
      name: 'x',
      type: EquipmentType.regulator,
      status: status,
      isActive: isActive,
    );

/// The detail header's status line (#2025): an inactive item's real status,
/// and the purchase action for wishlist gear.
void main() {
  group('headerStatusOf', () {
    test('active gear gets no chip', () {
      expect(headerStatusOf(_item(EquipmentStatus.active)), isNull);
    });

    test('inactive gear names its own status', () {
      for (final s in [
        EquipmentStatus.sold,
        EquipmentStatus.lost,
        EquipmentStatus.wanted,
      ]) {
        expect(headerStatusOf(_item(s, isActive: false)), s, reason: '$s');
      }
    });

    test('wanted gear is named even with isActive left true', () {
      // An import that defaults isActive must still offer the purchase.
      expect(
        headerStatusOf(_item(EquipmentStatus.wanted)),
        EquipmentStatus.wanted,
      );
    });

    test('a legacy inactive row reads as retired', () {
      expect(
        headerStatusOf(_item(EquipmentStatus.needsService, isActive: false)),
        EquipmentStatus.retired,
      );
    });
  });

  group('EquipmentHeaderStatus', () {
    Future<void> pump(WidgetTester tester, EquipmentItem item) =>
        tester.pumpWidget(
          MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: EquipmentHeaderStatus(item: item)),
          ),
        );

    testWidgets('sold gear shows Sold, not Retired', (tester) async {
      await pump(tester, _item(EquipmentStatus.sold, isActive: false));

      expect(find.text('Sold'), findsOneWidget);
      expect(find.text('Retired'), findsNothing);
    });

    // The purchase is made in the header block's editor (issue #4527,
    // phase 3), not here.
    testWidgets('wanted gear shows its chip and offers no purchase', (
      tester,
    ) async {
      await pump(tester, _item(EquipmentStatus.wanted, isActive: false));

      expect(find.text('Wanted'), findsOneWidget);
      expect(find.text('Mark as purchased'), findsNothing);
    });

    testWidgets('active gear renders nothing', (tester) async {
      await pump(tester, _item(EquipmentStatus.active));

      expect(find.byType(Chip), findsNothing);
    });
  });
}
