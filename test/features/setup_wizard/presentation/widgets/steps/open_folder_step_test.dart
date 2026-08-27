import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/domain/entities/storage_config.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/database_location_service.dart';
import 'package:submersion/core/services/database_migration_service.dart';
import 'package:submersion/features/settings/presentation/providers/storage_providers.dart';
import 'package:submersion/features/setup_wizard/presentation/widgets/steps/open_folder_step.dart';

import '../../../../../helpers/test_app.dart';

/// Minimal fake so the step's folder-adoption flow can be driven without a
/// real picker or database. Only the three methods the step calls are
/// implemented; everything else is unused.
class _FakeStorageNotifier extends StateNotifier<StorageConfigState>
    implements StorageConfigNotifier {
  _FakeStorageNotifier()
    : super(const StorageConfigState(config: StorageConfig()));

  FolderPickResultWithBookmark? pickResult;
  ExistingDatabaseInfo? existingInfo;
  MigrationResult? switchResult;

  @override
  Future<FolderPickResultWithBookmark?> pickCustomFolder({
    Object? chooser,
  }) async => pickResult;

  @override
  Future<ExistingDatabaseInfo?> checkForExistingDatabase(
    String folderPath,
  ) async => existingInfo;

  @override
  Future<MigrationResult> switchToExistingDatabase(String folderPath) async =>
      switchResult!;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _existing = ExistingDatabaseInfo(
  path: '/tmp/x/submersion.db',
  userCount: 1,
  diveCount: 5,
  siteCount: 2,
  tripCount: 0,
  buddyCount: 0,
  fileSize: 1024,
);

void main() {
  late _FakeStorageNotifier fake;

  setUp(() => fake = _FakeStorageNotifier());

  Widget build() => testApp(
    overrides: [storageConfigNotifierProvider.overrideWith((ref) => fake)],
    child: const OpenFolderStep(),
  );

  testWidgets('idle shows the choose-folder button', (tester) async {
    await tester.pumpWidget(build());
    expect(find.text('Choose folder'), findsOneWidget);
  });

  testWidgets('cancelled folder pick returns to idle', (tester) async {
    fake.pickResult = null;
    await tester.pumpWidget(build());
    await tester.tap(find.text('Choose folder'));
    await tester.pumpAndSettle();
    expect(find.text('Choose folder'), findsOneWidget);
  });

  testWidgets('folder without a database shows the not-found message', (
    tester,
  ) async {
    fake.pickResult = const FolderPickResultWithBookmark(path: '/tmp/x');
    fake.existingInfo = null;
    await tester.pumpWidget(build());
    await tester.tap(find.text('Choose folder'));
    await tester.pumpAndSettle();
    expect(
      find.text('The selected folder does not contain a Submersion database.'),
      findsOneWidget,
    );
  });

  testWidgets('existing database + success surfaces no error', (tester) async {
    fake.pickResult = const FolderPickResultWithBookmark(path: '/tmp/x');
    fake.existingInfo = _existing;
    fake.switchResult = MigrationResult.success(
      oldPath: '/a',
      newPath: '/tmp/x',
    );
    await tester.pumpWidget(build());
    await tester.tap(find.text('Choose folder'));
    await tester.pumpAndSettle();
    // restartApp() was invoked (harmless ValueNotifier bump); no error shown.
    expect(find.textContaining('does not contain'), findsNothing);
  });

  testWidgets('switch failure shows the error message', (tester) async {
    fake.pickResult = const FolderPickResultWithBookmark(path: '/tmp/x');
    fake.existingInfo = _existing;
    fake.switchResult = MigrationResult.failure('disk error');
    await tester.pumpWidget(build());
    await tester.tap(find.text('Choose folder'));
    await tester.pumpAndSettle();
    expect(find.text('disk error'), findsOneWidget);
  });
}
