import 'dart:typed_data';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/global_drop_target.dart';

/// Platform variant that runs tests as macOS (desktop).
const _macOS = TargetPlatformVariant({TargetPlatform.macOS});

/// Build a test app that places [GlobalDropTarget] inside a GoRouter.
Widget _buildTestApp({String initialLocation = '/home'}) {
  final router = GoRouter(
    initialLocation: initialLocation,
    routes: [
      ShellRoute(
        builder: (context, state, child) =>
            Scaffold(body: GlobalDropTarget(child: child)),
        routes: [
          GoRoute(
            path: '/home',
            builder: (context, state) => const Text('Home Content'),
          ),
          GoRoute(
            path: '/transfer/import-wizard',
            builder: (context, state) => const Text('Import Wizard'),
          ),
        ],
      ),
    ],
  );

  return ProviderScope(
    child: MaterialApp.router(
      routerConfig: router,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    ),
  );
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

/// Create a [DropItemFile] with pre-loaded [bytes] that avoids real file I/O.
///
/// On dart:io platforms [DropItemFile.fromData] stores the bytes in memory so
/// [readAsBytes] returns them directly (unlike [DropItemFile()] which ignores bytes).
DropItemFile _dropItemFromBytes(Uint8List bytes, String name) =>
    DropItemFile.fromData(bytes, path: name);

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
            files: [_dropItemFromBytes(_pngBytes, 'photo.png')],
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
}
