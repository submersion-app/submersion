import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/services/media_store/media_object_store.dart';
import 'package:submersion/features/media/data/services/media_health_report.dart';
import 'package:submersion/features/media/presentation/providers/media_health_providers.dart';
import 'package:submersion/features/media_store/data/media_verify_service.dart';
import 'package:submersion/features/media_store/domain/media_transfer_summary.dart';
import 'package:submersion/features/media_store/presentation/providers/media_sweep_providers.dart';

import 'photos_page_harness.dart';

void main() {
  late PhotosPageHarness h;

  setUp(() async => h = await PhotosPageHarness.create());

  testWidgets('the connected state shows policies, transfers, backfill and '
      'disconnect', (tester) async {
    tester.view.physicalSize = const Size(800, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.runAsync(() async {
      await tester.pumpWidget(
        h.app(
          statusHint: 'dive-media @ minio',
          summary: const MediaTransferSummary(transferring: 3),
        ),
      );
      // Pump until the active-count stream has propagated.
      for (var i = 0; i < 20; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        await tester.pump();
        if (find.textContaining('3 uploading').evaluate().isNotEmpty) break;
      }
    });

    // The S3 form is gone; the connected controls are present.
    expect(find.byKey(const Key('media-s3-endpoint')), findsNothing);
    expect(find.byKey(const Key('media-provider-chooser')), findsNothing);
    expect(
      find.byKey(const Key('media-s3-policy-auto-upload')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('media-s3-policy-photos-cellular')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('media-s3-backfill')), findsOneWidget);
    expect(find.byKey(const Key('media-s3-transfers')), findsOneWidget);
    expect(find.byKey(const Key('media-s3-disconnect')), findsOneWidget);
    // The status line says how many are moving.
    expect(find.textContaining('3 uploading'), findsOneWidget);
  });

  testWidgets('toggling the policy switches writes through to policies', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.runAsync(() async {
      await tester.pumpWidget(h.app(statusHint: 'dive-media @ minio'));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await tester.pump();
    });

    await tester.ensureVisible(
      find.byKey(const Key('media-s3-policy-auto-upload')),
    );
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const Key('media-s3-policy-auto-upload')));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await tester.pump();
    });
    await tester.ensureVisible(
      find.byKey(const Key('media-s3-policy-photos-cellular')),
    );
    await tester.runAsync(() async {
      await tester.tap(
        find.byKey(const Key('media-s3-policy-photos-cellular')),
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await tester.pump();
    });

    // Defaults are on; both toggles flip to off and persist.
    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getBool('media_store_auto_upload'),
      isFalse,
      reason: 'auto-upload persisted off',
    );
  });

  testWidgets('backfill enqueues and reports the count', (tester) async {
    tester.view.physicalSize = const Size(800, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.runAsync(() async {
      await tester.pumpWidget(h.app(statusHint: 'dive-media @ minio'));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await tester.pump();
    });

    await tester.ensureVisible(find.byKey(const Key('media-s3-backfill')));
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const Key('media-s3-backfill')));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await tester.pump();
    });

    expect(h.backfill.calls, 1);
    expect(find.textContaining('7'), findsWidgets);
  });

  testWidgets('export media report builds the library report and hands it '
      'to the exporter', (tester) async {
    tester.view.physicalSize = const Size(800, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final exported = <(String content, String fileName, String mimeType)>[];
    final reporter = FakeLibraryReporter(
      MediaHealthReport(
        generatedAt: DateTime.utc(2026, 7, 1),
        deviceId: 'dev-a',
        deviceName: 'Device A',
        attachedStoreId: 'store-1',
        markerStoreId: 'store-1',
        rows: const [],
      ),
    );
    await tester.runAsync(() async {
      await tester.pumpWidget(
        h.app(
          statusHint: 'dive-media @ minio',
          extraOverrides: [
            mediaHealthReporterProvider.overrideWithValue(reporter),
            textFileExporterProvider.overrideWithValue((
              content,
              fileName,
              mimeType, {
              Rect? sharePositionOrigin,
            }) async {
              exported.add((content, fileName, mimeType));
              return fileName;
            }),
          ],
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await tester.pump();
    });

    expect(
      find.textContaining('The report lists file paths and device names'),
      findsOneWidget,
    );
    await tester.ensureVisible(find.byKey(const Key('media-export-report')));
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const Key('media-export-report')));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await tester.pump();
    });

    expect(reporter.libraryCalls, 1);
    final (content, fileName, mimeType) = exported.single;
    expect(fileName, 'submersion-media-report.txt');
    expect(mimeType, 'text/plain');
    expect(content, startsWith('Submersion media health report'));
    expect(content, contains('device: dev-a (Device A)'));
    expect(find.text('Media report exported'), findsOneWidget);
  });

  testWidgets('export media report is offered with no store attached', (
    tester,
  ) async {
    // The report describes local file and gallery rows too, which is the
    // whole library a user with no store has. Gating it on a connection
    // hid the media diagnostic from exactly the people diagnosing media.
    tester.view.physicalSize = const Size(800, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final exported = <(String content, String fileName, String mimeType)>[];
    final reporter = FakeLibraryReporter(
      MediaHealthReport(
        generatedAt: DateTime.utc(2026, 7, 1),
        deviceId: 'dev-a',
        deviceName: 'Device A',
        attachedStoreId: null,
        markerStoreId: null,
        rows: const [],
      ),
    );
    await tester.runAsync(() async {
      await tester.pumpWidget(
        h.app(
          extraOverrides: [
            mediaHealthReporterProvider.overrideWithValue(reporter),
            textFileExporterProvider.overrideWithValue((
              content,
              fileName,
              mimeType, {
              Rect? sharePositionOrigin,
            }) async {
              exported.add((content, fileName, mimeType));
              return fileName;
            }),
          ],
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await tester.pump();
    });

    await tester.ensureVisible(find.byKey(const Key('media-export-report')));
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const Key('media-export-report')));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await tester.pump();
    });

    expect(reporter.libraryCalls, 1);
    expect(exported.single.$2, 'submersion-media-report.txt');
  });

  testWidgets('verify library runs the sweep and reports the summary', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    var runs = 0;
    await tester.runAsync(() async {
      await tester.pumpWidget(
        h.app(
          statusHint: 'dive-media @ minio',
          extraOverrides: [
            mediaVerifyRunnerProvider.overrideWithValue(() async {
              runs++;
              return const VerifyLibraryReport(
                objectsChecked: 12,
                originalsChecked: 7,
                thumbsChecked: 4,
                renditionsChecked: 1,
                orphansRemoved: 3,
                bytesReclaimed: 999,
                sessionsAborted: 1,
                repairsQueued: 2,
              );
            }),
          ],
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await tester.pump();
    });

    await tester.ensureVisible(find.byKey(const Key('media-verify-library')));
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const Key('media-verify-library')));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await tester.pump();
    });

    expect(runs, 1);
    // A photo is stored as an original plus a thumbnail (plus a rendition
    // when compressed), so the object count exceeds the photo count; the
    // summary says so rather than leaving the reader to count twice.
    expect(
      find.textContaining(
        'Checked 12 cloud objects (7 originals, 4 thumbnails, 1 compressed version)',
      ),
      findsOneWidget,
    );
  });

  testWidgets('a deferred verify says nothing was deleted yet', (tester) async {
    tester.view.physicalSize = const Size(800, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    var runs = 0;
    await tester.runAsync(() async {
      await tester.pumpWidget(
        h.app(
          statusHint: 'dive-media @ minio',
          extraOverrides: [
            mediaVerifyRunnerProvider.overrideWithValue(() async {
              runs++;
              return const VerifyLibraryReport(
                objectsChecked: 12,
                originalsChecked: 7,
                thumbsChecked: 4,
                renditionsChecked: 1,
                orphansRemoved: 0,
                bytesReclaimed: 0,
                sessionsAborted: 1,
                repairsQueued: 0,
                deferred: true,
              );
            }),
          ],
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await tester.pump();
    });

    await tester.ensureVisible(find.byKey(const Key('media-verify-library')));
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const Key('media-verify-library')));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await tester.pump();
    });

    expect(runs, 1);
    // Removed 0 alone reads as "nothing to remove"; the deletes were held
    // back until this device catches up with sync.
    expect(
      find.textContaining(
        'Nothing was deleted: deletes wait until this device has finished '
        'syncing.',
      ),
      findsOneWidget,
    );
  });

  Widget throwingVerifyApp(Object error) => h.app(
    statusHint: 'dive-media @ minio',
    extraOverrides: [
      mediaVerifyRunnerProvider.overrideWithValue(() async => throw error),
    ],
  );

  Future<void> pumpAndTapVerify(WidgetTester tester, Widget widget) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(widget);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await tester.pump();
    });
    await tester.ensureVisible(find.byKey(const Key('media-verify-library')));
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const Key('media-verify-library')));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await tester.pump();
    });
  }

  testWidgets('verify surfaces MediaStoreException via the error snack', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await pumpAndTapVerify(
      tester,
      throwingVerifyApp(
        const MediaStoreException(
          'bucket unreachable',
          kind: MediaStoreErrorKind.transient,
        ),
      ),
    );
    expect(find.text('bucket unreachable'), findsOneWidget);
  });

  testWidgets('verify surfaces generic failures via the error snack', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await pumpAndTapVerify(
      tester,
      throwingVerifyApp(StateError('no media store attached')),
    );
    expect(find.textContaining('no media store attached'), findsOneWidget);
  });
  testWidgets('disconnect confirms via dialog then calls the service', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.runAsync(() async {
      await tester.pumpWidget(h.app(statusHint: 'dive-media @ minio'));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await tester.pump();
    });

    await tester.ensureVisible(find.byKey(const Key('media-s3-disconnect')));
    await tester.tap(find.byKey(const Key('media-s3-disconnect')));
    await tester.pumpAndSettle();

    // Confirm in the dialog.
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const Key('media-s3-disconnect-confirm')));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await tester.pump();
    });

    expect(h.service.disconnectCalls, 1);
  });

  testWidgets('cancelling the disconnect dialog does not disconnect', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.runAsync(() async {
      await tester.pumpWidget(h.app(statusHint: 'dive-media @ minio'));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await tester.pump();
    });

    await tester.ensureVisible(find.byKey(const Key('media-s3-disconnect')));
    await tester.tap(find.byKey(const Key('media-s3-disconnect')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(h.service.disconnectCalls, 0);
  });
}
