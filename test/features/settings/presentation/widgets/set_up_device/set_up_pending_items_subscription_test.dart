import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/services/accounts/pending_setup_service.dart';
import 'package:submersion/features/settings/presentation/widgets/set_up_device/set_up_pending_items.dart';

import '../../../../../helpers/l10n_test_helpers.dart';

const _item = PendingSetupItem(
  kind: SetupItemKind.subscriptionPassword,
  key: 'subscription_password_s1',
  label: 'Dives',
  route: '/settings/media-sources/network-sources',
  subscriptionId: 's1',
);

Future<void> _pump(
  WidgetTester tester, {
  required List<String> opened,
  List<PendingSetupItem>? entered,
}) async {
  await tester.pumpWidget(
    localizedMaterialApp(
      locale: const Locale('en'),
      home: Scaffold(
        body: SetUpPendingItems(
          items: const [_item],
          onOpen: opened.add,
          onSignIn: (_) async {},
          onReconnect: (_) async {},
          onDismiss: (_) async {},
          onEnterPassword: entered == null
              ? null
              : (item) async => entered.add(item),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('names the album and asks for its password', (tester) async {
    final opened = <String>[];
    final entered = <PendingSetupItem>[];
    await _pump(tester, opened: opened, entered: entered);

    expect(
      find.text('The photo album Dives needs its password on this device.'),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.key_outlined), findsOneWidget);

    await tester.tap(find.text('Enter password'));
    await tester.pumpAndSettle();
    expect(entered, [_item]);
    expect(opened, isEmpty);
  });

  testWidgets('without a password flow the action opens the page', (
    tester,
  ) async {
    final opened = <String>[];
    await _pump(tester, opened: opened);

    await tester.tap(find.text('Enter password'));
    await tester.pumpAndSettle();
    expect(opened, ['/settings/media-sources/network-sources']);
  });
}
