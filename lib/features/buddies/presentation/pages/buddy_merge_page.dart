import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/buddies/presentation/pages/buddy_edit_page.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Wrapper page that loads buddy data for a merge operation, then delegates
/// to [BuddyEditPage] in merge mode with the loaded buddies.
class BuddyMergePage extends ConsumerStatefulWidget {
  final List<String> buddyIds;

  const BuddyMergePage({super.key, required this.buddyIds});

  @override
  ConsumerState<BuddyMergePage> createState() => _BuddyMergePageState();
}

class _BuddyMergePageState extends ConsumerState<BuddyMergePage> {
  late final Future<List<Buddy>> _loadFuture;

  @override
  void initState() {
    super.initState();
    _loadFuture = _loadMergeBuddies();
  }

  Future<List<Buddy>> _loadMergeBuddies() async {
    final repository = ref.read(buddyRepositoryProvider);
    final fetched = await Future.wait(
      widget.buddyIds.map((id) => repository.getBuddyById(id)),
    );
    final buddiesById = <String, Buddy>{
      for (final buddy in fetched)
        if (buddy != null) buddy.id: buddy,
    };
    return widget.buddyIds
        .map((id) => buddiesById[id])
        .whereType<Buddy>()
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Buddy>>(
      future: _loadFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Scaffold(
            appBar: AppBar(title: Text(context.l10n.buddies_edit_merge_title)),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(
              title: Text(context.l10n.buddies_edit_merge_loadingErrorTitle),
            ),
            body: Center(
              child: Text(
                context.l10n.buddies_edit_merge_loadingErrorBody(
                  '${snapshot.error}',
                ),
              ),
            ),
          );
        }

        final buddies = snapshot.data;
        if (buddies == null || buddies.length < 2) {
          return Scaffold(
            appBar: AppBar(
              title: Text(context.l10n.buddies_edit_merge_notEnoughTitle),
            ),
            body: Center(
              child: Text(context.l10n.buddies_edit_merge_notEnoughBody),
            ),
          );
        }

        return BuddyEditPage(mergeBuddies: buddies);
      },
    );
  }
}
