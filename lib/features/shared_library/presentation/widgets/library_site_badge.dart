import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/shared_library/presentation/providers/shared_library_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// A small group glyph beside the name of a club library site, with the
/// library's name as tooltip (issue #2567). Nothing for a personal site.
class LibrarySiteBadge extends ConsumerWidget {
  const LibrarySiteBadge({super.key, required this.site, this.size = 16});

  final DiveSite site;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = site.sharedLibraryId;
    if (id == null) return const SizedBox.shrink();
    final libraries = ref.watch(sharedLibrariesProvider).valueOrNull;
    var name = '';
    for (final l in libraries ?? const []) {
      if (l.id == id) name = l.name;
    }
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 6),
      child: Tooltip(
        message: context.l10n.sharedLibrary_site_badgeTooltip(name),
        child: Icon(
          Icons.groups_outlined,
          size: size,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}
