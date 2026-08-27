import 'package:flutter/foundation.dart'
    show debugDefaultTargetPlatformOverride;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/features/import_wizard/presentation/widgets/photo_folder_step.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/models/import_payload.dart';
import 'package:submersion/features/universal_import/domain/services/import_media_resolver.dart';
import 'package:submersion/features/universal_import/presentation/providers/universal_import_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// These tests never let the resolver touch the filesystem. Its real IO does
/// not progress inside testWidgets' fake-async zone, and driving a tap from
/// inside `runAsync` to work around that deadlocks the binding. Resolution is
/// covered end to end by import_media_resolver_test.dart; here the resolution
/// is seeded directly so the widget's rendering is what is under test.
void main() {
  late ProviderContainer container;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
  });

  tearDown(() {
    container.dispose();
  });

  /// Sets the platform for [body] and always clears it again.
  ///
  /// The binding asserts every foundation debug variable is unset at the end
  /// of the TEST BODY, before tearDown runs, so clearing it in tearDown is
  /// too late. The finally also keeps one failing expectation from cascading
  /// into every later test in the file.
  Future<void> withPlatform(
    TargetPlatform platform,
    Future<void> Function() body,
  ) async {
    debugDefaultTargetPlatformOverride = platform;
    try {
      await body();
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  }

  void seedPictures(int count) {
    final notifier = container.read(universalImportNotifierProvider.notifier);
    notifier.state = notifier.state.copyWith(
      payload: ImportPayload(
        entities: {
          ImportEntityType.dives: [
            {'uddfId': 'd0', 'dateTime': DateTime(2025, 1, 15)},
          ],
          ImportEntityType.media: [
            for (var i = 0; i < count; i++)
              {'filename': '/home/jai/Pictures/p$i.jpg', '_diveIndex': 0},
          ],
        },
      ),
    );
  }

  Widget host(Widget child) {
    return UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        // Pin the locale: an unpinned host adopts the test device locale and
        // the string assertions below stop matching.
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: child),
      ),
    );
  }

  testWidgets('shows the referenced count and a folder button', (tester) async {
    await withPlatform(TargetPlatform.macOS, () async {
      seedPictures(1);

      await tester.pumpWidget(host(const PhotoFolderStep()));
      await tester.pump();

      expect(find.text('1 photo referenced in this logbook'), findsOneWidget);
      expect(find.text('Choose photo folder...'), findsOneWidget);
    });
  });

  testWidgets('pluralises the referenced count', (tester) async {
    await withPlatform(TargetPlatform.macOS, () async {
      seedPictures(2);

      await tester.pumpWidget(host(const PhotoFolderStep()));
      await tester.pump();

      expect(find.text('2 photos referenced in this logbook'), findsOneWidget);
    });
  });

  testWidgets('renders the match summary and the picked folder', (
    tester,
  ) async {
    await withPlatform(TargetPlatform.macOS, () async {
      seedPictures(5);
      final notifier = container.read(universalImportNotifierProvider.notifier);
      notifier.state = notifier.state.copyWith(
        photoFolderPath: '/Users/eric/Photos',
        photoResolution: const ImportMediaResolution(
          resolvedPathByIndex: {0: '/a', 1: '/b', 2: '/c'},
          reRootedCount: 2,
          filenameOnlyCount: 1,
          notFoundCount: 2,
        ),
      );

      await tester.pumpWidget(host(const PhotoFolderStep()));
      await tester.pump();

      expect(
        find.text('3 matched, 1 by filename only, 2 not found'),
        findsOneWidget,
      );
      expect(find.text('/Users/eric/Photos'), findsOneWidget);
    });
  });

  testWidgets('a cancelled folder pick leaves the step untouched', (
    tester,
  ) async {
    await withPlatform(TargetPlatform.macOS, () async {
      seedPictures(1);

      await tester.pumpWidget(
        host(PhotoFolderStep(pickFolderOverride: () async => null)),
      );
      await tester.pump();

      await tester.tap(find.text('Choose photo folder...'));
      await tester.pump();

      expect(find.text('Choose photo folder...'), findsOneWidget);
      expect(
        container.read(universalImportNotifierProvider).photoResolution,
        isNull,
      );
    });
  });

  testWidgets('offers to skip photos and records the choice', (tester) async {
    await withPlatform(TargetPlatform.macOS, () async {
      seedPictures(1);

      await tester.pumpWidget(host(const PhotoFolderStep()));
      await tester.pump();

      await tester.tap(find.text('Skip photos'));
      await tester.pump();

      expect(
        container.read(universalImportNotifierProvider).photosSkipped,
        isTrue,
      );
    });
  });

  testWidgets('explains the limitation instead of picking on mobile', (
    tester,
  ) async {
    await withPlatform(TargetPlatform.android, () async {
      seedPictures(1);

      await tester.pumpWidget(host(const PhotoFolderStep()));
      await tester.pump();

      expect(find.text('Choose photo folder...'), findsNothing);
      expect(
        find.textContaining('Run this import on a computer'),
        findsOneWidget,
      );
      // The count is still stated, so nothing is silently dropped.
      expect(find.text('1 photo referenced in this logbook'), findsOneWidget);
    });
  });
}
