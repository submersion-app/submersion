import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

import 'package:submersion/features/documents/domain/entities/document_page.dart';
import 'package:submersion/features/documents/presentation/helpers/document_page_opener.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Swipes through a document's pages. Images zoom with a pinch, PDFs render
/// in place, and Word and text pages offer "Open with". A page that fails
/// to render degrades to a placeholder with the same action.
class DocumentPageViewer extends StatefulWidget {
  final List<DocumentPage> pages;

  const DocumentPageViewer({super.key, required this.pages});

  @override
  State<DocumentPageViewer> createState() => _DocumentPageViewerState();
}

class _DocumentPageViewerState extends State<DocumentPageViewer> {
  final _controller = PageController();
  int _current = 0;

  @override
  void didUpdateWidget(DocumentPageViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    // An edit can remove pages while this stays on screen: land on the new
    // last page rather than counting past the end.
    final last = widget.pages.length - 1;
    if (last >= 0 && _current > last) {
      _current = last;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _controller.hasClients) _controller.jumpToPage(last);
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pages = widget.pages;
    return Column(
      children: [
        if (pages.length > 1)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(
              context.l10n.documents_page_counter(_current + 1, pages.length),
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ),
        Expanded(
          child: PageView.builder(
            controller: _controller,
            itemCount: pages.length,
            onPageChanged: (i) => setState(() => _current = i),
            itemBuilder: (context, i) => _PageView(page: pages[i]),
          ),
        ),
      ],
    );
  }
}

class _PageView extends StatelessWidget {
  final DocumentPage page;

  const _PageView({required this.page});

  @override
  Widget build(BuildContext context) {
    final bytes = page.bytes;
    if (bytes == null) return _FileTile(page: page);
    if (page.isImage) {
      return InteractiveViewer(
        maxScale: 6,
        child: Image.memory(
          bytes,
          fit: BoxFit.contain,
          errorBuilder: (context, _, _) => _CannotDisplay(page: page),
        ),
      );
    }
    if (page.isPdf) return _PdfPage(page: page);
    return _FileTile(page: page);
  }
}

class _PdfPage extends StatefulWidget {
  final DocumentPage page;

  const _PdfPage({required this.page});

  @override
  State<_PdfPage> createState() => _PdfPageState();
}

class _PdfPageState extends State<_PdfPage> {
  late final Future<void> _engineReady = pdfrxFlutterInitialize();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _engineReady,
      builder: (context, snapshot) {
        if (snapshot.hasError) return _CannotDisplay(page: widget.page);
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        return PdfViewer.data(
          widget.page.bytes!,
          sourceName: 'document-page-${widget.page.id}',
          params: PdfViewerParams(
            // A corrupt file degrades to the placeholder, not a crash.
            errorBannerBuilder: (context, error, stackTrace, _) =>
                _CannotDisplay(page: widget.page),
          ),
        );
      },
    );
  }
}

class _FileTile extends StatelessWidget {
  final DocumentPage page;

  const _FileTile({required this.page});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Scrolls rather than overflows when the pages get a short strip (a
    // phone in landscape with the details open).
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.insert_drive_file_outlined,
              size: 56,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 12),
            Text(
              page.fileName,
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.tonalIcon(
              icon: const Icon(Icons.open_in_new),
              label: Text(context.l10n.documents_page_openWith),
              onPressed: () => openDocumentPageExternally(context, page),
            ),
          ],
        ),
      ),
    );
  }
}

class _CannotDisplay extends StatelessWidget {
  final DocumentPage page;

  const _CannotDisplay({required this.page});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Scrolls rather than overflows when the pages get a short strip (a
    // phone in landscape with the details open).
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.broken_image_outlined,
              size: 56,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(
              context.l10n.documents_page_cannotDisplay,
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.tonalIcon(
              icon: const Icon(Icons.open_in_new),
              label: Text(context.l10n.documents_page_openWith),
              onPressed: () => openDocumentPageExternally(context, page),
            ),
          ],
        ),
      ),
    );
  }
}
