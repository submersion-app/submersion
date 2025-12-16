import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/entities/buddy.dart';
import '../providers/buddy_providers.dart';

class BuddyListPage extends ConsumerWidget {
  const BuddyListPage({super.key});

  /// Check if contact import is supported on this platform
  bool get _isContactImportSupported {
    if (kIsWeb) return false;
    return Platform.isIOS || Platform.isAndroid;
  }

  Future<void> _importFromContacts(BuildContext context) async {
    // Check platform support first
    if (!_isContactImportSupported) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Contact import is only available on iOS and Android'),
          ),
        );
      }
      return;
    }

    // Request permission
    if (!await FlutterContacts.requestPermission(readonly: true)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Contact permission is required to import buddies'),
          ),
        );
      }
      return;
    }

    // Let user pick a contact
    final contact = await FlutterContacts.openExternalPick();
    if (contact == null) return;

    // Get full contact details
    final fullContact = await FlutterContacts.getContact(contact.id);
    if (fullContact == null) return;

    // Extract contact info
    final name = fullContact.displayName;
    final email = fullContact.emails.isNotEmpty
        ? fullContact.emails.first.address
        : null;
    final phone = fullContact.phones.isNotEmpty
        ? fullContact.phones.first.number
        : null;

    if (context.mounted) {
      // Navigate to buddy edit page with pre-filled data
      context.push(
        '/buddies/new',
        extra: {
          'name': name,
          'email': email,
          'phone': phone,
        },
      );
    }
  }

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
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'import') {
                _importFromContacts(context);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'import',
                child: ListTile(
                  leading: Icon(Icons.contacts),
                  title: Text('Import from Contacts'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
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
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
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
                  .withValues(alpha: 0.5),
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
                      .withValues(alpha: 0.5),
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
