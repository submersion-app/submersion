import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_providers.dart';

/// Records every call made on the buddy list instead of reaching the real
/// repository, which widget tests have no database for, so a test can show
/// that a tap wrote nothing. Every call is a no-op, mirroring the
/// `noSuchMethod`-based mocks elsewhere in this feature.
class FakeBuddyListNotifier extends StateNotifier<AsyncValue<List<Buddy>>>
    implements BuddyListNotifier {
  FakeBuddyListNotifier() : super(const AsyncValue.data(<Buddy>[]));

  /// The names of the methods called, in order.
  final List<Symbol> calls = [];

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.isMethod) calls.add(invocation.memberName);
    return null;
  }
}
