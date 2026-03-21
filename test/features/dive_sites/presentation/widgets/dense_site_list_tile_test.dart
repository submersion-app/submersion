import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/dense_site_list_tile.dart';

import '../../../../helpers/test_app.dart';

void main() {
  group('DenseSiteListTile', () {
    testWidgets('renders name, location, and dive count', (tester) async {
      await tester.pumpWidget(
        testApp(
          child: DenseSiteListTile(
            name: 'Blue Corner Wall',
            location: 'Palau, Micronesia',
            diveCount: 12,
            onTap: () {},
          ),
        ),
      );

      expect(find.text('Blue Corner Wall'), findsOneWidget);
      expect(find.text('Palau, Micronesia'), findsOneWidget);
      expect(find.text('12'), findsOneWidget);
    });

    testWidgets('shows checkbox in selection mode', (tester) async {
      await tester.pumpWidget(
        testApp(
          child: DenseSiteListTile(
            name: 'Blue Corner Wall',
            diveCount: 5,
            isSelectionMode: true,
            isSelected: true,
            onTap: () {},
          ),
        ),
      );

      expect(find.byType(Checkbox), findsOneWidget);
    });

    testWidgets('handles null location gracefully', (tester) async {
      await tester.pumpWidget(
        testApp(
          child: DenseSiteListTile(
            name: 'Unknown Site',
            diveCount: 0,
            onTap: () {},
          ),
        ),
      );

      expect(find.text('Unknown Site'), findsOneWidget);
      expect(find.text('0'), findsOneWidget);
    });
  });
}
