import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Picks one of the diver's buddies, or one added on the spot. Null when
/// dismissed.
Future<Buddy?> showBuddyPickSheet(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet<Buddy>(
    context: context,
    isScrollControlled: true,
    builder: (_) =>
        const FractionallySizedBox(heightFactor: 0.8, child: _BuddyPick()),
  );
}

class _BuddyPick extends ConsumerStatefulWidget {
  const _BuddyPick();

  @override
  ConsumerState<_BuddyPick> createState() => _BuddyPickState();
}

class _BuddyPickState extends ConsumerState<_BuddyPick> {
  String _search = '';

  Future<void> _addBuddy() async {
    final created = await context.push<Buddy>('/buddies/new');
    if (created == null || !mounted) return;
    ref.invalidate(allBuddiesProvider);
    Navigator.of(context).pop(created);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final everyone = ref.watch(allBuddiesProvider).value ?? const <Buddy>[];
    final query = _search.trim().toLowerCase();
    final buddies = [
      for (final b in everyone)
        if (query.isEmpty || b.name.toLowerCase().contains(query)) b,
    ];
    return SafeArea(
      child: Column(
        children: [
          ListTile(
            title: Text(
              l10n.equipment_location_pickBuddy_title,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            trailing: IconButton(
              icon: const Icon(Icons.close),
              tooltip: l10n.common_action_close,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: l10n.buddies_picker_searchHint,
              ),
              onChanged: (v) => setState(() => _search = v),
            ),
          ),
          Expanded(
            child: ListView(
              children: [
                ListTile(
                  key: const ValueKey('buddy_pick_add'),
                  leading: const Icon(Icons.person_add),
                  title: Text(l10n.buddies_picker_addNew),
                  onTap: _addBuddy,
                ),
                const Divider(height: 1),
                if (buddies.isEmpty)
                  ListTile(
                    title: Text(
                      everyone.isEmpty
                          ? l10n.buddies_picker_noBuddiesYet
                          : l10n.buddies_picker_noBuddiesFound,
                    ),
                  ),
                for (final b in buddies)
                  ListTile(
                    key: ValueKey('buddy_pick_${b.id}'),
                    leading: const Icon(Icons.person_outline),
                    title: Text(b.name),
                    onTap: () => Navigator.of(context).pop(b),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
