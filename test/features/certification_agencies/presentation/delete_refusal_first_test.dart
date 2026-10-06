import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/certification_agencies/data/repositories/custom_certification_repository.dart';
import 'package:submersion/features/certification_agencies/domain/entities/certification_usage.dart';
import 'package:submersion/features/certification_agencies/domain/entities/custom_certification_agency.dart';
import 'package:submersion/features/certification_agencies/domain/entities/custom_certification_level.dart';
import 'package:submersion/features/certification_agencies/presentation/pages/certification_agencies_page.dart';
import 'package:submersion/features/certification_agencies/presentation/pages/certification_agency_edit_page.dart';
import 'package:submersion/features/certification_agencies/presentation/providers/certification_catalog_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../helpers/mock_providers.dart';

/// Every entry is in use; a delete must never get as far as the repository.
class _InUseRepository extends CustomCertificationRepository {
  final deleted = <String>[];
  static const _used = CertificationUsage(certifications: 2, courses: 0);

  @override
  Stream<void> watchChanges() => const Stream.empty();

  @override
  Future<List<CustomCertificationAgency>> getAllAgencies() async => [
    CustomCertificationAgency(
      id: 'club',
      diverId: 'a',
      name: 'Club X',
      colorArgb: 0xFF0EA5E9,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    ),
  ];

  @override
  Future<List<CustomCertificationLevel>> getAllLevels() async => [
    CustomCertificationLevel(
      id: 'ice',
      diverId: 'a',
      agencyId: 'padi',
      name: 'Ice Diver',
      isProgression: true,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    ),
  ];

  @override
  Future<CertificationUsage> usage(String id) async => _used;

  @override
  Future<CertificationUsage> agencyUsage(String id) async => _used;

  @override
  Future<CertificationUsage?> deleteAgency(
    String id, {
    required String actingDiverId,
  }) async {
    deleted.add(id);
    return _used;
  }

  @override
  Future<CertificationUsage?> deleteLevel(
    String id, {
    required String actingDiverId,
  }) async {
    deleted.add(id);
    return _used;
  }
}

/// Issue #690: an entry that is still in use says so at once, rather than
/// asking "Delete?" and then refusing.
void main() {
  Future<_InUseRepository> pump(WidgetTester tester, Widget home) async {
    final repo = _InUseRepository();
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...overrides,
          customCertificationRepositoryProvider.overrideWithValue(repo),
          validatedCurrentDiverIdProvider.overrideWith((ref) async => 'a'),
          allDiversProvider.overrideWith((ref) async => const []),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: home,
        ),
      ),
    );
    await tester.pumpAndSettle();
    return repo;
  }

  testWidgets('an agency in use is refused without a confirmation', (
    tester,
  ) async {
    final repo = await pump(tester, const CertificationAgenciesPage());
    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    expect(find.text('Delete Club X?'), findsNothing);
    expect(find.text('Still in use'), findsOneWidget);
    expect(repo.deleted, isEmpty);
  });

  testWidgets('a certification in use is refused without a confirmation', (
    tester,
  ) async {
    final repo = await pump(
      tester,
      const CertificationAgencyEditPage(agencyId: 'padi'),
    );
    await tester.ensureVisible(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    expect(find.text('Delete Ice Diver?'), findsNothing);
    expect(find.text('Still in use'), findsOneWidget);
    expect(repo.deleted, isEmpty);
  });
}
