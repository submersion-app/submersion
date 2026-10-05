import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/certification_agencies/data/repositories/custom_certification_repository.dart';
import 'package:submersion/features/certification_agencies/domain/entities/certification_usage.dart';
import 'package:submersion/features/certification_agencies/domain/entities/custom_certification_agency.dart';
import 'package:submersion/features/certification_agencies/presentation/pages/certification_agencies_page.dart';
import 'package:submersion/features/certification_agencies/domain/entities/custom_certification_level.dart';
import 'package:submersion/features/certification_agencies/presentation/providers/certification_catalog_providers.dart';
import 'package:submersion/features/certification_agencies/presentation/widgets/certification_level_dialog.dart';
import 'package:submersion/features/certification_agencies/presentation/widgets/custom_agency_dialog.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../helpers/mock_providers.dart';

/// A repository whose writes fail for a reason that is not a name clash.
class _FailingRepository extends CustomCertificationRepository {
  _FailingRepository({this.agencies = const []});

  final List<CustomCertificationAgency> agencies;

  @override
  Stream<void> watchChanges() => const Stream.empty();

  @override
  Future<List<CustomCertificationAgency>> getAllAgencies() async => agencies;

  @override
  Future<CertificationUsage> agencyUsage(String id) async =>
      const CertificationUsage();

  @override
  Future<CertificationUsage?> deleteAgency(
    String id, {
    required String actingDiverId,
  }) => Future.error(StateError('disk full'));

  @override
  Future<List<CustomCertificationLevel>> getAllLevels() async => const [];

  @override
  Future<CustomCertificationAgency> createAgency({
    required String diverId,
    required String name,
    int? colorArgb,
    required bool isShared,
  }) => Future.error(StateError('disk full'));

  @override
  Future<CustomCertificationLevel> createLevel({
    required String diverId,
    required String agencyId,
    required String name,
    required bool isProgression,
    required bool isShared,
  }) => Future.error(StateError('disk full'));
}

/// Issue #690: an unexpected failure must not leave a dialog with both of
/// its buttons disabled.
void main() {
  Future<void> pumpOpener(
    WidgetTester tester,
    Future<Object?> Function(BuildContext) open,
  ) async {
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...overrides,
          customCertificationRepositoryProvider.overrideWithValue(
            _FailingRepository(),
          ),
          validatedCurrentDiverIdProvider.overrideWith((ref) async => 'a'),
          allDiversProvider.overrideWith((ref) async => const []),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => open(context),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Future<void> expectRecovered(WidgetTester tester) async {
    await tester.enterText(find.byType(TextField).last, 'Club X');
    await tester.tap(find.text('Save').last);
    await tester.pumpAndSettle();
    final save = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(save.onPressed, isNotNull, reason: 'Save is usable again');
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.textContaining('Something went wrong'), findsOneWidget);
  }

  testWidgets('the agency dialog recovers from an unexpected error', (
    tester,
  ) async {
    await pumpOpener(tester, (c) => showCustomAgencyDialog(c));
    await expectRecovered(tester);
  });

  testWidgets('the level dialog recovers from an unexpected error', (
    tester,
  ) async {
    await pumpOpener(
      tester,
      (c) => showCertificationLevelDialog(c, agencyId: 'padi'),
    );
    await expectRecovered(tester);
  });

  testWidgets('a failed delete on the manage page reports it', (tester) async {
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...overrides,
          customCertificationRepositoryProvider.overrideWithValue(
            _FailingRepository(
              agencies: [
                CustomCertificationAgency(
                  id: 'club',
                  diverId: 'a',
                  name: 'Club X',
                  colorArgb: 0xFF0EA5E9,
                  createdAt: DateTime(2026),
                  updatedAt: DateTime(2026),
                ),
              ],
            ),
          ),
          validatedCurrentDiverIdProvider.overrideWith((ref) async => 'a'),
          allDiversProvider.overrideWith((ref) async => const []),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: CertificationAgenciesPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete').last);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.textContaining('Something went wrong'), findsOneWidget);
  });
}
