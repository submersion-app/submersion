import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/material.dart';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/universal_import/presentation/providers/universal_import_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/services/incoming_file_handler.dart';

/// Wraps content with a desktop drag-and-drop target that navigates to the
/// import wizard when a supported file is dropped.
///
/// On non-desktop platforms, this widget passes through [child] unchanged.
/// Shows a frosted glass overlay when a file is dragged over the app.
class GlobalDropTarget extends ConsumerStatefulWidget {
  const GlobalDropTarget({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<GlobalDropTarget> createState() => _GlobalDropTargetState();
}

class _GlobalDropTargetState extends ConsumerState<GlobalDropTarget> {
  bool _isDragging = false;

  static bool get _isDesktop =>
      Platform.isWindows || Platform.isMacOS || Platform.isLinux;

  @override
  Widget build(BuildContext context) {
    if (!_isDesktop) return widget.child;

    return DropTarget(
      onDragEntered: (_) => setState(() => _isDragging = true),
      onDragExited: (_) => setState(() => _isDragging = false),
      onDragDone: (details) => _handleDrop(details),
      child: Stack(
        children: [widget.child, if (_isDragging) const _FrostedDropOverlay()],
      ),
    );
  }

  Future<void> _handleDrop(DropDoneDetails details) async {
    setState(() => _isDragging = false);

    if (details.files.isEmpty) return;

    // Read the first file only
    final xFile = details.files.first;
    final Uint8List bytes;
    try {
      bytes = await xFile.readAsBytes();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.dropTarget_error_readFailed)),
        );
      }
      return;
    }

    if (!mounted) return;

    final shouldNavigate = await handleIncomingFile(
      bytes: bytes,
      fileName: xFile.name,
      currentPath: GoRouterState.of(context).uri.path,
      notifier: ref.read(universalImportNotifierProvider.notifier),
      messenger: ScaffoldMessenger.of(context),
      wizardActiveMessage: context.l10n.dropTarget_error_wizardActive,
      unsupportedFileMessage: context.l10n.dropTarget_error_unsupportedFile,
    );

    if (!mounted) return;

    if (shouldNavigate) {
      context.go('/transfer/import-wizard');
    }
  }
}

/// Frosted glass overlay shown when a file is dragged over the app.
class _FrostedDropOverlay extends StatelessWidget {
  const _FrostedDropOverlay();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Positioned.fill(
      child: IgnorePointer(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: ColoredBox(
            color: const Color(0xBF0A1628),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: const Color(0x9964B4FF),
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.upload_file,
                      size: 40,
                      color: Color(0xCC64B4FF),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l10n.dropTarget_title,
                    style: const TextStyle(
                      color: Color(0xE664B4FF),
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.dropTarget_subtitle,
                    style: const TextStyle(
                      color: Color(0x99B4C8E6),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
