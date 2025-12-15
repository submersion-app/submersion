import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/entities/buddy.dart';
import '../providers/buddy_providers.dart';

class BuddyListPage extends ConsumerWidget {
  const BuddyListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final buddiesAsync = ref.watch(buddyListNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Buddies'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              showSearch(
                context: context,
                delegate: BuddySearchDelegate(ref),
              );
            },
          ),
        ],
      ),
      body: buddiesAsync.when(
        data: (buddies) => buddies.isEmpty
            ? _buildEmptyState(context)
            : _buildBuddyList(context, ref, buddies),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error loading buddies: $error'),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () =>
                    ref.read(buddyListNotifierProvider.notifier).refresh(),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/buddies/new'),
        icon: const Icon(Icons.person_add),
        label: const Text('Add Buddy'),
      ),
    );
  }

  Widget _buildBuddyList(
      BuildContext context, WidgetRef ref, List<Buddy> buddies) {
    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(buddyListNotifierProvider.notifier).refresh();
      },
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 80),
        itemCount: buddies.length,
        itemBuilder: (context, index) {
          final buddy = buddies[index];
          return BuddyListTile(
            buddy: buddy,
            onTap: () => context.push('/buddies/${buddy.id}'),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.people_outline,
            size: 80,
            color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No buddies added yet',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Add your dive buddies to track who you dive with',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => context.push('/buddies/new'),
            icon: const Icon(Icons.person_add),
            label: const Text('Add Your First Buddy'),
          ),
        ],
      ),
    );
  }
}

/// List item widget for displaying a buddy
class BuddyListTile extends StatelessWidget {
  final Buddy buddy;
  final VoidCallback? onTap;

  const BuddyListTile({
    super.key,
    required this.buddy,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          backgroundImage:
              buddy.photoPath != null ? AssetImage(buddy.photoPath!) : null,
          child: buddy.photoPath == null
              ? Text(
                  buddy.initials,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
                )
              : null,
        ),
        title: Text(buddy.name),
        subtitle: _buildSubtitle(context),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }

  Widget? _buildSubtitle(BuildContext context) {
    final parts = <String>[];

    if (buddy.certificationLevel != null) {
      parts.add(buddy.certificationLevel!.displayName);
    }
    if (buddy.certificationAgency != null) {
      parts.add(buddy.certificationAgency!.displayName);
    }

    if (parts.isEmpty) {
      return null;
    }

    return Text(parts.join(' - '));
  }
}

/// Search delegate for buddies
class BuddySearchDelegate extends SearchDelegate<Buddy?> {
  final WidgetRef ref;

  BuddySearchDelegate(this.ref);

  @override
  String get searchFieldLabel => 'Search buddies...';

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          icon: const Icon(Icons.clear),
          onPressed: () => query = '',
        ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildSearchResults(context);
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    if (query.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search,
              size: 64,
              color: Theme.of(context)
                  .colorScheme
                  .onSurfaceVariant
                  .withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'Search by name, email, or phone',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      );
    }
    return _buildSearchResults(context);
  }

  Widget _buildSearchResults(BuildContext context) {
    final searchAsync = ref.watch(buddySearchProvider(query));

    return searchAsync.when(
      data: (buddies) {
        if (buddies.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.search_off,
                  size: 64,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurfaceVariant
                      .withOpacity(0.5),
                ),
                const SizedBox(height: 16),
                Text(
                  'No buddies found for "$query"',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: buddies.length,
          itemBuilder: (context, index) {
            final buddy = buddies[index];
            return BuddyListTile(
              buddy: buddy,
              onTap: () {
                close(context, buddy);
                context.push('/buddies/${buddy.id}');
              },
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Text('Error: $error'),
      ),
    );
  }
}
