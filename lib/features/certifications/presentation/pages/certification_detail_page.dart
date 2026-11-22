import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/core/router/pushed_route.dart';
import 'package:submersion/features/certifications/presentation/editing/certification_new_sitting.dart';
import 'package:submersion/features/change_log/presentation/widgets/change_log_history_menu_item.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/icon_detail_row.dart';
import 'package:submersion/shared/widgets/master_detail/detail_scroll_retainer.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_providers.dart';
import 'package:submersion/features/certifications/domain/certification_title.dart';
import 'package:submersion/features/certifications/domain/entities/certification.dart';
import 'package:submersion/features/certifications/presentation/providers/certification_providers.dart';
import 'package:submersion/features/courses/presentation/providers/course_providers.dart';
import 'package:submersion/features/certifications/presentation/widgets/certification_currency_section.dart';
import 'package:submersion/features/certifications/presentation/widgets/certification_ecard.dart';
import 'package:submersion/features/certifications/presentation/certification_title_l10n.dart';
import 'package:submersion/features/certification_agencies/presentation/certification_entry_display.dart';
import 'package:submersion/features/certification_agencies/presentation/providers/certification_catalog_context.dart';
import 'package:submersion/features/certification_agencies/presentation/providers/certification_catalog_providers.dart';
import 'package:submersion/features/documents/presentation/widgets/documents_section.dart';
import 'package:submersion/features/documents/domain/entities/document.dart';
import 'package:submersion/shared/widgets/detail_row/detail_row_group.dart';
import 'package:submersion/shared/widgets/markdown_notes/markdown_notes_view.dart';
import 'package:submersion/features/certifications/data/services/certification_edit_save_service.dart';
import 'package:submersion/features/certifications/presentation/editing/certification_card_ids.dart';
import 'package:submersion/features/certifications/presentation/editing/certification_currency_sitting.dart';
import 'package:submersion/features/certifications/presentation/editing/certification_edit_cards.dart';
import 'package:submersion/features/certifications/presentation/pages/certification_edit_routes.dart';
import 'package:submersion/shared/widgets/record_editing/record_creating.dart';
import 'package:submersion/shared/widgets/record_editing/record_operation_gate.dart';
import 'package:submersion/features/documents/presentation/editing/record_document_links_sitting.dart';
import 'package:submersion/shared/widgets/record_editing/add_strip.dart';
import 'package:submersion/shared/widgets/record_editing/edit_card.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';
import 'package:submersion/shared/widgets/record_editing/record_card_fade.dart';
import 'package:submersion/shared/widgets/record_editing/record_card_frame.dart';
import 'package:submersion/shared/widgets/record_editing/record_card_pencil.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_host.dart';
import 'package:submersion/shared/widgets/record_editing/record_open_unlocked.dart';
import 'package:submersion/shared/widgets/record_editing/record_pane_row.dart';

part 'certification_detail_page_creating.dart';
part 'certification_detail_page_editing.dart';
part 'certification_detail_page_sections.dart';
part 'certification_detail_page_photos.dart';

/// A certification's page. It opens locked and edits in place (issue #4527):
/// its cards are held in one sitting and written by one Save.

class CertificationDetailPage extends ConsumerStatefulWidget {
  final String certificationId;
  final bool embedded;
  final VoidCallback? onDeleted;

  /// Opens unlocked, as the old edit address asks (`?mode=edit`).
  final bool openUnlocked;

  /// Told when a sitting the page opened unlocked ends: the list pane's
  /// edit returns to the certification in view.
  final VoidCallback? onSittingEnded;

  /// A new certification (issue #4527, phase 3, plan 11).
  final bool newCertification;

  /// The pane's own: given the new certification's id once created.
  final void Function(String certificationId)? onCreated;

  /// The pane's own: told when a new certification's page leaves uncreated.
  final VoidCallback? onCreateCancelled;

  const CertificationDetailPage({
    super.key,
    required this.certificationId,
    this.embedded = false,
    this.onDeleted,
    this.openUnlocked = false,
    this.onSittingEnded,
  }) : newCertification = false,
       onCreated = null,
       onCreateCancelled = null;

  /// A new certification's page.
  const CertificationDetailPage.newCertification({
    super.key,
    this.embedded = false,
    this.onCreated,
    this.onCreateCancelled,
  }) : newCertification = true,
       certificationId = '',
       onDeleted = null,
       openUnlocked = false,
       onSittingEnded = null;

  @override
  ConsumerState<CertificationDetailPage> createState() =>
      _CertificationDetailPageState();
}

class _CertificationDetailPageState
    extends ConsumerState<CertificationDetailPage>
    with
        RecordEditHost<CertificationDetailPage, Certification>,
        RecordOpenUnlocked<CertificationDetailPage, Certification>,
        _CertificationDetailPageEditing,
        RecordCreating<CertificationDetailPage, Certification>,
        _CertificationDetailPageCreating {
  bool _hasRedirected = false;

  @override
  void dispose() {
    disposeEditing();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (isCreating) {
      final seed = newRecordSeed;
      return newRecordWaiting(context) ??
          _CertificationDetailContent(
            certification: shownRecord(seed!),
            stored: seed,
            embedded: widget.embedded,
            host: this,
          );
    }
    // Desktop redirect: a root visit (deep link, sidebar) moves into the
    // master-detail split. A pushed page, opened from a dive's details
    // say, stays put: the redirect's go() would erase the page under it
    // and its back arrow (#3292).
    if (!_hasRedirected &&
        shouldRedirectToMasterDetail(
          context,
          embedded: widget.embedded,
          viewMode: ref.read(certificationListViewModeProvider),
        )) {
      _hasRedirected = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          context.go(
            certificationPaneLocation(
              widget.certificationId,
              openUnlocked: widget.openUnlocked,
            ),
          );
        }
      });
    }

    final certificationAsync = ref.watch(
      certificationByIdProvider(widget.certificationId),
    );
    followStored(certificationByIdProvider(widget.certificationId));

    return certificationAsync.when(
      data: (certification) {
        if (certification == null) {
          if (widget.embedded) {
            return Center(
              child: Text(context.l10n.certifications_detail_notFound),
            );
          }
          return Scaffold(
            appBar: AppBar(
              title: Text(context.l10n.certifications_detail_appBar_title),
            ),
            body: Center(
              child: Text(context.l10n.certifications_detail_notFound),
            ),
          );
        }
        openUnlockedOnce(certification);
        return _CertificationDetailContent(
          certification: shownRecord(certification),
          stored: certification,
          embedded: widget.embedded,
          onDeleted: widget.onDeleted,
          host: this,
        );
      },
      loading: () {
        if (widget.embedded) {
          return const Center(child: CircularProgressIndicator());
        }
        return Scaffold(
          appBar: AppBar(
            title: Text(context.l10n.certifications_detail_appBar_title),
          ),
          body: const Center(child: CircularProgressIndicator()),
        );
      },
      error: (error, stack) {
        if (widget.embedded) {
          return Center(child: Text('Error: $error'));
        }
        return Scaffold(
          appBar: AppBar(
            title: Text(context.l10n.certifications_detail_appBar_title),
          ),
          body: Center(child: Text('Error: $error')),
        );
      },
    );
  }
}

class _CertificationDetailContent extends ConsumerWidget {
  /// The certification the cards show: the sitting's while unlocked.
  final Certification certification;

  /// The certification as stored.
  final Certification stored;
  final bool embedded;
  final VoidCallback? onDeleted;

  /// The page, which edits in place.
  final _CertificationDetailPageState host;

  const _CertificationDetailContent({
    required this.certification,
    required this.stored,
    required this.host,
    this.embedded = false,
    this.onDeleted,
  });

  /// A certification not yet created: what it cannot have yet is left out.
  bool get _creating => host.isCreating;

  /// [child] as the card [id].
  Widget _framed(CertificationCardId id, Widget child) =>
      host._framed(id, child);

  /// Whether the empty card [id] is shown in the sitting.
  bool _shows(CertificationCardId id) => host._showsWhileEmpty(id);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(certificationCatalogSyncProvider);
    final units = ref.watch(unitFormatterProvider);
    final body = SingleChildScrollView(
      controller: DetailScrollController.maybeOf(context),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status banner
          if (_creating)
            const SizedBox.shrink()
          else
            _calculated(_buildStatusBanner(context, units)),
          if (!_creating) const SizedBox(height: 24),

          // Header with agency logo
          _buildHeader(context),
          const SizedBox(height: 24),

          // Basic info
          _framed(CertificationCardId.details, _buildBasicInfoSection(context)),
          const SizedBox(height: 16),

          // Dates
          _framed(
            CertificationCardId.dates,
            _buildDatesSection(context, units),
          ),
          const SizedBox(height: 16),
          // Refresher and renewal currency (issue #2267). Carries its own
          // bottom gap, so an absent section leaves no extra space.
          if (_creating)
            const SizedBox.shrink()
          else
            _framed(
              CertificationCardId.currency,
              CertificationCurrencySection(
                certification: certification,
                shown: host.maybeEditController?.session,
              ),
            ),

          // Instructor info
          if (certification.instructorName != null ||
              certification.instructorNumber != null ||
              certification.instructorId != null ||
              _shows(CertificationCardId.instructor)) ...[
            _framed(
              CertificationCardId.instructor,
              _buildInstructorSection(context, ref),
            ),
            const SizedBox(height: 16),
          ],

          // Training course
          if (!_creating) _buildCourseSection(context, ref),

          // Card photos
          if (certification.hasPhotos ||
              _shows(CertificationCardId.cardPhotos)) ...[
            _framed(
              CertificationCardId.cardPhotos,
              _buildPhotosSection(context),
            ),
            const SizedBox(height: 16),
          ],

          // Other papers; the card images show above (issue #2613).
          _framed(
            CertificationCardId.documents,
            DocumentsSection<Certification>(
              owner: DocumentOwner(
                DocumentOwnerKind.certification,
                certification.id,
              ),
              excludeCards: true,
            ),
          ),
          const SizedBox(height: 16),

          // Notes
          if (certification.notes.isNotEmpty ||
              _shows(CertificationCardId.notes))
            _framed(CertificationCardId.notes, _buildNotesSection(context)),
        ],
      ),
    );

    if (embedded) {
      return host.editPane(
        header: RecordPaneRow(
          locked: _buildEmbeddedHeader(context, ref),
          unlocked: host.isSittingOpen
              ? host.editingPaneRow(stored, menu: _menu(context, ref))
              : null,
        ),
        shown: certification,
        content: body,
      );
    }

    final bar = AppBar(
      title: Text(
        certificationTitleL10n(
          certification,
          context.l10n,
          catalog: context.certificationCatalog,
        ),
      ),
      actions: [host.lockButton(certification), _menu(context, ref)],
    );
    return host.editScaffold(
      record: stored,
      shown: certification,
      lockedBar: bar,
      unlockedActions: [_menu(context, ref)],
      content: body,
    );
  }

  Widget _buildEmbeddedHeader(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          bottom: BorderSide(color: colorScheme.outlineVariant, width: 1),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                _abbreviateAgency(
                  context.certificationCatalog
                      .agency(certification.agency)
                      .localizedName(context.l10n),
                ),
                style: TextStyle(
                  color: colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  certificationTitleL10n(
                    certification,
                    context.l10n,
                    catalog: context.certificationCatalog,
                  ),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  context.certificationCatalog
                      .agency(certification.agency)
                      .localizedName(context.l10n),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          host.lockButton(certification, compact: true),
          _menu(context, ref, compact: true),
        ],
      ),
    );
  }

  /// Delete, through the sitting.
  void _requestDelete(BuildContext context, WidgetRef ref) {
    recordOperationRunnerOf(
      host.editController,
      record: 'certification ${certification.id}',
    )(() => _handleDelete(context, ref));
  }

  /// Asks, then deletes; whether it was deleted.
  Future<bool> _handleDelete(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final deleted = context.l10n.certifications_detail_snackBar_deleted;
    final confirmed = await _showDeleteConfirmation(context);
    if (!confirmed || !context.mounted) return false;
    await ref
        .read(certificationListNotifierProvider.notifier)
        .deleteCertification(certification.id);
    if (context.mounted) {
      if (embedded) {
        onDeleted?.call();
      } else {
        context.pop();
      }
    }
    messenger.showSnackBar(SnackBar(content: Text(deleted)));
    return true;
  }

  Widget _buildStatusBanner(BuildContext context, UnitFormatter units) {
    if (certification.isExpired) {
      return Semantics(
        label:
            'Warning: This certification has expired${certification.expiryDate != null ? ' on ${units.formatDate(certification.expiryDate)}' : ''}',
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.red.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.warning, color: Colors.red),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.certifications_detail_status_expired,
                      style: const TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (certification.expiryDate != null)
                      Text(
                        context.l10n.certifications_detail_status_expiredOn(
                          units.formatDate(certification.expiryDate),
                        ),
                        style: TextStyle(
                          color: Colors.red.withValues(alpha: 0.8),
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    } else if (certification.expiresWithin(90)) {
      final days = certification.daysUntilExpiry ?? 0;
      return Semantics(
        label:
            'Warning: Certification expires in $days days${certification.expiryDate != null ? ' on ${units.formatDate(certification.expiryDate)}' : ''}',
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.orange.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.schedule, color: Colors.orange),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.certifications_detail_status_expiresInDays(
                        days,
                      ),
                      style: const TextStyle(
                        color: Colors.orange,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (certification.expiryDate != null)
                      Text(
                        context.l10n.certifications_detail_status_expiresOn(
                          units.formatDate(certification.expiryDate),
                        ),
                        style: TextStyle(
                          color: Colors.orange.withValues(alpha: 0.8),
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildHeader(BuildContext context) {
    return Center(
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Text(
                _agencyBadge(
                  context.certificationCatalog
                      .agency(certification.agency)
                      .localizedName(context.l10n),
                ),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            certificationTitleL10n(
              certification,
              context.l10n,
              catalog: context.certificationCatalog,
            ),
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            context.certificationCatalog
                .agency(certification.agency)
                .localizedName(context.l10n),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBasicInfoSection(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: DetailRowGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionTitle(
                context,
                context.l10n.certifications_detail_sectionTitle_details,
              ),
              const SizedBox(height: 12),
              // Only shown when the stored name says something the agency and
              // certification rows do not already say.
              if (customNameOrNull(
                    certification,
                    catalog: context.certificationCatalog,
                  ) !=
                  null)
                IconDetailRow(
                  icon: Icons.card_membership,
                  label: context.l10n.certifications_detail_label_title,
                  value: customNameOrNull(
                    certification,
                    catalog: context.certificationCatalog,
                  )!,
                ),
              IconDetailRow(
                icon: Icons.business,
                label: context.l10n.certifications_detail_label_agency,
                value: context.certificationCatalog
                    .agency(certification.agency)
                    .localizedName(context.l10n),
              ),
              if (certification.level != null)
                IconDetailRow(
                  icon: Icons.workspace_premium,
                  label: context.l10n.certifications_detail_label_certification,
                  value: context.certificationCatalog
                      .level(certification.level!)
                      .localizedName(context.l10n),
                ),
              if (certification.hasMultipleCredentials)
                IconDetailRow(
                  icon: Icons.workspace_premium_outlined,
                  label:
                      context.l10n.certifications_detail_label_alsoRecognized,
                  value: certification.additionalCredentials
                      .map((c) {
                        final a = context.certificationCatalog
                            .agency(c.agency)
                            .localizedName(context.l10n);
                        final level = c.level;
                        final l = level == null
                            ? null
                            : context.certificationCatalog
                                  .level(level)
                                  .localizedName(context.l10n);
                        return l == null ? a : '$a $l';
                      })
                      .join(' · '),
                ),
              if (certification.cardNumber != null)
                IconDetailRow(
                  icon: Icons.numbers,
                  label: context.l10n.certifications_detail_label_cardNumber,
                  value: certification.cardNumber!,
                  copyable: true,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDatesSection(BuildContext context, UnitFormatter units) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: DetailRowGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionTitle(
                context,
                context.l10n.certifications_detail_sectionTitle_dates,
              ),
              const SizedBox(height: 12),
              if (certification.issueDate != null)
                IconDetailRow(
                  icon: Icons.event_available,
                  label: context.l10n.certifications_detail_label_issueDate,
                  value: units.formatDate(certification.issueDate),
                ),
              if (certification.expiryDate != null)
                IconDetailRow(
                  icon: Icons.event_busy,
                  label: context.l10n.certifications_detail_label_expiryDate,
                  value: units.formatDate(certification.expiryDate),
                  valueColor: certification.isExpired
                      ? Colors.red
                      : certification.expiresWithin(90)
                      ? Colors.orange
                      : null,
                ),
              if (certification.expiryDate == null)
                IconDetailRow(
                  icon: Icons.all_inclusive,
                  label: context.l10n.certifications_detail_label_validity,
                  value: context.l10n.certifications_detail_noExpiration,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInstructorSection(BuildContext context, WidgetRef ref) {
    final instructorId = certification.instructorId;
    final linkedBuddy = instructorId != null
        ? ref.watch(buddyByIdProvider(instructorId)).value
        : null;
    // Fall back to the linked buddy's name when the snapshot text fields
    // were cleared (e.g. after a data-quality fix-up); if there's still
    // nothing to show, hide the section entirely.
    final displayName = certification.instructorName ?? linkedBuddy?.name;

    if (displayName == null &&
        certification.instructorNumber == null &&
        !_shows(CertificationCardId.instructor)) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: DetailRowGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionTitle(
                context,
                context.l10n.certifications_detail_sectionTitle_instructor,
              ),
              const SizedBox(height: 12),
              if (displayName != null)
                linkedBuddy != null
                    ? ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          Icons.person,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        title: Text(
                          context
                              .l10n
                              .certifications_detail_label_instructorName,
                        ),
                        subtitle: Text(displayName),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          if (embedded) {
                            context.go('/buddies?selected=$instructorId');
                          } else {
                            context.push('/buddies/$instructorId');
                          }
                        },
                      )
                    : IconDetailRow(
                        icon: Icons.person,
                        label: context
                            .l10n
                            .certifications_detail_label_instructorName,
                        value: displayName,
                      ),
              if (certification.instructorNumber != null)
                IconDetailRow(
                  icon: Icons.badge,
                  label:
                      context.l10n.certifications_detail_label_instructorNumber,
                  value: certification.instructorNumber!,
                  copyable: true,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNotesSection(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle(
              context,
              context.l10n.certifications_detail_sectionTitle_notes,
            ),
            const SizedBox(height: 12),
            MarkdownNotesView(certification.notes),
          ],
        ),
      ),
    );
  }

  String _abbreviateAgency(String displayName) {
    if (displayName.length <= 4) {
      return displayName;
    }
    return displayName.substring(0, 4);
  }

  /// The first four characters of an agency name, for the badge.
  String _agencyBadge(String name) =>
      name.length > 4 ? name.substring(0, 4) : name;
}
