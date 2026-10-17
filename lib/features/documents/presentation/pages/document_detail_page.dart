import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/certification_agencies/presentation/providers/certification_catalog_providers.dart';
import 'package:submersion/features/documents/domain/entities/document.dart';
import 'package:submersion/features/documents/presentation/document_l10n.dart';
import 'package:submersion/features/documents/presentation/providers/document_providers.dart';
import 'package:submersion/features/documents/presentation/widgets/document_details_panel.dart';
import 'package:submersion/features/documents/presentation/widgets/document_page_viewer.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/master_detail/responsive_breakpoints.dart';

/// One document: its pages, its details and what it is filed under.
class DocumentDetailPage extends ConsumerStatefulWidget {
  final String documentId;

  /// True inside the master-detail pane on wide screens.
  final bool embedded;
  final VoidCallback? onDeleted;

  const DocumentDetailPage({
    super.key,
    required this.documentId,
    this.embedded = false,
    this.onDeleted,
  });

  @override
  ConsumerState<DocumentDetailPage> createState() => _DocumentDetailPageState();
}

class _DocumentDetailPageState extends ConsumerState<DocumentDetailPage> {
  /// Wide enough for a readable page beside the details column.
  static const double _sideBySideWidth = 840;
  static const double _sideColumnWidth = 360;

  bool _redirected = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    // A full page reached directly (a deep link, the home chip) belongs in
    // the list's detail pane on a wide screen. One pushed from an owner
    // page's Documents section stays a page, so Back returns to the owner.
    if (!widget.embedded &&
        !_redirected &&
        ResponsiveBreakpoints.isMasterDetail(context) &&
        !context.canPop()) {
      _redirected = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go('/documents?selected=${widget.documentId}');
      });
    }
    final entry = ref.watch(documentEntryProvider(widget.documentId));
    final pages = ref.watch(documentPagesProvider(widget.documentId));
    final units = UnitFormatter(ref.watch(settingsProvider));
    return entry.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      // Embedded, these placeholder bars belong to a detail pane, not a page:
      // a pushed list underneath must not give them a back arrow (#3292).
      error: (e, _) => Scaffold(
        appBar: AppBar(automaticallyImplyLeading: !widget.embedded),
        body: Center(child: Text(l10n.documents_error_load('$e'))),
      ),
      data: (stored) {
        if (stored == null) {
          return Scaffold(
            appBar: AppBar(automaticallyImplyLeading: !widget.embedded),
            body: Center(child: Text(l10n.documents_empty)),
          );
        }
        final entry = withCertificationOwnerTitle(
          stored,
          l10n,
          catalog: ref.watch(certificationCatalogSyncProvider),
        );
        final doc = entry.document;
        final owner = entry.ownerText(units);
        return Scaffold(
          appBar: AppBar(
            automaticallyImplyLeading: !widget.embedded,
            title: Text(
              documentDisplayTitle(l10n, doc, ownerLabel: entry.ownerLabel),
            ),
            actions: [
              IconButton(
                tooltip: l10n.common_action_edit,
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => _edit(doc.id),
              ),
              // Delete waits behind the overflow menu, as on the other
              // detail pages, not one tap away beside Edit (#3384).
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'delete') _delete(doc);
                },
                itemBuilder: (context) {
                  final error = Theme.of(context).colorScheme.error;
                  return [
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, color: error),
                          const SizedBox(width: 8),
                          Text(
                            l10n.common_action_delete,
                            style: TextStyle(color: error),
                          ),
                        ],
                      ),
                    ),
                  ];
                },
              ),
            ],
          ),
          body: LayoutBuilder(
            builder: (context, constraints) {
              // Nothing to show but the details (an insurance kept as its
              // numbers alone): show them, not an empty viewer over a
              // folded panel.
              if (pages.value?.isEmpty ?? false) {
                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // A readable line length on a wide window.
                    Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 640),
                        child: DocumentDetailsCard(
                          document: doc,
                          ownerLabel: owner,
                        ),
                      ),
                    ),
                  ],
                );
              }
              final viewer = pages.when(
                data: (list) => DocumentPageViewer(pages: list),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('$e')),
              );
              if (constraints.maxWidth >= _sideBySideWidth) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: viewer),
                    SizedBox(
                      width: _sideColumnWidth,
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: DocumentDetailsCard(
                          document: doc,
                          ownerLabel: owner,
                        ),
                      ),
                    ),
                  ],
                );
              }
              // The pages own every vertical drag here: inside a scrolling
              // list a PDF could neither fill the screen nor scroll.
              return Column(
                children: [
                  Expanded(child: viewer),
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: constraints.maxHeight / 2,
                    ),
                    child: DocumentDetailsPanel(entry: entry),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  /// In the list's detail pane the editor opens in that pane, as every
  /// master-detail feature's does; a full page pushes the edit route.
  void _edit(String id) {
    if (!widget.embedded) {
      context.push('/documents/$id/edit');
      return;
    }
    final uri = GoRouterState.of(context).uri;
    context.go(
      uri
          .replace(
            queryParameters: {
              ...uri.queryParameters,
              'selected': id,
              'mode': 'edit',
            },
          )
          .toString(),
    );
  }

  Future<void> _delete(Document doc) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.documents_delete_title),
        content: Text(l10n.documents_delete_content),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.common_action_cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.common_action_delete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await ref.read(documentMutationsProvider).delete(doc.id);
    messenger.showSnackBar(SnackBar(content: Text(l10n.documents_deleted)));
    if (!mounted) return;
    if (widget.onDeleted != null) {
      widget.onDeleted!();
    } else if (context.canPop()) {
      context.pop();
    } else {
      context.go('/documents');
    }
  }
}
