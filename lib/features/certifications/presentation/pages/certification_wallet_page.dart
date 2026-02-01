import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/features/certifications/domain/entities/certification.dart';
import 'package:submersion/features/certifications/presentation/providers/certification_providers.dart';
import 'package:submersion/features/certifications/presentation/widgets/certification_ecard_stack.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';

/// Full-screen page displaying the certification card stack with navigation
/// and share functionality.
class CertificationWalletPage extends ConsumerStatefulWidget {
  const CertificationWalletPage({super.key});

  @override
  ConsumerState<CertificationWalletPage> createState() =>
      _CertificationWalletPageState();
}

class _CertificationWalletPageState
    extends ConsumerState<CertificationWalletPage> {
  int _currentIndex = 0;

  void _onIndexChanged(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  void _showOptionsSheet(BuildContext context, Certification certification) {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.share),
                title: const Text('Share'),
                onTap: () {
                  Navigator.pop(context);
                  _showShareSheet(context, certification);
                },
              ),
              ListTile(
                leading: const Icon(Icons.visibility),
                title: const Text('View Details'),
                onTap: () {
                  Navigator.pop(context);
                  context.push('/certifications/${certification.id}');
                },
              ),
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Edit'),
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

  void _showShareSheet(BuildContext context, Certification certification) {
    // TODO: Replace with CertificationShareSheet when Task 6 is complete
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Share coming soon')));
  }

  @override
  Widget build(BuildContext context) {
    final certificationsAsync = ref.watch(certificationListNotifierProvider);
    final diverAsync = ref.watch(currentDiverProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Certification Wallet'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => context.push('/certifications/new'),
          ),
        ],
      ),
      body: certificationsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => _buildErrorState(context, error),
        data: (certifications) {
          final diverName = diverAsync.when(
            data: (diver) => diver?.name ?? 'Diver',
            loading: () => 'Diver',
            error: (_, _) => 'Diver',
          );

          // Ensure current index is valid after data changes
          if (_currentIndex >= certifications.length &&
              certifications.isNotEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              setState(() {
                _currentIndex = certifications.length - 1;
              });
            });
          }

          return CertificationEcardStack(
            certifications: certifications,
            diverName: diverName,
            initialIndex: _currentIndex,
            onIndexChanged: _onIndexChanged,
            onCardLongPress: (certification) =>
                _showOptionsSheet(context, certification),
          );
        },
      ),
      floatingActionButton: certificationsAsync.when(
        data: (certifications) {
          if (certifications.isEmpty) return null;

          return FloatingActionButton(
            onPressed: () {
              final index = _currentIndex.clamp(0, certifications.length - 1);
              _showShareSheet(context, certifications[index]);
            },
            child: const Icon(Icons.share),
          );
        },
        loading: () => null,
        error: (_, _) => null,
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, Object error) {
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
              'Failed to load certifications',
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
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
