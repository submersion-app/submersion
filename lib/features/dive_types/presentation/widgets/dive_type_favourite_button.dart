import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_types/presentation/providers/dive_type_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The key of the star button for the dive type [id], for tests and for
/// telling one row's star from another's.
Key diveTypeFavouriteButtonKey(String id) => ValueKey('diveTypeFavourite:$id');

/// A star that makes a dive type a favourite, listed first in the dive type
/// pickers (issue #4413). Saves at once; filled while starred.
class DiveTypeFavouriteButton extends ConsumerWidget {
  const DiveTypeFavouriteButton({super.key, required this.diveTypeId});

  final String diveTypeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final starred = ref.watch(
      favouriteDiveTypeIdsProvider.select((ids) => ids.contains(diveTypeId)),
    );
    final l10n = context.l10n;
    return IconButton(
      key: diveTypeFavouriteButtonKey(diveTypeId),
      icon: Icon(
        starred ? Icons.star : Icons.star_border,
        color: starred ? Theme.of(context).colorScheme.primary : null,
      ),
      tooltip: starred
          ? l10n.diveTypes_favourite_remove
          : l10n.diveTypes_favourite_add,
      onPressed: () => ref
          .read(settingsProvider.notifier)
          .setDiveTypeFavourite(diveTypeId, !starred),
    );
  }
}
