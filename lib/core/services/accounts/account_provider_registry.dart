import 'package:submersion/core/services/accounts/account_kind.dart';
import 'package:submersion/core/services/accounts/account_provider_adapter.dart';

/// Maps [AccountKind] to its adapter. Construction-time registration keeps
/// the mapping total and testable; features query capabilities, never
/// concrete adapter types.
class AccountProviderRegistry {
  AccountProviderRegistry(List<AccountProviderAdapter> adapters)
    : _adapters = {for (final a in adapters) a.kind: a};

  final Map<AccountKind, AccountProviderAdapter> _adapters;

  AccountProviderAdapter adapterFor(AccountKind kind) {
    final adapter = _adapters[kind];
    if (adapter == null) {
      throw StateError('No account adapter registered for $kind');
    }
    return adapter;
  }

  /// The adapter for [kind] as capability [T], or null when the kind is
  /// unregistered or lacks the capability.
  T? capabilityFor<T>(AccountKind kind) {
    final adapter = _adapters[kind];
    return adapter is T ? adapter as T : null;
  }
}
