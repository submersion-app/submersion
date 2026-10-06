import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/services/export/export_service.dart';
import 'package:submersion/core/services/export/models/currency_backup_data.dart';
import 'package:submersion/features/certifications/data/repositories/certification_currency_repository.dart';
import 'package:submersion/features/certifications/data/repositories/certification_repository.dart';
import 'package:submersion/features/certifications/domain/entities/certification.dart';
import 'package:submersion/features/certifications/domain/entities/currency_event.dart';
import 'package:submersion/features/certifications/domain/entities/currency_pref.dart';
import 'package:submersion/features/certifications/domain/entities/currency_rule.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/export_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

/// Both full UDDF export paths load the diver's certification currency rows
/// and pass them on (issue #2267).
///
/// The round-trip test proves the writer and parser agree; this proves the
/// app actually reaches them. Without it the export could pass an empty
/// bundle forever while every round-trip test stayed green.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late String certId;

  setUp(() async {
    await setUpTestDatabase();
    final now = DateTime.utc(2026, 3, 1);
    await DiverRepository().createDiver(
      Diver(
        id: 'me',
        name: 'Me',
        isDefault: true,
        createdAt: now,
        updatedAt: now,
      ),
    );
    // The export refuses a library with no dives and no sites.
    await SiteRepository().createSite(
      const DiveSite(id: '', name: 'House reef', diverId: 'me'),
    );
    final cert = await CertificationRepository().createCertification(
      Certification(
        id: '',
        diverId: 'me',
        name: 'Open Water',
        agency: CertificationAgency.padi.name,
        level: CertificationLevel.openWater.name,
        createdAt: now,
        updatedAt: now,
      ),
    );
    certId = cert.id;
    final currency = CertificationCurrencyRepository();
    await currency.createRule(
      CurrencyRule(
        id: 'custom-1',
        diverId: 'me',
        name: 'Club refresher',
        clockKind: CurrencyClockKind.activity,
        lapseDays: 200,
        leadDays: 30,
        createdAt: now,
        updatedAt: now,
      ),
    );
    await currency.upsertPref(
      CurrencyPref(
        id: 'p1',
        certificationId: cert.id,
        ruleId: 'padi_reactivate',
        muted: true,
        createdAt: now,
        updatedAt: now,
      ),
    );
    await currency.createEvent(
      CurrencyEvent(
        id: 'e1',
        certificationId: cert.id,
        ruleId: 'padi_reactivate',
        eventType: CurrencyEventType.refresher,
        eventDate: DateTime(2026, 2, 1),
        createdAt: now,
        updatedAt: now,
      ),
    );
  });

  tearDown(tearDownTestDatabase);

  ProviderContainer make(_CapturingExportService export) {
    final container = ProviderContainer(
      overrides: [
        currentDiverIdProvider.overrideWith(
          (ref) => MockCurrentDiverIdNotifier()..state = 'me',
        ),
        settingsProvider.overrideWith((ref) => _FixedSettings()),
        exportServiceProvider.overrideWithValue(export),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  for (final save in [false, true]) {
    test('${save ? 'saving' : 'sharing'} passes the currency rows', () async {
      final export = _CapturingExportService();
      final container = make(export);
      final notifier = container.read(exportNotifierProvider.notifier);
      await (save ? notifier.saveUddfToFile() : notifier.exportDivesToUddf());

      final state = container.read(exportNotifierProvider);
      expect(state.status, ExportStatus.success, reason: state.message);
      final currency = export.currency;
      expect(currency, isNotNull, reason: 'the export passed no bundle');
      expect(currency!.customRules.map((r) => r.id), ['custom-1']);
      expect(currency.prefs.single.certificationId, certId);
      expect(currency.prefs.single.muted, isTrue);
      expect(currency.events.single.id, 'e1');
    });
  }
}

class _CapturingExportService implements ExportService {
  CurrencyBackupData? currency;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    final name = invocation.memberName;
    if (name == #exportAllDataToUddf || name == #saveAllDataToUddfFile) {
      currency = invocation.namedArguments[#currency] as CurrencyBackupData?;
      return name == #exportAllDataToUddf
          ? Future<String>.value('/tmp/export.uddf')
          : Future<String?>.value('/tmp/export.uddf');
    }
    return null;
  }
}

class _FixedSettings extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _FixedSettings() : super(const AppSettings());

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
