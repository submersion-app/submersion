import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mockito/mockito.dart';
import 'package:path/path.dart' as p;

import 'package:submersion/core/services/divelogs/divelogs_api_client.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/import_wizard/data/adapters/divelogs_import_adapter.dart';
import 'package:submersion/features/import_wizard/data/adapters/remote_photo_attacher.dart';
import 'package:submersion/features/import_wizard/domain/models/import_bundle.dart';
import 'package:submersion/features/import_wizard/domain/models/import_notice.dart';
import 'package:submersion/features/media/data/services/local_file_link_service.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/presentation/providers/photo_picker_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/tank_presets/presentation/providers/tank_preset_providers.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart'
    as ui;
import 'package:submersion/features/universal_import/data/models/import_payload.dart';
import 'package:submersion/features/universal_import/presentation/providers/universal_import_providers.dart';

import '../../../../helpers/test_database.dart';
import 'universal_adapter_test.mocks.dart';

final _now = DateTime(2026);

class _TestSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _TestSettingsNotifier() : super(const AppSettings());

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

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
      takenAt: _now,
      createdAt: _now,
      updatedAt: _now,
    );
  }
}

/// The whole import, end to end: a divelogs dive with two listed photos,
/// one of which will not download, imported into a real database.
void main() {
  late Directory dest;

  setUp(() async {
    await setUpTestDatabase();
  });
  tearDown(tearDownTestDatabase);

  testWidgets('reports attached photos and the ones that failed', (
    tester,
  ) async {
    dest = (await tester.runAsync(
      () => Directory.systemTemp.createTemp('divelogs_perform_'),
    ))!;
    addTearDown(() => dest.deleteSync(recursive: true));
    await tester.runAsync(
      () => DiverRepository().createDiver(
        Diver(id: 'diver-1', name: 'Me', createdAt: _now, updatedAt: _now),
      ),
    );
    final tankPresets = MockTankPresetRepository();
    when(tankPresets.getPresetById(any)).thenAnswer((_) async => null);
    final linkService = _RecordingLinkService();

    final payload = ImportPayload(
      entities: {
        ui.ImportEntityType.dives: [
          {
            'dateTime': DateTime.utc(2024, 5, 1, 9),
            'maxDepth': 18.0,
            'runtime': const Duration(minutes: 40),
            'sourceUuid': 'divelogs-7',
          },
        ],
      },
    );

    late DivelogsImportAdapter adapter;
    late WidgetRef widgetRef;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
          currentDiverProvider.overrideWith(
            (ref) async => Diver(
              id: 'diver-1',
              name: 'Me',
              createdAt: _now,
              updatedAt: _now,
            ),
          ),
          tankPresetRepositoryProvider.overrideWithValue(tankPresets),
          localFileLinkServiceProvider.overrideWithValue(linkService),
        ],
        child: MaterialApp(
          home: Consumer(
            builder: (context, ref, _) {
              widgetRef = ref;
              adapter = DivelogsImportAdapter(ref: ref);
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    adapter.setClient(
      DivelogsApiClient(
        getBearerToken: () async => 't',
        onTokenRejected: () {},
        httpClient: MockClient((req) async {
          if (req.url.path.endsWith('bad.jpg')) return http.Response('', 500);
          return http.Response.bytes([7, 7, 7], 200);
        }),
      ),
    );
    // Sign-in happens before the fetch, and a new client clears whatever
    // was installed before it; the fetch then installs this payload.
    final notifier = widgetRef.read(universalImportNotifierProvider.notifier);
    notifier.state = notifier.state.copyWith(
      payload: payload,
      remotePhotoCount: 2,
      bundledPhotoFolderPath: dest.path,
    );
    adapter.setRemotePhotos({
      'divelogs-7': [
        RemotePhoto(
          url: Uri.parse('https://divelogs.de/pics/reef.jpg'),
          fileName: 'reef.jpg',
        ),
        RemotePhoto(
          url: Uri.parse('https://divelogs.de/pics/bad.jpg'),
          fileName: 'bad.jpg',
        ),
      ],
    });

    final result = (await tester.runAsync(() async {
      final bundle = await adapter.buildBundle();
      return adapter.performImport(bundle, {
        ImportEntityType.dives: {0},
      }, {});
    }))!;

    expect(result.errorMessage, isNull);
    expect(result.attachedPhotoCount, 1);
    final notice = result.notices.singleWhere(
      (n) => n.kind == ImportNoticeKind.photosNotDownloaded,
    );
    expect(notice.count, 1);
    expect(linkService.linked.single.$1, p.join(dest.path, 'reef.jpg'));
  });
}
