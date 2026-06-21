import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/services/database_location_service.dart';
import 'package:submersion/core/services/database_migration_service.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/settings/presentation/providers/storage_providers.dart';

/// Records every assignment to [externalVolumeChooser] so the wrapper's
/// set-then-clear-in-finally contract can be asserted, and short-circuits the
/// underlying pick.
class _SpyLocationService extends DatabaseLocationService {
  _SpyLocationService(super.prefs);

  final chooserAssignments = <Object?>[];

  @override
  set externalVolumeChooser(
    Future<ExternalVolumeOption?> Function(List<ExternalVolumeOption>)? chooser,
  ) => chooserAssignments.add(chooser);

  @override
  Future<FolderPickResultWithBookmark?> pickCustomFolder() async => null;
}

Future<ExternalVolumeOption?> _chooser(List<ExternalVolumeOption> o) async =>
    o.first;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('pickCustomFolder sets the chooser then clears it in finally', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final spy = _SpyLocationService(prefs);
    final notifier = StorageConfigNotifier(
      spy,
      DatabaseMigrationService(DatabaseService.instance, spy),
    );

    final result = await notifier.pickCustomFolder(chooser: _chooser);

    expect(result, isNull);
    // First the chooser is installed, then cleared to null in the finally.
    expect(spy.chooserAssignments, hasLength(2));
    expect(spy.chooserAssignments.first, isNotNull);
    expect(spy.chooserAssignments.last, isNull);
  });
}
