import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/features/marine_life/domain/entities/species_lookup.dart';
import 'package:submersion/features/marine_life/presentation/providers/species_lookup_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Opens the lookup sheet. Resolves to a [SpeciesLookupChosen] when the
/// diver picked a taxon, a [SpeciesLookupCreateWithout] when they asked to
/// skip the lookup, and null when they dismissed the sheet.
///
/// Set [allowCreateWithout] to false when the caller has no name to fall
/// back on, so the sheet does not offer to create a species out of an empty
/// string.
Future<SpeciesLookupOutcome?> showSpeciesLookupSheet(
  BuildContext context, {
  String initialQuery = '',
  bool allowCreateWithout = true,
}) => showModalBottomSheet<SpeciesLookupOutcome>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (_) => DraggableScrollableSheet(
    initialChildSize: 0.7,
    minChildSize: 0.4,
    maxChildSize: 0.95,
    expand: false,
    builder: (_, controller) => SpeciesLookupSheet(
      initialQuery: initialQuery,
      allowCreateWithout: allowCreateWithout,
      scrollController: controller,
    ),
  ),
);

/// Search iNaturalist for a species. Lookups are explicit: nothing is sent
/// until the diver taps Look up, so typing never leaks keystrokes and an
/// offline boat is a single clear message rather than a stream of errors.
class SpeciesLookupSheet extends ConsumerStatefulWidget {
  final String initialQuery;
  final bool allowCreateWithout;
  final ScrollController? scrollController;

  const SpeciesLookupSheet({
    super.key,
    required this.initialQuery,
    this.allowCreateWithout = true,
    this.scrollController,
  });

  @override
  ConsumerState<SpeciesLookupSheet> createState() => _SpeciesLookupSheetState();
}

class _SpeciesLookupSheetState extends ConsumerState<SpeciesLookupSheet> {
  late final TextEditingController _controller;
  List<SpeciesLookupHit>? _hits;
  String _lastQuery = '';
  SpeciesLookupErrorKind? _error;
  bool _searching = false;
  int? _resolvingId;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialQuery);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    // The button disables itself; the field's onSubmitted does not, so a
    // second Enter while a search is in flight is dropped here rather than
    // racing the first one's result.
    if (_searching) return;
    final query = _controller.text.trim();
    if (query.isEmpty) return;
    setState(() {
      _searching = true;
      _error = null;
      _lastQuery = query;
    });
    try {
      final hits = await ref
          .read(speciesLookupServiceProvider)
          .search(query, locale: ref.read(speciesLookupLocaleProvider));
      if (mounted) setState(() => _hits = hits);
    } on SpeciesLookupException catch (e) {
      if (mounted) setState(() => _error = e.kind);
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _choose(SpeciesLookupHit hit) async {
    setState(() => _resolvingId = hit.taxonId);
    try {
      final result = await ref
          .read(speciesLookupServiceProvider)
          .resolve(hit.taxonId, locale: ref.read(speciesLookupLocaleProvider));
      if (mounted) Navigator.of(context).pop(SpeciesLookupChosen(result));
    } on SpeciesLookupException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.kind;
          _resolvingId = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);

    return ListView(
      controller: widget.scrollController,
      padding: const EdgeInsets.all(16),
      children: [
        Text(l10n.marineLife_lookup_title, style: theme.textTheme.titleLarge),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                autofocus: widget.initialQuery.isEmpty,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _search(),
                decoration: InputDecoration(
                  hintText: l10n.marineLife_lookup_searchHint,
                  prefixIcon: const Icon(Icons.search),
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              key: const ValueKey('lookup_search'),
              onPressed: _searching ? null : _search,
              child: Text(l10n.marineLife_lookup_search),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ..._body(l10n, theme),
        const SizedBox(height: 16),
        if (widget.allowCreateWithout) ...[
          OutlinedButton(
            key: const ValueKey('lookup_create_without'),
            onPressed: () =>
                Navigator.of(context).pop(const SpeciesLookupCreateWithout()),
            child: Text(l10n.marineLife_lookup_createWithout),
          ),
          const SizedBox(height: 8),
        ],
        Text(
          l10n.marineLife_lookup_attribution,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  List<Widget> _body(AppLocalizations l10n, ThemeData theme) {
    if (_searching) {
      return const [Center(child: CircularProgressIndicator())];
    }
    final error = _error;
    if (error != null) {
      return [
        Text(_errorText(l10n, error), textAlign: TextAlign.center),
        const SizedBox(height: 8),
        Center(
          child: TextButton(
            onPressed: _search,
            child: Text(l10n.marineLife_lookup_retry),
          ),
        ),
      ];
    }
    final hits = _hits;
    if (hits == null) {
      return [
        Text(
          l10n.marineLife_lookup_idle,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ];
    }
    if (hits.isEmpty) {
      return [
        Text(
          l10n.marineLife_lookup_empty(_lastQuery),
          textAlign: TextAlign.center,
        ),
      ];
    }
    return [
      for (final hit in hits)
        _HitTile(
          hit: hit,
          resolving: _resolvingId == hit.taxonId,
          onTap: hit.isResolvable && _resolvingId == null
              ? () => _choose(hit)
              : null,
        ),
    ];
  }

  String _errorText(AppLocalizations l10n, SpeciesLookupErrorKind kind) =>
      switch (kind) {
        SpeciesLookupErrorKind.offline => l10n.marineLife_lookup_errorOffline,
        SpeciesLookupErrorKind.timeout => l10n.marineLife_lookup_errorTimeout,
        SpeciesLookupErrorKind.server => l10n.marineLife_lookup_errorServer,
        SpeciesLookupErrorKind.malformed =>
          l10n.marineLife_lookup_errorMalformed,
      };
}

class _HitTile extends StatelessWidget {
  final SpeciesLookupHit hit;
  final bool resolving;
  final VoidCallback? onTap;

  const _HitTile({required this.hit, required this.resolving, this.onTap});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final photo = hit.photo;
    final title = hit.commonName ?? hit.scientificName;
    final subtitle = hit.isResolvable
        ? hit.scientificName
        : l10n.marineLife_lookup_unresolvableRank(hit.rank);
    return ListTile(
      enabled: hit.isResolvable,
      leading: SizedBox(
        width: 48,
        height: 48,
        child: photo == null
            ? const Icon(Icons.image_not_supported_outlined)
            : Tooltip(
                message: photo.attribution,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.network(
                    photo.squareUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) =>
                        const Icon(Icons.image_not_supported_outlined),
                  ),
                ),
              ),
      ),
      title: Text(title),
      subtitle: Text(
        subtitle,
        style: hit.isResolvable
            ? const TextStyle(fontStyle: FontStyle.italic)
            : null,
      ),
      trailing: resolving
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Text(
              l10n.marineLife_lookup_observations(hit.observationCount),
              style: Theme.of(context).textTheme.bodySmall,
            ),
      onTap: onTap,
    );
  }
}
