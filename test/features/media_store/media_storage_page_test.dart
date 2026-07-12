import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/services/cloud_storage/s3/s3_config.dart';
import 'package:submersion/core/services/media_store/media_object_store.dart';
import 'package:submersion/core/services/media_store/media_store_attach_state.dart';
import 'package:submersion/core/services/media_store/media_store_credentials_store.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media_store/data/media_backfill_service.dart';
import 'package:submersion/features/media_store/data/media_store_service.dart';
import 'package:submersion/features/media_store/data/media_stores_repository.dart';
import 'package:submersion/features/media_store/data/media_transfer_queue_repository.dart';
import 'package:submersion/features/media_store/presentation/pages/media_storage_page.dart';
import 'package:submersion/features/media_store/presentation/providers/media_store_providers.dart';
import 'package:submersion/features/settings/presentation/providers/sync_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../helpers/in_memory_media_object_store.dart';
import '../../support/fake_keychain_storage.dart';

class _RecordingService extends MediaStoreService {
  _RecordingService()
    : super(
        credentials: MediaStoreCredentialsStore(storage: InMemoryKeychain()),
        attachState: MediaStoreAttachState(),
        storesRepository: MediaStoresRepository(),
        storeFactory: (_) => InMemoryMediaObjectStore(),
      );

  int connectCalls = 0;
  int testCalls = 0;
  int dropboxCalls = 0;
  int gdriveCalls = 0;
  int icloudCalls = 0;
  int disconnectCalls = 0;

  /// When set, connectS3/testConnection/connectDropbox throw it.
  Object? throwOnConnect;
  Object? throwOnTest;
  Object? throwOnDropbox;

  static const _result = MediaStoreConnectResult(
    storeId: 'store-x',
    createdNewStore: true,
  );

  @override
  Future<MediaStoreConnectResult> connectS3(
    S3Config config, {
    String? accountId,
  }) async {
    connectCalls++;
    if (throwOnConnect != null) throw throwOnConnect!;
    return _result;
  }

  @override
  Future<MediaStoreConnectResult> connectDropbox() async {
    dropboxCalls++;
    if (throwOnDropbox != null) throw throwOnDropbox!;
    return _result;
  }

  @override
  Future<MediaStoreConnectResult> connectGoogleDrive() async {
    gdriveCalls++;
    return _result;
  }

  @override
  Future<MediaStoreConnectResult> connectICloud() async {
    icloudCalls++;
    return _result;
  }

  @override
  Future<void> testConnection(S3Config config) async {
    testCalls++;
    if (throwOnTest != null) throw throwOnTest!;
  }

  @override
  Future<void> disconnect() async {
    disconnectCalls++;
  }
}

/// Credentials store whose load() always throws, to drive the page's
/// secure-storage error branch.
class _ThrowingCredentialsStore extends MediaStoreCredentialsStore {
  _ThrowingCredentialsStore() : super(storage: InMemoryKeychain());

  @override
  Future<S3Config?> load() async => throw StateError('keychain locked');
}

/// Backfill double: returns a fixed count without touching a database.
class _FakeBackfillService extends MediaBackfillService {
  _FakeBackfillService()
    : super(
        mediaRepository: MediaRepository(),
        queue: MediaTransferQueueRepository(),
      );

  int calls = 0;

  @override
  Future<int> enqueueAll() async {
    calls++;
    return 7;
  }
}

void main() {
  late _RecordingService service;
  late _FakeBackfillService backfill;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    service = _RecordingService();
    backfill = _FakeBackfillService();
  });

  Widget app({bool apple = true, String? statusHint, int activeCount = 0}) =>
      ProviderScope(
        overrides: [
          mediaStoreRuntimeProvider.overrideWith((ref) async => null),
          mediaStoreCredentialsStoreProvider.overrideWithValue(
            MediaStoreCredentialsStore(storage: InMemoryKeychain()),
          ),
          mediaStoreServiceProvider.overrideWithValue(service),
          mediaBackfillServiceProvider.overrideWithValue(backfill),
          mediaStoreStatusHintProvider.overrideWith((ref) async => statusHint),
          mediaTransferActiveCountProvider.overrideWith(
            (ref) => Stream.value(activeCount),
          ),
          isApplePlatformProvider.overrideWithValue(apple),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: MediaStoragePage(),
        ),
      );

  testWidgets('shows the not-configured status and no disconnect '
      'button', (tester) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(app());
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await tester.pump();
    });

    expect(
      find.text('No media store connected on this device'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('media-s3-connect')), findsOneWidget);
    expect(find.byKey(const Key('media-s3-disconnect')), findsNothing);
  });

  testWidgets('invalid form blocks connect and never calls the '
      'service', (tester) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(app());
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await tester.pump();
    });

    await tester.ensureVisible(find.byKey(const Key('media-s3-connect')));
    await tester.tap(find.byKey(const Key('media-s3-connect')));
    await tester.pump();

    expect(service.connectCalls, 0);
    expect(find.byType(MediaStoragePage), findsOneWidget);
  });

  testWidgets('valid form calls connectS3 once', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.runAsync(() async {
      await tester.pumpWidget(app());
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await tester.pump();
    });

    await tester.enterText(
      find.byKey(const Key('media-s3-endpoint')),
      'https://minio.example.com',
    );
    await tester.enterText(
      find.byKey(const Key('media-s3-bucket')),
      'dive-media',
    );
    await tester.enterText(find.byKey(const Key('media-s3-access-key')), 'AK');
    await tester.enterText(find.byKey(const Key('media-s3-secret-key')), 'SK');

    await tester.ensureVisible(find.byKey(const Key('media-s3-connect')));
    await tester.pump();
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const Key('media-s3-connect')));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await tester.pump();
    });

    expect(service.connectCalls, 1);
  });

  testWidgets('chooser defaults to S3 with the form visible', (tester) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(app());
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await tester.pump();
    });

    expect(find.byKey(const Key('media-provider-chooser')), findsOneWidget);
    expect(find.byKey(const Key('media-s3-endpoint')), findsOneWidget);
    expect(find.text('iCloud'), findsOneWidget);
    expect(find.byKey(const Key('media-dropbox-connect')), findsNothing);
  });

  testWidgets('selecting dropbox swaps the form for the connect panel '
      'and calls the service', (tester) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(app());
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await tester.pump();
    });

    await tester.tap(find.text('Dropbox'));
    await tester.pump();

    expect(find.byKey(const Key('media-s3-endpoint')), findsNothing);
    expect(find.byKey(const Key('media-dropbox-connect')), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('media-dropbox-connect')));
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const Key('media-dropbox-connect')));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await tester.pump();
    });

    expect(service.dropboxCalls, 1);
    expect(service.connectCalls, 0);
  });

  testWidgets('the iCloud segment is absent on non-Apple '
      'platforms', (tester) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(app(apple: false));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await tester.pump();
    });

    expect(find.byKey(const Key('media-provider-chooser')), findsOneWidget);
    expect(find.text('iCloud'), findsNothing);
    expect(find.text('Google Drive'), findsOneWidget);
  });

  testWidgets('test connection reports success on the valid form', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.runAsync(() async {
      await tester.pumpWidget(app());
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await tester.pump();
    });

    await tester.enterText(
      find.byKey(const Key('media-s3-endpoint')),
      'https://minio.example.com',
    );
    await tester.enterText(find.byKey(const Key('media-s3-bucket')), 'b');
    await tester.enterText(find.byKey(const Key('media-s3-access-key')), 'AK');
    await tester.enterText(find.byKey(const Key('media-s3-secret-key')), 'SK');

    await tester.ensureVisible(find.byKey(const Key('media-s3-test')));
    await tester.pump();
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const Key('media-s3-test')));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await tester.pump();
    });

    expect(service.testCalls, 1);
    expect(find.text('Connection successful'), findsOneWidget);
  });

  testWidgets('a MediaStoreException on test connection shows the error '
      'message', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    service.throwOnTest = const MediaStoreException(
      'bucket unreachable',
      kind: MediaStoreErrorKind.transient,
    );
    await tester.runAsync(() async {
      await tester.pumpWidget(app());
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await tester.pump();
    });

    await tester.enterText(
      find.byKey(const Key('media-s3-endpoint')),
      'https://minio.example.com',
    );
    await tester.enterText(find.byKey(const Key('media-s3-bucket')), 'b');
    await tester.enterText(find.byKey(const Key('media-s3-access-key')), 'AK');
    await tester.enterText(find.byKey(const Key('media-s3-secret-key')), 'SK');

    await tester.ensureVisible(find.byKey(const Key('media-s3-test')));
    await tester.pump();
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const Key('media-s3-test')));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await tester.pump();
    });

    expect(find.text('bucket unreachable'), findsOneWidget);
  });

  testWidgets('a non-MediaStore error on connect shows the generic secure '
      'storage message', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    service.throwOnConnect = StateError('keychain locked');
    await tester.runAsync(() async {
      await tester.pumpWidget(app());
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await tester.pump();
    });

    await tester.enterText(
      find.byKey(const Key('media-s3-endpoint')),
      'https://minio.example.com',
    );
    await tester.enterText(find.byKey(const Key('media-s3-bucket')), 'b');
    await tester.enterText(find.byKey(const Key('media-s3-access-key')), 'AK');
    await tester.enterText(find.byKey(const Key('media-s3-secret-key')), 'SK');

    await tester.ensureVisible(find.byKey(const Key('media-s3-connect')));
    await tester.pump();
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const Key('media-s3-connect')));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await tester.pump();
    });

    expect(service.connectCalls, 1);
    expect(find.textContaining('keychain locked'), findsOneWidget);
  });

  testWidgets('a managed connect failure surfaces the auth message', (
    tester,
  ) async {
    service.throwOnDropbox = const MediaStoreException(
      'Dropbox is not connected or unavailable on this device',
      kind: MediaStoreErrorKind.auth,
    );
    await tester.runAsync(() async {
      await tester.pumpWidget(app());
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await tester.pump();
    });

    await tester.tap(find.text('Dropbox'));
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('media-dropbox-connect')));
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const Key('media-dropbox-connect')));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await tester.pump();
    });

    expect(service.dropboxCalls, 1);
    expect(
      find.text('Dropbox is not connected or unavailable on this device'),
      findsOneWidget,
    );
  });

  testWidgets('the connected state shows policies, transfers, backfill and '
      'disconnect', (tester) async {
    tester.view.physicalSize = const Size(800, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.runAsync(() async {
      await tester.pumpWidget(
        app(statusHint: 'dive-media @ minio', activeCount: 3),
      );
      // Pump until the active-count stream has propagated.
      for (var i = 0; i < 20; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        await tester.pump();
        if (find.text('3').evaluate().isNotEmpty) break;
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
    // The active-count progress row renders when count > 0.
    expect(find.text('3'), findsOneWidget);
  });

  testWidgets('toggling the policy switches writes through to policies', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.runAsync(() async {
      await tester.pumpWidget(app(statusHint: 'dive-media @ minio'));
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
      await tester.pumpWidget(app(statusHint: 'dive-media @ minio'));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await tester.pump();
    });

    await tester.ensureVisible(find.byKey(const Key('media-s3-backfill')));
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const Key('media-s3-backfill')));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await tester.pump();
    });

    expect(backfill.calls, 1);
    expect(find.textContaining('7'), findsWidgets);
  });

  testWidgets('disconnect confirms via dialog then calls the service', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.runAsync(() async {
      await tester.pumpWidget(app(statusHint: 'dive-media @ minio'));
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
    });

    expect(service.disconnectCalls, 1);
  });

  testWidgets('cancelling the disconnect dialog does not disconnect', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.runAsync(() async {
      await tester.pumpWidget(app(statusHint: 'dive-media @ minio'));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await tester.pump();
    });

    await tester.ensureVisible(find.byKey(const Key('media-s3-disconnect')));
    await tester.tap(find.byKey(const Key('media-s3-disconnect')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(service.disconnectCalls, 0);
  });

  testWidgets('the form prefills from saved media credentials', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final creds = MediaStoreCredentialsStore(storage: InMemoryKeychain());
    await creds.save(
      S3Config(
        endpoint: 'https://minio.example.com',
        bucket: 'saved-bucket',
        prefix: 'submersion-media/',
        accessKeyId: 'AKSAVED',
        secretAccessKey: 'SKSAVED',
      ),
    );

    await tester.runAsync(() async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            mediaStoreRuntimeProvider.overrideWith((ref) async => null),
            mediaStoreCredentialsStoreProvider.overrideWithValue(creds),
            mediaStoreServiceProvider.overrideWithValue(service),
            mediaStoreStatusHintProvider.overrideWith((ref) async => null),
            isApplePlatformProvider.overrideWithValue(true),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: MediaStoragePage(),
          ),
        ),
      );
      for (var i = 0; i < 20; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        await tester.pump();
        if (find.text('saved-bucket').evaluate().isNotEmpty) break;
      }
    });

    expect(find.text('saved-bucket'), findsOneWidget);
  });

  testWidgets('an AWS saved config prefills the regional endpoint URL', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final creds = MediaStoreCredentialsStore(storage: InMemoryKeychain());
    await creds.save(
      S3Config(
        endpoint: 'https://s3.eu-west-1.amazonaws.com',
        region: 'eu-west-1',
        bucket: 'aws-bucket',
        accessKeyId: 'AK',
        secretAccessKey: 'SK',
      ),
    );

    await tester.runAsync(() async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            mediaStoreRuntimeProvider.overrideWith((ref) async => null),
            mediaStoreCredentialsStoreProvider.overrideWithValue(creds),
            mediaStoreServiceProvider.overrideWithValue(service),
            mediaStoreStatusHintProvider.overrideWith((ref) async => null),
            isApplePlatformProvider.overrideWithValue(true),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: MediaStoragePage(),
          ),
        ),
      );
      for (var i = 0; i < 20; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        await tester.pump();
        if (find.text('aws-bucket').evaluate().isNotEmpty) break;
      }
    });

    expect(find.text('https://s3.eu-west-1.amazonaws.com'), findsOneWidget);
  });

  testWidgets('a keychain error while loading shows the secure-storage '
      'snack', (tester) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            mediaStoreRuntimeProvider.overrideWith((ref) async => null),
            mediaStoreCredentialsStoreProvider.overrideWithValue(
              _ThrowingCredentialsStore(),
            ),
            mediaStoreServiceProvider.overrideWithValue(service),
            mediaStoreStatusHintProvider.overrideWith((ref) async => null),
            isApplePlatformProvider.overrideWithValue(true),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: MediaStoragePage(),
          ),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 80));
      await tester.pump();
    });

    expect(find.byType(SnackBar), findsOneWidget);
  });

  testWidgets('a MediaStoreException on connect shows the error message', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    service.throwOnConnect = const MediaStoreException(
      'bucket adoption failed',
      kind: MediaStoreErrorKind.fatal,
    );
    await tester.runAsync(() async {
      await tester.pumpWidget(app());
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await tester.pump();
    });
    await tester.enterText(
      find.byKey(const Key('media-s3-endpoint')),
      'https://minio.example.com',
    );
    await tester.enterText(find.byKey(const Key('media-s3-bucket')), 'b');
    await tester.enterText(find.byKey(const Key('media-s3-access-key')), 'AK');
    await tester.enterText(find.byKey(const Key('media-s3-secret-key')), 'SK');
    await tester.ensureVisible(find.byKey(const Key('media-s3-connect')));
    await tester.pump();
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const Key('media-s3-connect')));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await tester.pump();
    });
    expect(find.text('bucket adoption failed'), findsOneWidget);
  });

  testWidgets('a generic error on test connection shows the secure-storage '
      'message', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    service.throwOnTest = StateError('boom');
    await tester.runAsync(() async {
      await tester.pumpWidget(app());
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await tester.pump();
    });
    await tester.enterText(
      find.byKey(const Key('media-s3-endpoint')),
      'https://minio.example.com',
    );
    await tester.enterText(find.byKey(const Key('media-s3-bucket')), 'b');
    await tester.enterText(find.byKey(const Key('media-s3-access-key')), 'AK');
    await tester.enterText(find.byKey(const Key('media-s3-secret-key')), 'SK');
    await tester.ensureVisible(find.byKey(const Key('media-s3-test')));
    await tester.pump();
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const Key('media-s3-test')));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await tester.pump();
    });
    expect(find.byType(SnackBar), findsOneWidget);
  });

  testWidgets('selecting Google Drive and iCloud calls their connect '
      'flows', (tester) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(app());
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await tester.pump();
    });

    await tester.tap(find.text('Google Drive'));
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('media-gdrive-connect')));
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const Key('media-gdrive-connect')));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await tester.pump();
    });
    expect(service.gdriveCalls, 1);

    await tester.tap(find.text('iCloud'));
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('media-icloud-connect')));
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const Key('media-icloud-connect')));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await tester.pump();
    });
    expect(service.icloudCalls, 1);
  });

  testWidgets('the advanced section exposes region, prefix and path style', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.runAsync(() async {
      await tester.pumpWidget(app());
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await tester.pump();
    });

    await tester.ensureVisible(find.byKey(const Key('media-s3-advanced')));
    await tester.tap(find.byKey(const Key('media-s3-advanced')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('media-s3-region')), findsOneWidget);
    expect(find.byKey(const Key('media-s3-prefix')), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('media-s3-path-style')));
    await tester.tap(find.byKey(const Key('media-s3-path-style')));
    await tester.pump();
    // Entering an endpoint updates the derived-region helper text.
    await tester.enterText(
      find.byKey(const Key('media-s3-endpoint')),
      'https://s3.us-west-2.amazonaws.com',
    );
    await tester.pump();
    expect(find.byKey(const Key('media-s3-region')), findsOneWidget);
  });

  testWidgets('endpoint validation rejects a bad URL and a URL with a '
      'path', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.runAsync(() async {
      await tester.pumpWidget(app());
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await tester.pump();
    });

    // Fill the other required fields so only the endpoint validator fires.
    await tester.enterText(find.byKey(const Key('media-s3-bucket')), 'b');
    await tester.enterText(find.byKey(const Key('media-s3-access-key')), 'AK');
    await tester.enterText(find.byKey(const Key('media-s3-secret-key')), 'SK');

    await tester.enterText(
      find.byKey(const Key('media-s3-endpoint')),
      'not a url',
    );
    await tester.ensureVisible(find.byKey(const Key('media-s3-connect')));
    await tester.tap(find.byKey(const Key('media-s3-connect')));
    await tester.pump();
    expect(service.connectCalls, 0);

    await tester.enterText(
      find.byKey(const Key('media-s3-endpoint')),
      'https://minio.example.com/some/path',
    );
    await tester.tap(find.byKey(const Key('media-s3-connect')));
    await tester.pump();
    expect(
      service.connectCalls,
      0,
      reason: 'a path in the endpoint is invalid',
    );
  });
}
