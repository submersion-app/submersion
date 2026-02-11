import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/features/certifications/domain/entities/certification.dart';
import 'package:submersion/features/certifications/presentation/providers/certification_providers.dart';

/// A compact dashboard card showing a mini preview of certification cards.
///
/// Tapping the card navigates to the full certification wallet view.
class CertificationWalletCard extends ConsumerWidget {
  const CertificationWalletCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final certificationsAsync = ref.watch(certificationListNotifierProvider);
    final theme = Theme.of(context);

    return Semantics(
      button: true,
      label: context.l10n.certifications_walletCard_semanticLabel,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.go('/certifications/wallet'),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: certificationsAsync.when(
              data: (certifications) =>
                  _buildContent(context, theme, certifications),
              loading: () => _buildLoadingState(theme),
              error: (error, _) => _buildErrorState(context, theme),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    ThemeData theme,
    List<Certification> certifications,
  ) {
    final expiredCount = certifications.where((c) => c.isExpired).length;
    final expiringCount = certifications
        .where((c) => c.expiresWithin(90))
        .length;
    final warningCount = expiredCount + expiringCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Header row
        Row(
          children: [
            Icon(
              Icons.card_membership,
              color: theme.colorScheme.primary,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                context.l10n.certifications_walletCard_title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (warningCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: expiredCount > 0
                      ? theme.colorScheme.error
                      : Colors.orange,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$warningCount',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        // Mini card stack or empty state
        if (certifications.isEmpty)
          _buildEmptyState(context, theme)
        else
          _MiniCardStack(certifications: certifications),
        const SizedBox(height: 12),
        // Footer row
        Row(
          children: [
            Expanded(
              child: Text(
                certifications.isEmpty
                    ? context.l10n.certifications_walletCard_emptyFooter
                    : certifications.length == 1
                    ? context.l10n.certifications_walletCard_countSingular(
                        certifications.length,
                      )
                    : context.l10n.certifications_walletCard_countPlural(
                        certifications.length,
                      ),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: theme.colorScheme.onSurfaceVariant,
              size: 20,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context, ThemeData theme) {
    return Container(
      height: 80,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.5),
          style: BorderStyle.solid,
          width: 1,
        ),
      ),
      child: CustomPaint(
        painter: _DashedBorderPainter(
          color: theme.colorScheme.outline.withValues(alpha: 0.5),
          borderRadius: 12,
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.add_card,
                color: theme.colorScheme.onSurfaceVariant.withValues(
                  alpha: 0.7,
                ),
                size: 28,
              ),
              const SizedBox(height: 4),
              Text(
                context.l10n.certifications_walletCard_tapToAdd,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState(ThemeData theme) {
    return SizedBox(
      height: 140,
      child: Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: theme.colorScheme.primary,
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, ThemeData theme) {
    return SizedBox(
      height: 140,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: theme.colorScheme.error, size: 32),
            const SizedBox(height: 8),
            Text(
              context.l10n.certifications_walletCard_error,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Displays up to 3 certifications as small stacked cards.
class _MiniCardStack extends StatelessWidget {
  final List<Certification> certifications;

  const _MiniCardStack({required this.certifications});

  @override
  Widget build(BuildContext context) {
    // Take up to 3 certifications
    final displayCerts = certifications.take(3).toList();
    final cardCount = displayCerts.length;

    return SizedBox(
      height: 80,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (var i = cardCount - 1; i >= 0; i--)
            Positioned(
              left: i * 16.0,
              top: i * 4.0,
              child: _MiniCertCard(certification: displayCerts[i]),
            ),
        ],
      ),
    );
  }
}

/// A small card showing agency gradient and certification info.
class _MiniCertCard extends StatelessWidget {
  final Certification certification;

  const _MiniCertCard({required this.certification});

  @override
  Widget build(BuildContext context) {
    final agency = certification.agency;

    return Container(
      width: 140,
      height: 72,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [agency.primaryColor, agency.secondaryColor],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            agency.displayName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            certification.name,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

/// Custom painter for dashed border effect on empty state.
class _DashedBorderPainter extends CustomPainter {
  final Color color;
  final double borderRadius;

  static const double _dashWidth = 6;
  static const double _dashSpace = 4;

  _DashedBorderPainter({required this.color, required this.borderRadius});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0, 0, size.width, size.height),
          Radius.circular(borderRadius),
        ),
      );

    final dashPath = _createDashedPath(path);
    canvas.drawPath(dashPath, paint);
  }

  Path _createDashedPath(Path source) {
    final dashPath = Path();
    for (final metric in source.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final len = _dashWidth.clamp(0, metric.length - distance);
        dashPath.addPath(
          metric.extractPath(distance, distance + len),
          Offset.zero,
        );
        distance += _dashWidth + _dashSpace;
      }
    }
    return dashPath;
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.borderRadius != borderRadius;
  }
}
