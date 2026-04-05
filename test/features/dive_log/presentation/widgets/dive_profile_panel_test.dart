import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/presentation/providers/highlight_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_profile_panel.dart';

import '../../../../helpers/test_app.dart';

void main() {
  group('DiveProfilePanel', () {
    testWidgets('shows empty state when no dive is highlighted', (
      tester,
    ) async {
      await tester.pumpWidget(
        testApp(
          overrides: [highlightedDiveIdProvider.overrideWith((ref) => null)],
          child: const SizedBox(height: 250, child: DiveProfilePanel()),
        ),
      );
      await tester.pump();

      expect(find.text('Select a dive to view its profile'), findsOneWidget);
    });
  });
}
