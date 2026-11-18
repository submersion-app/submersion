import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_providers.dart';
import 'package:submersion/features/signatures/domain/entities/signature.dart';
import 'package:submersion/features/signatures/presentation/providers/signature_providers.dart';
import 'package:submersion/features/signatures/presentation/widgets/buddy_signature_card.dart';
import 'package:submersion/features/signatures/presentation/widgets/buddy_signature_request_sheet.dart';
import 'package:submersion/features/signatures/presentation/widgets/signature_display_widget.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Section displaying buddy signatures for a dive
class BuddySignaturesSection extends ConsumerWidget {
  final String diveId;

  /// The dive's buddies and their signatures as a sitting on the dive has
  /// them (issue #4527); null for each reads the stored ones.
  final List<BuddyWithRole>? buddies;
  final List<Signature>? signatures;

  /// Takes a signature just drawn: the open card's sitting holds it until
  /// Save (issue #4527). Null asks no buddy to sign, as on a locked dive.
  final void Function(BuddyWithRole bwr, List<List<Offset>> strokes, Size size)?
  onCaptured;

  const BuddySignaturesSection({
    super.key,
    required this.diveId,
    this.buddies,
    this.signatures,
    this.onCaptured,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final heldBuddies = buddies;
    final heldSignatures = signatures;
    final buddiesAsync = heldBuddies != null
        ? AsyncValue.data(heldBuddies)
        : ref.watch(buddiesForDiveProvider(diveId));
    final signaturesAsync = heldSignatures != null
        ? AsyncValue.data(heldSignatures)
        : ref.watch(buddySignaturesForDiveProvider(diveId));

    return buddiesAsync.when(
      data: (buddies) {
        // Don't show section if no buddies on this dive
        if (buddies.isEmpty) {
          return const SizedBox.shrink();
        }

        return signaturesAsync.when(
          data: (signatures) =>
              _buildSection(context, ref, buddies, signatures),
          loading: () => _buildLoadingSection(context),
          error: (_, _) => const SizedBox.shrink(),
        );
      },
      loading: () => _buildLoadingSection(context),
      error: (_, _) => const SizedBox.shrink(),
    );
  }

  Widget _buildSection(
    BuildContext context,
    WidgetRef ref,
    List<BuddyWithRole> buddies,
    List<Signature> signatures,
  ) {
    // Create a map of buddyId -> signature for quick lookup
    final signatureMap = <String, Signature>{};
    for (final sig in signatures) {
      if (sig.signerId != null) {
        signatureMap[sig.signerId!] = sig;
      }
    }

    final signedCount = buddies
        .where((bwr) => signatureMap.containsKey(bwr.buddy.id))
        .length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    ExcludeSemantics(
                      child: Icon(
                        Icons.draw_outlined,
                        size: 20,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      context.l10n.signatures_title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
                if (signedCount > 0)
                  Semantics(
                    label: context.l10n.signatures_signedCountSemantics(
                      signedCount,
                      buddies.length,
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '$signedCount/${buddies.length}',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(
                            context,
                          ).colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const Divider(),
            ...buddies.map((bwr) {
              final sig = signatureMap[bwr.buddy.id];
              return BuddySignatureCard(
                buddyWithRole: bwr,
                signature: sig,
                requestShown: onCaptured != null,
                onRequestSignature: () => _requestSignature(context, bwr),
                onViewSignature: sig != null
                    ? () => _viewSignature(context, sig)
                    : null,
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingSection(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator()),
      ),
    );
  }

  void _requestSignature(BuildContext context, BuddyWithRole bwr) {
    final captured = onCaptured;
    if (captured == null) return;
    showBuddySignatureRequestSheet(
      context: context,
      buddyWithRole: bwr,
      onSave: (strokes, canvasSize) async => captured(bwr, strokes, canvasSize),
    );
  }

  void _viewSignature(BuildContext context, Signature signature) {
    showDialog(
      context: context,
      builder: (context) => SignatureFullViewDialog(signature: signature),
    );
  }
}
