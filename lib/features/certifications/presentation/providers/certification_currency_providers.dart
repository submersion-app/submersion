import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/features/certifications/data/repositories/certification_currency_repository.dart';
import 'package:submersion/features/certifications/domain/entities/currency_event.dart';
import 'package:submersion/features/certifications/domain/entities/currency_pref.dart';
import 'package:submersion/features/certifications/domain/entities/currency_rule.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';

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
