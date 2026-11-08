import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_location.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_component_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_location_display.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_list_content.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/max_width_fraction.dart';

import '../../../../helpers/mock_providers.dart';

/// A card names the place its item is kept (issue #3625), in the right-hand
/// column under the type, when no badge already holds that line.
void main() {
  const reg = EquipmentItem(
    id: 'reg',
    name: 'Ultra Adj 82X',
    type: EquipmentType.regulator,
  );
  final shop = EquipmentLocation(
    id: 'shop',
    name: "Joe's Scuba",
    kind: EquipmentLocationKind.serviceShop,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  Future<void> pumpTile(
    WidgetTester tester, {
    EquipmentItem item = reg,
    EquipmentLocation? location,
    double width = 400,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(width, 600);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          equipmentRollupClockProvider.overrideWith((ref) async => const {}),
          equipmentComponentsIndexProvider.overrideWith(
            (ref) async => ComponentsIndex.empty,
          ),
          activeEquipmentProvider.overrideWith((ref) async => [item]),
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(
              child: EquipmentListTile(item: item, location: location),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder inTrailing(Finder finder) =>
      find.descendant(of: find.byType(MaxWidthFraction), matching: finder);

  testWidgets('names the place under the type, with its kind icon', (
    tester,
  ) async {
    await pumpTile(tester, location: shop);

    expect(inTrailing(find.text('Regulator')), findsOneWidget);
    expect(inTrailing(find.text("Joe's Scuba")), findsOneWidget);
    expect(
      inTrailing(find.byIcon(EquipmentLocationKind.serviceShop.icon)),
      findsOneWidget,
    );
    // Under the type, not beside it.
    expect(
      tester.getTopLeft(find.text("Joe's Scuba")).dy,
      greaterThan(tester.getBottomLeft(find.text('Regulator')).dy - 1),
    );
  });

  testWidgets('a screen reader hears it as the location', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpTile(tester, location: shop);
    // RegExp form: the ListTile merges its children's labels into one node.
    expect(
      find.bySemanticsLabel(RegExp(RegExp.escape("Location: Joe's Scuba"))),
      findsOneWidget,
    );
    semantics.dispose();
  });

  testWidgets('no recorded place leaves the type alone', (tester) async {
    await pumpTile(tester);
    final labels = find.descendant(
      of: find.byType(MaxWidthFraction),
      matching: find.byType(Text),
    );
    expect(labels, findsOneWidget);
    expect(find.text('Regulator'), findsOneWidget);
  });

  testWidgets('a status badge keeps the line and the place stays off', (
    tester,
  ) async {
    await pumpTile(
      tester,
      item: reg.copyWith(status: EquipmentStatus.wanted),
      location: shop,
    );
    expect(inTrailing(find.text('Wanted')), findsOneWidget);
    expect(find.text("Joe's Scuba"), findsNothing);
  });

  testWidgets('a long place name stays on one line in the capped column', (
    tester,
  ) async {
    await pumpTile(
      tester,
      width: 240,
      location: shop.copyWith(
        name: 'The very long name of a friend who borrows everything',
      ),
    );
    expect(tester.takeException(), isNull);
    final place = find.textContaining('The very long name');
    // One line of labelSmall is 16 px in the test font.
    expect(tester.getSize(place).height, lessThan(24));
  });
}
