import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/services/database_location_service.dart';

import '../../helpers/mock_file_picker_platform.dart';

/// A picker whose directory dialog blows up rather than returning a path --
/// the shape of a missing or broken XDG desktop portal on Linux (#218).
class _ExplodingDirectoryPicker extends MockFilePickerPlatform {
  @override
  Future<String?> getDirectoryPath({
    String? dialogTitle,
    String? initialDirectory,
    AndroidOptions androidOptions = const AndroidOptions(),
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async {
    throw StateError('no XDG desktop portal');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FilePickerPlatform originalPicker;

  setUp(() {
    originalPicker = FilePickerPlatform.instance;
  });

  tearDown(() {
    FilePickerPlatform.instance = originalPicker;
  });

  Future<DatabaseLocationService> service() async {
    SharedPreferences.setMockInitialValues({});
    return DatabaseLocationService(await SharedPreferences.getInstance());
  }

  group('FolderPickException', () {
    test('toString names the type and carries the message', () {
      // Wrapped the same way the service wraps a thrown picker, so the
      // rendered text here is what a log or SnackBar actually shows.
      final cause = StateError('no XDG desktop portal');
      final exception = FolderPickException('$cause');

      expect(exception.message, 'Bad state: no XDG desktop portal');
      expect(
        exception.toString(),
        'FolderPickException: Bad state: no XDG desktop portal',
      );
    });
  });

  group('pickCustomFolder (#218)', () {
    test('a cancelled picker returns null, not an exception', () async {
      FilePickerPlatform.instance = MockFilePickerPlatform()
        ..directoryPathResult = null;

      expect(await (await service()).pickCustomFolder(), isNull);
    });

    test('a chosen folder is returned', () async {
      FilePickerPlatform.instance = MockFilePickerPlatform()
        ..directoryPathResult = '/tmp/chosen';

      final result = await (await service()).pickCustomFolder();

      expect(result, isNotNull);
      expect(result!.path, '/tmp/chosen');
    });

    test('a THROWN picker surfaces as FolderPickException so the caller can '
        'tell a broken portal from a user cancel', () async {
      FilePickerPlatform.instance = _ExplodingDirectoryPicker();

      Object? caught;
      StackTrace? caughtStack;
      try {
        await (await service()).pickCustomFolder();
        fail('pickCustomFolder should have rethrown as FolderPickException');
      } catch (e, s) {
        caught = e;
        caughtStack = s;
      }

      expect(caught, isA<FolderPickException>());
      expect(
        (caught as FolderPickException).message,
        'Bad state: no XDG desktop portal',
        reason: 'the original failure text must reach the UI',
      );
      expect(
        caught.toString(),
        'FolderPickException: Bad state: no XDG desktop portal',
      );
      // Error.throwWithStackTrace keeps the ORIGINAL stack, so logs point
      // at the failing picker call rather than at the rethrow site.
      expect(
        caughtStack.toString(),
        contains('_ExplodingDirectoryPicker.getDirectoryPath'),
      );
    });
  });
}
