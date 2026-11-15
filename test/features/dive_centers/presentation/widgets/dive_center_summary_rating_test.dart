import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_centers/domain/entities/dive_center.dart';
import 'package:submersion/features/dive_centers/presentation/providers/dive_center_providers.dart';
import 'package:submersion/features/dive_centers/presentation/widgets/dive_center_summary_widget.dart';

import '../../../../helpers/test_app.dart';

class _List extends StateNotifier<AsyncValue<List<DiveCenter>>>
    implements DiveCenterListNotifier {
  _List(List<DiveCenter> centers) : super(AsyncValue.data(centers));

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

/// The overview pane shows a whole-star rating as "4", the way a dive's
/// reads, and keeps a fraction an import brought in (#4573).
void main() {
  testWidgets('ratings read without a trailing ".0"', (tester) async {
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final now = DateTime(2026);
    final centers = [
      DiveCenter(
        id: 'a',
        name: 'Whole Star Divers',
        rating: 4,
        createdAt: now,
        updatedAt: now,
      ),
      DiveCenter(
        id: 'b',
        name: 'Imported Divers',
        rating: 3.5,
        createdAt: now,
        updatedAt: now,
      ),
    ];
    await tester.pumpWidget(
      testApp(
        overrides: [
          diveCenterListNotifierProvider.overrideWith((ref) => _List(centers)),
          diveCenterCountriesProvider.overrideWith((ref) async => <String>[]),
        ],
        child: const DiveCenterSummaryWidget(),
      ),
    );
    await tester.pumpAndSettle();

    // The highest-rating stat and the 4-star center's row.
    expect(find.text('4'), findsNWidgets(2));
    expect(find.text('3.5'), findsOneWidget);
    expect(find.text('4.0'), findsNothing);
  });
}
