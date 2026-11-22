import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:submersion/features/buddies/presentation/editing/buddy_new_sitting.dart';
import 'package:submersion/features/change_log/presentation/widgets/change_log_history_menu_item.dart';
import 'package:submersion/features/connections/domain/entities/connection_kind.dart';
import 'package:submersion/features/connections/domain/entities/node_ref.dart';
import 'package:submersion/features/connections/presentation/widgets/open_in_connections.dart';
import 'package:submersion/shared/widgets/country_flag.dart';
import 'package:submersion/shared/widgets/icon_detail_row.dart';
import 'package:submersion/shared/widgets/profile_photo/profile_avatar.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/features/buddies/presentation/buddy_certification_l10n.dart';
import 'package:submersion/features/buddies/presentation/buddy_dive_share.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/core/router/pushed_route.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/shared/widgets/master_detail/detail_scroll_retainer.dart';
import 'package:submersion/features/buddies/data/repositories/buddy_repository.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_providers.dart';
import 'package:submersion/features/buddies/presentation/widgets/buddy_favorite_button.dart';
import 'package:submersion/features/buddies/presentation/widgets/buddy_gear_section.dart';
import 'package:submersion/features/buddies/presentation/widgets/buddy_photos_section.dart';
import 'package:submersion/features/buddies/presentation/widgets/buddy_shared_dives_section.dart';
import 'package:submersion/features/buddies/presentation/widgets/buddy_card_details_section.dart';
import 'package:submersion/features/certifications/presentation/providers/certification_providers.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/certifications/presentation/certification_title_l10n.dart';
import 'package:submersion/features/certification_agencies/presentation/providers/certification_catalog_context.dart';
import 'package:submersion/features/certification_agencies/presentation/providers/certification_catalog_providers.dart';
import 'package:submersion/features/documents/presentation/widgets/documents_section.dart';
import 'package:submersion/features/documents/domain/entities/document.dart';
import 'package:submersion/shared/widgets/detail_row/detail_row_group.dart';
import 'package:submersion/shared/widgets/markdown_notes/markdown_notes_view.dart';
import 'package:submersion/features/buddies/data/services/buddy_edit_save_service.dart';
import 'package:submersion/features/buddies/presentation/editing/buddy_card_ids.dart';
import 'package:submersion/features/buddies/presentation/editing/buddy_certifications_sitting.dart';
import 'package:submersion/features/buddies/presentation/editing/buddy_edit_cards.dart';
import 'package:submersion/features/buddies/presentation/pages/buddy_edit_routes.dart';
import 'package:submersion/features/buddies/presentation/editing/buddy_gear_sitting.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_location.dart';
import 'package:submersion/features/equipment/domain/services/gear_with_buddy.dart';
import 'package:submersion/features/equipment/presentation/pages/equipment_location_list_page.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_location_providers.dart';
import 'package:submersion/features/documents/presentation/editing/record_document_links_sitting.dart';
import 'package:submersion/shared/widgets/record_editing/add_strip.dart';
import 'package:submersion/shared/widgets/record_editing/edit_card.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';
import 'package:submersion/shared/widgets/record_editing/record_card_fade.dart';
import 'package:submersion/shared/widgets/record_editing/record_card_frame.dart';
import 'package:submersion/shared/widgets/record_editing/record_card_pencil.dart';
import 'package:submersion/shared/widgets/record_editing/record_creating.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_host.dart';
import 'package:submersion/shared/widgets/record_editing/record_open_unlocked.dart';
import 'package:submersion/shared/widgets/record_editing/record_operation_gate.dart';
import 'package:submersion/shared/widgets/record_editing/record_pane_row.dart';

part 'buddy_detail_page_creating.dart';
part 'buddy_detail_page_editing.dart';
part 'buddy_detail_page_header.dart';

/// A buddy's page. It opens locked and edits in place (issue #4527): its cards
/// are held in one sitting and written by one Save.

class BuddyDetailPage extends ConsumerStatefulWidget {
  final String buddyId;

  /// When true, renders without Scaffold wrapper for use in master-detail layout.
  final bool embedded;

  /// Callback when delete completes (used in embedded mode).
  final VoidCallback? onDeleted;

  /// Opens unlocked, as the old edit address asks (`?mode=edit`).
  final bool openUnlocked;

  /// Told when a sitting the page opened unlocked ends: the list pane's
  /// edit returns to the buddy in view.
  final VoidCallback? onSittingEnded;

  /// A new buddy (issue #4527, phase 3, plan 11): the page opened unlocked
  /// on a buddy not yet created, with what the opener brought.
  final ({NewBuddySeed? seed})? newBuddy;

  /// The pane's own: given the new buddy's id once created.
  final void Function(String buddyId)? onCreated;

  /// The pane's own: told when a new buddy's page leaves uncreated.
  final VoidCallback? onCreateCancelled;

  const BuddyDetailPage({
    super.key,
    required this.buddyId,
    this.embedded = false,
    this.onDeleted,
    this.openUnlocked = false,
    this.onSittingEnded,
  }) : newBuddy = null,
       onCreated = null,
       onCreateCancelled = null;

  /// A new buddy's page.
  const BuddyDetailPage.newBuddy({
    super.key,
    NewBuddySeed? seed,
    this.embedded = false,
    this.onCreated,
    this.onCreateCancelled,
  }) : newBuddy = (seed: seed),
       buddyId = '',
       onDeleted = null,
       openUnlocked = false,
       onSittingEnded = null;

  @override
  ConsumerState<BuddyDetailPage> createState() => _BuddyDetailPageState();
}

class _BuddyDetailPageState extends ConsumerState<BuddyDetailPage>
    with
        RecordEditHost<BuddyDetailPage, Buddy>,
        RecordOpenUnlocked<BuddyDetailPage, Buddy>,
        _BuddyDetailPageEditing,
        RecordCreating<BuddyDetailPage, Buddy>,
        _BuddyDetailPageCreating {
  bool _hasRedirected = false;

  @override
  void dispose() {
    disposeEditing();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(certificationCatalogSyncProvider);
    if (isCreating) {
      final waiting = newRecordWaiting(context);
      if (waiting != null) return waiting;
      final seed = newRecordSeed!;
      return _BuddyDetailContent(
        buddy: shownRecord(seed),
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
          viewMode: ref.read(buddyListViewModeProvider),
        )) {
      _hasRedirected = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          context.go(
            buddyPaneLocation(
              widget.buddyId,
              openUnlocked: widget.openUnlocked,
            ),
          );
        }
      });
    }

    final buddyAsync = ref.watch(buddyByIdProvider(widget.buddyId));
    followStored(buddyByIdProvider(widget.buddyId));

    return buddyAsync.when(
      data: (buddy) {
        if (buddy == null) {
          if (widget.embedded) {
            return Center(child: Text(context.l10n.buddies_detail_notFound));
          }
          return Scaffold(
            appBar: AppBar(title: Text(context.l10n.buddies_title_singular)),
            body: Center(child: Text(context.l10n.buddies_detail_notFound)),
          );
        }
        openUnlockedOnce(buddy);
        return _BuddyDetailContent(
          buddy: shownRecord(buddy),
          stored: buddy,
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
          appBar: AppBar(title: Text(context.l10n.buddies_title_singular)),
          body: const Center(child: CircularProgressIndicator()),
        );
      },
      error: (error, stack) {
        if (widget.embedded) {
          return Center(
            child: Text(context.l10n.buddies_detail_error(error.toString())),
          );
        }
        return Scaffold(
          appBar: AppBar(title: Text(context.l10n.buddies_title_singular)),
          body: Center(
            child: Text(context.l10n.buddies_detail_error(error.toString())),
          ),
        );
      },
    );
  }
}

class _BuddyDetailContent extends ConsumerWidget {
  /// The buddy the cards show: the sitting's while unlocked.
  final Buddy buddy;

  /// The buddy as stored.
  final Buddy stored;
  final bool embedded;
  final VoidCallback? onDeleted;

  /// The page, which edits in place.
  final _BuddyDetailPageState host;

  const _BuddyDetailContent({
    required this.buddy,
    required this.stored,
    required this.host,
    this.embedded = false,
    this.onDeleted,
  });

  /// Whether the buddy is not yet created: what it cannot have yet (gear
  /// lent, shared dives, photos) is left out, and nothing acts on it.
  bool get _creating => host.isCreating;

  /// [child] as the card [id].
  Widget _framed(BuddyCardId id, Widget child) => host._framed(id, child);

  /// Whether the empty card [id] is shown in the sitting.
  bool _shows(BuddyCardId id) => host._showsWhileEmpty(id);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(certificationCatalogSyncProvider);
    final statsAsync = ref.watch(buddyStatsProvider(buddy.id));
    final units = ref.watch(unitFormatterProvider);

    final body = SingleChildScrollView(
      controller: DetailScrollController.maybeOf(context),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Profile header
          _framed(BuddyCardId.header, _buildProfileHeader(context, ref)),
          const SizedBox(height: 24),

          // Contact info
          if (buddy.hasContactInfo ||
              buddy.socialHandle != null ||
              buddy.country != null ||
              buddy.linkedDiverId != null ||
              _shows(BuddyCardId.contact)) ...[
            _framed(BuddyCardId.contact, _buildContactSection(context, ref)),
            const SizedBox(height: 24),
          ],

          // What their buddy card said (issue #3728).
          if (buddy.hasCardDetails) ...[
            _faded(
              RecordCardFadeReason.imported,
              BuddyCardDetailsSection(buddy: buddy),
            ),
            const SizedBox(height: 24),
          ],

          // Certifications (issue #553): full list from the certifications
          // table, with an empty state.
          _framed(
            BuddyCardId.certifications,
            _buildCertificationSection(context, ref),
          ),
          const SizedBox(height: 24),

          // Statistics
          _framed(
            BuddyCardId.statistics,
            _buildStatsSection(context, statsAsync, units),
          ),
          const SizedBox(height: 24),

          // Gear they have (issue #3790), with its own spacing: most buddies
          // have none and show no gap.
          if (_creating)
            const SizedBox.shrink()
          else if (!host._gearEmpty(ref, buddy) || _shows(BuddyCardId.gear))
            _framed(
              BuddyCardId.gear,
              BuddyGearSection(
                buddy: buddy,
                shown: host.maybeEditController?.session,
              ),
            ),

          // Notes
          if (buddy.notes.isNotEmpty || _shows(BuddyCardId.notes)) ...[
            _framed(BuddyCardId.notes, _buildNotesSection(context)),
            const SizedBox(height: 24),
          ],
          _framed(
            BuddyCardId.documents,
            DocumentsSection<Buddy>(
              owner: DocumentOwner(DocumentOwnerKind.buddy, buddy.id),
            ),
          ),
          const SizedBox(height: 24),

          if (!_creating) ...[
            // Shared dives
            _faded(
              RecordCardFadeReason.calculated,
              BuddySharedDivesSection(buddyId: buddy.id),
            ),

            // Photos and videos they are tagged in (issue #1745)
            _faded(
              RecordCardFadeReason.calculated,
              BuddyPhotosSection(buddyId: buddy.id),
            ),
          ],
        ],
      ),
    );

    if (embedded) {
      return host.editPane(
        header: RecordPaneRow(
          locked: _buildEmbeddedHeader(context, ref),
          unlocked: host.isSittingOpen
              ? host.editingPaneRow(
                  stored,
                  menu: _creating
                      ? const SizedBox.shrink()
                      : _menu(context, ref),
                )
              : null,
        ),
        shown: buddy,
        content: body,
      );
    }

    final bar = AppBar(
      title: Text(buddy.name),
      actions: [
        host.lockButton(buddy),
        // The favourite is set on the header: the bar's star only shows it.
        BuddyFavoriteButton(isFavorite: buddy.isFavorite),
        _menu(context, ref),
      ],
    );
    return host.editScaffold(
      record: stored,
      shown: buddy,
      lockedBar: bar,
      unlockedActions: [if (!_creating) _menu(context, ref)],
      content: body,
    );
  }

  Widget _buildProfileHeader(BuildContext context, WidgetRef ref) {
    return Center(
      child: Column(
        children: [
          ProfileAvatar(
            photo: buddy.photo ?? _linkedProfile(ref)?.photo,
            initials: buddy.initials,
            radius: 50,
            textStyle: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  buddy.name,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ),
              RecordCardPencil(
                cardTitle: BuddyCardId.header.localizedDisplayName(
                  context.l10n,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// The local profile this buddy is, when linked and loaded (issue #2002).
  Diver? _linkedProfile(WidgetRef ref) {
    final linkedId = buddy.linkedDiverId;
    if (linkedId == null) return null;
    return ref.watch(diverByIdProvider(linkedId)).value;
  }

  Widget _buildContactSection(BuildContext context, WidgetRef ref) {
    final linked = _linkedProfile(ref);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle(context, context.l10n.buddies_section_contact),
            const SizedBox(height: 12),
            if (buddy.linkedDiverId != null)
              ListTile(
                key: const Key('buddy_detail_linked_profile'),
                leading: const Icon(Icons.account_circle_outlined),
                title: Text(context.l10n.buddies_field_linkedProfile),
                subtitle: linked == null ? null : Text(linked.name),
                contentPadding: EdgeInsets.zero,
              ),
            if (buddy.email != null)
              ListTile(
                leading: const Icon(Icons.email),
                title: Text(buddy.email!),
                onTap: () => _launchEmail(buddy.email!),
                contentPadding: EdgeInsets.zero,
                trailing: const Icon(Icons.open_in_new, size: 16),
              ),
            if (buddy.phone != null)
              ListTile(
                leading: const Icon(Icons.phone),
                title: Text(buddy.phone!),
                onTap: () => _launchPhone(buddy.phone!),
                contentPadding: EdgeInsets.zero,
                trailing: const Icon(Icons.open_in_new, size: 16),
              ),
            if (buddy.country != null)
              ListTile(
                leading: _countryLeading(ref),
                title: Text(buddy.country!),
                subtitle: Text(context.l10n.buddies_field_country),
                contentPadding: EdgeInsets.zero,
              ),
            if (buddy.socialHandle != null)
              ListTile(
                leading: const Icon(Icons.alternate_email),
                title: Text(buddy.socialHandle!),
                subtitle: Text(context.l10n.buddyShare_social),
                contentPadding: EdgeInsets.zero,
              ),
          ],
        ),
      ),
    );
  }

  /// The country row's flag (issue #4457), or a globe when flags are off
  /// or the country is one the flag table cannot draw.
  Widget _countryLeading(WidgetRef ref) {
    final code = shownFlagCode(
      ref,
      country: buddy.country,
      code: buddy.countryCode,
    );
    return code != null
        ? SizedBox(
            width: 24,
            child: Center(child: CountryFlag(code: code, height: 14)),
          )
        : const Icon(Icons.public);
  }

  Widget _buildCertificationSection(BuildContext context, WidgetRef ref) {
    final stored = ref.watch(buddyCertificationsProvider(buddy.id));
    // The sitting's list once it holds a change.
    final session = host.maybeEditController?.session;
    final held = session != null && buddyCertificationsList.isChanged(session)
        ? buddyCertificationsList.current(session)
        : null;
    final certsAsync = held != null
        ? AsyncValue.data(buddyCertificationsInOrder(held))
        : stored;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle(context, context.l10n.buddies_section_certifications),
            const SizedBox(height: 12),
            certsAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, _) =>
                  Text('${context.l10n.common_label_error}: $error'),
              data: (certs) => certs.isEmpty
                  ? Text(
                      context.l10n.buddies_certifications_empty,
                      style: Theme.of(context).textTheme.bodyMedium,
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final cert in certs)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.card_membership),
                            title: Text(
                              certificationTitleL10n(
                                cert,
                                context.l10n,
                                catalog: context.certificationCatalog,
                              ),
                            ),
                            subtitle: Text(
                              certificationAgencyAndLevelL10n(
                                cert,
                                context.l10n,
                                catalog: context.certificationCatalog,
                              ),
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

  Widget _buildStatsSection(
    BuildContext context,
    AsyncValue<BuddyStats> statsAsync,
    UnitFormatter units,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: DetailRowGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionTitle(
                context,
                context.l10n.buddies_section_diveStatistics,
              ),
              const SizedBox(height: 12),
              statsAsync.when(
                data: (stats) => Column(
                  children: [
                    IconDetailRow(
                      icon: Icons.scuba_diving,
                      label: context.l10n.buddies_stat_divesTogether,
                      value: stats.totalDives.toString(),
                    ),
                    if (stats.firstDive != null)
                      IconDetailRow(
                        icon: Icons.first_page,
                        label: context.l10n.buddies_stat_firstDive,
                        value: units.formatDate(stats.firstDive),
                      ),
                    if (stats.lastDive != null)
                      IconDetailRow(
                        icon: Icons.last_page,
                        label: context.l10n.buddies_stat_lastDive,
                        value: units.formatDate(stats.lastDive),
                      ),
                    if (stats.favoriteSite != null)
                      IconDetailRow(
                        icon: Icons.place,
                        label: context.l10n.buddies_stat_favoriteSite,
                        value: stats.favoriteSite!,
                      ),
                  ],
                ),
                loading: () =>
                    const Center(child: CircularProgressIndicator.adaptive()),
                error: (error, _) =>
                    Text(context.l10n.buddies_error_unableToLoadStats),
              ),
              if (buddy.excludedFromRankings) ...[
                const SizedBox(height: 12),
                _buildExcludedFromRankingsNote(context),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Says why a buddy with plenty of dives is missing from the rankings
  /// (issue #3624).
  Widget _buildExcludedFromRankingsNote(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.onSurfaceVariant;
    return Row(
      children: [
        Icon(Icons.leaderboard_outlined, size: 20, color: color),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            context.l10n.buddies_stat_excludedFromRankings,
            style: theme.textTheme.bodyMedium?.copyWith(color: color),
          ),
        ),
      ],
    );
  }

  Widget _buildNotesSection(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle(context, context.l10n.buddies_section_notes),
            const SizedBox(height: 12),
            MarkdownNotesView(buddy.notes),
          ],
        ),
      ),
    );
  }

  Future<void> _launchEmail(String email) async {
    final uri = Uri(scheme: 'mailto', path: email);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _launchPhone(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }
}
