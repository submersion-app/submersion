import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/certification_agencies/domain/certification_catalog.dart';
import 'package:submersion/features/certification_agencies/domain/entities/custom_certification_agency.dart';
import 'package:submersion/features/certification_agencies/presentation/providers/certification_catalog_context.dart';
import 'package:submersion/features/certification_agencies/presentation/providers/certification_catalog_providers.dart';

void main() {
  final custom = CertificationCatalog(
    agencies: [
      CustomCertificationAgency(
        id: 'u1',
        diverId: 'a',
        name: 'Club X',
        colorArgb: 0xFF3B82F6,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
    ],
  );

  Widget probe(void Function(CertificationCatalog) seen) => Builder(
    builder: (context) {
      seen(context.certificationCatalog);
      return const SizedBox();
    },
  );

  testWidgets('reads the live catalog under a ProviderScope', (tester) async {
    CertificationCatalog? seen;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [certificationCatalogSyncProvider.overrideWithValue(custom)],
        child: probe((c) => seen = c),
      ),
    );
    expect(seen!.agency('u1').name, 'Club X');
  });

  testWidgets('falls back to built-ins with no ProviderScope', (tester) async {
    CertificationCatalog? seen;
    await tester.pumpWidget(probe((c) => seen = c));
    expect(identical(seen, CertificationCatalog.builtInOnly), isTrue);
  });
}
