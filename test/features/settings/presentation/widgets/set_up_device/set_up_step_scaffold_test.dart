import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/settings/presentation/widgets/set_up_device/set_up_step_scaffold.dart';

Widget _scaffold({VoidCallback? onBack}) => MaterialApp(
  home: Scaffold(
    body: SetUpStepScaffold(
      title: 'Title',
      backLabel: 'Back',
      onBack: onBack,
      primaryLabel: 'Next',
      onPrimary: () {},
      children: const [],
    ),
  ),
);

void main() {
  testWidgets('a step with a way back shows Back', (tester) async {
    var went = false;
    await tester.pumpWidget(_scaffold(onBack: () => went = true));
    await tester.tap(find.text('Back'));
    expect(went, isTrue);
  });

  testWidgets('a step with nowhere to go back to shows no Back', (
    tester,
  ) async {
    await tester.pumpWidget(_scaffold());
    expect(find.text('Back'), findsNothing);
    expect(find.text('Next'), findsOneWidget);
  });
}
