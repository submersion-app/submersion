import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/certifications/domain/entities/certification.dart';
import 'package:submersion/features/certifications/domain/entities/currency_pref.dart';
import 'package:submersion/features/certifications/domain/entities/currency_rule.dart';
import 'package:submersion/features/certifications/domain/entities/dive_activity_index.dart';
import 'package:submersion/features/certifications/presentation/providers/certification_currency_providers.dart';
import 'package:submersion/features/certifications/presentation/providers/certification_providers.dart';

/// The providers that feed every currency surface (issue #2267).
final _t0 = DateTime(2020);

Certification _cert(String id, CertificationLevel level, {DateTime? expires}) =>
    Certification(
      id: id,
      name: id,
      agency: CertificationAgency.padi.name,
      level: level.name,
      expiryDate: expires,
      createdAt: _t0,
      updatedAt: _t0,
    );

final _refresher = CurrencyRule(
  id: 'padi_reactivate',
  name: 'PADI refresher',
  clockKind: CurrencyClockKind.activity,
  agencies: const [CertificationAgency.padi],
  levels: const [
    CertificationLevel.openWater,
    CertificationLevel.advancedOpenWater,
    CertificationLevel.rescue,
  ],
  lapseDays: 365,
  leadDays: 185,
  isBuiltIn: true,
  createdAt: _t0,
  updatedAt: _t0,
);

ProviderContainer _container({
  required List<Certification> certs,
  List<CurrencyPref> prefs = const [],
  DateTime? lastDive,
  bool rulesThrow = false,
}) {
  final c = ProviderContainer(
    overrides: [
      allCertificationsProvider.overrideWith((ref) async => certs),
      currencyRulesProvider.overrideWith((ref) async {
        if (rulesThrow) throw StateError('corrupt catalog');
        return [_refresher];
      }),
      currencyPrefsProvider.overrideWith((ref) async => prefs),
      currencyEventsProvider.overrideWith((ref) async => const []),
      diveActivityIndexProvider.overrideWith(
        (ref) async => DiveActivityIndex(lastDiveAt: lastDive),
      ),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

void main() {
  final ladder = [
    _cert('ow', CertificationLevel.openWater),
    _cert('aow', CertificationLevel.advancedOpenWater),
    _cert('res', CertificationLevel.rescue),
  ];

  test('attention counts the certifications it names, each once', () async {
    // One collapsed refresher row covers OW, AOW and Rescue. The chip says
    // "certifications", and the list it opens shows these three cards, so
    // the count is three, not one row.
    final c = _container(certs: ladder, lastDive: DateTime(2020, 1, 1));
    final attention = await c.read(currencyAttentionProvider.future);
    expect(attention.count, 3);
    expect(attention.anyLapsed, isTrue);
    expect(attention.certificationIds, {'ow', 'aow', 'res'});
  });

  test('a card needing attention twice counts once', () async {
    // The nitrox card lapses on its expiry; give it the refresher too.
    final c = _container(
      certs: [
        _cert(
          'ow',
          CertificationLevel.openWater,
          expires: DateTime(2021, 1, 1),
        ),
      ],
      lastDive: DateTime(2020, 1, 1),
    );
    final attention = await c.read(currencyAttentionProvider.future);
    expect(attention.certificationIds, {'ow'});
    expect(attention.count, 1);
  });

  test('a card with no counted dive never counts', () async {
    final c = _container(certs: ladder);
    final attention = await c.read(currencyAttentionProvider.future);
    expect(attention.count, 0);
    expect(attention.certificationIds, isEmpty);
  });

  test('muted groups never count', () async {
    final c = _container(
      certs: [ladder.first],
      lastDive: DateTime(2020, 1, 1),
      prefs: [
        CurrencyPref(
          id: 'p',
          certificationId: 'ow',
          ruleId: 'padi_reactivate',
          muted: true,
          createdAt: _t0,
          updatedAt: _t0,
        ),
      ],
    );
    final attention = await c.read(currencyAttentionProvider.future);
    expect(attention.count, 0);
    expect(attention.certificationIds, isEmpty);
  });

  test('anyHardened only for an entered-date lapse', () async {
    final inferred = _container(certs: ladder, lastDive: DateTime(2020, 1, 1));
    expect(
      (await inferred.read(currencyAttentionProvider.future)).anyHardened,
      isFalse,
    );

    final expired = _container(
      certs: [
        _cert('nx', CertificationLevel.nitrox, expires: DateTime(2021, 1, 1)),
        ...ladder,
      ],
      lastDive: DateTime(2020, 1, 1),
    );
    final attention = await expired.read(currencyAttentionProvider.future);
    expect(attention.anyHardened, isTrue);
    expect(attention.count, 4);
    expect(attention.hardenedCount, 1, reason: 'only the expired card');
  });

  test('a currency failure returns empty, never throws', () async {
    final c = _container(
      certs: ladder,
      lastDive: DateTime(2020, 1, 1),
      rulesThrow: true,
    );
    expect(await c.read(credentialCurrencyProvider.future), isEmpty);
    final attention = await c.read(currencyAttentionProvider.future);
    expect(attention.count, 0);
  });

  test('per card groups include every group the card is a member of', () async {
    final c = _container(certs: ladder, lastDive: DateTime(2020, 1, 1));
    final groups = await c.read(
      certificationCurrencyGroupsProvider('aow').future,
    );
    expect(groups, hasLength(1));
    expect(groups.single.representative.certification.id, 'res');
    expect(
      await c.read(certificationCurrencyGroupsProvider('unknown').future),
      isEmpty,
    );
  });
}
