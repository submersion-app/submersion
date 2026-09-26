import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/services/divelogs/divelogs_api_client.dart';
import 'package:submersion/core/services/divelogs/divelogs_auth.dart';
import 'package:submersion/core/services/divelogs/divelogs_session_store.dart';
import 'package:submersion/features/import_wizard/data/adapters/divelogs_import_adapter.dart';
import 'package:submersion/features/import_wizard/data/adapters/remote_photo_attacher.dart';
import 'package:submersion/features/import_wizard/domain/models/import_bundle.dart'
    show ImportSourceType;
import 'package:submersion/features/media/data/services/local_file_link_service.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/presentation/providers/photo_picker_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/models/import_payload.dart';
import 'package:submersion/features/universal_import/presentation/providers/universal_import_providers.dart';

import '../../../../support/fake_keychain_storage.dart';

/// Records every link instead of writing media rows.
class _RecordingLinkService extends Fake implements LocalFileLinkService {
  final linked = <(String, String)>[];

  @override
  Future<Set<String>> linkedPathsForDive(String diveId) async => {};

  @override
  Future<MediaItem?> linkFileForDive({
    required String path,
    required String diveId,
    required Set<String> linkedPaths,
    DateTime? takenAt,
    DateTime? fallbackTakenAt,
    double? latitude,
    double? longitude,
    String? caption,
  }) async {
    linked.add((path, diveId));
    return MediaItem(
      id: 'm${linked.length}',
      mediaType: MediaType.photo,
      takenAt: DateTime(2024),
      createdAt: DateTime(2024),
      updatedAt: DateTime(2024),
    );
  }
}

DivelogsApiClient _client(Future<http.Response> Function(http.Request) h) =>
    DivelogsApiClient(
      getBearerToken: () async => 't',
      onTokenRejected: () {},
      httpClient: MockClient(h),
    );

void main() {
  late ProviderContainer container;
  late _RecordingLinkService linkService;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    linkService = _RecordingLinkService();
    container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        localFileLinkServiceProvider.overrideWithValue(linkService),
      ],
    );
  });

  tearDown(() => container.dispose());

  Future<DivelogsImportAdapter> pumpAdapter(WidgetTester tester) async {
    late DivelogsImportAdapter adapter;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Consumer(
            builder: (context, ref, _) {
              adapter = DivelogsImportAdapter(ref: ref);
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
    return adapter;
  }

  testWidgets('sign in and fetch replace the file steps', (tester) async {
    final adapter = await pumpAdapter(tester);
    expect(adapter.acquisitionSteps.map((s) => s.label).toList(), [
      'Sign In',
      'Fetch',
      'Divers',
      'Photos',
    ]);
    expect(adapter.sourceType, ImportSourceType.divelogs);
    expect(adapter.displayName, 'divelogs.de');
  });

  testWidgets('resetState forgets the client, photos and step flags', (
    tester,
  ) async {
    final adapter = await pumpAdapter(tester);
    adapter.setClient(_client((_) async => http.Response('', 200)));
    adapter.setRemotePhotos({
      'divelogs-1': [
        RemotePhoto(url: Uri.parse('https://x.de/a.jpg'), fileName: 'a.jpg'),
      ],
    });
    container.read(divelogsSignedInProvider.notifier).state = true;
    container.read(divelogsFetchedProvider.notifier).state = true;

    adapter.resetState();

    expect(adapter.client, isNull);
    expect(
      await adapter.debugAttachAdditionalPhotosFor(
        photoDiveIds: const {0: 'dive-1'},
        dives: const [
          {'sourceUuid': 'divelogs-1'},
        ],
        destinationDir: '/nowhere',
      ),
      (attached: 0, failed: 0),
    );
    expect(container.read(divelogsSignedInProvider), isFalse);
    expect(container.read(divelogsFetchedProvider), isFalse);
  });

  testWidgets('downloads photos into the chosen folder and links them', (
    tester,
  ) async {
    final adapter = await pumpAdapter(tester);
    final dest = (await tester.runAsync(
      () => Directory.systemTemp.createTemp('divelogs_dest_'),
    ))!;
    addTearDown(() => dest.deleteSync(recursive: true));
    adapter.setClient(
      _client((req) async {
        if (req.url.path.endsWith('bad.jpg')) return http.Response('', 500);
        return http.Response.bytes([7, 7, 7], 200);
      }),
    );
    adapter.setRemotePhotos({
      'divelogs-1': [
        RemotePhoto(
          url: Uri.parse('https://divelogs.de/p/reef.jpg'),
          fileName: 'reef.jpg',
        ),
        RemotePhoto(
          url: Uri.parse('https://divelogs.de/p/bad.jpg'),
          fileName: 'bad.jpg',
        ),
      ],
    });

    final outcome = await tester.runAsync(
      () => adapter.debugAttachAdditionalPhotosFor(
        photoDiveIds: const {0: 'dive-1'},
        dives: const [
          {'sourceUuid': 'divelogs-1'},
        ],
        destinationDir: dest.path,
      ),
    );

    expect(outcome, (attached: 1, failed: 1));
    final saved = File(p.join(dest.path, 'reef.jpg'));
    expect(saved.readAsBytesSync(), [7, 7, 7]);
    expect(linkService.linked.single, (saved.path, 'dive-1'));
  });

  testWidgets('a lost session stops the downloads instead of retrying each', (
    tester,
  ) async {
    final adapter = await pumpAdapter(tester);
    var tokenRequests = 0;
    adapter.setClient(
      DivelogsApiClient(
        getBearerToken: () async {
          tokenRequests++;
          throw const DivelogsSessionExpiredException();
        },
        onTokenRejected: () {},
        httpClient: MockClient((_) async => fail('no request without a token')),
      ),
    );
    adapter.setRemotePhotos({
      'divelogs-1': [
        RemotePhoto(
          url: Uri.parse('https://divelogs.de/p/a.jpg'),
          fileName: 'a.jpg',
        ),
        RemotePhoto(
          url: Uri.parse('https://divelogs.de/p/b.jpg'),
          fileName: 'b.jpg',
        ),
      ],
    });

    final outcome = await tester.runAsync(
      () => adapter.debugAttachAdditionalPhotosFor(
        photoDiveIds: const {0: 'dive-1'},
        dives: const [
          {'sourceUuid': 'divelogs-1'},
        ],
        destinationDir: Directory.systemTemp.path,
      ),
    );

    expect(outcome, (attached: 0, failed: 2));
    expect(tokenRequests, 1);
  });

  testWidgets('a new or cleared client forgets the previous fetch', (
    tester,
  ) async {
    final adapter = await pumpAdapter(tester);
    adapter.setRemotePhotos({
      'divelogs-1': [
        RemotePhoto(url: Uri.parse('https://x.de/a.jpg'), fileName: 'a.jpg'),
      ],
    });
    container.read(divelogsFetchedProvider.notifier).state = true;

    adapter.setClient(_client((_) async => http.Response('', 200)));

    expect(container.read(divelogsFetchedProvider), isFalse);
    expect(
      await adapter.debugAttachAdditionalPhotosFor(
        photoDiveIds: const {0: 'dive-1'},
        dives: const [
          {'sourceUuid': 'divelogs-1'},
        ],
        destinationDir: '/nowhere',
      ),
      (attached: 0, failed: 0),
    );
  });

  testWidgets('a 401 from another host does not stop the other downloads', (
    tester,
  ) async {
    final adapter = await pumpAdapter(tester);
    final dest = (await tester.runAsync(
      () => Directory.systemTemp.createTemp('divelogs_foreign_'),
    ))!;
    addTearDown(() => dest.deleteSync(recursive: true));
    adapter.setClient(
      _client((req) async {
        if (req.url.host == 'cdn.example.com') return http.Response('', 401);
        return http.Response.bytes([5], 200);
      }),
    );
    adapter.setRemotePhotos({
      'divelogs-1': [
        RemotePhoto(
          url: Uri.parse('https://cdn.example.com/x.jpg'),
          fileName: 'x.jpg',
        ),
        RemotePhoto(
          url: Uri.parse('https://divelogs.de/p/y.jpg'),
          fileName: 'y.jpg',
        ),
      ],
    });

    final outcome = await tester.runAsync(
      () => adapter.debugAttachAdditionalPhotosFor(
        photoDiveIds: const {0: 'dive-1'},
        dives: const [
          {'sourceUuid': 'divelogs-1'},
        ],
        destinationDir: dest.path,
      ),
    );

    expect(outcome, (attached: 1, failed: 1));
  });

  testWidgets('a new client discards the payload fetched under the old one', (
    tester,
  ) async {
    final adapter = await pumpAdapter(tester);
    final notifier = container.read(universalImportNotifierProvider.notifier);
    notifier.state = notifier.state.copyWith(
      payload: const ImportPayload(
        entities: {
          ImportEntityType.dives: [
            {'sourceUuid': 'divelogs-1'},
          ],
        },
      ),
      remotePhotoCount: 3,
    );

    adapter.setClient(null);

    final state = container.read(universalImportNotifierProvider);
    expect(state.payload, isNull);
    expect(state.remotePhotoCount, 0);
  });

  testWidgets('an expired session is cleared, remembered and navigated back', (
    tester,
  ) async {
    final adapter = await pumpAdapter(tester);
    var wentBack = 0;
    adapter.goBack = () => wentBack++;
    final store = DivelogsSessionStore(storage: InMemoryKeychain());
    await tester.runAsync(
      () => store.save(const DivelogsSession(username: 'rainer', token: 't')),
    );
    final auth = DivelogsAuth(
      httpClient: MockClient((_) async => fail('')),
      store: store,
    );
    await tester.runAsync(auth.restore);
    adapter.setSession((
      auth: auth,
      client: _client((_) async => http.Response('', 200)),
    ));
    container.read(divelogsFetchedProvider.notifier).state = true;

    adapter.debugExpireSession();

    expect(adapter.client, isNull);
    expect(adapter.session, isNull);
    expect(adapter.lastUsername, 'rainer');
    expect(wentBack, 1);
    expect(container.read(divelogsFetchedProvider), isFalse);
  });
}
