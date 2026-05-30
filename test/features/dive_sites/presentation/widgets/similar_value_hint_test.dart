import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/similar_value_hint.dart';

import '../../../../helpers/test_app.dart';

void main() {
  group('SimilarValueHint', () {
    testWidgets('renders nothing when there is no near match', (tester) async {
      await tester.pumpWidget(
        testApp(
          child: const SimilarValueHint(
            query: 'Atlantis',
            candidates: ['Blue Hole', 'Shark Reef'],
          ),
        ),
      );
      expect(find.byType(Text), findsNothing);
    });

    testWidgets('shows a passive warning when onAccept is null', (
      tester,
    ) async {
      await tester.pumpWidget(
        testApp(
          child: const SimilarValueHint(
            query: 'Manta Pt',
            candidates: ['Manta Point'],
          ),
        ),
      );
      expect(find.textContaining('Manta Point'), findsOneWidget);
      expect(find.byType(InkWell), findsNothing);
    });

    testWidgets('is tappable and reports the match when onAccept is set', (
      tester,
    ) async {
      String? accepted;
      await tester.pumpWidget(
        testApp(
          child: SimilarValueHint(
            query: 'Manta Pt',
            candidates: const ['Manta Point'],
            onAccept: (value) => accepted = value,
          ),
        ),
      );
      expect(find.byType(InkWell), findsOneWidget);
      await tester.tap(find.byType(InkWell));
      expect(accepted, 'Manta Point');
    });
  });
}
