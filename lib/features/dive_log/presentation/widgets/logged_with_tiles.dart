import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_mirror_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/profile_photo/profile_avatar.dart';

/// The sibling dives of [diveId] (other profiles' logs of the same outing,
/// issue #2002), one tile each, opening the sibling. Renders nothing
/// without siblings.
class LoggedWithTiles extends ConsumerWidget {
  final String diveId;

  const LoggedWithTiles({super.key, required this.diveId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final siblings = ref.watch(siblingDivesProvider(diveId)).value;
    if (siblings == null || siblings.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Text(
            context.l10n.diveLog_detail_loggedWith,
            style: Theme.of(context).textTheme.labelLarge,
          ),
        ),
        for (final sibling in siblings) _SiblingTile(dive: sibling),
      ],
    );
  }
}

class _SiblingTile extends ConsumerWidget {
  final Dive dive;

  const _SiblingTile({required this.dive});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ownerId = dive.diverId;
    final owner = ownerId == null
        ? null
        : ref.watch(diverByIdProvider(ownerId)).value;
    return ListTile(
      key: Key('logged_with_${dive.id}'),
      contentPadding: EdgeInsets.zero,
      leading: ProfileAvatar(
        photo: owner?.photo,
        initials: owner?.initials ?? '?',
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      ),
      title: Text(owner?.name ?? ''),
      subtitle: dive.isPlanned
          ? Text(context.l10n.diveLog_detail_loggedWithPlanned)
          : null,
      trailing: const Icon(Icons.chevron_right, size: 20),
      onTap: () => context.push('/dives/${dive.id}'),
    );
  }
}
