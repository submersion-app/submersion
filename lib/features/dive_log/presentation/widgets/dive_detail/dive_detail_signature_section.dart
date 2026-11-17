import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_providers.dart';
import 'package:submersion/features/courses/presentation/providers/course_providers.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_course_rows.dart';
import 'package:submersion/features/signatures/presentation/providers/signature_providers.dart';
import 'package:submersion/features/signatures/presentation/widgets/buddy_signatures_section.dart';
import 'package:submersion/features/signatures/presentation/widgets/signature_capture_widget.dart';
import 'package:submersion/features/signatures/presentation/widgets/signature_display_widget.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/fill_last_column.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_buddies_sitting.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_signatures_sitting.dart';
import 'package:submersion/features/signatures/data/services/signature_storage_service.dart';
import 'package:submersion/features/signatures/domain/entities/signature.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_controller.dart';
import 'package:submersion/shared/widgets/record_editing/sitting_list.dart';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// The Signatures content: buddy signatures plus the optional
/// course-instructor signature card. The same content in the normal section
/// flow and beside Buddies.
///
/// Beside Buddies the row hands it the taller card's height (issue #4583).
/// A single card is returned bare so that it grows to fill that height; two
/// share it through a [FillLastColumn], the lower card taking the extra.
///
/// On a page that offers editing (issue #4527) it reads only, locked and
/// in a closed card alike, showing the sitting's buddies and signatures once
/// the sitting changed them. [editing] is the open card's sitting: its
/// captures and deletes go there, held until Save.
class DiveSignaturesSection extends ConsumerWidget {
  const DiveSignaturesSection({super.key, required this.dive, this.editing});

  final Dive dive;
  final EditSession<Dive>? editing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scope = RecordEditScope.maybeOf<Dive>(context);
    final editing = this.editing;
    final session = editing ?? scope?.session;
    // What the sitting holds: in the open card always, elsewhere once it
    // has changed them.
    List<T>? held<T>(SittingList<Dive, T> list) {
      if (session == null) return null;
      if (editing != null || list.isChanged(session)) {
        return list.current(session);
      }
      return null;
    }

    final heldBuddies = held(diveBuddiesList);
    final heldSignatures = held(diveSignaturesList);
    final interactive = scope == null || editing != null;
    final buddies = BuddySignaturesSection(
      diveId: dive.id,
      buddies: heldBuddies,
      signatures: heldSignatures?.where((s) => s.isBuddySignature).toList(),
      requestShown: interactive,
      onCaptured: editing == null
          ? null
          : (bwr, strokes, size) =>
                _captureForBuddy(editing, bwr, strokes, size),
    );
    if (dive.courseIds.isEmpty) return buddies;

    // The buddy card draws nothing for a dive without buddies, or when
    // either of its reads fails, so its gap must go with it or the
    // instructor's card starts 24px down. It draws a placeholder while the
    // buddies first load, so it counts as shown until then. A reload keeps
    // the last answer: `value` holds it through one driven by a dependency,
    // where `valueOrNull` reads as loading and the placeholder and its gap
    // would flicker in and out.
    final hasBuddies = heldBuddies != null
        ? heldBuddies.isNotEmpty
        : ref.watch(
            buddiesForDiveProvider(dive.id).select(
              (async) => !async.hasError && (async.value?.isNotEmpty ?? true),
            ),
          );
    final signaturesFailed =
        heldSignatures == null &&
        ref.watch(
          buddySignaturesForDiveProvider(
            dive.id,
          ).select((async) => async.hasError),
        );
    final buddiesShow = hasBuddies && !signaturesFailed;
    final training = _TrainingSignatureCard(
      dive: dive,
      held: heldSignatures == null
          ? null
          : (
              signature: heldSignatures
                  .where((s) => s.isInstructorSignature)
                  .firstOrNull,
            ),
      interactive: interactive,
      editing: editing,
    );
    if (!buddiesShow) return training;
    return FillLastColumn(
      children: [buddies, const SizedBox(height: 24), training],
    );
  }
}

/// Renders a buddy's drawn signature and holds it in [session], as the
/// immediate path saves it.
Future<void> _captureForBuddy(
  EditSession<Dive> session,
  BuddyWithRole bwr,
  List<List<Offset>> strokes,
  Size size,
) async {
  final png = await SignatureStorageService.strokesToPng(
    strokes: strokes,
    width: size.width,
    height: size.height,
    strokeColor: const Color(0xFF000000),
    strokeWidth: 3.0,
  );
  if (session.isDisposed || session.isFrozen) return;
  addCapturedSignature(
    session,
    Signature(
      id: _uuid.v4(),
      diveId: session.stored.id,
      imageData: png,
      signerId: bwr.buddy.id,
      signerName: bwr.buddy.name,
      signedAt: DateTime.now(),
      type: SignatureType.buddy,
      role: bwr.primaryRole.id,
    ),
  );
}

/// The course instructor's signature on a training dive.
class _TrainingSignatureCard extends ConsumerWidget {
  const _TrainingSignatureCard({
    required this.dive,
    this.held,
    this.interactive = true,
    this.editing,
  });

  final Dive dive;

  /// The instructor's signature as a sitting has it; null reads the stored
  /// one.
  final ({Signature? signature})? held;

  /// Whether it can be captured or deleted here.
  final bool interactive;

  /// The open card's sitting, which holds a capture or a delete.
  final EditSession<Dive>? editing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final heldSignature = held;
    final signatureAsync = heldSignature != null
        ? AsyncValue.data(heldSignature.signature)
        : ref.watch(signatureForDiveProvider(dive.id));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // spaceBetween with two loose Flexible children, never a Spacer:
            // a Spacer is tight and claims its half of the free space whether
            // or not the chip needs it, which both strands a gap after the
            // chip and leaves the chip itself unbounded. An unbounded chip
            // overflowed this header by 15px on a phone-width pane as soon as
            // the course name ran past a word or two.
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    context.l10n.diveLog_detail_section_trainingSignature,
                    style: Theme.of(context).textTheme.titleMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // One chip per course (#2515).
                Flexible(child: DiveCourseChips(diveId: dive.id)),
              ],
            ),
            const Divider(),
            signatureAsync.when(
              data: (signature) {
                if (signature != null) {
                  final session = editing;
                  return SignatureDisplayWidget(
                    signature: signature,
                    showDeleteButton: interactive,
                    onDelete: () {
                      if (session != null) {
                        removeSignature(session, signature.id);
                        return;
                      }
                      ref
                          .read(signatureSaveNotifierProvider.notifier)
                          .deleteSignature(signature.id, dive.id);
                    },
                  );
                }

                // Read only, there is nothing to offer.
                if (!interactive) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      context.l10n.signatures_notSigned,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  );
                }

                // No signature yet: show add signature button
                return _buildAddSignatureButton(context, ref);
              },
              loading: () => const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, _) => Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  context.l10n.diveLog_detail_errorLoadingSignature('$error'),
                  style: TextStyle(color: colorScheme.error),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddSignatureButton(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    // The representative course's instructor signs (#2515).
    final instructorName = ref
        .watch(coursesForDiveProvider(dive.id))
        .value
        ?.firstOrNull
        ?.instructorName;

    return Semantics(
      button: true,
      label: context.l10n.diveLog_detail_captureSignature,
      child: InkWell(
        onTap: () => _showSignatureCapture(context, ref, instructorName),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            border: Border.all(
              color: colorScheme.outline.withValues(alpha: 0.5),
              style: BorderStyle.solid,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Icon(Icons.draw_outlined, size: 48, color: colorScheme.primary),
              const SizedBox(height: 12),
              Text(
                context.l10n.diveLog_detail_captureSignature,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(color: colorScheme.primary),
              ),
              const SizedBox(height: 4),
              Text(
                context.l10n.diveLog_detail_signatureDescription,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSignatureCapture(
    BuildContext context,
    WidgetRef ref,
    String? instructorName,
  ) {
    // The representative course's instructor signs (#2515).
    final instructorId = ref
        .read(coursesForDiveProvider(dive.id))
        .value
        ?.firstOrNull
        ?.instructorId;

    // Captured before the sheet closes: the save outlives it, and reporting
    // a failure needs a messenger that is still in the tree.
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    // So is the container: this card can remount while the sheet is up.
    final container = ProviderScope.containerOf(context, listen: false);

    final session = editing;
    showSignatureCaptureSheet(
      context: context,
      initialSignerName: instructorName,
      onSave: (strokes, signerName, canvasSize) async {
        if (session != null) {
          final png = await SignatureStorageService.strokesToPng(
            strokes: strokes,
            width: canvasSize.width,
            height: canvasSize.height,
            strokeColor: const Color(0xFF000000),
            strokeWidth: 3.0,
            backgroundColor: Colors.white,
          );
          if (session.isDisposed || session.isFrozen) return;
          addCapturedSignature(
            session,
            Signature(
              id: _uuid.v4(),
              diveId: session.stored.id,
              imageData: png,
              signerId: instructorId,
              signerName: signerName,
              signedAt: DateTime.now(),
              type: SignatureType.instructor,
            ),
          );
          return;
        }
        // The strokes are in the capture canvas's own coordinates, so the
        // PNG is rendered at that exact size. A hardcoded size cropped
        // every signature drawn on a canvas wider than it (issue #1358).
        final signature = await container
            .read(signatureSaveNotifierProvider.notifier)
            .saveFromStrokes(
              diveId: dive.id,
              strokes: strokes,
              width: canvasSize.width,
              height: canvasSize.height,
              signerName: signerName,
              signerId: instructorId,
              backgroundColor: Colors.white,
            );
        // A null result means the save threw. Nothing watches the notifier's
        // AsyncValue, so without this the failure is entirely silent.
        if (signature == null) {
          messenger.showSnackBar(
            SnackBar(content: Text(l10n.signatures_error_saveFailed)),
          );
        }
      },
    );
  }
}
