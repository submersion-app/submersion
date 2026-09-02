import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/marine_life/presentation/widgets/species_category_chips.dart';

import '../../../../helpers/test_app.dart';

void main() {
  testWidgets('renders All plus one chip per category', (tester) async {
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        child: SpeciesCategoryChips(selected: null, onSelected: (_) {}),
      ),
    );

    expect(
      find.byType(FilterChip),
      findsNWidgets(SpeciesCategory.values.length + 1),
    );
    expect(find.text('All'), findsOneWidget);
    expect(find.text('Fish'), findsOneWidget);
    expect(find.text('Turtle'), findsOneWidget);
  });

  testWidgets('tapping a category reports it; tapping it again reports null', (
    tester,
  ) async {
    final received = <SpeciesCategory?>[];
    SpeciesCategory? selected;

    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        child: StatefulBuilder(
          builder: (context, setState) => SpeciesCategoryChips(
            selected: selected,
            onSelected: (category) {
              received.add(category);
              setState(() => selected = category);
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Fish'));
    await tester.pump();
    expect(received, [SpeciesCategory.fish]);

    await tester.tap(find.text('Fish'));
    await tester.pump();
    expect(received, [SpeciesCategory.fish, null]);
  });

  testWidgets('tapping All reports null', (tester) async {
    SpeciesCategory? received = SpeciesCategory.shark;

    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        child: SpeciesCategoryChips(
          selected: SpeciesCategory.shark,
          onSelected: (category) => received = category,
        ),
      ),
    );

    await tester.tap(find.text('All'));
    await tester.pump();
    expect(received, isNull);
  });
}
