import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/certification_agencies/domain/certification_catalog.dart';
import 'package:submersion/features/certification_agencies/domain/entities/custom_certification_agency.dart';
import 'package:submersion/features/certification_agencies/domain/entities/custom_certification_level.dart';
import 'package:submersion/features/certification_agencies/presentation/providers/certification_catalog_providers.dart';
import 'package:submersion/features/certifications/domain/entities/certification.dart';
import 'package:submersion/features/certifications/presentation/pages/certification_detail_page.dart';
import 'package:submersion/features/certifications/presentation/providers/certification_providers.dart';
import 'package:submersion/features/courses/presentation/providers/course_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../helpers/mock_providers.dart';

/// Issue #690: screens that show a certification name its custom agency and
/// level from the live catalog, not their ids.
void main() {
  final catalog = CertificationCatalog(
    agencies: [
      CustomCertificationAgency(
        id: 'club-x',
        diverId: 'a',
        name: 'Club X',
        colorArgb: 0xFF3B82F6,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
    ],
    levels: [
      CustomCertificationLevel(
        id: 'club-diver',
        diverId: 'a',
        agencyId: 'club-x',
        name: 'Club Diver',
        isProgression: true,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
    ],
    viewerDiverId: 'a',
  );

  final cert = Certification(
    id: 'c1',
    name: '',
    agency: 'club-x',
    level: 'club-diver',
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  Future<void> pumpDetail(
    WidgetTester tester,
    CertificationCatalog current,
  ) async {
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...overrides,
          certificationCatalogSyncProvider.overrideWithValue(current),
          certificationByIdProvider(cert.id).overrideWith((ref) async => cert),
          courseForCertificationProvider(
            cert.id,
          ).overrideWith((ref) async => null),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: CertificationDetailPage(
            certificationId: cert.id,
            embedded: true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('the detail page names a custom agency and level', (
    tester,
  ) async {
    await pumpDetail(tester, catalog);
    expect(find.textContaining('Club X'), findsWidgets);
    expect(find.textContaining('Club Diver'), findsWidgets);
    expect(find.textContaining('club-x'), findsNothing);
  });

  testWidgets('an agency missing from the catalog reads as unknown', (
    tester,
  ) async {
    await pumpDetail(tester, CertificationCatalog.builtInOnly);
    expect(find.textContaining('Unknown agency'), findsWidgets);
    expect(find.textContaining('Unknown certification'), findsWidgets);
  });
}
