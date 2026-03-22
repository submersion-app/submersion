import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_centers/domain/entities/dive_center.dart';
import 'package:submersion/features/dive_centers/presentation/widgets/compact_dive_center_list_tile.dart';

import '../../../../helpers/test_app.dart';

DiveCenter _makeCenter({String? city, String? country}) {
  final now = DateTime(2024, 1, 1);
  return DiveCenter(
    id: 'c1',
    name: 'Blue Horizon Dive Center',
    city: city,
    country: country,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  group('CompactDiveCenterListTile', () {
    testWidgets('renders name, location, and dive count', (tester) async {
      final center = _makeCenter(city: 'Koror', country: 'Palau');

      await tester.pumpWidget(
        testApp(
          child: CompactDiveCenterListTile(
            center: center,
            diveCount: 12,
            onTap: () {},
          ),
        ),
      );

      expect(find.text('Blue Horizon Dive Center'), findsOneWidget);
      expect(find.text('Koror, Palau'), findsOneWidget);
      expect(find.textContaining('12'), findsWidgets);
    });

    testWidgets('handles null location gracefully', (tester) async {
      final center = _makeCenter();

      await tester.pumpWidget(
        testApp(
          child: CompactDiveCenterListTile(
            center: center,
            diveCount: 0,
            onTap: () {},
          ),
        ),
      );

      expect(find.text('Blue Horizon Dive Center'), findsOneWidget);
      expect(find.textContaining('0'), findsWidgets);
    });

    testWidgets('applies selected card color when isSelected is true', (
      tester,
    ) async {
      final center = _makeCenter(city: 'Koror', country: 'Palau');

      await tester.pumpWidget(
        testApp(
          child: CompactDiveCenterListTile(
            center: center,
            diveCount: 5,
            isSelected: true,
            onTap: () {},
          ),
        ),
      );

      expect(find.text('Blue Horizon Dive Center'), findsOneWidget);
    });

    testWidgets('calls onTap when tapped', (tester) async {
      final center = _makeCenter(city: 'Koror', country: 'Palau');
      var tapped = false;

      await tester.pumpWidget(
        testApp(
          child: CompactDiveCenterListTile(
            center: center,
            diveCount: 3,
            onTap: () => tapped = true,
          ),
        ),
      );

      await tester.tap(find.byType(InkWell).first);
      expect(tapped, isTrue);
    });
  });
}
