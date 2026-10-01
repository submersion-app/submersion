import 'package:flutter_riverpod/flutter_riverpod.dart';

extension AsyncValueX<T> on AsyncValue<T> {
  T? get valueOrNull =>
      when(data: (value) => value, error: (_, _) => null, loading: () => null);

  /// Whether the rows have loaded or failed, so a list may prune its
  /// selection to them. A first load has no rows yet (a new query's id set
  /// starts that way), and pruning to that empty frame would drop every
  /// check the diver made.
  bool get hasSettled => hasValue || hasError;
}
