import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart' show AppDatabase;
import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/features/certifications/data/repositories/certification_repository.dart';
import 'package:submersion/features/certifications/domain/entities/certification.dart';
import 'package:submersion/features/certifications/presentation/providers/certification_currency_providers.dart';
import 'package:submersion/features/certifications/presentation/providers/certification_providers.dart';
import 'package:submersion/features/dashboard/presentation/providers/milestone_providers.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/test_database.dart';

/// The home screen's certification inputs need credential metadata, never
/// the scanned cards, so what they read must not grow with the scans
/// (issue #3848).
void main() {
  late AppDatabase db;
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    db = await setUpStatementLoggingTestDatabase();
    await withoutStatementLog(() async {
      final now = DateTime(2024);
      final diver = await DiverRepository().createDiver(
        Diver(
          id: '',
          name: 'D',
          isDefault: true,
          createdAt: now,
          updatedAt: now,
        ),
      );
      await prefs.setString(currentDiverIdKey, diver.id);
      await CertificationRepository().createCertification(
        Certification(
          id: 'c1',
          diverId: diver.id,
          name: 'Open Water',
          agency: CertificationAgency.padi.name,
          level: CertificationLevel.openWater.name,
          issueDate: DateTime(2024, 11, 3),
          photoFront: Uint8List.fromList([1, 2, 3]),
          photoBack: Uint8List.fromList([4, 5, 6]),
          createdAt: now,
          updatedAt: now,
        ),
      );
      // A card the v277 copy skipped keeps its only copy on the row, so the
      // legacy columns can hold real scans too.
      await db.customStatement(
        "UPDATE certifications SET photo_front = x'010203', "
        "photo_back = x'040506'",
      );
    });
  });

  tearDown(tearDownTestDatabase);

  Future<List<String>> statementsDuring(Future<void> Function() body) async {
    final logged = <String>[];
    await runZoned(
      body,
      zoneSpecification: ZoneSpecification(
        print: (self, parent, zone, line) => logged.add(line),
      ),
    );
    return [
      for (final line in logged)
        if (line.startsWith('Drift: Sent')) line,
    ];
  }

  void expectNoCardBlobs(List<String> statements) {
    // Without this a broken capture would pass every check below.
    expect(
      statements.where((s) => s.contains('certifications')),
      isNotEmpty,
      reason: 'the read under test must have reached the certifications table',
    );
    expect(
      statements.where((s) => s.contains('document_pages')),
      isEmpty,
      reason: 'a metadata path must not read the card documents',
    );
    expect(
      statements.where(
        (s) =>
            s.contains('SELECT * FROM "certifications"') ||
            s.contains('SELECT * FROM certifications') ||
            s.contains('photo_front'),
      ),
      isEmpty,
      reason: 'a metadata path must not read the legacy photo columns',
    );
  }

  ProviderContainer makeContainer() {
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('the home attention chip reads no card images', () async {
    final container = makeContainer();

    final statements = await statementsDuring(() async {
      await container.read(currencyAttentionProvider.future);
    });

    expectNoCardBlobs(statements);
  });

  test('the home milestones read no card images', () async {
    final container = makeContainer();
    final sub = container.listen(milestonesProvider, (_, _) {});
    addTearDown(sub.close);

    final statements = await statementsDuring(() async {
      await container
          .read(certificationListNotifierProvider.notifier)
          .refresh();
    });

    expectNoCardBlobs(statements);
    expect(
      container
          .read(certificationListNotifierProvider)
          .value
          ?.map((c) => c.name),
      ['Open Water'],
    );
  });
}
