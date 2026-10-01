import 'dart:io';
import 'dart:typed_data';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;
import 'package:submersion/core/models/log_entry.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/media/domain/value_objects/media_attach_target.dart';
import 'package:submersion/features/media/presentation/helpers/media_drop_destination.dart';
import 'package:submersion/features/media/presentation/providers/photo_picker_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/global_drop_target.dart';

/// Platform variant that runs tests as macOS (desktop).
const _macOS = TargetPlatformVariant({TargetPlatform.macOS});

/// One call the drop target made to its media importer.
typedef _MediaDrop = ({MediaDropDestination destination, List<String> paths});

/// Build a test app that places [GlobalDropTarget] inside a GoRouter.
///
/// Media drops are recorded into [mediaDrops] instead of opening the photo
/// picker, which flutter_test cannot drive. The routes that take media carry
/// the production route names, which is what the drop target keys on.
Widget _buildTestApp({
  String initialLocation = '/home',
  List<_MediaDrop>? mediaDrops,
  ProviderContainer? container,
}) {
  final router = GoRouter(
    initialLocation: initialLocation,
    routes: [
      ShellRoute(
        builder: (context, state, child) => Scaffold(
          body: GlobalDropTarget(
            onMediaDrop: (context, ref, destination, paths) async {
              mediaDrops?.add((destination: destination, paths: paths));
            },
            child: child,
          ),
        ),
        routes: [
          GoRoute(
            path: '/home',
            builder: (context, state) => const Text('Home Content'),
          ),
          GoRoute(
            path: '/media',
            name: 'media',
            builder: (context, state) => const Text('Media Content'),
          ),
          GoRoute(
            path: '/dives/:diveId',
            name: 'diveDetail',
            builder: (context, state) => const Text('Dive Content'),
          ),
          GoRoute(
            path: '/transfer/import-wizard',
            builder: (context, state) => const Text('Import Wizard'),
          ),
        ],
      ),
    ],
  );

  final app = MaterialApp.router(
    routerConfig: router,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    // The tests match English snackbar text.
    locale: const Locale('en'),
  );
  return container == null
      ? ProviderScope(child: app)
      : UncontrolledProviderScope(container: container, child: app);
}

/// Trigger [onDragDone] and wait for the full async [_handleDrop] chain to
/// resolve. Uses [tester.runAsync] to let all microtasks (readAsBytes,
/// loadFileFromBytes, setState) complete in the real async zone, then pumps
/// the widget tree for navigation and snackbar UI updates.
Future<void> _triggerDrop(WidgetTester tester, DropDoneDetails details) async {
  final dropTarget = tester.widget<DropTarget>(find.byType(DropTarget));
  await tester.runAsync(() async {
    dropTarget.onDragDone?.call(details);
    await Future<void>.delayed(const Duration(milliseconds: 500));
  });
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// Temp directory backing the dropped test files, recreated per test.
late Directory _tempDir;

/// Write [bytes] to a real file named [name] under [_tempDir] and return a
/// [DropItemFile] pointing at that path.
///
/// The widget reads dropped files via `File(path).readAsBytes()` (matching a
/// real desktop drop, where every dropped item is a file on disk), so the test
/// double must be a real file rather than in-memory data.
DropItemFile _dropItemFromBytes(Uint8List bytes, String name) {
  final file = File(p.join(_tempDir.path, name))..writeAsBytesSync(bytes);
  return DropItemFile(file.path);
}

/// UDDF XML content recognised by the format detector.
final _uddfBytes = Uint8List.fromList(
  '<?xml version="1.0"?><uddf version="3.2.0"></uddf>'.codeUnits,
);

/// PNG magic bytes -- not a supported dive-log format.
final _pngBytes = Uint8List.fromList([
  0x89,
  0x50,
  0x4E,
  0x47,
  0x0D,
  0x0A,
  0x1A,
  0x0A,
]);

/// CSV with dive-related headers recognised by the format detector.
final _csvBytes = Uint8List.fromList(
  'dive number,date,max depth,bottom time,water temp\n'
          '1,2024-01-01,30.0,45,22.0\n'
      .codeUnits,
);

/// FIT file header with magic bytes.
final _fitBytes = () {
  final b = Uint8List(14);
  b[0] = 14; // header size
  b[8] = 0x2E; // .
  b[9] = 0x46; // F
  b[10] = 0x49; // I
  b[11] = 0x54; // T
  return b;
}();

void main() {
  group('GlobalDropTarget', () {
    setUp(() {
      _tempDir = Directory.systemTemp.createTempSync('global_drop_target_test');
    });

    tearDown(() {
      if (_tempDir.existsSync()) {
        _tempDir.deleteSync(recursive: true);
      }
    });

    testWidgets('renders child content on desktop', variant: _macOS, (
      tester,
    ) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      expect(find.text('Home Content'), findsOneWidget);
    });

    testWidgets('wraps child with DropTarget on desktop', variant: _macOS, (
      tester,
    ) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      expect(find.byType(DropTarget), findsOneWidget);
    });

    testWidgets('shows frosted overlay on drag enter', variant: _macOS, (
      tester,
    ) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      final dropTarget = tester.widget<DropTarget>(find.byType(DropTarget));
      dropTarget.onDragEntered?.call(
        DropEventDetails(
          localPosition: Offset.zero,
          globalPosition: Offset.zero,
        ),
      );
      await tester.pump();

      expect(find.text('Drop to Import'), findsOneWidget);
      expect(find.text('Release to open import wizard'), findsOneWidget);
      expect(find.byIcon(Icons.upload_file), findsOneWidget);
    });

    testWidgets('hides overlay on drag exit', variant: _macOS, (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      final dropTarget = tester.widget<DropTarget>(find.byType(DropTarget));

      dropTarget.onDragEntered?.call(
        DropEventDetails(
          localPosition: Offset.zero,
          globalPosition: Offset.zero,
        ),
      );
      await tester.pump();
      expect(find.text('Drop to Import'), findsOneWidget);

      dropTarget.onDragExited?.call(
        DropEventDetails(
          localPosition: Offset.zero,
          globalPosition: Offset.zero,
        ),
      );
      await tester.pump();
      expect(find.text('Drop to Import'), findsNothing);
    });

    testWidgets('clears dragging state on drop', variant: _macOS, (
      tester,
    ) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      final dropTarget = tester.widget<DropTarget>(find.byType(DropTarget));

      dropTarget.onDragEntered?.call(
        DropEventDetails(
          localPosition: Offset.zero,
          globalPosition: Offset.zero,
        ),
      );
      await tester.pump();
      expect(find.text('Drop to Import'), findsOneWidget);

      dropTarget.onDragDone?.call(
        const DropDoneDetails(
          files: [],
          localPosition: Offset.zero,
          globalPosition: Offset.zero,
        ),
      );
      await tester.pump();
      expect(find.text('Drop to Import'), findsNothing);
    });

    testWidgets('empty drop is a no-op (no navigation)', variant: _macOS, (
      tester,
    ) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      final dropTarget = tester.widget<DropTarget>(find.byType(DropTarget));
      dropTarget.onDragDone?.call(
        const DropDoneDetails(
          files: [],
          localPosition: Offset.zero,
          globalPosition: Offset.zero,
        ),
      );
      await tester.pump();

      expect(find.text('Home Content'), findsOneWidget);
    });

    testWidgets(
      'shows error snackbar when wizard is already active',
      variant: _macOS,
      (tester) async {
        await tester.pumpWidget(
          _buildTestApp(initialLocation: '/transfer/import-wizard'),
        );
        await tester.pumpAndSettle();

        // Wizard-active path returns before readAsBytes, so any XFile works.
        await _triggerDrop(
          tester,
          DropDoneDetails(
            files: [_dropItemFromBytes(_uddfBytes, 'test.uddf')],
            localPosition: Offset.zero,
            globalPosition: Offset.zero,
          ),
        );

        expect(find.text('Finish current import first'), findsOneWidget);
      },
    );

    testWidgets('logs the read failure, naming the file', variant: _macOS, (
      tester,
    ) async {
      final captured = <LogEntry>[];
      final sub = LoggerService.logStream.listen(captured.add);
      addTearDown(sub.cancel);
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();
      final missing = p.join(_tempDir.path, 'gone.uddf');

      await _triggerDrop(
        tester,
        DropDoneDetails(
          files: [DropItemFile(missing)],
          localPosition: Offset.zero,
          globalPosition: Offset.zero,
        ),
      );

      // The snackbar alone left a bug report with no trace of the cause
      // (#2715).
      expect(find.text('Could not read file'), findsOneWidget);
      expect(
        captured.where(
          (e) => e.level == LogLevel.warning && e.message.contains(missing),
        ),
        isNotEmpty,
      );
    });

    testWidgets(
      'shows error snackbar when file cannot be read',
      variant: _macOS,
      (tester) async {
        await tester.pumpWidget(_buildTestApp());
        await tester.pumpAndSettle();

        // XFile with no bytes AND a non-existent path -> readAsBytes throws.
        // Uses runAsync so the real I/O exception can propagate.
        await tester.runAsync(() async {
          final dropTarget = tester.widget<DropTarget>(find.byType(DropTarget));
          dropTarget.onDragDone?.call(
            DropDoneDetails(
              files: [DropItemFile('/nonexistent/path/file.uddf')],
              localPosition: Offset.zero,
              globalPosition: Offset.zero,
            ),
          );
          await Future<void>.delayed(const Duration(milliseconds: 200));
        });
        await tester.pump();

        expect(find.text('Could not read file'), findsOneWidget);
      },
    );

    testWidgets(
      'shows error snackbar for unsupported file format',
      variant: _macOS,
      (tester) async {
        await tester.pumpWidget(_buildTestApp());
        await tester.pumpAndSettle();

        await _triggerDrop(
          tester,
          DropDoneDetails(
            files: [_dropItemFromBytes(_pngBytes, 'notes.bin')],
            localPosition: Offset.zero,
            globalPosition: Offset.zero,
          ),
        );

        expect(find.text('Unsupported file type'), findsOneWidget);
      },
    );

    testWidgets(
      'navigates to import wizard for supported UDDF file',
      variant: _macOS,
      (tester) async {
        await tester.pumpWidget(_buildTestApp());
        await tester.pumpAndSettle();

        await _triggerDrop(
          tester,
          DropDoneDetails(
            files: [_dropItemFromBytes(_uddfBytes, 'dive.uddf')],
            localPosition: Offset.zero,
            globalPosition: Offset.zero,
          ),
        );

        expect(find.text('Import Wizard'), findsOneWidget);
      },
    );

    testWidgets(
      'navigates to wizard for CSV file with dive headers',
      variant: _macOS,
      (tester) async {
        await tester.pumpWidget(_buildTestApp());
        await tester.pumpAndSettle();

        await _triggerDrop(
          tester,
          DropDoneDetails(
            files: [_dropItemFromBytes(_csvBytes, 'dives.csv')],
            localPosition: Offset.zero,
            globalPosition: Offset.zero,
          ),
        );

        expect(find.text('Import Wizard'), findsOneWidget);
      },
    );

    testWidgets('navigates to wizard for FIT file', variant: _macOS, (
      tester,
    ) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      await _triggerDrop(
        tester,
        DropDoneDetails(
          files: [_dropItemFromBytes(_fitBytes, 'dive.fit')],
          localPosition: Offset.zero,
          globalPosition: Offset.zero,
        ),
      );

      expect(find.text('Import Wizard'), findsOneWidget);
    });

    testWidgets('uses only first dropped file', variant: _macOS, (
      tester,
    ) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      await _triggerDrop(
        tester,
        DropDoneDetails(
          files: [
            _dropItemFromBytes(_uddfBytes, 'dive.uddf'),
            _dropItemFromBytes(_pngBytes, 'photo.png'),
          ],
          localPosition: Offset.zero,
          globalPosition: Offset.zero,
        ),
      );

      // First file is UDDF -> navigates to wizard.
      expect(find.text('Import Wizard'), findsOneWidget);
    });
  });

  // Issue #2488: a photo dropped on the Media screen was read as a dive log
  // and rejected as "Unsupported file type".
  group('GlobalDropTarget photos and videos', () {
    setUp(() {
      _tempDir = Directory.systemTemp.createTempSync('global_drop_media_test');
    });

    tearDown(() {
      if (_tempDir.existsSync()) {
        _tempDir.deleteSync(recursive: true);
      }
    });

    DropDoneDetails drop(List<DropItem> files) => DropDoneDetails(
      files: files,
      localPosition: Offset.zero,
      globalPosition: Offset.zero,
    );

    testWidgets(
      'a photo dropped on Media opens the library importer',
      variant: _macOS,
      (tester) async {
        final drops = <_MediaDrop>[];
        await tester.pumpWidget(
          _buildTestApp(initialLocation: '/media', mediaDrops: drops),
        );
        await tester.pumpAndSettle();

        final photo = _dropItemFromBytes(_pngBytes, 'P4204060.jpg');
        await _triggerDrop(tester, drop([photo]));

        expect(drops, hasLength(1));
        expect(drops.single.destination, const MediaDropDestination());
        expect(drops.single.paths, [photo.path]);
        expect(find.text('Unsupported file type'), findsNothing);
        expect(find.text('Import Wizard'), findsNothing);
      },
    );

    testWidgets(
      'photos and videos dropped on a dive attach to that dive',
      variant: _macOS,
      (tester) async {
        final drops = <_MediaDrop>[];
        await tester.pumpWidget(
          _buildTestApp(initialLocation: '/dives/dive-1', mediaDrops: drops),
        );
        await tester.pumpAndSettle();

        final photo = _dropItemFromBytes(_pngBytes, 'P4204060.JPG');
        final video = _dropItemFromBytes(_pngBytes, 'GX010100.MP4');
        await _triggerDrop(tester, drop([photo, video]));

        expect(drops, hasLength(1));
        expect(
          drops.single.destination,
          const MediaDropDestination(target: DiveAttachTarget('dive-1')),
        );
        expect(drops.single.paths, [photo.path, video.path]);
      },
    );

    testWidgets(
      'a mixed drop sends photos to media and the dive log to the wizard',
      variant: _macOS,
      (tester) async {
        final drops = <_MediaDrop>[];
        await tester.pumpWidget(
          _buildTestApp(initialLocation: '/media', mediaDrops: drops),
        );
        await tester.pumpAndSettle();

        final photo = _dropItemFromBytes(_pngBytes, 'P4204060.jpg');
        await _triggerDrop(
          tester,
          drop([photo, _dropItemFromBytes(_uddfBytes, 'dive.uddf')]),
        );

        expect(drops.single.paths, [photo.path]);
        expect(find.text('Import Wizard'), findsOneWidget);
      },
    );

    testWidgets(
      'a folder dropped on Media opens the photos inside it',
      variant: _macOS,
      (tester) async {
        final drops = <_MediaDrop>[];
        await tester.pumpWidget(
          _buildTestApp(initialLocation: '/media', mediaDrops: drops),
        );
        await tester.pumpAndSettle();

        final photo = _dropItemFromBytes(_pngBytes, 'P4204060.jpg');
        await _triggerDrop(
          tester,
          drop([DropItemDirectory(_tempDir.path, [])]),
        );

        expect(drops.single.paths, [photo.path]);
        expect(find.text('Import Wizard'), findsNothing);
      },
    );

    testWidgets(
      'a photo dropped where media cannot go says where to drop it',
      variant: _macOS,
      (tester) async {
        final drops = <_MediaDrop>[];
        await tester.pumpWidget(_buildTestApp(mediaDrops: drops));
        await tester.pumpAndSettle();

        await _triggerDrop(
          tester,
          drop([_dropItemFromBytes(_pngBytes, 'photo.png')]),
        );

        expect(drops, isEmpty);
        expect(
          find.text(
            'To link photos and videos, drop them on Media, a dive or a '
            'dive site',
          ),
          findsOneWidget,
        );
        expect(find.text('Unsupported file type'), findsNothing);
      },
    );

    testWidgets(
      'a drop while a photo picker is open is turned away',
      variant: _macOS,
      (tester) async {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final sessions = container.read(openPhotoPickerSessionsProvider);
        sessions.value = 1;
        final drops = <_MediaDrop>[];
        await tester.pumpWidget(
          _buildTestApp(
            initialLocation: '/media',
            mediaDrops: drops,
            container: container,
          ),
        );
        await tester.pumpAndSettle();

        await _triggerDrop(
          tester,
          drop([_dropItemFromBytes(_pngBytes, 'P4204060.jpg')]),
        );

        expect(drops, isEmpty);
        expect(find.text('Finish current import first'), findsOneWidget);
      },
    );
  });
}
