import 'package:flutter/foundation.dart'
    show debugDefaultTargetPlatformOverride;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/features/import_wizard/data/adapters/universal_adapter.dart';
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
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
  });

  /// Rebuilds the container with the folder-writability probe answering
  /// [writable]. The real probe touches the filesystem, and a `testWidgets`
  /// body never completes real IO, so an injected answer is the only way to
  /// drive the picker path here.
  void answerProbe(bool writable) {
    container.dispose();
    container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        universalImportNotifierProvider.overrideWith(
          (ref) => UniversalImportNotifier(
            ref,
            folderWriteProbe: (_) async => writable,
          ),
        ),
      ],
    );
  }

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

  void seedBundled(int count) {
    final notifier = container.read(universalImportNotifierProvider.notifier);
    notifier.state = notifier.state.copyWith(
      payload: const ImportPayload(entities: {}),
      photoPathsByBaseName: {
        'dive1': [for (var i = 0; i < count; i++) '/tmp/x/p$i.jpg'],
      },
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

  testWidgets('shows the bundled count and asks where to save them', (
    tester,
  ) async {
    await withPlatform(TargetPlatform.macOS, () async {
      seedBundled(3);

      await tester.pumpWidget(host(const PhotoFolderStep()));
      await tester.pump();

      expect(find.text('3 photos bundled in the archive'), findsOneWidget);
      expect(find.text('Choose where to save photos...'), findsOneWidget);
      expect(find.textContaining('never keeps its own copy'), findsOneWidget);
      // No referenced photos, so no folder-to-resolve question.
      expect(find.text('Choose photo folder...'), findsNothing);
    });
  });

  group('photos a remote source will download', () {
    void seedRemote(int count) {
      final notifier = container.read(universalImportNotifierProvider.notifier);
      notifier.state = notifier.state.copyWith(
        payload: ImportPayload(
          entities: {
            ImportEntityType.dives: [
              {'sourceUuid': 'divelogs-1', 'dateTime': DateTime(2025, 1, 15)},
            ],
          },
        ),
        remotePhotoCount: count,
      );
    }

    test('put the Photos step in front of the user', () {
      seedRemote(5);
      expect(container.read(universalAdapterNoPhotosProvider), isFalse);
      expect(container.read(universalAdapterPhotosReadyProvider), isFalse);
    });

    test('are ready once a destination is chosen', () async {
      answerProbe(true);
      seedRemote(5);
      expect(container.read(universalAdapterPhotosReadyProvider), isFalse);
      await container
          .read(universalImportNotifierProvider.notifier)
          .chooseBundledPhotoFolder('/Users/eric/Pictures/Dives');
      expect(container.read(universalAdapterPhotosReadyProvider), isTrue);
    });

    testWidgets('are counted as downloads and ask where to save them', (
      tester,
    ) async {
      await withPlatform(TargetPlatform.macOS, () async {
        seedRemote(5);

        await tester.pumpWidget(host(const PhotoFolderStep()));
        await tester.pump();

        expect(find.text('5 photos to download'), findsOneWidget);
        expect(find.textContaining('bundled in the archive'), findsNothing);
        expect(find.text('Choose where to save photos...'), findsOneWidget);
      });
    });
  });

  testWidgets('picking a destination records it on the state', (tester) async {
    const dest = '/Users/eric/Pictures/Dives';
    await withPlatform(TargetPlatform.macOS, () async {
      answerProbe(true);
      seedBundled(1);

      await tester.pumpWidget(
        host(PhotoFolderStep(pickDestinationOverride: () async => dest)),
      );
      await tester.pump();

      await tester.tap(find.text('Choose where to save photos...'));
      await tester.pump();

      expect(find.text(dest), findsOneWidget);
      expect(
        container.read(universalImportNotifierProvider).bundledPhotoFolderPath,
        dest,
      );
    });
  });

  testWidgets('skipping clears a chosen destination', (tester) async {
    await withPlatform(TargetPlatform.macOS, () async {
      seedBundled(1);
      final notifier = container.read(universalImportNotifierProvider.notifier);
      notifier.state = notifier.state.copyWith(bundledPhotoFolderPath: '/x');

      await tester.pumpWidget(host(const PhotoFolderStep()));
      await tester.pump();

      await tester.tap(find.text('Skip photos'));
      await tester.pump();

      final state = container.read(universalImportNotifierProvider);
      expect(state.photosSkipped, isTrue);
      expect(state.bundledPhotoFolderPath, isNull);
    });
  });

  testWidgets('states the mobile limitation once for bundled photos', (
    tester,
  ) async {
    await withPlatform(TargetPlatform.iOS, () async {
      seedBundled(2);

      await tester.pumpWidget(host(const PhotoFolderStep()));
      await tester.pump();

      expect(find.text('Choose where to save photos...'), findsNothing);
      expect(
        find.textContaining('Run this import on a computer'),
        findsOneWidget,
      );
      expect(find.text('2 photos bundled in the archive'), findsOneWidget);
    });
  });

  testWidgets('shows the scanning state while a folder resolves', (
    tester,
  ) async {
    await withPlatform(TargetPlatform.macOS, () async {
      seedPictures(1);
      final notifier = container.read(universalImportNotifierProvider.notifier);
      notifier.state = notifier.state.copyWith(isLoading: true);

      await tester.pumpWidget(host(const PhotoFolderStep()));
      await tester.pump();

      expect(find.text('Scanning folder...'), findsOneWidget);
      expect(find.text('Choose photo folder...'), findsNothing);
    });
  });

  testWidgets('an unwritable destination is refused with a message', (
    tester,
  ) async {
    await withPlatform(TargetPlatform.macOS, () async {
      answerProbe(false);
      seedBundled(1);

      await tester.pumpWidget(
        host(const PhotoFolderStep(pickDestinationOverride: _pickUnwritable)),
      );
      await tester.pump();

      await tester.tap(find.text('Choose where to save photos...'));
      await tester.pump();

      expect(
        container.read(universalImportNotifierProvider).bundledPhotoFolderPath,
        isNull,
      );
      expect(
        find.text("That folder can't be written to. Choose another one."),
        findsOneWidget,
      );
    });
  });

  testWidgets('mobile explains the limitation once for both kinds', (
    tester,
  ) async {
    await withPlatform(TargetPlatform.iOS, () async {
      final notifier = container.read(universalImportNotifierProvider.notifier);
      notifier.state = notifier.state.copyWith(
        payload: ImportPayload(
          entities: {
            ImportEntityType.dives: [
              {'uddfId': 'd0', 'dateTime': DateTime(2025, 1, 15)},
            ],
            ImportEntityType.media: [
              {'filename': '/p/a.jpg', '_diveIndex': 0},
            ],
          },
        ),
        photoPathsByBaseName: const {
          'dive1': ['/tmp/x/p0.jpg'],
        },
      );

      await tester.pumpWidget(host(const PhotoFolderStep()));
      await tester.pump();

      // Both counts are stated, so nothing is silently dropped, and the
      // explanation appears once rather than under each heading.
      expect(find.text('1 photo referenced in this logbook'), findsOneWidget);
      expect(find.text('1 photo bundled in the archive'), findsOneWidget);
      expect(
        find.textContaining('Run this import on a computer'),
        findsOneWidget,
      );
    });
  });
}

Future<String?> _pickUnwritable() async => '/somewhere/read-only';
