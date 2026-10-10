import 'package:flutter/material.dart';

import 'package:submersion/features/documents/domain/entities/document_page.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The editor's pages: card types first show a Front and a Back slot, then
/// any further pages in a reorderable row, then an "Add page" tile.
///
/// The strip only arranges. Capturing a page is the editor's job: [onAdd]
/// is called with the slot's side (null for an extra page) and [onChanged]
/// receives every new arrangement, re-numbered from 0.
class DocumentPageStrip extends StatelessWidget {
  final List<DocumentPage> pages;
  final bool cardSlots;
  final ValueChanged<List<DocumentPage>> onChanged;
  final ValueChanged<DocumentPageSide?> onAdd;

  const DocumentPageStrip({
    super.key,
    required this.pages,
    required this.cardSlots,
    required this.onChanged,
    required this.onAdd,
  });

  static const double _height = 96;

  List<DocumentPage> get _extras => [
    for (final p in pages)
      if (!cardSlots || p.side == null) p,
  ];

  DocumentPage? _slot(DocumentPageSide side) =>
      pages.where((p) => p.side == side).firstOrNull;

  void _emit(List<DocumentPage> next) =>
      onChanged([for (final (i, p) in next.indexed) p.copyWith(pageIndex: i)]);

  /// Card slots keep their place at the front; extras follow in order.
  List<DocumentPage> _assemble(List<DocumentPage> extras) => [
    if (cardSlots) ...[
      ?_slot(DocumentPageSide.front),
      ?_slot(DocumentPageSide.back),
    ],
    ...extras,
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final extras = _extras;
    return SizedBox(
      height: _height,
      child: Row(
        children: [
          if (cardSlots) ...[
            _SlotTile(
              label: l10n.documents_pages_front,
              page: _slot(DocumentPageSide.front),
              onTap: () => onAdd(DocumentPageSide.front),
              onRemove: () => _emit(
                _assemble(
                  extras,
                ).where((p) => p.side != DocumentPageSide.front).toList(),
              ),
            ),
            const SizedBox(width: 8),
            _SlotTile(
              label: l10n.documents_pages_back,
              page: _slot(DocumentPageSide.back),
              onTap: () => onAdd(DocumentPageSide.back),
              onRemove: () => _emit(
                _assemble(
                  extras,
                ).where((p) => p.side != DocumentPageSide.back).toList(),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: ReorderableListView.builder(
              scrollDirection: Axis.horizontal,
              buildDefaultDragHandles: false,
              itemCount: extras.length,
              onReorderItem: (from, to) {
                final next = [...extras];
                next.insert(to, next.removeAt(from));
                _emit(_assemble(next));
              },
              itemBuilder: (context, i) => Padding(
                key: ValueKey('document-page-${extras[i].id}-$i'),
                padding: const EdgeInsets.only(right: 8),
                child: ReorderableDragStartListener(
                  index: i,
                  child: _PageTile(
                    page: extras[i],
                    onRemove: () => _emit(_assemble([...extras]..removeAt(i))),
                  ),
                ),
              ),
              footer: _AddTile(onTap: () => onAdd(null)),
            ),
          ),
        ],
      ),
    );
  }
}

class _Frame extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;

  const _Frame({required this.child, this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: DocumentPageStrip._height * 1.4,
      height: DocumentPageStrip._height,
      child: Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: InkWell(onTap: onTap, child: child),
      ),
    );
  }
}

class _PageTile extends StatelessWidget {
  final DocumentPage page;
  final VoidCallback onRemove;
  final String? label;

  const _PageTile({required this.page, required this.onRemove, this.label});

  @override
  Widget build(BuildContext context) {
    final bytes = page.bytes;
    final scheme = Theme.of(context).colorScheme;
    return _Frame(
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (page.isImage && bytes != null)
            Image.memory(
              bytes,
              fit: BoxFit.cover,
              cacheWidth: 300,
              errorBuilder: (context, _, _) => _fileFace(context),
            )
          else
            _fileFace(context),
          if (label != null)
            Positioned(left: 4, top: 4, child: _Label(text: label!)),
          Positioned(
            top: 0,
            right: 0,
            child: IconButton(
              tooltip: context.l10n.documents_pages_remove,
              icon: const Icon(Icons.close, size: 18),
              style: IconButton.styleFrom(
                backgroundColor: scheme.surface.withValues(alpha: 0.8),
              ),
              onPressed: onRemove,
            ),
          ),
        ],
      ),
    );
  }

  Widget _fileFace(BuildContext context) {
    final theme = Theme.of(context);
    return ColoredBox(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              page.isPdf
                  ? Icons.picture_as_pdf_outlined
                  : Icons.insert_drive_file_outlined,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 4),
            Text(
              page.fileName,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: theme.textTheme.labelSmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _SlotTile extends StatelessWidget {
  final String label;
  final DocumentPage? page;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const _SlotTile({
    required this.label,
    required this.page,
    required this.onTap,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final current = page;
    if (current != null) {
      return GestureDetector(
        onTap: onTap,
        child: _PageTile(page: current, onRemove: onRemove, label: label),
      );
    }
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      label: label,
      child: _Frame(
        onTap: onTap,
        child: ColoredBox(
          color: theme.colorScheme.surfaceContainerHighest,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.add_a_photo_outlined,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 4),
              Text(label, style: theme.textTheme.labelMedium),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddTile extends StatelessWidget {
  final VoidCallback onTap;

  const _AddTile({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _Frame(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.add, color: theme.colorScheme.primary),
          const SizedBox(height: 4),
          Text(
            context.l10n.documents_pages_add,
            textAlign: TextAlign.center,
            style: theme.textTheme.labelMedium,
          ),
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;

  const _Label({required this.text});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: scheme.inverseSurface.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: Theme.of(
          context,
        ).textTheme.labelSmall?.copyWith(color: scheme.onInverseSurface),
      ),
    );
  }
}
