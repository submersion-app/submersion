import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/features/certifications/data/repositories/certification_repository.dart';
import 'package:submersion/features/certifications/domain/entities/certification.dart';
import 'package:submersion/features/certifications/presentation/providers/certification_providers.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/test_database.dart';

Certification _makeCertification({
  String id = '',
  String name = 'Open Water',
  String? diverId,
}) {
  final now = DateTime(2024);
  return Certification(
    id: id,
    diverId: diverId,
    name: name,
    agency: CertificationAgency.padi,
    createdAt: now,
    updatedAt: now,
  );
}

Diver _makeDiver({String name = 'D', bool isDefault = true}) {
  final now = DateTime(2024);
  return Diver(
    id: '',
    name: name,
    isDefault: isDefault,
    createdAt: now,
    updatedAt: now,
  );
}

/// Repository whose [getAllCertifications] always throws, to exercise the
/// error/catch branch of the providers. Its change stream is inert so no tick
/// is ever delivered.
class _ThrowingCertificationRepository extends CertificationRepository {
  @override
  Stream<void> watchCertificationsChanges() => const Stream<void>.empty();

  @override
  Future<List<Certification>> getAllCertifications({String? diverId}) async {
    throw StateError('boom');
  }
}

void main() {
  late SharedPreferences prefs;
  late CertificationRepository certRepo;
  late DiverRepository diverRepo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    await setUpTestDatabase();
    certRepo = CertificationRepository();
    diverRepo = DiverRepository();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  ProviderContainer makeContainer() {
    return ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
  }

  /// Creates a default diver and selects it as current, so diver-scoped
  /// providers resolve a stable validated diver id.
  Future<Diver> seedCurrentDiver() async {
    final diver = await diverRepo.createDiver(_makeDiver());
    await prefs.setString(currentDiverIdKey, diver.id);
    return diver;
  }

  group('allCertificationsProvider', () {
    test('auto-refreshes after a write to the certifications table '
        '(sync scenario)', () async {
      final diver = await seedCurrentDiver();

      final container = makeContainer();
      addTearDown(container.dispose);

      // An active listener keeps the provider (and its table-change
      // subscription) alive, mirroring a widget watching the list.
      final sub = container.listen(allCertificationsProvider, (_, _) {});
      addTearDown(sub.close);

      expect(await container.read(allCertificationsProvider.future), isEmpty);

      // A sync applies a remote certification straight to the DB, bypassing the
      // list notifier. The tableUpdates tick must invalidate the provider so the
      // UI reflects the new row.
      await certRepo.createCertification(
        _makeCertification(name: 'Synced Cert').copyWith(diverId: diver.id),
      );

      var names = <String>[];
      for (var i = 0; i < 50; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        names = (await container.read(
          allCertificationsProvider.future,
        )).map((c) => c.name).toList();
        if (names.contains('Synced Cert')) break;
      }

      expect(
        names,
        contains('Synced Cert'),
        reason:
            'allCertificationsProvider should auto-refresh after the table '
            'write without any manual invalidation',
      );
    });

    test('surfaces an AsyncError when the repository getAll throws', () async {
      await seedCurrentDiver();

      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          certificationRepositoryProvider.overrideWithValue(
            _ThrowingCertificationRepository(),
          ),
        ],
      );
      addTearDown(container.dispose);

      await expectLater(
        container.read(allCertificationsProvider.future),
        throwsA(isA<StateError>()),
      );
      expect(container.read(allCertificationsProvider).hasError, isTrue);
    });
  });

  group('certificationListNotifierProvider', () {
    test('auto-refreshes the list when a certification is written directly to '
        'the DB (sync scenario)', () async {
      final diver = await seedCurrentDiver();

      final container = makeContainer();
      addTearDown(container.dispose);
      // Active listener keeps the notifier (and its table-change subscription)
      // alive, mirroring the on-screen list.
      final sub = container.listen(
        certificationListNotifierProvider,
        (_, _) {},
      );
      addTearDown(sub.close);

      while (container.read(certificationListNotifierProvider).isLoading) {
        await Future<void>.delayed(Duration.zero);
      }
      expect(container.read(certificationListNotifierProvider).value, isEmpty);

      // A sync applies a remote certification straight to the DB (no notifier
      // mutation call). The watchCertificationsChanges tick must silently reload
      // the list via _silentReloadCertifications.
      await certRepo.createCertification(
        _makeCertification(name: 'Synced Cert').copyWith(diverId: diver.id),
      );

      var names = <String>[];
      for (var i = 0; i < 50; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        names = (container.read(certificationListNotifierProvider).value ?? [])
            .map((c) => c.name)
            .toList();
        if (names.contains('Synced Cert')) break;
      }

      expect(
        names,
        contains('Synced Cert'),
        reason:
            'CertificationListNotifier should auto-refresh after a direct DB '
            'write without any manual refresh() call',
      );
    });

    test('reports AsyncError when the initial load throws', () async {
      await seedCurrentDiver();

      // A repository whose getAllCertifications always throws makes the
      // notifier's initial load (_loadCertifications) fail, exercising its
      // error catch branch. No table-change tick is involved here.
      final throwing = _ThrowingCertificationRepository();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          certificationRepositoryProvider.overrideWithValue(throwing),
        ],
      );
      addTearDown(container.dispose);

      final sub = container.listen(
        certificationListNotifierProvider,
        (_, _) {},
      );
      addTearDown(sub.close);

      // The initial load itself goes through _loadCertifications, which also
      // routes the throw into AsyncValue.error.
      for (var i = 0; i < 50; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        if (container.read(certificationListNotifierProvider).hasError) break;
      }

      expect(
        container.read(certificationListNotifierProvider).hasError,
        isTrue,
      );
    });
  });
}
