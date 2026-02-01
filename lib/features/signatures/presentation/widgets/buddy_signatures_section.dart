import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_providers.dart';
import 'package:submersion/features/signatures/domain/entities/signature.dart';
import 'package:submersion/features/signatures/presentation/providers/signature_providers.dart';
import 'package:submersion/features/signatures/presentation/widgets/buddy_signature_card.dart';
import 'package:submersion/features/signatures/presentation/widgets/buddy_signature_request_sheet.dart';
import 'package:submersion/features/signatures/presentation/widgets/signature_display_widget.dart';

/// Section displaying buddy signatures for a dive
class BuddySignaturesSection extends ConsumerWidget {
  final String diveId;

  const BuddySignaturesSection({super.key, required this.diveId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final buddiesAsync = ref.watch(buddiesForDiveProvider(diveId));
    final signaturesAsync = ref.watch(buddySignaturesForDiveProvider(diveId));

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
                    Icon(
                      Icons.draw_outlined,
                      size: 20,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Signatures',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
                if (signedCount > 0)
                  Container(
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
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
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
                onRequestSignature: () => _requestSignature(context, ref, bwr),
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

  void _requestSignature(
    BuildContext context,
    WidgetRef ref,
    BuddyWithRole bwr,
  ) {
    showBuddySignatureRequestSheet(
      context: context,
      buddyWithRole: bwr,
      onSave: (strokes) async {
        final notifier = ref.read(buddySignatureSaveNotifierProvider.notifier);
        await notifier.saveFromStrokes(
          diveId: diveId,
          buddyId: bwr.buddy.id,
          buddyName: bwr.buddy.name,
          role: bwr.role.name,
          strokes: strokes,
          width: 400,
          height: 200,
        );
      },
    );
  }

  void _viewSignature(BuildContext context, Signature signature) {
    showDialog(
      context: context,
      builder: (context) => SignatureFullViewDialog(signature: signature),
    );
  }
}
