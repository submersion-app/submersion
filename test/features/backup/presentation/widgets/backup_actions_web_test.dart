import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/platform/device_capabilities.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/backup/presentation/providers/backup_providers.dart';
import 'package:submersion/features/backup/presentation/widgets/backup_actions.dart';

import '../../../../helpers/test_app.dart';

class _IdleBackupOp extends StateNotifier<BackupOperationState>
    implements BackupOperationNotifier {
  _IdleBackupOp() : super(const BackupOperationState());
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Restoring from a file swaps the database for one the user picked, which
/// a browser cannot do (issue #4121): the tile is not offered there.
void main() {
  Future<void> pump(WidgetTester tester, {bool browser = false}) async {
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        overrides: [
          backupOperationProvider.overrideWith((ref) => _IdleBackupOp()),
          if (browser)
            deviceCapabilitiesProvider.overrideWithValue(
              DeviceCapabilities.web,
            ),
        ],
        child: const RestoreFromFileTile(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('natively offers to restore from a file', (tester) async {
    await pump(tester);
    expect(find.text('Restore from a file'), findsOneWidget);
  });

  testWidgets('a browser has no file to restore from', (tester) async {
    await pump(tester, browser: true);
    expect(find.text('Restore from a file'), findsNothing);
    expect(find.byType(ListTile), findsNothing);
  });
}
