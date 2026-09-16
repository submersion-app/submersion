import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/providers/ref_invalidate_on_change.dart';
import 'package:submersion/features/buddies/data/repositories/buddy_profile_link_repository.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_providers.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';

final buddyProfileLinkRepositoryProvider = Provider<BuddyProfileLinkRepository>(
  (ref) => BuddyProfileLinkRepository(
    buddies: ref.watch(buddyRepositoryProvider),
    divers: ref.watch(diverRepositoryProvider),
  ),
);

/// Arguments for [linkedProfileSuggestionProvider]: the owner list and the
/// name/email typed on the buddy page.
typedef LinkedProfileSuggestionArgs = ({
  String? ownerDiverId,
  String name,
  String? email,
});

/// The single profile a buddy page should offer to link, or null. Reads
/// both divers (the candidates) and buddies (whether one already holds the
/// link), so it follows both tables' ticks.
final linkedProfileSuggestionProvider = FutureProvider.autoDispose
    .family<Diver?, LinkedProfileSuggestionArgs>((ref, args) {
      ref.invalidateSelfWhen(
        ref.watch(diverRepositoryProvider).watchDiversChanges(),
      );
      ref.invalidateSelfWhen(
        ref.watch(buddyRepositoryProvider).watchBuddiesChanges(),
      );
      return ref
          .watch(buddyProfileLinkRepositoryProvider)
          .suggestProfileFor(
            ownerDiverId: args.ownerDiverId,
            name: args.name,
            email: args.email,
          );
    });
