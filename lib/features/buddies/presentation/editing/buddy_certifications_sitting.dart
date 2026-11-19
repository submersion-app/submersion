import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/text/text_sort.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/buddies/presentation/editing/buddy_card_ids.dart';
import 'package:submersion/features/buddies/presentation/editing/buddy_certification_dialog.dart';
import 'package:submersion/features/certification_agencies/presentation/providers/certification_catalog_context.dart';
import 'package:submersion/features/certifications/data/repositories/certification_repository.dart';
import 'package:submersion/features/certifications/domain/entities/certification.dart';
import 'package:submersion/features/certifications/presentation/certification_title_l10n.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';
import 'package:submersion/shared/widgets/record_editing/record_card_header.dart';
import 'package:submersion/shared/widgets/record_editing/sitting_list.dart';
import 'package:submersion/shared/widgets/record_editing/sitting_load_failed.dart';

/// A buddy's certifications held in its page's sitting (issue #4527, phase
/// 3): added, edited and removed in a dialog, written at Save.
///
/// Only the difference is written: a certification added meanwhile, which
/// the sitting never loaded, is left as it is.
final buddyCertificationsList = SittingList<Buddy, Certification>(
  key: 'buddy.certifications',
  cardId: BuddyCardId.certifications.name,
  read: (b) => CertificationRepository().getCertificationsByBuddy(b.id),
  write: (b, loaded, current) async {
    final repository = CertificationRepository();
    final loadedById = {for (final c in loaded) c.id: c};
    final currentIds = {for (final c in current) c.id};
    var changed = false;
    for (final cert in current) {
      final owned = cert.copyWith(buddyId: b.id);
      final before = loadedById[owned.id];
      if (before == null) {
        await repository.createCertification(owned, notify: false);
        changed = true;
      } else if (owned != before) {
        await repository.updateCertification(owned, notify: false);
        changed = true;
      }
    }
    for (final cert in loaded) {
      if (currentIds.contains(cert.id)) continue;
      await repository.deleteCertification(cert.id, notify: false);
      changed = true;
    }
    return changed;
  },
);

/// [certs] in the order the buddy's page lists them when stored: newest
/// issued first, undated last, then by title; one added in the sitting
/// takes its place, not the end.
List<Certification> buddyCertificationsInOrder(List<Certification> certs) =>
    [...certs]..sort((a, b) {
      final ai = a.issueDate;
      final bi = b.issueDate;
      if (ai != bi) {
        if (ai == null) return 1;
        if (bi == null) return -1;
        return bi.compareTo(ai);
      }
      return compareTextForSort(a.name, b.name);
    });

/// A new certification for [buddy], with an id of its own so the sitting
/// can hold it.
Certification newBuddyCertification(Buddy buddy) =>
    Certification.empty().copyWith(id: const Uuid().v4(), buddyId: buddy.id);

/// The Certifications card's editor: the buddy's certifications as the
/// sitting holds them, each opened in [showBuddyCertificationDialog], with
/// add and remove. A change is a change of Certifications; held rows show
/// the changed dot. A read that failed says so and offers to try again.
class BuddyCertificationsCardEditor extends StatefulWidget {
  const BuddyCertificationsCardEditor({super.key, required this.session});

  final EditSession<Buddy> session;

  @override
  State<BuddyCertificationsCardEditor> createState() =>
      _BuddyCertificationsCardEditorState();
}

class _BuddyCertificationsCardEditorState
    extends State<BuddyCertificationsCardEditor> {
  EditSession<Buddy> get _session => widget.session;

  @override
  void initState() {
    super.initState();
    if (buddyCertificationsList.current(_session) == null) _load();
  }

  /// Reads the list (again), and draws it once read: a read answers
  /// without telling the sitting's listeners.
  Future<void> _load() async {
    await buddyCertificationsList.load(_session);
    if (mounted) setState(() {});
  }

  Future<void> _edit(BuildContext context, Certification? existing) async {
    final initial = existing ?? newBuddyCertification(_session.stored);
    final edited = await showBuddyCertificationDialog(
      context,
      initial: initial,
    );
    final current = buddyCertificationsList.current(_session);
    if (edited == null || current == null || _session.isDisposed) return;
    buddyCertificationsList.set(_session, [
      if (existing == null) ...[
        ...current,
        edited,
      ] else
        for (final c in current) c.id == edited.id ? edited : c,
    ]);
  }

  void _remove(Certification cert) {
    final current = buddyCertificationsList.current(_session);
    if (current == null) return;
    buddyCertificationsList.set(_session, [
      for (final c in current)
        if (c.id != cert.id) c,
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final session = _session;
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) {
        final held = buddyCertificationsList.current(session);
        final current = held == null ? null : buddyCertificationsInOrder(held);
        if (current == null) {
          if (buddyCertificationsList.failed(session)) {
            return SittingLoadFailed(onRetry: _load);
          }
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final loaded = {
          for (final c in buddyCertificationsList.loaded(session) ?? [])
            c.id: c,
        };
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (current.isEmpty)
              Text(
                l10n.buddies_certifications_empty,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            for (final cert in current)
              ListTile(
                key: ValueKey('buddy-cert-${cert.id}'),
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.card_membership),
                title: Row(
                  children: [
                    Flexible(
                      child: Text(
                        certificationTitleL10n(
                          cert,
                          l10n,
                          catalog: context.certificationCatalog,
                        ),
                      ),
                    ),
                    if (loaded[cert.id] != cert) ...[
                      const SizedBox(width: 6),
                      const RecordChangedDot(),
                    ],
                  ],
                ),
                subtitle: Text(
                  certificationAgencyAndLevelL10n(
                    cert,
                    l10n,
                    catalog: context.certificationCatalog,
                  ),
                ),
                onTap: () => _edit(context, cert),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: l10n.common_action_delete,
                  onPressed: () => _remove(cert),
                ),
              ),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                key: const ValueKey('buddy-cert-add'),
                icon: const Icon(Icons.add),
                label: Text(l10n.buddies_action_addCertification),
                onPressed: () => _edit(context, null),
              ),
            ),
          ],
        );
      },
    );
  }
}
