import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/documents/data/repositories/document_repository.dart';
import 'package:submersion/features/documents/domain/document_expiry.dart';
import 'package:submersion/features/documents/domain/entities/document.dart';
import 'package:submersion/features/documents/presentation/document_l10n.dart';
import 'package:submersion/features/documents/presentation/widgets/document_expiry_badge.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';
import 'package:submersion/features/tags/presentation/providers/tag_link_providers.dart';
import 'package:submersion/features/tags/presentation/widgets/tag_chip.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/markdown_notes/markdown_notes_view.dart';

/// The details under a document's pages on a narrow screen. Collapsed it
/// is one line (type, expiry, what it is filed under) so the pages get the
/// screen; expanded it shows every detail, scrolling within half the
/// height so the pages always keep the other half.
class DocumentDetailsPanel extends ConsumerStatefulWidget {
  final DocumentListEntry entry;

  /// Keeps the details open, with no toggle: while the page is unlocked
  /// its Details card must stay in view (issue #4527, phase 3).
  final bool forceOpen;

  /// Wraps the panel as the page's Details card, framed for editing.
  final Widget Function(Widget details)? frame;

  /// The Details card's pencil, shown in the header in place of the fold
  /// arrow while [forceOpen].
  final Widget? pencil;

  /// Passed to [DocumentDetailsCard.tags].
  final List<Tag>? tags;

  const DocumentDetailsPanel({
    super.key,
    required this.entry,
    this.forceOpen = false,
    this.frame,
    this.pencil,
    this.tags,
  });

  @override
  ConsumerState<DocumentDetailsPanel> createState() =>
      _DocumentDetailsPanelState();
}

class _DocumentDetailsPanelState extends ConsumerState<DocumentDetailsPanel> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final doc = widget.entry.document;
    final status = documentExpiryStatus(doc, DateTime.now());
    final owner = widget.entry.ownerText(ref.watch(unitFormatterProvider));
    final summary = [
      documentTypeLabel(l10n, doc.type),
      owner ?? documentOwnerKindLabel(l10n, doc.owner.kind),
    ].join(' · ');
    final panel = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _toggle(context, doc, status, summary),
        if (_expanded || widget.forceOpen)
          Flexible(
            child: SingleChildScrollView(
              child: DocumentDetailsCard(
                document: doc,
                ownerLabel: owner,
                flat: true,
                tags: widget.tags,
              ),
            ),
          ),
      ],
    );
    final frame = widget.frame;
    if (widget.forceOpen && frame != null) {
      // Unlocked, the panel is the page's Details card, framed whole: its
      // header keeps the pencil, and once open its editor, taller than the
      // panel's half of the screen, takes the panel's place and scrolls.
      return Card(
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: SingleChildScrollView(
          child: frame(
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _toggle(context, doc, status, summary),
                DocumentDetailsCard(
                  document: doc,
                  ownerLabel: owner,
                  flat: true,
                  tags: widget.tags,
                ),
              ],
            ),
          ),
        ),
      );
    }
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: frame == null ? panel : frame(panel),
    );
  }

  /// The panel's header: the type and owner, the expiry badge when it needs
  /// attention, and the fold arrow; while [DocumentDetailsPanel.forceOpen]
  /// the arrow's place holds the Details card's pencil.
  Widget _toggle(
    BuildContext context,
    Document doc,
    DocumentExpiryStatus status,
    String summary,
  ) => ListTile(
    key: const ValueKey('document-details-toggle'),
    leading: Icon(documentTypeIcon(doc.type)),
    title: Text(summary, maxLines: 1, overflow: TextOverflow.ellipsis),
    subtitle: status.needsAttention
        ? Align(
            alignment: AlignmentDirectional.centerStart,
            child: DocumentExpiryBadge(status: status),
          )
        : null,
    // Kept open while the page is unlocked: the fold arrow's place
    // holds the Details card's pencil.
    trailing: widget.forceOpen
        ? widget.pencil
        : Icon(_expanded ? Icons.expand_more : Icons.expand_less),
    onTap: widget.forceOpen
        ? null
        : () => setState(() => _expanded = !_expanded),
  );
}

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

/// Every detail of a document: its type, issuer and numbers, dates, the
/// insurance phones, what it is filed under and its notes.
class DocumentDetailsCard extends ConsumerWidget {
  final Document document;
  final String? ownerLabel;

  /// True inside [DocumentDetailsPanel], which is already a card.
  final bool flat;

  /// The Details card's pencil and changed dot, at its top while the page
  /// is unlocked.
  final Widget? pencil;

  /// The tags to show in place of the stored ones: those a sitting holds
  /// (issue #4527, phase 3).
  final List<Tag>? tags;

  const DocumentDetailsCard({
    super.key,
    required this.document,
    required this.ownerLabel,
    this.flat = false,
    this.pencil,
    this.tags,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final units = ref.watch(unitFormatterProvider);
    final doc = document;
    final insurance = doc.type == DocumentType.insurance;
    final ownerRoute = documentOwnerRoute(doc.owner);
    final status = documentExpiryStatus(doc, DateTime.now());
    final stored =
        ref
            .watch(
              tagsForItemProvider((scope: TagScope.documents, itemId: doc.id)),
            )
            .value ??
        const <Tag>[];
    final tags = this.tags ?? stored;
    String? text(String? v) => (v == null || v.trim().isEmpty) ? null : v;
    final rows = Column(
      children: [
        if (pencil case final pencil?)
          Align(alignment: AlignmentDirectional.topEnd, child: pencil),
        _DetailRow(
          icon: documentTypeIcon(doc.type),
          label: l10n.documents_field_type,
          value: documentTypeLabel(l10n, doc.type),
        ),
        if (text(doc.issuer) case final issuer?)
          _DetailRow(
            icon: Icons.apartment_outlined,
            label: insurance
                ? l10n.documents_field_issuerInsurance
                : l10n.documents_field_issuer,
            value: issuer,
          ),
        if (text(doc.referenceNumber) case final number?)
          _DetailRow(
            icon: Icons.tag,
            label: insurance
                ? l10n.documents_field_referenceNumberInsurance
                : l10n.documents_field_referenceNumber,
            value: number,
          ),
        if (doc.issueDate case final issued?)
          _DetailRow(
            icon: Icons.event_outlined,
            label: l10n.documents_field_issueDate,
            value: units.formatDate(issued),
          ),
        if (doc.expiryDate case final expiry?)
          _DetailRow(
            icon: Icons.event_busy_outlined,
            label: l10n.documents_field_expiryDate,
            value: units.formatDate(expiry),
            trailing: DocumentExpiryBadge(status: status),
          ),
        // The expiry reminder when it is set and not the default (issue
        // #4527, phase 3).
        if (doc.expiryDate != null)
          if (doc.reminderLeadDays case final days?)
            _DetailRow(
              icon: Icons.notifications_outlined,
              label: l10n.documents_field_reminderLead,
              value: l10n.documents_field_reminderLeadDays(days),
            ),
        if (insurance && text(doc.emergencyPhone) != null)
          _DetailRow(
            icon: Icons.emergency_outlined,
            label: l10n.documents_field_emergencyPhone,
            value: doc.emergencyPhone!,
            onTap: () => _call(doc.emergencyPhone!),
          ),
        if (insurance && text(doc.phone) != null)
          _DetailRow(
            icon: Icons.phone_outlined,
            label: l10n.documents_field_phone,
            value: doc.phone!,
            onTap: () => _call(doc.phone!),
          ),
        if (insurance && doc.isPrimary)
          _DetailRow(
            icon: Icons.star_outline,
            label: l10n.documents_field_isPrimary,
            value: l10n.documents_field_isPrimary_subtitle,
          ),
        _DetailRow(
          icon: Icons.folder_outlined,
          label: l10n.documents_detail_owner,
          value: ownerLabel ?? documentOwnerKindLabel(l10n, doc.owner.kind),
          onTap: ownerRoute == null ? null : () => context.push(ownerRoute),
        ),
        if (tags.isNotEmpty) _TagsRow(tags: tags),
        if (text(doc.notes) case final notes?)
          _DetailRow(
            icon: Icons.notes_outlined,
            label: l10n.documents_field_notes,
            value: notes,
            markdown: true,
          ),
      ],
    );
    return flat ? rows : Card(child: rows);
  }

  Future<void> _call(String number) async {
    final uri = Uri(scheme: 'tel', path: number.replaceAll(' ', ''));
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }
}

/// A document's tags as colored chips (issue #1970). Tapping one opens the
/// documents list filtered to that tag, as a dive's tag chip opens the dive
/// list.
class _TagsRow extends StatelessWidget {
  final List<Tag> tags;

  const _TagsRow({required this.tags});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return ListTile(
      leading: const Icon(Icons.sell_outlined),
      title: Text(
        l10n.documents_field_tags,
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final tag in tags)
              TagChip(
                tag: tag,
                tooltip: l10n.documents_detail_showWithTag(tag.name),
                onTap: () => context.go(
                  Uri(
                    path: '/documents',
                    queryParameters: {'tag': tag.id},
                  ).toString(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;
  final Widget? trailing;

  /// Draws [value] as a Markdown note (#3683).
  final bool markdown;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
    this.trailing,
    this.markdown = false,
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
          if (markdown)
            MarkdownNotesView(value, style: theme.textTheme.bodyLarge)
          else
            Text(value, style: theme.textTheme.bodyLarge),
          if (trailing case final badge?) ...[const SizedBox(height: 4), badge],
        ],
      ),
      onTap: onTap,
    );
  }
}
