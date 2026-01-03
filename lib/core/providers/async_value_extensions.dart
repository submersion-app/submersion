import 'package:flutter_riverpod/flutter_riverpod.dart';

extension AsyncValueX<T> on AsyncValue<T> {
  T? get valueOrNull => when(
        data: (value) => value,
        error: (_, __) => null,
        loading: () => null,
      );
}
