import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/utils/geo_math.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_centers/domain/entities/dive_center.dart';
import 'package:submersion/features/dive_centers/domain/services/dive_center_picker_ranking.dart';
import 'package:submersion/features/dive_centers/presentation/providers/dive_center_providers.dart';
import 'package:submersion/features/dive_centers/presentation/widgets/dive_center_closed_tag.dart';
import 'package:submersion/features/dive_centers/presentation/widgets/dive_center_picker.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';

/// The dive center picker lists centers near the dive first (#3379).
void main() {
  const saltPier = GeoPoint(12.0864, -68.2779);
  const buddy = GeoPoint(12.1665, -68.2830);
  const vip = GeoPoint(12.1440, -68.2760);

  DiveCenter center(String name, {GeoPoint? at, bool closed = false}) {
    final now = DateTime(2026);
    return DiveCenter(
      id: name,
      name: name,
      latitude: at?.latitude,
      longitude: at?.longitude,
      isPermanentlyClosed: closed,
      createdAt: now,
      updatedAt: now,
    );
  }

  // Alphabetical, as the repository returns them.
  final centers = [
    center('Blue Corner Dive', at: const GeoPoint(-8.679, 115.451)),
    center('Buddy Dive Resort', at: buddy),
    center('Dressel Divers', at: const GeoPoint(20.423, -86.922)),
    center('Toucan Diving', closed: true),
    center('VIP Diving', at: vip),
  ];

  Future<List<DiveCenter>> pump(
    WidgetTester tester, {
    DiveCenterPickerReference? reference,
    DiveCenter? selected,
    DistanceUnit unit = DistanceUnit.kilometers,
  }) async {
    tester.view.physicalSize = const Size(900, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final picked = <DiveCenter>[];
    await tester.pumpWidget(
      testApp(
        overrides: [
          allDiveCentersProvider.overrideWith((ref) async => centers),
          settingsProvider.overrideWith(
            (ref) => MockSettingsNotifier(AppSettings(distanceUnit: unit)),
          ),
        ],
        child: DiveCenterPickerSheet(
          scrollController: ScrollController(),
          selectedCenter: selected,
          reference: reference,
          onCenterSelected: picked.add,
          onCreateNewCenter: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    return picked;
  }

  double top(WidgetTester tester, String text) =>
      tester.getTopLeft(find.text(text)).dy;

  void expectInOrder(WidgetTester tester, List<String> texts) {
    for (var i = 1; i < texts.length; i++) {
      expect(
        top(tester, texts[i - 1]),
        lessThan(top(tester, texts[i])),
        reason: '${texts[i - 1]} before ${texts[i]}',
      );
    }
  }

  testWidgets('a site puts its nearby centers first, nearest at the top', (
    tester,
  ) async {
    await pump(
      tester,
      reference: const DiveCenterPickerReference(
        point: saltPier,
        siteName: 'Salt Pier',
      ),
    );

    expectInOrder(tester, [
      'Near Salt Pier',
      'VIP Diving',
      'Buddy Dive Resort',
      'All dive centers',
      'Blue Corner Dive',
      'Dressel Divers',
      'Toucan Diving',
    ]);
    const km = UnitFormatter(AppSettings());
    expect(
      find.text(km.formatGeoDistance(distanceMeters(saltPier, vip))),
      findsOneWidget,
    );
  });

  testWidgets('a point from the dive GPS says "Near this dive"', (
    tester,
  ) async {
    await pump(
      tester,
      reference: const DiveCenterPickerReference(point: saltPier),
    );

    expect(find.text('Near this dive'), findsOneWidget);
    expect(find.textContaining('Near Salt Pier'), findsNothing);
  });

  testWidgets('a point from the device says "Near your location"', (
    tester,
  ) async {
    await pump(
      tester,
      reference: const DiveCenterPickerReference(
        point: saltPier,
        source: DiveCenterReferenceSource.device,
      ),
    );

    expect(find.text('Near your location'), findsOneWidget);
    expect(find.text('Near this dive'), findsNothing);
  });

  testWidgets('without a reference there are no headers, closed last', (
    tester,
  ) async {
    await pump(tester);

    expect(find.text('All dive centers'), findsNothing);
    expect(find.textContaining('Near '), findsNothing);
    expectInOrder(tester, [
      'Blue Corner Dive',
      'Buddy Dive Resort',
      'Dressel Divers',
      'VIP Diving',
      'Toucan Diving',
    ]);
  });

  testWidgets('the selected closed center is greyed, tagged, checked, and '
      'still selectable', (tester) async {
    final toucan = centers.firstWhere((c) => c.name == 'Toucan Diving');
    final picked = await pump(
      tester,
      selected: toucan,
      reference: const DiveCenterPickerReference(
        point: saltPier,
        siteName: 'Salt Pier',
      ),
    );

    final row = find.ancestor(
      of: find.text('Toucan Diving'),
      matching: find.byType(ListTile),
    );
    expect(
      find.descendant(of: row, matching: find.byType(DiveCenterClosedTag)),
      findsOneWidget,
    );
    expect(
      find.descendant(of: row, matching: find.byIcon(Icons.check_circle)),
      findsOneWidget,
    );
    expect(
      find.ancestor(
        of: find.text('Toucan Diving'),
        matching: find.byWidgetPredicate(
          (w) => w is Opacity && w.opacity == kClosedDiveCenterOpacity,
        ),
      ),
      findsOneWidget,
    );
    expect(
      top(tester, 'All dive centers'),
      lessThan(top(tester, 'Toucan Diving')),
    );

    await tester.tap(find.text('Toucan Diving'));
    expect(picked.single.id, toucan.id);
  });

  testWidgets('distances follow the diver unit', (tester) async {
    await pump(
      tester,
      unit: DistanceUnit.miles,
      reference: const DiveCenterPickerReference(
        point: saltPier,
        siteName: 'Salt Pier',
      ),
    );

    const mi = UnitFormatter(AppSettings(distanceUnit: DistanceUnit.miles));
    final text = mi.formatGeoDistance(distanceMeters(saltPier, vip));
    expect(text, endsWith('mi'));
    expect(find.text(text), findsOneWidget);
  });
}
