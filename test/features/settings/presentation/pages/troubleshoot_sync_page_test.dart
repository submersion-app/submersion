import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/settings/presentation/pages/troubleshoot_sync_page.dart';

void main() {
  testWidgets('shows Repair Sync action with an explanation', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: TroubleshootSyncPage())),
    );
    await tester.pumpAndSettle();

    expect(find.text('Repair Sync'), findsOneWidget);
    // The explanation must reassure the user their dive data is safe.
    expect(find.textContaining('dive data'), findsWidgets);
  });

  testWidgets('shows both cloud-clear actions', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: TroubleshootSyncPage())),
    );
    await tester.pumpAndSettle();

    expect(find.text('Remove this device’s cloud files'), findsOneWidget);
    expect(find.text('Wipe all sync data on this backend'), findsOneWidget);
  });

  testWidgets('wipe-all requires typed confirmation', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: TroubleshootSyncPage())),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Wipe all sync data on this backend'));
    await tester.pumpAndSettle();

    final confirmBtn = find.widgetWithText(FilledButton, 'Wipe everything');
    expect(
      tester.widget<FilledButton>(confirmBtn).onPressed,
      isNull,
      reason: 'disabled until the confirmation word is typed',
    );

    await tester.enterText(find.byType(TextField), 'WIPE');
    await tester.pump();

    expect(
      tester.widget<FilledButton>(confirmBtn).onPressed,
      isNotNull,
      reason: 'enabled once the user types WIPE',
    );
  });
}
