import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_providers.dart';

/// Records [toggleFavorite] calls instead of reaching the real repository,
/// which widget tests have no database for. Every other call is a no-op,
/// mirroring the `noSuchMethod`-based mocks elsewhere in this feature.
class FakeBuddyListNotifier extends StateNotifier<AsyncValue<List<Buddy>>>
    implements BuddyListNotifier {
  FakeBuddyListNotifier() : super(const AsyncValue.data(<Buddy>[]));

  final List<String> toggledFavoriteIds = [];

  @override
  Future<void> toggleFavorite(String buddyId) async {
    toggledFavoriteIds.add(buddyId);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
