// Coverage for the tab-shell branches in PhotoPickerPage.build():
//   - When mediaPickerHiddenTabsProvider == false → simple Scaffold body.
//   - When mediaPickerHiddenTabsProvider == true  → DefaultTabController
//     with Gallery / Files / URL tabs and the _PlaceholderTab in the
//     non-Gallery slots.

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/data/services/photo_picker_service.dart';
import 'package:submersion/features/media/presentation/pages/photo_picker_page.dart';
import 'package:submersion/features/media/presentation/providers/media_resolver_providers.dart';
import 'package:submersion/features/media/presentation/providers/photo_picker_providers.dart';
import 'package:submersion/features/media/presentation/widgets/files_tab.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

class _StubPhotoPickerService implements PhotoPickerService {
  @override
  bool get supportsGalleryBrowsing => true;
  @override
  Future<List<AssetInfo>> getAssetsInDateRange(DateTime s, DateTime e) async =>
      const [];
  @override
  Future<Uint8List?> getThumbnail(String assetId, {int size = 200}) async =>
      null;
  @override
  Future<Uint8List?> getFileBytes(String assetId) async => null;
  @override
  Future<PhotoPermissionStatus> checkPermission() async =>
      PhotoPermissionStatus.denied;
  @override
  Future<PhotoPermissionStatus> requestPermission() async =>
      PhotoPermissionStatus.denied;
  @override
  Future<String?> getFilePath(String assetId) async => null;
}

Widget _wrap({required bool showHiddenTabs}) {
  return ProviderScope(
    overrides: [
      photoPickerServiceProvider.overrideWithValue(_StubPhotoPickerService()),
      mediaPickerHiddenTabsProvider.overrideWith((ref) => showHiddenTabs),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: PhotoPickerPage(
        startTime: DateTime.utc(2024, 1, 1, 9),
        endTime: DateTime.utc(2024, 1, 1, 11),
      ),
    ),
  );
}

void main() {
  testWidgets(
    'renders single Scaffold (no tabs) when mediaPickerHiddenTabsProvider is false',
    (tester) async {
      await tester.pumpWidget(_wrap(showHiddenTabs: false));
      await tester.pump();

      expect(find.byType(TabBar), findsNothing);
      expect(find.byType(DefaultTabController), findsNothing);
    },
  );

  testWidgets(
    'renders DefaultTabController with Gallery / Files / URL tabs when mediaPickerHiddenTabsProvider is true',
    (tester) async {
      await tester.pumpWidget(_wrap(showHiddenTabs: true));
      await tester.pump();

      expect(find.byType(DefaultTabController), findsOneWidget);
      expect(find.byType(TabBar), findsOneWidget);
      expect(find.text('Gallery'), findsOneWidget);
      expect(find.text('Files'), findsOneWidget);
      expect(find.text('URL'), findsOneWidget);
    },
  );

  testWidgets('switching to Files tab shows FilesTab', (tester) async {
    await tester.pumpWidget(_wrap(showHiddenTabs: true));
    await tester.pump();

    await tester.tap(find.text('Files'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.byType(FilesTab), findsOneWidget);
  });

  testWidgets('switching to URL tab shows Phase 3 placeholder', (tester) async {
    await tester.pumpWidget(_wrap(showHiddenTabs: true));
    await tester.pump();

    await tester.tap(find.text('URL'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('Coming in Phase 3'), findsOneWidget);
  });
}
