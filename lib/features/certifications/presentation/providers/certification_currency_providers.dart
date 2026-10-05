import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/logger_service.dart';

import 'package:submersion/features/certifications/data/repositories/certification_currency_repository.dart';
import 'package:submersion/features/certifications/data/repositories/dive_activity_repository.dart';
import 'package:submersion/features/certifications/domain/entities/credential_currency.dart';
import 'package:submersion/features/certifications/domain/entities/dive_activity_index.dart';
import 'package:submersion/features/certifications/domain/services/certification_currency_engine.dart';
import 'package:submersion/features/certifications/domain/entities/currency_event.dart';
import 'package:submersion/features/certifications/domain/entities/currency_pref.dart';
import 'package:submersion/features/certifications/domain/entities/currency_rule.dart';
import 'package:submersion/features/certifications/presentation/providers/certification_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';

final _log = LoggerService.forClass(CertificationCurrencyRepository);

/// Repository provider for certification currency (issue #2267).
final certificationCurrencyRepositoryProvider =
    Provider<CertificationCurrencyRepository>((ref) {
      return CertificationCurrencyRepository();
    });

/// The rules that apply to the active diver: every built-in, the diver's
/// own custom rules, and unowned custom rules. Self-invalidates on any
/// currency table change, including sync.
final currencyRulesProvider = FutureProvider<List<CurrencyRule>>((ref) async {
  final repository = ref.watch(certificationCurrencyRepositoryProvider);
  final diverId = await ref.watch(validatedCurrentDiverIdProvider.future);
  ref.invalidateSelfWhen(repository.watchCurrencyChanges());
  return repository.getRulesForDiver(diverId);
});

/// Every currency pref. Prefs hang off certifications, which are already
/// scoped to the active diver, so the engine ignores prefs of other cards.
final currencyPrefsProvider = FutureProvider<List<CurrencyPref>>((ref) async {
  final repository = ref.watch(certificationCurrencyRepositoryProvider);
  ref.invalidateSelfWhen(repository.watchCurrencyChanges());
  return repository.getAllPrefs();
});

/// Every currency ledger event, scoped the same way as [currencyPrefsProvider].
final currencyEventsProvider = FutureProvider<List<CurrencyEvent>>((ref) async {
  final repository = ref.watch(certificationCurrencyRepositoryProvider);
  ref.invalidateSelfWhen(repository.watchCurrencyChanges());
  return repository.getAllEvents();
});

/// One certification's ledger, newest first.
final certificationCurrencyEventsProvider =
    FutureProvider.family<List<CurrencyEvent>, String>((
      ref,
      certificationId,
    ) async {
      final repository = ref.watch(certificationCurrencyRepositoryProvider);
      ref.invalidateSelfWhen(repository.watchCurrencyChanges());
      return repository.getEvents(certificationId);
    });

final diveActivityRepositoryProvider = Provider<DiveActivityRepository>(
  (ref) => DiveActivityRepository(),
);

final diveActivityIndexProvider = FutureProvider<DiveActivityIndex>((
  ref,
) async {
  final repository = ref.watch(diveActivityRepositoryProvider);
  final diverId = await ref.watch(validatedCurrentDiverIdProvider.future);
  ref.invalidateSelfWhen(repository.watchDiveChanges());
  return repository.buildIndex(diverId: diverId);
});

/// Every status, uncollapsed. Catches its own failures: the home strip awaits
/// this inside dashboardGaugesProvider, and an uncaught throw would take the
/// whole strip, hardened safety chips included, to its retry chip.
final credentialCurrencyProvider = FutureProvider<List<CredentialCurrency>>((
  ref,
) async {
  // Watch every input before awaiting any, so they load concurrently.
  final certifications = ref.watch(allCertificationsProvider.future);
  final rules = ref.watch(currencyRulesProvider.future);
  final prefs = ref.watch(currencyPrefsProvider.future);
  final events = ref.watch(currencyEventsProvider.future);
  final activity = ref.watch(diveActivityIndexProvider.future);
  try {
    return evaluateCurrency(
      certifications: await certifications,
      rules: await rules,
      prefs: await prefs,
      events: await events,
      activity: await activity,
      now: DateTime.now(),
    );
  } catch (e, stackTrace) {
    _log.error(
      'Certification currency unavailable; the chip is hidden',
      error: e,
      stackTrace: stackTrace,
    );
    return const [];
  }
});

final currencyGroupsProvider = FutureProvider<List<CurrencyGroup>>(
  (ref) async =>
      collapseCurrency(await ref.watch(credentialCurrencyProvider.future)),
);

class CurrencyAttention {
  /// Distinct certifications needing attention.
  final int count;
  final bool anyLapsed;
  final bool anyHardened;

  /// Distinct certifications with a hardened lapse: what the chip still
  /// names when the diver has hidden it.
  final int hardenedCount;
  final Set<String> certificationIds;

  const CurrencyAttention({
    this.count = 0,
    this.anyLapsed = false,
    this.anyHardened = false,
    this.hardenedCount = 0,
    this.certificationIds = const {},
  });

  static const none = CurrencyAttention();
}

final currencyAttentionProvider = FutureProvider<CurrencyAttention>((
  ref,
) async {
  final groups = [
    for (final g in await ref.watch(currencyGroupsProvider.future))
      if (g.needsAttention) g,
  ];
  final ids = {for (final g in groups) ...g.certificationIds};
  // The chip counts certifications, each once, matching the list it opens:
  // one refresher row covering three cards is three, and a card needing two
  // refreshers is one.
  return CurrencyAttention(
    count: ids.length,
    anyLapsed: groups.any((g) => g.severity == CurrencySeverity.lapsed),
    anyHardened: groups.any((g) => g.hardened),
    hardenedCount: {
      for (final g in groups)
        if (g.hardened) ...g.certificationIds,
    }.length,
    certificationIds: ids,
  );
});

final certificationCurrencyGroupsProvider =
    FutureProvider.family<List<CurrencyGroup>, String>((ref, certId) async {
      return [
        for (final g in await ref.watch(currencyGroupsProvider.future))
          if (g.certificationIds.contains(certId)) g,
      ];
    });
