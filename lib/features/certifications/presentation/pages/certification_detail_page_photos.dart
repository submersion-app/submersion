part of 'certification_detail_page.dart';

/// The certification page's card photos and its delete confirmation.
extension _CertificationDetailPhotos on _CertificationDetailContent {
  Widget _buildPhotosSection(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle(
              context,
              context.l10n.certifications_detail_sectionTitle_cardPhotos,
            ),
            const SizedBox(height: 12),
            // Stacked full-width, not side by side: at card-width thumbnails
            // a photographed card is too small to read (issue #966), and
            // BoxFit.contain (not cover) shows the whole card instead of
            // cropping it.
            if (certification.photoFront != null)
              _buildPhotoThumbnail(
                context,
                imageData: certification.photoFront!,
                label: context.l10n.certifications_detail_photoLabel_front,
              ),
            if (certification.photoFront != null &&
                certification.photoBack != null)
              const SizedBox(height: 16),
            if (certification.photoBack != null)
              _buildPhotoThumbnail(
                context,
                imageData: certification.photoBack!,
                label: context.l10n.certifications_detail_photoLabel_back,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoThumbnail(
    BuildContext context, {
    required Uint8List imageData,
    required String label,
  }) {
    return Column(
      children: [
        Semantics(
          button: true,
          label: context.l10n
              .certifications_detail_semanticLabel_photoTapToView(
                label,
                certificationTitleL10n(
                  certification,
                  context.l10n,
                  catalog: context.certificationCatalog,
                ),
              ),
          child: GestureDetector(
            onTap: () => _showFullscreenPhoto(context, imageData, label),
            child: AspectRatio(
              aspectRatio: CertificationEcard.aspectRatio,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                ),
                clipBehavior: Clip.antiAlias,
                child: Image.memory(
                  imageData,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.broken_image_outlined,
                            size: 32,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            context
                                .l10n
                                .certifications_detail_photo_unableToLoad,
                            style: TextStyle(
                              fontSize: 10,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  void _showFullscreenPhoto(
    BuildContext context,
    Uint8List imageData,
    String label,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            title: Text(
              context.l10n.certifications_detail_photo_fullscreenTitle(
                label,
                certificationTitleL10n(
                  certification,
                  context.l10n,
                  catalog: context.certificationCatalog,
                ),
              ),
            ),
          ),
          body: InteractiveViewer(
            minScale: 0.5,
            maxScale: 4.0,
            child: Center(
              child: Image.memory(
                imageData,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.broken_image_outlined,
                          size: 64,
                          color: Colors.white54,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          context.l10n.certifications_detail_photo_unableToLoad,
                          style: const TextStyle(color: Colors.white54),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<bool> _showDeleteConfirmation(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(context.l10n.certifications_detail_dialog_deleteTitle),
            content: Text(
              context.l10n.certifications_detail_dialog_deleteContent(
                certificationTitleL10n(
                  certification,
                  context.l10n,
                  catalog: context.certificationCatalog,
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(context.l10n.certifications_detail_dialog_cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                ),
                child: Text(
                  context.l10n.certifications_detail_dialog_deleteConfirm,
                ),
              ),
            ],
          ),
        ) ??
        false;
  }

  /// Safely abbreviate agency name to at most 4 characters
}
