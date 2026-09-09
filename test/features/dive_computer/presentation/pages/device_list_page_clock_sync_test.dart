import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_computer/presentation/pages/device_list_page.dart';
import 'package:submersion/features/dive_computer/presentation/providers/clock_sync_providers.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_computer.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_computer_providers.dart';

import '../../../../helpers/test_app.dart';

const _switchKey = ValueKey('clock_sync_global_switch');

Widget _build({List<DiveComputer> computers = const []}) {
  return testApp(
    locale: const Locale('en'),
    overrides: [
      allDiveComputersProvider.overrideWith((ref) async => computers),
    ],
    child: const DeviceListPage(),
  );
}

DiveComputer _computer(String id) => DiveComputer(
  id: id,
  name: 'Perdix $id',
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

void main() {
  testWidgets('shows the switch, off, above the empty state', (tester) async {
    await tester.pumpWidget(_build());
    await tester.pumpAndSettle();

    expect(find.byKey(_switchKey), findsOneWidget);
    expect(find.text('Sync dive computer clocks'), findsOneWidget);
    expect(find.text('Find Computers'), findsOneWidget);
    expect(
      tester.widget<SwitchListTile>(find.byKey(_switchKey)).value,
      isFalse,
    );
  });

  testWidgets('shows the switch above a populated list', (tester) async {
    await tester.pumpWidget(_build(computers: [_computer('c1')]));
    await tester.pumpAndSettle();

    final switchTop = tester.getTopLeft(find.byKey(_switchKey)).dy;
    final cardTop = tester.getTopLeft(find.byType(Card).first).dy;
    expect(switchTop, lessThan(cardTop));
  });

  testWidgets('toggling the switch updates the setting', (tester) async {
    await tester.pumpWidget(_build(computers: [_computer('c1')]));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(_switchKey));
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(DeviceListPage)),
    );
    expect(
      container.read(clockSyncSettingsNotifierProvider).globalEnabled,
      isTrue,
    );
    expect(tester.widget<SwitchListTile>(find.byKey(_switchKey)).value, isTrue);
  });

  testWidgets('reflects a setting that is already on', (tester) async {
    await tester.pumpWidget(_build());
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(DeviceListPage)),
    );
    await container
        .read(clockSyncSettingsNotifierProvider.notifier)
        .setGlobalEnabled(true);
    await tester.pumpAndSettle();

    expect(tester.widget<SwitchListTile>(find.byKey(_switchKey)).value, isTrue);
  });
}
