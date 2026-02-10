import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/signatures/domain/entities/signature.dart';

/// Card displaying a buddy's signature status
class BuddySignatureCard extends StatelessWidget {
  final BuddyWithRole buddyWithRole;
  final Signature? signature;
  final VoidCallback? onRequestSignature;
  final VoidCallback? onViewSignature;

  const BuddySignatureCard({
    super.key,
    required this.buddyWithRole,
    this.signature,
    this.onRequestSignature,
    this.onViewSignature,
  });

  bool get hasSigned => signature != null;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final buddy = buddyWithRole.buddy;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Semantics(
        button: hasSigned,
        label:
            '${buddy.name} signature${hasSigned ? ", signed" : ", not signed"}',
        child: InkWell(
          onTap: hasSigned ? onViewSignature : null,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Status indicator
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: hasSigned
                        ? colorScheme.primaryContainer
                        : colorScheme.surfaceContainerHighest,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    hasSigned ? Icons.check : Icons.edit_outlined,
                    color: hasSigned
                        ? colorScheme.onPrimaryContainer
                        : colorScheme.onSurfaceVariant,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),

                // Buddy info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        buddy.name,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      Text(
                        buddyWithRole.role.displayName,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      if (hasSigned && signature != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Signed ${DateFormat.yMMMd().format(signature!.signedAt)}',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: colorScheme.primary),
                        ),
                      ],
                    ],
                  ),
                ),

                // Signature preview or request button
                if (hasSigned && signature != null)
                  _buildSignaturePreview(context, signature!)
                else
                  FilledButton.tonal(
                    onPressed: onRequestSignature,
                    child: const Text('Request'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSignaturePreview(BuildContext context, Signature sig) {
    return Container(
      width: 60,
      height: 30,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: sig.hasImage
            ? Image.memory(sig.imageData!, fit: BoxFit.contain)
            : const Icon(Icons.image_not_supported, size: 16),
      ),
    );
  }
}
