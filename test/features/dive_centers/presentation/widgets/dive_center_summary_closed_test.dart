import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_centers/domain/entities/dive_center.dart';
import 'package:submersion/features/dive_centers/presentation/providers/dive_center_providers.dart';
import 'package:submersion/features/dive_centers/presentation/widgets/dive_center_closed_tag.dart';
import 'package:submersion/features/dive_centers/presentation/widgets/dive_center_summary_widget.dart';

import '../../../../helpers/test_app.dart';

class _List extends StateNotifier<AsyncValue<List<DiveCenter>>>
    implements DiveCenterListNotifier {
  _List(List<DiveCenter> centers) : super(AsyncValue.data(centers));

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

/// The overview pane's recent centers mark a closed one (#3379).
void main() {
  testWidgets('a closed recent center is greyed and tagged', (tester) async {
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final now = DateTime(2026);
    final centers = [
      DiveCenter(id: 'a', name: 'Open Divers', createdAt: now, updatedAt: now),
      DiveCenter(
        id: 'b',
        name: 'Toucan Diving',
        isPermanentlyClosed: true,
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

    expect(find.byType(DiveCenterClosedTag), findsOneWidget);
    Finder greyed(String name) => find.ancestor(
      of: find.text(name),
      matching: find.byWidgetPredicate(
        (w) => w is Opacity && w.opacity == kClosedDiveCenterOpacity,
      ),
    );
    expect(greyed('Toucan Diving'), findsOneWidget);
    expect(greyed('Open Divers'), findsNothing);
  });
}
