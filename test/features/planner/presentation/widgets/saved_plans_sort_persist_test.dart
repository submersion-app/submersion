import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/planner/presentation/widgets/saved_plans_list.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';

/// A sort chosen in the Saved Dive Plans sheet is saved for the diver (issue
/// #3748), so the list comes back sorted that way after a restart instead of
/// newest first.
void main() {
  testWidgets('saved plans sort sheet persists the choice', (tester) async {
    final settings = MockSettingsNotifier();
    await tester.pumpWidget(
      testApp(
        overrides: [settingsProvider.overrideWith((ref) => settings)],
        locale: const Locale('en'),
        child: Consumer(
          builder: (context, ref, _) => TextButton(
            onPressed: () => openSavedPlansSortSheet(context, ref),
            child: const Text('sort'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('sort'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Name'));
    await tester.pumpAndSettle();

    expect(settings.state.listArrangements.divePlanSort, 'name:descending');
  });
}
