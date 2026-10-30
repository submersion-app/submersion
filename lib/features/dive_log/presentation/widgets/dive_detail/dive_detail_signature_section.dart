import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/courses/presentation/providers/course_providers.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_course_rows.dart';
import 'package:submersion/features/signatures/presentation/providers/signature_providers.dart';
import 'package:submersion/features/signatures/presentation/widgets/buddy_signatures_section.dart';
import 'package:submersion/features/signatures/presentation/widgets/signature_capture_widget.dart';
import 'package:submersion/features/signatures/presentation/widgets/signature_display_widget.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The Signatures content: buddy signatures plus the optional
/// course-instructor signature card. The same content in the normal section
/// flow and beside Buddies.
class DiveSignaturesSection extends StatelessWidget {
  const DiveSignaturesSection({super.key, required this.dive});

  final Dive dive;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BuddySignaturesSection(diveId: dive.id),
        if (dive.courseIds.isNotEmpty) ...[
          const SizedBox(height: 24),
          _TrainingSignatureCard(dive: dive),
        ],
      ],
    );
  }
}

/// The course instructor's signature on a training dive.
class _TrainingSignatureCard extends ConsumerWidget {
  const _TrainingSignatureCard({required this.dive});

  final Dive dive;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final signatureAsync = ref.watch(signatureForDiveProvider(dive.id));

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
                  return SignatureDisplayWidget(
                    signature: signature,
                    showDeleteButton: true,
                    onDelete: () {
                      ref
                          .read(signatureSaveNotifierProvider.notifier)
                          .deleteSignature(signature.id, dive.id);
                    },
                  );
                }

                // No signature yet - show add signature button
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

    showSignatureCaptureSheet(
      context: context,
      initialSignerName: instructorName,
      onSave: (strokes, signerName, canvasSize) async {
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
