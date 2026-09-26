import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/presentation/widgets/add_dive_bottom_sheet.dart';

import '../../../../helpers/test_app.dart';

void main() {
  testWidgets('Plan a dive calls onPlanDive and nothing else', (tester) async {
    var planned = false;
    var manual = false;
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        child: Builder(
          builder: (context) => TextButton(
            onPressed: () => showAddDiveBottomSheet(
              context: context,
              onLogManually: () => manual = true,
              onPlanDive: () => planned = true,
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Plan a dive'), findsOneWidget);

    await tester.tap(find.text('Plan a dive'));
    await tester.pumpAndSettle();
    expect(planned, isTrue);
    expect(manual, isFalse);
  });
}
