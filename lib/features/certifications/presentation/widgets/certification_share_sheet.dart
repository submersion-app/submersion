import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:submersion/features/certifications/domain/entities/certification.dart';
import 'package:submersion/features/certifications/presentation/services/certification_card_renderer.dart';

/// Bottom sheet for sharing a certification as an image.
///
/// Provides two sharing options:
/// - Share as Card: Generates a credit card-style certification image
/// - Share as Certificate: Generates a formal certificate document
class CertificationShareSheet extends StatefulWidget {
  /// The certification to share.
  final Certification certification;

  /// The name of the diver holding this certification.
  final String diverName;

  const CertificationShareSheet({
    super.key,
    required this.certification,
    required this.diverName,
  });

  @override
  State<CertificationShareSheet> createState() =>
      _CertificationShareSheetState();
}

class _CertificationShareSheetState extends State<CertificationShareSheet> {
  bool _isExporting = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Title
            Text(
              'Share Certification',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),

            // Subtitle with certification name
            Text(
              widget.certification.name,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 24),

            // Share options
            _ShareOptionTile(
              icon: Icons.credit_card,
              title: 'Share as Card',
              subtitle: 'Credit card-style certification image',
              onTap: _isExporting ? null : _shareAsCard,
              isLoading: _isExporting,
            ),
            const SizedBox(height: 12),
            _ShareOptionTile(
              icon: Icons.article_outlined,
              title: 'Share as Certificate',
              subtitle: 'Formal certificate document',
              onTap: _isExporting ? null : _shareAsCertificate,
              isLoading: _isExporting,
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _shareAsCard() async {
    setState(() => _isExporting = true);

    try {
      final bytes = await CertificationCardRenderer.generateCardImage(
        certification: widget.certification,
        diverName: widget.diverName,
      );
      if (bytes == null) {
        throw Exception('Failed to generate card image');
      }

      // Save to temp file
      final tempDir = await getTemporaryDirectory();
      final sanitizedName = _sanitizeFilename(widget.certification.name);
      final filename = 'certification_${sanitizedName}_card.png';
      final file = File('${tempDir.path}/$filename');
      await file.writeAsBytes(bytes);

      // Pop before sharing to avoid UI issues
      if (mounted) Navigator.of(context).pop();

      // Share the file
      await SharePlus.instance.share(
        ShareParams(files: [XFile(file.path, mimeType: 'image/png')]),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isExporting = false);
        _showError('Failed to share card: $e');
      }
    }
  }

  Future<void> _shareAsCertificate() async {
    setState(() => _isExporting = true);

    try {
      final bytes = await CertificationCardRenderer.generateCertificateImage(
        certification: widget.certification,
        diverName: widget.diverName,
      );
      if (bytes == null) {
        throw Exception('Failed to generate certificate image');
      }

      // Save to temp file
      final tempDir = await getTemporaryDirectory();
      final sanitizedName = _sanitizeFilename(widget.certification.name);
      final filename = 'certification_${sanitizedName}_certificate.png';
      final file = File('${tempDir.path}/$filename');
      await file.writeAsBytes(bytes);

      // Pop before sharing to avoid UI issues
      if (mounted) Navigator.of(context).pop();

      // Share the file
      await SharePlus.instance.share(
        ShareParams(files: [XFile(file.path, mimeType: 'image/png')]),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isExporting = false);
        _showError('Failed to share certificate: $e');
      }
    }
  }

  /// Sanitizes a string for use in a filename.
  String _sanitizeFilename(String name) {
    return name
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s-]'), '')
        .replaceAll(RegExp(r'\s+'), '_')
        .replaceAll(RegExp(r'_+'), '_');
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }
}

/// A tile widget for share options.
class _ShareOptionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool isLoading;

  const _ShareOptionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      button: true,
      label: '$title. $subtitle',
      child: Card(
        margin: EdgeInsets.zero,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: theme.colorScheme.onPrimaryContainer,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isLoading)
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  Icon(
                    Icons.chevron_right,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
