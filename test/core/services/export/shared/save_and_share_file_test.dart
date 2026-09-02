import 'dart:io';
import 'dart:ui' show Rect;

import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:share_plus_platform_interface/share_plus_platform_interface.dart';
import 'package:submersion/core/services/export/export_service.dart';
import 'package:submersion/core/services/export/shared/file_export_utils.dart';

/// The share helpers write into getApplicationDocumentsDirectory(), a platform
/// channel with no implementation under flutter_test. Unstubbed it never
/// completes and the await hangs forever.
class _FakePathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _FakePathProvider(this.documentsPath);
  final String documentsPath;

  @override
  Future<String?> getApplicationDocumentsPath() async => documentsPath;
}

/// Records what reached the platform so the anchor can be asserted without a
/// real share sheet.
class _FakeSharePlatform extends SharePlatform {
  final List<ShareParams> calls = [];

  @override
  Future<ShareResult> share(ShareParams params) async {
    calls.add(params);
    return const ShareResult('ok', ShareResultStatus.success);
  }
}

void main() {
  late Directory documents;
  final platform = _FakeSharePlatform();

  // SharePlus.instance is a `static final` that captures SharePlatform.instance
  // the first time it is read and keeps it for the life of the isolate, so the
  // fake has to be in place before the first share.
  setUpAll(() => SharePlatform.instance = platform);

  setUp(() {
    documents = Directory.systemTemp.createTempSync('save_and_share_file_test');
    PathProviderPlatform.instance = _FakePathProvider(documents.path);
    platform.calls.clear();
  });

  tearDown(() => documents.deleteSync(recursive: true));

  const anchor = Rect.fromLTWH(12, 34, 56, 78);

  test('saveAndShareFile forwards the anchor to the share sheet', () async {
    await saveAndShareFile(
      '<uddf/>',
      'dives.uddf',
      'application/xml',
      sharePositionOrigin: anchor,
    );

    expect(platform.calls.single.sharePositionOrigin, anchor);
  });

  test(
    'saveAndShareFileBytes forwards the anchor to the share sheet',
    () async {
      await saveAndShareFileBytes(
        [1, 2, 3],
        'dives.xlsx',
        'application/vnd.ms-excel',
        sharePositionOrigin: anchor,
      );

      expect(platform.calls.single.sharePositionOrigin, anchor);
    },
  );

  test('sharePdfBytes forwards the anchor to the share sheet', () async {
    await sharePdfBytes([1, 2, 3], 'logbook.pdf', sharePositionOrigin: anchor);

    expect(platform.calls.single.sharePositionOrigin, anchor);
  });

  test('exportImageAsPng forwards the anchor to the share sheet', () async {
    await exportImageAsPng(
      [1, 2, 3],
      'profile.png',
      sharePositionOrigin: anchor,
    );

    expect(platform.calls.single.sharePositionOrigin, anchor);
  });

  test('an omitted anchor leaves the platform to place the popover', () async {
    // Callers with no BuildContext (the settings export chain, the debug log
    // provider) must keep working. share_plus centres the popover itself when
    // the origin is absent, so null is a supported value, not a bug.
    await saveAndShareFile('<uddf/>', 'dives.uddf', 'application/xml');

    expect(platform.calls.single.sharePositionOrigin, isNull);
  });

  group('ExportService pass-throughs', () {
    // These two are one-line delegates, which is exactly why the anchor can
    // reach them from the dive detail page at all. A delegate that forgets to
    // forward the argument still compiles and silently re-centres the popover.
    test('exportImageAsPng forwards the anchor', () async {
      await ExportService().exportImageAsPng(
        [1, 2, 3],
        'profile.png',
        sharePositionOrigin: anchor,
      );

      expect(platform.calls.single.sharePositionOrigin, anchor);
    });

    test('sharePdfBytes forwards the anchor', () async {
      await ExportService().sharePdfBytes(
        [1, 2, 3],
        'logbook.pdf',
        sharePositionOrigin: anchor,
      );

      expect(platform.calls.single.sharePositionOrigin, anchor);
    });
  });
}
