import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/certification_agencies/domain/certification_catalog.dart';
import 'package:submersion/features/certification_agencies/domain/entities/custom_certification_agency.dart';
import 'package:submersion/features/certification_agencies/domain/entities/custom_certification_level.dart';
import 'package:submersion/features/certification_agencies/presentation/providers/certification_catalog_providers.dart';
import 'package:submersion/features/certifications/domain/constants/certification_field.dart';
import 'package:submersion/features/certifications/domain/entities/certification.dart';
import 'package:submersion/features/certifications/presentation/widgets/certification_ecard_front.dart';
import 'package:submersion/features/certifications/presentation/widgets/certification_ecard_grid.dart';
import 'package:submersion/features/certifications/presentation/widgets/certification_share_sheet.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Issue #690: the generated card front, the wallet grid and the table's
/// Name column title a card with a custom level by that level's name.
void main() {
  final t = DateTime(2026);
  final catalog = CertificationCatalog(
    agencies: [
      CustomCertificationAgency(
        id: 'club-id',
        diverId: 'a',
        name: 'Lakeshore Dive Club',
        colorArgb: 0xFF0EA5E9,
        createdAt: t,
        updatedAt: t,
      ),
    ],
    levels: [
      CustomCertificationLevel(
        id: 'club-diver-id',
        diverId: 'a',
        agencyId: 'club-id',
        name: 'Club Diver',
        isProgression: true,
        createdAt: t,
        updatedAt: t,
      ),
    ],
  );
  final cert = Certification(
    id: 'c1',
    name: '',
    agency: 'club-id',
    level: 'club-diver-id',
    createdAt: t,
    updatedAt: t,
  );

  Widget host(Widget child) => ProviderScope(
    overrides: [certificationCatalogSyncProvider.overrideWithValue(catalog)],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    ),
  );

  testWidgets('the generated card front titles the custom level', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        SizedBox(
          width: 400,
          height: 260,
          child: CertificationEcardFront(certification: cert, diverName: 'Ana'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Club Diver'), findsWidgets);
    expect(find.textContaining('Unknown'), findsNothing);
  });

  testWidgets('the wallet grid titles the custom level', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      host(CertificationEcardGrid(certifications: [cert], diverName: 'Ana')),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Unknown'), findsNothing);
    expect(find.textContaining('Club Diver'), findsWidgets);
  });

  testWidgets('the share sheet subtitle updates when the catalog loads', (
    tester,
  ) async {
    final pending = Completer<CertificationCatalog>();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          certificationCatalogProvider.overrideWith((ref) => pending.future),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: CertificationShareSheet(
              certification: cert,
              diverName: 'Ana',
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    pending.complete(catalog);
    await tester.pumpAndSettle();
    expect(find.text('Club Diver'), findsOneWidget);
  });

  test('the Name column titles the custom level', () {
    final adapter = CertificationFieldAdapter.withCatalog(catalog);
    expect(
      adapter.extractValue(CertificationField.certName, cert),
      'Club Diver',
    );
  });
}
