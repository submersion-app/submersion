import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/documents/domain/document_expiry.dart';
import 'package:submersion/features/documents/domain/entities/document.dart';
import 'package:submersion/features/documents/presentation/document_l10n.dart';
import 'package:submersion/features/documents/presentation/providers/document_providers.dart';
import 'package:submersion/features/documents/presentation/widgets/document_expiry_badge.dart';
import 'package:submersion/features/documents/presentation/widgets/document_page_viewer.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/master_detail/responsive_breakpoints.dart';

/// The route of the record a document is filed under; null for personal.
String? documentOwnerRoute(DocumentOwner owner) {
  final id = owner.id;
  if (id == null) return null;
  return switch (owner.kind) {
    DocumentOwnerKind.personal => null,
    DocumentOwnerKind.dive => '/dives/$id',
    DocumentOwnerKind.site => '/sites/$id',
    DocumentOwnerKind.trip => '/trips/$id',
    DocumentOwnerKind.equipment => '/equipment/$id',
    DocumentOwnerKind.course => '/courses/$id',
    DocumentOwnerKind.certification => '/certifications/$id',
    DocumentOwnerKind.buddy => '/buddies/$id',
    DocumentOwnerKind.diveCenter => '/dive-centers/$id',
  };
}

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
    return entry.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(l10n.documents_error_load('$e'))),
      ),
      data: (entry) {
        if (entry == null) {
          return Scaffold(
            appBar: AppBar(),
            body: Center(child: Text(l10n.documents_empty)),
          );
        }
        final doc = entry.document;
        return Scaffold(
          appBar: AppBar(
            automaticallyImplyLeading: !widget.embedded,
            title: Text(documentDisplayTitle(l10n, doc)),
            actions: [
              IconButton(
                tooltip: l10n.common_action_edit,
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => _edit(doc.id),
              ),
              IconButton(
                tooltip: l10n.common_action_delete,
                icon: const Icon(Icons.delete_outline),
                onPressed: () => _delete(doc),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              SizedBox(
                height: 320,
                child: pages.when(
                  data: (list) => list.isEmpty
                      ? Center(
                          child: Icon(
                            documentTypeIcon(doc.type),
                            size: 64,
                            color: Theme.of(context).colorScheme.outline,
                          ),
                        )
                      : DocumentPageViewer(pages: list),
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('$e')),
                ),
              ),
              const SizedBox(height: 16),
              _DetailsCard(document: doc, ownerLabel: entry.ownerLabel),
            ],
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

class _DetailsCard extends ConsumerWidget {
  final Document document;
  final String? ownerLabel;

  const _DetailsCard({required this.document, required this.ownerLabel});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final units = UnitFormatter(ref.watch(settingsProvider));
    final doc = document;
    final insurance = doc.type == DocumentType.insurance;
    final ownerRoute = documentOwnerRoute(doc.owner);
    final status = documentExpiryStatus(doc, DateTime.now());
    String? text(String? v) => (v == null || v.trim().isEmpty) ? null : v;
    return Card(
      child: Column(
        children: [
          _Row(
            icon: documentTypeIcon(doc.type),
            label: l10n.documents_field_type,
            value: documentTypeLabel(l10n, doc.type),
          ),
          if (text(doc.issuer) case final issuer?)
            _Row(
              icon: Icons.apartment_outlined,
              label: insurance
                  ? l10n.documents_field_issuerInsurance
                  : l10n.documents_field_issuer,
              value: issuer,
            ),
          if (text(doc.referenceNumber) case final number?)
            _Row(
              icon: Icons.tag,
              label: insurance
                  ? l10n.documents_field_referenceNumberInsurance
                  : l10n.documents_field_referenceNumber,
              value: number,
            ),
          if (doc.issueDate case final issued?)
            _Row(
              icon: Icons.event_outlined,
              label: l10n.documents_field_issueDate,
              value: units.formatDate(issued),
            ),
          if (doc.expiryDate case final expiry?)
            _Row(
              icon: Icons.event_busy_outlined,
              label: l10n.documents_field_expiryDate,
              value: units.formatDate(expiry),
              trailing: DocumentExpiryBadge(status: status),
            ),
          if (insurance && text(doc.emergencyPhone) != null)
            _Row(
              icon: Icons.emergency_outlined,
              label: l10n.documents_field_emergencyPhone,
              value: doc.emergencyPhone!,
              onTap: () => _call(doc.emergencyPhone!),
            ),
          if (insurance && text(doc.phone) != null)
            _Row(
              icon: Icons.phone_outlined,
              label: l10n.documents_field_phone,
              value: doc.phone!,
              onTap: () => _call(doc.phone!),
            ),
          if (insurance && doc.isPrimary)
            _Row(
              icon: Icons.star_outline,
              label: l10n.documents_field_isPrimary,
              value: l10n.documents_field_isPrimary_subtitle,
            ),
          _Row(
            icon: Icons.folder_outlined,
            label: l10n.documents_detail_owner,
            value: ownerLabel ?? documentOwnerKindLabel(l10n, doc.owner.kind),
            onTap: ownerRoute == null ? null : () => context.push(ownerRoute),
          ),
          if (text(doc.notes) case final notes?)
            _Row(
              icon: Icons.notes_outlined,
              label: l10n.documents_field_notes,
              value: notes,
            ),
        ],
      ),
    );
  }

  Future<void> _call(String number) async {
    final uri = Uri(scheme: 'tel', path: number.replaceAll(' ', ''));
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }
}

class _Row extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;
  final Widget? trailing;

  const _Row({
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      leading: Icon(icon),
      title: Text(
        label,
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value, style: theme.textTheme.bodyLarge),
          if (trailing case final badge?) ...[const SizedBox(height: 4), badge],
        ],
      ),
      onTap: onTap,
    );
  }
}
