import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/features/certifications/domain/entities/certification.dart';
import 'package:submersion/features/certifications/presentation/providers/certification_providers.dart';
import 'package:submersion/features/certifications/presentation/widgets/certification_ecard_grid.dart';
import 'package:submersion/features/certifications/presentation/widgets/certification_share_sheet.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';

/// Full-screen page displaying the certification cards in a vertically
/// scrolling grid, with per-card share and options actions.
class CertificationWalletPage extends ConsumerWidget {
  const CertificationWalletPage({super.key});

  void _showOptionsSheet(
    BuildContext context,
    WidgetRef ref,
    Certification certification,
  ) {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.share),
                title: Text(context.l10n.certifications_wallet_options_share),
                onTap: () {
                  Navigator.pop(context);
                  _showShareSheet(context, ref, certification);
                },
              ),
              ListTile(
                leading: const Icon(Icons.visibility),
                title: Text(
                  context.l10n.certifications_wallet_options_viewDetails,
                ),
                onTap: () {
                  Navigator.pop(context);
                  context.push('/certifications/${certification.id}');
                },
              ),
              ListTile(
                leading: const Icon(Icons.edit),
                title: Text(context.l10n.certifications_wallet_options_edit),
                onTap: () {
                  Navigator.pop(context);
                  context.push('/certifications/${certification.id}/edit');
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showShareSheet(
    BuildContext context,
    WidgetRef ref,
    Certification certification,
  ) {
    final diverName = ref.read(currentDiverProvider).value?.name ?? 'Diver';

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => CertificationShareSheet(
        certification: certification,
        diverName: diverName,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final certificationsAsync = ref.watch(certificationListNotifierProvider);
    final diverAsync = ref.watch(currentDiverProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.certifications_wallet_appBar_title),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: context.l10n.certifications_wallet_tooltip_add,
            onPressed: () => context.push('/certifications/new'),
          ),
        ],
      ),
      body: certificationsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => _buildErrorState(context, ref, error),
        data: (certifications) {
          final diverName = diverAsync.when(
            data: (diver) => diver?.name ?? 'Diver',
            loading: () => 'Diver',
            error: (_, _) => 'Diver',
          );

          return CertificationEcardGrid(
            certifications: certifications,
            diverName: diverName,
            onCardLongPress: (certification) =>
                _showOptionsSheet(context, ref, certification),
            onShare: (certification) =>
                _showShareSheet(context, ref, certification),
            onMoreOptions: (certification) =>
                _showOptionsSheet(context, ref, certification),
          );
        },
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, WidgetRef ref, Object error) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: theme.colorScheme.error),
            const SizedBox(height: 16),
            Text(
              context.l10n.certifications_wallet_error_title,
              style: theme.textTheme.titleLarge?.copyWith(
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error.toString(),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () {
                ref.invalidate(certificationListNotifierProvider);
              },
              icon: const Icon(Icons.refresh),
              label: Text(context.l10n.certifications_wallet_error_retry),
            ),
          ],
        ),
      ),
    );
  }
}
