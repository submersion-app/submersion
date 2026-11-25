import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/app_sql_functions.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/media/data/parsers/manifest_format.dart';
import 'package:submersion/features/media/data/repositories/manifest_subscription_repository.dart';
import 'package:submersion/features/media/presentation/providers/network_sources_providers.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory(setup: registerAppSqlFunctions));
    DatabaseService.instance.setTestDatabase(db);
  });

  tearDown(() async {
    await db.close();
    DatabaseService.instance.resetForTesting();
  });

  test('a paused share keeps its album name on the saved row', () async {
    final repo = ManifestSubscriptionRepository();
    final active = await repo.createSubscription(
      manifestUrl: 'https://nas.example.com:5001/mo/sharing/code1',
      format: ManifestFormat.json,
      displayName: 'Dives',
    );
    final paused = await repo.createSubscription(
      manifestUrl: 'https://nas.example.com:5001/mo/sharing/code2',
      format: ManifestFormat.json,
      displayName: 'Reef trips',
    );
    await repo.setActive(paused.id, false);
    // A plain feed has no saved share row to name.
    await repo.createSubscription(
      manifestUrl: 'https://feed.example.com/m.json',
      format: ManifestFormat.json,
      displayName: 'Feed',
    );

    final container = ProviderContainer();
    addTearDown(container.dispose);
    final names = await container.read(savedHostAlbumNamesProvider.future);

    expect(active.isActive, isTrue);
    expect(names, {
      'nas.example.com:5001/mo/sharing/code1': 'Dives',
      'nas.example.com:5001/mo/sharing/code2': 'Reef trips',
    });
  });
}
