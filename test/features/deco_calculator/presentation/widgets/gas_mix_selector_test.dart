import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/deco_calculator/presentation/widgets/gas_mix_selector.dart';

import '../../../../helpers/test_app.dart';

void main() {
  // The custom mix toggle sits before its label, where a chevron reads as
  // the section's state: right while folded, down once open, as the dive
  // list's group headers draw it (#2061).
  testWidgets('custom mix toggle points right while folded and down once '
      'open (#2061)', (tester) async {
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        child: const SingleChildScrollView(child: GasMixSelector()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    expect(
      find.byIcon(Icons.expand_more),
      findsNothing,
      reason: 'a down chevron made the folded section look already open',
    );

    await tester.tap(find.text('Custom Mix (Trimix)'));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.expand_more), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right), findsNothing);
    expect(find.byIcon(Icons.expand_less), findsNothing);
  });
}
