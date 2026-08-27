import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/setup_wizard/domain/setup_wizard_models.dart';
import 'package:submersion/features/setup_wizard/presentation/providers/setup_wizard_providers.dart';
import 'package:submersion/features/setup_wizard/presentation/widgets/steps/existing_choice_step.dart';

import '../../../../../helpers/mock_providers.dart';
import '../../../../../helpers/test_app.dart';

void main() {
  testWidgets('existing choice cards set the draft source', (tester) async {
    late ProviderContainer container;
    final overrides = await getBaseOverrides();
    var advanced = 0;
    await tester.pumpWidget(
      testApp(
        overrides: overrides,
        child: Builder(
          builder: (context) {
            container = ProviderScope.containerOf(context);
            return ExistingChoiceStep(
              mode: SetupWizardMode.firstRun,
              onChosen: () => advanced++,
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Bring your data'), findsOneWidget);
    await tester.tap(find.text('Restore a backup file'));
    await tester.pumpAndSettle();

    final draft = container.read(setupWizardProvider(SetupWizardMode.firstRun));
    expect(draft.source, ExistingDataSource.restoreBackup);
    expect(advanced, 1);
  });
}
