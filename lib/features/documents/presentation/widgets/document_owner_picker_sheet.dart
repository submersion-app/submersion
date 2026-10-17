import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/certification_agencies/presentation/providers/certification_catalog_providers.dart';
import 'package:submersion/features/certifications/presentation/certification_title_l10n.dart';
import 'package:submersion/features/documents/data/repositories/document_owner_options_repository.dart';
import 'package:submersion/features/documents/domain/entities/document.dart';
import 'package:submersion/features/documents/presentation/document_l10n.dart';
import 'package:submersion/features/documents/presentation/providers/document_owner_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Asks what a document is filed under: a kind, then one of the active
/// diver's records of that kind. Personal returns at once. Null when the
/// sheet is dismissed.
Future<DocumentOwner?> showDocumentOwnerPicker(
  BuildContext context, {
  required DocumentOwner current,
}) => showModalBottomSheet<DocumentOwner>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (_) => DraggableScrollableSheet(
    expand: false,
    initialChildSize: 0.7,
    maxChildSize: 0.95,
    builder: (context, scroll) =>
        _OwnerPickerSheet(current: current, scrollController: scroll),
  ),
);

class _OwnerPickerSheet extends ConsumerStatefulWidget {
  final DocumentOwner current;
  final ScrollController scrollController;

  const _OwnerPickerSheet({
    required this.current,
    required this.scrollController,
  });

  @override
  ConsumerState<_OwnerPickerSheet> createState() => _OwnerPickerSheetState();
}

class _OwnerPickerSheetState extends ConsumerState<_OwnerPickerSheet> {
  late DocumentOwnerKind? _kind = widget.current.isPersonal
      ? null
      : widget.current.kind;
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _choose(DocumentOwnerKind kind) {
    if (kind == DocumentOwnerKind.personal) {
      Navigator.of(context).pop(const DocumentOwner.personal());
      return;
    }
    // The field and the filter clear together, so what is typed is what
    // filters.
    _search.clear();
    setState(() {
      _kind = kind;
      _query = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final kind = _kind;
    // Personal has no records to choose, so it is marked from the owner.
    final current =
        kind ?? (widget.current.isPersonal ? DocumentOwnerKind.personal : null);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            l10n.documents_owner_pickerTitle,
            style: theme.textTheme.titleMedium,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final k in DocumentOwnerKind.values)
                ChoiceChip(
                  key: ValueKey('owner-kind-${k.name}'),
                  avatar: Icon(documentOwnerKindIcon(k), size: 18),
                  label: Text(documentOwnerKindLabel(l10n, k)),
                  selected: k == current,
                  onSelected: (_) => _choose(k),
                ),
            ],
          ),
        ),
        if (kind != null) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              key: const ValueKey('owner-search'),
              controller: _search,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: l10n.documents_owner_search,
                isDense: true,
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          Expanded(child: _records(kind)),
        ],
      ],
    );
  }

  Widget _records(DocumentOwnerKind kind) {
    final l10n = context.l10n;
    final units = UnitFormatter(ref.watch(settingsProvider));
    return ref
        .watch(documentOwnerOptionsProvider(kind))
        .when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text(l10n.documents_error_load('$e'))),
          data: (options) {
            final catalog = ref.watch(certificationCatalogSyncProvider);
            String? dateOf(DocumentOwnerOption o) =>
                o.date == null ? null : units.formatDate(o.date);
            // A certification goes by its title, derived from its
            // certification when it has no custom one (#3366).
            String nameOf(DocumentOwnerOption o) => switch (o.certification) {
              final fields? => certificationTitleFieldsL10n(
                fields,
                l10n,
                catalog: catalog,
              ),
              null => o.label,
            };
            final named = [for (final o in options) (o, nameOf(o))];
            // The query sorts by stored name, which is empty for a derived
            // certification title, so certifications sort by title here.
            if (kind == DocumentOwnerKind.certification) {
              named.sort(
                (a, b) => a.$2.toLowerCase().compareTo(b.$2.toLowerCase()),
              );
            }
            final q = _query.trim().toLowerCase();
            final shown = [
              for (final (o, name) in named)
                if (q.isEmpty ||
                    [
                      name,
                      o.subtitle,
                      dateOf(o),
                    ].any((v) => v != null && v.toLowerCase().contains(q)))
                  (o, name),
            ];
            if (shown.isEmpty) {
              return Center(child: Text(l10n.documents_owner_none));
            }
            return ListView.builder(
              controller: widget.scrollController,
              itemCount: shown.length,
              itemBuilder: (context, i) {
                final (o, name) = shown[i];
                final date = dateOf(o);
                // A dive reads number, name or site, then date, as the
                // File under field does (#3391): an unnumbered one leads
                // with its name or site, else its date.
                final title = name.isNotEmpty
                    ? name
                    : (o.subtitle ?? date ?? '');
                final subtitle = [
                  if (name.isNotEmpty) ?o.subtitle,
                  if (title != date) ?date,
                ].join(' · ');
                final owner = DocumentOwner(kind, o.id);
                return ListTile(
                  leading: Icon(documentOwnerKindIcon(kind)),
                  title: Text(title),
                  subtitle: subtitle.isEmpty ? null : Text(subtitle),
                  selected: owner == widget.current,
                  onTap: () => Navigator.of(context).pop(owner),
                );
              },
            );
          },
        );
  }
}
