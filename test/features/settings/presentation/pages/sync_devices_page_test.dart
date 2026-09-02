import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/sync/sync_device_footprint.dart';
import 'package:submersion/features/settings/presentation/pages/sync_devices_page.dart';
import 'package:submersion/features/settings/presentation/providers/sync_device_providers.dart';

import '../../../../helpers/l10n_test_helpers.dart';

/// Issue #1032: the user could see 400+ files on Dropbox but nothing in the app
/// explained them, so the only tool available was the all-or-nothing wipe.
void main() {
  SyncDeviceFootprint device({
    required String id,
    required SyncDeviceFootprintState state,
    String? name,
    bool isSelf = false,
    int files = 1,
    int bytes = 2048,
  }) => SyncDeviceFootprint(
    deviceId: id,
    state: state,
    fileCount: files,
    byteCount: bytes,
    deviceName: name,
    isSelf: isSelf,
    publishedAt: DateTime.utc(2026, 8, 13, 12),
  );

  Future<void> pump(
    WidgetTester tester,
    List<SyncDeviceFootprint> devices,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          syncDeviceFootprintListProvider.overrideWith((ref) async => devices),
        ],
        child: localizedMaterialApp(
          locale: const Locale('en'),
          home: const SyncDevicesPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('totals the whole backend and calls out the dead weight', (
    tester,
  ) async {
    await pump(tester, [
      device(
        id: 'self',
        state: SyncDeviceFootprintState.active,
        name: 'Pixel',
        isSelf: true,
        files: 2,
        bytes: 1024,
      ),
      device(
        id: 'ghost1',
        state: SyncDeviceFootprintState.staleEpoch,
        files: 80,
        bytes: 1024 * 1024,
      ),
    ]);

    expect(find.textContaining('2 devices, 82 files'), findsOneWidget);
    expect(
      find.textContaining('1 left over from a replaced or retired library'),
      findsOneWidget,
      reason: 'the whole point is telling the user what is safe to delete',
    );
  });

  testWidgets('names an unnamed device by its short id', (tester) async {
    await pump(tester, [
      device(
        id: 'abcdef1234567890',
        state: SyncDeviceFootprintState.staleEpoch,
      ),
    ]);

    expect(find.text('Device abcdef12'), findsOneWidget);
  });

  testWidgets('explains why a stale device is stale', (tester) async {
    await pump(tester, [
      device(id: 'ghost', state: SyncDeviceFootprintState.staleEpoch),
    ]);

    expect(
      find.textContaining('Left over from an earlier library'),
      findsOneWidget,
    );
  });

  testWidgets('offers no delete button for this device', (tester) async {
    await pump(tester, [
      device(
        id: 'self',
        state: SyncDeviceFootprintState.active,
        name: 'Pixel',
        isSelf: true,
      ),
    ]);

    expect(
      find.byIcon(Icons.delete_outline),
      findsNothing,
      reason:
          'removing your own files is a different operation with different '
          'consequences, and it lives on the Troubleshoot page',
    );
  });

  testWidgets('warns harder before removing a device that still syncs', (
    tester,
  ) async {
    await pump(tester, [
      device(id: 'live', state: SyncDeviceFootprintState.active, name: 'iPad'),
    ]);

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();

    expect(find.textContaining('still part of this sync'), findsOneWidget);
    expect(
      find.textContaining('has not yet published will be lost'),
      findsOneWidget,
    );
  });

  testWidgets('a stale device gets the calm confirmation', (tester) async {
    await pump(tester, [
      device(
        id: 'ghost',
        state: SyncDeviceFootprintState.staleEpoch,
        files: 80,
      ),
    ]);

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('no device syncs from any more'),
      findsOneWidget,
    );
    expect(find.textContaining('still part of this sync'), findsNothing);
  });

  testWidgets('an unreadable footprint is not offered as safe to remove', (
    tester,
  ) async {
    await pump(tester, [
      device(id: 'half', state: SyncDeviceFootprintState.unreadable),
    ]);

    expect(
      find.textContaining('No readable manifest'),
      findsOneWidget,
      reason: 'an unfinished upload must not be presented as dead weight',
    );
    expect(
      find.textContaining('left over from a replaced or retired'),
      findsNothing,
    );
  });

  testWidgets('says so when the backend holds nothing', (tester) async {
    await pump(tester, []);
    expect(find.text('No sync files on this backend.'), findsOneWidget);
  });

  // Issue #1194: mobile devices publish a name now. Two phones of one model,
  // and every iPhone on iOS 16+, publish the SAME name.
  testWidgets('qualifies a name two devices share', (tester) async {
    await pump(tester, [
      device(
        id: 'aaaabbbbccccdddd',
        state: SyncDeviceFootprintState.active,
        name: 'iPhone',
      ),
      device(
        id: 'eeeeffff00001111',
        state: SyncDeviceFootprintState.active,
        name: 'iPhone',
      ),
    ]);

    expect(find.text('iPhone (aaaabbbb)'), findsOneWidget);
    expect(find.text('iPhone (eeeeffff)'), findsOneWidget);
    expect(
      find.text('iPhone'),
      findsNothing,
      reason: 'two rows a user cannot tell apart is the thing being fixed',
    );
  });

  testWidgets('leaves a unique name alone', (tester) async {
    await pump(tester, [
      device(
        id: 'aaaabbbbccccdddd',
        state: SyncDeviceFootprintState.active,
        name: "Eric's Pixel",
      ),
      device(
        id: 'eeeeffff00001111',
        state: SyncDeviceFootprintState.active,
        name: 'ERIC-PC',
      ),
    ]);

    expect(find.text("Eric's Pixel"), findsOneWidget);
    expect(find.text('ERIC-PC'), findsOneWidget);
  });

  test('duplicatedSyncDeviceNames reports only names published twice', () {
    final duplicated = duplicatedSyncDeviceNames([
      device(id: 'a', state: SyncDeviceFootprintState.active, name: 'iPhone'),
      device(id: 'b', state: SyncDeviceFootprintState.active, name: 'iPhone'),
      device(id: 'c', state: SyncDeviceFootprintState.active, name: 'ERIC-PC'),
      // Unnamed devices already carry their id, and null is not a name two
      // devices can be said to share.
      device(id: 'd', state: SyncDeviceFootprintState.retired),
      device(id: 'e', state: SyncDeviceFootprintState.retired),
    ]);

    expect(duplicated, {'iPhone'});
  });
}
