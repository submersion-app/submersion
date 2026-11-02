import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/global_search/presentation/global_search_navigation.dart';
import 'package:submersion/l10n/l10n_extension.dart';

const kSearchEverywhereRowKey = ValueKey('search-everywhere-row');

/// The row under a list's search field that takes the typed text to global
/// search (#3882): `Search everything for "text"`. It offers the text as
/// typed, parsed or not, so a query this list cannot read (`expires < 2027`
/// on Buddies) still finds the records that can.
class SearchEverywhereRow extends ConsumerWidget {
  const SearchEverywhereRow({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context, WidgetRef ref) => ListTile(
    key: kSearchEverywhereRowKey,
    dense: true,
    leading: const Icon(Icons.travel_explore),
    title: Text(
      context.l10n.search_everywhere(text.trim()),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    ),
    trailing: const Icon(Icons.chevron_right),
    onTap: () => openGlobalSearch(context, ref, text.trim()),
  );
}
