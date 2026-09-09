import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/certifications/data/repositories/certification_repository.dart';
import 'package:submersion/features/certifications/domain/entities/certification.dart';
import 'package:submersion/features/certifications/presentation/pages/certification_edit_page.dart';
import 'package:submersion/features/certifications/presentation/providers/certification_providers.dart';
import 'package:submersion/features/certifications/presentation/widgets/certification_option.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

/// The editor's credential list: "Add another recognition" turns the single
/// agency/level pair into a repeatable list of equal-rank recognitions, all
/// written to the one card (row 0 -> agency/level columns, the rest ->
/// Certification.additionalCredentials).
void main() {
  late CertificationRepository repository;

  setUp(() async {
    await setUpTestDatabase();
    repository = CertificationRepository();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  Future<Widget> buildHarness(
    WidgetTester tester, {
    String? certificationId,
  }) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final overrides = await getBaseOverrides();
    return ProviderScope(
      overrides: [
        ...overrides,
        certificationRepositoryProvider.overrideWithValue(repository),
      ],
      child: MaterialApp(
        // Pinned: this test asserts English literals, and flutter_test
        // forwards the HOST machine's locale list, so an unpinned
        // MaterialApp renders translated on a non-English dev machine.
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: CertificationEditPage(
            certificationId: certificationId,
            embedded: true,
          ),
        ),
      ),
    );
  }

  Finder agencyDropdowns() =>
      find.byType(DropdownButtonFormField<CertificationAgency>);
  Finder levelDropdowns() =>
      find.byType(DropdownButtonFormField<CertificationOption>);

  Future<void> selectFromDropdown(
    WidgetTester tester,
    Finder dropdown,
    String optionLabel,
  ) async {
    await tester.ensureVisible(dropdown);
    await tester.pumpAndSettle();
    await tester.tap(dropdown);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text(optionLabel),
      100.0,
      scrollable: find.byType(Scrollable).last,
    );
    final item = find.text(optionLabel).last;
    await tester.ensureVisible(item);
    await tester.pumpAndSettle();
    await tester.tap(item);
    await tester.pumpAndSettle();
  }

  testWidgets('starts with a single credential row', (tester) async {
    await tester.pumpWidget(await buildHarness(tester));
    await tester.pumpAndSettle();

    expect(agencyDropdowns(), findsOneWidget);
    expect(levelDropdowns(), findsOneWidget);
  });

  testWidgets('"Add another recognition" appends an equal-rank row', (
    tester,
  ) async {
    await tester.pumpWidget(await buildHarness(tester));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add another recognition'));
    await tester.pumpAndSettle();

    expect(agencyDropdowns(), findsNWidgets(2));
    expect(levelDropdowns(), findsNWidgets(2));
    // Both rows can now be removed (the row is only fixed while it is alone).
    expect(find.byTooltip('Remove this recognition'), findsNWidgets(2));
  });

  testWidgets('removing the second row returns to a single row', (
    tester,
  ) async {
    await tester.pumpWidget(await buildHarness(tester));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add another recognition'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Remove this recognition').last);
    await tester.pumpAndSettle();

    expect(agencyDropdowns(), findsOneWidget);
    expect(find.byTooltip('Remove this recognition'), findsNothing);
  });

  testWidgets('a second recognition is saved to additionalCredentials', (
    tester,
  ) async {
    await tester.pumpWidget(await buildHarness(tester));
    await tester.pumpAndSettle();

    // Row 0: PADI (default agency) Open Water.
    await selectFromDropdown(tester, levelDropdowns().first, 'Open Water');

    // Row 1: CMAS 1-star -- equal rank, same card.
    await tester.tap(find.text('Add another recognition'));
    await tester.pumpAndSettle();
    await selectFromDropdown(tester, agencyDropdowns().last, 'CMAS');
    await selectFromDropdown(tester, levelDropdowns().last, '1★ Diver');

    await tester.tap(find.text('Save'));
    await tester.pump(const Duration(seconds: 1));

    final saved = await tester.runAsync(
      () => repository.getAllCertifications(),
    );
    expect(saved, hasLength(1));
    final cert = saved!.single;
    expect(cert.agency, CertificationAgency.padi);
    expect(cert.level, CertificationLevel.openWater);
    expect(cert.additionalCredentials, hasLength(1));
    expect(cert.additionalCredentials.single.agency, CertificationAgency.cmas);
    expect(
      cert.additionalCredentials.single.level,
      CertificationLevel.cmas1StarDiver,
    );
    expect(cert.hasMultipleCredentials, isTrue);
  });

  testWidgets('an existing multi-credential card prefills every row', (
    tester,
  ) async {
    final now = DateTime(2024);
    final cert = await repository.createCertification(
      Certification(
        id: '',
        name: '',
        agency: CertificationAgency.ffessm,
        level: CertificationLevel.ffessmN1,
        additionalCredentials: const [
          CertificationCredential(
            agency: CertificationAgency.cmas,
            level: CertificationLevel.cmas1StarDiver,
          ),
        ],
        createdAt: now,
        updatedAt: now,
      ),
    );

    await tester.pumpWidget(
      await buildHarness(tester, certificationId: cert.id),
    );
    await tester.pumpAndSettle();

    expect(agencyDropdowns(), findsNWidgets(2));
    expect(
      find.descendant(of: agencyDropdowns().last, matching: find.text('CMAS')),
      findsOneWidget,
    );
  });
}
