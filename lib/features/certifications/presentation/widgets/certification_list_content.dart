import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:submersion/features/certifications/domain/entities/certification.dart';
import 'package:submersion/features/certifications/presentation/providers/certification_providers.dart';

/// Content widget for the certification list, used in master-detail layout.
class CertificationListContent extends ConsumerStatefulWidget {
  final void Function(String?)? onItemSelected;
  final String? selectedId;
  final bool showAppBar;
  final Widget? floatingActionButton;

  const CertificationListContent({
    super.key,
    this.onItemSelected,
    this.selectedId,
    this.showAppBar = true,
    this.floatingActionButton,
  });

  @override
  ConsumerState<CertificationListContent> createState() =>
      _CertificationListContentState();
}

class _CertificationListContentState
    extends ConsumerState<CertificationListContent> {
  final ScrollController _scrollController = ScrollController();
  String? _lastScrolledToId;
  bool _selectionFromList = false;

  @override
  void initState() {
    super.initState();
    if (widget.selectedId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToSelectedItem();
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(CertificationListContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedId != null &&
        widget.selectedId != oldWidget.selectedId &&
        widget.selectedId != _lastScrolledToId) {
      if (_selectionFromList) {
        _selectionFromList = false;
        _lastScrolledToId = widget.selectedId;
      } else {
        _scrollToSelectedItem();
      }
    }
  }

  void _scrollToSelectedItem() {
    if (widget.selectedId == null) return;

    final certsAsync = ref.read(certificationListNotifierProvider);
    certsAsync.whenData((certs) {
      final index = certs.indexWhere((c) => c.id == widget.selectedId);
      if (index >= 0 && _scrollController.hasClients) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!_scrollController.hasClients || certs.isEmpty) return;

          final maxScroll = _scrollController.position.maxScrollExtent;
          final viewportHeight = _scrollController.position.viewportDimension;
          final totalContentHeight = maxScroll + viewportHeight - 80;
          final avgItemHeight = totalContentHeight / certs.length;
          final targetOffset = (index * avgItemHeight) - (viewportHeight / 3);
          final clampedOffset = targetOffset.clamp(0.0, maxScroll);

          _scrollController.animateTo(
            clampedOffset,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
          _lastScrolledToId = widget.selectedId;
        });
      }
    });
  }

  void _handleItemTap(Certification cert) {
    if (widget.onItemSelected != null) {
      _selectionFromList = true;
      widget.onItemSelected!(cert.id);
    } else {
      context.push('/certifications/${cert.id}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final certificationsAsync = ref.watch(certificationListNotifierProvider);

    final content = certificationsAsync.when(
      data: (certifications) => certifications.isEmpty
          ? _buildEmptyState(context)
          : _buildCertificationList(context, ref, certifications),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => _buildErrorState(context, error),
    );

    if (!widget.showAppBar) {
      return Column(
        children: [
          _buildCompactAppBar(context),
          Expanded(child: content),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Certifications'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              showSearch(
                context: context,
                delegate: CertificationSearchDelegate(ref),
              );
            },
          ),
        ],
      ),
      body: content,
      floatingActionButton: widget.floatingActionButton,
    );
  }

  Widget _buildCompactAppBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          const SizedBox(width: 8),
          Text(
            'Certifications',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.search, size: 20),
            onPressed: () {
              showSearch(
                context: context,
                delegate: CertificationSearchDelegate(ref),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCertificationList(
    BuildContext context,
    WidgetRef ref,
    List<Certification> certifications,
  ) {
    // Group certifications by status
    final expired = <Certification>[];
    final expiringSoon = <Certification>[];
    final valid = <Certification>[];

    for (final cert in certifications) {
      if (cert.isExpired) {
        expired.add(cert);
      } else if (cert.expiresWithin(90)) {
        expiringSoon.add(cert);
      } else {
        valid.add(cert);
      }
    }

    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(certificationListNotifierProvider.notifier).refresh();
      },
      child: ListView(
        controller: _scrollController,
        padding: const EdgeInsets.only(bottom: 80),
        children: [
          if (expired.isNotEmpty) ...[
            _buildSectionHeader(context, 'Expired', Colors.red),
            ...expired.map(
              (cert) => CertificationListTile(
                certification: cert,
                isSelected: widget.selectedId == cert.id,
                onTap: () => _handleItemTap(cert),
              ),
            ),
          ],
          if (expiringSoon.isNotEmpty) ...[
            _buildSectionHeader(context, 'Expiring Soon', Colors.orange),
            ...expiringSoon.map(
              (cert) => CertificationListTile(
                certification: cert,
                isSelected: widget.selectedId == cert.id,
                onTap: () => _handleItemTap(cert),
              ),
            ),
          ],
          if (valid.isNotEmpty) ...[
            _buildSectionHeader(context, 'Valid', Colors.green),
            ...valid.map(
              (cert) => CertificationListTile(
                certification: cert,
                isSelected: widget.selectedId == cert.id,
                onTap: () => _handleItemTap(cert),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title, Color color) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.card_membership_outlined,
            size: 80,
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No certifications added yet',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Add your dive certifications to keep track\nof your training and qualifications',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => context.push('/certifications/new'),
            icon: const Icon(Icons.add_card),
            label: const Text('Add Your First Certification'),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, Object error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 16),
          Text('Error loading certifications: $error'),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () =>
                ref.read(certificationListNotifierProvider.notifier).refresh(),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

/// List item widget for displaying a certification
class CertificationListTile extends StatelessWidget {
  final Certification certification;
  final bool isSelected;
  final VoidCallback? onTap;

  const CertificationListTile({
    super.key,
    required this.certification,
    this.isSelected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      color: isSelected
          ? theme.colorScheme.primaryContainer.withValues(alpha: 0.5)
          : null,
      child: ListTile(
        onTap: onTap,
        leading: _buildLeadingIcon(context),
        title: Text(certification.name),
        subtitle: _buildSubtitle(context),
        trailing: _buildTrailing(context),
      ),
    );
  }

  Widget _buildLeadingIcon(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Text(
          certification.agency.displayName.substring(
            0,
            certification.agency.displayName.length > 4
                ? 4
                : certification.agency.displayName.length,
          ),
          style: TextStyle(
            color: Theme.of(context).colorScheme.onPrimaryContainer,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget? _buildSubtitle(BuildContext context) {
    final parts = <String>[];
    parts.add(certification.agency.displayName);
    if (certification.issueDate != null) {
      parts.add(DateFormat.yMMMd().format(certification.issueDate!));
    }
    return Text(parts.join(' - '));
  }

  Widget _buildTrailing(BuildContext context) {
    if (certification.isExpired) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text(
          'Expired',
          style: TextStyle(
            color: Colors.red,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    } else if (certification.expiresWithin(90)) {
      final days = certification.daysUntilExpiry;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          '${days}d',
          style: const TextStyle(
            color: Colors.orange,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }
    return const Icon(Icons.chevron_right);
  }
}

/// Search delegate for certifications
class CertificationSearchDelegate extends SearchDelegate<Certification?> {
  final WidgetRef ref;

  CertificationSearchDelegate(this.ref);

  @override
  String get searchFieldLabel => 'Search certifications...';

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(icon: const Icon(Icons.clear), onPressed: () => query = ''),
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
              color: Theme.of(
                context,
              ).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'Search by name, agency, or card number',
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
    final searchAsync = ref.watch(certificationSearchProvider(query));

    return searchAsync.when(
      data: (certifications) {
        if (certifications.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.search_off,
                  size: 64,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                ),
                const SizedBox(height: 16),
                Text(
                  'No certifications found for "$query"',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: certifications.length,
          itemBuilder: (context, index) {
            final cert = certifications[index];
            return CertificationListTile(
              certification: cert,
              onTap: () {
                close(context, cert);
                context.push('/certifications/${cert.id}');
              },
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('Error: $error')),
    );
  }
}
